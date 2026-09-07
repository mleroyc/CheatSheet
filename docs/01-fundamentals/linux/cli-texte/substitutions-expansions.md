# 🛠️ Notion / Shell : Substitutions et expansions

## 1. Description rapide (Rôle et cas d'usage)

La substitution de commande insère le résultat d'une commande dans une autre. L'expansion de paramètres permet de manipuler des variables directement en Bash (valeurs par défaut, extraction, remplacement) sans appeler d'outils externes (`sed`, `awk`), rendant les scripts plus rapides et plus robustes face aux valeurs manquantes.

## 2. Syntaxe de base

```bash
resultat=$(commande)
${VAR:-default}
${VAR/ancien/nouveau}
```

## 3. Options, fanions et opérateurs principaux

| Élément | Effet |
|---|---|
| `$(commande)` | Substitution de commande (syntaxe moderne, imbricable) |
| `` `commande` `` | Substitution de commande (syntaxe historique, à éviter) |
| `${VAR:-default}` | Retourne `default` si VAR est vide/non définie, sans la modifier |
| `${VAR:=default}` | Affecte `default` à VAR si elle est vide/non définie |
| `${VAR:?message}` | Stoppe le script avec `message` si VAR est vide/non définie |
| `${VAR:+valeur}` | Retourne `valeur` uniquement si VAR est définie (et non vide) |
| `${#VAR}` | Longueur de la chaîne contenue dans VAR |
| `${VAR:offset:length}` | Extrait une sous-chaîne à partir de `offset` sur `length` caractères |
| `${VAR/ancien/nouveau}` | Remplace la première occurrence d'`ancien` par `nouveau` |
| `${VAR//ancien/nouveau}` | Remplace toutes les occurrences d'`ancien` par `nouveau` |

## 4. Exemples pratiques & Cas d'usage

**Horodater automatiquement un fichier de backup**
```bash
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf backup_${DATE}.tar.gz /data
```

**Imbriquer plusieurs substitutions de commande proprement**
```bash
echo "Espace disque libre : $(df -h / | awk 'NR==2 {print $(NF-2)}')"
```

**Fournir une valeur par défaut pour un argument de script manquant**
```bash
ENVIRONNEMENT="${1:-production}"
echo "Déploiement sur : $ENVIRONNEMENT"
```

**Forcer l'arrêt d'un script si une variable critique est absente**
```bash
: "${API_KEY:?Erreur : la variable API_KEY doit être définie}"
```

**Extraire une sous-chaîne d'une variable (ex: 4 premiers caractères d'une année)**
```bash
DATE_COMPLETE="20240315"
ANNEE="${DATE_COMPLETE:0:4}"
echo "$ANNEE"
```

**Nettoyer un chemin de fichier en remplaçant toutes les occurrences d'un motif**
```bash
CHEMIN="/var/www//app//uploads"
CHEMIN_PROPRE="${CHEMIN//\/\//\/}"
```

## 5. Astuces & Pièges à éviter

!!! warning "Toujours privilégier $() aux backticks"
    Les backticks `` `commande` `` sont difficiles à imbriquer (nécessitent l'échappement `\``), moins lisibles et plus sujets aux erreurs de parsing. `$(commande)` s'imbrique naturellement (`$(commande1 $(commande2))`) et est la syntaxe recommandée dans tout script moderne.

!!! tip "Utiliser :? pour fail-fast sur les scripts critiques"
    `${VAR:?message}` interrompt immédiatement l'exécution avec un message d'erreur explicite si la variable attendue n'est pas définie — bien plus sûr que de laisser un script continuer avec une variable vide (ex: un `rm -rf "$DOSSIER"/` où `$DOSSIER` serait vide).

!!! tip "Manipulation de chaîne pure Bash = plus rapide qu'un sous-processus"
    `${VAR/ancien/nouveau}` évite d'appeler `sed` ou `awk` dans un sous-processus séparé pour de simples remplacements de texte, ce qui accélère sensiblement les scripts exécutant ce type d'opération en boucle.
