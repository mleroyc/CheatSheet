# tr

> `tr` (translate) est un outil en ligne de commande qui lit sur l'entrée standard pour traduire, compresser ou supprimer des caractères, sans jamais manipuler directement des fichiers.

!!! tip "Cas d'usage principal"
    En pentest ou en administration système, `tr` est souvent utilisé en combinaison avec d'autres commandes (`cat`, `grep`, `cut`) via un pipe pour normaliser un flux de texte : convertir la casse, compresser des espaces multiples avant un `cut`, supprimer des caractères indésirables (retours chariot Windows `\r`, caractères non imprimables) ou nettoyer une sortie brute.

## 1. Syntaxe de base

```bash
# Structure générale de la commande
# tr lit uniquement sur l'entrée standard : nécessite < ou un pipe |
commande | tr [options] SET1 [SET2]
tr [options] SET1 [SET2] < fichier
```

!!! warning "tr ne lit pas de fichier en argument"
    Contrairement à `grep` ou `cut`, `tr` n'accepte pas de nom de fichier en argument direct. Il faut obligatoirement lui fournir un flux via une redirection `<` ou un pipe `|`, sans quoi la commande reste en attente d'une saisie clavier.

## 2. Commandes et cas d'usage fréquents

### Traduction / remplacement de caractères

```bash
# tr SET1 SET2 : remplace chaque caractère de SET1 par le caractère de SET2
# situé à la même position (correspondance caractère par caractère)
echo "Bonjour" | tr 'a-z' 'A-Z'
```

```bash
# Exemple : convertir tous les caractères minuscules en majuscules
cat fichier.txt | tr 'a-z' 'A-Z'
```

### Compression des répétitions (-s)

```bash
# -s : repère les caractères qui se répètent consécutivement (en chaîne)
# et les compresse en une seule occurrence
cat fichier.txt | tr -s ' '
```

!!! tip "Utilité avec cut"
    `tr -s ' '` est particulièrement utile en amont de `cut -d ' '` : il permet de normaliser des colonnes séparées par un nombre variable d'espaces (sortie de `ps`, `ls -l`, etc.) en un seul espace, pour que `cut` puisse extraire correctement les colonnes attendues.

### Suppression de caractères (-d)

```bash
# -d SET : supprime tous les caractères présents dans le SET indiqué
cat fichier.txt | tr -d '\r'
```

```bash
# Exemple : supprimer tous les chiffres d'un flux de texte
cat fichier.txt | tr -d '0-9'
```

### Négation / inversion du SET (-c)

```bash
# -c : inverse le SET donné, et supprime (ou traite) tout ce qui n'y figure PAS
cat fichier.txt | tr -cd 'a-zA-Z\n'
```

## 3. Options et flags utiles

| Flag / Option | Description | Exemple |
| --- | --- | --- |
| `SET1 SET2` | Remplace chaque caractère de SET1 par celui de SET2 à la même position | `tr 'a-z' 'A-Z'` |
| `-s` | Compresse les répétitions consécutives d'un même caractère en une seule occurrence | `tr -s ' '` |
| `-d SET` | Supprime tous les caractères présents dans le SET | `tr -d '\r'` |
| `-c` | Inverse le SET (complément) : agit sur tout ce qui n'est PAS dans la liste | `tr -cd 'a-zA-Z\n'` |

!!! tip "Compléments utiles non mentionnés dans les notes initiales"
    - `-t` : tronque SET1 pour qu'il ait la même longueur que SET2 (évite les comportements imprévus si les deux sets ont des tailles différentes)
    - Les options peuvent être combinées, ex: `tr -cd` (suppression + inversion) pour ne garder QUE les caractères d'un SET donné
    - Classes de caractères prédéfinies utilisables dans les SET : `[:alpha:]`, `[:digit:]`, `[:upper:]`, `[:lower:]`, `[:space:]`, `[:punct:]`

```bash
# Exemple : ne conserver que les lettres et les chiffres, tout supprimer d'autre
cat fichier.txt | tr -cd '[:alnum:]\n'
```

## 4. Bonnes pratiques & pièges à éviter

!!! warning "SET1 et SET2 doivent correspondre position par position"
    En mode traduction (`tr SET1 SET2`), si `SET2` est plus court que `SET1`, le dernier caractère de `SET2` est répété pour compléter la correspondance — ce qui peut donner un résultat inattendu. Utilise `-t` pour forcer la troncature de `SET1` si ce comportement n'est pas voulu.

!!! warning "Ne pas confondre -d et -s"
    `-d` **supprime** les caractères du SET, tandis que `-s` **compresse** les répétitions consécutives sans les supprimer complètement (il en garde une occurrence). Les combiner (`tr -sd`) demande de bien distinguer les deux SET utilisés pour chaque action.

!!! note "Flux uniquement, pas de fichier en sortie"
    `tr` ne modifie jamais un fichier sur place. Pour sauvegarder le résultat, il faut rediriger la sortie vers un nouveau fichier : `tr -s ' ' < entree.txt > sortie.txt` (ne jamais rediriger vers le même fichier en entrée, cela le viderait).

---