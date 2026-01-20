import 'package:flutter/material.dart';
import 'ui_widgets.dart'; // 引入组件库

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 隐藏 Debug 标签
      home: TestPage(),
    );
  }
}

// 模拟测试页面 (模拟组员 C 的 AppController)
class TestPage extends StatefulWidget {
  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  // === 模拟状态数据 ===
  int _seconds = 1500;       // 倒计时 (25分钟)
  bool _isActive = false;    // 是否运行中

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF7AE), // 奶油黄背景
      
      body: Stack(
        children: [
          // 1. 背景层：模拟 Live2D 小人
          Center(
            child: Opacity(
              opacity: 0.2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 200, color: Colors.blueGrey),
                  Text("Live2D Character Placeholder"),
                ],
              ),
            ),
          ),

          // 2. UI 层：你的组件
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 60), // 顶部留白
                
                // ⬇️ 倒计时组件
                PomodoroTimer(
                  seconds: _seconds, 
                  totalSeconds: 1500
                ),
                
                Spacer(), // 把中间撑开
                
                // ⬇️ Dock 栏组件
                DockBar(
                  isActive: _isActive,
                  
                  // 1. 点击播放/暂停 -> toggleTimer
                  onToggleTimer: () {
                    setState(() {
                      _isActive = !_isActive;
                      if (_isActive) _seconds -= 10; // 模拟跑秒
                    });
                    print("调用接口: toggleTimer()");
                  },
                  
                  // 2. 长按 -> resetTimer (新增)
                  onResetTimer: () {
                    setState(() {
                      _isActive = false;
                      _seconds = 1500; // 重置回 25:00
                    });
                    print("调用接口: resetTimer()");
                  },
                  
                  // 3. 点击统计 -> fetchHistoryData
                  onShowStats: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => StatsPanel(
                        totalMinutes: 45, 
                        totalDays: 3,
                      ),
                    );
                    print("调用接口: fetchHistoryData()");
                  },
                ),
                
                SizedBox(height: 40), // 底部留白
              ],
            ),
          ),
        ],
      ),
    );
  }
}


