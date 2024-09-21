import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _flutterWebviewPlugin = FlutterWebviewPlugin();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebView Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/': (_) => FutureBuilder<void>(
            future: _flutterWebviewPlugin.hide(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _flutterWebviewPlugin.show();
                });
              }
              return WebviewScaffold(
                url: 'https://www.google.com',
                appBar: AppBar(
                  title: const Text('Plugin Example App'),
                ),
                withZoom: true,
                withLocalStorage: true,
                hidden: true,
                initialChild: Container(
                  color: Colors.lightBlueAccent,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              );
            }),
      },
    );
  }
}
