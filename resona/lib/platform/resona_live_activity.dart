import 'package:flutter/services.dart';

class ResonaLiveActivity {
  ResonaLiveActivity._();

  static const _channel = MethodChannel('ai.synheart.resona/live_activity');

  static Future<void> listenForLinks({
    required VoidCallback onOpenPlayer,
    required ValueChanged<Uri> onWearablePair,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openPlayer') onOpenPlayer();
      if (call.method == 'pairWearable' && call.arguments is String) {
        final uri = Uri.tryParse(call.arguments as String);
        if (uri != null) onWearablePair(uri);
      }
    });
    try {
      final pending = await _channel.invokeMethod<bool>(
        'consumePendingPlayerOpen',
      );
      if (pending ?? false) onOpenPlayer();
    } on PlatformException {
      // Deep-link restoration is an iOS enhancement.
    } on MissingPluginException {
      // Expected on unsupported platforms and widget tests.
    }
  }

  static Future<void> start({
    required String title,
    required String artist,
    required bool isPlaying,
    String state = 'Flow',
    String stateImage = 'd16cbf7e-5125-4b51-ad96-eada0666f402',
  }) async {
    await _invoke(
      'start',
      title: title,
      artist: artist,
      isPlaying: isPlaying,
      state: state,
      stateImage: stateImage,
    );
  }

  static Future<void> update({
    required String title,
    required String artist,
    required bool isPlaying,
    String message = 'Supporting sustained focus',
    String state = 'Flow',
    String stateImage = 'd16cbf7e-5125-4b51-ad96-eada0666f402',
  }) async {
    await _invoke(
      'update',
      title: title,
      artist: artist,
      isPlaying: isPlaying,
      message: message,
      state: state,
      stateImage: stateImage,
    );
  }

  static Future<void> showAdaptation({
    required String title,
    required String artist,
    String state = 'Flow',
    String stateImage = 'd16cbf7e-5125-4b51-ad96-eada0666f402',
  }) async {
    await _invoke(
      'update',
      title: title,
      artist: artist,
      isPlaying: true,
      message: 'Sound adapted to support your flow',
      state: state,
      stateImage: stateImage,
    );
  }

  static Future<void> end() async {
    try {
      await _channel.invokeMethod<void>('end');
    } on PlatformException {
      // Live Activities are an iOS enhancement; playback remains functional.
    } on MissingPluginException {
      // Expected on unsupported platforms and widget tests.
    }
  }

  static Future<void> _invoke(
    String method, {
    required String title,
    required String artist,
    required bool isPlaying,
    String message = 'Supporting sustained focus',
    String state = 'Flow',
    String stateImage = 'd16cbf7e-5125-4b51-ad96-eada0666f402',
  }) async {
    try {
      await _channel.invokeMethod<void>(method, {
        'title': title,
        'artist': artist,
        'state': state,
        'stateImage': stateImage,
        'message': message,
        'isPlaying': isPlaying,
      });
    } on PlatformException {
      // A denied Live Activity must never interrupt the music experience.
    } on MissingPluginException {
      // Expected on Android and during widget tests.
    }
  }
}
