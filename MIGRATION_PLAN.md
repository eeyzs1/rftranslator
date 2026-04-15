## 问题诊断报告

### 发现的问题

1. **✅ 启动流程正确**：`init_screen.dart:46` 确实调用了 `preloadRecentDictionaries()`
2. **❌ 语言对未保存**：用户日志显示 `Preloading dictionaries for 0 recent language pairs`
3. **⚠️ 异常被静默捕获**：`_saveToHistory()` 中的异常只打印日志（第497-498行）

### 根本原因分析

**可能原因**：
1. 第一次启动后翻译时，`saveRecentLangPair()` 可能执行失败但错误被隐藏
2. 或者 SharedPreferences 持久化在某些情况下失败
3. 或者应用在保存前就崩溃/断开连接（从日志看到 "Lost connection to device"）

### 修复计划

#### 阶段一：立即修复（1-2小时）
- [x] 增强错误处理和日志记录
- [ ] 验证 SharedPreferences 读写流程
- [ ] 添加数据持久化验证机制

#### 阶段二：Dart 原生词典解析器（3-5天）
- [ ] 实现 StarDict .ifo/.idx/.dict 文件解析
- [ ] 创建纯 Dart 数据源替换 Python 依赖
- [ ] 保持现有 API 接口兼容

#### 阶段三：LLM 翻译集成（5-7天）
- [ ] 调研并选择最佳 Flutter LLM 插件
- [ ] 集成 llama_cpp 或 google_mlkit_translation
- [ ] 实现模型下载和管理界面

#### 阶段四：性能优化（2-3天）
- [ ] 词典预加载优化
- [ ] 缓存策略实现
- [ ] 启动速度优化
