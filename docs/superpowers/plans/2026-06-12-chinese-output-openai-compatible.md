# Chinese Output and OpenAI-Compatible API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Chinese output for scoring responses and support for OpenAI-compatible API endpoints.

**Architecture:** Minimal injection approach — add new preferences, extend UI, and branch existing OpenAI code path for custom endpoints. No refactoring of existing provider logic.

**Tech Stack:** Lua (Lightroom SDK), JSON, HTTP/curl

---

## File Structure

| File | Purpose |
|------|---------|
| `AISelects.lrplugin/Prefs.lua` | Add new preference defaults |
| `AISelects.lrplugin/Config.lua` | Add UI elements (checkbox, radio button, input fields) |
| `AISelects.lrplugin/AIEngine.lua` | Add Chinese prompt suffix, add OpenAI-compatible API call functions |
| `AISelects.lrplugin/BatchStrategy.lua` | Add OpenAI-compatible to provider config map |

---

## Task 1: Add Preferences to Prefs.lua

**Files:**
- Modify: `AISelects.lrplugin/Prefs.lua:12-44`

- [ ] **Step 1: Add new preference defaults to DEFAULTS table**

Add 4 new preferences to the `DEFAULTS` table in `Prefs.lua`:

```lua
local DEFAULTS = {
    -- Provider
    provider           = "ollama",
    ollamaUrl          = "http://localhost:11434",
    model              = "qwen2.5vl:7b",
    claudeApiKey       = "",
    claudeModel        = "claude-haiku-4-5-20251001",
    openaiApiKey       = "",
    openaiModel        = "gpt-4.1-mini",
    geminiApiKey       = "",
    geminiModel        = "gemini-2.5-flash",
    -- OpenAI-Compatible (NEW)
    openaiCompatibleBaseUrl = "",
    openaiCompatibleApiKey  = "",
    openaiCompatibleModel   = "",
    timeoutSecs        = 90,
    -- Selection
    selectionMode      = "bestof",
    targetCount        = 40,
    emphasisSlider     = 50,
    renderSize         = 512,
    burstThresholdSecs = 2,
    skipScored         = false,
    -- Scoring
    nitpickyScale      = "consumer",
    batchSize          = 0,
    -- Chinese Output (NEW)
    enableChineseOutput = false,
    -- Story mode
    storyPreset            = "family_vacation",
    -- Pre-scoring context (all modes)
    preHints           = "",
    -- Story prompt (confirmed by user after Pass 1)
    storyPrompt        = "",
    storyEmphasis      = "",
    -- Logging
    enableLogging      = false,
    logFolder          = "",
}
```

- [ ] **Step 2: Add new preferences to getPrefs() return table**

Add the 4 new preferences to the `getPrefs()` function's return table (around line 69-94):

```lua
local function getPrefs()
    local prefs = LrPrefs.prefsForPlugin()
    return {
        provider           = stringPref(prefs, "provider"),
        ollamaUrl          = stringPref(prefs, "ollamaUrl"),
        model              = stringPref(prefs, "model"),
        claudeApiKey       = stringPref(prefs, "claudeApiKey", true),
        claudeModel        = stringPref(prefs, "claudeModel"),
        openaiApiKey       = stringPref(prefs, "openaiApiKey", true),
        openaiModel        = stringPref(prefs, "openaiModel"),
        geminiApiKey       = stringPref(prefs, "geminiApiKey", true),
        geminiModel        = stringPref(prefs, "geminiModel"),
        -- OpenAI-Compatible (NEW)
        openaiCompatibleBaseUrl = stringPref(prefs, "openaiCompatibleBaseUrl", true),
        openaiCompatibleApiKey  = stringPref(prefs, "openaiCompatibleApiKey", true),
        openaiCompatibleModel   = stringPref(prefs, "openaiCompatibleModel", true),
        timeoutSecs        = numPref(prefs, "timeoutSecs"),
        selectionMode      = stringPref(prefs, "selectionMode"),
        targetCount        = numPref(prefs, "targetCount"),
        emphasisSlider     = numPref(prefs, "emphasisSlider"),
        renderSize         = numPref(prefs, "renderSize"),
        burstThresholdSecs = numPref(prefs, "burstThresholdSecs"),
        skipScored         = boolPref(prefs, "skipScored"),
        nitpickyScale      = stringPref(prefs, "nitpickyScale"),
        batchSize          = numPref(prefs, "batchSize"),
        -- Chinese Output (NEW)
        enableChineseOutput = boolPref(prefs, "enableChineseOutput"),
        storyPreset            = stringPref(prefs, "storyPreset"),
        preHints           = stringPref(prefs, "preHints", true),
        storyPrompt        = stringPref(prefs, "storyPrompt", true),
        storyEmphasis      = stringPref(prefs, "storyEmphasis", true),
        enableLogging      = boolPref(prefs, "enableLogging"),
        logFolder          = stringPref(prefs, "logFolder", true),
    }
end
```

- [ ] **Step 3: Commit Prefs.lua changes**

```bash
git add AISelects.lrplugin/Prefs.lua
git commit -m "feat: add Chinese output and OpenAI-compatible preferences"
```

---

## Task 2: Add Provider Config to BatchStrategy.lua

**Files:**
- Modify: `AISelects.lrplugin/BatchStrategy.lua:14-47`

- [ ] **Step 1: Add openai-compatible to PROVIDER_CONFIG table**

Add a new entry to the `PROVIDER_CONFIG` table in `BatchStrategy.lua` (after the `gemini` entry, around line 46):

```lua
local PROVIDER_CONFIG = {
    ollama = {
        batchSize        = 4,
        maxAnchors       = 1,
        supportsSnapshot = false,
        scoringMaxTokens = 6144,
        synthesisMaxTokens = 4096,
        defaultTimeout   = 60,
    },
    claude = {
        batchSize        = 10,
        maxAnchors       = 2,
        supportsSnapshot = true,
        scoringMaxTokens = 4096,
        synthesisMaxTokens = 8192,
        defaultTimeout   = 180,
    },
    openai = {
        batchSize        = 10,
        maxAnchors       = 2,
        supportsSnapshot = true,
        scoringMaxTokens = 4096,
        synthesisMaxTokens = 8192,
        defaultTimeout   = 180,
    },
    gemini = {
        batchSize        = 10,
        maxAnchors       = 2,
        supportsSnapshot = true,
        scoringMaxTokens = 4096,
        synthesisMaxTokens = 16384,
        defaultTimeout   = 180,
    },
    -- OpenAI-Compatible (NEW) - same as OpenAI
    ["openai-compatible"] = {
        batchSize        = 10,
        maxAnchors       = 2,
        supportsSnapshot = true,
        scoringMaxTokens = 4096,
        synthesisMaxTokens = 8192,
        defaultTimeout   = 180,
    },
}
```

- [ ] **Step 2: Commit BatchStrategy.lua changes**

```bash
git add AISelects.lrplugin/BatchStrategy.lua
git commit -m "feat: add OpenAI-compatible provider config to BatchStrategy"
```

---

## Task 3: Add Chinese Output to Scoring Prompt

**Files:**
- Modify: `AISelects.lrplugin/AIEngine.lua:207-378`

- [ ] **Step 1: Modify buildBatchScoringPrompt() to accept enableChineseOutput parameter**

Update the function signature to accept the new parameter (line 207):

```lua
function M.buildBatchScoringPrompt(photoIds, timestamps, exifData, anchors, nitpickyScale, includeSnapshot, preHints, priorSnapshots, enableChineseOutput)
```

- [ ] **Step 2: Add Chinese output instruction at end of prompt**

Before the final `return table.concat(parts)` (line 377), add the Chinese output instruction:

```lua
    -- Chinese output instruction (optional)
    if enableChineseOutput then
        parts[#parts + 1] = "\n\n请使用中文输出所有评分理由和描述内容（content字段）。"
    end

    return table.concat(parts)
end
```

- [ ] **Step 3: Commit AIEngine.lua Chinese output changes**

```bash
git add AISelects.lrplugin/AIEngine.lua
git commit -m "feat: add Chinese output instruction to scoring prompt"
```

---

## Task 4: Add OpenAI-Compatible API Functions

**Files:**
- Modify: `AISelects.lrplugin/AIEngine.lua` (add new functions after queryOpenAIBatch)

- [ ] **Step 1: Add queryOpenAICompatibleBatch() function**

Add after `queryOpenAIBatch()` function (around line 1628). This function is identical to `queryOpenAIBatch()` but accepts a `baseUrl` parameter:

```lua
-- == Multi-image batch query: OpenAI-Compatible =================================
-- Same as OpenAI but with configurable base URL.
function M.queryOpenAICompatibleBatch(images, imageLabels, anchorImages, anchorLabels,
                                      prompt, model, apiKey, baseUrl, maxTokens, timeoutSecs)
    local ts = tostring(math.floor(LrDate.currentTime() * 1000))

    local content = {}
    local totalSize = 0

    -- Anchor images first
    if anchorImages then
        content[#content + 1] = {
            type = "text",
            text = "=== REFERENCE ANCHORS (already scored, DO NOT re-score) ===",
        }
        for i, img in ipairs(anchorImages) do
            content[#content + 1] = {
                type = "text",
                text = anchorLabels[i] or string.format("[Anchor %d]", i),
            }
            content[#content + 1] = {
                type      = "image_url",
                image_url = {
                    url    = "data:image/jpeg;base64," .. img.base64,
                    detail = "low",
                },
            }
            totalSize = totalSize + img.fileSize
        end
        content[#content + 1] = {
            type = "text",
            text = "=== NEW PHOTOS TO SCORE (return scores for these only) ===",
        }
    end

    -- New photos
    for i, img in ipairs(images) do
        content[#content + 1] = {
            type = "text",
            text = imageLabels[i] or string.format("[Photo %d]", i),
        }
        content[#content + 1] = {
            type      = "image_url",
            image_url = {
                url    = "data:image/jpeg;base64," .. img.base64,
                detail = "low",
            },
        }
        totalSize = totalSize + img.fileSize
    end

    -- Prompt as final text block
    content[#content + 1] = {
        type = "text",
        text = prompt,
    }

    local encodeOk, body = pcall(json.encode, {
        model      = model,
        max_tokens = maxTokens or 4096,
        messages   = {{
            role    = "user",
            content = content,
        }}
    })
    if not encodeOk then return nil, "JSON encode failed: " .. tostring(body) end

    local cleanKey = apiKey:gsub("%s+", "")
    local cleanUrl = baseUrl:gsub("/$", "") -- remove trailing slash if present

    local tmpCfg = M.TEMP_DIR .. "/ai_sel_cfg_" .. ts .. ".txt"
    local tmpIn  = M.TEMP_DIR .. "/ai_sel_req_" .. ts .. ".json"
    local tmpOut = M.TEMP_DIR .. "/ai_sel_resp_" .. ts .. ".json"

    if not M.writeCurlConfig(tmpCfg, cleanUrl .. "/chat/completions", {
        "Authorization: Bearer " .. cleanKey,
        "Content-Type: application/json",
    }, timeoutSecs) then
        return nil, "Could not write curl config file"
    end

    local fh = io.open(tmpIn, "w")
    if not fh then return nil, "Could not write temp file: " .. tmpIn end
    fh:write(body); fh:close()

    local result, err = M.curlPost(tmpCfg, tmpIn, tmpOut, totalSize, timeoutSecs)
    if not result then return nil, err end

    local ok, decoded = pcall(function() return json.decode(result) end)
    if not ok or type(decoded) ~= "table" then
        return nil, "Could not parse OpenAI-Compatible response: " .. tostring(result):sub(1, 200)
    end

    if decoded.error then
        return nil, "OpenAI-Compatible API error: " .. (decoded.error.message or "Unknown")
    end

    -- Extract usage for cost tracking
    if decoded.usage then
        recordUsage("openai-compatible", model,
            decoded.usage.prompt_tokens, decoded.usage.completion_tokens)
    end

    local stopReason = decoded.choices and decoded.choices[1]
        and decoded.choices[1].finish_reason

    if decoded.choices and decoded.choices[1] and decoded.choices[1].message then
        return decoded.choices[1].message.content, nil, stopReason
    end

    return nil, "Unexpected OpenAI-Compatible response: " .. tostring(result):sub(1, 200)
end
```

- [ ] **Step 2: Add queryOpenAICompatibleText() function**

Add after `queryOpenAIText()` function (around line 1980):

```lua
function M.queryOpenAICompatibleText(prompt, model, apiKey, baseUrl, timeoutSecs, maxTokens)
    local ts = tostring(math.floor(LrDate.currentTime() * 1000))
    local encodeOk, body = pcall(json.encode, {
        model      = model,
        max_tokens = maxTokens or 8192,
        messages   = {{
            role    = "user",
            content = prompt,
        }}
    })
    if not encodeOk then return nil, "JSON encode failed: " .. tostring(body) end

    local cleanKey = apiKey:gsub("%s+", "")
    local cleanUrl = baseUrl:gsub("/$", "")

    local tmpCfg = M.TEMP_DIR .. "/ai_sel_cfg_" .. ts .. ".txt"
    local tmpIn  = M.TEMP_DIR .. "/ai_sel_req_" .. ts .. ".json"
    local tmpOut = M.TEMP_DIR .. "/ai_sel_resp_" .. ts .. ".json"

    if not M.writeCurlConfig(tmpCfg, cleanUrl .. "/chat/completions", {
        "Authorization: Bearer " .. cleanKey,
        "Content-Type: application/json",
    }, timeoutSecs) then
        return nil, "Could not write curl config file"
    end

    local fh = io.open(tmpIn, "w")
    if not fh then return nil, "Could not write temp file: " .. tmpIn end
    fh:write(body); fh:close()

    local result, err = M.curlPost(tmpCfg, tmpIn, tmpOut, 0, timeoutSecs)
    if not result then return nil, err end

    local ok, decoded = pcall(function() return json.decode(result) end)
    if not ok or type(decoded) ~= "table" then
        return nil, "Could not parse OpenAI-Compatible response: " .. tostring(result):sub(1, 200)
    end

    if decoded.error then
        return nil, "OpenAI-Compatible API error: " .. (decoded.error.message or "Unknown")
    end

    if decoded.usage then
        recordUsage("openai-compatible", model,
            decoded.usage.prompt_tokens, decoded.usage.completion_tokens)
    end

    local stopReason = decoded.choices and decoded.choices[1]
        and decoded.choices[1].finish_reason

    if decoded.choices and decoded.choices[1] and decoded.choices[1].message then
        return decoded.choices[1].message.content, nil, stopReason
    end

    return nil, "Unexpected OpenAI-Compatible response: " .. tostring(result):sub(1, 200)
end
```

- [ ] **Step 3: Commit AIEngine.lua OpenAI-compatible functions**

```bash
git add AISelects.lrplugin/AIEngine.lua
git commit -m "feat: add OpenAI-compatible batch and text query functions"
```

---

## Task 5: Update queryBatch() to Handle OpenAI-Compatible

**Files:**
- Modify: `AISelects.lrplugin/AIEngine.lua:1792-1813`

- [ ] **Step 1: Add openai-compatible branch to queryBatch()**

Add a new branch in the `queryBatch()` function (after the `gemini` branch, around line 1809):

```lua
function M.queryBatch(images, imageLabels, anchorImages, anchorLabels, prompt, prefs, maxTokens)
    local provider = prefs.provider
    local timeout  = prefs.timeoutSecs or BatchStrategy.getDefaultTimeout(provider)

    if provider == "ollama" then
        return M.queryOllamaBatch(images, prompt, prefs.model, prefs.ollamaUrl, timeout)
    elseif provider == "claude" then
        return M.queryClaudeBatch(images, imageLabels, anchorImages, anchorLabels,
            prompt, prefs.claudeModel, prefs.claudeApiKey, maxTokens, timeout)
    elseif provider == "openai" then
        return M.queryOpenAIBatch(images, imageLabels, anchorImages, anchorLabels,
            prompt, prefs.openaiModel, prefs.openaiApiKey, maxTokens, timeout)
    elseif provider == "gemini" then
        return M.queryGeminiBatch(images, imageLabels, anchorImages, anchorLabels,
            prompt, prefs.geminiModel, prefs.geminiApiKey, maxTokens, timeout)
    elseif provider == "openai-compatible" then
        return M.queryOpenAICompatibleBatch(images, imageLabels, anchorImages, anchorLabels,
            prompt, prefs.openaiCompatibleModel, prefs.openaiCompatibleApiKey,
            prefs.openaiCompatibleBaseUrl, maxTokens, timeout)
    else
        return nil, "Unknown provider: " .. tostring(provider)
    end
end
```

- [ ] **Step 2: Commit queryBatch() changes**

```bash
git add AISelects.lrplugin/AIEngine.lua
git commit -m "feat: add openai-compatible provider to queryBatch router"
```

---

## Task 6: Add UI Elements to Config.lua

**Files:**
- Modify: `AISelects.lrplugin/Config.lua`

- [ ] **Step 1: Add OpenAI-Compatible radio button**

Add a new row with radio button for OpenAI-Compatible in the provider selector section (after the Gemini radio button, around line 284):

```lua
            f:row {
                f:static_text {
                    title     = "AI Provider:",
                    width     = LrView.share("label_width"),
                    alignment = "right",
                },
                f:radio_button {
                    title         = "Ollama (local)",
                    value         = LrView.bind("provider"),
                    checked_value = "ollama",
                },
                f:radio_button {
                    title         = "Claude API (cloud)",
                    value         = LrView.bind("provider"),
                    checked_value = "claude",
                },
            },
            f:row {
                f:static_text {
                    title     = "",
                    width     = LrView.share("label_width"),
                },
                f:radio_button {
                    title         = "OpenAI API (cloud)",
                    value         = LrView.bind("provider"),
                    checked_value = "openai",
                },
                f:radio_button {
                    title         = "Gemini API (cloud)",
                    value         = LrView.bind("provider"),
                    checked_value = "gemini",
                },
            },
            f:row {
                f:static_text {
                    title     = "",
                    width     = LrView.share("label_width"),
                },
                f:radio_button {
                    title         = "OpenAI-Compatible",
                    value         = LrView.bind("provider"),
                    checked_value = "openai-compatible",
                },
            },
```

- [ ] **Step 2: Add OpenAI-Compatible config group box**

Add a new group box for OpenAI-Compatible settings (after the Gemini API group box, around line 510):

```lua
            -- ═══════════════════════════════════════════════════════════
            -- OPENAI-COMPATIBLE API
            -- ═══════════════════════════════════════════════════════════
            f:group_box {
                title           = "OpenAI-Compatible API",
                fill_horizontal = 1,
                f:row {
                    f:static_text {
                        title     = "Base URL:",
                        width     = LrView.share("label_width"),
                        alignment = "right",
                    },
                    f:edit_field {
                        value          = LrView.bind("openaiCompatibleBaseUrl"),
                        width_in_chars = 40,
                    },
                },
                f:row {
                    f:static_text {
                        title     = "API Key:",
                        width     = LrView.share("label_width"),
                        alignment = "right",
                    },
                    f:edit_field {
                        value          = LrView.bind("openaiCompatibleApiKey"),
                        width_in_chars = 55,
                    },
                },
                f:row {
                    f:static_text {
                        title     = "Model:",
                        width     = LrView.share("label_width"),
                        alignment = "right",
                    },
                    f:edit_field {
                        value          = LrView.bind("openaiCompatibleModel"),
                        width_in_chars = 30,
                    },
                },
                f:row {
                    f:static_text {
                        title = "",
                        width = LrView.share("label_width"),
                    },
                    f:static_text {
                        title      = "Supports any OpenAI-compatible endpoint (Ollama, LM Studio, DeepSeek, Qwen, etc.)",
                        text_color = LrView.kDisabledColor,
                    },
                },
            },
```

- [ ] **Step 3: Add Chinese output checkbox to Scoring & Selection group**

Add the checkbox to the Scoring & Selection group box (around line 565):

```lua
                f:row {
                    f:static_text {
                        title = "",
                        width = LrView.share("label_width"),
                    },
                    f:checkbox {
                        title = "Skip photos that already have scores",
                        value = LrView.bind("skipScored"),
                    },
                },
                f:row {
                    f:static_text {
                        title = "",
                        width = LrView.share("label_width"),
                    },
                    f:checkbox {
                        title = "使用中文输出评分 (Use Chinese for scoring)",
                        value = LrView.bind("enableChineseOutput"),
                    },
                },
```

- [ ] **Step 4: Add props bindings for new preferences**

Add property bindings for the new preferences (around line 196):

```lua
        props.geminiModel        = current.geminiModel
        props.openaiCompatibleBaseUrl = current.openaiCompatibleBaseUrl
        props.openaiCompatibleApiKey  = current.openaiCompatibleApiKey
        props.openaiCompatibleModel   = current.openaiCompatibleModel
        props.timeoutSecs        = tostring(current.timeoutSecs)
        -- ... existing code ...
        props.skipScored         = current.skipScored
        props.enableChineseOutput = current.enableChineseOutput
        props.enableLogging      = current.enableLogging
```

- [ ] **Step 5: Add validation for OpenAI-Compatible**

Update the `validateSettings()` function to validate OpenAI-Compatible fields (around line 698):

```lua
        local function validateSettings(values)
            local timeout = tonumber(values.timeoutSecs)
            if not timeout or timeout < 5 then
                return false, "Timeout must be at least 5 seconds."
            end
            local burst = tonumber(values.burstThresholdSecs)
            if not burst or burst < 0 then
                return false, "Burst threshold must be a positive number."
            end
            if values.provider == "claude" and (values.claudeApiKey == nil or values.claudeApiKey == "") then
                return false, "Claude API selected — enter your Anthropic API key."
            end
            if values.provider == "openai" and (values.openaiApiKey == nil or values.openaiApiKey == "") then
                return false, "OpenAI API selected — enter your OpenAI API key."
            end
            if values.provider == "gemini" and (values.geminiApiKey == nil or values.geminiApiKey == "") then
                return false, "Gemini API selected — enter your Google AI API key."
            end
            -- OpenAI-Compatible validation (NEW)
            if values.provider == "openai-compatible" then
                if values.openaiCompatibleBaseUrl == nil or values.openaiCompatibleBaseUrl == "" then
                    return false, "OpenAI-Compatible selected — enter the base URL."
                end
                if not values.openaiCompatibleBaseUrl:match("^https?://") then
                    return false, "Base URL must start with http:// or https://"
                end
                if values.openaiCompatibleApiKey == nil or values.openaiCompatibleApiKey == "" then
                    return false, "OpenAI-Compatible selected — enter the API key."
                end
                if values.openaiCompatibleModel == nil or values.openaiCompatibleModel == "" then
                    return false, "OpenAI-Compatible selected — enter the model name."
                end
            end
            local url = values.ollamaUrl or ""
            if values.provider == "ollama" and not url:match("^https?://") then
                return false, "Ollama URL must start with http:// or https://"
            end
            return true, ""
        end
```

- [ ] **Step 6: Update actionBinding keys**

Add the new preference keys to the actionBinding (around line 721):

```lua
            actionBinding = {
                enabled = {
                    bind_to_object = props,
                    keys = {
                        "timeoutSecs", "burstThresholdSecs",
                        "claudeApiKey", "openaiApiKey", "geminiApiKey",
                        "openaiCompatibleBaseUrl", "openaiCompatibleApiKey", "openaiCompatibleModel",
                        "provider", "ollamaUrl",
                    },
                    operation = function(_, values)
                        local isValid, validMsg = validateSettings(values)
                        props.validationMessage = validMsg
                        return isValid
                    end,
                },
            },
```

- [ ] **Step 7: Save new preferences on dialog OK**

Add the new preferences to the save block (around line 747):

```lua
        if result == "ok" then
            prefs.provider           = props.provider
            prefs.ollamaUrl          = props.ollamaUrl
            prefs.model              = props.model
            prefs.claudeApiKey       = props.claudeApiKey
            prefs.claudeModel        = props.claudeModel
            prefs.openaiApiKey       = props.openaiApiKey
            prefs.openaiModel        = props.openaiModel
            prefs.geminiApiKey       = props.geminiApiKey
            prefs.geminiModel        = props.geminiModel
            -- OpenAI-Compatible (NEW)
            prefs.openaiCompatibleBaseUrl = props.openaiCompatibleBaseUrl
            prefs.openaiCompatibleApiKey  = props.openaiCompatibleApiKey
            prefs.openaiCompatibleModel   = props.openaiCompatibleModel
            prefs.timeoutSecs        = math.floor(tonumber(props.timeoutSecs))
            prefs.renderSize         = props.renderSize
            prefs.burstThresholdSecs = tonumber(props.burstThresholdSecs)
            prefs.skipScored         = props.skipScored
            -- Chinese Output (NEW)
            prefs.enableChineseOutput = props.enableChineseOutput
            prefs.enableLogging      = props.enableLogging
            prefs.logFolder          = props.logFolder
        end
```

- [ ] **Step 8: Commit Config.lua changes**

```bash
git add AISelects.lrplugin/Config.lua
git commit -m "feat: add UI for Chinese output and OpenAI-Compatible provider"
```

---

## Task 7: Update ScorePhotos.lua to Pass Chinese Output Preference

**Files:**
- Modify: `AISelects.lrplugin/ScorePhotos.lua`

- [ ] **Step 1: Find the buildBatchScoringPrompt() call and add enableChineseOutput parameter**

Search for the call to `Engine.buildBatchScoringPrompt()` in ScorePhotos.lua and add the `enableChineseOutput` parameter. The call should be updated to pass `prefs.enableChineseOutput` as the last argument.

Example (the exact location may vary):
```lua
local prompt = Engine.buildBatchScoringPrompt(
    photoIds, timestamps, exifData, anchors,
    prefs.nitpickyScale, includeSnapshot, prefs.preHints, priorSnapshots,
    prefs.enableChineseOutput  -- NEW
)
```

- [ ] **Step 2: Commit ScorePhotos.lua changes**

```bash
git add AISelects.lrplugin/ScorePhotos.lua
git commit -m "feat: pass enableChineseOutput to scoring prompt builder"
```

---

## Task 8: Update Text Query Router for OpenAI-Compatible

**Files:**
- Modify: `AISelects.lrplugin/AIEngine.lua`

- [ ] **Step 1: Find queryText() or similar router function and add openai-compatible branch**

Search for the text query router function (similar to `queryBatch()`) and add the openai-compatible branch. This is used for scene inventory, story assembly, etc.

Example:
```lua
function M.queryText(prompt, prefs, maxTokens)
    local provider = prefs.provider
    local timeout  = prefs.timeoutSecs or BatchStrategy.getDefaultTimeout(provider)

    if provider == "ollama" then
        return M.queryOllamaText(prompt, prefs.model, prefs.ollamaUrl, timeout)
    elseif provider == "claude" then
        return M.queryClaudeText(prompt, prefs.claudeModel, prefs.claudeApiKey, timeout, maxTokens)
    elseif provider == "openai" then
        return M.queryOpenAIText(prompt, prefs.openaiModel, prefs.openaiApiKey, timeout, maxTokens)
    elseif provider == "gemini" then
        return M.queryGeminiText(prompt, prefs.geminiModel, prefs.geminiApiKey, timeout, maxTokens)
    elseif provider == "openai-compatible" then
        return M.queryOpenAICompatibleText(prompt, prefs.openaiCompatibleModel,
            prefs.openaiCompatibleApiKey, prefs.openaiCompatibleBaseUrl, timeout, maxTokens)
    else
        return nil, "Unknown provider: " .. tostring(provider)
    end
end
```

- [ ] **Step 2: Commit text query router changes**

```bash
git add AISelects.lrplugin/AIEngine.lua
git commit -m "feat: add openai-compatible to text query router"
```

---

## Task 9: Final Integration Test

**Files:**
- None (manual testing)

- [ ] **Step 1: Restart Lightroom Classic**

The plugin code is cached in memory. Restart Lightroom to load the new code.

- [ ] **Step 2: Test Chinese Output**

1. Open Settings dialog
2. Enable "使用中文输出评分 (Use Chinese for scoring)" checkbox
3. Save settings
4. Score 3-5 photos with any provider
5. Verify scoring responses contain Chinese text in the `content` field

- [ ] **Step 3: Test OpenAI-Compatible with Ollama**

1. Open Settings dialog
2. Select "OpenAI-Compatible" provider
3. Enter base URL: `http://localhost:11434/v1`
4. Enter API key: `ollama` (or any dummy value for Ollama)
5. Enter model: `qwen2.5vl:7b` (or your installed vision model)
6. Save settings
7. Score 3-5 photos
8. Verify API calls hit the correct endpoint

- [ ] **Step 4: Test Backwards Compatibility**

1. Switch back to "Ollama (local)" provider
2. Score photos
3. Verify existing functionality works unchanged

---

## Summary

| Task | Description | Files Changed |
|------|-------------|---------------|
| 1 | Add preferences to Prefs.lua | `Prefs.lua` |
| 2 | Add provider config to BatchStrategy.lua | `BatchStrategy.lua` |
| 3 | Add Chinese output to scoring prompt | `AIEngine.lua` |
| 4 | Add OpenAI-Compatible API functions | `AIEngine.lua` |
| 5 | Update queryBatch() router | `AIEngine.lua` |
| 6 | Add UI elements to Config.lua | `Config.lua` |
| 7 | Update ScorePhotos.lua | `ScorePhotos.lua` |
| 8 | Update text query router | `AIEngine.lua` |
| 9 | Integration testing | Manual |
