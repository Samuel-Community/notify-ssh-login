#!/usr/bin/env bash
# Script dédié de désinstallation (équivalent à --remove)
set -Eeuo pipefail
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "❌ Lance en root (sudo)."; exit 1; }

KEEP_LOG=false
PURGE_PKGS=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-log) KEEP_LOG=true; shift;;
    --purge-packages) PURGE_PKGS=true; shift;;
    -h|--help) echo "Usage: sudo $0 [--keep-log] [--purge-packages]"; exit 0;;
    *) echo "Option inconnue: $1"; exit 1;;
  esac
done

BIN=/usr/local/bin
ETC=/etc/ssh-notify
SYSTEMD=/etc/systemd/system
PAM_FILE="/etc/pam.d/sshd"
LOG_FILE="/var/log/ssh-notify.log"

command -v systemctl >/dev/null 2>&1 && {
  systemctl disable --now ssh-notify-weekly.timer >/dev/null 2>&1 || true
  rm -f "$SYSTEMD/ssh-notify-weekly.timer" "$SYSTEMD/ssh-notify-weekly.service"
  systemctl daemon-reload || true
}

if [[ -f "$PAM_FILE" ]] && grep -q "ssh-notify\.sh" "$PAM_FILE"; then
  sed -i '/^# SSH-Notify$/,/ssh-notify\.sh$/d' "$PAM_FILE" || true
fi

rm -f /etc/profile.d/ssh-notify.sh
rm -f "$BIN/ssh-notify.sh" "$BIN/ssh-notify-report.sh"
rm -rf "$ETC"

if ! $KEEP_LOG; then rm -f "$LOG_FILE"; else echo "ℹ️ Journal conservé : $LOG_FILE"; fi

if $PURGE_PKGS && command -v apt-get >/dev/null 2>&1; then
  apt-get remove --purge -y curl jq mailutils || true
fi

echo "🧹 SSH-Notify supprimé."
