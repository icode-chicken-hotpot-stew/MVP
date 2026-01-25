// UI 组件模块 - 负责界面组件和交互（组员 D 维护）
library ui_widgets;

import 'package:flutter/material.dart';
import 'app_controller.dart';

/// 前端交互面板：监听状态并更新 UI 面板与统计图表
class UIWidgets extends StatelessWidget {
  final AppController controller;
  const UIWidgets({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 进度条：监听秒数变化，自动重绘（顶部）
          ValueListenableBuilder<int>(
            valueListenable: controller.remainingSeconds,
            builder: (context, seconds, child) {
              final double progress = seconds / kDefaultPomodoroSeconds;
              return LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white24,
                color: Colors.orange,
              );
            },
          ),

          const SizedBox(height: 10),

          // 2. 交互按钮：调用控制器方法
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                style: buttonStyle,
                onPressed: () => controller.toggleTimer(),
                child: ValueListenableBuilder<bool>(
                  valueListenable: controller.isActive,
                  builder: (context, active, _) => Text(active ? "暂停" : "开始"),
                ),
              ),
              ElevatedButton(
                style: buttonStyle,
                onPressed: () => controller.resetTimer(),
                child: const Text("重置"),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 3. 日期（左）和时间（右）显示（底部）
          // 将 Row 作为静态结构，日期和时间分别独立监听各自的状态
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 日期：左侧 - 独立监听 currentDate
              ValueListenableBuilder<String>(
                valueListenable: controller.currentDate,
                builder: (context, dateString, child) {
                  return Text(
                    dateString,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              // 时间：右侧 - 独立监听 remainingSeconds
              ValueListenableBuilder<int>(
                valueListenable: controller.remainingSeconds,
                builder: (context, seconds, child) {
                  final String timeString =
                      "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";
                  return Text(
                    timeString,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
