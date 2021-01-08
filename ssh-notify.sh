#!/bin/sh

ipP= dig +short myip.opendns.com @resolver1.opendns.com #On récupére notre ip

TMPFILE=$(mktemp)

curl -s "http://ip-api.com/json/${ipP}" > $TMPFILE  #On recupére les infomation de notre ip
 
curl --silent -v \
-H "Content-Type: application/json" \
-X POST \
-d '{"username": "SSH-Notify-Login", "avatar_url": "https://cdn.pixabay.com/photo/2018/09/15/04/31/putty-3678638_960_720.png", 
    "embeds": [{ 
            "color": 15258703, 
            "title": "SSH-INFORMATION",
            "description":  "**Détails**\n :small_blue_diamond: Utilisateur: '\`$(whoami)\`',\n :small_blue_diamond: Host: '\`$(hostname -f)\`',\n\n **Information sur ladresse ip**\n :small_orange_diamond: IP:\nIPV4:'\`${USER_IP}\`' IP-PUBLIC:'\`$(dig +short myip.opendns.com @resolver1.opendns.com)\`',\n :small_orange_diamond: Appareil '\`$(dig -x $USER_IP +short)\`',\n :small_orange_diamond: Pays: '\`$(cat $TMPFILE | jq -r .country)\`' \n :small_orange_diamond: Region: '\`$(cat $TMPFILE | jq -r .regionName)\`',\n:small_orange_diamond: Ville: '\`$(cat $TMPFILE | jq -r .city)\`',\n:small_orange_diamond: ISP: '\`$(cat $TMPFILE | jq -r .isp)\`' "
       }] 
    }' \
urlwebhook > /dev/null 2>&1 
