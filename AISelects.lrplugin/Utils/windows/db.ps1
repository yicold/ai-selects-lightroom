# Database query script for Windows using sqlite3.exe
# Positional args: DbPath, Query, OutputFile
param(
    [Parameter(Position=0)]
    [string]$DbPath,
    [Parameter(Position=1)]
    [string]$Query,
    [Parameter(Position=2)]
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
