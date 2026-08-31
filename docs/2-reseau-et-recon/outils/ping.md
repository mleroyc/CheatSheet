# 🛠️ ping — Test de Connectivité ICMP

## 1. Description rapide

`ping` envoie des paquets ICMP Echo Request vers une cible et mesure le temps de réponse (RTT). Utilisé pour tester la connectivité L3, la résolution DNS, la latence et détecter des pertes de paquets. Outil de premier diagnostic réseau universel.

---

## 2. Syntaxe de base

```bash
ping [options] destination
```

`destination` : adresse IP, nom d'hôte ou FQDN.

```bash
# Comportement par défaut Linux : ping continu jusqu'à Ctrl+C
ping 8.8.8.8

# Comportement par défaut Windows : 4 paquets seulement
ping 8.8.8.8
```

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `-c N` | Limite à N paquets (puis s'arrête) |
| `-i N` | Intervalle entre les paquets (secondes, défaut : 1) |
| `-s N` | Taille du payload ICMP en octets (défaut : 56) |
| `-W N` | Timeout d'attente de réponse en secondes |
| `-t N` | TTL des paquets envoyés |
| `-I IFACE` | Force l'utilisation d'une interface spécifique |
| `-q` | Mode silencieux (affiche uniquement le résumé final) |
| `-f` | Flood ping — envoie aussi vite que possible (root requis) |
| `-4` | Force IPv4 |
| `-6` | Force IPv6 |

---

## 4. Exemples pratiques

```bash
# Envoyer exactement 4 paquets et afficher le résumé
ping -c 4 192.168.1.1
```

```bash
# Test de latence avec intervalle réduit (0.2s) pour une mesure plus rapide
ping -c 10 -i 0.2 8.8.8.8
```

```bash
# Tester avec un paquet de grande taille pour détecter les problèmes de fragmentation MTU
ping -c 4 -s 1472 192.168.1.1
```

```bash
# Ping silencieux via une interface spécifique (utile en multi-home)
ping -c 1 -q -I eth1 10.0.0.1
```

```bash
# Découverte d'hôtes rapide sur un /24 (sans nmap, à la main)
for i in $(seq 1 254); do ping -c 1 -W 1 192.168.1.$i &>/dev/null && echo "192.168.1.$i UP"; done
```

```bash
# Test de connectivité IPv6
ping -6 -c 4 2001:4860:4860::8888
```

---

## 5. Astuces & Pièges à éviter

!!! tip "Absence de réponse ≠ hôte éteint"
    De nombreux pare-feux, hôtes Windows et équipements réseau **bloquent ICMP par politique**. Un ping sans réponse signifie que l'ICMP est filtré, pas nécessairement que l'hôte est inactif. Compléter avec `nmap -sT -Pn` ou `curl` pour confirmer.

!!! tip "Utiliser -W pour accélérer les sweeps"
    `ping -c 1 -W 1` attend au maximum 1 seconde par hôte. Combiné à un `for` ou `xargs -P`, permet un sweep réseau rapide sans outil tiers.

!!! warning "ping -f nécessite root et peut saturer le réseau"
    Le flood ping (`-f`) envoie des paquets aussi vite que le noyau le permet — peut générer plusieurs milliers de paquets par seconde et dégrader un réseau en production. À n'utiliser qu'en lab ou avec une autorisation explicite.

!!! warning "Différence Linux vs Windows"
    Sous **Linux**, `ping` est continu par défaut (Ctrl+C pour arrêter). Sous **Windows**, il s'arrête après 4 paquets. En scripting cross-platform, toujours spécifier `-c N` (Linux) ou `-n N` (Windows) pour un comportement prévisible.
