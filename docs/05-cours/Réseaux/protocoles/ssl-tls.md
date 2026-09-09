---
title: "Protocoles SSL / TLS : Cryptographie, Handshake et Sécurité"
description: "Anatomie des protocoles SSL et TLS, déroulement du Handshake (1.2 vs 1.3), PKI et certificats, suites de chiffrement, attaques historiques et recommandations de hardening."
tags:
  - ssl
  - tls
  - cryptography
  - pki
  - network
  - security
  - hardening
---

# Protocoles SSL / TLS : Cryptographie, Handshake et Sécurité

!!! note "Public visé"
    Cette fiche s'adresse aux administrateurs systèmes/réseau, pentesters et architectes sécurité souhaitant comprendre le fonctionnement cryptographique de TLS, auditer une configuration existante et appliquer les recommandations de durcissement actuelles.

## 1. Résumé Exécutif & Historique

**TLS (Transport Layer Security)** est un protocole cryptographique assurant la confidentialité, l'intégrité et l'authentification des communications au-dessus de la couche transport (positionné entre les couches 4 et 7 du modèle OSI, souvent qualifié de couche 5/6 dans les représentations pédagogiques). Il protège la donnée applicative (HTTP, SMTP, IMAP, etc.) transitant sur un réseau potentiellement hostile.

!!! danger "Obsolescence de SSL et des premières versions TLS"
    L'ensemble des versions suivantes est **formellement déprécié** et ne doit plus être utilisé en production :

    - **SSL 2.0** et **SSL 3.0** — protocoles historiques, vulnérabilités structurelles majeures (voir section 5).
    - **TLS 1.0** (RFC 2246, 1999) et **TLS 1.1** (RFC 4346, 2006) — dépréciés par l'IETF via la **RFC 8996** (mars 2021), retirés du support des principaux navigateurs et référentiels de conformité (PCI-DSS notamment).

    Seules **TLS 1.2** (RFC 5246) et **TLS 1.3** (RFC 8446) doivent être activées sur une infrastructure moderne.

```
Chronologie simplifiée
------------------------
SSL 2.0 (1995) --> SSL 3.0 (1996) --> TLS 1.0 (1999) --> TLS 1.1 (2006)
                                                                |
                              [OBSOLÈTES - à désactiver]        v
                                                        TLS 1.2 (2008) --> TLS 1.3 (2018)
                                                        [ACTUELS - à maintenir]
```

---

## 2. Infrastructure à Clé Publique (PKI) & Certificats

### 2.1 Composants clés

!!! info "Éléments de la PKI"
    - **Autorité de Certification (CA)** : entité de confiance qui signe et délivre des certificats attestant du lien entre une identité (nom de domaine) et une clé publique.
    - **Chaîne de confiance (Trust Chain)** : suite de certificats reliant le certificat serveur (*leaf*) à une **CA racine** (root CA) via un ou plusieurs certificats intermédiaires, chaque maillon étant signé par le niveau supérieur.
    - **Certificat serveur X.509** : structure normalisée contenant l'identité du sujet, la clé publique, la période de validité, les usages autorisés et la signature de l'autorité émettrice.
    - **Clé privée / Clé publique** : paire asymétrique où la clé publique est diffusée dans le certificat et la clé privée reste strictement confidentielle côté serveur, utilisée pour prouver la possession du certificat lors du handshake.

```
Chaîne de confiance typique
-----------------------------

  [CA Racine - Root CA]   (auto-signée, préinstallée dans le magasin de confiance du client)
          |
          | signe
          v
  [CA Intermédiaire]      (délivrée par la CA racine, souvent utilisée pour l'émission courante)
          |
          | signe
          v
  [Certificat serveur]    (leaf / certificat final présenté au client, ex: exemple.com)
```

### 2.2 Mécanismes de vérification de révocation

| Mécanisme | Fonctionnement | Limite principale |
|---|---|---|
| **CRL (Certificate Revocation List)** | Liste complète des certificats révoqués, publiée périodiquement par la CA | Fichier volumineux, latence de mise à jour |
| **OCSP (Online Certificate Status Protocol)** | Requête en temps réel auprès de la CA sur le statut d'un certificat unique | Fuite d'information (la CA connaît les sites visités), latence réseau supplémentaire |
| **OCSP Stapling** | Le serveur obtient et joint (*staple*) une réponse OCSP signée directement dans le handshake | Résout la latence et la fuite de confidentialité vers la CA ; recommandé en production |

### 2.3 SAN et Transparence des Certificats (CT Logs)

Le champ **SAN (Subject Alternative Name)** liste l'ensemble des noms de domaine couverts par un certificat (domaine principal, sous-domaines, wildcards). C'est le mécanisme de validation effectivement utilisé par les navigateurs modernes, le champ historique *Common Name (CN)* étant désormais ignoré à ce titre.

Les **CT Logs (Certificate Transparency)** sont des journaux publics, infalsifiables (structure Merkle Tree), dans lesquels toute CA conforme doit publier chaque certificat émis. Ils permettent de détecter l'émission frauduleuse de certificats pour un domaine donné.

```bash
# Extraire les SAN d'un certificat distant via openssl
echo | openssl s_client -connect exemple.com:443 -servername exemple.com 2>/dev/null \
  | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
```

---

## 3. Anatomie du Handshake TLS

### 3.1 Handshake TLS 1.2 (2 Round Trips / 2-RTT)

```
Client                                                    Serveur
  |                                                           |
  |------------------- ClientHello ------------------------->|
  |   (versions supportées, cipher suites proposées, random)  |
  |                                                           |
  |<------------------ ServerHello ---------------------------|
  |   (version/cipher retenus, random serveur)                |
  |<------------------ Certificate ----------------------------|
  |   (certificat serveur X.509)                               |
  |<------------------ ServerKeyExchange -----------------------|
  |   (paramètres Diffie-Hellman éphémères si suite ECDHE/DHE) |
  |<------------------ ServerHelloDone --------------------------|
  |                                                           |
  |------------------- ClientKeyExchange --------------------->|
  |   (matériel de clé client)                                 |
  |------------------- ChangeCipherSpec ------------------------>|
  |------------------- Finished (chiffré) ----------------------->|
  |                                                           |
  |<------------------ ChangeCipherSpec --------------------------|
  |<------------------ Finished (chiffré) ---------------------------|
  |                                                           |
  |============ Données applicatives chiffrées ================|

  -> 2 allers-retours complets avant le premier octet de données applicatives
```

### 3.2 Handshake TLS 1.3 (1-RTT, et 0-RTT / Early Data)

TLS 1.3 (RFC 8446) restructure profondément le handshake : le client anticipe les paramètres cryptographiques dès le premier message, supprimant un aller-retour complet.

```
Client                                                    Serveur
  |                                                           |
  |------------------- ClientHello -------------------------->|
  |   (cipher suites, groupes DH supportés + clé publique     |
  |    éphémère "key_share" envoyée directement)               |
  |                                                           |
  |<------------------ ServerHello -----------------------------|
  |   (paramètres retenus + key_share serveur)                 |
  |<== [dès ce point, le reste est chiffré] ====================|
  |<------------------ EncryptedExtensions -----------------------|
  |<------------------ Certificate --------------------------------|
  |<------------------ CertificateVerify ----------------------------|
  |<------------------ Finished --------------------------------------|
  |                                                           |
  |------------------- Finished (chiffré) ------------------------>|
  |                                                           |
  |============ Données applicatives chiffrées (dès 1-RTT) ====|

  -> 1 seul aller-retour avant le premier octet de données applicatives
```

!!! tip "0-RTT / Early Data"
    Lors d'une **reprise de session** (le client a déjà communiqué précédemment avec le serveur et dispose d'un *PSK - Pre-Shared Key* issu d'une session antérieure), TLS 1.3 permet d'envoyer des données applicatives **dès le premier message**, sans attendre la fin du handshake. Ce mode **0-RTT** améliore fortement la latence perçue mais introduit un risque de **rejeu (replay attack)** sur les données envoyées en 0-RTT : il doit être réservé aux requêtes idempotentes (ex: GET sans effet de bord), jamais à des opérations sensibles (paiement, changement d'état).

!!! danger "Simplifications majeures de TLS 1.3"
    - Suppression du **RSA Key Exchange statique** (absence de Forward Secrecy) : seuls les échanges de clés **éphémères** (ECDHE/DHE) sont désormais autorisés.
    - Suppression des mécanismes de compression (source de l'attaque CRIME, voir section 5).
    - Suppression des suites de chiffrement CBC non-AEAD, des ciphers RC4, DES, MD5 et de la renégociation non authentifiée.

### 3.3 Forward Secrecy (PFS - Perfect Forward Secrecy)

!!! info "Principe"
    La **Forward Secrecy** garantit que la compromission ultérieure de la clé privée long-terme du serveur ne permet **pas** de déchiffrer rétroactivement des sessions passées interceptées et enregistrées. Elle repose sur l'utilisation d'un échange de clé **éphémère** — notamment **ECDHE (Elliptic Curve Diffie-Hellman Ephemeral)** — où une nouvelle paire de clés est générée pour chaque session et détruite après usage, contrairement à un échange RSA statique où une seule clé privée compromise expose l'ensemble du trafic historiquement capturé.

    TLS 1.3 impose PFS de façon systématique en supprimant tout mode d'échange de clé non éphémère.

---

## 4. Suites de Chiffrement (Cipher Suites)

### 4.1 Anatomie d'une cipher suite (TLS 1.2)

```
TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
 |     |      |        |        |
 |     |      |        |        +-- Fonction de hachage pour le PRF/HMAC (SHA256)
 |     |      |        +----------- Chiffrement symétrique AEAD (AES-128 en mode GCM)
 |     |      +-------------------- Mot-clé de séparation
 |     +--------------------------- Algorithme d'authentification du serveur (certificat RSA)
 +--------------------------------- Algorithme d'échange de clé (ECDHE, éphémère)
```

| Composant | Rôle | Exemples |
|---|---|---|
| Échange de clés | Établit le secret partagé de session | ECDHE, DHE, RSA (statique, obsolète) |
| Authentification | Prouve l'identité du serveur (via le certificat) | RSA, ECDSA |
| Chiffrement symétrique (AEAD) | Chiffre les données applicatives + garantit l'intégrité | AES-GCM, AES-CCM, ChaCha20-Poly1305 |
| Hachage / MAC | Dérivation de clés et intégrité des messages du handshake | SHA-256, SHA-384 |

### 4.2 Simplification sous TLS 1.3

TLS 1.3 réduit drastiquement le nombre de suites disponibles (5 suites majeures normalisées) en supprimant toute mention de l'échange de clé et de l'authentification dans le nom de la suite — ces deux aspects étant négociés séparément via les extensions `key_share` et `signature_algorithms`.

```text
# Les 5 cipher suites TLS 1.3 normalisées (RFC 8446)

TLS_AES_128_GCM_SHA256
TLS_AES_256_GCM_SHA384
TLS_CHACHA20_POLY1305_SHA256
TLS_AES_128_CCM_SHA256
TLS_AES_128_CCM_8_SHA256
```

!!! note "Pourquoi cette simplification"
    En imposant un échange de clé éphémère unique (ECDHE/DHE) et en excluant tout algorithme jugé faible dès la conception du protocole, TLS 1.3 élimine la classe entière de vulnérabilités liées à la négociation d'une suite obsolète (voir attaques de rétrogradation, section 5.1).

---

## 5. Attaques Historiques & Vulnérabilités

### 5.1 Attaques sur la négociation / Rétrogradation

!!! danger "POODLE (2014)"
    Exploite une faiblesse du mode **CBC de SSL 3.0** combinée à un mécanisme de repli (*fallback*) permettant à un attaquant MitM de forcer artificiellement une négociation vers SSL 3.0 même lorsque des versions plus récentes sont supportées, puis d'exploiter le padding CBC pour déchiffrer progressivement des données (ex: cookies de session).

!!! danger "FREAK (2015)"
    Exploite la présence résiduelle de suites **EXPORT** (chiffrement volontairement affaibli, héritage des restrictions d'exportation cryptographique américaines des années 1990) encore acceptées par certains serveurs/clients, permettant à un attaquant de forcer l'usage d'une clé RSA de 512 bits factorisable en temps raisonnable.

!!! danger "Logjam (2015)"
    Attaque similaire à FREAK mais ciblant l'échange **Diffie-Hellman** : force la négociation vers des paramètres DH faibles (512 bits, groupes EXPORT), rendant le calcul du logarithme discret praticable pour un attaquant disposant de ressources de calcul conséquentes.

### 5.2 Attaques sur le chiffrement par bloc / CBC

!!! danger "BEAST (2011)"
    Exploite une faiblesse du **mode CBC dans TLS 1.0** liée à la prévisibilité du vecteur d'initialisation (IV) entre enregistrements successifs, permettant sous certaines conditions de déchiffrer partiellement des données chiffrées (ex: cookies) via une attaque de type *chosen-plaintext*.

!!! danger "Lucky 13 (2013)"
    Attaque temporelle (*timing attack*) exploitant de subtiles différences de temps de traitement lors de la vérification du padding et du MAC dans les implémentations CBC de TLS, permettant à un attaquant patient d'inférer progressivement le contenu chiffré.

### 5.3 Faiblesses d'implémentation

!!! danger "Heartbleed (2014) — CVE-2014-0160"
    Vulnérabilité critique dans l'implémentation de l'extension **Heartbeat** d'**OpenSSL** (versions 1.0.1 à 1.0.1f), permettant à un attaquant d'envoyer une requête heartbeat falsifiée déclenchant une lecture hors limites (*buffer over-read*) sur le serveur, exposant jusqu'à 64 Ko de mémoire process à chaque requête — pouvant inclure clés privées, cookies de session ou identifiants en mémoire. Illustre le risque lié à une faille d'implémentation indépendante de la conception théorique du protocole.

### 5.4 Renegotiation Attacks et compression

!!! danger "TLS Renegotiation Attack (2009) — CVE-2009-3555"
    Exploite l'absence de liaison cryptographique entre une session TLS initiale et une renégociation ultérieure, permettant à un attaquant MitM d'injecter du contenu au début d'une session avant qu'elle ne soit renégociée par le client légitime (typiquement exploité contre HTTP pour de l'injection de requêtes).

!!! danger "CRIME (2012) & BREACH (2013)"
    Exploitent la **compression** appliquée respectivement au niveau du protocole TLS (CRIME) ou au niveau HTTP (BREACH) : en observant la variation de taille des données compressées en réponse à des injections de contenu contrôlées par l'attaquant, il devient possible d'inférer progressivement le contenu de secrets présents dans la réponse (ex: jetons CSRF). Ces attaques ont conduit à la suppression de la compression au niveau TLS et à des recommandations de prudence pour la compression HTTP sur du contenu sensible.

---

## 6. Audit & Énumération Offensive (Red Team)

### 6.1 Discovery de sous-domaines via les champs SAN

Les certificats émis publiquement étant journalisés dans les **CT Logs** (section 2.3), leur consultation permet de découvrir des sous-domaines non référencés par ailleurs, y compris des environnements de test ou d'administration insuffisamment cloisonnés.

```bash
# Extraction directe des SAN d'un certificat distant
echo | openssl s_client -connect exemple.com:443 -servername exemple.com 2>/dev/null \
  | openssl x509 -noout -ext subjectAltName
```

### 6.2 Outils d'audit de configuration

```bash
# openssl s_client - inspection manuelle d'une connexion TLS
# Affiche la chaîne de certificats, le protocole négocié et la cipher suite retenue
openssl s_client -connect exemple.com:443 -servername exemple.com

# Forcer le test d'une version de protocole spécifique (vérifier si TLS 1.0 est encore accepté)
openssl s_client -connect exemple.com:443 -tls1

# testssl.sh - audit automatisé complet (protocoles, ciphers, vulnérabilités connues)
./testssl.sh exemple.com:443

# testssl.sh - se concentrer uniquement sur les vulnérabilités historiques connues
./testssl.sh --vulnerable exemple.com:443

# nmap - énumération des cipher suites supportées via le script NSE dédié
nmap --script ssl-enum-ciphers -p 443 exemple.com
```

### 6.3 Repérage de configurations faibles

!!! warning "Éléments à identifier lors d'un audit"
    - **Protocoles obsolètes acceptés** : SSLv2, SSLv3, TLS 1.0, TLS 1.1 encore actifs en parallèle de TLS 1.2/1.3.
    - **Suites de chiffrement faibles** : suites contenant `NULL` (absence de chiffrement), `RC4` (biais statistiques connus), `EXPORT` (héritage FREAK/Logjam), `DES`/`3DES` (bloc 64 bits vulnérable, attaque *Sweet32*), `MD5` (collision pratique démontrée).
    - **Absence de Forward Secrecy** : suites RSA statiques sans ECDHE/DHE encore proposées en priorité par le serveur.
    - **Certificat expiré, auto-signé en production, ou chaîne de confiance incomplète.**

```text
# Extrait illustratif de sortie nmap --script ssl-enum-ciphers signalant une faiblesse

|   TLSv1.0:
|     ciphers:
|       TLS_RSA_WITH_RC4_128_SHA - C          <- suite faible : RC4 + absence de PFS
|   least strength: C
```

---

## 7. Hardening & Recommandations (Blue Team)

### 7.1 Politique de version

!!! tip "Recommandation ANSSI / Mozilla"
    N'activer que **TLS 1.2** et **TLS 1.3**. Désactiver explicitement SSLv2, SSLv3, TLS 1.0 et TLS 1.1 sur l'ensemble des services exposés (web, mail, VPN, API internes comprises).

### 7.2 Désactivation des algorithmes faibles

- Exclure toute suite **non-PFS** (RSA Key Exchange statique).
- Exclure les suites **CBC** au profit des modes **AEAD** (GCM, ChaCha20-Poly1305) lorsque TLS 1.2 doit être conservé pour compatibilité.
- Bannir totalement **RC4**, **DES/3DES**, **MD5** et les suites **EXPORT** ou **NULL**.

### 7.3 En-têtes de sécurité web associées

```text
# HSTS (HTTP Strict Transport Security)
# includeSubDomains : applique la contrainte à l'ensemble des sous-domaines
# preload : permet l'inscription dans la liste de préchargement embarquée des navigateurs
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```

!!! warning "Précaution avant activation de `preload`"
    L'inscription dans la liste de préchargement HSTS est difficilement réversible (délai de propagation important dans les navigateurs). Elle ne doit être activée qu'après validation que **l'intégralité** des sous-domaines du domaine concerné supportent effectivement HTTPS.

### 7.4 Exemples de configuration serveur

```nginx
# Nginx - configuration TLS durcie (inspirée des recommandations Mozilla "Modern"/ANSSI)

server {
    listen 443 ssl http2;
    server_name exemple.com;

    ssl_certificate     /etc/ssl/certs/exemple.com.fullchain.pem;
    ssl_certificate_key /etc/ssl/private/exemple.com.key;

    # Uniquement TLS 1.2 et 1.3
    ssl_protocols TLSv1.2 TLSv1.3;

    # Suites de chiffrement pour TLS 1.2 (AEAD uniquement, PFS obligatoire)
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_prefer_server_ciphers on;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
}
```

```apache
# Apache httpd - configuration TLS durcie équivalente

SSLEngine on
SSLCertificateFile      /etc/ssl/certs/exemple.com.fullchain.pem
SSLCertificateKeyFile   /etc/ssl/private/exemple.com.key

# Uniquement TLS 1.2 et 1.3
SSLProtocol -all +TLSv1.2 +TLSv1.3

SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305
SSLHonorCipherOrder on

# OCSP Stapling
SSLUseStapling on
SSLStaplingCache "shmcb:/var/run/ocsp(128000)"

# HSTS
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
```

!!! tip "Outil de référence"
    Le **Mozilla SSL Configuration Generator** permet de générer une configuration adaptée (profils *Modern*, *Intermediate*, *Old*) selon les contraintes de compatibilité client, en cohérence avec les recommandations ANSSI relatives au choix des mécanismes cryptographiques.

---

## 8. Anti-Sèche Commandes CLI (Cheat Sheet)

```bash
# --- Inspection d'un certificat distant ---

# Connexion et affichage brut de la chaîne de certificats
openssl s_client -connect exemple.com:443 -servername exemple.com

# Affichage détaillé du certificat serveur (texte lisible)
echo | openssl s_client -connect exemple.com:443 -servername exemple.com 2>/dev/null \
  | openssl x509 -noout -text

# Extraction de la date d'expiration
echo | openssl s_client -connect exemple.com:443 -servername exemple.com 2>/dev/null \
  | openssl x509 -noout -dates

# Extraction de l'empreinte SHA-256 du certificat
echo | openssl s_client -connect exemple.com:443 -servername exemple.com 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha256


# --- Test des versions de protocole supportées ---

openssl s_client -connect exemple.com:443 -tls1_2
openssl s_client -connect exemple.com:443 -tls1_3


# --- Audit automatisé ---

# Audit complet
./testssl.sh exemple.com:443

# Vulnérabilités connues uniquement
./testssl.sh --vulnerable exemple.com:443

# Énumération des cipher suites via nmap
nmap --script ssl-enum-ciphers -p 443 exemple.com


# --- Vérification côté client (curl) ---

# Afficher les informations TLS de la connexion établie par curl
curl -vI https://exemple.com 2>&1 | grep -i "SSL\|TLS"
```

---

## 9. Références

- **RFC 5246** — *The Transport Layer Security (TLS) Protocol Version 1.2*, IETF.
- **RFC 8446** — *The Transport Layer Security (TLS) Protocol Version 1.3*, IETF.
- **RFC 8996** — *Deprecating TLS 1.0 and TLS 1.1*, IETF.
- **ANSSI** — Guide des mécanismes cryptographiques et recommandations de sécurité relatives à TLS.
- **Mozilla SSL Configuration Generator** — profils de configuration serveur *Modern / Intermediate / Old*.

!!! note "Mentions complémentaires"
    Les exemples de configuration Nginx/Apache présentés dans ce document sont volontairement génériques ; les suites de chiffrement, chemins de certificats et paramètres OCSP doivent être adaptés à la version logicielle et à l'environnement de production réellement déployés.
