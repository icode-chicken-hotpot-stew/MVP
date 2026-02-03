// lib/main.dart - 完整代码
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() {
  runApp(const Live2DApp());
}

class Live2DApp extends StatelessWidget {
  const Live2DApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live2D Hiyori 测试',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HiyoriViewerPage(), // 这里直接跳转到Hiyori页面
      debugShowCheckedModeBanner: false,
    );
  }
}

class HiyoriViewerPage extends StatefulWidget {
  const HiyoriViewerPage({super.key});

  @override
  State<HiyoriViewerPage> createState() => _HiyoriViewerPageState();
}

class _HiyoriViewerPageState extends State<HiyoriViewerPage> {
  late final WebViewController _controller;
  double _loadingProgress = 0;
  bool _isLoading = true;
  String _status = '正在初始化...';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    // 配置 Android WebView 以允许本地文件访问
    final params = PlatformWebViewControllerCreationParams();
    final WebViewController controller;
    if (params is AndroidWebViewControllerCreationParams) {
      controller = WebViewController.fromPlatformCreationParams(params);
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    } else {
      controller = WebViewController.fromPlatformCreationParams(params);
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
            } else if (assetPath.endsWith('.moc3')) {
              mimeType = 'application/octet-stream';
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
          setState(() {
            _status = message.message;
            // 当收到模型加载成功的消息时，隐藏加载指示器
            if (message.message.contains('ready') ||
                message.message.contains('loaded') ||
                message.message.contains('Model is visible')) {
              _isLoading = false;
              _loadingProgress = 1.0;
            }
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // 页面加载完成后，延迟隐藏加载器（给模型一点加载时间）
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _loadingProgress = 1.0;
                });
              }
            });
          },
        ),
      );

    // 读取所有文件内容
    final htmlContent = await rootBundle.loadString(
      'assets/live2d/hiyori_viewer.html',
    );

    // 预加载纹理并生成 base64，直接嵌入 HTML 占位符，确保脚本执行前即可使用
    Map<String, String> preloadedTextures = {};
    try {
      final tex0 = await rootBundle.load(
        'assets/live2d/hiyori/Hiyori.2048/texture_00.png',
      );
      final tex1 = await rootBundle.load(
        'assets/live2d/hiyori/Hiyori.2048/texture_01.png',
      );
      preloadedTextures = {
        'texture_00':
            'data:image/png;base64,${base64Encode(tex0.buffer.asUint8List())}',
        'texture_01':
            'data:image/png;base64,${base64Encode(tex1.buffer.asUint8List())}',
      };
    } catch (e) {
      debugPrint('[Flutter] Failed to preload textures: $e');
    }

    // 将JS内容内联到HTML中,替换script标签和纹理占位符
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
          '/*__PRELOADED_TEXTURES__*/ {}',
          jsonEncode(preloadedTextures),
        );

    await _controller.loadHtmlString(
      modifiedHtml,
      baseUrl: 'https://appassets.androidplatform.net/assets/live2d/',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView 显示区域
          WebViewWidget(controller: _controller),

          // 加载指示器
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: _loadingProgress,
                      strokeWidth: 6,
                      color: Colors.pinkAccent,
                      backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '加载 Hiyori Live2D...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(_loadingProgress * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _status,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // 顶部状态栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: kToolbarHeight + MediaQuery.of(context).padding.top,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: 16,
                  right: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 返回按钮
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.black.withOpacity(0.5),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                      ),
                    ),

                    // 标题
                    Text(
                      'Hiyori Live2D',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // 状态指示器
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isLoading
                            ? Colors.orange.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isLoading ? Colors.orange : Colors.green,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _isLoading ? '加载中' : '已加载',
                        style: TextStyle(
                          color: _isLoading ? Colors.orange : Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 底部状态信息
          if (!_isLoading)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.pinkAccent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.pinkAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live2D 状态',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _loadingProgress,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      color: Colors.pinkAccent,
                      minHeight: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // 浮动操作按钮
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              // 发送JavaScript命令
              _controller.runJavaScript('''
                if (window.hiyoriController && window.hiyoriController.reset) {
                  window.hiyoriController.reset();
                }
              ''');
            },
            backgroundColor: Colors.blueAccent,
            mini: true,
            child: const Icon(Icons.center_focus_strong, size: 20),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              _controller.reload();
              setState(() {
                _isLoading = true;
                _status = '重新加载中...';
              });
            },
            backgroundColor: Colors.pinkAccent,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              // 发送测试命令
              _controller.runJavaScript('''
                if (window.hiyoriController && window.hiyoriController.playMotion) {
                  window.hiyoriController.playMotion('wave');
                }
              ''');
            },
            backgroundColor: Colors.greenAccent,
            mini: true,
            child: const Icon(Icons.play_arrow, size: 20),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
