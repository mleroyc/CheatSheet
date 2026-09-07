# 🛠️ ps — Inspection des processus

## 1. Description rapide

`ps` (*Process Snapshot*) affiche une liste statique des processus en cours d'exécution au moment de l'appel. Contrairement à `top`, il ne se rafraîchit pas — il produit un instantané.

**Cas d'usage :** audit des processus actifs, recherche d'un processus par nom ou utilisateur, détection de processus suspects (pentest/forensic), vérification qu'un service tourne correctement.

---

## 2. Syntaxe de base

```bash
ps [options]
```

Deux styles de syntaxe coexistent, hérités de deux familles Unix distinctes :

| Style | Exemple | Caractéristique |
|---|---|---|
| **BSD** | `ps aux` | Options **sans** tiret |
| **System V** | `ps -ef` | Options **avec** tiret |
| **GNU/Hybride** | `ps auxf` | Accepte les deux |

```bash
ps aux       # Tous les processus, tous les utilisateurs — style BSD
ps -ef       # Tous les processus, tous les utilisateurs — style System V
ps auxf      # Arborescence ASCII (forest) — style BSD
ps -efH      # Arborescence — style System V
```

---

## 3. Options et fanions principaux

### Style BSD

| Option | Signification |
|---|---|
| `a` | Affiche les processus de tous les utilisateurs (pas uniquement le courant) |
| `u` | Format orienté utilisateur — affiche %CPU, %MEM, RSS, VSZ |
| `x` | Inclut les processus sans terminal de contrôle (daemons) |
| `f` | Affichage en arborescence ASCII (forest) |

### Style System V

| Option | Signification |
|---|---|
| `-e` | Affiche tous les processus du système |
| `-f` | Format complet : UID, PID, PPID, C, STIME, TTY, TIME, CMD |
| `-H` | Arborescence hiérarchique (indentation) |
| `-u <user>` | Filtre sur un utilisateur précis |
| `-p <PID>` | Affiche uniquement un PID précis |
| `-o` | Colonnes personnalisées (ex : `-o pid,ppid,cmd,%cpu`) |

### Colonnes de `ps aux`

| Colonne | Signification |
|---|---|
| `USER` | Propriétaire du processus |
| `PID` | Process ID — identifiant unique |
| `%CPU` | Pourcentage CPU consommé depuis le démarrage du processus |
| `%MEM` | Pourcentage de RAM physique utilisée |
| `VSZ` | Taille mémoire virtuelle allouée (Ko) |
| `RSS` | Resident Set Size — RAM physiquement occupée (Ko) |
| `TTY` | Terminal associé (`?` = daemon sans terminal) |
| `STAT` | État du processus (voir tableau ci-dessous) |
| `START` | Heure ou date de démarrage |
| `TIME` | Temps CPU cumulé consommé |
| `COMMAND` | Commande et arguments |

### Codes d'état (`STAT`)

| Code | Signification |
|---|---|
| `R` | Running — en cours d'exécution |
| `S` | Sleeping — en attente d'un événement |
| `D` | Uninterruptible Sleep — attente I/O bloquante (ne peut pas être killé) |
| `T` | Stopped — suspendu (ex : `Ctrl+Z`) |
| `Z` | Zombie — terminé, en attente de lecture par le parent |
| `+` | Processus au premier plan du terminal |
| `s` | Leader de session |
| `l` | Multi-threadé |
| `N` | Priorité réduite (nice > 0) |

---

## 4. Exemples pratiques

```bash
# Lister tous les processus avec leur consommation CPU/RAM
ps aux

# Lister tous les processus avec leur hiérarchie parent/enfant
ps -efH

# Trier par consommation CPU décroissante, afficher le top 10
ps aux --sort=-%cpu | head -10

# Trier par consommation RAM décroissante
ps aux --sort=-%mem | head -10

# Filtrer les processus d'un utilisateur précis
ps -u www-data
ps aux | grep "^www-data"

# Afficher uniquement les colonnes utiles (PID, PPID, utilisateur, commande, CPU)
ps -eo pid,ppid,user,cmd,%cpu,%mem --sort=-%cpu | head -15

# Rechercher un processus par nom — sans remonter le grep lui-même
ps aux | grep [n]ginx
# Alternative propre :
pgrep -a nginx

# Détecter des processus suspects en pentest/forensic
ps aux | grep -iE "nc|ncat|netcat|python|ruby|perl|php|bash -i"

# Trouver les processus en état Zombie
ps aux | awk '$8 == "Z" { print $0 }'
```

---

## 5. Astuces & Pièges à éviter

!!! tip "Éviter de remonter la commande grep elle-même"
    ```bash
    ps aux | grep nginx          # Remonte aussi la ligne du grep
    ps aux | grep [n]ginx        # Le crochet crée un pattern qui n'est pas dans la liste ps
    pgrep -a nginx               # Solution la plus propre, ne remonte que les vrais processus
    ```

!!! tip "Colonnes personnalisées avec -o"
    ```bash
    ps -eo pid,ppid,user,stat,cmd --sort=pid
    # Affiche uniquement les colonnes choisies, dans l'ordre souhaité
    # Utilisé en script pour extraire précisément les champs nécessaires
    ```

!!! warning "Le %CPU de ps n'est pas instantané"
    La colonne `%CPU` de `ps` affiche la moyenne depuis le **démarrage du processus**, pas la consommation à l'instant T. Pour une mesure instantanée de l'activité CPU, utiliser `top` ou `htop`.

!!! warning "Processus D (Uninterruptible Sleep) ne peut pas être tué"
    Un processus en état `D` attend une opération I/O bloquante (souvent NFS ou disque défaillant). `kill -9` n'a aucun effet sur lui — le signal est bien envoyé mais le processus ne peut pas le traiter tant qu'il n'est pas sorti de l'attente I/O. La solution est de résoudre le problème I/O sous-jacent.

!!! tip "Audit rapide des services exposés (pentest interne)"
    ```bash
    ps aux | grep -v "^\[" | awk '{print $1, $11}' | sort -u
    # Liste chaque utilisateur avec ses binaires en cours d'exécution
    # Révèle les services tournant sous des comptes inattendus
    ```
