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
