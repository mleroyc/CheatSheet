---
title: "Protocole ARP : Fonctionnement, Cache et Sécurité"
description: "Anatomie du protocole ARP (RFC 826), résolution d'adresses IP/MAC, structure de trame, Gratuitous ARP, ARP Spoofing et contre-mesures (DAI, Arpwatch, entrées statiques)."
tags:
  - arp
  - network
  - protocoles
  - layer2
  - security
  - mitm
  - blue-team
  - red-team
---

# Protocole ARP : Fonctionnement, Cache et Sécurité

## 1. Résumé Exécutif & Définition

**ARP (Address Resolution Protocol)**, défini par la **RFC 826**, est le protocole chargé de faire correspondre une adresse **IPv4** (couche 3, logique) à une adresse **MAC** (couche 2, physique) sur un réseau local. Sans cette résolution, une trame Ethernet ne peut pas être adressée : IP permet de savoir *où* se trouve la destination sur le réseau, mais c'est l'adresse MAC qui permet de l'atteindre physiquement sur le segment.

!!! note "Positionnement dans le modèle OSI"
    ARP est souvent qualifié de protocole de "couche 2.5" : il encapsule directement ses messages dans une trame Ethernet (pas d'en-tête IP), mais manipule des informations de couche 3 (adresses IP). Il se situe donc à la frontière entre la couche Liaison de données et la couche Réseau.

**Portée du protocole :** ARP ne fonctionne qu'au sein d'un **même domaine de diffusion** (broadcast domain), généralement assimilé à un VLAN. Les requêtes ARP ne traversent jamais un routeur : dès qu'une communication doit sortir du sous-réseau local, c'est l'adresse MAC de la passerelle par défaut qui est résolue, et non celle de la destination finale.

!!! tip "Équivalent IPv6"
    En IPv6, ARP est remplacé par **NDP (Neighbor Discovery Protocol)**, qui repose sur des messages ICMPv6 (Neighbor Solicitation / Neighbor Advertisement) plutôt que sur des trames broadcast dédiées. Voir la [section 5](#5-matrice-comparative-arp-vs-ndp-ipv6) pour une comparaison détaillée.

---

## 2. Anatomie & Fonctionnement Interne

### 2.1 Mécanisme de résolution (Request / Reply)

La résolution ARP repose sur un échange en deux temps :

1. **ARP Request** : l'hôte émetteur diffuse une trame en **broadcast** (adresse MAC de destination `FF:FF:FF:FF:FF:FF`) contenant en substance la question *"Qui possède l'adresse IP X.X.X.X ? Merci de me communiquer votre adresse MAC."*
2. **ARP Reply** : seul l'hôte possédant réellement cette adresse IP répond, en **unicast**, directement à l'émetteur : *"J'ai l'IP X.X.X.X, voici mon adresse MAC Y:Y:Y:Y:Y:Y."*

```text
Étape 1 - Broadcast (ARP Request)
  Émetteur (192.168.1.10, MAC AA:AA...)
      │
      ├──► Broadcast FF:FF:FF:FF:FF:FF : "Qui a 192.168.1.20 ?"
      │
  Tous les hôtes du LAN reçoivent la trame

Étape 2 - Unicast (ARP Reply)
  Hôte cible (192.168.1.20, MAC BB:BB...)
      │
      └──► Unicast vers AA:AA... : "192.168.1.20 est à BB:BB:BB:BB:BB:BB"
```

### 2.2 Structure de la trame ARP

Une trame ARP est encapsulée directement dans l'en-tête Ethernet (EtherType `0x0806`). Sa structure est la suivante :

| Champ | Taille | Description |
|---|---|---|
| Hardware Type (HTYPE) | 2 octets | Type de réseau physique (`1` = Ethernet) |
| Protocol Type (PTYPE) | 2 octets | Protocole de couche 3 résolu (`0x0800` = IPv4) |
| Hardware Address Length (HLEN) | 1 octet | Longueur d'une adresse MAC (`6`) |
| Protocol Address Length (PLEN) | 1 octet | Longueur d'une adresse IPv4 (`4`) |
| Opcode | 2 octets | Type de message : `1` = Request, `2` = Reply |
| Sender Hardware Address (SHA) | 6 octets | Adresse MAC de l'émetteur |
| Sender Protocol Address (SPA) | 4 octets | Adresse IP de l'émetteur |
| Target Hardware Address (THA) | 6 octets | Adresse MAC cible (mise à `00:00:00:00:00:00` dans une Request) |
| Target Protocol Address (TPA) | 4 octets | Adresse IP cible |

```text
# Exemple de trame ARP Request décortiquée (capture Wireshark simplifiée)

Ethernet II
    Destination : ff:ff:ff:ff:ff:ff (Broadcast)
    Source      : aa:aa:aa:aa:aa:aa
    Type        : ARP (0x0806)

Address Resolution Protocol (request)
    Hardware type : Ethernet (1)
    Protocol type : IPv4 (0x0800)
    Hardware size : 6
    Protocol size : 4
    Opcode         : request (1)
    Sender MAC address : aa:aa:aa:aa:aa:aa
    Sender IP address   : 192.168.1.10
    Target MAC address : 00:00:00:00:00:00
    Target IP address   : 192.168.1.20
```

### 2.3 Le Cache ARP

Pour éviter de réémettre une requête broadcast avant chaque communication, chaque système d'exploitation maintient une **table de correspondance IP-MAC en mémoire**, appelée cache ARP (ou table de voisinage).

- **Rôle** : réduire le trafic broadcast et accélérer l'envoi des trames.
- **Gestion dynamique** : chaque entrée obtenue par un échange Request/Reply possède une **durée de vie (TTL)**, généralement de l'ordre de quelques minutes (souvent 60 à 300 secondes selon l'OS). Passé ce délai, l'entrée est soit rafraîchie par une nouvelle résolution, soit supprimée si l'hôte ne répond plus.
- **Entrées statiques** : il est possible de figer manuellement une entrée pour qu'elle ne soit jamais modifiée dynamiquement (voir [section 4.2](#42-protections-systeme-et-entrees-statiques)).

```text
# Consultation du cache ARP sous Linux
$ arp -n
Address                  HWtype  HWaddress           Flags Mask  Iface
192.168.1.1              ether   00:11:22:33:44:55   C           eth0
192.168.1.20              ether   bb:bb:bb:bb:bb:bb    C           eth0

# Équivalent moderne (iproute2)
$ ip neighbor show
192.168.1.1 dev eth0 lladdr 00:11:22:33:44:55 REACHABLE
192.168.1.20 dev eth0 lladdr bb:bb:bb:bb:bb:bb STALE
```

### 2.4 Gratuitous ARP (GARP)

Un **Gratuitous ARP** est une trame ARP particulière (généralement une Request ou une Reply) où le champ *Sender IP* est identique au champ *Target IP*. L'hôte annonce spontanément sa propre correspondance IP-MAC, sans qu'aucune requête préalable ne le justifie.

!!! tip "Cas d'usage légitimes du GARP"
    - **Détection d'adresse IP dupliquée (RFC 5227)** : à l'initialisation de son interface, un hôte envoie un GARP ; si un autre hôte répond en indiquant qu'il possède déjà cette IP, un conflit est détecté.
    - **Mise à jour du cache après changement de carte réseau** : après remplacement matériel, un GARP force les autres hôtes à rafraîchir leur cache avec la nouvelle MAC.
    - **Bascule de VIP (VRRP / Keepalived)** : lors d'un failover de cluster haute disponibilité, le nouveau maître envoie un GARP pour rediriger immédiatement le trafic destiné à l'IP virtuelle (VIP) vers sa propre adresse MAC.

```text
# Exemple : envoi manuel d'un Gratuitous ARP avec arping (Linux)
$ arping -U -I eth0 -c 3 192.168.1.100
# -U : mode Gratuitous ARP (Unsolicited)
```

---

## 3. Risques de Sécurité & Absence d'Authentification

La faiblesse fondamentale d'ARP tient à sa conception historique (1982), à une époque où la confiance implicite entre équipements était la norme sur les réseaux locaux.

!!! danger "Absence totale d'authentification et d'état"
    ARP est un protocole **stateless** et **non authentifié** :

    - Un hôte accepte et enregistre dans son cache une **ARP Reply** même s'il n'a **jamais émis la Request correspondante**.
    - Aucun mécanisme cryptographique ne permet de vérifier qu'une réponse provient réellement du propriétaire légitime de l'adresse IP annoncée.
    - Rien n'empêche un hôte malveillant d'émettre des trames ARP falsifiées (Sender MAC/IP arbitraires).

### 3.1 Vecteurs d'attaque (Red Team)

**ARP Spoofing / ARP Poisoning**

Un attaquant envoie des réponses ARP falsifiées (souvent des Gratuitous ARP non sollicités) à une ou plusieurs victimes, associant sa propre adresse MAC à l'adresse IP d'un tiers légitime (typiquement la passerelle par défaut). Les victimes mettent alors à jour leur cache ARP avec cette fausse correspondance.

```text
# Scénario type d'empoisonnement de cache

Victime (192.168.1.10)          Attaquant (192.168.1.66)        Passerelle (192.168.1.1)
        │                                │                                │
        │◄── GARP falsifié: "1.1 est à MAC-ATTAQUANT" ──┤                │
        │                                │                                │
        │                                ├── GARP falsifié: "1.10 est à MAC-ATTAQUANT" ──►│
        │                                │                                │

Résultat : tout le trafic Victime <-> Passerelle transite désormais par l'Attaquant.
```

**Positionnement Man-in-the-Middle (MitM)**

Une fois le cache empoisonné des deux côtés (victime et passerelle), l'attaquant se positionne en intermédiaire transparent. Il peut alors :

- **Intercepter** le trafic (capture de flux non chiffrés, credentials, sessions).
- **Altérer** les paquets à la volée (injection de contenu, downgrade de protocole).
- **Bloquer** sélectivement certains flux (déni de service ciblé).

**Impact sur le routage**

Le détournement du trafic destiné à la passerelle par défaut est le cas d'usage le plus critique : il permet à l'attaquant d'intercepter **l'intégralité des communications sortantes** de la victime vers le reste du réseau et Internet, sans que celle-ci ne perçoive d'anomalie visible (latence mise à part).

---

## 4. Détection, Hardening & Remédiation (Blue Team)

### 4.1 Protections au niveau Commutateur (Switching)

**Dynamic ARP Inspection (DAI)**

DAI est une fonctionnalité de commutateurs (Cisco, et équivalents chez d'autres constructeurs) qui intercepte tous les paquets ARP transitant sur les ports non fiables et les valide contre une table d'appariement IP-MAC-Port construite dynamiquement à partir du **DHCP Snooping**. Toute trame ARP dont la correspondance IP-MAC ne figure pas dans cette table légitime est rejetée.

```text
# Exemple de configuration DAI sur un switch Cisco (extrait annoté)

! Active le DHCP Snooping (prérequis pour construire la table de confiance)
ip dhcp snooping
ip dhcp snooping vlan 10

! Active Dynamic ARP Inspection sur le VLAN concerné
ip arp inspection vlan 10

! Déclare le port montant vers le serveur DHCP/routeur comme "trusted"
! (les ports non déclarés sont "untrusted" par défaut et donc inspectés)
interface GigabitEthernet0/1
 description Uplink vers routeur
 ip arp inspection trust

! Limitation du débit de paquets ARP pour prévenir un flood
interface range GigabitEthernet0/2-24
 ip arp inspection limit rate 15
```

**Port Security**

Le Port Security restreint le nombre et/ou la liste des adresses MAC autorisées à communiquer sur un port physique donné, limitant la capacité d'un attaquant à usurper plusieurs identités MAC depuis un même point de connexion.

```text
# Exemple de configuration Port Security (Cisco)
interface GigabitEthernet0/5
 switchport port-security
 switchport port-security maximum 2
 switchport port-security violation restrict
 switchport port-security mac-address sticky
```

### 4.2 Protections Système et Entrées Statiques

Pour les équipements critiques (passerelle, serveurs sensibles), il est possible de figer manuellement l'entrée ARP correspondante afin qu'elle ne puisse plus être modifiée par une réponse falsifiée.

```text
# Ajout d'une entrée ARP statique - Linux
$ sudo ip neighbor add 192.168.1.1 lladdr 00:11:22:33:44:55 dev eth0 nud permanent
# ou avec l'ancien outil net-tools
$ sudo arp -s 192.168.1.1 00:11:22:33:44:55

# Ajout d'une entrée ARP statique - Windows (PowerShell)
PS> New-NetNeighbor -IPAddress 192.168.1.1 -LinkLayerAddress "00-11-22-33-44-55" -InterfaceIndex 12 -State Permanent
```

!!! warning "Limites des entrées statiques"
    Cette approche n'est réaliste qu'à petite échelle (postes critiques, serveurs isolés). Elle ne passe pas à l'échelle sur un grand parc et doit être combinée avec des protections réseau (DAI) plutôt que de s'y substituer.

### 4.3 Supervision & Détection d'Anomalies

**Outils de surveillance dédiés**

- **`arpwatch`** : démon historique qui surveille en continu les échanges ARP sur une interface et déclenche une alerte (mail, log) dès qu'une adresse IP change soudainement de MAC associée, ou qu'une nouvelle station apparaît sur le réseau.
- **`ArpON`** : daemon de sécurisation ARP qui propose plusieurs modes (SARPI, DARPI, HARPI) pour figer dynamiquement ou statiquement les correspondances IP-MAC légitimes et bloquer les tentatives d'empoisonnement.

```text
# Installation et lancement basique d'arpwatch (Debian/Ubuntu)
$ sudo apt install arpwatch
$ sudo arpwatch -i eth0

# Extrait de log typique en cas d'empoisonnement détecté
hostname changed ip address
ip address: 192.168.1.1
old ethernet address: 00:11:22:33:44:55
new ethernet address: de:ad:be:ef:13:37
```

**Détection via IDS/NSM**

Des sondes comme **Suricata** ou **Snort** peuvent être configurées avec des règles dédiées pour détecter une abondance anormale de réponses ARP Unicast non sollicitées, un indicateur fort d'une tentative de spoofing en cours.

```text
# Inspection manuelle du trafic ARP en temps réel

# tcpdump : filtrer uniquement les trames ARP
$ sudo tcpdump -i eth0 arp -n

# Wireshark : filtre d'affichage équivalent
arp
# Filtre affiné pour repérer des Gratuitous ARP suspects
arp.opcode == 2 && arp.src.proto_ipv4 == arp.dst.proto_ipv4
```

---

## 5. Matrice Comparative : ARP vs NDP (IPv6)

| Critère | ARP (IPv4) | NDP (IPv6) |
|---|---|---|
| Couche protocolaire | Encapsulé directement dans Ethernet (EtherType `0x0806`) | Basé sur ICMPv6 (au-dessus d'IPv6) |
| Type de trafic pour la résolution | Broadcast (`FF:FF:FF:FF:FF:FF`) | Multicast (adresses solicited-node) |
| Message de requête | ARP Request | Neighbor Solicitation (NS) |
| Message de réponse | ARP Reply | Neighbor Advertisement (NA) |
| Authentification native | Aucune | Aucune par défaut |
| Mécanisme de sécurité associé | Aucun natif (DAI au niveau switch en compensation) | **SEND (SEcure Neighbor Discovery, RFC 3971)**, basé sur des certificats et signatures cryptographiques (CGA) |
| Exposition aux attaques de spoofing | Élevée (ARP Spoofing/Poisoning classique) | Existe (NDP Spoofing) mais mitigée par SEND lorsqu'il est déployé |

---

## 6. Anti-Sèche Commandes CLI (Cheat Sheet)

```text
# ============================
# LINUX
# ============================

# Afficher le cache ARP (méthode moderne, iproute2)
$ ip neighbor show

# Afficher le cache ARP (méthode historique, net-tools)
$ arp -n

# Ajouter une entrée statique
$ sudo ip neighbor add 192.168.1.1 lladdr 00:11:22:33:44:55 dev eth0 nud permanent
$ sudo arp -s 192.168.1.1 00:11:22:33:44:55

# Supprimer une entrée
$ sudo ip neighbor del 192.168.1.1 dev eth0
$ sudo arp -d 192.168.1.1

# Vider entièrement le cache
$ sudo ip neighbor flush all

# ============================
# WINDOWS
# ============================

# Afficher le cache ARP
C:\> arp -a

# Supprimer une entrée
C:\> arp -d 192.168.1.1

# Afficher le cache via PowerShell (plus détaillé)
PS> Get-NetNeighbor

# Ajouter une entrée statique via PowerShell
PS> New-NetNeighbor -IPAddress 192.168.1.1 -LinkLayerAddress "00-11-22-33-44-55" -InterfaceIndex 12 -State Permanent

# ============================
# INSPECTION DU TRAFIC
# ============================

# tcpdump : capturer uniquement le trafic ARP
$ sudo tcpdump -i eth0 arp -n -v

# Wireshark : filtre d'affichage
arp
```

---

## 7. Références

- **RFC 826** – *An Ethernet Address Resolution Protocol*
- **RFC 5227** – *IPv4 Address Conflict Detection*
- **RFC 3971** – *SEcure Neighbor Discovery (SEND)*
- Guides de sécurisation des réseaux locaux de l'**ANSSI**
