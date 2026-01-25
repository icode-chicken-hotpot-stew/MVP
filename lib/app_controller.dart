// 应用控制器模块 - 逻辑中枢（组员 C 维护）
library app_controller;

import 'package:flutter/material.dart';

/// 中枢控制器：管理应用全局状态，通过 ValueNotifier 向 View 层广播
class AppController {
  // ============ 状态广播接口 ============
  /// 倒计时秒数（默认 1500 秒 = 25 分钟）
  final ValueNotifier<int> remainingSeconds;

  /// 计时器运行状态
  final ValueNotifier<bool> isActive;

  /// 上拉菜单状态
  final ValueNotifier<bool> isDrawerOpen;

  /// 格式化日期字符串
  final ValueNotifier<String> currentDate;

  /// 格式化当前日期
  static String _formatCurrentDate() {
    final now = DateTime.now();
    return '${now.year}年${now.month}月${now.day}日';
  }

  AppController({
    int initialSeconds = 1500,
    bool initialActive = false,
    bool initialDrawerOpen = false,
    String? initialDate,
  }) : remainingSeconds = ValueNotifier<int>(initialSeconds),
       isActive = ValueNotifier<bool>(initialActive),
       isDrawerOpen = ValueNotifier<bool>(initialDrawerOpen),
       currentDate = ValueNotifier<String>(initialDate ?? _formatCurrentDate());

  // ============ 逻辑触发接口 ============
  /// 切换计时器的开始与暂停（由组员 C 填充逻辑）
  void toggleTimer() {
    // TODO: implement timer toggle logic
  }

  /// 重置番茄钟至初始状态（由组员 C 填充逻辑）
  void resetTimer() {
    // TODO: implement reset logic
  }

  /// 从本地存储读取历史时长数据（由组员 C 填充逻辑）
  void fetchHistoryData() {
    // TODO: implement history fetch logic
  }

  /// 释放所有 ValueNotifier 资源
  void dispose() {
    remainingSeconds.dispose();
    isActive.dispose();
    isDrawerOpen.dispose();
    currentDate.dispose();
  }
}
