# Cheat Sheet : Fichiers & Dossiers — Navigation, création, copie, suppression

!!! tip "Usage principal"
    Toutes les commandes de base pour naviguer, créer, copier, déplacer, supprimer et identifier des fichiers/dossiers sous Linux — le socle quotidien de l'administration comme du pentest.

## 1. Syntaxe de base

```bash
# Structure générale des commandes couvertes
ls [options] [chemin]
cd [chemin] | pwd
mkdir [options] repertoire | rmdir repertoire
cp [options] source destination
mv [options] source destination
rm [options] fichier
touch [options] fichier
file [options] fichier
```

---

## 2. Navigation (`cd`, `pwd`, `ls`)

### Se situer et se déplacer
```bash
# Affiche le chemin absolu du répertoire courant
pwd
```

```bash
# Se déplace vers un chemin relatif ou absolu
cd dossier/sous-dossier
cd /var/www/html
```

### Raccourcis de navigation
```bash
cd ~     # répertoire home de l'utilisateur
cd -     # répertoire précédent (bascule aller-retour)
cd ..    # répertoire parent
cd .     # répertoire courant (sans effet, utile en argument d'autre commande)
```

### Lister le contenu d'un répertoire
```bash
# Format long : permissions, propriétaire, groupe, taille, date
ls -l
```

```bash
# Inclut les fichiers cachés (commençant par un point)
ls -a
```

```bash
# Combo le plus utilisé en énumération : détails + cachés
ls -la
```

### Trier la liste
```bash
ls -lt     # tri par date de modification (récent en premier)
ls -lS     # tri par taille (plus gros en premier)
ls -lh     # tailles lisibles (Ko/Mo/Go) au lieu d'octets bruts
ls -ld dossier/   # affiche le dossier lui-même, pas son contenu
```

!!! tip "Rappel express"
    Les droits `rwx rwx rwx` (propriétaire/groupe/autres) affichés par `ls -l` se lisent : `r`=4, `w`=2, `x`=1. Voir la fiche `chmod` pour la gestion complète des permissions.

---

## 3. Création & Arborescence (`mkdir`, `rmdir`, `touch`)

### Créer un ou plusieurs dossiers
```bash
# Échoue si le parent n'existe pas
mkdir nouveau_dossier
```

```bash
# -p crée aussi les parents manquants (indispensable pour une arborescence en une commande)
mkdir -p projet/src/utils
```

```bash
# Création multiple avec accolades
mkdir -p projet/{src,tests,docs}
```

### Supprimer un dossier vide
```bash
# rmdir ne fonctionne QUE sur un dossier vide (sinon erreur)
rmdir dossier_vide/
```

### Créer ou "toucher" un fichier
```bash
# Crée un fichier vide s'il n'existe pas, ou met à jour son timestamp s'il existe
touch fichier.txt
```

```bash
# Création multiple en une commande
touch a.txt b.txt c.txt
```

```bash
# Force un timestamp précis (utile en scripting, ou en anti-forensic : "timestomping")
touch -d "2024-01-01 00:00:00" fichier.txt
```

---

## 4. Copie & Déplacement (`cp`, `mv`)

### Copier un fichier
```bash
# Copie simple, renommage possible dans la destination
cp fichier.txt copie.txt
```

```bash
# -r obligatoire pour copier un dossier et son contenu
cp -r dossier_source/ dossier_dest/
```

```bash
# -a (archive) : récursif + préserve permissions, dates, liens symboliques
cp -a dossier_source/ dossier_dest/
```

### Déplacer / renommer un fichier
```bash
# Usage le plus courant : renommage simple
mv ancien_nom.txt nouveau_nom.txt
```

```bash
# Aucun -r nécessaire pour mv, même pour un dossier entier
mv dossier_source/ /destination/
```

### Sécuriser une copie/déplacement contre l'écrasement
```bash
cp -i fichier.txt dest/   # demande confirmation avant écrasement
mv -i fichier.txt dest/   # idem pour mv
cp -n fichier.txt dest/   # n'écrase jamais, sans prompt
```

## Synthèse `cp` / `mv` — Tableau des flags

| Flag | Rôle | Commande |
| --- | --- | --- |
| `-r` | Récursif (obligatoire pour un dossier avec `cp`) | `cp -r src/ dst/` |
| `-a` | Archive : récursif + préserve permissions/dates/liens | `cp -a src/ dst/` |
| `-i` | Mode interactif, confirme avant écrasement | `cp -i a.txt dst/` |
| `-f` | Force l'écrasement sans prompt | `cp -f a.txt dst/` |
| `-n` | N'écrase jamais, sans prompt | `mv -n a.txt dst/` |
| `-v` | Mode verbeux, liste chaque fichier traité | `cp -v *.log dst/` |
| `-u` (cp) | Copie seulement si la source est plus récente | `cp -u a.txt dst/` |
| `-t DEST` (mv) | Destination avant la liste de fichiers | `mv -t dst/ a.txt b.txt` |

---

## 5. Suppression & Sécurité (`rm`)

### Supprimer un fichier
```bash
# Suppression définitive : aucune corbeille en ligne de commande
rm fichier.txt
```

```bash
# Confirmation avant chaque suppression (recommandé en usage manuel)
rm -i fichier.txt
```

### Supprimer un dossier et son contenu
```bash
# -r rend la suppression récursive (obligatoire pour un dossier non vide)
rm -r dossier/
```

```bash
# Combo classique : récursif + forcé, sans aucune confirmation
rm -rf dossier/
```

### Nettoyage ciblé
```bash
# Supprimer tous les dossiers vides d'une arborescence
find . -type d -empty -delete
```

## Synthèse `rm` — Tableau des flags

| Flag | Rôle | Commande |
| --- | --- | --- |
| `-i` | Confirme chaque suppression | `rm -i fichier` |
| `-f` | Force, ignore les fichiers protégés, pas de prompt | `rm -f fichier` |
| `-r` | Récursif (nécessaire pour un dossier) | `rm -r dossier/` |
| `-rf` | Combo récursif + forcé | `rm -rf dossier/` |
| `-v` | Mode verbeux | `rm -v *.tmp` |

---

## 6. Identification (`file`)

### Vérifier le type réel d'un fichier
```bash
# Se base sur le contenu (magic bytes), pas sur l'extension
file fichier_inconnu
```

```bash
# Vérifier tous les fichiers d'un dossier d'un coup
file *
```

```bash
# Affiche le type MIME (utile pour scripts/validation)
file -i document
```

## Synthèse `file` — Tableau des flags

| Flag | Rôle | Commande |
| --- | --- | --- |
| `-i` | Affiche le type MIME | `file -i doc.pdf` |
| `-b` | Mode bref, sans afficher le nom du fichier | `file -b doc.pdf` |
| `-L` | Suit les liens symboliques | `file -L lien` |
| `-z` | Inspecte l'intérieur des fichiers compressés | `file -z archive.gz` |

---

## 7. One-Liners & Pièges courants

```bash
# Repérer les fichiers récemment modifiés (traces d'intrusion / debug rapide)
ls -lat /var/www/html | head -20
```

```bash
# Sauvegarde rapide avant modification d'un fichier de config
cp -p /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
```

```bash
# Vérifier qu'une extension suspecte correspond bien au contenu réel
file *.jpg | grep -v "image data"
```

```bash
# Recomposer un chemin absolu fiable dans un script
BASEDIR=$(pwd)
```

!!! warning "Pièges à connaître"
    - **`rm -rf` est irréversible et sans confirmation** : une variable vide (`rm -rf "$VAR"/*` avec `$VAR` non définie) peut effacer bien plus que prévu. Toujours vérifier le chemin avant d'exécuter.
    - **`cp` et `mv` écrasent silencieusement** un fichier de destination portant le même nom : utilisez `-i` en usage manuel.
    - **`rmdir` échoue sur un dossier non vide** ; il faut `rm -r` dans ce cas.
    - **`mkdir a/b/c` échoue sans `-p`** si les parents n'existent pas encore.
    - **L'extension d'un fichier n'a aucune valeur de sécurité** sous Linux : seul `file` (contenu réel) fait foi, jamais le nom.
