# 💾 Android Backup Vault

> One-command Android backup & restore — APKs, photos, SMS, contacts, and Wi-Fi via ADB. No root. No cloud.

[![Shell](https://img.shields.io/badge/shell-bash-green?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![ADB](https://img.shields.io/badge/requires-ADB-green?logo=android)](https://developer.android.com/tools/releases/platform-tools)
[![No Root](https://img.shields.io/badge/root-not%20required-brightgreen)](.)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A dead-simple backup script that actually works. Connect your phone, run one command, get a complete backup folder on your computer. Restore is just as easy.

---

## ✨ What Gets Backed Up

| Category | Contents | Root Needed? |
|----------|----------|-------------|
| 📦 APKs | All third-party apps | ❌ No |
| 🖼️ Media | DCIM, Pictures, Downloads | ❌ No |
| 💬 SMS/MMS | Inbox + Sent messages | ❌ No |
| 📇 Contacts | Contact list export | ❌ No |
| 📶 Wi-Fi | Network names & info | ❌ No |
| 💾 App Data | Full backup (ADB protocol) | ❌ No* |

*App data backup success depends on the device and Android version. Some apps opt out of ADB backup.

---

## 📦 Requirements

- macOS/Linux/WSL (or Git Bash on Windows)
- [ADB (Android Platform Tools)](https://developer.android.com/tools/releases/platform-tools)
- USB Debugging enabled on your Android device

---

## 🚀 Quick Start

```bash
# Clone
git clone https://github.com/OutrageousStorm/android-backup-vault
cd android-backup-vault
chmod +x backup.sh

# Connect your phone via USB, enable USB Debugging, then:
./backup.sh
```

That's it. Your backup lands in a timestamped folder like `android_backup_20250115_143200/`.

---

## 📂 Backup Structure

```
android_backup_20250115_143200/
├── MANIFEST.txt          ← Device info + file summary
├── apks/                 ← All .apk files
│   ├── com.spotify.music.apk
│   ├── com.whatsapp.apk
│   └── ...
├── media/
│   ├── DCIM/             ← Photos & videos
│   ├── Pictures/
│   └── Download/
├── contacts/             ← Contact exports
├── sms/                  ← SMS inbox + sent
│   ├── sms_inbox.txt
│   └── sms_sent.txt
└── wifi/                 ← Wi-Fi network info
    └── wifi_networks.txt
```

---

## 🔧 Commands

```bash
# Full backup (everything)
./backup.sh

# Partial backups
./backup.sh backup-apks       # APKs only
./backup.sh backup-media      # Photos & videos only
./backup.sh backup-sms        # SMS only
./backup.sh backup-contacts   # Contacts only
./backup.sh backup-data       # Full app data (ADB backup protocol)

# Restore
./backup.sh restore ./android_backup_20250115_143200

# Options
./backup.sh --device R3CN80XXXXX    # Specific device
./backup.sh --output /my/backup/    # Custom output directory
```

---

## 🔄 Restore

```bash
# Restore APKs + media from a backup
./backup.sh restore ./android_backup_20250115_143200
```

Reinstalls all APKs and pushes media back to the device. SMS and contacts restoration requires importing the exported files via your contacts/SMS app.

---

## 💡 Tips

- Run on a **new device** after a factory reset to restore your apps in bulk.
- Combine with `adb backup` app data for the most complete backup possible.
- Schedule with `cron` for automatic periodic backups.
- The `MANIFEST.txt` is great for inventory — what apps did you have on that old phone?

---

## 🤝 Contributing

PRs welcome! Ideas:
- Windows `.bat` version
- Selective app restore (pick from list)
- Compression of backup folder
- Incremental backups (only changed files)
- Backup verification / integrity check

---

## 📜 License

MIT

---

*Your data, your control. No accounts, no subscriptions, no cloud.*
