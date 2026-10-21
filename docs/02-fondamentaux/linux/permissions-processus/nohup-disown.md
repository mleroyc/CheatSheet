# 🛠️ nohup & disown — Persistance des processus hors session TTY

## 1. Description rapide

Par défaut, la fermeture d'un terminal (ou d'une session SSH) envoie `SIGHUP` à tous les processus enfants du shell — ils sont tués. `nohup` et `disown` sont deux mécanismes complémentaires pour **immuniser un processus contre SIGHUP** et lui permettre de survivre à la fermeture de la session.

- **`nohup`** : se place **avant** la commande au lancement — protège dès le départ.
- **`disown`** : s'applique **après** le lancement — détache un job déjà en cours du shell.

**Cas d'usage :** scans réseau long cours (Nmap, ffuf), scripts de déploiement via SSH, serveurs de test lancés manuellement, transferts de fichiers volumineux.

---

## 2. Syntaxe de base

```bash
nohup <commande> &                       # Lance et protège contre SIGHUP, stdout → nohup.out
nohup <commande> > fichier.log 2>&1 &   # Avec redirection explicite des sorties

disown %<N>                              # Détache le job N de la liste des jobs du shell
disown -h %<N>                           # Marque le job comme insensible à SIGHUP sans le retirer de jobs
disown -a                                # Détache tous les jobs en arrière-plan
```

---

## 3. Options et fanions principaux

### `nohup`

| Comportement | Détail |
|---|---|
| Sortie standard (stdout) | Redirigée vers `./nohup.out` si non redirigée explicitement |
| Sortie d'erreur (stderr) | Redirigée vers stdout par défaut (donc aussi dans `nohup.out`) |
| Signal ignoré | `SIGHUP` uniquement — les autres signaux fonctionnent normalement |
| Fichier de sortie | `./nohup.out` si accessible, sinon `~/nohup.out` |

### `disown`

| Option | Signification |
|---|---|
| `%N` | Référence le job numéro N |
| `-h` | Marque le job comme insensible à SIGHUP **sans** le retirer de la liste `jobs` |
| `-a` | Applique à **tous** les jobs en arrière-plan |
| `-r` | Applique uniquement aux jobs en état **running** |

### Comparatif `nohup` vs `disown`

| Critère | `nohup` | `disown` |
|---|---|---|
| Moment d'utilisation | Avant le lancement | Après le lancement |
| Redirection stdout | Automatique (nohup.out) | Aucune (la sortie existante est conservée) |
| Reste visible dans `jobs` | Oui (jusqu'à fermeture) | Non (retiré de la liste) sauf avec `-h` |
| Protection contre SIGHUP | Oui | Oui |
| Persistance après reboot | Non | Non |

---

## 4. Exemples pratiques

```bash
# Lancer un scan Nmap complet qui survit à la déconnexion SSH
nohup nmap -sV -p- 192.168.1.0/24 -oA scan_complet > nmap.log 2>&1 &
echo "PID du scan : $!"   # Noter le PID pour suivi ultérieur

# Script de déploiement long via SSH — survivra à la coupure
nohup ./deploy.sh > deploy_$(date +%Y%m%d_%H%M).log 2>&1 &

# Fuzzing de répertoires en arrière-plan persistant
nohup ffuf -w /usr/share/wordlists/dirb/big.txt \
  -u http://cible.com/FUZZ \
  -o ffuf_results.json > ffuf.log 2>&1 &

# Workflow : oubli du nohup au départ → rattraper avec disown
nmap -sV 192.168.1.1     # Lancé sans &, puis Ctrl+Z pour suspendre
bg %1                     # Passe en arrière-plan
disown %1                 # Détache du shell — survit à la fermeture du terminal

# Vérifier qu'un processus tourne encore après reconnexion SSH
ssh user@serveur
ps aux | grep nmap        # Le processus est toujours là malgré la déconnexion
tail -f nmap.log          # Suivre l'avancement en temps réel

# Serveur Python de partage de fichiers persistant
nohup python3 -m http.server 8080 > http_server.log 2>&1 &
```

---

## 5. Astuces & Pièges à éviter

!!! warning "nohup.out peut grossir sans limite"
    Si `nohup` est utilisé sans redirection explicite, tout stdout va dans `nohup.out`. Un processus verbeux peut remplir le disque silencieusement. **Toujours rediriger explicitement** :
    ```bash
    nohup ./script.sh > /var/log/script.log 2>&1 &
    # Ou supprimer complètement la sortie si inutile :
    nohup ./script.sh > /dev/null 2>&1 &
    ```

!!! warning "nohup ne garantit pas la persistance après reboot"
    `nohup` protège uniquement contre `SIGHUP` lors de la fermeture du terminal. Un **redémarrage système** tue quand même le processus. Pour une vraie persistance multi-reboot, utiliser une **unité systemd** ou un job `cron @reboot`.

!!! tip "Suivre un processus nohup après reconnexion"
    ```bash
    # Lors du lancement, noter le PID
    nohup long_script.sh > script.log 2>&1 &
    echo $! > /tmp/script.pid    # Sauvegarde le PID dans un fichier

    # Après reconnexion
    cat /tmp/script.pid           # Retrouve le PID
    ps -p $(cat /tmp/script.pid)  # Vérifie s'il tourne toujours
    tail -f script.log            # Suit l'avancement en live
    ```

!!! tip "Disown sans -h retire le job de jobs"
    `disown %1` retire le job de la liste `jobs` — il ne sera plus visible mais tourne toujours. `disown -h %1` conserve le job dans la liste `jobs` tout en le rendant insensible à SIGHUP — utile si on veut encore interagir avec via `fg` avant de fermer le terminal.

!!! tip "Alternative moderne : screen ou tmux"
    `nohup` et `disown` sont des solutions légères. Pour une gestion complète de sessions persistantes avec possibilité de se **rattacher** à une session existante, `tmux` ou `screen` sont supérieurs :
    ```bash
    tmux new -s scan           # Nouvelle session nommée
    nmap -sV -p- 192.168.1.1  # Lancer le scan
    Ctrl+B puis D              # Détacher la session (processus continue)
    tmux attach -t scan        # Se rattacher depuis n'importe quelle connexion
    ```
