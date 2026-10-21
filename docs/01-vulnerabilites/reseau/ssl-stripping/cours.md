---
title: "SSL Stripping et Downgrade Attacks : Interception et Protections"
description: "Anatomie des attaques par rétrogradation HTTPS vers HTTP, contournement de STARTTLS, mécanismes de contournement MitM et contre-mesures (HSTS Preloading, Certificate Pinning, DANE, MTA-STS)."
tags:
  - ssl-stripping
  - downgrade-attack
  - mitm
  - hsts
  - starttls
  - dane
  - cert-pinning
  - security
  - red-team
  - blue-team
---

# SSL Stripping et Downgrade Attacks : Interception et Protections

## 1. Résumé Exécutif & Concepts Clés

Le **SSL Stripping** est une technique d'attaque **Man-in-the-Middle (MitM)** qui vise à intercepter la négociation initiale entre un client et un serveur pour forcer le maintien de la communication **en clair** — HTTP au lieu de HTTPS pour le web, ou SMTP en clair au lieu de STARTTLS pour la messagerie — sans jamais provoquer d'erreur de certificat côté client.

!!! danger "Impact principal"
    Contrairement à une attaque MitM classique sur TLS déjà établi (qui déclenche systématiquement un avertissement de certificat invalide dans le navigateur), le SSL Stripping agit **en amont**, avant même que le chiffrement ne soit négocié. La victime ne voit donc **aucun signal d'alerte visible** : jetons de session, identifiants, données personnelles peuvent être interceptés en clair, et du contenu malveillant peut être injecté à la volée dans les réponses.

Le point commun de toutes les variantes de downgrade attack traitées dans cette fiche est le même : exploiter le fait que la **première tentative de connexion** entre un client et un serveur se fait souvent, par défaut ou par habitude, en clair — laissant une fenêtre d'opportunité à un attaquant positionné sur le chemin réseau.

---

## 2. Méthodologie Offensive & Vecteurs d'Attaque

### A. Interception Web : SSL Stripping (HTTPS vers HTTP)

**Mécanisme historique et moderne**

1. **Positionnement MitM** : l'attaquant se place sur le chemin réseau entre la victime et sa passerelle, typiquement via [ARP Spoofing](../protocoles/arp.md) sur un réseau local, ou via un point d'accès Wi-Fi malveillant (rogue AP).
2. **Interception des requêtes initiales** : la victime tape une URL sans préciser de schéma (`exemple.com`) ou clique sur un lien `http://`, ce qui déclenche une première requête en clair — c'est ce **premier saut non chiffré** que l'attaquant exploite.
3. **Substitution à la volée** : l'attaquant réécrit dynamiquement tous les liens `https://` renvoyés par le serveur légitime en `http://` avant de les transmettre à la victime, ou utilise des domaines visuellement proches (homoglyphes, sous-domaines trompeurs de type *look-alike*).
4. **Double connexion asymétrique** : l'attaquant maintient une session **HTTPS légitime** avec le serveur cible (il agit comme un client normal de ce point de vue), tout en servant à la victime un flux **HTTP non chiffré** — se plaçant ainsi en relais transparent et déchiffrant.

```text
# Schéma synoptique du SSL Stripping

  Victime                    Attaquant (MitM)                 Serveur cible
     │                              │                                │
     │──── HTTP (en clair) ────────►│                                │
     │                              │──── HTTPS (chiffré) ──────────►│
     │                              │◄─── HTTPS (chiffré) ───────────│
     │◄─── HTTP (en clair,          │                                │
     │      liens réécrits) ────────│                                │

  La victime croit naviguer sur un site sans HTTPS disponible.
  L'attaquant voit l'intégralité du trafic en clair, y compris
  identifiants et cookies de session.
```

**Outillage de référence**

- **`sslstrip`** (Moxie Marlinspike, 2009) : l'outil historique ayant popularisé la technique, aujourd'hui largement neutralisé sur le web moderne par la généralisation de HSTS.
- **`bettercap`** : framework MitM moderne intégrant un module `http.proxy` capable de rejouer des techniques de stripping, de manipulation de contenu et de capture de identifiants.
- **`mitmproxy`** : proxy interactif permettant d'inspecter et de modifier en temps réel le trafic HTTP/HTTPS intercepté, utilisé aussi bien en test d'intrusion qu'en debugging légitime d'applications.

```text
# Exemple illustratif : lancement d'un module de proxy MitM avec bettercap
# (nécessite un positionnement réseau préalable, ex: ARP Spoofing actif)

$ sudo bettercap -iface eth0
» set arp.spoof.targets 192.168.1.10
» arp.spoof on
» set http.proxy.sslstrip true
» http.proxy on
```

### B. Interception Messagerie : Suppression de STARTTLS (STARTTLS Stripping)

Le même principe de rétrogradation s'applique aux protocoles de messagerie **SMTP**, **IMAP** et **POP3**, qui négocient historiquement TLS de manière **opportuniste** via une commande dédiée plutôt que sur un port dédié au chiffrement.

**Principe de l'attaque**

1. Le dialogue applicatif débute **en clair** (port 25 pour SMTP, 143 pour IMAP, 110 pour POP3).
2. Le serveur légitime annonce sa capacité à chiffrer la suite de la session via une réponse contenant `250-STARTTLS` (SMTP) ou une ligne `STARTTLS` dans sa réponse `CAPABILITY` (IMAP/POP3).
3. L'attaquant, positionné en MitM, **filtre ou altère** cette annonce avant qu'elle n'atteigne le client.
4. Le client, ne voyant pas la capacité STARTTLS annoncée, considère que le serveur ne supporte pas le chiffrement et **poursuit l'échange en clair** — y compris l'authentification.

```text
# Exemple : dialogue SMTP normal vs dialogue altéré par un attaquant

# --- Dialogue légitime (sans interception) ---
S: 220 mail.example.com ESMTP
C: EHLO client.example.com
S: 250-mail.example.com
S: 250-STARTTLS
S: 250 AUTH LOGIN
C: STARTTLS
   [négociation TLS, puis authentification chiffrée]

# --- Dialogue avec STARTTLS Stripping actif ---
S: 220 mail.example.com ESMTP
C: EHLO client.example.com
S: 250-mail.example.com          <-- ligne "250-STARTTLS" supprimée par l'attaquant
S: 250 AUTH LOGIN
C: AUTH LOGIN
C: [identifiants transmis EN CLAIR, base64 uniquement]
```

---

## 3. Contournement des Protections Basiques

Une protection naïve et largement insuffisante consiste à s'appuyer uniquement sur une **redirection serveur** de HTTP vers HTTPS (codes `301`/`302`).

!!! warning "Limite fondamentale des redirections serveur"
    Une redirection 301/302 est elle-même une **réponse HTTP en clair**. Le tout premier échange — la requête HTTP initiale du client et la redirection du serveur — reste donc totalement exposé à l'interception : c'est précisément ce **First-Hop** que le SSL Stripping cible et neutralise en interceptant ou en réécrivant la redirection avant qu'elle n'atteigne la victime. La redirection serveur seule ne protège en rien contre un attaquant déjà positionné en MitM.

Cette limite structurelle est ce qui justifie l'existence de mécanismes s'appuyant non plus sur le réseau, mais sur une **mémorisation côté client** (HSTS) ou sur une **publication cryptographiquement vérifiable** (DANE, MTA-STS), détaillés en section suivante.

---

## 4. Contre-Mesures & Architecture Défensive (Blue Team)

### A. Hardening Web : HSTS & HSTS Preloading

**HTTP Strict Transport Security (HSTS)**

HSTS est un en-tête de réponse HTTP, défini par la **RFC 6797**, qui indique au navigateur qu'un domaine ne doit **plus jamais** être contacté en HTTP pendant une durée donnée.

```text
# En-tête HSTS typique renvoyé par un serveur web
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

| Directive | Rôle |
|---|---|
| `max-age=31536000` | Durée (en secondes) pendant laquelle le navigateur doit forcer HTTPS pour ce domaine (ici, un an) |
| `includeSubDomains` | Étend la politique HSTS à l'ensemble des sous-domaines |
| `preload` | Marque l'intention du domaine à être inclus dans les listes de préchargement des navigateurs (voir ci-dessous) |

**Fonctionnement** : une fois l'en-tête reçu une première fois, le navigateur enregistre localement la politique et effectue, pour toute requête ultérieure vers ce domaine, une **redirection interne** (*Internal Redirect*) de HTTP vers HTTPS **avant même d'émettre la moindre requête sur le réseau**. Le First-Hop en clair n'existe donc plus, sauf lors de la toute première visite.

!!! warning "La faille résiduelle du 'premier accès'"
    HSTS ne protège pas la **toute première connexion** à un domaine que le navigateur n'a jamais visité : cette requête initiale reste émise en HTTP et donc vulnérable à un attaquant déjà en position MitM à ce moment précis.

**HSTS Preloading**

Pour éliminer ce risque résiduel du premier accès, les principaux moteurs de navigateurs (Chromium, Firefox, WebKit) maintiennent une **liste statique intégrée au binaire du navigateur**, listant les domaines qui doivent être contactés exclusivement en HTTPS, **dès la toute première requête**, sans jamais avoir reçu l'en-tête au préalable.

!!! tip "Soumission à la liste de préchargement"
    Un domaine respectant les prérequis (HTTPS valide sur tous les sous-domaines, en-tête HSTS avec `includeSubDomains` et `preload`, `max-age` suffisamment long) peut être soumis via [hstspreload.org](https://hstspreload.org). L'inclusion est cependant quasi irréversible à court terme : un retrait de la liste peut prendre plusieurs mois à se propager sur l'ensemble du parc de navigateurs déployés.

### B. Validation d'Identité : Certificate Pinning & HPKP

**Certificate Pinning**

Le Certificate Pinning consiste à associer, **au niveau de l'application cliente** (souvent une application mobile ou un client lourd plutôt qu'un navigateur généraliste), une empreinte spécifique attendue pour la clé publique ou le certificat du serveur. Toute présentation d'un certificat différent — même signé par une autorité de certification par ailleurs valide et reconnue par le système — est rejetée par l'application.

```text
# Illustration conceptuelle (pseudo-code) d'une vérification de pinning
# côté client mobile

expected_pubkey_hash = "sha256/AAAAB3NzaC1yc2EAAAADAQABAAAB..."

if sha256(server_certificate.public_key) != expected_pubkey_hash:
    abort_connection("Certificate pinning mismatch")
```

!!! danger "Compromis opérationnel du pinning"
    Le Certificate Pinning offre une protection forte contre une autorité de certification compromise ou contrainte, mais introduit un couplage fort entre l'application et le certificat serveur : toute rotation de certificat non anticipée côté serveur **casse la connectivité** de toutes les instances de l'application tant qu'une mise à jour n'a pas été déployée.

**Obsolescence de HPKP**

L'en-tête HTTP **HPKP** (*HTTP Public Key Pinning*) proposait un mécanisme équivalent directement pilotable via un en-tête de réponse HTTP, mais a été **déprécié et retiré** des navigateurs majeurs en raison de son risque élevé de mauvaise configuration (un épinglage erroné pouvant rendre un domaine durablement inaccessible, un scénario exploité par certains attaquants pour du ransomware de domaine). Il a été remplacé par une combinaison de HSTS et de la **Transparence des Certificats (Certificate Transparency, CT Logs)**, qui permet de détecter publiquement l'émission de certificats frauduleux pour un domaine sans imposer de couplage cassant côté client.

### C. Sécurisation DNS et Messagerie : DANE, TLSA & MTA-STS

**DANE (DNS-based Authentication of Named Entities)**

DANE, défini par la **RFC 6698**, permet de publier dans le DNS l'empreinte cryptographique attendue du certificat d'un service, via des enregistrements de type **TLSA**. Le client peut alors valider le certificat présenté par le serveur en le comparant à cette empreinte publiée, indépendamment de la chaîne de confiance des autorités de certification traditionnelles.

```text
# Exemple d'enregistrement DNS TLSA (format simplifié)
_443._tcp.exemple.com. IN TLSA 3 1 1 <empreinte-sha256-du-certificat>
```

!!! note "Dépendance stricte à DNSSEC"
    DANE n'a de valeur de sécurité que si les enregistrements `TLSA` sont eux-mêmes **signés via DNSSEC** : sans cette signature cryptographique de la zone DNS, un attaquant en position MitM capable également d'usurper des réponses DNS pourrait falsifier l'enregistrement TLSA lui-même, annulant la protection apportée.

**MTA-STS (Mail Transfer Agent Strict Transport Security)**

MTA-STS, défini par la **RFC 8461**, est l'équivalent conceptuel de HSTS pour le transport de courrier électronique entre serveurs (MTA à MTA). Il permet à un domaine de publier une politique forçant l'usage de TLS pour toute session SMTP entrante, neutralisant directement les attaques de STARTTLS Stripping décrites en section 2.B.

```text
# Exemple de fichier de politique MTA-STS
# publié sur https://mta-sts.example.com/.well-known/mta-sts.txt

version: STSv1
mode: enforce
mx: mail.example.com
max_age: 604800
```

| Mode | Comportement |
|---|---|
| `testing` | Les échecs TLS sont journalisés mais le message est tout de même délivré |
| `enforce` | Un échec de négociation TLS conforme à la politique entraîne le **rejet** de la remise du message |
| `none` | Désactive la politique (retour à un comportement opportuniste classique) |

**DMARC / TLS-RPT (SMTP TLS Reporting)**

Le mécanisme **TLS-RPT**, associé à MTA-STS, permet aux opérateurs de domaine de recevoir des **rapports agrégés** en provenance des serveurs expéditeurs, signalant les échecs de négociation TLS rencontrés lors de tentatives de remise vers leur domaine — offrant une visibilité opérationnelle sur des tentatives potentielles de rétrogradation ciblant leur infrastructure de messagerie.

```text
# Exemple d'enregistrement DNS TXT pour activer TLS-RPT
_smtp._tls.example.com. IN TXT "v=TLSRPTv1; rua=mailto:tls-reports@example.com"
```

---

## 5. Tableau Synthétique : Attaques vs Protections

| Vecteur de rétrogradation | Protocole ciblé | Mécanisme de défense | Niveau d'efficacité |
|---|---|---|---|
| SSL Stripping (réécriture de liens `https://` → `http://`) | HTTP/HTTPS | HSTS (`Strict-Transport-Security`) | Partiel (inefficace au tout premier accès) |
| SSL Stripping sur premier accès jamais visité | HTTP/HTTPS | HSTS Preloading | Complet (pour les domaines inclus dans la liste) |
| Substitution de certificat par une AC compromise/contrainte | HTTPS | Certificate Pinning | Complet (au prix d'un couplage opérationnel fort) |
| Falsification de certificat malgré une AC valide | HTTPS/DNS | DANE / TLSA (avec DNSSEC) | Complet (conditionné à l'intégrité DNSSEC de la zone) |
| STARTTLS Stripping (suppression de l'annonce `250-STARTTLS`) | SMTP/IMAP/POP3 | MTA-STS (`mode: enforce`) | Complet (pour le transport SMTP inter-domaines) |
| Rétrogradation TLS non détectée en messagerie | SMTP | TLS-RPT | Détection/supervision uniquement (pas de blocage) |

---

## 6. Anti-Sèche Commandes CLI & Audit (Cheat Sheet)

```text
# ============================
# VÉRIFICATION DES EN-TÊTES HSTS
# ============================

# Afficher uniquement les en-têtes de réponse HTTP(S)
$ curl -I https://exemple.com

# Filtrer spécifiquement la présence de l'en-tête HSTS
$ curl -sI https://exemple.com | grep -i "strict-transport-security"

# ============================
# INSPECTION DES ENREGISTREMENTS TLSA (DANE)
# ============================

# Interroger l'enregistrement TLSA pour un service HTTPS
$ dig TLSA _443._tcp.exemple.com

# Vérifier que la zone est bien signée DNSSEC (bit AD = Authenticated Data)
$ dig +dnssec exemple.com A

# ============================
# VALIDATION D'UNE POLITIQUE MTA-STS
# ============================

# Récupérer et afficher le fichier de politique MTA-STS publié
$ curl -s https://mta-sts.exemple.com/.well-known/mta-sts.txt

# Vérifier l'enregistrement DNS TXT associé (version de la politique)
$ dig TXT _mta-sts.exemple.com
```

---

## 7. Références

- **RFC 6797** – *HTTP Strict Transport Security (HSTS)*
- **RFC 6698** – *The DNS-Based Authentication of Named Entities (DANE) Transport Layer Security (TLS) Protocol: TLSA*
- **RFC 8461** – *SMTP MTA Strict Transport Security (MTA-STS)*
- Guides de recommandations HTTPS/TLS de l'**ANSSI**
