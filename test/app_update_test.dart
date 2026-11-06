import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapsweep/core/services/app_update_service.dart';
import 'package:snapsweep/presentation/common/update_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.yousful.snapsweep/updates');
  late int installed;
  late int availability;
  late bool fail;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    installed = 17;
    availability = 2;
    fail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'installedVersion') return installed;
          if (call.method == 'startImmediate') return 'cancelled';
          if (fail) throw PlatformException(code: 'NETWORK_ERROR');
          return {
            'installedVersion': installed,
            'availableVersion': 18,
            'availability': availability,
            'immediateAllowed': true,
          };
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('cancel and restart cannot bypass a detected required update', () async {
    final first = AppUpdateController();
    await first.check();
    expect(first.stage, UpdateStage.required);
    await first.update();
    expect(first.allowsAccess, isFalse);
    expect(first.message, contains('cancelled'));
    first.dispose();
    fail = true;
    final reopened = AppUpdateController();
    await reopened.check();
    expect(reopened.stage, UpdateStage.required);
    expect(reopened.requiredVersion, 18);
    fail = false;
    availability = 1;
    await reopened.check();
    expect(reopened.allowsAccess, isTrue);
    installed = 18;
    await reopened.check();
    expect(reopened.allowsAccess, isTrue);
    reopened.dispose();
  });

  test('unavailable Play check allows direct APK testing', () async {
    fail = true;
    final controller = AppUpdateController();
    await controller.check();
    expect(controller.stage, UpdateStage.checkFailed);
    expect(controller.allowsAccess, isTrue);
    fail = false;
    availability = 1;
    await controller.check();
    expect(controller.allowsAccess, isTrue);
    controller.dispose();
  });

  test(
    'current or newer APK never prompts from a stale Play response',
    () async {
      for (final version in [18, 19]) {
        installed = version;
        SharedPreferences.setMockInitialValues({'required_play_version': 18});
        final controller = AppUpdateController();
        await controller.check();
        expect(controller.allowsAccess, isTrue);
        expect(controller.stage, UpdateStage.current);
        expect(controller.requiredVersion, 0);
        controller.dispose();
      }
    },
  );

  test(
    'updated sideloaded APK clears old required version before Play fails',
    () async {
      SharedPreferences.setMockInitialValues({'required_play_version': 18});
      installed = 19;
      fail = true;
      final controller = AppUpdateController();
      await controller.check();
      expect(controller.allowsAccess, isTrue);
      expect(controller.requiredVersion, 0);
      expect(
        (await SharedPreferences.getInstance()).getInt('required_play_version'),
        isNull,
      );
      controller.dispose();
    },
  );

  testWidgets(
    'Play unavailable never displays an update page over a sideloaded APK',
    (tester) async {
      fail = true;
      final controller = AppUpdateController();
      await tester.pumpWidget(
        MaterialApp(
          home: UpdateGate(
            enforce: true,
            controller: controller,
            child: const Scaffold(body: Text('Gallery tools')),
          ),
        ),
      );
      expect(find.text('Gallery tools'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Gallery tools'), findsOneWidget);
      expect(find.text('New update available'), findsNothing);
      expect(find.text('Couldn’t check for updates'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('required update page covers the app and survives back', (
    tester,
  ) async {
    final controller = AppUpdateController();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateGate(
          enforce: true,
          controller: controller,
          child: const Scaffold(body: Text('Gallery tools')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New update available'), findsOneWidget);
    expect(find.text('Gallery tools'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Gallery tools'), findsNothing);
    await tester.ensureVisible(find.text('Update now'));
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cancelled'), findsOneWidget);
    expect(tester.takeException(), isNull);
    installed = 18;
    availability = 1;
    await controller.check();
    await tester.pumpAndSettle();
    expect(find.text('Gallery tools'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
