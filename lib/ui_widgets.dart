import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'character_view.dart';

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

    final int? focusValue = int.tryParse(_focusMinutesController.text);
    final int? restValue = int.tryParse(_restMinutesController.text);
    final int? cycleValue = int.tryParse(_cycleCountController.text);

    if (focusValue != null && focusValue > 0) {
      widget.controller.updateFocusDuration(focusValue * 60);
    }
    if (restValue != null && restValue > 0) {
      widget.controller.updateRestDuration(restValue * 60);
    }

    widget.controller.updateCycleCount(
      cycleValue == null || cycleValue <= 0 ? null : cycleValue,
    );

    _closePomodoroConfig();
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
    });
    if (hasOpenPanels) {
      unawaited(widget.controller.triggerUiBackSfx());
    }
  }

  void _handleBlankTap() {
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: _handleBlankTap,
        behavior: HitTestBehavior.deferToChild,
        child: Stack(
          children: [
            Positioned.fill(child: _buildStageBackground()),
            Positioned.fill(child: _buildCharacterStage(context)),
            Positioned.fill(child: _buildStageForeground()),
            Positioned(bottom: 120, right: 40, child: _buildDialogueBubble()),
            Positioned(top: 10, left: 20, child: _buildTomatoTimerDrop()),
            Positioned(top: 20, left: 50, child: _buildExpBarDrop()),
            Positioned(top: 15, right: 28, child: _buildBlackboardStatsDrop()),
            Positioned(bottom: 10, left: 15, child: _buildRecordPlayer()),
          ],
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
                        ValueListenableBuilder<int>(
                          valueListenable: widget.controller.remainingSeconds,
                          builder: (context, _, _) {
                            return SizedBox(
                              width: 70,
                              height: 70,
                              child: CircularProgressIndicator(
                                value: _currentProgress,
                                color: const Color.fromARGB(255, 204, 196, 195),
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  179,
                                  22,
                                  22,
                                ),
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
          top: 55,
          left: 190,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              height: (_isTomatoExpanded && _isPomodoroConfigOpen) ? 240 : 0,
              width: (_isTomatoExpanded && _isPomodoroConfigOpen) ? 170 : 0,
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
                  physics: const NeverScrollableScrollPhysics(),
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
                                    TextField(
                                      controller: _focusMinutesController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 6,
                                          horizontal: 8,
                                        ),
                                        labelText: '专注(分)',
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.always,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _restMinutesController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 6,
                                          horizontal: 8,
                                        ),
                                        labelText: '休息(分)',
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.always,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _cycleCountController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 6,
                                          horizontal: 8,
                                        ),
                                        labelText: '循环(次)',
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.always,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
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
              width: 100,
              height: 35,
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
          width: 140,
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
              width: 50,
              height: 50,
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
                                '今日 XP：$dailyXp',
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
                                '累计 XP：$totalXp',
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
                          _showShareCard(context, widget.controller);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '分享',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 15,
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
                              width: 55,
                              height: 35,
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
        return Container(
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
                  unawaited(widget.controller.toggleMuteMusic());
                },
                child: Image.asset(
                  'assets/images/btn_music.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        );
      },
    );
  }
}

void _showShareCard(BuildContext context, AppController controller) {
  unawaited(controller.triggerUiOpenSfx());
  final int seconds = controller.remainingSeconds.value;
  final double hours = (25 * 60 - seconds) / 3600.0;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFFF4E8C1),
      title: const Text('今日复古专注打卡'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '今日学习：${hours.toStringAsFixed(2)} 小时',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            '（此处为分享卡片占位）',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            controller.registerUserInteraction();
            unawaited(controller.triggerUiBackSfx());
            Navigator.of(ctx).pop();
          },
          child: const Text('收下', style: TextStyle(color: Colors.brown)),
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

  void _handleSkipTap() {
    _cancelAutoNextTimer();
    widget.onSkip();
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
          constraints: const BoxConstraints(maxWidth: 240, minHeight: 60),
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
                right: -5,
                child: GestureDetector(
                  onTap: _handleSkipTap,
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
