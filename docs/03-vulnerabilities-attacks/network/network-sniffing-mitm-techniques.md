---
title: "Attaques LAN : Reniflage, ARP Spoofing et Détournement DNS"
description: "Anatomie des attaques Man-in-the-Middle sur réseau local, interception de flux non chiffrés, empoisonnement ARP, détournement DNS et mécanismes de défense (DAI, 802.1X, VLANs)."
tags:
  - mitm
  - arp-spoofing
  - dns-spoofing
  - sniffing
  - wireshark
  - network-security
  - blue-team
  - red-team
---

# Attaques LAN : Reniflage, ARP Spoofing et Détournement DNS

!!! note "Public visé"
    Cette fiche s'adresse aux administrateurs réseau, analystes SOC/Blue Team et pentesters souhaitant comprendre l'anatomie des attaques de niveau 2/3 sur un LAN Ethernet, ainsi que les contre-mesures d'architecture à déployer.

## 1. Résumé Exécutif & Concepts Clés

Les réseaux locaux Ethernet reposent historiquement sur des protocoles conçus dans les années 1980-1990, à une époque où la confiance implicite entre hôtes du même segment était la norme. **ARP, DNS non sécurisé, et la majorité des protocoles applicatifs historiques (HTTP, FTP, Telnet, POP3, IMAP, SMTP) n'intègrent aucun mécanisme natif d'authentification ou de chiffrement.** Cette absence de contrôle constitue la surface d'attaque exploitée par les techniques décrites dans ce document.

!!! info "Définition : Man-in-the-Middle (MitM)"
    Une attaque **Man-in-the-Middle** consiste, pour un attaquant positionné sur le même segment réseau que ses victimes, à s'insérer logiquement au milieu d'un flux de communication entre deux hôtes (typiquement une machine cliente et la passerelle par défaut). L'attaquant peut alors :

    - **Observer** (sniffing passif) le trafic transitant,
    - **Altérer** le contenu des paquets à la volée,
    - **Rejeter** ou rediriger sélectivement certains flux.

    Le MitM sur LAN repose généralement sur une étape préalable de **détournement de flux** (le plus souvent via ARP Spoofing), suivie d'une étape d'**exploitation** (sniffing, injection, DNS spoofing, SSL stripping).

```
Schéma général du principe MitM
--------------------------------

  [Victime A]                                   [Victime B / Gateway]
       |                                                  |
       |  Trafic normal (sans MitM)                       |
       +--------------------------------------------------+

  [Victime A]        [Attaquant]                [Victime B / Gateway]
       |                   |                              |
       |------------------>|                               |
       |   (intercepté)    |----------------------------->|
       |                   |<-----------------------------|
       |<------------------|                               |
       |  (relayé, observé, éventuellement altéré)          |
```

!!! warning "Cadre légal"
    L'ensemble des techniques présentées ci-après ne doit être mis en œuvre que dans un cadre autorisé (laboratoire personnel, environnement de test, mission de pentest avec accord écrit). L'interception de communications sans autorisation constitue une infraction pénale dans la majorité des juridictions.

---

## 2. Reniflage de Trafic (Network Sniffing)

### 2.1 Mode Promiscuous

Par défaut, une carte réseau Ethernet ne traite que les trames dont l'adresse MAC de destination lui correspond (ou les trames de broadcast/multicast). Le **mode promiscuous** désactive ce filtrage matériel : la carte transmet à la pile réseau **toutes** les trames reçues sur le segment physique, qu'elles lui soient destinées ou non.

!!! note "Portée du sniffing selon la topologie"
    - Sur un **hub** (concentrateur, obsolète aujourd'hui), toutes les trames sont diffusées à tous les ports : le sniffing passif suffit à tout observer.
    - Sur un **switch**, chaque port ne reçoit en théorie que le trafic qui lui est destiné (grâce à la table CAM). Le sniffing passif y est donc limité au trafic broadcast/multicast et au trafic propre à l'hôte. C'est précisément pour contourner cette limitation que l'**ARP Spoofing** (section 3) est utilisé : il force la victime à envoyer son trafic vers l'attaquant plutôt que directement vers la passerelle.

### 2.2 Capture de secrets sur protocoles non chiffrés

De nombreux protocoles applicatifs historiques transmettent leurs identifiants et données en clair :

| Protocole | Port(s) | Type de données exposées |
|---|---|---|
| FTP | 21 | Identifiants de connexion, listing de fichiers |
| Telnet | 23 | Identifiants, session interactive complète |
| HTTP | 80 | Cookies de session, formulaires (login), données applicatives |
| POP3 | 110 | Identifiants de messagerie, contenu des e-mails |
| IMAP | 143 | Identifiants de messagerie, contenu des e-mails |
| SMTP (non STARTTLS) | 25 | Identifiants d'authentification SMTP, contenu des e-mails |

!!! danger "Impact"
    La capture de ces flux permet une compromission directe d'identifiants (credential harvesting), sans nécessiter d'exploitation de vulnérabilité applicative.

### 2.3 Outillage pratique

#### `tcpdump` — capture en ligne de commande

```bash
# Capturer le trafic sur l'interface eth0, avec résolution de noms désactivée (-n)
# et affichage complet des paquets (-X pour hex/ASCII)
sudo tcpdump -i eth0 -n -X

# Filtrer uniquement le trafic HTTP (port 80) vers/depuis un hôte cible
sudo tcpdump -i eth0 -n host 192.168.1.50 and port 80

# Enregistrer la capture dans un fichier .pcap pour analyse ultérieure sous Wireshark
sudo tcpdump -i eth0 -w capture.pcap

# Capturer uniquement les paquets contenant des requêtes FTP (port 21)
sudo tcpdump -i eth0 -n port 21 -A
```

#### `tshark` — équivalent CLI de Wireshark

```bash
# Capture avec filtre d'affichage Wireshark natif
sudo tshark -i eth0 -Y "http.request.method == \"POST\""

# Extraction des champs spécifiques (ex : hôtes HTTP interrogés)
sudo tshark -i eth0 -Y "http.request" -T fields -e ip.src -e http.host -e http.request.uri

# Rejouer une capture existante et filtrer les paquets Telnet
tshark -r capture.pcap -Y "telnet"
```

#### `Wireshark` — filtres d'affichage clés

```text
# Isoler toutes les requêtes HTTP de type POST (souvent des formulaires de login)
http.request.method == "POST"

# Isoler l'ensemble du trafic FTP (commandes en clair : USER, PASS)
ftp

# Isoler les sessions Telnet (flux interactif non chiffré)
telnet

# Rechercher des chaînes contenant potentiellement des identifiants
tcp contains "password"

# Suivre un flux TCP complet reconstruit (clic droit > Follow > TCP Stream)
tcp.stream eq 0
```

!!! tip "Bonne pratique d'analyse"
    Utiliser la fonction **Follow TCP Stream** de Wireshark pour reconstituer une conversation applicative complète (ex : une session FTP entière avec commandes `USER`/`PASS`) plutôt que d'analyser paquet par paquet.

---

## 3. Empoisonnement du Cache ARP (ARP Spoofing / Poisoning)

### 3.1 Fonctionnement du protocole ARP

Le protocole **ARP (Address Resolution Protocol, RFC 826)** permet de résoudre une adresse IPv4 en adresse MAC sur un même segment de diffusion. Son fonctionnement basique :

1. L'hôte A diffuse une requête ARP (`who-has 192.168.1.1 tell 192.168.1.10`).
2. L'hôte détenant cette IP répond avec un paquet ARP reply contenant son adresse MAC.
3. Chaque hôte du segment met à jour son **cache ARP** local avec cette association IP↔MAC.

!!! danger "Absence d'authentification"
    Le protocole ARP ne prévoit **aucun mécanisme de vérification** de la légitimité d'une réponse. Un hôte peut émettre spontanément une réponse ARP non sollicitée — un **Gratuitous ARP** — et la quasi-totalité des piles réseau l'accepteront et mettront à jour leur cache en conséquence, sans vérifier qu'une requête correspondante a bien été émise.

### 3.2 Mécanisme de l'attaque

L'attaquant forge et diffuse des réponses ARP falsifiées afin d'associer **sa propre adresse MAC** à l'adresse IP d'une cible légitime (typiquement la passerelle par défaut), et réciproquement associe son adresse MAC à l'IP de la victime auprès de la passerelle. Ce **double empoisonnement** place l'attaquant au centre du flux bidirectionnel.

### 3.3 Schéma synoptique ASCII

```
AVANT empoisonnement (flux normal)
-----------------------------------

  Victime (192.168.1.10)                    Gateway (192.168.1.1)
  MAC: AA:AA:AA:AA:AA:AA                     MAC: GG:GG:GG:GG:GG:GG

  Table ARP victime :
    192.168.1.1  -> GG:GG:GG:GG:GG:GG   (correcte)

  Victime ------------------------------------> Gateway
           (trafic direct, non intercepté)


APRÈS empoisonnement ARP
-----------------------------------

  Victime (192.168.1.10)     Attaquant (192.168.1.66)      Gateway (192.168.1.1)
  MAC: AA:AA:AA:AA:AA:AA     MAC: EE:EE:EE:EE:EE:EE         MAC: GG:GG:GG:GG:GG:GG

  Table ARP victime (empoisonnée) :
    192.168.1.1  -> EE:EE:EE:EE:EE:EE   (falsifiée, pointe vers l'attaquant)

  Table ARP gateway (empoisonnée) :
    192.168.1.10 -> EE:EE:EE:EE:EE:EE   (falsifiée, pointe vers l'attaquant)

  Victime -------> Attaquant -------> Gateway
           (le trafic transite désormais par l'attaquant, qui
            le relaie après observation/altération éventuelle)
```

### 3.4 Mise en œuvre offensive (PoC & Concepts)

!!! warning "Prérequis indispensable : IP Forwarding"
    Pour que l'attaque reste transparente (les victimes conservent leur connectivité) et que le trafic continue de circuler après interception, l'attaquant doit activer le **routage IP** sur sa machine, faute de quoi il provoquerait un déni de service au lieu d'un MitM discret.

```bash
# Activer temporairement le forwarding IP dans le noyau Linux
sudo sysctl -w net.ipv4.ip_forward=1

# Vérifier l'état du forwarding
cat /proc/sys/net/ipv4/ip_forward
```

#### `arpspoof` (suite dsniff)

```bash
# Empoisonner la victime 192.168.1.10 en se faisant passer pour la gateway 192.168.1.1
sudo arpspoof -i eth0 -t 192.168.1.10 192.168.1.1

# Empoisonner en parallèle la gateway pour intercepter le flux retour
# (nécessite un second terminal ou l'usage de l'option -r sur certaines versions)
sudo arpspoof -i eth0 -t 192.168.1.1 192.168.1.10
```

#### `bettercap` (framework MitM moderne)

```bash
# Lancer bettercap en mode interactif sur l'interface eth0
sudo bettercap -iface eth0
```

```text
# Depuis la console interactive bettercap :

# Découverte des hôtes présents sur le segment
net.probe on

# Activer le module d'empoisonnement ARP, cible spécifique
set arp.spoof.targets 192.168.1.10
arp.spoof on

# Activer la capture/analyse du trafic intercepté
net.sniff on
```

!!! tip "Détection côté attaquant de sa propre efficacité"
    Une fois l'empoisonnement actif, vérifier depuis la machine attaquante que le trafic de la victime transite bien via `tcpdump -i eth0 host 192.168.1.10` : la présence de trafic destiné à des IP externes en provenance de la victime confirme le succès du MitM.

---

## 4. Détournement de Trafic & DNS Spoofing

### 4.1 Combinaison ARP + DNS Spoofing

Une fois le MitM établi via ARP Spoofing, l'attaquant peut répondre lui-même aux requêtes DNS émises par la victime, avant même que le serveur DNS légitime n'ait le temps de répondre (ou en lieu et place de celui-ci puisque le trafic transite déjà par l'attaquant). Il retourne alors une adresse IP arbitraire — celle d'une infrastructure qu'il contrôle — pour un nom de domaine ciblé.

```text
# Exemple de règle bettercap pour le module dns.spoof
# Fichier hosts virtuel utilisé par bettercap (dns.spoof.hosts)

192.168.1.66   exemple-banque.com     # redirige le domaine vers l'IP de l'attaquant
192.168.1.66   webmail.exemple.com
```

```bash
# Activation du module DNS spoof dans bettercap (console interactive)
set dns.spoof.domains exemple-banque.com,webmail.exemple.com
set dns.spoof.all false
dns.spoof on
```

!!! danger "Conséquence"
    La victime, croyant contacter le service légitime, est redirigée vers un serveur contrôlé par l'attaquant — typiquement un clone de page de connexion (phishing local) ou un point de collecte de identifiants.

### 4.2 Attaques par dégradation SSL/TLS (SSL Stripping)

Le **SSL Stripping** exploite le fait que de nombreux utilisateurs accèdent initialement à un site en HTTP (sans forcer explicitement HTTPS), avant une éventuelle redirection serveur vers HTTPS. L'attaquant positionné en MitM intercepte cette première requête HTTP et :

1. Établit lui-même une connexion HTTPS légitime vers le serveur réel.
2. Relaie à la victime une version **HTTP non chiffrée** du contenu, en réécrivant les liens `https://` en `http://`.

```
Victime <--HTTP (non chiffré)--> Attaquant <--HTTPS (chiffré)--> Serveur légitime
```

La victime croit naviguer normalement (le contenu s'affiche) mais l'ensemble du trafic entre elle et l'attaquant circule en clair, permettant la capture de session et d'identifiants.

!!! note "Limite actuelle de cette technique"
    Le déploiement massif de **HSTS (HTTP Strict Transport Security)** et la présence de HSTS preloading dans les navigateurs modernes réduisent significativement l'efficacité du SSL Stripping classique sur les sites qui l'ont correctement configuré.

---

## 5. Détection & Mécanismes de Défense (Blue Team)

### 5.1 Contrôles d'architecture & d'équipements réseau (Commutateurs)

#### DAI — Dynamic ARP Inspection

Le **DAI** est une fonctionnalité des commutateurs de niveau 2 qui valide chaque paquet ARP entrant sur un port non approuvé (*untrusted*) en le comparant à une table de liaison IP↔MAC construite dynamiquement par le **DHCP Snooping**. Tout paquet ARP dont l'association IP/MAC ne correspond pas à une entrée connue est rejeté.

```text
# Exemple de configuration DAI sur un commutateur Cisco IOS (illustratif)

ip dhcp snooping
ip dhcp snooping vlan 10
!
ip arp inspection vlan 10
interface GigabitEthernet0/1
 ip arp inspection trust        ! port montant vers le cœur de réseau (trusted)
!
interface GigabitEthernet0/2
 ! port d'accès utilisateur laissé untrusted par défaut (inspection active)
```

#### DHCP Snooping

Le **DHCP Snooping** filtre les réponses DHCP (offer/ack) provenant de ports non autorisés, empêchant ainsi la mise en service d'un **serveur DHCP illégitime (Rogue DHCP)** qui pourrait distribuer une passerelle ou un serveur DNS falsifié aux clients du réseau. C'est également la base de données exploitée par le DAI.

#### Port Security & MAC Limiting

La fonctionnalité de **Port Security** limite le nombre d'adresses MAC pouvant être apprises sur un port de commutateur donné, et peut désactiver automatiquement le port (*err-disable*) en cas de violation. Elle réduit la capacité d'un attaquant à générer un flot d'adresses MAC falsifiées depuis un même point de connexion.

```text
# Exemple illustratif Cisco IOS

interface GigabitEthernet0/2
 switchport port-security
 switchport port-security maximum 2
 switchport port-security violation restrict
 switchport port-security mac-address sticky
```

#### 802.1X / Port-Based Network Access Control

Le standard **802.1X** impose une authentification (EAP, souvent adossée à un serveur RADIUS) avant qu'un équipement ne se voie accorder l'accès au réseau au niveau du port physique. Il empêche un attaquant de simplement brancher un poste non autorisé sur une prise réseau pour lancer une attaque ARP.

#### Segmentation & VLANs

La segmentation en **VLANs** limite la portée d'un empoisonnement ARP au seul domaine de broadcast concerné : un attaquant présent sur un VLAN utilisateur ne peut pas directement empoisonner le cache ARP d'hôtes situés sur un VLAN serveur distinct. Elle constitue une mesure de réduction d'impact plutôt qu'une prévention directe de l'attaque elle-même.

### 5.2 Outillage de surveillance & Alerte

#### `arpwatch` / `ArpON`

`arpwatch` surveille en continu les associations IP↔MAC observées sur le réseau et alerte (généralement par e-mail) en cas de changement suspect (*flip-flop*) ou d'apparition d'une nouvelle association pour une IP déjà connue — signature typique d'un empoisonnement ARP en cours.

```bash
# Installation et démarrage basique d'arpwatch (Debian/Ubuntu)
sudo apt install arpwatch
sudo systemctl enable --now arpwatch

# Consultation des journaux d'activité ARP détectée
sudo tail -f /var/log/syslog | grep arpwatch
```

`ArpON` propose une approche plus active en verrouillant dynamiquement les associations ARP légitimes une fois découvertes, empêchant leur écrasement par des réponses falsifiées.

#### Alertes IDS/NSM (Suricata, Snort)

Des règles de détection dédiées permettent d'identifier les anomalies ARP au niveau du trafic :

```text
# Exemple illustratif de règle Suricata/Snort détectant un volume anormal
# de réponses ARP non sollicitées (Gratuitous ARP) — signature générique

alert arp any any -> any any (msg:"Possible ARP Spoofing - Gratuitous ARP detected"; \
    arp_type:reply; threshold: type both, track by_src, count 5, seconds 10; \
    sid:1000001; rev:1;)
```

!!! tip "Complémentarité des couches de défense"
    Aucune mesure isolée n'est suffisante : DHCP Snooping et DAI protègent au niveau du commutateur, 802.1X contrôle l'admission au réseau, la segmentation VLAN limite le rayon d'impact, et arpwatch/IDS assurent une détection en cas de contournement des contrôles préventifs.

---

## 6. Tableau Synthétique : Attaques vs Protections

| Vecteur d'attaque | Impact principal | Solution d'architecture | Outil de détection |
|---|---|---|---|
| Sniffing passif (mode promiscuous) | Capture de secrets en clair (FTP, Telnet, HTTP, POP3/IMAP) | Chiffrement systématique des protocoles (HTTPS, SFTP, IMAPS) | Wireshark / tshark (analyse forensique) |
| ARP Spoofing / Poisoning | Détournement du flux victime↔gateway, MitM généralisé | DAI + DHCP Snooping, Port Security, segmentation VLAN | `arpwatch`, `ArpON`, alertes IDS sur Gratuitous ARP |
| Rogue DHCP | Distribution de gateway/DNS falsifiés | DHCP Snooping | Journaux DHCP Snooping du commutateur |
| DNS Spoofing (post-MitM) | Redirection vers infrastructure attaquant, phishing local | DNSSEC, résolveurs internes de confiance | Comparaison des réponses DNS observées vs attendues (NSM) |
| SSL Stripping | Rétrogradation HTTPS → HTTP, capture de session | HSTS + HSTS preloading, HTTPS Everywhere côté client | Détection d'incohérence de certificat / absence de HSTS |
| Accès physique non autorisé au LAN | Point d'entrée pour l'ensemble des attaques ci-dessus | 802.1X (authentification par port) | Journaux RADIUS, alertes d'échec d'authentification |

---

## 7. Anti-Sèche Commandes CLI (Cheat Sheet)

```bash
# --- Consultation des tables ARP ---

# Afficher le cache ARP local (méthode historique)
arp -a

# Afficher le cache ARP local (méthode moderne, iproute2)
ip neighbor show

# Vider le cache ARP local (utile après suspicion d'empoisonnement)
sudo ip -s -s neigh flush all


# --- Vérification de l'IP Forwarding (côté attaquant ou diagnostic défense) ---

# Lire l'état actuel du forwarding IP
cat /proc/sys/net/ipv4/ip_forward

# Activer / désactiver le forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.ip_forward=0


# --- Captures réseau rapides ---

# Capture générale avec écriture sur disque
sudo tcpdump -i eth0 -w capture.pcap

# Capture ciblée sur un hôte et affichage ASCII du contenu
sudo tcpdump -i eth0 -n host 192.168.1.10 -A

# Extraction de champs HTTP via tshark
sudo tshark -i eth0 -Y "http.request" -T fields -e ip.src -e http.host -e http.request.uri


# --- Surveillance ARP côté défense ---

# Statut du service arpwatch
sudo systemctl status arpwatch

# Suivi des alertes en temps réel
sudo journalctl -u arpwatch -f
```

---

## 8. Références

- **RFC 826** — *An Ethernet Address Resolution Protocol (ARP)*, IETF.
- **RFC 5227** — *IPv4 Address Conflict Detection*, IETF.
- **ANSSI** — Guides de recommandations relatives à l'administration et la sécurisation des équipements réseau (commutateurs, VLANs, contrôle d'accès au réseau).
- Documentation constructeur relative aux fonctionnalités **DHCP Snooping** et **Dynamic ARP Inspection (DAI)**.

!!! note "Mentions complémentaires"
    Les exemples de configuration présentés dans ce document sont volontairement génériques et illustratifs ; ils doivent être adaptés à la plateforme et à la version logicielle réellement déployée avant toute mise en production.
