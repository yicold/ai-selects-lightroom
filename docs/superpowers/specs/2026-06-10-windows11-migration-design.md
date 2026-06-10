# AI Selects Windows 11 Migration Design

**Date:** 2026-06-10
**Status:** Approved
**Target:** Complete feature parity on Windows 11

---

## Executive Summary

Migrate AI Selects Lightroom plugin from macOS-only to Windows 11 support with complete feature parity. The solution uses PowerShell + ImageMagick, introducing a platform abstraction layer to minimize changes to existing Lua business logic.

---

## Goals and Constraints

### Goals
- Complete feature parity on Windows 11 (scoring, story mode, face detection, all AI providers)
- Maintain macOS compatibility (no regression)
- Manual installation with clear documentation

### Constraints
- Allow external dependencies (ImageMagick, sqlite3)
- Current development environment is Linux
- Windows testing strategy deferred

---

## Architecture

### Platform Abstraction Layer

```
AISelects.lrplugin/
├── [Existing files] - Minimal changes
├── Platform.lua (NEW) - Platform detection and command abstraction
└── Utils/
    ├── macos/ (NEW) - macOS-specific implementations
    │   ├── image.sh
    │   ├── http.sh
    │   └── db.sh
    └── windows/ (NEW) - Windows-specific implementations
        ├── image.ps1
        ├── http.ps1
        └── db.ps1
```

### Workflow

1. Lua code calls `Platform.executeCommand("image", args)`
2. Platform.lua detects current OS
3. Calls corresponding script (.sh or .ps1)
4. Script executes and returns result to Lua

---

## Platform Abstraction Layer Implementation

### Platform.lua Core API

```lua
-- Platform detection
Platform.isWindows = function()
    return package.config:sub(1,1) == '\\'  -- Windows path separator
end

Platform.isMacOS = function()
    return not Platform.isWindows()
end

-- Command execution abstraction
Platform.executeCommand = function(command, args)
    local scriptExt = Platform.isWindows() and ".ps1" or ".sh"
    local scriptDir = Platform.isWindows() and "windows" or "macos"
    local scriptPath = pluginPath .. "/Utils/" .. scriptDir .. "/" .. command .. scriptExt

    if Platform.isWindows() then
        return Platform.executePowerShell(scriptPath, args)
    else
        return Platform.executeBash(scriptPath, args)
    end
end
```

### Command Mapping

| Command | macOS | Windows | Purpose |
|---------|-------|---------|---------|
| `image.resize` | sips | ImageMagick | Resize image |
| `image.convert` | sips | ImageMagick | Format conversion |
| `http.post` | curl | curl.exe / Invoke-WebRequest | API calls |
| `db.query` | sqlite3 | sqlite3.exe | Database queries |
| `file.hash` | shasum | PowerShell Get-FileHash | File hashing |

### Error Handling

- Unified return format: `{ success = bool, output = string, error = string }`
- Script failures captured and logged to Lightroom log

---

## Windows Dependencies

### Required Tools

| Tool | Version | Installation | Purpose |
|------|---------|--------------|---------|
| ImageMagick | 7.0+ | Official .exe installer | Image processing |
| sqlite3.exe | 3.35+ | SQLite website download | Database queries |
| curl.exe | Built-in | Windows 10/11 built-in | HTTP requests |
| PowerShell | 5.1+ | Windows built-in | Script execution |

---

## Windows Scripts Implementation

### image.ps1

```powershell
param($action, $inputPath, $outputPath, $width, $height)

if ($action -eq "resize") {
    & magick convert $inputPath -resize "${width}x${height}" $outputPath
}
elseif ($action -eq "convert") {
    & magick convert $inputPath $outputPath
}
```

### http.ps1

```powershell
param($url, $headers, $body, $outputFile)

$headersJson = $headers | ConvertFrom-Json
$bodyJson = $body | ConvertFrom-Json

Invoke-RestMethod -Uri $url -Method Post `
    -Headers $headersJson -Body $bodyJson `
    -OutFile $outputFile
```

### db.ps1

```powershell
param($dbPath, $query, $outputFile)

$results = & sqlite3.exe $dbPath "$query"
$results | Out-File -Encoding UTF8 $outputFile
```

### Path Handling

- macOS: `/` separator
- Windows: `\` separator, requires escaping or `Join-Path`
- Platform.lua handles path conversion uniformly

---

## Lua Code Modifications

### Files to Modify

**1. AIEngine.lua** - API calls
- Current: Direct `curl` commands
- Change: `Platform.executeCommand("http", args)`
- Impact: ~15-20 call sites

**2. ScorePhotos.lua** - Image processing
- Current: `sips` for resize and format conversion
- Change: `Platform.executeCommand("image", args)`
- Impact: ~5-8 call sites

**3. SelectPhotos.lua** - Database queries
- Current: Direct `sqlite3` queries
- Change: `Platform.executeCommand("db", args)`
- Impact: ~10-15 call sites

**4. Config.lua** - Configuration UI
- Add: Windows dependency detection and prompts
- Add: Dependency path configuration (ImageMagick, sqlite3)

### Modification Strategy

- "Find and replace" pattern, preserve business logic
- Add comment markers: `-- [Windows] Replaced direct call with Platform abstraction`
- Maintain backward compatibility: macOS behavior unchanged

---

## Installation Documentation

### Structure

```
docs/
└── WINDOWS_INSTALL.md
    ├── Prerequisites
    ├── Dependency Installation
    ├── Plugin Installation
    ├── Configuration Verification
    └── Troubleshooting
```

### Installation Steps

**Step 1: Prerequisites**
- Windows 11 (64-bit)
- Adobe Lightroom Classic CC 2019 or later
- PowerShell 5.1+ (built-in)

**Step 2: Dependency Installation**

1. ImageMagick
   - Download: https://imagemagick.org/script/download.php#windows
   - Check "Install legacy utilities (e.g. convert)"
   - Verify: `magick --version`

2. SQLite3
   - Download: https://www.sqlite.org/download.html
   - Extract to `C:\Tools\sqlite3\` or custom path
   - Verify: `sqlite3 --version`

**Step 3: Plugin Installation**
1. Download `AISelects.lrplugin` folder
2. Lightroom: File → Plug-in Manager → Add Plug-in
3. Select `AISelects.lrplugin` folder

**Step 4: Configuration Verification**
- Open plugin settings → Settings
- Click "Verify Dependencies" button
- Confirm all dependencies show green ✓

### Troubleshooting

- ImageMagick not found: Check PATH environment variable
- sqlite3 not found: Configure custom path in plugin settings
- PowerShell execution policy: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

---

## Testing Strategy

### Linux Environment Testing

- PowerShell script syntax check: `pwsh -File script.ps1`
- Script logic validation: Use Linux ImageMagick and sqlite3
- Lua code static analysis: Syntax validation, platform abstraction logic check

### Windows Testing

- Deferred: No Windows testing strategy defined at this time

---

## Risks and Limitations

### Technical Risks

**1. PowerShell Execution Policy**
- Risk: Windows may block unsigned scripts by default
- Mitigation: Provide execution policy command in installation docs
- Impact: Users may encounter script execution failures on first use

**2. Path Handling Differences**
- Risk: Spaces and special characters in Windows paths
- Mitigation: Platform.lua handles path escaping, PowerShell uses quotes
- Impact: May cause file path errors

**3. ImageMagick Command Differences**
- Risk: ImageMagick 7.x syntax differs from older versions (`magick convert` vs `convert`)
- Mitigation: Document requires ImageMagick 7.0+, scripts use new syntax
- Impact: Users with old versions will encounter command failures

**4. Performance Differences**
- Risk: PowerShell startup slower than bash, may affect batch processing
- Mitigation: Use PowerShell batch mode, reduce startup frequency
- Impact: Windows processing may be slightly slower than macOS

### Known Limitations

**1. Dependency Installation Barrier**
- Limitation: Users must manually install ImageMagick and sqlite3
- Impact: Non-technical users may find installation complex
- Future: Consider one-click installer or packaging

**2. Feature Parity**
- Limitation: Some macOS-specific features may not be fully equivalent (e.g., certain sips metadata operations)
- Impact: Very few edge features may differ
- Mitigation: Document differences, provide alternatives

**3. Long-term Maintenance**
- Limitation: Must maintain both macOS and Windows scripts
- Impact: Increased maintenance cost
- Mitigation: Keep scripts simple, add detailed comments

---

## Implementation Plan

### Phase 1: Infrastructure Setup (2-3 days)

- Create `Platform.lua` platform abstraction layer
- Create `Utils/macos/` and `Utils/windows/` directory structure
- Implement macOS script wrappers (encapsulate existing commands)
- Implement Windows scripts (PowerShell versions)

### Phase 2: Core Code Migration (3-5 days)

- Modify `AIEngine.lua` - HTTP call migration
- Modify `ScorePhotos.lua` - Image processing migration
- Modify `SelectPhotos.lua` - Database query migration
- Modify `Config.lua` - Add Windows configuration and dependency detection

### Phase 3: Documentation and Installation Support (1-2 days)

- Write `WINDOWS_INSTALL.md` installation documentation
- Update `README.md` to add Windows support notes
- Write dependency detection and verification logic

### Phase 4: Validation and Optimization (2-3 days)

- Script syntax validation in Linux environment
- PowerShell script logic validation
- Code review and optimization
- Documentation refinement

**Total Estimated Time: 8-13 days**

### Key Milestones

1. Platform abstraction layer complete and testable
2. Core functionality migration complete
3. Installation documentation complete
4. Code review passed

### Parallel Work Opportunities

- Phase 1 and Phase 3 documentation work can run in parallel
- Phase 2 file modifications can run in parallel (different developers)

---

## Success Criteria

- All features work identically on Windows 11
- macOS functionality unchanged (no regression)
- Installation documentation enables users to self-serve
- Code maintainable with clear platform separation
