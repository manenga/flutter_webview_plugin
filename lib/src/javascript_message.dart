/// A message that was sent by JavaScript code running in a [WebView].

// ignore_for_file: unnecessary_null_comparison

class JavascriptMessage {
  /// Constructs a JavaScript message object.
  ///
  /// The `message` parameter must not be null.
  const JavascriptMessage(this.message) : assert(message != null);

  /// The contents of the message that was sent by the JavaScript code.
  final String message;
}
