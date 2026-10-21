# 🛠️ Commande : gzip / gunzip

## 1. Description rapide (Rôle et cas d'usage)

`gzip` compresse un fichier unique (pas un dossier ni plusieurs fichiers d'un coup) et remplace l'original par un fichier `.gz`. `gunzip` fait l'inverse. C'est le compresseur de référence pour les fichiers de logs en rotation (`logrotate` l'utilise nativement) et pour compresser rapidement un flux de données en pipe.

## 2. Syntaxe de base

```bash
gzip [OPTIONS] fichier
gunzip [OPTIONS] fichier.gz
```

## 3. Options et fanions principaux

| Option | Commande | Effet |
|---|---|---|
| (aucune) | `gzip` | Compresse et supprime le fichier original |
| `-k` | `gzip` / `gunzip` | Conserve le fichier original (keep) |
| `-d` | `gzip` | Équivalent de `gunzip` |
| `-9` | `gzip` | Compression maximale (plus lent) |
| `-1` | `gzip` | Compression rapide (moins efficace) |
| `-v` | `gzip` / `gunzip` | Affiche le taux de compression |
| `-r` | `gzip` | Compresse récursivement (chaque fichier individuellement) |

## 4. Exemples pratiques & Cas d'usage

**Compresser un fichier de log en fin de rotation**
```bash
gzip /var/log/app/app.log.1
```

**Compresser sans supprimer l'original (vérification avant nettoyage)**
```bash
gzip -k backup_db.sql
```

**Décompresser un fichier reçu pour analyse**
```bash
gunzip access.log.gz
```

**Lire directement un fichier .gz sans le décompresser sur disque**
```bash
zcat access.log.gz | grep "500"
```

**Rechercher un motif dans plusieurs logs compressés sans extraction préalable**
```bash
zgrep "Failed password" /var/log/auth.log*.gz
```

**Parcourir un gros fichier .gz avec pagination sans décompression complète**
```bash
zless huge_dataset.csv.gz
```

## 5. Astuces & Pièges à éviter

!!! warning "gzip supprime le fichier original par défaut"
    Sans `-k`, `gzip fichier` remplace directement le fichier source par `fichier.gz`. En contexte de sauvegarde critique, pensez à `-k` ou à travailler sur une copie pour ne pas perdre l'original en cas d'erreur.

!!! tip "Analyser des logs compressés sans décompression : zcat/zgrep/zless"
    Ces outils (`z`-prefixed) permettent d'analyser directement des fichiers `.gz` archivés, très utile en analyse d'incident sur des rotations de logs déjà compressées — évite de saturer le disque en décompressant temporairement des fichiers volumineux.

!!! tip "gzip ne gère qu'un seul fichier à la fois"
    Contrairement à `zip` ou `tar`, `gzip` ne sait compresser qu'un fichier individuel. Pour archiver un dossier entier avec compression gzip, il faut d'abord l'assembler avec `tar` (`tar -czf`), `gzip` intervenant alors en interne via l'option `-z`.
