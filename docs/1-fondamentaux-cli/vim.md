# Cheat Sheet : `vim` — Éditeur de texte modal

!!! tip "Usage principal"
    Éditer des fichiers directement en environnement terminal, y compris sur un serveur distant sans interface graphique — quasi systématiquement présent sur les systèmes Linux/Unix, et un vecteur classique d'évasion de shell restreint.

## 1. Syntaxe de base

```bash
# Structure générale
vim fichier
```

---

## 2. Modes de fonctionnement & Navigation de base

| Mode | Rôle | Accès |
| --- | --- | --- |
| `Normal` | Exécuter des commandes (déplacement, suppression, copie...) | `Esc` depuis n'importe quel mode |
| `Insert` | Saisir du texte librement | `i`, `a`, `o`... depuis `Normal` |
| `Visual` | Sélectionner du texte (caractère, ligne, bloc) | `v`, `V`, `Ctrl+v` depuis `Normal` |
| `Commande` (Ex) | Taper des commandes `:` (sauvegarde, remplacement...) | `:` depuis `Normal` |

### Déplacement rapide sans les flèches
```
h j k l    # gauche, bas, haut, droite
w          # début du mot suivant
b          # début du mot précédent
0          # début de la ligne
$          # fin de la ligne
gg         # début du fichier
G          # fin du fichier
50%        # va à 50% du fichier (N% = pourcentage donné)
```

!!! tip "Répéter un déplacement"
    Préfixer un déplacement d'un nombre le répète : `5j` descend de 5 lignes, `3w` avance de 3 mots. Cette formule `[répétition]+action` est le cœur de l'efficacité sous vim.

---

## 3. Édition, Copie & Suppression (Mode Normal)

### Insertion
```
i     # insère avant le curseur
a     # ajoute après le curseur
I     # insère en début de ligne
A     # ajoute en fin de ligne
o     # nouvelle ligne en dessous
O     # nouvelle ligne au dessus
```

### Suppression et découpage
```
x     # supprime le caractère sous le curseur
dd    # supprime la ligne entière
dw    # supprime jusqu'au début du mot suivant
d$    # supprime jusqu'à la fin de la ligne
dG    # supprime du curseur jusqu'à la fin du fichier
2dd   # supprime 2 lignes
```

### Copie et collage
```
yy    # copie la ligne entière ("yank")
yw    # copie le mot
p     # colle après le curseur / ligne suivante
P     # colle avant le curseur / ligne précédente
```

### Annulation et rétablissement
```
u        # annule la dernière action
Ctrl+r   # rétablit l'action annulée
.        # répète le dernier changement
```

## Synthèse — Tableau des raccourcis d'édition

| Commande | Rôle |
| --- | --- |
| `cw` | Modifie le mot (supprime puis passe en `Insert`) |
| `c$` | Modifie jusqu'à la fin de la ligne |
| `r{char}` | Remplace le caractère sous le curseur |
| `R` | Passe en mode `Replace` (écrase en tapant) |
| `J` | Joint la ligne actuelle avec la suivante |

---

## 4. Recherche & Remplacement (Regex / Mode Commande)

### Recherche rapide
```
/motif    # recherche en avant, Entrée pour lancer
?motif    # recherche en arrière
n / N     # occurrence suivante / précédente
```

### Substitution globale par regex
```
:%s/ancien/nouveau/g     # remplace TOUTES les occurrences sur TOUT le fichier
:%s/ancien/nouveau/gc    # comme ci-dessus, avec confirmation (y/n) à chaque occurrence
:s/ancien/nouveau/g      # remplace uniquement sur la ligne courante
```

### Sensibilité à la casse
```
:set ic      # active la recherche insensible à la casse (ignorecase)
:set noic    # revient à une recherche sensible à la casse
/motif\c     # force l'insensibilité à la casse pour cette seule recherche
```

---

## 5. Gestion des Fichiers, Buffers & Fenêtres

### Sauvegarder et quitter
```
:w      # sauvegarder
:q      # quitter
:q!     # quitter sans sauvegarder
:wq     # sauvegarder et quitter
:x      # sauvegarde uniquement si modifié, puis quitte (équivalent optimisé de :wq)
ZZ      # sauvegarder et quitter (raccourci clavier, mode Normal)
```

### Split d'écran
```
:sp fichier     # split horizontal (ouvre fichier dans le nouveau volet)
:vsp fichier    # split vertical
Ctrl+w puis w   # bascule d'un volet à l'autre
Ctrl+w puis q   # ferme le volet courant
```

### Lire ou incruster un fichier / une sortie de commande
```
:r fichier       # insère le contenu d'un fichier à la position du curseur
:r !whoami       # insère la sortie d'une commande shell dans le buffer
```

---

## 6. Cas d'usage Pentest & Administration

### Édition de fichiers binaires (vue hexadécimale)
```
:%!xxd        # convertit l'affichage du buffer en hexdump éditable
:%!xxd -r     # reconvertit le hexdump modifié en binaire avant sauvegarde
```

### Nettoyage des retours chariot Windows (CRLF → LF)
```
:%s/\r//g       # supprime tous les caractères \r (retour chariot) du fichier
:set ff=unix    # force le format de fin de ligne Unix (LF) avant sauvegarde
```

## Synthèse — Tableau des commandes utilitaires

| Commande | Rôle |
| --- | --- |
| `:%!xxd` | Bascule le buffer en vue hexadécimale éditable |
| `:%!xxd -r` | Reconvertit le hexdump en binaire |
| `:%s/\r//g` | Supprime les retours chariot Windows (CRLF → LF) |
| `:set ff=unix` | Force le format de fin de ligne Unix |
| `vim +42 fichier` | Ouvre directement à la ligne 42 |

```bash
# Ouvrir directement un fichier à une ligne précise (utile pour un rapport d'erreur avec numéro de ligne)
vim +42 fichier.txt
```

!!! warning "Évasion de shell restreint / élévation de privilèges via `sudo vim`"
    Si `vim` est autorisé en `sudo` (`sudo -l` montre `vim` sans restriction d'arguments), il est possible d'obtenir un **shell root complet** depuis l'éditeur, sans jamais quitter proprement le programme autorisé :
    ```
    :shell           " ouvre un shell interactif hérité des droits de vim
    :!/bin/sh        " variante équivalente
    :w !sudo tee %   " écrit le buffer via sudo, utile pour éditer un fichier root en confirmant l'écrasement forcé
    ```
    C'est une entrée GTFOBins classique : en durcissement de comptes à privilèges limités, `vim` (comme `less`, `man`, `find -exec`) doit systématiquement être vérifié dans les règles `sudoers`.

!!! warning "Piège du mode Insert"
    Un utilisateur non habitué peut se retrouver **bloqué en mode Insert sans pouvoir taper de commande** : appuyer sur `Esc` pour revenir en mode `Normal` avant toute action (`:q!`, `:wq`, etc.). C'est la source n°1 de confusion des débutants avec `vim`.