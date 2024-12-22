#!/bin/bash

#===============================================================================
# title             : ssh_notify
# description       : Notifie sur Discord lors d'une connexion SSH.
# author            : TutoRapide
# date              : 08-01-2021 (mis à jour)
# version           : 1.0.0
# usage             : placer dans /etc/profile.d/ssh-notify.sh
#===============================================================================

# Configuration
BOTNAME="SSH-Notify"
AVATAR_URL="https://icons.iconarchive.com/icons/blackvariant/button-ui-system-apps/512/Terminal-icon.png"
WEBHOOK="votre_url"
DATE=$(date +"%d-%m-%Y %H:%M:%S")

# Vérifie les dépendances
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Erreur : Les commandes 'curl' et 'jq' doivent être installées." >&2
    exit 1
fi

# Récupération des informations
IP=$(echo "$SSH_CLIENT" | awk '{print $1}')
if [ -z "$IP" ]; then
    echo "Erreur : Impossible de récupérer l'adresse IP." >&2
    exit 1
fi

TMPFILE=$(mktemp)
curl -s "https://ipapi.co/${IP}/json/" -o "$TMPFILE"

# Extraire les données de localisation
ISP=$(jq -r '.org // "Inconnu"' "$TMPFILE")
PAYS=$(jq -r '.country_name // "Inconnu"' "$TMPFILE")
VILLE=$(jq -r '.city // "Inconnu"' "$TMPFILE")

# Prépare le timestamp ISO
getCurrentTimestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Envoie la notification Discord
sendDiscordNotification() {
    curl -s -H "Content-Type: application/json" -X POST -d "{
        \"username\": \"$BOTNAME\",
        \"avatar_url\": \"$AVATAR_URL\",
        \"embeds\": [{
            \"color\": 12976176,
            \"title\": \"SSH Notification\",
            \"thumbnail\": { \"url\": \"$AVATAR_URL\" },
            \"author\": { \"name\": \"$BOTNAME\", \"icon_url\": \"$AVATAR_URL\" },
            \"footer\": { \"text\": \"$BOTNAME\", \"icon_url\": \"$AVATAR_URL\" },
            \"description\": \"**Détails**\n👤 Utilisateur: \`$(whoami)\`\n🖥️ Host: \`$(hostname)\`\n🕐 Connexion: \`$DATE\`\n\n**Adresse IP**\n📡 IP: \`$IP\`\n🌎 Pays: \`$PAYS\`\n🏙️ Ville: \`$VILLE\`\n📠 ISP: \`$ISP\`\",
            \"timestamp\": \"$(getCurrentTimestamp)\"
        }]
    }" "$WEBHOOK" > /dev/null
}

# Envoi et nettoyage
sendDiscordNotification
if [ $? -eq 0 ]; then
    echo "Notification envoyée avec succès."
else
    echo "Erreur lors de l'envoi de la notification." >&2
fi

rm -f "$TMPFILE"
