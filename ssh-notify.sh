#!/bin/sh

#
# title             : ssh_notify
# description       : Notification lors d'une connexion ssh.
# author            : TutoRapide
# date              : 08-01-2021
# version           : 0.1.0
# usage             : placer dans /etc/profile.d/ssh-notify.sh
#===============================================================================

   # Config {

        BOTNAME=SSH-Notify #Nom du webhook
        AVATAR_URL="https://icons.iconarchive.com/icons/blackvariant/button-ui-system-apps/512/Terminal-icon.png"
        WEBHOOK="https://discord.com/api/webhooks/796733904777379840/3PcW_K5riB9IhM7v2onZ5ibOnmTSiWE-jhwiMADiNu2mcpc8RxLe50DrQS0S9DoB_69R"
        DATE=$(date +"%m-%d-%Y-%H:%M:%S") #Date + heure

        TMPFILE=$(mktemp) #Creation d'un fichier temporaire dans /tmp

        IGNORED_USERS="git" #Définir la liste des utilisateurs à ignorer, espacer les utilisateur ou , pour séparer les utilisateurs


        #~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ }

    IP=`echo $SSH_CLIENT | awk '{ ip = $1 } END { print ip }'` 
    PTR=`dig +short -x ${IP} | sed s/\.$//`

TMPFILE=$(mktemp)

curl -s "http://ip-api.com/json/${PTR}" > $TMPFILE 
 
curl --silent -v \
-H "Content-Type: application/json" \
-X POST \
-d '{"username": "'"$BOTNAME"'", "avatar_url": "'"$AVATAR_URL"'", 
    "embeds": [{ 
            "color": 12976176, 
            "title": "SSH-Notification",
            "thumbnail": {
                "url": "'"$AVATAR_URL"'"
            },
            "author": {
                "name": "'"$BOTNAME"'",
                "icon_url": "'"$AVATAR_URL"'"
            },
            "footer": {
                "icon_url": "'"$AVATAR_URL"'",
                "text": "'"$BOTNAME"'"
            },
            "description":  "**Détails**\n \\👤 Utilisateur: '\`$(whoami)\`',\n \\🖥️ Host: '\`$(hostname)\`' \n \\🕐 Connexion: '\`$DATE\`',\n\n **Adresse IP**\n 📡 IP: '\`${IP}\`',\n \\🌎 Pays: '\`$(cat $TMPFILE | jq -r .country)\`' \n \\🌐 Region: '\`$(cat $TMPFILE | jq -r .regionName)\`',\n \\🔰 Ville: '\`$(cat $TMPFILE | jq -r .city)\`',\n \\📠 ISP: '\`$(cat $TMPFILE | jq -r .isp)\`' "
       }] 
    }' \
$WEBHOOK > /dev/null 2>&1 
