#!/bin/bash
# HTTP request script for macOS using curl
# Args: ConfigFile [BodyFile] OutputFile
# - 2 args: ConfigFile, OutputFile (GET)
# - 3 args: ConfigFile, BodyFile, OutputFile (POST)

CONFIG_FILE="$1"
BODY_FILE="$2"
OUTPUT_FILE="$3"

# If only 2 args, it's GET (no body)
if [ -z "$3" ]; then
    OUTPUT_FILE="$2"
    BODY_FILE=""
fi

if [ -n "$BODY_FILE" ]; then
    curl -K "$CONFIG_FILE" -d @"$BODY_FILE" -o "$OUTPUT_FILE"
else
    curl -K "$CONFIG_FILE" -o "$OUTPUT_FILE"
fi

exit $?
