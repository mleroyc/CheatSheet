# 🛠️ Commande : date

## 1. Description rapide (Rôle et cas d'usage)

`date` est l'utilitaire standard permettant d'**afficher**, de **formater**, de **calculer** et de **modifier** la date et l'heure système sous Linux. Il s'appuie sur l'horloge système du noyau et peut restituer l'information dans un format arbitraire grâce à des spécificateurs (`%Y`, `%m`, `%d`, etc.), ou effectuer des calculs relatifs (« il y a 3 jours », « lundi prochain ») via l'option `-d`.

**Principaux cas d'usage :**

- **Horodatage dans les scripts de sauvegarde** : générer des noms de fichiers uniques et triables chronologiquement.
- **Génération de timestamps** : produire des identifiants temporels (Epoch Unix) pour des logs, des bases de données ou des API.
- **Conversion de dates** : passer d'un format lisible à un timestamp Unix et inversement.
- **Calculs de délais** : déterminer des dates passées/futures pour des tâches planifiées, des purges de fichiers ou des rapports périodiques.
- **Débogage de logs** : recouper des horodatages entre systèmes, fuseaux horaires ou formats hétérogènes.

---

## 2. Syntaxe de base

**Affichage / formatage :**

```bash
date [options] [+FORMAT]
```

Le paramètre `+FORMAT` commence obligatoirement par le caractère `+`, suivi d'une chaîne contenant des spécificateurs préfixés par `%` (ex. `date +%Y-%m-%d`).

**Définition de la date système :**

```bash
date [options] MMJJhhmm[[SS]AA][.ss]
```

ou, de façon plus lisible, via l'option dédiée :

```bash
date --set="STRING"
```

Ces deux formes nécessitent des privilèges root et modifient directement l'horloge système du noyau.

---

## 3. Options, fanions et spécificateurs de format principaux

### A. Options principales

| Option | Forme longue | Description |
|---|---|---|
| `-u` | `--utc` / `--universal` | Affiche ou définit la date en temps universel coordonné (UTC), en ignorant le fuseau horaire local. |
| `-d STRING` | `--date=STRING` | Calcule et affiche une date à partir d'une chaîne arbitraire (ex. `"yesterday"`, `"2 weeks"`, `"2024-01-01 12:00"`), sans modifier la date système. |
| `-r FICHIER` | `--reference=FICHIER` | Affiche la date de dernière modification (mtime) du fichier indiqué au lieu de la date courante. |
| `-I[SPEC]` | `--iso-8601[=SPEC]` | Affiche la date au format ISO 8601. `SPEC` peut valoir `date`, `hours`, `minutes`, `seconds` ou `ns` pour ajuster la précision. |
| `-s STRING` | `--set=STRING` | Définit l'heure système à la valeur indiquée par `STRING` (nécessite `sudo`). |

### B. Spécificateurs de format clés

| Spécificateur | Description |
|---|---|
| `%Y` | Année sur 4 chiffres (ex. `2026`). |
| `%m` | Mois sur 2 chiffres (`01` à `12`). |
| `%d` | Jour du mois sur 2 chiffres (`01` à `31`). |
| `%H` | Heure au format 24h (`00` à `23`). |
| `%M` | Minutes (`00` à `59`). |
| `%S` | Secondes (`00` à `60`). |
| `%s` | Timestamp Unix (nombre de secondes depuis le 01/01/1970 00:00:00 UTC — Epoch). |
| `%F` | Date complète au format ISO `AAAA-MM-JJ` (équivalent à `%Y-%m-%d`). |
| `%T` | Heure complète au format `HH:MM:SS` (équivalent à `%H:%M:%S`). |
| `%Z` | Nom du fuseau horaire (ex. `UTC`, `CEST`). |

!!! tip "Astuce mémo"
    `%F` et `%T` sont des raccourcis pratiques : `date +"%F %T"` équivaut à `date +"%Y-%m-%d %H:%M:%S"`, avec moins de risques d'erreur de frappe.

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Horodatage de fichiers de sauvegarde

Génère un suffixe dynamique, trié chronologiquement et sans caractères problématiques (espaces, `:`) :

```bash
tar -czf backup_$(date +%Y%m%d_%H%M%S).tar.gz /var/www
```

### 2. Calcul de dates relatives (arithmétique temporelle)

`date -d` accepte des expressions en langage naturel pour calculer des dates passées ou futures sans modifier l'horloge système :

```bash
date -d "yesterday" +%F        # Date d'hier
date -d "3 days ago" +%F       # Il y a 3 jours
date -d "next Monday" +%F      # Prochain lundi
date -d "$(date +%Y-%m-01)"    # Premier jour du mois courant
```

### 3. Gestion des timestamps Unix

Conversion date → Epoch, et Epoch → date lisible :

```bash
# Date courante convertie en timestamp Unix
date +%s

# Timestamp Unix converti en date lisible (le @ est obligatoire)
date -d @1700000000 +"%F %T"
```

### 4. Changement de fuseau horaire à la volée

La variable d'environnement `TZ` permet d'afficher l'heure d'un autre fuseau **sans modifier** la configuration système :

```bash
TZ="America/New_York" date
TZ="Asia/Tokyo" date +"%F %T %Z"
```

### 5. Mesure de temps d'exécution dans un script

Capture des timestamps avant/après un traitement pour calculer une durée précise en secondes :

```bash
#!/bin/bash
debut=$(date +%s)

# --- traitement long ---
sleep 5

fin=$(date +%s)
duree=$((fin - debut))
echo "Durée d'exécution : ${duree} secondes"
```

### 6. Modification de l'heure système

Définit manuellement la date et l'heure système (nécessite les droits root) :

```bash
sudo date --set="2026-09-02 14:30:00"
```

!!! danger "Avertissement"
    Cette commande modifie directement l'horloge système. Sur une machine synchronisée par NTP/`systemd-timesyncd`, ce changement est **temporaire** et sera écrasé à la prochaine resynchronisation — voir la section [Pièges à éviter](#5-astuces-pieges-a-eviter) ci-dessous.

---

## 5. Astuces & Pièges à éviter

!!! warning "Confusion entre UTC et Heure Locale"
    Mélanger heure locale et UTC est une source fréquente d'erreurs lors de l'analyse de logs distribués sur plusieurs serveurs ou fuseaux horaires. Deux événements horodatés en heure locale sur des machines à fuseaux différents peuvent sembler décalés alors qu'ils sont simultanés.

    **Bonne pratique :** standardiser tous les horodatages de logs en UTC avec `-u` :

    ```bash
    date -u +"%F %T %Z"
    ```

!!! danger "Incompatibilités entre `date` GNU (Linux) et `date` BSD (macOS)"
    La version GNU de `date` (Linux) et la version BSD (macOS, `*BSD`) ont des syntaxes **incompatibles** pour le calcul de dates arbitraires :

    ```bash
    # GNU (Linux) — utilise -d
    date -d "2024-01-01" +%s

    # BSD (macOS) — utilise -j -f pour parser une date puis -v pour les calculs relatifs
    date -j -f "%Y-%m-%d" "2024-01-01" +%s
    date -v-1d +%F   # équivalent BSD de "yesterday"
    ```

    Un script utilisant `date -d` échouera silencieusement ou renverra une erreur sur macOS. Pour un script portable, prévoir une détection de plateforme ou utiliser `gdate` (GNU `date` installable via `coreutils` sur macOS/Homebrew).

!!! danger "Changement manuel de date vs NTP/systemd-timesyncd"
    Modifier l'heure système à la main (`date -s` ou `date --set`) sur une machine dont l'horloge est gérée par NTP ou `systemd-timesyncd` est une opération **temporaire et risquée** :

    - Le service de synchronisation réécrasera la valeur manuelle au prochain cycle de synchronisation.
    - Un décalage brutal de l'horloge peut corrompre des bases de données sensibles au temps (index, transactions, réplication), invalider des certificats TLS, ou fausser des jobs planifiés (`cron`, `systemd timers`).

    !!! tip "Bonne pratique"
        Pour ajuster durablement l'heure système, désactiver temporairement la synchronisation avant modification, ou — mieux — corriger la configuration NTP elle-même plutôt que l'horloge :

        ```bash
        sudo timedatectl set-ntp false   # désactive la synchro avant modification manuelle
        sudo date --set="2026-09-02 14:30:00"
        sudo timedatectl set-ntp true    # réactive la synchronisation NTP
        ```
