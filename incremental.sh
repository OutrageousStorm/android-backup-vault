#!/bin/bash
# incremental.sh -- Back up only changed files since last backup
# Usage: ./incremental.sh [--days 7]
# Backs up only files modified in the last N days

set -e
DAYS="${1:--days}" "${2:-1}"
OUT_DIR="incremental_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

echo "🔄 Incremental Backup (last $2 days)"
echo "Destination: $OUT_DIR"

if ! adb devices | grep -q "device$"; then
    echo "No device connected"; exit 1
fi

# Find recently modified files on device
echo "Scanning device for recent changes..."
adb shell find /sdcard -mtime -${2} -type f 2>/dev/null | while read file; do
    # Skip certain directories
    [[ "$file" =~ \.(tmp|cache|log)$ ]] && continue
    [[ "$file" =~ /(\.hidden|\.cache)/ ]] && continue
    
    size=$(adb shell stat -c%s "$file" 2>/dev/null || echo "0")
    if [[ $size -gt 0 ]]; then
        dir="${OUT_DIR}/$(dirname "${file#/sdcard/}")"
        mkdir -p "$dir"
        adb pull "$file" "$dir/" 2>/dev/null && echo "  ✓ $(basename "$file")" || true
    fi
done

echo ""
du -sh "$OUT_DIR"
echo "✅ Backup saved to: $OUT_DIR"
