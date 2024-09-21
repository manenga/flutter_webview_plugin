part of 'base.dart';

enum WebViewState { shouldStart, startLoad, finishLoad, abortLoad }

class WebViewStateChanged {
  WebViewStateChanged(this.type, this.url, this.navigationType);

  factory WebViewStateChanged.fromMap(Map<String, dynamic> map) {
    WebViewState t;
    switch (map['type']) {
      case 'shouldStart':
        t = WebViewState.shouldStart;
        break;
      case 'startLoad':
        t = WebViewState.startLoad;
        break;
      case 'finishLoad':
        t = WebViewState.finishLoad;
        break;
      case 'abortLoad':
        t = WebViewState.abortLoad;
        break;
      default:
        throw UnimplementedError(
            'WebViewState type "${map['type']}" is not supported.');
    }
    return WebViewStateChanged(t, map['url'], map['navigationType']);
  }

  final WebViewState type;
  final String url;
  final int? navigationType;
}