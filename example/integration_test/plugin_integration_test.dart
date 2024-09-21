import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FlutterWebviewPlugin plugin;

  setUp(() {
    plugin = FlutterWebviewPlugin();
  });

  testWidgets('canGoBack test', (WidgetTester tester) async {
    final bool canGoBack = await plugin.canGoBack();
    expect(canGoBack, isFalse);
  });

  testWidgets('canGoForward test', (WidgetTester tester) async {
    final bool canGoForward = await plugin.canGoForward();
    expect(canGoForward, isFalse);
  });

  testWidgets('canGoBack after navigation', (WidgetTester tester) async {
    await plugin.launch('https://flutter.dev');
    await plugin.reloadUrl('https://dart.dev');

    final bool canGoBack = await plugin.canGoBack();
    expect(canGoBack, isTrue);
  });

  testWidgets('canGoForward after going back', (WidgetTester tester) async {
    await plugin.launch('https://flutter.dev');
    await plugin.reloadUrl('https://dart.dev');
    await plugin.goBack();

    final bool canGoForward = await plugin.canGoForward();
    expect(canGoForward, isTrue);
  });
}
