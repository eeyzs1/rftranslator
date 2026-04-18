# CTranslate2 FFI 集成方案

## 概述

本文档描述如何通过 Dart FFI 直接调用 CTranslate2 的 C API，实现 OPUS-MT 模型的本地推理，无需 Python 进程。

## 架构

```
┌─────────────────────────────────────────────────┐
│  Flutter App                                     │
│  ┌─────────────────────────────────────────────┐ │
│  │  TranslationProvider                        │ │
│  │    ↓                                        │ │
│  │  CTranslate2DataSource (Dart)               │ │
│  │    ↓ FFI                                    │ │
│  │  ctranslate2.dll / libctranslate2.so        │ │
│  │    ↓                                        │ │
│  │  OPUS-MT 模型 (CT2 格式, INT8 量化)         │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

## 为什么需要从源码编译

CTranslate2 的 Python wheel 预编译包**不包含 C API 导出**：
- Windows: `ctranslate2.dll` 只有 C++ mangled 符号和 pybind11 绑定
- Linux: `libctranslate2.so` 同样只有 C++ 符号

C API 函数（如 `ctranslate2_Translator_new`）只在**从源码编译且启用 C API** 时才会导出。

## 前置条件

### Windows
- Visual Studio 2022 Build Tools (C++ 桌面开发工作负载)
- CMake >= 3.16
- Git

### Android
- Android NDK (r25+)
- CMake >= 3.16
- Git

### WSL (用于交叉编译 Android 版本)
- Ubuntu 20.04+
- CMake, Git, NDK

## 编译步骤

### 1. Windows x64 编译

运行 `scripts/build_ctranslate2_windows.ps1`：

```powershell
# 在 PowerShell 中执行
.\scripts\build_ctranslate2_windows.ps1
```

脚本会自动：
1. 克隆 CTranslate2 源码
2. 配置 CMake (启用 C API, INT8 量化支持)
3. 编译 Release 版本
4. 将 DLL 复制到 `windows/libs/` 目录

### 2. Android ARM64 编译

运行 `scripts/build_ctranslate2_android.sh`：

```bash
# 在 WSL 中执行
bash scripts/build_ctranslate2_android.sh
```

脚本会自动：
1. 克隆 CTranslate2 源码
2. 使用 NDK 交叉编译
3. 将 .so 复制到 `android/app/src/main/jniLibs/arm64-v8a/` 目录

## 模型格式转换

OPUS-MT 原始模型是 MarianMT 格式 (pytorch_model.bin)，需要转换为 CTranslate2 格式：

```bash
python scripts/convert_model_to_ct2.py --model_dir E:\temp_dict\opus-mt-en-zh --output_dir E:\temp_dict\opus-mt-en-zh-ct2
```

转换后的模型目录包含：
- `model.bin` — 量化后的模型权重 (INT8)
- `config.json` — 模型配置
- `source_vocabulary.txt` — 源语言词表
- `target_vocabulary.txt` — 目标语言词表

### 批量转换

```bash
python scripts/convert_model_to_ct2.py --models_dir E:\temp_dict --output_dir E:\temp_dict\ct2_models
```

会自动扫描 `models_dir` 下所有 `opus-mt-*` 文件夹并转换。

## C API 接口

CTranslate2 C API 核心函数：

```c
// 创建/销毁 Translator
ctranslate2_Translator* ctranslate2_Translator_new(
    const char* model_path,
    const char* device,
    int device_index,
    const ctranslate2_TranslatorOptions* options
);
void ctranslate2_Translator_delete(ctranslate2_Translator* translator);

// 翻译
ctranslate2_TranslationResult** ctranslate2_Translator_translate_batch(
    ctranslate2_Translator* translator,
    const ctranslate2_StringVector* const* input,
    size_t input_size,
    const ctranslate2_TranslationOptions* options
);

// 获取翻译结果
ctranslate2_StringVector* ctranslate2_TranslationResult_get_output(
    const ctranslate2_TranslationResult* result,
    size_t index
);
const char* ctranslate2_StringVector_at(
    const ctranslate2_StringVector* vector,
    size_t index
);
size_t ctranslate2_StringVector_size(
    const ctranslate2_StringVector* vector
);

// 内存管理
void ctranslate2_TranslationResult_delete(ctranslate2_TranslationResult* result);
void ctranslate2_StringVector_delete(ctranslate2_StringVector* vector);

// 选项
ctranslate2_TranslatorOptions* ctranslate2_TranslatorOptions_new();
void ctranslate2_TranslatorOptions_set_compute_type(
    ctranslate2_TranslatorOptions* options,
    const char* compute_type  // "int8" for quantized
);
void ctranslate2_TranslatorOptions_set_intra_threads(
    ctranslate2_TranslatorOptions* options,
    size_t num_threads
);
ctranslate2_TranslationOptions* ctranslate2_TranslationOptions_new();
void ctranslate2_TranslationOptions_set_beam_size(
    ctranslate2_TranslationOptions* options,
    size_t beam_size
);
void ctranslate2_TranslationOptions_set_max_decoding_length(
    ctranslate2_TranslationOptions* options,
    size_t length
);
```

## Dart FFI 绑定

文件: `lib/core/ffi/ctranslate2_ffi.dart`

封装了所有 C API 函数调用，提供类型安全的 Dart 接口。

## CTranslate2DataSource

文件: `lib/features/llm/data/datasources/ctranslate2_datasource.dart`

实现 `LlmDataSource` 接口，通过 FFI 调用 CTranslate2：
- `loadModel()` → 调用 `ctranslate2_Translator_new`
- `generate()` → 调用 `ctranslate2_Translator_translate_batch`
- `dispose()` → 调用 `ctranslate2_Translator_delete`

## 性能对比

| 方案 | 首次翻译 | 后续翻译 | Python 依赖 |
|------|---------|---------|------------|
| PyTorch (transformers) | ~5-8s | ~1-3s | ✅ 需要 |
| CTranslate2 Python | ~3-5s | ~0.3-1s | ✅ 需要 |
| **CTranslate2 FFI** | **~0.5-1s** | **~0.1-0.3s** | **❌ 不需要** |

INT8 量化 + CTranslate2 优化引擎 + 无进程启动开销 = 10-30x 整体提速。

## Fallback 策略

```
CTranslate2 FFI (首选)
    ↓ DLL/SO 不存在
OpusMtDataSource (Python 子进程, 备选)
    ↓ Python 不存在
显示错误提示
```

## 文件清单

| 文件 | 用途 |
|------|------|
| `scripts/build_ctranslate2_windows.ps1` | Windows 编译脚本 |
| `scripts/build_ctranslate2_android.sh` | Android 编译脚本 |
| `scripts/convert_model_to_ct2.py` | 模型格式转换脚本 |
| `lib/core/ffi/ctranslate2_ffi.dart` | Dart FFI 绑定 |
| `lib/features/llm/data/datasources/ctranslate2_datasource.dart` | FFI 数据源 |
| `windows/libs/ctranslate2.dll` | Windows DLL (编译后) |
| `android/app/src/main/jniLibs/arm64-v8a/libctranslate2.so` | Android SO (编译后) |
