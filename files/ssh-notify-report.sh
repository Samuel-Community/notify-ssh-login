#!/usr/bin/env bash
# Génère un rapport sur les 7 derniers jours à partir du journal CSV,
# envoie par e-mail (si MAIL_TO) et en résumé sur Discord (si WEBHOOK).
set -Eeuo pipefail

ENV_FILE="/etc/ssh-notify/.env"
[[ -r "$ENV_FILE" ]] && source "$ENV_FILE"

LOG_FILE="${LOG_FILE:-/var/log/ssh-notify.log}"
MAIL_TO="${MAIL_TO:-}"
MAIL_FROM="${MAIL_FROM:-"ssh-notify@$(hostname -f)"}"
MAIL_SUBJECT="${MAIL_SUBJECT:-"[SSH-Notify] Rapport hebdomadaire"}"
WEBHOOK="${WEBHOOK:-}"

since_iso="$(date -u -d '7 days ago' +'%Y-%m-%dT%H:%M:%SZ')"
now_local="$(date +'%F %T')"
host="$(hostname -f 2>/dev/null || hostname)"

[[ ! -f "$LOG_FILE" ]] && exit 0

# Filtre des 7 derniers jours
mapfile -t lines < <(awk -F, -v since="$since_iso" '$1>=since' "$LOG_FILE")
total="${#lines[@]}"

# Agrégations
declare -A ipCount userCount ipFirst ipLast
for l in "${lines[@]}"; do
  ts="${l%%,*}"; rest="${l#*,}"
  user="${rest%%,*}"; rest="${rest#*,}"
  hostf="${rest%%,*}"; rest="${rest#*,}"
  ip="${rest%%,*}"
  ipCount["$ip"]=$(( ${ipCount["$ip"]:-0} + 1 ))
  userCount["$user"]=$(( ${userCount["$user"]:-0} + 1 ))
  ipFirst["$ip"]="${ipFirst["$ip"]:-$ts}"
  ipLast["$ip"]="$ts"
done

topN(){ declare -n ref="${1}Count"; for k in "${!ref[@]}"; do echo "${ref[$k]} $k"; done | sort -nr | head -5; }
top_ip="$(topN ip)"; top_user="$(topN user)"

report_text=$(cat <<EOF
Rapport SSH-Notify — $host
Période: 7 derniers jours
Généré: $now_local

Total connexions: $total

Top IP:
$(printf '%s\n' "$top_ip" | awk '{printf "  - %s (%s)\n",$2,$1}')

Top utilisateurs:
$(printf '%s\n' "$top_user" | awk '{printf "  - %s (%s)\n",$2,$1}')

Détails IP (première/dernière vue):
$(for k in "${!ipCount[@]}"; do printf "  - %s: %s hits, %s → %s\n" "$k" "${ipCount[$k]}" "${ipFirst[$k]}" "${ipLast[$k]}"; done | sort -k2nr)
EOF
)

# Envoi e-mail (si configuré et MTA dispo)
send_email(){
  command -v sendmail >/dev/null 2>&1 || command -v mail >/dev/null 2>&1 || return 1
  if command -v sendmail >/dev/null 2>&1; then
    {
      printf "From: %s\nTo: %s\nSubject: %s\nContent-Type: text/plain; charset=UTF-8\n\n" "$MAIL_FROM" "$MAIL_TO" "$MAIL_SUBJECT"
      printf "%s\n" "$report_text"
    } | sendmail -t
  else
    printf "%s\n" "$report_text" | mail -a "From: $MAIL_FROM" -s "$MAIL_SUBJECT" "$MAIL_TO"
  fi
}
[[ -n "$MAIL_TO" ]] && send_email || true

# Envoi Discord (résumé)
if [[ -n "$WEBHOOK" ]]; then
  desc=$(printf "Total: **%s** connexions (7 jours)\n\n**Top IP**\n%s\n\n**Top utilisateurs**\n%s\n" \
    "$total" \
    "$(printf '%s\n' "$top_ip"   | awk '{printf "• `%s` (%s)\n",$2,$1}')" \
    "$(printf '%s\n' "$top_user" | awk '{printf "• `%s` (%s)\n",$2,$1}')")
  payload=$(jq -n --arg title "Rapport hebdomadaire SSH ($host)" --arg description "$desc" --arg ts "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    '{ embeds: [{ color: 3447003, title: $title, description: $description, timestamp: $ts }] }')
  curl -m 6 -fsS -H "Content-Type: application/json" -d "$payload" "$WEBHOOK" >/dev/null || true
fi
