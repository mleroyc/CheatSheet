# 🛠️ Commande : nl

## 1. Description rapide (Rôle et cas d'usage)

`nl` (*number lines*) numérote les lignes d'un fichier, avec des options de numérotation plus fines que `cat -n` : possibilité d'ignorer les lignes vides, de personnaliser le format des numéros, ou de numéroter uniquement certaines sections.

## 2. Syntaxe de base

```bash
nl [OPTIONS] fichier
commande | nl
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-b a` | Numérote toutes les lignes, y compris les vides |
| `-b t` | Numérote uniquement les lignes non vides (défaut) |
| `-n ln` | Justifie les numéros à gauche |
| `-n rz` | Numéros avec zéros de tête (ex: `001`) |
| `-s SEP` | Définit le séparateur entre le numéro et le texte |
| `-w N` | Largeur du champ de numérotation |

## 4. Exemples pratiques & Cas d'usage

**Numéroter un fichier de configuration pour y faire référence**
```bash
nl /etc/hosts
```

**Numéroter absolument toutes les lignes, y compris vides**
```bash
nl -b a script.sh
```

**Générer une numérotation avec zéros de tête pour un rapport formaté**
```bash
nl -n rz -w 4 rapport.txt
```

**Numéroter la sortie d'une commande pour cibler une ligne précise ensuite**
```bash
grep "ERROR" app.log | nl
```

**Personnaliser le séparateur entre numéro et contenu**
```bash
nl -s ") " liste_taches.txt
```

**Numéroter uniquement les lignes correspondant à un motif de section**
```bash
nl -b p"^Section" document.txt
```

## 5. Astuces & Pièges à éviter

!!! tip "nl vs cat -n : plus de contrôle"
    `cat -n` numérote systématiquement toutes les lignes sans option de filtrage. `nl` permet d'ignorer les lignes vides par défaut (`-b t`), ce qui donne une numérotation plus proche de celle attendue dans un document structuré (code, texte).

!!! warning "Comportement par défaut différent de cat -n"
    Par défaut, `nl` ne numérote PAS les lignes vides (contrairement à `cat -n` qui numérote tout). Si vous voulez un comportement identique à `cat -n`, ajoutez explicitement `-b a`.

!!! tip "Combiner avec grep pour localiser une ligne précise"
    `nl fichier | grep "motif"` retourne le numéro de ligne exact correspondant au motif recherché, pratique avant d'ouvrir un éditeur avec `vim +N fichier`.
