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

#import <CoreMIDI/CoreMIDI.h>

#import "WebViewDelegate.h"

static NSString *kURLScheme_RequestSetup = @"webmidi-onready://";
static NSString *kURLScheme_RequestSend  = @"webmidi-send://";

@implementation WebViewDelegate

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
                                @"manufacturer" : (__bridge NSString *)manufacturer,
                                @"name"         : (__bridge NSString *)name,
                              };
    
    return portInfo;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // Process informal URL schemes.
    NSString *urlStr = request.URL.absoluteString;
    if ([urlStr hasPrefix:kURLScheme_RequestSetup]) {
        // Setup the callback for receiving MIDI message.
        _midiDriver.onReceiveMessage = ^(ItemCount index, NSData *receivedData) {
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:[receivedData length]];
            for (int i = 0; i < [receivedData length]; i++) {
                [array addObject:[NSNumber numberWithUnsignedChar:((unsigned char *)[receivedData bytes])[i]]];
            }
            NSData *dataJSON = [NSJSONSerialization dataWithJSONObject:array options:0 error:nil];
            NSString *dataJSONStr = [[NSString alloc] initWithData:dataJSON encoding:NSUTF8StringEncoding];
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"_callback_receiveMIDIMessage(%lu, %d, %@);", index, 0, dataJSONStr]];
        };
        
        // Send all MIDI ports information when the setup request is received.
        ItemCount srcCount = MIDIGetNumberOfSources();
        ItemCount destCount = MIDIGetNumberOfDestinations();

        NSMutableArray *srcs  = [NSMutableArray arrayWithCapacity:srcCount];
        NSMutableArray *dests = [NSMutableArray arrayWithCapacity:destCount];


        for (ItemCount srcIndex = 0; srcIndex < srcCount; srcIndex++) {
            MIDIEndpointRef endpoint = MIDIGetSource(srcIndex);
            NSDictionary *info = [self portinfoFromEndpointRef:endpoint];
            [srcs addObject:info];
        }

        for (ItemCount destIndex = 0; destIndex < destCount; destIndex++) {
            MIDIEndpointRef endpoint = MIDIGetSource(destIndex);
            NSDictionary *info = [self portinfoFromEndpointRef:endpoint];
            [dests addObject:info];
        }

        
        NSData *srcsJSON = [NSJSONSerialization dataWithJSONObject:srcs options:0 error:nil];
        NSString *srcsJSONStr = [[NSString alloc] initWithData:srcsJSON encoding:NSUTF8StringEncoding];

        NSData *destsJSON = [NSJSONSerialization dataWithJSONObject:dests options:0 error:nil];
        NSString *destsJSONStr = [[NSString alloc] initWithData:destsJSON encoding:NSUTF8StringEncoding];

        [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"_callback_onReady(%@, %@);", srcsJSONStr, destsJSONStr]];
        
        
        return NO;
    } else if ([urlStr hasPrefix:kURLScheme_RequestSend]) {
        NSString *jsonStr = [[urlStr substringFromIndex:[kURLScheme_RequestSend length]] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSData *data = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

        NSArray *array = dict[@"data"];

        NSMutableData *message = [NSMutableData dataWithCapacity:[array count]];
        for (NSNumber *number in array) {
            uint8_t byte = [number unsignedIntegerValue];
            [message appendBytes:&byte length:1];
        }

        ItemCount outputIndex = [dict[@"outputPortIndex"] unsignedLongValue];
        float deltatime = [dict[@"deltaTime"] floatValue];
        [_midiDriver sendMessage:message toDestinationIndex:outputIndex deltatime:deltatime];

        return NO;
    }
    
    return YES;
}

@end
