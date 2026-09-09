---
title: "Reconnaissance Active vs Passive : Méthodologies, Outils et Détection"
description: "Fiche synthétique et technique couvrant la distinction entre reconnaissance active et passive, l'OSINT, le transfert de métadonnées, l'utilisation du navigateur web et des outils CLI d'énumération."
tags:
  - recon
  - osint
  - active-recon
  - passive-recon
  - footprinting
  - redteam
  - blueteam
  - dns
  - whois
  - shodan
  - certificate-transparency
---

# Reconnaissance Active vs Passive : Méthodologies, Outils et Détection

!!! warning "Cadre légal"
    La reconnaissance active génère du trafic vers des systèmes tiers. Sans autorisation écrite préalable du propriétaire du système cible, même un simple scan de port ou un `ping` peut constituer un accès non autorisé à un système informatique, passible de poursuites pénales. Toujours opérer dans le cadre d'un accord de pentest signé ou sur une infrastructure dont vous êtes propriétaire.

---

## 1. Résumé Exécutif & Définition

### Comparaison fondamentale

| Critère | Reconnaissance Passive | Reconnaissance Active |
| --- | --- | --- |
| **Interaction cible** | Aucun contact direct — sources publiques uniquement | Contact direct avec l'infrastructure cible |
| **Traces côté cible** | Zéro log généré chez la cible | Trafic réseau loggable par WAF, IDS/IPS, CDN |
| **Détectabilité** | Indétectable par la cible | Détectable et potentiellement bloquable |
| **Légalité** | Toujours légale (sources publiques) | Illégale sans autorisation sur des systèmes tiers |
| **Volume d'informations** | Limité aux données publiquement accessibles | Plus précis, couvre ports ouverts, services, versions |
| **Durée** | Peut durer des semaines sans risque | Fenêtre réduite pour limiter l'exposition |
| **Outils** | WHOIS, crt.sh, Shodan, Google Dorks | nmap, netcat, curl, dig, traceroute |

### Tension Red Team / Blue Team

**Perspective Red Team — Discrétion offensive :**

- Se fondre dans le trafic légitime : User-Agents réalistes (navigateurs actuels), espacer les requêtes pour imiter un comportement humain, utiliser le navigateur plutôt que des outils CLI identifiables.
- Prioriser la reconnaissance passive en phase initiale : collecter un maximum d'informations sans générer de signal, puis limiter la reconnaissance active au strict nécessaire, sur des plages horaires à faible surveillance (nuits/week-ends en UTC selon la localisation de la cible).
- Distribuer les sources d'énumération : utiliser des résolveurs DoH publics, des VPN/proxies tournants, des Tor exit nodes pour fragmenter les corrélations IP → source.

**Perspective Blue Team — Détection précoce :**

- Les phases de reconnaissance active précèdent systématiquement une attaque : un scan de ports, un banner grab ou une énumération de sous-domaines détectés tôt permettent d'anticiper et de durcir avant l'exploitation.
- Surveiller l'exposition externe propre : si un attaquant trouve vos sous-domaines via `crt.sh` ou Shodan, vous devriez les avoir trouvés avant lui via les mêmes outils.
- Analyser les logs WAF/CDN pour les patterns de sonde : rafales de 404 sur des chemins prévisibles, scans de ports répétés depuis une IP, comportements d'énumération DNS.

---

## 2. Vecteurs & Sources de Reconnaissance Passive (OSINT)

### 2.1 Registres & DNS Publics

#### WHOIS & RDAP

```bash
# WHOIS classique — interrogation du port 43/TCP
whois example.com

# Filtrer les informations clés (registrar, dates, nameservers)
whois example.com | grep -iE "registrar|created|expires|name server|tech|admin"

# WHOIS sur une IP (ASN, organisation propriétaire du bloc)
whois 93.184.216.34
```

```bash
# RDAP (Registration Data Access Protocol) — remplace progressivement WHOIS
# Format JSON structuré via HTTPS — post-2025 ICANN
curl -s "https://rdap.verisign.com/com/v1/domain/example.com" | jq '.entities[].vcardArray'

# RDAP pour une IP
curl -s "https://rdap.arin.net/registry/ip/93.184.216.34" | jq '{name: .name, org: .entities[0].vcardArray}'
```

!!! note "Masquage RGPD / Privacy Protection"
    Depuis le RGPD (2018) et les politiques ICANN, la majorité des WHOIS de domaines `.com`/`.net` ne retournent plus d'informations personnelles sur les registrants. Pour les enquêtes sur des domaines anciens ou des TLD moins stricts (`.io`, `.co`, etc.), les données peuvent encore être disponibles. L'historique WHOIS est disponible via **Whoxy** (`https://www.whoxy.com`) ou **DomainIQ**.

```bash
# Consulter l'historique WHOIS via l'API Whoxy
curl "https://api.whoxy.com/?key=API_KEY&history=example.com" | jq '.whois_records[] | {date: .create_date, registrant_email: .registrant_contact.email_address}'
```

#### Enregistrements DNS

```bash
# Requête DNS ciblée — record A (IPv4)
dig example.com A +short

# Tous les enregistrements visibles
dig example.com ANY +noall +answer

# Enregistrements mail (MX)
dig example.com MX +short

# Enregistrements SPF (TXT) — révèle les services email utilisés
dig example.com TXT +short | grep -i "spf"
# Exemple : "v=spf1 include:mailchimp.com include:sendgrid.net ~all"
# → révèle l'usage de Mailchimp et SendGrid comme infrastructure email

# Enregistrements DKIM — révèle les sélecteurs et les services email
dig google._domainkey.example.com TXT +short

# DMARC — politique anti-spoofing
dig _dmarc.example.com TXT +short
```

!!! tip "SPF / DKIM / DMARC comme vecteur OSINT"
    Les enregistrements TXT révèlent souvent l'intégralité de la stack email : serveurs SMTP internes, fournisseurs SaaS (Salesforce, HubSpot, Mailchimp, SendGrid, Google Workspace, Microsoft 365). Ces informations orientent les phases de phishing et d'usurpation d'identité email.

```bash
# DoH (DNS over HTTPS) — masquer ses requêtes DNS aux FAI et équipements réseau intermédiaires
# Cloudflare DoH
curl -s "https://cloudflare-dns.com/dns-query?name=example.com&type=A" \
  -H "Accept: application/dns-json" | jq '.Answer[].data'

# Google DoH
curl -s "https://dns.google/resolve?name=example.com&type=MX" | jq '.Answer[].data'
```

### 2.2 Découverte de Sous-domaines & Certificate Transparency

#### Certificate Transparency Logs (CT Logs)

Les navigateurs modernes exigent que tout certificat TLS/SSL public soit journalisé dans des registres publics transparents. Ces registres — consultables sans authentification — révèlent tous les sous-domaines couverts par le champ **SAN** (*Subject Alternative Names*) du certificat.

```bash
# crt.sh — requête sur les CT logs pour un domaine
curl -s "https://crt.sh/?q=%.example.com&output=json" | \
  jq -r '.[].name_value' | sort -u | grep -v "^\*"

# Filtrer les sous-domaines avec wildcards exclus
curl -s "https://crt.sh/?q=%.example.com&output=json" | \
  jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u
```

```bash
# Subfinder — outil d'énumération passive multi-sources (CT logs, SecurityTrails, VirusTotal...)
subfinder -d example.com -silent -o subdomains.txt

# Résoudre les sous-domaines découverts pour identifier les actifs
cat subdomains.txt | while read sub; do
    ip=$(dig +short "$sub" A | head -1)
    [ -n "$ip" ] && echo "$sub -> $ip"
done
```

!!! tip "CT Logs — source passive la plus riche pour les sous-domaines"
    Les CT Logs sont **exhaustifs et rétroactifs** : ils contiennent tous les certificats émis depuis ~2013. Un sous-domaine de staging, une API interne avec certificat public, un accès VPN exposé temporairement — s'ils ont eu un certificat TLS public, ils apparaissent dans `crt.sh`, même s'ils ne sont plus accessibles aujourd'hui.

### 2.3 Moteurs de Recherche Spécialisés

#### Shodan.io & Censys.io

```bash
# Shodan CLI — recherche par organisation
shodan search "org:\"Example Corp\"" --fields ip_str,port,banner

# Filtres Shodan courants
# hostname:example.com          → Services sur un domaine
# org:"Example Corporation"     → Tous les actifs d'une organisation
# port:8080                     → Services sur un port spécifique
# country:FR                    → Filtrer par pays
# http.component:WordPress      → Identifier les CMS et frameworks
# ssl.cert.subject.cn:example.com → Certificats associés
# product:Apache                 → Filtrer par produit

# Recherche d'interfaces d'administration exposées
shodan search "hostname:example.com port:8443,8080,9090,3000"
```

```bash
# Censys.io — recherche via API
curl -s "https://search.censys.io/api/v2/hosts/search" \
  -u "API_ID:API_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"q":"parsed.names: example.com", "per_page": 25}' | \
  jq '.result.hits[] | {ip: .ip, services: [.services[].port]}'
```

#### Google Dorks — OSINT via les moteurs de recherche

```bash
# Découvrir des sous-domaines et des pages indexées
site:example.com

# Fichiers sensibles exposés par index de répertoire
site:example.com ext:xml OR ext:conf OR ext:ini OR ext:env OR ext:log

# Fichiers de configuration et identifiants
site:example.com ext:sql OR ext:db OR ext:bak

# Pages de login et interfaces d'administration
site:example.com intitle:"admin" OR intitle:"login" OR inurl:"/admin"

# Informations de version révélées dans les pages
site:example.com intext:"Apache/2." OR intext:"nginx/1."
```

#### GitHub & Dépôts Publics

```bash
# Recherches GitHub pour des fuites de secrets
# Via GitHub search web :
# "example.com" password OR secret OR token OR api_key language:python
# "example.com" DB_PASSWORD OR DATABASE_URL

# Avec truffleHog — scan d'un dépôt public pour secrets
trufflehog git https://github.com/org/repo --only-verified

# Avec gitleaks
gitleaks detect --source /path/to/cloned/repo --report-format json
```

!!! danger "GitHub — source critique de fuites de credentials"
    Les développeurs commettent régulièrement des clés API, des credentials de base de données, des certificats privés et des tokens AWS directement dans des dépôts publics — parfois supprimés rapidement, mais capturés par des crawlers automatisés. Les dépôts *fork* et l'historique Git conservent les secrets même après suppression du commit.

#### Ressources métier & Emploi comme vecteur OSINT

```bash
# LinkedIn — identifier la stack technique via les profils de développeurs et d'administrateurs
# Recherche : "example corp" + "AWS" + "Kubernetes" + "Terraform"
# → révèle le cloud provider, les outils DevOps, les frameworks utilisés

# Offres d'emploi — la source la plus riche sur la stack technique interne
# Une offre "DevOps Engineer — Ansible, Terraform, AWS, GitLab CI" révèle :
# → Cloud provider, IaC tool, CI/CD platform, version control
# Les exigences de certifications révèlent les produits (Cisco, Palo Alto, CrowdStrike...)

# Builtwith.com — empreinte technologique via les balises HTML/JS analysées à l'indexation
curl -s "https://api.builtwith.com/v21/api.json?KEY=API_KEY&LOOKUP=example.com" | \
  jq '.Results[0].Result.Paths[0].Technologies[] | .Name'
```

---

## 3. Vecteurs & Méthodes de Reconnaissance Active

### 3.1 Le Navigateur Web comme Outil de Reconnaissance

Le navigateur est l'**outil de reconnaissance active le moins suspicieux** : il génère du trafic strictement identique à celui d'un utilisateur légitime, avec les mêmes User-Agents, les mêmes protocoles (HTTP/2, HTTP/3), les mêmes patterns de requêtes multiressources.

#### HTTP/3 et QUIC — Implications réseau

```
HTTP/3 utilise QUIC comme couche transport :
  - QUIC = protocole basé sur UDP/443 (contrairement à HTTP/1.1 et HTTP/2 sur TCP)
  - Combine transport + chiffrement TLS 1.3 en un seul handshake
  - Réduit la latence et améliore la résistance aux coupures réseau
  - Impact Blue Team : les firewalls filtrant UDP/443 bloquent HTTP/3 mais pas forcément HTTP/2

curl --http3 -s -I https://example.com 2>/dev/null | head -5
```

#### DevTools — Inspection en profondeur

```
Ouverture DevTools :
  Chrome / Firefox Linux/Windows : Ctrl+Shift+I
  Chrome / Firefox macOS         : Cmd+Option+I
  Firefox raccourci alternatif   : F12
```

**Onglet Sources / Debugger :**
```javascript
// Rechercher des endpoints API dans les fichiers JavaScript bundlés
// Dans la console DevTools :
// 1. Ouvrir Sources → chercher les fichiers .js bundlés (main.js, chunk.*.js)
// 2. Beautifier le code (icône {} en bas à gauche)
// 3. Ctrl+F pour chercher :
//    - "api/" → endpoints API
//    - "http://" ou "https://" → URLs hardcodées
//    - "Bearer" ou "token" → patterns d'authentification
//    - "secret" ou "key" → fuites potentielles
```

**Onglet Application :**
```
Cookies        → tokens de session, CSRF tokens, drapeaux HttpOnly/Secure/SameSite
LocalStorage   → clés API, tokens JWT stockés côté client (mauvaise pratique courante)
SessionStorage → données temporaires de session
IndexedDB      → bases de données client potentiellement riches en données sensibles
Cache Storage  → ressources mises en cache, peut révéler des endpoints API utilisés hors ligne
```

**Onglet Security :**
```
Certificat TLS → champ Subject Alternative Names (SAN) : autres sous-domaines couverts
              → Validity period, CA émettrice
              → Certificate Transparency logs link
```

#### Extensions de reconnaissance

| Extension | Rôle | Utilisation |
| --- | --- | --- |
| **FoxyProxy** | Gestion multi-proxy | Basculer entre Burp Suite, ZAP, Tor selon la phase |
| **Wappalyzer** | Détection de stack | CMS, frameworks, analytics, serveurs web — en un coup d'œil |
| **User-Agent Switcher** | Usurpation d'UA | Contourner les filtres WAF/CDN qui bloquent certains UAs |
| **uBlock Origin** | Filtrage de requêtes | Analyser les requêtes sortantes et les traceurs tiers |

### 3.2 Sondes Réseau et Énumération CLI

#### ping — Joignabilité et inférence d'OS

```bash
# Ping IPv4 basique — 4 paquets
ping -c 4 example.com

# Ping avec intervalle réduit (0.2s) pour une mesure rapide de la latence
ping -c 10 -i 0.2 example.com

# Ping IPv6
ping6 -c 4 example.com
# ou
ping -6 -c 4 example.com

# Ping silencieux (pour les scripts — exit code 0 si joignable)
ping -c 1 -W 1 example.com &>/dev/null && echo "UP" || echo "DOWN"
```

!!! tip "Inférence d'OS via le TTL de réponse"
    Le TTL initial d'une réponse ICMP donne un indice sur l'OS cible :
    
    | TTL reçu | OS probable |
    | --- | --- |
    | 64 | Linux / macOS / équipements réseau modernes |
    | 128 | Windows |
    | 255 | Cisco IOS / équipements réseau Cisco |
    
    Le TTL diminue de 1 à chaque saut réseau. Calculer le TTL initial : `TTL_reçu + nombre_de_sauts` (obtenable via `traceroute`).

!!! warning "ICMP souvent filtré"
    Un `ping` sans réponse ne signifie pas que l'hôte est éteint — beaucoup d'hôtes Windows, de firewalls et de CDN bloquent ICMP par politique. Compléter avec `curl -I https://target.com` ou `nmap -sT -Pn -p 80,443 target.com`.

#### traceroute / tracert / mtr — Cartographie du chemin réseau

```bash
# traceroute standard (Linux) — utilise UDP par défaut, mode ICMP avec -I
traceroute -n example.com         # -n : pas de résolution DNS (plus rapide)
traceroute -I -n example.com      # mode ICMP (passe mieux les firewalls)
traceroute -T -p 443 -n example.com  # mode TCP SYN sur port 443 (contourne les filtres UDP)

# tracert (Windows)
tracert -d example.com            # -d : pas de résolution DNS

# mtr — combinaison traceroute + ping, vue dynamique et statistiques par saut
mtr -n example.com                # mode interactif
mtr -n -r -c 20 example.com      # rapport non interactif, 20 cycles
```

!!! tip "traceroute pour identifier les WAF, CDN et load balancers"
    Un traceroute qui "disparaît" à quelques sauts de la cible avec des IPs appartenant à Akamai, Cloudflare, Fastly ou Imperva indique un CDN/WAF en frontal. Les IPs du CDN sont ainsi connues, mais l'IP d'origine peut rester masquée. Chercher l'IP d'origine via `crt.sh`, DNS historique ou `Shodan` (le serveur d'origine est souvent exposé directement sur un autre port ou IP).

#### Banner Grabbing — netcat et telnet

```bash
# netcat — connexion brute à un port TCP pour lire la bannière du service
nc -vn 93.184.216.34 22     # SSH — révèle version OpenSSH
nc -vn 93.184.216.34 25     # SMTP — révèle le MTA et sa version
nc -vn 93.184.216.34 21     # FTP — révèle le serveur FTP et sa version
nc -vn 93.184.216.34 80     # HTTP — envoyer ensuite : HEAD / HTTP/1.0\r\n\r\n

# Banner grabbing HTTP via netcat (manuel)
echo -e "HEAD / HTTP/1.0\r\nHost: example.com\r\n\r\n" | nc -vn 93.184.216.34 80

# netcat en IPv6
nc -6 -vn 2606:2800:220:1::93 80

# telnet — alternative à nc, plus explicite sur les erreurs de connexion
telnet example.com 80
telnet example.com 443
```

#### curl — Banner Grabbing HTTP discret et propre

```bash
# Récupérer uniquement les headers HTTP (méthode HEAD — moins visible dans les logs)
curl -sI https://example.com

# Headers complets avec détail TLS (très verbeux — utile pour l'analyse)
curl -sv https://example.com 2>&1 | grep -E "^\*|^<|^>"

# Identifier les headers révélateurs de stack technique
curl -sI https://example.com | grep -iE "server:|x-powered-by:|x-generator:|via:|cf-ray:|x-amz"
# Server: Apache/2.4.41 (Ubuntu) → Apache 2.4.41 sur Ubuntu
# X-Powered-By: PHP/7.4.3       → PHP 7.4.3
# X-Generator: Drupal 9          → CMS Drupal version 9
# CF-Ray: ...                    → Cloudflare CDN en frontal
# X-Amz-Cf-Id: ...               → AWS CloudFront CDN

# Tester si un chemin est accessible (code de retour + taille)
curl -sI https://example.com/admin | head -5
curl -sI https://example.com/.git/config | head -5

# Forcer HTTP/1.1 pour éviter HTTP/2 et réduire le fingerprint de l'outil
curl --http1.1 -sI https://example.com
```

#### dig & nslookup — Résolution DNS ciblée

```bash
# dig — outil de référence, sortie précise et complète
dig example.com A +short               # IPv4 uniquement
dig example.com AAAA +short            # IPv6 uniquement
dig example.com MX +noall +answer      # Serveurs mail
dig example.com NS +short              # Serveurs DNS autoritaires
dig example.com TXT +short             # Enregistrements TXT (SPF, DKIM, DMARC)
dig example.com SOA +short             # Start of Authority (admin email, serial)

# Interroger un serveur DNS précis (bypass du cache local)
dig @8.8.8.8 example.com A +short     # Via Google DNS
dig @1.1.1.1 example.com MX +short    # Via Cloudflare DNS

# Reverse DNS (PTR)
dig -x 93.184.216.34 +short

# Tentative de transfert de zone (reconnaissance passive/active limite)
dig axfr @ns1.example.com example.com

# nslookup — disponible sur Linux et Windows, moins précis mais universel
nslookup example.com                   # Résolution basique
nslookup -type=MX example.com         # Type spécifique
nslookup example.com 8.8.8.8          # Via serveur DNS précis
```

#### Scans plus agressifs (reconnaissance active franche)

```bash
# Nmap — scan de ports, détection de services et OS
# Scan SYN (semi-ouvert, plus discret) sur les ports courants
nmap -sS -T2 --top-ports 1000 example.com

# Scan de détection de services et versions
nmap -sV -sC -T3 -p 80,443,8080,8443 example.com

# Scan complet tous ports avec détection OS
nmap -sV -O -p- --min-rate 1000 example.com

# masscan — scan de ports ultra-rapide (bruyant — éviter sur des cibles non autorisées)
masscan -p 80,443,8080,22,21 --rate=1000 93.184.216.0/24

# gobuster — énumération de répertoires et de fichiers
gobuster dir -u https://example.com -w /usr/share/wordlists/dirb/common.txt -t 20

# ffuf — fuzzing de répertoires/paramètres
ffuf -u https://example.com/FUZZ -w /usr/share/wordlists/dirb/common.txt -mc 200,301,302
```

!!! danger "Scans actifs = traces permanentes"
    Nmap, masscan et les outils de fuzzing génèrent des milliers de requêtes identifiables et sont systématiquement détectés et logués par les WAF, IDS/IPS et CDN modernes. En pentest, utiliser des options de ralentissement (`-T2`, `--min-rate`) et distribuer l'origine. En dehors d'un cadre contractuel, leur utilisation contre des systèmes tiers est une infraction pénale.

---

## 4. Tableau Synthétique de Référence Rapide

### 4.1 Commandes CLI de reconnaissance

| Outil | Commande | Résultat attendu |
| --- | --- | --- |
| **ping** | `ping -c 4 example.com` | Joignabilité, RTT, TTL (inférence OS) |
| **ping IPv6** | `ping -6 -c 4 example.com` | Joignabilité IPv6 |
| **traceroute** | `traceroute -n example.com` | Chemin réseau, nombre de sauts |
| **traceroute ICMP** | `traceroute -I -n example.com` | Idem, passe mieux les firewalls |
| **traceroute TCP** | `traceroute -T -p 443 -n target.com` | Chemin via TCP/443, contourne les filtres UDP |
| **tracert (Windows)** | `tracert -d example.com` | Équivalent traceroute Windows |
| **mtr rapport** | `mtr -n -r -c 20 example.com` | Statistiques de perte/latence par saut |
| **telnet** | `telnet example.com 80` | Connexion brute TCP, bannière |
| **netcat client** | `nc -vn 93.184.216.34 22` | Bannière SSH/SMTP/FTP |
| **netcat listener** | `nc -lvnp 4444` | Écoute entrante (reverse shell/transfert) |
| **netcat IPv6** | `nc -6 -vn ::1 80` | Connexion TCP en IPv6 |
| **curl headers** | `curl -sI https://example.com` | Headers HTTP (Server, X-Powered-By...) |
| **curl verbose TLS** | `curl -sv https://example.com` | Détail TLS, certificat, headers complets |
| **dig A** | `dig example.com A +short` | Adresse IPv4 |
| **dig MX** | `dig example.com MX +short` | Serveurs mail |
| **dig TXT** | `dig example.com TXT +short` | SPF, DKIM, DMARC |
| **dig @DNS ciblé** | `dig @8.8.8.8 example.com A` | Bypass cache local |
| **dig reverse** | `dig -x 93.184.216.34 +short` | PTR — nom d'hôte depuis IP |
| **nslookup** | `nslookup -type=MX example.com` | Résolution DNS (Windows/Linux) |
| **whois domaine** | `whois example.com` | Registrar, dates, nameservers |
| **whois IP** | `whois 93.184.216.34` | ASN, organisation, bloc IP |
| **RDAP** | `curl "https://rdap.verisign.com/com/v1/domain/example.com"` | Données registre JSON structuré |
| **crt.sh** | `curl -s "https://crt.sh/?q=%.example.com&output=json"` | Sous-domaines via CT Logs |

### 4.2 Raccourcis DevTools par OS

| Action | Chrome/Firefox Linux | Chrome/Firefox Windows | Chrome/Firefox macOS |
| --- | --- | --- | --- |
| Ouvrir DevTools | `Ctrl+Shift+I` | `Ctrl+Shift+I` | `Cmd+Option+I` |
| Ouvrir Console | `Ctrl+Shift+J` | `Ctrl+Shift+J` | `Cmd+Option+J` |
| Raccourci universel | `F12` | `F12` | `F12` |
| Inspecter élément | `Ctrl+Shift+C` | `Ctrl+Shift+C` | `Cmd+Shift+C` |
| Vue Sources | `Ctrl+Shift+P` puis "Sources" | `Ctrl+Shift+P` puis "Sources" | `Cmd+Shift+P` puis "Sources" |
| Recherche dans tous les fichiers | `Ctrl+Shift+F` | `Ctrl+Shift+F` | `Cmd+Option+F` |

### 4.3 Sources OSINT passives essentielles

| Source | URL | Utilisation |
| --- | --- | --- |
| **crt.sh** | `https://crt.sh/?q=%.example.com` | Sous-domaines via CT Logs |
| **Shodan** | `https://shodan.io` | Services/ports exposés, banners |
| **Censys** | `https://search.censys.io` | Inventaire Internet, certificats |
| **DNSDumpster** | `https://dnsdumpster.com` | Cartographie DNS graphique |
| **SecurityTrails** | `https://securitytrails.com` | Historique DNS, sous-domaines |
| **Whoxy** | `https://whoxy.com` | Historique WHOIS |
| **BuiltWith** | `https://builtwith.com` | Stack technique via les headers |
| **Wayback Machine** | `https://web.archive.org` | Pages archivées, endpoints historiques |
| **Hunter.io** | `https://hunter.io` | Emails de l'organisation |
| **Have I Been Pwned** | `https://haveibeenpwned.com/api` | Comptes exposés dans des fuites |
| **VirusTotal** | `https://virustotal.com` | Sous-domaines, IPs associées, réputation |
| **FOFA** | `https://fofa.info` | Moteur de recherche Internet (style Shodan) |

---

## 5. Recommandations Blue Team & Hardening

### 5.1 Surveillance de l'exposition externe

```bash
# Automatiser la recherche de sous-domaines via CT Logs (à lancer régulièrement)
curl -s "https://crt.sh/?q=%.example.com&output=json" | \
  jq -r '.[].name_value' | sort -u > ct_subdomains_$(date +%F).txt

# Comparer avec l'inventaire connu et alerter sur les nouveaux sous-domaines
diff known_subdomains.txt ct_subdomains_$(date +%F).txt | grep "^>" | \
  awk '{print "NOUVEAU SOUS-DOMAINE DETECTE:", $2}'

# Vérifier sa propre présence sur Shodan
shodan search "org:\"Mon Organisation\"" --fields ip_str,port,banner | \
  grep -vE "80|443"  # Alerter sur les services exposés hors HTTP/HTTPS standard
```

### 5.2 Analyse des logs pour détecter la reconnaissance active

```bash
# Détecter les scans de ports dans les logs de firewall
# Critère : une même IP source touchant plus de N ports différents en moins de 60 secondes
awk '{print $1, $6}' /var/log/firewall.log | \
  awk -F'[ :]' '{print $1, $4}' | \
  sort | uniq -c | sort -nr | head -20

# Détecter les comportements d'énumération dans les logs Apache/Nginx
# Critère : une même IP avec un ratio élevé de 404/400/403
awk '$9 ~ /^(404|403|400)$/ {print $1}' /var/log/nginx/access.log | \
  sort | uniq -c | sort -nr | head -20

# Détecter les User-Agents de scanners connus
grep -iE "(nmap|masscan|zgrab|nikto|dirbuster|sqlmap|python-requests|go-http-client|curl/|wget/)" \
  /var/log/nginx/access.log | awk '{print $1, $6, $7}' | head -20
```

### 5.3 Réduction de la surface d'exposition

| Mesure | Impact sur la reconnaissance |
| --- | --- |
| **Supprimer les headers révélateurs** | `Server: Apache/2.4.49` → `Server: Apache` ou suppression totale — élimine la version de la détection passive |
| **Supprimer `X-Powered-By`** | Masque le langage et sa version (PHP, ASP.NET...) |
| **Mettre en place un CDN/WAF** | Masque l'IP d'origine, filtre les scans actifs, logue les tentatives |
| **Politique RDAP/WHOIS privacy** | Activer la protection du registrant pour masquer les informations d'enregistrement |
| **Auditer les CT Logs régulièrement** | Détecter les sous-domaines non intentionnellement publiés |
| **Centraliser les logs** | Aggréger WAF + firewall + applicatif → corrélations possibles pour détecter les reconnaissances distribuées |
| **Alertes Shodan/Censys sur son ASN** | Services exposés non intentionnellement détectés avant un attaquant |
| **Politique Referrer-Policy** | `Referrer-Policy: no-referrer` — empêche la fuite de l'URL interne vers des tiers via les navigateurs |

!!! tip "Principe de l'adversarial exposure monitoring"
    La meilleure défense contre la reconnaissance passive est d'effectuer régulièrement soi-même cette reconnaissance contre sa propre infrastructure : `crt.sh`, Shodan, `dnsdumpster`, GitHub search. Ce que vous trouvez, un attaquant le trouvera aussi — mais vous avec une longueur d'avance pour corriger.
