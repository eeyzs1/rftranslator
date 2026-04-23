# MarianMT / OPUS-MT 指南 — rftranslator

> **注意**：本文档描述当前使用的 OPUS-MT 翻译方案。以源码为准。

## 1. 从 MarianMT 到 OPUS-MT

rftranslator 使用 OPUS-MT 模型（基于 MarianMT 架构），通过 CTranslate2 推理引擎在本地运行翻译。

| 对比项 | MarianMT (HuggingFace) | OPUS-MT (CTranslate2) |
|--------|----------------------|----------------------|
| 推理引擎 | PyTorch / ONNX | CTranslate2 (C++) |
| 模型格式 | PyTorch .bin / SafeTensors | CTranslate2 格式 |
| 部署方式 | Python 服务 / ONNX Runtime | FFI 直接调用 |
| 性能 | 中 | 高（CPU 优化） |
| 依赖 | Python 生态 | 单个 .dll / .so |

---

## 2. OPUS-MT 模型详情

### 2.1 模型来源

OPUS-MT 模型由 Helsinki-NLP 团队训练，基于 MarianMT 架构：
- 训练数据：OPUS 平行语料库
- 模型架构：Encoder-Decoder Transformer
- 转换工具：`ct2-transformers-converter`（将 HuggingFace 模型转为 CTranslate2 格式）

### 2.2 模型命名规则

```
opus-mt-{src}-{tgt}
```

其中 `{src}` 和 `{tgt}` 为 ISO 639-1 语言代码。

特殊命名：
- `opus-mt-tc-big-en-ko` → 别名 `opus-mt-en-ko`（tc-big 为大模型版本）
- `opus-mt-tc-big-he-en` → 别名 `opus-mt-he-en`

### 2.3 模型文件结构

```
opus-mt-en-zh/
├── model.bin              # 模型权重
├── config.json            # 模型配置
├── source_vocabulary.json # 源语言词表
└── target_vocabulary.json # 目标语言词表
```

或使用共享词表：
```
opus-mt-en-zh/
├── model.bin
├── config.json
└── shared_vocabulary.json
```

### 2.4 模型验证

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

## 3. CTranslate2 推理

### 3.1 FFI 绑定

通过 `dart:ffi` 直接调用 CTranslate2 C 库：

```dart
// ctranslate2_ffi.dart
final DynamicLibrary _lib = Platform.isWindows
    ? DynamicLibrary.open('ctranslate2.dll')
    : DynamicLibrary.open('libctranslate2.so');
```

### 3.2 翻译流程

```
1. 加载模型 → ctranslate2.Translator(modelPath)
2. 分词 → sourceTokenizer.encode(text)
3. 翻译 → translator.translateBatch(tokens)
4. 解码 → targetTokenizer.decode(outputTokens)
```

### 3.3 Isolate 隔离

翻译推理在独立 Isolate 中运行（`TranslationIsolateWorker`），避免阻塞 UI 线程。

---

## 4. 下载与安装

### 4.1 下载源

| 下载源 | URL | 国内可用性 |
|--------|-----|-----------|
| 自动检测 | 先 HF 后 ModelScope | ✅ |
| Hugging Face | huggingface.co | 可能需要代理 |
| ModelScope | modelscope.cn | ✅ |

### 4.2 本地导入

支持从本地文件夹导入 CTranslate2 格式模型，需包含 `model.bin`、`config.json` 和词表文件。
