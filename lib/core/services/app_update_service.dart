import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateStage { checking, current, required, checkFailed }

class AppUpdateController extends ChangeNotifier {
  AppUpdateController({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.yousful.snapsweep/updates');
  final MethodChannel _channel;
  UpdateStage stage = UpdateStage.checking;
  bool updating = false;
  bool immediateAllowed = false;
  bool resumeRequested = false;
  int installedVersion = 0;
  int requiredVersion = 0;
  String message = '';
  bool _checking = false;
  bool _disposed = false;
  // An unavailable Play check is not evidence that this APK is outdated.
  bool get allowsAccess => stage != UpdateStage.required;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> check() async {
    if (_checking || updating || _disposed) return;
    _checking = true;
    if (stage != UpdateStage.required) stage = UpdateStage.checking;
    resumeRequested = false;
    immediateAllowed = false;
    message = '';
    _emit();
    try {
      final prefs = await SharedPreferences.getInstance();
      requiredVersion = prefs.getInt('required_play_version') ?? 0;
      installedVersion =
          await _channel
              .invokeMethod<int>('installedVersion')
              .timeout(const Duration(seconds: 4)) ??
          0;
      if (installedVersion > 0 && installedVersion >= requiredVersion) {
        requiredVersion = 0;
        await prefs.remove('required_play_version');
      }
      final info = await _channel
          .invokeMapMethod<String, dynamic>('check')
          .timeout(const Duration(seconds: 12));
      if (info == null || installedVersion <= 0) {
        throw StateError('Update status unavailable');
      }
      final availability = info['availability'] as int? ?? 0;
      final available = info['availableVersion'] as int? ?? 0;
      if ((availability == 2 || availability == 3) &&
          available > installedVersion) {
        immediateAllowed = info['immediateAllowed'] == true;
        resumeRequested = availability == 3;
        requiredVersion = available;
        await prefs.setInt('required_play_version', requiredVersion);
        stage = UpdateStage.required;
      } else if (availability == 1 ||
          ((availability == 2 || availability == 3) &&
              available > 0 &&
              available <= installedVersion)) {
        stage = UpdateStage.current;
        requiredVersion = 0;
        await prefs.remove('required_play_version');
      } else {
        throw StateError('Google Play could not confirm update status');
      }
    } catch (error) {
      stage = requiredVersion > installedVersion && installedVersion > 0
          ? UpdateStage.required
          : UpdateStage.checkFailed;
      message = stage == UpdateStage.required
          ? 'A newer version was previously confirmed. Connect to Google Play to finish updating.'
          : '';
    } finally {
      _checking = false;
      _emit();
    }
  }

  Future<void> update() async {
    if (updating || _checking || _disposed || stage != UpdateStage.required) {
      return;
    }
    updating = true;
    message = '';
    _emit();
    try {
      if (immediateAllowed) {
        final outcome = await _channel.invokeMethod<String>('startImmediate');
        message = outcome == 'cancelled'
            ? 'The update was cancelled. Install the update to continue.'
            : 'Finish installing the update to continue. You can also update from Google Play.';
      } else {
        await openStore();
      }
    } catch (error) {
      message =
          'The update could not start. Open Google Play to install it, then return here.';
    } finally {
      updating = false;
      _emit();
      // An accepted or cancelled flow is never proof of an installed update.
      // Only a new installed-version/availability check can release the gate.
    }
  }

  Future<void> openStore() async {
    try {
      final opened = await launchUrl(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.yousful.snapsweep',
        ),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Store unavailable');
    } catch (error) {
      message =
          'Google Play could not be opened. Open the Play Store and search for SnapSweep.';
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
