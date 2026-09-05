# 🛠️ ss — Inspection des Sockets & Ports

## 1. Description rapide

Remplaçant moderne et performant de `netstat` (paquet `iproute2`). Affiche les sockets TCP/UDP, les ports en écoute, les connexions établies et les processus associés. Beaucoup plus rapide que `netstat` sur les systèmes avec de nombreuses connexions.

---

## 2. Syntaxe de base

```bash
ss [options] [filtre]
```

La combinaison la plus utilisée en diagnostic et en pentest :
```bash
ss -tulpn
```
- `-t` : TCP
- `-u` : UDP
- `-l` : sockets en écoute uniquement
- `-p` : affiche le processus associé (PID + nom)
- `-n` : numérique (pas de résolution de noms de service)

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `-t` | Connexions TCP |
| `-u` | Connexions UDP |
| `-l` | Sockets en écoute (`LISTEN`) uniquement |
| `-a` | Toutes les connexions (écoute + établies) |
| `-n` | Affiche les numéros de port (pas les noms) |
| `-p` | Affiche le PID et le nom du processus associé |
| `-s` | Statistiques globales des sockets |
| `-4` | IPv4 uniquement |
| `-6` | IPv6 uniquement |
| `-r` | Résout les noms d'hôtes (opposé de `-n`) |
| `-e` | Informations étendues (utilisateur, inode) |

---

## 4. Exemples pratiques

```bash
# Voir tous les ports TCP/UDP en écoute avec le processus associé
ss -tulpn
```

```bash
# Voir toutes les connexions TCP établies (sessions actives)
ss -tn state established
```

```bash
# Filtrer sur un port de destination précis (ex: port 443)
ss -tn dport = :443
```

```bash
# Filtrer sur un port source (ex: services écoutant sur 80)
ss -tlnp sport = :80
```

```bash
# Lister les connexions établies d'un processus spécifique (ex: nginx)
ss -tlpn | grep nginx
```

```bash
# Détecter les sockets inattendus : processus shell avec connexion réseau
ss -antp | grep -E "bash|sh|python|perl|nc"
```

---

## 5. Astuces & Pièges à éviter

!!! tip "Combiner avec grep pour le threat hunting"
    `ss -antp | grep ESTABLISHED | grep -vE 'sshd|chrome|firefox'` isole les connexions établies hors processus légitimes attendus — signature d'un reverse shell ou d'un malware.

!!! tip "Filtres d'état disponibles"
    `ss state ESTABLISHED`, `ss state LISTEN`, `ss state TIME-WAIT`, `ss state CLOSE-WAIT` — les états sont ceux de la machine d'état TCP standard. Utile pour diagnostiquer des TIME-WAIT excessifs.

!!! warning "ss -p nécessite root pour les processus des autres utilisateurs"
    Sans `sudo`, `-p` n'affiche le PID que pour les sockets appartenant à l'utilisateur courant. Les sockets des autres utilisateurs (et de root) apparaissent sans PID. Toujours utiliser `sudo ss -tulpn` pour une vue complète.

!!! warning "UDP est toujours en état UNCONN"
    Les sockets UDP n'ont pas d'état de connexion. Ils apparaissent avec l'état `UNCONN` même quand actifs — contrairement à TCP qui passe par LISTEN → ESTABLISHED. Ne pas en déduire qu'un service UDP est inactif.
