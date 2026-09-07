# 🛠️ Commande : join

## 1. Description rapide (Rôle et cas d'usage)

`join` fusionne deux fichiers ligne par ligne en se basant sur une **clé commune** (comme une jointure SQL). Il compare le champ clé de chaque fichier et n'affiche que les lignes dont la clé correspond (par défaut, jointure interne). Très utile pour croiser deux jeux de données textuels (ex: liste d'IP et liste de noms de domaine, identifiants utilisateurs et logs).

## 2. Syntaxe de base

```bash
join [OPTIONS] fichier1 fichier2
```

**Condition impérative :** les deux fichiers doivent être triés sur leur clé de jointure (`sort`) avant l'appel à `join`.

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-1 N` | Indique le numéro de champ clé dans le fichier 1 |
| `-2 N` | Indique le numéro de champ clé dans le fichier 2 |
| `-t SEP` | Définit le séparateur de champ (défaut : espace) |
| `-a N` | Inclut aussi les lignes sans correspondance du fichier N (jointure externe) |
| `-e STR` | Remplace les champs manquants par la chaîne STR |
| `-o FORMAT` | Personnalise les champs affichés dans le résultat |

## 4. Exemples pratiques & Cas d'usage

**Croiser une liste d'IP avec leur géolocalisation**
```bash
sort ips.txt -o ips.txt
sort geoloc.txt -o geoloc.txt
join ips.txt geoloc.txt
```

**Jointure sur des fichiers CSV avec un séparateur virgule**
```bash
join -t',' -1 1 -2 1 utilisateurs.csv commandes.csv
```

**Jointure externe pour garder aussi les entrées sans correspondance**
```bash
join -a1 -e "N/A" -t',' clients.csv paiements.csv
```

**Croiser un fichier d'ID utilisateurs avec un fichier de logs d'accès**
```bash
join -1 2 -2 1 <(sort -k2 sessions.log) <(sort utilisateurs.txt)
```

**Fusionner deux tables de correspondance clé-valeur triées**
```bash
join code_pays.txt noms_pays.txt
```

**Vérifier la correspondance d'IP bloquées avec un référentiel connu (threat intel)**
```bash
join <(sort ips_bloquees.txt) <(sort ips_connues_malveillantes.txt)
```

## 5. Astuces & Pièges à éviter

!!! warning "Les fichiers DOIVENT être triés sur la clé de jointure"
    `join` suppose que les deux fichiers sont triés selon le même ordre sur le champ clé. Si ce n'est pas le cas, le résultat sera incomplet ou incorrect, sans message d'erreur explicite. Utilisez toujours `sort` (ou une substitution de processus `<(sort fichier)`) avant `join`.

!!! tip "Utiliser la substitution de processus pour éviter les fichiers temporaires"
    `join <(sort fichier1) <(sort fichier2)` permet de trier à la volée sans créer de fichiers intermédiaires sur le disque.

!!! tip "join -a pour une jointure externe façon LEFT/RIGHT JOIN"
    Par défaut `join` se comporte comme un INNER JOIN (uniquement les correspondances). L'option `-a1` ou `-a2` permet de conserver aussi les lignes sans correspondance du fichier indiqué, à la manière d'un LEFT JOIN ou RIGHT JOIN en SQL.
