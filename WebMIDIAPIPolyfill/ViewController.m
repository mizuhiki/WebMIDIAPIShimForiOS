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

#import "ViewController.h"
#import "WebViewDelegate.h"
#import "MIDIDriver.h"

@interface ViewController () {
    WebViewDelegate *_delegate;
}
@end

@implementation ViewController

- (void)onEditingDidEnd:(UITextField *)field
{
    UIWebView *webview = [[UIWebView alloc] initWithFrame:_webview.frame];
    webview.autoresizingMask = _webview.autoresizingMask;
    
    [self.view insertSubview:webview aboveSubview:_webview];
    [_webview removeFromSuperview];

    _webview = webview;
    _webview.delegate = _delegate;

    NSString *polyfill_path = [[NSBundle mainBundle] pathForResource:@"WebMIDIAPIPolyfill" ofType:@"js"];
    NSString *polyfill_script = [NSString stringWithContentsOfFile:polyfill_path encoding:NSUTF8StringEncoding error:nil];
    [_webview stringByEvaluatingJavaScriptFromString:polyfill_script];

    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:field.text]];
    [_webview loadRequest:request];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 30)];
    [textField setBorderStyle:UITextBorderStyleRoundedRect];
    [textField setPlaceholder:@"Enter URL"];
    [textField addTarget:self action:@selector(onEditingDidEnd:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [textField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [textField setKeyboardType:UIKeyboardTypeURL];
    [textField setReturnKeyType:UIReturnKeyGo];
    [textField setClearButtonMode:UITextFieldViewModeWhileEditing];
    self.navigationItem.titleView = textField;

    _delegate = [[WebViewDelegate alloc] init];
    _webview.delegate = _delegate;

    MIDIDriver *midiDriver = [[MIDIDriver alloc] init];
    _delegate.midiDriver = midiDriver;

    NSString *path = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]];

    NSString *polyfill_path = [[NSBundle mainBundle] pathForResource:@"WebMIDIAPIPolyfill" ofType:@"js"];
    NSString *polyfill_script = [NSString stringWithContentsOfFile:polyfill_path encoding:NSUTF8StringEncoding error:nil];
    [_webview stringByEvaluatingJavaScriptFromString:polyfill_script];
    
    [_webview loadRequest:request];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
