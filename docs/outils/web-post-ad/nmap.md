# Cheat Sheet : Nmap — Reconnaissance, Détection & Évasion

!!! tip "Usage principal"
    Scanner des hôtes, détecter des services/versions/OS et identifier des vulnérabilités via NSE — l'outil de reconnaissance réseau de référence en pentest comme en audit défensif.

---

## 1. Syntaxe de base

```bash
# Structure générale
nmap [type de scan] [options] [cible]

# Cibles : IP, CIDR, plage, nom d'hôte, fichier
nmap 192.168.1.1
nmap 192.168.1.0/24
nmap 192.168.1.1-50
nmap scanme.nmap.org
nmap -iL cibles.txt        # lit les cibles depuis un fichier
```

---

## 2. Découverte d'Hôtes (Host Discovery)

```bash
nmap -sn 192.168.1.0/24    # ping scan : découvre les hôtes sans scanner les ports
nmap -Pn 192.168.1.10      # désactive le ping ICMP, scan les ports même si l'hôte semble mort
nmap -PR 192.168.1.0/24    # découverte ARP (rapide sur LAN, pas d'ICMP)
```

!!! tip "-Pn sur cibles protégées"
    Les hôtes sous Windows ou derrière un firewall bloquent souvent ICMP → Nmap les considère éteints par défaut. `-Pn` force le scan des ports quoi qu'il arrive, au prix d'une durée plus longue sur les plages larges.

---

## 3. Types de Scans de Ports

```bash
nmap -sS 192.168.1.10      # TCP SYN (Half-Open) : furtif, rapide, root requis
nmap -sT 192.168.1.10      # TCP Connect : complet, sans root, plus visible dans les logs
nmap -sU 192.168.1.10      # UDP : lent, utile pour DNS/SNMP/NTP/TFTP
nmap -sN 192.168.1.10      # NULL : aucun flag TCP — contourne certains firewalls
nmap -sF 192.168.1.10      # FIN : flag FIN uniquement
nmap -sX 192.168.1.10      # Xmas : FIN + PSH + URG — contourne certains firewalls
nmap -sA 192.168.1.10      # ACK : ne détecte pas les ports ouverts, mais les règles firewall
```

### Comparaison des types de scans

| Type | Flag | Root | Furtivité | Cas d'usage |
| --- | --- | --- | --- | --- |
| TCP SYN | `-sS` | Oui | Moyenne | Référence pentest — rapide et semi-furtif |
| TCP Connect | `-sT` | Non | Faible | Sans root, laisse des traces dans les logs |
| UDP | `-sU` | Oui | Faible | Détection DNS, SNMP, NTP, TFTP |
| NULL | `-sN` | Oui | Bonne | Bypass firewall stateless, inefficace sur Windows |
| FIN | `-sF` | Oui | Bonne | Idem NULL |
| Xmas | `-sX` | Oui | Bonne | Idem NULL — tous flags offensifs |
| ACK | `-sA` | Oui | Bonne | Cartographie des règles firewall (filtré vs non filtré) |

---

## 4. Contrôle des Ports & Timing

### Ports scannés
```bash
nmap -p 80 192.168.1.10          # port unique
nmap -p 80,443,8080 192.168.1.10 # liste de ports
nmap -p 1-1024 192.168.1.10      # plage de ports
nmap -p- 192.168.1.10            # tous les 65535 ports
nmap --top-ports 1000 192.168.1.10  # top 1000 ports les plus courants (défaut)
```

### Vitesse et timing (`-T0` à `-T5`)
| Profil | Alias | Usage |
| --- | --- | --- |
| `-T0` | Paranoid | IDS evasion maximum, très lent |
| `-T1` | Sneaky | Discret, lent |
| `-T2` | Polite | Réduit la charge réseau |
| `-T3` | Normal | Défaut |
| `-T4` | Aggressive | Rapide, environnements fiables |
| `-T5` | Insane | Maximum, bruyant, risque de pertes |

```bash
nmap -T4 --min-rate 1000 -p- 192.168.1.10   # scan complet rapide avec débit minimum garanti
```

---

## 5. Détection de Services, OS & Scripts NSE

### Détection de version et d'OS
```bash
nmap -sV 192.168.1.10       # détecte les versions des services en écoute
nmap -O 192.168.1.10        # détecte l'OS de la cible (root requis)
nmap -A 192.168.1.10        # mode agressif : -sV + -O + traceroute + scripts par défaut
```

### Nmap Scripting Engine (NSE)
```bash
nmap --script=default 192.168.1.10           # scripts de la catégorie "default"
nmap --script=vuln 192.168.1.10              # recherche de vulnérabilités connues
nmap --script=safe 192.168.1.10              # uniquement scripts non intrusifs
nmap --script=auth 192.168.1.10              # test d'authentification (comptes par défaut)
nmap --script=exploit 192.168.1.10           # tentatives d'exploitation (très intrusif)
```

### Scripts NSE ciblés par protocole

```bash
# HTTP : identification du serveur, méthodes autorisées, répertoires
nmap --script=http-headers,http-methods,http-title -p 80,443 192.168.1.10
```

```bash
# SMB : énumération des partages et utilisateurs
nmap --script=smb-enum-shares,smb-enum-users -p 445 192.168.1.10
```

```bash
# SMB : détection de vulnérabilité EternalBlue (MS17-010)
nmap --script=smb-vuln-ms17-010 -p 445 192.168.1.10
```

```bash
# SSH : algorithmes supportés, bannière
nmap --script=ssh2-enum-algos,ssh-hostkey -p 22 192.168.1.10
```

```bash
# FTP : accès anonyme, bannière
nmap --script=ftp-anon,ftp-banner -p 21 192.168.1.10
```

```bash
# DNS : brute-force de sous-domaines
nmap --script=dns-brute target.com
```

### Catégories NSE de référence

| Catégorie | Contenu | Intrusif ? |
| --- | --- | --- |
| `default` | Scripts courants équilibrés (inclus dans `-A`) | Non |
| `safe` | Scripts sans impact sur la cible | Non |
| `auth` | Test de credentials par défaut | Modéré |
| `vuln` | Détection de vulnérabilités connues | Modéré |
| `exploit` | Tentatives d'exploitation | Oui |
| `brute` | Brute-force d'authentification | Oui |
| `discovery` | Énumération étendue de services | Non |

---

## 6. Techniques d'Évasion (Bypass Firewall / IDS / IPS)

```bash
nmap -f 192.168.1.10            # fragmentation des paquets en 8 octets (contourne certains IDS)
nmap -f -f 192.168.1.10         # fragmentation en 16 octets
nmap -D RND:5 192.168.1.10      # leurres : génère 5 IPs sources aléatoires + la vraie
nmap -D 10.0.0.1,10.0.0.2,ME 192.168.1.10  # leurres précis avec position de la vraie IP
nmap -S 10.0.0.5 -e eth0 192.168.1.10      # spoofing d'IP source (réponses perdues sans routage)
nmap --source-port 53 192.168.1.10          # port source 53 (DNS) : souvent autorisé en sortie
nmap --data-length 25 192.168.1.10          # ajoute 25 octets de padding aléatoire aux paquets
nmap --randomize-hosts 192.168.1.0/24       # scanne les hôtes dans un ordre aléatoire
```

!!! warning "Évasion ≠ Invisibilité totale"
    Les techniques d'évasion Nmap réduisent la probabilité de détection par des systèmes **stateless** ou mal configurés. Un IDS/IPS moderne (Snort, Suricata) avec des règles à jour détecte les scans fragmentés, les leurres (`-D`) et les scans lents (`-T0`) via corrélation temporelle. En environnement réel, combiner `-T2`, `--source-port 53`, `-f` et `-D` reste de la discrétion, pas de la furtivité totale.

---

## 7. Sorties & Formats

```bash
nmap -oN scan.txt 192.168.1.10   # format texte normal (lisible)
nmap -oX scan.xml 192.168.1.10   # format XML (parsable par outils tiers)
nmap -oG scan.gnmap 192.168.1.10 # format Grepable (analyse rapide avec grep/awk)
nmap -oA scan 192.168.1.10       # génère les 3 formats simultanément (scan.nmap + .xml + .gnmap)
```

### Parsing rapide du format Grepable
```bash
# Extraire uniquement les hôtes avec des ports ouverts
grep "open" scan.gnmap
```

```bash
# Extraire les IPs des hôtes actifs
grep "Up" scan.gnmap | cut -d " " -f 2
```

```bash
# Extraire les ports ouverts d'un hôte spécifique
grep "192.168.1.10" scan.gnmap | grep -oP '\d+/open'
```

---

## 8. Matrice des Flags & Profils de Scans Terrain

### Matrice récapitulative des flags essentiels

| Flag | Rôle |
| --- | --- |
| `-sS` / `-sT` / `-sU` | Type de scan (SYN / Connect / UDP) |
| `-sN` / `-sF` / `-sX` | Scans furtifs (NULL / FIN / Xmas) |
| `-sn` | Découverte d'hôtes sans scan de ports |
| `-Pn` | Désactive le ping (traite l'hôte comme actif) |
| `-p-` | Scanne les 65535 ports |
| `--top-ports N` | Scanne les N ports les plus courants |
| `-sV` | Détection de version des services |
| `-O` | Détection de l'OS |
| `-A` | Mode complet : version + OS + scripts + traceroute |
| `--script=CAT` | Exécute une catégorie de scripts NSE |
| `-T0` à `-T5` | Profil de timing (lenteur ↔ vitesse) |
| `--min-rate N` | Garantit un débit minimum de N paquets/seconde |
| `-f` | Fragmentation des paquets |
| `-D RND:N` | Génère N leurres d'IPs aléatoires |
| `--source-port N` | Spoofing du port source |
| `-oA fichier` | Export dans les 3 formats simultanément |
| `-iL fichier` | Lit les cibles depuis un fichier |
| `-v` / `-vv` | Verbosité (voir les résultats en temps réel) |

### Profils de scans types terrain

```bash
# SCAN RAPIDE : top 1000 ports, détection de version, scripts par défaut
nmap -sV -sC -T4 192.168.1.10

# SCAN COMPLET : 65535 ports, puis scan approfondi sur les ports ouverts (en deux passes)
nmap -p- --min-rate 5000 -T4 192.168.1.10 -oG all_ports.gnmap
ports=$(grep open all_ports.gnmap | grep -oP '\d+/open' | cut -d/ -f1 | tr '\n' ',')
nmap -sV -sC -O -p $ports 192.168.1.10 -oA scan_complet

# SCAN FURTIF : SYN, timing lent, port source DNS, pas de ping
nmap -sS -T2 --source-port 53 -Pn -f 192.168.1.10
```

!!! warning "Nmap sans autorisation explicite = infraction"
    Scanner un réseau ou un système sans autorisation préalable écrite est **illégal** dans la plupart des juridictions (CFAA aux États-Unis, article 323-1 du Code pénal en France). Toujours opérer dans le périmètre d'un accord de pentest signé ou sur une infrastructure dont vous êtes propriétaire.
