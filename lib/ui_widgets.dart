import 'dart:async';
//import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_controller.dart';
import 'character_view.dart';


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
  late final VoidCallback _activeListener;

  bool get _isTimerRunning => widget.controller.isActive.value;

  // 【V2复古风新增】控制各个磁贴展开状态的变量
  bool _isTomatoExpanded = false;
  bool _isStatsExpanded = false;
  bool _isExpExpanded = false;
  bool _isMusicExpanded = false; // 选歌栏
  
  // ==============================
  // 【V2复古风新增】记录音乐是否正在播放
  // 它的正确位置在这里！和上面这些状态变量做邻居
  // ==============================
  bool _isMusicPlaying = false;

  // 【新增】缩放动画状态变量
  bool _isTomatoScaling = false;
  bool _isExpScaling = false;
  bool _isStatsScaling = false;

  bool _isPomodoroConfigOpen = false;
  final TextEditingController _focusMinutesController = TextEditingController();
  final TextEditingController _restMinutesController = TextEditingController();
  final TextEditingController _cycleCountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 【MVP原有逻辑/注释】监听 isActive 变化时再 start/stop
    _activeListener = () {
      final bool active = widget.controller.isActive.value;
      if (active && _isPomodoroConfigOpen) {
        _closePomodoroConfig();
      }
      if (active) {
        _startFakeProgress();
      } else {
        _stopFakeProgress();
      }
    };
    widget.controller.isActive.addListener(_activeListener);
    _activeListener();
  }

  @override
  void dispose() {
    widget.controller.isActive.removeListener(_activeListener);
    _fakeTimer?.cancel();
    _focusMinutesController.dispose();
    _restMinutesController.dispose();
    _cycleCountController.dispose();
    super.dispose();
  }

  void _startFakeProgress() {
    if (_fakeTimer != null && _fakeTimer!.isActive) return;
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
    _fakeTimer?.cancel();
    _fakeTimer = null;
  }

  void _resetFakeProgress() {
    setState(() {
      _fakeProgress = 0.0;
    });
  }

  void _openPomodoroConfig() {
    if (_isTimerRunning) {
      return;
    }

    setState(() {
      _isPomodoroConfigOpen = true;
      _focusMinutesController.text = (widget.controller.focusDurationSeconds.value ~/ 60).toString();
      _restMinutesController.text = (widget.controller.restDurationSeconds.value ~/ 60).toString();
      _cycleCountController.text = widget.controller.cycleCount.value?.toString() ?? '';
    });
  }

  void _closePomodoroConfig() {
    setState(() {
      _isPomodoroConfigOpen = false;
    });
  }

  // 【新增】缩放动画方法
  void _triggerScaleAnimation(String type) {
    setState(() {
      if (type == 'tomato') _isTomatoScaling = true;
      else if (type == 'exp') _isExpScaling = true;
      else if (type == 'stats') _isStatsScaling = true;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          if (type == 'tomato') _isTomatoScaling = false;
          else if (type == 'exp') _isExpScaling = false;
          else if (type == 'stats') _isStatsScaling = false;
        });
      }
    });
  }

  void _savePomodoroConfig() {
    if (_isTimerRunning) {
      _closePomodoroConfig();
      return;
    }

    final focusValue = int.tryParse(_focusMinutesController.text);
    final restValue = int.tryParse(_restMinutesController.text);
    final cycleValue = int.tryParse(_cycleCountController.text);

    if (focusValue != null && focusValue > 0) {
      widget.controller.updateFocusDuration(focusValue * 60);
    }
    if (restValue != null && restValue > 0) {
      widget.controller.updateRestDuration(restValue * 60);
    }

    widget.controller.updateCycleCount(cycleValue == null || cycleValue <= 0 ? null : cycleValue);

    _closePomodoroConfig();
  }

  // ===============================
  // 【V2复古风新增】全局点击关闭所有磁贴
  // ===============================
  void _closeAllPanels() {
    setState(() {
      _isTomatoExpanded = false;
      _isStatsExpanded = false;
      _isExpExpanded = false;
      _isMusicExpanded = false;
      _isPomodoroConfigOpen = false;
    });
  }

  Widget _buildCharacterStage(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.isActive,
      builder: (context, active, _) {
        debugPrint('[DEBUG][CharacterStage] active=$active');
        return CharacterView(isActive: active);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      // 【V2复古风新增】使用 GestureDetector 包裹全屏，点击空白处收起磁贴和推进对话
      body: GestureDetector(
        behavior: HitTestBehavior.translucent, // 允许穿透到底层背景
        onTap: () {
          _closeAllPanels();
          // 【V2 接口对接】如果正在对话，点击空白处推进下一句
          // widget.controller.nextDialogue(); // 假设后端提供了这个方法
        },
        child: Stack(
          children: [
            // ------------------------------------------------
            // 1. 【MVP原有逻辑】最底层：全屏人物动画 / 书架背景
            // ------------------------------------------------
            Positioned.fill(
              child: _buildCharacterStage(context),
            ),

                        // ------------------------------------------------
            // 2. 【V2复古风新增】中间层：Q弹对话气泡
            // ------------------------------------------------
            Positioned(
              bottom: 120, // 悬浮在小人旁边
              right: 40,

              // ==========================================
              // 【接口对接预留区】等后端 isTalking 和 currentDialogue 好了，
              // 把下面这坨多行注释打开，并删掉下方的占位 ChatBubble 即可。
              // ==========================================
              /*
              child: ValueListenableBuilder<bool>(
                valueListenable: widget.controller.isTalking,
                builder: (context, isTalking, _) {
                  // 后端控制没说话时，直接返回空组件隐藏气泡
                  if (!isTalking) return const SizedBox.shrink();

                  return ValueListenableBuilder<String>(
                    valueListenable: widget.controller.currentDialogue,
                    builder: (context, dialogue, _) {
                      return ChatBubble(
                        text: dialogue, // 动态接收后端的文字
                        onNext: () => widget.controller.nextDialogue(),
                        onSkip: () => widget.controller.skipDialogue(),
                      );
                    }
                  );
                },
              ),
              */

              // 【当前占位】保持原样不动，方便你继续调 UI
              child: ChatBubble(
                text: "主人，今天专注力不错哦！想要放一张肖邦的黑胶唱片吗？", 
                onNext: () {
                  // 预留：widget.controller.nextDialogue();
                },
                onSkip: () {
                  // 预留：widget.controller.skipDialogue();
                },
              ),
            ),

            // ------------------------------------------------
            // 3. 【V2复古风新增】顶层控制区：打散的复古按钮与磁贴
            // ------------------------------------------------
            
            // 左上角 A：番茄钟按钮及下拉磁贴
            Positioned(
              top: 10,
              left: 20,
              child: _buildTomatoTimerDrop(),
            ),

            // 左上角 B：牛皮纸经验条及下拉磁贴 (放在番茄钟下方一点)
            Positioned(
              top: 20,
              left: 50,
              child: _buildExpBarDrop(),
            ),

            // 右上角：黑板统计面板
            Positioned(
              top: 15,
              right: 28,
              child: _buildBlackboardStatsDrop(),
            ),

            // 左下角：唱片机音乐控制台
            Positioned(
              bottom: 10,
              left: 15,
              child: _buildRecordPlayer(),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 下方是 V2 各种复古 UI 组件的具象化实现
  // 注意：目前用色块+基础图标占位，后期把 Container 换成 Image.asset 即可
  // ==========================================

   Widget _buildTomatoTimerDrop() {
    return Stack(
      // 【本次修改】整体外层改为 Stack，便于让自定义配置面板在右侧层叠弹出
      clipBehavior: Clip.none, 
      children: [
        // 【核心修复】增加一个透明占位层，确保右侧 Positioned 区域能接收到点击事件
        // 如果没有这个，Positioned 弹出的面板在 hit-test 阶段会被忽略，导致键盘弹不出
        if (_isTomatoExpanded && _isPomodoroConfigOpen)
          const SizedBox(width: 360, height: 300),

        // 1. Column 包含番茄按钮和便签磁贴
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 按钮本体 (已为你替换为图片结构)
            GestureDetector(
              onTap: () {
                _triggerScaleAnimation('tomato');
                setState(() {
                  _isTomatoExpanded = !_isTomatoExpanded;
                  if(_isTomatoExpanded) { 
                    _isStatsExpanded=false; 
                    _isExpExpanded=false;
                    // 【新增逻辑】每次点击主按钮展开/收起时，强制先关闭自定义配置面板，防止它“蹦出来”
                    _isPomodoroConfigOpen = false; 
                  }
                });
              },
              child: AnimatedScale(
                scale: _isTomatoScaling ? 0.9 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 45, height: 45,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    // 给番茄按钮加一点淡淡的常驻阴影，更有立体感
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 3))],
                  ),
                  // 【本次修改】这里为你留好了番茄图片的坑位，直接改路径就行！
                  child: Image.asset(
                    'assets/images/tomato_btn.png', 
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            
            // 下拉活页便签磁贴 (现已改为浅色便签纸)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              // 【核心修复】将 easeOutBack 改为 easeOut，去掉回弹效果，杜绝负数引发红屏
              curve: Curves.easeOut,
              // 【本次修改】便签的高度不再根据配置面板开启而变大，配置面板已移至右侧弹出
              height: _isTomatoExpanded ? 160 : 0, 
              width: 180,
              margin: EdgeInsets.only(top: _isTomatoExpanded ? 10 : 0),
              clipBehavior: Clip.hardEdge, 
              decoration: BoxDecoration(
                // 【便签质感修改】换成白底便签图片
                image: _isTomatoExpanded ? const DecorationImage(
                  image: AssetImage('assets/images/memo_bg.png'), // 替换为你的便签图片
                  fit: BoxFit.fill,
                ) : null,
               
                // 【核心修复】保持两边都有 BoxShadow 对象，只让透明度和 blurRadius 归零，动画更丝滑
                // boxShadow: [
                  // BoxShadow(
                  //   // 【便签阴影】便签的阴影稍微轻巧一点
                  //   color: _isTomatoExpanded ? Colors.black26 : Colors.transparent,
                  //   blurRadius: _isTomatoExpanded ? 8.0 : 0.0,
                  //   offset: const Offset(0, 4)
                  // )
                // ],
              ),
              child: SingleChildScrollView(
                // 【优化】防止在收起面板的时候手误滑动内容导致溢出
                physics: const NeverScrollableScrollPhysics(), 
                child: Column(
                  children: [
                    const SizedBox(height: 33),
                    // 红色圆框进度条
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 70, height: 70,
                          child: CircularProgressIndicator(
                            value: _fakeProgress,
                            // 【适配便签】底色变浅了，这里的颜色换回复古红和深灰
                            color: const Color.fromARGB(255, 204, 196, 195), // 白色进度
                            backgroundColor: const Color.fromARGB(255, 179, 22, 22), // 红色初始轨道
                            strokeWidth: 6,
                          ),
                        ),
                        // 内部时间
                        // 【核心修复】重新明确参数，解决 valueListenable 报错
                        ValueListenableBuilder<int>(
                          valueListenable: widget.controller.remainingSeconds,
                          builder: (BuildContext context, int seconds, Widget? child) {
                            final time = "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";
                            // 【适配便签】文字颜色改为深棕色，在白底便签上才清晰
                            return Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037), fontFamily: 'ZCOOLKuaiLe-Regular'));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // 【本次修改】重新排列按钮：重置放左边，播放放中间，自定义按钮放右边 (临时占位)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 【本次修改】重置按钮放左边
                        IconButton(
                          icon: const Icon(Icons.refresh), 
                          // 【适配便签】图标颜色改为深棕色
                          color: const Color(0xFF5D4037),
                          onPressed: () {
                            widget.controller.resetTimer();
                            _resetFakeProgress();
                          },
                        ),
                        
                        // 【本次修改】播放按钮放中间
                        ValueListenableBuilder<bool>(
                          valueListenable: widget.controller.isActive,
                          builder: (context, isActive, _) {
                            return IconButton(
                              icon: Icon(isActive ? Icons.pause : Icons.play_arrow, size: 28),
                              color: const Color(0xFF5D4037),
                              onPressed: () => widget.controller.toggleTimer(),
                            );
                          },
                        ),
                        
                        // 【本次修改】自定义铅笔按钮放右边 (临时占位)
                        // 下方是为你留好的铅笔图片引入坑位，参考下方教程进行操作
                        const SizedBox(width: 8), // 按钮间距
                        /*
                        // 【教程：铅笔按钮引入】
                        // 将此 IconButton 替换为以下代码块
                        GestureDetector(
                          onTap: _openPomodoroConfig,
                          child: SizedBox(
                            width: 32, height: 32, // 规范大小
                            child: Image.asset(
                              'assets/images/btn_pencil.png', // 规范命名：btn_pencil.png
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        */
                        IconButton(
                          icon: const Icon(Icons.edit), // 临时铅笔占位
                          // 【适配便签】图标颜色改为深棕色
                          color: const Color(0xFF5D4037),
                          onPressed: _isTimerRunning
                              ? null
                              : _openPomodoroConfig,
                        ),
                      ],
                    ),
                    
                    /*
                    // 【本次修改】原来的 TextButton 被移动到上面的 Row 中作为铅笔图标
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF5D4037),
                        minimumSize: const Size(120, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: _openPomodoroConfig,
                      child: const Text('自定义番茄设置', style: TextStyle(fontSize: 12))
                    ),
                    */
                  ],
                ),
              ),
            ),
          ],
        ),

        // 2. Positioned 自定义配置面板 (在便签右侧弹出)
        // 【核心修改】这里是配置弹出面板的新宿主
        Positioned(
          top: 55, // 按钮高度+spacer
          left: 180 + 10, // 便签宽度 + margin
          child: GestureDetector(
            // 【核心修复】增加透明点击行为拦截，防止事件流失，并强制拦截父级手势
            behavior: HitTestBehavior.opaque,
            onTap: () {}, 
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              // 【核心动画逻辑】这里加入 topCenter 甚至 topRight 对齐，
              // 配合 hardEdge 裁剪，就能模拟出从边缘拉出的完美手感！
              alignment: Alignment.topLeft, 
              height: (_isTomatoExpanded && _isPomodoroConfigOpen) ? 240 : 0, // 撑开高度
              width: (_isTomatoExpanded && _isPomodoroConfigOpen) ? 170 : 0, // 撑开宽度
              clipBehavior: Clip.hardEdge, 
              margin: const EdgeInsets.only(top: 0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                border: Border.all(color: const Color(0xFF795548), width: 1),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
              ),
              // 【核心修复】必须有 Material，否则 TextField 在 Stack 里无法获得渲染层级来弹出键盘
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    // 给弹出面板一些 padding
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
                                    const Text('专注/休息/循环(次)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5D4037), fontFamily: 'ZCOOLKuaiLe-Regular')),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(child: TextField(controller: _focusMinutesController, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8), labelText: '专注(分)', floatingLabelBehavior: FloatingLabelBehavior.always, border: OutlineInputBorder()))),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(child: TextField(controller: _restMinutesController, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8), labelText: '休息(分)', floatingLabelBehavior: FloatingLabelBehavior.always, border: OutlineInputBorder()))),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(child: TextField(controller: _cycleCountController, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8), labelText: '循环(次)', floatingLabelBehavior: FloatingLabelBehavior.always, border: OutlineInputBorder()))),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(onPressed: _closePomodoroConfig, child: const Text('取消', style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'ZCOOLKuaiLe-Regular'))),
                                        TextButton(onPressed: _savePomodoroConfig, child: const Text('保存', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5D4037), fontFamily: 'ZCOOLKuaiLe-Regular'))),
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

   // 【V2复古风新增】牛皮纸经验条
  Widget _buildExpBarDrop() {
    return Column(
      // 【本次修改】既然是竖向卷轴，下拉和本体保持居中对齐最自然
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 经验条本体 (卷轴卷起状态)
        GestureDetector(
          onTap: () {
            _triggerScaleAnimation('exp');
            setState(() {
              _isExpExpanded = !_isExpExpanded;
               if(_isExpExpanded) { _isTomatoExpanded=false; _isStatsExpanded=false;}
            });
          },
          child: AnimatedScale(
            scale: _isExpScaling ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 100, height: 35,
              decoration: const BoxDecoration(
                // 【本次修改】原注释保留：占位：牛皮纸色。现已替换为你的卷轴本体图片
                image: DecorationImage(
                  image: AssetImage('assets/images/scroll_rolled.png'), // 替换为你的卷起图片名
                  fit: BoxFit.contain,
                ),
                // 原来的颜色和边框注释掉，全权交给你的精美图片
                // color: const Color(0xFFD2B48C), 
                // borderRadius: BorderRadius.circular(5),
                // border: Border.all(color: Colors.brown[700]!, width: 2),
              ),
              
            ),
          ),
        ),
        
        // 下拉磁贴 (展开的羊皮纸)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          // 【本次修改】吸取教训，使用 easeOut 杜绝红屏报错！
          curve: Curves.easeOut,
          // 【本次修改】竖向卷轴，高度稍微拉长，宽度适当收窄
          height: _isExpExpanded ? 160 : 0,
          width: 140, 
          margin: const EdgeInsets.only(top: 8),
          // 【本次修改】开启硬裁剪，防止收起时内部文字溢出撑爆 UI
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            // 【本次修改】替换为展开后的卷轴图片
            image: _isExpExpanded ? const DecorationImage(
              image: AssetImage('assets/images/scroll_unrolled.png'), // 替换为你的展开图片名
              fit: BoxFit.fill,
            ) : null,
            // color: const Color(0xFFE5C89E),
            // borderRadius: BorderRadius.circular(8),
            // 【本次修改】安全的动态阴影，收起时归零
            boxShadow: [
              BoxShadow(
                color: _isExpExpanded ? Colors.black26 : Colors.transparent, 
                blurRadius: _isExpExpanded ? 5.0 : 0.0,
                offset: const Offset(0, 3)
              )
            ],
          ),
          // 【本次修改】去掉原来的三元表达式，常驻子组件，靠外部高度丝滑截断
          child: SingleChildScrollView(
            // 【本次修改】禁用滚动，防止手残滑动导致内容跑偏
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              // 【本次修改】上下留出一些 padding，避开卷轴上下的木棍画轴
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 30.0),
              child: Column(
                // 【本次修改】内部元素全方位居中
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Lv. 5 学徒", 
                    textAlign: TextAlign.center, // 【本次修改】文字居中
                    style: TextStyle(color: Colors.brown[900], fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'ZCOOLKuaiLe-Regular')
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "再专注 120 分钟\n即可升级", // 【本次修改】加个换行 `\n`，更贴合竖向排版
                    textAlign: TextAlign.center, // 【本次修改】文字居中
                    style: TextStyle(color: Colors.brown[800], fontSize: 12, height: 1.4, fontFamily: 'ZCOOLKuaiLe-Regular')
                  ),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

   // 【V2复古风新增】黑板统计面板
  Widget _buildBlackboardStatsDrop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 黑板按钮
        GestureDetector(
          onTap: () {
            _triggerScaleAnimation('stats');
            setState(() {
              _isStatsExpanded = !_isStatsExpanded;
               if(_isStatsExpanded) { _isTomatoExpanded=false; _isExpExpanded=false;}
            });
            if (_isStatsExpanded) widget.controller.fetchHistoryData(); // 后端接口依然健在！
          },
          child: AnimatedScale(
            scale: _isStatsScaling ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 50, height: 50,
              decoration: const BoxDecoration(
                // 【本次修改】换成了图片占位
                image: DecorationImage(
                  image: AssetImage('assets/images/board_btn.png'), // 替换为生成的黑板按钮图片
                  fit: BoxFit.contain,
                ),
                // color: const Color(0xFF2E3B32), // 占位：黑板墨绿色
                // borderRadius: BorderRadius.circular(8),
                // border: Border.all(color: Colors.brown[400]!, width: 3), // 木边框
              ),
              // 【本次修改】去掉了 Icon
              // child: const Icon(Icons.bar_chart, color: Colors.white70),
            ),
          ),
        ),
        // ==============================
        // 【修改这里】：去掉会导致动画失效的 Visibility！
        // ==============================
        // 黑板下拉磁贴
        Transform.translate(
          offset: const Offset(0, -40), // 往上提，掩盖在按钮后方
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            // 【核心动画逻辑】这里加入 topCenter 甚至 topRight 对齐，
            // 配合 hardEdge 裁剪，就能模拟出从边缘拉出的完美手感！
            alignment: Alignment.topRight, 
            height: _isStatsExpanded ? 240 : 0, 
            width: 280,
            clipBehavior: Clip.hardEdge, // 必须加这个，配合 height 产生拉出效果
            margin: const EdgeInsets.only(top: 0),
            decoration: BoxDecoration(
              // 【本次修改】底板换成展开的黑板图片
              image: _isStatsExpanded ? const DecorationImage(
                image: AssetImage('assets/images/board_panel.png'), // 替换为生成的大黑板图片
                fit: BoxFit.fill,
              ) : null,
              // color: const Color(0xFF2E3B32),
              // borderRadius: BorderRadius.circular(8),
              // border: Border.all(color: Colors.brown[400]!, width: 4),
              // 【本次修改】黑影被我彻底删除了！！！干干净净！！！
            ),
            // 使用 SingleChildScrollView 防止高度为 0 时内部组件报溢出错误
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: 280, // 撑满最终高度，让外层去裁剪它
                width: 320,
                child: Stack(
                  children: [
                    Padding(
                      // 【本次修改】内边距也跟着变大，给厚重木边框留足空间
                      padding: const EdgeInsets.only(left: 50.0, top: 50.0, right: 30.0, bottom: 20.0), 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 模拟粉笔字
                          Text(
                            "今日专注：1.5 hrs", 
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85), // 【粉笔特效】微透明
                              fontSize: 19, // 【本次修改】字号调大
                              fontFamily: 'ZhuoKai', // 换成了工整字体（记得按下方教程配）
                              shadows: const [BoxShadow(color: Colors.white38, blurRadius: 3)] // 【粉笔特效】粉尘发光
                            )
                          ), 
                          const SizedBox(height: 6),
                          Text(
                            "累计天数：7 days", 
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 19, 
                              fontFamily: 'ZhuoKai', // 换成了工整字体
                              shadows: const [BoxShadow(color: Colors.white38, blurRadius: 3)]
                            )
                          ),
                        ],
                      ),
                    ),
                    // 小板擦（分享按钮）
                    Positioned(
                      bottom: 70, right: 35, 
                      child: GestureDetector(
                        onTap: () {
                          // 【MVP原有逻辑】保留：复用分享卡片弹窗
                          _showShareCard(context, widget.controller);
                        },
                        // 【本次修改】把板擦和文字拆开，上下排列！
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 分享文字在上方，也是粉笔质感
                            Text(
                              "分享", 
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9), 
                                fontSize: 15, 
                                fontFamily: 'ZhuoKai', // 这里也换成了工整字体
                                shadows: const [BoxShadow(color: Colors.white38, blurRadius: 2)]
                              )
                            ),
                            const SizedBox(height: 4), // 字和板擦之间的缝隙
                            // 无字板擦在下方
                            Container(
                              width: 55, height: 35, // 给板擦定个大小
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage('assets/images/eraser_btn.png'), // 替换为板擦图片
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 【核心修改】V2复古风：唱片机音乐控制
  // 已经全套替换为你准备好的图片素材和切换逻辑！
  // ==========================================
  Widget _buildRecordPlayer() {
    return Container(
      // 【本次修改】等比例缩小：280x70 缩减为 240x60
      width: 240, 
      height: 60,
      decoration: BoxDecoration(
        // 加载你的底座图片
        image: const DecorationImage(
          image: AssetImage('assets/images/record_bg.png'),
          fit: BoxFit.fill, 
        ),
        borderRadius: BorderRadius.circular(30), // 【本次修改】圆角跟着缩小为 30
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0,5))],
      ),
      child: Row(
        // 【本次修改】改为居中对齐，使用 SizedBox 挤压控制间距
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 【本次修改】最左边的透明墙，把唱片往里推
          const SizedBox(width: 12), 

          // 黑胶唱盘
          Image.asset('assets/images/record_disk.png', width: 40, height: 40, fit: BoxFit.contain), // 【本次修改】缩小尺寸
          const SizedBox(width: 8), 
          
          // 上一首
          GestureDetector(
            onTap: (){}, 
            child: Image.asset('assets/images/btn_prev.png', width: 30, height: 30, fit: BoxFit.contain)
          ),
          const SizedBox(width: 12), 
          
          // 播放 / 暂停 切换键
          GestureDetector(
            onTap: () {
              setState(() {
                // 点击切换播放状态
                _isMusicPlaying = !_isMusicPlaying; 
              });
            }, 
            child: Image.asset(
              _isMusicPlaying ? 'assets/images/btn_pause.png' : 'assets/images/btn_play.png', 
              width: 45, height: 45, fit: BoxFit.contain // 【本次修改】缩小尺寸
            )
          ),
          const SizedBox(width: 12), 

          // 下一首
          GestureDetector(
            onTap: (){}, 
            child: Image.asset('assets/images/btn_next.png', width: 30, height: 30, fit: BoxFit.contain)
          ),
          const SizedBox(width: 8), 
          
          // 音量键
          GestureDetector(
            onTap: (){}, 
            child: Image.asset('assets/images/btn_music.png', width: 30, height: 30, fit: BoxFit.contain)
          ),

          // 【本次修改】最右边的透明墙，把音量键往里推
          const SizedBox(width: 12), 
        ],
      ),
    );
  }

  
  // 【对接队友接口】人物动画层
  // 保留你现在的 live2d 组件版本（全屏式舞台）
  // 如上面 _buildCharacterStage() 已实现，无需重复定义
}


// ===============================
// 【MVP原有逻辑】保留：分享卡片弹窗
// ===============================
void _showShareCard(BuildContext context, AppController controller) {
  final int seconds = controller.remainingSeconds.value;
  final double hours = (25 * 60 - seconds) / 3600.0; // 假定默认25分钟
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFFF4E8C1), // 改成了便签色
      title: const Text('今日复古专注打卡'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('今日学习：${hours.toStringAsFixed(2)} 小时', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('（此处为分享卡片占位）', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('收下', style: TextStyle(color: Colors.brown))),
      ],
    ),
  );
}

// ===============================
// 【V2复古风新增】打字机聊天气泡组件 (自带动画)
// ===============================
class ChatBubble extends StatefulWidget {
  final String text;
  final VoidCallback onNext; // 点击空白处下一句
  final VoidCallback onSkip; // 点击 Skip 退出

  const ChatBubble({super.key, required this.text, required this.onNext, required this.onSkip});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  String _displayedText = "";
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
    setState(() { _displayedText = ""; _charIndex = 0; });
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

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale, alignment: Alignment.bottomRight, 
          child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240, minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_displayedText, style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF5D4037), fontFamily: 'ZCOOLKuaiLe-Regular')),
                const SizedBox(height: 15),
              ],
            ),
            // Skip 按钮
            Positioned(
              bottom: -5, right: -5,
              child: GestureDetector(
                onTap: widget.onSkip,
                child: const Icon(Icons.fast_forward_rounded, size: 20, color: Colors.grey),
              ),
            )
          ],
        ),
      ),
    );
  }
}


