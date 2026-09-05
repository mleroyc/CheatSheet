# 🛠️ kill — Envoi de signaux aux processus

## 1. Description rapide

`kill` envoie un **signal** à un processus identifié par son PID. Par défaut (sans option), il envoie `SIGTERM` (15), qui demande au processus de s'arrêter proprement. Ce n'est pas un outil de destruction mais un mécanisme de **communication inter-processus**.

**Cas d'usage :** arrêt propre d'un service, rechargement de configuration sans interruption (`SIGHUP`), arrêt forcé d'un processus gelé (`SIGKILL`), suspension et reprise d'un processus.

---

## 2. Syntaxe de base

```bash
kill <PID>               # Envoie SIGTERM (15) — arrêt propre
kill -<N> <PID>          # Envoie le signal numéro N
kill -<NOM> <PID>        # Envoie le signal par nom (ex : kill -SIGTERM 1234)
kill -l                  # Liste tous les signaux disponibles avec leurs numéros
```

---

## 3. Options et fanions principaux

### Signaux fondamentaux

| Signal | Numéro | Interceptable | Comportement | Cas d'usage typique |
|---|---|---|---|---|
| `SIGHUP` | 1 | Oui | Raccroche le terminal — ou recharge la config si intercepté | `kill -1 $(pgrep nginx)` pour recharger nginx |
| `SIGINT` | 2 | Oui | Interruption clavier — équivalent `Ctrl+C` | Arrêt interactif d'une commande |
| `SIGQUIT` | 3 | Oui | Quitte avec génération d'un core dump | Débogage, trace mémoire |
| `SIGTERM` | 15 | Oui | Demande d'arrêt propre — le processus peut nettoyer | Arrêt standard de tout daemon |
| `SIGKILL` | 9 | **Non** | Arrêt forcé immédiat par le noyau | Processus gelé refusant SIGTERM |
| `SIGSTOP` | 19 | **Non** | Suspend le processus (non interceptable) | Geler un processus |
| `SIGCONT` | 18 | Oui | Reprend un processus suspendu | Continuer après SIGSTOP |
| `SIGUSR1` | 10 | Oui | Signal applicatif personnalisé | Rotation de logs (ex : logrotate → nginx) |
| `SIGUSR2` | 12 | Oui | Signal applicatif personnalisé | Fonctions définies par l'application |

### Formes d'envoi

```bash
kill -15 1234        # Par numéro
kill -TERM 1234      # Par nom court
kill -SIGTERM 1234   # Par nom complet
```

---

## 4. Exemples pratiques

```bash
# Arrêt propre d'un processus (SIGTERM — toujours essayer en premier)
kill 4567

# Arrêt forcé si SIGTERM ignoré (SIGKILL — en dernier recours)
kill -9 4567

# Recharger la configuration de nginx sans interrompre le service
kill -1 $(pgrep -f "nginx: master")
# Ou :
kill -SIGHUP $(cat /run/nginx.pid)

# Séquence recommandée : tenter propre, attendre, forcer si nécessaire
kill -15 4567 && sleep 5 && kill -9 4567
# Note : kill -9 retournera une erreur si le processus s'est déjà arrêté, ce qui est normal

# Suspendre temporairement un processus (ex : limiter temporairement un scan)
kill -STOP $(pgrep nmap)

# Reprendre le processus suspendu
kill -CONT $(pgrep nmap)

# Lister tous les signaux disponibles
kill -l
```

---

## 5. Astuces & Pièges à éviter

!!! warning "SIGKILL ne permet aucun nettoyage"
    `kill -9` est traité **directement par le noyau** — le processus n'a aucune chance de libérer ses ressources. Conséquences possibles : fichiers temporaires non supprimés, verrous non relâchés, transactions base de données non terminées, données en buffer non écrites sur disque. **Toujours tenter SIGTERM d'abord.**

!!! warning "SIGKILL et SIGSTOP sont non interceptables"
    Un programme peut définir des gestionnaires personnalisés (*signal handlers*) pour intercepter et surcharger la majorité des signaux. SIGKILL (9) et SIGSTOP (19) font exception : ils sont **toujours traités par le noyau**, quoi que le programme ait défini.

!!! warning "kill -9 sur un processus en état D est inefficace"
    Un processus en état `D` (*Uninterruptible Sleep*, attente I/O) **ne peut pas recevoir de signaux** tant qu'il n'est pas sorti de l'attente. Même `SIGKILL` est mis en file d'attente. La solution est de résoudre le problème I/O sous-jacent (disque, NFS...).

!!! tip "Trouver le PID avant de killer"
    ```bash
    # Méthodes pour obtenir le PID d'un processus
    pgrep nginx                   # PIDs par nom de processus
    pidof nginx                   # PIDs par nom exact d'exécutable
    cat /run/nginx.pid            # Fichier PID si le service en génère un
    ps aux | grep nginx           # Méthode manuelle avec filtrage
    ```

!!! tip "Réassembler une séquence de kill robuste en script"
    ```bash
    PID=4567
    kill -15 $PID 2>/dev/null
    for i in $(seq 1 10); do
      kill -0 $PID 2>/dev/null || break   # kill -0 teste l'existence du processus sans signal
      sleep 1
    done
    kill -0 $PID 2>/dev/null && kill -9 $PID
    # Force uniquement si le processus est encore là après 10 secondes
    ```
