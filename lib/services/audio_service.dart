import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

abstract class AudioService {
  int get trackCount;

  Future<void> initialize({
    required int trackIndex,
    required double volume,
  });

  Future<bool> playBgm(int trackIndex, {required double volume});
  Future<void> pauseBgm();
  Future<bool> resumeBgm({required double volume});
  Future<void> stopBgm();
  Future<bool> playStartSfx();
  Future<bool> playEncouragementSfx();
}

class JustAudioService implements AudioService {
  JustAudioService({AudioPlayer? bgmPlayer, AudioPlayer? sfxPlayer})
    : _bgmPlayer = bgmPlayer ?? AudioPlayer(),
      _sfxPlayer = sfxPlayer ?? AudioPlayer();

  static const List<String> bgmTracks = <String>[
    'assets/music/bgm1.mp3',
    'assets/music/bgm2.mp3',
    'assets/music/bgm3.mp3',
  ];
  static const String startSfxAsset = 'assets/sfx/start_sfx.mp3';
  static const String encouragementSfxAsset = 'assets/sfx/encouragement_sfx.mp3';

  final AudioPlayer _bgmPlayer;
  final AudioPlayer _sfxPlayer;

  bool _initialized = false;
  int _currentTrackIndex = 0;

  @override
  int get trackCount => bgmTracks.length;

  @override
  Future<void> initialize({
    required int trackIndex,
    required double volume,
  }) async {
    if (_initialized) {
      return;
    }

    _currentTrackIndex = _sanitizeTrackIndex(trackIndex);
    await _bgmPlayer.setLoopMode(LoopMode.one);
    await _bgmPlayer.setVolume(_sanitizeVolume(volume));
    await _sfxPlayer.setVolume(_sanitizeVolume(volume));
    _initialized = true;
  }

  @override
  Future<bool> playBgm(int trackIndex, {required double volume}) async {
    await initialize(trackIndex: trackIndex, volume: volume);
    _currentTrackIndex = _sanitizeTrackIndex(trackIndex);

    try {
      await _bgmPlayer.setVolume(_sanitizeVolume(volume));
      await _bgmPlayer.setAsset(bgmTracks[_currentTrackIndex]);
      unawaited(
        _bgmPlayer.play().catchError((Object error, StackTrace stackTrace) {
          debugPrint('[AudioService] Failed to play BGM: $error\n$stackTrace');
        }),
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('[AudioService] Failed to play BGM: $error\n$stackTrace');
      return false;
    }
  }

  @override
  Future<void> pauseBgm() async {
    try {
      await _bgmPlayer.pause();
    } catch (error, stackTrace) {
      debugPrint('[AudioService] Failed to pause BGM: $error\n$stackTrace');
    }
  }

  @override
  Future<bool> resumeBgm({required double volume}) async {
    try {
      if (_bgmPlayer.audioSource == null) {
        return playBgm(_currentTrackIndex, volume: volume);
      }
      await _bgmPlayer.setVolume(_sanitizeVolume(volume));
      unawaited(
        _bgmPlayer.play().catchError((Object error, StackTrace stackTrace) {
          debugPrint('[AudioService] Failed to resume BGM: $error\n$stackTrace');
        }),
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('[AudioService] Failed to resume BGM: $error\n$stackTrace');
      return false;
    }
  }

  @override
  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (error, stackTrace) {
      debugPrint('[AudioService] Failed to stop BGM: $error\n$stackTrace');
    }
  }

  @override
  Future<bool> playStartSfx() => _playSfx(startSfxAsset);

  @override
  Future<bool> playEncouragementSfx() => _playSfx(encouragementSfxAsset);

  Future<bool> _playSfx(String assetPath) async {
    try {
      await _sfxPlayer.setAsset(assetPath);
      await _sfxPlayer.seek(Duration.zero);
      await _sfxPlayer.play();
      return true;
    } catch (error, stackTrace) {
      debugPrint('[AudioService] Failed to play SFX: $error\n$stackTrace');
      return false;
    }
  }

  int _sanitizeTrackIndex(int index) {
    if (bgmTracks.isEmpty) {
      return 0;
    }
    if (index < 0) {
      return 0;
    }
    if (index >= bgmTracks.length) {
      return bgmTracks.length - 1;
    }
    return index;
  }

  double _sanitizeVolume(double volume) {
    if (volume.isNaN) {
      return 1.0;
    }
    if (volume < 0) {
      return 0;
    }
    if (volume > 1) {
      return 1;
    }
    return volume;
  }
}
