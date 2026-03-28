#!/bin/bash
# list.sh -- List backups
for d in android_backup_*; do
    [[ ! -d "$d" ]] && continue
    size=$(du -sh "$d" | cut -f1)
    apks=$(find "$d/apks" -name "*.apk" 2>/dev/null | wc -l)
    echo "  $d ($size, $apks APKs)"
done
