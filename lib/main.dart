import 'package:flutter/material.dart';
// 预留其他模块的引用（需要先创建对应的空文件）
import 'app_controller.dart';
import 'character_view.dart';
import 'ui_widgets.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Study App(MVP)',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const MainStage(),
    );
  }
}

class MainStage extends StatefulWidget {
  const MainStage({super.key});

  @override
  State<MainStage> createState() => _MainStageState();
}

class _MainStageState extends State<MainStage> {
  // 创建 AppController 实例（逻辑中枢）
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController();
  }

  @override
  void dispose() {
    // 释放 ValueNotifier 资源
    controller.remainingSeconds.dispose();
    controller.isActive.dispose();
    controller.isDrawerOpen.dispose();
    controller.currentDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用 Stack 布局，确保背景、角色、UI 层次分明 [3, 4]
      body: Stack(
        children: [
          // 1. 背景层
          Positioned.fill(
            child: Image.asset('assets/background.webp', fit: BoxFit.cover),
          ),

          // 2. 角色层 (对应组员 B 的模块) [4, 5]
          Center(
            child: Container(
              color: Colors.grey,
              padding: const EdgeInsets.all(16),
              child: const Text(
                "这里是角色占位符",
                style: TextStyle(fontSize: 28, color: Colors.white),
              ),
            ),
          ),

          // 3. UI 交互层 (对应组员 D 的模块) [4, 6]
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.4,
              height: MediaQuery.of(context).size.height * 0.35,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: UIWidgets(controller: controller),
            ),
          ),

          // 4. 上拉菜单入口 [7]
          Positioned(
            bottom: 0,
            left: MediaQuery.of(context).size.width * 0.05,
            child: Container(
              color: Colors.grey,
              width: MediaQuery.of(context).size.width * 0.15,
              height: MediaQuery.of(context).size.height * 0.15,
              padding: const EdgeInsets.all(16),
              child: const Icon(
                Icons.keyboard_arrow_up,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
