import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterWebviewPlugin', () {
    late FlutterWebviewPlugin webviewPlugin;
    late MethodChannel channel;

    setUp(() {
      channel = const MethodChannel('flutter_webview_plugin');
      webviewPlugin = FlutterWebviewPlugin.private(channel);
    });

    test('launch method sends correct arguments', () async {
      final List<MethodCall> log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      });

      await webviewPlugin.launch('https://google.com');

      expect(log, hasLength(1));
      expect(log[0].method, 'launch');
      expect(log[0].arguments['url'], 'https://google.com');
    });

    test('close method invokes correct channel method', () async {
      final List<MethodCall> log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      });

      await webviewPlugin.close();

      expect(log, hasLength(1));
      expect(log[0].method, 'close');
    });

    test('reload method invokes correct channel method', () async {
      final List<MethodCall> log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      });

      await webviewPlugin.reload();

      expect(log, hasLength(1));
      expect(log[0].method, 'reload');
    });

    test('goBack method invokes correct channel method', () async {
      final List<MethodCall> log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      });

      await webviewPlugin.goBack();

      expect(log, hasLength(1));
      expect(log[0].method, 'back');
    });

    test('goForward method invokes correct channel method', () async {
      final List<MethodCall> log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      });

      await webviewPlugin.goForward();

      expect(log, hasLength(1));
      expect(log[0].method, 'forward');
    });
  });

  group('FlutterWebviewPlugin _handleMessages', () {
    late FlutterWebviewPlugin webviewPlugin;

    setUp(() {
      webviewPlugin = FlutterWebviewPlugin();
    });

    test('onBack event', () async {
      final future = webviewPlugin.onBack.first;
      // Simulate the native code calling onBack
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('onBack')),
        (ByteData? data) {},
      );
      try {
        await future.timeout(const Duration(seconds: 5), onTimeout: () {
          throw TimeoutException('Future did not complete');
        });
        await expectLater(future, completes);
      } catch (e) {
        rethrow;
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('onDestroy event', () async {
      final future = webviewPlugin.onDestroy.first;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('onDestroy')),
        (ByteData? data) {},
      );
      await expectLater(future, completes);
    });

    test('onUrlChanged event', () async {
      final future = webviewPlugin.onUrlChanged.first;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onUrlChanged', {'url': 'https://example.com'})),
        (ByteData? data) {},
      );
      expect(await future, equals('https://example.com'));
    });

    test('onScrollXChanged event', () async {
      final future = webviewPlugin.onScrollXChanged.first;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onScrollXChanged', {'xDirection': 10.0})),
        (ByteData? data) {},
      );
      expect(await future, equals(10.0));
    });

    test('onScrollYChanged event', () async {
      final future = webviewPlugin.onScrollYChanged.first;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onScrollYChanged', {'yDirection': 20.0})),
        (ByteData? data) {},
      );
      expect(await future, equals(20.0));
    });

    test('onProgressChanged event', () async {
      final future = webviewPlugin.onProgressChanged.first;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onProgressChanged', {'progress': 0.5})),
        (ByteData? data) {},
      );
      expect(await future, equals(0.5));
    });

    test('onState event - shouldStart', () async {
      final future = webviewPlugin.onStateChanged.first;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(const MethodCall(
            'onState', {
          'type': 'shouldStart',
          'url': 'https://google.com',
          'navigationType': 0
        })),
        (ByteData? data) {},
      );
      final result = await future;
      expect(result.type, equals(WebViewState.shouldStart));
      expect(result.url, equals('https://google.com'));
      expect(result.navigationType, equals(0));
    });

    test('onState event - startLoad', () async {
      final future = webviewPlugin.onStateChanged.first;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(const MethodCall(
            'onState', {
          'type': 'startLoad',
          'url': 'https://google.com',
          'navigationType': 0
        })),
        (ByteData? data) {},
      );
      final result = await future;
      expect(result.type, equals(WebViewState.startLoad));
      expect(result.url, equals('https://google.com'));
      expect(result.navigationType, equals(0));
    });

    test('onState event - finishLoad', () async {
      final future = webviewPlugin.onStateChanged.first;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(const MethodCall(
            'onState', {
          'type': 'finishLoad',
          'url': 'https://google.com',
          'navigationType': 0
        })),
        (ByteData? data) {},
      );
      final result = await future;
      expect(result.type, equals(WebViewState.finishLoad));
      expect(result.url, equals('https://google.com'));
      expect(result.navigationType, equals(0));
    });

    test('onState event - abortLoad', () async {
      final future = webviewPlugin.onStateChanged.first;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(const MethodCall(
            'onState', {
          'type': 'abortLoad',
          'url': 'https://google.com',
          'navigationType': 0
        })),
        (ByteData? data) {},
      );
      final result = await future;
      expect(result.type, equals(WebViewState.abortLoad));
      expect(result.url, equals('https://google.com'));
      expect(result.navigationType, equals(0));
    });

    test('onHttpError event', () async {
      final future = webviewPlugin.onHttpError.first;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(const MethodCall(
            'onHttpError',
            {'code': '404', 'url': 'https://google.com/notfound'})),
        (ByteData? data) {},
      );
      final error = await future;
      expect(error.code, equals('404'));
      expect(error.url, equals('https://google.com/notfound'));
    });

    test('javascriptChannelMessage event', () async {
      final testChannel = JavascriptChannel(
        name: 'TestChannel',
        onMessageReceived: expectAsync1((JavascriptMessage message) {
          expect(message.message, equals('Hello from JS'));
        }),
      );
      webviewPlugin = FlutterWebviewPlugin();
      await webviewPlugin
          .launch('https://google.com', javascriptChannels: {testChannel});

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(const MethodCall(
            'javascriptChannelMessage',
            {'channel': 'TestChannel', 'message': 'Hello from JS'})),
        (ByteData? data) {},
      );
    });

    test('javascriptChannelMessage event - non-existent channel', () async {
      // This should not throw an error, but it should print a debug message
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'flutter_webview_plugin',
        const StandardMethodCodec().encodeMethodCall(const MethodCall(
            'javascriptChannelMessage', {
          'channel': 'NonExistentChannel',
          'message': 'This should be ignored'
        })),
        (ByteData? data) {},
      );
      // We can't easily test for the debug print, but we can ensure it doesn't throw
    });
  });

  group('WebViewStateChanged', () {
    test('constructor creates instance with correct properties', () {
      final state =
          WebViewStateChanged(WebViewState.startLoad, 'https://google.com', 0);

      expect(state.type, equals(WebViewState.startLoad));
      expect(state.url, equals('https://google.com'));
      expect(state.navigationType, equals(0));
    });

    group('fromMap factory', () {
      test('creates shouldStart state correctly', () {
        final state = WebViewStateChanged.fromMap({
          'type': 'shouldStart',
          'url': 'https://google.com',
          'navigationType': 1
        });

        expect(state.type, equals(WebViewState.shouldStart));
        expect(state.url, equals('https://google.com'));
        expect(state.navigationType, equals(1));
      });

      test('creates startLoad state correctly', () {
        final state = WebViewStateChanged.fromMap({
          'type': 'startLoad',
          'url': 'https://google.com',
          'navigationType': 2
        });

        expect(state.type, equals(WebViewState.startLoad));
        expect(state.url, equals('https://google.com'));
        expect(state.navigationType, equals(2));
      });

      test('creates finishLoad state correctly', () {
        final state = WebViewStateChanged.fromMap({
          'type': 'finishLoad',
          'url': 'https://google.com',
          'navigationType': 3
        });

        expect(state.type, equals(WebViewState.finishLoad));
        expect(state.url, equals('https://google.com'));
        expect(state.navigationType, equals(3));
      });

      test('creates abortLoad state correctly', () {
        final state = WebViewStateChanged.fromMap({
          'type': 'abortLoad',
          'url': 'https://google.com',
          'navigationType': 4
        });

        expect(state.type, equals(WebViewState.abortLoad));
        expect(state.url, equals('https://google.com'));
        expect(state.navigationType, equals(4));
      });

      test('handles null navigationType', () {
        final state = WebViewStateChanged.fromMap({
          'type': 'startLoad',
          'url': 'https://google.com',
          'navigationType': null
        });

        expect(state.type, equals(WebViewState.startLoad));
        expect(state.url, equals('https://google.com'));
        expect(state.navigationType, isNull);
      });

      test('throws UnimplementedError for unknown type', () {
        expect(
            () => WebViewStateChanged.fromMap({
                  'type': 'unknownType',
                  'url': 'https://google.com',
                  'navigationType': 0
                }),
            throwsA(isA<UnimplementedError>()));
      });
    });
  });
}
