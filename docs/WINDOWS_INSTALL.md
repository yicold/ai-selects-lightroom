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
3. Click **Verify Windows Dependencies** button
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
