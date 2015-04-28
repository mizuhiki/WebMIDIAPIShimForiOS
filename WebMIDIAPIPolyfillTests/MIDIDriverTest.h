//
//  MIDIDriverTest.h
//  WebMIDIAPIShimForiOS
//
//  Created by 水引 孝至 on 2015/04/17.
//  Copyright (c) 2015年 Takashi Mizuhiki. All rights reserved.
//

#import "MIDIDriver.h"

@interface MIDIDriverTest : MIDIDriver
@property (nonatomic, assign) NSUInteger numOfOutputPorts;
@property (nonatomic, assign) NSUInteger numOfInputPorts;

@property (nonatomic, copy) void (^onSendMessageCalled)(NSData *data, ItemCount index, float deltatime_ms);
@property (nonatomic, copy) void (^onClearCalled)(ItemCount index);

- (void)simulateReceivingMessage:(NSData *)data toDestinationIndex:(ItemCount)index deltatime:(float)deltatime_ms;
- (void)simulateAddingMIDIInputPort:(ItemCount)index;
- (void)simulateRemovingMIDIInputPort:(ItemCount)index;
- (void)simulateAddingMIDIOutputPort:(ItemCount)index;
- (void)simulateRemovingMIDIOutputPort:(ItemCount)index;

@end
