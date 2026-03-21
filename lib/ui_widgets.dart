// UI 组件模块 - 负责界面组件和交互（组员 D 维护）
// library ui_widgets; // ✅ 建议删掉：会触发 “Library names are not necessary”

import 'dart:async';
import 'package:flutter/material.dart';
import 'app_controller.dart';
import 'character_view.dart';

// ==========================================
// 2. 底部菜单栏 (DockBar)
// 功能：放置操作按钮，触发逻辑方法
// 对应接口规范：toggleTimer, resetTimer, fetchHistoryData
// ==========================================
// ✅ 关键修复：DockBar 必须在文件顶层定义，不能写在 build() 里
/// DockBar - 底部操作栏组件
/// 负责显示：统计、播放/暂停、重置、分享等操作按钮
/// 说明：
///   - 只负责UI和点击事件，具体逻辑由外部传入回调实现
///   - 新增重置按钮（单独icon）、分享按钮（单独icon）
///   - 保留原有注释，新增注释解释新功能
class DockBar extends StatelessWidget {
  final bool isActive;                // 是否正在计时 (控制按钮颜色/图标)
  final VoidCallback onToggleTimer;   // 点击回调 -> 切换开始/暂停
  final VoidCallback onResetTimer;    // 点击重置按钮 -> 重置计时器
  final VoidCallback onShowStats;     // 点击统计按钮 -> 获取历史数据
  final VoidCallback onShare;         // 点击分享按钮 -> 生成分享卡片

  const DockBar({
    super.key,
    required this.isActive,
    required this.onToggleTimer,
    required this.onResetTimer,
    required this.onShowStats,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      // width: 360, // 【修复】注释掉固定宽度，防止小屏手机左右溢出（导致右侧黄色条纹）
      // 【修复】使用 constraints 限制最大宽度，这样大屏保持胶囊状，小屏自动收缩
      constraints: const BoxConstraints(maxWidth: 260), 
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(45),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 📊 统计按钮（左侧）
          IconButton(
            icon: Icon(Icons.bar_chart_rounded, size: 22, color: Colors.grey),
            onPressed: onShowStats,
            tooltip: '学习统计',
          ),

          // 🔄 重置按钮
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 22, color: Colors.grey),
            onPressed: onResetTimer,
            tooltip: '重置计时',
          ),

          // ▶️/⏸️ 播放/暂停按钮
          GestureDetector(
            behavior: HitTestBehavior.opaque, // [DEBUG] 点击区域更稳定（调试完可删）
            onTap: () {
              // [DEBUG] DockBar 播放键点击调试（确认 tap 事件有没有触发）
              debugPrint('[DEBUG][DockBar] Play/Pause tapped. isActive=$isActive');

              onToggleTimer();
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? Color(0xFFFF6B6B) : Color(0xFF2D3436),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                ],
              ),
              child: Icon(
                isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),

          // 📤 分享按钮
          IconButton(
            icon: Icon(Icons.share_rounded, size: 22, color: Colors.grey),
            onPressed: onShare,
            tooltip: '生成分享卡片',
          ),

          // ⚙️ 设置按钮（占位）
          IconButton(
            icon: Icon(Icons.settings_rounded, size: 22, color: Colors.grey),
            onPressed: () {},
            tooltip: '设置',
          ),
        ],
      ),
    );
  }
}

/// 前端交互面板：监听状态并更新 UI 面板与统计图表
class UIWidgets extends StatefulWidget {
  final AppController controller;
  const UIWidgets({super.key, required this.controller});

  @override
  State<UIWidgets> createState() => _UIWidgetsState();
}

class _UIWidgetsState extends State<UIWidgets> {
  Timer? _fakeTimer;
  double _fakeProgress = 0.0;

  // ===============================
  // 【新增】用于监听 controller.isActive 的变化
  // 为什么要加？
  // - 你原来是在 ValueListenableBuilder 的 builder 里 start/stop timer
  // - 但 builder 可能被多次触发，导致 timer 频繁重建（副作用写在 build 里是 Flutter 大忌）
  // - 正确做法是：监听 isActive 变化时再 start/stop
  // ===============================
  late final VoidCallback _activeListener;

  @override
  void initState() {
    super.initState();

    // ===============================
    // 【新增】初始化监听器：当 isActive.value 变化时触发
    // - active=true：启动假进度条动画
    // - active=false：停止假进度条动画
    // ===============================
    _activeListener = () {
      final bool active = widget.controller.isActive.value;

      // [DEBUG] isActive 监听触发调试（确认 controller.isActive 是否真的发生变化）
      debugPrint('[DEBUG][UIWidgets] isActive changed -> $active');

      if (active) {
        _startFakeProgress();
      } else {
        _stopFakeProgress();
      }
    };

    // ===============================
    // 【新增】注册监听
    // ===============================
    widget.controller.isActive.addListener(_activeListener);

    // ===============================
    // 【新增】初始化时同步一次（防止页面首次进入 active=true 但 UI 没开假动画）
    // ===============================
    _activeListener();
  }

  @override
  void dispose() {
    // ===============================
    // 【新增】取消监听，防止内存泄漏
    // ===============================
    widget.controller.isActive.removeListener(_activeListener);

    _fakeTimer?.cancel();
    super.dispose();
  }

  // ===============================
  // UI 假进度动画（仅用于 MVP 演示）
  // 后续由 controller.remainingSeconds 接管
  // ===============================
  void _startFakeProgress() {
    // ===============================
    // 【修改】避免重复创建多个 Timer
    // - 如果 timer 已经在跑，就不要再 new Timer.periodic
    // ===============================
    if (_fakeTimer != null && _fakeTimer!.isActive) return;

    // [DEBUG] 假进度条启动调试
    debugPrint('[DEBUG][UIWidgets] _startFakeProgress()');

    _fakeTimer?.cancel();
    _fakeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _fakeProgress += 0.002;
        if (_fakeProgress >= 1.0) _fakeProgress = 0.0;
      });
    });
  }

  void _stopFakeProgress() {
    // [DEBUG] 假进度条停止调试
    debugPrint('[DEBUG][UIWidgets] _stopFakeProgress()');

    _fakeTimer?.cancel();
    _fakeTimer = null;
  }

  // ===============================
  // 【新增】重置假进度条（配合 reset 按钮）
  // 为什么要加？
  // - 你原来 resetTimer 只会重置 controller 的真实计时
  // - 但 UI 假进度不会归零，看起来像“重置按钮没效果”
  // ===============================
  void _resetFakeProgress() {
    // [DEBUG] 假进度条重置调试
    debugPrint('[DEBUG][UIWidgets] _resetFakeProgress()');

    setState(() {
      _fakeProgress = 0.0;
    });
  }

  // ===============================
  // 人物动画接口（UI 占位）
  // 说明：
  // - 这里就是“动画小人”未来要放的位置
  // - active=true：播放动作
  // - active=false：待机动作
  // ===============================
  Widget _buildCharacterStage(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.isActive,
      builder: (context, active, _) {
        debugPrint('[DEBUG][CharacterStage] active=$active');
        return CharacterView(isActive: active);
      },
    );
  }

  // ===============================
  // 统计面板弹窗（UI 占位）
  // ===============================
  void _showStatsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('学习统计', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('• 今日专注：1.5 小时'),
            Text('• 累计天数：7 天'),
            SizedBox(height: 12),
            Text(
              '（此处为统计面板 UI 占位，后端数据接入后替换）',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 【布局调整】使用 Stack（层叠布局）替换原来的 Column（垂直布局）
    // 理由：Stack 允许元素重叠，实现“全屏背景”+“悬浮 UI”的效果
    return Scaffold(
      backgroundColor: Colors.transparent, // 背景透明，方便透出后面的元素（如果有）
      body: Stack(
        children: [
          // ------------------------------------------------
          // 第一层（最底层）：全屏人物动画
          // ------------------------------------------------
          Positioned.fill(
            child: _buildCharacterStage(context),
          ),
      
          // ------------------------------------------------
          // 第二层（悬浮层）：左上角的控制区 (Dock + 进度条)
          // ------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0), // 留点边距
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. 进度条 (变小了)
                    // 【布局调整】限制宽度为 260，使其更精致，放在 Dock 上方
                    SizedBox(
                      width: 260, 
                      child: LinearProgressIndicator(
                        value: _fakeProgress,
                        minHeight: 8, //稍微变细一点
                        backgroundColor: Colors.white24,
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    
                    const SizedBox(height: 12), // 间距
      
                    // 2. Dock 栏
                    // 这里直接复用 DockBar，因为父级是 Column(left对齐)，所以它会靠左显示
                    ValueListenableBuilder<bool>(
                      valueListenable: widget.controller.isActive,
                      builder: (context, active, _) {
                        return DockBar(
                          isActive: active,
                          onToggleTimer: () => widget.controller.toggleTimer(),
                          onResetTimer: () {
                            widget.controller.resetTimer();
                            _resetFakeProgress();
                          },
                          onShowStats: () {
                            widget.controller.fetchHistoryData();
                            _showStatsPanel(context);
                          },
                          onShare: () {
                            _showShareCard(context, widget.controller);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      
          // ------------------------------------------------
          // 第三层（悬浮层）：底部的日期和时间
          // ------------------------------------------------
          // 【布局调整】把日期时间固定在屏幕底部中央
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: widget.controller.currentDate,
                    builder: (context, dateString, _) {
                      return Text(
                        dateString,
                        // 加了阴影，防止背景太白导致文字看不清
                        style: TextStyle(
                          fontSize: 14, 
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black45, offset: Offset(1,1))]
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: widget.controller.remainingSeconds,
                    builder: (context, seconds, _) {
                      final time =
                          "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";
                      return Text(
                        time,
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.orange,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black45, offset: Offset(1,1))]
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================
// 分享卡片弹窗（UI占位，后端/设计提供模板后对接）
// ===============================
void _showShareCard(BuildContext context, AppController controller) {
  final int seconds = controller.remainingSeconds.value;
  final double hours = (kDefaultPomodoroSeconds - seconds) / 3600.0;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('今日学习时长'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('今日学习：${hours.toStringAsFixed(2)} 小时'),
          SizedBox(height: 16),
          Text(
            '（此处为分享卡片占位，后端/设计提供模板后替换）',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('关闭'),
        ),
      ],
    ),
  );
}





