import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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
  static const String _stageBackgroundAsset = 'assets/background_back.png';
  static const String _stageForegroundAsset = 'assets/background_front.png';

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

  double get _elapsedProgress {
    final int total = widget.controller.currentPhaseDurationSeconds;
    if (total <= 0) {
      return 0;
    }
    final int remaining = widget.controller.remainingSeconds.value.clamp(
      0,
      total,
    );
    return (1 - (remaining / total)).clamp(0.0, 1.0);
  }

  void _openPomodoroConfig() {
    widget.controller.registerUserInteraction();

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
    unawaited(widget.controller.triggerUiOpenSfx());
  }

  void _closePomodoroConfig() {
    if (!_isPomodoroConfigOpen) {
      return;
    }

    widget.controller.registerUserInteraction();
    setState(() {
      _isPomodoroConfigOpen = false;
    });
    unawaited(widget.controller.triggerUiBackSfx());
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
      final String shortMinutesText = (safeSeconds ~/ 60).toString().padLeft(
        2,
        '0',
      );
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
    final bool hasOpenPanels =
        _isTomatoExpanded ||
        _isStatsExpanded ||
        _isExpExpanded ||
        _isPomodoroConfigOpen;
    setState(() {
      _isTomatoExpanded = false;
      _isStatsExpanded = false;
      _isExpExpanded = false;
      _isPomodoroConfigOpen = false;
      _isVolumePanelOpen = false;
      _isInteractingWithVolume = false;
    });
    if (hasOpenPanels) {
      unawaited(widget.controller.triggerUiBackSfx());
    }
  }

  void _handleBlankTap() {
    if (_isInteractingWithVolume) {
      return;
    }

    _closeAllPanels();

    if (widget.controller.isTalking) {
      widget.controller.nextDialogue();
      return;
    }

    widget.controller.registerUserInteraction();
  }

  void _handleCharacterTap() {
    widget.controller.registerUserInteraction();
    unawaited(widget.controller.triggerDialogue('clicked'));
  }

  void _handleEntranceMotionStarted() {
    widget.controller.scheduleColdStartDialogueAfterEntrance();
  }

  Widget _buildCharacterStage(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        widget.controller.pomodoroState,
      ]),
      builder: (context, _) {
        return CharacterView(
          pomodoroState: widget.controller.pomodoroState.value,
          isTalking: widget.controller.isTalking,
          onCharacterTap: _handleCharacterTap,
          onEntranceMotionStarted: _handleEntranceMotionStarted,
        );
      },
    );
  }

  Widget _buildDialogueBubble() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.isTalking) {
          return const SizedBox.shrink();
        }

        return ChatBubble(
          text: widget.controller.currentDialogue,
          onNext: widget.controller.nextDialogue,
          onSkip: widget.controller.skipDialogue,
        );
      },
    );
  }

  Widget _buildStageBackground() {
    return const IgnorePointer(
      child: Image(image: AssetImage(_stageBackgroundAsset), fit: BoxFit.cover),
    );
  }

  Widget _buildStageForeground() {
    return const IgnorePointer(
      child: Image(image: AssetImage(_stageForegroundAsset), fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(fontFamily: 'ZCOOLKuaiLe-Regular'),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: _handleBlankTap,
          behavior: HitTestBehavior.deferToChild,
          child: Stack(
            children: [
              Positioned.fill(child: _buildStageBackground()),
              Positioned.fill(child: _buildCharacterStage(context)),
              Positioned.fill(child: _buildStageForeground()),
              Positioned(bottom: 120, right: 20, child: _buildDialogueBubble()),
              Positioned(top: 15, left: 20, child: _buildTomatoTimerDrop()),
              Positioned(top: 20, left: 50, child: _buildExpBarDrop()),
              Positioned(
                top: 15,
                right: 28,
                child: _buildBlackboardStatsDrop(),
              ),
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
                final bool nextTomatoExpanded = !_isTomatoExpanded;
                widget.controller.registerUserInteraction();
                _triggerScaleAnimation('tomato');
                setState(() {
                  _isTomatoExpanded = nextTomatoExpanded;
                  if (_isTomatoExpanded) {
                    _isStatsExpanded = false;
                    _isExpExpanded = false;
                    _isPomodoroConfigOpen = false;
                  }
                });
                if (nextTomatoExpanded) {
                  unawaited(widget.controller.triggerUiOpenSfx());
                } else {
                  unawaited(widget.controller.triggerUiBackSfx());
                }
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
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            widget.controller.remainingSeconds,
                            widget.controller.pomodoroState,
                            widget.controller.phaseStatus,
                          ]),
                          builder: (context, _) {
                            final PomodoroState state =
                                widget.controller.pomodoroState.value;

                            // 点击展开时如果处于 ready（未开始），按产品期望显示为专注模式（红色）。
                            final bool isStudying =
                                state == PomodoroState.studying ||
                                widget.controller.phaseStatus.value ==
                                    PomodoroPhaseStatus.ready;

                            // 环形条采用“已流逝=浅色、剩余=深色”视觉语义：
                            // 已流逝部分会沿顺时针逐步增大，从而呈现深色圈被持续消耗。
                            final double progressValue = _elapsedProgress.clamp(
                              0.0,
                              1.0,
                            );

                            final Color progressColor = isStudying
                                ? Colors.red.shade100
                                : Colors.green.shade100;
                            final Color backgroundColor = isStudying
                                ? Colors.red.shade700
                                : Colors.green.shade700;

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
                          builder:
                              (
                                BuildContext context,
                                int seconds,
                                Widget? child,
                              ) {
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
                          onPressed: _isTimerRunning
                              ? null
                              : _openPomodoroConfig,
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
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
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
                                      valueListenable: widget
                                          .controller
                                          .focusDurationSeconds,
                                      builder: (context, value, _) =>
                                          _buildAdjustRow(
                                            label: '专注(分)',
                                            value: value ~/ 60,
                                            onIncrease: () =>
                                                _changeFocusMinutes(1),
                                            onDecrease: () =>
                                                _changeFocusMinutes(-1),
                                            onSuperIncrease: () =>
                                                _changeFocusMinutes(10),
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    ValueListenableBuilder<int>(
                                      valueListenable:
                                          widget.controller.restDurationSeconds,
                                      builder: (context, value, _) =>
                                          _buildAdjustRow(
                                            label: '休息(分)',
                                            value: value ~/ 60,
                                            onIncrease: () =>
                                                _changeRestMinutes(1),
                                            onDecrease: () =>
                                                _changeRestMinutes(-1),
                                            onSuperIncrease: () =>
                                                _changeRestMinutes(10),
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    ValueListenableBuilder<int?>(
                                      valueListenable:
                                          widget.controller.cycleCount,
                                      builder: (context, value, _) =>
                                          _buildAdjustRow(
                                            label: '循环(次)',
                                            value: value ?? 0,
                                            onIncrease: () =>
                                                _changeCycleCount(1),
                                            onDecrease: () =>
                                                _changeCycleCount(-1),
                                            onSuperIncrease: () =>
                                                _changeCycleCount(10),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
            final bool nextExpExpanded = !_isExpExpanded;
            widget.controller.registerUserInteraction();
            _triggerScaleAnimation('exp');
            setState(() {
              _isExpExpanded = nextExpExpanded;
              if (_isExpExpanded) {
                _isTomatoExpanded = false;
                _isStatsExpanded = false;
              }
            });
            if (nextExpExpanded) {
              unawaited(widget.controller.triggerUiOpenSfx());
            } else {
              unawaited(widget.controller.triggerUiBackSfx());
            }
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 30.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: widget.controller.level,
                    builder: (context, level, _) {
                      return Text(
                        '【 Lv. $level 】\n${widget.controller.xpToNextLevel} XP',
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
            final bool nextStatsExpanded = !_isStatsExpanded;
            widget.controller.registerUserInteraction();
            _triggerScaleAnimation('stats');
            setState(() {
              _isStatsExpanded = nextStatsExpanded;
              if (_isStatsExpanded) {
                _isTomatoExpanded = false;
                _isExpExpanded = false;
              }
            });
            if (nextStatsExpanded) {
              unawaited(widget.controller.triggerUiOpenSfx());
            } else {
              unawaited(widget.controller.triggerUiBackSfx());
            }
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
                                    BoxShadow(
                                      color: Colors.white38,
                                      blurRadius: 3,
                                    ),
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
                                    BoxShadow(
                                      color: Colors.white38,
                                      blurRadius: 3,
                                    ),
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
                          widget.controller.registerUserInteraction();
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
                                  BoxShadow(
                                    color: Colors.white38,
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 64,
                              height: 44,
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(
                                    'assets/images/eraser_btn.png',
                                  ),
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
        return SizedBox(
          width: 240,
          height: _isVolumePanelOpen ? 260 : 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  width: 240,
                  height: 60,
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/record_bg.png'),
                      fit: BoxFit.fill,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 12),
                      Image.asset(
                        'assets/images/record_disk.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          widget.controller.registerUserInteraction();
                          unawaited(widget.controller.playPreviousTrack());
                        },
                        child: Image.asset(
                          'assets/images/btn_prev.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          widget.controller.registerUserInteraction();
                          unawaited(widget.controller.playOrPauseMusic());
                        },
                        child: Image.asset(
                          isMusicPlaying
                              ? 'assets/images/btn_pause.png'
                              : 'assets/images/btn_play.png',
                          width: 45,
                          height: 45,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          widget.controller.registerUserInteraction();
                          unawaited(widget.controller.playNextTrack());
                        },
                        child: Image.asset(
                          'assets/images/btn_next.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          widget.controller.registerUserInteraction();
                          setState(() {
                            _isVolumePanelOpen = !_isVolumePanelOpen;
                          });
                        },
                        child: Image.asset(
                          'assets/images/btn_music.png',
                          width: 26,
                          height: 26,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),

              if (_isVolumePanelOpen)
                Positioned(
                  bottom: 70,
                  right: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 56,
                      height: 190,
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.15),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ValueListenableBuilder<double>(
                        valueListenable: widget.controller.musicVolume,
                        builder: (context, volume, _) {
                          return Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              const Text(
                                '+',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 8,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 9,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 14,
                                          ),
                                    ),
                                    child: Slider(
                                      value: volume,
                                      min: 0,
                                      max: 1,
                                      activeColor: Colors.black,
                                      inactiveColor: Colors.black26,
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
                                        unawaited(
                                          widget.controller.setMusicVolume(
                                            newValue,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '-',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
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

void _showAboutUsDialog(
  BuildContext context,
  AppController controller, [
  String aboutText = '''
鸡公煲队正式入驻！
我们是一个由四位开发者组成的独立团队。

感谢你拨冗体验我们的作品，
由 4 人团队历时 60 天精心慢炖而成,
你的支持是我们不断迭代的动力。
--------------------------------
制作团队：
主厨：陈柏森 Paschen
摆盘专家：刘思源 Stella
汤底架构师：姚博闻 YewFence
灵魂调味师：陈逸宇 Xiaoyukuki
--------------------------------
“加辣、加汤、不加 Bug！”''',
]) {
  unawaited(controller.triggerUiOpenSfx());
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFFF7E9C6),
      elevation: 18,
      shadowColor: const Color(0x7F3D2A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFC89961), width: 1.2),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      content: SizedBox(
        width: 288,
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF7E4), Color(0xFFF1E0BC)],
              ),
              border: Border.all(color: const Color(0xFFDAB98D)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33A56D3F),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 圆形 logo（硬裁切）：请把图片放在 assets/images/about_logo.png
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFE7B0), Color(0xFFD39A59)],
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 28,
                    backgroundImage: AssetImage('assets/images/about_logo.png'),
                    backgroundColor: Colors.transparent,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '鸡公煲队\nRooster Stewdio',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Color(0xFF4A2A13),
                    fontFamily: 'ZCOOLKuaiLe-Regular',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 122,
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0x00B07D49),
                        Color(0xFFB07D49),
                        Color(0x00B07D49),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.44),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD1AF84)),
                  ),
                  child: Text(
                    aboutText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF4A2A13),
                      fontFamily: 'ZhuoKai',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4A2A13),
            backgroundColor: const Color(0xFFE8CEA0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFC5914E)),
            ),
          ),
          onPressed: () {
            controller.registerUserInteraction();
            unawaited(controller.triggerUiBackSfx());
            Navigator.of(ctx).pop();
          },
          child: const Text(
            'CLOSE',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
        ),
      ],
    ),
  );
}

class ChatBubble extends StatefulWidget {
  final String text;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const ChatBubble({
    super.key,
    required this.text,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  String _displayedText = '';
  Timer? _timer;
  Timer? _autoNextTimer;
  int _charIndex = 0;

  void _handleBubbleTap() {
    if (_charIndex < widget.text.length) {
      _timer?.cancel();
      setState(() {
        _charIndex = widget.text.length;
        _displayedText = widget.text;
      });
      _scheduleAutoNextIfNeeded();
      return;
    }

    _cancelAutoNextTimer();
    widget.onNext();
  }

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
    _cancelAutoNextTimer();
    super.dispose();
  }

  void _startTypewriterEffect() {
    _timer?.cancel();
    _cancelAutoNextTimer();
    setState(() {
      _displayedText = '';
      _charIndex = 0;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (_charIndex >= widget.text.length) {
        timer.cancel();
        return;
      }

      setState(() {
        _charIndex++;
        _displayedText = widget.text.substring(0, _charIndex);
      });

      if (_charIndex >= widget.text.length) {
        timer.cancel();
        _scheduleAutoNextIfNeeded();
      }
    });
  }

  void _cancelAutoNextTimer() {
    _autoNextTimer?.cancel();
    _autoNextTimer = null;
  }

  void _scheduleAutoNextIfNeeded() {
    _cancelAutoNextTimer();

    if (_charIndex < widget.text.length) {
      return;
    }

    _autoNextTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) {
        return;
      }
      if (_charIndex < widget.text.length || _displayedText != widget.text) {
        return;
      }
      widget.onNext();
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleBubbleTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200, minHeight: 80),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
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
                right: 0,
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
      ),
    );
  }
}
