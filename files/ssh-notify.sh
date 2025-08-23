#!/usr/bin/env bash
# SSH-Notify — notifie uniquement les sessions SSH interactives (pas SFTP/SCP/rsync).
set -Eeuo pipefail
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"

ENV_FILE="/etc/ssh-notify/.env"
[[ -r "$ENV_FILE" ]] && source "$ENV_FILE"

# Défauts
BOTNAME="${BOTNAME:-SSH-Notify}"
AVATAR_URL="${AVATAR_URL:-}"
WEBHOOK="${WEBHOOK:-}"
LOG_FILE="${LOG_FILE:-/var/log/ssh-notify.log}"
TIMEOUT_SECS="${TIMEOUT_SECS:-8}"
RETRY_COUNT="${RETRY_COUNT:-2}"
QUIET_HOURS="${QUIET_HOURS:-}"
ONLY_ROOT="${ONLY_ROOT:-false}"
EXCLUDE_USERS="${EXCLUDE_USERS:-}"
GEOIP_METHOD="${GEOIP_METHOD:-auto}"   # auto | ipapi | ipinfo | none
DEDUP_WINDOW_SECS="${DEDUP_WINDOW_SECS:-10}"
LOCAL_POLICY="${LOCAL_POLICY:-label}"   # label | mute | notify
LOCAL_GEOIP="${LOCAL_GEOIP:-false}"
SHOW_IFACE_LOCAL="${SHOW_IFACE_LOCAL:-true}"
DEBUG="${DEBUG:-false}"
DEBUG_LOG="${DEBUG_LOG:-/var/log/ssh-notify.debug.log}"

# Assurer logs
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$DEBUG_LOG")" 2>/dev/null || true
touch "$LOG_FILE" "$DEBUG_LOG" 2>/dev/null || true
chmod 0640 "$LOG_FILE" "$DEBUG_LOG" 2>/dev/null || true
log_debug(){ [[ "$DEBUG" == "true" ]] && printf '%s | %s\n' "$(date +'%F %T')" "$*" >> "$DEBUG_LOG" 2>/dev/null || true; }

# 👍 Ne s'exécute QUE pour le service PAM 'sshd'
if [[ "${PAM_SERVICE:-}" != "sshd" ]]; then
  log_debug "exit: PAM_SERVICE='${PAM_SERVICE:-}' != sshd"
  exit 0
fi

# Contexte
PAMTYPE="${PAM_TYPE:-}"; USER_NAME="${PAM_USER:-${USER:-unknown}}"
RHOST="${PAM_RHOST:-}"; SSH_IP="${RHOST:-${SSH_CLIENT%% *}}"
SSH_TTY_STR="${SSH_TTY:-}"; PAM_TTY_STR="${PAM_TTY:-}"
ORIG_CMD="${SSH_ORIGINAL_COMMAND:-}"
HOSTNAME_SHORT="$(hostname -s)"; HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
TS_ISO="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"; TS_LOCAL="$(date +'%F %T')"

log_debug "start PAM_TYPE='$PAMTYPE' USER='$USER_NAME' RHOST='$RHOST' SSH_TTY='$SSH_TTY_STR' PAM_TTY='$PAM_TTY_STR' ORIG_CMD='${ORIG_CMD//[$'\r\n']/ }'"

# 1) open_session seulement
[[ "$PAMTYPE" != "open_session" ]] && { log_debug "exit: PAM_TYPE != open_session"; exit 0; }

# 2) Bloquer transferts (SFTP/SCP/rsync)
if [[ -n "$ORIG_CMD" ]] && grep -Eiq '(^|[[:space:]])(scp|rsync|sftp)([[:space:]]|$)' <<<"$ORIG_CMD"; then
  log_debug "exit: ORIG_CMD transfer ($ORIG_CMD)"; exit 0
fi
PPID_CMD="$(tr -d '\0' < "/proc/${PPID:-0}/cmdline" 2>/dev/null || true)"
if echo "$PPID_CMD" | grep -Eiq 'internal-sftp|sftp-server|scp|rsync'; then
  log_debug "exit: parent transfer ($PPID_CMD)"; exit 0
fi

# 3) Session interactive (souple)
is_interactive=false
if [[ -n "$SSH_TTY_STR" ]]; then is_interactive=true
elif [[ -n "$PAM_TTY_STR" && "$PAM_TTY_STR" != "notty" && "$PAM_TTY_STR" != "unknown" ]]; then is_interactive=true
elif echo "$PPID_CMD" | grep -Eq 'sshd: .*@.*(pts|tty)'; then ! echo "$PPID_CMD" | grep -Eq 'notty' && is_interactive=true; fi
$is_interactive || { log_debug "exit: non-interactive"; exit 0; }

# 4) Filtres user/IP
[[ "$ONLY_ROOT" == "true" && "$USER_NAME" != "root" ]] && { log_debug "exit: ONLY_ROOT"; exit 0; }
for u in $EXCLUDE_USERS; do [[ "$USER_NAME" == "$u" ]] && { log_debug "exit: excluded user"; exit 0; }; done
[[ -z "${SSH_IP:-}" ]] && { log_debug "exit: missing SSH_IP"; exit 0; }

# 5) Type d'IP
ip_is_private(){ [[ "$1" =~ ^10\. ]] || [[ "$1" =~ ^192\.168\. ]] || [[ "$1" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$1" =~ ^127\. ]] || [[ "$1" =~ ^169\.254\. ]]; }
ip_is_cgnat(){ [[ "$1" =~ ^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\. ]]; }
IS_PRIVATE=false; IS_CGNAT=false
ip_is_private "$SSH_IP" && IS_PRIVATE=true
$IS_PRIVATE || ip_is_cgnat "$SSH_IP" && IS_CGNAT=true
CONN_TYPE="Internet (public)"; EMBED_COLOR=12976176
$IS_PRIVATE && { CONN_TYPE="LAN (privé)"; EMBED_COLOR=9807270; }
$IS_CGNAT && { CONN_TYPE="Public (CGNAT)"; EMBED_COLOR=10181046; }

# 6) Anti-doublon
CACHE_DIR="/run/ssh-notify"; mkdir -p "$CACHE_DIR" 2>/dev/null || true; chmod 0755 "$CACHE_DIR" || true
SIG="${PAMTYPE}|${USER_NAME}|${SSH_IP}|${SSH_TTY_STR:-$PAM_TTY_STR}"
HSH="$(printf '%s' "$SIG" | sha1sum | awk '{print $1}')"; FLAG="$CACHE_DIR/$HSH"
now_ts="$(date +%s)"
if [[ -f "$FLAG" ]]; then last_ts="$(stat -c %Y "$FLAG" 2>/dev/null || echo 0)"; (( now_ts - last_ts < DEDUP_WINDOW_SECS )) && { log_debug "exit: dedup"; exit 0; }; fi
printf '%s\n' "$now_ts" > "$FLAG"

# 7) Heures muettes
within_quiet_hours(){ [[ -z "$QUIET_HOURS" ]] && return 1; IFS='-' read -r H1 H2 <<<"$QUIET_HOURS"; now=$((10#$(date +%H))); H1=$((10#$H1)); H2=$((10#$H2)); (( now%=24, H1%=24, H2%=24 )); if (( H1 <= H2 )); then (( now >= H1 && now < H2 )); else (( now >= H1 || now < H2 )); fi; }
MUTED=false; within_quiet_hours && MUTED=true; $MUTED && log_debug "muted by QUIET_HOURS"

# 8) GeoIP (auto-fallback)
ISP="Unknown"; COUNTRY="Unknown"; CITY="Unknown"
geoip_lookup(){
  try_ipapi(){ data="$(curl -m "$TIMEOUT_SECS" -fsS "https://ipapi.co/${SSH_IP}/json/" || true)"; [[ -z "$data" ]] && return 1
    ISP="$(jq -r '.org // .org_name // "Unknown"' <<<"$data" 2>/dev/null || echo Unknown)"
    COUNTRY="$(jq -r '.country_name // .country // "Unknown"' <<<"$data" 2>/dev/null || echo Unknown)"
    CITY="$(jq -r '.city // "Unknown"' <<<"$data" 2>/dev/null || echo Unknown)"
    [[ "$ISP$COUNTRY$CITY" == *Unknown*Unknown*Unknown* ]] && return 1 || return 0; }
  try_ipinfo(){ data="$(curl -m "$TIMEOUT_SECS" -fsS "https://ipinfo.io/${SSH_IP}/json" || true)"; [[ -z "$data" ]] && return 1
    ISP="$(jq -r '.org // .org_name // "Unknown"' <<<"$data" 2>/dev/null || echo Unknown)"
    COUNTRY="$(jq -r '.country // "Unknown"' <<<"$data" 2>/dev/null || echo Unknown)"
    CITY="$(jq -r '.city // "Unknown"' <<<"$data" 2>/dev/null || echo Unknown)"
    [[ "$ISP$COUNTRY$CITY" == *Unknown*Unknown*Unknown* ]] && return 1 || return 0; }
  case "$GEOIP_METHOD" in
    none) return 0;;
    ipapi)  try_ipapi  || true ;;
    ipinfo) try_ipinfo || true ;;
    auto|"") try_ipapi || try_ipinfo || true ;;
    *) try_ipapi || try_ipinfo || true ;;
  esac
}

IFACE_INFO=""
if $IS_PRIVATE; then
  [[ "$LOCAL_GEOIP" == "true" ]] && geoip_lookup || { ISP="Réseau local (RFC1918)"; COUNTRY="Local"; CITY="LAN"; }
  if [[ "$SHOW_IFACE_LOCAL" == "true" ]] && command -v ip >/dev/null 2>&1; then
    if ip route get "$SSH_IP" >/dev/null 2>&1; then
      dev="$(ip route get "$SSH_IP" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
      src="$(ip route get "$SSH_IP" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
      [[ -n "$dev$src" ]] && IFACE_INFO="iface ${dev:-?}, src ${src:-?}"
    fi
  fi
else
  geoip_lookup
  $IS_CGNAT && [[ "$ISP" == "Unknown" ]] && ISP="CGNAT (souvent accès mobile/box)"
fi

# 9) Journal CSV
log_debug "journal: write -> $LOG_FILE"
printf '%s,%s,%s,%s,%s,%s,%s\n' "$TS_ISO" "$USER_NAME" "$HOSTNAME_FQDN" "$SSH_IP" "$COUNTRY" "$CITY" "$ISP" >> "$LOG_FILE" 2>>"$DEBUG_LOG" || log_debug "journal: write failed"
chmod 0640 "$LOG_FILE" 2>>"$DEBUG_LOG" || true
log_debug "journal: ok"

# 10) Discord
[[ "$MUTED" == "true" ]] && { log_debug "discord: muted"; exit 0; }
[[ -z "$WEBHOOK" ]] && { log_debug "discord: WEBHOOK empty"; exit 0; }
if $IS_PRIVATE && [[ "$LOCAL_POLICY" == "mute" ]]; then log_debug "discord: private+mute"; exit 0; fi

extra_iface=""; [[ -n "$IFACE_INFO" ]] && extra_iface="$(printf '🔧 %s\n' "$IFACE_INFO")"
desc=$(printf '**Détails**\n🔌 Type: %s\n👤 Utilisateur: `%s`\n🖥️ Hôte: `%s`\n🕐 Connexion: `%s`\n' "$CONN_TYPE" "$USER_NAME" "$HOSTNAME_SHORT" "$TS_LOCAL"; [[ -n "$SSH_TTY_STR$PAM_TTY_STR" ]] && printf '🖲️ TTY: `%s`\n' "${SSH_TTY_STR:-$PAM_TTY_STR}"; [[ -n "$extra_iface" ]] && printf '%s\n' "$extra_iface"; printf '\n**Adresse IP**\n📡 IP: `%s`\n🌎 Pays: `%s`\n🏙️ Ville: `%s`\n📠 ISP: `%s`' "$SSH_IP" "$COUNTRY" "$CITY" "$ISP")
payload=$(jq -n --arg username "$BOTNAME" --arg avatar_url "$AVATAR_URL" --arg title "SSH Login (interactive)" --arg description "$desc" --arg ts "$TS_ISO" --argjson color "$EMBED_COLOR" '{username:$username,avatar_url:$avatar_url,embeds:[{color:$color,title:$title,thumbnail:{url:$avatar_url},author:{name:$username,icon_url:$avatar_url},footer:{text:$username,icon_url:$avatar_url},description:$description,timestamp:$ts}]}')

attempt=0
until (( attempt > RETRY_COUNT )); do
  if curl -m "$TIMEOUT_SECS" -fsS -H "Content-Type: application/json" -d "$payload" "$WEBHOOK" >/dev/null; then log_debug "discord: OK"; exit 0; fi
  log_debug "discord: attempt $attempt failed"; attempt=$((attempt+1)); sleep 1
done
log_debug "discord: failed after retries"; exit 0
