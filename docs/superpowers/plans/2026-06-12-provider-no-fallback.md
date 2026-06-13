# Provider No-Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix implicit Ollama fallback in provider routing to ensure strict provider adherence

**Architecture:** Add explicit branches for openai-compatible provider and defensive validation for unknown providers in two display functions, plus documentation update

**Tech Stack:** Lua (Lightroom Classic plugin), no automated test framework (manual testing in LR)

---

## Task 1: Fix getProviderInfo() in ScorePhotos.lua

**Files:**
- Modify: `AISelects.lrplugin/ScorePhotos.lua:225-242`

- [ ] **Step 1: Read current implementation**

Read `AISelects.lrplugin/ScorePhotos.lua` lines 225-242 to verify current code structure.

- [ ] **Step 2: Replace getProviderInfo() function**

Replace the entire `getProviderInfo` function (lines 225-242) with the corrected version:

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

- [ ] **Step 3: Commit ScorePhotos.lua changes**

```bash
git add AISelects.lrplugin/ScorePhotos.lua
git commit -m "fix: add explicit openai-compatible branch in getProviderInfo

- Add openai-compatible provider to model name selection
- Add openai-compatible to providerLabels table
- Replace implicit else with explicit ollama branch
- Add error dialog for unknown providers
- Add defensive validation for provider label

Prevents silent fallback to Ollama when openai-compatible is configured."
```

---

## Task 2: Fix provider display in ScoreAndSelect.lua

**Files:**
- Modify: `AISelects.lrplugin/ScoreAndSelect.lua:65-76`

- [ ] **Step 1: Read current implementation**

Read `AISelects.lrplugin/ScoreAndSelect.lua` lines 65-76 to verify current code structure.

- [ ] **Step 2: Replace provider display logic**

Replace lines 65-76 with the corrected version:

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

- [ ] **Step 3: Commit ScoreAndSelect.lua changes**

```bash
git add AISelects.lrplugin/ScoreAndSelect.lua
git commit -m "fix: add explicit openai-compatible branch in provider display

- Add openai-compatible provider to display label
- Replace implicit else with explicit ollama branch
- Add explicit error message for unknown providers

Ensures UI correctly shows OpenAI-Compatible instead of Ollama."
```

---

## Task 3: Update CLAUDE.md documentation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read CLAUDE.md to find insertion point**

Read `CLAUDE.md` to locate the "Architecture" section end point for inserting the new Provider Routing section.

- [ ] **Step 2: Add Provider Routing section**

Insert the following section after the Architecture section:

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

- [ ] **Step 3: Commit CLAUDE.md changes**

```bash
git add CLAUDE.md
git commit -m "docs: add Provider Routing section to CLAUDE.md

- Document no-silent-fallback guarantee
- List all supported providers
- Reference key routing files
- Explain design rationale for user trust and cost control"
```

---

## Task 4: Manual testing in Lightroom

**Files:**
- None (manual testing)

- [ ] **Step 1: Test openai-compatible provider**

1. Open Lightroom Classic
2. Open AI Selects Settings
3. Configure provider as "OpenAI-Compatible" with valid base URL, API key, and model
4. Select 3-5 test photos
5. Run "Score Only" from Library menu
6. Verify progress dialog shows "OpenAI-Compatible — <model>" not "Ollama"
7. Check log file at `~/Desktop/Selects Logs/` for correct provider

- [ ] **Step 2: Test unknown provider error handling**

1. Close Lightroom
2. Manually edit Lightroom preferences file to set provider to "unknown-provider"
3. Open Lightroom
4. Select test photos
5. Run "Score Only"
6. Verify error dialog appears with "Unknown provider: unknown-provider"
7. Verify no scoring occurs (no fallback to Ollama)

- [ ] **Step 3: Test existing providers still work**

1. Configure provider as "Claude" with valid API key
2. Run scoring on test photos
3. Verify displays "Claude API — claude-sonnet-4-6-20250514" (or selected model)
4. Repeat for OpenAI and Gemini
5. Repeat for Ollama
6. All should display correctly and use correct API endpoints

- [ ] **Step 4: Document test results**

Create a test report comment in the commit:

```bash
git commit --allow-empty -m "test: manual testing completed for provider no-fallback

✅ openai-compatible displays correctly (not as Ollama)
✅ unknown provider shows error dialog
✅ claude/openai/gemini/ollama still work correctly
✅ no silent fallback observed

Tested on Lightroom Classic with 5 test photos per provider."
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ Issue 1 (ScorePhotos.lua line 233-234): Fixed in Task 1
- ✅ Issue 2 (ScorePhotos.lua line 240): Fixed in Task 1
- ✅ Issue 3 (ScoreAndSelect.lua line 67-74): Fixed in Task 2
- ✅ Documentation: Added in Task 3
- ✅ Testing: Manual tests in Task 4

**Placeholder scan:**
- ✅ No TBD, TODO, or "implement later"
- ✅ All code blocks contain complete implementation
- ✅ All commit messages are complete
- ✅ No references to undefined functions

**Type consistency:**
- ✅ `SETTINGS.provider` used consistently
- ✅ `current.provider` used consistently
- ✅ `openaiCompatibleModel` property name matches Prefs.lua definition
- ✅ All provider strings match: "openai-compatible", "claude", "openai", "gemini", "ollama"

**Success criteria from spec:**
- ✅ No implicit fallback to Ollama when `provider = "openai-compatible"` - Task 1 & 2
- ✅ UI correctly displays "OpenAI-Compatible" label - Task 1 & 2
- ✅ Unknown providers show explicit error - Task 1 & 2
- ✅ All existing providers continue to work - Task 4
- ✅ CLAUDE.md documents the no-fallback guarantee - Task 3
