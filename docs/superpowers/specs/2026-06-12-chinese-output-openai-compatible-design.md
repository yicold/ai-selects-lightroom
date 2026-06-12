# Design: Chinese Output and OpenAI-Compatible API Support

**Date:** 2026-06-12
**Status:** Approved

## Overview

Add two features to AI Selects plugin with minimal code changes and full backwards compatibility.

| Feature | Scope | Approach |
|---------|-------|----------|
| Chinese output | AI scoring responses only | Append language instruction to scoring prompt |
| OpenAI-Compatible API | New provider option | Reuse OpenAI code path with configurable base URL |

**Principles:**
- No changes to existing provider logic (Claude, Gemini, Ollama, OpenAI)
- New preferences default to disabled/empty — existing configs work unchanged
- No refactoring of existing code — only additions

---

## Feature 1: Chinese Output

### Scope
AI scoring responses only (photo scores/ratings like "构图精良，光线充足")

### Implementation

**New preference:** `enableChineseOutput` (boolean, default: `false`)

**Prompt modification:** In `AIEngine.lua`, when building the scoring prompt, append language instruction if enabled:
```
If enableChineseOutput is true:
  Append to scoring prompt: "请使用中文输出评分理由和描述。"
```

**Affected prompts:**
- `buildScoringPrompt()` — the main scoring prompt for photo evaluation
- No changes to scene inventory, story assembly, beat casting, etc.

**Config UI:** Add checkbox in `Config.lua`:
- Label: "使用中文输出评分 (Use Chinese for scoring)"
- Location: General settings section
- Only affects scoring responses

### File Changes
- `Prefs.lua` — add default `enableChineseOutput = false`
- `Config.lua` — add checkbox UI element
- `AIEngine.lua` — conditional prompt suffix in scoring prompt builder

---

## Feature 2: OpenAI-Compatible Provider

### Scope
Support any OpenAI-compatible API endpoint (local models, Chinese providers, custom deployments)

### Implementation

**New preferences:**
- `openaiCompatibleBaseUrl` (string, default: `""`)
- `openaiCompatibleApiKey` (string, default: `""`)
- `openaiCompatibleModel` (string, default: `""`)

**Provider dropdown:** Add "OpenAI-Compatible" as new option in `Config.lua`:
- Existing options: Claude, OpenAI, Gemini, Ollama
- New option: OpenAI-Compatible

**Config UI fields:** When "OpenAI-Compatible" is selected, show:
- Base URL field (e.g., `http://localhost:11434/v1` or `https://api.deepseek.com/v1`)
- API Key field
- Model Name field (e.g., `deepseek-chat`, `qwen2.5:latest`)

**API call logic:** In `AIEngine.lua`:
- Reuse existing `callOpenAI()` function
- When provider is "OpenAI-Compatible", use the custom base URL instead of `api.openai.com`
- Pass the custom model name in the API request

### File Changes
- `Prefs.lua` — add 3 new preference defaults
- `Config.lua` — add dropdown option + 3 input fields
- `AIEngine.lua` — branch in OpenAI code path to use custom endpoint
- `BatchStrategy.lua` — add OpenAI-Compatible to provider strategy map

---

## Error Handling

### Chinese Output
- No special error handling needed — it's just a prompt suffix
- If AI ignores the instruction, response will be in English (acceptable fallback)

### OpenAI-Compatible
- Validate required fields before API call:
  - Base URL: must not be empty, must be valid URL format
  - API Key: must not be empty
  - Model Name: must not be empty
- Connection errors: display clear message with endpoint URL for debugging
- Timeout handling: reuse existing OpenAI timeout settings from `BatchStrategy.lua`

### Validation in Config UI
- When user selects "OpenAI-Compatible" and clicks OK:
  - If any field is empty, show error dialog with specific missing field
  - If base URL doesn't start with `http://` or `https://`, show format error

---

## Testing

### Chinese Output
1. Enable checkbox, score 3-5 photos
2. Verify scoring responses contain Chinese text
3. Disable checkbox, score same photos
4. Verify responses return to English
5. Test with different providers (Claude, OpenAI, Gemini, Ollama)

### OpenAI-Compatible
1. Configure with Ollama local endpoint (`http://localhost:11434/v1`)
2. Score photos, verify API calls hit correct endpoint
3. Configure with Chinese provider (e.g., DeepSeek)
4. Verify model name is passed correctly in request
5. Test error cases: empty fields, invalid URL, wrong API key
6. Verify existing OpenAI config still works unchanged

### Backwards Compatibility
1. Existing configs without new preferences should work unchanged
2. Existing OpenAI, Claude, Gemini, Ollama workflows unchanged
3. No changes to metadata schema or log file locations
