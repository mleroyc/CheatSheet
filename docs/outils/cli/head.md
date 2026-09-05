# 🛠️ Commande : head

## 1. Description rapide (Rôle et cas d'usage)

`head` affiche les premières lignes (10 par défaut) d'un fichier ou d'un flux. Très utilisé en début ou en fin de pipe pour limiter le volume de données affichées, notamment pour prévisualiser un fichier ou récupérer les N meilleurs résultats d'un tri.

## 2. Syntaxe de base

```bash
head [OPTIONS] fichier
commande | head
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-n N` | Affiche les N premières lignes |
| `-n -N` | Affiche tout sauf les N dernières lignes |
| `-c N` | Affiche les N premiers octets |
| `-q` | Masque les en-têtes de fichier (multi-fichiers) |
| `-v` | Force l'affichage des en-têtes de fichier |

## 4. Exemples pratiques & Cas d'usage

**Prévisualiser un fichier sans l'ouvrir entièrement**
```bash
head -n 20 access.log
```

**Récupérer le top 10 des IP les plus fréquentes**
```bash
cat access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 10
```

**Vérifier rapidement l'en-tête d'un CSV**
```bash
head -n 1 export.csv
```

**Comparer les premières lignes de plusieurs fichiers de config**
```bash
head -n 5 /etc/nginx/sites-available/*.conf
```

**Inspecter le début d'un binaire ou fichier inconnu (octets bruts)**
```bash
head -c 100 fichier_inconnu | xxd
```

**Limiter la sortie d'une commande verbeuse pendant un debug**
```bash
find / -name "*.log" 2>/dev/null | head -n 15
```

## 5. Astuces & Pièges à éviter

!!! tip "Combiner avec tail pour extraire une plage précise"
    `head -n 50 fichier | tail -n 10` affiche les lignes 41 à 50 : pratique pour cibler une portion précise sans connaître l'extrémité du fichier.

!!! warning "head -c coupe au milieu d'un caractère multi-octets"
    Avec des fichiers en UTF-8, `head -c N` peut tronquer un caractère multi-octets et produire un affichage corrompu en fin de sortie.

!!! tip "head -n -N pour tout sauf la fin"
    `head -n -5 fichier` affiche tout le fichier sauf ses 5 dernières lignes, utile pour retirer un pied de page ou une ligne de total dans un export.
