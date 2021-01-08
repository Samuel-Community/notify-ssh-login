# notify-ssh-login

### Dépendances

- [curl][curl] (http requests)
- [jq][jq] (JSON parsing)

## Usage

### 1. Mise en place d'un webhook sur discord.

1. [Configurer un webhook](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) dans le channel de texte Discord souhaité
2. Télécharger (ou cloner) une copie de `ssh-notify.sh`
3. Déplacer `ssh-notif.sh` dans `/etc/profile.d/` *mv /notify-ssh-login/ssh-notif.sh /etc/profile.d/*
4. Redémarrer votre machine