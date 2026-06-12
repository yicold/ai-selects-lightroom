--[[
  Prefs.lua
  ─────────────────────────────────────────────────────────────────────────────
  Pure preferences module — no UI, no side effects.
  Safe to dofile() from ScorePhotos.lua and SelectPhotos.lua.

  The Settings dialog lives in Config.lua and is invoked via the LR menu.
--]]

local LrPrefs = import 'LrPrefs'

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
    -- OpenAI-Compatible
    openaiCompatibleBaseUrl = "",
    openaiCompatibleApiKey  = "",
    openaiCompatibleModel  = "",
    timeoutSecs        = 90,
    -- Selection
    selectionMode      = "bestof",
    targetCount        = 40,
    emphasisSlider     = 50,    -- 0 = full technical, 100 = full creative
    renderSize         = 512,
    burstThresholdSecs = 2,
    skipScored         = false,
    -- Scoring
    nitpickyScale      = "consumer",   -- "consumer", "enthusiast", "professional"
    batchSize          = 0,            -- 0 = auto (provider default), or user override
    enableChineseOutput = false,
    -- Story mode
    storyPreset            = "family_vacation",
    -- Pre-scoring context (all modes)
    preHints           = "",             -- e.g. "this is from 2007", "the man in green is the groom's father"
    -- Story prompt (confirmed by user after Pass 1)
    storyPrompt        = "",             -- user's confirmed story description
    storyEmphasis      = "",             -- optional emphasis ("the speeches were the highlight")
    -- Logging
    enableLogging      = false,
    logFolder          = "",
}

-- Helper: Lua's `cond and valTrue or valFalse` breaks when valTrue is false.
-- Use explicit nil checks for booleans.
local function boolPref(prefs, key)
    if prefs[key] == nil then return DEFAULTS[key] end
    return prefs[key]
end

local function stringPref(prefs, key, allowEmpty)
    if allowEmpty then
        if prefs[key] == nil then return DEFAULTS[key] end
        return prefs[key]
    end
    if prefs[key] ~= nil and prefs[key] ~= "" then return prefs[key] end
    return DEFAULTS[key]
end

local function numPref(prefs, key)
    if prefs[key] ~= nil then return prefs[key] end
    return DEFAULTS[key]
end

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
        openaiCompatibleBaseUrl = stringPref(prefs, "openaiCompatibleBaseUrl", true),
        openaiCompatibleApiKey  = stringPref(prefs, "openaiCompatibleApiKey", true),
        openaiCompatibleModel  = stringPref(prefs, "openaiCompatibleModel", true),
        timeoutSecs        = numPref(prefs, "timeoutSecs"),
        selectionMode      = stringPref(prefs, "selectionMode"),
        targetCount        = numPref(prefs, "targetCount"),
        emphasisSlider     = numPref(prefs, "emphasisSlider"),
        renderSize         = numPref(prefs, "renderSize"),
        burstThresholdSecs = numPref(prefs, "burstThresholdSecs"),
        skipScored         = boolPref(prefs, "skipScored"),
        nitpickyScale      = stringPref(prefs, "nitpickyScale"),
        batchSize          = numPref(prefs, "batchSize"),
        enableChineseOutput = boolPref(prefs, "enableChineseOutput"),
        storyPreset            = stringPref(prefs, "storyPreset"),
        preHints           = stringPref(prefs, "preHints", true),
        storyPrompt        = stringPref(prefs, "storyPrompt", true),
        storyEmphasis      = stringPref(prefs, "storyEmphasis", true),
        enableLogging      = boolPref(prefs, "enableLogging"),
        logFolder          = stringPref(prefs, "logFolder", true),
    }
end

return {
    getPrefs = getPrefs,
    DEFAULTS = DEFAULTS,
}
