# 本地翻译架构指南 — Flutter 原生方案

> **变更记录 (2026-04-15)**：从 Python 后端方案迁移到 Flutter 原生方案。
> - 词典：Python pystardict → 纯 Dart `StarDictNativeDataSource`
> - LLM：Python llama-cpp-python → `llamadart` 插件
> - OPUS-MT：Python MarianNMT → 暂由 LLM 替代（未来可集成 onnxruntime）

## 1. 架构概览

本项目采用**Flutter 原生混合架构**，根据文本类型自动选择最优翻译引擎：

```
┌─────────────────────────────────────────────────────────┐
│                    翻译请求                              │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│              文本长度/复杂度判断                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │ 单词/短语：≤ 3 词 且 ≤ 50 字符                    │  │
│  │  → 使用 StarDict 词典查询（纯 Dart，快速准确）    │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │ 长句/段落：> 3 词 或 > 50 字符                    │  │
│  │  → 使用 LLM 翻译（llamadart + GGUF 模型）         │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
                ┌───────────────────┐
                │  翻译成功？        │
                └───────────────────┘
                      │   │
                   是 │   │ 否
                      │   │
                      ▼   ▼
           返回结果      显示错误提示
```

**核心约束：纯本地，不调用任何远程 API，不依赖 Python。**

---

## 2. 组件选型

### 2.1 翻译引擎对比

| 引擎类型 | 实现方式 | 适用场景 | 优势 | 劣势 |
|----------|----------|----------|------|------|
| **词典查询** | StarDictNativeDataSource (纯 Dart) | 单词、短语 | 快速、准确、无需额外模型 | 仅支持词典中的词条 |
| **LLM 翻译** | llamadart 插件 (llama.cpp FFI) | 长句、段落 | 灵活、支持任意语言对 | 需下载模型、资源占用大 |

### 2.2 LLM 插件选型决策

| 插件 | 平台支持 | 离线 | Windows | GPU加速 | 选/不选原因 |
|------|----------|------|---------|---------|------------|
| **llamadart** ✅ | 全平台+Web | ✅ | ✅ Vulkan | ✅ | **最终选择**：零配置、全平台、GPU加速、活跃维护(v0.6.10) |
| google_mlkit_translation | iOS/Android | ✅ | ❌ | N/A | 不支持 Windows 桌面端 |
| flutter_llama | iOS/Android/macOS | ✅ | ❌ | ✅ Metal | 不支持 Windows 桌面端 |
| argos_translate_dart | 全平台 | ⚠️ | ✅ | ❌ | 仍依赖 Python 运行时，离线功能有缺陷 |
| llama_cpp_dart | 全平台 | ✅ | ✅ | ✅ | 需手动编译共享库，配置复杂 |

**选择 llamadart 的核心理由：**
1. **零配置**：使用 Dart Native Assets 机制，首次运行自动下载原生运行时
2. **Windows 支持**：Vulkan GPU 加速，性能优异
3. **全平台**：Android/iOS/macOS/Linux/Windows/Web
4. **API 简洁**：`LlamaEngine` + `generate()` 流式输出

---

## 3. StarDict 词典 — 纯 Dart 实现

### 3.1 实现架构

```
StarDictNativeDataSource
├── _parseIfoFile()     → 解析 .ifo 文件获取词典元信息
├── _loadIndex()        → 加载 .idx/.idx.gz 索引到内存
│   ├── 二进制索引解析：word\0 + offset(4B) + size(4B)
│   └── gzip 解压支持（.idx.gz 格式）
├── _binarySearch()     → 二分查找词条
├── _readDefinition()   → 读取 .dict/.dict.dz 释义
│   ├── RandomAccessFile 直接读取（.dict）
│   └── 全量解压后读取（.dict.dz）
└── _parseDefinition()  → 解析原始释义为 WordEntry
    ├── _stripHtmlTags()       → 清理 HTML 标签
    ├── _extractPhonetic()     → 提取音标
    └── _extractChineseText()  → 提取中文释义
```

### 3.2 性能数据

| 词典 | 词条数 | 索引加载时间 | 查词延迟 |
|------|--------|-------------|---------|
| 简明英汉字典增强版 (ecdict) | 3,402,564 | ~2s | < 1ms |
| English-中文 FreeDict | 26,666 | ~0.1s | < 1ms |

### 3.3 语言对持久化

翻译成功后自动保存语言对到 SharedPreferences，启动时预加载对应词典：

```dart
// 保存
await dictManager.saveRecentLangPair(sourceLang, targetLang);

// 读取并预加载
final pairs = await dictManager.getRecentLangPairs();
await dictManager.preloadRecentDictionaries(pairs);
```

---

## 4. LLM 翻译 — llamadart 集成

### 4.1 依赖配置

```yaml
# pubspec.yaml
dependencies:
  llamadart: ^0.6.9
```

### 4.2 LlamaCppDataSource 实现

```dart
class LlamaCppDataSource implements LlmDataSource {
  LlamaEngine? _engine;

  @override
  Future<void> loadModel(String modelPath) async {
    _engine = LlamaEngine(LlamaBackend());
    await _engine!.loadModel(modelPath);
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) {
    return _engine!.generate(prompt);
  }

  @override
  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
  }
}
```

### 4.3 推荐模型

| 模型 | 大小 (Q4_K_M) | 适用场景 | 最低RAM | 推荐RAM |
|------|---------------|----------|---------|---------|
| Qwen2.5-0.5B-Instruct | ~400MB | 轻量翻译 | 2GB | 4GB |
| Qwen2.5-1.5B-Instruct | ~1GB | 平衡翻译 | 4GB | 8GB |
| Qwen2.5-3B-Instruct | ~2GB | 高质量翻译 | 8GB | 12GB |
| 腾讯混元 HY-MT 1.5-1.8B | ~1GB | 专用翻译模型 | 4GB | 8GB |

### 4.4 GPU 加速配置

| 平台 | GPU 后端 | 配置方式 |
|------|----------|---------|
| Windows | Vulkan | 默认启用 |
| macOS/iOS | Metal | 默认启用 |
| Android | Vulkan (可选) | pubspec.yaml 配置 |
| Linux | Vulkan | 默认启用 |

```yaml
# pubspec.yaml - 可选 GPU 后端配置
hooks:
  user_defines:
    llamadart:
      llamadart_native_backends:
        platforms:
          windows-x64: [vulkan, cuda]
```

---

## 5. 翻译流程

### 5.1 完整翻译流程

```
用户输入文本
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
    │                         ├─ 找到 → 返回词典结果 + 保存语言对
    │                         └─ 未找到 → LLM 翻译 + 保存语言对
    │
    └─── 长句/段落 ──▶ LLM 翻译 + 保存语言对
```

### 5.2 降级策略

```
用户发起翻译
    │
    ├─── 词典可用？ ──是──▶ 使用词典（单词/短语）
    │       │
    │       否
    │       │
    ├─── LLM 可用？ ──是──▶ 使用 LLM
    │       │
    │       否
    │       │
    └─── 显示"翻译功能暂不可用，请下载模型"
```

---

## 6. 模型文件管理

### 6.1 模型存储路径

```
Windows: %USERPROFILE%\Documents\rftranslator\models\
├── qwen2.5-1.5b-instruct-q4_k_m.gguf
└── hy-mt-1.5b-q4_k_m.gguf
```

### 6.2 模型下载

支持从 HuggingFace 下载 GGUF 模型：
- 自动检测最佳下载源
- 支持断点续传
- 显示实时进度

---

## 7. 迁移记录：Python → Flutter 原生

### 7.1 迁移内容

| 模块 | 迁移前 (Python) | 迁移后 (Flutter 原生) |
|------|-----------------|---------------------|
| StarDict 词典 | pystardict + Python 进程 | StarDictNativeDataSource (纯 Dart) |
| LLM 推理 | llama-cpp-python + Python 进程 | llamadart 插件 (FFI) |
| OPUS-MT | MarianNMT + Python 进程 | 暂由 LLM 替代 |
| 词典解压 | Python zstandard | Dart gzip + 系统 tar |
| 模型下载 | Python requests | Dart dio |

### 7.2 迁移收益

| 维度 | 迁移前 | 迁移后 |
|------|--------|--------|
| 平台依赖 | ❌ 需要 Python 环境 | ✅ 纯 Dart，无外部依赖 |
| 启动速度 | 慢（需启动 Python 进程） | 快（直接加载） |
| 部署复杂度 | 高（需打包 Python） | 低（单一二进制） |
| Windows 支持 | ⚠️ 需要用户安装 Python | ✅ 原生支持 |
| 维护成本 | 高（双语言栈） | 低（统一技术栈） |

### 7.3 Bug 修复记录

**问题**：应用启动时不加载上次使用的语对词典
- **根因**：`_saveToHistory()` 只在 OPUS-MT 翻译成功时调用，词典查词成功时不保存语言对
- **修复**：在 `_tryOpusMtTranslation()` 的所有退出路径中添加 `_saveToHistory()` 调用
- **验证**：日志显示 `[DictManager] saveRecentLangPair: saving pair=en_zh` + `save result: true`

---

## 8. 详细的 OPUS-MT 集成指南（历史参考）

> **注意**：OPUS-MT 的 Python 实现已弃用。未来如需恢复，建议使用 onnxruntime_flutter 插件。

详见 [docs/09_marian_opus_mt_guide.md](./09_marian_opus_mt_guide.md)
