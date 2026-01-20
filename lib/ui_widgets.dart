import 'package:flutter/material.dart';

// ==========================================
// 1. 番茄钟组件 (PomodoroTimer)
// 功能：显示当前日期、倒计时数字、圆环进度条
// 对应接口规范：remainingSeconds, currentDate
// ==========================================
class PomodoroTimer extends StatelessWidget {
  // 接收外部数据 ("插座")
  final int seconds;           // 当前剩余秒数
  final int totalSeconds;      // 总秒数 (用于计算进度条比例)

  const PomodoroTimer({
    super.key, 
    required this.seconds,
    this.totalSeconds = 1500, // 默认为 25 分钟
  });

  // 格式化时间字符串：将 1500 转换为 "25:00"
  String get timerString {
    int m = seconds ~/ 60; // 分钟
    int s = seconds % 60;  // 秒数
    // padLeft(2, '0') 保证不足两位数时补零，如 "5" -> "05"
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 计算进度比例 (0.0 ~ 1.0)
    double progress = seconds / totalSeconds;

    return Column(
      mainAxisSize: MainAxisSize.min, // 高度包裹内容
      children: [
        // 📅 日期显示
        Text(
          "2026年1月22日", // 后期可由 Logic 传入
          style: TextStyle(
            color: Colors.grey[600], 
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        
        SizedBox(height: 30), // 垂直间距
        
        // ⭕️ 圆环进度条 + 倒计时
        Stack(
          alignment: Alignment.center, // 居中堆叠
          children: [
            // 底层：灰色轨道
            SizedBox(
              width: 260, height: 260,
              child: CircularProgressIndicator(
                value: 1.0,              // 满圈
                strokeWidth: 12,         // 粗细
                color: Colors.grey[200], // 浅灰
              ),
            ),
            
            // 中层：进度条 (根据 progress 变化)
            SizedBox(
              width: 260, height: 260,
              child: CircularProgressIndicator(
                value: progress,            // 绑定数据
                strokeWidth: 12,
                color: Color(0xFFFF6B6B),   // 番茄红
                strokeCap: StrokeCap.round, // 圆头
              ),
            ),
            
            // 顶层：时间数字
            Text(
              timerString,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w100, // 极细字体
                color: Colors.black87,
                letterSpacing: -2.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ==========================================
// 2. 底部菜单栏 (DockBar)
// 功能：放置操作按钮，触发逻辑方法
// 对应接口规范：toggleTimer, resetTimer, fetchHistoryData
// ==========================================
class DockBar extends StatelessWidget {
  final bool isActive;              // 是否正在计时 (控制按钮颜色/图标)
  final VoidCallback onToggleTimer; // 点击回调 -> 切换开始/暂停
  final VoidCallback onResetTimer;  // 长按回调 -> 重置计时器
  final VoidCallback onShowStats;   // 点击图表回调 -> 获取历史数据

  const DockBar({
    super.key,
    required this.isActive,
    required this.onToggleTimer,
    required this.onResetTimer,     // 必须传入
    required this.onShowStats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(45), // 胶囊形状
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 左右均匀
        crossAxisAlignment: CrossAxisAlignment.center,    // 上下居中
        children: [
          // 📊 左侧：统计数据
          IconButton(
            icon: Icon(Icons.bar_chart_rounded, size: 30, color: Colors.grey),
            onPressed: onShowStats, // 触发 fetchHistoryData
          ),
          
          // ▶️ 中间：播放/暂停 (带长按功能)
          GestureDetector(
            onTap: onToggleTimer,       // 短按 -> toggleTimer
            onLongPress: onResetTimer,  // 长按 -> resetTimer
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200), // 颜色渐变动画
              width: 64, height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // 激活状态变红，暂停状态变黑
                color: isActive ? Color(0xFFFF6B6B) : Color(0xFF2D3436),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                ],
              ),
              child: Icon(
                // 激活显示暂停，暂停显示播放
                isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                size: 36, 
                color: Colors.white,
              ),
            ),
          ),
          
          // ⚙️ 右侧：设置 (占位)
          IconButton(
            icon: Icon(Icons.settings_rounded, size: 30, color: Colors.grey),
            onPressed: () {}, 
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. 统计面板 (StatsPanel)
// 功能：显示统计详情
// 对应接口规范：UI 数据更新
// ==========================================
class StatsPanel extends StatelessWidget {
  final int totalMinutes; // 今日专注时长
  final int totalDays;    // 累计天数

  const StatsPanel({
    super.key, 
    required this.totalMinutes, 
    required this.totalDays
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 高度自适应
        children: [
          // 顶部拖拽条 Handle
          Container(
            width: 40, height: 5, 
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(height: 40),
          
          // 数据展示区域
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("🔥 今日专注", "$totalMinutes", "分钟"),
              _buildStatItem("📅 累计坚持", "$totalDays", "天"),
            ],
          ),
          SizedBox(height: 50),
        ],
      ),
    );
  }

  // 私有辅助方法：构建单个数据项
  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 14)),
        SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value, 
              style: TextStyle(
                fontSize: 36, 
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 6, left: 4),
              child: Text(
                unit, 
                style: TextStyle(color: Colors.grey[600], fontSize: 14)
              ),
            ),
          ],
        ),
      ],
    );
  }
}

