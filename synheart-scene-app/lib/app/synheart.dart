import 'package:flutter/foundation.dart';
import 'package:synheart_behavior/synheart_behavior.dart';

/// Owns the Synheart Behavior SDK for the app.
///
/// Scene only needs typing signals for the check-in, so input signals are
/// on and motion is off. If the SDK cannot start (an unsupported platform,
/// a test), the app keeps working and the check-in offers the manual path.
class SynheartService {
  SynheartService._(this.behavior, this.error);

  /// Null when the SDK could not be initialised.
  final SynheartBehavior? behavior;

  /// Why initialisation failed, for the check-in screen.
  final String? error;

  bool get isAvailable => behavior != null;

  static Future<SynheartService> start() async {
    try {
      final behavior = await SynheartBehavior.initialize(
        config: const BehaviorConfig(
          enableInputSignals: true,
          enableAttentionSignals: true,
          enableMotionLite: false,
        ),
      );
      return SynheartService._(behavior, null);
    } catch (e) {
      debugPrint('Synheart Behavior unavailable: $e');
      return SynheartService._(null, '$e');
    }
  }

  /// For tests and platforms without the SDK.
  factory SynheartService.unavailable([String reason = 'Synheart Behavior is not available here.']) =>
      SynheartService._(null, reason);
}
