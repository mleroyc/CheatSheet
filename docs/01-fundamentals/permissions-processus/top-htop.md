# 🛠️ top & htop — Surveillance dynamique en temps réel

## 1. Description rapide

`top` et `htop` affichent une vue **dynamique et rafraîchie** des processus actifs et des métriques système globales. Contrairement à `ps`, l'affichage se met à jour automatiquement.

- **`top`** : présent sur tous les systèmes Unix/Linux, aucune installation requise.
- **`htop`** : version enrichie avec affichage coloré, barres de progression, navigation souris et manipulation plus intuitive.

**Cas d'usage :** diagnostic de charge CPU/RAM en temps réel, identification d'un processus gourmand, kill depuis l'interface, surveillance continue d'un serveur.

---

## 2. Syntaxe de base

```bash
top                        # Lance l'interface interactive
top -d 2                   # Rafraîchissement toutes les 2 secondes (défaut : 3s)
top -u www-data            # Filtre sur un utilisateur dès le démarrage
top -p 1234,5678           # Surveille uniquement ces PIDs
top -b -n 5 > rapport.txt  # Mode batch : 5 itérations, sortie dans un fichier

htop                       # Lance htop (apt install htop / yum install htop)
htop -u www-data           # Filtre sur un utilisateur
htop -p 1234               # Surveille un PID précis
```

---

## 3. Options et fanions principaux

### Options de lancement `top`

| Option | Signification |
|---|---|
| `-d <sec>` | Intervalle de rafraîchissement en secondes |
| `-u <user>` | Filtre sur un utilisateur au démarrage |
| `-p <PID>` | Surveille uniquement le(s) PID(s) indiqué(s) |
| `-b` | Mode batch (non interactif) — pour scripts et logs |
| `-n <n>` | Nombre d'itérations avant arrêt automatique |
| `-H` | Affiche les threads individuellement dès le démarrage |
| `-i` | Masque les processus inactifs (idle) |

### Raccourcis clavier interactifs — `top`

| Touche | Action |
|---|---|
| `P` | Trie par consommation CPU (défaut) |
| `M` | Trie par consommation mémoire |
| `T` | Trie par temps CPU cumulé |
| `N` | Trie par PID |
| `R` | Inverse l'ordre de tri |
| `u` | Filtre par utilisateur (saisir le nom) |
| `k` | Envoie un signal à un PID (saisir PID puis signal) |
| `r` | Change la priorité nice d'un processus |
| `1` | Affiche les stats de chaque cœur CPU individuellement |
| `H` | Bascule entre threads et processus |
| `c` | Affiche la ligne de commande complète |
| `i` | Masque/affiche les processus idle |
| `d` | Modifie l'intervalle de rafraîchissement |
| `Shift+W` | Sauvegarde la configuration dans `~/.toprc` |
| `q` | Quitte |

### Raccourcis clavier interactifs — `htop`

| Touche | Action |
|---|---|
| `F2` | Configuration (colonnes, couleurs, options) |
| `F3` ou `/` | Recherche incrémentale par nom |
| `F4` | Filtre permanent (affiche uniquement les correspondances) |
| `F5` | Vue arborescente parent/enfant |
| `F6` | Changer le critère de tri |
| `F9` | Menu d'envoi de signal au processus sélectionné |
| `F10` ou `q` | Quitter |
| `Espace` | Sélectionne/désélectionne (multi-sélection) |
| `u` | Filtre par utilisateur |
| `k` | Envoie un signal |
| `t` | Bascule la vue arborescente |
| `H` | Masque/affiche les threads utilisateurs |
| `K` | Masque/affiche les threads kernel |

---

## 4. Exemples pratiques

```bash
# Lancer top et trier immédiatement par consommation mémoire
top
# puis appuyer sur M dans l'interface

# Surveiller un service précis par PID
top -p $(pgrep nginx | tr '\n' ',' | sed 's/,$//')

# Capturer un snapshot du système toutes les 5s pendant 1 minute (12 itérations)
top -b -d 5 -n 12 > /tmp/top_snapshot_$(date +%Y%m%d_%H%M).txt

# Surveiller uniquement les processus d'un utilisateur
top -u postgres

# htop : lancer avec vue arborescente et filtre sur un utilisateur
htop -u www-data
# puis F5 pour basculer en vue arborescente si pas déjà activée

# Identifier le processus le plus gourmand puis le tuer depuis top
# Dans l'interface top : appuyer sur k, entrer le PID, entrer 15 (SIGTERM)
```

### Lire l'en-tête `top`

```text
top - 14:32:01 up 5 days, 3:12,  2 users,  load average: 0.42, 0.38, 0.31
Tasks: 213 total,   1 running, 212 sleeping,   0 stopped,   0 zombie
%Cpu(s):  3.2 us,  1.1 sy,  0.0 ni, 95.2 id,  0.3 wa,  0.0 hi,  0.2 si
MiB Mem :   7842.5 total,   1203.2 free,   4512.0 used,   2127.3 buff/cache
MiB Swap:   2048.0 total,   1748.0 free,    300.0 used.   3015.1 avail Mem
```

| Métrique CPU | Signification |
|---|---|
| `us` | User space — processus utilisateurs |
| `sy` | Kernel/System — appels système |
| `ni` | Nice — processus à priorité modifiée |
| `id` | Idle — CPU inoccupé |
| `wa` | I/O Wait — CPU attendant une opération disque/réseau |
| `hi` | Hardware IRQ — interruptions matérielles |
| `si` | Software IRQ — interruptions logicielles |

| Load average | Signification |
|---|---|
| Valeur 1 | Charge moyenne sur la dernière minute |
| Valeur 2 | Charge moyenne sur les 5 dernières minutes |
| Valeur 3 | Charge moyenne sur les 15 dernières minutes |

---

## 5. Astuces & Pièges à éviter

!!! tip "Interpréter le Load Average"
    Un load average est sain s'il est **inférieur ou égal au nombre de cœurs CPU**. Un load de `4.0` sur un système 4 cœurs = saturation totale. Un load de `4.0` sur un système 16 cœurs = aucun problème. Vérifier le nombre de cœurs : `nproc` ou `lscpu | grep "CPU(s):"`.

!!! tip "Capturer un rapport top en mode batch"
    ```bash
    top -b -n 1 | head -30
    # Affiche un snapshot instantané sans ouvrir l'interface interactive
    # Idéal pour intégrer dans un script de monitoring ou un rapport d'audit
    ```

!!! warning "Le tri par CPU dans top peut être trompeur"
    Le `%CPU` affiché par `top` est calculé depuis le **dernier rafraîchissement**, pas depuis le démarrage du processus (contrairement à `ps`). Un processus peut apparaître à 100% CPU brièvement lors d'un pic, puis revenir à 0%.

!!! warning "wa (I/O Wait) élevé ≠ problème CPU"
    Un `wa` élevé (> 20-30%) indique que le CPU attend des opérations disque ou réseau. La cause est I/O (disque lent, NFS saturé, base de données), pas le CPU lui-même. Investiguer avec `iotop` ou `iostat`.

!!! tip "Sauvegarder la configuration htop"
    La configuration de `htop` (colonnes, couleurs, tri) est sauvegardée dans `~/.config/htop/htoprc`. Elle peut être copiée d'un système à l'autre pour retrouver instantanément sa configuration personnalisée.
