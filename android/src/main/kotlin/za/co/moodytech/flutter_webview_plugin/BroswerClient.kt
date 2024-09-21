package za.co.moodytech.flutter_webview_plugin

import android.graphics.Bitmap
import android.os.Build
import android.annotation.TargetApi
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodChannel
import java.util.regex.Pattern
import android.view.ViewGroup

open class BrowserClient(private val channel: MethodChannel) : WebViewClient() {
    private var invalidUrlPattern: Pattern? = null

    fun updateInvalidUrlRegex(invalidUrlRegex: String?) {
        invalidUrlPattern = invalidUrlRegex?.let { Pattern.compile(it) }
    }

    override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
        super.onPageStarted(view, url, favicon)
        val data = mapOf(
            "url" to url,
            "type" to "startLoad"
        )
        channel.invokeMethod("onState", data)
    }

    override fun onPageFinished(view: WebView?, url: String?) {
        super.onPageFinished(view, url)
        val urlChangedData = mapOf("url" to url)
        channel.invokeMethod("onUrlChanged", urlChangedData)

        val stateData = mapOf(
            "url" to url,
            "type" to "finishLoad"
        )
        channel.invokeMethod("onState", stateData)
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
        val url = request?.url?.toString()
        return handleUrlLoading(url)
    }

    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
        return handleUrlLoading(url)
    }

    private fun handleUrlLoading(url: String?): Boolean {
        val isInvalid = checkInvalidUrl(url)
        val data = mapOf(
            "url" to url,
            "type" to if (isInvalid) "abortLoad" else "shouldStart"
        )
        channel.invokeMethod("onState", data)
        return isInvalid
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    override fun onReceivedHttpError(view: WebView?, request: WebResourceRequest?, errorResponse: WebResourceResponse?) {
        super.onReceivedHttpError(view, request, errorResponse)
        val data = mapOf(
            "url" to request?.url?.toString(),
            "code" to errorResponse?.statusCode?.toString()
        )
        channel.invokeMethod("onHttpError", data)
    }

    override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
        super.onReceivedError(view, errorCode, description, failingUrl)
        val data = mapOf(
            "url" to failingUrl,
            "code" to errorCode.toString()
        )
        channel.invokeMethod("onHttpError", data)
    }

    private fun checkInvalidUrl(url: String?): Boolean {
        return invalidUrlPattern?.matcher(url ?: "")?.lookingAt() ?: false
    }
}
