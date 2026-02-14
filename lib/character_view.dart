// 角色显示模块 - 负责 Live2D 角色动画和交互
library character_view;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Live2D 角色显示组件
/// 负责：
/// - WebView 初始化和管理
/// - Live2D 模型加载和渲染
/// - JavaScript 通道通信
class CharacterView extends StatefulWidget {
  /// 是否正在计时（用于扩展：active 时播放动作，idle 时播放待机）
  final bool isActive;
  
  /// 纹理文件路径列表（相对于 assets 目录）
  /// 默认为 Hiyori 模型的纹理：texture_00.png, texture_01.png
  final List<String> texturePaths;
  
  /// 模型基础路径（相对于 assets 目录）
  /// 默认为 'live2d/hiyori/'
  final String modelBasePath;

  const CharacterView({
    super.key,
    this.isActive = false,
    this.texturePaths = const [
      'live2d/hiyori/Hiyori.2048/texture_00.png',
      'live2d/hiyori/Hiyori.2048/texture_01.png',
    ],
    this.modelBasePath = 'live2d/hiyori/',
  });

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    // 创建 WebViewController
    final controller = WebViewController();

    // 配置 Android WebView 以允许本地文件访问
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      // 设置 WebView 透明背景
      androidController.setBackgroundColor(const Color(0x00000000)); // ARGB: 00=透明, 000000=黑色
    }

    _controller = controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'AssetLoader',
        onMessageReceived: (JavaScriptMessage message) async {
          // 解析请求: "assets/live2d/hiyori/Hiyori.model3.json"
          final parts = message.message.split('|');
          if (parts.isEmpty) return;

          final assetPath = parts[0];
          final callbackId = parts.length > 1 ? parts[1] : '';

          try {
            final content = await rootBundle.loadString(assetPath);
            // 调用 JavaScript 回调
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
          final parts = message.message.split('|');
          if (parts.isEmpty) return;

          final assetPath = parts[0];
          final callbackId = parts.length > 1 ? parts[1] : '';

          try {
            final data = await rootBundle.load(assetPath);
            final base64 = base64Encode(data.buffer.asUint8List());

            // 根据文件类型设置 MIME type
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
          if (!mounted) return;
          debugPrint('[Live2DController] ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {},
        ),
      );

    // 读取所有文件内容
    final htmlContent = await rootBundle.loadString(
      'assets/live2d/hiyori_viewer.html',
    );

    // 预加载纹理并生成 base64，直接嵌入 HTML 占位符，确保脚本执行前即可使用
    Map<String, String> preloadedTextures = {};
    try {
      for (int i = 0; i < widget.texturePaths.length; i++) {
        final texturePath = widget.texturePaths[i];
        final data = await rootBundle.load('assets/$texturePath');
        final base64 = base64Encode(data.buffer.asUint8List());
        
        // 从路径获取纹理键名（例如 texture_00）
        final fileName = texturePath.split('/').last.replaceAll('.png', '');
        preloadedTextures[fileName] = 'data:image/png;base64,$base64';
      }
    } catch (e) {
      debugPrint('[CharacterView] Failed to preload textures: $e');
    }

    // 将JS内容内联到HTML中,替换script标签
    // 内联 pixi / cubism core / live2d-display 以避免外链加载问题
    final pixiJs = await rootBundle.loadString(
      'assets/live2d/libs/pixi.min.js',
    );
    final cubismCoreJs = await rootBundle.loadString(
      'assets/live2d/libs/live2dcubismcore.min.js',
    );
    final live2dDisplayJs = await rootBundle.loadString(
      'assets/live2d/libs/pixi-live2d-display.min.js',
    );

    // 用 JSON 编码纹理对象，然后注入到 JavaScript 中
    final texturesJson = jsonEncode(preloadedTextures);

    final modifiedHtml = htmlContent
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
      baseUrl: 'https://appassets.androidplatform.net/assets/${widget.modelBasePath}',
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: WebViewWidget(controller: _controller),
    );
  }
}
