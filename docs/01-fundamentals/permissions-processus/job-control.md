# 🛠️ Job Control — Gestion des tâches dans le shell

## 1. Description rapide

Le **Job Control** est la capacité du shell à gérer plusieurs processus depuis un seul terminal : lancer des commandes en arrière-plan, les suspendre, les reprendre, et basculer entre premier plan et arrière-plan.

**Cas d'usage :** lancer un scan en arrière-plan pendant qu'on travaille sur autre chose, suspendre temporairement une commande, gérer plusieurs tâches longues dans une même session SSH sans multiplexeur.

---

## 2. Syntaxe de base

```bash
commande &             # Lance une commande directement en arrière-plan
Ctrl+Z                 # Suspend la commande en cours d'exécution au premier plan
bg [%job]              # Reprend un job suspendu en arrière-plan
fg [%job]              # Ramène un job au premier plan
jobs [-l]              # Liste les jobs actifs du shell courant
```

---

## 3. Options et fanions principaux

### Référencement des jobs

| Notation | Signification |
|---|---|
| `%1`, `%2`... | Job par numéro d'identifiant |
| `%%` ou `%+` | Job courant (dernier manipulé) |
| `%-` | Job précédent |
| `%nginx` | Job dont la commande commence par "nginx" |
| `%?log` | Job dont la commande contient "log" |

### Options de `jobs`

| Option | Signification |
|---|---|
| `-l` | Affiche les PIDs en plus des numéros de job |
| `-r` | Affiche uniquement les jobs en cours d'exécution (running) |
| `-s` | Affiche uniquement les jobs suspendus (stopped) |
| `-p` | Affiche uniquement les PIDs des jobs |

### Symboles dans la sortie de `jobs`

| Symbole | Signification |
|---|---|
| `+` | Job courant — cible par défaut de `fg`/`bg` sans argument |
| `-` | Job précédent |
| (aucun) | Autres jobs |

---

## 4. Exemples pratiques

```bash
# Lancer un scan Nmap en arrière-plan immédiatement
nmap -sn 192.168.1.0/24 &
# Affiche : [1] 4729  → [numéro_job] PID

# Lancer un serveur HTTP de partage en arrière-plan
python3 -m http.server 8080 &

# Suspendre une commande en cours (Ctrl+Z) et la reprendre en arrière-plan
nmap -sV 192.168.1.1
# ... quelques secondes ...
^Z
# [1]+  Stopped   nmap -sV 192.168.1.1
bg %1
# [1]+ nmap -sV 192.168.1.1 &

# Lister les jobs avec leurs PIDs
jobs -l
# [1]  4729 Running    nmap -sn 192.168.1.0/24 &
# [2]- 4812 Stopped    vim /etc/nginx/nginx.conf
# [3]+ 4901 Running    python3 -m http.server 8080 &

# Ramener un job au premier plan pour interagir avec lui
fg %1                   # Par numéro de job
fg %nmap                # Par nom (préfixe de la commande)

# Tuer un job directement depuis le shell sans fg
kill %2                 # Envoie SIGTERM au job 2

# Suspendre un processus gourmand temporairement et le reprendre
kill -STOP %1           # Suspend le job 1
kill -CONT %1           # Reprend le job 1
```

### Cycle de vie complet d'un job

```text
commande &          → Running (arrière-plan)
commande            → Running (premier plan)
     ↓ Ctrl+Z
Stopped (suspendu)
     ↓ bg
Running (arrière-plan)
     ↓ fg
Running (premier plan)
     ↓ Ctrl+C
Terminé
```

---

## 5. Astuces & Pièges à éviter

!!! warning "La fermeture du terminal tue tous les jobs"
    Quand un terminal se ferme, le shell envoie `SIGHUP` à tous ses jobs — même ceux en arrière-plan. Ils sont **tous tués**. Pour éviter cela, utiliser `nohup` au lancement ou `disown` après coup (voir fiche `nohup-disown.md`).

!!! tip "Vérifier qu'un job est vraiment en arrière-plan"
    ```bash
    jobs -l
    # Si un job est "Running" mais n'affiche rien en sortie, vérifier qu'il ne attend pas
    # une entrée stdin — un processus attendant stdin est bloqué même en arrière-plan
    nmap -sn 192.168.1.0/24 < /dev/null &
    # Rediriger stdin depuis /dev/null pour éviter tout blocage
    ```

!!! warning "Ctrl+C vs Ctrl+Z"
    - `Ctrl+C` envoie `SIGINT` → **termine** le processus.
    - `Ctrl+Z` envoie `SIGTSTP` → **suspend** le processus (peut être repris).
    Ne pas confondre les deux dans une situation où on voulait juste suspendre.

!!! tip "Jobs limités à la session shell courante"
    `jobs` n'affiche que les jobs du **shell courant**. Un job lancé dans un autre terminal ou un autre shell fils n'apparaîtra pas. Pour voir tous les processus en arrière-plan sur le système, utiliser `ps aux` ou `ss`/`lsof`.

!!! tip "Utiliser les jobs pour un workflow de pentest multi-tâches"
    ```bash
    # Lancer plusieurs scans simultanément sans multiplexeur
    nmap -p- 192.168.1.10 -oA scan_full &           # job 1
    nmap -sV -p 80,443,8080 192.168.1.10 &          # job 2
    gobuster dir -u http://192.168.1.10 -w /usr/share/wordlists/dirb/common.txt &  # job 3

    jobs -l                  # Surveiller l'avancement des trois tâches
    fg %1                    # Passer sur le scan complet si besoin d'interaction
    ```
