---
title: "WHOIS & RDAP : Registres de noms de domaine et empreinte administrative"
description: "Anatomie du protocole WHOIS, analyse des métadonnées d'enregistrement de domaine, masquage RGPD et transition vers le protocole RDAP."
tags:
  - whois
  - rdap
  - osint
  - recon
  - dns
  - icann
  - footprinting
  - domain-registration
---

# WHOIS & RDAP — Registres de noms de domaine et empreinte administrative

!!! warning "Cadre légal"
    Les techniques de collecte d'informations décrites dans ce document (OSINT passif, reverse
    WHOIS, historique d'enregistrement) s'appliquent exclusivement à des fins légitimes :
    recherche de sécurité, audit autorisé, investigation sur infrastructure propre, ou
    traitement de signalements d'abus. L'usage à des fins malveillantes engage la responsabilité
    pénale de l'opérateur.

---

## 1. Résumé exécutif & contexte

### L'écosystème d'enregistrement de noms de domaine

La gestion des noms de domaine repose sur trois acteurs distincts dont la confusion est
fréquente, même chez les praticiens expérimentés :

```text
Écosystème d'enregistrement — acteurs et flux

┌─────────────────────────────────────────────────────────────────────┐
│  ICANN (Internet Corporation for Assigned Names and Numbers)        │
│  Organisme de coordination global — fixe les politiques,           │
│  accrédite les registrars, mandate le déploiement de RDAP          │
└────────────────────────┬────────────────────────────────────────────┘
                         │ accrédite & supervise
          ┌──────────────▼──────────────┐
          │       REGISTRY               │
          │  Gère le TLD et sa base de  │
          │  données d'autorité          │
          │  Ex : Verisign (.com/.net)  │
          │       AFNIC (.fr)           │
          │       PIR (.org)            │
          └──────────────┬──────────────┘
                         │ délègue la vente
          ┌──────────────▼──────────────┐
          │       REGISTRAR              │
          │  Revendeur accrédité par    │
          │  l'ICANN — vend les noms   │
          │  Ex : GoDaddy, Namecheap,  │
          │       OVH, Gandi           │
          └──────────────┬──────────────┘
                         │ vend à
          ┌──────────────▼──────────────┐
          │       REGISTRANT             │
          │  Entité physique ou morale  │
          │  qui enregistre et détient  │
          │  le nom de domaine          │
          └─────────────────────────────┘
```

| Acteur | Rôle | Exemples |
|---|---|---|
| **ICANN** | Coordination des politiques, accréditation, racine DNS | icann.org |
| **Registry** | Gestion technique et base de données du TLD | Verisign (.com), AFNIC (.fr), Donuts (.io) |
| **Registrar** | Vente et gestion des domaines aux utilisateurs finaux | GoDaddy, OVH, Gandi, Namecheap |
| **Registrant** | Titulaire enregistré du nom de domaine | Toute personne physique ou morale |

### Intérêt pour la cybersécurité

Les métadonnées d'enregistrement exposées par WHOIS et RDAP constituent une source de
renseignement passive de premier ordre :

| Cas d'usage | Type d'acteur | Objectif |
|---|---|---|
| **Footprinting / OSINT** | Red Team | Cartographier l'infrastructure d'une cible avant engagement |
| **Attribution d'infrastructure** | Threat Intelligence | Relier des domaines malveillants à un acteur ou une campagne |
| **Détection de typosquatting** | Blue Team | Identifier des domaines frauduleux usurpant une marque |
| **Takedown** | Blue Team / Legal | Localiser les contacts d'abus du registrar pour signalement |
| **Due diligence** | SOC / IR | Vérifier la légitimité d'un domaine contacté par un endpoint |

---

## 2. Le protocole WHOIS (legacy)

### 2.1 Moteur & fonctionnement

WHOIS est un protocole de requête/réponse en texte brut défini par la **RFC 3912** (2004).

```text
Flux d'une requête WHOIS complète :

Client (port aléatoire)                    Serveur WHOIS (port 43/TCP)
        │                                          │
        │── Connexion TCP ─────────────────────── ►│
        │── "example.com\r\n" (texte brut) ───── ►│
        │                                          │  Interroge la base
        │                                          │  de données interne
        │◄── Réponse texte brut (non structuré) ───│
        │    (connexion fermée après la réponse)    │
        │                                          │
        [Fin de connexion — protocole stateless]
```

!!! warning "Limites structurelles de WHOIS"
    - **Aucun chiffrement** : échange en clair sur port 43/TCP, interceptable sur le réseau.
    - **Aucune standardisation** : chaque registrar retourne des champs nommés différemment
      (ex : `Registrant Email` vs `registrant-email` vs `holder-c`).
    - **Aucun contrôle d'accès** : toute requête anonyme est traitée identiquement.
    - **Rate limiting variable** : certains serveurs bloquent après quelques requêtes rapides.
    - **Pas d'internationalisation native** : les noms de domaines internationalisés (IDN)
      sont mal supportés.

### 2.2 Structure des données retournées

Un enregistrement WHOIS type pour un domaine `.com` comporte les champs suivants :

```text
; Exemple de réponse WHOIS pour un domaine enregistré (données anonymisées)
; Serveur interrogé : whois.verisign-grs.com → renvoi vers whois.registrar.com

Domain Name: TARGET-COMPANY.COM
Registry Domain ID: 1234567890_DOMAIN_COM-VRSN
Registrar WHOIS Server: whois.registrar-example.com
Registrar URL: https://www.registrar-example.com
Updated Date: 2023-11-02T08:14:22Z           ; Date de dernière modification
Creation Date: 2011-03-15T12:00:00Z          ; Date de création originale
Registry Expiry Date: 2025-03-15T12:00:00Z   ; Date d'expiration du nom

Registrar: ExampleRegistrar, Inc.
Registrar IANA ID: 1234
Registrar Abuse Contact Email: abuse@registrar-example.com   ; ← Clé pour les takedowns
Registrar Abuse Contact Phone: +1.8005551234                 ; ← Clé pour les takedowns

Domain Status: clientDeleteProhibited https://icann.org/epp#clientDeleteProhibited
Domain Status: clientTransferProhibited https://icann.org/epp#clientTransferProhibited
Domain Status: clientUpdateProhibited https://icann.org/epp#clientUpdateProhibited

; ── Contacts — données souvent masquées post-RGPD ──────────────────────────
Registrant Name: REDACTED FOR PRIVACY
Registrant Organization: Target Company Ltd.     ; ← Souvent encore visible
Registrant Street: REDACTED FOR PRIVACY
Registrant City: REDACTED FOR PRIVACY
Registrant State/Province: CA
Registrant Postal Code: REDACTED FOR PRIVACY
Registrant Country: US
Registrant Phone: REDACTED FOR PRIVACY
Registrant Email: Consult https://rdds.example-registrar.com/; ← Lien de contact indirect

Admin Name: REDACTED FOR PRIVACY
Admin Email: REDACTED FOR PRIVACY

Tech Name: REDACTED FOR PRIVACY
Tech Email: REDACTED FOR PRIVACY

; ── Serveurs de noms autoritaires ───────────────────────────────────────────
Name Server: NS1.TARGET-COMPANY.COM              ; ← Infrastructure propre → IP interne
Name Server: NS2.TARGET-COMPANY.COM              ; ← Pivot possible vers d'autres domaines

DNSSEC: unsigned                                 ; Absence de DNSSEC = vecteur de spoofing

URL of the ICANN Whois Inaccuracy Complaint Form: https://www.icann.org/wicf/
>>> Last update of WHOIS database: 2024-09-09T08:00:00Z <<<
```

**Les grandes familles de champs :**

| Famille | Champs | Intérêt OSINT |
|---|---|---|
| **Identité du domaine** | Domain Name, Registry Domain ID, DNSSEC | Confirmation, signatures de sécurité |
| **Registrar** | Registrar, IANA ID, Abuse Contact | Takedown, identification du prestataire |
| **Dates clés** | Creation Date, Updated Date, Expiry Date | Détection de domaines récents ou abandonnés |
| **Contacts** | Registrant, Admin, Tech (Name/Org/Email) | Attribution — souvent masqué post-RGPD |
| **Infrastructure** | Name Servers | Pivot vers autres domaines sur le même NS |
| **Statuts EPP** | Domain Status | État opérationnel du domaine |

### 2.3 Domain Status Codes (EPP)

Les statuts EPP (*Extensible Provisioning Protocol*) décrivent l'état opérationnel et les
protections actives sur un domaine. Ils apparaissent dans les champs `Domain Status:`.

| Code EPP | Déclencheur | Signification opérationnelle |
|---|---|---|
| `ok` | Registrant | État normal — aucune prohibition active |
| `inactive` | Système | Domaine sans nameserver délégué (non résolu) |
| `clientTransferProhibited` | Registrar | Transfert vers un autre registrar bloqué — **le plus courant** |
| `clientDeleteProhibited` | Registrar | Suppression bloquée côté registrar |
| `clientUpdateProhibited` | Registrar | Modification des données WHOIS bloquée |
| `clientHold` | Registrar | Domaine suspendu par le registrar (non résolu) |
| `clientRenewProhibited` | Registrar | Renouvellement bloqué (ex : contentieux) |
| `serverTransferProhibited` | Registry | Transfert bloqué par le Registry (ex : .gov, ICANN) |
| `serverDeleteProhibited` | Registry | Suppression bloquée par le Registry |
| `serverUpdateProhibited` | Registry | Mise à jour bloquée par le Registry |
| `serverHold` | Registry | Suspension par le Registry (abus, litiges UDRP) |
| `pendingDelete` | Système | En attente de suppression (période de rédemption ~30 j) |
| `pendingTransfer` | Système | Transfert de registrar en cours |
| `pendingCreate` | Système | Création en cours de traitement |
| `redemptionPeriod` | Système | Expiration passée — domaine récupérable par le titulaire |

!!! tip "clientTransferProhibited en OSINT"
    La présence de `clientTransferProhibited` sans autres protections (`clientUpdateProhibited`,
    `clientDeleteProhibited`) peut indiquer un domaine géré par un tiers ou un registrar
    discount avec configuration minimale. Un domaine de grande entreprise affiche typiquement
    **au moins trois** protections simultanées. Son absence totale signale une configuration
    potentiellement négligente.

!!! warning "serverHold — domaine suspendu par le Registry"
    Un statut `serverHold` posé par le Registry indique généralement une suspension pour activité
    abusive signalée (phishing, malware C2, spam). Les domaines en `serverHold` ne résolvent plus
    mais peuvent réapparaître si le titulaire conteste. Ce statut constitue un **indicateur de
    compromission passée** utile en threat hunting.

### 2.4 Protection des données & masquage RGPD

Depuis l'entrée en vigueur du RGPD en mai 2018, l'ICANN a temporairement autorisé puis
formalisé la **redaction des données personnelles** dans les réponses WHOIS publiques.

```text
Évolution du masquage WHOIS :

Avant 2018 (pré-RGPD) :          Après 2018 (post-RGPD) :
──────────────────────────────    ──────────────────────────────
Registrant Name: John Smith       Registrant Name: REDACTED FOR PRIVACY
Registrant Email: j@example.com   Registrant Email: [Lien formulaire contact]
Registrant Phone: +1.555.1234     Registrant Phone: REDACTED FOR PRIVACY
Registrant Street: 123 Main St    Registrant Street: REDACTED FOR PRIVACY
                                  Registrant Organization: Visible (si entreprise)
                                  Registrant Country: Visible
```

**Services de confidentialité des registrars :**

Certains registrars proposent des services de **proxy d'enregistrement** qui substituent
les coordonnées du registrant par celles d'une entité intermédiaire :

```text
; Exemple avec service WhoisGuard (Namecheap)
Registrant Name: WhoisGuard Protected
Registrant Organization: WhoisGuard, Inc.
Registrant Email: wg-proxy-XXXXXX@namecheap.com   ← Adresse de transfert anonymisée
Registrant Phone: +507.8365503
Registrant Street: P.O. Box 0823-03411
Registrant City: Panama
Registrant Country: PA                            ← Panama (juridiction favorable à la vie privée)

; Autres services courants :
; Domains By Proxy (GoDaddy) → proxy@godaddy.com
; PrivacyGuardian (PDR Ltd)  → domains@privacyguardian.org
; Contact Privacy Inc. (Tucows) → customerXXXXXX@contact-privacy.com
```

### 2.5 Exploitation de l'historique WHOIS (snapshots)

Avant le masquage RGPD, les données WHOIS étaient souvent indexées par des tiers.
Ces **snapshots historiques** permettent de retrouver les informations originales.

```text
Fenêtre d'exploitation des snapshots historiques :

2011 ─────────────────────────── 2018 ──────────────────── 2024
  │                                │                          │
  │ Données WHOIS en clair         │ Masquage progressif      │ Données masquées
  │ (Nom, email, téléphone,        │ (RGPD + politiques       │ (REDACTED FOR PRIVACY
  │  adresse complète)             │  registrars)             │  généralisé)
  │                                │
  └──────── Indexées par des tiers ─────────►
            (Whoxy, DomainTools, Whoisology,
             SecurityTrails, ViewDNS.info...)
```

| Service | Fonctionnalité | Usage OSINT |
|---|---|---|
| **Whoxy** | Snapshots historiques + Reverse WHOIS | Retrouver l'email d'enregistrement pré-GDPR |
| **DomainTools** | Historique complet + pivot multi-champs | Attribution d'infrastructure, profiling |
| **SecurityTrails** | DNS historique + WHOIS + registrar | Pivot NS, corrélation d'infrastructure |
| **ViewDNS.info** | Reverse WHOIS, IP history, reverse NS | Pivot rapide, gratuit (limité) |
| **Whoisology** | Reverse WHOIS massif, export | Recherche d'email de registrant à grande échelle |
| **RiskIQ / Recorded Future** | Graph d'infrastructure complet | Threat Intelligence professionnelle |

### 2.6 Syntaxe & exemples de commandes CLI

```bash
# Requête WHOIS basique — interroge le serveur WHOIS du TLD automatiquement
whois example.com

# Interroger un serveur WHOIS spécifique explicitement
whois -h whois.verisign-grs.com example.com        # Serveur .com (Verisign)
whois -h whois.iana.org example.com                # Serveur IANA (référence)
whois -h whois.nic.fr exemple.fr                   # Serveur .fr (AFNIC)

# WHOIS sur une adresse IP — retourne les informations d'allocation IP et ASN
whois 8.8.8.8                                       # Google DNS — identifie l'ASN (AS15169)
whois 203.0.113.42                                  # Exemple : IP d'infrastructure cible

# WHOIS sur une plage réseau (ASN → CIDR)
whois -h whois.radb.net AS15169                    # Routes annoncées par un AS

# Extraction propre de champs spécifiques (grep sur la sortie texte)
whois target-company.com | grep -iE "registrar:|creation date:|expiry date:|name server:|abuse"

# Comparaison de deux domaines suspects (typosquatting) — dates de création
whois legitimatebank.com  | grep "Creation Date"
whois legitimatebank-secure.com | grep "Creation Date"
# Un domaine très récent corrélé à une tentative de phishing est un signal fort

# Requête WHOIS avec sortie brute vers un fichier (pour post-traitement)
whois cible.com > whois_cible_$(date +%Y%m%d).txt

# Extraction de l'email d'abus pour signalement direct
whois cible.com | grep -i "abuse" | grep -i "email"
```

!!! tip "Interprétation des dates WHOIS"
    - **Creation Date très récente** (< 30 jours) + domaine imitant une marque = fort indicateur
      de phishing ou typosquatting. Les campagnes de phishing utilisent massivement des domaines
      fraîchement enregistrés.
    - **Expiry Date dans le passé** = domaine expiré, potentiellement récupérable par un tiers
      (domain squatting). Certains acteurs malveillants rachètent d'anciens domaines légitimes
      pour leur réputation héritée.
    - **Updated Date récente** sur un domaine ancien = changement de configuration (NS, registrar,
      contact) — peut indiquer une compromission ou une reprise de domaine.

**Services web de référence :**

```bash
# Portail officiel ICANN — données non filtrées par les politiques registrar
https://lookup.icann.org/lookup

# RDDS ICANN — recherche dans les données de registre ICANN
https://whois.icann.org/en/lookup?name=example.com

# Who.is — interface web conviviale + historique léger
https://who.is/whois/example.com

# ARIN (IP WHOIS pour l'Amérique du Nord)
https://search.arin.net/rdap/?query=203.0.113.0

# RIPE NCC (IP WHOIS pour l'Europe et le Moyen-Orient)
https://apps.db.ripe.net/search/lookup.html?source=RIPE&key=203.0.113.0&type=inetnum
```

---

## 3. Transition vers RDAP

### 3.1 Pourquoi la transition ?

L'ICANN a mandaté le remplacement progressif de WHOIS par RDAP pour les gTLDs, devenu
**obligatoire pour les registrars accrédités ICANN depuis le 26 août 2019**.

```text
Limitations de WHOIS ayant motivé la transition :

❌ Port 43/TCP — texte brut, interceptable, pas d'authentification
❌ Absence de standardisation — chaque registrar invente ses propres noms de champs
❌ Impossible de distinguer une réponse "domaine introuvable" d'une erreur réseau
❌ Pas de contrôle d'accès — même réponse pour tous (journaliste, criminel, chercheur)
❌ Pas de support natif des IDN (Internationalized Domain Names)
❌ Rate limiting implémenté de façon hétérogène et non documentée
❌ Pas de redirection standardisée vers le bon serveur autoritaire

✅ RDAP répond à chacun de ces problèmes
```

### 3.2 Fonctionnement de RDAP

RDAP (*Registration Data Access Protocol*) est défini par les RFC 7480–7484 (mises à jour
par RFC 9082 et RFC 9083). Il repose entièrement sur **HTTP/HTTPS** et retourne des réponses
**JSON** structurées.

```text
Flux d'une requête RDAP avec bootstrapping :

Client                    IANA Bootstrap        Registrar RDAP Server
  │                           Registry                  │
  │                              │                       │
  │── GET /dns.json ────────────►│                       │
  │   "Pour .com → Verisign"     │                       │
  │◄── Réponse JSON ─────────────│                       │
  │    (services URLs)           │                       │
  │                                                      │
  │── HTTPS GET /com/v1/domain/EXAMPLE.COM ────────────►│
  │   Host: rdap.verisign.com                            │
  │   Accept: application/rdap+json                      │
  │                                                      │  Interroge sa base
  │◄── 200 OK + JSON structuré ─────────────────────────│
  │    Content-Type: application/rdap+json               │

Note : après la première découverte, le client met en cache l'URL du serveur
      RDAP pour chaque TLD — le bootstrapping n'est effectué qu'une seule fois.
```

**Endpoints RDAP standardisés :**

| Type d'objet | Chemin de requête | Exemple |
|---|---|---|
| **Domaine** | `/domain/{nom}` | `/domain/example.com` |
| **Nameserver** | `/nameserver/{nom}` | `/nameserver/ns1.example.com` |
| **Entité** (registrar, contact) | `/entity/{handle}` | `/entity/292-IANA` |
| **Adresse IP** | `/ip/{adresse}` | `/ip/8.8.8.8` |
| **Numéro autonome (ASN)** | `/autnum/{numero}` | `/autnum/15169` |
| **Recherche domaine** | `/domains?name={pattern}` | `/domains?name=example*.com` |

### 3.3 Structure d'une réponse RDAP

```bash
# Interrogation RDAP d'un domaine .com via l'API Verisign
curl -s "https://rdap.verisign.com/com/v1/domain/EXAMPLE.COM" \
     -H "Accept: application/rdap+json" | jq .
```

```json
{
  "objectClassName": "domain",
  "handle": "2138514_DOMAIN_COM-VRSN",
  "ldhName": "EXAMPLE.COM",
  "links": [
    {
      "value": "https://rdap.verisign.com/com/v1/domain/EXAMPLE.COM",
      "rel": "self",
      "href": "https://rdap.verisign.com/com/v1/domain/EXAMPLE.COM",
      "type": "application/rdap+json"
    },
    {
      "value": "https://rdap.verisign.com/com/v1/domain/EXAMPLE.COM",
      "rel": "related",
      "href": "https://rdap.example-registrar.com/v1/domain/EXAMPLE.COM",
      "type": "application/rdap+json"
    }
  ],
  "status": [
    "client delete prohibited",
    "client transfer prohibited",
    "client update prohibited"
  ],
  "events": [
    {
      "eventAction": "registration",
      "eventDate": "2011-03-15T12:00:00Z"
    },
    {
      "eventAction": "expiration",
      "eventDate": "2025-03-15T12:00:00Z"
    },
    {
      "eventAction": "last changed",
      "eventDate": "2023-11-02T08:14:22Z"
    }
  ],
  "entities": [
    {
      "objectClassName": "entity",
      "handle": "1234-IANA",
      "roles": ["registrar"],
      "publicIds": [
        {
          "type": "IANA Registrar ID",
          "identifier": "1234"
        }
      ],
      "vcardArray": [
        "vcard",
        [
          ["version", {}, "text", "4.0"],
          ["fn", {}, "text", "ExampleRegistrar, Inc."]
        ]
      ],
      "entities": [
        {
          "objectClassName": "entity",
          "roles": ["abuse"],
          "vcardArray": [
            "vcard",
            [
              ["version", {}, "text", "4.0"],
              ["fn", {}, "text", "Abuse Contact"],
              ["tel", {"type": "voice"}, "uri", "tel:+1.8005551234"],
              ["email", {}, "text", "abuse@registrar-example.com"]
            ]
          ]
        }
      ]
    },
    {
      "objectClassName": "entity",
      "roles": ["registrant"],
      "remarks": [
        {
          "description": ["REDACTED FOR PRIVACY"],
          "title": "REDACTED FOR PRIVACY",
          "type": "object redacted due to authorization"
        }
      ]
    }
  ],
  "nameservers": [
    {
      "objectClassName": "nameserver",
      "ldhName": "NS1.TARGET-COMPANY.COM"
    },
    {
      "objectClassName": "nameserver",
      "ldhName": "NS2.TARGET-COMPANY.COM"
    }
  ],
  "secureDNS": {
    "delegationSigned": false,
    "zoneSigned": false
  },
  "remarks": [
    {
      "description": ["This response contains RDAP conformance level rdap_level_0"],
      "title": "RDAP conformance"
    }
  ],
  "rdapConformance": ["rdap_level_0", "icann_rdap_response_profile_0", "icann_rdap_technical_implementation_guide_0"]
}
```

### 3.4 Exemples pratiques d'interrogation RDAP

```bash
# ── Domaines ─────────────────────────────────────────────────────────────────

# Domaine .com via Verisign (Registry)
curl -s "https://rdap.verisign.com/com/v1/domain/EXAMPLE.COM" | jq .

# Domaine .com via le registrar (données plus complètes selon les droits d'accès)
curl -s "https://rdap.example-registrar.com/v1/domain/EXAMPLE.COM" | jq .

# Domaine .fr via AFNIC
curl -s "https://rdap.nic.fr/domain/EXEMPLE.FR" \
     -H "Accept: application/rdap+json" | jq .

# Domaine .io via le Registry
curl -s "https://rdap.nic.io/domain/EXAMPLE.IO" | jq .

# ── Bootstrapping automatique via IANA ───────────────────────────────────────
# Le bootstrapping permet de trouver automatiquement le bon serveur RDAP pour un TLD
curl -s "https://data.iana.org/rdap/dns.json" | jq '.services[] | select(.[0][] | test("com"))'
# → Retourne l'URL du serveur RDAP autoritaire pour .com

# ── Extraction ciblée avec jq ────────────────────────────────────────────────

# Extraire uniquement les dates clés
curl -s "https://rdap.verisign.com/com/v1/domain/EXAMPLE.COM" \
  | jq '.events[] | {action: .eventAction, date: .eventDate}'

# Extraire les nameservers
curl -s "https://rdap.verisign.com/com/v1/domain/EXAMPLE.COM" \
  | jq '[.nameservers[].ldhName]'

# Extraire le contact d'abus (pour un takedown)
curl -s "https://rdap.verisign.com/com/v1/domain/EXAMPLE.COM" \
  | jq '.entities[] | select(.roles[] == "registrar") | .entities[]
        | select(.roles[] == "abuse") | .vcardArray[1][]
        | select(.[0] == "email") | .[3]'

# Extraire les statuts EPP
curl -s "https://rdap.verisign.com/com/v1/domain/EXAMPLE.COM" \
  | jq '.status'

# ── Adresses IP et ASN ───────────────────────────────────────────────────────

# RDAP IP via ARIN (Amérique du Nord)
curl -s "https://rdap.arin.net/registry/ip/8.8.8.8" | jq .

# RDAP IP via RIPE NCC (Europe / Moyen-Orient)
curl -s "https://rdap.db.ripe.net/ip/203.0.113.0" | jq .

# RDAP ASN
curl -s "https://rdap.arin.net/registry/autnum/15169" | jq '.name,.handle'

# ── Outil CLI dédié : rdap (client Python) ───────────────────────────────────
pip install rdap           # Installation
rdap example.com           # Requête domaine
rdap 8.8.8.8               # Requête IP
rdap AS15169               # Requête ASN
```

!!! note "Content-Type RDAP"
    Les serveurs RDAP retournent le type MIME `application/rdap+json` (et non
    `application/json`). Les clients qui ne valorisent pas l'en-tête `Accept:` correctement
    peuvent recevoir une erreur `406 Not Acceptable` de la part de certains serveurs stricts.
    Toujours spécifier `-H "Accept: application/rdap+json"` dans les requêtes `curl`.

---

## 4. Matrice comparative : WHOIS vs RDAP

| Critère | WHOIS (RFC 3912) | RDAP (RFC 7480–7484) |
|---|---|---|
| **Transport / Port** | TCP/43 — texte brut, non chiffré | HTTPS/443 — TLS natif |
| **Format de réponse** | Texte libre, non structuré | JSON normalisé (`application/rdap+json`) |
| **Standardisation** | Faible — chaque registrar invente ses champs | Forte — schéma JSON défini par RFC 7483 / 9083 |
| **Chiffrement** | ❌ Aucun | ✅ TLS obligatoire |
| **Authentification** | ❌ Aucune (anonyme) | ✅ OAuth 2.0 / Bearer tokens (optionnel) |
| **Contrôle d'accès** | ❌ Identique pour tous | ✅ Réponses différenciées par rôle |
| **Parsing automatisé** | Difficile — expressions régulières fragiles | Facile — `jq`, bibliothèques JSON standard |
| **Bootstrap (découverte du serveur)** | Manuel (connaissance préalable requise) | ✅ Automatique via IANA Bootstrap Registry |
| **Internationalisation (IDN)** | Partielle et hétérogène | ✅ Support natif UTF-8 et ACE |
| **Gestion des erreurs** | Texte libre, non normalisé | ✅ Codes HTTP standard (404, 429, 501…) |
| **Redirections** | Mention textuelle (à parser manuellement) | ✅ Liens `rel="related"` dans le JSON |
| **Rate limiting** | Implémenté de façon hétérogène | ✅ HTTP 429 avec `Retry-After` standardisé |
| **Extensibilité** | Impossible sans casser les parseurs existants | ✅ Extensions via `rdapConformance` |
| **RGPD / redaction** | Texte "REDACTED FOR PRIVACY" libre | ✅ Champ `remarks` structuré avec `type` |
| **Adoption obligatoire** | Maintenu pour rétrocompatibilité | ✅ Obligatoire pour gTLDs depuis 08/2019 |

!!! tip "Quand utiliser WHOIS vs RDAP en pratique ?"
    - **WHOIS CLI** : accès rapide, sans outil supplémentaire, sur des domaines dont le registrar
      maintient encore le service (ccTLDs notamment : `.fr`, `.de`, `.uk` ont leurs propres
      politiques).
    - **RDAP** : parsing automatisé, scripts OSINT, surveillance de masse, ou lorsqu'une réponse
      JSON structurée est nécessaire pour alimenter un SIEM, un outil de threat intelligence ou
      une plateforme SOAR.
    - **Les deux** : certains registrars fournissent des données différentes selon le protocole
      (WHOIS plus complet sur les anciens ccTLD ; RDAP plus complet sur les gTLD modernes).

---

## 5. Utilisation en Red Team vs Blue Team

### 5.1 Red Team — Collecte d'empreinte et pivotement

#### Pivotement par email de registrant (Reverse WHOIS)

Avant le masquage RGPD, les adresses email utilisées pour enregistrer un domaine constituaient
le vecteur de pivot le plus puissant : une même adresse peut avoir été réutilisée pour
enregistrer des dizaines de domaines d'infrastructure.

```bash
# Reverse WHOIS via Whoxy (API gratuite — limites quotidiennes)
curl -s "https://api.whoxy.com/?key=YOUR_KEY&reverse=whois&email=admin@target.com" \
  | jq '.search_result[] | {domain: .domain_name, created: .create_date}'

# → Si "admin@target.com" a enregistré 30 domaines entre 2015 et 2018,
#   l'attaquant obtient toute l'infrastructure historique de la cible

# Whoxy — pivot par organisation
curl -s "https://api.whoxy.com/?key=YOUR_KEY&reverse=whois&company=Target+Company+Ltd" \
  | jq '[.search_result[].domain_name]'
```

#### Corrélation par nameservers partagés

```bash
# Identifier tous les domaines sur les mêmes nameservers que la cible
# (indique des domaines gérés par la même entité / même prestataire DNS)

# Étape 1 : récupérer les NS de la cible
TARGET_NS=$(whois target-company.com | grep "Name Server" | awk '{print $3}')
echo "Nameservers : $TARGET_NS"

# Étape 2 : reverse NS lookup via SecurityTrails (API)
curl -s "https://api.securitytrails.com/v1/search/list?apikey=YOUR_KEY" \
  --data-binary '{"filter":{"ns":"ns1.target-company.com"}}' | jq .

# Étape 3 : pivot via ViewDNS.info (gratuit, interface web)
# https://viewdns.info/reversens/?ns=ns1.target-company.com

# → Résultat : liste de domaines partageant le même NS → cartographie d'infrastructure
```

#### Analyse des dates pour détecter l'infrastructure de campagne

```bash
# Comparer les dates de création de domaines suspects pour identifier une campagne
# Tous créés le même jour / même semaine → même acteur, même déploiement
for domain in suspicious-bank.com secure-banking-login.com bank-update-required.com; do
  echo -n "$domain : "
  whois $domain 2>/dev/null | grep -i "creation date"
done

# Extraction de l'infrastructure associée à une IP connue (ex: serveur C2)
whois 198.51.100.10   # Identifier l'ASN et le netblock
# → Puis pivot : quels autres domaines pointent vers ce netblock ?
```

#### Exploitation de l'historique pré-RGPD

```text
Stratégie de pivot historique :

1. Cible actuelle → WHOIS 2024 → Données masquées (REDACTED)
                                         │
2. Même domaine → Snapshot Whoxy 2016 → admin@perso-email.com
                                         │
3. Reverse WHOIS sur admin@perso-email.com → 8 autres domaines enregistrés
                                         │
4. Ces 8 domaines → NSs pointant vers → Hébergeur utilisé en 2016
                                         │
5. Hébergeur → Plage IP → Scan historique Shodan → Services exposés en 2016
                                         │
6. Croisement avec Shodan + Censys → Infrastructure complète de l'acteur
```

!!! tip "Outils Red Team WHOIS/RDAP intégrés"
    - **theHarvester** : collecte d'emails, domaines et sous-domaines via WHOIS et autres sources
    - **Maltego** (transforms WHOIS) : pivotement graphique multi-sources
    - **Recon-ng** (module `whois_pocs`) : automatisation de la collecte WHOIS
    - **SpiderFoot** : OSINT automatisé intégrant WHOIS, RDAP et historique DNS

### 5.2 Blue Team — Surveillance, détection et takedown

#### Détection de domaines typosquattés récemment enregistrés

```python
# Script de surveillance des nouveaux enregistrements similaires à un domaine de marque
# Utilise RDAP pour vérifier la date de création et le registrar

import subprocess
import json
from datetime import datetime, timedelta

PROTECTED_DOMAIN = "legitimatebank"
TYPOSQUATTING_VARIANTS = [
    "legitimatebank-secure.com",
    "secure-legitimatebank.com",
    "legitimatebank.net",
    "legitlmatebank.com",     # Substitution : i → l
    "legitimatebank-online.com",
    "legitimatebank.co",
]

def check_domain_via_rdap(domain):
    """Interroge RDAP et retourne les dates si le domaine existe."""
    import urllib.request
    tld = domain.split(".")[-1]
    # Serveurs RDAP connus par TLD (simplification)
    rdap_servers = {
        "com": "https://rdap.verisign.com/com/v1",
        "net": "https://rdap.verisign.com/net/v1",
        "org": "https://rdap.publicinterestregistry.org/rdap",
        "co":  "https://rdap.nic.co",
    }
    server = rdap_servers.get(tld)
    if not server:
        return None
    try:
        url = f"{server}/domain/{domain.upper()}"
        with urllib.request.urlopen(url, timeout=5) as r:
            data = json.loads(r.read())
        events = {e["eventAction"]: e["eventDate"] for e in data.get("events", [])}
        return {
            "domain": domain,
            "creation_date": events.get("registration"),
            "expiry_date": events.get("expiration"),
            "nameservers": [ns["ldhName"] for ns in data.get("nameservers", [])],
        }
    except Exception:
        return None  # Domaine non enregistré ou erreur réseau

THRESHOLD = datetime.now() - timedelta(days=30)

for variant in TYPOSQUATTING_VARIANTS:
    result = check_domain_via_rdap(variant)
    if result and result["creation_date"]:
        creation = datetime.fromisoformat(result["creation_date"].replace("Z", "+00:00"))
        age_marker = "⚠️  RÉCENT" if creation.replace(tzinfo=None) > THRESHOLD else "✓ ancien"
        print(f"{age_marker} | {result['domain']} | créé le {result['creation_date']}")
        print(f"  NS : {', '.join(result['nameservers'])}")
    else:
        print(f"  ✓ Non enregistré : {variant}")
```

#### Procédure de takedown via les contacts d'abus WHOIS/RDAP

```bash
# Étape 1 — Identifier le registrar et ses contacts d'abus
PHISHING_DOMAIN="secure-legitimatebank.com"

echo "=== Collecte des contacts d'abus ==="
REGISTRAR=$(whois $PHISHING_DOMAIN | grep -i "Registrar:" | head -1 | awk -F: '{print $2}' | xargs)
ABUSE_EMAIL=$(whois $PHISHING_DOMAIN | grep -i "Registrar Abuse Contact Email:" | awk '{print $NF}')
ABUSE_PHONE=$(whois $PHISHING_DOMAIN | grep -i "Registrar Abuse Contact Phone:" | awk '{print $NF}')

echo "Registrar : $REGISTRAR"
echo "Abuse Email : $ABUSE_EMAIL"
echo "Abuse Phone : $ABUSE_PHONE"

# Étape 2 — Même extraction via RDAP (plus fiable, JSON structuré)
curl -s "https://rdap.verisign.com/com/v1/domain/$PHISHING_DOMAIN" \
  | jq '.entities[] | select(.roles[] == "registrar")
        | .entities[]? | select(.roles[]? == "abuse")
        | .vcardArray[1][] | select(.[0] == "email") | .[3]'

# Étape 3 — Préparer le rapport d'abus standardisé
# Template de signalement (ICANN Registrar Abuse Contact)
cat << 'EOF'
Subject: Phishing/Fraud Domain Abuse Report — [PHISHING_DOMAIN]

Dear Registrar Abuse Team,

We are reporting a domain registered through your company that is being used for
phishing attacks targeting customers of LegitimateBank:

Malicious domain: secure-legitimatebank.com
Creation date: [DATE FROM WHOIS]
Attack type: Phishing / Brand Impersonation
Evidence: [SCREENSHOTS, LOG EXCERPTS, PHISHING EMAIL SAMPLES]

Legitimate brand owner contact:
  Security Team, LegitimateBank
  security@legitimatebank.com
  +1-XXX-XXX-XXXX

We request immediate suspension of this domain in accordance with your Acceptable
Use Policy and ICANN registration agreement section [X].

Sincerely,
[Sender Name, Organization, Contact Information]
EOF
```

#### Surveillance continue via Certificate Transparency + WHOIS

```bash
# Approche combinée CT logs + WHOIS pour détecter du phishing précoce
# Les certificats TLS sont émis AVANT ou JUSTE APRÈS l'enregistrement du domaine

# 1. Surveillance CT logs (certstream, crt.sh)
# Surveiller les certificats contenant "legitimatebank" dans le CN ou SAN

curl -s "https://crt.sh/?q=%25legitimatebank%25&output=json" \
  | jq '.[] | select(.not_before > "2024-01-01") | {domain: .name_value, date: .not_before}' \
  | head -20

# 2. Pour chaque domaine suspect détecté → vérifier WHOIS
# (âge, registrar, NS — tous les signaux de phishing frais)
SUSPECTED="secure-legitimatebank.com"
whois $SUSPECTED | grep -E "Creation Date|Registrar:|Name Server:|Status:"
```

!!! warning "Délais de propagation et fenêtre d'action"
    Entre l'enregistrement d'un domaine de phishing et sa première utilisation opérationnelle,
    il s'écoule généralement **48 à 72 heures** (propagation DNS, émission de certificat TLS,
    mise en place du contenu). Ce délai constitue la **fenêtre d'intervention optimale** pour
    un takedown préventif. Les équipes Blue Team disposant d'une surveillance CT + WHOIS en
    temps réel peuvent initier le takedown avant même la première vague d'emails malveillants.

!!! note "Ressources de signalement d'abus en dehors du registrar"
    Lorsqu'un takedown via le registrar est trop lent ou infructueux :
    - **ICANN Compliance** : https://www.icann.org/resources/compliance (pour les infractions aux
      politiques registrar)
    - **PhishTank** / **OpenPhish** : partage communautaire de données de phishing
    - **APWG** (Anti-Phishing Working Group) : https://apwg.org/reportphishing/
    - **Google Safe Browsing** : https://safebrowsing.google.com/safebrowsing/report_phish/
    - **Microsoft SmartScreen** : https://www.microsoft.com/en-us/wdsi/support/report-unsafe-site

---

## 6. Références

### RFCs fondamentaux

| RFC | Titre | Contenu |
|---|---|---|
| **RFC 3912** (2004) | WHOIS Protocol Specification | Spécification originale de WHOIS, port 43/TCP |
| **RFC 7480** (2015) | HTTP Usage in RDAP | Transport HTTP/HTTPS pour RDAP |
| **RFC 7481** (2015) | Security Services for RDAP | Authentification et contrôle d'accès RDAP |
| **RFC 7482** (2015) | RDAP Query Format | Format des requêtes (mis à jour par RFC 9082) |
| **RFC 7483** (2015) | JSON Responses for RDAP | Schéma JSON (mis à jour par RFC 9083) |
| **RFC 7484** (2015) | Finding the Authoritative RDAP Service | Bootstrap et découverte du serveur |
| **RFC 8056** (2017) | EPP and RDAP Status Mapping | Correspondance codes EPP ↔ RDAP |
| **RFC 9082** (2021) | RDAP Query Format (updated) | Mise à jour de RFC 7482 |
| **RFC 9083** (2021) | JSON Responses for RDAP (updated) | Mise à jour de RFC 7483 |

### Portails officiels et outils

| Ressource | URL | Utilité |
|---|---|---|
| **ICANN Lookup** | https://lookup.icann.org | WHOIS et RDAP officiels — données non filtrées |
| **IANA RDAP Bootstrap** | https://data.iana.org/rdap/dns.json | Liste des serveurs RDAP par TLD |
| **RDAP Pilot (ICANN)** | https://www.icann.org/rdap | Documentation officielle RDAP |
| **ARIN RDAP** | https://rdap.arin.net/registry/ | IP et ASN (Amérique du Nord) |
| **RIPE NCC RDAP** | https://rdap.db.ripe.net/ | IP et ASN (Europe, Moyen-Orient) |
| **AFRINIC RDAP** | https://rdap.afrinic.net/rdap/ | IP et ASN (Afrique) |
| **Verisign RDAP** | https://rdap.verisign.com/com/v1/ | Domaines .com et .net |
| **AFNIC RDAP** | https://rdap.nic.fr | Domaines .fr |
| **Whoxy** | https://www.whoxy.com | Historique et Reverse WHOIS |
| **SecurityTrails** | https://securitytrails.com | WHOIS, DNS historique, pivot |
| **ViewDNS.info** | https://viewdns.info | Reverse NS, IP history, WHOIS |
| **crt.sh** | https://crt.sh | Certificate Transparency + surveillance |
| **ICANN Compliance** | https://www.icann.org/resources/compliance | Signalement d'infractions registrar |

### Documentation complémentaire

- [ICANN — RDAP Overview](https://www.icann.org/rdap) : présentation officielle de la transition WHOIS → RDAP
- [IANA — Root Zone RDAP Bootstrap](https://www.iana.org/assignments/rdap-dns/rdap-dns.xhtml) : registre officiel des serveurs RDAP par TLD
- [ICANN — EPP Status Codes](https://www.icann.org/resources/pages/epp-status-codes-2014-06-16-en) : référence complète des codes de statut EPP avec descriptions
- [APWG eCrime Reports](https://apwg.org/resources/apwg-reports/) : rapports statistiques sur le phishing et l'usage frauduleux de domaines
