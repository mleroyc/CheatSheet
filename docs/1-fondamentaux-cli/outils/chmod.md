# Cheat Sheet : `chmod` — Gestion des permissions Linux

!!! tip "Usage principal"
    Modifier les droits d'accès (lecture/écriture/exécution) d'un fichier ou dossier, y compris les bits spéciaux souvent exploités en élévation de privilèges (SUID/SGID).

## 1. Syntaxe de base

```bash
# Structure générale
chmod [options] mode cible

# Deux notations possibles :
chmod 755 fichier        # notation octale
chmod u+x,g-w fichier    # notation symbolique (u/g/o/a + +/-/= + r/w/x)
```

Rappel du calcul octal : `r=4`, `w=2`, `x=1` → on additionne par entité (propriétaire/groupe/autres).

## 2. Commandes rapides & Cas d'usage fréquents

### Modification des droits basiques
```bash
# rwxr-xr-x : propriétaire tous droits, groupe et autres lecture/exécution seulement
chmod 755 script.sh
```

```bash
# Ajoute uniquement le droit d'exécution au propriétaire, sans toucher au reste
chmod u+x script.sh
```

```bash
# Retire tout droit d'accès aux "autres" (durcissement rapide)
chmod o-rwx fichier_sensible
```

### Application récursive
```bash
# Applique 644 (lecture/écriture propriétaire, lecture seule groupe/autres) à tout un dossier
chmod -R 644 /var/www/html
```

### Gestion des droits spéciaux (SUID/SGID/Sticky bit)
```bash
# SUID : le fichier s'exécute avec les privilèges de son propriétaire (souvent root)
chmod 4755 /usr/bin/binaire
chmod u+s /usr/bin/binaire
# Visible dans ls -l : -rwsr-xr-x (s = SUID + x actif | S = SUID sans x)
```

```bash
# SGID sur un dossier : tout fichier créé dedans hérite du groupe du dossier parent
chmod 2775 /partage/commun
chmod g+s /partage/commun
# Visible dans ls -l : drwxrwsr-x (s = SGID + x actif | S = SGID sans x)
```

```bash
# Sticky bit : dans un dossier partagé, seul le propriétaire du fichier peut le supprimer
chmod 1777 /tmp
chmod +t /tmp
# Visible dans ls -l : drwxrwxrwt (t = Sticky + x actif | T = Sticky sans x)
```

## 3. Synthèse des Flags & Options (Tableau)

| Flag / Bit | Rôle | Exemple d'utilisation |
| --- | --- | --- |
| `-R` | Applique les modifications de manière récursive | `chmod -R 755 /dossier` |
| `u / g / o / a` | Cible propriétaire / groupe / autres / tous (notation symbolique) | `chmod g+w fichier` |
| `4000` | Active le bit SUID (exécution avec privilèges du propriétaire) | `chmod 4755 /fichier` |
| `2000` | Active le bit SGID (héritage de groupe sur dossier, ou droits groupe propriétaire sur binaire) | `chmod 2755 /fichier` |
| `1000` | Active le Sticky bit (suppression réservée au propriétaire) | `chmod 1777 /dossier` |
| `--reference=fichier` | Copie les permissions d'un fichier de référence | `chmod --reference=modele.txt cible.txt` |

## 4. One-Liners & Pièges courants

```bash
# Recherche de binaires SUID sur tout le système : classique en escalade de privilèges Linux
find / -perm -4000 -type f 2>/dev/null
```

```bash
# Recherche des dossiers/fichiers accessibles en écriture par tous (faille potentielle)
find / -perm -o+w -type f 2>/dev/null
```

!!! warning "Attention"
    Un `chmod 777` "pour que ça marche" est une mauvaise pratique classique : cela autorise **écriture et exécution par n'importe quel utilisateur**, ouvrant la porte à un remplacement malveillant du fichier. Préférez toujours le droit minimal nécessaire (principe du moindre privilège).
