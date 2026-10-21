# 🛠️ ip — Configuration & Inspection Réseau (iproute2)

## 1. Description rapide

Commande centrale de la suite **iproute2**, remplaçant `ifconfig` et `route`. Gère les interfaces réseau, les adresses IP, la table de routage, les voisins ARP et les tunnels. Indispensable en administration réseau et en énumération post-exploitation.

---

## 2. Syntaxe de base

```bash
ip [options] OBJET COMMANDE [arguments]
```

| Objet | Alias | Rôle |
| --- | --- | --- |
| `address` | `a`, `addr` | Adresses IP des interfaces |
| `link` | `l` | État et paramètres des interfaces (couche 2) |
| `route` | `r` | Table de routage |
| `neighbor` | `n`, `neigh` | Table ARP / NDP |
| `netns` | — | Espaces de noms réseau |

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `-4` | Limite l'affichage à IPv4 |
| `-6` | Limite l'affichage à IPv6 |
| `-c` | Affichage colorisé |
| `-s` | Statistiques (compteurs de paquets/erreurs) |
| `-br` | Format bref, une ligne par interface |
| `-j` | Sortie JSON (scriptable) |

---

## 4. Exemples pratiques

```bash
# Afficher toutes les interfaces et leurs adresses IP (version concise)
ip -br a
```

```bash
# Afficher le détail complet d'une interface spécifique
ip addr show eth0
```

```bash
# Afficher la table de routage et identifier la passerelle par défaut
ip route show
# Ligne "default via X.X.X.X" = passerelle par défaut
```

```bash
# Ajouter une adresse IP temporaire à une interface
ip addr add 192.168.1.50/24 dev eth0
```

```bash
# Activer / désactiver une interface réseau
ip link set eth0 up
ip link set eth0 down
```

```bash
# Ajouter une route statique vers un réseau interne via un pivot (pentest)
ip route add 10.10.10.0/24 via 192.168.1.1 dev eth0
```

---

## 5. Astuces & Pièges à éviter

!!! tip "Combiner -br et -c pour un aperçu rapide"
    `ip -br -c a` affiche toutes les interfaces sur une ligne avec coloration : vert = UP, rouge = DOWN. Idéal pour un état réseau en quelques secondes.

!!! tip "Sortie JSON pour les scripts"
    `ip -j route show | jq '.[0].gateway'` extrait proprement la passerelle par défaut sans grep fragile sur du texte.

!!! warning "Les changements ip sont temporaires"
    Toutes les modifications effectuées avec `ip` (adresses, routes, état d'interface) sont **perdues au redémarrage**. Pour les rendre permanentes, passer par `nmcli`, `/etc/network/interfaces` (Debian) ou `/etc/sysconfig/network-scripts/` (RHEL).

!!! warning "Ne pas confondre ip link et ip addr"
    `ip link set eth0 up` active l'interface physique (couche 2) mais n'assigne pas d'adresse IP. Il faut ensuite `ip addr add` ou un client DHCP (`dhclient eth0`) pour obtenir une adresse (couche 3).
