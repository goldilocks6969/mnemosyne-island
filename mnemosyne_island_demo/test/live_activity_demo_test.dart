import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnemosyne_island/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('one.antimattr.mnemosyne/live_activity');
  late List<MethodCall> calls;
  String? phase;
  bool failUpdates = false;
  bool pendingReview = false;

  Map<String, Object?> status() => {
        'active': phase != null,
        'phase': phase,
        'activityId': phase == null ? null : 'test-activity',
        'enabled': true,
      };

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = [];
    phase = null;
    failUpdates = false;
    pendingReview = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getStatus':
          return status();
        case 'setState':
          if (failUpdates) {
            throw PlatformException(
              code: 'activity_failed',
              message: 'The iPhone could not start the activity.',
            );
          }
          phase = (call.arguments as Map<Object?, Object?>)['phase'] as String;
          return status();
        case 'stop':
          phase = null;
          return status();
        case 'consumePendingReview':
          final result = pendingReview;
          pendingReview = false;
          return result;
        default:
          throw MissingPluginException('Unexpected test call: ${call.method}');
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> launch(WidgetTester tester) async {
    // A tall surface keeps the controls visible without scrolling in these tests.
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump();
  }

  testWidgets('failed native start never selects or previews a successful state',
      (tester) async {
    failUpdates = true;
    await launch(tester);
    expect(find.text('Ready to start'), findsOneWidget);

    await tester.tap(find.text('Recording'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('The iPhone could not start the activity.'), findsOneWidget);
    expect(find.text('Ready to start'), findsOneWidget);
    expect(find.text('Recording · active'), findsNothing);
    expect(find.text('[rec]'), findsNothing);
    final end = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('End Live Activity'),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      ),
    );
    expect(end.onPressed, isNull);
    expect(calls.where((call) => call.method == 'setState'), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('successful native state can be ended and clears the preview',
      (tester) async {
    await launch(tester);
    await tester.tap(find.text('Agent working'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Agent working · active'), findsOneWidget);
    expect(find.text('[working]'), findsOneWidget);
    final tag = tester.widget<Text>(find.text('[working]'));
    expect(tag.style?.color, Colors.white);
    final update = calls.singleWhere((call) => call.method == 'setState');
    expect(update.arguments, {'phase': 'working'});

    await tester.tap(find.text('End Live Activity'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ready to start'), findsOneWidget);
    expect(find.text('[working]'), findsNothing);
    expect(calls.where((call) => call.method == 'stop'), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cold-start pending review opens Instinct without executing work',
      (tester) async {
    pendingReview = true;
    await launch(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Instinct needs you.'), findsOneWidget);
    expect(find.textContaining('does not approve or execute anything'), findsOneWidget);
    expect(calls.where((call) => call.method == 'consumePendingReview'), hasLength(1));
    expect(calls.where((call) => call.method == 'setState'), isEmpty);

    await tester.tap(find.text('Back to demo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Ready to start'), findsOneWidget);
    expect(find.text('Instinct needs you.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
