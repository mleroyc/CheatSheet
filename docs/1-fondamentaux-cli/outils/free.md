# 🛠️ free — Surveillance de la mémoire RAM et du Swap

## 1. Description rapide

`free` affiche l'état de la **mémoire RAM physique** et du **Swap** (mémoire virtuelle sur disque). Il lit les informations depuis `/proc/meminfo` et les présente de façon synthétique.

**Cas d'usage :** vérifier la disponibilité mémoire avant un déploiement, diagnostiquer un système qui swapped massivement, comprendre l'utilisation du cache noyau, détecter une fuite mémoire progressive.

---

## 2. Syntaxe de base

```bash
free                        # Affichage en kilo-octets (défaut)
free -h                     # Format lisible (Mo, Go)
free -m                     # Valeurs en méga-octets
free -s 2                   # Rafraîchissement toutes les 2 secondes
free -s 1 -c 10             # 10 itérations à intervalle de 1 seconde puis arrêt
```

---

## 3. Options et fanions principaux

| Option | Signification |
|---|---|
| `-h` | Human-readable : Ko, Mo, Go, To |
| `-b` | Valeurs en octets |
| `-k` | Valeurs en kilo-octets (défaut) |
| `-m` | Valeurs en méga-octets |
| `-g` | Valeurs en giga-octets |
| `-s <sec>` | Rafraîchissement automatique toutes les `<sec>` secondes |
| `-c <n>` | Nombre d'itérations avant arrêt (combiné avec `-s`) |
| `-t` | Ajoute une ligne de total RAM + Swap combinés |
| `-w` | Wide output — sépare `buffers` et `cache` en deux colonnes distinctes |
| `--si` | Utilise les puissances de 10 (1 Mo = 1 000 000 octets) au lieu de 2^20 |

### Signification des colonnes

```text
              total        used        free      shared  buff/cache   available
Mem:           7.7G        4.4G        1.2G        245M        2.1G        2.9G
Swap:          2.0G        293M        1.7G
```

| Colonne | Signification |
|---|---|
| `total` | RAM physique totale installée |
| `used` | RAM occupée par les processus (hors buff/cache) |
| `free` | RAM non utilisée du tout — vraiment libre |
| `shared` | RAM partagée entre processus (tmpfs, shared memory IPC) |
| `buff/cache` | Cache disque noyau (buffers + page cache) — **libérable à la demande** |
| `available` | RAM réellement disponible pour de nouveaux processus = `free` + partie récupérable de `buff/cache` |

---

## 4. Exemples pratiques

```bash
# Affichage standard lisible
free -h

# Affichage en Mo — pratique pour calculs manuels ou scripts
free -m

# Surveillance continue toutes les 2 secondes — détecter une fuite mémoire progressive
free -h -s 2

# 10 itérations à 1 seconde — capture rapide d'une tendance
free -h -s 1 -c 10

# Ajouter la ligne de total RAM + Swap combinés
free -ht

# Séparer buffers et cache en colonnes distinctes
free -hw

# Calculer le % de RAM vraiment disponible en script
AVAIL=$(free -m | awk '/^Mem:/ {print $7}')
TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
PERCENT=$(( 100 * AVAIL / TOTAL ))
echo "RAM disponible : ${PERCENT}% (${AVAIL} Mo sur ${TOTAL} Mo)"

# Alerte si RAM disponible < 10%
free -m | awk '/^Mem:/ {
  total=$2; avail=$7; pct=100*avail/total
  if (pct < 10) print "⚠️ RAM critique : " pct "% disponible"
}'

# Vérifier l'état du Swap uniquement
free -h | grep Swap
```

---

## 5. Astuces & Pièges à éviter

!!! warning "La colonne 'free' seule est trompeuse"
    Linux utilise **agressivement la RAM libre comme cache disque** pour accélérer les accès. La colonne `free` peut être quasi nulle sur un système parfaitement sain — ce n'est pas du tout un problème. **La colonne à surveiller est `available`** : elle représente la mémoire réellement exploitable par un nouveau processus.

!!! tip "Règle de lecture rapide"
    ```
    RAM disponible = colonne "available"
    RAM consommée par les applis = colonne "used"
    RAM cache noyau (récupérable) = colonne "buff/cache"
    ```
    Si `available` est proche de zéro ET `buff/cache` est faible → **vrai manque de RAM**.
    Si `available` est proche de zéro mais `buff/cache` est élevé → le noyau utilisera ce cache, pas de problème.

!!! warning "Swap élevé = signal d'alerte sérieux"
    Un `used` élevé sur la ligne Swap indique que le système pagine des données sur disque faute de RAM suffisante. Les performances s'effondrent (accès disque vs RAM : facteur 100 à 1000). Un Swap à 100% précède l'activation du **OOM Killer** (Out Of Memory Killer), qui termine des processus arbitrairement pour libérer de la RAM.

!!! tip "Forcer la libération du cache noyau (test uniquement)"
    ```bash
    sync                           # Vide les buffers en attente d'écriture vers le disque
    echo 3 > /proc/sys/vm/drop_caches   # Libère pagecache + dentries + inodes
    # ⚠️ Uniquement en test/benchmark — sur un serveur en production, cela dégrade
    # temporairement les performances car le cache doit être reconstruit
    ```

!!! tip "Identifier un processus en fuite mémoire"
    ```bash
    # Surveiller l'évolution RSS d'un processus dans le temps
    while true; do
      ps -p <PID> -o pid,rss,%mem --no-headers
      sleep 5
    done
    # Si RSS augmente indéfiniment → fuite mémoire probable
    ```

!!! tip "Compléter free avec /proc/meminfo pour le détail complet"
    ```bash
    cat /proc/meminfo
    # Affiche le détail exhaustif : Dirty, Writeback, AnonPages, Mapped, Slab...
    # free est un résumé de /proc/meminfo — pour le diagnostic fin, lire la source
    grep -E "MemAvailable|MemFree|SwapUsed|Cached|Dirty" /proc/meminfo
    ```
