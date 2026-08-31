# 🛠️ df — Espace disque et points de montage

## 1. Description rapide

`df` (*Disk Free*) affiche l'espace disque disponible et utilisé sur chaque **point de montage** du système. Il interroge les métadonnées des systèmes de fichiers montés, sans parcourir les fichiers un par un (contrairement à `du`).

**Cas d'usage :** vérifier qu'un disque n'est pas plein avant un déploiement, détecter une partition système saturée, surveiller les inodes, diagnostiquer pourquoi des fichiers ne peuvent plus être créés malgré de l'espace apparent.

---

## 2. Syntaxe de base

```bash
df [options] [chemin]
```

```bash
df                        # Vue complète de tous les points de montage (en blocs de 1Ko)
df -h                     # Format lisible (Ko, Mo, Go, To)
df /var                   # Uniquement le système de fichiers contenant /var
df -i                     # Inodes au lieu des blocs de données
```

---

## 3. Options et fanions principaux

| Option | Signification |
|---|---|
| `-h` | Human-readable : affiche Ko, Mo, Go, To (puissances de 2) |
| `-H` | Human-readable : affiche en puissances de 10 (1 Mo = 1 000 000 octets) |
| `-i` | Affiche les inodes (nombre de fichiers) au lieu des blocs de données |
| `-T` | Affiche le type de système de fichiers (ext4, xfs, tmpfs, nfs...) |
| `-a` | Inclut les pseudo-systèmes de fichiers (proc, sysfs, tmpfs, devtmpfs...) |
| `-l` | Limite aux systèmes de fichiers locaux (exclut NFS, CIFS...) |
| `--total` | Ajoute une ligne de total agrégé en fin de tableau |
| `-x <type>` | Exclut un type de système de fichiers (ex : `-x tmpfs`) |
| `--output=<champs>` | Colonnes personnalisées (source, fstype, size, used, avail, pcent, target) |

---

## 4. Exemples pratiques

```bash
# Vue standard — affichage lisible de tous les points de montage
df -h

# Afficher uniquement les systèmes de fichiers locaux avec leur type
df -hT -l

# Exclure les systèmes de fichiers temporaires pour une vue plus claire
df -h -x tmpfs -x devtmpfs

# Surveiller les inodes — détecter une saturation sans manque d'espace apparent
df -i
df -ih    # Idem en format lisible

# Vérifier uniquement le point de montage contenant /var/log
df -h /var/log

# Ajouter une ligne de total
df -h --total

# Vue personnalisée — seulement source, type, taille et usage
df -h --output=source,fstype,size,used,avail,pcent,target

# Alerter si un système de fichiers dépasse un seuil
df -h | awk 'NR>1 && int($5) > 80 { print "⚠️ ALERTE " $5 " sur " $6 }'

# Afficher le FS contenant un répertoire précis (utile pour docker, logs...)
df -h /var/lib/docker
```

```text
# Exemple de sortie df -hT :
Filesystem      Type   Size  Used Avail Use% Mounted on
/dev/sda1       ext4    50G   34G   14G  71% /
tmpfs           tmpfs  3.9G  1.2M  3.9G   1% /dev/shm
/dev/sdb1       xfs    200G  120G   80G  60% /data
nfs-srv:/share  nfs     1.0T  300G  700G  30% /mnt/backup
```

---

## 5. Astuces & Pièges à éviter

!!! warning "Saturation des inodes : disque 'plein' alors que Use% < 100%"
    Un système de fichiers peut afficher 0% d'espace utilisé mais être **saturé en inodes** — trop de fichiers ou répertoires ont été créés. Dans ce cas, aucun nouveau fichier ne peut être créé malgré l'espace disque apparent. Détecter avec :
    ```bash
    df -i
    # IUse% à 100% = saturation en inodes, malgré de l'espace libre en blocs
    ```
    Solution : trouver et supprimer les répertoires avec une densité anormale de petits fichiers (`find / -xdev -type d | xargs ls | sort -rn | head`).

!!! tip "df vs du : deux lectures différentes"
    | Outil | Ce qu'il mesure |
    |---|---|
    | `df` | Espace déclaré par le **système de fichiers** (métadonnées) — rapide |
    | `du` | Espace **réellement occupé** par les fichiers — lent mais précis |
    `df` peut afficher de l'espace utilisé même si les fichiers ont été supprimés, si un processus garde encore le descripteur de fichier ouvert (fichier "fantôme").

!!! tip "Détecter les fichiers supprimés encore ouverts"
    ```bash
    lsof | grep "(deleted)"
    # Liste les fichiers supprimés mais encore ouverts par un processus
    # Ces fichiers consomment de l'espace réel non visible dans ls mais visible dans df
    # Solution : redémarrer le processus concerné pour libérer l'espace
    ```

!!! warning "NFS et df : attention aux timeouts"
    `df` sur un point de montage NFS **inaccessible** peut geler indéfiniment. Utiliser `-l` (local only) ou un timeout :
    ```bash
    df -hl                              # Limite aux systèmes de fichiers locaux
    timeout 5 df -h /mnt/nfs_share     # Timeout de 5s sur un NFS potentiellement mort
    ```

!!! tip "Surveillance automatique dans un script cron"
    ```bash
    #!/bin/bash
    # Alerte si un FS dépasse 90%
    df -h | awk 'NR>1 && int($5) > 90 {
      print "ALERTE DISQUE : " $5 " utilisé sur " $6
    }' | mail -s "Alerte espace disque $(hostname)" admin@exemple.com
    ```
