# 🛠️ Commande : xxd

## 1. Description rapide (Rôle et cas d'usage)

`xxd` est un utilitaire qui crée un **dump hexadécimal** d'un fichier ou d'un flux binaire/texte, et sait également effectuer l'opération inverse : **reconstruire** un fichier binaire à partir d'un dump hexadécimal. Il affiche classiquement, pour chaque ligne, l'adresse (offset), les octets en hexadécimal, et leur représentation ASCII correspondante.

**Principaux cas d'usage :**

- **Inspection de fichiers binaires** : identifier des en-têtes (headers), signatures et nombres magiques (Magic Numbers).
- **Analyse forensique** : examiner le contenu brut d'un fichier suspect ou corrompu, octet par octet.
- **Reverse engineering** : étudier la structure interne d'un exécutable, d'une image mémoire ou d'un protocole binaire.
- **Édition hexadécimale** : modifier des octets précis dans un fichier (patching binaire).
- **Conversion binaire/ASCII** : transformer des données brutes en représentation hexadécimale texte, et inversement.
- **Intégration de données binaires dans du code C/C++** : générer des tableaux d'octets directement inclus dans un projet (shellcode, payloads, ressources embarquées).

---

## 2. Syntaxe de base

**Générer un dump :**

```bash
xxd [options] [FICHIER_ENTRÉE] [FICHIER_SORTIE]
```

**Reconstruire un binaire (mode inverse) :**

```bash
xxd -r [options] [FICHIER_DUMP] [FICHIER_BINAIRE]
```

Sans `FICHIER_SORTIE` (ou `FICHIER_BINAIRE`), `xxd` écrit sur la sortie standard (STDOUT), permettant son usage dans des pipelines.

---

## 3. Options et fanions principaux

| Option | Forme longue | Description |
|---|---|---|
| `-g COLS` | `--groups` | Nombre d'octets regroupés entre deux espaces dans le dump (ex. `-g 1` sépare chaque octet individuellement). |
| `-c COLS` | `--cols` | Nombre d'octets (colonnes) affichés par ligne du dump. |
| `-p` | `--postscript` / `--plain` | Sortie en format brut ("plain hexdump") : suite continue de caractères hexadécimaux, sans adresses ni colonne ASCII. |
| `-r` | `--revert` | Mode inverse : transforme un dump hexadécimal en son binaire d'origine. |
| `-i` | `--include` | Génère un tableau C/C++ (`unsigned char[]`) prêt à être inclus dans du code source. |
| `-l LEN` | `--len` | S'arrête après avoir lu `LEN` octets depuis le début (ou depuis l'offset défini par `-s`). |
| `-s SEEK` | `--seek` | Commence la lecture à l'offset `SEEK` (en octets) dans le fichier d'entrée. |
| `-b` | `--bits` | Affiche un dump au format binaire (suites de `0` et `1`) au lieu de l'hexadécimal. |

!!! tip "Astuce mémo"
    `-s` et `-l` se combinent naturellement pour cibler une zone précise d'un gros fichier : `xxd -s 256 -l 64 fichier` extrait 64 octets à partir de l'offset 256, sans charger tout le fichier en mémoire.

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Inspection rapide d'un fichier binaire

Visualise les en-têtes et nombres magiques (Magic Numbers) présents dans les 16 premiers octets d'un fichier :

```bash
xxd -l 16 fichier
```

### 2. Extraction en mode Hex brut (`-p`)

Convertit un fichier (ou une chaîne via pipe) en une suite continue de caractères hexadécimaux, sans espaces ni adresses :

```bash
echo -n "Hello" | xxd -p
# 48656c6c6f

xxd -p fichier.bin > fichier.hex
```

### 3. Restauration d'un binaire depuis un Hex brut (`xxd -r -p`)

Reconstruit un fichier binaire à partir de sa représentation hexadécimale brute — technique fréquente en CTF et en pentest pour reconstituer un payload transmis en clair :

```bash
echo "48656c6c6f" | xxd -r -p
# Hello

xxd -r -p fichier.hex > fichier_restaure.bin
```

### 4. Modification/Patching ciblé d'un fichier binaire

Génère le dump, l'édite avec un éditeur de texte classique, puis réapplique la modification dans le binaire :

```bash
# 1. Génération du dump complet (avec adresses, pour repérage précis)
xxd fichier.bin > fichier.dump

# 2. Édition manuelle du dump (modifier les octets hexadécimaux souhaités)
vim fichier.dump

# 3. Réinjection des modifications dans le binaire d'origine
xxd -r fichier.dump > fichier_patché.bin
```

### 5. Génération d'un tableau C (`xxd -i`)

Convertit un fichier (payload, shellcode, ressource) en tableau C prêt à l'inclusion dans un projet :

```bash
xxd -i payload.bin > payload.h
```

```c
// Extrait généré par xxd -i
unsigned char payload_bin[] = {
  0x7f, 0x45, 0x4c, 0x46, 0x02, 0x01, 0x01, 0x00, ...
};
unsigned int payload_bin_len = 128;
```

### 6. Visualisation au format binaire (`xxd -b`)

Affiche le contenu au format binaire brut (`0`/`1`), utile pour analyser des masques de bits ou des flags au niveau bit :

```bash
xxd -b -l 4 fichier.bin
```

---

## 5. Astuces & Pièges à éviter

!!! danger "Restauration stricte avec `-r`"
    La reconstruction via `-r` exige un formatage **strictement conforme** au format généré par `xxd` (adresses, espacements, colonnes ASCII). Toute modification manuelle qui casse cette structure (ligne mal alignée, caractère en trop, adresse incohérente) peut faire échouer la reconstruction ou **corrompre silencieusement** le fichier binaire produit.

    **Recommandation :** privilégier le format brut (`-p`) pour tout aller-retour dump/reconstruction, car il ne comporte ni adresses ni alignement à préserver :

    ```bash
    xxd -p fichier.bin > fichier.hex     # dump simplifié
    xxd -r -p fichier.hex > fichier.bin  # reconstruction fiable
    ```

!!! tip "Remplacement de `hexdump` / `od`"
    `xxd` est souvent préféré à `hexdump` ou `od` car il est **bidirectionnel** : il sait aussi bien produire un dump hexadécimal (`xxd`) que le reconvertir en binaire d'origine (`xxd -r`). `hexdump` et `od` ne proposent nativement aucune fonction de reconstruction équivalente, ce qui limite leur usage aux tâches de simple inspection.

!!! tip "Inclusion Vim (`:%!xxd`)"
    Vim permet l'édition hexadécimale directe d'un fichier binaire en s'appuyant sur `xxd` comme filtre externe :

    ```vim
    :%!xxd
    ```

    Cette commande convertit le buffer courant en dump hexadécimal éditable. Après modification des octets souhaités, la commande suivante réapplique les changements dans le fichier binaire :

    ```vim
    :%!xxd -r
    ```

    Cette combinaison transforme Vim en un éditeur hexadécimal complet, sans outil externe supplémentaire.
