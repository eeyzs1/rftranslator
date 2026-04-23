# 翻译应用重设计 — rftranslator

> **注意**：本文档记录 rftranslator 的设计决策。以源码为准。

## 1. 设计目标

| 目标 | 说明 |
|------|------|
| Real Free | 无广告、无订阅、无追踪，完全离线 |
| 双引擎 | 词典查询 + AI 模型翻译，自动回退 |
| 跨平台 | Windows（主要）+ Android，支持 Material / Fluent 双风格 |
| 轻量 | 本地推理，无需服务器 |

---

## 2. 核心设计决策

### 2.1 为什么选择 OPUS-MT 而非通用 LLM？

| 对比项 | OPUS-MT + CTranslate2 | 通用 LLM (Qwen/Gemma) |
|--------|----------------------|----------------------|
| 模型大小 | ~150MB/语言对 | 1-7GB |
| 翻译速度 | 快（专用翻译模型） | 慢（生成式推理） |
| 翻译质量 | 高（专业翻译训练） | 中（通用生成，可能添加解释） |
| 资源占用 | 低 | 高 |
| 适合场景 | 实时翻译 | 复杂语言理解 |

结论：OPUS-MT 更适合翻译场景，同时保留 llamadart 支持以备未来扩展。

### 2.2 为什么双引擎？

- **单词/短语**：词典查询更精准，提供音标、释义、例句
- **长句/段落**：AI 模型翻译更自然流畅
- **兜底**：词典查不到时自动回退到 AI 模型，确保总有结果

### 2.3 为什么支持 Material / Fluent 双风格？

- **Material 3**：Android 用户熟悉，底部导航栏适合触屏
- **Fluent Design**：Windows 用户熟悉，侧边导航栏适合键鼠
- **自适应**：根据平台自动选择，无需用户手动设置

---

## 3. 架构演进

### V1（当前）
- OPUS-MT + CTranslate2 翻译
- ECDICT + StarDict + MDict 词典
- Material 3 / Fluent Design 双 UI
- Hive 本地存储（历史、收藏）
- GitHub Actions CI/CD
- Inno Setup Windows 安装包

### 未来方向
- 更多语言对支持
- macOS / iOS / Linux 平台
- 翻译结果缓存
- 批量翻译
