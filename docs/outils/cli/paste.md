# 🛠️ Commande : paste

## 1. Description rapide (Rôle et cas d'usage)

`paste` fusionne plusieurs fichiers **horizontalement**, ligne par ligne, en les juxtaposant sous forme de colonnes séparées par une tabulation (par défaut) ou un séparateur personnalisé. C'est l'outil idéal pour reconstituer rapidement un fichier tabulaire (CSV/TSV) à partir de listes séparées.

## 2. Syntaxe de base

```bash
paste [OPTIONS] fichier1 fichier2 [...]
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-d SEP` | Définit le(s) séparateur(s) de colonnes (défaut : TAB) |
| `-s` | Regroupe chaque fichier sur une seule ligne (transposition) |
| `-` | Utilise l'entrée standard comme un des fichiers d'entrée |

## 4. Exemples pratiques & Cas d'usage

**Créer un fichier CSV à partir de deux listes séparées**
```bash
paste -d',' noms.txt emails.txt > utilisateurs.csv
```

**Fusionner trois colonnes de données avec un séparateur virgule**
```bash
paste -d',' ids.txt dates.txt montants.txt > transactions.csv
```

**Transformer une colonne verticale en une seule ligne horizontale**
```bash
paste -s -d',' liste_verticale.txt
```

**Combiner la sortie d'une commande avec un fichier existant**
```bash
seq 1 5 | paste - noms.txt
```

**Assembler des adresses IP et leurs comptages en colonnes lisibles**
```bash
paste ips.txt compteurs.txt
```

**Regrouper plusieurs lignes de log en une seule ligne CSV par bloc de 3**
```bash
paste -d',' - - - < logs_bruts.txt
```

## 5. Astuces & Pièges à éviter

!!! warning "Les fichiers doivent avoir le même nombre de lignes"
    Si les fichiers en entrée n'ont pas le même nombre de lignes, `paste` complète les colonnes manquantes par des champs vides plutôt que de générer une erreur — vérifiez avec `wc -l` avant fusion pour éviter des colonnes décalées.

!!! tip "Le tiret (-) comme entrée standard"
    `paste - fichier.txt` permet de fusionner la sortie d'une commande précédente (via pipe) avec un fichier existant, sans fichier temporaire intermédiaire.

!!! tip "paste -s pour transposer une liste en ligne"
    `paste -s -d',' fichier` est l'astuce classique pour transformer une colonne de valeurs en une seule ligne séparée par des virgules, prête à être collée dans un tableur.
