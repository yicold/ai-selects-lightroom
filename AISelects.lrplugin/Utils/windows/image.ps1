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
