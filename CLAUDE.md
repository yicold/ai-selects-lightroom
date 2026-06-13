# AI Selects — Project Context

## What This Is

A Lightroom Classic plugin (Lua) that uses AI vision models to score and select photos. Multi-pass architecture: AI scoring → three-layer dedup → story assembly → beat casting → review. Supports Claude, OpenAI, Gemini, and Ollama. Cross-platform: macOS and Windows.

## Architecture

```
Score (AI vision) → Reject → Burst Dedup → Phash Dedup → MODE SWITCH:
  ├─ Best Of: Content Dedup → Temporal Distribution → Category Distribution → Face Coverage → Collection
  └─ Story v3:
       Scene Inventory (text AI — clusters photos into WHO+WHEN+WHAT moments)
       → Story Assembly (text AI — plans beats from inventory)
       → Candidate Ranking (text AI — ranks candidates per beat)
       → Beat Casting (vision AI — picks best photo per beat, scarcity-first order)
       → Similarity Gate (phash — catches near-duplicate selections)
       → Story Review (vision AI — coherence check + gap detection)
       → Swap Resolution (vision AI — fixes flagged beats)
       → Face Coverage → Ordered Collection
```

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
- `ScorePhotos.lua` lines 225-261: `getProviderInfo()` with explicit provider handling
- `ScoreAndSelect.lua` lines 65-82: Provider display logic
- `Prefs.lua` line 14: Default provider setting

**Design rationale:** Users configure a specific provider because they want predictable behavior and cost control. Silent fallback would violate that expectation — if Claude is configured and fails, the user needs to know it failed, not have it silently switch to Ollama.

## Key Files

- `AIEngine.lua` — Core AI engine. Scoring prompt, API calls (Ollama, Claude, OpenAI, Gemini), perceptual hashing, face queries, all prompt templates (scoring, scene inventory, story assembly, candidate ranking, beat casting, story review, swap resolution), JSON parsers with `extractJSON` 4-level fallback, partial score recovery. ~3000 lines.
- `SelectPhotos.lua` — Selection pipeline. Both Best Of and Story v3 modes. Shared reject/dedup pipeline, scene inventory, story assembly, scarcity-first beat ordering, image cache, phash similarity gate, face coverage, collection creation. ~2500 lines.
- `ScorePhotos.lua` — Scoring pass. Renders JPEGs, sends to AI, writes metadata, computes perceptual hashes, stop reason detection, partial score recovery from truncated responses. ~770 lines.
- `ScoreAndSelect.lua` — Primary entry point. Run config dialog UI, calls score + select.
- `BatchStrategy.lua` — Provider-specific config (batch sizes, token limits, timeouts). ~290 lines.
- `StoryPresets.lua` — Story mode preset definitions (8 presets).
- `Config.lua` — Settings dialog (provider, model, API key, logging).
- `Prefs.lua` — Default preference values.
- `MetadataDefinition.lua` — 11 custom metadata fields, schemaVersion 4. **Critical: `browsable = true` requires `searchable = true`.**
- `MetadataTagset.lua` — How fields appear in LR's Metadata panel.
- `Platform.lua` — Cross-platform abstraction layer. Detects OS, provides unified interface for platform-specific operations (image processing, HTTP requests, database queries).
- `Info.lua` — Plugin manifest. LrToolkitIdentifier: `io.github.gibbonsr4.ai-selects`.
- `dkjson.lua` — Bundled JSON library (do not modify).
- `Utils/macos/` — macOS-specific shell scripts (image.sh, http.sh, db.sh). Use built-in tools: `sips` for image processing, `curl` for HTTP, `sqlite3` for database queries.
- `Utils/windows/` — Windows-specific PowerShell scripts (image.ps1, http.ps1, db.ps1). Require ImageMagick 7.0+ and sqlite3.

## Provider Notes

- **Claude** (Sonnet 4.6): Most reliable, best quality. ~$0.70 for 68 photos (score + select). No special handling needed.
- **Gemini 2.5 Flash**: 21x cheaper (~$0.03 for 68 photos). Requires `thinkingConfig: {thinkingBudget: 0}` to prevent thinking tokens from consuming output budget. Scores ~0.5 points higher than Claude on average (more generous grader). Rank correlation with Claude: ~0.73.
- **OpenAI**: Works, similar cost to Claude.
- **Ollama**: Local models, no cost but lower quality. No anchor images, no snapshots.

## Gemini 2.5 Gotchas

- **Thinking tokens consume maxOutputTokens**: Gemini 2.5 models think by default. Without `thinkingBudget: 0`, a 4096-token limit may produce only ~500 tokens of actual response. We disable thinking for all structured JSON calls.
- **`thinkingBudget: 0` may not always be honored**: Known Gemini API issue. We set generous synthesis token limits (16384) as insurance, and scale token budgets with photo count.
- **Thought parts in response**: Response parts may include `thought: true` entries. We extract the LAST non-thought text part.

## Cross-Platform Development

- **Platform detection**: `Platform.isWindows()` and `Platform.isMacOS()` detect OS at runtime by checking if plugin path contains backslash (Windows) or forward slash (macOS).
- **Platform-specific scripts**: All external commands go through `Platform.executeCommand()`, which routes to bash scripts on macOS or PowerShell scripts on Windows.
- **Path handling**: Use `Platform.normalizePath()` and `Platform.getPathSeparator()` for cross-platform path operations.
- **Windows requirements**: ImageMagick 7.0+ and sqlite3 must be installed and in PATH. PowerShell execution policy must allow running scripts.
- **Testing on both platforms**: Changes to platform-specific code must be tested on both macOS and Windows.

## Lightroom SDK Gotchas

- **schemaVersion**: Must increment when metadata fields change. If LR shows "error reading schema", check platform-specific log: macOS `~/Library/Application Support/Adobe/Lightroom/lrc_console.log`, Windows `%APPDATA%\Adobe\Lightroom\lrc_console.log`.
- **browsable + searchable**: `browsable = true` silently requires `searchable = true`. The generic error dialog gives no details.
- **No custom sort order via SDK**: Collections support "Custom Order" but there's no API to set it. Photos are added in order; user must select Custom Order sort manually.
- **No Adobe Assisted Culling scores via SDK**: Subject Focus, Eye Focus, Eyes Open are not available.
- **No histogram via SDK**.
- **EXIF data available** via `photo:getRawMetadata()` — ISO, shutter speed, aperture, focal length — but not currently used in scoring.
- **Plugin reload requires LR restart**: Code changes are not picked up until Lightroom Classic is restarted (or plugin is removed and re-added via Plug-in Manager).

## Lua Quirks

- `.` in patterns does NOT match newlines. Use `[\1-\127\128-\255]` for multi-line matching.
- `string.format()` treats `%` as format specifiers. Use `gsub` with `function() return value end` for safe replacement of strings containing special characters (like JSON).
- `ipairs` iterates arrays (sequential numeric keys). `pairs` iterates all keys. `validIds` for story response parsing must be an array, not a set.
- `%b{}` balanced brace matcher is useful for extracting JSON objects from truncated responses.

## Common Operations

- **Score photos**: ScorePhotos.lua renders JPEG via `photo:requestJpegThumbnail()`, base64 encodes, sends to AI, writes scores to plugin metadata. Computes dHash perceptual hash via platform-specific image script (sips on macOS, ImageMagick on Windows).
  - **AI returns per photo**: Technical (1-10), Composition (1-10), Emotion (1-10), Moment (1-10), Content (3-5 word description), Category, Narrative Role, Eye Quality, Reject flag.
  - **Composite score formula**: `technical * (techPct/100) + composition * (1-techPct/100) * 0.4 + emotion * (1-techPct/100) * 0.3 + moment * (1-techPct/100) * 0.3 + eyePenalty`. Default techPct = 40%. Closed/squinting eyes get -1.5 penalty.
- **Story mode v3**: Scene inventory clusters photos by WHO+WHEN+WHAT → story assembly plans beats → candidate ranking + beat casting selects photos → review + swap resolution polishes.
- **Face queries**: Reads LR catalog SQLite database directly via `sqlite3` command. Read-only.
- **Perceptual hash**: Renders 9×8 BMP via `sips`, computes dHash (64-bit fingerprint). Handles both 24-bit and 32-bit BMPs (modern macOS sips produces 32-bit).
- **Image cache**: Vision passes (4, 5, 6) pre-render candidate photos once and reuse cached images across beats. Cleaned up at end of pipeline.

## Key Design Decisions

- **Scarcity-first beat ordering**: Pass 4 processes beats with fewest candidates first, preventing pool depletion where later beats find all candidates used.
- **Scene/Moment Inventory**: Pre-pass clusters photos by WHO (people groups) + WHEN (capture time) + WHAT (activity). Duration-adaptive: handles 1-hour sessions to 5-year compilations.
- **extractJSON 4-level fallback**: Direct parse → fence strip → first-{-to-last-} → first-[-to-last-]. Handles markdown fences, surrounding text, and bare arrays.
- **Partial score recovery**: When JSON is truncated, `recoverPartialScores()` extracts individual complete score objects using Lua's `%b{}` matcher.
- **Stop reason tracking**: All providers return stop/finish reason. Truncation is detected and reported clearly instead of cryptic parse errors.
- **Adaptive token budgets**: Scene inventory and story assembly token limits scale with photo count (base + per-photo multiplier).

## Testing

- Score a small batch (3-5 photos) first when testing new providers or after code changes.
- Check logs at `~/Desktop/Selects Logs/` (macOS) or `%USERPROFILE%\Desktop\Selects Logs\` (Windows).
- Check LR console at platform-specific path (see Lightroom SDK Gotchas).
- Story mode: if AI response parsing fails, it falls back to Best Of with a warning.
- **Always restart LR after code changes** — the plugin code is cached in memory.
- **Windows testing**: Verify ImageMagick and sqlite3 are in PATH. Check PowerShell execution policy allows script execution.
