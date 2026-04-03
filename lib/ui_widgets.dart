import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:ui';

import 'app_controller.dart';
import 'character_view.dart';

/// UIWidgets 负责应用主界面的可视化和交互：
/// - 番茄钟控制卡片、时间进度条、开始/暂停/重置按钮；
/// - 设置面板支持专注/休息/循环加减调整；
/// - XP/等级信息显示与“鸡公煲队”团队 logo；
/// - 桌面角色/对话气泡等视觉组件组合。
class UIWidgets extends StatefulWidget {
  final AppController controller;
  const UIWidgets({super.key, required this.controller});

  @override
  State<UIWidgets> createState() => _UIWidgetsState();
}

class _UIWidgetsState extends State<UIWidgets> {
  bool _isTomatoExpanded = false;
  bool _isStatsExpanded = false;
  bool _isExpExpanded = false;

  bool _isTomatoScaling = false;
  bool _isExpScaling = false;
  bool _isStatsScaling = false;

  bool _isVolumePanelOpen = false; // 音量栏开关
  bool _isInteractingWithVolume = false; // 滑动音量时避免全局 onTap 关闭面板
  bool _isPomodoroConfigOpen = false;
  final TextEditingController _focusMinutesController = TextEditingController();
  final TextEditingController _restMinutesController = TextEditingController();
  final TextEditingController _cycleCountController = TextEditingController();

  PomodoroPhaseStatus get _phaseStatus => widget.controller.phaseStatus.value;
  bool get _isTimerRunning => _phaseStatus == PomodoroPhaseStatus.running;

  @override
  void dispose() {
    _focusMinutesController.dispose();
    _restMinutesController.dispose();
    _cycleCountController.dispose();
    super.dispose();
  }

  double get _currentProgress {
    final int total = widget.controller.currentPhaseDurationSeconds;
    if (total <= 0) {
      return 0;
    }
    final int remaining = widget.controller.remainingSeconds.value.clamp(0, total);
    // 使用“剩余/总时长”作为进度显示，使进度条随时间减少而变短。
    return (remaining / total).clamp(0.0, 1.0);
  }

  void _openPomodoroConfig() {
    if (_isTimerRunning) {
      return;
    }

    setState(() {
      _isPomodoroConfigOpen = true;
      _focusMinutesController.text =
          (widget.controller.focusDurationSeconds.value ~/ 60).toString();
      _restMinutesController.text =
          (widget.controller.restDurationSeconds.value ~/ 60).toString();
      _cycleCountController.text =
          widget.controller.cycleCount.value?.toString() ?? '';
    });
  }

  void _closePomodoroConfig() {
    setState(() {
      _isPomodoroConfigOpen = false;
    });
  }

  void _triggerScaleAnimation(String type) {
    setState(() {
      if (type == 'tomato') {
        _isTomatoScaling = true;
      } else if (type == 'exp') {
        _isExpScaling = true;
      } else if (type == 'stats') {
        _isStatsScaling = true;
      }
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      setState(() {
        if (type == 'tomato') {
          _isTomatoScaling = false;
        } else if (type == 'exp') {
          _isExpScaling = false;
        } else if (type == 'stats') {
          _isStatsScaling = false;
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final int safeSeconds = seconds < 0 ? 0 : seconds;
    final int totalHours = safeSeconds ~/ 3600;
    final int totalMinutes = (safeSeconds % 3600) ~/ 60;
    final String minutesText = totalMinutes.toString().padLeft(2, '0');
    final String secondsText = (safeSeconds % 60).toString().padLeft(2, '0');

    if (totalHours <= 0) {
      final String shortMinutesText = (safeSeconds ~/ 60).toString().padLeft(2, '0');
      return '$shortMinutesText:$secondsText';
    }

    return '$totalHours:$minutesText:$secondsText';
  }

  void _savePomodoroConfig() {
    if (_isTimerRunning) {
      _closePomodoroConfig();
      return;
    }

    // 由于按钮即时生效，保存即关闭配置面板。
    _closePomodoroConfig();
  }

  void _changeFocusMinutes(int delta) {
    final int current = widget.controller.focusDurationSeconds.value ~/ 60;
    final int updated = max(1, current + delta);
    widget.controller.updateFocusDuration(updated * 60);
    _focusMinutesController.text = updated.toString();
  }

  void _changeRestMinutes(int delta) {
    final int current = widget.controller.restDurationSeconds.value ~/ 60;
    final int updated = max(1, current + delta);
    widget.controller.updateRestDuration(updated * 60);
    _restMinutesController.text = updated.toString();
  }

  void _changeCycleCount(int delta) {
    final int current = widget.controller.cycleCount.value ?? 0;
    final int updated = max(0, current + delta);
    widget.controller.updateCycleCount(updated == 0 ? null : updated);
    _cycleCountController.text = updated.toString();
  }

  Widget _buildAdjustRow({
    required String label,
    required int value,
    required VoidCallback onIncrease,
    required VoidCallback onDecrease,
    required VoidCallback onSuperIncrease,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border.all(color: const Color(0xFFBCAAA4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF5D4037),
                fontFamily: 'ZCOOLKuaiLe-Regular',
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 40,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1E2D8),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFBCAAA4)),
            ),
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
                fontFamily: 'ZCOOLKuaiLe-Regular',
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              onPressed: onDecrease,
              icon: const Icon(Icons.remove, size: 16),
              color: const Color(0xFF6D4C41),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              onPressed: onIncrease,
              icon: const Icon(Icons.add, size: 16),
              color: const Color(0xFF6D4C41),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              onPressed: onSuperIncrease,
              icon: const Icon(Icons.keyboard_double_arrow_up, size: 16),
              color: const Color(0xFF6D4C41),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  void _restorePomodoroDefaults() {
    if (_isTimerRunning) {
      return;
    }

    widget.controller.restoreDefaultDurations();
    _focusMinutesController.text =
        (widget.controller.focusDurationSeconds.value ~/ 60).toString();
    _restMinutesController.text =
        (widget.controller.restDurationSeconds.value ~/ 60).toString();
  }

  void _closeAllPanels() {
    setState(() {
      _isTomatoExpanded = false;
      _isStatsExpanded = false;
      _isExpExpanded = false;
      _isPomodoroConfigOpen = false;
    });
  }

  Widget _buildCharacterStage(BuildContext context) {
    return ValueListenableBuilder<PomodoroState>(
      valueListenable: widget.controller.pomodoroState,
      builder: (context, state, _) {
        return CharacterView(isActive: state == PomodoroState.studying);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(fontFamily: 'ZCOOLKuaiLe-Regular'),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (!_isInteractingWithVolume) {
            _closeAllPanels();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(child: _buildCharacterStage(context)),
            Positioned(
              bottom: 120,
              right: 40,
              child: ValueListenableBuilder<int>(
                valueListenable: widget.controller.level,
                builder: (context, level, _) {
                  return ChatBubble(
                    text: widget.controller.dialogueLockReason(level + 1),
                    onNext: () {},
                    onSkip: () {},
                  );
                },
              ),
            ),
            Positioned(top: 15, left: 20, child: _buildTomatoTimerDrop()),
            Positioned(top: 20, left: 50, child: _buildExpBarDrop()),
            Positioned(top: 15, right: 28, child: _buildBlackboardStatsDrop()),
            Positioned(bottom: 10, left: 15, child: _buildRecordPlayer()),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildTomatoTimerDrop() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_isTomatoExpanded && _isPomodoroConfigOpen)
          const SizedBox(width: 360, height: 300),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                _triggerScaleAnimation('tomato');
                setState(() {
                  _isTomatoExpanded = !_isTomatoExpanded;
                  if (_isTomatoExpanded) {
                    _isStatsExpanded = false;
                    _isExpExpanded = false;
                    _isPomodoroConfigOpen = false;
                  }
                });
              },
                child: AnimatedScale(
                scale: _isTomatoScaling ? 0.9 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/tomato_btn.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: _isTomatoExpanded ? 160 : 0,
              width: 180,
              margin: EdgeInsets.only(top: _isTomatoExpanded ? 10 : 0),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                image: _isTomatoExpanded
                    ? const DecorationImage(
                        image: AssetImage('assets/images/memo_bg.png'),
                        fit: BoxFit.fill,
                      )
                    : null,
              ),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 33),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ValueListenableBuilder<PomodoroState>(
                          valueListenable: widget.controller.pomodoroState,
                          builder: (context, state, _) {
                            // 点击展开时如果处于 ready（未开始），按产品期望显示为专注模式（红色）。
                            final bool isStudying = state == PomodoroState.studying ||
                                widget.controller.phaseStatus.value == PomodoroPhaseStatus.ready;

                            // 对于专注阶段，进度条按“已流逝比例”增长（从空到满）；
                            // 对于休息阶段，进度条按“剩余比例”减少（从满到空）。
                            // 统一使用剩余比例显示进度（无论专注或休息，都是从满到空）
                            final double progressValue = _currentProgress.clamp(0.0, 1.0);

                            final Color progressColor = isStudying ? Colors.redAccent : Colors.green;
                            final Color backgroundColor = isStudying ? Colors.red.shade100 : Colors.green.shade100;

                            return SizedBox(
                              width: 70,
                              height: 70,
                              child: CircularProgressIndicator(
                                value: progressValue.clamp(0.0, 1.0),
                                color: progressColor,
                                backgroundColor: backgroundColor,
                                strokeWidth: 6,
                              ),
                            );
                          },
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: widget.controller.remainingSeconds,
                          builder: (BuildContext context, int seconds, Widget? child) {
                            return Text(
                              _formatTime(seconds),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5D4037),
                                fontFamily: 'ZCOOLKuaiLe-Regular',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          color: const Color(0xFF5D4037),
                          onPressed: () {
                            widget.controller.resetTimer();
                          },
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: widget.controller.isActive,
                          builder: (context, isActive, _) {
                            return IconButton(
                              icon: Icon(
                                isActive ? Icons.pause : Icons.play_arrow,
                                size: 28,
                              ),
                              color: const Color(0xFF5D4037),
                              onPressed: widget.controller.toggleTimer,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          color: const Color(0xFF5D4037),
                          onPressed: _isTimerRunning ? null : _openPomodoroConfig,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 10,
          left: 175,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              height: (_isTomatoExpanded && _isPomodoroConfigOpen) ? 265 : 0,
              width: (_isTomatoExpanded && _isPomodoroConfigOpen) ? 200 : 0,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                border: Border.all(color: const Color(0xFF795548), width: 1),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isTimerRunning ? 0.45 : 1.0,
                              child: IgnorePointer(
                                ignoring: _isTimerRunning,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '专注/休息/循环(次)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF5D4037),
                                        fontFamily: 'ZCOOLKuaiLe-Regular',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ValueListenableBuilder<int>(
                                      valueListenable: widget.controller.focusDurationSeconds,
                                      builder: (context, value, _) => _buildAdjustRow(
                                        label: '专注(分)',
                                        value: value ~/ 60,
                                        onIncrease: () => _changeFocusMinutes(1),
                                        onDecrease: () => _changeFocusMinutes(-1),
                                        onSuperIncrease: () => _changeFocusMinutes(10),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    ValueListenableBuilder<int>(
                                      valueListenable: widget.controller.restDurationSeconds,
                                      builder: (context, value, _) => _buildAdjustRow(
                                        label: '休息(分)',
                                        value: value ~/ 60,
                                        onIncrease: () => _changeRestMinutes(1),
                                        onDecrease: () => _changeRestMinutes(-1),
                                        onSuperIncrease: () => _changeRestMinutes(10),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    ValueListenableBuilder<int?>(
                                      valueListenable: widget.controller.cycleCount,
                                      builder: (context, value, _) => _buildAdjustRow(
                                        label: '循环(次)',
                                        value: value ?? 0,
                                        onIncrease: () => _changeCycleCount(1),
                                        onDecrease: () => _changeCycleCount(-1),
                                        onSuperIncrease: () => _changeCycleCount(10),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: _restorePomodoroDefaults,
                                        child: const Text(
                                          '恢复默认时间（25/5）',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF5D4037),
                                            fontFamily: 'ZCOOLKuaiLe-Regular',
                                          ),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                          onPressed: _closePomodoroConfig,
                                          child: const Text(
                                            '取消',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                              fontFamily: 'ZCOOLKuaiLe-Regular',
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _savePomodoroConfig,
                                          child: const Text(
                                            '保存',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF5D4037),
                                              fontFamily: 'ZCOOLKuaiLe-Regular',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_isTimerRunning)
                              const Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color.fromRGBO(255, 255, 255, 0.12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpBarDrop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            _triggerScaleAnimation('exp');
            setState(() {
              _isExpExpanded = !_isExpExpanded;
              if (_isExpExpanded) {
                _isTomatoExpanded = false;
                _isStatsExpanded = false;
              }
            });
          },
          child: AnimatedScale(
            scale: _isExpScaling ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 120,
              height: 42,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/scroll_rolled.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          height: _isExpExpanded ? 160 : 0,
          width: 180,
          margin: const EdgeInsets.only(top: 8),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            image: _isExpExpanded
                ? const DecorationImage(
                    image: AssetImage('assets/images/scroll_unrolled.png'),
                    fit: BoxFit.fill,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: _isExpExpanded ? Colors.black26 : Colors.transparent,
                blurRadius: _isExpExpanded ? 5.0 : 0.0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: widget.controller.level,
                    builder: (context, level, _) {
                      return Text(
                        'Lv. $level 学徒',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.brown[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'ZCOOLKuaiLe-Regular',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: widget.controller.totalXp,
                    builder: (context, _, _) {
                      final int minutes = widget.controller.minutesToNextLevel;
                      final String text = minutes == 0
                          ? '已达到当前最高等级'
                          : '再专注 $minutes 分钟\n即可升级';
                      return Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.brown[800],
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: 'ZCOOLKuaiLe-Regular',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlackboardStatsDrop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () {
            _triggerScaleAnimation('stats');
            setState(() {
              _isStatsExpanded = !_isStatsExpanded;
              if (_isStatsExpanded) {
                _isTomatoExpanded = false;
                _isExpExpanded = false;
              }
            });
            if (_isStatsExpanded) {
              widget.controller.fetchHistoryData();
            }
          },
          child: AnimatedScale(
            scale: _isStatsScaling ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
                width: 64,
                height: 64,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/board_btn.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -40),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: Alignment.topRight,
            height: _isStatsExpanded ? 240 : 0,
            width: 280,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              image: _isStatsExpanded
                  ? const DecorationImage(
                      image: AssetImage('assets/images/board_panel.png'),
                      fit: BoxFit.fill,
                    )
                  : null,
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: 280,
                width: 320,
                child: Stack(
                  children: [
                    //（水印已移除）
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 50.0,
                        top: 50.0,
                        right: 30.0,
                        bottom: 20.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: widget.controller.dailyXp,
                            builder: (context, dailyXp, _) {
                              return Text(
                                '今日学习时长：$dailyXp',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 19,
                                  fontFamily: 'ZhuoKai',
                                  shadows: const [
                                    BoxShadow(color: Colors.white38, blurRadius: 3),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          ValueListenableBuilder<int>(
                            valueListenable: widget.controller.totalXp,
                            builder: (context, totalXp, _) {
                              return Text(
                                '累计学习时长：$totalXp',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 19,
                                  fontFamily: 'ZhuoKai',
                                  shadows: const [
                                    BoxShadow(color: Colors.white38, blurRadius: 3),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 70,
                      right: 35,
                      child: GestureDetector(
                        onTap: () {
                          _showAboutUsDialog(context, widget.controller);
                        },
                            child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '关于我们',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontFamily: 'ZhuoKai',
                                shadows: const [
                                  BoxShadow(color: Colors.white38, blurRadius: 2),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 64,
                              height: 44,
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage('assets/images/eraser_btn.png'),
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    //（小字水印已移除）
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordPlayer() {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.isMusicPlaying,
      builder: (context, isMusicPlaying, _) {
        // 使用 Stack 在音量按钮上方弹出音量滑块（浮层）
        // 注意：指定高度以保证播放器始终可见（避免 Stack 仅包含 Positioned 时高度为 0 的问题）。
        return SizedBox(
          width: 320,
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 主播放器条
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  width: 320,
                  height: 80,
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/record_bg.png'),
                      fit: BoxFit.fill,
                    ),
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 12),
                      Image.asset(
                        'assets/images/record_disk.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.controller.playPreviousTrack,
                        child: Image.asset(
                          'assets/images/btn_prev.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: widget.controller.playOrPauseMusic,
                        child: Image.asset(
                          isMusicPlaying ? 'assets/images/btn_pause.png' : 'assets/images/btn_play.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: widget.controller.playNextTrack,
                        child: Image.asset(
                          'assets/images/btn_next.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 音量按钮——点击展开浮层
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isVolumePanelOpen = !_isVolumePanelOpen;
                          });
                        },
                        child: Image.asset(
                          'assets/images/btn_music.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),

              // 浮层：在音量图标上方弹出
              if (_isVolumePanelOpen)
                Positioned(
                  // 在音量按钮上方弹出竖向滑块
                  bottom: 70,
                  right: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 48,
                      height: 160,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: ValueListenableBuilder<double>(
                        valueListenable: widget.controller.musicVolume,
                        builder: (context, volume, _) {
                          return Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              const Icon(Icons.volume_up, color: Colors.white, size: 18),
                              const SizedBox(height: 6),
                              Expanded(
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 6,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                    ),
                                    child: Slider(
                                      value: volume,
                                      min: 0,
                                      max: 1,
                                      activeColor: Colors.orangeAccent,
                                      inactiveColor: Colors.white30,
                                      onChangeStart: (v) {
                                        setState(() {
                                          _isInteractingWithVolume = true;
                                        });
                                      },
                                      onChangeEnd: (v) {
                                        setState(() {
                                          _isInteractingWithVolume = false;
                                        });
                                      },
                                      onChanged: (newValue) {
                                        widget.controller.setMusicVolume(newValue);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(volume > 0 ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 18),
                                onPressed: () {
                                  if (volume > 0) {
                                    widget.controller.setMusicVolume(0.0);
                                  } else {
                                    widget.controller.setMusicVolume(1.0);
                                  }
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

void _showAboutUsDialog(BuildContext context, AppController controller, [String aboutText = '''鸡公煲队 (Rooster Stewdio)

由 4 人团队历时 60 天精心慢炖而成。
鸡公煲队正式入驻！
我们是一个由四位开发者组成的独立团队。
我们热爱简洁的设计与纯粹的交互，
致力于在方寸屏幕间构建有趣的灵魂。
感谢你拨冗体验我们的作品，
你的支持是我们不断迭代的动力。
制作团队：
主厨：陈柏森
摆盘专家：刘思源
汤底架构师：姚博闻
灵魂调味师：陈逸宇

“加辣、加汤、不加 Bug！”''']) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFFF4E8C1),
      contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 圆形 logo（硬裁切）：请把图片放在 assets/images/about_logo.png
              CircleAvatar(
                radius: 28,
                backgroundImage: const AssetImage('assets/images/about_logo.png'),
                backgroundColor: Colors.transparent,
              ),
              const SizedBox(height: 8),
              const Text(
                'ABOUT US',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                aboutText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('CLOSE', style: TextStyle(color: Colors.brown)),
        ),
      ],
    ),
  );
}

class ChatBubble extends StatefulWidget {
  final String text;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const ChatBubble({super.key, required this.text, required this.onNext, required this.onSkip});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  String _displayedText = '';
  Timer? _timer;
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTypewriterEffect();
  }

  @override
  void didUpdateWidget(covariant ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _startTypewriterEffect();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTypewriterEffect() {
    _timer?.cancel();
    setState(() {
      _displayedText = '';
      _charIndex = 0;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (_charIndex < widget.text.length) {
        setState(() {
          _charIndex++;
          _displayedText = widget.text.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _fastForwardSentence() {
    // 找到从当前 _charIndex 开始的本句结束位置（以常见中文/英文句号或问号为界）
    if (_charIndex >= widget.text.length) {
      return;
    }
    final String rest = widget.text.substring(_charIndex);
    final RegExp sentenceEnd = RegExp(r'[。！？!?\.]');
    final Match? m = sentenceEnd.firstMatch(rest);
    int targetIndex;
    if (m != null) {
      targetIndex = _charIndex + m.end; // 包含标点
    } else {
      targetIndex = widget.text.length; // 没有标点则直接到句尾
    }

    setState(() {
      _charIndex = targetIndex.clamp(0, widget.text.length);
      _displayedText = widget.text.substring(0, _charIndex);
    });
    // 如果还在计时器中，继续保留定时器使后续句子仍以打字效果出现
    // 但如果已经到末尾则取消
    if (_charIndex >= widget.text.length) {
      _timer?.cancel();
    }
  }

  void _fastForwardOrSkip() {
    // 若仍在逐字显示，则先按“到本句末尾”处理；若已全部显示，则调用外部跳过行为
    if (_charIndex < widget.text.length) {
      _fastForwardSentence();
      return;
    }
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.bottomRight,
          child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240, minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayedText,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Color(0xFF5D4037),
                    fontFamily: 'ZCOOLKuaiLe-Regular',
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
            Positioned(
              bottom: -5,
              right: -5,
              child: GestureDetector(
                onTap: _fastForwardOrSkip,
                child: const Icon(
                  Icons.fast_forward_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
