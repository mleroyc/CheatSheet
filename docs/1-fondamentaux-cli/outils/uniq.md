# 🛠️ Commande : uniq

## 1. Description rapide (Rôle et cas d'usage)

`uniq` filtre ou compte les lignes **adjacentes** identiques dans un flux. Il ne détecte que les doublons consécutifs, ce qui impose presque toujours de trier le flux avec `sort` en amont. Combiné à `sort`, c'est l'outil de référence pour compter des occurrences (IP, codes HTTP, user-agents).

## 2. Syntaxe de base

```bash
uniq [OPTIONS] fichier
commande | sort | uniq
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-c` | Préfixe chaque ligne par son nombre d'occurrences |
| `-u` | N'affiche que les lignes uniques (sans doublon) |
| `-d` | N'affiche que les lignes dupliquées (une seule fois chacune) |
| `-i` | Ignore la casse lors de la comparaison |
| `-f N` | Ignore les N premiers champs lors de la comparaison |

## 4. Exemples pratiques & Cas d'usage

**Compter les occurrences de chaque IP dans un log (pattern incontournable)**
```bash
awk '{print $1}' access.log | sort | uniq -c | sort -nr
```

**Identifier les lignes strictement uniques d'une liste**
```bash
sort emails.txt | uniq -u
```

**Repérer les doublons dans une liste d'utilisateurs**
```bash
sort utilisateurs.txt | uniq -d
```

**Compter les codes de statut HTTP distincts**
```bash
awk '{print $9}' access.log | sort | uniq -c | sort -nr
```

**Dédupliquer une liste d'IP bloquées avant import dans un firewall**
```bash
sort -u ips_bloquees.txt > ips_final.txt
```

**Comparer deux exports pour ne garder que les entrées communes après tri**
```bash
cat fichier1.txt fichier2.txt | sort | uniq -d
```

## 5. Astuces & Pièges à éviter

!!! warning "uniq ne fonctionne que sur des lignes adjacentes"
    `uniq` compare uniquement des lignes consécutives. Sans tri préalable, des doublons non adjacents (ex: lignes 3 et 150 identiques) ne seront jamais détectés. **Toujours faire `sort fichier | uniq`, jamais `uniq` seul sur un fichier non trié.**

!!! tip "uniq -c produit un compteur exploitable par sort -nr"
    La sortie de `uniq -c` place le compteur en première colonne, ce qui permet de l'enchaîner directement avec `sort -nr` pour classer par fréquence décroissante.

!!! tip "Combiner -i pour une déduplication insensible à la casse"
    Utile pour dédupliquer des noms de domaine ou adresses e-mail qui ne diffèrent que par la casse (`Admin@site.com` vs `admin@site.com`).
