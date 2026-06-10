#!/bin/bash
# HTTP request script for macOS using curl

URL="$1"
METHOD="$2"
HEADERS_FILE="$3"
BODY_FILE="$4"
OUTPUT_FILE="$5"
TIMEOUT="$6"

if [ "$METHOD" = "POST" ]; then
    curl -K "$HEADERS_FILE" -d @"$BODY_FILE" -o "$OUTPUT_FILE" --max-time "$TIMEOUT"
else
    curl -K "$HEADERS_FILE" -o "$OUTPUT_FILE" --max-time "$TIMEOUT"
fi

exit $?
