/*
 
 Copyright 2014 Takashi Mizuhiki
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */

#import <mach/mach_time.h>
#import <CoreMIDI/CoreMIDI.h>

#import "MIDIDriver.h"
#import "MIDIParser.h"

@interface MIDINotificationLogItem : NSObject
@property (nonatomic, assign) MIDIObjectAddRemoveNotification notification;
@end

@implementation MIDINotificationLogItem
@end

@interface MIDIDriver () {
    MIDIClientRef _clientRef;
    MIDIPortRef _inputPortRef;
    MIDIPortRef _outputPortRef;

    NSArray *_parsers;
    mach_timebase_info_data_t _base;
    
    NSArray *_destinationEndpointIDs;
    NSArray *_sourceEndpointIDs;

    NSMutableArray *_midiNotificationLog;
}

@end

@implementation MIDIDriver

#pragma mark -
#pragma mark API

- (void)sendMessage:(NSData *)data toDestinationIndex:(ItemCount)index deltatime:(float)deltatime_ms
{
    MIDIEndpointRef endpoint = MIDIGetDestination(index);
    MIDITimeStamp timestamp = mach_absolute_time() + deltatime_ms * 1000000 /* ns */ * _base.denom / _base.numer;

    Byte buffer[sizeof(MIDIPacketList) + [data length]];
    MIDIPacketList *packetList = (MIDIPacketList *)buffer;
    MIDIPacket *packet = MIDIPacketListInit(packetList);
    packet = MIDIPacketListAdd(packetList, sizeof(buffer), packet, timestamp, [data length], [data bytes]);
    
    MIDISend(_outputPortRef, endpoint, packetList);

    return;
}

- (NSDictionary *)portinfoFromEndpointRef:(MIDIEndpointRef)endpoint
{
    SInt32 uniqueId;
    MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueId);
    
    CFStringRef manufacturer;
    MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer);
    
    CFStringRef name;
    MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name);
    
    SInt32 version;
    MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyDriverVersion, &version);
    
    NSDictionary *portInfo = @{ @"id"           : [NSNumber numberWithInt:uniqueId],
                                @"version"      : [NSNumber numberWithInt:version],
                                @"manufacturer" : ((__bridge NSString *)manufacturer ?: @""),
                                @"name"         : ((__bridge NSString *)name ?: @""),
                                };
    
    return portInfo;
}

- (NSDictionary *)portinfoFromDestinationEndpointIndex:(ItemCount)index
{
    return [self portinfoFromEndpointRef:MIDIGetDestination(index)];
}

- (NSDictionary *)portinfoFromSourceEndpointIndex:(ItemCount)index
{
    return [self portinfoFromEndpointRef:MIDIGetSource(index)];
}

- (ItemCount)numberOfSources
{
    return MIDIGetNumberOfSources();
}

- (ItemCount)numberOfDestinations
{
    return MIDIGetNumberOfDestinations();
}

#pragma mark -
#pragma mark MIDIParser delegate

- (void)midiParser:(MIDIParser *)parser recvMessage:(uint8_t *)message length:(uint32_t)length timestamp:(uint64_t)timestamp
{
    NSData *data = [[NSData alloc] initWithBytes:message length:length];
    
    ItemCount index = [_parsers indexOfObject:parser];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (_onMessageReceived) {
            _onMessageReceived(index, data, timestamp);
        }
    });    
}

static void MyMIDIInputProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon)
{
    MIDIParser *parser = (__bridge MIDIParser *)srcConnRefCon;
    
    MIDIPacket *packet = (MIDIPacket *)&(pktlist->packet[0]);
    UInt32 packetCount = pktlist->numPackets;

    for (NSInteger i = 0; i < packetCount; i++) {
        [parser setMessage:packet->data length:packet->length timestamp:packet->timeStamp];
        packet = MIDIPacketNext(packet);
    }
}

static void MyMIDINotifyProc(const MIDINotification *notification, void *refCon)
{
    MIDIDriver *myself = (__bridge MIDIDriver *)refCon;
    [myself onMIDINotification:notification];
}

- (void)onMIDINotification:(const MIDINotification *)notification
{
    switch (notification->messageID) {
        case kMIDIMsgSetupChanged:
            // Notify removed MIDI ports
            for (MIDINotificationLogItem *item in _midiNotificationLog) {
                MIDIObjectAddRemoveNotification n = item.notification;
                if (n.messageID == kMIDIMsgObjectRemoved) {
                    MIDIEndpointRef endpointRef = (MIDIEndpointRef)n.child;
                    SInt32 uniqueId;
                    MIDIObjectGetIntegerProperty(endpointRef, kMIDIPropertyUniqueID, &uniqueId);

                    switch (n.childType) {
                        case kMIDIObjectType_Destination:
                            {
                                NSUInteger index = [_destinationEndpointIDs indexOfObject:[NSNumber numberWithInt:uniqueId]];
                                NSAssert(index != NSNotFound, @"Removed unknown MIDI destination");
                                if (_onDestinationPortRemoved) {
                                    _onDestinationPortRemoved(index);
                                }
                            }
                            break;
                            
                        case kMIDIObjectType_Source:
                            {
                                NSUInteger index = [_sourceEndpointIDs indexOfObject:[NSNumber numberWithInt:uniqueId]];
                                NSAssert(index != NSNotFound, @"Removed unknown MIDI source");
                                if (_onSourcePortRemoved) {
                                    _onSourcePortRemoved(index);
                                }
                            }
                            break;
                            
                        default:
                            break;
                    }
                }
            }

            // Rebuild the port ID tables and the received MIDI message parsers
            [self disposeMIDIInPort];
            [self disposeMIDIOutPort];
            [self createMIDIInPort];
            [self createMIDIOutPort];

            // Notify added MIDI ports
            for (MIDINotificationLogItem *item in _midiNotificationLog) {
                MIDIObjectAddRemoveNotification n = item.notification;
                if (n.messageID == kMIDIMsgObjectAdded) {
                    MIDIEndpointRef endpointRef = (MIDIEndpointRef)n.child;
                    SInt32 uniqueId;
                    MIDIObjectGetIntegerProperty(endpointRef, kMIDIPropertyUniqueID, &uniqueId);

                    switch (n.childType) {
                        case kMIDIObjectType_Destination:
                            {
                                NSUInteger index = [_destinationEndpointIDs indexOfObject:[NSNumber numberWithInt:uniqueId]];
                                NSAssert(index != NSNotFound, @"Added unknown MIDI destination");
                                if (_onDestinationPortAdded) {
                                    _onDestinationPortAdded(index);
                                }
                            }
                            break;
                            
                        case kMIDIObjectType_Source:
                            {
                                NSUInteger index = [_sourceEndpointIDs indexOfObject:[NSNumber numberWithInt:uniqueId]];
                                NSAssert(index != NSNotFound, @"Added unknown MIDI source");
                                if (_onSourcePortAdded) {
                                    _onSourcePortAdded(index);
                                }
                            }
                            break;
                            
                        default:
                            break;
                    }
                }
            }
            
            _midiNotificationLog = nil;
            
            break;
            
        case kMIDIMsgObjectAdded:
        case kMIDIMsgObjectRemoved:
            {
                if (_midiNotificationLog == nil) {
                    _midiNotificationLog = [NSMutableArray array];
                }
                
                MIDINotificationLogItem *item = [[MIDINotificationLogItem alloc] init];
                item.notification = *((MIDIObjectAddRemoveNotification *)notification);

                [_midiNotificationLog addObject:item];
            }
            break;
            
        default:
            break;
    }
}

- (BOOL)createMIDIInPort
{
    OSStatus err;
    
    NSString *inputPortName = @"inputPort";
    err = MIDIInputPortCreate(_clientRef, (__bridge CFStringRef)inputPortName, MyMIDIInputProc, (__bridge void *)(self), &_inputPortRef);
    if (err != noErr) {
        NSLog(@"MIDIInputPortCreate err = %d", (int)err);
        return NO;
    }
    
    // Get MIDI IN endpoints and connect them to the MIDI port.
    ItemCount sourceCount = MIDIGetNumberOfSources();
    NSMutableArray *parsers = [NSMutableArray arrayWithCapacity:sourceCount];
    NSMutableArray *sourceEndpointIDs = [NSMutableArray arrayWithCapacity:sourceCount];

    for (ItemCount i = 0; i < sourceCount; i++) {
        MIDIParser *parser = [[MIDIParser alloc] init];
        parser.delegate = self;
        [parsers addObject:parser];
        
        MIDIEndpointRef endpointRef = MIDIGetSource(i);
        err = MIDIPortConnectSource(_inputPortRef, endpointRef, (__bridge void *)parser);
        
        //
        SInt32 uniqueId;
        MIDIObjectGetIntegerProperty(endpointRef, kMIDIPropertyUniqueID, &uniqueId);
        
        [sourceEndpointIDs addObject:[NSNumber numberWithInt:uniqueId]];
    }
    
    _parsers = parsers;
    _sourceEndpointIDs = sourceEndpointIDs;

    return YES;
}

- (BOOL)createMIDIOutPort
{
    OSStatus err;
    
    NSString *outputPortName = @"outputPort";
    err = MIDIOutputPortCreate(_clientRef, (__bridge CFStringRef)outputPortName, &_outputPortRef);
    if (err != noErr) {
        NSLog(@"MIDIOutputPortCreate err = %d", (int)err);
        return NO;
    }

    ItemCount destinationCount = MIDIGetNumberOfDestinations();
    NSMutableArray *destinationEndpointIDs = [NSMutableArray arrayWithCapacity:destinationCount];
    for (ItemCount i = 0; i < destinationCount; i++) {
        MIDIEndpointRef endpointRef = MIDIGetDestination(i);

        SInt32 uniqueId;
        MIDIObjectGetIntegerProperty(endpointRef, kMIDIPropertyUniqueID, &uniqueId);
        
        [destinationEndpointIDs addObject:[NSNumber numberWithInt:uniqueId]];
    }

    _destinationEndpointIDs = destinationEndpointIDs;
    
    return YES;
}

- (void)disposeMIDIInPort
{
    MIDIPortDispose(_inputPortRef);
    _inputPortRef = 0;

    _parsers = nil;
}

- (void)disposeMIDIOutPort
{
    MIDIPortDispose(_outputPortRef);
    _outputPortRef = 0;
}

- (void)createMIDIClient
{
    OSStatus err;

    NSString *clientName = @"inputClient";
    err = MIDIClientCreate((__bridge CFStringRef)clientName, MyMIDINotifyProc, (__bridge void *)(self), &_clientRef);
    if (err != noErr) {
        NSLog(@"MIDIClientCreate err = %d", (int)err);
        return;
    }

    if ([self createMIDIInPort] == NO) {
        return;
    }

    if ([self createMIDIOutPort] == NO) {
        return;
    }

    return;
}

- (void)disposeMIDIClient
{
    MIDIClientDispose(_clientRef);
}

- (id)init
{
    self = [super init];
    if (self) {
        mach_timebase_info(&_base);

        [self createMIDIClient];
    }
    
    return self;
}

- (void)dealloc
{
    [self disposeMIDIClient];
}

@end
