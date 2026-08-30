# Cheat Sheet : Gestion des Paquets & Journalisation (Logs)

!!! tip "Usage principal"
    Installer/gérer des logiciels quelle que soit la distribution, manipuler des archives, compiler depuis les sources, et exploiter les logs système pour l'administration comme pour la détection Blue Team.

---

## 1. Gestionnaires de Paquets Debian / RedHat

### Matrice de correspondance

| Action | Debian/Ubuntu (`apt`/`dpkg`) | RHEL/CentOS (`dnf`/`yum`/`rpm`) |
| --- | --- | --- |
| Installer un paquet | `apt install nom` | `dnf install nom` (ou `yum install nom`) |
| Supprimer un paquet | `apt remove nom` | `dnf remove nom` |
| Supprimer + configs | `apt purge nom` | `dnf remove nom` (rpm ne sépare pas configs) |
| Rechercher un paquet | `apt search motclé` | `dnf search motclé` |
| Mettre à jour la liste des dépôts | `apt update` | `dnf check-update` |
| Mettre à jour tous les paquets | `apt upgrade` | `dnf upgrade` |
| Nettoyer le cache | `apt clean` / `apt autoremove` | `dnf clean all` |
| Installer un fichier local | `dpkg -i paquet.deb` | `rpm -ivh paquet.rpm` |
| Lister fichiers d'un paquet installé | `dpkg -L nom` | `rpm -ql nom` |
| Quel paquet possède ce fichier ? | `dpkg -S /chemin/fichier` | `rpm -qf /chemin/fichier` |
| Inspecter un fichier sans l'installer | `dpkg -I paquet.deb` | `rpm -qip paquet.rpm` |

### Commandes rapides
```bash
# Installer un paquet depuis les dépôts configurés (Debian/Ubuntu)
sudo apt install nginx
```

```bash
# Équivalent RHEL/CentOS
sudo dnf install nginx
```

```bash
# Inspecter le contenu et les métadonnées d'un .deb avant installation
dpkg -I paquet.deb
```

```bash
# Inspecter un .rpm : dépendances, description, version
rpm -qip paquet.rpm
```

### Gestion des dépôts
```bash
cat /etc/apt/sources.list          # dépôts principaux Debian/Ubuntu
ls /etc/apt/sources.list.d/        # dépôts additionnels (PPA, tiers)
ls /etc/yum.repos.d/               # dépôts RHEL/CentOS (fichiers .repo)
```

!!! info "yum vs dnf"
    `dnf` est le successeur moderne de `yum` (résolution de dépendances plus rapide et fiable), utilisé par défaut depuis RHEL 8/CentOS 8. La syntaxe reste quasi identique ; `yum` est généralement conservé comme alias de compatibilité.

---

## 2. Archives, Compression & Compilation Source

### Compression / Décompression avec `tar`
```bash
tar -cvzf archive.tar.gz dossier/   # Créer une archive gzip (c=create, v=verbose, z=gzip, f=fichier)
tar -xvzf archive.tar.gz            # Extraire une archive gzip
tar -jxvf archive.tar.bz2           # Extraire une archive bzip2 (j)
tar -tvf archive.tar                # Lister le contenu sans extraire
```

## Synthèse — Tableau des flags `tar`

| Flag | Rôle |
| --- | --- |
| `-c` | Créer une nouvelle archive |
| `-x` | Extraire une archive existante |
| `-t` | Lister le contenu sans extraire |
| `-v` | Mode verbeux (affiche chaque fichier traité) |
| `-z` | Compression/décompression gzip (`.tar.gz`) |
| `-j` | Compression/décompression bzip2 (`.tar.bz2`) |
| `-f` | Spécifie le nom du fichier archive (toujours en dernier) |
| `-C DIR` | Extrait dans un répertoire cible plutôt que le courant |

### Autres outils de compression
```bash
gzip fichier.txt      # compresse en fichier.txt.gz (supprime l'original)
gunzip fichier.txt.gz # décompresse
zip -r archive.zip dossier/   # crée une archive zip récursive
unzip archive.zip             # extrait une archive zip
```

### Compilation depuis les sources
```bash
./configure    # vérifie l'environnement et génère le Makefile adapté au système
make           # compile le code source selon le Makefile généré
sudo make install   # installe les binaires compilés aux emplacements système
```

!!! tip "Dépendances manquantes lors du `./configure`"
    Une erreur `./configure` s'arrêtant sur une bibliothèque manquante (`libssl-dev not found`...) se résout en installant le paquet `-dev`/`-devel` correspondant via le gestionnaire de paquets de la distribution (`apt install libssl-dev` ou `dnf install openssl-devel`), puis en relançant `./configure`.

---

## 3. Architecture de Journalisation (Logs)

### Emplacements clés dans `/var/log/`

| Fichier / Dossier | Contenu |
| --- | --- |
| `/var/log/auth.log` (Debian) / `/var/log/secure` (RHEL) | Authentifications, `sudo`, connexions SSH |
| `/var/log/syslog` | Journal général du système (Debian/Ubuntu) |
| `/var/log/kern.log` | Messages spécifiques au noyau |
| `/var/log/boot.log` | Messages du démarrage des services |
| `dmesg` (commande) | Buffer noyau depuis le dernier boot (pilotes, matériel) |

### Configuration de `rsyslog`
```bash
# /etc/rsyslog.conf : règles au format "facility.severity   destination"
auth,authpriv.*    /var/log/auth.log   # toutes sévérités de la facility auth/authpriv
kern.warning       /var/log/kern.log   # messages noyau de sévérité warning et plus
*.emerg            :omusrmsg:*         # urgences envoyées à tous les utilisateurs connectés
```

```bash
# Redirection des logs vers un serveur syslog centralisé (Blue Team / SIEM)
*.* @@siem.entreprise.local:514   # @@=TCP, @=UDP, port 514 standard
```

!!! info "Facility et Severity"
    Une règle `rsyslog` combine une **facility** (source : `auth`, `kern`, `cron`, `mail`...) et une **severity** (gravité : `debug` < `info` < `notice` < `warning` < `err` < `crit` < `alert` < `emerg`). `*.*` capture tout, `kern.err` ne capture que les erreurs noyau et plus graves.

### Rotation des logs avec `logrotate`
```bash
cat /etc/logrotate.conf       # configuration globale par défaut
ls /etc/logrotate.d/          # règles spécifiques par service (nginx, apache...)
```

```bash
# Exemple de règle logrotate typique
/var/log/nginx/*.log {
    weekly          # rotation hebdomadaire
    rotate 4        # conserve 4 archives avant suppression
    compress        # compresse les anciennes archives
    missingok       # ne pas échouer si le fichier de log est absent
}
```

### Inspection en temps réel et analyse rapide
```bash
tail -f /var/log/auth.log          # suit les nouvelles lignes en direct
multitail /var/log/auth.log /var/log/syslog   # suit plusieurs logs simultanément, côte à côte
```

```bash
# Détection Blue Team : tentatives d'authentification SSH échouées
grep "Failed password" /var/log/auth.log | tail -20
```

```bash
# Compter les IP sources les plus agressives en tentatives échouées
grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -10
```

!!! tip "Suivi de log résistant à la rotation"
    Préférez `tail -F` (majuscule) à `tail -f` pour suivre un fichier de log activement soumis à `logrotate` : `-F` recolle automatiquement au nouveau fichier après une rotation, tandis que `-f` reste accroché à l'ancien descripteur de fichier devenu obsolète.
