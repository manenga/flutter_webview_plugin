import Flutter
import WebKit

public class FLTCommunityJavaScriptChannel: NSObject, WKScriptMessageHandler {
    private let methodChannel: FlutterMethodChannel
    private let javaScriptChannelName: String

    init(methodChannel: FlutterMethodChannel, javaScriptChannelName: String) {
        assert(methodChannel != nil, "methodChannel must not be nil.")
        assert(javaScriptChannelName != nil, "javaScriptChannelName must not be nil.")

        self.methodChannel = methodChannel
        self.javaScriptChannelName = javaScriptChannelName
        super.init()
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        assert(methodChannel != nil, "Can't send a message to an uninitialized JavaScript channel.")
        assert(javaScriptChannelName != nil, "Can't send a message to an uninitialized JavaScript channel.")

        let arguments: [String: Any] = [
            "channel": javaScriptChannelName,
            "message": String(describing: message.body)
        ]

        methodChannel.invokeMethod("javascriptChannelMessage", arguments: arguments)
    }
}
