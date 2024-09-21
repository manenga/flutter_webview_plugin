package za.co.moodytech.flutter_webview_plugin

import android.content.Context
import android.util.AttributeSet
import android.webkit.WebView

class ObservableWebView : WebView {
    private var onScrollChangedCallback: OnScrollChangedCallback? = null

    constructor(context: Context) : super(context)

    constructor(context: Context, attrs: AttributeSet) : super(context, attrs)

    constructor(context: Context, attrs: AttributeSet, defStyle: Int) : super(context, attrs, defStyle)

    override fun onScrollChanged(l: Int, t: Int, oldl: Int, oldt: Int) {
        super.onScrollChanged(l, t, oldl, oldt)
        onScrollChangedCallback?.onScroll(l, t, oldl, oldt)
    }

    fun setOnScrollChangedCallback(onScrollChangedCallback: OnScrollChangedCallback?) {
        this.onScrollChangedCallback = onScrollChangedCallback
    }

    /**
     * Implement in the activity/fragment/view that you want to listen to the webview
     */
    interface OnScrollChangedCallback {
        fun onScroll(l: Int, t: Int, oldl: Int, oldt: Int)
    }
}
