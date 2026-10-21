# 🛠️ Commande : seq

## 1. Description rapide (Rôle et cas d'usage)

`seq` est un utilitaire qui génère des **séquences de nombres**, entiers ou décimaux, entre une valeur de début et une valeur de fin, avec un pas configurable. Chaque nombre est affiché sur une ligne distincte par défaut.

**Principaux cas d'usage :**

- **Boucles dans des scripts Bash**, pour itérer sur une plage de valeurs numériques.
- **Génération de jeux de données de test** (identifiants, index, valeurs numériques factices).
- **Création de séries de fichiers ou de répertoires numérotés**, avec ou sans zéros de remplissage.
- **Intégration dans des pipelines Shell** avec `xargs` ou `parallel`, pour répéter ou paralléliser une commande N fois.

---

## 2. Syntaxe de base

```bash
seq [options] DERNIER
```
Génère la séquence de `1` à `DERNIER`, avec un pas de `1`.

```bash
seq [options] PREMIER DERNIER
```
Génère la séquence de `PREMIER` à `DERNIER`, avec un pas de `1`.

```bash
seq [options] PREMIER PAS DERNIER
```
Génère la séquence de `PREMIER` à `DERNIER`, avec un `PAS` spécifique (positif ou négatif).

**Comportement avec les nombres négatifs et décimaux :**

- `seq` accepte nativement les valeurs négatives, aussi bien en bornes qu'en pas (ex. `seq 10 -1 1` pour un décompte).
- `seq` accepte les valeurs décimales (flottantes) en entrée, avec les limites de précision inhérentes à l'arithmétique en virgule flottante (voir section 5).

---

## 3. Options et fanions principaux

| Option | Forme longue | Description |
|---|---|---|
| `-w` | `--equal-width` | Égalise la largeur d'affichage de tous les nombres en ajoutant des zéros de remplissage au début (ex. `01, 02, ... 10`). |
| `-s STRING` | `--separator=STRING` | Utilise `STRING` comme séparateur entre les valeurs, au lieu du saut de ligne (`\n`) par défaut. |
| `-f FORMAT` | `--format=FORMAT` | Utilise un format de style `printf` pour l'affichage de chaque valeur (ex. `%03d`, ou une chaîne composite comme `IP_192.168.1.%d`). |

!!! tip "Astuce mémo"
    `-f` est plus flexible que `-w` : il permet d'insérer le nombre généré dans un gabarit de texte complet (préfixe/suffixe), alors que `-w` se contente d'ajouter des zéros de remplissage.

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Génération simple et personnalisation du pas

Nombres impairs de 1 à 10 (pas de 2) :

```bash
seq 1 2 10
# 1 3 5 7 9
```

Décompte de 10 à 1 (pas négatif) :

```bash
seq 10 -1 1
# 10 9 8 7 6 5 4 3 2 1
```

### 2. Utilisation dans une boucle Bash (`for`)

Parcourt une plage de numéros dans une boucle `for` :

```bash
for i in $(seq 1 5); do
    echo "Traitement de l'itération $i"
done
```

### 3. Création massive de dossiers/fichiers numérotés (`-w`)

Génère une structure de dossiers propre avec zéros de remplissage, garantissant un tri alphabétique correct :

```bash
mkdir $(seq -f "backup_%02d" 1 12)
# Crée backup_01, backup_02, ..., backup_12

touch fichier_$(seq -w 1 31 | sed 's/^/fichier_/')
# Alternative directe avec -w seul :
for n in $(seq -w 1 31); do touch "fichier_${n}.log"; done
```

### 4. Formatage avancé d'adresses ou d'identifiants (`-f`)

Génère une liste d'adresses IP consécutives, via un gabarit `printf` :

```bash
seq -f "192.168.1.%g" 10 20
# 192.168.1.10
# 192.168.1.11
# ...
# 192.168.1.20
```

### 5. Génération d'une liste sur une seule ligne (`-s`)

Crée une séquence sur une seule ligne, séparée par une chaîne personnalisée (virgule, espace, etc.) :

```bash
seq -s ", " 1 10
# 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
```

### 6. Combinaison avec `xargs` pour le traitement en parallèle

Exécute une commande pour chaque valeur générée, avec un parallélisme contrôlé via `xargs -P` :

```bash
seq 1 50 | xargs -P 5 -I {} curl -s "https://api.exemple.com/item/{}" -o "item_{}.json"
```

---

## 5. Astuces, Alternatives & Pièges à éviter

!!! tip "Alternative native Bash (Brace Expansion `{1..N}`)"
    Bash propose une expansion d'accolades native, `{PREMIER..DERNIER}` (et `{PREMIER..DERNIER..PAS}` en Bash 4+), qui **ne lance aucun processus externe** et s'exécute donc plus rapidement que `seq` pour des cas simples :

    ```bash
    for i in {1..5}; do echo "$i"; done
    for i in {01..10}; do echo "$i"; done   # Zéros de remplissage natifs
    ```

    **Privilégier `{1..N}`** pour des scripts Bash purs avec bornes fixes connues à l'écriture du script. **`seq` reste nécessaire** dans les cas suivants :

    - Compatibilité avec des shells POSIX ne supportant pas l'expansion d'accolades (`sh`, `dash`).
    - Bornes **dynamiques** définies par une variable (voir piège ci-dessous).
    - Nombres **décimaux** (non supportés par l'expansion d'accolades).
    - Pas personnalisé combiné à un formatage avancé (`-f`, `-s`).

!!! danger "Gestion des variables dynamiques"
    L'expansion d'accolades Bash est évaluée **avant** la substitution de variable, ce qui empêche `{1..$VAR}` de fonctionner comme une plage dynamique :

    ```bash
    VAR=5

    # NE FONCTIONNE PAS : traité littéralement comme la chaîne "{1..5}" seulement
    # si $VAR est développé avant coup — en réalité Bash standard échoue ici :
    for i in {1..$VAR}; do echo "$i"; done
    # Affiche littéralement : {1..5}   (pas d'expansion)

    # FONCTIONNE : seq accepte nativement une variable comme borne
    for i in $(seq 1 "$VAR"); do echo "$i"; done
    # Affiche : 1 2 3 4 5
    ```

    Pour toute plage dont les bornes sont calculées ou fournies en paramètre de script, **`seq` est le choix fiable**, sauf à utiliser la syntaxe `eval` ou une boucle `for ((i=1; i<=VAR; i++))` en alternative.

!!! warning "Précision avec les nombres décimaux"
    `seq` s'appuie sur l'arithmétique en virgule flottante pour les séquences décimales, ce qui peut produire des **résultats imprécis** en raison des limites de représentation binaire des flottants :

    ```bash
    seq 0 0.1 1
    # 0.0
    # 0.1
    # 0.2
    # ...
    # 1.0
    # (le dernier terme peut parfois être omis ou légèrement décalé selon la plateforme)
    ```

    Pour des calculs nécessitant une précision décimale garantie (finance, mesures scientifiques), préférer un outil dédié à l'arithmétique de précision (`bc`, `awk`, ou un langage de script avec gestion explicite des décimales) plutôt que `seq` seul.
