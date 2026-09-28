import 'package:flutter/foundation.dart';
import 'package:synheart_behavior/synheart_behavior.dart';

/// Owns the Synheart Behavior SDK for the app.
///
/// Nothing is collected before consent (RFC §4.4): the SDK is initialised
/// only when the user agrees on the check-in screen, and disposed when they
/// leave it, so there is no background collection (RFC §5). Scene needs
/// typing signals only, so input signals are on and attention and motion
/// are off.
///
/// The typing metrics themselves are computed by the SDK's
/// `BehaviorTextField` in Dart and delivered through its `onTypingEvent`
/// callback, so the check-in still works if the native side cannot start.
/// Checked in the synheart_behavior 0.4.1 source, which has no HTTP client:
/// nothing is sent off the device.
class SynheartService {
  SynheartService() : enabled = true;

  /// For tests and platforms without the native SDK: [start] never
  /// initialises it.
  SynheartService.unavailable() : enabled = false;

  final bool enabled;

  SynheartBehavior? _behavior;
  String? _error;

  /// Null until [start] succeeds.
  SynheartBehavior? get behavior => _behavior;

  /// Why the native SDK did not start, if it did not.
  String? get error => _error;

  /// Initialise the SDK after consent. Returns whether the native side runs.
  Future<bool> start() async {
    if (_behavior != null) return true;
    if (!enabled) return false;
    try {
      _behavior = await SynheartBehavior.initialize(
        config: const BehaviorConfig(
          enableInputSignals: true,
          enableAttentionSignals: false,
          enableMotionLite: false,
        ),
      );
      _error = null;
      return true;
    } catch (e) {
      debugPrint('Synheart Behavior unavailable: $e');
      _error = '$e';
      return false;
    }
  }

  /// Stop collecting when the check-in closes.
  Future<void> stop() async {
    final b = _behavior;
    _behavior = null;
    if (b == null) return;
    try {
      await b.dispose();
    } catch (e) {
      debugPrint('Synheart Behavior dispose failed: $e');
    }
  }
}
