# 🛠️ Commande : tar

## 1. Description rapide (Rôle et cas d'usage)

`tar` (*tape archive*) regroupe plusieurs fichiers et dossiers en une seule archive, avec ou sans compression. Il ne compresse pas nativement : c'est en le combinant avec un algorithme de compression (`gzip`, `bzip2`, `xz`) qu'on obtient une archive `.tar.gz`, `.tar.bz2` ou `.tar.xz`. C'est l'outil standard pour les sauvegardes système et la distribution d'archives sous Linux.

## 2. Syntaxe de base

```bash
tar [OPTIONS] -f archive.tar [fichiers/dossiers]
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-c` | Crée une nouvelle archive |
| `-x` | Extrait une archive |
| `-t` | Liste le contenu de l'archive sans extraire |
| `-f` | Spécifie le fichier archive cible (obligatoire, en dernier) |
| `-v` | Mode verbeux (affiche les fichiers traités) |
| `-z` | Compression/décompression gzip (`.tar.gz`) |
| `-j` | Compression/décompression bzip2 (`.tar.bz2`) |
| `-J` | Compression/décompression xz (`.tar.xz`) |
| `-C DIR` | Extrait ou archive en se plaçant dans DIR |
| `--exclude=MOTIF` | Exclut les fichiers correspondant au motif |

## 4. Exemples pratiques & Cas d'usage

**Créer un backup compressé d'un répertoire de configuration**
```bash
tar -czvf backup_etc_$(date +%F).tar.gz /etc
```

**Extraire une archive dans un dossier spécifique**
```bash
tar -xzvf backup.tar.gz -C /restauration/
```

**Lister le contenu d'une archive avant extraction (vérification)**
```bash
tar -tzvf archive_suspecte.tar.gz
```

**Créer une archive en excluant les fichiers volumineux ou temporaires**
```bash
tar -czvf projet.tar.gz --exclude='*.log' --exclude='node_modules' /var/www/projet
```

**Compresser avec xz pour un taux de compression maximal (archivage long terme)**
```bash
tar -cJvf archive_finale.tar.xz /data/archives
```

**Extraire uniquement un fichier précis d'une grosse archive**
```bash
tar -xzvf backup.tar.gz etc/nginx/nginx.conf
```

## 5. Astuces & Pièges à éviter

!!! warning "tar seul n'archive pas les permissions/propriétaires en root sans -p"
    Lors d'une restauration en tant qu'utilisateur non-root, les permissions et propriétaires d'origine peuvent ne pas être restaurés correctement. Utilisez `sudo tar -xpzvf` pour préserver les permissions lors d'une restauration système complète.

!!! tip "Toujours vérifier avec -t avant d'extraire une archive inconnue"
    `tar -tzvf archive.tar.gz` permet d'inspecter le contenu (chemins, tailles) sans rien écrire sur le disque — essentiel avant d'extraire une archive reçue d'une source non fiable, pour éviter une attaque par "tar bomb" (des milliers de fichiers déversés dans le dossier courant).

!!! tip "Ordre des options : -f toujours en dernier"
    Le nom du fichier archive doit toujours suivre immédiatement `-f`. Un ordre incorrect (ex: `-fcz archive.tar.gz`) peut provoquer des erreurs selon l'implémentation de `tar` utilisée.
