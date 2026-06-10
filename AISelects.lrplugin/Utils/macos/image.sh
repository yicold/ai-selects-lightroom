#!/bin/bash
# Image processing script for macOS using sips

ACTION="$1"
INPUT_PATH="$2"
OUTPUT_PATH="$3"
WIDTH="$4"
HEIGHT="$5"

case "$ACTION" in
    resize)
        sips --resampleWidth "$WIDTH" --resampleHeight "$HEIGHT" "$INPUT_PATH" --out "$OUTPUT_PATH"
        ;;
    convert)
        sips -s format jpeg "$INPUT_PATH" --out "$OUTPUT_PATH"
        ;;
    *)
        echo "Unknown action: $ACTION" >&2
        exit 1
        ;;
esac

exit $?
