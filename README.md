<p align="center">
<img alt="SSH-NOTIFY" src="https://i.ibb.co/JvngrD9/ssh.png" width="457" height="289" >
</p>

# SSH-Notify

**SSH-Notify** envoie une notification Discord à chaque **connexion SSH interactive** (shell) sur votre serveur — plus de spam lors des transferts **SFTP/SCP/rsync**.

* ✅ Hook **PAM `open_session`** (fiable, idempotent)
* ⚙️ **Installateur / désinstalleur** (avec options)
* 🧩 **`.env`** pour toute la configuration
* 🧾 **Log CSV** + **logrotate**
* 📅 **Rapport hebdomadaire** (systemd timer + e-mail optionnel)
* 🌐 **GeoIP** configurable (ipapi/ipinfo/none)
* 💤 **Heures muettes** + anti-doublon
* 🛡️ Politique **LAN** (label/mute/notify)

---

## 🆕 Quoi de neuf (par rapport à l’ancien script v1.x)

* Passage d’un script dans `/etc/profile.d` → à un **hook PAM** (pas de doublons, plus robuste)
* **Filtrage strict** des transferts : SFTP / SCP / rsync **ignorés**
* Installation simplifiée : `ssh-notify-install.sh` copie les binaires, ajoute le hook PAM, installe le timer et le logrotate, crée `.env`
* **.env** centralise le webhook, les heures muettes, la politique LAN, etc.
* **Rapport hebdo** via Discord et/ou e-mail (bientôt)
* **Logs** en CSV + rotation automatique

---

## 📦 Dépendances

* [curl](https://curl.se)
* [jq](https://stedolan.github.io/jq/)
* (optionnel) [mailutils](https://mailutils.org/) pour l’e-mail hebdomadaire
* (pour installer depuis Git) [git](https://git-scm.com)

Sous Debian/Ubuntu :

```bash
sudo apt update
sudo apt install -y curl jq mailutils git
```

---

## 🚀 Installation

1. Cloner le projet :

```bash
git clone https://github.com/T-TutoRapide/notify-ssh-login
cd notify-ssh-login
```

2. Lancer l’install (vous pouvez fournir le webhook en CLI ou le saisir au prompt) :

```bash
# mode interactif (posera la question si WEBHOOK vide)
sudo bash ./ssh-notify-install.sh

# ou silencieux avec webhook fourni
sudo bash ./ssh-notify-install.sh -y --webhook "https://discord.com/api/webhooks/ID/TOKEN"
```

Ce que fait l’installateur :

* Copie `files/ssh-notify.sh` et `files/ssh-notify-report.sh` → `/usr/local/bin/`
* Ajoute le hook PAM dans `/etc/pam.d/sshd` :

  ```
  session optional pam_exec.so seteuid /usr/local/bin/ssh-notify.sh
  ```
* Crée `/etc/ssh-notify/.env` depuis `.env.example`
* Installe `ssh-notify-weekly.service` + `ssh-notify-weekly.timer` (rapport chaque dimanche 06:00)
* Installe `/etc/logrotate.d/ssh-notify`

---

## ⚙️ Configuration ( `/etc/ssh-notify/.env` )

Les clés importantes :

```ini
WEBHOOK=""                  # URL Discord
QUIET_HOURS="23-6"          # heures muettes (vide = désactivé)
LOCAL_POLICY="label"        # label | mute | notify (comportement en LAN)
GEOIP_METHOD="ipapi"        # ipapi | ipinfo | none
EXCLUDE_USERS="backup www-data"
ONLY_ROOT=false

LOG_FILE="/var/log/ssh-notify.log"
DEBUG_LOG="/var/log/ssh-notify.debug.log"
DEBUG=false                 # true pour diagnostiquer, puis remettre false

# E-mail hebdo (optionnel)
MAIL_TO=""
MAIL_FROM="ssh-notify@$(hostname -f)"
MAIL_SUBJECT="[SSH-Notify] Rapport hebdomadaire"
```

* **LOCAL\_POLICY**

  * `label` : notifie et indique “LAN (privé)”
  * `mute` : **ne pas** envoyer sur Discord en LAN (log CSV conservé)
  * `notify` : notifie comme une IP publique
* **QUIET\_HOURS** : plage d’heures à **ne pas** notifier (ex. `23-6`).

---

## 🧪 Tests rapides

```bash
# Simuler une connexion interactive (doit notifier)
PAM_TYPE=open_session PAM_USER=$USER PAM_RHOST=8.8.8.8 SSH_TTY=/dev/pts/1 /usr/local/bin/ssh-notify.sh

# Simuler un transfert (NE DOIT PAS notifier)
PAM_TYPE=open_session PAM_USER=$USER PAM_RHOST=8.8.8.8 SSH_ORIGINAL_COMMAND='scp -t /tmp' /usr/local/bin/ssh-notify.sh
```

Vérifier les journaux :

```bash
tail -n 50 /var/log/ssh-notify.log
tail -n 50 /var/log/ssh-notify.debug.log
```

---

## 🔁 Rapport hebdomadaire

Un timer systemd lance `/usr/local/bin/ssh-notify-report.sh` chaque **dimanche 06:00** :

* Résumé envoyé sur Discord (si `WEBHOOK` est défini)
* Envoi e-mail si `MAIL_TO` est renseigné et `mailutils` installé

Gérer le timer :

```bash
systemctl status ssh-notify-weekly.timer
systemctl list-timers | grep ssh-notify
```

---

## 🧾 Logrotate

Installé automatiquement dans `/etc/logrotate.d/ssh-notify` pour :

* ` /var/log/ssh-notify.log`
* ` /var/log/ssh-notify.debug.log`

Rotation **hebdomadaire**, 12 archives, compression activée.

Tester une rotation :

```bash
sudo logrotate -v -f /etc/logrotate.d/ssh-notify
```

---

## ❌ Désinstallation

```bash
# supprime scripts, .env, PAM, systemd, logrotate
sudo bash ./ssh-notify-install.sh --remove

# variantes
sudo bash ./ssh-notify-install.sh --remove --keep-log
sudo bash ./ssh-notify-install.sh --remove --purge-packages   # (Debian/Ubuntu) supprime curl jq mailutils
```

---

## 🐞 Dépannage

* Activer le debug :

  ```bash
  sudo sed -i 's/^DEBUG=.*/DEBUG=true/' /etc/ssh-notify/.env
  ```

  Puis regarder : `/var/log/ssh-notify.debug.log`

* Vérifier le hook PAM :

  ```bash
  tail -n +1 /etc/pam.d/sshd | grep -n 'ssh-notify.sh'
  ```

* Purger l’anti-doublon (si tests rapprochés) :

  ```bash
  sudo rm -f /run/ssh-notify/*
  ```

* Heures muettes actives ? Mettre `QUIET_HOURS=""` pour tester.

---

## ️👀 Aperçu

![Screenshot](https://media.tutorapide.xyz/TW770ZtD1CFC.png)

---

Fait avec 💖 par [TutoRapide](https://discord.gg/YM9XTZP)

---

Tu veux que je te génère aussi un **CHANGELOG.md** ou un **badge de version** (ex. v2.0) pour le repo ?
