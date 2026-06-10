import 'package:flutter/services.dart';

/// Dart side of the Android PROCESS_TEXT bridge (see MainActivity.kt).
/// On iOS / when unavailable the methods degrade gracefully to no-ops.
class ProcessTextService {
  const ProcessTextService();

  static const MethodChannel _channel =
      MethodChannel('talk2text/process_text');

  /// The text the user selected when launching via the selection action, or
  /// null for a normal app launch.
  Future<String?> getInitialText() async {
    try {
      return await _channel.invokeMethod<String>('getInitialProcessText');
    } on MissingPluginException {
      return null; // iOS / channel not registered
    } catch (_) {
      return null;
    }
  }

  /// Returns [text] to the source app, replacing the original selection, and
  /// closes the activity.
  Future<void> finish(String text) async {
    try {
      await _channel.invokeMethod('finishWithText', {'text': text});
    } catch (_) {
      // Best effort — nothing to do if the platform side is unavailable.
    }
  }
}
