# Cheat Sheet : Gobuster — Fuzzing & Énumération Web / DNS

!!! tip "Usage principal"
    Énumérer des répertoires, fichiers, sous-domaines, virtual hosts et buckets S3 par brute-force de wordlist — l'outil de découverte de surface d'attaque de référence en reconnaissance web.

---

## 1. Syntaxe de base

```bash
# Structure générale
gobuster [mode] [options]

# Modes disponibles
gobuster dir    # énumération de répertoires et fichiers
gobuster dns    # énumération de sous-domaines par résolution DNS
gobuster vhost  # détection de virtual hosts sur une même IP
gobuster s3     # énumération de buckets AWS S3
gobuster fuzz   # fuzzing générique avec le mot-clé FUZZ
```

---

## 2. Énumération de Répertoires & Fichiers (`dir`)

### Commandes de base
```bash
# Scan minimal : URL cible + wordlist
gobuster dir -u http://target.com -w /usr/share/wordlists/dirb/common.txt
```

```bash
# Extensions ciblées : cherche /index.php, /config.bak, /readme.txt...
gobuster dir -u http://target.com -w wordlist.txt -x php,txt,html,json,bak
```

```bash
# Threads parallèles pour accélérer le scan (défaut : 10)
gobuster dir -u http://target.com -w wordlist.txt -t 50
```

### Filtrage par codes de statut HTTP
```bash
# Exclure des codes de réponse de l'affichage (ex: 404 et 403)
gobuster dir -u http://target.com -w wordlist.txt -b 404,403
```

```bash
# N'afficher que des codes de statut précis
gobuster dir -u http://target.com -w wordlist.txt -s 200,301,302
```

### Personnalisation des requêtes
```bash
# Ajouter un header personnalisé (ex: token Bearer pour une API authentifiée)
gobuster dir -u http://target.com -w wordlist.txt -H "Authorization: Bearer eyJhbG..."
```

```bash
# Passer un cookie de session pour scanner une zone authentifiée
gobuster dir -u http://target.com -w wordlist.txt -c "PHPSESSID=abc123; role=admin"
```

```bash
# Spoofing du User-Agent (imiter un navigateur pour contourner un WAF basique)
gobuster dir -u http://target.com -w wordlist.txt -a "Mozilla/5.0 (Windows NT 10.0)"
```

```bash
# Ignorer les erreurs de certificat SSL/TLS (cibles avec certificat auto-signé)
gobuster dir -u https://target.com -w wordlist.txt -k
```

```bash
# Proxy les requêtes vers Burp Suite pour analyser le trafic en parallèle
gobuster dir -u http://target.com -w wordlist.txt --proxy http://127.0.0.1:8080
```

### Synthèse — Flags du mode `dir`

| Flag | Rôle |
| --- | --- |
| `-u URL` | URL cible |
| `-w FILE` | Wordlist à utiliser |
| `-x EXT` | Extensions à tester (sans point, séparées par virgule) |
| `-t N` | Nombre de threads parallèles (défaut : 10) |
| `-b CODES` | Codes HTTP à exclure de l'affichage |
| `-s CODES` | Codes HTTP à afficher uniquement |
| `-H "Header: val"` | Header HTTP personnalisé |
| `-c "cookie=val"` | Cookie de session |
| `-a "User-Agent"` | User-Agent personnalisé |
| `-k` | Ignore les erreurs de certificat SSL/TLS |
| `--proxy URL` | Redirige le trafic vers un proxy (Burp Suite...) |
| `-o FILE` | Sauvegarde les résultats dans un fichier |
| `--timeout N` | Timeout par requête en secondes |
| `-r` | Suit les redirections HTTP |

!!! tip "Wordlists recommandées"
    - `/usr/share/wordlists/dirb/common.txt` — discovery rapide (4 600 entrées)
    - `/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt` — découverte approfondie (220 000 entrées)
    - `/usr/share/seclists/Discovery/Web-Content/raft-large-files.txt` — focus fichiers (SecLists)
    - `/usr/share/seclists/Discovery/Web-Content/api/objects.txt` — endpoints API REST

---

## 3. Énumération de Sous-domaines (`dns`)

```bash
# Résolution DNS par brute-force : teste sub.target.com, mail.target.com...
gobuster dns -d target.com -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
```

```bash
# Utiliser un serveur DNS spécifique pour la résolution (évite les caches locaux)
gobuster dns -d target.com -w wordlist.txt -r 8.8.8.8
```

```bash
# Afficher les IPs résolues en plus des noms (--show-ips)
gobuster dns -d target.com -w wordlist.txt --show-ips
```

### Synthèse — Flags du mode `dns`

| Flag | Rôle |
| --- | --- |
| `-d DOMAIN` | Domaine racine cible |
| `-w FILE` | Wordlist de sous-domaines à tester |
| `-r IP` | Serveur DNS à utiliser pour la résolution |
| `--show-ips` | Affiche les adresses IP résolues |
| `-t N` | Nombre de threads |

---

## 4. Énumération de Virtual Hosts (`vhost`)

```bash
# Détecte des VHosts en envoyant chaque entrée de la wordlist comme valeur du header "Host:"
gobuster vhost -u http://target.com -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
```

```bash
# Filtrer les faux positifs : exclure les réponses d'une taille précise (réponse "par défaut")
gobuster vhost -u http://target.com -w wordlist.txt --exclude-length 1831
```

```bash
# Ajouter les noms testés au domaine de base (nécessaire avec les versions récentes de Gobuster)
gobuster vhost -u http://target.com -w wordlist.txt --append-domain
```

!!! tip "vhost vs dns : quelle différence ?"
    Le mode `dns` résout les sous-domaines via le DNS public (le sous-domaine doit exister dans le DNS). Le mode `vhost` envoie chaque entrée de la wordlist dans le **header HTTP `Host:`** — il découvre des applications accessibles sur la même IP mais non publiées en DNS (staging, admin, dev...) et qui ne répondraient jamais à une requête DNS.

---

## 5. Buckets S3 & Fuzzing générique

### Énumération de buckets AWS S3 (`s3`)
```bash
# Cherche des buckets S3 publics : teste bucket.s3.amazonaws.com pour chaque entrée
gobuster s3 -w wordlist.txt
```

```bash
# Combiner avec une wordlist orientée noms d'entreprises/projets pour des résultats ciblés
gobuster s3 -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -t 50
```

### Fuzzing générique (`fuzz`)
```bash
# FUZZ est remplacé par chaque entrée de la wordlist (peut cibler n'importe quelle partie de l'URL)
gobuster fuzz -u "http://target.com/api/v1/FUZZ" -w wordlist.txt
```

```bash
# Fuzzing de paramètres GET
gobuster fuzz -u "http://target.com/index.php?page=FUZZ" -w wordlist.txt -b 404
```

---

## 6. Matrice Comparative des Modes

| Critère | `dir` | `dns` | `vhost` |
| --- | --- | --- | --- |
| **Cible principale** | Fichiers et dossiers | Sous-domaines DNS | Virtual Hosts HTTP non publiés |
| **Mécanisme** | Requêtes HTTP GET par chemin | Résolution DNS du nom complet | Header HTTP `Host:` modifié |
| **DNS requis** | Non | Oui (le sous-domaine doit exister) | Non |
| **Besoin réseau** | HTTP/HTTPS | DNS (UDP 53) | HTTP/HTTPS |
| **Faux positifs typiques** | Codes 403 retournés pour tout | NXDOMAIN sur wildcards DNS | Taille de réponse identique pour toutes les requêtes |
| **Contre-mesure typique** | Filtrer avec `-b 403` | `-r` pour éviter les caches | `--exclude-length` sur la taille par défaut |
| **Wordlist conseillée** | `directory-list-medium.txt` | `subdomains-top1million.txt` | `subdomains-top1million.txt` |
