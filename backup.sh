#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  android-backup-vault — One-command Android backup & restore
#  No root. No cloud. Pure ADB.
# ═══════════════════════════════════════════════════════════

set -euo pipefail

VERSION="1.0.0"
BACKUP_DIR="./android_backup_$(date +%Y%m%d_%H%M%S)"
DEVICE=""
MODE="backup"

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}${BLUE}══ $* ══${NC}\n"; }

# ── Banner ───────────────────────────────────────────────────
banner() {
  echo -e "${BOLD}"
  echo "  ╔══════════════════════════════════════╗"
  echo "  ║   💾  Android Backup Vault v$VERSION   ║"
  echo "  ║   No root. No cloud. Just ADB.       ║"
  echo "  ╚══════════════════════════════════════╝"
  echo -e "${NC}"
}

# ── ADB helpers ─────────────────────────────────────────────
adb_cmd() {
  if [[ -n "$DEVICE" ]]; then
    adb -s "$DEVICE" "$@"
  else
    adb "$@"
  fi
}

check_adb() {
  if ! command -v adb &>/dev/null; then
    error "ADB not found. Install Android Platform Tools:"
    error "  https://developer.android.com/tools/releases/platform-tools"
    exit 1
  fi
}

check_device() {
  local devices
  devices=$(adb devices | grep -v "^List" | grep "device$" | awk '{print $1}')
  if [[ -z "$devices" ]]; then
    error "No Android device connected!"
    error "  1. Connect via USB"
    error "  2. Enable USB Debugging (Settings > Developer Options)"
    exit 1
  fi

  local count
  count=$(echo "$devices" | wc -l | tr -d ' ')

  if [[ "$count" -gt 1 ]] && [[ -z "$DEVICE" ]]; then
    warn "Multiple devices found. Using first: $(echo "$devices" | head -1)"
    warn "Use --device <serial> to specify one"
    DEVICE=$(echo "$devices" | head -1)
  elif [[ -z "$DEVICE" ]]; then
    DEVICE=$(echo "$devices" | head -1)
  fi

  log "Target device: ${BOLD}$DEVICE${NC}"
}

# ── Backup functions ─────────────────────────────────────────

backup_apks() {
  header "Backing up APKs"
  local apk_dir="$BACKUP_DIR/apks"
  mkdir -p "$apk_dir"

  local packages
  packages=$(adb_cmd shell pm list packages -3 | sed 's/package://' | sort)
  local total count=0
  total=$(echo "$packages" | wc -l | tr -d ' ')

  log "Found $total third-party apps"

  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    local path
    path=$(adb_cmd shell pm path "$pkg" 2>/dev/null | sed 's/package://' | tr -d '\r')
    if [[ -n "$path" ]]; then
      local filename="${pkg}.apk"
      if adb_cmd pull "$path" "$apk_dir/$filename" &>/dev/null; then
        ((count++)) || true
        echo -ne "  Progress: $count/$total\r"
      fi
    fi
  done <<< "$packages"

  echo ""
  success "Backed up $count/$total APKs → $apk_dir"
}

backup_photos() {
  header "Backing up Photos & Videos"
  local media_dir="$BACKUP_DIR/media"
  mkdir -p "$media_dir"

  log "Pulling DCIM folder..."
  adb_cmd pull /sdcard/DCIM "$media_dir/DCIM" 2>/dev/null || warn "No DCIM folder found"
  
  log "Pulling Pictures folder..."
  adb_cmd pull /sdcard/Pictures "$media_dir/Pictures" 2>/dev/null || warn "No Pictures folder found"
  
  log "Pulling Download folder..."
  adb_cmd pull /sdcard/Download "$media_dir/Download" 2>/dev/null || warn "No Download folder found"

  local count
  count=$(find "$media_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
  success "Backed up $count media files → $media_dir"
}

backup_contacts() {
  header "Backing up Contacts"
  local contacts_dir="$BACKUP_DIR/contacts"
  mkdir -p "$contacts_dir"

  log "Exporting contacts via content provider..."
  # Dump contacts via content query (no root needed)
  adb_cmd shell content query \
    --uri content://com.android.contacts/contacts \
    --projection display_name:has_phone_number 2>/dev/null \
    > "$contacts_dir/contacts_raw.txt" || warn "Could not export contacts"

  # Pull any existing vCard exports from storage
  adb_cmd pull /sdcard/contacts.vcf "$contacts_dir/" 2>/dev/null || true
  adb_cmd pull /sdcard/Contacts "$contacts_dir/" 2>/dev/null || true

  success "Contacts exported → $contacts_dir"
}

backup_sms() {
  header "Backing up SMS/MMS"
  local sms_dir="$BACKUP_DIR/sms"
  mkdir -p "$sms_dir"

  log "Exporting SMS via content provider..."
  adb_cmd shell content query \
    --uri content://sms/inbox \
    --projection "address:date:body" \
    2>/dev/null > "$sms_dir/sms_inbox.txt" || warn "Could not read SMS"

  adb_cmd shell content query \
    --uri content://sms/sent \
    --projection "address:date:body" \
    2>/dev/null > "$sms_dir/sms_sent.txt" || warn "Could not read sent SMS"

  success "SMS exported → $sms_dir"
}

backup_wifi() {
  header "Backing up Wi-Fi Profiles"
  local wifi_dir="$BACKUP_DIR/wifi"
  mkdir -p "$wifi_dir"

  # Android 10+ requires root for wpa_supplicant, but we can get SSID list
  adb_cmd shell cmd wifi list-networks 2>/dev/null \
    > "$wifi_dir/wifi_networks.txt" || \
  adb_cmd shell dumpsys wifi 2>/dev/null | grep -E "SSID|BSSID" \
    > "$wifi_dir/wifi_networks.txt" || \
    warn "Could not export Wi-Fi profiles (may require root for passwords)"

  success "Wi-Fi info exported → $wifi_dir"
}

backup_apps_data() {
  header "Backing up App Data (Android Backup Protocol)"
  local data_dir="$BACKUP_DIR/app_data"
  mkdir -p "$data_dir"

  warn "Note: ADB backup may prompt confirmation on your device!"
  log "Starting ADB backup (confirm on device if prompted)..."

  # adb backup creates an encrypted .ab file
  adb_cmd backup -apk -shared -all -f "$data_dir/full_backup.ab" 2>/dev/null || \
    warn "Full backup failed (some devices restrict this)"

  success "App data backup → $data_dir"
}

create_manifest() {
  local manifest="$BACKUP_DIR/MANIFEST.txt"
  {
    echo "Android Backup Vault"
    echo "Version: $VERSION"
    echo "Date: $(date)"
    echo "Device: $DEVICE"
    echo "Device Model: $(adb_cmd shell getprop ro.product.model 2>/dev/null)"
    echo "Android Version: $(adb_cmd shell getprop ro.build.version.release 2>/dev/null)"
    echo "Build: $(adb_cmd shell getprop ro.build.display.id 2>/dev/null)"
    echo ""
    echo "Contents:"
    find "$BACKUP_DIR" -type d | sed "s|$BACKUP_DIR||" | sort
    echo ""
    echo "File count by type:"
    find "$BACKUP_DIR" -type f | sed 's/.*\.//' | sort | uniq -c | sort -rn
  } > "$manifest"
  success "Manifest saved → $manifest"
}

# ── Restore functions ────────────────────────────────────────

restore_apks() {
  local backup_dir="${1:-}"
  [[ -z "$backup_dir" ]] && { error "Specify backup dir: $0 restore <dir>"; exit 1; }
  
  header "Restoring APKs"
  local apk_dir="$backup_dir/apks"
  [[ ! -d "$apk_dir" ]] && { warn "No APKs folder in backup"; return; }

  local count=0 failed=0
  for apk in "$apk_dir"/*.apk; do
    [[ -f "$apk" ]] || continue
    if adb_cmd install -r "$apk" &>/dev/null; then
      ((count++)) || true
    else
      ((failed++)) || true
    fi
  done
  success "Restored $count APKs ($failed failed)"
}

restore_media() {
  local backup_dir="${1:-}"
  header "Restoring Media"
  local media_dir="$backup_dir/media"
  [[ ! -d "$media_dir" ]] && { warn "No media folder in backup"; return; }

  adb_cmd push "$media_dir/DCIM" /sdcard/ 2>/dev/null || true
  adb_cmd push "$media_dir/Pictures" /sdcard/ 2>/dev/null || true
  success "Media restored"
}

# ── Usage ────────────────────────────────────────────────────

usage() {
  echo -e "${BOLD}Usage:${NC}"
  echo "  $0 [command] [options]"
  echo ""
  echo -e "${BOLD}Commands:${NC}"
  echo "  backup          Full backup (default): APKs + photos + SMS + contacts + Wi-Fi"
  echo "  backup-apks     APKs only"
  echo "  backup-media    Photos & videos only"
  echo "  backup-sms      SMS/MMS only"
  echo "  backup-contacts Contacts only"
  echo "  backup-data     Full app data (ADB backup protocol)"
  echo "  restore <dir>   Restore APKs and media from backup directory"
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  --device, -d <serial>   Target specific device"
  echo "  --output, -o <dir>      Output directory (default: timestamped)"
  echo "  --help, -h              Show this help"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo "  $0                      # Full backup"
  echo "  $0 backup-media         # Photos only"
  echo "  $0 restore ./android_backup_20250115_143200"
}

# ── Main ─────────────────────────────────────────────────────

main() {
  banner

  # Parse args
  local cmd="${1:-backup}"
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --device|-d) DEVICE="$2"; shift 2 ;;
      --output|-o) BACKUP_DIR="$2"; shift 2 ;;
      --help|-h)   usage; exit 0 ;;
      *) break ;;
    esac
  done

  check_adb
  check_device

  case "$cmd" in
    backup)
      mkdir -p "$BACKUP_DIR"
      log "Backup directory: ${BOLD}$BACKUP_DIR${NC}"
      backup_apks
      backup_photos
      backup_contacts
      backup_sms
      backup_wifi
      create_manifest
      echo ""
      success "✅ Backup complete! → ${BOLD}$BACKUP_DIR${NC}"
      ;;
    backup-apks)     mkdir -p "$BACKUP_DIR"; backup_apks; create_manifest ;;
    backup-media)    mkdir -p "$BACKUP_DIR"; backup_photos; create_manifest ;;
    backup-sms)      mkdir -p "$BACKUP_DIR"; backup_sms; create_manifest ;;
    backup-contacts) mkdir -p "$BACKUP_DIR"; backup_contacts; create_manifest ;;
    backup-data)     mkdir -p "$BACKUP_DIR"; backup_apps_data; create_manifest ;;
    restore)         restore_apks "${1:-}"; restore_media "${1:-}" ;;
    help|--help|-h)  usage ;;
    *)               error "Unknown command: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
