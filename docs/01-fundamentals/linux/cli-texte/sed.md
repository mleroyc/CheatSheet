# sed

> `sed` (Stream EDitor) permet de rechercher, remplacer, insérer ou supprimer du texte à la volée dans un flux ou un fichier, ligne par ligne, sans ouvrir d'éditeur interactif.

!!! tip "Cas d'usage principal"
    En pentest ou en administration système, `sed` est très utilisé pour nettoyer/transformer des sorties de commandes en pipe (remplacement de motifs, suppression de lignes vides ou commentées), automatiser des modifications de fichiers de configuration en masse, ou reformater des données extraites (ex: inversion nom/prénom, remplacement d'URLs).

!!! note "Comportement par défaut"
    `sed` affiche le résultat modifié à l'écran (stdout) mais **ne modifie pas le fichier source** par défaut. La modification directe du fichier nécessite l'option `-i` (voir section Options).

## 1. Syntaxe de base

```bash
# Structure générale de la commande
sed 'COMMANDE' fichier
```

## 2. Substitution (commande `s`)

```bash
# Syntaxe : sed 's/MOTIF/REMPLACEMENT/FLAGS' fichier
sed 's/ancien/nouveau/' fichier.txt
```

- Le caractère `/` sert de délimiteur, mais peut être remplacé par un autre caractère (`@`, `#`, etc.) si le motif recherché contient lui-même des `/` (ex: des URLs).

```bash
# Remplace http:// par https:// dans tout le fichier
# Utilisation de @ comme délimiteur pour éviter d'échapper les / des URLs
sed 's#http://#https://#g' urls.txt
```

## 3. Modification directe d'un fichier

```bash
# -i applique directement les modifications au fichier (aucune sortie affichée)
sed -i 's/ancien/nouveau/g' fichier.txt

# -i.bak crée une sauvegarde du fichier original avant modification
sed -i.bak 's/ancien/nouveau/g' fichier.txt
```

!!! warning "Toujours sauvegarder avant une modification en masse"
    L'option `-i` seule (sans suffixe) modifie le fichier sans aucune sauvegarde. En environnement de production ou sur des fichiers de configuration critiques, privilégie systématiquement `-i.bak` (ou une copie manuelle préalable) pour pouvoir revenir en arrière en cas d'erreur de motif.

## 4. Suppression de lignes et filtrage (commande `d`)

```bash
# Supprime la ligne 1
sed '1d' donnees.csv

# Supprime les lignes 2 à 4 incluses
sed '2,4d' donnees.csv

# Supprime les lignes vides
sed '/^$/d' fichier.txt

# Supprime les lignes commençant par # (lignes de commentaire)
sed '/^[[:space:]]*#/d' config.conf
```

## 5. Ajout, insertion et changement de ligne

### Ajout (commande `a`) — ajoute du texte après la ligne ciblée

```bash
# Ajoute une ligne de texte après la ligne 3
sed '3a TEXTE À AJOUTER' fichier.txt
```

### Insertion (commande `i`) — insère du texte avant la ligne ciblée

```bash
# Insère du texte avant la ligne 1
sed "1i TEXTE"
```

### Changement (commande `c`) — remplace toute la ligne ciblée

```bash
# Remplace entièrement le contenu de la ligne 2 par le nouveau texte
sed '2c NOUVELLE LIGNE'
```

## 6. Recherche (affichage sélectif)

```bash
# -n bloque l'affichage automatique des lignes
# /MOTIF/p n'affiche que les lignes correspondant au motif
sed -n '/MOTIF/p' fichier
```

## 7. Capture et réutilisation de groupes

`sed` permet de capturer du texte entre parenthèses (avec `-E`/`-r` pour les regex étendues) et de le réutiliser dans le remplacement via `\1`, `\2`, etc.

```bash
# Inverse le nom et le prénom en capturant deux groupes de mots
echo "Dupont Jean" | sed -E 's/([A-Za-z]+) ([A-Za-z]+)/\2 \1/'
```

## 8. Flags de la commande de substitution

| Flag | Description |
| --- | --- |
| `g` | Remplace toutes les occurrences de la ligne (sinon, seule la première occurrence de chaque ligne est remplacée) |
| `i` | Ignore la casse lors de la recherche du motif |
| `d` | Supprime des lignes en fonction d'un numéro ou d'un motif regex |
| `1,2,3,...` | Numéro d'occurrence sur la ligne à remplacer |
| `p` | Affiche la ligne si la substitution a réussi |
| `w fichier` | Écrit le résultat de la ligne modifiée dans un fichier spécifique |

## 9. Options utiles

| Flag / Option | Description | Exemple |
| --- | --- | --- |
| `-E` / `-r` | Active les expressions régulières étendues (pas besoin d'échapper les caractères spéciaux) | `sed -E 's/(a+)/X/' fichier` |
| `-n` | Bloque l'affichage automatique de chaque ligne | `sed -n '/motif/p' fichier` |
| `-i` | Modifie directement le fichier (voir section 3) | `sed -i 's/a/b/' fichier` |
| `-e 'cmd1'` | Permet d'exécuter plusieurs commandes `sed` d'affilée | `sed -e 's/a/b/' -e 's/c/d/' fichier` |
| `-f script.sed` | Exécute les commandes contenues dans un fichier script | `sed -f script.sed fichier` |

## 10. Bonnes pratiques & pièges à éviter

!!! warning "BRE par défaut : penser à -E pour les regex étendues"
    Sans `-E`/`-r`, `sed` utilise les Basic Regular Expression (BRE), où `+`, `?`, `|`, `{}`, `()` doivent être échappés avec `\` pour être interprétés comme des opérateurs regex plutôt que des caractères littéraux — même piège qu'avec `grep` en mode par défaut.

!!! warning "Portabilité de sed -i entre GNU et BSD/macOS"
    La syntaxe de `-i` diffère entre **GNU sed** (Linux) et **BSD sed** (macOS) : sur macOS, `-i` exige un argument de suffixe explicite même vide (`sed -i '' 's/a/b/' fichier`), alors que sur Linux `sed -i 's/a/b/' fichier` fonctionne sans argument. Un script portable doit tester la version ou éviter `-i` au profit d'une redirection vers un nouveau fichier.

!!! tip "Combiner plusieurs commandes sed"
    Plutôt que de chaîner plusieurs `sed | sed | sed` via des pipes, utilise `-e` pour exécuter plusieurs commandes en une seule invocation (`sed -e '1d' -e 's/a/b/g' fichier`), plus lisible et plus performant.

!!! note "sed vs awk"
    `sed` est optimisé pour la substitution/suppression ligne par ligne avec des regex, tandis que `awk` est plus adapté dès qu'il faut manipuler des colonnes, faire des calculs ou appliquer une logique conditionnelle complexe. Les deux sont fréquemment combinés dans un même pipeline.

---