# Cheat Sheet : Réseau — Bases, Configuration & Diagnostic

!!! tip "Usage principal"
    Configurer, inspecter et dépanner le réseau Linux de l'interface physique jusqu'au routage — en administration système comme en reconnaissance réseau offensive/défensive.

---

## 1. Rappels Modèle OSI vs TCP/IP

| Couche OSI | N° | Couche TCP/IP | Protocoles courants | PDU |
| --- | --- | --- | --- | --- |
| Application | 7 | Application | HTTP, HTTPS, DNS, FTP, SSH, SMTP | Données |
| Présentation | 6 | Application | TLS/SSL, MIME | Données |
| Session | 5 | Application | NetBIOS, RPC | Données |
| Transport | 4 | Transport | TCP, UDP | Segment / Datagramme |
| Réseau | 3 | Internet | IP, ICMP, OSPF, BGP | Paquet |
| Liaison | 2 | Accès réseau | Ethernet, ARP, Wi-Fi (802.11) | Trame |
| Physique | 1 | Accès réseau | Câbles, signaux, RJ45 | Bit |

!!! info "ICMP n'a pas de port"
    ICMP (couche 3) est utilisé par `ping` et `traceroute` mais n'a ni numéro de port ni état de connexion : les règles pare-feu ciblant des ports ne l'affectent pas — il faut des règles ICMP dédiées pour le filtrer.

---

## 2. Configuration & Inspection des Interfaces

### Commandes modernes vs legacy

| Action | Moderne (`iproute2`) | Legacy (obsolète) |
| --- | --- | --- |
| Lister les interfaces | `ip a` / `ip addr` | `ifconfig` |
| Activer une interface | `ip link set eth0 up` | `ifconfig eth0 up` |
| Désactiver une interface | `ip link set eth0 down` | `ifconfig eth0 down` |
| Ajouter une IP | `ip addr add 192.168.1.10/24 dev eth0` | `ifconfig eth0 192.168.1.10 netmask 255.255.255.0` |
| Supprimer une IP | `ip addr del 192.168.1.10/24 dev eth0` | — |
| Table de routage | `ip route` | `route -n` / `netstat -r` |
| Voisins ARP | `ip neighbor` | `arp -an` |
| Ports/connexions actifs | `ss -tulnp` | `netstat -tulnp` |

### Inspecter les interfaces
```bash
ip a                         # liste toutes les interfaces et leurs adresses IP
ip link show                 # liste les interfaces avec leur état (UP/DOWN) et MAC
ip addr show eth0            # détails de l'interface eth0 uniquement
```

### Activer / désactiver une interface
```bash
ip link set eth0 up          # active l'interface eth0
ip link set eth0 down        # désactive l'interface eth0
```

### Assigner une IP manuellement
```bash
# Temporaire (perdu au prochain boot) : notation CIDR obligatoire
ip addr add 192.168.1.10/24 dev eth0
ip addr del 192.168.1.10/24 dev eth0   # supprime l'adresse
```

### Inspection ARP
```bash
ip neighbor                  # affiche la table ARP (IP ↔ MAC des voisins connus)
ip neighbor flush dev eth0   # vide la table ARP de l'interface eth0
```

### Obtenir une IP via DHCP
```bash
dhclient -v eth0             # demande une IP en DHCP avec sortie verbose
nmcli device connect eth0    # équivalent via NetworkManager
```

!!! info "Persistance de la configuration réseau"
    Les commandes `ip` sont **temporaires** et ne survivent pas au redémarrage. Pour rendre la configuration permanente, utilisez `nmcli` (NetworkManager) ou éditez les fichiers de configuration : `/etc/network/interfaces` (Debian) ou `/etc/sysconfig/network-scripts/ifcfg-eth0` (RHEL).

---

## 3. Table de Routage & Passerelle

### Afficher la table de routage
```bash
ip route                     # affiche toutes les routes (format moderne)
ip route show default        # affiche uniquement la route par défaut (passerelle)
```

### Ajouter / Supprimer une route statique
```bash
# Ajouter une route vers le réseau 10.0.0.0/8 via la passerelle 192.168.1.1
ip route add 10.0.0.0/8 via 192.168.1.1 dev eth0
```

```bash
# Supprimer la route statique ajoutée
ip route del 10.0.0.0/8 via 192.168.1.1
```

### Ajouter / Modifier / Supprimer la passerelle par défaut
```bash
ip route add default via 192.168.1.254       # ajoute la passerelle par défaut
ip route replace default via 192.168.1.1     # remplace la passerelle existante
ip route del default                          # supprime la passerelle par défaut
```

---

## 4. Dépannage & Diagnostic Réseau

### Validation de connectivité (Couche 3)
```bash
ping 8.8.8.8                        # test ICMP continu vers 8.8.8.8
ping -c 4 8.8.8.8                   # envoie exactement 4 paquets
ping -c 4 -i 0.2 8.8.8.8           # 4 paquets, intervalle de 0.2 s (flood léger)
ping -I eth0 8.8.8.8               # force l'utilisation de l'interface eth0
```

### Tracé de route
```bash
traceroute 8.8.8.8                  # trace le chemin L3 jusqu'à la destination (UDP par défaut)
traceroute -I 8.8.8.8              # utilise ICMP plutôt qu'UDP (moins filtré par les firewalls)
mtr 8.8.8.8                        # combine traceroute et ping : vue continue et statistiques par saut
```

!!! tip "mtr > traceroute pour le diagnostic"
    `mtr` affiche en continu les statistiques de perte et latence **par saut** : bien supérieur à un traceroute one-shot pour localiser précisément un nœud problématique ou une perte de paquets intermittente sur un chemin réseau.

### Inspection des ports et connexions actives
```bash
ss -tulnp                           # tous les ports en écoute (t=TCP, u=UDP, l=listen, n=numérique, p=processus)
ss -anp                             # toutes les connexions établies avec PID associé
ss -tulnp | grep :80                # filtrer un port spécifique
```

## Synthèse — Tableau des flags `ss`

| Flag | Rôle |
| --- | --- |
| `-t` | Connexions TCP uniquement |
| `-u` | Connexions UDP uniquement |
| `-l` | Sockets en écoute uniquement |
| `-n` | Affiche les numéros de port (pas les noms de service) |
| `-p` | Affiche le processus (PID et nom) associé |
| `-a` | Toutes les connexions (écoute + établies) |

!!! info "ss remplace netstat"
    `netstat` (paquet `net-tools`) est obsolète et souvent absent des distributions modernes. `ss` (paquet `iproute2`, installé par défaut) est son remplaçant direct : même syntaxe des flags courants, mais plus rapide et plus riche en informations.

---

## 5. Commandes Obsolètes vs Modernes — Référence rapide

| Ancienne commande | Équivalent moderne | Package |
| --- | --- | --- |
| `ifconfig` | `ip addr` / `ip link` | `iproute2` |
| `ifconfig eth0 up` | `ip link set eth0 up` | `iproute2` |
| `route -n` | `ip route` | `iproute2` |
| `arp -an` | `ip neighbor` | `iproute2` |
| `netstat -tulnp` | `ss -tulnp` | `iproute2` |
| `netstat -r` | `ip route` | `iproute2` |

!!! tip "Quand `ifconfig` et `netstat` sont encore utiles"
    Sur des systèmes anciens (RHEL 6, vieux firmwares, équipements embarqués) ou en pentest sur une cible sans `iproute2`, `ifconfig` et `netstat` restent présents et fonctionnels. Connaître les deux syntaxes évite d'être bloqué sur un système que vous ne contrôlez pas.
