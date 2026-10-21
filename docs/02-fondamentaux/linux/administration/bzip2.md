# 🛠️ Commande : bzip2

## 1. Description rapide (Rôle et cas d'usage)

`bzip2` est un utilitaire de **compression de fichiers uniques** s'appuyant sur la transformée de Burrows-Wheeler (BWT) combinée au codage de Huffman. Il produit des fichiers portant l'extension `.bz2`.

**Comparaison de performance :** `bzip2` offre généralement un **taux de compression supérieur** à `gzip`, en particulier sur des données textuelles (logs, dumps SQL), mais au prix d'un **temps de calcul CPU plus élevé** à la compression et d'un **temps de décompression plus long**.

**Principaux cas d'usage :**

- **Archivage longue durée** de logs applicatifs ou de dumps de bases de données, où le gain d'espace disque prime sur la vitesse.
- **Création d'archives compressées combinées avec `tar`** (`.tar.bz2` ou `.tbz2`), pour regrouper et compresser des répertoires entiers.

---

## 2. Syntaxe de base

**Compresser :**

```bash
bzip2 [options] [FICHIER...]
```

**Décompresser :**

```bash
bunzip2 [options] [FICHIER.bz2...]
```

ou :

```bash
bzip2 -d [options] [FICHIER.bz2...]
```

---

## 3. Options et fanions principaux

| Option | Forme longue | Description |
|---|---|---|
| `-d` | `--decompress` | Force la décompression, équivalent fonctionnel à `bunzip2`. |
| `-k` | `--keep` | Conserve le fichier d'origine après compression ou décompression (comportement non-destructif). |
| `-f` | `--force` | Force le remplacement des fichiers de sortie existants sans confirmation. |
| `-v` | `--verbose` | Affiche le taux de compression obtenu et le détail du traitement en cours. |
| `-t` | `--test` | Vérifie l'intégrité de l'archive `.bz2` sans effectuer de décompression réelle. |
| `-q` | `--quiet` | Mode silencieux : supprime les avertissements non critiques. |
| `-1` à `-9` | — | Règle le niveau de compression / la taille de bloc : `-1` (le plus rapide, blocs de 100 Ko) à `-9` (meilleure compression, blocs de 900 Ko — valeur par défaut). |
| `-s` | `--small` | Réduit l'utilisation de mémoire RAM lors du traitement, au prix d'une vitesse d'exécution réduite. |

!!! tip "Astuce mémo"
    `-k` (Keep) est l'option la plus importante à retenir en priorité : sans elle, `bzip2` **supprime le fichier source** après traitement (voir la section [Pièges à éviter](#5-astuces-pieges-a-eviter)).

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Compression simple en conservant l'original (`-k`)

Compresse un fichier de log volumineux sans supprimer la source :

```bash
bzip2 -k app.log
# Produit app.log.bz2, conserve app.log
```

### 2. Décompression rapide (`bunzip2` / `bzip2 -d`)

Extrait le fichier d'origine tout en conservant l'archive `.bz2` grâce à `-k` :

```bash
bunzip2 -k app.log.bz2
# ou équivalent :
bzip2 -dk app.log.bz2
```

### 3. Inspection et lecture sans décompresser

Les outils compagnons `bzcat`, `bzless` et `bzgrep` permettent de lire ou rechercher dans un fichier `.bz2` à la volée, sans créer de fichier décompressé sur le disque :

```bash
bzcat app.log.bz2 | head -n 50       # Affiche les 50 premières lignes
bzless app.log.bz2                    # Pagine le contenu comme less
bzgrep "ERROR" app.log.bz2            # Recherche un motif directement dans l'archive
```

### 4. Vérification de l'intégrité de l'archive (`-t`)

Valide la santé d'un fichier compressé après un transfert réseau ou une sauvegarde, sans le décompresser :

```bash
bzip2 -t backup.log.bz2
```

### 5. Combinaison avec `tar` pour les répertoires

`bzip2` ne compresse qu'un fichier à la fois : pour un répertoire entier, il faut passer par `tar` avec l'option `-j` :

```bash
# Création d'une archive compressée du répertoire
tar -cjvf archive.tar.bz2 dossier/

# Extraction complète de l'archive
tar -xjvf archive.tar.bz2
```

### 6. Optimisation des ressources mémoire (`-s`)

Exécute une compression en mode économe en RAM, adapté aux systèmes contraints (VPS légers, systèmes embarqués) :

```bash
bzip2 -s -9 dump_database.sql
```

---

## 5. Astuces & Pièges à éviter

!!! danger "Suppression automatique du fichier source"
    Par défaut, **sans l'option `-k`**, `bzip2` **supprime le fichier d'origine** dès que la compression (ou la décompression) est terminée avec succès. Ce comportement est identique à celui de `gzip` et surprend fréquemment les utilisateurs habitués à des outils non-destructifs (`zip`, `tar` seul).

    ```bash
    bzip2 app.log
    # app.log a disparu, seul app.log.bz2 subsiste

    bzip2 -k app.log
    # app.log est conservé en plus de app.log.bz2
    ```

    **Réflexe recommandé :** ajouter systématiquement `-k` dans les scripts de sauvegarde automatisés, sauf si la suppression de la source est explicitement voulue.

!!! warning "Incapacité à compresser des dossiers directement"
    Comme `gzip`, `bzip2` ne sait compresser qu'un **fichier unique** à la fois — il ne regroupe jamais plusieurs fichiers ou un répertoire en une seule archive. Tenter de compresser un dossier échoue directement :

    ```bash
    $ bzip2 mon_dossier/
    bzip2: Input file mon_dossier/ is a directory.
    ```

    Il est **impératif de passer par `tar`** au préalable pour regrouper les fichiers en une seule archive, que `bzip2` compresse ensuite (généralement via l'option intégrée `-j` de `tar`, comme illustré dans l'exemple 5).

!!! tip "Consommation CPU & Vitesse vs `gzip` / `xz`"
    Les trois outils de compression courants sous Linux occupent des positions distinctes sur le compromis vitesse/taux de compression :

    | Outil | Vitesse | Taux de compression | Usage typique |
    |---|---|---|---|
    | `gzip` | Très rapide | Modéré | Compression à la volée, streaming, compatibilité maximale |
    | `bzip2` | Intermédiaire | Bon à très bon | Archivage équilibré vitesse/taille |
    | `xz` | Lent (voire très lent en `-9`) | Excellent | Archivage longue durée où la taille prime sur le temps de traitement |

    Pour un pipeline nécessitant une compression rapide (logs en temps réel, transferts fréquents), préférer `gzip`. Pour un stockage d'archive rarement accédé où chaque octet compte, `xz` surpasse généralement `bzip2` au prix d'un temps de calcul nettement plus élevé.
