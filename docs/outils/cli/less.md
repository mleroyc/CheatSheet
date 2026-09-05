# 🛠️ Commande : less

## 1. Description rapide (Rôle et cas d'usage)

`less` est un pageur interactif permettant de parcourir un fichier ou un flux sans le charger intégralement en mémoire. Il est indispensable pour explorer de gros fichiers (logs, dumps) car il ne lit que la portion affichée à l'écran, contrairement à `cat` qui affiche tout d'un bloc. Il permet aussi la recherche, la navigation bidirectionnelle et le suivi temps réel.

## 2. Syntaxe de base

```bash
less [OPTIONS] fichier
commande | less
```

## 3. Options et fanions principaux

| Option / Raccourci | Effet |
|---|---|
| `-N` | Affiche les numéros de ligne |
| `-S` | Désactive le retour à la ligne (scroll horizontal) |
| `-i` | Recherche insensible à la casse |
| `Page Up` / `Page Down` | Défilement page par page |
| `g` / `G` | Aller au début / à la fin du fichier |
| `/motif` | Recherche vers le bas |
| `?motif` | Recherche vers le haut |
| `n` / `N` | Occurrence suivante / précédente |
| `F` | Mode suivi temps réel (équivalent `tail -f`) |
| `q` | Quitter |

## 4. Exemples pratiques & Cas d'usage

**Explorer un log volumineux sans le charger entièrement**
```bash
less /var/log/syslog
```

**Rechercher une IP suspecte dans un log d'accès**
```bash
less /var/log/nginx/access.log
/203\.0\.113\.
```

**Afficher avec numéros de lignes pour référencer une ligne précise**
```bash
less -N /etc/nginx/nginx.conf
```

**Suivre un log en direct depuis less (utile si on veut aussi chercher)**
```bash
less +F /var/log/auth.log
```

**Analyser la sortie d'une commande sans fichier temporaire**
```bash
journalctl -u sshd | less
```

**Désactiver le retour à la ligne pour lire des fichiers CSV/large lines**
```bash
less -S rapport_large.csv
```

## 5. Astuces & Pièges à éviter

!!! tip "Basculer entre suivi et navigation"
    En mode `F` (suivi temps réel), appuyez sur `Ctrl+C` pour repasser en navigation normale sans quitter `less`, contrairement à `tail -f` qu'il faut interrompre.

!!! warning "Pas de suivi automatique sur rotation de log"
    Comme `tail -f`, le mode `F` de `less` peut perdre le fichier si celui-ci est renommé/recréé par `logrotate`. Il faut relancer `less` sur le nouveau fichier.

!!! tip "Gestion mémoire vs cat"
    Sur un fichier de plusieurs Go, `less` reste réactif car il ne lit que par blocs, alors que `cat` tenterait d'écrire tout le contenu sur la sortie standard, ce qui peut noyer le terminal.
