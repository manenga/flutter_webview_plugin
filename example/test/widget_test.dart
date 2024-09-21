import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webview_plugin_example/main.dart';

void main() {
  testWidgets('MyApp has a title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Plugin Example App'), findsOneWidget);
  });
}
