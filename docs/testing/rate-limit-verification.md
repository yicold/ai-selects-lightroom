# Rate Limit Implementation Verification

## Verification Date
2026-06-13

## Modified Files

| File | Change Type | Description |
|------|-------------|-------------|
| `BatchStrategy.lua` | Modified | Added `requestDelay` config for `openai-compatible` provider and `getRequestDelay()` function |
| `AIEngine.lua` | Modified | Added rate limit delay in `queryBatch()` and `queryText()` dispatchers |

## New Configuration Item

```lua
-- BatchStrategy.lua, line 54-56
["openai-compatible"] = {
    -- ... other config ...
    requestDelay = 1.5,  -- Rate limit: 40 RPM = 1.5s between requests
}
```

**Value**: `1.5` seconds between API calls
**Rationale**: 40 requests per minute = 1.5 seconds per request

## New Function

### `BatchStrategy.getRequestDelay(provider)`

**Location**: `BatchStrategy.lua`, lines 94-101

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

## Affected Code Paths

### 1. `AIEngine.queryBatch()` (line 1916-1920)
```lua
-- 速率限制：在API调用前等待
local delay = BatchStrategy.getRequestDelay(provider)
if delay > 0 then
    LrTasks.sleep(delay)
end
```

### 2. `AIEngine.queryText()` (line 2288-2292)
```lua
-- 速率限制：在API调用前等待
local delay = BatchStrategy.getRequestDelay(provider)
if delay > 0 then
    LrTasks.sleep(delay)
end
```

## Provider Configuration Summary

| Provider | `requestDelay` Value | Affected |
|----------|---------------------|----------|
| `ollama` | Not set (defaults to 0) | No |
| `claude` | Not set (defaults to 0) | No |
| `openai` | Not set (defaults to 0) | No |
| `gemini` | Not set (defaults to 0) | No |
| `openai-compatible` | `1.5` | **Yes** |

## Expected Behavior Change

- **Before**: All API calls were made immediately without delay
- **After**: `openai-compatible` provider calls are delayed by 1.5 seconds between each request
- **Impact**: Limits API calls to ~40 RPM for rate-limited endpoints

## Other `LrTasks.sleep()` Usages

| File | Line | Value | Purpose |
|------|------|-------|---------|
| `ScorePhotos.lua` | 737 | `0.05` | Small delay between batch iterations (unrelated to rate limiting) |
| `Config.lua` | 322 | `3.0` | UI dialog delay (unrelated to rate limiting) |

## Verification Checklist

- [x] `requestDelay` only appears in `BatchStrategy.lua` (provider config) and `AIEngine.lua` (usage)
- [x] `getRequestDelay()` function defined and returns correct value (1.5 for openai-compatible, 0 otherwise)
- [x] Rate limiting applied in both `queryBatch()` and `queryText()` dispatchers
- [x] `ollama` provider: no `requestDelay` field, unaffected
- [x] `claude` provider: no `requestDelay` field, unaffected
- [x] `openai` provider: no `requestDelay` field, unaffected
- [x] `gemini` provider: no `requestDelay` field, unaffected
- [x] `LrTasks.sleep` only used for rate limiting in AI engine dispatchers

## Result

**PASS** - All verification checks passed. The rate limit implementation is correct:
- Only `openai-compatible` provider has rate limiting configured
- Both batch and text query paths apply the delay
- Other providers are unaffected by this change
