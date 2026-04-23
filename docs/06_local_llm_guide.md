# 本地 LLM 翻译指南 — rftranslator

> **注意**：本文档描述当前已实现的本地 LLM 翻译方案。以源码为准。

## 1. 方案概述

rftranslator 使用 OPUS-MT 模型 + CTranslate2 推理引擎实现本地翻译，而非通用 LLM（如 Qwen、Gemma）。

| 组件 | 说明 |
|------|------|
| 翻译模型 | OPUS-MT（32 种语言对） |
| 推理引擎 | CTranslate2（通过 dart:ffi 调用） |
| 模型格式 | CTranslate2 格式（非 GGUF） |
| 辅助推理 | llamadart（llama.cpp，支持 GGUF 格式模型） |

---

## 2. OPUS-MT 模型

### 2.1 支持的语言对（32 种）

| 源语言 | 目标语言 | 模型 ID |
|--------|---------|---------|
| English | Chinese | opus-mt-en-zh |
| Chinese | English | opus-mt-zh-en |
| English | Japanese | opus-mt-en-ja |
| Japanese | English | opus-mt-ja-en |
| English | Korean | opus-mt-en-ko |
| Korean | English | opus-mt-ko-en |
| English | French | opus-mt-en-fr |
| French | English | opus-mt-fr-en |
| English | German | opus-mt-en-de |
| German | English | opus-mt-de-en |
| English | Spanish | opus-mt-en-es |
| Spanish | English | opus-mt-es-en |
| English | Russian | opus-mt-en-ru |
| Russian | English | opus-mt-ru-en |
| English | Italian | opus-mt-en-it |
| Italian | English | opus-mt-it-en |
| English | Portuguese | opus-mt-en-pt |
| Portuguese | English | opus-mt-pt-en |
| English | Arabic | opus-mt-en-ar |
| Arabic | English | opus-mt-ar-en |
| English | Vietnamese | opus-mt-en-vi |
| Vietnamese | English | opus-mt-vi-en |
| English | Finnish | opus-mt-en-fi |
| Finnish | English | opus-mt-fi-en |
| English | Swedish | opus-mt-en-sv |
| Swedish | English | opus-mt-sv-en |
| English | Bulgarian | opus-mt-en-bg |
| Bulgarian | English | opus-mt-bg-en |
| English | Hebrew | opus-mt-en-he |
| Hebrew | English | opus-mt-he-en |
| French | German | opus-mt-fr-de |
| German | French | opus-mt-de-fr |

### 2.2 模型格式

每个 OPUS-MT 模型是一个 CTranslate2 格式的文件夹，包含：
- `model.bin` — 模型权重
- `config.json` — 模型配置
- `source_vocabulary.json` + `target_vocabulary.json`（或 `shared_vocabulary.json`）

### 2.3 模型验证

```dart
static bool isValidModelDirectory(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return false;
  if (File(path.join(dirPath, 'model.bin')).existsSync() &&
      File(path.join(dirPath, 'config.json')).existsSync()) {
    if (File(path.join(dirPath, 'shared_vocabulary.json')).existsSync()) return true;
    if (File(path.join(dirPath, 'source_vocabulary.json')).existsSync() &&
        File(path.join(dirPath, 'target_vocabulary.json')).existsSync()) return true;
  }
  return false;
}
```

---

## 3. CTranslate2 FFI 集成

详见 [docs/11_ctranslate2_ffi_integration.md](./11_ctranslate2_ffi_integration.md)

---

## 4. 下载源

| 下载源 | 说明 | 国内可用性 |
|--------|------|-----------|
| 自动检测 | 先 HuggingFace，失败回退 ModelScope | ✅ 推荐 |
| Hugging Face | 官方源 | 可能需要代理 |
| ModelScope | 阿里云模型库 | ✅ 推荐国内用户 |

另外支持从本地文件夹导入 CTranslate2 格式模型。

---

## 5. 翻译流程

```
用户输入 → 文本类型判断
  ├─ 单词/短语（≤3 词且 ≤50 字符）→ 词典查询 → 未找到则回退到 OPUS-MT
  └─ 长句/段落 → OPUS-MT 模型翻译
```

翻译推理在独立 Isolate 中运行（`TranslationIsolateWorker`），不阻塞 UI。
