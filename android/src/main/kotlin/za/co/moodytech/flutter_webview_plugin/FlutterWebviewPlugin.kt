package za.co.moodytech.flutter_webview_plugin

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Point
import android.os.Build
import android.view.Display
import android.webkit.CookieManager
import android.webkit.ValueCallback
import android.webkit.WebStorage
import android.widget.FrameLayout
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** FlutterWebviewPlugin */
class FlutterWebviewPlugin: FlutterPlugin, ActivityAware, MethodCallHandler, PluginRegistry.ActivityResultListener {
    private var activity: Activity? = null
    private var webViewManager: WebviewManager? = null
    private var context: Context? = null
    private val CHANNEL_NAME = "flutter_webview_plugin"
    private val JS_CHANNEL_NAMES_FIELD = "javascriptChannelNames"
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    lateinit var channel: MethodChannel

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        context = flutterPluginBinding.applicationContext
        channel.setMethodCallHandler(this)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
        webViewManager = WebviewManager(activity!!, context!!, channel, listOf())
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        context = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        context = activity?.applicationContext
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
        context = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "launch" -> openUrl(call, result)
            "close" -> close(call, result)
            "eval" -> eval(call, result)
            "resize" -> resize(call, result)
            "reload" -> reload(call, result)
            "back" -> back(call, result)
            "forward" -> forward(call, result)
            "hide" -> hide(call, result)
            "show" -> show(call, result)
            "reloadUrl" -> reloadUrl(call, result)
            "stopLoading" -> stopLoading(call, result)
            "cleanCookies" -> cleanCookies(call, result)
            "canGoBack" -> canGoBack(result)
            "canGoForward" -> canGoForward(result)
            "cleanCache" -> cleanCache(result)
            else -> result.notImplemented()
        }
    }

    private fun cleanCache(result: Result) {
        webViewManager?.cleanCache()
        WebStorage.getInstance().deleteAllData()
        result.success(null)
    }

    private fun openUrl(call: MethodCall, result: Result) {
        val hidden = call.argument<Boolean>("hidden") ?: false
        val url = call.argument<String>("url") ?: ""
        val userAgent = call.argument<String>("userAgent")
        val withJavascript = call.argument<Boolean>("withJavascript") ?: true
        val clearCache = call.argument<Boolean>("clearCache") ?: false
        val clearCookies = call.argument<Boolean>("clearCookies") ?: false
        val mediaPlaybackRequiresUserGesture = call.argument<Boolean>("mediaPlaybackRequiresUserGesture") ?: true
        val withZoom = call.argument<Boolean>("withZoom") ?: false
        val displayZoomControls = call.argument<Boolean>("displayZoomControls") ?: false
        val withLocalStorage = call.argument<Boolean>("withLocalStorage") ?: true
        val withOverviewMode = call.argument<Boolean>("withOverviewMode") ?: false
        val supportMultipleWindows = call.argument<Boolean>("supportMultipleWindows") ?: false
        val appCacheEnabled = call.argument<Boolean>("appCacheEnabled") ?: false
        val headers = call.argument<Map<String, String>>("headers")
        val scrollBar = call.argument<Boolean>("scrollBar") ?: true
        val allowFileURLs = call.argument<Boolean>("allowFileURLs") ?: false
        val useWideViewPort = call.argument<Boolean>("useWideViewPort") ?: false
        val invalidUrlRegex = call.argument<String>("invalidUrlRegex")
        val geolocationEnabled = call.argument<Boolean>("geolocationEnabled") ?: false
        val debuggingEnabled = call.argument<Boolean>("debuggingEnabled") ?: false
        val ignoreSSLErrors = call.argument<Boolean>("ignoreSSLErrors") ?: false

        if (webViewManager == null || webViewManager?.closed == true) {
            val arguments = call.arguments as? Map<String, Any>
            val channelNames = arguments?.get(JS_CHANNEL_NAMES_FIELD) as? List<String> ?: listOf()
            webViewManager = WebviewManager(activity!!, context!!, channel, channelNames)
        }

        val params = buildLayoutParams(call)

        activity?.addContentView(webViewManager?.webView, params)

        webViewManager?.openUrl(
            withJavascript, clearCache, hidden, clearCookies, mediaPlaybackRequiresUserGesture,
            userAgent, url, headers, withZoom, displayZoomControls, withLocalStorage,
            withOverviewMode, scrollBar, supportMultipleWindows, appCacheEnabled,
            allowFileURLs, useWideViewPort, invalidUrlRegex, geolocationEnabled,
            debuggingEnabled, ignoreSSLErrors
        )
        result.success(null)
    }

    private fun buildLayoutParams(call: MethodCall): FrameLayout.LayoutParams {
        val rc = call.argument<Map<String, Number>>("rect")
        return if (rc != null) {
            FrameLayout.LayoutParams(
                dp2px(activity, rc["width"]?.toInt() ?: 0),
                dp2px(activity, rc["height"]?.toInt() ?: 0)
            ).apply {
                setMargins(
                    dp2px(activity, rc["left"]?.toInt() ?: 0),
                    dp2px(activity, rc["top"]?.toInt() ?: 0),
                    0,
                    0
                )
            }
        } else {
            val display = activity?.windowManager?.defaultDisplay
            val size = Point()
            display?.getSize(size)
            FrameLayout.LayoutParams(size.x, size.y)
        }
    }

    private fun stopLoading(call: MethodCall, result: Result) {
        webViewManager?.stopLoading(call, result)
        result.success(null)
    }

    private fun close(call: MethodCall, result: Result) {
        webViewManager?.close(call, result)
        webViewManager = null
    }

    private fun canGoBack(result: Result) {
        if (webViewManager != null) {
            result.success(webViewManager?.canGoBack())
        } else {
            result.error("Webview is null", null, null)
        }
    }

    private fun back(call: MethodCall, result: Result) {
        webViewManager?.back(call, result)
        result.success(null)
    }

    private fun canGoForward(result: Result) {
        if (webViewManager != null) {
            result.success(webViewManager?.canGoForward())
        } else {
            result.error("Webview is null", null, null)
        }
    }

    private fun forward(call: MethodCall, result: Result) {
        webViewManager?.forward(call, result)
        result.success(null)
    }

    private fun reload(call: MethodCall, result: Result) {
        webViewManager?.reload(call, result)
        result.success(null)
    }

    private fun reloadUrl(call: MethodCall, result: Result) {
        val url = call.argument<String>("url") ?: ""
        val headers = call.argument<Map<String, String>>("headers")
        if (headers != null) {
            webViewManager?.reloadUrl(url, headers)
        } else {
            webViewManager?.reloadUrl(url)
        }
        result.success(null)
    }

    private fun eval(call: MethodCall, result: Result) {
        webViewManager?.eval(call, result)
    }

    private fun resize(call: MethodCall, result: Result) {
        val params = buildLayoutParams(call)
        webViewManager?.resize(params)
        result.success(null)
    }

    private fun hide(call: MethodCall, result: Result) {
        webViewManager?.hide(call, result)
        result.success(null)
    }

    private fun show(call: MethodCall, result: Result) {
        webViewManager?.show(call, result)
        result.success(null)
    }

    private fun cleanCookies(call: MethodCall, result: Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            CookieManager.getInstance().removeAllCookies { }
        } else {
            CookieManager.getInstance().removeAllCookie()
        }
        result.success(null)
    }

    private fun dp2px(context: Context?, dp: Int): Int {
        return if (context != null) {
            val scale = context.resources.displayMetrics.density
            (dp * scale + 0.5f).toInt()
        } else {
            dp
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return webViewManager?.resultHandler?.handleResult(requestCode, resultCode, data) ?: false
    }
}
