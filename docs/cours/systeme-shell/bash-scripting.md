# 🐚 Guide Ultime & Référence Complète : Bash Scripting

!!! info "À propos de ce guide"
    Cette documentation couvre le Bash Scripting du niveau débutant à expert, sans simplification. Chaque section fournit la syntaxe exacte, des tableaux de référence et des exemples exploitables tels quels.

---

## 1. Structure de base & Bonnes pratiques

### 1.1 Le Shebang

Le shebang (`#!`) est la toute première ligne d'un script. Il indique au système quel interpréteur utiliser pour exécuter le fichier.

```bash
#!/bin/bash
```

```bash
#!/usr/bin/env bash
```

| Forme | Fonctionnement | Avantages | Inconvénients |
|---|---|---|---|
| `#!/bin/bash` | Chemin absolu et fixe vers l'exécutable `bash` | Prévisible, rapide (pas de résolution supplémentaire) | Échoue si `bash` n'est pas installé exactement à `/bin/bash` (rare mais possible sur certains BSD, NixOS, etc.) |
| `#!/usr/bin/env bash` | Utilise `env` pour rechercher `bash` dans le `$PATH` | Portable entre systèmes où `bash` n'est pas à `/bin/bash` | Dépend de la configuration du `$PATH` de l'utilisateur exécutant le script ; théoriquement plus lent (appel supplémentaire à `env`) |

!!! tip "Bonne pratique"
    Pour un script destiné à être distribué (outil open source, script portable macOS/Linux), préférez `#!/usr/bin/env bash`. Pour un script système interne dont l'environnement est maîtrisé (serveur de production, conteneur), `#!/bin/bash` est plus déterministe.

!!! warning "Le shebang doit être la ligne 1"
    Aucun caractère, y compris un espace ou un BOM (Byte Order Mark UTF-8), ne doit précéder `#!`. Un fichier édité sous Windows peut introduire un BOM invisible qui casse le shebang.

### 1.2 Mode strict : `set -euo pipefail`

Bash est par défaut extrêmement permissif : il continue son exécution même après une erreur, ignore les variables non définies et masque les échecs dans les pipelines. Le "mode strict" corrige ces trois comportements.

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

| Option | Nom complet | Effet détaillé |
|---|---|---|
| `set -e` | `errexit` | Le script s'arrête immédiatement si une commande se termine avec un statut de sortie non nul (≠ 0). Exceptions notables : commandes dans une condition (`if`, `while`, `&&`, `\|\|`), commandes précédées de `!`, et dernière commande d'une fonction appelée dans un contexte testé. |
| `set -u` | `nounset` | Toute référence à une variable non définie provoque une erreur immédiate au lieu d'être silencieusement remplacée par une chaîne vide. Évite les bugs de typo (`$Directoy` au lieu de `$Directory`). |
| `set -o pipefail` | `pipefail` | Dans un pipeline (`cmd1 \| cmd2 \| cmd3`), le code de retour global devient celui de la première commande qui échoue, et non systématiquement celui de la dernière commande (comportement par défaut de Bash). |
| `IFS=$'\n\t'` | Internal Field Separator | Change le séparateur de champ par défaut (espace, tabulation, saut de ligne) pour ne conserver que tabulation et saut de ligne. Réduit les risques de découpage incorrect sur des noms de fichiers contenant des espaces. |

!!! danger "Piège classique avec `set -e`"
    `set -e` **n'arrête pas** le script dans certains cas contre-intuitifs :

    ```bash
    set -e
    false && echo "jamais affiché"   # OK, -e s'applique normalement
    if false; then echo "test"; fi   # -e ignoré dans une condition
    false || echo "rattrapé"         # -e ignoré car la commande fait partie d'un test logique
    resultat=$(false)                # -e ignoré : substitution de commande dans une affectation simple
    ```

    Pour ce dernier cas, utilisez systématiquement une vérification explicite ou `set -e` combiné à une gestion via `trap ERR`.

!!! tip "Fonction utilitaire de log/erreur"
    ```bash
    err() {
        echo "[ERREUR] $*" >&2
        exit 1
    }

    [[ -f "$fichier" ]] || err "Le fichier $fichier est introuvable."
    ```

### 1.3 Commentaires et en-têtes professionnels

```bash
#!/usr/bin/env bash
#
# Nom du script : deploy.sh
# Description   : Déploie l'application sur l'environnement cible.
# Auteur        : Équipe DevOps
# Date création : 2026-01-15
# Version       : 1.2.0
# Usage         : ./deploy.sh [-e environnement] [-v]
#
# Dépendances   : docker, jq, curl
#
set -euo pipefail

# --- Ceci est un commentaire de ligne unique ---

: '
Ceci est un commentaire
sur plusieurs lignes,
en utilisant le "no-op" : suivi de guillemets.
'
```

!!! info "Astuce du commentaire multiligne"
    Bash n'a pas de syntaxe native pour les commentaires multilignes. L'astuce `: '...'` fonctionne car `:` est une commande "no-op" (ne fait rien, retourne toujours 0) qui accepte n'importe quel argument, y compris une chaîne multiligne entre guillemets simples.

### 1.4 Exécution et permissions

| Commande | Effet |
|---|---|
| `chmod +x script.sh` | Ajoute le droit d'exécution pour tous les utilisateurs (selon l'umask) |
| `chmod u+x script.sh` | Ajoute le droit d'exécution uniquement pour le propriétaire |
| `chmod 755 script.sh` | Propriétaire : rwx, Groupe : r-x, Autres : r-x |
| `./script.sh` | Exécute le script dans un nouveau sous-shell, en utilisant le shebang |
| `bash script.sh` | Exécute explicitement avec `bash`, sans nécessiter les droits d'exécution ni le shebang |
| `source script.sh` ou `. script.sh` | Exécute le script **dans le shell courant** (pas de sous-shell) : les variables et fonctions définies restent disponibles après |

!!! warning "`./script.sh` vs `source script.sh`"
    `./script.sh` crée un nouveau processus : toute variable d'environnement exportée (`export`) ou tout `cd` effectué à l'intérieur du script **n'affecte pas** le shell parent. `source script.sh` s'exécute dans le shell actuel : un `cd` ou une variable définie dans le script modifiera bien votre session courante. C'est la technique utilisée pour les fichiers comme `.bashrc` ou les scripts d'activation d'environnements virtuels Python (`source venv/bin/activate`).

---

## 2. Variables & Portée

### 2.1 Syntaxe de base

```bash
nom="valeur"      # Correct : aucun espace autour du =
nom = "valeur"     # INCORRECT : Bash interprète "nom" comme une commande
echo "$nom"
```

!!! danger "Zéro espace autour du `=`"
    `nom = "valeur"` provoque l'erreur `nom: command not found`, car Bash essaie d'exécuter `nom` avec les arguments `=` et `"valeur"`. L'affectation de variable exige une adjacence stricte : `nom="valeur"`.

### 2.2 Variables locales vs globales

```bash
variable_globale="je suis visible partout"

ma_fonction() {
    local variable_locale="je n'existe que dans cette fonction"
    variable_globale="modifiée depuis la fonction"
    echo "Interne : $variable_locale"
}

ma_fonction
echo "Externe : $variable_globale"      # affiche "modifiée depuis la fonction"
echo "Externe : $variable_locale"       # affiche une chaîne vide (variable inexistante hors fonction)
```

| Type | Mot-clé | Portée |
|---|---|---|
| Globale | (aucun) | Visible dans tout le script, y compris dans les fonctions appelées après sa définition |
| Locale | `local` | Visible uniquement à l'intérieur de la fonction où elle est déclarée, y compris dans les sous-fonctions appelées depuis celle-ci |

!!! tip "Toujours utiliser `local` dans les fonctions"
    Sans `local`, toute variable créée dans une fonction devient globale par défaut, ce qui peut écraser silencieusement une variable de même nom ailleurs dans le script. C'est une source fréquente de bugs difficiles à tracer.

### 2.3 Variables d'environnement (`export`)

```bash
MON_VAR="valeur"          # variable de shell locale au script
export MA_VAR_ENV="valeur"  # variable d'environnement, héritée par les processus enfants

# Export et affectation en une ligne :
export AUTRE_VAR="valeur"

# Voir toutes les variables exportées :
export -p
```

`export` marque une variable pour qu'elle soit transmise à tout processus **enfant** lancé depuis le shell courant (un script appelé, une commande externe, etc.). Une variable non exportée reste strictement locale au shell/script actuel.

### 2.4 Variables d'environnement intégrées

| Variable | Description |
|---|---|
| `$PATH` | Liste des répertoires (séparés par `:`) où le shell recherche les exécutables |
| `$HOME` | Répertoire personnel de l'utilisateur courant |
| `$PWD` | Répertoire de travail courant (mis à jour automatiquement à chaque `cd`) |
| `$OLDPWD` | Répertoire de travail précédent (utilisé par `cd -`) |
| `$USER` | Nom de l'utilisateur exécutant le shell |
| `$SHELL` | Chemin vers le shell de connexion par défaut de l'utilisateur (pas forcément le shell en cours d'exécution) |
| `$HOSTNAME` | Nom d'hôte de la machine |
| `$LANG` / `$LC_ALL` | Paramètres de localisation (langue, formats de date/nombre) |
| `$TERM` | Type de terminal utilisé |
| `$RANDOM` | Génère un entier pseudo-aléatoire entre 0 et 32767 à chaque lecture |
| `$SECONDS` | Nombre de secondes écoulées depuis le lancement du shell |
| `$IFS` | Internal Field Separator, utilisé pour le découpage de mots |

### 2.5 Variables spéciales Bash

| Variable | Description |
|---|---|
| `$0` | Nom du script (ou du shell si interactif) |
| `$1` à `$9` | Les 9 premiers arguments positionnels passés au script ou à la fonction |
| `${10}`, `${11}`... | Arguments positionnels au-delà de 9 — **les accolades sont obligatoires**, car `$10` serait interprété comme `${1}0` |
| `$#` | Nombre total d'arguments positionnels |
| `$@` | Tous les arguments positionnels, individuellement |
| `$*` | Tous les arguments positionnels, comme une seule chaîne |
| `$?` | Code de sortie (statut) de la dernière commande exécutée |
| `$$` | PID (identifiant de processus) du shell/script courant |
| `$!` | PID du dernier processus lancé en arrière-plan (`&`) |
| `$-` | Options actuellement actives du shell (ex. `himBH`) |
| `$_` | Dernier argument de la commande précédente |

```bash
#!/usr/bin/env bash
echo "Nom du script : $0"
echo "Premier argument : $1"
echo "Nombre d'arguments : $#"
echo "PID du script : $$"

sleep 100 &
echo "PID du processus en arrière-plan : $!"

ls /chemin/inexistant
echo "Code de retour de la commande précédente : $?"
```

### 2.6 `$@` vs `$*` : la différence exacte

C'est l'un des pièges les plus fréquents et les plus mal compris de Bash.

| Expression | Sans guillemets | Avec guillemets `"..."` |
|---|---|---|
| `$@` | Équivalent à `$*` : les mots sont re-découpés selon `$IFS`, perte des arguments contenant des espaces | Se développe en **autant de mots séparés que d'arguments d'origine** : `"$1" "$2" "$3"...` — comportement quasi toujours souhaité |
| `$*` | Concatène tous les arguments, re-découpés selon `$IFS` | Se développe en **une seule chaîne**, avec les arguments joints par le **premier caractère de `$IFS`** (espace par défaut) : `"$1$IFS$2$IFS$3..."` |

```bash
#!/usr/bin/env bash
# Appel : ./script.sh "arg un" "arg deux"

for a in $@; do echo "non-quoté \$@: [$a]"; done
# Sortie : 4 mots séparés (arg, un, arg, deux) -> arguments "cassés"

for a in "$@"; do echo "quoté \"\$@\": [$a]"; done
# Sortie : 2 mots, respectant les arguments d'origine -> [arg un] [arg deux]

for a in "$*"; do echo "quoté \"\$*\": [$a]"; done
# Sortie : 1 seul mot -> [arg un arg deux]
```

!!! danger "Règle à retenir"
    Utilisez **toujours** `"$@"` (avec guillemets) pour transmettre fidèlement une liste d'arguments à une autre commande ou fonction (par exemple `ma_fonction "$@"`). C'est la seule forme qui préserve exactement les arguments d'origine, espaces compris.

---

## 3. Substitutions & Expansion de variables (Pure Bash)

### 3.1 Substitution de commande

```bash
date_actuelle=$(date +%Y-%m-%d)      # forme moderne, recommandée
date_actuelle=`date +%Y-%m-%d`       # forme historique (backticks)
```

| Forme | Avantages | Inconvénients |
|---|---|---|
| `$(commande)` | Imbrication facile (`$(cmd1 $(cmd2))`), lisible, échappement simplifié | Aucun, c'est la forme standard moderne |
| `` `commande` `` | Compatible avec les très vieux shells POSIX | Imbrication pénible (nécessite d'échapper les backticks internes `` \` ``), moins lisible, obsolète |

!!! tip "Toujours préférer `$()`"
    `$(...)` est plus lisible, s'imbrique nativement et évite les problèmes d'échappement des backticks. Il n'y a aucune raison d'utiliser la syntaxe historique dans du code nouveau.

### 3.2 Valeurs par défaut et substitutions conditionnelles

| Syntaxe | Comportement |
|---|---|
| `${var:-defaut}` | Si `var` est non définie ou vide, retourne `defaut` (sans modifier `var`) |
| `${var:=defaut}` | Si `var` est non définie ou vide, **assigne** `defaut` à `var` et le retourne |
| `${var:?message}` | Si `var` est non définie ou vide, affiche `message` sur stderr et quitte le script avec un code d'erreur |
| `${var:+alt}` | Si `var` **est** définie et non vide, retourne `alt` (sinon retourne une chaîne vide) |

```bash
echo "${nom:-Invité}"          # affiche "Invité" si $nom est vide/non définie, sans la modifier
: "${nom:=Invité}"             # affecte "Invité" à $nom si elle est vide/non définie
echo "${config_path:?Erreur : la variable config_path doit être définie}"
echo "${debug:+--verbose}"     # affiche "--verbose" uniquement si $debug est définie et non vide
```

!!! info "Note sur `:` vs sans `:`"
    Chaque opérateur existe aussi sans le `:` initial (`${var-defaut}`, `${var=defaut}`, etc.). La différence : avec `:`, l'opérateur se déclenche si la variable est **non définie OU vide**. Sans `:`, il se déclenche uniquement si la variable est **non définie** (une variable définie avec une chaîne vide `var=""` ne déclenche pas la substitution).

### 3.3 Manipulation de chaînes

```bash
chaine="Bonjour_Le_Monde.txt"
```

| Opération | Syntaxe | Exemple | Résultat |
|---|---|---|---|
| Longueur | `${#var}` | `${#chaine}` | `20` |
| Extraction (substring) | `${var:offset:longueur}` | `${chaine:9:2}` | `Le` |
| Extraction depuis la fin | `${var: -N}` (espace obligatoire avant le `-`) | `${chaine: -4}` | `.txt` |
| Suppression motif le plus court, au début | `${var#pattern}` | `${chaine#*_}` | `Le_Monde.txt` |
| Suppression motif le plus long, au début | `${var##pattern}` | `${chaine##*_}` | `Monde.txt` |
| Suppression motif le plus court, à la fin | `${var%pattern}` | `${chaine%.*}` | `Bonjour_Le_Monde` |
| Suppression motif le plus long, à la fin | `${var%%pattern}` | `${chaine%%_*}` | `Bonjour` |
| Remplacement première occurrence | `${var/pattern/repl}` | `${chaine/_/-}` | `Bonjour-Le_Monde.txt` |
| Remplacement toutes occurrences | `${var//pattern/repl}` | `${chaine//_/-}` | `Bonjour-Le-Monde.txt` |
| Remplacement en début de chaîne | `${var/#pattern/repl}` | `${chaine/#Bonjour/Salut}` | `Salut_Le_Monde.txt` |
| Remplacement en fin de chaîne | `${var/%pattern/repl}` | `${chaine/%.txt/.md}` | `Bonjour_Le_Monde.md` |
| Majuscules totales | `${var^^}` | `${chaine^^}` | `BONJOUR_LE_MONDE.TXT` |
| Minuscules totales | `${var,,}` | `${chaine,,}` | `bonjour_le_monde.txt` |
| Majuscule première lettre | `${var^}` | `${chaine^}` | `Bonjour_Le_Monde.txt` (déjà majuscule ici) |
| Minuscule première lettre | `${var,}` | `${chaine,}` | `bonjour_Le_Monde.txt` |

!!! tip "Astuce mnémotechnique # et %"
    `#` (croisillon, en haut à gauche du clavier) supprime depuis le **début** ("gauche") ; `%` supprime depuis la **fin** ("droite"). Doublé (`##`, `%%`), l'effet est **glouton** (greedy) : il retire la correspondance la plus longue possible plutôt que la plus courte.

```bash
# Exemple pratique : extraire le nom de fichier et l'extension d'un chemin
chemin="/var/log/application/erreurs.2026-01-15.log"

nom_fichier="${chemin##*/}"       # erreurs.2026-01-15.log
repertoire="${chemin%/*}"         # /var/log/application
extension="${nom_fichier##*.}"    # log
base="${nom_fichier%.*}"          # erreurs.2026-01-15

echo "Répertoire : $repertoire"
echo "Fichier    : $nom_fichier"
echo "Base       : $base"
echo "Extension  : $extension"
```

---

## 4. Arithmetic & Calculs

### 4.1 Évaluation arithmétique

| Syntaxe | Usage |
|---|---|
| `(( expression ))` | Évalue une expression arithmétique comme **commande** ; renvoie un code de sortie (0 si le résultat est non-nul/vrai, 1 sinon). Utilisée pour les conditions et incrémentations, pas pour capturer une valeur. |
| `$(( expression ))` | Évalue une expression arithmétique et **retourne le résultat** sous forme de chaîne, à assigner ou afficher. |
| `let expression` | Forme historique équivalente à `(( ))`, moins lisible, à éviter dans du code nouveau. |

```bash
a=5
b=3

resultat=$((a + b))
echo "$resultat"          # 8

if (( a > b )); then
    echo "a est plus grand que b"
fi

(( a++ ))                 # incrémente a, ne rien afficher
echo "$a"                 # 6
```

### 4.2 Opérateurs arithmétiques complets

| Opérateur | Description | Exemple | Résultat |
|---|---|---|---|
| `+` | Addition | `$((5 + 3))` | `8` |
| `-` | Soustraction | `$((5 - 3))` | `2` |
| `*` | Multiplication | `$((5 * 3))` | `15` |
| `/` | Division entière | `$((7 / 2))` | `3` |
| `%` | Modulo (reste) | `$((7 % 2))` | `1` |
| `**` | Puissance | `$((2 ** 8))` | `256` |
| `++` | Incrémentation (pré/post) | `((i++))`, `((++i))` | +1 |
| `--` | Décrémentation (pré/post) | `((i--))`, `((--i))` | -1 |
| `+=` | Addition + affectation | `((total += 10))` | — |
| `-=` | Soustraction + affectation | `((total -= 5))` | — |
| `*=` | Multiplication + affectation | `((total *= 2))` | — |
| `/=` | Division + affectation | `((total /= 2))` | — |
| `%=` | Modulo + affectation | `((total %= 3))` | — |
| `&`, `\|`, `^`, `~` | ET, OU, XOR, NON binaires | `$((6 & 3))` | `2` |
| `<<`, `>>` | Décalage de bits gauche/droite | `$((1 << 4))` | `16` |
| `<`, `<=`, `>`, `>=`, `==`, `!=` | Comparaisons (retournent 1 vrai / 0 faux) | `$((5 > 3))` | `1` |
| `&&`, `\|\|`, `!` | ET, OU, NON logiques | `$((1 && 0))` | `0` |
| `?:` | Opérateur ternaire | `$((a > b ? a : b))` | le plus grand des deux |

### 4.3 Limites de l'arithmétique entière et calcul flottant

!!! warning "Bash ne gère que les entiers"
    L'arithmétique native de Bash (`(( ))`, `$(( ))`) est **strictement entière**. Toute opération impliquant des décimales est soit tronquée, soit provoque une erreur.

    ```bash
    echo $((10 / 3))     # 3, et non 3.333... (division entière, troncature)
    echo $((10.5 + 2))   # erreur : "10.5: syntax error: invalid arithmetic operator"
    ```

Pour du calcul flottant, deux outils externes sont couramment utilisés :

```bash
# Avec bc (basic calculator)
resultat=$(echo "scale=4; 10 / 3" | bc)
echo "$resultat"              # 3.3333

resultat=$(bc -l <<< "sqrt(2)")
echo "$resultat"              # 1.41421356237309504880

# Avec awk
resultat=$(awk 'BEGIN { printf "%.4f", 10/3 }')
echo "$resultat"              # 3.3333
```

| Outil | Avantages | Inconvénients |
|---|---|---|
| `bc` | Syntaxe proche des mathématiques, précision configurable (`scale=N`), fonctions avancées (`sqrt`, `l`, `e`, `s`, `c`) avec `-l` | Pas toujours installé par défaut sur les systèmes minimalistes |
| `awk` | Quasi universellement disponible, rapide, pratique pour du calcul dans un contexte de traitement de texte | Syntaxe moins naturelle pour du calcul pur isolé |

---

## 5. Conditions & Opérateurs de test

### 5.1 `[ ... ]` vs `[[ ... ]]` vs `test`

| Forme | Nature | Portabilité | Fonctionnalités |
|---|---|---|---|
| `test expression` | Commande externe/builtin POSIX | POSIX, portable sur `sh` | Fonctionnalités de base uniquement |
| `[ expression ]` | Alias de `test` (le `]` final est un argument littéral attendu par la commande) | POSIX, portable sur `sh` | Identique à `test` ; sensible aux erreurs de quotage, pas de `&&`/`\|\|`/regex internes |
| `[[ expression ]]` | Mot-clé du shell (keyword), spécifique à Bash/Ksh/Zsh | Non-POSIX, propre à Bash et dérivés | Découpage de mots désactivé (les variables non quotées sont sûres), supporte `&&`, `\|\|`, `<`, `>` sans échappement, et `=~` pour les regex |

```bash
# [ ] : nécessite de quoter les variables pour éviter les erreurs
var=""
if [ -z "$var" ]; then echo "vide"; fi     # OK avec guillemets
if [ -z $var ]; then echo "vide"; fi       # risque d'erreur si $var contient des espaces ou est vide sans guillemets

# [[ ]] : plus sûr, pas besoin de quoter systématiquement (mais recommandé quand même par lisibilité)
if [[ -z $var ]]; then echo "vide"; fi     # fonctionne même sans guillemets

# [[ ]] permet les opérateurs logiques et regex directement
if [[ $age -ge 18 && $age -lt 65 ]]; then echo "actif"; fi
if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then echo "email valide"; fi
```

!!! tip "Recommandation"
    Dans un script Bash (identifié par le shebang `#!/bin/bash`), utilisez systématiquement `[[ ... ]]` : plus sûr, plus lisible, plus puissant. Réservez `[ ... ]`/`test` aux scripts devant rester compatibles POSIX (`#!/bin/sh`).

### 5.2 Tests sur les fichiers

| Opérateur | Vrai si... |
|---|---|
| `-e fichier` | Le chemin existe (quel que soit son type) |
| `-f fichier` | C'est un fichier régulier |
| `-d fichier` | C'est un répertoire |
| `-L fichier` | C'est un lien symbolique |
| `-r fichier` | Le fichier est lisible par l'utilisateur courant |
| `-w fichier` | Le fichier est accessible en écriture |
| `-x fichier` | Le fichier est exécutable |
| `-s fichier` | Le fichier existe et sa taille est supérieure à 0 |
| `-p fichier` | C'est un tube nommé (named pipe / FIFO) |
| `-S fichier` | C'est un socket |
| `-b fichier` | C'est un périphérique bloc |
| `-c fichier` | C'est un périphérique caractère |
| `-nt fichier2` | Le fichier est plus récent (newer than) que `fichier2` |
| `-ot fichier2` | Le fichier est plus ancien (older than) que `fichier2` |
| `-ef fichier2` | Les deux chemins pointent vers le même inode (même fichier physique) |

```bash
if [[ -f "/etc/hosts" ]]; then echo "fichier existant"; fi
if [[ -d "/var/log" ]]; then echo "répertoire existant"; fi
if [[ "config.new" -nt "config.old" ]]; then echo "config.new est plus récent"; fi
```

### 5.3 Tests de chaînes

| Opérateur | Vrai si... |
|---|---|
| `-z chaine` | La chaîne est vide (zero length) |
| `-n chaine` | La chaîne est non vide |
| `chaine1 = chaine2` | Les chaînes sont égales (POSIX, préférer à `==` pour `[ ]`) |
| `chaine1 == chaine2` | Les chaînes sont égales (spécifique à `[[ ]]`, supporte aussi le pattern matching à droite) |
| `chaine1 != chaine2` | Les chaînes sont différentes |
| `chaine1 < chaine2` | `chaine1` précède `chaine2` dans l'ordre lexicographique (nécessite `[[ ]]` ou `\<`/`\>` échappés dans `[ ]`) |
| `chaine1 > chaine2` | `chaine1` suit `chaine2` dans l'ordre lexicographique |
| `chaine =~ regex` | La chaîne correspond à l'expression régulière étendue (ERE) — **uniquement dans `[[ ]]`** |

```bash
nom=""
[[ -z "$nom" ]] && echo "nom vide"

fruit="pomme"
[[ "$fruit" == "pomme" ]] && echo "c'est une pomme"
[[ "$fruit" == p* ]] && echo "commence par p"   # pattern matching, pas regex

if [[ "$fruit" =~ ^p.*e$ ]]; then
    echo "correspond à la regex"
fi
```

### 5.4 Tests numériques

| Opérateur | Signification |
|---|---|
| `-eq` | Égal (equal) |
| `-ne` | Différent (not equal) |
| `-lt` | Inférieur strict (less than) |
| `-le` | Inférieur ou égal (less or equal) |
| `-gt` | Supérieur strict (greater than) |
| `-ge` | Supérieur ou égal (greater or equal) |

```bash
age=25
if [[ "$age" -ge 18 ]]; then
    echo "majeur"
fi
```

!!! warning "Ne confondez pas comparaison de chaînes et comparaison numérique"
    `[[ "10" > "9" ]]` compare **lexicographiquement** ("1" < "9" en ASCII) et renvoie **faux**. `[[ 10 -gt 9 ]]` compare **numériquement** et renvoie **vrai**. Utiliser le mauvais opérateur est une source classique de bugs silencieux.

### 5.5 Opérateurs logiques

| Contexte | ET | OU | NON |
|---|---|---|---|
| Entre commandes (shell) | `cmd1 && cmd2` | `cmd1 \|\| cmd2` | `! cmd1` |
| Intérieur de `[[ ... ]]` | `[[ cond1 && cond2 ]]` | `[[ cond1 \|\| cond2 ]]` | `[[ ! cond1 ]]` |
| Intérieur de `[ ... ]` (POSIX historique) | `[ cond1 -a cond2 ]` | `[ cond1 -o cond2 ]` | `[ ! cond1 ]` |

!!! danger "`-a` et `-o` sont dépréciés"
    POSIX marque `-a` et `-o` (dans `[ ]`) comme obsolètes en raison d'ambiguïtés de parsing avec des expressions complexes. Préférez toujours des tests `[ ]` séparés combinés par `&&`/`||` au niveau shell, ou passez directement à `[[ ]]` :

    ```bash
    # À éviter :
    [ "$a" -eq 1 -a "$b" -eq 2 ]

    # Préférer :
    [[ "$a" -eq 1 && "$b" -eq 2 ]]
    # ou :
    [ "$a" -eq 1 ] && [ "$b" -eq 2 ]
    ```

---

## 6. Structures de contrôle

### 6.1 Conditions `if / elif / else / fi`

```bash
# Syntaxe bloc classique
if [[ "$statut" == "actif" ]]; then
    echo "Utilisateur actif"
elif [[ "$statut" == "suspendu" ]]; then
    echo "Utilisateur suspendu"
else
    echo "Statut inconnu"
fi

# Syntaxe one-line (avec point-virgules obligatoires)
if [[ -f "config.yml" ]]; then echo "trouvé"; else echo "absent"; fi

# Forme condensée avec && / ||
[[ -f "config.yml" ]] && echo "trouvé" || echo "absent"
```

!!! warning "Piège du `&&`/`||` en remplacement de `if/else`"
    `cond && action1 || action2` n'est **pas strictement équivalent** à un `if/else` : si `action1` échoue (code ≠ 0), `action2` sera **également exécutée**, ce qui peut ne pas être l'intention. Réservez cette forme aux cas simples et sans effet de bord risqué ; pour toute logique importante, préférez `if/then/else/fi`.

### 6.2 Aiguillage `case ... in ... esac`

```bash
lire_extension() {
    local fichier="$1"
    case "$fichier" in
        *.jpg|*.jpeg|*.png|*.gif)
            echo "Image"
            ;;
        *.mp4|*.mkv|*.avi)
            echo "Vidéo"
            ;;
        *.txt|*.md)
            echo "Texte"
            ;;
        *)
            echo "Type inconnu"
            ;;
    esac
}

lire_extension "photo.png"
```

| Élément | Rôle |
|---|---|
| `motif)` | Déclare un motif de correspondance (supporte les wildcards `*`, `?`, `[...]`) |
| `motif1\|motif2)` | Plusieurs motifs pour une même branche, séparés par `\|` |
| `;;` | Termine la branche normalement, saute directement à la fin du `case` (comportement classique, comme un `break`) |
| `;&` | Termine la branche mais **enchaîne** sur le bloc de code de la branche suivante **sans tester son motif** (fall-through inconditionnel) |
| `;;&` | Termine la branche mais **continue à tester** les motifs suivants dans l'ordre (contrairement à `;;` qui arrête tout) |
| `*)` | Motif joker, capture tout le reste — équivalent du `default` dans d'autres langages |

```bash
# Démonstration de ;;& (continue à tester les motifs suivants)
valeur="15"
case "$valeur" in
    [0-9]*)
        echo "C'est un nombre"
        ;;&
    1[0-9])
        echo "Entre 10 et 19"
        ;;&
    *5)
        echo "Se termine par 5"
        ;;
esac
# Affiche les trois lignes, car ;;& permet la poursuite des tests
```

### 6.3 Boucle `for`

```bash
# Style liste explicite
for fruit in pomme banane cerise; do
    echo "Fruit : $fruit"
done

# Style liste depuis un tableau
fruits=(pomme banane cerise)
for fruit in "${fruits[@]}"; do
    echo "Fruit : $fruit"
done

# Séquences avec accolades
for i in {1..10}; do
    echo "Nombre : $i"
done

# Séquences avec un pas (step)
for i in {0..20..5}; do
    echo "Multiple de 5 : $i"
done

# Style C (nécessite double parenthèses)
for ((i = 0; i < 10; i++)); do
    echo "Itération : $i"
done

# Style C avec pas et sens inversé
for ((i = 10; i > 0; i -= 2)); do
    echo "Décompte : $i"
done
```

!!! warning "`{1..$n}` ne fonctionne pas avec une variable"
    L'expansion d'accolades `{1..N}` est effectuée **avant** l'expansion des variables. `for i in {1..$n}; do` ne développera **pas** correctement si `n` est une variable — Bash traitera littéralement `{1..$n}` comme une chaîne si `$n` n'est pas connu au moment du parsing des accolades. Utilisez plutôt `seq` ou la boucle C-style :

    ```bash
    n=5
    for i in $(seq 1 "$n"); do echo "$i"; done      # fonctionne
    for ((i = 1; i <= n; i++)); do echo "$i"; done  # fonctionne, plus idiomatique
    ```

### 6.4 Boucle `while`

```bash
compteur=0
while [[ $compteur -lt 5 ]]; do
    echo "Compteur : $compteur"
    (( compteur++ ))
done

# Boucle infinie classique
while true; do
    echo "Ctrl+C pour arrêter"
    sleep 1
done

# Lecture d'un fichier ligne par ligne (méthode canonique)
while IFS= read -r ligne; do
    echo "Ligne lue : $ligne"
done < "fichier.txt"
```

!!! tip "Pourquoi `IFS= read -r ligne`"
    - `IFS=` (vide) empêche `read` de supprimer les espaces/tabulations en début et fin de ligne.
    - `-r` désactive l'interprétation des antislashs (`\`) comme caractères d'échappement, pour lire la ligne exactement telle qu'elle est écrite dans le fichier.
    - Sans ces deux options, des lignes contenant des espaces significatifs ou des backslashs (chemins Windows, regex, etc.) seraient altérées silencieusement.

!!! danger "Piège du sous-shell dans un pipe"
    ```bash
    compteur=0
    cat fichier.txt | while read -r ligne; do
        (( compteur++ ))
    done
    echo "$compteur"   # affiche 0 ! La boucle s'exécute dans un sous-shell
    ```
    Le pipe (`|`) crée un sous-shell pour la partie droite : toute variable modifiée dans la boucle `while` est perdue à sa sortie. Préférez la redirection `< fichier.txt` (comme dans l'exemple précédent) qui exécute la boucle dans le shell courant, ou utilisez la substitution de processus : `while read -r l; do ...; done < <(cat fichier.txt)`.

### 6.5 Boucle `until`

`until` est l'inverse logique de `while` : elle s'exécute **tant que la condition est fausse**.

```bash
compteur=0
until [[ $compteur -ge 5 ]]; do
    echo "Compteur : $compteur"
    (( compteur++ ))
done

# Attente active d'une condition externe
until curl -sf "http://localhost:8080/health" > /dev/null; do
    echo "Service pas encore prêt, nouvelle tentative dans 2s..."
    sleep 2
done
echo "Service opérationnel"
```

### 6.6 Contrôle de boucle : `break` et `continue`

```bash
for i in {1..10}; do
    if (( i == 5 )); then
        continue    # passe directement à l'itération suivante, saute le echo
    fi
    if (( i == 8 )); then
        break       # sort complètement de la boucle
    fi
    echo "$i"
done

# Niveaux d'imbrication : break N / continue N
for i in {1..3}; do
    for j in {1..3}; do
        if (( j == 2 )); then
            break 2   # sort des DEUX boucles imbriquées, pas seulement la boucle interne
        fi
        echo "i=$i j=$j"
    done
done
```

| Commande | Effet |
|---|---|
| `break` | Sort de la boucle la plus proche (interne) |
| `break N` | Sort de `N` niveaux de boucles imbriquées |
| `continue` | Passe directement à l'itération suivante de la boucle interne |
| `continue N` | Passe à l'itération suivante en remontant de `N` niveaux de boucles imbriquées |

---

## 7. Entrées / Sorties & Redirections

### 7.1 Descripteurs de fichier standards

| Descripteur | Nom | Usage par défaut |
|---|---|---|
| `0` | `stdin` (entrée standard) | Lecture des données entrantes (clavier, pipe, fichier) |
| `1` | `stdout` (sortie standard) | Sortie normale d'une commande (écran par défaut) |
| `2` | `stderr` (sortie d'erreur) | Messages d'erreur et diagnostics (écran par défaut, distinct de stdout) |

### 7.2 Redirections simples et combinées

| Syntaxe | Effet |
|---|---|
| `commande > fichier` | Redirige stdout vers `fichier`, en l'**écrasant** s'il existe |
| `commande >> fichier` | Redirige stdout vers `fichier`, en **ajoutant** à la fin (append) |
| `commande < fichier` | Utilise `fichier` comme entrée standard |
| `commande 2> fichier` | Redirige uniquement stderr vers `fichier` |
| `commande 2>> fichier` | Ajoute stderr à la fin de `fichier` |
| `commande 2>&1` | Redirige stderr vers **la même destination que stdout actuellement** |
| `commande > fichier 2>&1` | Redirige stdout vers `fichier`, **puis** fait pointer stderr vers cette même destination — ordre important ! |
| `commande &> fichier` | Raccourci Bash : redirige stdout **et** stderr vers `fichier` (écrase) |
| `commande &>> fichier` | Identique en mode append |
| `commande > /dev/null` | Jette la sortie standard (aucune trace, aucun affichage) |
| `commande 2> /dev/null` | Jette uniquement les erreurs |
| `commande > /dev/null 2>&1` | Rend la commande totalement silencieuse (ni sortie ni erreur) |

!!! danger "L'ordre des redirections compte"
    ```bash
    commande > fichier.log 2>&1    # CORRECT : stdout -> fichier.log, puis stderr suit stdout -> fichier.log
    commande 2>&1 > fichier.log    # INCORRECT (généralement) : stderr est d'abord dupliqué vers la destination
                                    # actuelle de stdout (le terminal), PUIS stdout seul est redirigé vers le
                                    # fichier. Résultat : stderr continue à s'afficher au terminal, seul
                                    # stdout va dans le fichier.
    ```
    Les redirections s'évaluent **de gauche à droite** ; l'ordre a un impact réel sur le résultat.

### 7.3 Pipes et sous-shells

```bash
# Pipe : la sortie standard de la commande de gauche devient l'entrée standard de la commande de droite
ps aux | grep "nginx" | sort -k3 -n -r | head -5

# Sous-shell explicite avec parenthèses : exécute dans un environnement enfant isolé
(cd /tmp && ls -la)
echo "$PWD"   # inchangé, car le cd a eu lieu dans le sous-shell
```

### 7.4 Process Substitution

La substitution de processus permet de traiter la sortie (ou l'entrée) d'une commande comme s'il s'agissait d'un fichier.

```bash
# <(commande) : traite la SORTIE d'une commande comme un fichier en lecture
diff <(sort fichier1.txt) <(sort fichier2.txt)

# Comparer les résultats de deux commandes distinctes sans fichiers temporaires
diff <(curl -s https://api1.example.com/data) <(curl -s https://api2.example.com/data)

# >(commande) : traite l'ENTRÉE d'une commande comme un fichier en écriture
commande_source | tee >(grep "ERREUR" > erreurs.log) >(grep "AVERTISSEMENT" > avertissements.log) > tout.log
```

!!! info "Cas d'usage type"
    La substitution de processus évite d'avoir à créer des fichiers temporaires intermédiaires uniquement pour comparer ou combiner des flux de données.

### 7.5 Here-Documents et Here-Strings

```bash
# Here-Document (<<) : injecte un bloc de texte multiligne comme entrée standard
cat <<EOF
Bonjour $USER,
Votre répertoire courant est $PWD.
La date du jour est $(date +%F).
EOF

# Here-Document avec délimiteur quoté : désactive l'expansion des variables (texte littéral)
cat <<'EOF'
Cette ligne contient $VARIABLE et $(commande) sans aucune expansion.
EOF

# Here-Document avec suppression des tabulations en début de ligne (<<-)
if true; then
	cat <<-EOF
	Ce texte peut être indenté avec des tabulations
	pour suivre l'indentation du script, sans que
	ces tabulations n'apparaissent dans la sortie.
	EOF
fi

# Here-String (<<<) : passe une simple chaîne comme entrée standard
grep "motif" <<< "$variable_a_tester"
bc <<< "5 + 3"
```

| Syntaxe | Usage |
|---|---|
| `<<EOF ... EOF` | Bloc de texte multiligne en entrée, avec expansion des variables/commandes |
| `<<'EOF' ... EOF` | Identique mais **sans** expansion (le délimiteur est quoté) |
| `<<-EOF ... EOF` | Identique à `<<EOF` mais ignore les tabulations de début de ligne (pas les espaces) |
| `<<< "chaine"` | Injecte une chaîne unique comme entrée standard, sans bloc multiligne |

### 7.6 Saisie utilisateur interactive avec `read`

| Option | Effet |
|---|---|
| `-p "texte"` | Affiche `texte` comme invite (prompt) avant la saisie, sans saut de ligne |
| `-s` | Mode silencieux : n'affiche pas les caractères saisis (pour les mots de passe) |
| `-n N` | Lit exactement `N` caractères puis retourne automatiquement, sans attendre Entrée |
| `-t N` | Timeout de `N` secondes ; `read` retourne un code d'erreur si rien n'est saisi à temps |
| `-r` | Désactive l'interprétation des antislashs comme caractères d'échappement (raw mode) |
| `-a tableau` | Stocke les mots saisis dans un tableau indexé plutôt qu'une seule variable |
| `-d delim` | Utilise `delim` comme séparateur de fin de saisie au lieu du saut de ligne par défaut |

```bash
read -rp "Entrez votre nom : " nom
echo "Bonjour, $nom !"

read -rsp "Mot de passe : " mdp
echo   # saut de ligne manuel car -s ne l'affiche pas automatiquement
echo "Mot de passe saisi (longueur : ${#mdp})"

read -rt 5 -p "Vous avez 5 secondes pour répondre : " reponse || echo "Temps écoulé !"

read -ra mots -p "Entrez plusieurs mots : "
echo "Nombre de mots saisis : ${#mots[@]}"
```

---

## 8. Fonctions

### 8.1 Déclaration

```bash
# Syntaxe POSIX (recommandée, portable)
nom_fonction() {
    echo "Corps de la fonction"
}

# Syntaxe spécifique Bash avec mot-clé "function"
function nom_fonction {
    echo "Corps de la fonction"
}

# Forme hybride (redondante mais valide en Bash)
function nom_fonction() {
    echo "Corps de la fonction"
}
```

| Syntaxe | Portabilité | Remarque |
|---|---|---|
| `nom() { ... }` | POSIX, fonctionne avec `sh`, `dash`, `bash`, `zsh` | Forme recommandée pour un code portable |
| `function nom { ... }` | Spécifique Bash/Ksh/Zsh | Plus explicite visuellement, mais non portable vers `sh`/`dash` |

### 8.2 Passage d'arguments

Les fonctions Bash reçoivent leurs arguments exactement comme un script reçoit les siens : via `$1`, `$2`, `$#`, `$@`, etc. — indépendamment des arguments positionnels du script appelant.

```bash
saluer() {
    local prenom="$1"
    local nom="$2"
    echo "Bonjour, $prenom $nom ! (${#@} arguments reçus)"
}

saluer "Jean" "Dupont"

# Transmission fidèle de tous les arguments reçus par le script à une fonction
traiter_tout() {
    for arg in "$@"; do
        echo "Traitement de : $arg"
    done
}
traiter_tout "$@"
```

### 8.3 Valeurs de retour

| Mécanisme | Usage | Limite |
|---|---|---|
| `return N` | Définit le **code de sortie** de la fonction (0 à 255), récupérable via `$?` juste après l'appel | Ne peut pas retourner de texte ni de nombre > 255 ; réservé à signaler succès/échec |
| `echo "valeur"` puis capture via `$(fonction)` | Permet de "retourner" n'importe quelle chaîne ou nombre en la capturant à l'appel | Crée un sous-shell (légère perte de performance, pas d'accès aux variables globales modifiées dans le sous-shell) |

```bash
est_pair() {
    local nombre="$1"
    if (( nombre % 2 == 0 )); then
        return 0   # 0 = succès = "vrai" en Bash
    else
        return 1   # non-zéro = échec = "faux"
    fi
}

if est_pair 42; then
    echo "42 est pair"
fi

calculer_carre() {
    local nombre="$1"
    echo $(( nombre * nombre ))
}

resultat=$(calculer_carre 7)
echo "Le carré est : $resultat"
```

!!! warning "`return` n'accepte que 0-255"
    `return` fonctionne comme un code de sortie Unix classique : uniquement des entiers de 0 à 255. `return 300` sera tronqué (300 % 256 = 44). Pour retourner une vraie valeur numérique ou textuelle, utilisez systématiquement la capture via `$(...)` ou passez par une variable globale/nommée (`declare -n` pour une référence, disponible depuis Bash 4.3+).

### 8.4 Portée des variables et `local`

```bash
compteur_global=0

incrementer() {
    local increment="${1:-1}"   # variable locale avec valeur par défaut
    (( compteur_global += increment ))
}

incrementer 5
incrementer
echo "$compteur_global"   # 6
echo "$increment"         # vide : $increment n'existe pas hors de la fonction
```

---

## 9. Tableaux (Arrays)

### 9.1 Tableaux indexés

```bash
# Création
fruits=("pomme" "banane" "cerise")

# Création vide puis ajout progressif
taches=()
taches+=("Faire les courses")
taches+=("Nettoyer la maison")

# Accès à un élément (index commence à 0)
echo "${fruits[0]}"        # pomme
echo "${fruits[-1]}"       # cerise (dernier élément, Bash 4.3+)

# Tous les éléments
echo "${fruits[@]}"        # pomme banane cerise
echo "${fruits[*]}"        # pomme banane cerise (identique en affichage, diffère si quoté)

# Taille du tableau
echo "${#fruits[@]}"       # 3

# Indices du tableau (utile si le tableau est "troué")
echo "${!fruits[@]}"       # 0 1 2

# Modification d'un élément
fruits[1]="mangue"

# Suppression d'un élément (laisse un "trou" dans les indices)
unset 'fruits[0]'

# Suppression complète du tableau
unset fruits

# Slicing (extraction d'une plage d'éléments)
nombres=(0 1 2 3 4 5 6 7 8 9)
echo "${nombres[@]:2:4}"   # 2 3 4 5 (à partir de l'index 2, 4 éléments)

# Itération
for fruit in "${fruits[@]}"; do
    echo "$fruit"
done
```

!!! tip "Toujours quoter `${arr[@]}`"
    Comme pour `"$@"`, `"${fruits[@]}"` préserve chaque élément individuellement, même s'il contient des espaces. Sans guillemets, les éléments sont re-découpés selon `$IFS`.

### 9.2 Tableaux associatifs (dictionnaires clé-valeur)

Les tableaux associatifs nécessitent une déclaration explicite avec `declare -A` et sont disponibles depuis **Bash 4.0**.

```bash
declare -A utilisateur

utilisateur[nom]="Dupont"
utilisateur[prenom]="Jean"
utilisateur[age]="35"

# Déclaration et remplissage en une seule instruction
declare -A capitales=(
    ["France"]="Paris"
    ["Espagne"]="Madrid"
    ["Italie"]="Rome"
)

# Accès à une valeur par sa clé
echo "${capitales[France]}"       # Paris

# Toutes les clés
echo "${!capitales[@]}"           # France Espagne Italie (ordre non garanti)

# Toutes les valeurs
echo "${capitales[@]}"            # Paris Madrid Rome (même ordre que les clés ci-dessus)

# Nombre d'entrées
echo "${#capitales[@]}"           # 3

# Vérifier l'existence d'une clé
if [[ -v capitales[France] ]]; then
    echo "La clé 'France' existe"
fi

# Suppression d'une entrée
unset 'capitales[Italie]'

# Itération clé/valeur
for pays in "${!capitales[@]}"; do
    echo "$pays -> ${capitales[$pays]}"
done
```

!!! danger "Différence critique avec les tableaux indexés"
    `declare -A` est **obligatoire** avant toute utilisation d'un tableau associatif. Sans cette déclaration, Bash traite `dict[clé]="valeur"` comme un tableau indexé classique, où `clé` est évaluée arithmétiquement (souvent `0`), ce qui écrase silencieusement les données précédentes au lieu de créer une nouvelle entrée.

---

## 10. Traitement des options et arguments (Getopts)

`getopts` est le mécanisme intégré de Bash pour parser des options de ligne de commande de style `-a valeur -b -c`.

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage : $0 -e <environnement> [-v] [-h]" >&2
    exit 1
}

environnement=""
verbeux=0

while getopts ":e:vh" opt; do
    case "$opt" in
        e)
            environnement="$OPTARG"
            ;;
        v)
            verbeux=1
            ;;
        h)
            usage
            ;;
        \?)
            echo "Option invalide : -$OPTARG" >&2
            usage
            ;;
        :)
            echo "L'option -$OPTARG requiert un argument." >&2
            usage
            ;;
    esac
done

# Décale les arguments déjà traités par getopts
shift $((OPTIND - 1))

[[ -z "$environnement" ]] && usage

echo "Environnement : $environnement"
echo "Mode verbeux  : $verbeux"
echo "Arguments restants (non-options) : $*"
```

### 10.1 Explication de la chaîne d'options `":e:vh"`

| Caractère | Signification |
|---|---|
| `:` (premier caractère) | Active le **mode silencieux** : `getopts` ne génère pas ses propres messages d'erreur, laissant le script gérer `\?` et `:` manuellement (bonne pratique) |
| `e:` | L'option `-e` **requiert** un argument, stocké automatiquement dans `$OPTARG` |
| `v` | L'option `-v` est un simple **flag** (drapeau), sans argument |
| `h` | L'option `-h` est également un flag |

### 10.2 Variables associées à `getopts`

| Variable | Rôle |
|---|---|
| `$opt` (ou tout autre nom choisi) | Contient l'option courante en cours de traitement dans la boucle |
| `$OPTARG` | Contient l'argument de l'option courante, si celle-ci en requiert un |
| `$OPTIND` | Index de l'argument suivant à traiter ; démarre à 1, doit être utilisé avec `shift` après la boucle pour accéder aux arguments non-options restants |

### 10.3 `shift` pour décaler les arguments positionnels

```bash
echo "Avant : $1 $2 $3"    # a b c
shift                       # décale tous les arguments d'une position vers la gauche
echo "Après : $1 $2"       # b c (l'ancien $1 "a" est perdu)

shift 2                     # décale de 2 positions supplémentaires
```

`shift $((OPTIND - 1))` après une boucle `getopts` permet de "consommer" toutes les options déjà traitées, pour que `$1`, `$2`, etc. pointent ensuite vers les arguments positionnels restants (non-options), typiquement des noms de fichiers.

---

## 11. Gestion des signaux & Traps

### 11.1 La commande `trap`

`trap` permet d'intercepter des signaux système ou des événements internes du shell, et d'exécuter du code en réponse.

```bash
trap 'commande_ou_fonction' SIGNAL
```

| Signal / Événement | Origine | Usage typique |
|---|---|---|
| `SIGINT` | Envoyé par `Ctrl+C` | Interruption propre d'un script en cours |
| `SIGTERM` | Signal de terminaison standard (envoyé par `kill` par défaut) | Arrêt propre d'un processus, nettoyage avant fermeture |
| `SIGHUP` | Fermeture du terminal contrôlant le processus | Redémarrage de configuration, ou terminaison |
| `SIGKILL` | Terminaison forcée (`kill -9`) | **Non interceptable**, le processus est tué immédiatement sans exécution de trap |
| `EXIT` | Événement interne Bash, déclenché à **toute** sortie du script (normale ou via `exit`, y compris après une erreur avec `set -e`) | Nettoyage systématique de fichiers temporaires, fermeture de connexions |
| `ERR` | Événement interne Bash, déclenché après toute commande qui échoue (utile combiné à `set -e`) | Log centralisé des erreurs |
| `DEBUG` | Déclenché avant chaque commande simple exécutée | Débogage avancé, traçage d'exécution |

### 11.2 Nettoyage automatique de fichiers temporaires

```bash
#!/usr/bin/env bash
set -euo pipefail

fichier_temp=$(mktemp)
repertoire_temp=$(mktemp -d)

nettoyage() {
    local code_sortie=$?
    echo "Nettoyage en cours (code de sortie : $code_sortie)..." >&2
    rm -f "$fichier_temp"
    rm -rf "$repertoire_temp"
    exit "$code_sortie"
}

trap nettoyage EXIT
trap 'echo "Interrompu par l'"'"'utilisateur" >&2; exit 130' SIGINT
trap 'echo "Signal de terminaison reçu" >&2; exit 143' SIGTERM

echo "Fichier temporaire : $fichier_temp"
echo "Travail en cours..."
sleep 5
echo "Terminé normalement"
```

!!! tip "Toujours utiliser `trap ... EXIT` pour le nettoyage"
    `EXIT` se déclenche dans **tous les cas** de fin de script : succès, `exit` explicite, erreur avec `set -e`, ou même après réception d'un `SIGINT`/`SIGTERM` qui n'est pas explicitement intercepté ailleurs (car ces derniers finissent par déclencher une sortie qui, elle, active le trap `EXIT`). C'est le point d'ancrage le plus fiable pour garantir qu'un fichier temporaire est toujours supprimé.

!!! danger "`SIGKILL` (`kill -9`) ne peut jamais être intercepté"
    Aucun `trap` ne peut capturer `SIGKILL` (signal 9) ni `SIGSTOP` (signal 19) : ce sont des signaux traités directement par le noyau, sans possibilité pour le processus de réagir. Un script tué avec `kill -9` ne pourra **jamais** exécuter son nettoyage — à concevoir en amont (fichiers temporaires dans un répertoire nettoyé automatiquement au redémarrage, verrous avec expiration, etc.).

---

## 12. Astuces, Débogage & Pièges classiques

### 12.1 Débogage pas à pas

| Méthode | Effet |
|---|---|
| `set -x` (dans le script) | Active le mode trace : chaque commande est affichée sur stderr avant son exécution, précédée de `+` |
| `set +x` | Désactive le mode trace (utile pour ne tracer qu'une portion du script) |
| `set -v` | Affiche chaque ligne du script telle qu'elle est **lue** (avant expansion), en plus de son exécution |
| `bash -x script.sh` | Active le mode trace pour l'exécution entière, sans modifier le script lui-même |
| `PS4='+ ${BASH_SOURCE}:${LINENO}: '` | Personnalise le préfixe affiché par `set -x` pour inclure le nom de fichier et le numéro de ligne — très utile en cas de script avec plusieurs fichiers sourcés |

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Avant la section de débogage"

set -x
variable="test"
resultat=$((1 + 2))
set +x

echo "Après la section de débogage"
```

```bash
# Débogage ciblé depuis l'extérieur, sans toucher au script
bash -x mon_script.sh arg1 arg2

# Avec préfixe enrichi (fichier + ligne)
PS4='+ ${BASH_SOURCE}:${LINENO}: ' bash -x mon_script.sh
```

### 12.2 Pièges d'espacement et de quotage

!!! danger "Toujours entourer les variables de guillemets doubles"
    Ne **jamais** utiliser une variable non quotée dans une commande, sauf cas très spécifiques et volontaires (comme l'expansion volontaire de plusieurs mots). Les conséquences d'un oubli sont parmi les bugs les plus fréquents et les plus dangereux en Bash.

    ```bash
    fichier="mon document.txt"

    rm $fichier          # DANGEREUX : équivaut à rm "mon" "document.txt"
                          # -> tente de supprimer DEUX fichiers distincts, "mon" et "document.txt"

    rm "$fichier"         # CORRECT : supprime bien le fichier "mon document.txt"
    ```

    ```bash
    variable=""
    if [ -n $variable ]; then echo "non vide"; fi   # BUG : affiche "non vide" alors que $variable est vide !
                                                       # Car $variable non quotée disparaît, laissant [ -n ]
                                                       # qui teste la présence de l'argument "-n" lui-même (vrai)

    if [ -n "$variable" ]; then echo "non vide"; fi  # CORRECT : fonctionne comme attendu
    ```

    ```bash
    for fichier in $(ls *.txt); do    # DANGEREUX : "word splitting" sur les espaces internes aux noms
        echo "$fichier"
    done

    for fichier in *.txt; do          # CORRECT : le globbing natif du shell gère nativement les espaces
        echo "$fichier"
    done
    ```

| Piège | Symptôme | Solution |
|---|---|---|
| Variable non quotée passée à une commande | Découpage involontaire sur les espaces, glob non désiré | Toujours utiliser `"$variable"` |
| `$(ls ...)` pour lister des fichiers | Casse sur les espaces, interprète les caractères glob (`*`, `?`) contenus dans les noms | Utiliser le globbing natif (`for f in *.txt`) ou `find ... -print0 \| xargs -0` |
| Comparaison `[ $a == $b ]` sans guillemets, avec `$a` vide | Erreur de syntaxe `unary operator expected` | Toujours quoter : `[ "$a" == "$b" ]`, ou utiliser `[[ ]]` qui est plus tolérant |
| Utilisation de `[[ ]]` dans un script `#!/bin/sh` | Erreur de syntaxe, `[[` non reconnu par `sh`/`dash` | Utiliser `[ ]` pour un script POSIX, réserver `[[ ]]` à `#!/bin/bash` |
| Espaces autour de `=` dans une affectation | `command not found` | Ne jamais espacer : `var="valeur"` |

### 12.3 Outil recommandé : `shellcheck`

!!! tip "Intégrer ShellCheck dans le flux de travail"
    [ShellCheck](https://www.shellcheck.net/) est un analyseur statique qui détecte automatiquement la quasi-totalité des pièges décrits dans cette documentation (quotage manquant, mauvaise utilisation de `[ ]`, variables non utilisées, incompatibilités POSIX, etc.).

```bash
# Installation (Debian/Ubuntu)
sudo apt-get install shellcheck

# Installation (macOS via Homebrew)
brew install shellcheck

# Analyse d'un script
shellcheck mon_script.sh

# Analyse avec sévérité minimale (error, warning, info, style)
shellcheck --severity=warning mon_script.sh

# Exclure des vérifications spécifiques (à utiliser avec parcimonie)
shellcheck --exclude=SC2086 mon_script.sh
```

!!! info "Intégration continue"
    Il est fortement recommandé d'ajouter `shellcheck` comme étape obligatoire dans tout pipeline CI/CD manipulant des scripts Bash, afin de détecter les erreurs de quotage et de logique avant leur exécution en production.

---

## Récapitulatif express

!!! info "Checklist du script Bash professionnel"
    - [ ] Shebang adapté au contexte (`#!/usr/bin/env bash` pour la portabilité)
    - [ ] `set -euo pipefail` en tête de script
    - [ ] Toutes les variables systématiquement quotées (`"$var"`, `"${arr[@]}"`, `"$@"`)
    - [ ] `[[ ... ]]` utilisé plutôt que `[ ... ]` (sauf contrainte POSIX stricte)
    - [ ] `local` utilisé pour toute variable interne à une fonction
    - [ ] `trap ... EXIT` pour le nettoyage des ressources temporaires
    - [ ] Script validé par `shellcheck` avant mise en production
