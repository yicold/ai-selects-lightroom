--[[
Platform abstraction layer for cross-platform support.
Provides unified interface for OS-specific operations.
]]

local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

local Platform = {}

-- Determine if running on Windows
-- Lightroom's Lua environment doesn't have 'package' or 'os.getenv',
-- so we detect platform by checking if the plugin path contains a backslash
-- (Windows uses backslashes, macOS uses forward slashes)
function Platform.isWindows()
    return _PLUGIN.path:find('\\') ~= nil
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

-- Get temp directory for current platform
-- Note: Lightroom Lua doesn't have os.getenv, so on Windows we use a known temp location
function Platform.getTempDir()
    if Platform.isWindows() then
        -- Use plugin directory for temp files (guaranteed writable)
        return _PLUGIN.path
    else
        return '/tmp'
    end
end

-- Get a temp file path with the given name
function Platform.getTempPath(filename)
    return Platform.getTempDir() .. Platform.getPathSeparator() .. filename
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
        argsStr = argsStr .. ' "' .. arg .. '"'
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
