# 功能架构设计

## 1. 架构设计总原则

### 1.1 核心约束（刚性）
1. **纯本地化**：所有功能必须不依赖远程 API，完全离线可用
2. **非侵入式**：不能修改底层依赖的源码（如 sds 模块）
3. **最小变更**：优先扩展而非重构，保持现有功能稳定

### 1.2 三层架构
```
┌─────────────────────────────────────────────────┐
│          UI 层 (Flutter)                       │
│  - 主翻译界面、词典管理、设置页、模型下载      │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│      业务逻辑层 (Dart Provider)                │
│  - 翻译状态管理、查询历史、模型管理             │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│       数据/能力层                                │
│  ├── SQLite：本地历史记录和自定义词典          │
│  ├── StarDictNative：纯 Dart StarDict 解析     │
│  ├── MDict：mdict_reader 插件解析              │
│  └── llamadart：本地 LLM 推理 (GGUF 模型)     │
└─────────────────────────────────────────────────┘
```

> **架构变更记录 (2026-04-15)**：
> - 词典层：Python pystardict → 纯 Dart `StarDictNativeDataSource`
> - LLM 层：Python 后端 → `llamadart` 插件 (基于 llama.cpp)
> - 移除了 Python 进程依赖，实现完全 Flutter 原生化

---

## 2. 本地翻译模块（Encoder-Decoder 架构）

### 2.1 核心功能
- **StarDict 词典**：单词、短语翻译
- **MarianNMT/OPUS-MT**：长句、段落翻译（Encoder-Decoder 架构）
- **兜底策略**：单词/短语词典查询失败 → Encoder-Decoder 模型翻译

### 2.2 架构设计
```
用户输入
    │
    ▼
┌─────────────────────────────────────────┐
│         文本类型判断                      │
│  - 单词/短语（≤3 词，≤20 字符）         │
│  - 长句/段落（>3 词 或 >20 字符）       │
└─────────────────────────────────────────┘
    │
    ├─── 单词/短语 ──▶ StarDict 词典查询
    │                         │
    │                         ├─ 找到 → 返回词典结果
    │                         └─ 未找到 → Encoder-Decoder 模型兜底翻译
    │
    └─── 长句/段落 ──▶ Encoder-Decoder 模型翻译
```

### 2.3 推荐模型（已确定）

#### 2.3.1 支持的模型列表

| 模型 | 语言对 | 大小 | 适用场景 | 最低RAM | 推荐RAM | 存储需求 |
|------|--------|------|----------|---------|---------|----------|
| OPUS-MT | en→zh | ~150MB | 英语→中文 | 2GB | 4GB | 300MB |
| OPUS-MT | zh→en | ~150MB | 中文→英语 | 2GB | 4GB | 300MB |
| MarianMT | en→de | ~250MB | 英语→德语 | 3GB | 6GB | 500MB |
| MarianMT | en→fr | ~250MB | 英语→法语 | 3GB | 6GB | 500MB |
| MarianMT | en→es | ~250MB | 英语→西班牙语 | 3GB | 6GB | 500MB |
| M2M-100 418M | 100+ 语言 | ~1.5GB | 多语言互译 | 6GB | 12GB | 3GB |

#### 2.3.2 硬件配置说明

| 配置级别 | 适用的模型 | 推荐配置 |
|---------|-----------|---------|
| 入门级 | OPUS-MT en/zh | 4GB RAM, 10GB 存储 |
| 中级 | MarianMT 系列 | 8GB RAM, 20GB 存储 |
| 高级 | M2M-100 | 16GB RAM, 50GB 存储 |

#### 2.3.3 下载源

支持两种下载源：

| 下载源 | 说明 | 国内可用性 |
|--------|------|-----------|
| **Hugging Face** | 官方源 | 可能需要代理 |
| **ModelScope** | 阿里云模型库 | ✅ 推荐国内用户 |

系统会自动检测最佳下载源，也允许用户手动选择。

### 2.4 模型下载管理
- **选择下载**：用户在设置中选择并下载所需模型
- **支持删除**：已下载的模型可以删除
- **首次使用引导**：无模型时提示下载

### 2.5 Flutter 原生集成（已实现）

> **变更记录 (2026-04-15)**：已从 Python 后端迁移到 Flutter 原生方案。

#### 2.5.1 StarDict 词典 — 纯 Dart 实现

`StarDictNativeDataSource` 直接解析 StarDict 格式文件，无需 Python：
- 解析 `.ifo` 文件获取词典元信息
- 加载 `.idx`/`.idx.gz` 索引到内存（支持 gzip 压缩）
- 二分搜索快速查词
- 读取 `.dict`/`.dict.dz` 释义数据（支持 gzip 压缩）
- HTML 标签清理、音标提取、中文释义提取

#### 2.5.2 LLM 翻译 — llamadart 插件

`LlamaCppDataSource` 通过 `llamadart` 插件调用 llama.cpp：
- 支持 GGUF 格式量化模型
- 流式输出（`Stream<String>`）
- GPU 加速（Windows: Vulkan, macOS: Metal）
- 零配置 — 自动下载原生运行时

#### 2.5.3 插件选型决策

| 插件 | 平台支持 | 离线 | Windows | 选/不选原因 |
|------|----------|------|---------|------------|
| **llamadart** ✅ | 全平台 | ✅ | ✅ Vulkan | 零配置、全平台、GPU加速、活跃维护 |
| google_mlkit_translation | iOS/Android | ✅ | ❌ | 不支持 Windows |
| flutter_llama | iOS/Android/macOS | ✅ | ❌ | 不支持 Windows |
| argos_translate_dart | 全平台 | ⚠️ | ✅ | 仍依赖 Python 运行时 |

---

## 3. 词典管理模块

### 3.1 StarDict 支持
- **纯 Dart 解析**：`StarDictNativeDataSource` 直接读取 StarDict 文件，无需 Python
- **多格式支持**：.ifo, .idx, .idx.gz, .dict, .dict.dz
- **二分搜索**：索引加载到内存后使用二分查找，340万词条查词 < 1ms
- **语言对持久化**：翻译后自动保存语对到 SharedPreferences，启动时预加载对应词典

### 3.2 内置词典
- **Wiktionary (EN-ZH)**：作为默认内置词典
- **不打包进 APK**：首次启动时释放或提示下载（策略见 docs/05）

---

## 4. 历史记录与收藏

### 4.1 本地 SQLite
表结构：
```sql
CREATE TABLE history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_text TEXT NOT NULL,
    target_text TEXT NOT NULL,
    source_lang TEXT,
    target_lang TEXT,
    translated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 5. 平台适配层（概要）

详见 [docs/04_cross_platform_design.md](./04_cross_platform_design.md)
