# CTranslate2 FFI 集成 — rftranslator

> **注意**：本文档描述当前已实现的 CTranslate2 FFI 集成。以源码为准。

## 1. 概述

rftranslator 通过 `dart:ffi` 直接调用 CTranslate2 C 库，实现本地 OPUS-MT 模型推理，无需 Python 或 HTTP 服务。

---

## 2. FFI 绑定

### 2.1 动态库加载

```dart
// ctranslate2_ffi.dart
final DynamicLibrary _lib = Platform.isWindows
    ? DynamicLibrary.open('ctranslate2.dll')
    : DynamicLibrary.open('libctranslate2.so');
```

搜索路径：
- **Windows**: 当前目录 → `windows\libs\` → exe 同目录
- **Android**: 应用 native 库目录

### 2.2 核心 FFI 函数

CTranslate2 C 库的核心函数通过 FFI 绑定暴露给 Dart：

| 函数 | 说明 |
|------|------|
| `ctranslate2_Translator_new` | 创建翻译器实例 |
| `ctranslate2_Translator_translate_batch` | 批量翻译 |
| `ctranslate2_Translator_delete` | 销毁翻译器 |
| `ctranslate2_TranslationResult_delete` | 销毁翻译结果 |

---

## 3. 翻译流程

### 3.1 完整流程

```
1. 加载 CTranslate2 动态库
2. 创建 Translator 实例（加载模型）
3. 加载源语言和目标语言的 SentencePiece 分词器
4. 输入文本 → 分词 → 翻译 → 解码
5. 返回翻译结果
```

### 3.2 Isolate 隔离

翻译推理在独立 Isolate 中运行，通过 `TranslationIsolateWorker` 实现：

```dart
// 翻译请求通过 SendPort/ReceivePort 传递
// 翻译结果通过 SendPort 返回主 Isolate
// 支持模型热切换、超时重启、关闭信号
```

---

## 4. 构建脚本

### 4.1 Windows

```powershell
# scripts/build_ctranslate2_windows.ps1
# 从源码编译 CTranslate2，生成 ctranslate2.dll
```

### 4.2 Android

```bash
# scripts/build_ctranslate2_android.sh
# 交叉编译 CTranslate2，生成 libctranslate2.so
```

### 4.3 WSL 环境

```bash
# scripts/build_android_wsl.sh
# 在 WSL 环境下编译 Android 版本
```

---

## 5. 运行时依赖

| 平台 | 文件 | 说明 |
|------|------|------|
| Windows | `ctranslate2.dll` | 放置在 exe 同目录 |
| Android | `libctranslate2.so` | 放置在 `jniLibs/` 目录 |
| Linux | `libctranslate2.so` | 放置在应用库目录 |

---

## 6. 错误处理

| 错误类型 | 处理方式 |
|----------|----------|
| 动态库加载失败 | 显示错误提示，引导用户检查安装 |
| 模型加载失败 | 显示错误状态，支持重新加载/重新下载 |
| 翻译超时 | 自动重启 Isolate，重试翻译 |
| 内存不足 | 释放模型，显示提示 |
