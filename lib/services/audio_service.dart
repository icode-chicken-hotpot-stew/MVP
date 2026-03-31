import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

abstract class AudioService {
  int get trackCount;

  Future<void> initialize({required int trackIndex, required double volume});

  Future<bool> playBgm(int trackIndex, {required double volume});
  Future<void> pauseBgm();
  Future<bool> resumeBgm({required double volume});
  Future<void> stopBgm();
  Future<bool> playStartSfx();
  Future<bool> playEncouragementSfx();
  Future<bool> playButtonOpenSfx();
  Future<bool> playButtonBackSfx();
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
  static const String studyStartSfxAsset = 'assets/sfx/study_start.mp3';
  static const String studyEndSfxAsset = 'assets/sfx/study_end.mp3';
  static const String buttonOpenSfxAsset = 'assets/sfx/button_open.mp3';
  static const String buttonBackSfxAsset = 'assets/sfx/button_back.mp3';
  static const Duration sfxAnyTypeCooldown = Duration(milliseconds: 180);
  static const Duration sfxSameAssetDedupWindow = Duration(milliseconds: 360);

  final AudioPlayer _bgmPlayer;
  final AudioPlayer _sfxPlayer;

  bool _initialized = false;
  int _currentTrackIndex = 0;
  bool _sfxStartInFlight = false;
  String? _lastSfxAssetPath;
  DateTime? _lastSfxAcceptedAt;

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
          debugPrint(
            '[AudioService] Failed to resume BGM: $error\n$stackTrace',
          );
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
  Future<bool> playStartSfx() => _playSfx(studyStartSfxAsset);

  @override
  Future<bool> playEncouragementSfx() => _playSfx(studyEndSfxAsset);

  @override
  Future<bool> playButtonOpenSfx() => _playSfx(buttonOpenSfxAsset);

  @override
  Future<bool> playButtonBackSfx() => _playSfx(buttonBackSfxAsset);

  Future<bool> _playSfx(String assetPath) async {
    final DateTime now = DateTime.now();
    final DateTime? lastAt = _lastSfxAcceptedAt;
    final Duration? elapsed = lastAt == null ? null : now.difference(lastAt);

    if (_sfxStartInFlight) {
      debugPrint(
        '[AudioService] Skip SFX while previous start is in flight: $assetPath',
      );
      return true;
    }

    final bool isRapidConsecutiveBurst =
        elapsed != null && elapsed < sfxAnyTypeCooldown;
    if (isRapidConsecutiveBurst) {
      debugPrint('[AudioService] Skip rapid consecutive SFX burst: $assetPath');
      return true;
    }

    final bool isSameAssetDuplicate =
        _lastSfxAssetPath == assetPath &&
        elapsed != null &&
        elapsed < sfxSameAssetDedupWindow;
    if (isSameAssetDuplicate) {
      debugPrint('[AudioService] Skip duplicate SFX burst: $assetPath');
      return true;
    }

    _sfxStartInFlight = true;
    _lastSfxAssetPath = assetPath;
    _lastSfxAcceptedAt = now;

    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setAsset(assetPath);
      await _sfxPlayer.seek(Duration.zero);
      unawaited(
        _sfxPlayer.play().catchError((Object error, StackTrace stackTrace) {
          debugPrint('[AudioService] Failed to play SFX: $error\n$stackTrace');
        }),
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('[AudioService] Failed to play SFX: $error\n$stackTrace');
      return false;
    } finally {
      _sfxStartInFlight = false;
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
