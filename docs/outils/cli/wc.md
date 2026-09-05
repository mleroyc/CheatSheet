# 🛠️ Commande : wc

## 1. Description rapide (Rôle et cas d'usage)

`wc` (*word count*) compte les lignes, mots et octets/caractères d'un fichier ou d'un flux. Il s'utilise très fréquemment en fin de pipe pour quantifier un résultat de filtrage : nombre de correspondances `grep`, nombre d'entrées uniques après `uniq`, taille d'un fichier de log, etc.

## 2. Syntaxe de base

```bash
wc [OPTIONS] fichier
commande | wc
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-l` | Compte le nombre de lignes |
| `-w` | Compte le nombre de mots |
| `-c` | Compte le nombre d'octets |
| `-m` | Compte le nombre de caractères (gère l'UTF-8) |
| `-L` | Affiche la longueur de la ligne la plus longue |

## 4. Exemples pratiques & Cas d'usage

**Compter le nombre de tentatives de connexion échouées**
```bash
grep "Failed password" /var/log/auth.log | wc -l
```

**Vérifier le nombre de lignes d'un fichier avant traitement massif**
```bash
wc -l export.csv
```

**Compter le nombre d'IP uniques ayant accédé au serveur**
```bash
awk '{print $1}' access.log | sort -u | wc -l
```

**Estimer la taille d'un fichier en octets rapidement**
```bash
wc -c fichier.bin
```

**Vérifier qu'un script ne dépasse pas une longueur de ligne raisonnable**
```bash
wc -L script.sh
```

**Compter le nombre d'entrées correspondant à un pattern précis**
```bash
grep -c "ERROR" application.log
```

## 5. Astuces & Pièges à éviter

!!! tip "grep -c vs grep | wc -l"
    `grep -c motif fichier` compte le nombre de **lignes correspondantes**, alors que `grep motif fichier | wc -l` fait la même chose via un pipe supplémentaire. `grep -c` est plus direct et légèrement plus performant.

!!! warning "wc -c compte des octets, pas des caractères"
    Sur un fichier UTF-8 contenant des accents ou emojis, `-c` donnera un nombre supérieur au nombre réel de caractères affichés. Utilisez `-m` pour un comptage de caractères correct.

!!! tip "Pattern de fin de pipe très courant"
    `commande | wc -l` est l'idiome standard pour transformer n'importe quel filtrage (`grep`, `awk`, `find`) en un simple chiffre exploitable dans un script ou une alerte de supervision.
