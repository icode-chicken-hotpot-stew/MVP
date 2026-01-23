# 开发指引 - Flutter 初学者入门

> 本文档面向 Flutter 初学者，帮助团队成员快速上手项目开发。

## 1. 环境搭建

### 安装 Flutter SDK

1. 下载 Flutter SDK：https://docs.flutter.dev/get-started/install/windows
2. 解压到合适位置（如 `D:\flutter`）
3. 添加 `D:\flutter\bin` 到系统环境变量 PATH
4. 打开终端验证安装：

```bash
flutter doctor
```

看到�bindbindASI类似以下输出说明安装成功：

```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain
[✓] Android Studio
```

### 安装 IDE 插件

推荐使用 **VS Code** 或 **Android Studio**：

- VS Code：安装 `Flutter` 和 `Dart` 插件
- Android Studio：安装 `Flutter` 插件（会自动安装 Dart）

### 安装 Python 工具（可选但推荐）

项目使用 Python 脚本来管理图片资源，建议安装：

1. 安装 [uv](https://docs.astral.sh/uv/getting-started/installation/)（Python 包管理器）：
   ```bash
   # Windows PowerShell
   powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
   ```

2. 安装 pre-commit（Git 提交钩子工具）：
   ```bash
   uv tool install pre-commit
   ```

3. 在项目目录下激活钩子：
   ```bash
   cd d:/Program/ProgramStudy/icode/MVP
   pre-commit install
   ```

> 💡 激活后，每次 `git commit` 时会自动检查并转换图片格式，无需手动操作。

## 2. 运行项目

```bash
# 1. 进入项目目录
cd d:/Program/ProgramStudy/icode/MVP

# 2. 获取依赖包
flutter pub get

# 3. 连接手机或启动模拟器，然后运行
flutter run
```

**热重载**：修改代码后，在终端按 `r` 键即可实时刷新界面，无需重启应用。

## 3. 项目结构速览

```
lib/
├── main.dart           # 入口文件 - 组长负责布局整合
├── app_controller.dart # 逻辑中枢 - 组员 C 负责
├── ui_widgets.dart     # UI 组件 - 组员 D 负责
└── character_view.dart # 角色动画 - 组员 B 负责
```

## 4. Flutter 核心概念（5 分钟速成）

### Widget 是什么？

Flutter 里**一切都是 Widget**（组件）。按钮是 Widget，文字是 Widget，整个页面也是 Widget。

```dart
// 一个简单的文本 Widget
Text('你好世界')

// 一个按钮 Widget
ElevatedButton(
  onPressed: () { print('被点击了'); },
  child: Text('点我'),
)
```

### StatelessWidget vs StatefulWidget

| 类型 | 特点 | 使用场景 |
|------|------|----------|
| StatelessWidget | 静态的，不会变化 | 纯展示内容，如标题、图标 |
| StatefulWidget | 动态的，可以变化 | 需要更新的内容，如计时器数字 |

### 本项目的状态管理方式

我们用 `ValueNotifier` + `ValueListenableBuilder` 来管理状态：

```dart
// 在 AppController 中定义状态（组员 C 负责）
final remainingSeconds = ValueNotifier<int>(1500);

// 在 UI 中监听状态（组员 D 负责）
ValueListenableBuilder<int>(
  valueListenable: controller.remainingSeconds,
  builder: (context, seconds, child) {
    return Text('$seconds 秒');  // 当 seconds 变化时，这里会自动刷新
  },
)
```

**重要原则**：UI 层只能**读取**状态，不能直接修改。要改状态，调用 Controller 的方法。

## 5. 各组员开发指南

### 组员 B - 角色动画

编辑 `lib/character_view.dart`，你需要：

1. 监听 `isActive` 状态
2. 根据状态切换角色的动画（学习中 / 休息中）

```dart
ValueListenableBuilder<bool>(
  valueListenable: controller.isActive,
  builder: (context, isActive, child) {
    // isActive == true 表示正在计时，播放学习动画
    // isActive == false 表示暂停，播放休息动画
    return YourCharacterWidget(isStudying: isActive);
  },
)
```

### 组员 C - 逻辑中枢

编辑 `lib/app_controller.dart`，你需要实现：

1. `toggleTimer()` - 开始/暂停计时器
2. `resetTimer()` - 重置为 1500 秒
3. 每秒递减 `remainingSeconds`

```dart
void toggleTimer() {
  isActive.value = !isActive.value;
  if (isActive.value) {
    // 开始计时：每秒减 1
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        // 时间到了，停止计时
        isActive.value = false;
        _timer?.cancel();
      }
    });
  } else {
    // 暂停计时
    _timer?.cancel();
  }
}
```

### 组员 D - UI 交互

编辑 `lib/ui_widgets.dart`，你需要：

1. 显示倒计时数字和进度条
2. 实现开始/暂停按钮
3. 实现重置按钮

```dart
// 按钮点击时调用 Controller 的方法
ElevatedButton(
  onPressed: () => controller.toggleTimer(),
  child: ValueListenableBuilder<bool>(
    valueListenable: controller.isActive,
    builder: (context, isActive, _) {
      return Text(isActive ? '暂停' : '开始');
    },
  ),
)
```

## 6. 常用调试技巧

### 打印调试信息

```dart
print('当前秒数: ${remainingSeconds.value}');
```

在 VS Code 的 DEBUG CONSOLE 或终端中查看输出。

### 热重载 vs 热重启

- **热重载** (`r`)：保留应用状态，只刷新 UI。改 UI 时用这个。
- **热重启** (`R`)：重置应用状态，重新运行。改逻辑时用这个。

### 常见错误

| 错误信息 | 原因 | 解决方案 |
|----------|------|----------|
| `No connected devices` | 没有连接设备 | 连接手机或启动模拟器 |
| `Could not find a file named "pubspec.yaml"` | 目录不对 | cd 到项目根目录 |
| `The method 'xxx' isn't defined` | 方法不存在 | 检查拼写，确认方法已定义 |

## 7. 图片资源规范

### 为什么用 WebP？

项目统一使用 **WebP** 格式存放图片，原因：

- 体积小：比 PNG 小 80%+，比 JPG 小 30%+
- 质量好：支持透明度，画质损失小
- 兼容性：Flutter 原生支持

### 添加图片的正确姿势

1. 把图片放到 `assets/` 目录下（任何格式都行）
2. 在 `pubspec.yaml` 中注册资源路径
3. 直接 `git commit`

如果你添加的是 PNG 或 JPG，pre-commit 钩子会自动：
1. 将图片转换为 WebP 格式
2. 删除原始的 PNG/JPG 文件
3. 更新暂存区

你只需要**再执行一次 `git commit`** 即可完成提交。

### 手动转换图片

如果需要手动批量转换图片，可以使用脚本：

```bash
# 转换所有超过 500KB 的 PNG/JPG 为 WebP，并删除原文件
uv run scripts/compress_images.py --to-webp --delete

# 预览会被转换的文件（不实际执行）
uv run scripts/compress_images.py --to-webp --dry-run

# 只压缩图片（不转换格式）
uv run scripts/compress_images.py
```

## 8. Git 协作流程

```bash
# 1. 开始工作前，先拉取最新代码
git pull origin main

# 2. 创建自己的分支
git checkout -b feat/你的功能名

# 3. 写代码...

# 4. 提交代码
git add .
git commit -m "feat: 你做了什么"

# 5. 推送到远程
git push origin feat/你的功能名

# 6. 在 GitHub 上创建 Pull Request，等待组长合并
```

## 9. 学习资源

- [Flutter 中文文档](https://flutter.cn/docs)
- [Dart 语言入门](https://dart.cn/guides/language/language-tour)
- [Flutter Widget 目录](https://flutter.cn/docs/reference/widgets)

---

有问题随时在 Notion 里问，大家一起学习进步！💪
