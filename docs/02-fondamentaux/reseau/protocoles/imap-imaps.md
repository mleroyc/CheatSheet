---
title: "Protocole IMAP, IMAPS et STARTTLS : Mécanismes et Sécurité"
description: "Anatomie complète du protocole IMAP, comparaison avec POP3, IMAPS (port 993) vs STARTTLS (port 143), énumération et sécurisation des accès."
tags:
  - imap
  - imaps
  - starttls
  - email-security
  - network
  - protocoles
  - pop3
  - oauth2
---

# Protocole IMAP, IMAPS et STARTTLS : Mécanismes et Sécurité

!!! warning "Cadre légal"
    Les techniques d'audit et d'exploitation décrites dans ce document (énumération, sniffing, brute-force d'identifiants) ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## 1. Résumé exécutif & définition

**IMAP** (*Internet Message Access Protocol*) est le protocole de **consultation et de gestion synchronisée** des messages électroniques stockés sur un serveur distant. Contrairement à un simple protocole de téléchargement, IMAP maintient un **état persistant côté serveur** : les dossiers, les indicateurs de lecture, les suppressions et les déplacements de messages sont reflétés sur le serveur lui-même, permettant à plusieurs clients (mobile, webmail, client de bureau) d'accéder à une vue cohérente et identique de la même boîte aux lettres.

### Deux ports, une seule sémantique protocolaire

| Port | Nom | Usage |
|---|---|---|
| **143/TCP** | IMAP en clair | Connexion historique non chiffrée par défaut, pouvant être élevée dynamiquement en TLS via la commande `STARTTLS` |
| **993/TCP** | IMAPS (implicite) | Connexion chiffrée SSL/TLS établie **immédiatement** dès l'ouverture du socket TCP, avant tout échange de commande — standard recommandé aujourd'hui |

!!! note "IMAP transporte le même protocole, quel que soit le port"
    La distinction entre le port 143 et le port 993 ne change rien à la sémantique des commandes IMAP elles-mêmes — elle ne modifie que le **moment** où le chiffrement TLS est établi dans le cycle de vie de la connexion, exactement comme pour la paire SMTP/SMTPS abordée dans la fiche dédiée à SMTP.

### Différence clé avec POP3

| Aspect | IMAP | POP3 |
|---|---|---|
| Stockage principal | Sur le **serveur**, synchronisé en continu | Généralement **téléchargé et supprimé** du serveur après récupération (comportement par défaut historique) |
| Multi-appareils | Vue cohérente sur tous les clients connectés simultanément | Chaque client agit indépendamment, désynchronisation fréquente entre appareils |
| Gestion de dossiers | Complète — dossiers, sous-dossiers, indicateurs (lu/non lu, marqué) réplicables sur le serveur | Absente — POP3 n'a qu'une notion plate de boîte de réception unique |
| Cas d'usage typique aujourd'hui | Standard de fait pour tout accès moderne multi-appareils (webmail, mobile, client lourd) | Résiduel, environnements contraints ou legacy |

---

## 2. Anatomie détaillée d'une session IMAP

### Mécanique du protocole & système de tags

Chaque commande envoyée par le client est préfixée par une **étiquette unique** (tag), généralement une séquence alphanumérique courte incrémentée à chaque échange (`A001`, `A002`, `A003`...). Le serveur reprend systématiquement ce même tag dans sa réponse finale, ce qui permet au client de faire correspondre sans ambiguïté chaque réponse — y compris des réponses intermédiaires non taguées — à la commande qui l'a déclenchée, dans un protocole qui autorise en théorie le pipelining de plusieurs commandes.

```text
A001 CAPABILITY
* CAPABILITY IMAP4rev1 STARTTLS AUTH=PLAIN AUTH=LOGIN
A001 OK CAPABILITY completed

A002 LOGIN utilisateur motdepasse
A002 OK LOGIN completed

A003 SELECT INBOX
* 42 EXISTS
* 1 RECENT
* OK [UIDVALIDITY 1234567890] UIDs valid
A003 OK [READ-WRITE] SELECT completed
```

!!! tip "Réponses non taguées (untagged)"
    Les lignes commençant par `*` sont des réponses **non taguées**, portant des données ou des notifications d'état (nombre de messages, alertes serveur). Elles précèdent toujours la ligne finale taguée qui confirme l'issue de la commande (`OK`, `NO` ou `BAD`).

### Commandes IMAP clés

| Commande | Rôle |
|---|---|
| `CAPABILITY` | Énumère les extensions supportées par le serveur et les mécanismes d'authentification disponibles (`AUTH=PLAIN`, `AUTH=LOGIN`, `STARTTLS`...) |
| `LOGIN user password` | Authentification directe en texte clair (identifiant + mot de passe transmis littéralement dans la commande) |
| `AUTHENTICATE` | Authentification via un mécanisme SASL négocié (`PLAIN`, `CRAM-MD5`, `XOAUTH2` pour OAuth2), évitant de transmettre le mot de passe en clair dans la commande elle-même selon le mécanisme choisi |
| `LIST` / `LSUB` | Énumère respectivement l'ensemble des dossiers disponibles, ou uniquement ceux auxquels le client est abonné |
| `SELECT` / `EXAMINE` | Ouvre un dossier donné (ex : `INBOX`) en lecture-écriture (`SELECT`) ou en lecture seule (`EXAMINE`) |
| `FETCH` | Récupère tout ou partie d'un message par son identifiant : en-têtes seuls, corps complet, pièces jointes spécifiques |
| `LOGOUT` | Ferme proprement la session |

```text
A004 LIST "" "*"
* LIST (\HasNoChildren) "/" "INBOX"
* LIST (\HasNoChildren) "/" "Sent"
* LIST (\HasNoChildren) "/" "Drafts"
A004 OK LIST completed

A005 FETCH 12 (BODY[HEADER] BODY[TEXT])
* 12 FETCH (BODY[HEADER] {312}
[en-têtes bruts du message 12]
 BODY[TEXT] {891}
[corps brut du message 12]
)
A005 OK FETCH completed
```

### Codes de réponse du serveur

| Code | Signification |
|---|---|
| `OK` | Commande exécutée avec succès |
| `NO` | Commande refusée par le serveur (ex : identifiants invalides, permission insuffisante) |
| `BAD` | Commande malformée ou syntaxiquement invalide, non reconnue par le serveur |
| `BYE` | Le serveur ferme la connexion (annonce précédant la déconnexion, souvent en réponse à `LOGOUT` ou lors d'une fermeture forcée) |

---

## 3. Matrice comparative : IMAP vs IMAPS vs POP3

| Protocole | Port(s) par défaut | Chiffrement | Mode de stockage | Gestion des dossiers | Risque de fuite d'identifiants |
|---|---|---|---|---|---|
| **IMAP (clair)** | 143/TCP | Optionnel via `STARTTLS` (élévation dynamique) | Serveur (synchronisé) | Complète (dossiers, sous-dossiers, indicateurs) | Élevé — `LOGIN` en clair capturable par simple sniffing si `STARTTLS` n'est pas exigé |
| **IMAPS (implicite)** | 993/TCP | TLS immédiat dès l'ouverture du socket | Serveur (synchronisé) | Complète | Faible — aucune fenêtre de clair possible avant chiffrement complet |
| **POP3 (clair)** | 110/TCP | Optionnel via `STLS` (équivalent de STARTTLS pour POP3) | Local (téléchargement, suppression fréquente côté serveur) | Absente (boîte plate unique) | Élevé — mêmes risques de sniffing que l'IMAP en clair |
| **POP3S (implicite)** | 995/TCP | TLS immédiat | Local | Absente | Faible |

---

## 4. Empreinte, audit & méthodologie d'exploitation (Red Team)

### Énumération de bannières & CAPABILITY

```bash
# Récupération de la bannière et des capacités annoncées via netcat
nc mail.cible.com 143
```

```text
* OK [CAPABILITY IMAP4rev1 STARTTLS AUTH=PLAIN LOGINDISABLED] Dovecot ready.
```

!!! tip "Fuite d'informations dans la bannière"
    La bannière révèle fréquemment le **logiciel serveur** (Dovecot, Courier-IMAP, Microsoft Exchange) et parfois sa version exacte, permettant de cibler ensuite une recherche de vulnérabilités connues (CVE) spécifiques à cette implémentation.

```bash
# Interrogation explicite de CAPABILITY via une session TLS
openssl s_client -connect mail.cible.com:993 -quiet
```

```text
A001 CAPABILITY
* CAPABILITY IMAP4rev1 SASL-IR AUTH=PLAIN AUTH=LOGIN AUTH=XOAUTH2 IDLE
A001 OK CAPABILITY completed
```

**Scan automatisé via Nmap :**

```bash
# Énumération des capacités et de la bannière du serveur
nmap -p143,993 --script imap-capabilities mail.cible.com

# Brute-force d'identifiants directement intégré au moteur NSE
nmap -p143 --script imap-brute \
     --script-args userdb=users.txt,passdb=passwords.txt \
     mail.cible.com
```

### Attaques & fuites d'informations

**Sniffing réseau sur le port 143 non chiffré :**

```bash
# Capture du trafic IMAP en clair pour extraire les identifiants LOGIN
tcpdump -i eth0 -A 'tcp port 143' | grep -A2 "LOGIN"
```

```text
A002 LOGIN victime@cible.com MotDePasse2026!
```

!!! danger "Capture triviale des identifiants"
    Sur une connexion IMAP en clair sans élévation `STARTTLS`, la commande `LOGIN` transmet l'identifiant **et** le mot de passe en texte intégralement lisible dans le flux réseau. Toute position d'écoute sur le chemin réseau (réseau Wi-Fi partagé, commutateur mal segmenté, proxy transparent) suffit à exfiltrer des identifiants valides sans aucune interaction avec la victime.

**Attaque par rétrogradation — STARTTLS Stripping :**

De la même façon que pour SMTP, un attaquant en position de Man-in-the-Middle peut intercepter la réponse `CAPABILITY` et **supprimer la mention `STARTTLS`** avant qu'elle n'atteigne le client, incitant ce dernier à poursuivre en clair si le client n'est pas configuré pour exiger impérativement le chiffrement.

**Brute-force d'identifiants via Hydra / Medusa :**

```bash
# Brute-force d'identifiants IMAP via Hydra, ciblant le port 143
hydra -L users.txt -P passwords.txt imap://mail.cible.com

# Équivalent ciblant explicitement le port IMAPS (993, TLS implicite)
hydra -L users.txt -P passwords.txt -s 993 -S imap://mail.cible.com
```

```bash
# Brute-force équivalent via Medusa
medusa -h mail.cible.com -U users.txt -P passwords.txt -M imap
```

!!! warning "Absence de rate-limiting = brute-force praticable"
    Sans limitation du nombre de tentatives par IP/compte, ni verrouillage progressif après un seuil d'échecs, un espace de mots de passe restreint (dictionnaire ciblé, mots de passe issus de fuites publiques) devient testable en quelques minutes à quelques heures.

**Extraction automatisée de données après compromission d'accès :**

Une fois un accès IMAP valide obtenu (par brute-force, phishing, ou réutilisation de fuite de mot de passe), la boîte aux lettres devient elle-même une source d'exfiltration secondaire, souvent riche en secrets oubliés :

```bash
# Récupération de tous les identifiants de messages du dossier INBOX
# puis recherche ciblée de mots-clés sensibles dans les corps de message
curl --url "imaps://mail.cible.com/INBOX" \
     --user "victime@cible.com:MotDePasse2026!" \
     --request "SEARCH TEXT \"password\""
```

!!! danger "La boîte mail comme pivot"
    Une boîte de messagerie compromise contient fréquemment des mots de passe transmis en clair par des tiers négligents, des liens de réinitialisation de mot de passe pour d'autres services (cf. fiche dédiée *Insecure Password Reset*), des jetons d'API, ou des documents sensibles en pièce jointe — la compromission d'un seul compte email constitue donc rarement un point d'arrivée, mais un **pivot** vers un périmètre bien plus large.

---

## 5. Hardening & remédiation (Blue Team)

### Restriction stricte aux flux chiffrés

```ini
# /etc/dovecot/conf.d/10-auth.conf — interdiction de toute authentification en clair
# hors connexion déjà chiffrée (TLS établi, implicite ou via STARTTLS)
disable_plaintext_auth = yes
auth_mechanisms = plain login
```

!!! tip "Nuance importante"
    `disable_plaintext_auth = yes` n'interdit pas la commande `LOGIN` en tant que telle : il interdit sa transmission **hors d'un canal déjà chiffré**. Une fois `STARTTLS` négocié avec succès (ou sur une connexion IMAPS implicite), `LOGIN` redevient acceptée car le canal offre alors une protection équivalente.

### Migration obligatoire vers IMAPS ou imposition de STARTTLS

```ini
# /etc/dovecot/conf.d/10-ssl.conf — configuration TLS de référence
ssl = required
ssl_cert = </etc/ssl/certs/mail.cible.com.pem
ssl_key = </etc/ssl/private/mail.cible.com.key
ssl_min_protocol = TLSv1.2
```

```ini
# /etc/dovecot/conf.d/10-master.conf — désactivation explicite du port 143 en clair
# au profit du seul port 993 (IMAPS implicite), lorsque la politique l'exige
service imap-login {
  inet_listener imap {
    port = 0   # désactive complètement l'écoute en clair sur le port 143
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
}
```

### Remplacement de l'authentification basique par des mécanismes modernes

```text
Environnements Microsoft 365 / Google Workspace :
- Désactivation de l'authentification basique (Basic Auth / LOGIN/PLAIN) au niveau du tenant.
- Migration vers OAuth2 (mécanisme SASL "XOAUTH2") pour toute application cliente IMAP.
- Renforcement complémentaire via MFA obligatoire sur le compte utilisateur sous-jacent,
  rendant la seule connaissance du mot de passe insuffisante pour établir une session.
```

!!! danger "Pourquoi l'authentification basique reste une cible privilégiée"
    L'authentification basique (`LOGIN`/`PLAIN`) ne transporte qu'un identifiant et un mot de passe statiques, sans notion de second facteur ni de jeton à durée de vie limitée. Un mot de passe volé via phishing ou fuite de données tierce reste valide indéfiniment jusqu'à son changement manuel — contrairement à un jeton OAuth2, révocable et limité dans le temps, qui réduit fortement la fenêtre d'exploitation d'un identifiant compromis.

### Isolation réseau et limitation de débit

```ini
# /etc/dovecot/conf.d/10-auth.conf — limitation des tentatives d'authentification échouées
auth_failure_delay = 2s
```

```bash
# Limitation complémentaire au niveau pare-feu (exemple iptables) :
# blocage temporaire d'une IP après un seuil de tentatives de connexion rapprochées sur le port 993
iptables -A INPUT -p tcp --dport 993 -m recent --name imap_bruteforce \
  --update --seconds 60 --hitcount 10 -j DROP
iptables -A INPUT -p tcp --dport 993 -m recent --name imap_bruteforce --set
```

!!! tip "Défense en profondeur"
    Le rate-limiting applicatif (Dovecot) et la limitation réseau (pare-feu/fail2ban) se complètent : le premier protège le service lui-même, le second réduit la charge et la visibilité offerte à un attaquant menant un brute-force distribué depuis une même plage d'IP.

---

## 6. Anti-sèche commandes CLI (Cheat Sheet)

```bash
# Connexion brute en clair (port 143) via netcat
nc mail.cible.com 143

# Connexion brute en clair via telnet (équivalent)
telnet mail.cible.com 143

# Connexion chiffrée implicite IMAPS (port 993)
openssl s_client -connect mail.cible.com:993 -quiet

# Élévation STARTTLS sur le port en clair (143)
openssl s_client -starttls imap -connect mail.cible.com:143 -quiet
```

```bash
# Vérification rapide du certificat présenté sur IMAPS
openssl s_client -connect mail.cible.com:993 -servername mail.cible.com </dev/null 2>/dev/null \
  | openssl x509 -noout -dates -subject -issuer
```

**Session interactive complète avec tags (sur un canal chiffré déjà établi) :**

```text
A001 CAPABILITY
* CAPABILITY IMAP4rev1 SASL-IR AUTH=PLAIN AUTH=LOGIN IDLE
A001 OK CAPABILITY completed

A002 LOGIN utilisateur motdepasse
A002 OK [CAPABILITY IMAP4rev1 IDLE] Logged in

A003 LIST "" "*"
* LIST (\HasNoChildren) "/" "INBOX"
* LIST (\HasNoChildren) "/" "Sent"
A003 OK LIST completed

A004 SELECT INBOX
* 42 EXISTS
* OK [UIDVALIDITY 1234567890] UIDs valid
A004 OK [READ-WRITE] SELECT completed

A005 FETCH 1 (BODY[HEADER.FIELDS (SUBJECT FROM)])
* 1 FETCH (BODY[HEADER.FIELDS (SUBJECT FROM)] {58}
Subject: Bienvenue
From: support@cible.com
)
A005 OK FETCH completed

A006 LOGOUT
* BYE Logging out
A006 OK LOGOUT completed
```

```bash
# Équivalent scriptable via curl pour lister ou rechercher dans une boîte
curl --url "imaps://mail.cible.com/INBOX" --user "utilisateur:motdepasse"
curl --url "imaps://mail.cible.com/INBOX" --user "utilisateur:motdepasse" \
     --request "SEARCH SUBJECT \"facture\""
```

---

## 7. Références

- RFC 9051 — *Internet Message Access Protocol (IMAP) — Version 4rev2* : [https://www.rfc-editor.org/rfc/rfc9051](https://www.rfc-editor.org/rfc/rfc9051)
- RFC 3501 — *Internet Message Access Protocol — Version 4rev1* (référence historique, largement déployée) : [https://www.rfc-editor.org/rfc/rfc3501](https://www.rfc-editor.org/rfc/rfc3501)
- RFC 8314 — *Cleartext Considered Obsolete: Use of TLS for Email Submission and Access* : [https://www.rfc-editor.org/rfc/rfc8314](https://www.rfc-editor.org/rfc/rfc8314)
- RFC 2595 — *Using TLS with IMAP, POP3 and ACAP* (introduction historique de STARTTLS/STLS pour IMAP et POP3) : [https://www.rfc-editor.org/rfc/rfc2595](https://www.rfc-editor.org/rfc/rfc2595)
- RFC 1939 — *Post Office Protocol — Version 3 (POP3)* : [https://www.rfc-editor.org/rfc/rfc1939](https://www.rfc-editor.org/rfc/rfc1939)
