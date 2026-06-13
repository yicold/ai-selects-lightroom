# Image processing script for Windows using ImageMagick
# Positional args: Action, InputPath, OutputPath, Width, Height
param(
    [Parameter(Position=0)]
    [string]$Action,
    [Parameter(Position=1)]
    [string]$InputPath,
    [Parameter(Position=2)]
    [string]$OutputPath,
    [Parameter(Position=3)]
    [int]$Width,
    [Parameter(Position=4)]
    [int]$Height
)

try {
    switch ($Action) {
        "resize" {
            # Resize and convert to target format based on output extension
            & magick convert $InputPath -resize "${Width}x${Height}!" $OutputPath
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
