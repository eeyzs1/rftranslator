# rftranslator (rftranslator) 开发规划

## 项目概览

跨平台离线翻译词典应用，基于 Flutter 开发，目标平台为 Windows 和 Android。

## 技术栈

| 层级 | 技术 |
|------|------|
| UI 框架 | Flutter (Material 3 + Fluent UI 双风格) |
| 状态管理 | Riverpod + riverpod_annotation |
| 路由 | go_router |
| 本地存储 | Hive (收藏/历史) + SQLite/ECDict (词典) |
| 翻译引擎 | StarDict 词典 + OPUS-MT (Python 后端) |
| LLM 推理 | Python 子进程通信 (JSON over stdin/stdout) |
| 模型下载 | Dio + HuggingFace/ModelScope 双源 |

## 当前架构

```
┌─ UI 层 ─────────────────────────────────────┐
│  InitScreen → TranslationScreen (翻译首页)  │
│  HomeScreen (词典搜索，/dictionary)          │
│  FavoritesScreen / HistoryScreen / Settings  │
└──────────────────────────────────────────────┘
         ↓
┌─ 业务逻辑层 (Riverpod Providers) ──────────┐
│  TranslationNotifier (翻译状态管理)          │
│  DictionaryManager (词典管理/下载)           │
│  ModelManager (模型管理/下载)                │
│  LlmService (LLM/OPUS-MT 服务)              │
└──────────────────────────────────────────────┘
         ↓
┌─ 数据/能力层 ───────────────────────────────┐
│  DictionaryLocalDataSource (ECDict SQLite)   │
│  StarDictDataSource (StarDict 格式词典)      │
│  PythonLlmDataSource (Python子进程通信)      │
│  Python后端: llm_server.py (OPUS-MT/StarDict)│
└──────────────────────────────────────────────┘
```

---

## Phase 1: 核心翻译功能完善（高优先级） ✅ 已完成

| 任务 | 说明 | 状态 |
|------|------|------|
| 1.1 翻译页集成到主导航 | 翻译页作为首页Tab（`/`），词典搜索移至 `/dictionary` | ✅ 已完成 |
| 1.2 语言选择器与词典联动 | 根据用户下载的词典动态显示可用语言对，Language枚举扩展至11种语言 | ✅ 已完成 |
| 1.3 翻译历史与收藏完善 | 翻译结果添加收藏按钮（⭐）、词典查询入口、翻译来源标签 | ✅ 已完成 |
| 1.4 修复编译错误 | flutter analyze 零错误 | ✅ 已完成 |

### Phase 1 变更文件清单

- `lib/core/router/app_router.dart` — 导航结构重构，翻译页为首页
- `lib/core/localization/app_localizations.dart` — 新增8个国际化键
- `lib/features/translation/presentation/screens/translation_screen.dart` — 添加收藏按钮、词典查询入口、来源标签
- `lib/features/translation/presentation/providers/translation_provider.dart` — 多语言支持，词典联动查询
- `lib/features/translation/domain/entities/language.dart` — 扩展至11种语言
- `lib/features/dictionary/presentation/screens/home_screen.dart` — 路由路径更新

## Phase 2: AI增强翻译（高优先级） ✅ 已完成

| 任务 | 说明 | 状态 |
|------|------|------|
| 2.1 OPUS-MT多语言对支持 | 扩展翻译引擎支持20种语言对（11种语言互译），Python后端和Dart模型管理器同步更新 | ✅ 已完成 |
| 2.2 混合翻译策略优化 | 单词→词典优先→OPUS-MT兜底；长句→OPUS-MT；自动检测模型是否已下载 | ✅ 已完成 |
| 2.3 翻译状态指示优化 | 渐进式翻译：先显示词典快速结果，OPUS-MT加载中显示进度，完成后追加展示 | ✅ 已完成 |

### Phase 2 变更文件清单

- `python_backend/llm_server.py` — 扩展支持20种语言对的OPUS-MT模型映射，动态模型文件夹名
- `lib/features/llm/domain/model_manager.dart` — ModelType枚举扩展至20种语言对，新增languagePair/pythonModelTypeKey属性
- `lib/features/translation/presentation/providers/translation_provider.dart` — 渐进式翻译流程，TranslationState新增isTranslatingWithLLM/llmTranslation字段
- `lib/features/translation/presentation/screens/translation_screen.dart` — 新增LLM加载卡片和LLM结果卡片组件

## Phase 3: 体验优化（中/低优先级）

| 任务 | 说明 | 状态 |
|------|------|------|
| 3.1 Fluent UI 适配完善 | 翻译页、设置页等适配 Fluent 风格 | 待完成 |
| 3.2 TTS发音集成 | 集成 flutter_tts 实现单词/句子朗读 | 待完成 |
| 3.3 翻译动画与反馈 | 翻译中加载动画、结果渐显效果 | 待完成 |
| 3.4 国际化完善 | 补全所有界面的中英文翻译 | 待完成 |
