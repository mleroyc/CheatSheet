# Cheat Sheet : OWASP Top 10 (2021) — Audit & Méthodologie Web

!!! tip "Usage principal"
    Référence méthodologique pour l'audit de sécurité web — identification, exploitation et remédiation des 10 catégories de vulnérabilités les plus critiques selon l'OWASP.

---

## Référence Rapide — OWASP Top 10 2021

| Rang | Catégorie | Vecteur principal |
| --- | --- | --- |
| **A01** | Broken Access Control | IDOR, élévation de privilèges, bypass de verbes HTTP |
| **A02** | Cryptographic Failures | Protocoles clairs, MD5/SHA1, TLS faible |
| **A03** | Injection | SQLi, XSS, Command Injection, SSTI |
| **A04** | Insecure Design | Logique métier défaillante, absence de threat modeling |
| **A05** | Security Misconfiguration | Headers manquants, `.env` exposé, erreurs verbeuses |
| **A06** | Vulnerable & Outdated Components | CMS/bibliothèques non patchés, CVE connues |
| **A07** | Identification & Auth Failures | Bruteforce, MFA absent, session fixation |
| **A08** | Software & Data Integrity Failures | CI/CD compromise, dépendances non vérifiées |
| **A09** | Security Logging & Monitoring Failures | Absence de logs, pas d'alertes sur incidents |
| **A10** | Server-Side Request Forgery (SSRF) | Requêtes internes forgées vers `169.254.169.254` |

---

## A01 — Broken Access Control

### IDOR (Insecure Direct Object Reference)
```bash
# Tester la manipulation directe d'identifiants dans les paramètres
# Changer l'ID dans l'URL pour accéder à un objet appartenant à un autre utilisateur
GET /api/user/profile?user_id=1001   # utilisateur légitime
GET /api/user/profile?user_id=1000   # → données d'un autre utilisateur accessibles ?
```

```bash
# IDOR dans les paramètres POST (à tester via Burp Suite → Repeater)
POST /api/orders/details
{"order_id": "4521"}   # → remplacer par l'ID d'une commande d'un autre utilisateur
```

```bash
# IDOR dans les chemins de fichiers ou noms prévisibles
GET /documents/rapport_2024_alice.pdf   # → remplacer par rapport_2024_bob.pdf ?
GET /api/invoices/10042                 # → itérer sur 10041, 10040...
```

### Contrôle d'accès vertical / horizontal
```
Accès horizontal  : un utilisateur A accède aux ressources d'un utilisateur B (même rôle)
                    → tester chaque objet avec un second compte de même niveau

Accès vertical    : un utilisateur non-admin accède à des fonctions admin
                    → tester les endpoints /admin/, /api/admin/, /manage/ sans être connecté en admin
```

```bash
# Tester les endpoints admin directement sans token admin (accès non authentifié)
curl -s http://target.com/admin/users
curl -s http://target.com/api/v1/admin/settings -H "Authorization: Bearer <token_user_normal>"
```

### Bypass via verbes HTTP
```bash
# Si GET /admin est bloqué, tester d'autres verbes HTTP (le contrôle peut ne couvrir que GET)
curl -X POST http://target.com/admin/delete-user -d "id=5"
curl -X PUT http://target.com/api/ressource/42 -d '{"role":"admin"}'
curl -X DELETE http://target.com/api/user/1001
```

!!! tip "Checklist A01 en audit"
    - Tester tous les paramètres numériques et identifiants (URL, POST body, headers)
    - Rejouer les requêtes d'un utilisateur A avec le token d'un utilisateur B (Burp → Autorize extension)
    - Essayer tous les verbes HTTP sur chaque endpoint (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS)
    - Tester l'accès aux fonctions admin avec un compte non-privilégié

---

## A02 — Cryptographic Failures

### Protocoles obsolètes et stockage non sécurisé
```bash
# Détecter les services en clair sur le réseau (scan Nmap)
nmap -p 21,23,80 --open target.com   # FTP(21), Telnet(23), HTTP(80) en clair
```

```bash
# Identifier des mots de passe hashés non salés dans une fuite ou une DB exposée
# MD5 (32 hex) → crackable facilement via hashcat / tables arc-en-ciel
echo -n "password" | md5sum           # → 5f4dcc3b5aa765d61d8327deb882cf99

# SHA-1 (40 hex) → également obsolète et vulnérable
echo -n "password" | sha1sum          # → 5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8
```

### Analyse TLS/SSL
```bash
# sslyze : audit des suites de chiffrement, protocoles supportés, vulnérabilités connues
sslyze target.com:443
sslyze --early_data --robot target.com:443   # test ROBOT (RSA key exchange oracle)
```

```bash
# testssl.sh : équivalent open-source complet (protocoles, ciphers, BEAST, POODLE, Heartbleed...)
./testssl.sh target.com:443
./testssl.sh --severity HIGH target.com:443   # n'affiche que les problèmes HIGH et CRITICAL
```

### Points de contrôle clés

| Vérification | Signal de vulnérabilité |
| --- | --- |
| Protocole HTTP (pas HTTPS) | Trafic en clair interceptable |
| TLS 1.0 / TLS 1.1 supportés | Protocoles dépréciés (RFC 8996) |
| Certificat auto-signé | Pas de validation d'identité |
| Cipher suite RC4 / DES / 3DES | Chiffrement cassé |
| Mots de passe stockés en MD5/SHA1 | Crackables via rainbow tables |
| Absence de salt sur les hashs | Attaques par tables précalculées |

---

## A05 — Security Misconfiguration & Information Disclosure

### Fichiers et répertoires sensibles exposés
```bash
# Tester l'accès aux fichiers de configuration et backups classiques
curl -s http://target.com/.env             # variables d'environnement (DB_PASS, API_KEY...)
curl -s http://target.com/.git/config      # dépôt Git exposé (reconstruction du code source)
curl -s http://target.com/backup.bak       # backup de fichier de config
curl -s http://target.com/robots.txt       # chemins exclus → souvent des zones intéressantes
curl -s http://target.com/web.config       # config IIS (Windows)
curl -s http://target.com/phpinfo.php      # infos PHP version, config serveur
```

```bash
# Reconstruction d'un dépôt Git exposé (outil dédié)
git-dumper http://target.com/.git/ ./recovered_repo
```

### Directory Indexing (Listing de répertoires)
```bash
# Si le serveur liste le contenu d'un dossier → navigation libre dans les fichiers
curl -s http://target.com/uploads/         # → liste tous les fichiers uploadés ?
curl -s http://target.com/backup/          # → backups accessibles publiquement ?
```

### En-têtes de sécurité manquants
```bash
# Inspecter les headers de réponse HTTP pour les directives de sécurité absentes
curl -sI http://target.com | grep -iE "hsts|csp|x-frame|x-content|referrer"
```

| Header de sécurité | Rôle | Absence = risque |
| --- | --- | --- |
| `Strict-Transport-Security` (HSTS) | Force HTTPS sur le navigateur | Downgrade HTTP possible |
| `Content-Security-Policy` (CSP) | Contrôle les sources de scripts/ressources | XSS facilité |
| `X-Frame-Options` | Bloque l'intégration dans des iframes | Clickjacking |
| `X-Content-Type-Options: nosniff` | Empêche le MIME sniffing | Exécution de fichiers mal typés |
| `Referrer-Policy` | Contrôle les infos dans l'en-tête Referer | Fuite d'URLs internes |
| `Permissions-Policy` | Restreint l'accès aux APIs navigateur (caméra, GPS...) | Abus de fonctionnalités |

### Informations exposées via erreurs et headers serveur
```bash
# Headers révélant la stack technique (versions = surface CVE connue)
curl -sI http://target.com | grep -iE "server|x-powered-by|x-aspnet"
# Server: Apache/2.4.49 → CVE-2021-41773 (Path Traversal/RCE) si non patché
# X-Powered-By: PHP/7.2.0 → version obsolète, vulnérabilités connues
```

```bash
# Provoquer des erreurs pour obtenir des infos de stack (stack traces, chemins absolus)
curl -s "http://target.com/page?id='"      # injection de quote → erreur SQL verbose ?
curl -s "http://target.com/page?id[]=1"    # type inattendu → erreur PHP verbose ?
```

!!! warning "Information Disclosure — Impact souvent sous-estimé"
    Un `.env` exposé contenant `DATABASE_URL`, `AWS_SECRET_KEY` ou `STRIPE_SECRET` représente une compromission **immédiate et totale** de l'infrastructure, souvent sans aucune exploitation technique supplémentaire. Un `.git` exposé permet de reconstruire tout le code source et d'y chercher des secrets, de la logique métier vulnérable ou des endpoints cachés — automatisable en quelques secondes avec `git-dumper`.
