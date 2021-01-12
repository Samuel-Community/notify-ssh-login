<p align="center">
<img alt="SSH-NOTIFY" src="https://i.ibb.co/JvngrD9/ssh.png" width="457" height="289" >
</p>

Ce script à pour but de vous signaler qui ce connecte sur votre serveur via une notification sur discord. Des une connexion ssh sur votre serveur.

### Dépendances

- [curl](https://curl.se)
- [jq](https://stedolan.github.io/jq/)
- [git](https://git-scm.com)

### 1. Mise en place du script.

1. [Configurer un webhook](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) dans le channel Discord souhaité
2. Installer les packages **JQ** , **curl**, **git** `sudo apt install jq curl git -y`
3. Clonez le repo `git clone https://github.com/T-TutoRapide/notify-ssh-login/`. 
5. Ce rendre dans le dossier **notify-ssh-login** `cd notify-ssh-login`.
6. Déplacer le fichier **ssh-notify.sh** dans le dossier **/etc/profile.d/** `mv ssh-notify.sh /etc/profile.d/`
7. Rendre le script exécutable `chmod +x /etc/profile.d/ssh-notify.sh`
8. Ajouter le lien de votre **webhook discord** dans le script.  
Chercher la ligne **WEBHOOK="votre_url"** et remplacer **votre_url** par le lien du webhook. `sudo nano /etc/profile.d/ssh-notify.sh`.  
Pour sauvegarder: **ctrl +x** taper **y**  
9. Redémarrer le service ssh **sudo systemctl restart sshd**
10. Et voila le tour est joué.

### 2. Aperçu 

![Screenshot](https://i.ibb.co/PcJxGD7/image.png)


## Contributeurs

<table>
  <tr>
    <td align="center"><a href="https://www.youtube.com/TutoRapide"><img src="https://yt3.ggpht.com/ytc/AAUvwngzJkJHJEWz421NQonqJzaAlthI8DXuQaYJ4_002A=s900-c-k-c0x00ffffff-no-rj" width="100px;" alt=""/><br /><sub><b>TutoRapide</b></sub></a><br /><a href="https://www.youtube.com/TutoRapide" title="Code">💻</a></td>
  </tr>
</table>

Fait avec 💖 par [TutoRapide](https://discord.gg/YM9XTZP)
