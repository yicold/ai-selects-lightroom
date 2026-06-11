# Chinese Output & OpenAI-Compatible API Support

**Date:** 2026-06-11  
**Status:** Design approved  

## Overview

Add two optimization features to the AI Selects Lightroom plugin:

1. **Chinese Output Support** - Enable AI responses in Simplified Chinese
2. **OpenAI-Compatible API Provider** - Support for custom OpenAI-format API endpoints (DeepSeek, Moonshot, local LLMs, etc.)

Both features are designed as low-risk, non-breaking additions that integrate cleanly with the existing architecture.

---

## Feature 1: Chinese Output Support

### Goal

Allow users to receive AI-generated content (photo descriptions, story assembly, reasoning) in Simplified Chinese instead of English.

### User Interface

**Config.lua - Settings Dialog:**

Add a "Language" dropdown in the "Scoring & Selection" group box:

```
Language:   [English ▼]  (options: "English" or "中文 (Chinese)")
```

This is a global setting that applies to all AI outputs across all providers.

### Architecture

#### Preference Storage

**Prefs.lua:**

```lua
outputLanguage = "en",  -- "en" or "zh"
```

Default is English to maintain backward compatibility.

#### Language Instruction Injection

**AIEngine.lua:**

Add a helper function to generate language-specific prompt suffix:

```lua
local function getLanguageInstruction(lang)
    if lang == "zh" then
        return "\n\n重要：所有文本输出必须使用简体中文。JSON字段值（如content、reasoning、description等）必须用中文回答。"
    end
    return ""
end
```

**Update function signatures to accept language parameter:**

Each prompt builder function should receive the `outputLanguage` parameter:

```lua
function M.buildBatchScoringPrompt(photoIds, timestamps, exifData, anchors,
                                   nitpickyScale, includeSnapshot, preHints,
                                   priorSnapshots, outputLanguage)
    -- ... existing code ...
    
    -- Add language instruction before response format
    if outputLanguage == "zh" then
        parts[#parts + 1] = getLanguageInstruction("zh")
    end
    
    -- Response format section
    parts[#parts + 1] = "\nReturn ONLY valid JSON in this exact format:\n"
end
```

Apply similar changes to all builder functions.

#### Example Implementation

**Before (buildBatchScoringPrompt):**

```lua
-- Section 6: Response format
parts[#parts + 1] = "\nReturn ONLY valid JSON in this exact format:\n"
```

**After:**

```lua
-- Section 6: Language instruction (if Chinese)
if prefs.outputLanguage == "zh" then
    parts[#parts + 1] = getLanguageInstruction("zh")
end

-- Section 7: Response format
parts[#parts + 1] = "\nReturn ONLY valid JSON in this exact format:\n"
```

### Provider Compatibility

| Provider | Chinese Support | Notes |
|----------|----------------|-------|
| Claude (Sonnet 4.6) | ✅ Excellent | Native Chinese capability |
| OpenAI (GPT-4.1) | ✅ Excellent | Strong Chinese generation |
| Gemini (2.5 Flash) | ✅ Excellent | Good Chinese support |
| Ollama (Qwen2.5-VL) | ✅ Excellent | Chinese-trained model |
| OpenAI-Compatible | ⚠️ Varies | Depends on specific provider/model |

### Non-Goals

- UI localization (all labels remain in English)
- Error message translation (logs remain in English for maintainability)
- Traditional Chinese support (can be added later if requested)

### Testing Strategy

1. Test with each provider (Claude, OpenAI, Gemini, Ollama)
2. Verify JSON parsing works with Chinese text values
3. Check that structured fields (category, eye_quality) remain in expected format
4. Confirm Chinese descriptions are specific enough for photo matching

---

## Feature 2: OpenAI-Compatible API Provider

### Goal

Support any API endpoint that implements the OpenAI chat completions format, enabling use of:
- Chinese AI providers (DeepSeek, Moonshot, Zhipu AI)
- Local LLM servers (vLLM, LM Studio, Ollama in OpenAI mode)
- Other OpenAI-compatible cloud services

### User Interface

**Config.lua - Settings Dialog:**

Add new provider option:

```
AI Provider:   ○ Ollama (local)  ○ Claude API (cloud)
               ○ OpenAI API (cloud)  ○ Gemini API (cloud)
               ○ OpenAI-Compatible (custom endpoint)
```

Add new configuration group box:

```
┌─ OpenAI-Compatible API ─────────────────────────────────┐
│ API Base URL: [                                      ]  │
│ API Key:      [                                          │
│ Model:        [                                          │
│                                                          │
│               Example endpoints:                         │
│               • api.deepseek.com/v1                     │
│               • api.moonshot.cn/v1                      │
│               • localhost:8000/v1 (local)               │
└──────────────────────────────────────────────────────────┘
```

**Field Specifications:**

- **API Base URL**: Free text input
  - Must start with `http://` or `https://`
  - Should include the `/v1` or `/v1/chat/completions` path
  - Examples: `https://api.deepseek.com/v1`, `http://localhost:8000/v1`
  
- **API Key**: Free text input
  - Required when provider is selected
  - No format validation (different providers use different key formats)
  
- **Model**: Free text input
  - User enters the exact model identifier
  - Examples: `deepseek-chat`, `moonshot-v1-8k`, `glm-4`, `llama-3.2-11b-vision-instruct`

### Architecture

#### Preference Storage

**Prefs.lua:**

```lua
openaiCompatibleUrl    = "",    -- API base URL
openaiCompatibleApiKey = "",    -- API key
openaiCompatibleModel  = "",    -- model identifier
```

#### Batch Strategy Configuration

**BatchStrategy.lua:**

Add configuration entry:

```lua
openaiCompatible = {
    batchSize        = 10,
    maxAnchors       = 2,
    supportsSnapshot = true,
    scoringMaxTokens = 4096,
    synthesisMaxTokens = 8192,
    defaultTimeout   = 180,
},
```

Uses same parameters as OpenAI since the API format is identical.

#### API Implementation

**AIEngine.lua - New Functions:**

**1. `M.queryOpenAICompatibleBatch()`** - Vision API calls

```lua
function M.queryOpenAICompatibleBatch(images, imageLabels, anchorImages, anchorLabels,
                                      prompt, model, apiKey, baseUrl, maxTokens, timeoutSecs)
    -- Build request body (identical to queryOpenAIBatch)
    local content = {}
    -- ... (same image encoding logic)
    
    local encodeOk, body = pcall(json.encode, {
        model      = model,
        max_tokens = maxTokens or 4096,
        messages   = {{
            role    = "user",
            content = content,
        }}
    })
    
    -- Use configurable base URL
    local endpoint = baseUrl:gsub("/+$", "") .. "/chat/completions"
    
    local tmpCfg = M.TEMP_DIR .. "/ai_sel_cfg_" .. ts .. ".txt"
    if not M.writeCurlConfig(tmpCfg, endpoint, {
        "Authorization: Bearer " .. apiKey,
        "Content-Type: application/json",
    }, timeoutSecs) then
        return nil, "Could not write curl config file"
    end
    
    -- ... (same response parsing as OpenAI)
end
```

**2. `M.queryOpenAICompatibleText()`** - Text-only API calls

```lua
function M.queryOpenAICompatibleText(prompt, model, apiKey, baseUrl, timeoutSecs, maxTokens)
    -- Similar structure to queryOpenAIText
    -- Uses configurable baseUrl instead of hardcoded OpenAI endpoint
end
```

#### Provider Routing

**AIEngine.lua - `queryBatch()` Function:**

```lua
function M.queryBatch(images, imageLabels, anchorImages, anchorLabels, prompt, prefs, maxTokens)
    local provider = prefs.provider
    local timeoutSecs = prefs.timeoutSecs
    
    -- ... existing providers ...
    
    elseif provider == "openaiCompatible" then
        return M.queryOpenAICompatibleBatch(
            images, imageLabels, anchorImages, anchorLabels,
            prompt, prefs.openaiCompatibleModel, prefs.openaiCompatibleApiKey,
            prefs.openaiCompatibleUrl, maxTokens, timeoutSecs
        )
    end
end
```

**AIEngine.lua - `queryText()` Function:**

```lua
function M.queryText(prompt, prefs, maxTokens)
    local provider = prefs.provider
    local timeoutSecs = prefs.timeoutSecs
    
    -- ... existing providers ...
    
    elseif provider == "openaiCompatible" then
        return M.queryOpenAICompatibleText(
            prompt, prefs.openaiCompatibleModel, prefs.openaiCompatibleApiKey,
            prefs.openaiCompatibleUrl, timeoutSecs, maxTokens
        )
    end
end
```

#### Cost Tracking

**AIEngine.lua - PRICING Table:**

```lua
openaiCompatible = {
    _default = { input = 0.00, output = 0.00 },  -- Unknown provider, no cost tracking
},
```

Since pricing varies by provider, we don't track costs for OpenAI-Compatible. Users should check their provider's dashboard.

#### Validation

**Config.lua - `validateSettings()` Function:**

```lua
if values.provider == "openaiCompatible" then
    if values.openaiCompatibleApiKey == nil or values.openaiCompatibleApiKey == "" then
        return false, "OpenAI-Compatible API selected — enter your API key."
    end
    local url = values.openaiCompatibleUrl or ""
    if not url:match("^https?://") then
        return false, "API Base URL must start with http:// or https://"
    end
end
```

### Common Provider Configurations

| Provider | Base URL | Example Models |
|----------|----------|----------------|
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat`, `deepseek-reasoner` |
| Moonshot (Kimi) | `https://api.moonshot.cn/v1` | `moonshot-v1-8k`, `moonshot-v1-32k` |
| Zhipu AI | `https://open.bigmodel.cn/api/paas/v4` | `glm-4`, `glm-4v` (vision) |
| SiliconFlow | `https://api.siliconflow.cn/v1` | `Qwen/Qwen2.5-VL-72B-Instruct` |
| Local vLLM | `http://localhost:8000/v1` | Model name as loaded in vLLM |
| LM Studio | `http://localhost:1234/v1` | Model name shown in LM Studio |

### Error Handling

Provide clear error messages for common failure modes:

- **Connection refused**: "Could not connect to [base URL]. Is the server running?"
- **401 Unauthorized**: "Invalid API key for OpenAI-Compatible endpoint"
- **404 Not Found**: "Endpoint not found. Check API Base URL (should end with /v1)"
- **Model not found**: "Model '[model_name]' not found. Check your model name."
- **Timeout**: "Request timed out after [timeout] seconds"

### Security Considerations

- API keys stored in Lightroom preferences (same as existing cloud providers)
- No validation of API key format (different providers use different formats)
- Users responsible for ensuring their endpoint is trustworthy

### Testing Strategy

1. Test with DeepSeek API (major Chinese provider)
2. Test with local vLLM server (self-hosted scenario)
3. Verify error messages are clear and actionable
4. Confirm anchor images work correctly
5. Test with both vision and text-only endpoints

---

## Implementation Plan

### Phase 1: Chinese Output Support

1. Update `Prefs.lua` with `outputLanguage` preference
2. Update `Config.lua` UI with language dropdown
3. Add `getLanguageInstruction()` helper to `AIEngine.lua`
4. Modify all prompt builders to inject language instruction
5. Test with multiple providers

### Phase 2: OpenAI-Compatible Provider

1. Update `Prefs.lua` with three new preferences
2. Update `BatchStrategy.lua` with provider config
3. Update `Config.lua` UI with new provider option and fields
4. Add `queryOpenAICompatibleBatch()` to `AIEngine.lua`
5. Add `queryOpenAICompatibleText()` to `AIEngine.lua`
6. Update routing in `queryBatch()` and `queryText()`
7. Add validation logic
8. Test with multiple endpoints

### Phase 3: Integration Testing

1. Test Chinese output with all providers
2. Test OpenAI-Compatible with DeepSeek and Moonshot
3. Test combination (Chinese output + OpenAI-Compatible)
4. Verify no regressions in existing functionality
5. Update documentation

---

## Risks and Mitigations

### Chinese Output

**Risk:** Some models may not follow language instructions well  
**Mitigation:** Document which models have good Chinese support; user can switch models if needed

**Risk:** Chinese text may be longer, hitting token limits  
**Mitigation:** Current token limits have headroom; monitor in testing

### OpenAI-Compatible API

**Risk:** Different providers may have subtle API differences  
**Mitigation:** Stick to standard OpenAI format; let provider-specific quirks be user's responsibility

**Risk:** Users may enter invalid endpoints  
**Mitigation:** Provide clear examples; show helpful error messages

**Risk:** No cost tracking for unknown providers  
**Mitigation:** Document that users should check their provider's dashboard

---

## Success Criteria

- Chinese output produces natural, accurate Chinese text for all prompt types
- Chinese output works with all existing providers (Claude, OpenAI, Gemini, Ollama)
- OpenAI-Compatible provider successfully connects to at least DeepSeek and a local vLLM server
- No regression in existing functionality
- Clear error messages help users troubleshoot configuration issues
- Code changes are minimal and maintainable

---

## Future Enhancements

- Support for Traditional Chinese (`zh-tw`)
- Per-run language toggle in addition to global setting
- Cost tracking for known OpenAI-compatible providers (if pricing APIs available)
- Auto-detect available models from endpoint (requires provider-specific APIs)
- Favorite endpoints list for quick switching
