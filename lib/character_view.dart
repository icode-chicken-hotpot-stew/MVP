// 角色显示模块 - 负责 Live2D 角色动画和交互

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'app_controller.dart';

const double kCharacterHorizontalOffset = 100.0;
const double kCharacterVerticalOffset = 320.0;

/// Live2D 角色显示组件
/// 负责：
/// - WebView 初始化和管理
/// - Live2D 模型加载和渲染
/// - JavaScript 通道通信
class CharacterView extends StatefulWidget {
  /// 当前番茄钟状态，用于切换基础待机动作
  final PomodoroState pomodoroState;

  /// 是否处于对话中
  final bool isTalking;

  /// 角色被点击时回调给 Flutter
  final VoidCallback? onCharacterTap;

  /// 纹理文件路径列表（相对于 assets 目录）
  final List<String> texturePaths;

  /// 模型基础路径（相对于 assets 目录）
  final String modelBasePath;

  /// Flutter 层整体横向位移（像素）。负值向左，正值向右。
  final double? horizontalOffset;

  /// Flutter 层整体纵向位移（像素）。
  /// 该位移作用在整个 WebView 上，不受 HTML 内部动画坐标影响。
  final double? verticalOffset;

  const CharacterView({
    super.key,
    required this.pomodoroState,
    required this.isTalking,
    this.onCharacterTap,
    this.texturePaths = const [
      'live2d/hiyori_pro/hiyori_movie_pro_t03.4096/texture_00.png',
    ],
    this.modelBasePath = 'live2d/hiyori_pro/',
    this.horizontalOffset,
    this.verticalOffset,
  });

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView> {
  late final WebViewController _controller;
  bool _pageReady = false;
  bool _isBridgeReady = false;
  String? _lastCharacterState;
  String? _lastViewportOffsetState;
  bool? _lastTalkingState;

  String get _targetCharacterState {
    return widget.pomodoroState == PomodoroState.studying ? 'study' : 'normal';
  }

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void reassemble() {
    super.reassemble();
    _syncViewportOffset(force: true);
    _syncCharacterState(force: true);
  }

  @override
  void didUpdateWidget(covariant CharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pomodoroState != widget.pomodoroState ||
        oldWidget.isTalking != widget.isTalking) {
      _syncCharacterState();
    }
    if (oldWidget.horizontalOffset != widget.horizontalOffset ||
        oldWidget.verticalOffset != widget.verticalOffset) {
      _syncViewportOffset();
    }
  }

  Future<void> _syncCharacterState({bool force = false}) async {
    if (!_pageReady) {
      return;
    }

    final String nextState = _targetCharacterState;
    final bool talkingChanged = _lastTalkingState != widget.isTalking;
    if (!force && _lastCharacterState == nextState && !talkingChanged) {
      return;
    }

    try {
      await _controller.runJavaScript(
        'if (window.setCharacterState) { window.setCharacterState(${jsonEncode(nextState)}); }',
      );

      if (_isBridgeReady && widget.isTalking && (force || talkingChanged)) {
        await _controller.runJavaScript(
          'if (window.playMotionByName) { window.playMotionByName("Talk", 0); } else if (window.playMotion) { window.playMotion("Talk"); }',
        );
      }

      _lastCharacterState = nextState;
      _lastTalkingState = widget.isTalking;
      debugPrint(
        '[CharacterView] synced state -> $nextState, talking=${widget.isTalking}',
      );
    } catch (e) {
      debugPrint('[CharacterView] failed to sync character state: $e');
    }
  }

  Future<void> _syncViewportOffset({bool force = false}) async {
    if (!_pageReady) {
      return;
    }

    final double x = widget.horizontalOffset ?? kCharacterHorizontalOffset;
    final double y = widget.verticalOffset ?? kCharacterVerticalOffset;
    final String nextState = '$x|$y';
    if (!force && _lastViewportOffsetState == nextState) {
      return;
    }

    try {
      await _controller.runJavaScript(
        'if (window.setViewportOffset) { window.setViewportOffset(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}); }',
      );
      _lastViewportOffsetState = nextState;
      debugPrint('[CharacterView] synced viewport offset -> x=$x, y=$y');
    } catch (e) {
      debugPrint('[CharacterView] failed to sync viewport offset: $e');
    }
  }

  Future<void> _initializeWebView() async {
    final controller = WebViewController();

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setBackgroundColor(const Color(0x00000000));
    }

    _controller = controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'AssetLoader',
        onMessageReceived: (JavaScriptMessage message) async {
          final List<String> parts = message.message.split('|');
          if (parts.isEmpty) {
            return;
          }

          final String assetPath = parts[0];
          final String callbackId = parts.length > 1 ? parts[1] : '';

          try {
            final String content = await rootBundle.loadString(assetPath);
            await _controller.runJavaScript(
              'window._assetLoaded("$callbackId", ${jsonEncode(content)});',
            );
          } catch (e) {
            await _controller.runJavaScript(
              'window._assetLoaded("$callbackId", null, ${jsonEncode(e.toString())});',
            );
          }
        },
      )
      ..addJavaScriptChannel(
        'BinaryAssetLoader',
        onMessageReceived: (JavaScriptMessage message) async {
          final List<String> parts = message.message.split('|');
          if (parts.isEmpty) {
            return;
          }

          final String assetPath = parts[0];
          final String callbackId = parts.length > 1 ? parts[1] : '';

          try {
            final ByteData data = await rootBundle.load(assetPath);
            final String base64 = base64Encode(data.buffer.asUint8List());

            String mimeType = 'application/octet-stream';
            if (assetPath.endsWith('.png')) {
              mimeType = 'image/png';
            } else if (assetPath.endsWith('.jpg') ||
                assetPath.endsWith('.jpeg')) {
              mimeType = 'image/jpeg';
            }

            await _controller.runJavaScript(
              'window._binaryAssetLoaded("$callbackId", "data:$mimeType;base64,$base64");',
            );
          } catch (e) {
            await _controller.runJavaScript(
              'window._binaryAssetLoaded("$callbackId", null, ${jsonEncode(e.toString())});',
            );
          }
        },
      )
      ..addJavaScriptChannel(
        'Live2DController',
        onMessageReceived: (JavaScriptMessage message) {
          if (!mounted) {
            return;
          }
          _handleLive2DMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String _) {
            _pageReady = true;
            unawaited(_syncCharacterState(force: true));
            unawaited(_syncViewportOffset(force: true));
          },
        ),
      );

    final String htmlContent = await rootBundle.loadString(
      'assets/live2d/hiyori_viewer.html',
    );

    final Map<String, String> preloadedTextures = <String, String>{};
    for (final String texturePath in widget.texturePaths) {
      final Set<String> candidates = <String>{
        'assets/$texturePath',
        texturePath,
      };

      ByteData? data;
      for (final String candidate in candidates) {
        try {
          data = await rootBundle.load(candidate);
          debugPrint('[CharacterView] Preloaded texture from: $candidate');
          break;
        } catch (_) {
          // 继续尝试下一个候选路径
        }
      }

      if (data == null) {
        debugPrint('[CharacterView] Failed to preload texture: $texturePath');
        continue;
      }

      final String base64 = base64Encode(data.buffer.asUint8List());
      final String fileName = texturePath
          .split('/')
          .last
          .replaceAll('.png', '');
      preloadedTextures[fileName] = 'data:image/png;base64,$base64';
    }

    final String pixiJs = await rootBundle.loadString(
      'assets/live2d/libs/pixi.min.js',
    );
    final String cubismCoreJs = await rootBundle.loadString(
      'assets/live2d/libs/live2dcubismcore.min.js',
    );
    final String live2dDisplayJs = await rootBundle.loadString(
      'assets/live2d/libs/pixi-live2d-display.min.js',
    );
    final String texturesJson = jsonEncode(preloadedTextures);

    final String modifiedHtml = htmlContent
        .replaceAll(
          '<script src="https://appassets.androidplatform.net/assets/live2d/libs/pixi.min.js"></script>',
          '<script>$pixiJs</script>',
        )
        .replaceAll(
          '<script src="https://appassets.androidplatform.net/assets/live2d/libs/live2dcubismcore.min.js"></script>',
          '<script>$cubismCoreJs</script>',
        )
        .replaceAll(
          '<script src="https://appassets.androidplatform.net/assets/live2d/libs/pixi-live2d-display.min.js"></script>',
          '<script>$live2dDisplayJs</script>',
        )
        .replaceFirst(
          'window._preloadedTextures = /*__PRELOADED_TEXTURES__*/ {};',
          'window._preloadedTextures = $texturesJson;',
        );

    await _controller.loadHtmlString(
      modifiedHtml,
      baseUrl:
          'https://appassets.androidplatform.net/assets/${widget.modelBasePath}',
    );
  }

  void _handleLive2DMessage(String rawMessage) {
    try {
      final dynamic decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final String? type = decoded['type'] as String?;
      if (type == null) {
        return;
      }

      switch (type) {
        case 'ready':
          _isBridgeReady = true;
          unawaited(_syncCharacterState(force: true));
          unawaited(_syncViewportOffset(force: true));
          return;
        case 'character_tap':
          widget.onCharacterTap?.call();
          return;
        default:
          return;
      }
    } on FormatException {
      debugPrint('[Live2DController] $rawMessage');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: WebViewWidget(controller: _controller),
    );
  }
}
