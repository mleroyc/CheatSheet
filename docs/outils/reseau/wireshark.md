# Wireshark & Tshark — analyse de trafic

Cheat sheet dédiée à l'analyse de trafic réseau avec Wireshark (interface graphique) et Tshark (son équivalent en ligne de commande).

---

## Capture Filters vs Display Filters

Deux mécanismes de filtrage coexistent dans Wireshark, à ne pas confondre.

| | Capture Filters | Display Filters |
|---|---|---|
| **Syntaxe** | BPF (Berkeley Packet Filter) | Syntaxe propre à Wireshark |
| **Moment d'application** | Avant la capture, au niveau du pilote réseau | Après capture, sur les paquets déjà stockés |
| **Effet** | Les paquets non filtrés ne sont **jamais enregistrés** | Les paquets sont conservés mais **masqués** de l'affichage |
| **Exemple** | `host 192.168.1.1 and port 443` | `ip.addr == 192.168.1.1 && tcp.port == 443` |
| **Modifiable après coup** | Non — les données exclues sont perdues | Oui — on peut changer le filtre à tout moment |

!!! tip "Quand utiliser lequel ?"
    Utilisez un **Capture Filter** pour limiter le volume capturé sur un lien à fort trafic (ex : `not port 22` pour exclure votre propre session SSH). Utilisez un **Display Filter** pour explorer et affiner l'analyse une fois la capture terminée, sans risquer de perdre des paquets utiles.

---

## Filtres d'affichage incontournables

### Couche IP

| Filtre | Description |
|---|---|
| `ip.addr == 192.168.1.1` | Paquets vers ou depuis cette adresse |
| `ip.src == 192.168.1.1` | Paquets émis depuis cette adresse |
| `ip.dst == 192.168.1.1` | Paquets à destination de cette adresse |
| `ip.addr == 192.168.1.0/24` | Filtre sur une plage réseau entière |
| `!(ip.addr == 192.168.1.1)` | Exclut cette adresse du résultat |

### Couche transport (TCP/UDP)

| Filtre | Description |
|---|---|
| `tcp.port == 443` | Paquets TCP sur le port 443 (source ou destination) |
| `udp.port == 53` | Paquets UDP sur le port 53 (DNS) |
| `tcp.flags.syn == 1 && tcp.flags.ack == 0` | Isole les paquets SYN (ouverture de connexion) |
| `tcp.flags.reset == 1` | Isole les paquets RST (connexion rejetée/fermée) |
| `tcp.analysis.retransmission` | Détecte les retransmissions (indice de perte réseau) |
| `tcp.stream eq 0` | Isole un flux TCP précis par son numéro de stream |

### Couche application

| Filtre | Description |
|---|---|
| `http.request.method == "POST"` | Isole les requêtes HTTP POST |
| `http.request.method == "GET"` | Isole les requêtes HTTP GET |
| `http.response.code == 200` | Filtre les réponses HTTP par code statut |
| `dns.qry.name == "domain.com"` | Requêtes DNS portant sur ce nom |
| `dns.flags.response == 1` | Isole uniquement les réponses DNS |
| `tls.handshake.type == 1` | Isole les Client Hello TLS |

### Recherche de contenu brut

```text
frame contains "password"          # Recherche la chaîne dans l'ensemble de la trame
tcp contains "login"                # Recherche limitée à la charge utile TCP
http.request.uri matches "\.php$"   # Recherche par expression régulière (regex)
```

!!! tip "frame contains vs matches"
    `contains` effectue une recherche de sous-chaîne simple et rapide. `matches` s'appuie sur une expression régulière (PCRE), plus puissante mais plus coûteuse en performance sur de grosses captures.

### Opérateurs logiques

| Opérateur | Alias | Exemple |
|---|---|---|
| Égal | `eq` ou `==` | `ip.addr eq 10.0.0.1` |
| Différent | `ne` ou `!=` | `tcp.port ne 80` |
| Et | `and` ou `&&` | `ip.src == 10.0.0.1 and tcp.port == 22` |
| Ou | `or` ou `\|\|` | `tcp.port == 80 or tcp.port == 443` |
| Non | `not` ou `!` | `not arp` |

---

## Techniques d'analyse approfondie

### Reconstruction de sessions

- **Follow TCP Stream** : clic droit sur un paquet → *Follow → TCP Stream*. Reconstitue l'intégralité d'une conversation TCP dans l'ordre chronologique, avec coloration par sens de communication.
- **Follow HTTP Stream** : équivalent spécifique au protocole HTTP, isole proprement en-têtes et corps des requêtes/réponses.

!!! tip "Filtre généré automatiquement"
    *Follow Stream* applique automatiquement le filtre `tcp.stream eq X`, permettant de revenir à cette vue à tout moment.

### Export Objects — extraction de fichiers

Permet de récupérer les fichiers transférés en clair directement depuis la capture, sans les rejouer.

- *File → Export Objects → HTTP* : extrait les fichiers transitant en HTTP (images, exécutables, documents).
- *File → Export Objects → SMB/SMB2* : extrait les fichiers partagés sur un réseau Windows.

!!! warning "Uniquement en clair"
    L'extraction ne fonctionne que sur du trafic non chiffré. Un flux HTTPS nécessite un déchiffrement préalable via une clé de session (`SSLKEYLOGFILE`).

### Statistiques et profiling du trafic

- **Statistics → Conversations** : liste toutes les paires source/destination avec volume, durée et débit — utile pour repérer un hôte anormalement bavard.
- **Statistics → Protocol Hierarchy** : vue arborescente de la répartition des protocoles, en pourcentage du trafic total.
- **Statistics → Endpoints** : liste individuelle de chaque hôte observé (IP, MAC), avec ses volumes d'échange.

---

## Tshark — Wireshark en ligne de commande

Tshark expose la quasi-totalité du moteur de Wireshark sans interface graphique, idéal pour l'automatisation et l'analyse sur serveur distant.### Lecture et filtrage d'un fichier PCAP

```bash
tshark -r file.pcap                          # Lit et affiche le contenu d'une capture
tshark -r file.pcap -Y "http.request"         # Applique un display filter (-Y)
tshark -r file.pcap -f "port 443"             # Applique un capture filter (-f) à la relecture
tshark -r file.pcap -Y "tcp.stream eq 3"      # Isole un flux TCP précis
```

### Capture en direct

```bash
tshark -i eth0                                # Capture en direct sur l'interface eth0
tshark -i eth0 -f "host 10.0.0.5"             # Capture filtrée dès l'acquisition
tshark -i eth0 -w capture.pcap                # Capture et écrit vers un fichier
```

### Extraction de champs spécifiques

```bash
tshark -r file.pcap -T fields -e ip.src -e http.host      # Extrait IP source et hôte HTTP
tshark -r file.pcap -T fields -e frame.time -e ip.src -e ip.dst -e tcp.port   # Plusieurs champs
tshark -r file.pcap -T fields -e dns.qry.name -Y "dns"     # Liste les noms interrogés en DNS
tshark -r file.pcap -T fields -E separator=, -e ip.src -e ip.dst   # Sortie façon CSV
```

!!! tip "Automatisation et scripting"
    L'option `-T fields` combinée à `-E separator=,` produit une sortie directement exploitable par `awk`, `grep` ou un script Python, ce qui fait de Tshark un outil de choix pour le traitement massif de captures dans un pipeline d'analyse.

### Statistiques en CLI

```bash
tshark -r file.pcap -q -z conv,tcp            # Équivalent CLI de Statistics → Conversations
tshark -r file.pcap -q -z io,phs              # Équivalent CLI de Protocol Hierarchy
```

---

## Voir aussi

- Documentation officielle des display filters : `https://www.wireshark.org/docs/dfref/`
- Fiche complémentaire : `dns-outils.md` pour l'inspection DNS en CLI
