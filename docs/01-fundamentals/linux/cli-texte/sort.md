# 🛠️ Commande : sort

## 1. Description rapide (Rôle et cas d'usage)

`sort` trie les lignes d'un fichier ou d'un flux selon différents critères : alphabétique, numérique, par colonne, avec inversion ou déduplication. C'est un maillon central des pipes d'analyse de logs, souvent combiné avec `uniq`.

## 2. Syntaxe de base

```bash
sort [OPTIONS] fichier
commande | sort
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-n` | Tri numérique (au lieu de lexicographique) |
| `-r` | Tri inversé (décroissant) |
| `-k N` | Trie selon le champ (colonne) numéro N |
| `-t SEP` | Définit le séparateur de champ (par défaut : espace) |
| `-u` | Supprime les doublons après tri (unique) |
| `-h` | Tri "humain" des tailles (1K, 2M, 3G) |
| `-M` | Tri par nom de mois (Jan, Feb, ...) |

## 4. Exemples pratiques & Cas d'usage

**Trier un fichier de noms par ordre alphabétique**
```bash
sort utilisateurs.txt
```

**Trier des valeurs numériques correctement**
```bash
sort -n tailles.txt
```

**Top des adresses IP par nombre d'occurrences (pipe complet)**
```bash
awk '{print $1}' access.log | sort | uniq -c | sort -nr | head -n 10
```

**Trier un fichier CSV par la 3e colonne, séparée par des virgules**
```bash
sort -t',' -k3,3 -n export.csv
```

**Trier des fichiers par taille de façon lisible**
```bash
du -sh /var/log/* | sort -h
```

**Déduplication directe pendant le tri**
```bash
sort -u ips_bloquees.txt > ips_uniques.txt
```

## 5. Astuces & Pièges à éviter

!!! warning "Piège classique : tri lexicographique de nombres"
    Sans `-n`, `sort` trie `10` avant `2` car il compare caractère par caractère ("1" < "2"). Résultat : `1, 10, 2, 20, 3`. Toujours ajouter `-n` pour un tri numérique correct.

!!! tip "Trier par colonne avec un séparateur personnalisé"
    `-k` seul trie à partir du champ indiqué jusqu'à la fin de la ligne. Pour trier strictement sur une seule colonne, précisez la borne de fin : `-k3,3`.

!!! tip "Combiner -u avec -k pour dédupliquer sur une clé précise"
    `sort -u -k1,1 fichier` déduplique en ne comparant que le premier champ, même si le reste de la ligne diffère — utile pour garder une seule entrée par utilisateur ou par IP.
