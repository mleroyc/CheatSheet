# 🛠️ Commande : cut

## 1. Description rapide (Rôle et cas d'usage)

`cut` est un utilitaire d'extraction qui permet de découper chaque ligne d'un fichier ou d'un flux texte pour n'en conserver que certaines **sections** : des caractères, des octets, ou des champs délimités par un séparateur donné. Contrairement à `awk`, `cut` est volontairement minimaliste : il ne fait qu'une chose (extraire des positions ou des champs), sans logique conditionnelle ni réorganisation.

**Principaux cas d'usage :**

- **Extraction de champs spécifiques** dans des fichiers structurés (CSV, `/etc/passwd`, fichiers `/etc/group`, logs à délimiteurs fixes).
- **Découpage de sorties de commandes** dans des pipelines (`ps`, `df`, `who`, `ip a`, etc.) pour isoler une colonne précise.
- **Nettoyage rapide de données tabulaires** avant transmission à un autre outil (`sort`, `uniq`, `xargs`).

---

## 2. Syntaxe de base

```bash
cut OPTION... [FICHIER]...
```

ou via un pipe :

```bash
commande | cut OPTION...
```

**Principes fondamentaux :** `cut` propose trois modes de sélection, mutuellement exclusifs :

- **par caractères** (`-c`) : sélection par position de caractère sur la ligne ;
- **par octets** (`-b`) : sélection par position d'octet (utile pour les encodages multi-octets) ;
- **par champs** (`-f`, associé à `-d`) : sélection par numéro de champ, en fonction d'un délimiteur donné.

---

## 3. Options et fanions principaux

| Option | Forme longue | Description |
|---|---|---|
| `-d DELIM` | `--delimiter=DELIM` | Spécifie le caractère délimiteur de champs (défaut : tabulation). |
| `-f LISTE` | `--fields=LISTE` | Sélectionne les numéros de champs à afficher (ex. `1`, `1,3`, `2-5`, `3-`). |
| `-c LISTE` | `--characters=LISTE` | Sélectionne des positions de caractères spécifiques (même syntaxe de plage que `-f`). |
| `-b LISTE` | `--bytes=LISTE` | Sélectionne des octets spécifiques sur chaque ligne. |
| `-s` | `--only-delimited` | Ignore (n'affiche pas) les lignes ne contenant pas le délimiteur spécifié. |
| — | `--complement` | Inverse la sélection : affiche tout **sauf** les champs/caractères/octets spécifiés. |
| — | `--output-delimiter=CHAINE` | Remplace le délimiteur d'entrée par une autre chaîne dans le rendu final. |

!!! tip "Astuce mémo"
    Les listes acceptent des plages : `1-3` (du 1er au 3e), `4-` (du 4e à la fin), `-2` (du début au 2e), ou une combinaison `1,3,5-7`.

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Extraction de champs dans un fichier à délimiteur (`/etc/passwd`)

Extrait le nom d'utilisateur (champ 1) et le shell par défaut (champ 7), séparés par `:` :

```bash
cut -d: -f1,7 /etc/passwd
```

### 2. Découpage par plages de caractères

Affiche uniquement les caractères 1 à 10 de chaque ligne (utile pour des colonnes à largeur fixe) :

```bash
cut -c1-10 fichier.txt
```

### 3. Changement de délimiteur de sortie (`--output-delimiter`)

Convertit des données séparées par `:` en pseudo-CSV séparé par des virgules :

```bash
cut -d: -f1,3,7 --output-delimiter=',' /etc/passwd
```

### 4. Masquage / Exclusion avec `--complement`

Affiche toutes les colonnes **sauf** la 2e (ex. masquer un champ de mot de passe/hash) :

```bash
cut -d: -f2 --complement /etc/shadow
```

### 5. Filtrage des lignes sans délimiteur (`-s`)

Ignore les lignes de commentaires ou les lignes vides qui ne contiennent pas le délimiteur, évitant qu'elles ne soient réaffichées intégralement :

```bash
cut -d: -f1 -s /etc/passwd
```

### 6. One-liner combiné avec d'autres outils

Extrait les adresses IP depuis la sortie de `ip a`, en combinant `grep`, `awk`/`tr` et `cut` :

```bash
ip a | grep "inet " | tr -s ' ' | cut -d' ' -f3 | cut -d'/' -f1
```

---

## 5. Astuces & Pièges à éviter

!!! warning "La gestion des espaces multiples"
    `cut -d' '` traite **chaque espace individuellement** comme un délimiteur. Sur des sorties dont les colonnes sont alignées par plusieurs espaces consécutifs (`ps aux`, `ls -l`), cela génère de nombreux champs vides et décale le numéro de colonne attendu.

    ```bash
    # Résultat imprévisible : les espaces multiples créent des champs vides
    ps aux | cut -d' ' -f2

    # Solution 1 : compresser les espaces avec tr -s avant cut
    ps aux | tr -s ' ' | cut -d' ' -f2

    # Solution 2 : préférer awk, qui gère nativement les espaces multiples
    ps aux | awk '{print $2}'
    ```

!!! danger "Absence de réorganisation des colonnes"
    `cut` **conserve toujours l'ordre d'origine** des champs dans la ligne source, quel que soit l'ordre indiqué dans la liste `-f`. `cut -f2,1` produit exactement le même résultat que `cut -f1,2` : la colonne 1 puis la colonne 2.

    ```bash
    # Ces deux commandes sont strictement équivalentes
    cut -d: -f2,1 /etc/passwd
    cut -d: -f1,2 /etc/passwd
    ```

    Pour réordonner des colonnes, utiliser `awk '{print $2, $1}'` à la place.

!!! danger "Délimiteurs de plusieurs caractères"
    `cut` ne supporte **strictement qu'un seul caractère** comme délimiteur avec `-d`. Passer une chaîne de plusieurs caractères provoque une erreur :

    ```bash
    $ cut -d', ' -f1 fichier.csv
    cut: the delimiter must be a single character
    ```

    Pour un délimiteur multi-caractères (ex. `" | "`, `"::"`), utiliser `awk -F` à la place, qui accepte des expressions régulières comme séparateur :

    ```bash
    awk -F'::' '{print $1}' fichier.txt
    ```
