/*
 
 Copyright 2015 Takashi Mizuhiki
 
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

#import <XCTest/XCTest.h>
#import "MIDIWebView.h"
#import "MIDIDriverTest.h"

const static NSTimeInterval kEvaluateTimeout_sec = 1.5f;

@interface MIDIWebViewTests : XCTestCase
@end

@implementation MIDIWebViewTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (BOOL)_testWMArequestMIDIAccessWithParameter:(NSString *)parameter sysExAllowed:(BOOL)sysexAllowed
{
    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    WKWebViewConfiguration *configuration = [MIDIWebView createConfigurationWithMIDIDriver:midiDriver
                                                                         sysexConfirmation:^(NSString *url) { return sysexAllowed; }];
    MIDIWebView *webView = [[MIDIWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    
    [UIApplication.sharedApplication.delegate.window addSubview:webView];
    
    // Open sample HTML file at bundle path
    //    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"test1" ofType:@"html"];
    //    NSString *html = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSString *html = [NSString stringWithFormat:
                      @"<html><head><script type=\"text/javascript\">"
                      @"window.onload = function() {"
                      @"  window.navigator.requestMIDIAccess( %@ ).then("
                      @"    function() { succeeded = 'true'; },"
                      @"    function() { succeeded = 'false'; }"
                      @"  );"
                      @"};"
                      @"</script></head></html>", parameter];
    
    [webView loadHTMLString:html baseURL:nil];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    __block bool succeeded = NO;
    [webView evaluateJavaScript:@"succeeded" completionHandler:^(id result, NSError *error) {
        succeeded = [result isEqualToString:@"true"];
    }];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    [webView removeFromSuperview];

    return succeeded;
}

- (void)testWMArequestMIDIAccess
{
    XCTAssertTrue ([self _testWMArequestMIDIAccessWithParameter:@"" sysExAllowed:NO]);
    XCTAssertTrue ([self _testWMArequestMIDIAccessWithParameter:@"" sysExAllowed:YES]);
    XCTAssertFalse([self _testWMArequestMIDIAccessWithParameter:@"{ sysex : true }" sysExAllowed:NO]);
    XCTAssertTrue ([self _testWMArequestMIDIAccessWithParameter:@"{ sysex : true }" sysExAllowed:YES]);
    XCTAssertTrue ([self _testWMArequestMIDIAccessWithParameter:@"{ sysex : \"false\" }" sysExAllowed:NO]);
    XCTAssertTrue ([self _testWMArequestMIDIAccessWithParameter:@"{ sysex : false }" sysExAllowed:YES]);
    XCTAssertFalse([self _testWMArequestMIDIAccessWithParameter:@"{ sysex : \"true\" }" sysExAllowed:NO]);
    XCTAssertTrue ([self _testWMArequestMIDIAccessWithParameter:@"{ sysex : \"true\" }" sysExAllowed:YES]);
    XCTAssertTrue ([self _testWMArequestMIDIAccessWithParameter:@"{ sysex : \"false\" }" sysExAllowed:NO]);
    XCTAssertTrue ([self _testWMArequestMIDIAccessWithParameter:@"{ sysex : \"false\" }" sysExAllowed:YES]);
}

- (void)testEnumeratePorts
{
    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    midiDriver.numOfOutputPorts = 1;
    midiDriver.numOfInputPorts  = 2;
    
    WKWebViewConfiguration *configuration = [MIDIWebView createConfigurationWithMIDIDriver:midiDriver
                                                                         sysexConfirmation:^(NSString *url) { return YES; }];
    MIDIWebView *webView = [[MIDIWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    
    [UIApplication.sharedApplication.delegate.window addSubview:webView];
    
    NSString *html =  @"<html><head><script type=\"text/javascript\">"
                      @"window.onload = function() {"
                      @"  window.navigator.requestMIDIAccess().then("
                      @"    function(access) {"
                      @"      if (access.outputs.size == 1 && access.inputs.size == 2) {"
                      @"        var outputs = [];"
                      @"        var iter = access.outputs.values();"
                      @"        for (var o = iter.next(); !o.done; o = iter.next()) {"
                      @"          outputs.push(o.value);"
                      @"        }"
                      @"        var inputs = [];"
                      @"        var iter = access.inputs.values();"
                      @"        for (var o = iter.next(); !o.done; o = iter.next()) {"
                      @"          inputs.push(o.value);"
                      @"        }"
                      @"        if (outputs.length == 1 && inputs.length == 2) {"
                      @"          succeeded = 'true';"
                      @"        }"
                      @"      }"
                      @"    },"
                      @"    function() { succeeded = 'false'; }"
                      @"  );"
                      @"};"
                      @"</script></head></html>";

    [webView loadHTMLString:html baseURL:nil];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    __block bool succeeded = NO;
    [webView evaluateJavaScript:@"succeeded" completionHandler:^(id result, NSError *error) {
        succeeded = [result isEqualToString:@"true"];
    }];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    [webView removeFromSuperview];
    
    XCTAssertTrue(succeeded == YES);
}


- (void)_testMIDIOutputSendWithParameter:(NSString *)param initParameter:(NSString *)initParam sysExAllowed:(BOOL)sysexAllowed midiDriver:(MIDIDriver *)driver
{
    WKWebViewConfiguration *configuration = [MIDIWebView createConfigurationWithMIDIDriver:driver
                                                                         sysexConfirmation:^(NSString *url) { return sysexAllowed; }];
    MIDIWebView *webView = [[MIDIWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    
    [UIApplication.sharedApplication.delegate.window addSubview:webView];
    
    NSString *html =  [NSString stringWithFormat:
                       @"<html><head><script type=\"text/javascript\">"
                       @"window.onload = function() {"
                       @"  window.navigator.requestMIDIAccess(%@).then("
                       @"    function(access) {"
                       @"      var iter = access.outputs.values();"
                       @"      for (var o = iter.next(); !o.done; o = iter.next()) {"
                       @"        o.value.send(%@, window.performance.now() + 100);"
                       @"      }"
                       @"    },"
                       @"    function() {}"
                       @"  );"
                       @"};"
                       @"</script></head></html>", initParam, param];
    
    [webView loadHTMLString:html baseURL:nil];
    

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    [webView removeFromSuperview];
    
}

- (void)testMIDIOutputSendChannelMessage
{
    __block bool succeeded;

    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    midiDriver.numOfOutputPorts = 1;
    midiDriver.onSendMessageCalled = ^(NSData *data, ItemCount index, float deltatime_ms) {
        if ([data isEqualToData:[NSData dataWithBytes:(uint8_t[]){ 0x90, 0x12, 0x34 } length:3]] == YES) {
            succeeded = YES;
        } else {
            succeeded = NO;
        }
    };

    succeeded = NO;
    [self _testMIDIOutputSendWithParameter:@"[ 0x90, 0x12, 0x34 ]" initParameter:@"" sysExAllowed:NO midiDriver:midiDriver];
    XCTAssertTrue(succeeded == YES);

    succeeded = NO;
    [self _testMIDIOutputSendWithParameter:@"[ \"0x90\", 18, 064 ]" initParameter:@"" sysExAllowed:NO midiDriver:midiDriver];
    XCTAssertTrue(succeeded == YES);
}

- (void)testMIDIOutputSendSysExMessage
{
    __block bool succeeded;
    
    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    midiDriver.numOfOutputPorts = 1;
    midiDriver.onSendMessageCalled = ^(NSData *data, ItemCount index, float deltatime_ms) {
        if ([data isEqualToData:[NSData dataWithBytes:(uint8_t[]){ 0xF0, 0x00, 0xF7 } length:3]] == YES &&
            index == 0 &&
            fabs(deltatime_ms - 100) <= 1.0f) {
            succeeded = YES;
        } else {
            succeeded = NO;
        }
    };

    succeeded = NO;
    [self _testMIDIOutputSendWithParameter:@"[ 0xF0, 0x00, 0xF7 ]" initParameter:@"{ sysex : true }" sysExAllowed:YES midiDriver:midiDriver];
    XCTAssertTrue(succeeded == YES);

    succeeded = NO;
    [self _testMIDIOutputSendWithParameter:@"[ 0xF0, 0x00, 0xF7 ]" initParameter:@"{ sysex : true }" sysExAllowed:NO midiDriver:midiDriver];
    XCTAssertTrue(succeeded == NO); // should be failed because sysex access disallowed

    succeeded = NO;
    [self _testMIDIOutputSendWithParameter:@"[ 0xF0, 0x00, 0xF7 ]" initParameter:@"" sysExAllowed:YES midiDriver:midiDriver];
    XCTAssertTrue(succeeded == NO);
}

- (void)testMIDIOutputOpen
{
    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    midiDriver.numOfOutputPorts = 1;

    WKWebViewConfiguration *configuration = [MIDIWebView createConfigurationWithMIDIDriver:midiDriver
                                                                         sysexConfirmation:^(NSString *url) { return YES; }];
    MIDIWebView *webView = [[MIDIWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    
    [UIApplication.sharedApplication.delegate.window addSubview:webView];
    
    NSString *html = @"<html><head><script type=\"text/javascript\">"
                     @"var port;"
                     @"window.onload = function() {"
                     @"  window.navigator.requestMIDIAccess().then("
                     @"    function(access) {"
                     @"      access.onstatechange = function(event) {"
                     @"        connection = event.port.connection;"
                     @"      };"
                     @"      var iter = access.outputs.values();"
                     @"      port = iter.next().value;"
                     @"      portconnection = port.connection;"
                     @"      port.onstatechange = function(event) {"
                     @"        portconnection = event.port.connection;"
                     @"      };"
                     @"    },"
                     @"    function() {}"
                     @"  );"
                     @"};"
                     @"</script></head></html>";
    
    [webView loadHTMLString:html baseURL:nil];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];

    // the default status should be "closed"
    __block bool succeeded = NO;
    [webView evaluateJavaScript:@"portconnection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"closed"]) {
            succeeded = YES;
        }
    }];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];

    XCTAssertTrue(succeeded == YES);

    // after calling open(), status should be "open"
    succeeded = NO;
    [webView evaluateJavaScript:@"port.open(); portconnection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"open"]) {
            succeeded = YES;
        }
    }];

    __block bool succeeded_connection = NO;
    [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"open"]) {
            succeeded_connection = YES;
        }
    }];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    XCTAssertTrue(succeeded == YES);
    XCTAssertTrue(succeeded_connection == YES);

    // after calling close(), status should be "close"
    succeeded = NO;
    [webView evaluateJavaScript:@"port.close(); portconnection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"closed"]) {
            succeeded = YES;
        }
    }];
    
    succeeded_connection = NO;
    [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"closed"]) {
            succeeded_connection = YES;
        }
    }];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];

    XCTAssertTrue(succeeded == YES);
    XCTAssertTrue(succeeded_connection == YES);
    
    // after calling send(), the port should be opened. Therefore, status should be "open".
    succeeded = NO;
    [webView evaluateJavaScript:@"port.send([0xF8]); portconnection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"open"]) {
            succeeded = YES;
        }
    }];
    
    succeeded_connection = NO;
    [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"open"]) {
            succeeded_connection = YES;
        }
    }];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    XCTAssertTrue(succeeded == YES);
    XCTAssertTrue(succeeded_connection == YES);

    [webView removeFromSuperview];
}

- (void)testMIDIOutputClear
{
    __block bool succeeded = NO;
    
    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    midiDriver.numOfOutputPorts = 1;
    midiDriver.onClearCalled = ^(ItemCount index) {
        succeeded = YES;
    };

    WKWebViewConfiguration *configuration = [MIDIWebView createConfigurationWithMIDIDriver:midiDriver
                                                                         sysexConfirmation:^(NSString *url) { return YES; }];
    MIDIWebView *webView = [[MIDIWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    
    [UIApplication.sharedApplication.delegate.window addSubview:webView];
    
    NSString *html =   @"<html><head><script type=\"text/javascript\">"
                       @"window.onload = function() {"
                       @"  window.navigator.requestMIDIAccess().then("
                       @"    function(access) {"
                       @"      var iter = access.outputs.values();"
                       @"      for (var o = iter.next(); !o.done; o = iter.next()) {"
                       @"        o.value.clear();"
                       @"      }"
                       @"    },"
                       @"    function() {}"
                       @"  );"
                       @"};"
                       @"</script></head></html>";
    
    [webView loadHTMLString:html baseURL:nil];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    [webView removeFromSuperview];

    XCTAssertTrue(succeeded == YES);
}

- (void)testMIDIInputOpen
{
    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    midiDriver.numOfInputPorts = 1;
    
    WKWebViewConfiguration *configuration = [MIDIWebView createConfigurationWithMIDIDriver:midiDriver
                                                                         sysexConfirmation:^(NSString *url) { return YES; }];
    MIDIWebView *webView = [[MIDIWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    
    [UIApplication.sharedApplication.delegate.window addSubview:webView];
    
    NSString *html = @"<html><head><script type=\"text/javascript\">"
                     @"var port;"
                     @"window.onload = function() {"
                     @"  window.navigator.requestMIDIAccess().then("
                     @"    function(access) {"
                     @"      access.onstatechange = function(event) {"
                     @"        connection = event.port.connection;"
                     @"      };"
                     @"      var iter = access.inputs.values();"
                     @"      port = iter.next().value;"
                     @"      portconnection = port.connection;"
                     @"      port.onstatechange = function(event) {"
                     @"        portconnection = event.port.connection;"
                     @"      };"
                     @"    },"
                     @"    function() {}"
                     @"  );"
                     @"};"
                     @"</script></head></html>";
    
    [webView loadHTMLString:html baseURL:nil];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    // the default status should be "closed"
    __block bool succeeded = NO;
    [webView evaluateJavaScript:@"portconnection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"closed"]) {
            succeeded = YES;
        }
    }];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    XCTAssertTrue(succeeded == YES);
    
    // after calling open(), status should be "open"
    succeeded = NO;
    [webView evaluateJavaScript:@"port.open(); portconnection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"open"]) {
            succeeded = YES;
        }
    }];

    __block bool succeeded_connection = NO;
    [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"open"]) {
            succeeded_connection = YES;
        }
    }];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    XCTAssertTrue(succeeded == YES);
    XCTAssertTrue(succeeded_connection == YES);
    
    // after calling close(), status should be "close"
    succeeded = NO;
    [webView evaluateJavaScript:@"port.close(); portconnection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"closed"]) {
            succeeded = YES;
        }
    }];

    succeeded_connection = NO;
    [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"closed"]) {
            succeeded_connection = YES;
        }
    }];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    XCTAssertTrue(succeeded == YES);
    XCTAssertTrue(succeeded_connection == YES);
    
    // after setting onmidimessage property, the port should be opened. Therefore, status should be "open".
    succeeded = NO;
    [webView evaluateJavaScript:@"port.onmidimessage = function(e){}; portconnection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"open"]) {
            succeeded = YES;
        }
    }];
    
    succeeded_connection = NO;
    [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
        if ([result isEqualToString:@"open"]) {
            succeeded_connection = YES;
        }
    }];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    XCTAssertTrue(succeeded == YES);
    XCTAssertTrue(succeeded_connection == YES);

    [webView removeFromSuperview];
}

- (BOOL)_testMIDIInputReceiveChannelMessage:(NSData *)message initParameter:(NSString *)initParam sysExAllowed:(BOOL)sysexAllowed
{
    __block bool succeeded = NO;
    
    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    midiDriver.numOfInputPorts = 1;
    
    WKWebViewConfiguration *configuration = [MIDIWebView createConfigurationWithMIDIDriver:midiDriver
                                                                         sysexConfirmation:^(NSString *url) { return sysexAllowed; }];
    MIDIWebView *webView = [[MIDIWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    
    [UIApplication.sharedApplication.delegate.window addSubview:webView];
    
    NSString *html = [NSString stringWithFormat:
                       @"<html><head><script type=\"text/javascript\">"
                       @"window.onload = function() {"
                       @"  window.navigator.requestMIDIAccess(%@).then("
                       @"    function(access) {"
                       @"      var iter = access.inputs.values();"
                       @"      o = iter.next();"
                       @"      o.value.onmidimessage = function(event) {"
                       @"        receivedData = event.data;"
                       @"      };"
                       @"    },"
                       @"    function() {}"
                       @"  );"
                       @"};"
                       @"</script></head></html>", initParam];
    
    [webView loadHTMLString:html baseURL:nil];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];

    [midiDriver simulateReceivingMessage:message toDestinationIndex:0 deltatime:0];
    
    [webView evaluateJavaScript:@"receivedData" completionHandler:^(id result, NSError *error) {
        NSArray *resultArray = result;
        if ([resultArray count] == [message length]) {
            succeeded = YES;
            
            for (int i = 0; i < [resultArray count]; i++) {
                if ([(NSNumber *)resultArray[i] unsignedCharValue] != ((uint8_t *)message.bytes)[i]) {
                    succeeded = NO;
                }
            }
        }
    }];


    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];

    [webView removeFromSuperview];
    
    return succeeded;
}

- (void)testMIDIInputReceiveChannelMessage
{
    {
        uint8_t message[] = { 0x90, 0x12, 0x34 };
        NSData *data = [NSData dataWithBytes:message length:sizeof(message)];
        XCTAssertTrue([self _testMIDIInputReceiveChannelMessage:data initParameter:@"" sysExAllowed:NO]);
    }

    {
        uint8_t message[] = { 0xF0, 0x00, 0xF7 };
        NSData *data = [NSData dataWithBytes:message length:sizeof(message)];
        XCTAssertTrue([self _testMIDIInputReceiveChannelMessage:data initParameter:@"{sysex : true}" sysExAllowed:YES]);
    }

    // receiving sysex without sysex access permission
    {
        uint8_t message[] = { 0xF0, 0x00, 0xF7 };
        NSData *data = [NSData dataWithBytes:message length:sizeof(message)];
        XCTAssertFalse([self _testMIDIInputReceiveChannelMessage:data initParameter:@"" sysExAllowed:YES]);
    }

    {
        uint8_t message[] = { 0xF0, 0x00, 0xF7 };
        NSData *data = [NSData dataWithBytes:message length:sizeof(message)];
        XCTAssertFalse([self _testMIDIInputReceiveChannelMessage:data initParameter:@"{sysex : true}" sysExAllowed:NO]);
    }
}

- (void)testMIDIPortAdded
{
    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    
    WKWebViewConfiguration *configuration = [MIDIWebView createConfigurationWithMIDIDriver:midiDriver
                                                                         sysexConfirmation:^(NSString *url) { return YES; }];
    MIDIWebView *webView = [[MIDIWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    
    [UIApplication.sharedApplication.delegate.window addSubview:webView];
    
    NSString *html = @"<html><head><script type=\"text/javascript\">"
                     @"window.onload = function() {"
                     @"  window.navigator.requestMIDIAccess().then("
                     @"    function(access) {"
                     @"      access.onstatechange = function(event) {"
                     @"        state = event.port.state;"
                     @"        connection = event.port.connection;"
                     @"        type = event.port.type;"
                     @"        numOutputPorts = access.outputs.size;"
                     @"        numInputPorts = access.inputs.size;"
                     @"      }"
                     @"    },"
                     @"    function() {}"
                     @"  );"
                     @"};"
                     @"</script></head></html>";
    
    [webView loadHTMLString:html baseURL:nil];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];

    {
        [midiDriver simulateAddingMIDIOutputPort:0];
        
        __block bool succeeded_state = NO;
        [webView evaluateJavaScript:@"state" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"connected"]) {
                succeeded_state = YES;
            }
        }];
        
        __block bool succeeded_connection = NO;
        [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"closed"]) {
                succeeded_connection = YES;
            }
        }];
        
        __block bool succeeded_type = NO;
        [webView evaluateJavaScript:@"type" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"output"]) {
                succeeded_type = YES;
            }
        }];

        __block bool succeeded_numPorts = NO;
        [webView evaluateJavaScript:@"numOutputPorts" completionHandler:^(id result, NSError *error) {
            if ([result integerValue] == 1) {
                succeeded_numPorts = YES;
            }
        }];

        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
        
        XCTAssertTrue(succeeded_state == YES);
        XCTAssertTrue(succeeded_connection == YES);
        XCTAssertTrue(succeeded_type == YES);
        XCTAssertTrue(succeeded_numPorts == YES);
    }

    {
        [midiDriver simulateAddingMIDIInputPort:0];
        
        __block bool succeeded_state = NO;
        [webView evaluateJavaScript:@"state" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"connected"]) {
                succeeded_state = YES;
            }
        }];
        
        __block bool succeeded_connection = NO;
        [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"closed"]) {
                succeeded_connection = YES;
            }
        }];
        
        __block bool succeeded_type = NO;
        [webView evaluateJavaScript:@"type" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"input"]) {
                succeeded_type = YES;
            }
        }];

        __block bool succeeded_numPorts = NO;
        [webView evaluateJavaScript:@"numInputPorts" completionHandler:^(id result, NSError *error) {
            if ([result integerValue] == 1) {
                succeeded_numPorts = YES;
            }
        }];
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
        XCTAssertTrue(succeeded_state == YES);
        XCTAssertTrue(succeeded_connection == YES);
        XCTAssertTrue(succeeded_type == YES);
        XCTAssertTrue(succeeded_numPorts == YES);
    }

    [webView removeFromSuperview];
}

- (void)testMIDIPortRemoved
{
    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    midiDriver.numOfOutputPorts = 1;
    midiDriver.numOfInputPorts = 1;
    
    WKWebViewConfiguration *configuration = [MIDIWebView createConfigurationWithMIDIDriver:midiDriver
                                                                         sysexConfirmation:^(NSString *url) { return YES; }];
    MIDIWebView *webView = [[MIDIWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    
    [UIApplication.sharedApplication.delegate.window addSubview:webView];
    
    NSString *html = @"<html><head><script type=\"text/javascript\">"
                     @"window.onload = function() {"
                     @"  window.navigator.requestMIDIAccess().then("
                     @"    function(access) {"
                     @"      access.onstatechange = function(event) {"
                     @"        state = event.port.state;"
                     @"        connection = event.port.connection;"
                     @"        type = event.port.type;"
                     @"        numOutputPorts = access.outputs.size;"
                     @"        numInputPorts = access.inputs.size;"
                     @"      }"
                     @"    },"
                     @"    function() {}"
                     @"  );"
                     @"};"
                     @"</script></head></html>";
    
    [webView loadHTMLString:html baseURL:nil];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    {
        [midiDriver simulateRemovingMIDIOutputPort:0];
        
        __block bool succeeded_state = NO;
        [webView evaluateJavaScript:@"state" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"disconnected"]) {
                succeeded_state = YES;
            }
        }];
        
        __block bool succeeded_connection = NO;
        [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"pending"]) {
                succeeded_connection = YES;
            }
        }];
        
        __block bool succeeded_type = NO;
        [webView evaluateJavaScript:@"type" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"output"]) {
                succeeded_type = YES;
            }
        }];

        __block bool succeeded_numPorts = NO;
        [webView evaluateJavaScript:@"numOutputPorts" completionHandler:^(id result, NSError *error) {
            if ([result integerValue] == 1) {
                succeeded_numPorts = YES;
            }
        }];
        

        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
        XCTAssertTrue(succeeded_state == YES);
        XCTAssertTrue(succeeded_connection == YES);
        XCTAssertTrue(succeeded_type == YES);
        XCTAssertTrue(succeeded_numPorts == YES);
    }
    
    {
        [midiDriver simulateAddingMIDIOutputPort:0];
        
        __block bool succeeded_state = NO;
        [webView evaluateJavaScript:@"state" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"connected"]) {
                succeeded_state = YES;
            }
        }];
        
        __block bool succeeded_connection = NO;
        [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"closed"]) {
                succeeded_connection = YES;
            }
        }];
        
        __block bool succeeded_type = NO;
        [webView evaluateJavaScript:@"type" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"output"]) {
                 succeeded_type = YES;
            }
        }];
        
        __block bool succeeded_numPorts = NO;
        [webView evaluateJavaScript:@"numOutputPorts" completionHandler:^(id result, NSError *error) {
            if ([result integerValue] == 1) {
                succeeded_numPorts = YES;
            }
        }];
        

        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
        
        XCTAssertTrue(succeeded_state == YES);
        XCTAssertTrue(succeeded_connection == YES);
        XCTAssertTrue(succeeded_type == YES);
        XCTAssertTrue(succeeded_numPorts == YES);
    }

    {
        [midiDriver simulateRemovingMIDIInputPort:0];
        
        __block bool succeeded_state = NO;
        [webView evaluateJavaScript:@"state" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"disconnected"]) {
                succeeded_state = YES;
            }
        }];
        
        __block bool succeeded_connection = NO;
        [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"pending"]) {
                succeeded_connection = YES;
            }
        }];
        
        __block bool succeeded_type = NO;
        [webView evaluateJavaScript:@"type" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"input"]) {
                succeeded_type = YES;
            }
        }];
        
        __block bool succeeded_numPorts = NO;
        [webView evaluateJavaScript:@"numInputPorts" completionHandler:^(id result, NSError *error) {
            if ([result integerValue] == 1) {
                succeeded_numPorts = YES;
            }
        }];
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
        
        XCTAssertTrue(succeeded_state == YES);
        XCTAssertTrue(succeeded_connection == YES);
        XCTAssertTrue(succeeded_type == YES);
        XCTAssertTrue(succeeded_numPorts == YES);
    }

    {
        [midiDriver simulateAddingMIDIInputPort:0];
        
        __block bool succeeded_state = NO;
        [webView evaluateJavaScript:@"state" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"connected"]) {
                succeeded_state = YES;
            }
        }];
        
        __block bool succeeded_connection = NO;
        [webView evaluateJavaScript:@"connection" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"closed"]) {
                succeeded_connection = YES;
            }
        }];
        
        __block bool succeeded_type = NO;
        [webView evaluateJavaScript:@"type" completionHandler:^(id result, NSError *error) {
            if ([result isEqualToString:@"input"]) {
                succeeded_type = YES;
            }
        }];
        
        __block bool succeeded_numPorts = NO;
        [webView evaluateJavaScript:@"numInputPorts" completionHandler:^(id result, NSError *error) {
            if ([result integerValue] == 1) {
                succeeded_numPorts = YES;
            }
        }];
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
        
        XCTAssertTrue(succeeded_state == YES);
        XCTAssertTrue(succeeded_connection == YES);
        XCTAssertTrue(succeeded_type == YES);
        XCTAssertTrue(succeeded_numPorts == YES);
    }

    [webView removeFromSuperview];
}


- (void)testMIDIOutputSendException
{
    MIDIDriverTest *midiDriver = [[MIDIDriverTest alloc] init];
    midiDriver.numOfOutputPorts = 1;
    
    WKWebViewConfiguration *configuration = [MIDIWebView createConfigurationWithMIDIDriver:midiDriver
                                                                         sysexConfirmation:^(NSString *url) { return YES; }];
    MIDIWebView *webView = [[MIDIWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    
    [UIApplication.sharedApplication.delegate.window addSubview:webView];
    
    NSString *html = @"<html><head><script type=\"text/javascript\">"
                     @"window.onload = function() {"
                     @"  window.navigator.requestMIDIAccess().then("
                     @"    function(access) {"
                     @"      var iter = access.outputs.values();"
                     @"      port = iter.next().value;"
                     @"    },"
                     @"    function() {}"
                     @"  );"
                     @"};"
                     @"</script></head></html>";
    
    [webView loadHTMLString:html baseURL:nil];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
    
    {
        __block bool succeeded = NO;
        [webView evaluateJavaScript:@"try { port.send([0xF0, 0xF7]) } catch (e) { _e = e } _e.code == DOMException.INVALID_ACCESS_ERR" completionHandler:^(id result, NSError *error) {
            succeeded = [result boolValue];
        }];

        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
        
        XCTAssertTrue(succeeded == YES);
    }

    {
        [midiDriver simulateRemovingMIDIOutputPort:0];
        
        __block bool succeeded = NO;
        [webView evaluateJavaScript:@"try { port.send([0xF8]) } catch (e) { _e = e } _e.code == DOMException.INVALID_STATE_ERR" completionHandler:^(id result, NSError *error) {
            succeeded = [result boolValue];
        }];
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
        
        XCTAssertTrue(succeeded == YES);
    }
    
    {
        [midiDriver simulateRemovingMIDIOutputPort:0];
        
        __block bool succeeded = NO;
        [webView evaluateJavaScript:@"try { port.send() } catch (e) { _e = e } _e.name" completionHandler:^(id result, NSError *error) {
            succeeded = [result isEqualToString:@"TypeError"];
        }];
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kEvaluateTimeout_sec]];
        
        XCTAssertTrue(succeeded == YES);
    }

    [webView removeFromSuperview];
}
@end
