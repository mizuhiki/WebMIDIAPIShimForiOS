WebMIDIAPIShimForiOS
====================
This is a shim to enable [Web MIDI API](https://dvcs.w3.org/hg/audio/raw-file/tip/midi/specification.html) on iOS. WebMIDIAPIPolyfill.js is the bridge script to invoke iOS native Core MIDI APIs. And WebViewDelegate.m is the receptor for informal URL schemes triggered by the bridge script. You can build a hybrid Web MIDI application for iOS with using them.

The idea was brought from [WebMIDIAPIShim](https://github.com/cwilso/WebMIDIAPIShim) by Chris Wilson. WebMIDIAPIPolyfill.js in this project was derived from his great work.

A simple web browser is included in the project. It uses JavaScript injection hack by using `-(NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script` in UIWebView. You can try Web MIDI applications using the browser as if it were a native API support browser.

License
--------------------
Apache License 2.0
