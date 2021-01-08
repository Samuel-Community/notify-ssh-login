#!/bin/sh


BOTNAME=SSH-Notify #Nom du webhook
DATE=$(date +"%m-%d-%Y-%H:%M:%S") #Date + heure

USER_IP=`echo $SSH_CLIENT | awk '{ print $1}'` #Ipv4 de l'utilisateur
ipP= dig +short myip.opendns.com @resolver1.opendns.com  #Ip de la machine

TMPFILE=$(mktemp)


curl -s "http://ip-api.com/json/${USER_IP}" > $TMPFILE 
 
curl --silent -v \
-H "Content-Type: application/json" \
-X POST \
-d '{"username": "'"$BOTNAME"'", "avatar_url": "https://icons.iconarchive.com/icons/blackvariant/button-ui-system-apps/512/Terminal-icon.png", 
    "embeds": [{ 
            "color": 12976176, 
            "title": "SSH-Notification",
            "thumbnail": {
                "url": "https://icons.iconarchive.com/icons/blackvariant/button-ui-system-apps/512/Terminal-icon.png"
            },
            "author": {
                "name": "'"$BOTNAME"'",
                "icon_url": "https://icons.iconarchive.com/icons/blackvariant/button-ui-system-apps/512/Terminal-icon.png"
            },
            "footer": {
                "icon_url": "https://icons.iconarchive.com/icons/blackvariant/button-ui-system-apps/512/Terminal-icon.png",
                "text": "'"$BOTNAME"'"
            },
            "description":  "**Détails**\n \\👤 Utilisateur: '\`$(whoami)\`',\n \\🖥️ Host: '\`$(hostname)\`' \n \\🕐 Connexion: '\`$DATE\`',\n\n **Adresse IP**\n 📡 IP: '\`${USER_IP}\`',\n \\🛰️ Appareil '\`$(dig -x $USER_IP +short)\`',\n \\🌎 Pays: '\`$(cat $TMPFILE | jq -r .country)\`' \n \\🌐 Region: '\`$(cat $TMPFILE | jq -r .regionName)\`',\n \\🔰 Ville: '\`$(cat $TMPFILE | jq -r .city)\`',\n \\📠 ISP: '\`$(cat $TMPFILE | jq -r .isp)\`' "
       }] 
    }' \
https://discord.com/api/webhooks/796733904777379840/3PcW_K5riB9IhM7v2onZ5ibOnmTSiWE-jhwiMADiNu2mcpc8RxLe50DrQS0S9DoB_69R > /dev/null 2>&1 
