import Flutter
import WebKit
import UIKit

public class FlutterWebviewPlugin: NSObject, FlutterPlugin, WKNavigationDelegate, UIScrollViewDelegate, WKUIDelegate {
    private static let CHANNEL_NAME = "flutter_webview_plugin"

    private var webview: WKWebView?
    private var viewController: UIViewController!
    private var channel: FlutterMethodChannel!

    private var enableAppScheme = false
    private var enableZoom = false
    private var invalidUrlRegex: String?
    private var javaScriptChannelNames = Set<String>()
    private var ignoreSSLErrors: Bool = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: registrar.messenger())

        guard let viewController = UIApplication.shared.delegate?.window??.rootViewController else {
            fatalError("Unable to get root view controller")
        }

        let instance = FlutterWebviewPlugin(viewController: viewController, channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    init(viewController: UIViewController, channel: FlutterMethodChannel) {
        super.init()
        self.channel = channel
        self.viewController = viewController
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "launch":
            if webview == nil {
                initWebview(call, result: result)
            } else {
                navigate(call)
            }
            result(nil)
        case "close":
            closeWebView()
            result(nil)
        case "eval":
            evalJavascript(call) { response in
                result(response)
            }
        case "resize":
            resize(call)
            result(nil)
        case "reloadUrl":
            reloadUrl(call)
            result(nil)
        case "show":
            show()
            result(nil)
        case "hide":
            hide()
            result(nil)
        case "stopLoading":
            stopLoading()
            result(nil)
        case "cleanCookies":
            cleanCookies(result)
        case "back":
            back()
            result(nil)
        case "forward":
            forward()
            result(nil)
        case "reload":
            reload()
            result(nil)
        case "canGoBack":
            onCanGoBack(call, result: result)
        case "canGoForward":
            onCanGoForward(call, result: result)
        case "cleanCache":
            cleanCache(result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initWebview(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else { return }

        let clearCache = args["clearCache"] as? Bool ?? false
        let clearCookies = args["clearCookies"] as? Bool ?? false
        let hidden = args["hidden"] as? Bool ?? false
        let rect = args["rect"] as? [String: Any]
        enableAppScheme = args["enableAppScheme"] as? Bool ?? false
        let userAgent = args["userAgent"] as? String
        let withZoom = args["withZoom"] as? Bool ?? false
        let scrollBar = args["scrollBar"] as? Bool ?? false
        let withJavascript = args["withJavascript"] as? Bool ?? false
        invalidUrlRegex = args["invalidUrlRegex"] as? String
        ignoreSSLErrors = args["ignoreSSLErrors"] as? Bool ?? false

        let userContentController = WKUserContentController()
        if let channelNames = args["javascriptChannelNames"] as? [String] {
            javaScriptChannelNames = Set(channelNames)
            registerJavaScriptChannels(javaScriptChannelNames, controller: userContentController)
        }

        if clearCache {
            URLCache.shared.removeAllCachedResponses()
            cleanCache(result)
        }

        if clearCookies {
            HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
            cleanCookies(result)
        }

        if let userAgent = userAgent {
            UserDefaults.standard.register(defaults: ["UserAgent": userAgent])
        }

        let frame: CGRect
        if let rect = rect {
            frame = parseRect(rect)
        } else {
            frame = viewController.view.bounds
        }

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true

        webview = WKWebView(frame: frame, configuration: configuration)
        webview?.uiDelegate = self
        webview?.navigationDelegate = self
        webview?.scrollView.delegate = self
        webview?.isHidden = hidden
        webview?.scrollView.showsHorizontalScrollIndicator = scrollBar
        webview?.scrollView.showsVerticalScrollIndicator = scrollBar

        webview?.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        if withJavascript {
            webview?.configuration.preferences.javaScriptEnabled = true
        } else {
            webview?.configuration.preferences.javaScriptEnabled = false
        }

        enableZoom = withZoom

        if let presentedViewController = viewController.presentedViewController {
            presentedViewController.view.addSubview(webview!)
        } else {
            viewController.view.addSubview(webview!)
        }

        navigate(call)
    }

    private func navigate(_ call: FlutterMethodCall) {
        guard let webview = webview, let args = call.arguments as? [String: Any] else { return }

        if let urlString = args["url"] as? String {
            if let withLocalUrl = args["withLocalUrl"] as? Bool, withLocalUrl {
                if #available(iOS 9.0, *) {
                    let url = URL(fileURLWithPath: urlString)
                    if let localUrlScope = args["localUrlScope"] as? String {
                        let scopeUrl = URL(fileURLWithPath: localUrlScope)
                        webview.loadFileURL(url, allowingReadAccessTo: scopeUrl)
                    } else {
                        webview.loadFileURL(url, allowingReadAccessTo: url)
                    }
                } else {
                    print("Loading local files is not supported on iOS versions earlier than 9.0")
                }
            } else {
                if let url = URL(string: urlString) {
                    var request = URLRequest(url: url)
                    if let headers = args["headers"] as? [String: String] {
                        for (key, value) in headers {
                            request.setValue(value, forHTTPHeaderField: key)
                        }
                    }
                    webview.load(request)
                }
            }
        }
    }

    private func evalJavascript(_ call: FlutterMethodCall, completionHandler: @escaping (String?) -> Void) {
        guard let webview = webview, let args = call.arguments as? [String: Any], let code = args["code"] as? String else {
            completionHandler(nil)
            return
        }

        webview.evaluateJavaScript(code) { (result, error) in
            completionHandler(String(describing: result))
        }
    }

    private func resize(_ call: FlutterMethodCall) {
        guard let webview = webview, let args = call.arguments as? [String: Any], let rect = args["rect"] as? [String: Any] else { return }
        let frame = parseRect(rect)
        webview.frame = frame
    }

    private func closeWebView() {
        if let webview = webview {
            webview.stopLoading()
            webview.removeFromSuperview()
            webview.navigationDelegate = nil
            webview.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
            self.webview = nil
            channel.invokeMethod("onDestroy", arguments: nil)
        }
    }

    private func reloadUrl(_ call: FlutterMethodCall) {
        guard let webview = webview, let args = call.arguments as? [String: Any], let urlString = args["url"] as? String else { return }

        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            if let headers = args["headers"] as? [String: String] {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            webview.load(request)
        }
    }

    private func cleanCookies(_ result: @escaping FlutterResult) {
        guard webview != nil else { return }

        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

        if #available(iOS 9.0, *) {
            let dataTypes = Set([WKWebsiteDataTypeCookies])
            WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: Date.distantPast) {
                result(nil)
            }
        } else {
            print("Clearing cookies is not supported for Flutter WebViews prior to iOS 9.")
            result(nil)
        }
    }

    private func cleanCache(_ result: @escaping FlutterResult) {
        guard webview != nil else { return }

        if #available(iOS 9.0, *) {
            let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
            WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: Date.distantPast) {
                result(nil)
            }
        } else {
            print("Clearing cache is not supported for Flutter WebViews prior to iOS 9.")
            result(nil)
        }
    }

    private func show() {
        webview?.isHidden = false
    }

    private func hide() {
        webview?.isHidden = true
    }

    private func stopLoading() {
        webview?.stopLoading()
    }

    private func back() {
        webview?.goBack()
    }

    private func forward() {
        webview?.goForward()
    }

    private func reload() {
        webview?.reload()
    }

    private func onCanGoBack(_ call: FlutterMethodCall, result: FlutterResult) {
        result(webview?.canGoBack ?? false)
    }

    private func onCanGoForward(_ call: FlutterMethodCall, result: FlutterResult) {
        result(webview?.canGoForward ?? false)
    }

    private func parseRect(_ rect: [String: Any]) -> CGRect {
        let x = rect["left"] as? CGFloat ?? 0
        let y = rect["top"] as? CGFloat ?? 0
        let width = rect["width"] as? CGFloat ?? 0
        let height = rect["height"] as? CGFloat ?? 0
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func registerJavaScriptChannels(_ channelNames: Set<String>, controller: WKUserContentController) {
        for channelName in channelNames {
            let channel = FLTCommunityJavaScriptChannel(methodChannel: self.channel, javaScriptChannelName: channelName)
            controller.add(channel, name: channelName)

            let wrapperSource = "window.\(channelName) = webkit.messageHandlers.\(channelName);"
            let wrapperScript = WKUserScript(source: wrapperSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            controller.addUserScript(wrapperScript)
        }
    }

    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            if let webview = object as? WKWebView {
                let progress = webview.estimatedProgress
                channel.invokeMethod("onProgressChanged", arguments: ["progress": progress])
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let isInvalid = checkInvalidUrl(navigationAction.request.url)

        var data: [String: Any] = [
            "url": navigationAction.request.url?.absoluteString ?? "",
            "type": isInvalid ? "abortLoad" : "shouldStart",
            "navigationType": navigationAction.navigationType.rawValue
        ]

        channel.invokeMethod("onState", arguments: data)

        if navigationAction.navigationType == .backForward {
            channel.invokeMethod("onBackPressed", arguments: nil)
        } else if !isInvalid {
            data = ["url": navigationAction.request.url?.absoluteString ?? ""]
            channel.invokeMethod("onUrlChanged", arguments: data)
        }

        if enableAppScheme || (webView.url?.scheme == "http" || webView.url?.scheme == "https" || webView.url?.scheme == "about" || webView.url?.scheme == "file") {
            if isInvalid {
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.cancel)
        }
    }

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        channel.invokeMethod("onState", arguments: ["type": "startLoad", "url": webView.url?.absoluteString ?? ""])
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        channel.invokeMethod("onHttpError", arguments: ["code": "\((error as NSError).code)", "url": webView.url?.absoluteString ?? ""])
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        channel.invokeMethod("onState", arguments: ["type": "finishLoad", "url": webView.url?.absoluteString ?? ""])
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        channel.invokeMethod("onHttpError", arguments: ["code": "\((error as NSError).code)", "error": error.localizedDescription])
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            if response.statusCode >= 400 {
                channel.invokeMethod("onHttpError", arguments: ["code": "\(response.statusCode)", "url": webView.url?.absoluteString ?? ""])
            }
        }
        decisionHandler(.allow)
    }

    // MARK: - UIScrollViewDelegate

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        channel.invokeMethod("onScrollXChanged", arguments: ["xDirection": scrollView.contentOffset.x])
        channel.invokeMethod("onScrollYChanged", arguments: ["yDirection": scrollView.contentOffset.y])
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.pinchGestureRecognizer?.isEnabled = enableZoom
    }

    // MARK: - WKUIDelegate

    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel) { _ in
            completionHandler()
        })
        viewController.present(alert, animated: true, completion: nil)
    }

    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            completionHandler(true)
        })
        viewController.present(alert, animated: true, completion: nil)
    }

    public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = defaultText
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            completionHandler(nil)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        viewController.present(alert, animated: true, completion: nil)
    }

    // MARK: - Helper methods

    private func checkInvalidUrl(_ url: URL?) -> Bool {
        guard let urlString = url?.absoluteString, let regex = invalidUrlRegex else { return false }
        do {
            let regex = try NSRegularExpression(pattern: regex, options: .caseInsensitive)
            let range = NSRange(location: 0, length: urlString.utf16.count)
            return regex.firstMatch(in: urlString, options: [], range: range) != nil
        } catch {
            print("Invalid regex: \(error.localizedDescription)")
            return false
        }
    }
}
