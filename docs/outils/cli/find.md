# Cheat Sheet : `find` — Recherche de fichiers et exécution d'actions

!!! tip "Usage principal"
    Rechercher des fichiers/dossiers selon des critères précis (nom, type, taille, date, permissions, propriétaire) et enchaîner une action dessus — outil central en énumération pentest et en administration système.

## 1. Syntaxe de base

```bash
# Structure générale
find chemin [options] expression

# Recherche récursive par défaut depuis le chemin donné
find /home -name "*.log"
```

---

## 2. Filtres courants (nom, type, taille, temps)

### Recherche par nom / extension
```bash
# Sensible à la casse
find /home -name "*.log"
```

```bash
# Insensible à la casse : trouve "config", "Config", "CONFIG"...
find / -iname "config*" 2>/dev/null
```

### Recherche par type
```bash
find /var -type d -name "log*"   # -type d : dossiers uniquement
find /etc -type f -name "*.conf" # -type f : fichiers uniquement
find /usr -type l                # -type l : liens symboliques uniquement
```

### Recherche par taille
```bash
find / -size +100M 2>/dev/null   # fichiers de plus de 100 Mo
find / -size -10k 2>/dev/null    # fichiers de moins de 10 Ko
find / -size 0 2>/dev/null       # fichiers vides (0 octet)
```

### Recherche par temps (modification, accès, changement de métadonnées)
```bash
find /tmp -mtime -1     # modifié il y a moins de 1 jour (contenu)
find /tmp -atime -1     # accédé (lu) il y a moins de 1 jour
find /tmp -ctime -1     # métadonnées changées il y a moins de 1 jour (permissions, propriétaire...)
```

```bash
# -mmin travaille en minutes plutôt qu'en jours : précision fine pour une intrusion récente
find / -mmin -30 -type f 2>/dev/null
```

!!! tip "mtime vs atime vs ctime"
    `mtime` = contenu modifié · `atime` = fichier lu/accédé · `ctime` = métadonnées changées (permissions, propriétaire, renommage). En forensic, `ctime` est souvent plus fiable que `mtime` car plus difficile à falsifier proprement (`touch` ne modifie pas `ctime`).

---

## 3. Droits, Propriétaires & Recherche de Privilèges (Essentiel Pentest)

### Recherche par permissions
```bash
# Permissions EXACTES (777 pile, ni plus ni moins)
find / -perm 777 2>/dev/null
```

```bash
# -4000 : bit SUID actif (masque partiel, quel que soit le reste des droits)
find / -perm -4000 -type f 2>/dev/null
```

```bash
# -2000 : bit SGID actif
find / -perm -2000 -type f 2>/dev/null
```

### Recherche par propriétaire / groupe
```bash
find / -user alice 2>/dev/null    # appartenant à l'utilisateur alice
find / -group admins 2>/dev/null  # appartenant au groupe admins
```

```bash
# Fichiers orphelins : propriétaire ou groupe supprimé du système (souvent oubliés, jamais audités)
find / -nouser 2>/dev/null
find / -nogroup 2>/dev/null
```

### Fichiers/dossiers accessibles en écriture
```bash
# Accessible en écriture par l'utilisateur courant (selon droits effectifs)
find / -writable -type d 2>/dev/null
```

```bash
# Accessible en écriture par TOUT LE MONDE (faille classique de configuration)
find / -perm -o+w -type f 2>/dev/null
```

### Filtrer le bruit des erreurs de permission
```bash
find / -name "*.conf" 2>/dev/null            # masque les "Permission denied" sur stderr
find / -readable -name "*.conf" 2>/dev/null  # alternative : ne remonte que les fichiers réellement lisibles
```

## Synthèse — Tableau récapitulatif des critères & flags

| Flag / Option | Rôle | Exemple d'utilisation |
| --- | --- | --- |
| `-name` | Recherche par nom (sensible à la casse) | `find / -name "*.php"` |
| `-iname` | Recherche par nom, insensible à la casse | `find / -iname "*.PHP"` |
| `-type f\|d\|l` | Filtre par type : fichier, dossier, lien symbolique | `find / -type l` |
| `-size +N/-N[k,M,G]` | Filtre par taille (supérieure/inférieure) | `find / -size +50M` |
| `-mtime +N/-N` | Filtre par date de modification du contenu (jours) | `find / -mtime -7` |
| `-atime +N/-N` | Filtre par date de dernier accès (jours) | `find / -atime -1` |
| `-ctime +N/-N` | Filtre par date de changement de métadonnées (jours) | `find / -ctime -1` |
| `-mmin +N/-N` | Comme `-mtime` mais en minutes | `find / -mmin -30` |
| `-perm MODE` | Permissions strictement égales au mode | `find / -perm 644` |
| `-perm -MODE` | Au moins les bits du mode (masque) — SUID/SGID | `find / -perm -4000` |
| `-user NOM` | Filtre par propriétaire | `find / -user root` |
| `-group NOM` | Filtre par groupe propriétaire | `find / -group admins` |
| `-nouser` / `-nogroup` | Fichiers orphelins (propriétaire/groupe inexistant) | `find / -nouser` |
| `-writable` | Accessible en écriture par l'utilisateur courant | `find / -writable -type d` |
| `-readable` | Accessible en lecture par l'utilisateur courant | `find / -readable` |
| `-maxdepth N` | Limite la profondeur de recherche | `find / -maxdepth 3` |
| `-mindepth N` | Ignore les N premiers niveaux de profondeur | `find / -mindepth 2` |
| `-prune` | Exclut une arborescence de la recherche | voir section 5 |
| `-exec cmd {} \;` | Exécute une commande par résultat (1 appel/fichier) | `find . -exec chmod 644 {} \;` |
| `-exec cmd {} +` | Exécute une commande groupée (plusieurs fichiers/appel) | `find . -exec chmod 644 {} +` |
| `-delete` | Supprime directement chaque résultat trouvé | `find /tmp -name "*.tmp" -delete` |
| `-print` / `-print0` | Affiche le résultat (défaut), ou terminé par `\0` (voir `xargs`) | `find . -print0` |

---

## 4. Actions & Exécution automatique

### `-exec` : ligne par ligne vs groupé
```bash
# {} remplacé par chaque fichier, \; termine l'appel : UNE commande par fichier trouvé
find . -name "*.log" -exec ls -l {} \;
```

```bash
# {} + regroupe autant de fichiers que possible en un minimum d'appels : bien plus rapide
find . -name "*.log" -exec ls -l {} +
```

!!! tip "Quand utiliser `+` plutôt que `\;`"
    `{} +` fonctionne comme `xargs` intégré : la commande doit accepter plusieurs arguments à la suite (`ls`, `chmod`, `chown`...). Pour des commandes qui ne traitent qu'un seul fichier à la fois (ou nécessitent `{}` au milieu des arguments), `\;` reste obligatoire.

### Combiner avec `xargs`
```bash
# Passe chaque résultat en argument à xargs, qui les regroupe pour la commande grep
find / -name "*.conf" 2>/dev/null | xargs grep -l "password"
```

```bash
# -print0 (find) + xargs -0 : sépare les résultats par un octet NUL au lieu d'un espace/retour ligne
# Indispensable pour gérer correctement les noms de fichiers contenant espaces ou retours à la ligne
find / -name "*.conf" -print0 2>/dev/null | xargs -0 grep -l "password"
```

### Suppression directe
```bash
# Supprime chaque résultat sans passer par -exec rm
find /tmp -name "*.tmp" -delete
```

```bash
# Toujours tester avec -print avant -delete pour vérifier la portée exacte de la recherche
find /tmp -name "*.tmp" -print
```

---

## 5. Optimisation & Navigation

### Limiter la profondeur
```bash
find /etc -maxdepth 2 -name "*.conf"   # ne descend pas au-delà de 2 niveaux
find / -mindepth 3 -name "*.log"       # ignore les 2 premiers niveaux de profondeur
```

### Exclure des dossiers spécifiques avec `-prune`
```bash
# Exclut /proc, /sys et /dev d'une recherche système complète (dossiers virtuels, sans intérêt et lents)
find / \( -path /proc -o -path /sys -o -path /dev \) -prune -o -name "*.conf" -print 2>/dev/null
```

```bash
# Variante plus lisible pour exclure un seul dossier
find / -path /mnt -prune -o -type f -name "*.log" -print 2>/dev/null
```

!!! tip "Pourquoi exclure /proc, /sys, /dev"
    Ces répertoires contiennent des fichiers **virtuels** générés dynamiquement par le noyau (pas de vraies données sur disque) : les parcourir ralentit fortement une recherche système complète et peut produire des résultats non pertinents, voire des erreurs de lecture en boucle.

---

## 6. One-Liners d'Énumération / Pentest

```bash
# Binaires SUID/SGID exploitables — étape n°1 de l'énumération post-exploitation Linux
find / -perm -4000 -type f 2>/dev/null
find / -perm -2000 -type f 2>/dev/null
```

```bash
# Fichiers/dossiers accessibles en écriture par tout le monde (faille de configuration)
find / -perm -o+w -type f 2>/dev/null
find / -perm -o+w -type d 2>/dev/null
```

```bash
# Clés SSH privées oubliées sur le système (souvent en dehors de ~/.ssh)
find / -name "id_rsa" -o -name "id_ed25519" -o -name "*.pem" 2>/dev/null
```

```bash
# Fichiers de config potentiellement sensibles (mots de passe, tokens, credentials)
find / \( -name "*.conf" -o -name "*.xml" -o -name "*.env" \) 2>/dev/null | xargs grep -liE "pass|token|secret" 2>/dev/null
```

```bash
# Fichiers modifiés récemment (traces d'intrusion ou de dépôt de payload)
find / -mmin -60 -type f 2>/dev/null
```

```bash
# Fichiers orphelins (propriétaire supprimé), souvent négligés en audit
find / -nouser -o -nogroup 2>/dev/null
```

!!! warning "Risques de `-exec` mal nettoyé"
    Une commande `-exec` construite dynamiquement (ex: variable utilisateur injectée dans le motif ou la commande exécutée) peut ouvrir la porte à une **injection de commande** si le motif de recherche provient d'une entrée non fiable. Ne jamais interpoler une entrée utilisateur brute dans un `-exec` sans validation stricte.

!!! warning "Piège des espaces et caractères spéciaux dans les noms de fichiers"
    Un pipe classique `find ... | xargs cmd` **casse silencieusement** sur des noms de fichiers contenant des espaces, des retours à la ligne ou des apostrophes (chaque espace est interprété comme un séparateur d'arguments). Utilisez systématiquement `find ... -print0 | xargs -0 cmd` dès que les noms de fichiers ne sont pas garantis "propres" — c'est-à-dire presque toujours en contexte réel.

!!! warning "Performance de `\;` vs `+`"
    `-exec cmd {} \;` lance **une nouvelle instance de la commande pour chaque fichier trouvé**, ce qui peut être très lent sur de gros volumes (des milliers d'appels de processus). Préférez `-exec cmd {} +` (regroupe plusieurs fichiers en un seul appel) dès que la commande cible le permet.
