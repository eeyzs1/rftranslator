# 双端适配设计 — rftranslator

> **注意**：本文档描述当前已实现的跨平台适配。以源码为准。

## 1. 适配策略总览

```
┌─────────────────────────────────────────────────────────┐
│                   共享层（~80%代码）                      │
│  业务逻辑 / 状态管理 / 数据层 / 核心 UI 组件              │
├──────────────────────┬──────────────────────────────────┤
│   Android 适配层     │        Windows 适配层             │
│   (~10%代码)         │        (~10%代码)                 │
│  - Material 风格     │  - Fluent 风格                    │
│  - 底部导航栏        │  - 侧边导航栏                     │
│  - 软键盘处理        │  - 菜单栏 / 快捷键                │
│  - 长按操作          │  - 右键上下文菜单                 │
│  - 系统返回键        │  - 窗口大小调整                   │
└──────────────────────┴──────────────────────────────────┘
```

UI 风格由设置中的 `UIStyle` 控制（Material / Fluent / Adaptive），而非硬编码按平台区分。

---

## 2. 布局适配

### 2.1 导航结构

**Material 风格（底部导航栏）：**
```
┌─────────────────┐
│    内容区域      │
│                 │
│                 │
├─────────────────┤
│ 翻译 收藏 历史 设置 │  ← NavigationBar
└─────────────────┘
```

**Fluent 风格（侧边导航栏）：**
```
┌──────┬──────────────────────┐
│ 翻译 │                      │
│ 收藏 │      内容区域         │
│ 历史 │                      │
│ 设置 │                      │
└──────┴──────────────────────┘
  ↑ NavigationRail
```

**自适应模式：** 桌面端自动使用 Fluent，移动端使用 Material。

---

## 3. UI 风格切换

应用支持三种 UI 风格，在设置中切换：

| 风格 | App 类型 | 导航方式 |
|------|---------|---------|
| Material 3 | `MaterialApp` | 底部 NavigationBar |
| Fluent | `FluentApp` (fluent_ui) | 侧边 NavigationRail |
| Adaptive | 根据平台自动选择 | 桌面 Fluent / 移动 Material |

切换在 `App` 组件中实现，根据 `SettingsState.uiStyle` 决定渲染 `MaterialApp` 还是 `FluentApp`。

---

## 4. 主题适配

两端均支持浅色/深色/跟随系统三种主题模式，用户可在设置中自由切换。

主题色支持 12 种预设色，默认 `#E8002D`（红色），使用 `ColorScheme.fromSeed` 生成完整配色。

---

## 5. 窗口管理（Windows）

```dart
Future<void> initWindowManager() async {
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(400, 600));
  await windowManager.setSize(const Size(900, 700));
  await windowManager.setTitle('rftranslator');
  await windowManager.center();
  await windowManager.show();
}
```

---

## 6. 平台工具类

```dart
class PlatformUtils {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  static bool get isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
```

---

## 7. TTS 适配

使用 `flutter_tts` 插件，两端统一接口，不区分英式/美式口音。

---

## 8. 本地推理适配

| 平台 | CTranslate2 | llamadart |
|------|-------------|-----------|
| Windows | `ctranslate2.dll` (dart:ffi) | llama.cpp (Vulkan GPU) |
| Android | `libctranslate2.so` (dart:ffi) | — |

翻译推理在独立 Isolate 中运行，不阻塞 UI 线程。
