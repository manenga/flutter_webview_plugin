package za.co.moodytech.flutter_webview_plugin

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.http.SslError
import android.os.Build
import android.os.Handler
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.view.KeyEvent
import android.view.View
import android.webkit.*
import android.widget.FrameLayout
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import android.view.ViewGroup
import android.annotation.TargetApi

class WebviewManager(
    private val activity: Activity,
    private val context: Context,
    private val channel: MethodChannel,
    channelNames: List<String>
) {
    private var mUploadMessage: ValueCallback<Uri>? = null
    private var mUploadMessageArray: ValueCallback<Array<Uri>>? = null
    private val FILECHOOSER_RESULTCODE = 1
    private var fileUri: Uri? = null
    private var videoUri: Uri? = null

    private val platformThreadHandler: Handler = Handler(context.mainLooper)
    var closed = false
    var webView: WebView = ObservableWebView(activity)
    private val webViewClient: BrowserClient
    val resultHandler = ResultHandler()
    private var ignoreSSLErrors = false

    init {
        webViewClient = object : BrowserClient(channel) {
            override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
                if (ignoreSSLErrors) {
                    handler?.proceed()
                } else {
                    super.onReceivedSslError(view, handler, error)
                }
            }
        }

        webView.setOnKeyListener { _, keyCode, event ->
            if (event.action == KeyEvent.ACTION_DOWN) {
                when (keyCode) {
                    KeyEvent.KEYCODE_BACK -> {
                        if (webView.canGoBack()) {
                            webView.goBack()
                        } else {
                            channel.invokeMethod("onBack", null)
                        }
                        return@setOnKeyListener true
                    }
                }
            }
            false
        }

        (webView as ObservableWebView).setOnScrollChangedCallback(object : ObservableWebView.OnScrollChangedCallback {
            override fun onScroll(x: Int, y: Int, oldx: Int, oldy: Int) {
                channel.invokeMethod("onScrollYChanged", mapOf("yDirection" to y.toDouble()))
                channel.invokeMethod("onScrollXChanged", mapOf("xDirection" to x.toDouble()))
            }
        })

        webView.webViewClient = webViewClient
        webView.webChromeClient = createWebChromeClient()

        registerJavaScriptChannelNames(channelNames)
    }

    private fun createWebChromeClient(): WebChromeClient {
        return object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, progress: Int) {
                channel.invokeMethod("onProgressChanged", mapOf("progress" to progress / 100.0))
            }

            override fun onGeolocationPermissionsShowPrompt(
                origin: String?,
                callback: GeolocationPermissions.Callback?
            ) {
                callback?.invoke(origin, true, false)
            }

            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?
            ): Boolean {
                mUploadMessageArray = filePathCallback

                val acceptTypes = getSafeAcceptedTypes(fileChooserParams)
                val intentList = mutableListOf<Intent>()
                fileUri = null
                videoUri = null

                if (acceptsImages(acceptTypes)) {
                    val takePhotoIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                    fileUri = getOutputFilename(MediaStore.ACTION_IMAGE_CAPTURE)
                    takePhotoIntent.putExtra(MediaStore.EXTRA_OUTPUT, fileUri)
                    intentList.add(takePhotoIntent)
                }

                if (acceptsVideo(acceptTypes)) {
                    val takeVideoIntent = Intent(MediaStore.ACTION_VIDEO_CAPTURE)
                    videoUri = getOutputFilename(MediaStore.ACTION_VIDEO_CAPTURE)
                    takeVideoIntent.putExtra(MediaStore.EXTRA_OUTPUT, videoUri)
                    intentList.add(takeVideoIntent)
                }

                val contentSelectionIntent = Intent(Intent.ACTION_GET_CONTENT)
                contentSelectionIntent.addCategory(Intent.CATEGORY_OPENABLE)
                contentSelectionIntent.type = "*/*"

                val chooserIntent = Intent(Intent.ACTION_CHOOSER)
                chooserIntent.putExtra(Intent.EXTRA_INTENT, contentSelectionIntent)
                chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, intentList.toTypedArray())

                activity.startActivityForResult(chooserIntent, FILECHOOSER_RESULTCODE)
                return true
            }
        }
    }

    fun openUrl(
        withJavascript: Boolean,
        clearCache: Boolean,
        hidden: Boolean,
        clearCookies: Boolean,
        mediaPlaybackRequiresUserGesture: Boolean,
        userAgent: String?,
        url: String,
        headers: Map<String, String>?,
        withZoom: Boolean,
        displayZoomControls: Boolean,
        withLocalStorage: Boolean,
        withOverviewMode: Boolean,
        scrollBar: Boolean,
        supportMultipleWindows: Boolean,
        appCacheEnabled: Boolean,
        allowFileURLs: Boolean,
        useWideViewPort: Boolean,
        invalidUrlRegex: String?,
        geolocationEnabled: Boolean,
        debuggingEnabled: Boolean,
        ignoreSSLErrors: Boolean
    ) {
        webView.settings.javaScriptEnabled = withJavascript
        webView.settings.builtInZoomControls = withZoom
        webView.settings.displayZoomControls = displayZoomControls
        webView.settings.domStorageEnabled = withLocalStorage
        webView.settings.loadWithOverviewMode = withOverviewMode
        webView.settings.javaScriptCanOpenWindowsAutomatically = supportMultipleWindows
        webView.settings.setSupportMultipleWindows(supportMultipleWindows)
        webView.settings.allowFileAccessFromFileURLs = allowFileURLs
        webView.settings.allowUniversalAccessFromFileURLs = allowFileURLs
        webView.settings.useWideViewPort = useWideViewPort

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            webView.settings.mediaPlaybackRequiresUserGesture = mediaPlaybackRequiresUserGesture
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(debuggingEnabled)
        }

        this.ignoreSSLErrors = ignoreSSLErrors

        webViewClient.updateInvalidUrlRegex(invalidUrlRegex)

        if (geolocationEnabled) {
            webView.settings.setGeolocationEnabled(true)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            webView.settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
        }

        if (clearCache) {
            clearCache()
        }

        if (hidden) {
            webView.visibility = View.GONE
        }

        if (clearCookies) {
            clearCookies()
        }

        if (userAgent != null) {
            webView.settings.userAgentString = userAgent
        }

        if (!scrollBar) {
            webView.isVerticalScrollBarEnabled = false
        }

        if (headers != null) {
            webView.loadUrl(url, headers)
        } else {
            webView.loadUrl(url)
        }
    }

    private fun clearCache() {
        webView.clearCache(true)
        webView.clearFormData()
    }

    private fun clearCookies() {
        CookieManager.getInstance().removeAllCookies(null)
    }

    private fun registerJavaScriptChannelNames(channelNames: List<String>) {
        for (channelName in channelNames) {
            webView.addJavascriptInterface(
                JavaScriptChannel(channel, channelName, platformThreadHandler),
                channelName
            )
        }
    }

    fun close(call: MethodCall?, result: MethodChannel.Result?) {
        if (webView != null) {
            val vg = webView.parent as? ViewGroup
            vg?.removeView(webView)
        }
        webView = ObservableWebView(activity)
        result?.success(null)
        closed = true
        channel.invokeMethod("onDestroy", null)
    }

    fun close() {
        close(null, null)
    }

    @TargetApi(Build.VERSION_CODES.KITKAT)
    fun eval(call: MethodCall, result: MethodChannel.Result) {
        val code = call.argument<String>("code")
        webView.evaluateJavascript(code ?: "") { value -> result.success(value) }
    }

    fun reload(call: MethodCall, result: MethodChannel.Result) {
        webView.reload()
    }

    fun back(call: MethodCall, result: MethodChannel.Result) {
        if (webView.canGoBack()) {
            webView.goBack()
        }
    }

    fun forward(call: MethodCall, result: MethodChannel.Result) {
        if (webView.canGoForward()) {
            webView.goForward()
        }
    }

    fun resize(params: FrameLayout.LayoutParams) {
        webView.layoutParams = params
    }

    fun hide(call: MethodCall, result: MethodChannel.Result) {
        webView.visibility = View.GONE
    }

    fun show(call: MethodCall, result: MethodChannel.Result) {
        webView.visibility = View.VISIBLE
    }

    fun stopLoading(call: MethodCall, result: MethodChannel.Result) {
        webView.stopLoading()
    }

    fun reloadUrl(url: String) {
        webView.loadUrl(url)
    }

    fun reloadUrl(url: String, headers: Map<String, String>) {
        webView.loadUrl(url, headers)
    }

    fun canGoBack() = webView.canGoBack()

    fun canGoForward() = webView.canGoForward()

    fun cleanCache() {
        webView.clearCache(true)
    }

    private fun getOutputFilename(intentType: String): Uri {
        val prefix = when (intentType) {
            MediaStore.ACTION_IMAGE_CAPTURE -> "image-"
            MediaStore.ACTION_VIDEO_CAPTURE -> "video-"
            else -> ""
        }
        val suffix = when (intentType) {
            MediaStore.ACTION_IMAGE_CAPTURE -> ".jpg"
            MediaStore.ACTION_VIDEO_CAPTURE -> ".mp4"
            else -> ""
        }

        val packageName = context.packageName
        val capturedFile = createCapturedFile(prefix, suffix)
        return FileProvider.getUriForFile(context, "$packageName.fileprovider", capturedFile)
    }

    private fun createCapturedFile(prefix: String, suffix: String): File {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFileName = "${prefix}_$timeStamp"
        val storageDir = context.getExternalFilesDir(null)
        return File.createTempFile(imageFileName, suffix, storageDir)
    }

    private fun acceptsImages(types: Array<String>?) = types.isNullOrEmpty() || types.any { it.contains("image") }

    private fun acceptsVideo(types: Array<String>?) = types.isNullOrEmpty() || types.any { it.contains("video") }

    private fun getSafeAcceptedTypes(params: WebChromeClient.FileChooserParams?): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            params?.acceptTypes ?: emptyArray()
        } else {
            emptyArray()
        }
    }

    inner class ResultHandler {
        fun handleResult(requestCode: Int, resultCode: Int, intent: Intent?): Boolean {
            var handled = false
            if (Build.VERSION.SDK_INT >= 21) {
                if (requestCode == FILECHOOSER_RESULTCODE) {
                    val results: Array<Uri>? = when {
                        resultCode == Activity.RESULT_OK -> when {
                            fileUri != null && getFileSize(fileUri!!) > 0 -> arrayOf(fileUri!!)
                            videoUri != null && getFileSize(videoUri!!) > 0 -> arrayOf(videoUri!!)
                            intent != null -> getSelectedFiles(intent)
                            else -> null
                        }
                        else -> null
                    }
                    mUploadMessageArray?.onReceiveValue(results)
                    mUploadMessageArray = null
                    handled = true
                }
            } else {
                if (requestCode == FILECHOOSER_RESULTCODE) {
                    val result = if (resultCode == Activity.RESULT_OK && intent != null) intent.data else null
                    mUploadMessage?.onReceiveValue(result)
                    mUploadMessage = null
                    handled = true
                }
            }
            return handled
        }
    }

    private fun getFileSize(uri: Uri): Long {
        val cursor = context.contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            it.moveToFirst()
            val sizeIndex = it.getColumnIndex(OpenableColumns.SIZE)
            return it.getLong(sizeIndex)
        }
        return 0
    }

    private fun getSelectedFiles(data: Intent): Array<Uri>? {
        return when {
            data.data != null -> arrayOf(Uri.parse(data.dataString))
            data.clipData != null -> {
                val numSelectedFiles = data.clipData!!.itemCount
                Array(numSelectedFiles) { i -> data.clipData!!.getItemAt(i).uri }
            }
            else -> null
        }
    }
}
