---
title: "Protocole SMTP, SMTPS et STARTTLS : Mécanismes et Sécurité Email"
description: "Anatomie complète du protocole SMTP, comparaison SMTPS vs STARTTLS, relais ouverts, mécanismes d'authentification et attaques associées."
tags:
  - smtp
  - smtps
  - starttls
  - email-security
  - network
  - posture
  - spf
  - dkim
  - dmarc
  - open-relay
---

# Protocole SMTP, SMTPS et STARTTLS : Mécanismes et Sécurité Email

!!! warning "Cadre légal"
    Les techniques d'audit et d'exploitation décrites dans ce document (énumération, test de relais ouvert, forge d'enveloppe) ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite. L'envoi non autorisé de courriels usurpés vers des tiers réels constitue une infraction dans la quasi-totalité des juridictions.

---

## 1. Résumé exécutif & définition

**SMTP** (*Simple Mail Transfer Protocol*, RFC 5321) est le protocole de transport chargé d'acheminer un message électronique depuis son point d'émission jusqu'à la boîte de réception du destinataire. Il intervient à plusieurs niveaux de la chaîne de messagerie, portés par des rôles distincts :

- **MUA** (*Mail User Agent*) : le client de messagerie utilisé par l'utilisateur final (Outlook, Thunderbird, webmail) pour rédiger et soumettre un message.
- **MTA** (*Mail Transfer Agent*) : le serveur chargé de relayer le message d'un domaine à un autre (Postfix, Exim, Sendmail). C'est le cœur du protocole SMTP historique.
- **MDA** (*Mail Delivery Agent*) : le composant qui dépose finalement le message dans la boîte aux lettres du destinataire, généralement accédée ensuite via IMAP ou POP3 — hors du périmètre direct de SMTP.

!!! note "SMTP transporte, il ne stocke ni ne consulte"
    SMTP ne concerne que l'acheminement du message entre serveurs et la soumission par le client. La consultation d'une boîte de réception relève d'autres protocoles (IMAP, POP3), ce qui explique qu'un serveur SMTP mal configuré peut être exploité pour l'envoi sans jamais exposer directement le contenu des boîtes aux lettres.

### Trois ports, trois usages distincts

| Port | Nom | Usage principal |
|---|---|---|
| **25/TCP** | SMTP historique | Transfert **inter-serveurs** (MTA → MTA), historiquement en clair, sans authentification entre relais de confiance |
| **587/TCP** | SMTP Submission | Soumission d'un message par un **client** (MUA → MTA), authentification **obligatoire**, chiffrement via **STARTTLS** |
| **465/TCP** | SMTPS (implicite) | Soumission client équivalente au port 587, mais avec un chiffrement TLS établi **immédiatement** dès l'ouverture du socket TCP, avant tout dialogue SMTP en clair |

!!! tip "Retenir la distinction essentielle"
    Le port 25 sert au relais entre serveurs de messagerie (Internet backbone du mail). Les ports 587 et 465 servent à la soumission par un client final authentifié — c'est la porte par laquelle un utilisateur envoie effectivement son courrier via son propre fournisseur.

---

## 2. Anatomie détaillée d'une session SMTP

### Dialogue client-serveur

Une session SMTP est un échange textuel synchrone, commande par commande, chaque commande client recevant une réponse numérotée du serveur.

```text
CLIENT : EHLO client.exemple.com
SERVEUR: 250-mail.cible.com Hello client.exemple.com
SERVEUR: 250-SIZE 35882577
SERVEUR: 250-STARTTLS
SERVEUR: 250-AUTH LOGIN PLAIN
SERVEUR: 250 OK

CLIENT : MAIL FROM:<expediteur@exemple.com>
SERVEUR: 250 OK

CLIENT : RCPT TO:<destinataire@cible.com>
SERVEUR: 250 OK

CLIENT : DATA
SERVEUR: 354 Start mail input; end with <CRLF>.<CRLF>

CLIENT : From: "Expediteur" <expediteur@exemple.com>
CLIENT : To: destinataire@cible.com
CLIENT : Subject: Test
CLIENT :
CLIENT : Corps du message.
CLIENT : .
SERVEUR: 250 OK: queued as 4A3B2C1D

CLIENT : QUIT
SERVEUR: 221 Bye
```

**Commandes fondamentales :**

| Commande | Rôle |
|---|---|
| `HELO` / `EHLO` | Présentation du client au serveur. `EHLO` (Extended HELO) déclenche l'annonce des extensions supportées (`STARTTLS`, `AUTH`, `SIZE`...) |
| `MAIL FROM:` | Déclare l'expéditeur au niveau de l'**enveloppe** SMTP (utilisé pour le retour d'erreur — bounce) |
| `RCPT TO:` | Déclare le destinataire au niveau de l'enveloppe (peut être répété pour plusieurs destinataires) |
| `DATA` | Ouvre la saisie du corps du message, incluant ses propres en-têtes (`From:`, `To:`, `Subject:`), terminée par une ligne contenant uniquement un point `.` |
| `QUIT` | Termine proprement la session |

!!! danger "Enveloppe vs en-tête : la racine technique du spoofing"
    SMTP distingue strictement deux notions d'expéditeur, qui **n'ont techniquement aucune obligation de correspondre** :

    - L'**expéditeur d'enveloppe** (`MAIL FROM:`), utilisé uniquement pour le routage et les notifications d'erreur (bounce), invisible pour l'utilisateur final dans son client de messagerie.
    - L'**en-tête `From:`** inséré dans le corps `DATA`, qui est la seule information affichée par le client de messagerie du destinataire.

    Un serveur SMTP qui n'implémente aucun contrôle complémentaire (SPF, DKIM, DMARC) accepte par défaut n'importe quelle valeur arbitraire dans ces deux champs, sans jamais vérifier qu'elles correspondent à un domaine que l'expéditeur contrôle réellement. C'est cette absence de contrôle intrinsèque au protocole de base qui rend le spoofing d'email possible.

### Codes de réponse clés

| Code | Signification |
|---|---|
| `220` | Bannière de connexion / serveur prêt |
| `250` | Action terminée avec succès (OK) |
| `354` | Le serveur attend la saisie du corps du message (suite à `DATA`) |
| `421` | Service indisponible, fermeture du canal de transmission |
| `451` | Erreur temporaire côté serveur — à retenter plus tard |
| `550` | Action refusée : destinataire inconnu, boîte inexistante, ou politique refusant explicitement le message |
| `554` | Transaction échouée (souvent utilisé pour un rejet ferme lié à une politique anti-spam) |

### Sécurisation des flux : STARTTLS vs SMTPS

**STARTTLS** (RFC 3207) est une commande qui **élève dynamiquement** une connexion initialement en clair vers une session chiffrée TLS, sur un port qui reste identique (25 ou 587) :

```text
CLIENT : EHLO client.exemple.com
SERVEUR: 250-mail.cible.com Hello
SERVEUR: 250-STARTTLS
SERVEUR: 250 AUTH LOGIN PLAIN

CLIENT : STARTTLS
SERVEUR: 220 2.0.0 Ready to start TLS

[Négociation TLS — la session devient chiffrée à partir de cet instant]

CLIENT : EHLO client.exemple.com   ← seconde EHLO obligatoire après la négociation TLS
```

À l'inverse, **SMTPS implicite** (port 465) établit le chiffrement TLS **avant tout échange SMTP**, dès l'ouverture du socket TCP — aucune commande de dialogue en clair n'est jamais transmise, y compris la bannière initiale.

!!! warning "Attaque par rétrogradation — STARTTLS Stripping"
    Parce que STARTTLS démarre par un échange en clair (`EHLO`, annonce de l'extension `STARTTLS`), un attaquant en position de Man-in-the-Middle peut intercepter la session et **supprimer ou altérer la ligne `250-STARTTLS`** annoncée par le serveur avant qu'elle n'atteigne le client. Si le client n'est pas configuré pour **exiger** impérativement le chiffrement (`smtp_tls_security_level = encrypt` côté MTA, ou équivalent côté client), celui-ci retombe silencieusement sur une transmission en clair, exposant les identifiants SASL et le contenu du message.

    **SMTPS implicite (port 465) n'est structurellement pas exposé à cette classe d'attaque**, puisqu'aucun octet n'est jamais transmis en clair avant l'établissement complet du canal TLS.

---

## 3. Matrice comparative des ports & modes

| Port | Usage principal | Mécanisme de chiffrement | Authentification obligatoire | Niveau de risque en clair |
|---|---|---|---|---|
| **25/TCP** | Relais inter-serveurs MTA → MTA | Optionnel via `STARTTLS` (opportuniste, rarement imposé entre MTA publics) | Non (relais de confiance historiquement basé sur l'IP source) | Élevé — la majorité du trafic inter-domaines mondial reste transmis sans garantie de chiffrement de bout en bout |
| **587/TCP** | Soumission client (MUA → MTA) | `STARTTLS` (élévation dynamique) | Oui — SASL (`AUTH LOGIN`, `AUTH PLAIN`, etc.) | Modéré — vulnérable au STARTTLS stripping si le client n'exige pas explicitement le chiffrement |
| **465/TCP** | Soumission client (MUA → MTA), historique/alternative | TLS implicite dès l'ouverture du socket | Oui — SASL | Faible — aucune fenêtre de clair possible avant chiffrement complet |

---

## 4. Empreinte, audit & méthodologie d'exploitation (Red Team)

### Énumération d'utilisateurs & bannières

Les commandes historiques `VRFY` (vérification d'existence d'une adresse) et `EXPN` (expansion d'une liste de diffusion en adresses individuelles) permettent, lorsqu'elles sont activées, une énumération directe et fiable des comptes valides sur un domaine.

```bash
# Connexion manuelle via telnet pour tester VRFY/EXPN
telnet mail.cible.com 25
```

```text
220 mail.cible.com ESMTP Postfix
VRFY admin
252 2.0.0 admin
VRFY compte_inexistant_xyz
550 5.1.1 <compte_inexistant_xyz>: Recipient address rejected: User unknown
EXPN liste-diffusion
250 2.1.5 jdupont@cible.com
250 2.1.5 mmartin@cible.com
```

!!! danger "Oracle direct d'énumération"
    Une réponse `252` ou `250` sur `VRFY` confirme l'existence d'un compte ; une réponse `550` confirme son absence. Ce différentiel constitue un oracle d'énumération exploitable pour construire des listes d'adresses valides en vue d'une campagne de phishing ciblée, ou pour du password spraying ultérieur sur les services d'authentification exposés (webmail, VPN, SSO).

**Automatisation via Nmap :**

```bash
# Grabbing de bannière et détection des commandes supportées
nmap -p25,465,587 --script smtp-commands mail.cible.com

# Énumération automatisée d'utilisateurs via VRFY/EXPN/RCPT TO
nmap -p25 --script smtp-enum-users \
     --script-args smtp-enum-users.methods={VRFY,EXPN,RCPT} \
     mail.cible.com
```

### Relais ouvert (Open Relay)

Un **relais ouvert** est un serveur SMTP qui accepte de relayer un message vers un domaine externe **sans authentification préalable et sans que l'expéditeur ni le destinataire n'appartiennent à un domaine géré localement**. Historiquement fréquent avant la généralisation de l'authentification SASL obligatoire, ce défaut de configuration reste identifié régulièrement sur des MTA mal durcis.

```bash
# Test manuel d'un relais ouvert via netcat
nc mail.cible.com 25
```

```text
220 mail.cible.com ESMTP
EHLO test.exemple.com
250 mail.cible.com
MAIL FROM:<attaquant@domaine-externe-a.com>
250 OK
RCPT TO:<victime@domaine-externe-b.com>
250 OK          ← RÉPONSE CRITIQUE : le serveur accepte un routage externe→externe
DATA
354 Start mail input
Subject: Test relais ouvert

Ceci confirme un relais ouvert.
.
250 OK: queued
```

!!! danger "Signal de relais ouvert confirmé"
    Si `MAIL FROM` **et** `RCPT TO` référencent chacun un domaine totalement extérieur à celui du serveur testé, et que le message est néanmoins accepté (`250 OK`) sans authentification, le relais ouvert est confirmé.

**Impact d'un relais ouvert exploité :**

- Blacklistage de l'IP/du domaine du serveur sur les principales listes de réputation (Spamhaus, SORBS...), entraînant le rejet systématique de tous les emails légitimes de l'organisation par les fournisseurs tiers.
- Utilisation comme infrastructure gratuite de diffusion de campagnes de spam ou de phishing, à l'insu de l'organisation propriétaire du serveur.
- Dégradation durable de la réputation d'envoi du domaine, difficile à restaurer même après correction du défaut initial.

### Ingénierie sociale & email spoofing

En l'absence de contrôles SPF/DKIM/DMARC correctement configurés côté destinataire, rien n'empêche techniquement la construction d'un message usurpant intégralement l'identité affichée d'un expéditeur légitime.

```bash
# Forge d'un email usurpant l'identité d'un expéditeur via swaks (Swiss Army Knife for SMTP)
swaks --to victime@cible-test.com \
      --from "Support IT <support@entreprise-legitime.com>" \
      --header "Subject: Action requise sur votre compte" \
      --body "Merci de confirmer vos identifiants via ce lien." \
      --server mail.cible-test.com \
      --port 25
```

```text
=== Trying mail.cible-test.com:25...
=== Connected to mail.cible-test.com.
<-  220 mail.cible-test.com ESMTP
 -> EHLO test
<-  250-mail.cible-test.com
 -> MAIL FROM:<support@entreprise-legitime.com>
<-  250 OK
 -> RCPT TO:<victime@cible-test.com>
<-  250 OK
 -> DATA
<-  354 Start mail input
 -> [en-têtes + corps du message]
<-  250 OK: queued as 7F3A2B1C
```

!!! tip "swaks comme outil d'audit légitime"
    `swaks` est l'outil de référence pour valider, dans un cadre autorisé, le comportement réel d'un MTA face à des enveloppes et en-têtes construits manuellement — que ce soit pour tester un relais ouvert, valider l'application effective de SPF/DKIM côté serveur destinataire, ou vérifier qu'une politique DMARC `p=reject` rejette bien un message dont l'alignement échoue.

---

## 5. Hardening, anti-spoofing & remédiation (Blue Team)

### Désactivation des fonctions dangereuses

`VRFY` et `EXPN` doivent être désactivées ou strictement limitées aux connexions internes de confiance, car leur seule utilité opérationnelle légitime pour un utilisateur final est marginale face au risque d'énumération qu'elles introduisent.

```ini
# /etc/postfix/main.cf — désactivation de VRFY et durcissement associé
disable_vrfy_command = yes
smtpd_helo_required = yes
```

### Authentification & chiffrement

```ini
# /etc/postfix/main.cf — exigence d'authentification SASL sur la soumission (port 587)
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_recipient_restrictions =
    permit_sasl_authenticated,
    permit_mynetworks,
    reject_unauth_destination

# Forcer le chiffrement TLS plutôt que de le laisser optionnel/opportuniste
smtp_tls_security_level = encrypt
smtpd_tls_security_level = encrypt
smtpd_tls_auth_only = yes
```

!!! warning "Le simple support de STARTTLS ne suffit pas"
    Annoncer l'extension `STARTTLS` sans imposer `smtpd_tls_security_level = encrypt` (ou équivalent) laisse la porte ouverte à un downgrade : un client ou un attaquant en MitM peut toujours retomber sur une transmission en clair. Le chiffrement doit être **exigé**, non simplement **proposé**.

### Protections contre l'usurpation d'identité

**SPF (Sender Policy Framework)** — publie, sous forme d'enregistrement DNS `TXT`, la liste des serveurs autorisés à émettre au nom d'un domaine :

```dns
; Enregistrement SPF pour le domaine entreprise-legitime.com
entreprise-legitime.com. IN TXT "v=spf1 ip4:203.0.113.10 include:_spf.google.com -all"
```

Le `-all` final indique un rejet strict (*hard fail*) de toute IP non listée ; `~all` (*soft fail*) est une variante plus permissive, souvent utilisée en phase de transition avant durcissement complet.

**DKIM (DomainKeys Identified Mail)** — signe cryptographiquement certains en-têtes et le corps du message avec une clé privée détenue par le serveur émetteur, vérifiable par le destinataire via une clé publique publiée en DNS :

```dns
; Clé publique DKIM publiée sous le sélecteur "mail2026"
mail2026._domainkey.entreprise-legitime.com. IN TXT "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC..."
```

```ini
# /etc/opendkim.conf — configuration minimale côté Postfix + OpenDKIM
Domain                  entreprise-legitime.com
KeyFile                 /etc/opendkim/keys/mail2026.private
Selector                mail2026
Mode                    sv
```

**DMARC (Domain-based Message Authentication, Reporting and Conformance)** — définit la politique appliquée par les destinataires lorsque SPF et/ou DKIM échouent, et exige leur **alignement** avec le domaine visible dans l'en-tête `From:` :

```dns
; Politique DMARC stricte avec rejet et reporting agrégé
_dmarc.entreprise-legitime.com. IN TXT "v=DMARC1; p=reject; rua=mailto:dmarc-reports@entreprise-legitime.com; pct=100"
```

| Valeur `p=` | Comportement du destinataire en cas d'échec d'alignement |
|---|---|
| `none` | Aucune action, seul un rapport est envoyé (phase d'observation) |
| `quarantine` | Le message est placé en dossier indésirable/spam |
| `reject` | Le message est rejeté avant même la remise (politique cible en production mature) |

!!! danger "SPF et DKIM seuls ne suffisent pas sans DMARC"
    Un domaine peut publier un enregistrement SPF ou une clé DKIM parfaitement valides sans que cela n'empêche un attaquant d'envoyer un message dont le `From:` affiché usurpe le domaine, **si aucune politique DMARC n'impose l'alignement**. DMARC est le mécanisme qui relie effectivement le résultat technique de SPF/DKIM à une décision de traitement du message côté destinataire.

### Interdiction du relais anonyme

```ini
# /etc/postfix/main.cf — restriction stricte du relais aux réseaux de confiance explicitement listés
mynetworks = 127.0.0.0/8, 10.0.0.0/24
smtpd_relay_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    defer_unauth_destination
```

!!! tip "Principe de durcissement central"
    Aucun message ne doit pouvoir être relayé vers un domaine externe sans que l'expéditeur soit **soit** authentifié via SASL, **soit** situé dans un réseau interne explicitement listé dans `mynetworks`. Tout relais anonyme externe→externe doit être structurellement impossible, indépendamment de la charge de la file d'attente.

---

## 6. Anti-sèche commandes CLI (Cheat Sheet)

```bash
# Connexion brute en clair (port 25) via netcat — inspection manuelle du dialogue
nc mail.cible.com 25

# Connexion brute en clair via telnet (équivalent, plus universellement disponible)
telnet mail.cible.com 25

# Test de connexion chiffrée implicite SMTPS (port 465)
openssl s_client -connect mail.cible.com:465

# Test de l'élévation STARTTLS sur le port de soumission (587) ou le port historique (25)
openssl s_client -starttls smtp -connect mail.cible.com:587
openssl s_client -starttls smtp -connect mail.cible.com:25

# Vérification rapide du certificat présenté (dates de validité, CN/SAN)
openssl s_client -starttls smtp -connect mail.cible.com:587 -servername mail.cible.com \
  | openssl x509 -noout -dates -subject -issuer
```

```bash
# swaks — test d'envoi standard, authentifié, avec confirmation TLS
swaks --to destinataire@cible.com \
      --from expediteur@domaine-autorise.com \
      --server mail.cible.com:587 \
      --auth LOGIN \
      --auth-user "utilisateur" \
      --auth-password "motdepasse" \
      --tls

# swaks — test ciblé de relais ouvert (enveloppe entièrement externe)
swaks --to victime@domaine-externe-b.com \
      --from test@domaine-externe-a.com \
      --server mail.cible.com:25

# swaks — vérification du support et du comportement STARTTLS
swaks --to test@cible.com --server mail.cible.com:25 --tls -av
```

```bash
# Vérification des enregistrements SPF, DKIM et DMARC d'un domaine (côté Blue Team / audit)
dig TXT entreprise-legitime.com +short
dig TXT mail2026._domainkey.entreprise-legitime.com +short
dig TXT _dmarc.entreprise-legitime.com +short
```

---

## 7. Références

- RFC 5321 — *Simple Mail Transfer Protocol* : [https://www.rfc-editor.org/rfc/rfc5321](https://www.rfc-editor.org/rfc/rfc5321)
- RFC 3207 — *SMTP Service Extension for Secure SMTP over TLS (STARTTLS)* : [https://www.rfc-editor.org/rfc/rfc3207](https://www.rfc-editor.org/rfc/rfc3207)
- RFC 7505 — *A "Null MX" No Service Resource Record for Domains That Accept No Mail* : [https://www.rfc-editor.org/rfc/rfc7505](https://www.rfc-editor.org/rfc/rfc7505)
- RFC 7208 — *Sender Policy Framework (SPF)* : [https://www.rfc-editor.org/rfc/rfc7208](https://www.rfc-editor.org/rfc/rfc7208)
- RFC 6376 — *DomainKeys Identified Mail (DKIM) Signatures* : [https://www.rfc-editor.org/rfc/rfc6376](https://www.rfc-editor.org/rfc/rfc6376)
- RFC 7489 — *Domain-based Message Authentication, Reporting, and Conformance (DMARC)* : [https://www.rfc-editor.org/rfc/rfc7489](https://www.rfc-editor.org/rfc/rfc7489)
