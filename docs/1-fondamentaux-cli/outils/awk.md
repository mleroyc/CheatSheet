# awk

> `awk` est un langage de programmation orienté colonnes qui découpe chaque ligne d'un fichier en champs et exécute un bloc d'instructions sur chaque ligne, avec support des conditions, boucles, fonctions et tableaux associatifs.

!!! tip "Cas d'usage principal"
    En pentest ou en administration système, `awk` est particulièrement puissant pour extraire des colonnes précises avec des conditions (ex: comptes utilisateurs avec UID ≥ 1000, shells de connexion actifs), agréger des données (sommes, comptages) directement depuis la sortie d'une autre commande, ou parser des fichiers structurés (`/etc/passwd`, logs, CSV) sans avoir besoin d'un script externe.

## 1. Syntaxe de base

```bash
# Structure générale de la commande
awk -F 'SEPARATEUR' 'CONDITION {ACTION}' fichier
```

## 2. Variables de champ et de ligne

| Variable | Description |
| --- | --- |
| `$0` | La ligne entière |
| `$1` | La première colonne |
| `$N` | La N-ième colonne |
| `NF` | Le nombre de colonnes dans la ligne actuelle |
| `$NF` | La dernière colonne de la ligne (car `NF` contient l'indice de la dernière colonne) |
| `NR` | Le numéro de la ligne actuelle |

!!! note "Séparateur par défaut"
    Par défaut, `awk` utilise l'espace et la tabulation comme séparateurs de colonnes, avec compression automatique des espaces multiples (contrairement à `cut`).

## 3. Commandes et cas d'usage fréquents

### Extraire des colonnes avec un séparateur

```bash
# -F définit le séparateur de champ, ici ':'
# extrait la colonne 1 (login) et la colonne 7 (shell) de /etc/passwd
awk -F':' '{print $1, $7}' /etc/passwd
```

### Filtrer par valeur numérique

```bash
# Affiche uniquement les lignes où la 3ème colonne (UID) est >= 1000
awk -F':' '$3 >= 1000 {print $1, $3}' /etc/passwd
```

### Filtrer par correspondance de texte (regex)

```bash
# Affiche les lignes où la dernière colonne se termine par "bash"
# En awk, les regex sont toujours encadrées par des slashs /.../
awk -F':' '$NF ~ /bash$/ {print $1, $NF}' /etc/passwd
```

### Opérateurs de comparaison et logiques

| Opérateur | Signification |
| --- | --- |
| `~` | Correspond à la regex suivante |
| `!~` | Ne correspond PAS à la regex suivante |
| `==` | Égalité stricte (texte ou chiffre) |
| `!=` | Différent (texte ou chiffre) |
| `>` | Supérieur à |
| `<` | Inférieur à |
| `&&` | ET logique |
| `\|\|` | OU logique |

### Blocs BEGIN et END

```bash
# BEGIN {...} s'exécute avant la lecture de la première ligne
# END {...} s'exécute après la lecture de toutes les lignes
# Exemple : calcule la taille totale des fichiers d'un répertoire
ls -l | awk 'BEGIN {total=0} {total+=$5} END {print "Taille totale :", total, "octets"}'
```

## 4. Options utiles

| Flag / Option | Description | Exemple |
| --- | --- | --- |
| `-F 'SEP'` | Définit le séparateur de champ en entrée | `awk -F':' '{print $1}' fichier` |
| `-v var=valeur` | Déclare une variable externe utilisable dans le bloc d'action | `awk -v seuil=1000 '$3>=seuil {print $1}' fichier` |
| `-f script.awk` | Exécute les commandes contenues dans un fichier script | `awk -f script.awk fichier` |
| `-i inplace` | Modifie directement le fichier source (GNU awk) | `awk -i inplace '{gsub(/foo/,"bar")}1' fichier` |

!!! warning "Portabilité de l'option -i"
    La modification directe du fichier source (`-i inplace`) est une extension spécifique à **GNU awk (gawk)** et n'est pas disponible sur toutes les implémentations (ex: `mawk`, `awk` BSD). Vérifie la version installée (`awk --version`) avant de t'appuyer dessus en script portable.

## 5. Variables internes

| Variable | Description |
| --- | --- |
| `FS` | Le séparateur d'entrée (modifiable via `-F`) |
| `OFS` | Le séparateur de sortie (espace par défaut) |
| `RS` | Le séparateur d'enregistrement/lignes en entrée (`\n` par défaut) |
| `ORS` | Le séparateur de ligne en sortie (`\n` par défaut) |
| `NR` | Numéro de la ligne courante, tous fichiers confondus |
| `FNR` | Numéro de la ligne courante du fichier actuellement traité |
| `FILENAME` | Le nom du fichier en cours de traitement |

## 6. Fonctions intégrées

| Fonction | Description |
| --- | --- |
| `length([chaine])` | Renvoie la longueur de la chaîne ou du champ (ex: `length($1) > 10`) |
| `substr(s, pos, len)` | Extrait une sous-chaîne de `s` à partir de `pos` sur `len` caractères |
| `gsub(r, s [, t])` | Équivalent de `sed 's/.../.../g'` : remplace toutes les occurrences du motif `r` par `s` dans `t` (par défaut `$0`) |
| `sub(r, s [, t])` | Remplace uniquement la première occurrence du motif `r` par `s` |
| `split(string, array, fieldsep)` | Découpe une chaîne en un tableau selon un séparateur donné |

```bash
# Exemple : remplacer toutes les occurrences de "http" par "https" dans chaque ligne
awk '{gsub(/http/, "https"); print}' urls.txt
```

## 7. Boucles

```awk
# Boucle for classique
for (i = 1; i <= NF; i++) { print $i }

# Boucle while
while (condition) { action }
```

## 8. Tableaux

- `awk` supporte les **tableaux associatifs**, qui fonctionnent avec des clés en chaînes de texte ou des index numériques.
- Parcours d'un tableau via une boucle `for (cle in tableau) {...}`.

```bash
# Exemple : compter le nombre d'occurrences de chaque shell dans /etc/passwd
awk -F':' '{compte[$7]++} END {for (shell in compte) print shell, compte[shell]}' /etc/passwd
```

## 9. Bonnes pratiques & pièges à éviter

!!! warning "Guillemets et échappement en shell"
    Le script `awk` doit être entouré de guillemets simples `'...'` pour éviter que le shell n'interprète les `$` (réservés aux champs `awk`) comme des variables shell. Utiliser des guillemets doubles `"..."` casse quasi systématiquement les scripts `awk` contenant `$1`, `$NF`, etc.

!!! warning "Différence avec cut sur les espaces"
    Contrairement à `cut`, `awk` compresse automatiquement les espaces/tabulations multiples en un seul séparateur par défaut. C'est souvent plus pratique pour des sorties alignées (`ps`, `ls -l`) sans avoir besoin d'un `tr -s` préalable.

!!! tip "Combiner condition et action"
    Il n'est pas obligatoire de fournir un bloc `{ACTION}` : une simple `CONDITION` sans action affiche par défaut la ligne entière (`$0`) si la condition est vraie, ce qui permet un filtrage rapide façon `grep` mais avec la logique de colonnes en plus.

---