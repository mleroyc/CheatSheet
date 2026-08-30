# Cheat Sheet : Manipulation de texte — Lecture, tri, comptage, formatage

!!! tip "Usage principal"
    Les utilitaires secondaires de manipulation de texte, à combiner en pipes avec `grep`/`sed`/`awk`/`cut`/`tr` pour lire, trier, compter et reformater rapidement fichiers et logs.

## 1. Syntaxe de base

```bash
# Structure générale des commandes couvertes
cat [options] fichier | less [options] fichier | head/tail [options] fichier
sort [options] fichier | uniq [options]
wc [options] fichier | nl [options] fichier
paste [options] f1 f2 | expand/unexpand [options] fichier
join [options] f1 f2 | split [options] fichier [prefixe]
```

---

## 2. Visualisation & Suivi de logs (`cat`, `less`, `head`, `tail`)

### Afficher un fichier en entier
```bash
# Affichage brut, adapté aux petits fichiers
cat fichier.txt
```

```bash
cat -n fichier.txt   # numérote toutes les lignes
cat -A fichier.txt   # affiche caractères non imprimables, tabulations, fins de ligne
```

### Paginer un fichier volumineux
```bash
# Ne charge pas tout en mémoire, contrairement à cat
less fichier.log
```

Navigation et recherche dans `less` :

| Touche | Action |
| --- | --- |
| `Page Up` / `Page Down` | Navigation page par page |
| `/motif` | Recherche en avant |
| `?motif` | Recherche en arrière |
| `n` / `N` | Occurrence suivante / précédente |
| `g` / `G` | Début / fin du fichier |
| `F` | Mode suivi temps réel (comme `tail -f`), `CTRL+C` pour revenir à la navigation |
| `q` | Quitter |

### Afficher début/fin d'un fichier
```bash
head fichier.log       # 10 premières lignes par défaut
tail fichier.log       # 10 dernières lignes par défaut
head -n 50 fichier.log # 50 premières lignes
```

### Suivre un log en temps réel
```bash
# Affiche les nouvelles lignes ajoutées au fur et à mesure (CTRL+C pour quitter)
tail -f /var/log/auth.log
```

```bash
# -q supprime l'en-tête du nom de fichier quand plusieurs fichiers sont suivis
tail -f -q /var/log/*.log
```

---

## 3. Tri, Filtrage & Nettoyage (`sort`, `uniq`)

### Trier des lignes
```bash
sort fichier.txt      # tri alphabétique croissant
sort -r fichier.txt   # tri inversé (décroissant)
sort -n nombres.txt   # tri numérique (indispensable pour des valeurs chiffrées)
sort -u fichier.txt   # tri avec suppression de doublons intégrée
```

### Trier par colonne
```bash
# -k 2 trie selon la 2e colonne ; -t définit le séparateur de colonnes
sort -t "," -k 2 data.csv
```

### Dédupliquer et compter (nécessite un tri préalable)
```bash
# uniq ne compare que des lignes adjacentes : toujours trier avant
sort fichier.txt | uniq
```

```bash
sort fichier.txt | uniq -c   # ajoute le nombre d'occurrences en préfixe
sort fichier.txt | uniq -u   # affiche uniquement les lignes uniques (jamais dupliquées)
sort fichier.txt | uniq -d   # affiche uniquement les lignes dupliquées (une fois chacune)
```

## Synthèse `sort` / `uniq` — Tableau des flags

| Flag | Commande | Rôle |
| --- | --- | --- |
| `-n` | `sort` | Tri numérique |
| `-r` | `sort` | Tri inversé (décroissant) |
| `-k N` | `sort` | Trie selon la colonne N |
| `-u` | `sort` | Tri + dédoublonnage intégré |
| `-c` | `uniq` | Compte les occurrences de chaque ligne |
| `-u` | `uniq` | N'affiche que les lignes uniques |
| `-d` | `uniq` | N'affiche que les lignes dupliquées |

---

## 4. Comptage & Numérotation (`wc`, `nl`)

### Compter lignes, mots, octets
```bash
wc fichier.txt      # affiche lignes + mots + octets
wc -l fichier.txt   # uniquement le nombre de lignes
wc -w fichier.txt   # uniquement le nombre de mots
wc -c fichier.txt   # uniquement le nombre d'octets
```

### Numéroter les lignes d'un fichier
```bash
# Affiche le fichier avec le numéro de chaque ligne devant
nl fichier.txt
```

---

## 5. Formatage & Découpage avancé (`paste`, `expand`/`unexpand`, `join`, `split`)

### Fusionner des fichiers en colonnes
```bash
# La ligne N de f1 et la ligne N de f2 sont jointes par une TAB
paste f1.txt f2.txt
```

```bash
paste -s fichier.txt          # regroupe toutes les lignes en une seule
paste -d "," f1.txt f2.txt    # délimiteur personnalisé au lieu de TAB
```

### Convertir tabulations ↔ espaces
```bash
expand fichier.txt > propre.txt      # convertit TAB en espaces (8 par défaut)
unexpand -a fichier.txt > tabs.txt   # convertit tous les espaces multiples en TAB
```

### Fusionner deux fichiers sur une clé commune
```bash
# Les deux fichiers DOIVENT être triés sur la colonne clé au préalable
join fichier1.txt fichier2.txt
```

### Découper un gros fichier
```bash
split -l 500 gros.log morceau_    # découpe par tranche de 500 lignes
split -b 10M archive.dat morceau_ # découpe par tranche de 10 Mo
```

## Synthèse `join` / `split` — Tableau des flags

| Flag | Commande | Rôle |
| --- | --- | --- |
| `-1 N -2 M` | `join` | Spécifie la colonne clé de chaque fichier si différente |
| `-l N` | `split` | Découpe par nombre de lignes |
| `-b SIZE` | `split` | Découpe par taille (K, M, G) |

---

## 6. One-Liners combinés (Pipes)

```bash
# Classement des lignes les plus fréquentes d'un fichier (log, IP, user-agent...)
sort access.log | uniq -c | sort -nr | head -10
```

```bash
# Suivre un log en direct en filtrant les échecs d'authentification
tail -f /var/log/auth.log | grep -i "failed"
```

```bash
# Compter le nombre de lignes correspondant à un motif
grep "error" app.log | wc -l
```

```bash
# Extraire, dédupliquer et compter les IP sources d'un access.log
cut -d " " -f 1 access.log | sort | uniq -c | sort -nr
```

```bash
# Reconstruire un CSV à partir de deux colonnes issues de fichiers séparés
paste -d "," noms.txt emails.txt > contacts.csv
```

```bash
# Recomposer un fichier découpé avec split
cat morceau_* > fichier_reconstitue.log
```

!!! warning "Pièges à connaître"
    - **`uniq` sans `sort` préalable** ne détecte que les doublons adjacents : les doublons non consécutifs passent inaperçus.
    - **`sort` sans `-n`** trie lexicographiquement : "10" apparaît avant "9". Toujours `-n` pour des valeurs numériques.
    - **`join` exige des fichiers triés** sur la colonne clé, sinon des lignes correspondantes sont silencieusement ignorées.
    - **`expand`/`unexpand`/`paste`/`join`** n'écrivent jamais dans le fichier source : le résultat part sur `stdout`, pensez à la redirection (`>`).
    - **`tail -f`** ne suit pas un fichier remplacé après rotation de logs : utilisez `tail -F` (majuscule) pour recoller automatiquement au nouveau fichier.
