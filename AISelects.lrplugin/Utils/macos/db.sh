#!/bin/bash
# Database query script for macOS using sqlite3

DB_PATH="$1"
QUERY="$2"
OUTPUT_FILE="$3"

sqlite3 "$DB_PATH" "$QUERY" > "$OUTPUT_FILE"

exit $?
