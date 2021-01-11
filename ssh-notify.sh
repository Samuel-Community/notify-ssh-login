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
        WEBHOOK="votre_url"
        DATE=$(date +"%m-%d-%Y-%H:%M:%S") #Date + heure

        TMPFILE=$(mktemp) #Creation d'un fichier temporaire dans /tmp

        #~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ }


    IP=`echo $SSH_CLIENT | awk '{ ip = $1 } END { print ip }'` 
    PTR=`dig +short -x ${IP} | sed s/\.$//`


curl -s "https://ipapi.co/${IP}/json/" > $TMPFILE 

    ISP=`cat $TMPFILE | jq .org | sed s/' '//g | sed s/'"'//g`
    REGION=`cat $TMPFILE | jq -r .region`
    PAYS=`cat $TMPFILE | jq -r .country_name`

        curl -i --silent \
        -H "Accept: application/json" \
        -H "Content-Type:application/json" \
        -X POST \
        --data  '{"username": "'"$BOTNAME"'", "avatar_url": "'"$AVATAR_URL"'", 
            "embeds": [{
                    "color": 12976176, 
                    "title": "SSH-Notification",
                    "thumbnail": { "url": "'"$AVATAR_URL"'" },
                    "author": { "name": "'"$BOTNAME"'", "icon_url": "'"$AVATAR_URL"'" },
                    "footer": { "icon_url": "'"$AVATAR_URL"'", "text": "'"$BOTNAME"'" },
                    "description": "**Détails**\n \\👤 Utilisateur: '\`$(whoami)\`',\n \\🖥️ Host: '\`$(hostname)\`' \n \\🕐 Connexion: '\`$DATE\`',\n\n **Adresse IP**\n 📡 IP: '\`${IP}\`',\n \\🌎 Pays: '\`$PAYS\`',\n \\📠 ISP:  '\`${ISP}\`'"
            }]
            }' $WEBHOOK > /dev/null


# On vient verifier que le fichier temporaire est bien présent puis on le supprime {

checkdir() {
    if [ -e $TMPFILE ]; then
        rm -fr $TMPFILE
    else
        echo "le fichier $TMPFILE n'existe pas"
    fi
}
checkdir

#~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ }
