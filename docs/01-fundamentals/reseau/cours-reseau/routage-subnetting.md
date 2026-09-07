# Cheat Sheet : Routage & Subnetting — IPv4, CIDR, NAT & IPv6

!!! tip "Usage principal"
    Calculer des sous-réseaux, comprendre le routage et le NAT, et manipuler IPv6 — base indispensable en administration réseau et en reconnaissance d'infrastructure.

---

## 1. Subnetting IPv4 & Notations CIDR

### Anatomie d'un réseau découpé
```
Exemple : 192.168.1.0/24

Adresse réseau   : 192.168.1.0    → identifie le sous-réseau (non attribuable à un hôte)
Masque décimal   : 255.255.255.0  → /24 = 24 bits à 1 suivis de 8 bits à 0
Premier hôte     : 192.168.1.1    → première IP attribuable
Dernier hôte     : 192.168.1.254  → dernière IP attribuable
Adresse broadcast: 192.168.1.255  → paquet vers tous les hôtes du réseau (non attribuable)
Nb d'hôtes       : 2^8 - 2 = 254  → formule : 2^(32-préfixe) - 2
```

### Cheat sheet des masques CIDR usuels

| CIDR | Masque décimal | Nb d'hôtes | Usage courant |
| --- | --- | --- | --- |
| `/8` | `255.0.0.0` | 16 777 214 | Grandes org. / plages RFC 1918 (`10.0.0.0/8`) |
| `/16` | `255.255.0.0` | 65 534 | Réseaux d'entreprise / RFC 1918 (`172.16.0.0/16`) |
| `/24` | `255.255.255.0` | 254 | LAN standard, réseau d'agence |
| `/25` | `255.255.255.128` | 126 | Découpage d'un /24 en 2 |
| `/26` | `255.255.255.192` | 62 | Découpage d'un /24 en 4 |
| `/27` | `255.255.255.224` | 30 | Petit segment, DMZ |
| `/28` | `255.255.255.240` | 14 | Lien inter-routeurs, VLAN de gestion |
| `/29` | `255.255.255.248` | 6 | Point-à-point avec quelques hôtes |
| `/30` | `255.255.255.252` | 2 | Lien point-à-point entre routeurs |
| `/31` | `255.255.255.254` | 0 (2 IPs) | Lien P2P sans broadcast (RFC 3021) |
| `/32` | `255.255.255.255` | 1 (hôte seul) | Route hôte, loopback, règle firewall précise |

!!! tip "Calcul mental rapide"
    Pour un `/26` : `32 - 26 = 6` bits hôtes → `2^6 = 64` adresses → `64 - 2 = 62` hôtes. Le masque est `256 - 64 = 192` dans le dernier octet → `255.255.255.192`. Formule clé : **masque dernier octet = 256 − nb total d'adresses du sous-réseau**.

### Espaces d'adressage IPv4

| Plage | Notation CIDR | Type | Usage |
| --- | --- | --- | --- |
| `10.0.0.0 – 10.255.255.255` | `10.0.0.0/8` | Privé (RFC 1918) | Réseaux internes large échelle |
| `172.16.0.0 – 172.31.255.255` | `172.16.0.0/12` | Privé (RFC 1918) | Réseaux d'entreprise |
| `192.168.0.0 – 192.168.255.255` | `192.168.0.0/16` | Privé (RFC 1918) | LAN domestique / PME |
| `127.0.0.0 – 127.255.255.255` | `127.0.0.0/8` | Loopback | Interface locale uniquement (`127.0.0.1`) |
| `169.254.0.0 – 169.254.255.255` | `169.254.0.0/16` | APIPA (link-local) | Auto-assigné si pas de DHCP répondant |
| Tout le reste | — | Public | Routable sur Internet |

---

## 2. Principes du Routage & NAT

### Routage statique vs dynamique

| Critère | Routage statique | Routage dynamique |
| --- | --- | --- |
| Configuration | Manuelle par l'admin | Automatique via protocole |
| Convergence | Aucune (figé) | Automatique après changement topologie |
| Charge CPU/réseau | Nulle | Overhead du protocole |
| Usage | Petits réseaux, routes par défaut | Réseaux étendus, redondance |

```bash
# Routage statique Linux : ajouter une route vers un réseau via une passerelle
ip route add 10.10.0.0/16 via 192.168.1.1 dev eth0
```

### Protocoles de routage dynamique

| Protocole | Type | Algorithme | Usage |
| --- | --- | --- | --- |
| `RIP` | IGP | Distance Vector (sauts) | Petits réseaux, obsolète |
| `OSPF` | IGP | Link State (état de lien, coût) | Réseaux d'entreprise internes |
| `EIGRP` | IGP | Hybride (Cisco propriétaire) | Environnements Cisco |
| `BGP` | EGP | Path Vector (attributs de chemin) | Routage inter-AS sur Internet |

!!! tip "IGP vs EGP"
    **IGP** (Interior Gateway Protocol) : gère le routage **à l'intérieur** d'un système autonome (AS) — OSPF, RIP. **EGP** (Exterior Gateway Protocol) : gère le routage **entre** systèmes autonomes — BGP est l'unique EGP utilisé sur Internet aujourd'hui. Un AS est un ensemble de réseaux IP sous une même politique de routage (FAI, grande entreprise).

### NAT — Traduction d'Adresses Réseau

| Type | Direction | Rôle |
| --- | --- | --- |
| **SNAT** (Source NAT) | LAN → WAN | Traduit l'IP source privée en IP publique au départ (sortie vers Internet) |
| **Masquerade** | LAN → WAN | SNAT dynamique : IP publique de l'interface prise automatiquement (IP variable) |
| **DNAT** (Destination NAT) | WAN → LAN | Traduit l'IP/port destination en IP interne (entrée depuis Internet) |
| **PAT / Port Forwarding** | WAN → LAN | DNAT ciblant un port précis, redirige vers un hôte/port interne |

```bash
# Masquerade : partager la connexion Internet de eth0 vers les hôtes du réseau interne
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

```bash
# DNAT / Port Forwarding : redirige le port 80 entrant vers 192.168.1.10:80
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j DNAT --to-destination 192.168.1.10:80
```

---

## 3. Bases IPv6

### Structure d'une adresse IPv6
```
Adresse IPv6 : 128 bits, notation hexadécimale en 8 groupes de 16 bits séparés par ":"
Exemple complet : 2001:0db8:0000:0042:0000:0000:0000:0001
Après compression : 2001:db8:0:42::1

Règles de compression :
  - Supprimer les zéros de tête dans chaque groupe : "0042" → "42"
  - Remplacer UNE seule séquence de groupes "0000" consécutifs par "::"
  - "::" ne peut apparaître qu'une seule fois dans l'adresse
```

### Types d'adresses IPv6

| Préfixe | Type | Équivalent IPv4 | Rôle |
| --- | --- | --- | --- |
| `::1/128` | Loopback | `127.0.0.1` | Interface locale uniquement |
| `fe80::/10` | Link-Local | `169.254.0.0/16` | Communication sur le lien local (non routable) |
| `fc00::/7` | Unique Local | RFC 1918 privé | Réseaux privés internes (non routés sur Internet) |
| `2000::/3` | Global Unicast | IP publique | Adresses routables sur Internet |
| `ff00::/8` | Multicast | `224.0.0.0/4` | Envoi à un groupe d'hôtes |

### Exemples de compression
```
Avant :  2001:0db8:0000:0000:0000:0000:0000:0001
Étape 1 (zéros de tête) : 2001:db8:0:0:0:0:0:1
Étape 2 (:: pour la séquence la plus longue) : 2001:db8::1
```

```
Avant :  fe80:0000:0000:0000:0212:34ff:fe56:789a
Après  : fe80::212:34ff:fe56:789a
```

!!! tip "IPv6 sur Linux : commandes adaptées"
    Les outils `ip` et `ss` gèrent nativement IPv6 sans flag supplémentaire. `ping6 ::1` cible le loopback IPv6, `ip -6 addr` n'affiche que les adresses IPv6, et `ip -6 route` affiche la table de routage IPv6. Pour `dig`, ajouter `AAAA` comme type d'enregistrement pour résoudre les adresses IPv6 d'un domaine.
