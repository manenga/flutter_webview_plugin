package za.co.moodytech.flutter_webview_plugin

import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import io.flutter.plugin.common.MethodChannel

/**
 * Added as a JavaScript interface to the WebView for any JavaScript channel that the Dart code sets
 * up.
 *
 * Exposes a single method named `postMessage` to JavaScript, which sends a message over a method
 * channel to the Dart code.
 */
class JavaScriptChannel(
    private val methodChannel: MethodChannel,
    private val javaScriptChannelName: String,
    private val platformThreadHandler: Handler
) {

    /**
     * @param methodChannel the Flutter WebView method channel to which JS messages are sent
     * @param javaScriptChannelName the name of the JavaScript channel, this is sent over the method
     *     channel with each message to let the Dart code know which JavaScript channel the message
     *     was sent through
     */

    @JavascriptInterface
    fun postMessage(message: String) {
        val postMessageRunnable = Runnable {
            val arguments = mapOf(
                "channel" to javaScriptChannelName,
                "message" to message
            )
            methodChannel.invokeMethod("javascriptChannelMessage", arguments)
        }

        if (platformThreadHandler.looper == Looper.myLooper()) {
            postMessageRunnable.run()
        } else {
            platformThreadHandler.post(postMessageRunnable)
        }
    }
}
