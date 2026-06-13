# OpenAI-Compatible 速率限制设计

**日期**: 2026-06-13
**状态**: 已批准
**目标**: 为 openai-compatible 提供商添加请求间隔控制，避免触发 OpenRouter NVIDIA 免费层的 40 RPM 限制

## 背景

### 问题
- 用户使用 OpenRouter NVIDIA 免费层，该服务有明确的 40 RPM（每分钟请求数）限制
- 当前代码完全串行执行，没有任何速率限制机制
- 在评分大量照片（400+张）时，会产生约 40 个批次调用，几乎必然触发限制导致执行失败

### 使用场景
- **主要场景**: ScorePhotos.lua 评分大量照片（400+张）
- **批次计算**: 400张 ÷ 10张/批次 = 40个批次
- **限制临界**: 40 RPM 限制意味着每分钟最多 40 次请求

## 设计原则

### 核心策略
- **等待间隔**: 每次 API 调用前等待 1.5 秒（60秒 ÷ 40次 = 1.5秒/次）
- **保守策略**: 选择绝对稳定性，接受增加总执行时间
- **范围限制**: 仅影响 `openai-compatible` 提供商，其他提供商保持不变

### 性能影响
- 400张照片评分：原执行时间 + 60秒等待（40批次 × 1.5秒）
- 用户可接受的代价：换取 100% 稳定性，避免触发限制导致失败

## 实现方案

### 方案概述
**BatchStrategy 配置 + AIEngine 实现**

优点：
- 保持代码架构清晰（配置与实现分离）
- 足够灵活应对未来需求（其他 OpenRouter 套餐可能有不同限制）
- 改动适中，不会过度设计

### 实现细节

#### 1. BatchStrategy.lua 配置

在 `PROVIDER_CONFIG["openai-compatible"]` 中添加速率限制配置：

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

新增辅助函数：

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

#### 2. AIEngine.lua 实现

在 `queryBatch()` 函数开头添加速率限制逻辑：

```lua
function M.queryBatch(images, imageLabels, anchorImages, anchorLabels, prompt, prefs, maxTokens)
    local provider = prefs.provider
    local timeout  = prefs.timeoutSecs or BatchStrategy.getDefaultTimeout(provider)

    -- 速率限制：在API调用前等待
    local delay = BatchStrategy.getRequestDelay(provider)
    if delay > 0 then
        LrTasks.sleep(delay)
    end

    -- 原有路由逻辑...
    if provider == "ollama" then
        return M.queryOllamaBatch(images, prompt, prefs.model, prefs.ollamaUrl, timeout)
    elseif provider == "claude" then
        return M.queryClaudeBatch(images, imageLabels, anchorImages, anchorLabels,
            prompt, prefs.claudeModel, prefs.claudeApiKey, maxTokens, timeout)
    -- ... 其他提供商
    end
end
```

在 `queryText()` 函数开头添加相同的速率限制逻辑：

```lua
function M.queryText(prompt, prefs, maxTokens)
    local provider = prefs.provider
    local timeout  = prefs.timeoutSecs or BatchStrategy.getDefaultTimeout(provider)

    -- 速率限制：在API调用前等待
    local delay = BatchStrategy.getRequestDelay(provider)
    if delay > 0 then
        LrTasks.sleep(delay)
    end

    -- 原有路由逻辑...
    if provider == "ollama" then
        return M.queryOllamaText(prompt, prefs.model, prefs.ollamaUrl, timeout)
    elseif provider == "claude" then
        return M.queryClaudeText(prompt, prefs.claudeModel, prefs.claudeApiKey, timeout, maxTokens)
    -- ... 其他提供商
    end
end
```

## 影响范围

### 受影响的代码路径

#### ScorePhotos.lua（评分阶段）
- 每批次调用 `Engine.queryBatch()`
- 400张照片 ≈ 40批次 → 额外等待 60秒（40 × 1.5秒）

#### SelectPhotos.lua（Story模式）
- Pass 2 (Story Assembly): `queryText()` - 1次调用
- Pass 3B (AI ranking): `queryText()` - 每beat 1次
- Pass 4 (Beat Casting): `queryVision()` → 内部调用 `queryBatch()` - 每beat 1次
- Pass 5 (Story Review): `queryVision()` - 每批 1次
- Pass 6 (Swap Resolution): `queryVision()` - 每swap 1次
- Story模式总等待时间取决于beat数量和swap数量

### 不受影响的场景

- 其他提供商（ollama、claude、openai、gemini）完全不受影响
- `requestDelay` 默认为 0，不会引入额外等待
- 现有的批次处理逻辑、错误处理逻辑保持不变

## 测试与验证

### 测试场景

#### 1. 小批量测试（5-10张照片）
- 验证速率限制逻辑生效
- 确认日志中显示等待时间
- 检查 Lightroom 控制台无错误

#### 2. 大批量测试（50+张照片）
- 验证连续调用不会触发 40 RPM 限制
- 确认总执行时间符合预期（原时间 + 批次数 × 1.5秒）
- 监控 OpenRouter 控制台无 429 错误

#### 3. 其他提供商测试
- 确认 ollama/claude/openai/gemini 不受影响
- 验证 `requestDelay = 0` 时不引入等待
- 对比修改前后的执行时间（应无变化）

### 验证方法

1. **日志分析**
   - 检查日志文件中的时间戳
   - 确认每次 API 调用间隔 ≥ 1.5秒
   - 示例：`[Batch 1] 10:00:00` → `[Batch 2] 10:00:01.5` → `[Batch 3] 10:00:03.0`

2. **OpenRouter 监控**
   - 检查 OpenRouter 控制台的使用统计
   - 确认未触发速率限制错误（429 状态码）
   - 验证请求分布均匀

3. **性能对比**
   - 对比修改前后的总执行时间
   - 确认额外时间 ≈ 批次数 × 1.5秒
   - 验证用户可接受性能代价

### 回滚策略

如果出现问题，只需：
1. 移除 `BatchStrategy.lua` 中 `openai-compatible` 配置的 `requestDelay` 字段
2. 移除 `AIEngine.lua` 中 `queryBatch()` 和 `queryText()` 的 sleep 逻辑
3. 重启 Lightroom 加载修改后的代码

## 未来扩展

### 可配置化
如果未来需要支持不同 OpenRouter 套餐（如付费层的更高限制），可以考虑：
- 在 `Prefs.lua` 中添加 `openaiCompatibleRequestDelay` 配置项
- 在 `Config.lua` 中添加 UI 输入框
- 优先使用用户配置，回退到 BatchStrategy 默认值

### 自适应速率限制
如果需要更智能的策略，可以考虑：
- 实现"令牌桶"算法，允许短时突发请求
- 根据 429 错误动态调整等待时间
- 记录历史请求时间，计算实时 RPM

### 其他提供商扩展
如果其他云提供商也需要速率限制：
- 在各自的 `PROVIDER_CONFIG` 中添加 `requestDelay` 字段
- Claude: 500 RPM → 0.12秒间隔
- OpenAI: 500 RPM → 0.12秒间隔
- Gemini: 15 RPM → 4秒间隔（免费层）

## 总结

本设计通过在 BatchStrategy.lua 中添加配置、在 AIEngine.lua 中实现等待逻辑，为 openai-compatible 提供商添加了保守的速率限制机制。该方案：

- **简单可靠**：固定 1.5 秒间隔，确保不超过 40 RPM 限制
- **影响可控**：仅影响 openai-compatible 提供商
- **易于维护**：配置与实现分离，代码清晰
- **可扩展**：为未来支持其他套餐或提供商预留空间

用户接受增加约 60 秒的等待时间（400张照片），换取 100% 的稳定性，避免触发限制导致执行失败。
