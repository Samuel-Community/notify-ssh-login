#!/usr/bin/env bash
# SSH-Notify installer (simple & robuste)
set -Eeuo pipefail
trap 'echo "❌ Erreur à la ligne $LINENO : $BASH_COMMAND"; exit 1' ERR

need_root(){ [[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "❌ Lance en root (sudo)."; exit 1; }; }
usage(){ cat <<'USAGE'
Usage:
  sudo bash ssh-notify-install.sh
  sudo bash ssh-notify-install.sh -y
  sudo bash ssh-notify-install.sh --webhook "<URL>"
  sudo bash ssh-notify-install.sh --remove [--keep-log] [--purge-packages]

Options:
  -y                Pas de questions (non-interactif)
  --webhook URL     Enregistre le webhook Discord dans /etc/ssh-notify/.env
  --remove          Désinstalle tout (scripts, .env, PAM, systemd, logrotate)
  --keep-log        Conserve /var/log/ssh-notify*.log à la désinstallation
  --purge-packages  (apt/dnf/yum/zypper/pacman/apk) tente de supprimer curl jq mailutils
USAGE
}

ASSUME_Y=false; REMOVE=false; KEEP_LOG=false; PURGE_PKGS=false
WEBHOOK_CLI=""; SKIP_WEBHOOK_PROMPT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y) ASSUME_Y=true; shift;;
    --webhook) shift; WEBHOOK_CLI="${1:-}"; [[ -z "$WEBHOOK_CLI" ]] && { echo "❌ --webhook nécessite une valeur"; exit 1; }; shift;;
    --remove) REMOVE=true; shift;;
    --keep-log) KEEP_LOG=true; shift;;
    --purge-packages) PURGE_PKGS=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Option inconnue: $1"; usage; exit 1;;
  esac
done

need_root

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
FILES_DIR="$SCRIPT_DIR/files"

BIN=/usr/local/bin
ETC=/etc/ssh-notify
SYSTEMD=/etc/systemd/system
PAM_FILE="/etc/pam.d/sshd"
ENV_PATH="$ETC/.env"
LOGROTATE_CONF="/etc/logrotate.d/ssh-notify"

has_cmd(){ command -v "$1" >/dev/null 2>&1; }

install_deps(){
  local pkgs=("$@") mgr=""
  if   has_cmd apt-get; then mgr="apt";    DEBIAN_FRONTEND=noninteractive apt-get update -y && apt-get install -y "${pkgs[@]}" || true
  elif has_cmd apt;     then mgr="apt";    DEBIAN_FRONTEND=noninteractive apt update -y && apt install -y "${pkgs[@]}" || true
  elif has_cmd dnf;     then mgr="dnf";    dnf install -y "${pkgs[@]}" || true
  elif has_cmd yum;     then mgr="yum";    yum install -y "${pkgs[@]}" || true
  elif has_cmd zypper;  then mgr="zypper"; zypper --non-interactive install -y "${pkgs[@]}" || true
  elif has_cmd pacman;  then mgr="pacman"; pacman -Sy --noconfirm "${pkgs[@]}" || true
  elif has_cmd apk;     then mgr="apk";    apk add --no-cache "${pkgs[@]}" || true
  else echo "⚠️  Gestionnaire de paquets non détecté. Installe manuellement: ${pkgs[*]}"; return 0; fi
  echo "📦 Dépendances vérifiées via $mgr: ${pkgs[*]}"
}

uninstall_deps(){
  local pkgs=("curl" "jq" "mailutils")
  if   has_cmd apt-get; then apt-get remove --purge -y "${pkgs[@]}" || true
  elif has_cmd dnf;     then dnf remove -y "${pkgs[@]}" || true
  elif has_cmd yum;     then yum remove -y "${pkgs[@]}" || true
  elif has_cmd zypper;  then zypper --non-interactive remove -y "${pkgs[@]}" || true
  elif has_cmd pacman;  then pacman -Rns --noconfirm "${pkgs[@]}" || true
  elif has_cmd apk;     then apk del "${pkgs[@]}" || true
  fi
}

escape_sed(){ sed -e 's/[\/&]/\\&/g' <<<"$1"; }

desinstaller(){
  echo "🔎 Désinstallation…"
  if has_cmd systemctl; then
    systemctl disable --now ssh-notify-weekly.timer >/dev/null 2>&1 || true
    rm -f "$SYSTEMD/ssh-notify-weekly.timer" "$SYSTEMD/ssh-notify-weekly.service"
    systemctl daemon-reload >/dev/null 2>&1 || true
  fi
  if [[ -f "$PAM_FILE" ]] && grep -q "ssh-notify\.sh" "$PAM_FILE"; then
    sed -i '/^# SSH-Notify$/,/ssh-notify\.sh$/d' "$PAM_FILE" || true
  fi
  rm -f "$BIN/ssh-notify.sh" "$BIN/ssh-notify-report.sh"
  rm -rf "$ETC"
  rm -f "$LOGROTATE_CONF"
  if ! $KEEP_LOG; then rm -f /var/log/ssh-notify.log /var/log/ssh-notify.debug.log; fi
  $PURGE_PKGS && uninstall_deps
  echo "🧹 Désinstallation terminée."
  exit 0
}
$REMOVE && desinstaller

# Fichiers requis
for f in ssh-notify.sh ssh-notify-report.sh ssh-notify-weekly.service ssh-notify-weekly.timer .env.example ssh-notify.logrotate; do
  [[ -f "$FILES_DIR/$f" ]] || { echo "❌ Manquant : $FILES_DIR/$f"; exit 1; }
done

# Dépendances minimales + CA (HTTPS)
need=()
has_cmd curl || need+=("curl")
has_cmd jq   || need+=("jq")
has_cmd update-ca-certificates >/dev/null 2>&1 || has_cmd trust >/dev/null 2>&1 || need+=("ca-certificates")
((${#need[@]})) && install_deps "${need[@]}" || echo "✅ curl/jq/CA OK"

# mailutils (optionnel). On essaye, sans bloquer si ça rate.
install_deps mailutils || true

# Arborescence
install -d -m 0755 "$ETC"

# Copie binaires
install -m 0755 "$FILES_DIR/ssh-notify.sh" "$BIN/ssh-notify.sh"
install -m 0755 "$FILES_DIR/ssh-notify-report.sh" "$BIN/ssh-notify-report.sh"
chown root:root "$BIN/ssh-notify.sh" "$BIN/ssh-notify-report.sh"

# .env
if [[ ! -f "$ENV_PATH" ]]; then
  install -m 0640 "$FILES_DIR/.env.example" "$ENV_PATH"
  chown root:root "$ENV_PATH"
fi
sed -i 's/\r$//' "$ENV_PATH" || true

# --webhook (sans prompt)
if [[ -n "$WEBHOOK_CLI" ]]; then
  esc="$(escape_sed "$WEBHOOK_CLI")"
  if grep -qE '^[[:space:]]*WEBHOOK[[:space:]]*=' "$ENV_PATH"; then
    sed -i -E 's|^[[:space:]]*WEBHOOK[[:space:]]*=.*|WEBHOOK="'"$esc"'"|' "$ENV_PATH"
  else
    printf '\nWEBHOOK="%s"\n' "$WEBHOOK_CLI" >> "$ENV_PATH"
  fi
  echo "✅ Webhook (CLI) enregistré dans $ENV_PATH"
  SKIP_WEBHOOK_PROMPT=true
fi

# Hook PAM (uniquement dans sshd)
LINE='session optional pam_exec.so seteuid /usr/local/bin/ssh-notify.sh'
if [[ -f "$PAM_FILE" ]] && ! grep -qF "$LINE" "$PAM_FILE"; then
  cp "$PAM_FILE" "${PAM_FILE}.bak.$(date +%s)"
  printf '\n# SSH-Notify\n%s\n' "$LINE" >> "$PAM_FILE"
fi

# systemd (rapport hebdo)
if has_cmd systemctl; then
  install -m 0644 "$FILES_DIR/ssh-notify-weekly.service" "$SYSTEMD/ssh-notify-weekly.service"
  install -m 0644 "$FILES_DIR/ssh-notify-weekly.timer" "$SYSTEMD/ssh-notify-weekly.timer"
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable --now ssh-notify-weekly.timer >/dev/null 2>&1 || true
fi

# logrotate
install -m 0644 "$FILES_DIR/ssh-notify.logrotate" "$LOGROTATE_CONF"
touch /var/log/ssh-notify.log /var/log/ssh-notify.debug.log
chown root:root /var/log/ssh-notify*.log
chmod 0640 /var/log/ssh-notify*.log

# Prompt webhook si pas de --webhook et pas -y
if ! $ASSUME_Y && ! $SKIP_WEBHOOK_PROMPT; then
  current_webhook="$(sed -nE 's/^[[:space:]]*WEBHOOK[[:space:]]*=[[:space:]]*"?(.*?)"?[[:space:]]*$/\1/p' "$ENV_PATH" | tail -n1)"
  if [[ -z "$current_webhook" ]]; then
    if [ -t 0 ] && [ -t 1 ] && [ -r /dev/tty ]; then
      read -rp "Entrez l'URL du webhook Discord (laisser vide pour ignorer) : " WEBHOOK_IN < /dev/tty || WEBHOOK_IN=""
    else
      echo "ℹ️ Utilise --webhook \"<URL>\" pour renseigner sans prompt."
      WEBHOOK_IN=""
    fi
    if [[ -n "${WEBHOOK_IN:-}" ]]; then
      esc="$(escape_sed "$WEBHOOK_IN")"
      if grep -qE '^[[:space:]]*WEBHOOK[[:space:]]*=' "$ENV_PATH"; then
        sed -i -E 's|^[[:space:]]*WEBHOOK[[:space:]]*=.*|WEBHOOK="'"$esc"'"|' "$ENV_PATH"
      else
        printf '\nWEBHOOK="%s"\n' "$WEBHOOK_IN" >> "$ENV_PATH"
      fi
      echo "✅ Webhook enregistré dans $ENV_PATH"
    else
      echo "⚠️ Aucun webhook défini : logs/email OK, pas d'embed Discord."
    fi
  fi
fi

echo "✅ Installation terminée."
echo "• Config :   $ENV_PATH"
echo "• Binaires : $BIN/ssh-notify.sh, $BIN/ssh-notify-report.sh"
echo "• Logrotate : $LOGROTATE_CONF"
has_cmd systemctl && echo "• Timer :    ssh-notify-weekly.timer (dim 06:00)"
