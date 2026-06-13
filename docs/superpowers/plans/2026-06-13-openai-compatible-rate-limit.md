# OpenAI-Compatible 速率限制实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 openai-compatible 提供商添加请求间隔控制，确保不超过 40 RPM 限制

**Architecture:** 在 BatchStrategy.lua 中添加 requestDelay 配置，在 AIEngine.lua 的 queryBatch() 和 queryText() 函数中实现等待逻辑。配置与实现分离，仅影响 openai-compatible 提供商。

**Tech Stack:** Lua, Lightroom SDK (LrTasks.sleep)

---

## 文件结构

**修改文件：**
- `AISelects.lrplugin/BatchStrategy.lua` - 添加速率限制配置和辅助函数
- `AISelects.lrplugin/AIEngine.lua` - 在 API 调用前添加等待逻辑

**测试验证：**
- 通过 Lightroom 插件运行实际照片评分测试
- 检查日志文件确认等待时间
- 监控 OpenRouter 控制台确认无 429 错误

---

### Task 1: 在 BatchStrategy.lua 中添加速率限制配置

**Files:**
- Modify: `AISelects.lrplugin/BatchStrategy.lua:47-54`

- [ ] **Step 1: 在 PROVIDER_CONFIG["openai-compatible"] 中添加 requestDelay 字段**

在 `AISelects.lrplugin/BatchStrategy.lua` 文件的第 47-54 行，修改 `["openai-compatible"]` 配置：

```lua
["openai-compatible"] = {
    batchSize        = 10,
    maxAnchors       = 2,
    supportsSnapshot = true,
    scoringMaxTokens = 4096,
    synthesisMaxTokens = 8192,
    defaultTimeout   = 180,
    -- 新增：速率限制配置
    requestDelay     = 1.5,  -- 秒，确保不超过40 RPM限制
}
```

- [ ] **Step 2: 添加 getRequestDelay 辅助函数**

在 `AISelects.lrplugin/BatchStrategy.lua` 文件的第 90 行（`getDefaultTimeout` 函数之后）添加新函数：

```lua
--- Get the request delay for a provider (seconds between API calls).
-- Returns 0 for providers without rate limits.
-- @param provider  String: provider name
-- @return Number: delay in seconds (0 if no limit)
function M.getRequestDelay(provider)
    local cfg = M.getProviderConfig(provider)
    return cfg.requestDelay or 0
end
```

- [ ] **Step 3: 验证 BatchStrategy.lua 修改正确**

使用 Read 工具读取修改后的文件，确认：
1. `["openai-compatible"]` 配置包含 `requestDelay = 1.5`
2. `getRequestDelay` 函数已添加
3. 其他提供商配置未受影响

- [ ] **Step 4: 提交 BatchStrategy.lua 修改**

```bash
git add AISelects.lrplugin/BatchStrategy.lua
git commit -m "feat: add requestDelay config for openai-compatible provider (40 RPM limit)"
```

---

### Task 2: 在 AIEngine.lua 中实现速率限制逻辑

**Files:**
- Modify: `AISelects.lrplugin/AIEngine.lua:1912-1937` (queryBatch 函数)
- Modify: `AISelects.lrplugin/AIEngine.lua:2278-2295` (queryText 函数)

- [ ] **Step 1: 在 queryBatch 函数开头添加速率限制逻辑**

在 `AISelects.lrplugin/AIEngine.lua` 文件的 `queryBatch` 函数开头（第 1912 行之后）添加速率限制代码：

找到：
```lua
function M.queryBatch(images, imageLabels, anchorImages, anchorLabels, prompt, prefs, maxTokens)
    local provider = prefs.provider
    local timeout  = prefs.timeoutSecs or BatchStrategy.getDefaultTimeout(provider)

    if provider == "ollama" then
```

修改为：
```lua
function M.queryBatch(images, imageLabels, anchorImages, anchorLabels, prompt, prefs, maxTokens)
    local provider = prefs.provider
    local timeout  = prefs.timeoutSecs or BatchStrategy.getDefaultTimeout(provider)

    -- 速率限制：在API调用前等待
    local delay = BatchStrategy.getRequestDelay(provider)
    if delay > 0 then
        LrTasks.sleep(delay)
    end

    if provider == "ollama" then
```

- [ ] **Step 2: 在 queryText 函数开头添加速率限制逻辑**

在 `AISelects.lrplugin/AIEngine.lua` 文件的 `queryText` 函数开头（第 2278 行之后）添加相同的速率限制代码：

找到：
```lua
function M.queryText(prompt, prefs, maxTokens)
    local provider = prefs.provider
    local timeout  = prefs.timeoutSecs or BatchStrategy.getDefaultTimeout(provider)

    if provider == "ollama" then
```

修改为：
```lua
function M.queryText(prompt, prefs, maxTokens)
    local provider = prefs.provider
    local timeout  = prefs.timeoutSecs or BatchStrategy.getDefaultTimeout(provider)

    -- 速率限制：在API调用前等待
    local delay = BatchStrategy.getRequestDelay(provider)
    if delay > 0 then
        LrTasks.sleep(delay)
    end

    if provider == "ollama" then
```

- [ ] **Step 3: 验证 AIEngine.lua 修改正确**

使用 Read 工具读取修改后的文件，确认：
1. `queryBatch` 函数包含速率限制逻辑
2. `queryText` 函数包含速率限制逻辑
3. 两个函数的逻辑完全一致
4. 其他代码未受影响

- [ ] **Step 4: 提交 AIEngine.lua 修改**

```bash
git add AISelects.lrplugin/AIEngine.lua
git commit -m "feat: implement rate limiting in queryBatch and queryText for openai-compatible"
```

---

### Task 3: 验证实现正确性

**Files:**
- 无文件修改，仅验证

- [ ] **Step 1: 代码静态检查**

使用 Grep 工具验证：
1. 搜索 `requestDelay` 确认只在 BatchStrategy.lua 和 AIEngine.lua 中出现
2. 搜索 `getRequestDelay` 确认函数定义和调用正确
3. 搜索 `LrTasks.sleep` 确认只在速率限制逻辑中使用

- [ ] **Step 2: 验证其他提供商不受影响**

使用 Read 工具读取 BatchStrategy.lua，确认：
1. `ollama` 配置无 `requestDelay` 字段
2. `claude` 配置无 `requestDelay` 字段
3. `openai` 配置无 `requestDelay` 字段
4. `gemini` 配置无 `requestDelay` 字段

- [ ] **Step 3: 创建验证总结文档**

创建临时验证文档，记录：
1. 修改的文件列表
2. 新增的配置项
3. 新增的函数
4. 受影响的代码路径
5. 预期的行为变化

---

### Task 4: 更新 CLAUDE.md 文档

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 在 Provider Routing 部分添加速率限制说明**

在 `CLAUDE.md` 文件的 Provider Routing 部分添加速率限制说明：

找到：
```markdown
**Supported providers:**
- `ollama` — Local Ollama instance
- `claude` — Anthropic Claude API
- `openai` — OpenAI API
- `gemini` — Google Gemini API
- `openai-compatible` — Any OpenAI-compatible endpoint (LM Studio, DeepSeek, etc.)
```

修改为：
```markdown
**Supported providers:**
- `ollama` — Local Ollama instance
- `claude` — Anthropic Claude API
- `openai` — OpenAI API
- `gemini` — Google Gemini API
- `openai-compatible` — Any OpenAI-compatible endpoint (LM Studio, DeepSeek, OpenRouter, etc.)
  - **Rate limiting**: 1.5s delay between requests (40 RPM limit for OpenRouter NVIDIA free tier)
```

- [ ] **Step 2: 提交文档更新**

```bash
git add CLAUDE.md
git commit -m "docs: document rate limiting for openai-compatible provider"
```

---

### Task 5: 最终验证和测试指南

**Files:**
- 无文件修改，创建测试指南

- [ ] **Step 1: 创建测试指南文档**

创建 `docs/testing/rate-limit-testing.md` 文件：

```markdown
# Rate Limit Testing Guide

## 测试前准备

1. 确保使用 OpenRouter NVIDIA 免费层配置
2. 准备测试照片集：
   - 小批量：5-10 张照片
   - 大批量：50+ 张照片
3. 启用日志记录（Settings > Enable Logging）

## 测试步骤

### 1. 小批量测试（5-10张照片）

**目的**: 验证速率限制逻辑生效

**步骤**:
1. 在 Lightroom 中选择 5-10 张照片
2. 运行 AI Selects > Score Photos
3. 检查日志文件（`~/Desktop/Selects Logs/` 或 `%USERPROFILE%\Desktop\Selects Logs\`）
4. 验证每次 API 调用时间戳间隔 ≥ 1.5秒

**预期结果**:
- 日志显示每次批次调用间隔约 1.5秒
- 无 429 错误
- Lightroom 控制台无错误

### 2. 大批量测试（50+张照片）

**目的**: 验证连续调用不会触发 40 RPM 限制

**步骤**:
1. 在 Lightroom 中选择 50+ 张照片
2. 运行 AI Selects > Score Photos
3. 记录开始时间和结束时间
4. 检查 OpenRouter 控制台的使用统计

**预期结果**:
- 总执行时间 ≈ 原时间 + (批次数 × 1.5秒)
- OpenRouter 控制台无 429 错误
- 请求分布均匀

### 3. 其他提供商测试

**目的**: 确认其他提供商不受影响

**步骤**:
1. 切换到其他提供商（ollama/claude/openai/gemini）
2. 运行相同照片的评分
3. 对比执行时间

**预期结果**:
- 执行时间与修改前相同
- 无额外等待时间

## 验证方法

### 日志分析

检查日志文件中的时间戳：
```
[Batch 1] 10:00:00.000  Starting
[Batch 1] 10:00:05.234  Done
[Batch 2] 10:00:06.734  Starting  <- 等待 1.5秒
[Batch 2] 10:00:12.456  Done
[Batch 3] 10:00:13.956  Starting  <- 等待 1.5秒
```

### OpenRouter 监控

1. 登录 OpenRouter 控制台
2. 查看使用统计
3. 确认无 429 状态码
4. 验证请求分布均匀

## 回滚策略

如果出现问题：
1. 移除 `BatchStrategy.lua` 中的 `requestDelay` 字段
2. 移除 `AIEngine.lua` 中的 sleep 逻辑
3. 重启 Lightroom
```

- [ ] **Step 2: 提交测试指南**

```bash
git add docs/testing/rate-limit-testing.md
git commit -m "docs: add rate limit testing guide"
```

---

## 实现总结

**修改文件**:
- `AISelects.lrplugin/BatchStrategy.lua` - 添加 requestDelay 配置和 getRequestDelay 函数
- `AISelects.lrplugin/AIEngine.lua` - 在 queryBatch 和 queryText 中添加速率限制逻辑
- `CLAUDE.md` - 更新文档说明

**新增文件**:
- `docs/testing/rate-limit-testing.md` - 测试指南

**影响范围**:
- 仅影响 `openai-compatible` 提供商
- 其他提供商完全不受影响
- 用户可接受的性能代价：每批次增加 1.5 秒等待时间

**验证方法**:
- 代码静态检查
- 实际照片评分测试
- 日志时间戳分析
- OpenRouter 控制台监控
