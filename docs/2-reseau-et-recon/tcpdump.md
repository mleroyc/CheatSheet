# Tcpdump — capture et analyse en ligne de commande

Cheat sheet dédiée exclusivement à `tcpdump`, l'outil de capture de paquets en ligne de commande présent nativement sur la quasi-totalité des systèmes Unix/Linux.

---

## Syntaxe de base & options d'inspection

### Sélection de l'interface

```bash
tcpdump -i eth0                    # Capture sur l'interface eth0
tcpdump -i any                     # Capture sur toutes les interfaces disponibles
tcpdump -D                         # Liste les interfaces disponibles avec leur index
```

### Résolution de noms

```bash
tcpdump -n                         # Désactive la résolution des noms d'hôtes (IP brutes)
tcpdump -nn                        # Désactive aussi la résolution des noms de ports
```

!!! tip "Toujours utiliser -nn en pratique"
    La résolution DNS/services ralentit fortement l'affichage en temps réel et peut générer du trafic DNS parasite dans la capture elle-même. Le réflexe `-nn` doit être quasi systématique.

### Niveaux de verbosité

```bash
tcpdump -v                         # Verbeux : TTL, longueur totale, options IP
tcpdump -vv                        # Très verbeux : détails supplémentaires par protocole
tcpdump -vvv                       # Verbosité maximale, y compris télémétrie applicative
```

### Format de sortie ASCII / Hexadécimal

```bash
tcpdump -A                         # Affiche le contenu des paquets en ASCII
tcpdump -X                         # Affiche en hexadécimal ET ASCII (sans en-têtes liaison)
tcpdump -XX                        # Identique à -X, en incluant l'en-tête de couche liaison
```

!!! tip "Combiner les options"
    Les options courtes se combinent librement : `tcpdump -i eth0 -nn -X` reste parfaitement valide et lisible.

---

## Gestion des fichiers de capture (PCAP)

```bash
tcpdump -i eth0 -w capture.pcap             # Écrit la capture brute dans un fichier .pcap
tcpdump -r capture.pcap                     # Relit un fichier PCAP existant
tcpdump -r capture.pcap -nn tcp             # Relit un fichier en y appliquant un filtre
```

### Limiter le volume capturé

```bash
tcpdump -i eth0 -c 100                      # Capture 100 paquets puis s'arrête (-c = count)
tcpdump -i eth0 -w capture.pcap -C 10       # Découpe en fichiers de 10 Mo (-C = size en Mo)
tcpdump -i eth0 -w capture.pcap -C 10 -W 5  # Limite à 5 fichiers en rotation (-W)
```

!!! tip "Rotation de captures longue durée"
    Sur un poste de surveillance continue, combiner `-C` (taille) et `-W` (nombre de fichiers) évite de saturer le disque tout en conservant un historique glissant.

---

## Filtres BPF (Berkeley Packet Filter)

### Filtres par cible

| Filtre | Description |
|---|---|
| `host 192.168.1.1` | Paquets vers ou depuis cette adresse |
| `src host 192.168.1.1` | Paquets émis uniquement depuis cette adresse |
| `dst host 192.168.1.1` | Paquets à destination uniquement de cette adresse |
| `net 192.168.1.0/24` | Paquets appartenant à ce sous-réseau |
| `port 443` | Paquets sur le port 443 (source ou destination) |
| `src port 53` | Paquets ayant ce port en source uniquement |
| `portrange 8000-8080` | Paquets dont le port appartient à cette plage |

### Filtres par protocole

| Filtre | Description |
|---|---|
| `tcp` | Ne capture que le trafic TCP |
| `udp` | Ne capture que le trafic UDP |
| `icmp` | Ne capture que le trafic ICMP (ping, erreurs réseau) |
| `arp` | Ne capture que le trafic ARP (résolution d'adresses locales) |

### Opérateurs logiques

| Opérateur | Alias | Exemple |
|---|---|---|
| Et | `and` / `&&` | `host 10.0.0.1 and port 22` |
| Ou | `or` / `\|\|` | `port 80 or port 443` |
| Non | `not` / `!` | `tcp and not port 22` |

```bash
tcpdump -i eth0 -nn 'host 10.0.0.5 and port 443'       # Combine cible et port
tcpdump -i eth0 -nn 'tcp and (port 80 or port 443)'    # Parenthèses pour prioriser
tcpdump -i eth0 -nn 'not arp and not icmp'              # Exclut deux protocoles bruyants
```

!!! tip "Guillemets obligatoires"
    Toujours entourer l'expression BPF de guillemets simples lorsqu'elle contient des espaces ou des parenthèses, afin que le shell ne l'interprète pas avant tcpdump.

---

## One-liners utiles (SOC & Pentest)

### Interception HTTP en clair (GET/POST)

```bash
tcpdump -i eth0 -A -nn 'tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'
# Capture les paquets TCP port 80 contenant une charge utile applicative (filtre les ACK vides)

tcpdump -i eth0 -A -s 0 'tcp port 80 and (tcp[((tcp[12] >> 4) * 4)] = 0x47)'
# Isole spécifiquement les requêtes commençant par "G" (GET)
```

!!! warning "Trafic non chiffré uniquement"
    Ces interceptions ne fonctionnent que sur du trafic HTTP en clair. Le trafic HTTPS est chiffré au niveau applicatif et n'exposera pas son contenu, seuls les métadonnées de la poignée de main TLS restent visibles.

### Capture des poignées de main TCP (flags)

```bash
tcpdump -i eth0 -nn 'tcp[tcpflags] & tcp-syn != 0'                 # Isole les paquets SYN
tcpdump -i eth0 -nn 'tcp[tcpflags] & (tcp-syn|tcp-ack) == (tcp-syn|tcp-ack)'  # SYN-ACK uniquement
tcpdump -i eth0 -nn 'tcp[tcpflags] & tcp-fin != 0'                  # Isole les paquets FIN
tcpdump -i eth0 -nn 'tcp[tcpflags] & tcp-rst != 0'                  # Isole les paquets RST
```

!!! tip "Repérer un scan de ports"
    Un grand nombre de paquets SYN sans SYN-ACK correspondant, vers des ports variés et depuis une même source, est un indicateur classique de scan de type `nmap -sS`.

### Capture des requêtes/réponses DNS

```bash
tcpdump -i eth0 -nn -s 0 udp port 53               # Capture tout le trafic DNS (UDP/53)
tcpdump -i eth0 -nn -s 0 -A udp port 53             # Capture DNS avec affichage ASCII
tcpdump -i eth0 -nn 'udp port 53 and udp[10] & 0x80 = 0'   # Isole uniquement les requêtes (pas les réponses)
```

---

## Voir aussi

- Fiche complémentaire : `wireshark.md` pour l'analyse graphique et Tshark
- `man tcpdump` et `man pcap-filter` pour la syntaxe BPF complète
