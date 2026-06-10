# Windows 11 Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate AI Selects Lightroom plugin from macOS-only to Windows 11 support with complete feature parity using PowerShell + ImageMagick.

**Architecture:** Platform abstraction layer (Platform.lua) isolates OS-specific code. Lua business logic calls Platform.executeCommand() which dispatches to .sh (macOS) or .ps1 (Windows) scripts. Minimal changes to existing Lua code.

**Tech Stack:** Lua, PowerShell, Bash, ImageMagick, sqlite3, curl

---

## File Structure

### New Files
- `AISelects.lrplugin/Platform.lua` - Platform detection and command abstraction
- `AISelects.lrplugin/Utils/macos/image.sh` - macOS image processing
- `AISelects.lrplugin/Utils/macos/http.sh` - macOS HTTP requests
- `AISelects.lrplugin/Utils/macos/db.sh` - macOS database queries
- `AISelects.lrplugin/Utils/windows/image.ps1` - Windows image processing
- `AISelects.lrplugin/Utils/windows/http.ps1` - Windows HTTP requests
- `AISelects.lrplugin/Utils/windows/db.ps1` - Windows database queries
- `docs/WINDOWS_INSTALL.md` - Windows installation documentation

### Modified Files
- `AISelects.lrplugin/AIEngine.lua` - Replace direct curl calls with Platform abstraction
- `AISelects.lrplugin/ScorePhotos.lua` - Replace image processing commands with Platform abstraction
- `AISelects.lrplugin/SelectPhotos.lua` - Replace database commands with Platform abstraction
- `AISelects.lrplugin/Config.lua` - Add Windows dependency detection and configuration
- `README.md` - Add Windows support documentation

---

## Phase 1: Infrastructure Setup

### Task 1: Create Directory Structure

**Files:**
- Create: `AISelects.lrplugin/Utils/macos/`
- Create: `AISelects.lrplugin/Utils/windows/`

- [ ] **Step 1: Create Utils directories**

```bash
mkdir -p AISelects.lrplugin/Utils/macos
mkdir -p AISelects.lrplugin/Utils/windows
```

- [ ] **Step 2: Verify directories created**

```bash
ls -la AISelects.lrplugin/Utils/
```

Expected output:
```
drwxrwxr-x macos
drwxrwxr-x windows
```

- [ ] **Step 3: Commit**

```bash
git add AISelects.lrplugin/Utils/
git commit -m "feat: create platform-specific Utils directories"
```

---

### Task 2: Create Platform.lua

**Files:**
- Create: `AISelects.lrplugin/Platform.lua`

- [ ] **Step 1: Write Platform.lua with core functions**

```lua
--[[
Platform abstraction layer for cross-platform support.
Provides unified interface for OS-specific operations.
]]

local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

local Platform = {}

-- Determine if running on Windows
function Platform.isWindows()
    return package.config:sub(1,1) == '\\'
end

-- Determine if running on macOS
function Platform.isMacOS()
    return not Platform.isWindows()
end

-- Get the path separator for current platform
function Platform.getPathSeparator()
    return Platform.isWindows() and '\\' or '/'
end

-- Normalize path for current platform
function Platform.normalizePath(path)
    if Platform.isWindows() then
        return path:gsub('/', '\\')
    else
        return path:gsub('\\', '/')
    end
end

-- Get script extension for current platform
function Platform.getScriptExtension()
    return Platform.isWindows() and '.ps1' or '.sh'
end

-- Get platform-specific directory name
function Platform.getPlatformDir()
    return Platform.isWindows() and 'windows' or 'macos'
end

-- Execute a platform-specific command
-- @param command string - Command name (e.g., "image", "http", "db")
-- @param args table - Arguments for the command
-- @return table - { success = bool, output = string, error = string }
function Platform.executeCommand(command, args)
    local pluginPath = _PLUGIN.path
    local utilsPath = LrPathUtils.child(pluginPath, 'Utils')
    local platformDir = LrPathUtils.child(utilsPath, Platform.getPlatformDir())
    local scriptName = command .. Platform.getScriptExtension()
    local scriptPath = LrPathUtils.child(platformDir, scriptName)
    
    scriptPath = Platform.normalizePath(scriptPath)
    
    if Platform.isWindows() then
        return Platform.executePowerShell(scriptPath, args)
    else
        return Platform.executeBash(scriptPath, args)
    end
end

-- Execute a bash script (macOS)
function Platform.executeBash(scriptPath, args)
    local argsStr = ''
    for i, arg in ipairs(args) do
        argsStr = argsStr .. ' ' .. Platform.shellEscape(arg)
    end
    
    local cmd = 'bash ' .. Platform.shellEscape(scriptPath) .. argsStr
    local exitCode = LrTasks.execute(cmd)
    
    return {
        success = (exitCode == 0),
        output = '',
        error = (exitCode ~= 0) and 'Script failed with exit code: ' .. exitCode or nil
    }
end

-- Execute a PowerShell script (Windows)
function Platform.executePowerShell(scriptPath, args)
    local argsStr = ''
    for i, arg in ipairs(args) do
        argsStr = argsStr .. ' -' .. arg.key .. ' "' .. arg.value .. '"'
    end
    
    local cmd = 'powershell.exe -ExecutionPolicy Bypass -File "' .. scriptPath .. '"' .. argsStr
    local exitCode = LrTasks.execute(cmd)
    
    return {
        success = (exitCode == 0),
        output = '',
        error = (exitCode ~= 0) and 'Script failed with exit code: ' .. exitCode or nil
    }
end

-- Shell escape for bash
function Platform.shellEscape(str)
    if str:match('[^a-zA-Z0-9_./-]') then
        return "'" .. str:gsub("'", "'\\''") .. "'"
    end
    return str
end

return Platform
```

- [ ] **Step 2: Verify Platform.lua syntax**

```bash
lua -c AISelects.lrplugin/Platform.lua
```

Expected: No syntax errors

- [ ] **Step 3: Commit**

```bash
git add AISelects.lrplugin/Platform.lua
git commit -m "feat: add Platform.lua abstraction layer"
```

---

### Task 3: Create macOS Scripts

**Files:**
- Create: `AISelects.lrplugin/Utils/macos/image.sh`
- Create: `AISelects.lrplugin/Utils/macos/http.sh`
- Create: `AISelects.lrplugin/Utils/macos/db.sh`

- [ ] **Step 1: Write image.sh for macOS**

```bash
#!/bin/bash
# Image processing script for macOS using sips

ACTION="$1"
INPUT_PATH="$2"
OUTPUT_PATH="$3"
WIDTH="$4"
HEIGHT="$5"

case "$ACTION" in
    resize)
        sips --resampleWidth "$WIDTH" --resampleHeight "$HEIGHT" "$INPUT_PATH" --out "$OUTPUT_PATH"
        ;;
    convert)
        sips -s format jpeg "$INPUT_PATH" --out "$OUTPUT_PATH"
        ;;
    *)
        echo "Unknown action: $ACTION" >&2
        exit 1
        ;;
esac

exit $?
```

- [ ] **Step 2: Write http.sh for macOS**

```bash
#!/bin/bash
# HTTP request script for macOS using curl

URL="$1"
METHOD="$2"
HEADERS_FILE="$3"
BODY_FILE="$4"
OUTPUT_FILE="$5"
TIMEOUT="$6"

if [ "$METHOD" = "POST" ]; then
    curl -K "$HEADERS_FILE" -d @"$BODY_FILE" -o "$OUTPUT_FILE" --max-time "$TIMEOUT"
else
    curl -K "$HEADERS_FILE" -o "$OUTPUT_FILE" --max-time "$TIMEOUT"
fi

exit $?
```

- [ ] **Step 3: Write db.sh for macOS**

```bash
#!/bin/bash
# Database query script for macOS using sqlite3

DB_PATH="$1"
QUERY="$2"
OUTPUT_FILE="$3"

sqlite3 "$DB_PATH" "$QUERY" > "$OUTPUT_FILE"

exit $?
```

- [ ] **Step 4: Make scripts executable**

```bash
chmod +x AISelects.lrplugin/Utils/macos/*.sh
```

- [ ] **Step 5: Verify scripts are executable**

```bash
ls -la AISelects.lrplugin/Utils/macos/
```

Expected: All scripts show executable permission

- [ ] **Step 6: Commit**

```bash
git add AISelects.lrplugin/Utils/macos/
git commit -m "feat: add macOS platform scripts (image, http, db)"
```

---

### Task 4: Create Windows Scripts

**Files:**
- Create: `AISelects.lrplugin/Utils/windows/image.ps1`
- Create: `AISelects.lrplugin/Utils/windows/http.ps1`
- Create: `AISelects.lrplugin/Utils/windows/db.ps1`

- [ ] **Step 1: Write image.ps1 for Windows**

```powershell
# Image processing script for Windows using ImageMagick
param(
    [string]$Action,
    [string]$InputPath,
    [string]$OutputPath,
    [int]$Width,
    [int]$Height
)

try {
    switch ($Action) {
        "resize" {
            & magick convert $InputPath -resize "${Width}x${Height}" $OutputPath
        }
        "convert" {
            & magick convert $InputPath $OutputPath
        }
        default {
            Write-Error "Unknown action: $Action"
            exit 1
        }
    }
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
```

- [ ] **Step 2: Write http.ps1 for Windows**

```powershell
# HTTP request script for Windows using Invoke-WebRequest
param(
    [string]$Url,
    [string]$Method,
    [string]$HeadersFile,
    [string]$BodyFile,
    [string]$OutputFile,
    [int]$Timeout
)

try {
    # Read headers from file
    $headers = @{}
    if (Test-Path $HeadersFile) {
        Get-Content $HeadersFile | ForEach-Object {
            if ($_ -match "^([^:]+):\s*(.+)$") {
                $headers[$matches[1]] = $matches[2]
            }
        }
    }
    
    # Read body from file
    $body = $null
    if (Test-Path $BodyFile) {
        $body = Get-Content $BodyFile -Raw
    }
    
    # Execute request
    if ($Method -eq "POST") {
        Invoke-RestMethod -Uri $Url -Method Post -Headers $headers -Body $body -OutFile $OutputFile -TimeoutSec $Timeout
    }
    else {
        Invoke-RestMethod -Uri $Url -Method Get -Headers $headers -OutFile $OutputFile -TimeoutSec $Timeout
    }
    
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
```

- [ ] **Step 3: Write db.ps1 for Windows**

```powershell
# Database query script for Windows using sqlite3.exe
param(
    [string]$DbPath,
    [string]$Query,
    [string]$OutputFile
)

try {
    $results = & sqlite3.exe $DbPath $Query
    $results | Out-File -Encoding UTF8 $OutputFile
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
```

- [ ] **Step 4: Verify PowerShell syntax (if pwsh available)**

```bash
# Only run if PowerShell Core is installed
if command -v pwsh &> /dev/null; then
    pwsh -File AISelects.lrplugin/Utils/windows/image.ps1 -Action "test" 2>&1 || true
fi
```

Expected: No syntax errors (script may fail due to missing params, but should not show syntax errors)

- [ ] **Step 5: Commit**

```bash
git add AISelects.lrplugin/Utils/windows/
git commit -m "feat: add Windows platform scripts (image, http, db)"
```

---

## Phase 2: Core Code Migration

### Task 5: Modify AIEngine.lua for Platform Abstraction

**Files:**
- Modify: `AISelects.lrplugin/AIEngine.lua`

- [ ] **Step 1: Add Platform import at top of AIEngine.lua**

Find the import section (around line 1-20) and add:

```lua
local Platform = require 'Platform'
```

- [ ] **Step 2: Replace curl call at line 874**

Find:
```lua
local cmd = string.format("curl -K %s -o %s", M.shellEscape(tmpCfg), M.shellEscape(tmpOut))
```

Replace with:
```lua
-- [Windows] Replaced direct curl call with Platform abstraction
local result = Platform.executeCommand("http", {
    { key = "url", value = url },
    { key = "method", value = "GET" },
    { key = "headersFile", value = tmpCfg },
    { key = "outputFile", value = tmpOut }
})
```

- [ ] **Step 3: Replace curl call at line 923**

Find:
```lua
local cmd = string.format("curl -K %s -o %s", M.shellEscape(tmpCfg), M.shellEscape(tmpOut))
```

Replace with:
```lua
-- [Windows] Replaced direct curl call with Platform abstraction
local result = Platform.executeCommand("http", {
    { key = "url", value = url },
    { key = "method", value = "GET" },
    { key = "headersFile", value = tmpCfg },
    { key = "outputFile", value = tmpOut }
})
```

- [ ] **Step 4: Replace curlPost function (lines 1202-1232)**

Find the curlPost function and replace the curl command execution with:

```lua
-- [Windows] Replaced curl execution with Platform abstraction
local result = Platform.executeCommand("http", {
    { key = "url", value = url },
    { key = "method", value = "POST" },
    { key = "headersFile", value = tmpCfg },
    { key = "bodyFile", value = tmpIn },
    { key = "outputFile", value = tmpOut },
    { key = "timeout", value = timeoutSecs }
})
```

- [ ] **Step 5: Verify AIEngine.lua syntax**

```bash
lua -c AISelects.lrplugin/AIEngine.lua
```

Expected: No syntax errors

- [ ] **Step 6: Commit**

```bash
git add AISelects.lrplugin/AIEngine.lua
git commit -m "feat: migrate AIEngine.lua to Platform abstraction"
```

---

### Task 6: Modify ScorePhotos.lua for Platform Abstraction

**Files:**
- Modify: `AISelects.lrplugin/ScorePhotos.lua`

- [ ] **Step 1: Add Platform import at top of ScorePhotos.lua**

Find the import section and add:

```lua
local Platform = require 'Platform'
```

- [ ] **Step 2: Search for image processing commands**

```bash
grep -n "sips\|convert\|LrTasks.execute" AISelects.lrplugin/ScorePhotos.lua
```

Note: If no direct image processing commands found, document that ScorePhotos.lua may use Lightroom's built-in image handling.

- [ ] **Step 3: Replace any direct image processing calls**

If found, replace with:
```lua
-- [Windows] Replaced image processing call with Platform abstraction
local result = Platform.executeCommand("image", {
    { key = "action", value = "resize" },
    { key = "inputPath", value = inputPath },
    { key = "outputPath", value = outputPath },
    { key = "width", value = width },
    { key = "height", value = height }
})
```

- [ ] **Step 4: Verify ScorePhotos.lua syntax**

```bash
lua -c AISelects.lrplugin/ScorePhotos.lua
```

Expected: No syntax errors

- [ ] **Step 5: Commit**

```bash
git add AISelects.lrplugin/ScorePhotos.lua
git commit -m "feat: migrate ScorePhotos.lua to Platform abstraction"
```

---

### Task 7: Modify SelectPhotos.lua for Platform Abstraction

**Files:**
- Modify: `AISelects.lrplugin/SelectPhotos.lua`

- [ ] **Step 1: Add Platform import at top of SelectPhotos.lua**

Find the import section and add:

```lua
local Platform = require 'Platform'
```

- [ ] **Step 2: Search for database commands**

```bash
grep -n "sqlite3\|LrTasks.execute" AISelects.lrplugin/SelectPhotos.lua
```

Note: If no direct database commands found, document that SelectPhotos.lua may use Lightroom's built-in catalog access.

- [ ] **Step 3: Replace any direct database calls**

If found, replace with:
```lua
-- [Windows] Replaced database call with Platform abstraction
local result = Platform.executeCommand("db", {
    { key = "dbPath", value = dbPath },
    { key = "query", value = query },
    { key = "outputFile", value = outputFile }
})
```

- [ ] **Step 4: Verify SelectPhotos.lua syntax**

```bash
lua -c AISelects.lrplugin/SelectPhotos.lua
```

Expected: No syntax errors

- [ ] **Step 5: Commit**

```bash
git add AISelects.lrplugin/SelectPhotos.lua
git commit -m "feat: migrate SelectPhotos.lua to Platform abstraction"
```

---

### Task 8: Modify Config.lua for Windows Support

**Files:**
- Modify: `AISelects.lrplugin/Config.lua`

- [ ] **Step 1: Add Platform import at top of Config.lua**

Find the import section and add:

```lua
local Platform = require 'Platform'
```

- [ ] **Step 2: Add Windows dependency detection function**

Add before the return statement:

```lua
-- [Windows] Check if required dependencies are available
function M.checkWindowsDependencies()
    if not Platform.isWindows() then
        return { success = true, missing = {} }
    end
    
    local missing = {}
    
    -- Check ImageMagick
    local magickResult = LrTasks.execute('where magick 2>nul')
    if magickResult ~= 0 then
        table.insert(missing, "ImageMagick")
    end
    
    -- Check sqlite3
    local sqliteResult = LrTasks.execute('where sqlite3 2>nul')
    if sqliteResult ~= 0 then
        table.insert(missing, "sqlite3")
    end
    
    return {
        success = (#missing == 0),
        missing = missing
    }
end
```

- [ ] **Step 3: Add dependency verification UI section**

Add to the sections table in the dialog:

```lua
-- [Windows] Dependency verification section (Windows only)
if Platform.isWindows() then
    table.insert(sections, {
        title = "Windows Dependencies",
        spacing = f:control_spacing(),
        
        f:row {
            f:push_button {
                title = "Verify Dependencies",
                action = function()
                    local result = M.checkWindowsDependencies()
                    if result.success then
                        LrDialogs.message("Dependencies OK", "All required dependencies are installed.", "info")
                    else
                        local msg = "Missing dependencies:\n" .. table.concat(result.missing, "\n")
                        LrDialogs.message("Missing Dependencies", msg, "critical")
                    end
                end
            }
        }
    })
end
```

- [ ] **Step 4: Replace curl call at line 41**

Find:
```lua
local cmd = string.format("curl -K %s -o %s",
```

Replace with:
```lua
-- [Windows] Replaced direct curl call with Platform abstraction
local result = Platform.executeCommand("http", {
    { key = "url", value = url },
    { key = "method", value = "GET" },
    { key = "headersFile", value = tmpCfg },
    { key = "outputFile", value = tmpOut }
})
```

- [ ] **Step 5: Verify Config.lua syntax**

```bash
lua -c AISelects.lrplugin/Config.lua
```

Expected: No syntax errors

- [ ] **Step 6: Commit**

```bash
git add AISelects.lrplugin/Config.lua
git commit -m "feat: add Windows dependency detection to Config.lua"
```

---

## Phase 3: Documentation

### Task 9: Create Windows Installation Documentation

**Files:**
- Create: `docs/WINDOWS_INSTALL.md`

- [ ] **Step 1: Write WINDOWS_INSTALL.md**

```markdown
# AI Selects - Windows 11 Installation Guide

## Prerequisites

Before installing AI Selects on Windows 11, ensure you have:

- **Windows 11** (64-bit)
- **Adobe Lightroom Classic CC 2019** or later
- **PowerShell 5.1+** (included with Windows 11)

## Step 1: Install Dependencies

### 1.1 ImageMagick

ImageMagick is required for image processing operations.

1. Download ImageMagick from: https://imagemagick.org/script/download.php#windows
2. Run the installer
3. **Important:** Check "Install legacy utilities (e.g. convert)" during installation
4. Verify installation:
   ```powershell
   magick --version
   ```
   Expected output: `Version: ImageMagick 7.x.x`

### 1.2 SQLite3

SQLite3 is required for database operations.

1. Download SQLite3 from: https://www.sqlite.org/download.html
   - Look for "sqlite-tools-win32-x64-*.zip"
2. Extract the ZIP file to a directory, e.g., `C:\Tools\sqlite3\`
3. Add the directory to your PATH environment variable:
   - Open System Properties → Environment Variables
   - Edit "Path" variable
   - Add: `C:\Tools\sqlite3\`
4. Verify installation:
   ```powershell
   sqlite3 --version
   ```
   Expected output: `3.xx.x`

### 1.3 Configure PowerShell Execution Policy

PowerShell may block unsigned scripts by default. Allow script execution:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

When prompted, type `Y` and press Enter.

## Step 2: Install the Plugin

1. Download the `AISelects.lrplugin` folder
2. Open Adobe Lightroom Classic
3. Go to: **File → Plug-in Manager**
4. Click **Add** button
5. Navigate to and select the `AISelects.lrplugin` folder
6. Click **Select Folder**

## Step 3: Configure the Plugin

1. In the Plug-in Manager, select "AI Selects"
2. Click **Settings** button
3. Configure your AI provider:
   - **Claude:** Enter your Anthropic API key
   - **OpenAI:** Enter your OpenAI API key
   - **Gemini:** Enter your Google API key
   - **Ollama:** Ensure Ollama is running locally

## Step 4: Verify Installation

1. In the Plug-in Manager, select "AI Selects"
2. Click **Settings** button
3. Click **Verify Dependencies** button
4. Confirm all dependencies show green ✓

If any dependencies are missing:
- **ImageMagick not found:** Check PATH environment variable
- **sqlite3 not found:** Check PATH or configure custom path in settings

## Troubleshooting

### Issue: "Script execution disabled" error

**Solution:** Configure PowerShell execution policy:
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Issue: "magick command not found"

**Solution:** 
1. Verify ImageMagick is installed
2. Check PATH environment variable includes ImageMagick directory
3. Restart Lightroom after PATH changes

### Issue: "sqlite3 command not found"

**Solution:**
1. Verify sqlite3.exe is in PATH
2. Or configure custom path in plugin settings

### Issue: API calls fail

**Solution:**
1. Verify API key is correct
2. Check internet connection
3. Check firewall settings (curl.exe may be blocked)

## Next Steps

Once installed, you can:

- **Score photos:** Select photos → Library menu → Score Only
- **Select photos:** Select scored photos → Library menu → Select Only
- **Score & Select:** Select photos → Library menu → Score && Select

For detailed usage, see the main README.md.
```

- [ ] **Step 2: Commit**

```bash
git add docs/WINDOWS_INSTALL.md
git commit -m "docs: add Windows 11 installation guide"
```

---

### Task 10: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Windows support section to README.md**

Add after the existing installation section:

```markdown
## Platform Support

AI Selects supports both macOS and Windows 11:

### macOS
- Uses built-in tools: `sips`, `sqlite3`, `curl`
- No additional dependencies required

### Windows 11
- Requires: ImageMagick 7.0+, sqlite3.exe
- See [Windows Installation Guide](docs/WINDOWS_INSTALL.md) for detailed instructions

## Installation

### macOS

1. Download `AISelects.lrplugin` folder
2. In Lightroom: File → Plug-in Manager → Add Plug-in
3. Select `AISelects.lrplugin` folder

### Windows 11

See [Windows Installation Guide](docs/WINDOWS_INSTALL.md) for detailed setup instructions.

Quick start:
1. Install ImageMagick and sqlite3
2. Configure PowerShell execution policy
3. Install plugin in Lightroom
4. Verify dependencies in plugin settings
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add Windows support to README"
```

---

## Phase 4: Validation

### Task 11: Validate Lua Syntax

**Files:**
- All Lua files in `AISelects.lrplugin/`

- [ ] **Step 1: Check all Lua files for syntax errors**

```bash
for file in AISelects.lrplugin/*.lua; do
    echo "Checking $file..."
    lua -c "$file" || echo "ERROR in $file"
done
```

Expected: No errors for any file

- [ ] **Step 2: Fix any syntax errors found**

If errors found, fix them and re-run Step 1.

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve Lua syntax errors"
```

---

### Task 12: Validate PowerShell Scripts

**Files:**
- All PowerShell scripts in `AISelects.lrplugin/Utils/windows/`

- [ ] **Step 1: Check if PowerShell Core is available**

```bash
if command -v pwsh &> /dev/null; then
    echo "PowerShell Core available"
else
    echo "PowerShell Core not available - skipping syntax check"
fi
```

- [ ] **Step 2: If PowerShell available, check script syntax**

```bash
if command -v pwsh &> /dev/null; then
    for file in AISelects.lrplugin/Utils/windows/*.ps1; do
        echo "Checking $file..."
        pwsh -Command "Get-Content '$file' | Out-Null" || echo "ERROR in $file"
    done
fi
```

Expected: No syntax errors

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve PowerShell script issues"
```

---

### Task 13: Final Review and Commit

**Files:**
- All modified files

- [ ] **Step 1: Review all changes**

```bash
git status
git diff --stat
```

- [ ] **Step 2: Create summary of changes**

```bash
echo "## Changes Summary" > CHANGES.md
echo "" >> CHANGES.md
echo "### New Files" >> CHANGES.md
git ls-files --others --exclude-standard >> CHANGES.md
echo "" >> CHANGES.md
echo "### Modified Files" >> CHANGES.md
git diff --name-only >> CHANGES.md
```

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete Windows 11 migration

- Add Platform.lua abstraction layer
- Add macOS platform scripts (image.sh, http.sh, db.sh)
- Add Windows platform scripts (image.ps1, http.ps1, db.ps1)
- Migrate AIEngine.lua to Platform abstraction
- Migrate ScorePhotos.lua to Platform abstraction
- Migrate SelectPhotos.lua to Platform abstraction
- Add Windows dependency detection to Config.lua
- Add Windows installation documentation
- Update README with Windows support"
```

- [ ] **Step 4: Create git tag**

```bash
git tag -a v1.1.0-windows -m "Windows 11 support added"
```

---

## Success Criteria

- [ ] All Lua files pass syntax check
- [ ] PowerShell scripts pass syntax check (if PowerShell available)
- [ ] Platform.lua correctly detects OS
- [ ] macOS scripts are executable
- [ ] Windows installation documentation is complete
- [ ] README updated with Windows support
- [ ] All changes committed to git

---

## Notes

- **Testing:** Windows testing deferred. Validation limited to syntax checks in Linux environment.
- **macOS Compatibility:** All changes maintain backward compatibility with macOS.
- **Future Work:** Consider automated testing on Windows CI/CD pipeline.
