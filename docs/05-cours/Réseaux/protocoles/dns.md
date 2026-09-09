# Le protocole DNS — théorie et configuration

Cheat sheet sur le fonctionnement du DNS (Domain Name System), son architecture, ses enregistrements et sa configuration côté système Linux.

---

## Architecture & mécanisme de résolution

### Arborescence DNS

Le DNS est structuré en arbre hiérarchique inversé, chaque niveau étant délégué au suivant.

```text
.                     # Root — la racine, représentée par un point implicite
├── .com               # TLD générique
│   └── domain.com          # Domaine enregistré
│       └── www.domain.com  # Sous-domaine
├── .fr                # TLD national (ccTLD)
│   └── exemple.fr
└── .org, .net, .io    # Autres TLD
```

!!! info "Le point final"
    Un nom de domaine pleinement qualifié (FQDN) se termine techniquement par un point : `www.domain.com.`. Ce point représente la racine et est généralement omis par confort dans l'usage courant.

### Résolution récursive vs itérative

Deux rôles coexistent dans une résolution DNS complète :

- **Requête récursive** : le client demande au résolveur une réponse finale et complète. Le résolveur se charge de tout le travail.
- **Requête itérative** : le résolveur interroge successivement chaque serveur de la chaîne, chacun renvoyant soit la réponse, soit l'adresse du serveur suivant à contacter.

```text
Client → Cache local (OS/navigateur) → cache miss
       → Resolver (FAI, 8.8.8.8, 1.1.1.1...)
             ├──▶ Root Server ('.')      → adresse du TLD
             ├──▶ TLD Server ('.com')    → adresse du serveur autoritaire
             └──▶ Authoritative Server   → réponse finale (IP, MX...)
       → Réponse renvoyée au client (mise en cache selon le TTL)
```

!!! info "Rôle du TTL"
    Chaque enregistrement possède un TTL (Time To Live, en secondes) qui détermine sa durée de mise en cache. Un TTL court facilite les changements rapides (bascule d'infrastructure) mais augmente la charge sur les serveurs autoritaires.

---

## Types d'enregistrements DNS

| Type | Nom complet | Rôle | Exemple de valeur |
|---|---|---|---|
| `A` | Address | Associe un nom à une adresse IPv4 | `192.0.2.10` |
| `AAAA` | IPv4 Address (v6) | Associe un nom à une adresse IPv6 | `2001:db8::1` |
| `CNAME` | Canonical Name | Alias vers un autre nom de domaine | `www` → `domain.com` |
| `MX` | Mail Exchange | Désigne le(s) serveur(s) de messagerie, avec priorité | `10 mail.domain.com` |
| `NS` | Name Server | Indique les serveurs faisant autorité sur la zone | `ns1.domain.com` |
| `TXT` | Text | Stocke des données arbitraires (SPF, DKIM, DMARC, validations) | `v=spf1 include:_spf... ~all` |
| `PTR` | Pointer | Résolution inverse, IP vers nom (zone `in-addr.arpa`) | `10.2.0.192.in-addr.arpa` |
| `SOA` | Start of Authority | Décrit la zone : serveur primaire, contact, TTL par défaut, numéro de série | — |

!!! info "TXT et sécurité mail"
    Trois mécanismes anti-spoofing s'appuient sur les TXT : **SPF** (serveurs autorisés à envoyer), **DKIM** (signature cryptographique) et **DMARC** (politique appliquée en cas d'échec SPF/DKIM).

---

## Enregistrements TXT : SPF, DKIM, DMARC et vérification de domaine

Les enregistrements `TXT` servent de vecteur universel pour publier des métadonnées
machine-lisibles dans le DNS. Les trois mécanismes d'authentification email et la preuve
de propriété de domaine reposent tous sur ce type d'enregistrement.

### SPF — Sender Policy Framework

**Rôle :** déclarer publiquement quels serveurs sont autorisés à envoyer des emails au nom
d'un domaine. Le serveur destinataire vérifie que l'IP de l'expéditeur figure dans la
politique SPF du domaine d'envoi, extraite du champ `MAIL FROM` de l'enveloppe SMTP.

**Emplacement dans le DNS :** enregistrement `TXT` à la racine du domaine (`domain.com`).

```dns
; Anatomie d'un enregistrement SPF complet et annoté
domain.com.   3600   IN   TXT   "v=spf1 ip4:203.0.113.0/24 ip6:2001:db8::/32 include:_spf.google.com mx -all"
;                                 │       │                   │                  │                       │  │
;                                 │       │                   │                  │                       │  └─ Qualificateur : hard fail (tout autre serveur est rejeté)
;                                 │       │                   │                  │                       └─ Mécanisme catch-all (toujours en dernier)
;                                 │       │                   │                  └─ Délègue à la politique SPF de Google Workspace
;                                 │       │                   └─ Plage IPv6 autorisée
;                                 │       └─ Plage IPv4 autorisée
;                                 └─ Version obligatoire (toujours v=spf1)
```

**Mécanismes disponibles :**

| Mécanisme | Description | Exemple |
|---|---|---|
| `ip4:` | Adresse ou plage IPv4 autorisée | `ip4:192.0.2.0/24` |
| `ip6:` | Adresse ou plage IPv6 autorisée | `ip6:2001:db8::/48` |
| `mx` | Serveurs MX du domaine autorisés à émettre | `mx` |
| `a` | Enregistrements A/AAAA du domaine | `a:mail.domain.com` |
| `include:` | Inclut la politique SPF d'un autre domaine | `include:_spf.mailgun.org` |
| `redirect=` | Délègue entièrement la politique à un autre domaine | `redirect=_spf.domain.com` |
| `all` | Capture-tout — doit toujours être le dernier mécanisme | `~all` |

**Qualificateurs (préfixent chaque mécanisme) :**

| Qualificateur | Signification | Comportement du serveur destinataire |
|---|---|---|
| `+` | Pass (défaut si omis) | Serveur autorisé → email accepté |
| `-` | Fail (Hard Fail) | Serveur non autorisé → email **rejeté** |
| `~` | SoftFail | Serveur suspect → accepté mais marqué (dossier spam) |
| `?` | Neutral | Pas de politique → traitement à la discrétion du destinataire |

!!! warning "Limite des 10 résolutions DNS"
    La spécification SPF (RFC 7208) impose un maximum de **10 résolutions DNS** lors de
    l'évaluation d'une politique. Chaque `include:`, `a:`, `mx:` ou `redirect=` compte pour 1.
    Au-delà, l'évaluation échoue avec le statut `PermError`, ce qui peut faire rejeter des
    emails légitimes par les serveurs les plus stricts.

!!! warning "SPF ne protège pas l'en-tête `From:` visible"
    SPF vérifie uniquement l'adresse `MAIL FROM` de l'enveloppe SMTP (le *Return-Path*,
    invisible pour l'utilisateur final), pas l'en-tête `From:` affiché dans le client mail.
    Un attaquant peut donc usurper le `From:` visible tout en passant SPF. C'est pourquoi
    **SPF seul est insuffisant** contre le phishing : il doit être combiné avec DKIM et DMARC.

---

### DKIM — DomainKeys Identified Mail

**Rôle :** signer cryptographiquement les emails sortants afin que le serveur destinataire
puisse vérifier que le message n'a pas été altéré en transit et qu'il provient d'un serveur
autorisé par le domaine.

**Mécanisme en deux temps :**

```text
ENVOI (côté serveur émetteur)
  ├─ Calcule un hash des en-têtes et du corps sélectionnés (From, Subject, Date, Body…)
  ├─ Chiffre ce hash avec la clé privée DKIM stockée sur le serveur d'envoi
  └─ Ajoute l'en-tête DKIM-Signature: au message avant transmission

RÉCEPTION (côté serveur destinataire)
  ├─ Lit DKIM-Signature: pour identifier le domaine (d=) et le sélecteur (s=)
  ├─ Interroge le DNS : [sélecteur]._domainkey.[domaine] → récupère la clé publique
  ├─ Déchiffre la signature avec cette clé publique
  └─ Compare le hash recalculé au hash signé → correspondance = signature valide
```

**Emplacement dans le DNS :** enregistrement `TXT` à `[sélecteur]._domainkey.domain.com`.

```dns
; Le sélecteur (ici "mail2026") permet de gérer plusieurs clés simultanément :
; rotation de clés ou clés distinctes par service d'envoi (Mailchimp, SendGrid…)

mail2026._domainkey.domain.com.   3600   IN   TXT   "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w..."
;                                                      │         │       │
;                                                      │         │       └─ Clé publique RSA encodée en Base64
;                                                      │         └─ Type de clé : rsa (ou ed25519 pour les clés modernes)
;                                                      └─ Version obligatoire (DKIM1)
```

**Tags de l'enregistrement DKIM :**

| Tag | Signification | Valeurs courantes |
|---|---|---|
| `v=` | Version du protocole | `DKIM1` (obligatoire) |
| `k=` | Type de clé cryptographique | `rsa` (défaut), `ed25519` (recommandé) |
| `p=` | Clé publique encodée en Base64 | Générée par l'administrateur |
| `t=` | Flags optionnels | `y` (mode test), `s` (sous-domaines exclus) |
| `h=` | Algorithmes de hash acceptés | `sha256` (obligatoire, `sha1` déprécié) |

**En-tête `DKIM-Signature:` inséré dans chaque email signé :**

```text
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;
  d=domain.com; s=mail2026;
  h=From:To:Subject:Date:Message-ID:Content-Type;
  bh=uXWNQR5BMa5W/A3JdKGmrw1nGnkLOfZkSTVKFTCQ89Q=;
  b=ZkStyUn...base64_de_la_signature...

; d=  : domaine signataire (utilisé pour interroger le bon enregistrement DNS)
; s=  : sélecteur (retrouver la bonne clé parmi plusieurs publiées)
; h=  : liste des en-têtes inclus dans la signature (modifiés → signature invalide)
; bh= : hash du corps du message (body hash)
; b=  : signature cryptographique proprement dite
```

!!! tip "Sélecteurs et rotation de clés"
    Le **sélecteur** permet de publier plusieurs clés DKIM simultanément sous un même domaine.
    Cela facilite la **rotation de clés** (publier la nouvelle avant de retirer l'ancienne) et
    l'attribution de **clés distinctes par service d'envoi** — une clé pour Mailchimp, une pour
    SendGrid, une pour le serveur interne — sans qu'elles s'interfèrent.

!!! warning "DKIM n'authentifie pas l'adresse `From:` visible"
    DKIM garantit l'**intégrité** du contenu et l'**authenticité du domaine signataire** (`d=`),
    mais pas que ce domaine correspond au `From:` affiché à l'utilisateur. Cette vérification
    d'alignement est précisément le rôle de DMARC.

---

### DMARC — Domain-based Message Authentication, Reporting, and Conformance

**Rôle :** définir la politique appliquée par les serveurs destinataires lorsqu'un email
échoue les contrôles SPF et/ou DKIM, et recevoir des rapports agrégés sur l'authentification
de tous les emails émis au nom du domaine.

**DMARC apporte deux notions absentes de SPF et DKIM pris isolément :**

1. **L'alignement** : vérifie que le domaine authentifié par SPF ou DKIM correspond bien
   à l'en-tête `From:` affiché à l'utilisateur — la surface visible d'une usurpation d'identité.
2. **La politique d'action** : indique explicitement au destinataire quoi faire en cas d'échec,
   là où SPF et DKIM ne fournissent qu'un résultat sans l'imposer.

**Emplacement dans le DNS :** enregistrement `TXT` à `_dmarc.domain.com`.

```dns
_dmarc.domain.com.   3600   IN   TXT   "v=DMARC1; p=reject; sp=quarantine; pct=100; adkim=s; aspf=r; rua=mailto:dmarc@domain.com; ruf=mailto:forensics@domain.com; fo=1"
;                                        │          │           │              │        │         │       │                            │
;                                        │          │           │              │        │         │       │                            └─ Rapports forensiques (un par email non conforme)
;                                        │          │           │              │        │         │       └─ Rapports agrégés (résumés quotidiens en XML)
;                                        │          │           │              │        │         └─ Alignement SPF : r=relaxed (sous-domaines acceptés)
;                                        │          │           │              │        └─ Alignement DKIM : s=strict (domaine exact requis)
;                                        │          │           │              └─ 100 % des messages soumis à la politique
;                                        │          │           └─ Politique pour les sous-domaines : quarantine
;                                        │          └─ Politique principale : reject (emails non conformes rejetés par SMTP 5xx)
;                                        └─ Version obligatoire (DMARC1)
```

**Tags DMARC et leurs valeurs :**

| Tag | Signification | Valeurs possibles | Défaut |
|---|---|---|---|
| `v=` | Version | `DMARC1` | — (obligatoire) |
| `p=` | Politique principale | `none` / `quarantine` / `reject` | — (obligatoire) |
| `sp=` | Politique pour les sous-domaines | `none` / `quarantine` / `reject` | Hérite de `p=` |
| `pct=` | % de messages soumis à la politique | `0` – `100` | `100` |
| `adkim=` | Alignement DKIM | `r` (relaxed) / `s` (strict) | `r` |
| `aspf=` | Alignement SPF | `r` (relaxed) / `s` (strict) | `r` |
| `rua=` | URI des rapports agrégés (résumés quotidiens XML) | `mailto:...` | — |
| `ruf=` | URI des rapports forensiques (détail par email) | `mailto:...` | — |
| `fo=` | Options de rapport forensique | `0` (les deux échouent) / `1` (l'un ou l'autre) / `d` / `s` | `0` |

**Les trois politiques DMARC :**

```text
p=none
  → Mode observation : aucune action sur les emails non conformes.
    Ils sont livrés normalement. Les rapports agrégés sont collectés.
    À utiliser lors du déploiement initial pour cartographier tous les flux d'envoi.

p=quarantine
  → Mode intermédiaire : les emails non conformes sont acceptés mais classés
    en spam ou mis en quarantaine chez le destinataire.
    Politique de transition, une fois les flux légitimes identifiés.

p=reject
  → Mode maximal : les emails non conformes sont rejetés à la réception
    (code SMTP 5xx — aucune livraison, même en dossier spam).
    Politique recommandée en production, une fois tous les flux maîtrisés.
```

**Alignement SPF et DKIM — strict vs relaxed :**

```text
ALIGNEMENT DKIM (adkim=)
  Strict  (s) : le domaine d= de DKIM-Signature doit être IDENTIQUE au From:
  Relaxed (r) : le From: peut être un sous-domaine du domaine d=

  Relaxed PASSE :   From: noreply@news.domain.com  /  DKIM d= domain.com  ✓
  Strict  ÉCHOUE :  From: noreply@news.domain.com  /  DKIM d= domain.com  ✗

ALIGNEMENT SPF (aspf=)
  Strict  (s) : le MAIL FROM doit être IDENTIQUE au From:
  Relaxed (r) : le From: peut être un sous-domaine du MAIL FROM
```

!!! tip "Déploiement progressif recommandé"
    1. `p=none; rua=mailto:...` — observer sans impact, collecter les rapports
    2. `p=quarantine; pct=10` — appliquer à 10 %, augmenter progressivement jusqu'à `pct=100`
    3. `p=reject; pct=100` — politique finale une fois tous les flux légitimes maîtrisés

!!! warning "SPF, DKIM et DMARC sont complémentaires, non substituables"
    | Mécanisme | Ce qu'il protège | Sa limite principale |
    |---|---|---|
    | **SPF** seul | Usurpation de l'enveloppe SMTP (`MAIL FROM`) | Ne couvre pas le `From:` visible par l'utilisateur |
    | **DKIM** seul | Intégrité du contenu en transit | Ne prouve pas que le `From:` est légitime |
    | **DMARC** | Usurpation du `From:` visible (phishing direct) | Requiert SPF et/ou DKIM pour fonctionner |

---

### Vérification de propriété de domaine

**Rôle :** prouver à un service tiers qu'on contrôle effectivement un domaine en y publiant
un jeton aléatoire dans un enregistrement `TXT`. Seul le titulaire réel de la zone DNS peut
créer cet enregistrement — c'est une preuve de contrôle administratif du domaine.

**Mécanisme général :**

```text
1. Le service tiers génère un jeton unique associé à votre compte
2. Il vous demande de créer un enregistrement TXT dans votre zone DNS
3. Après propagation (délai selon le TTL en vigueur), le service interroge votre zone
4. Si le TXT contenant le jeton est trouvé → propriété du domaine prouvée
5. Selon le service, le jeton reste en place ou peut être supprimé après vérification
```

**Exemples concrets par service :**

```dns
; ── Google Search Console / Google Workspace ───────────────────────────────
domain.com.   3600   TXT   "google-site-verification=abc123XYZ_randomtoken_456def"

; ── ACME DNS-01 (Let's Encrypt, ZeroSSL — émission de certificats TLS) ─────
; Sous-domaine dédié _acme-challenge, TTL court : le jeton est éphémère
_acme-challenge.domain.com.   120   TXT   "Y3VpY3Jxb2FoZmd6dGtvcXVscWh3..."
; Supprimé automatiquement une fois le certificat délivré

; ── Microsoft 365 / Azure Active Directory ──────────────────────────────────
domain.com.   3600   TXT   "MS=ms12345678"

; ── GitHub (vérification de domaine d'organisation) ─────────────────────────
_github-challenge-orgname.domain.com.   TXT   "randomtoken123456"

; ── Atlassian (Jira, Confluence Cloud) ──────────────────────────────────────
domain.com.   TXT   "atlassian-domain-verification=aAbBcCdDeEfF..."

; ── Brevo / Mailchimp / SendGrid (vérification de domaine d'envoi) ──────────
; Ces services combinent un TXT de vérification + CNAME pour le tracking des clics
brevo-code._domainkey.domain.com.   TXT   "k=rsa; t=s; p=MIGfMA0..."
```

!!! info "Racine du domaine ou sous-domaine préfixé par `_`"
    Certains services placent leur jeton à la racine (`domain.com TXT`), d'autres utilisent un
    sous-domaine préfixé par un tiret bas (`_acme-challenge`, `_github-challenge-…`). Le préfixe
    `_` indique conventionnellement un enregistrement de service (RFC 6335) — il signale que ce
    nom n'est pas un hôte routable, mais un point d'ancrage pour un protocole applicatif.

!!! warning "Ne pas supprimer les jetons de vérification active"
    Certains services (Google Workspace, Microsoft 365) **revérifient périodiquement** la présence
    du jeton dans le DNS. Supprimer l'enregistrement `TXT` après la vérification initiale peut
    entraîner la suspension des droits ou services associés au domaine. Consulter la documentation
    du service avant toute suppression.

---

## Fichiers & configuration système (Linux)

### Ordre de résolution — `/etc/nsswitch.conf`

Définit l'ordre des sources consultées pour résoudre un nom (fichiers locaux, DNS, etc.).

```bash
cat /etc/nsswitch.conf | grep hosts   # Affiche l'ordre de résolution configuré
```

```text
hosts: files dns    # Consulte d'abord /etc/hosts, puis le DNS
```

### Fichier hôte local — `/etc/hosts`

Résolution statique, prioritaire sur le DNS si `nsswitch.conf` place `files` en premier.

```bash
cat /etc/hosts                        # Affiche les résolutions statiques locales
# 127.0.0.1       localhost
# 192.168.1.50    serveur-interne.local
```

### Résolveurs classiques — `/etc/resolv.conf`

Définit les serveurs DNS interrogés par le système (souvent généré automatiquement).

```bash
cat /etc/resolv.conf                  # Affiche les résolveurs DNS configurés
# nameserver 8.8.8.8     -> serveur DNS primaire
# nameserver 1.1.1.1     -> serveur DNS secondaire
# search domain.local    -> suffixe appliqué aux noms courts
```

!!! info "Fichier généré automatiquement"
    Sur de nombreuses distributions modernes, `/etc/resolv.conf` est généré dynamiquement par `systemd-resolved` ou `NetworkManager` : une modification manuelle peut être écrasée au redémarrage.

### Gestionnaire moderne — `systemd-resolved`

```bash
resolvectl status                     # Affiche les résolveurs actifs par interface
resolvectl query domain.com           # Résout un nom via systemd-resolved
resolvectl flush-caches               # Vide le cache DNS local
resolvectl statistics                 # Statistiques sur le cache et les requêtes
```

---

## Sécurité du protocole

### Transfert de zone (AXFR)

Le transfert de zone permet à un serveur secondaire de répliquer l'intégralité d'une zone depuis le serveur primaire.

!!! warning "Risque d'exposition"
    Un serveur autoritaire mal configuré peut répondre à une requête AXFR provenant de n'importe quel client, exposant ainsi l'ensemble des enregistrements de la zone (sous-domaines internes, infrastructure). Le transfert doit être restreint aux serveurs secondaires légitimes (ACL, TSIG).

### Principes de DNSSEC

DNSSEC (DNS Security Extensions) ajoute une authentification cryptographique au DNS, sans chiffrer les échanges.

- **Objectif** : garantir l'**authenticité** et l'**intégrité** des réponses, pas leur confidentialité.
- **Mécanisme** : chaque zone signe ses enregistrements avec une clé privée ; le résolveur vérifie avec la clé publique correspondante.
- **Chaîne de confiance** : la validation remonte jusqu'à la racine (`.`), de bout en bout.

| Enregistrement DNSSEC | Rôle |
|---|---|
| `RRSIG` | Signature cryptographique d'un ensemble d'enregistrements |
| `DNSKEY` | Clé publique utilisée pour vérifier les signatures de la zone |
| `DS` | Empreinte de la clé, déposée dans la zone parente (chaîne de confiance) |
| `NSEC` / `NSEC3` | Prouve l'absence d'un enregistrement (protection anti-énumération) |

!!! info "DNSSEC ne chiffre rien"
    DNSSEC protège contre la falsification de réponses (cache poisoning, spoofing) mais ne masque pas les requêtes. Pour la confidentialité, ce sont des protocoles comme **DoH** (DNS over HTTPS) ou **DoT** (DNS over TLS) qui interviennent.

### Chiffrement et confidentialité DNS : DoT & DoH

Par défaut, une requête DNS classique (UDP/TCP port 53) circule **en clair** sur le réseau : n'importe quel intermédiaire — FAI, point d'accès Wi-Fi, attaquant en position MitM — peut la lire, voire la falsifier. DoT et DoH répondent à ce problème en encapsulant les échanges DNS dans une couche de chiffrement, mais avec des philosophies et des implications de sécurité très différentes.

#### DNS over TLS (DoT — RFC 7858)

**Fonctionnement** : DoT encapsule directement les paquets DNS classiques (habituellement transportés en UDP/TCP sur le port 53) au sein d'une session **TLS dédiée**, sur un port distinct du trafic DNS non chiffré.

- **Port standard** : **853/TCP**.
- **Caractéristiques** : DoT opère à un niveau proche de la couche transport/réseau — c'est un canal DNS chiffré, mais qui reste **identifiable comme tel** sur le réseau du simple fait d'utiliser un port dédié.
- **Usage typique** : configurations système natives — *Private DNS* sur Android, résolveurs stub (*stub resolvers*) déployés en entreprise, intégration directe au niveau de l'OS.

```text
# Exemple de résolution DoT avec kdig (Knot DNS tools)
$ kdig @1.1.1.1 +tls-ca +tls-hostname=one.one.one.one example.com
```

!!! warning "Facilité de filtrage réseau"
    Parce que DoT utilise un **port dédié et reconnaissable** (853/TCP), il est trivial à bloquer ou à filtrer au niveau d'un pare-feu périphérique : une simple règle de blocage du port 853 suffit à empêcher son usage, sans même avoir besoin d'inspecter le contenu du trafic.

#### DNS over HTTPS (DoH — RFC 8484)

**Fonctionnement** : DoH encapsule les requêtes et réponses DNS au sein de requêtes **HTTP/2 ou HTTP/3** classiques, au format binaire dédié (`application/dns-message`) ou, pour certaines implémentations, au format JSON, via des requêtes HTTP `GET` ou `POST`.

- **Port standard** : **443/TCP** — le même port que l'ensemble du trafic web HTTPS.
- **Caractéristiques** : le trafic DoH **se confond totalement** avec n'importe quelle autre requête HTTPS légitime. Un pare-feu ou un WAF ne peut pas le distinguer par simple filtrage de port ; seule une **inspection SSL/TLS approfondie** (déchiffrement TLS, empreinte JA3/JA3S, analyse SNI) permet, avec des limites, de le repérer.
- **Usage typique** : intégré nativement au cœur des **navigateurs web modernes** (Firefox, Chrome, Edge), souvent pour isoler délibérément les requêtes DNS du navigateur de celles gérées par l'OS.

```text
# Exemple de résolution DoH avec curl (format JSON, Cloudflare)
$ curl -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name=example.com&type=A'
```

!!! tip "Format binaire vs format JSON"
    Le format binaire standard (`application/dns-message`, RFC 8484) encode directement un message DNS classique dans le corps de la requête/réponse HTTP. Le format JSON, proposé en complément par certains fournisseurs (Cloudflare, Google), est plus lisible pour un usage manuel ou de debug mais n'est pas universellement supporté par tous les résolveurs DoH.

#### Enjeux de sécurité : Red Team vs Blue Team

!!! note "Avantages en matière de confidentialité"
    DoT comme DoH empêchent efficacement le **reniflage de trafic (sniffing)** par un FAI, l'**interception Man-in-the-Middle** classique, et la **modification à la volée des réponses DNS** — un vecteur particulièrement pertinent sur des réseaux Wi-Fi publics non maîtrisés, où un attaquant en position MitM pourrait autrement rediriger silencieusement un utilisateur vers une infrastructure malveillante.

!!! warning "Impacts côté Blue Team / SOC"
    Le chiffrement des requêtes DNS entraîne une **perte de visibilité** pour les équipes de sécurité défensive : les mécanismes de filtrage DNS internes (listes noires, sinkholing de domaines malveillants) et les serveurs DNS autoritaires d'entreprise peuvent être **contournés**, en particulier lorsque DoH est configuré directement au niveau applicatif (navigateur) plutôt qu'au niveau du système d'exploitation supervisé.

!!! danger "Usage malveillant en Red Team / par des attaquants"
    DoH est de plus en plus utilisé par des **malwares et infrastructures de Command & Control (C2)** pour exfiltrer des données ou faire transiter leurs communications de pilotage, précisément parce que ce trafic se noie dans le flux HTTPS légitime et échappe aux contrôles de sécurité réseau basés sur le port ou sur des résolveurs DNS de confiance.

#### Matrice comparative : DoT vs DoH vs DNS classique

| Critère | DNS classique | DoT (DNS over TLS) | DoH (DNS over HTTPS) |
|---|---|---|---|
| Protocole/Port | UDP/TCP 53 | TCP 853 (dédié) | TCP 443 (partagé avec le web) |
| Transport/Encapsulation | Aucun chiffrement | TLS direct sur les paquets DNS | Message DNS encapsulé dans HTTP/2 ou HTTP/3 |
| Facilité de filtrage réseau | Triviale (port 53 en clair) | Facile (port 853 dédié et identifiable) | Très difficile (indissociable du trafic HTTPS) |
| Visibilité SOC | Totale (requêtes en clair) | Réduite mais le port trahit l'usage | Très faible sans inspection TLS approfondie |
| Cible d'implémentation | OS / résolveurs classiques | OS, résolveurs stub, Android Private DNS | Navigateurs web (Firefox, Chrome, Edge) |

---

## Voir aussi

- RFC 1034 / 1035 — Concepts et spécifications du DNS
- RFC 4033 à 4035 — Introduction à DNSSEC
- RFC 7208 — Sender Policy Framework (SPF)
- RFC 6376 — DomainKeys Identified Mail (DKIM)
- RFC 7489 — Domain-based Message Authentication, Reporting, and Conformance (DMARC)
- RFC 8301 — Cryptographic Algorithm and Key Usage Update to DomainKeys Identified Mail (DKIM) — ed25519
- RFC 6335 — Convention de nommage avec préfixe `_` pour les enregistrements de service
- Fiche complémentaire : `dns-outils.md` pour l'inspection en ligne de commande
