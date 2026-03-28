#!/bin/bash
# restore.sh -- Restore Android backup created by backup.sh
# Usage: ./restore.sh <backup_dir>
set -e

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

BACKUP_DIR="${1:?Usage: $0 <backup_dir>}"
[[ ! -d "$BACKUP_DIR" ]] && echo -e "${RED}Directory not found: $BACKUP_DIR${NC}" && exit 1

echo -e "\n${BOLD}📦 Android Restore Tool${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! adb devices | grep -q "device$"; then
    echo -e "${RED}❌ No device connected.${NC}"; exit 1
fi

MODEL=$(adb shell getprop ro.product.model)
echo -e "Target device: ${BOLD}$MODEL${NC}"
echo -e "Backup source: ${BOLD}$BACKUP_DIR${NC}\n"

# Show backup info
[[ -f "$BACKUP_DIR/device_info.txt" ]] && cat "$BACKUP_DIR/device_info.txt" | head -5 && echo ""

echo "What would you like to restore?"
echo "  1) APKs (re-install all backed-up apps)"
echo "  2) Storage (DCIM, Documents, Downloads)"
echo "  3) Both"
read -rp "Choice [1/2/3]: " CHOICE

# Restore APKs
if [[ "$CHOICE" == "1" || "$CHOICE" == "3" ]]; then
    APK_DIR="$BACKUP_DIR/apks"
    if [[ ! -d "$APK_DIR" ]]; then
        echo -e "${YELLOW}No APK backup found.${NC}"
    else
        echo -e "\n${YELLOW}📲 Installing APKs...${NC}"
        success=0; fail=0
        for apk in "$APK_DIR"/*.apk; do
            [[ -f "$apk" ]] || continue
            name=$(basename "$apk" .apk)
            result=$(adb install -r "$apk" 2>&1)
            if echo "$result" | grep -q "Success"; then
                echo -e "  ${GREEN}✓${NC} $name"
                ((success++))
            else
                echo -e "  ${RED}✗${NC} $name"
                ((fail++))
            fi
        done
        echo -e "\n  Installed: ${GREEN}$success${NC}  Failed: ${RED}$fail${NC}"
    fi
fi

# Restore storage
if [[ "$CHOICE" == "2" || "$CHOICE" == "3" ]]; then
    STORAGE_DIR="$BACKUP_DIR/storage"
    if [[ ! -d "$STORAGE_DIR" ]]; then
        echo -e "${YELLOW}No storage backup found.${NC}"
    else
        echo -e "\n${YELLOW}🗂  Pushing storage...${NC}"
        for folder in "$STORAGE_DIR"/*/; do
            fname=$(basename "$folder")
            echo -e "  Pushing /sdcard/$fname..."
            adb push "$folder" "/sdcard/$fname" 2>/dev/null || true
            echo -e "  ${GREEN}✓${NC} $fname"
        done
    fi
fi

echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Restore complete!${NC}"
