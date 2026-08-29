# Cheat Sheet : `chown` — Changement de propriétaire et de groupe

!!! tip "Usage principal"
    Modifier le propriétaire et/ou le groupe propriétaire d'un fichier ou dossier — essentiel pour le durcissement des droits d'accès et la gestion multi-utilisateurs.

## 1. Syntaxe de base

```bash
# Structure générale
chown [options] utilisateur:groupe cible
```

## 2. Commandes rapides & Cas d'usage fréquents

### Changement de propriétaire et de groupe
```bash
# Change le propriétaire en alice et le groupe en communs
chown alice:communs fichier.txt
```

### Changement du propriétaire uniquement
```bash
# Ne modifie que le propriétaire, laisse le groupe inchangé
chown alice fichier.txt
```

### Changement du groupe uniquement
```bash
# Le ":" seul devant le nom indique qu'on ne touche qu'au groupe
chown :communs fichier.txt
```

### Application récursive
```bash
# Change récursivement propriétaire et groupe sur toute une arborescence
chown -R www-data:www-data /var/www/monsite
```

### Copier les droits d'un fichier de référence
```bash
# Applique le même propriétaire/groupe que modele.txt à cible.txt
chown --reference=modele.txt cible.txt
```

## 3. Synthèse des Flags & Options (Tableau)

| Flag / Option | Rôle | Exemple d'utilisation |
| --- | --- | --- |
| `-R` | Applique le changement de manière récursive | `chown -R user:group /dossier` |
| `:` (seul devant le groupe) | Ne modifie que le groupe, pas le propriétaire | `chown :groupe fichier` |
| `-v` | Mode verbeux, affiche chaque changement effectué | `chown -v user fichier` |
| `--reference=FILE` | Copie les attributs propriétaire/groupe d'un fichier modèle | `chown --reference=a.txt b.txt` |
| `-h` | Modifie le lien symbolique lui-même, pas sa cible | `chown -h user lien_symbolique` |

## 4. One-Liners & Pièges courants

```bash
# Rechercher tous les fichiers appartenant à un utilisateur donné (audit / recherche de fichiers oubliés)
find / -user alice -type f 2>/dev/null
```

```bash
# Reprendre la main sur un dossier applicatif après une mauvaise manipulation de droits
chown -R $(whoami):$(whoami) /chemin/dossier
```

!!! warning "Attention"
    Seul **root** peut changer le propriétaire d'un fichier vers un autre utilisateur (contrairement à `chgrp`, qu'un propriétaire peut parfois exécuter pour son propre fichier vers un groupe dont il est membre). Un `chown -R` mal ciblé sur un dossier système peut casser des permissions critiques (ex: `/etc`, `/var`) — vérifiez toujours le chemin avant exécution.
