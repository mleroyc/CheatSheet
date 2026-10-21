# grep — Recherche et filtrage de motifs dans du texte

> `grep` (Global Regular Expression Print) est un outil en ligne de commande permettant de rechercher des motifs (littéraux ou via expressions régulières) dans un ou plusieurs fichiers, ligne par ligne.

!!! tip "Cas d'usage principal"
    En pentest ou en administration système, `grep` est indispensable pour fouiller rapidement des logs, extraire des identifiants/mots de passe dans des fichiers de configuration, filtrer la sortie d'autres commandes (via un pipe `|`), ou encore rechercher des motifs sensibles (clés API, IP, credentials) dans un dump de fichiers ou un dépôt de code.

## 1. Syntaxe de base

```bash
# Structure générale de la commande
grep [options] motif fichier
```

## 2. Les différents moteurs de recherche (regex engines)

`grep` peut s'appuyer sur plusieurs moteurs d'expressions régulières selon les options utilisées. Le choix du moteur change la syntaxe des métacaractères à utiliser.

### Basic Regular Expression (BRE) — mode par défaut

```bash
# Mode par défaut : tout est traité littéralement (sauf ^ $ . * [ ])
# Les métacaractères étendus (+, ?, |, {}) doivent être échappés avec \
grep motif fichier
```

### Extended Regular Expression (ERE)

```bash
# Active les métacaractères étendus sans avoir besoin de les échapper
# |, +, ?, {} sont directement interprétés comme des opérateurs regex
grep -E motif fichier
# Équivalent :
egrep motif fichier
```

### Fixed String / Recherche littérale (aucune regex)

```bash
# Recherche du motif en tant que chaîne de caractères pure (aucune interprétation regex)
# Utile pour rechercher des caractères spéciaux (., *, [, etc.) sans les échapper
grep -F motif fichier
# Équivalent :
fgrep motif fichier
```

### Perl Compatible Regular Expression (PCRE)

```bash
# Utilise le moteur de regex de Perl, avec des fonctionnalités absentes de ERE
grep -P motif fichier
```

PCRE apporte des fonctionnalités avancées non disponibles en ERE/BRE :

- **Lookahead / Lookbehind** : `(?=...)` (lookahead positif) / `(?<!...)` (lookbehind négatif)
- **Classes de caractères raccourcies** :
    - `\d` : un chiffre
    - `\w` : un caractère de mot (lettre, chiffre, underscore)
    - `\s` : un espace (espace, tabulation, saut de ligne)
- **Capture de groupes et rétro-référence** via des parenthèses

```bash
# Exemple : détecter un mot dupliqué consécutif (ex: "le le", "the the")
grep -P '(\w+)\s+\1' fichier.txt
```

- `(\w+)` : capture le premier mot et le place dans le groupe `\1`
- `\s+` : cherche un ou plusieurs espaces
- `\1` : exige de retrouver exactement la même valeur que le premier groupe capturé

!!! note "Disponibilité de PCRE"
    L'option `-P` dépend de la compilation de `grep` avec le support PCRE (`libpcre`). Sur certains systèmes minimalistes (conteneurs Alpine, busybox), `-P` peut être absent. Vérifie avec `grep --version` ou teste directement la commande avant de t'y fier en environnement contraint.

## 3. Commandes et cas d'usage fréquents

### Recherche insensible à la casse

```bash
# Ignore la casse (majuscules/minuscules) lors de la recherche
grep -i "password" fichier.txt
```

### Inverser la correspondance

```bash
# Affiche uniquement les lignes qui NE correspondent PAS au motif
grep -v "DEBUG" logfile.log
```

### Recherche récursive dans une arborescence

```bash
# Parcourt récursivement tous les fichiers d'un dossier à la recherche du motif
grep -r "API_KEY" /var/www/
```

### Afficher le contexte autour d'un résultat

```bash
# Affiche 3 lignes avant (-B) et après (-A) chaque ligne trouvée
grep -A 3 -B 3 "Failed password" /var/log/auth.log

# Raccourci : affiche 3 lignes avant ET après
grep -C 3 "Failed password" /var/log/auth.log
```

### Lister uniquement les fichiers correspondants

```bash
# Affiche uniquement le nom des fichiers contenant le motif
grep -l "root:" -r /etc/

# Affiche uniquement le nom des fichiers NE contenant PAS le motif
grep -L "root:" -r /etc/
```

### Numéroter les lignes et compter les occurrences

```bash
# Préfixe chaque ligne trouvée par son numéro dans le fichier
grep -n "error" app.log

# Compte uniquement le nombre de lignes correspondantes (par fichier)
grep -c "error" app.log
```

### Extraire uniquement la portion correspondante

```bash
# N'affiche que la partie du texte qui correspond au motif, pas la ligne entière
grep -o -E "([0-9]{1,3}\.){3}[0-9]{1,3}" access.log
```

### Correspondance de mot exact ou de ligne entière

```bash
# -w : force la correspondance sur un mot entier (évite de matcher "administrator" avec "admin")
grep -w "admin" users.txt

# -x : force la correspondance sur la ligne entière
grep -x "root" users.txt
```

## 4. Options et flags utiles

| Flag / Option | Description | Exemple |
| --- | --- | --- |
| `-i` | Insensible à la casse | `grep -i "erreur" fichier.log` |
| `-v` | Conserve uniquement les lignes qui ne matchent PAS le filtre | `grep -v "OK" fichier.log` |
| `-w` | Force la correspondance du mot exact | `grep -w "cat" fichier.txt` |
| `-x` | Force la correspondance de la ligne entière | `grep -x "root" fichier.txt` |
| `-o` | N'affiche que la partie exacte qui correspond (pas la ligne entière) | `grep -o "[0-9]+" fichier.txt` |
| `-A N` | Affiche N lignes après la ligne trouvée | `grep -A 5 "motif" fichier.txt` |
| `-B N` | Affiche N lignes avant la ligne trouvée | `grep -B 5 "motif" fichier.txt` |
| `-C N` | Affiche N lignes avant et après la ligne trouvée | `grep -C 5 "motif" fichier.txt` |
| `-r` | Parcourt récursivement les sous-dossiers | `grep -r "motif" ./dossier` |
| `-m N` | Limite l'affichage à N résultats | `grep -m 3 "motif" fichier.txt` |
| `-l` | Affiche uniquement le nom des fichiers contenant le motif | `grep -l "motif" *.log` |
| `-L` | Affiche uniquement le nom des fichiers ne contenant PAS le motif | `grep -L "motif" *.log` |
| `-n` | Préfixe chaque ligne extraite par son numéro de ligne | `grep -n "motif" fichier.txt` |
| `-c` | Compte uniquement le nombre de lignes correspondantes par fichier | `grep -c "motif" fichier.txt` |
| `-E` | Active le mode Extended Regular Expression (ERE) | `grep -E "abc\|def" fichier.txt` |
| `-F` | Recherche littérale, sans interprétation regex | `grep -F "192.168.1.1" fichier.txt` |
| `-P` | Active le mode Perl Compatible Regular Expression (PCRE) | `grep -P "\d{3}-\d{4}" fichier.txt` |

!!! tip "Compléments utiles non mentionnés dans les notes initiales"
    Quelques options additionnelles fréquemment utilisées en pratique :

    - `-e motif` : permet de spécifier plusieurs motifs de recherche (`grep -e "erreur" -e "warning" fichier.log`)
    - `-f fichier_motifs` : lit les motifs de recherche depuis un fichier (un motif par ligne)
    - `-H` : affiche le nom du fichier même s'il n'y en a qu'un seul (utile en scripting pour homogénéiser la sortie)
    - `--color=auto` : met en surbrillance la portion correspondante dans le terminal
    - `-a` : force le traitement d'un fichier binaire comme du texte (utile pour chercher une chaîne dans un binaire)
    - `-z` : traite les lignes comme séparées par un octet nul plutôt qu'un saut de ligne (utile avec `find -print0`)

## 5. Rappels sur la syntaxe des expressions régulières

| Symbole | Signification |
| --- | --- |
| `^` | Début de ligne |
| `$` | Fin de ligne |
| `^$` | Ligne vide |
| `.` | N'importe quel caractère unique |
| `[classe]` | Plage / ensemble de caractères |
| `[^classe]` | Exclut la plage / l'ensemble de caractères |
| `\b` | Limite de mot |
| `{X}` | Se répète exactement X fois |
| `{X,}` | Se répète au moins X fois |
| `{X,Y}` | Se répète entre X et Y fois |

## 6. Bonnes pratiques & pièges à éviter

!!! warning "Échappement des métacaractères selon le moteur"
    En mode BRE (par défaut), les métacaractères `+`, `?`, `|`, `{}` doivent être échappés (`\+`, `\?`, `\|`) pour être interprétés comme des opérateurs regex — sinon ils sont traités littéralement. C'est une source d'erreur fréquente lors du passage d'un script `grep -E` vers un `grep` classique (ou inversement).

!!! warning "Faux positifs avec les recherches non ancrées"
    Une recherche sans `-w` ou `^...$` peut matcher des sous-chaînes indésirables (ex: `grep "admin"` matchera aussi `administrator`, `subadmin`, etc.). Utilise `-w` pour un mot exact ou `-x` pour une ligne entière quand la précision est critique (ex: recherche de comptes utilisateurs).

!!! warning "Performance sur de gros volumes"
    `grep -r` sur une arborescence volumineuse peut être lent. Pour des recherches ciblées par type de fichier, privilégie `grep -r --include="*.log"` ou combine avec `find . -name "*.log" -exec grep motif {} +`. Pour des besoins intensifs de recherche récursive, l'outil `ripgrep` (`rg`) est une alternative nettement plus rapide et respecte nativement `.gitignore`.

!!! note "Sensibilité à la locale"
    Le comportement des classes de caractères (`[a-z]`, `\w`, etc.) peut varier selon la locale du système (`LC_ALL`, `LANG`). Pour un comportement prévisible en script, force la locale : `LC_ALL=C grep ...`.

---