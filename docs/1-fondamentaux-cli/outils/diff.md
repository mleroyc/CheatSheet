# 🛠️ Commande : diff

## 1. Description rapide (Rôle et cas d'usage)

`diff` est l'utilitaire standard de **comparaison ligne par ligne** de fichiers texte, capable également de comparer récursivement le contenu de répertoires entiers. Il identifie les lignes ajoutées, supprimées ou modifiées entre deux versions d'un même contenu et restitue le résultat sous différents formats.

**Principaux cas d'usage :**

- **Audit de modifications de fichiers de configuration** : identifier précisément ce qui a changé entre deux versions d'un fichier système.
- **Vérification de sauvegardes** : confirmer qu'une restauration correspond bien à l'état attendu.
- **Génération de rustines/correctifs (patches)** pour le code source, applicables via `patch` ou intégrées à des workflows Git.
- **Analyse de différences entre environnements** (dev/prod), pour détecter des divergences de configuration ou de code non synchronisées.

---

## 2. Syntaxe de base

```bash
diff [options] FICHIER1 FICHIER2
```

ou, pour comparer des répertoires :

```bash
diff [options] DOSSIER1 DOSSIER2
```

**Modes d'affichage principaux :**

- **Normal** (format historique par défaut, sans option) : syntaxe `NcN`/`NaN`/`NdN`, peu lisible mais universellement supportée.
- **Unifié** (`-u`) : format compact standard, utilisé par Git et la quasi-totalité des outils de patch modernes.
- **Côte à côte** (`-y`) : deux colonnes affichées côte à côte, pratique pour une lecture visuelle rapide.
- **Contextuel** (`-c`) : affiche des lignes de contexte avant/après chaque changement, format historique alternatif à l'unifié.

---

## 3. Options et fanions principaux

| Option | Forme longue | Description |
|---|---|---|
| `-u` | `--unified` | Format unifié, standard pour les rustines/patches et l'écosystème Git. |
| `-y` | `--side-by-side` | Affichage côte à côte sur deux colonnes. |
| `-r` | `--recursive` | Comparaison récursive des sous-dossiers, lors de la comparaison de deux répertoires. |
| `-i` | `--ignore-case` | Ignore la casse (majuscule/minuscule) lors de la comparaison. |
| `-w` | `--ignore-all-space` | Ignore tous les espaces et tabulations. |
| `-B` | `--ignore-blank-lines` | Ignore les lignes entièrement vides. |
| `-q` | `--brief` | Affiche uniquement si les fichiers diffèrent, sans détailler les lignes concernées. |
| `-N` | `--new-file` | Traite les fichiers absents d'un côté comme des fichiers vides, lors de la comparaison de dossiers (utile pour voir les fichiers ajoutés/supprimés en entier). |
| — | `--color[=WHEN]` | Colore la sortie. `WHEN` : `always`, `auto` (défaut, selon le terminal), `never`. |

!!! tip "Astuce mémo"
    Les options courtes se combinent : `diff -wBu` compare en format unifié tout en ignorant les espaces et les lignes vides — un combo fréquent pour comparer la logique d'un fichier sans bruit de formatage.

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Comparaison classique au format unifié (`diff -u`)

Analyse les changements entre deux versions d'un fichier de configuration :

```bash
diff -u config.conf.bak config.conf
```

### 2. Génération d'un fichier Patch et application

Crée un fichier de correctif à partir des différences entre deux versions d'un fichier source, puis l'applique sur l'original :

```bash
# Génération de la patchfile
diff -u orig.py modif.py > fix.patch

# Application du patch sur le fichier d'origine
patch orig.py < fix.patch
```

### 3. Comparaison visuelle côte à côte (`diff -y --suppress-common-lines`)

Affiche uniquement les lignes différentes sur deux colonnes, en masquant les lignes identiques pour réduire le bruit visuel :

```bash
diff -y --suppress-common-lines fichier1.txt fichier2.txt
```

### 4. Comparaison récursive de deux répertoires (`diff -rq`)

Identifie rapidement les fichiers ajoutés, modifiés ou supprimés entre deux répertoires de projet ou de sauvegardes, sans afficher le détail des lignes :

```bash
diff -rq projet_v1/ projet_v2/
```

### 5. Ignorer le bruit et le formatage (`diff -wB`)

Compare la logique d'un fichier sans être pollué par les espaces, tabulations ou lignes vides ajoutées lors d'un reformatage :

```bash
diff -wB fichier_avant.conf fichier_apres.conf
```

### 6. Comparaison de sorties de commandes sans fichier temporaire (Process Substitution)

Compare directement la sortie de deux commandes, sans créer de fichier intermédiaire, grâce à la substitution de processus Bash :

```bash
diff -u <(sort liste1.txt) <(sort liste2.txt)
```

---

## 5. Astuces, Outils complémentaires & Pièges à éviter

!!! tip "Compréhension des symboles du format unifié"
    Le format unifié (`-u`) utilise une syntaxe compacte et standardisée :

    - **`+`** : ligne ajoutée (présente uniquement dans le second fichier).
    - **`-`** : ligne supprimée (présente uniquement dans le premier fichier).
    - **`@@ -L,N +L,N @@`** : en-tête de bloc (« hunk »), indiquant la position et le nombre de lignes concernées : `-L,N` = à partir de la ligne `L` du premier fichier, sur `N` lignes ; `+L,N` = équivalent pour le second fichier.

    ```diff
    @@ -12,3 +12,4 @@
     ligne_inchangee
    -ancienne_valeur=10
    +nouvelle_valeur=20
    +nouvelle_ligne_ajoutee
     ligne_inchangee_suivante
    ```

!!! warning "Interprétation du code de retour (Exit Codes)"
    `diff` renvoie un code de sortie exploitable directement dans des scripts Bash ou des pipelines CI/CD :

    - **`0`** : les fichiers sont identiques.
    - **`1`** : des différences ont été trouvées.
    - **`2`** : une erreur s'est produite (fichier introuvable, permission refusée, etc.).

    ```bash
    if diff -q fichier1.txt fichier2.txt > /dev/null; then
        echo "Fichiers identiques"
    else
        echo "Différences détectées"
    fi
    ```

!!! tip "Alternative moderne `colordiff` / `git diff`"
    Sur des systèmes plus anciens où `diff --color` n'est pas disponible, l'outil complémentaire `colordiff` (wrapper autour de `diff`) ajoute une coloration syntaxique équivalente :

    ```bash
    colordiff -u fichier1.txt fichier2.txt
    ```

    Pour une lisibilité encore améliorée (mise en évidence par mot, statistiques de changement), `git diff --no-index` fonctionne même **hors d'un dépôt Git**, sur deux fichiers ou dossiers quelconques :

    ```bash
    git diff --no-index fichier1.txt fichier2.txt
    ```

!!! danger "Fichiers binaires"
    Par défaut, `diff` détecte automatiquement les fichiers non-texte (binaires) et **n'affiche pas leur contenu ligne par ligne** — il se contente d'indiquer qu'ils diffèrent :

    ```text
    Binary files fichier1.bin and fichier2.bin differ
    ```

    Pour forcer une comparaison textuelle malgré tout (rarement utile, résultat souvent illisible), l'option `-a`/`--text` force le traitement en mode texte. Pour une comparaison binaire structurée, préférer des outils dédiés comme `cmp` (position du premier octet différent) ou `xxd` combiné à `diff`.
