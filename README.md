<p align="center">
<img alt="SSH-NOTIFY" src="https://i.ibb.co/JvngrD9/ssh.png" width="457" height="289" >
</p>

### Dépendances

- [curl](https://curl.se)
- [jq](https://stedolan.github.io/jq/)

### 1. Mise en place du script.

1. [Configurer un webhook](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) dans le channel Discord souhaité
2. Installer les packages **JQ** et **curl** `sudo apt install jq curl -y`
3. Télécharger le project`wget https://github.com/T-TutoRapide/notify-ssh-login/ssh-notify.sh -O /etc/profile.d/ssh-notify.sh && chmod +x /etc/profile.d/ssh-notify.sh`
4. Rendre le script exécutable `chmod +x /etc/profile.d/ssh-notif.sh`
6. Ajouter le lien de votre **webhook discord** dans le script. Chercher la ligne **WEBHOOK="votre_url"** et remplacer **votre_url** par le lien du webhook.
5. Redémarrer le service ssh **sudo systemctl restart sshd**

### 2. Aperçu 

![Screenshot](https://i.ibb.co/KNtrxb2/image.png)


## Contributeurs

<table>
  <tr>
    <td align="center"><a href="https://www.youtube.com/TutoRapide"><img src="https://yt3.ggpht.com/ytc/AAUvwngzJkJHJEWz421NQonqJzaAlthI8DXuQaYJ4_002A=s900-c-k-c0x00ffffff-no-rj" width="100px;" alt=""/><br /><sub><b>TutoRapide</b></sub></a><br /><a href="https://www.youtube.com/TutoRapide" title="Code">💻</a></td>
  </tr>
</table>

Fait avec 💖 par [TutoRapide](https://discord.gg/YM9XTZP)