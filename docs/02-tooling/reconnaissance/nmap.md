# 🛠️ Commande & Outil : nmap

## 1. Description rapide (Rôle et cas d'usage)

**Nmap** (*Network Mapper*) est un outil open-source de découverte réseau et d'audit de sécurité, développé par Gordon Lyon (Fyodor). Il permet d'envoyer des paquets spécialement conçus vers des hôtes cibles et d'analyser les réponses pour déterminer :

- Les hôtes actifs sur un réseau (découverte).
- Les ports ouverts, fermés ou filtrés sur ces hôtes.
- Les services et versions applicatives écoutant sur ces ports.
- Le système d'exploitation et la pile TCP/IP de la cible.
- La présence de règles de filtrage (pare-feu, IDS/IPS).

### Principaux cas d'usage

| Cas d'usage | Description |
|---|---|
| **Cartographie d'infrastructure** | Inventaire exhaustif des hôtes, services et topologie d'un réseau interne ou externe. |
| **Identification de vulnérabilités** | Couplé au NSE (*Nmap Scripting Engine*), détection de failles connues (CVE) sur les services exposés. |
| **Contournement de sécurité (Firewall/IDS)** | Techniques de scan furtif, fragmentation, decoys et spoofing pour évaluer la résistance des dispositifs de filtrage. |
| **Audits de conformité** | Vérification que seuls les services autorisés sont exposés (PCI-DSS, ISO 27001, ANSSI). |
| **Pentesting / Red Teaming** | Phase de reconnaissance active (*enumeration*) dans une méthodologie d'intrusion structurée. |

!!! danger "Cadre légal"
    L'utilisation de Nmap contre des systèmes dont vous n'êtes pas propriétaire ou pour lesquels vous ne disposez pas d'une **autorisation écrite explicite** est illégale dans la quasi-totalité des juridictions (en France : articles 323-1 et suivants du Code pénal — accès et maintien frauduleux dans un STAD). Ne scannez que des périmètres pour lesquels vous avez un mandat clair (pentest contractualisé, CTF, lab personnel).

---

## 2. Syntaxe globale

```bash
nmap [Type(s) de scan] [Options] {Cibles}
```

### Spécification des cibles

| Méthode | Syntaxe | Exemple |
|---|---|---|
| Adresse IP unique | `IP` | `nmap 192.168.1.10` |
| Plage d'adresses | `IP-IP` | `nmap 192.168.1.1-20` |
| Notation CIDR | `IP/masque` | `nmap 10.0.0.0/24` |
| Nom de domaine | `FQDN` | `nmap scanme.nmap.org` |
| Plusieurs cibles | `cible1 cible2 ...` | `nmap 10.0.0.1 10.0.0.5 192.168.1.0/24` |
| Fichier d'entrée | `-iL fichier` | `nmap -iL liste.txt` |
| Exclusion d'hôtes | `--exclude IP1,IP2` | `nmap 10.0.0.0/24 --exclude 10.0.0.5` |
| Exclusion via fichier | `--excludefile fichier` | `nmap 10.0.0.0/24 --excludefile exclus.txt` |
| Cible aléatoire (Internet) | `-iR N` | `nmap -iR 100 -Pn -p 80` |

!!! tip "Fichier de cibles"
    `liste.txt` peut mélanger IP, plages CIDR et noms de domaine, un par ligne. Pratique pour un périmètre de pentest défini par le client.

---

## 3. Découverte d'hôtes (Host Discovery / Ping Scanning)

Avant de scanner les ports, Nmap détermine quels hôtes sont actifs (sauf si `-Pn` est utilisé). La méthode par défaut dépend du contexte réseau (local vs distant).

| Technique | Option | Fonctionnement |
|---|---|---|
| **ARP Ping** | `-PR` | Envoie une requête ARP *who-has*. Défaut automatique sur réseau local (LAN), car ARP est fiable et rapide (pas de filtrage IP possible sur la couche 2). |
| **ICMP Echo** | `-PE` | Envoie un ICMP Echo Request classique (`ping`). Souvent bloqué par les pare-feux modernes. |
| **ICMP Timestamp** | `-PP` | Envoie une requête ICMP Timestamp (type 13). Alternative si Echo est filtré. |
| **ICMP Netmask** | `-PM` | Envoie une requête ICMP Address Mask (type 17). Autre alternative de contournement. |
| **TCP SYN Ping** | `-PS[ports]` | Envoie un paquet TCP avec flag SYN sur les ports indiqués (défaut : 80). Un SYN/ACK ou un RST indique un hôte actif. |
| **TCP ACK Ping** | `-PA[ports]` | Envoie un paquet TCP avec flag ACK. Utile pour passer des pare-feux stateless qui bloquent les SYN entrants mais laissent passer les ACK "de retour". |
| **UDP Ping** | `-PU[ports]` | Envoie un paquet UDP vide. Un ICMP *Port Unreachable* en retour confirme que l'hôte est actif. |

### Désactivation / contrôle de la découverte

```bash
# Ne pas pinguer : traiter toutes les cibles comme étant en ligne
nmap -Pn 10.0.0.0/24

# Découverte seule, sans scan de ports (liste des hôtes actifs)
nmap -sn 10.0.0.0/24
```

### Résolution DNS

| Option | Effet |
|---|---|
| `-n` | Désactive totalement la résolution DNS (accélère fortement les gros scans). |
| `-R` | Force la résolution DNS inverse (reverse) sur toutes les cibles, même celles jugées hors-ligne. |
| `--dns-servers s1,s2` | Spécifie des serveurs DNS personnalisés pour les résolutions. |

!!! tip "Bonne pratique de performance"
    Sur un scan de grande envergure (`/16`, `/8`), toujours ajouter `-n` pour éviter que la résolution DNS ne ralentisse considérablement le scan.

---

## 4. Techniques de Scan de Ports (Port Scanning)

### Sélection des ports

| Option | Effet | Exemple |
|---|---|---|
| `-p <ports>` | Ports spécifiques ou plages | `-p 22,80,443` / `-p 1-1000` |
| `-p T:<ports>,U:<ports>` | Ports mixtes TCP/UDP | `-p T:53,U:53` |
| `-p-` | Scanne l'intégralité des 65535 ports | `nmap -p- 10.0.0.1` |
| `--top-ports N` | Scanne les N ports les plus fréquents (base statistique Nmap) | `--top-ports 100` |
| `-F` | *Fast scan* : les 100 ports les plus communs (raccourci de `--top-ports 100`) | `nmap -F 10.0.0.1` |

### TCP SYN Scan — `-sS` (Stealth / Half-open)

Scan **par défaut** si Nmap est exécuté avec des privilèges root/administrateur.

1. Nmap envoie un paquet `SYN`.
2. Si la cible répond `SYN/ACK` → port **ouvert** → Nmap répond par un `RST` (annule la connexion avant la fin du handshake).
3. Si la cible répond `RST` → port **fermé**.
4. Aucune réponse (ou ICMP unreachable) → port **filtré**.

```bash
nmap -sS 192.168.1.10
```

!!! tip "Pourquoi 'furtif' ?"
    Le handshake TCP n'étant jamais complété, la connexion n'est historiquement pas journalisée par les applications au niveau applicatif (bien que les IDS/IPS modernes le détectent aisément).

### TCP Connect Scan — `-sT`

Effectue un **3-way handshake complet** (`SYN` → `SYN/ACK` → `ACK`) via les appels système standards du système d'exploitation.

```bash
nmap -sT 192.168.1.10
```

!!! warning "Usage sans privilèges"
    Utilisé automatiquement si Nmap ne dispose pas des droits root (impossibilité de forger des paquets bruts). Plus lent que `-sS` et **beaucoup plus facilement journalisé** (logs applicatifs, connexions abouties).

### UDP Scan — `-sU`

```bash
nmap -sU -p 53,67,123,161 192.168.1.10
```

Interprétation des réponses :

| Réponse reçue | Statut du port |
|---|---|
| Réponse applicative UDP | **Ouvert** |
| ICMP type 3, code 3 (*Port Unreachable*) | **Fermé** |
| ICMP type 3, code 1/2/9/10/13 (filtré) | **Filtré** |
| Aucune réponse (timeout) | **Ouvert\|Filtré** (ambigu) |

!!! warning "Lenteur du scan UDP"
    L'UDP étant sans état, l'absence de réponse est ambiguë et nécessite des retransmissions coûteuses en temps. Toujours combiner avec `--top-ports` ou une liste de ports restreinte, sinon le scan peut durer plusieurs heures.

### Scans furtifs et exotiques (basés sur les flags TCP)

Ces scans exploitent le comportement de la RFC 793 : un port **fermé** doit répondre par un `RST`, un port **ouvert** doit **ignorer** un paquet ne contenant pas de flag `SYN`/`ACK`/`RST`. Ils sont inefficaces sur les piles Windows qui ne respectent pas strictement cette RFC (répondent RST à tout).

| Scan | Option | Flags envoyés | Principe |
|---|---|---|---|
| **NULL scan** | `-sN` | Aucun flag | Port ouvert = pas de réponse ; port fermé = RST. |
| **FIN scan** | `-sF` | `FIN` | Idem, avec le flag FIN seul. |
| **Xmas scan** | `-sX` | `FIN, PSH, URG` | Paquet "illuminé comme un sapin de Noël". Même logique. |
| **Maimon scan** | `-sM` | `FIN, ACK` | Exploite un bug de certaines implémentations BSD. |
| **ACK scan** | `-sA` | `ACK` | Ne détermine **pas** ouvert/fermé, mais **filtré/non filtré** — utilisé pour cartographier les règles d'un pare-feu stateless. |
| **Window scan** | `-sW` | `ACK` | Identique à `-sA` mais analyse la taille de la fenêtre TCP (*window size*) retournée pour déduire l'état réel du port sur certains OS. |
| **Custom flags** | `--scanflags` | Personnalisable | Ex : `--scanflags SYNFIN` pour forger une combinaison arbitraire. |

```bash
# Exemple : combinaison NULL scan discret
nmap -sN -p 1-1000 192.168.1.10

# Exemple : cartographie de règles de pare-feu
nmap -sA -p 1-65535 192.168.1.1
```

---

## 5. Furtivité, Performance, Timing et Parallélisation

### Modèles de timing (`-T0` à `-T5`)

| Niveau | Nom | Impact | Cas d'usage |
|---|---|---|---|
| `-T0` | **Paranoid** | 1 paquet toutes les 5 minutes | Évasion IDS maximale, scans sur plusieurs jours |
| `-T1` | **Sneaky** | 1 paquet toutes les 15 secondes | Évasion IDS forte |
| `-T2` | **Polite** | Ralentit pour limiter la charge réseau/cible | Environnements sensibles, faible bande passante |
| `-T3` | **Normal** | Comportement par défaut | Usage standard |
| `-T4` | **Aggressive** | Accélère significativement, suppose un réseau fiable | Pentest sur LAN/Internet stable |
| `-T5` | **Insane** | Vitesse maximale, tolère la perte de précision | Scan de masse, environnement contrôlé |

```bash
nmap -T4 -A 192.168.1.0/24
```

!!! warning "Compromis vitesse / fiabilité"
    `-T5` peut générer de faux négatifs (paquets perdus interprétés comme "filtré") sur des réseaux instables ou congestionnés. `-T0`/`-T1` sont réservés à des scénarios de furtivité extrême et rendent un scan de `/24` potentiellement long de plusieurs heures à plusieurs jours.

### Optimisation fine de la parallélisation

| Option | Rôle |
|---|---|
| `--min-hostgroup <N>` | Nombre minimal d'hôtes scannés en parallèle (par groupe). |
| `--max-hostgroup <N>` | Nombre maximal d'hôtes scannés en parallèle. |
| `--min-parallelism <N>` | Nombre minimal de sondes envoyées en parallèle par hôte. |
| `--max-parallelism <N>` | Nombre maximal de sondes envoyées en parallèle (1 = pas de parallélisation). |
| `--initial-rtt-timeout <temps>` | Timeout initial estimé pour le round-trip time (ex : `500ms`). |
| `--max-rtt-timeout <temps>` | Timeout RTT maximal avant retransmission. |
| `--max-rate <N>` | Nombre maximal de paquets envoyés par seconde (limite le débit). |
| `--min-rate <N>` | Nombre minimal de paquets envoyés par seconde (force la vitesse). |

```bash
# Scan rapide en forçant un débit minimal de paquets
nmap --min-rate 1000 -p- 10.0.0.5

# Scan interne d'un gros réseau avec parallélisation contrôlée
nmap --min-hostgroup 50 --max-parallelism 10 10.0.0.0/16
```

!!! tip "Astuce performance"
    `--min-rate` est souvent plus efficace que `-T5` seul pour accélérer un scan `-p-` sur une cible unique et stable, car il force directement le débit d'émission plutôt que de dépendre d'heuristiques adaptatives.

---

## 6. Contournement de Pare-feu / IDS & Evasion

!!! danger "Détection"
    Les techniques ci-dessous sont détectées par la quasi-totalité des IDS/IPS/EDR modernes correctement configurés (Suricata, Snort, Zeek). Elles restent pertinentes en pentest pour **tester** la robustesse des dispositifs de détection, pas comme garantie d'invisibilité.

### Fragmentation de paquets

```bash
# Fragmente les en-têtes sur plusieurs paquets IP (8 octets par fragment)
nmap -f 192.168.1.10

# Définit une taille de MTU personnalisée (multiple de 8)
nmap --mtu 24 192.168.1.10
```

**Principe :** répartit les données de l'en-tête TCP sur plusieurs petits paquets IP, rendant l'inspection par certains pare-feux/IDS à correspondance de signature plus difficile (nécessite une réassemblage des fragments).

### Decoys (Leurres)

```bash
# Génère 10 IP leurres aléatoires en plus de la vôtre
nmap -D RND:10 192.168.1.10

# Spécifie des leurres précis, ME = position réelle de votre IP dans la séquence
nmap -D 192.168.1.5,192.168.1.6,ME,192.168.1.7 192.168.1.10
```

**Principe :** envoie les sondes depuis plusieurs adresses IP sources simultanément (spoofées), noyant la véritable origine du scan parmi le "bruit" des leurres dans les logs de la cible.

### IP Spoofing

```bash
nmap -S 10.0.0.99 -e eth0 -Pn 192.168.1.10
```

- `-S IP_SOURCE` : usurpe l'adresse IP source des paquets envoyés.
- `-e <interface>` : force l'interface réseau à utiliser (souvent nécessaire avec `-S` car Nmap ne peut pas déduire automatiquement l'interface de sortie).

!!! warning "Limite pratique du spoofing"
    Le spoofing fonctionne pour l'émission, mais les réponses reviendront à l'IP usurpée, pas à vous. Cette technique s'utilise surtout en environnement contrôlé/local ou combinée à un sniffing sur le segment réseau partagé.

### Scan IDLE / Zombie — `-sI`

```bash
nmap -sI zombie_host 192.168.1.10
```

**Principe technique :**

1. L'attaquant identifie un hôte "zombie" **inactif** (peu de trafic) dont l'**IP ID** (champ d'identification IP) s'incrémente de manière prévisible et séquentielle.
2. L'attaquant envoie un SYN/ACK au zombie pour connaître son IP ID actuel.
3. L'attaquant envoie un paquet SYN **spoofé avec l'adresse du zombie** vers la cible réelle.
4. Si le port cible est ouvert, la cible répond SYN/ACK au zombie, qui répond RST (incrémentant son IP ID de +1).
5. L'attaquant re-sonde le zombie : si l'IP ID a incrémenté de +2 (au lieu de +1), le port cible était **ouvert**. Si +1 seulement, le port était **fermé/filtré**.

Ce scan permet de masquer **totalement** l'IP réelle de l'attaquant aux yeux de la cible, qui ne voit que l'IP du zombie.

### Manipulation avancée des paquets

| Option | Rôle |
|---|---|
| `--data-length <N>` | Ajoute N octets de données aléatoires à la fin des paquets pour modifier leur signature/taille. |
| `--source-port <port>` / `-g <port>` | Force un port source spécifique (ex : `-g 53` pour imiter du trafic DNS, souvent whitelisté). |

```bash
# Se faire passer pour du trafic DNS afin de contourner une règle de pare-feu permissive
nmap -g 53 -Pn 192.168.1.10
```

---

## 7. Détection de Services, OS & Traceroute

### Détection de version des services — `-sV`

```bash
nmap -sV 192.168.1.10
```

Nmap envoie des sondes spécifiques et compare les réponses à sa base de signatures (`nmap-service-probes`) pour identifier le logiciel et sa version précise (ex : `Apache httpd 2.4.41`).

| Option | Effet |
|---|---|
| `--version-intensity <0-9>` | Ajuste le niveau d'agressivité des sondes (0 = léger, 9 = exhaustif). Défaut : 7. |
| `--version-light` | Raccourci pour `--version-intensity 2` (rapide, moins précis). |
| `--version-all` | Raccourci pour `--version-intensity 9` (essaie toutes les sondes, plus lent). |

### Détection du système d'exploitation — `-O`

```bash
nmap -O 192.168.1.10
```

Analyse les particularités de la pile TCP/IP (TTL initial, taille de fenêtre TCP, options TCP, gestion des IP ID, réponse aux paquets malformés) et les compare à la base d'empreintes `nmap-os-db`.

```bash
# Force Nmap à proposer la correspondance OS la plus probable même si incertaine
nmap -O --osscan-guess 192.168.1.10
```

!!! warning "Prérequis"
    `-O` nécessite au moins un port ouvert et un port fermé sur la cible pour une empreinte fiable, ainsi que des privilèges root (nécessité de forger des paquets bruts).

### Traceroute intégré

```bash
nmap --traceroute 192.168.1.10
```

Détermine le chemin réseau (les sauts/routeurs) jusqu'à la cible, réutilisant intelligemment les informations déjà collectées pendant le scan (contrairement à `traceroute` classique qui repart de zéro).

### Scan agressif combiné — `-A`

```bash
nmap -A 192.168.1.10
```

Combine automatiquement :

- `-sV` (détection de version)
- `-O` (détection d'OS)
- `--traceroute`
- Scripts NSE de catégorie `default` (équivalent `--script=default`)

!!! danger "Furtivité nulle"
    `-A` est extrêmement bruyant et génère une empreinte facilement détectable par tout IDS. À réserver aux environnements où la furtivité n'est pas un objectif (audit interne assumé, labs).

---

## 8. Nmap Scripting Engine (NSE)

Le NSE permet d'exécuter des scripts écrits en **Lua** pour étendre les capacités de Nmap : détection de vulnérabilités, énumération avancée, voire exploitation légère.

### Catégories de scripts

| Catégorie | Rôle |
|---|---|
| `default` (ou `-sC`) | Scripts sûrs et rapides, exécutés par défaut avec `-A`. |
| `auth` | Tests liés à l'authentification (bypass, comptes par défaut). |
| `vuln` | Détection de vulnérabilités connues (CVE). |
| `exploit` | Tentative d'exploitation active de failles identifiées. |
| `discovery` | Énumération d'informations complémentaires (partages, utilisateurs, etc.). |
| `safe` | Scripts jugés non intrusifs, sans risque de perturber la cible. |
| `brute` | Attaques par force brute sur des services d'authentification. |

### Syntaxe d'utilisation

```bash
# Scripts par défaut
nmap -sC 192.168.1.10

# Catégorie spécifique
nmap --script=vuln 192.168.1.10

# Script nommé précisément
nmap --script=http-title 192.168.1.10

# Plusieurs scripts/catégories combinés
nmap --script=default,vuln,safe 192.168.1.10

# Script personnalisé depuis un fichier local
nmap --script=/chemin/vers/mon_script.nse 192.168.1.10
```

### Passage d'arguments aux scripts

```bash
nmap --script=http-brute --script-args userdb=users.txt,passdb=pass.txt 192.168.1.10
```

### Mise à jour de la base de scripts

```bash
nmap --script-updatedb
```

### Exemples concrets de détection de vulnérabilités

```bash
# Détection de la vulnérabilité EternalBlue (MS17-010 / WannaCry)
nmap --script=smb-vuln-ms17-010 -p445 192.168.1.10

# Détection de Heartbleed (CVE-2014-0160)
nmap --script=ssl-heartbleed -p443 192.168.1.10

# Énumération des partages SMB
nmap --script=smb-enum-shares -p445 192.168.1.10

# Énumération de pages/technologies HTTP
nmap --script=http-enum -p80,443 192.168.1.10

# Scan de vulnérabilités générique sur une cible complète
nmap --script=vuln -p- 192.168.1.10
```

!!! danger "Scripts de catégorie exploit/brute"
    Ces scripts peuvent activement perturber un service en production (déni de service, verrouillage de comptes après plusieurs échecs d'authentification). À n'utiliser que dans une fenêtre de test validée avec le client/l'équipe infra.

---

## 9. Formats de Sortie & Débogage

### Sauvegarde multi-format en une commande

```bash
nmap -oA rapport_scan 192.168.1.0/24
```

Génère simultanément trois fichiers : `rapport_scan.nmap` (normal), `rapport_scan.gnmap` (grepable), `rapport_scan.xml` (XML).

### Formats individuels

| Option | Format | Usage typique |
|---|---|---|
| `-oN <fichier>` | Normal | Lecture humaine, identique à la sortie console. |
| `-oG <fichier>` | Grepable | Parsing rapide via `grep`/`awk`/scripts shell (format historique, en fin de vie). |
| `-oX <fichier>` | XML | Intégration avec des outils tiers (Metasploit, Dradis, conversion HTML via `xsltproc`). |

```bash
nmap -oX rapport.xml 192.168.1.10
xsltproc rapport.xml -o rapport.html
```

### Raison du statut des ports

```bash
nmap --reason 192.168.1.10
```

Ajoute une colonne indiquant précisément pourquoi Nmap a classé un port dans un état donné (ex : `syn-ack` pour ouvert, `reset` pour fermé, `no-response` pour filtré).

### Modes verbeux et débogage

| Option | Effet |
|---|---|
| `-v` | Mode verbeux (affiche la progression). |
| `-vv` | Verbosité maximale. |
| `-d` | Mode debug (informations internes de Nmap). |
| `-dd` | Debug maximal. |
| `--packet-trace` | Trace bas niveau : affiche **chaque paquet** envoyé et reçu (utile pour diagnostiquer un comportement inattendu ou comprendre finement une technique d'évasion). |

```bash
nmap -sS --packet-trace -p80 192.168.1.10
```

---

## 10. Synthèse & Aide-mémoire des One-Liners Utiles

| Scénario | Commande |
|---|---|
| **Recon rapide** (ping + top 100 ports) | `nmap -F 192.168.1.10` |
| **Découverte d'hôtes actifs seule** | `nmap -sn 192.168.1.0/24` |
| **Scan complet tous ports, rapide** | `nmap -p- --min-rate 2000 -T4 192.168.1.10` |
| **Cartographie interne complète** | `nmap -sS -sV -O -A -T4 192.168.1.0/24 -oA rapport_interne` |
| **Scan furtif anti-IDS (lent)** | `nmap -sS -T1 -f --data-length 24 -D RND:15 192.168.1.10` |
| **Scan UDP ciblé** | `nmap -sU --top-ports 20 -T4 192.168.1.10` |
| **Contournement pare-feu via port source 53** | `nmap -Pn -g 53 -p80,443 192.168.1.10` |
| **Détection de vulnérabilités critiques** | `nmap -sV --script=vuln -p- 192.168.1.10` |
| **Scan agressif complet avec export** | `nmap -A -T4 -oA rapport_complet 192.168.1.10` |
| **Cartographie de règles de pare-feu** | `nmap -sA -p1-65535 192.168.1.1` |
| **Scan sans résolution DNS (perf. max)** | `nmap -n -T4 -p- 10.0.0.0/16` |
| **Scan zombie (anonymisation IP)** | `nmap -sI zombie_ip -Pn 192.168.1.10` |

!!! tip "Ordre de priorité recommandé en pentest"
    1. `-sn` pour découvrir les hôtes vivants.
    2. `-F` ou `--top-ports` pour un premier balayage rapide.
    3. `-p-` sur les hôtes d'intérêt pour l'exhaustivité.
    4. `-sV -O` pour l'identification précise des services/OS.
    5. `--script=vuln` pour la détection de failles connues.
    6. Documentation systématique via `-oA`.

!!! danger "Rappel final"
    Toujours confirmer le périmètre d'autorisation (scope) avant tout scan, particulièrement avec `-p-`, `-A` ou les scripts `vuln`/`exploit`, qui peuvent être assimilés à une activité malveillante par les équipes SOC/SIEM de la cible.
