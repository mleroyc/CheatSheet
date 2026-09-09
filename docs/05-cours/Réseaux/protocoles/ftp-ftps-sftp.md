---
title: "Protocoles de transfert de fichiers : FTP, FTPS et SFTP"
description: "Anatomie comparative des protocoles FTP, FTPS et SFTP, modes Actif/Passif, sécurité TLS/SSH et vecteurs d'attaque associants."
tags:
  - ftp
  - ftps
  - sftp
  - ssh
  - tls
  - network
  - security
  - pentest
  - hardening
  - red-team
  - blue-team
---

# Protocoles de Transfert de Fichiers : FTP, FTPS et SFTP

!!! warning "Cadre légal"
    Les techniques d'audit et d'exploitation présentées dans cette fiche sont réservées à des contextes légaux explicites : tests d'intrusion contractuels, CTF et labos personnels. Toute utilisation sans autorisation écrite du propriétaire du système cible constitue une infraction pénale.

---

## 1. Résumé Exécutif & Définition

### Clarification des trois protocoles

!!! danger "Confusion fréquente — SFTP ≠ FTPS"
    Ces deux protocoles sont radicalement différents et souvent confondus. **FTPS** est du FTP avec une couche SSL/TLS ajoutée par-dessus. **SFTP** n'a aucun lien avec FTP — c'est un sous-système du protocole **SSH** qui n'existe que sur le port 22. Partager ces deux noms ne reflète qu'une ressemblance phonétique, pas une parenté technique.

| Protocole | Couche de base | Chiffrement | Ports | Canal de données séparé |
| --- | --- | --- | --- | --- |
| **FTP** | TCP | Aucun — tout en clair | 21 (contrôle), 20 / dynamique (données) | Oui |
| **FTPS Explicite** | TCP + TLS | TLS (négocié via `AUTH TLS`) | 21 (contrôle), dynamique (données) | Oui |
| **FTPS Implicite** | TCP + TLS | TLS (dès la connexion) | 990 (contrôle), 989 (données) | Oui |
| **SFTP** | SSH | SSH (chiffrement intégral) | 22 | Non — canal unique |

**FTP** (*File Transfer Protocol*) — RFC 959, 1985 :
Protocole historique de transfert de fichiers en texte clair. Toutes les commandes, réponses, identifiants et données transitent sans aucun chiffrement. Encore présent en environnements legacy et comme cible d'audit courant en pentest.

**FTPS** (*FTP Secure* / *FTP-SSL*) — RFC 4217 :
Surcouche SSL/TLS ajoutée au protocole FTP existant. Deux variantes : Explicite (le client demande explicitement le chiffrement via `AUTH TLS` sur le port 21) et Implicite (connexion TLS immédiate sur le port 990). Le double canal de FTP subsiste, créant des complications de pare-feu.

**SFTP** (*SSH File Transfer Protocol*) — Draft IETF / RFC 4253 :
Sous-système du protocole SSH, activé via la directive `Subsystem sftp` dans `sshd_config`. Ne partage aucune commande, aucun port ni aucun mécanisme avec FTP. Canal unique chiffré, authentification par clé SSH ou mot de passe, traversée NAT/pare-feu simplifiée.

---

## 2. Anatomie & Fonctionnement Interne

### 2.1 Le Protocole FTP — Double Canal

#### Architecture des canaux

```
CLIENT                              SERVEUR
  |                                    |
  |--- TCP SYN → port 21 ------------>|  ← Canal de CONTRÔLE
  |<-- 220 Service ready --------------|    (commandes + réponses)
  |--- USER alice -------------------->|
  |<-- 331 Password required ----------|
  |--- PASS secret ------------------->|
  |<-- 230 Login successful -----------|
  |                                    |
  |--- PORT 192,168,1,10,20,5 ------->|  ← Commande d'ouverture canal DONNÉES
  |    (Mode Actif : h1,h2,h3,h4,p1,p2)|   (Mode Actif)
  |                                    |
  |<-- TCP SYN depuis port 20 ---------|  ← Canal de DONNÉES
  |    (le SERVEUR initie vers le      |    (transfert de fichier ou LIST)
  |     port indiqué par le CLIENT)    |
```

!!! note "Deux connexions TCP distinctes pour un seul transfert"
    Contrairement à la majorité des protocoles réseau, FTP nécessite **deux connexions TCP simultanées** : une pour les commandes/réponses (canal de contrôle, port 21) et une pour chaque transfert de fichier ou liste de répertoire (canal de données, port dynamique). Cette architecture est la source principale des difficultés de traversée de pare-feu/NAT.

#### Mode Actif (PORT)

```
CLIENT                              SERVEUR
Port aléatoire > 1023               Port 21 (contrôle)
                                    Port 20 (données)

1. Client → Serveur port 21 :  TCP SYN   (connexion de contrôle)
2. Client → Serveur port 21 :  PORT 192,168,1,10,201,5
   (indique IP+port d'écoute : 192.168.1.10 port 51461 = 201*256+5)
3. SERVEUR → CLIENT port 51461 :  TCP SYN depuis port 20
   (le serveur initie la connexion de données VERS le client)
```

!!! warning "Mode Actif — Problème avec les pare-feux et NAT"
    En Mode Actif, c'est le **serveur** qui initie la connexion de données vers le client. Cela pose deux problèmes : (1) Le pare-feu du client bloque généralement les connexions entrantes inattendues. (2) Si le client est derrière un NAT, l'adresse IP fournie dans `PORT` est une adresse privée non routable depuis Internet. **Le Mode Actif est quasi-inutilisable depuis des réseaux NAT modernes.**

#### Mode Passif (PASV)

```
CLIENT                              SERVEUR
Port aléatoire > 1023               Port 21 (contrôle)
                                    Port dynamique (données)

1. Client → Serveur port 21 :  TCP SYN   (connexion de contrôle)
2. Client → Serveur port 21 :  PASV
3. Serveur → Client :          227 Entering Passive Mode (192,168,1,100,195,149)
   (indique IP+port d'écoute du serveur : 192.168.1.100 port 50069 = 195*256+149)
4. CLIENT → SERVEUR port 50069 :  TCP SYN
   (le client initie la connexion de données VERS le serveur)
```

!!! tip "Mode Passif — Standard recommandé pour traverser les pare-feux"
    En Mode Passif, c'est le **client** qui initie la connexion de données — exactement comme toute connexion sortante standard. Les pare-feux et NAT côté client n'ont aucun blocage à effectuer. Le serveur doit en revanche ouvrir une plage de ports dynamiques dans son pare-feu. **Toujours utiliser le Mode Passif pour les transferts depuis des réseaux clients non contrôlés.**

#### EPSV — Extended Passive Mode (IPv6 et IPv4 amélioré)

```bash
# EPSV — version étendue de PASV, compatible IPv4 et IPv6
# Réponse : 229 Entering Extended Passive Mode (|||50123|)
# Le format (|||port|) évite les problèmes d'adressage IPv6 de PASV

# Forcer le mode EPSV avec curl
curl --ftp-pasv ftp://user:pass@ftp.example.com/fichier.txt
```

### 2.2 FTPS — Superposition SSL/TLS

#### FTPS Explicite (AUTH TLS / FTPES) — Port 21

```
CLIENT                              SERVEUR
  |                                    |
  |--- TCP SYN → port 21 ------------>|  ← Connexion en CLAIR d'abord
  |<-- 220 FTP server ready -----------|
  |--- AUTH TLS -----------------------|  ← Demande explicite de TLS
  |<-- 234 AUTH TLS OK ---------------|  ← Serveur accepte
  |=== Handshake TLS ================|  ← Passage en chiffré
  |--- USER alice -------------------->|  ← Authentification désormais chiffrée
  |<-- 331 Password required ----------|
  |--- PASS secret ------------------->|
  |<-- 230 Login successful -----------|
```

!!! note "AUTH TLS vs AUTH SSL"
    `AUTH TLS` est la commande standardisée (RFC 4217) pour activer FTPS Explicite et utilise TLSv1.2 ou TLSv1.3 selon la configuration du serveur. `AUTH SSL` est l'ancienne commande pour SSLv3 (déprécié et vulnérable — ne jamais utiliser). Sur les serveurs modernes, seul `AUTH TLS` doit être accepté.

#### FTPS Implicite — Port 990/989

```
CLIENT                              SERVEUR
  |                                    |
  |--- TCP SYN → port 990 ----------->|  ← La connexion est chiffrée DÈS le départ
  |=== Handshake TLS immédiat ========|  ← Pas de négociation préalable en clair
  |<-- 220 FTP server ready -----------|  ← Tout est chiffré dès ce message
  |--- USER alice -------------------->|
  |<-- 331 Password required ----------|
  |--- PASS secret ------------------->|
```

#### Canaux de données FTPS — Complication pare-feu

```
PROBLÈME SPÉCIFIQUE AU MODE PASSIF FTPS :

1. Canal de contrôle (port 21 ou 990) : chiffré via TLS
2. Canal de données (port dynamique) : AUSSI chiffré via TLS
   → Les pare-feux "Application Aware" qui inspectent les commandes FTP
     pour ouvrir dynamiquement les ports de données NE PEUVENT PAS lire
     les commandes PASV/EPSV chiffrées
   → Résultat : le canal de données est bloqué par les pare-feux intermédiaires
     SAUF si une plage de ports de données est explicitement ouverte en statique
```

!!! warning "FTPS et les pare-feux stateful — Piège de configuration"
    Un pare-feu qui comprend FTP en clair ne comprend pas les commandes PASV/PORT dans un flux FTPS chiffré. Il ne peut donc pas ouvrir dynamiquement le port de données. Il faut impérativement configurer une plage de ports statique pour les données FTPS sur le serveur (ex: `pasv_min_port=50000`, `pasv_max_port=50100` dans vsftpd) **et** ouvrir cette plage dans le pare-feu.

### 2.3 Le Protocole SFTP — Canal Unique SSH

#### Architecture SSH/SFTP

```
CLIENT                              SERVEUR
  |                                    |
  |--- TCP SYN → port 22 ------------>|  ← UN SEUL canal TCP
  |=== Handshake SSH (KEX + Auth) ===|  ← Chiffrement intégral dès le début
  |--- Subsystem SFTP request ------->|  ← Activation du sous-système SFTP
  |<-- Subsystem SFTP confirmed -------|
  |=== Protocole SFTP (binaire) ======|  ← Transferts dans le canal SSH existant
  |    INIT / VERSION                  |
  |    OPEN / READ / WRITE / CLOSE     |
  |    OPENDIR / READDIR               |
  |    STAT / LSTAT / RENAME / REMOVE  |
```

!!! tip "SFTP vs SCP vs rsync"
    | Outil | Protocole sous-jacent | Canal | Cas d'usage |
    | --- | --- | --- | --- |
    | `sftp` | SSH Subsystem SFTP | Unique SSH | Navigation interactive, transfert sécurisé |
    | `scp` | SSH + protocole SCP (ancien) | Unique SSH | Copie de fichiers rapide (déprécié dans OpenSSH 9.0+) |
    | `rsync -e ssh` | SSH + protocole rsync | Unique SSH | Synchronisation de répertoires avec delta |

#### Authentification SSH pour SFTP

```bash
# Génération d'une paire de clés Ed25519 (recommandé — plus court, plus sûr que RSA 2048)
ssh-keygen -t ed25519 -C "sftp-user@client-machine" -f ~/.ssh/sftp_ed25519

# Déploiement de la clé publique sur le serveur SFTP
ssh-copy-id -i ~/.ssh/sftp_ed25519.pub sftp-user@sftp.example.com

# Connexion SFTP avec clé explicite
sftp -i ~/.ssh/sftp_ed25519 sftp-user@sftp.example.com

# Générer une clé RSA 4096 si Ed25519 non supporté (serveurs anciens)
ssh-keygen -t rsa -b 4096 -C "sftp-user" -f ~/.ssh/sftp_rsa
```

---

## 3. Matrice Comparative

| Critère | FTP | FTPS Explicite | FTPS Implicite | SFTP |
| --- | --- | --- | --- | --- |
| **Port(s) contrôle** | 21 | 21 | 990 | 22 |
| **Port(s) données** | 20 / dynamique | Dynamique | 989 / dynamique | N/A (canal unique) |
| **Protocole sous-jacent** | TCP | TCP + TLS | TCP + TLS | SSH |
| **Chiffrement** | Aucun | TLS 1.2/1.3 (après AUTH TLS) | TLS 1.2/1.3 (immédiat) | SSH (AES, ChaCha20) |
| **Identifiants en clair** | Oui | Non (après TLS) | Non (depuis le début) | Non |
| **Canaux séparés** | Oui (contrôle + données) | Oui | Oui | Non |
| **Traversée NAT** | Mode Passif requis | Mode Passif requis | Mode Passif requis | Transparente |
| **Compatibilité pare-feux** | Bonne (avec stateful) | Difficile (chiffré) | Difficile (chiffré) | Excellente (port 22) |
| **Authentification** | Login/Password | Login/Password + certificat | Login/Password + certificat | Password ou clé SSH |
| **Interopérabilité** | Universelle | Large | Moins répandu | Universelle (SSH) |
| **Recommandation** | ❌ Obsolète | ⚠️ Acceptable sous contrainte | ⚠️ Acceptable sous contrainte | ✅ Recommandé |

---

## 4. Empreinte, Audit & Méthodologie d'Exploitation

### 4.1 Codes de Réponse FTP

| Code | Signification |
| --- | --- |
| `220` | Service ready (bannière serveur — révèle souvent la version) |
| `331` | Username OK, password required |
| `230` | Login successful |
| `530` | Login incorrect (authentication failed) |
| `421` | Service not available, closing control connection |
| `227` | Entering Passive Mode (IP,port dans la réponse) |
| `200` | Command OK |
| `215` | SYST reply — révèle l'OS du serveur |
| `550` | File unavailable (permission denied ou inexistant) |

### 4.2 Énumération avec Nmap

```bash
# Détection de version et OS sur les ports FTP/SFTP courants
nmap -sV -sC -p 21,22,990 --open target.com

# Scripts NSE dédiés FTP
nmap --script ftp-anon,ftp-syst,ftp-bounce,ftp-brute -p 21 target.com

# ftp-anon : teste l'accès anonyme automatiquement
nmap --script ftp-anon -p 21 target.com
# Output si vulnérable :
# 21/tcp open  ftp
# | ftp-anon: Anonymous FTP login allowed (FTP code 230)
# |_drwxr-xr-x  ...

# ftp-syst : interroge SYST pour identifier l'OS
nmap --script ftp-syst -p 21 target.com
# Output possible :
# | ftp-syst:
# |   STAT: Microsoft FTP Service
# |_  syst: Windows_NT

# ftp-bounce : teste si le serveur est utilisable comme rebond de scan
nmap --script ftp-bounce -p 21 target.com
```

### 4.3 Connexion FTP Anonyme

```bash
# Tentative de connexion anonyme en FTP CLI
ftp target.com
# À l'invite :
# Name: anonymous
# Password: anonymous   (ou email ou laisser vide)

# Via curl — accès anonyme direct
curl ftp://target.com/ --user anonymous:anonymous -v

# Lister récursivement le contenu du serveur FTP anonyme
curl ftp://target.com/ --user anonymous:anonymous --list-only
wget -r --user=anonymous --password=anonymous ftp://target.com/

# Télécharger un fichier spécifique en anonyme
curl ftp://target.com/fichier.txt --user anonymous: -o fichier.txt
```

### 4.4 Capture d'Identifiants FTP en Clair (Sniffing)

```bash
# Capture tcpdump du trafic FTP en clair sur le port 21
sudo tcpdump -i eth0 port 21 -A -w ftp_capture.pcap

# Filtrer les commandes d'authentification dans la capture
tcpdump -r ftp_capture.pcap -A | grep -iE "USER|PASS"

# Wireshark — filtre d'affichage pour extraire les identifiants FTP
# Display Filter : ftp.request.command == "USER" or ftp.request.command == "PASS"
# Suivre le flux TCP pour voir l'échange complet : clic droit → Follow → TCP Stream
```

!!! danger "FTP = capture d'identifiants triviale"
    Sur un réseau local partagé (switch non segmenté, réseau Wi-Fi partagé, ARP Spoofing préalable), la capture d'identifiants FTP est immédiate et triviale. Un seul fichier PCAP contenant du trafic FTP suffit à exposer tous les comptes et mots de passe utilisés. Aucune authentification FTP ne doit jamais transiter sur un réseau non totalement isolé et de confiance.

### 4.5 FTP Bounce Attack

```bash
# La commande PORT permet de spécifier une IP/port ARBITRAIRE pour la connexion de données
# Un serveur FTP vulnérable peut être utilisé comme proxy pour scanner d'autres hôtes internes

# Principe :
# 1. Se connecter au serveur FTP
# 2. Envoyer PORT avec l'IP d'une cible interne et le port à tester
# 3. Envoyer LIST : le serveur tente une connexion de données vers la cible interne
# 4. Le code de retour révèle si le port est ouvert (200/150) ou fermé (425/550)

# Détection de la vulnérabilité
nmap --script ftp-bounce -p 21 target.com

# Exploitation manuelle (connexion telnet au port 21)
telnet ftp.target.com 21
# > USER anonymous
# > PASS anonymous
# > PORT 10,0,0,1,0,22    (cible interne 10.0.0.1, port 22 = 0*256+22)
# > LIST
# 200/150 → port 22 ouvert sur 10.0.0.1
# 425     → port fermé
```

!!! note "FTP Bounce — Contexte historique"
    L'attaque FTP Bounce (RFC 2577) permettait classiquement de scanner des réseaux internes depuis l'extérieur en utilisant un serveur FTP comme pivot. La majorité des serveurs FTP modernes rejettent les commandes `PORT` pointant vers des adresses IP différentes de celle du client connecté. Mais des serveurs legacy ou mal configurés restent exploitables.

### 4.6 Brute-Force d'Identifiants

```bash
# Brute-force FTP avec Hydra
hydra -l admin -P /usr/share/wordlists/rockyou.txt ftp://target.com -t 4

# Brute-force FTP avec liste d'utilisateurs
hydra -L users.txt -P passwords.txt ftp://target.com -t 4

# Brute-force SSH/SFTP avec Hydra
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://target.com -t 4

# Medusa — alternative à Hydra pour FTP
medusa -h target.com -u admin -P /usr/share/wordlists/rockyou.txt -M ftp
```

!!! warning "Rate-limiting et lockout sur SSH/SFTP"
    La plupart des serveurs SSH modernes intègrent un rate-limiting natif (fail2ban, MaxAuthTries) qui bloque les brute-forces rapides. Sur FTP, ces protections sont moins systématiques. Adapter la vitesse (`-t 1`) et l'intervalle (`-W 3`) pour éviter les blocages prématurés.

### 4.7 Misconfiguration SFTP — Évasion de Chroot

```bash
# Vérifier si le ChrootDirectory est mal configuré :
# La restriction chroot exige que le répertoire chroot soit possédé par ROOT
# et ne soit PAS modifiable par l'utilisateur.
# Si ce n'est pas le cas, l'utilisateur peut écrire des binaires SUID ou des shared libs

# Vérification côté serveur
ls -la /var/sftp/         # Le répertoire doit appartenir à root:root avec permissions 755 max
ls -la /var/sftp/uploads/ # Le sous-répertoire accessible peut appartenir à l'utilisateur

# Test d'évasion : si l'utilisateur peut écrire dans son répertoire chroot
# et si les liens symboliques ne sont pas bloqués, il peut accéder à des fichiers hors chroot
sftp -i key.pem sftp-user@target.com
sftp> symlink /etc/passwd /home/sftp-user/passwd_leak
sftp> get passwd_leak   # Tente de lire /etc/passwd via le lien symbolique
```

---

## 5. Hardening & Remédiation

### 5.1 vsftpd — Sécurisation FTP/FTPS

```ini
# /etc/vsftpd.conf — Configuration sécurisée vsftpd

# --- Désactivation des accès anonymes ---
anonymous_enable=NO          # Interdit toute connexion anonyme
anon_upload_enable=NO        # (défense en profondeur si anonymous_enable était YES)
anon_mkdir_write_enable=NO

# --- Sécurisation des comptes locaux ---
local_enable=YES             # Autorise les comptes locaux
write_enable=YES             # Autorise les écritures (ajuster selon les besoins)
local_umask=022              # Permissions sur les fichiers uploadés

# --- Confinement Chroot ---
chroot_local_user=YES        # Confine chaque utilisateur dans son home
chroot_list_enable=NO        # Pas d'exceptions
allow_writeable_chroot=NO    # CRITIQUE : interdit que le répertoire chroot soit writable
                             # Si le home doit être writable, créer un sous-dossier

# --- Mode Passif et ports de données ---
pasv_enable=YES
pasv_min_port=50000          # Plage de ports PASV — à ouvrir dans le pare-feu
pasv_max_port=50100
pasv_address=203.0.113.10    # IP publique du serveur (si derrière NAT)

# --- Chiffrement FTPS Explicite ---
ssl_enable=YES
ssl_tlsv1_2=YES              # Activer TLS 1.2
ssl_tlsv1_3=YES              # Activer TLS 1.3
ssl_sslv2=NO                 # Désactiver SSLv2 (vulnérable)
ssl_sslv3=NO                 # Désactiver SSLv3 (vulnérable - POODLE)
rsa_cert_file=/etc/ssl/certs/vsftpd.crt
rsa_private_key_file=/etc/ssl/private/vsftpd.key
force_local_logins_ssl=YES   # Force TLS pour l'authentification
force_local_data_ssl=YES     # Force TLS pour les données

# --- Restrictions générales ---
max_per_ip=3                 # Maximum 3 connexions par IP
max_login_fails=3            # Blocage après 3 échecs d'auth
banner_file=/etc/vsftpd_banner.txt  # Bannière neutre sans info de version
ftpd_banner=Welcome.         # Alternative à banner_file
hide_ids=YES                 # Affiche ftp:ftp au lieu du vrai propriétaire
```

### 5.2 OpenSSH — Confinement SFTP strict

```bash
# /etc/ssh/sshd_config — Bloc de configuration pour le sous-système SFTP

# Sous-système SFTP interne (intégré à OpenSSH, recommandé)
Subsystem sftp internal-sftp

# Groupe dédié SFTP
Match Group sftpusers
    # ForceCommand : interdit le shell SSH, autorise SEULEMENT le sous-système SFTP
    ForceCommand internal-sftp -l VERBOSE -u 0022

    # ChrootDirectory : confine l'utilisateur dans ce répertoire
    # OBLIGATOIRE : le répertoire doit appartenir à root:root, permissions max 755
    ChrootDirectory /var/sftp/%u

    # Désactiver tout le forwarding (tunnels SSH, X11, agents)
    AllowTcpForwarding no
    AllowAgentForwarding no
    X11Forwarding no
    PermitTunnel no

    # Optionnel : restreindre aux clés SSH uniquement (pas de mot de passe)
    PasswordAuthentication no
```

```bash
# Création d'un utilisateur SFTP conforme au hardening ci-dessus
groupadd sftpusers

useradd -m -s /sbin/nologin -G sftpusers sftp-alice
# /sbin/nologin : empêche les connexions shell directes

# Configuration correcte du chroot
mkdir -p /var/sftp/sftp-alice/uploads
chown root:root /var/sftp/sftp-alice/  # ROOT doit posséder le chroot
chmod 755 /var/sftp/sftp-alice/        # Max 755 — pas writable par l'user
chown sftp-alice:sftpusers /var/sftp/sftp-alice/uploads/
chmod 755 /var/sftp/sftp-alice/uploads/  # Writable par l'user si nécessaire

# Rechargement de la configuration SSH
systemctl reload sshd

# Test de la configuration
sftp sftp-alice@localhost
# Tentative de shell devrait échouer :
ssh sftp-alice@localhost
# → This service allows sftp connections only.
```

```bash
# Vérification des permissions du chroot (erreur courante)
# Si sshd retourne "bad ownership or modes for chroot directory",
# vérifier :
ls -la /var/sftp/  # root:root, max 755
ls -la /var/sftp/sftp-alice/  # root:root, max 755
```

!!! danger "Erreur critique — Chroot writable par l'utilisateur"
    Si le répertoire `ChrootDirectory` (ou l'un de ses parents) est modifiable par l'utilisateur confiné, ce dernier peut y créer des fichiers `.so` (shared libraries) ou des binaires SUID qui lui permettront d'élever ses privilèges et d'échapper au chroot. OpenSSH refuse d'ailleurs d'activer un chroot si le répertoire n'appartient pas à root — mais des erreurs de configuration sur les sous-répertoires restent possibles.

### 5.3 Règles de pare-feu pour FTPS Passif

```bash
# iptables — Autoriser le canal de contrôle FTPS et la plage de ports passifs
# Canal de contrôle FTPS Explicite
iptables -A INPUT -p tcp --dport 21 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 21 -m state --state ESTABLISHED -j ACCEPT

# Canal de données FTPS Passif (plage définie dans vsftpd.conf)
iptables -A INPUT -p tcp --dport 50000:50100 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --sport 50000:50100 -m state --state ESTABLISHED -j ACCEPT

# SFTP — Un seul port
iptables -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
```

```bash
# nftables — Équivalent moderne
nft add rule ip filter input tcp dport 21 ct state new,established accept
nft add rule ip filter input tcp dport 50000-50100 ct state new,established accept
nft add rule ip filter input tcp dport 22 ct state new,established accept
```

---

## 6. Anti-Sèche Commandes CLI

### 6.1 Commandes FTP Interactives

```bash
# Connexion FTP en ligne de commande
ftp target.com
ftp -n target.com   # -n : pas de connexion automatique (utile pour des scripts)

# Commandes dans le shell FTP interactif
# open HOST        → connexion à un serveur
# user USER        → authentification
# ls / dir         → liste le répertoire distant
# cd DIR           → changer de répertoire distant
# lcd DIR          → changer de répertoire LOCAL
# get FILE         → télécharger un fichier
# put FILE         → uploader un fichier
# mget *.txt       → télécharger plusieurs fichiers avec wildcard
# mput *.log       → uploader plusieurs fichiers
# binary           → mode binaire (OBLIGATOIRE pour les fichiers non-texte)
# ascii            → mode texte (défaut — corrompt les binaires)
# passive          → activer/désactiver le mode passif
# bye / quit       → fermer la connexion
```

```bash
# Connexion non interactive avec curl (mode passif par défaut)
curl --ftp-pasv ftp://user:pass@target.com/ --list-only

# Télécharger un fichier avec curl en FTP
curl --ftp-pasv -u user:pass ftp://target.com/fichier.txt -o local.txt

# Upload avec curl en FTP
curl --ftp-pasv -u user:pass -T local.txt ftp://target.com/remote.txt

# FTPS Explicite avec curl
curl --ftp-ssl --ftp-pasv -u user:pass ftp://target.com/fichier.txt -o local.txt

# FTPS Implicite avec curl (port 990)
curl --ftp-ssl --ftp-pasv -u user:pass ftps://target.com/fichier.txt -o local.txt
```

### 6.2 Commandes SFTP

```bash
# Connexion SFTP interactive
sftp user@target.com
sftp -P 2222 user@target.com          # Port SSH non standard
sftp -i ~/.ssh/sftp_ed25519 user@target.com  # Authentification par clé

# Commandes dans le shell SFTP interactif
# ls / lls                → liste distante / locale
# cd DIR / lcd DIR        → changer répertoire distant / local
# get FILE / put FILE     → télécharger / uploader
# mget *.txt / mput *.log → transferts multiples
# mkdir DIR / rmdir DIR   → créer / supprimer répertoire distant
# chmod 600 FILE          → modifier les permissions distantes
# bye / exit              → fermer la connexion

# Transfert non interactif (en une commande)
sftp user@target.com:/remote/path/file.txt ./local_file.txt

# Upload non interactif
sftp user@target.com <<< "put local.txt /remote/path/"

# Commandes batch SFTP (script)
sftp -b /tmp/sftp_commands.txt user@target.com
# Contenu de sftp_commands.txt :
# cd /uploads
# put rapport.pdf
# ls -la
# bye
```

### 6.3 lftp — Client FTP/SFTP avancé

```bash
# lftp — client multi-protocole, miroir récursif et scripting avancé
lftp ftp://user:pass@target.com

# Miroir récursif du serveur FTP vers local (télécharger tout)
lftp -e "mirror /remote/path/ /local/path/; bye" ftp://user:pass@target.com

# Miroir inverse (upload récursif)
lftp -e "mirror -R /local/path/ /remote/path/; bye" ftp://user:pass@target.com

# SFTP avec lftp
lftp sftp://user@target.com

# FTPS avec lftp
lftp ftps://user:pass@target.com
```

### 6.4 Scan et Audit Nmap

```bash
# Détection de version sur les ports FTP/SFTP
nmap -sV -p 21,22,990,989 target.com

# Scripts NSE FTP complets
nmap -sV --script "ftp-*" -p 21 target.com

# Scripts spécifiques
nmap --script ftp-anon -p 21 target.com           # Test anonyme
nmap --script ftp-syst -p 21 target.com           # OS via SYST
nmap --script ftp-bounce --script-args ftp-bounce.username=anonymous -p 21 target.com
nmap --script ftp-brute --script-args userdb=users.txt,passdb=pass.txt -p 21 target.com

# SSH — scripts d'audit de configuration
nmap --script ssh-auth-methods -p 22 target.com   # Méthodes d'auth SSH activées
nmap --script ssh2-enum-algos -p 22 target.com    # Algorithmes SSH supportés
nmap --script ssh-hostkey -p 22 target.com        # Empreinte de la clé hôte
```

---

## 7. Références

### Standards & RFC

| RFC / Document | Sujet |
| --- | --- |
| **RFC 959** (1985) | File Transfer Protocol (FTP) — Spécification originale |
| **RFC 2228** (1997) | FTP Security Extensions (base de FTPS) |
| **RFC 2389** (1998) | Feature negotiation mechanism for FTP (`FEAT` command) |
| **RFC 2577** (1999) | FTP Security Considerations (Bounce Attack, Anonymous) |
| **RFC 4217** (2005) | Securing FTP with TLS (FTPS Explicite standardisé) |
| **RFC 4251** (2006) | The Secure Shell (SSH) Protocol Architecture |
| **RFC 4253** (2006) | The Secure Shell (SSH) Transport Layer Protocol |
| **RFC 4254** (2006) | The Secure Shell (SSH) Connection Protocol |
| **Draft IETF SFTP** | SSH File Transfer Protocol (draft-ietf-secsh-filexfer) |

### Ressources d'exploitation et de configuration

- **PayloadsAllTheThings — FTP** : `https://github.com/swisskyrepo/PayloadsAllTheThings`
- **HackTricks — FTP** : `https://book.hacktricks.xyz/network-services-pentesting/pentesting-ftp`
- **OpenSSH — sshd_config** : `https://man.openbsd.org/sshd_config`
- **vsftpd — Configuration** : `https://security.appspot.com/vsftpd/vsftpd_conf.html`
- **Mozilla SSH Guidelines** : `https://infosec.mozilla.org/guidelines/openssh`
