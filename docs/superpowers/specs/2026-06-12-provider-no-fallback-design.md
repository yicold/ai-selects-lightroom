---
name: provider-no-fallback
description: Ensure strict provider routing with no silent fallback to Ollama
type: project
---

# Provider No-Fallback Design

## Problem Statement

User reported two issues:
1. **Observed fallback behavior**: When cloud providers (Claude/OpenAI/Gemini/OpenAI-Compatible) are configured, the system sometimes falls back to Ollama
2. **Need preventive guarantee**: Ensure code has no implicit fallback logic

## Root Cause Analysis

Found three locations with implicit Ollama fallback:

### Issue 1: `ScorePhotos.lua` line 233-234
```lua
else
    modelName = SETTINGS.model  -- Assumes non-cloud = Ollama
```
**Problem**: When `provider = "openai-compatible"`, this falls back to Ollama's model setting.

### Issue 2: `ScorePhotos.lua` line 240
```lua
local providerLabel = providerLabels[SETTINGS.provider] or "Ollama"
```
**Problem**: `providerLabels` table lacks "openai-compatible" key, so it displays as "Ollama".

### Issue 3: `ScoreAndSelect.lua` line 67-74
```lua
if current.provider == "claude" then
    providerLabel = "Claude API — " .. current.claudeModel
elseif current.provider == "openai" then
    providerLabel = "OpenAI API — " .. current.openaiModel
elseif current.provider == "gemini" then
    providerLabel = "Gemini API — " .. current.geminiModel
else
    providerLabel = "Ollama — " .. current.model  -- Falls back for openai-compatible
end
```
**Problem**: Missing `openai-compatible` branch causes incorrect display.

## Solution Design

### Approach: Add explicit branches + defensive validation

**Why this approach:**
- Fixes all three implicit fallback points
- Adds explicit error handling for unknown providers
- Maintains consistency with existing code style
- Prevents future similar issues through defensive checks

### Modification 1: `ScorePhotos.lua` getProviderInfo()

**File**: `AISelects.lrplugin/ScorePhotos.lua`
**Lines**: 225-242

**Changes**:
1. Add explicit `openai-compatible` branch before the `else`
2. Change `else` to explicit `elseif SETTINGS.provider == "ollama"`
3. Add error dialog in final `else` for unknown providers
4. Add `["openai-compatible"] = "OpenAI-Compatible"` to `providerLabels` table
5. Remove `or "Ollama"` fallback, replace with explicit validation

**New code**:
```lua
local function getProviderInfo(SETTINGS)
    local modelName
    if SETTINGS.provider == "claude" then
        modelName = SETTINGS.claudeModel
    elseif SETTINGS.provider == "openai" then
        modelName = SETTINGS.openaiModel
    elseif SETTINGS.provider == "gemini" then
        modelName = SETTINGS.geminiModel
    elseif SETTINGS.provider == "openai-compatible" then
        modelName = SETTINGS.openaiCompatibleModel
    elseif SETTINGS.provider == "ollama" then
        modelName = SETTINGS.model
    else
        -- Explicit error: unknown provider, prevent implicit fallback
        LrDialogs.message("AI Selects - Configuration Error",
            "Unknown provider: " .. tostring(SETTINGS.provider) ..
            "\n\nPlease check your provider settings.", "warning")
        return nil, nil
    end

    local providerLabels = {
        claude = "Claude API",
        openai = "OpenAI API",
        gemini = "Gemini API",
        ollama = "Ollama",
        ["openai-compatible"] = "OpenAI-Compatible",
    }
    local providerLabel = providerLabels[SETTINGS.provider]
    if not providerLabel then
        -- Defensive check: should not reach here
        LrDialogs.message("AI Selects - Internal Error",
            "Provider label not found for: " .. tostring(SETTINGS.provider), "warning")
        return nil, modelName
    end

    return providerLabel, modelName or "unknown"
end
```

### Modification 2: `ScoreAndSelect.lua` provider display

**File**: `AISelects.lrplugin/ScoreAndSelect.lua`
**Lines**: 65-76

**Changes**:
1. Add explicit `openai-compatible` branch
2. Change `else` to explicit `elseif current.provider == "ollama"`
3. Add explicit error message for unknown providers

**New code**:
```lua
-- Provider info (read-only display)
local providerLabel
if current.provider == "claude" then
    providerLabel = "Claude API — " .. current.claudeModel
elseif current.provider == "openai" then
    providerLabel = "OpenAI API — " .. current.openaiModel
elseif current.provider == "gemini" then
    providerLabel = "Gemini API — " .. current.geminiModel
elseif current.provider == "openai-compatible" then
    providerLabel = "OpenAI-Compatible — " .. current.openaiCompatibleModel
elseif current.provider == "ollama" then
    providerLabel = "Ollama — " .. current.model
else
    -- Explicit error: unknown provider
    providerLabel = "Unknown Provider — " .. tostring(current.provider)
end
props.providerInfo = providerLabel
```

### Modification 3: CLAUDE.md documentation

**File**: `CLAUDE.md`
**Location**: After "Architecture" section

**Add new section**:
```markdown
## Provider Routing

The plugin uses explicit provider routing with **no silent fallback**:

- **Explicit routing**: `AIEngine.queryBatch()` and `AIEngine.queryText()` route directly to the configured provider
- **No fallback on failure**: If a cloud provider API call fails, the operation stops with an error — it never falls back to Ollama or any other provider
- **Unknown provider handling**: If `prefs.provider` is not a recognized value, returns explicit error instead of defaulting to Ollama
- **API key validation**: Cloud providers require API keys to be configured; execution stops if missing
- **Default provider**: New installations default to "ollama" in `Prefs.lua`, but this is only the initial default — once a cloud provider is configured, it is used exclusively

**Supported providers:**
- `ollama` — Local Ollama instance
- `claude` — Anthropic Claude API
- `openai` — OpenAI API
- `gemini` — Google Gemini API
- `openai-compatible` — Any OpenAI-compatible endpoint (LM Studio, DeepSeek, etc.)

**Key files:**
- `AIEngine.lua` lines 1912-1936: `queryBatch()` routing
- `AIEngine.lua` lines 2278-2295: `queryText()` routing
- `ScorePhotos.lua` lines 225-252: `getProviderInfo()` with explicit provider handling
- `ScoreAndSelect.lua` lines 65-82: Provider display logic
- `Prefs.lua` line 14: Default provider setting

**Design rationale:** Users configure a specific provider because they want predictable behavior and cost control. Silent fallback would violate that expectation — if Claude is configured and fails, the user needs to know it failed, not have it silently switch to Ollama.
```

## Testing Plan

1. **Test openai-compatible provider**:
   - Configure `provider = "openai-compatible"` with valid settings
   - Run scoring on test photos
   - Verify UI displays "OpenAI-Compatible — <model>"
   - Verify API calls use openai-compatible endpoint, not Ollama

2. **Test unknown provider**:
   - Manually set `provider = "unknown"` in preferences
   - Run scoring
   - Verify error dialog appears with clear message
   - Verify no fallback to Ollama occurs

3. **Test existing providers**:
   - Test each provider (ollama, claude, openai, gemini) still works
   - Verify correct model name and label display

## Success Criteria

- [ ] No implicit fallback to Ollama when `provider = "openai-compatible"`
- [ ] UI correctly displays "OpenAI-Compatible" label
- [ ] Unknown providers show explicit error, not silent fallback
- [ ] All existing providers continue to work correctly
- [ ] CLAUDE.md documents the no-fallback guarantee

## Implementation Notes

**Why:**
- User observed actual fallback behavior with openai-compatible provider
- Need to ensure predictable behavior for cost control and user expectations

**How to apply:**
- This design will be implemented via the writing-plans skill
- Changes are localized to two files plus documentation
- No breaking changes to existing functionality
