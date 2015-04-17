//
//  MIDIDriverTest.m
//  WebMIDIAPIShimForiOS
//
//  Created by 水引 孝至 on 2015/04/17.
//  Copyright (c) 2015年 Takashi Mizuhiki. All rights reserved.
//

#import <mach/mach_time.h>
#import <CoreMIDI/CoreMIDI.h>
#import "MIDIDriverTest.h"

@implementation MIDIDriverTest

- (OSStatus)sendMessage:(NSData *)data toDestinationIndex:(ItemCount)index deltatime:(float)deltatime_ms
{
    if (_onSendMessageCalled) {
        _onSendMessageCalled(data, index, deltatime_ms);
    }
    
    return noErr;
}

- (OSStatus)sendMessage:(NSData *)data toVirtualSourceIndex:(ItemCount)vindex timestamp:(uint64_t)timestamp
{
    return noErr;
}

- (OSStatus)clearWithDestinationIndex:(ItemCount)index
{
    if (_onClearCalled) {
        _onClearCalled(index);
    }

    return noErr;
}

- (NSDictionary *)portinfoFromDestinationEndpointIndex:(ItemCount)index
{
    NSDictionary *portInfo = @{ @"id"           : [NSNumber numberWithInt:(int)index],
                                @"version"      : [NSNumber numberWithInt:0],
                                @"manufacturer" : @"ManufacturerName",
                                @"name"         : @"DestinationPortName",
                                };
    return portInfo;
}

- (NSDictionary *)portinfoFromSourceEndpointIndex:(ItemCount)index
{
    NSDictionary *portInfo = @{ @"id"           : [NSNumber numberWithInt:(int)index],
                                @"version"      : [NSNumber numberWithInt:0],
                                @"manufacturer" : @"ManufacturerName",
                                @"name"         : @"DestinationPortName",
                                };
    return portInfo;
}

- (ItemCount)numberOfSources
{
    return _numOfInputPorts;
}

- (ItemCount)numberOfDestinations
{
    return _numOfOutputPorts;
}

- (ItemCount)createVirtualSrcEndpointWithName:(NSString *)name
{
    return 0;
}

- (void)removeVirtualSrcEndpointWithIndex:(ItemCount)vindex
{
    return;
}

- (ItemCount)createVirtualDestEndpointWithName:(NSString *)name
{
    return 0;
}

- (void)removeVirtualDestEndpointWithIndex:(ItemCount)vindex
{
    return;
}

#pragma mark -
#pragma mark simulate receiving

- (void)simulateReceivingMessage:(NSData *)data toDestinationIndex:(ItemCount)index deltatime:(float)deltatime_ms
{
    if (self.onMessageReceived) {
        mach_timebase_info_data_t base;
        mach_timebase_info(&base);
        MIDITimeStamp timestamp = mach_absolute_time() + deltatime_ms * 1000000 /* ns */ * base.denom / base.numer;

        self.onMessageReceived(index, data, timestamp);
    }
}

- (void)simulateAddingMIDIInputPort:(ItemCount)index
{
    if (self.onSourcePortAdded) {
        self.onSourcePortAdded(index);
    }
}

- (void)simulateRemovingMIDIInputPort:(ItemCount)index
{
    if (self.onSourcePortRemoved) {
        self.onSourcePortRemoved(index);
    }
}

- (void)simulateAddingMIDIOutputPort:(ItemCount)index
{
    if (self.onDestinationPortAdded) {
        self.onDestinationPortAdded(index);
    }
}

- (void)simulateRemovingMIDIOutputPort:(ItemCount)index
{
    if (self.onDestinationPortRemoved) {
        self.onDestinationPortRemoved(index);
    }
}



@end
