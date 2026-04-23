<div align="center">

# rftranslator

**R**eal **F**ree Translator — 真正免费的离线翻译词典

[![CI](https://github.com/eeyzs1/rftranslator/actions/workflows/ci.yml/badge.svg)](https://github.com/eeyzs1/rftranslator/actions/workflows/ci.yml)
[![Release](https://github.com/eeyzs1/rftranslator/actions/workflows/release.yml/badge.svg)](https://github.com/eeyzs1/rftranslator/actions/workflows/release.yml)
[![Release](https://img.shields.io/github/v/release/eeyzs1/rftranslator?include_prereleases)](https://github.com/eeyzs1/rftranslator/releases)

厌倦了开屏广告？厌倦了翻译 App 里无处不在的弹窗和推广？\
rftranslator 的初心很简单——做一个 **Real Free** 的翻译工具：没有广告，没有订阅，不需要联网，你的翻译完全由你自己掌控。

[下载最新版本](https://github.com/eeyzs1/rftranslator/releases) · [功能特性](#-功能特性) · [快速开始](#-快速开始)

</div>

---

## ✨ 功能特性

### 🔤 双引擎翻译

| 输入类型 | 翻译引擎 | 说明 |
|---------|---------|------|
| 单词 / 短语（≤3 词且 ≤50 字符） | 离线词典 | 查询音标、释义、例句，支持多词典结果并列展示 |
| 句子 / 段落 | 本地 AI 模型 | 基于 OPUS-MT + CTranslate2 的本地神经机器翻译 |
| 词典未收录 | 自动回退 | 词典查不到时自动切换到 AI 模型翻译 |

### 📚 丰富的词典资源（100+ 册）

- **ECDICT** — 超过 300 万词条英汉词典（SQLite + StarDict 双格式）
- **Wiktionary StarDict** — 多语言对维基词典（英→X 30 册、法→X 14 册、西→X 5 册）
- **FreeDict** — 多语言对开源词典（10 册，含中英、中俄、中印尼等）
- **WikDict** — 多语言对维基词典（45+ 册，覆盖中、日、英、葡等语言对）
- **MDict (.mdx)** — 支持用户导入
- **StarDict** — 支持用户导入文件夹

### 🤖 本地 AI 翻译模型

- 32 种 OPUS-MT 语言对，全部基于 CTranslate2 格式
- 下载源支持自动检测、Hugging Face、ModelScope（国内推荐）
- 支持从本地文件夹导入模型
- 翻译推理在独立 Isolate 中运行，不阻塞 UI
- 支持多模型并行翻译，结果独立展示

### 🌍 支持 19 种语言

英语、中文、日语、韩语、法语、德语、西班牙语、俄语、意大利语、葡萄牙语、阿拉伯语、越南语、芬兰语、瑞典语、保加利亚语、希伯来语、马来语、荷兰语、乌克兰语

### 🎨 可定制的外观

- **Material 3** — 底部导航栏，适合移动端
- **Fluent Design** — 侧边导航栏，适合桌面端
- **自适应** — 根据平台自动选择
- 12 种预设主题色 + 浅色/深色/跟随系统

### 📦 其他

- 收藏夹 — 收藏常用翻译结果
- 历史记录 — 自动保存翻译历史
- 语音朗读 — TTS 朗读翻译结果
- 中英双语界面 — 完整的国际化支持
- Windows 安装包 — 注册到系统，支持 Windows Search 搜索

---

## 🖼️ 截图

> 翻译主界面 | 词典查询结果 | 设置页面

---

## 🚀 快速开始

### 下载安装

前往 [Releases](https://github.com/eeyzs1/rftranslator/releases) 页面下载最新版本：

| 文件 | 说明 |
|------|------|
| `rftranslator-x.x.x-setup.exe` | Windows 安装版（推荐，注册到系统搜索） |
| `rftranslator-x.x.x.zip` | Windows 便携版（解压即用） |

### 首次使用

1. 启动应用后，进入 **设置 → 翻译模型** 下载所需语言对的模型
2. 进入 **设置 → 词典管理** 下载词典（推荐先下载 ECDICT 英汉词典）
3. 回到主界面即可开始翻译

### 从源码构建

**前置条件：**

- Flutter SDK >= 3.4.0
- CTranslate2 运行时库（Windows: `ctranslate2.dll`）

**构建步骤：**

```bash
# 克隆仓库
git clone https://github.com/eeyzs1/rftranslator.git
cd rftranslator

# 安装依赖
flutter pub get

# 生成代码（Provider、Hive Adapter 等）
dart run build_runner build --delete-conflicting-outputs

# 构建 Windows Release
flutter build windows --release
```

> **注意：** 翻译功能需要 CTranslate2 运行时库。请参考 `scripts/` 目录下的构建脚本编译，或将预编译的 `ctranslate2.dll` 放置到 `build/windows/x64/runner/Release/` 目录中。

---

## 🏗️ 项目结构

```
lib/
├── main.dart                                    # 入口：Hive 初始化、窗口管理
├── app.dart                                     # 根组件：Material / Fluent 双 UI 切换
├── core/
│   ├── di/providers.dart                        # 依赖注入 Provider
│   ├── ffi/ctranslate2_ffi.dart                 # CTranslate2 FFI 绑定
│   ├── localization/app_localizations.dart       # 国际化（中英双语）+ 设置状态
│   ├── router/app_router.dart                   # 路由配置 + 导航
│   ├── storage/resource_registry.dart            # 资源注册表（模型/词典路径）
│   ├── ui/                                      # UI 风格适配
│   │   ├── adaptive_widgets.dart
│   │   ├── dual_platform_adapter.dart
│   │   └── ui_style_wrapper.dart
│   └── utils/
│       ├── app_toast.dart
│       └── platform_utils.dart
├── features/
│   ├── dictionary/                              # 词典模块
│   │   ├── data/datasources/                    # SQLite / StarDict / MDict 数据源
│   │   ├── domain/                              # DictionaryManager / WordEntry
│   │   └── presentation/                        # 词典管理 / 搜索
│   ├── favorites/                               # 收藏模块（Hive）
│   ├── history/                                 # 历史模块（Hive）
│   ├── llm/                                     # 翻译模型模块
│   │   ├── data/datasources/                    # CTranslate2 / llama.cpp / Gemma / OPUS-MT
│   │   └── domain/                              # LlmService / ModelManager
│   ├── main/                                    # 主页面（Material / Fluent 双版本）
│   ├── settings/                                # 设置模块
│   └── translation/                             # 翻译模块（核心业务逻辑）
│       ├── data/                                # TranslationHistory / Repository
│       ├── domain/                              # Language / TranslationResult
│       └── presentation/                        # TranslationScreen / TranslationProvider
├── presentation/shell/                          # 导航 Shell（Material / Fluent / Main）
└── shared/widgets/                              # 共享组件
```

---

## 🛠️ 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter |
| 状态管理 | Riverpod + 代码生成 |
| 路由 | GoRouter |
| 本地存储 | Hive + SQLite |
| 本地推理 | CTranslate2 (FFI) + llamadart (llama.cpp) |
| UI | Material 3 + Fluent UI |
| 词典解析 | StarDict + MDict |
| CI/CD | GitHub Actions |
| 安装包 | Inno Setup |

---

## 📄 许可证

本项目仅供个人学习和研究使用。未经授权，不得用于商业用途。

---

<div align="center">

**Real Free. No Ads. No Cloud. No Tracking.**

</div>
