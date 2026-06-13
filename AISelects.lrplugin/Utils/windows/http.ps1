# HTTP request script for Windows using curl
# Windows 10+ has built-in curl.exe (must use .exe to avoid PowerShell alias)
# Args: ConfigFile [BodyFile] OutputFile
# - 2 args: ConfigFile, OutputFile (GET)
# - 3 args: ConfigFile, BodyFile, OutputFile (POST)

param(
    [Parameter(Position=0)]
    [string]$ConfigFile,
    [Parameter(Position=1)]
    [string]$BodyFile,
    [Parameter(Position=2)]
    [string]$OutputFile
)

# If only 2 args, it's GET (no body)
if ([string]::IsNullOrEmpty($OutputFile)) {
    $OutputFile = $BodyFile
    $BodyFile = ""
}

# Use curl.exe explicitly (curl in PowerShell is an alias to Invoke-WebRequest)
if ($BodyFile -ne "") {
    curl.exe -K $ConfigFile -d "@$BodyFile" -o $OutputFile
}
else {
    curl.exe -K $ConfigFile -o $OutputFile
}

exit $LASTEXITCODE
