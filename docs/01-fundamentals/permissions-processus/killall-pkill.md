# 🛠️ killall & pkill — Arrêt de processus par nom ou critères

## 1. Description rapide

Là où `kill` cible un processus par son PID, `killall` et `pkill` permettent de cibler des processus par **nom** ou **critères** (utilisateur, expression régulière, ligne de commande complète), sans avoir à retrouver les PIDs au préalable.

- **`killall`** : cible les processus dont le **nom correspond exactement** à la chaîne fournie.
- **`pkill`** : cible par **motif d'expression régulière** (partiel), avec options de filtrage avancées (utilisateur, groupe, terminal...).
- **`pgrep`** : jumeau de `pkill`, retourne les PIDs correspondants **sans envoyer de signal** — utile pour valider la sélection avant de killer.

---

## 2. Syntaxe de base

```bash
killall <nom>              # Envoie SIGTERM à tous les processus nommés exactement <nom>
killall -<signal> <nom>    # Envoie un signal précis

pkill <motif>              # Envoie SIGTERM aux processus dont le nom contient <motif>
pkill -<signal> <motif>    # Envoie un signal précis
pkill -f <motif>           # Recherche sur la ligne de commande complète (pas uniquement le nom)

pgrep <motif>              # Affiche les PIDs correspondants (sans envoyer de signal)
pgrep -l <motif>           # PID + nom du processus
pgrep -a <motif>           # PID + ligne de commande complète
```

---

## 3. Options et fanions principaux

### `killall`

| Option | Signification |
|---|---|
| `-9` ou `-SIGKILL` | Envoie SIGKILL au lieu de SIGTERM |
| `-1` ou `-SIGHUP` | Envoie SIGHUP (rechargement de config) |
| `-u <user>` | Limite aux processus appartenant à cet utilisateur |
| `-v` | Verbose — affiche les PIDs tués |
| `-i` | Interactif — demande confirmation pour chaque PID |
| `-r` | Interprète le nom comme une expression régulière |
| `-s <signal>` | Spécifie le signal à envoyer |
| `-w` | Attend que tous les processus tués soient terminés |

### `pkill`

| Option | Signification |
|---|---|
| `-9` ou `-SIGKILL` | Envoie SIGKILL |
| `-f` | Recherche sur la ligne de commande complète (args inclus) |
| `-u <user>` | Limite aux processus de l'utilisateur spécifié |
| `-U <UID>` | Limite par UID numérique |
| `-g <groupe>` | Limite par groupe de processus (PGID) |
| `-t <tty>` | Limite aux processus du terminal spécifié |
| `-e` | Verbose — affiche le nom et PID de chaque processus tué |
| `-l` | Affiche le nom du signal et les noms des processus |
| `-x` | Correspondance exacte du nom (comme killall sans -r) |
| `-n` | Cible uniquement le processus le plus récent |
| `-o` | Cible uniquement le processus le plus ancien |

### Comparatif des trois outils

| Critère | `killall` | `pkill` | `pgrep` |
|---|---|---|---|
| Sélection | Nom exact | Motif regex (partiel) | Motif regex (partiel) |
| Action | Envoie signal | Envoie signal | Affiche PIDs uniquement |
| Filtre utilisateur | `-u` | `-u` | `-u` |
| Ligne de commande complète | Non | `-f` | `-f` |
| Confirmation interactive | `-i` | Non | — |
| Attendre la fin | `-w` | Non | — |

---

## 4. Exemples pratiques

```bash
# Recharger nginx (SIGHUP) — tous les workers en une commande
killall -1 nginx
pkill -HUP nginx

# Tuer tous les processus Python3 de l'utilisateur courant
killall python3
pkill python3

# Tuer uniquement les processus Python3 appartenant à un utilisateur spécifique
pkill -u deploy python3
killall -u deploy python3

# Tuer un processus identifié par sa ligne de commande complète (args inclus)
pkill -f "python3 /opt/scripts/crawler.py"
# killall ne peut pas faire cela nativement

# Valider la sélection avant de tuer (workflow sécurisé)
pgrep -a nginx              # Vérifie quels PIDs seront ciblés
pkill nginx                 # Envoie le signal seulement si la liste semble correcte

# Tuer le processus zombie ou le plus ancien processus d'un groupe
pkill -o python3            # Cible le plus ancien (oldest)
pkill -n python3            # Cible le plus récent (newest)

# Tuer tous les processus d'un terminal donné (ex : pts/1)
pkill -t pts/1
```

---

## 5. Astuces & Pièges à éviter

!!! warning "killall sous Solaris/BSD"
    Sur certains systèmes non-Linux (Solaris notamment), `killall` **sans argument** tue **tous les processus du système**. Ce comportement n'existe pas sur Linux, mais connaître le contexte d'exécution est essentiel si des scripts sont partagés entre OS.

!!! tip "Toujours valider avec pgrep avant pkill"
    ```bash
    pgrep -a python          # Affiche ce qui sera ciblé
    pkill python             # Execute seulement si la liste est correcte
    ```
    `pkill` effectue une correspondance **partielle** par défaut : `pkill python` peut tuer `python2`, `python3`, et tout processus dont le nom contient "python". Utiliser `-x` pour une correspondance exacte si nécessaire.

!!! warning "pkill -f peut cibler trop largement"
    `-f` recherche dans **toute la ligne de commande**, y compris les arguments. Une chaîne trop courte comme `pkill -f python` pourrait correspondre à des scripts légitimes inattendus. Être aussi précis que possible dans le motif.
    ```bash
    pkill -f "/opt/scripts/malicious_script.py"   # Précis et sûr
    pkill -f "python"                              # Dangereux — trop large
    ```

!!! tip "Simulation avec pgrep -l avant un killall -u"
    ```bash
    pgrep -lu www-data        # Liste TOUS les processus de www-data avant de les killer
    pkill -e -u www-data      # -e affiche ce qui est tué, utile pour auditer l'action
    ```

!!! tip "Attendre que les processus soient bien terminés"
    ```bash
    killall -w nginx          # -w bloque jusqu'à ce que tous les processus soient morts
    # Utile dans un script de déploiement : garantit que nginx est arrêté avant de relancer
    ```
