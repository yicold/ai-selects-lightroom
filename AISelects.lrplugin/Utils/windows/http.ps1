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
