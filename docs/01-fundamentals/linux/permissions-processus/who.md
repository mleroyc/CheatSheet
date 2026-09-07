# 🛠️ Commande : who

## 1. Description rapide

`who` affiche les **sessions utilisateurs actuellement connectées** au système : nom d'utilisateur, terminal (TTY/PTS), heure de connexion et hôte source. Outil de base pour la surveillance des accès, la détection de sessions suspectes et l'audit d'un système après compromission. À compléter avec `w` pour une vue enrichie incluant la charge système et les processus actifs.

---

## 2. Syntaxe de base

```bash
who [options] [fichier]
```

Sans argument : lit `/var/run/utmp` (sessions actives en temps réel).  
Avec un fichier (ex: `/var/log/wtmp`) : historique des connexions passées.

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `-a` | Affiche toutes les informations disponibles (boot, dead procs, clock...) |
| `-b` | Date et heure du **dernier démarrage** du système |
| `-H` | Affiche les en-têtes de colonnes |
| `-q` | Affiche uniquement les noms d'utilisateurs et le nombre de sessions |
| `-u` | Affiche l'inactivité (idle time) de chaque session |
| `-T` | Affiche l'état du terminal (`+` = écriture autorisée, `-` = interdite, `?` = inconnu) |
| `--lookup` | Résout les noms d'hôtes des connexions distantes |
| `am i` | Affiche uniquement la session de l'utilisateur qui exécute la commande |

---

## 4. Exemples pratiques & Cas d'usage

```bash
# Voir toutes les sessions actives avec en-têtes
who -H
# NAME     LINE         TIME             COMMENT
# alice    pts/0        2024-01-15 09:32 (192.168.1.50)
# root     tty1         2024-01-15 08:10
```

```bash
# Connaître la date du dernier démarrage du système
who -b
# system boot  2024-01-15 08:05
```

```bash
# Détecter des connexions simultanées suspectes (sessions multiples d'un même compte)
who | awk '{print $1}' | sort | uniq -c | sort -nr
# Un compte avec plusieurs sessions peut indiquer un accès non autorisé
```

```bash
# Identifier sa propre session TTY/PTS (utile pour identifier son terminal)
who am i
# alice    pts/1        2024-01-15 10:15 (192.168.1.50)
```

```bash
# Lister les sessions avec le temps d'inactivité (idle) pour détecter les sessions abandonnées
who -uH
# → Sessions avec "." dans IDLE = actives récemment
# → Sessions avec "old" = inactives depuis plus de 24h
```

```bash
# Comparer who et w pour une vue système complète
who    # sessions + terminaux + heures de connexion
w      # sessions + charge système + commande en cours + idle
```

---

## 5. Astuces & Pièges à éviter

!!! tip "who vs w — lequel utiliser ?"
    | Besoin | Commande |
    | --- | --- |
    | Sessions actives uniquement | `who` |
    | Sessions + processus + charge CPU | `w` |
    | Historique des connexions passées | `last` (lit `/var/log/wtmp`) |
    | Tentatives de connexion échouées | `lastb` (lit `/var/log/btmp`, root requis) |
    | Session courante uniquement | `who am i` |

!!! tip "Détecter les connexions SSH distantes"
    `who | grep pts` filtre les connexions via pseudo-terminal (SSH, tmux, screen). Les sessions sur `tty1` à `ttyN` sont des connexions physiques ou console. Une session `pts/X` avec une IP source dans `who -H` est une connexion SSH entrante — à surveiller en audit.

!!! warning "who ne montre que les sessions utmp enregistrées"
    `who` lit `/var/run/utmp`. Certains processus ou connexions spéciales (scripts sans allocation de TTY, connexions via certains outils de tunneling) n'y sont **pas enregistrés** et sont donc invisibles pour `who`. Un attaquant peut aussi effacer l'entrée utmp pour se dissimuler — croiser avec `ps aux` et `ss -antp`.

!!! warning "who -b peut afficher un boot ancien après un suspend/hibernate"
    Sur les systèmes portables avec veille, `who -b` affiche la date du **dernier démarrage complet**, pas la date de dernière activation. Un système qui sort de veille garde la même heure de boot — ne pas confondre avec un uptime réel.
