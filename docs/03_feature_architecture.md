# 功能架构设计 — rftranslator

> **注意**：本文档描述当前已实现的功能架构。以源码为准。

## 1. 架构设计总原则

### 1.1 核心约束（刚性）
1. **纯本地化**：所有功能必须不依赖远程 API，完全离线可用
2. **Real Free**：无广告、无订阅、无追踪
3. **双引擎翻译**：词典查询 + AI 模型翻译

### 1.2 三层架构
```
┌─────────────────────────────────────────────────┐
│          UI 层 (Flutter)                        │
│  - Material 3 / Fluent Design 双风格           │
│  - 翻译主界面、词典管理、设置页、模型下载       │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│      业务逻辑层 (Riverpod)                      │
│  - 翻译状态管理、查询历史、模型管理             │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│       数据/能力层                                │
│  ├── Hive：历史记录、收藏                       │
│  ├── SQLite：ECDICT 词典数据                    │
│  ├── StarDictNative：纯 Dart StarDict 解析      │
│  ├── MDict：mdict_reader 插件解析               │
│  ├── CTranslate2 (FFI)：OPUS-MT 模型推理       │
│  └── llamadart：llama.cpp GGUF 模型推理        │
└─────────────────────────────────────────────────┘
```

---

## 2. 本地翻译模块

### 2.1 核心功能
- **离线词典**：单词、短语翻译（ECDICT / StarDict / MDict）
- **OPUS-MT + CTranslate2**：长句、段落翻译
- **兜底策略**：单词/短语词典查询失败 → OPUS-MT 模型翻译

### 2.2 架构设计
```
用户输入
    │
    ▼
┌─────────────────────────────────────────┐
│         文本类型判断                      │
│  - 单词/短语（≤3 词，≤50 字符）         │
│  - 长句/段落（>3 词 或 >50 字符）       │
└─────────────────────────────────────────┘
    │
    ├─── 单词/短语 ──▶ 词典查询
    │                         │
    │                         ├─ 找到 → 返回词典结果
    │                         └─ 未找到 → OPUS-MT 模型兜底翻译
    │
    └─── 长句/段落 ──▶ OPUS-MT 模型翻译
```

### 2.3 支持的翻译模型

32 种 OPUS-MT 语言对，全部基于 CTranslate2 格式：

| 语言对方向 | 模型数量 | 示例 |
|-----------|---------|------|
| en↔zh | 2 | opus-mt-en-zh, opus-mt-zh-en |
| en→X | 14 | en→ja, en→ko, en→fr, en→de, ... |
| X→en | 14 | ja→en, ko→en, fr→en, de→en, ... |
| 其他语言对 | 2 | fr→de, de→fr |

### 2.4 下载源

支持三种下载源选项：

| 下载源 | 说明 | 国内可用性 |
|--------|------|-----------|
| **自动检测** | 先尝试 HuggingFace，失败回退 ModelScope | ✅ 推荐 |
| **Hugging Face** | 官方源 | 可能需要代理 |
| **ModelScope** | 阿里云模型库 | ✅ 推荐国内用户 |

另外支持从本地文件夹导入 CTranslate2 格式模型。

### 2.5 CTranslate2 FFI 集成

`Ctranslate2Datasource` 通过 `dart:ffi` 直接调用 CTranslate2 C 库：
- 翻译推理在独立 Isolate 中运行（`TranslationIsolateWorker`）
- 支持模型热切换、超时重启、关闭信号
- Windows 使用 `ctranslate2.dll`，Android 使用 `libctranslate2.so`

---

## 3. 词典管理模块

### 3.1 词典资源（100+ 册）

| 来源 | 数量 | 格式 | 说明 |
|------|------|------|------|
| ECDICT | 2 | SQLite + StarDict | 超过 300 万词条英汉词典 |
| Wiktionary StarDict | 49 | StarDict | 英→X 30册、法→X 14册、西→X 5册 |
| FreeDict | 10 | StarDict | 含中英、中俄、中印尼等 |
| WikDict | 45+ | ZIP | 覆盖中、日、英、葡等语言对 |
| 用户导入 | — | MDict (.mdx) / StarDict | 支持用户自行导入 |

### 3.2 StarDict 支持
- **纯 Dart 解析**：`StarDictNativeDataSource` 直接读取 StarDict 文件
- **多格式支持**：.ifo, .idx, .idx.gz, .dict, .dict.dz
- **二分搜索**：索引加载到内存后使用二分查找
- **语言对持久化**：翻译后自动保存语对，启动时预加载对应词典

### 3.3 词典优先级

查询时按以下优先级遍历已选词典：
1. ECDICT (SQLite)
2. ECDICT (StarDict)
3. MDict
4. 大型 StarDict 词典
5. WikDict
6. FreeDict

---

## 4. 历史记录与收藏

### 4.1 存储：Hive

历史记录和收藏均使用 Hive 本地存储，非 SQLite。

**TranslationHistory 字段：**
- sourceText, targetText, sourceLang, targetLang
- translatedAt, source (opusMt / dictionary)
- isWordOrPhrase, isFavorite

**FavoriteWord 字段：**
- word, translation, sourceLang, targetLang
- addedAt, pronunciation, briefDefinition

---

## 5. 平台适配层

详见 [docs/04_cross_platform_design.md](./04_cross_platform_design.md)
