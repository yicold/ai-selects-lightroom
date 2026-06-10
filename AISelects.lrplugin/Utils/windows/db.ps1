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
