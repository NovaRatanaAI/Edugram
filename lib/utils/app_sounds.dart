import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AppSounds {
  AppSounds._();

  static const uploadSuccess = 'sounds/mixkit-long-pop-2358.wav';
  static const feedRefresh = 'sounds/mixkit-long-pop-2358.wav';

  static Future<void> playUploadSuccess() async {
    await _playAsset(uploadSuccess);
  }

  static Future<void> playFeedRefresh() async {
    await _playAsset(feedRefresh);
  }

  static Future<void> _playAsset(String asset) async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource(asset));
      player.onPlayerComplete.first.then((_) => player.dispose());
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }
}
