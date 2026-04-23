# 开发指南 — rftranslator

> **注意**：本文档描述当前的开发流程。以源码为准。

## 1. 环境要求

| 工具 | 版本 |
|------|------|
| Flutter SDK | >= 3.4.0 |
| Dart SDK | 随 Flutter |
| Android Studio | 最新稳定版（Android 开发） |
| Visual Studio | 2022 + C++ 桌面开发（Windows 开发） |
| CTranslate2 | 预编译运行时库 |

---

## 2. 项目搭建

```bash
# 克隆仓库
git clone https://github.com/eeyzs1/rftranslator.git
cd rftranslator

# 安装依赖
flutter pub get

# 生成代码（Provider、Hive Adapter 等）
dart run build_runner build --delete-conflicting-outputs

# 运行（Debug）
flutter run

# 构建 Windows Release
flutter build windows --release
```

---

## 3. 项目结构

```
lib/
├── main.dart                                    # 入口
├── app.dart                                     # 根组件（Material / Fluent 切换）
├── core/
│   ├── di/providers.dart                        # 依赖注入
│   ├── ffi/ctranslate2_ffi.dart                 # CTranslate2 FFI 绑定
│   ├── localization/app_localizations.dart       # 国际化 + 设置状态
│   ├── router/app_router.dart                   # 路由配置
│   ├── storage/resource_registry.dart            # 资源注册表
│   ├── ui/                                      # UI 风格适配
│   └── utils/                                   # 工具类
├── features/
│   ├── dictionary/                              # 词典模块
│   ├── favorites/                               # 收藏模块
│   ├── history/                                 # 历史模块
│   ├── llm/                                     # 翻译模型模块
│   ├── main/                                    # 主页面
│   ├── settings/                                # 设置模块
│   └── translation/                             # 翻译模块
├── presentation/shell/                          # 导航 Shell
└── shared/widgets/                              # 共享组件
```

---

## 4. 关键依赖

| 依赖 | 用途 |
|------|------|
| `flutter_riverpod` + `riverpod_annotation` | 状态管理 + 代码生成 |
| `go_router` | 路由 |
| `hive` + `hive_flutter` | 本地存储（历史、收藏） |
| `sqflite` | SQLite 词典数据 |
| `ffi` | CTranslate2 FFI 绑定 |
| `llamadart` | llama.cpp GGUF 模型推理 |
| `fluent_ui` | Fluent Design UI |
| `dio` | 网络请求（模型/词典下载） |
| `flutter_tts` | 语音朗读 |
| `window_manager` | Windows 窗口管理 |
| `file_picker` | 文件选择 |
| `mdict_reader` | MDict 词典解析 |
| `archive` | ZIP 解压 |
| `shared_preferences` | 设置持久化 |

---

## 5. 代码生成

项目使用 `build_runner` 生成代码：

```bash
# 一次性生成
dart run build_runner build --delete-conflicting-outputs

# 监听模式
dart run build_runner watch --delete-conflicting-outputs
```

生成的文件：
- `*.g.dart` — Riverpod Provider、Hive Adapter
- `*.freezed.dart` — 不可变数据类（如有）

---

## 6. CI/CD

### CI（每次 push / PR）
- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs`
- `dart analyze --no-fatal-warnings`
- `flutter test`
- `flutter build windows --release`（验证构建）

### Release（推送 `v*` 标签时）
- 构建 Windows Release
- 创建 ZIP 便携版
- 编译 Inno Setup 安装程序
- 上传到 GitHub Release

---

## 7. CTranslate2 运行时库

翻译功能依赖 CTranslate2 运行时库。构建脚本位于 `scripts/`：

| 脚本 | 说明 |
|------|------|
| `build_ctranslate2_windows.ps1` | Windows 编译 |
| `build_ctranslate2_windows_local.ps1` | Windows 本地编译 |
| `build_ctranslate2_android.sh` | Android 编译 |
| `build_android_wsl.sh` | WSL 环境 Android 构建 |

Windows 构建产物 `ctranslate2.dll` 需放置在 `build/windows/x64/runner/Release/` 目录中。
