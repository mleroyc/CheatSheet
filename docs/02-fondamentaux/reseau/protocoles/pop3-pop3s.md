---
title: "Protocole POP3, POP3S et STLS : Mécanismes et Sécurité"
description: "Anatomie complète du protocole POP3, cycle de vie des sessions, POP3S (port 995) vs STLS (port 110), comparaison avec IMAP et sécurisation des flux."
tags:
  - pop3
  - pop3s
  - stls
  - email-security
  - network
  - protocoles
  - apop
  - imap
---

# Protocole POP3, POP3S et STLS : Mécanismes et Sécurité

!!! warning "Cadre légal"
    Les techniques d'audit et d'exploitation décrites dans ce document (énumération, sniffing, brute-force d'identifiants) ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## 1. Résumé exécutif & définition

**POP3** (*Post Office Protocol version 3*, RFC 1939) est le protocole historique de **relève de messagerie en mode déconnecté** : son modèle d'origine consiste à télécharger l'intégralité des messages présents sur le serveur vers le client, puis à les **supprimer du serveur** une fois le rapatriement confirmé. Contrairement à IMAP, POP3 ne maintient aucune notion de dossiers distants ni d'état synchronisé entre plusieurs clients — chaque session est une transaction ponctuelle et largement indépendante des sessions précédentes ou suivantes.

### Deux ports, une seule sémantique protocolaire

| Port | Nom | Usage |
|---|---|---|
| **110/TCP** | POP3 en clair | Connexion historique non chiffrée par défaut, pouvant être élevée dynamiquement en TLS via la commande `STLS` |
| **995/TCP** | POP3S (implicite) | Connexion chiffrée SSL/TLS établie **immédiatement** dès l'ouverture du socket TCP, avant tout échange de commande — standard recommandé aujourd'hui |

!!! note "STLS, l'équivalent POP3 de STARTTLS"
    `STLS` joue pour POP3 exactement le rôle que joue `STARTTLS` pour SMTP et IMAP : une élévation dynamique d'une connexion initialement en clair vers un canal chiffré, sur le même port (110), sans changer de socket. Le principe est identique ; seul le nom de la commande diffère selon le protocole concerné.

### Différence stratégique avec IMAP

| Aspect | POP3 | IMAP |
|---|---|---|
| Stockage principal | **Local**, côté client — le serveur ne conserve les messages que temporairement, voire les supprime après rapatriement selon la configuration | **Serveur**, synchronisé en continu et consultable depuis n'importe quel client |
| Notion de dossiers distants | Absente — POP3 n'expose qu'une boîte de réception plate unique | Complète — dossiers, sous-dossiers, indicateurs d'état (lu/non lu, marqué) répliqués côté serveur |
| Cohérence multi-appareils | Faible — chaque client agit indépendamment, désynchronisation fréquente | Forte — tous les clients connectés voient le même état à tout instant |
| Empreinte de stockage serveur | Réduite dans le temps (messages retirés après relève, sauf configuration explicite de conservation) | Continue — l'ensemble de l'historique reste hébergé côté serveur |

!!! tip "Pourquoi POP3 reste parfois utilisé"
    Bien que largement supplanté par IMAP dans les usages modernes multi-appareils, POP3 conserve un intérêt résiduel dans des contextes précis : contraintes de quota de stockage serveur strictes, environnements à connectivité intermittente où le mode déconnecté est recherché délibérément, ou systèmes legacy dont la migration n'est pas priorisée.

---

## 2. Anatomie détaillée d'une session POP3

### Les trois états du cycle de vie POP3

Une session POP3 traverse toujours, dans cet ordre strict, trois états successifs :

```text
1. AUTORISATION (Authorization)
   → Le client s'authentifie (USER/PASS ou APOP). Aucune opération sur les
     messages n'est permise avant l'authentification réussie.

2. TRANSACTION
   → Le client consulte, compte et marque des messages pour suppression
     (STAT, LIST, RETR, DELE...). Aucune suppression n'est encore effective
     à ce stade — les marquages DELE restent réversibles via RSET.

3. MISE À JOUR (Update)
   → Déclenchée par QUIT : le serveur exécute effectivement les suppressions
     marquées durant la phase de Transaction, puis ferme la connexion.
     Si la connexion est interrompue brutalement avant QUIT (coupure réseau,
     crash client), aucune suppression marquée n'est appliquée.
```

!!! danger "QUIT n'est pas un simple au revoir"
    Contrairement à une commande de fermeture anodine, `QUIT` déclenche la **phase de mise à jour** qui rend irréversibles toutes les suppressions marquées via `DELE` durant la transaction. Une déconnexion prématurée (sans `QUIT`) préserve au contraire l'état initial des messages, un comportement de sécurité involontaire qu'il est utile de connaître lors d'un audit.

### Commandes POP3 clés

| Commande | Rôle |
|---|---|
| `USER username` | Déclare l'identifiant du compte, première moitié de l'authentification en clair |
| `PASS password` | Transmet le mot de passe en clair, complète l'authentification initiée par `USER` |
| `APOP name digest` | Authentification par challenge/réponse basée sur un hash MD5 combinant un horodatage fourni par le serveur et le mot de passe partagé — évite de transmettre le mot de passe en clair sur le réseau |
| `STLS` | Élève dynamiquement la connexion en clair (port 110) vers un canal chiffré TLS |
| `STAT` | Retourne le nombre total de messages et la taille cumulée de la boîte |
| `LIST [msg_id]` | Liste les identifiants et tailles de tous les messages, ou d'un message précis si un identifiant est fourni |
| `RETR msg_id` | Récupère l'intégralité (en-têtes + corps) du message identifié |
| `DELE msg_id` | Marque un message pour suppression — effective uniquement à la phase de Mise à jour |
| `NOOP` | Ne fait rien, sert uniquement à maintenir la session active |
| `RSET` | Annule tous les marquages `DELE` effectués depuis le début de la session |
| `QUIT` | Termine la session, déclenchant l'application effective des suppressions marquées |

```text
+OK POP3 server ready
USER victime
+OK
PASS MotDePasse2026!
+OK Logged in.

STAT
+OK 3 4096

LIST
+OK 3 messages (4096 octets)
1 1024
2 1536
3 1536
.

RETR 1
+OK 1024 octets
[en-têtes et corps complet du message 1]
.

DELE 1
+OK Message deleted.

QUIT
+OK Bye — suppressions appliquées.
```

### Codes de réponse du serveur

| Code | Signification |
|---|---|
| `+OK` | Commande exécutée avec succès, éventuellement suivie de données ou d'un message informatif |
| `-ERR` | Commande refusée ou échouée (identifiants invalides, message inexistant, commande hors séquence d'état) |

---

## 3. Matrice comparative : POP3 vs POP3S vs IMAP

| Protocole | Port(s) | Chiffrement | Modèle de synchronisation | Consommation stockage serveur | Niveau de sécurité natif |
|---|---|---|---|---|---|
| **POP3 (clair)** | 110/TCP | Optionnel via `STLS` (élévation dynamique) | Aucun — relève ponctuelle, pas d'état partagé entre clients | Faible/décroissante — messages retirés après relève par défaut | Faible — `USER`/`PASS` en clair capturables par sniffing si `STLS` n'est pas exigé |
| **POP3S (implicite)** | 995/TCP | TLS immédiat dès l'ouverture du socket | Aucun (identique à POP3) | Faible/décroissante | Modéré — protège le transport, mais le modèle protocolaire reste sans synchronisation |
| **IMAP (clair/IMAPS)** | 143/TCP ou 993/TCP | Optionnel (`STARTTLS`) ou immédiat (IMAPS) | Complet — dossiers, indicateurs et suppressions répliqués sur le serveur, cohérents multi-clients | Élevée et continue — l'historique complet reste hébergé | Équivalent à POP3S une fois le chiffrement imposé, mais offre en plus la richesse fonctionnelle de synchronisation |

---

## 4. Empreinte, audit & méthodologie d'exploitation (Red Team)

### Énumération & empreinte

```bash
# Récupération de la bannière du serveur via netcat
nc mail.cible.com 110
```

```text
+OK POP3 server ready <a1b2c3d4.1699999999@mail.cible.com>
```

!!! tip "La bannière révèle souvent le logiciel serveur"
    Le format exact de la bannière (présence d'un timestamp entre chevrons, mention explicite du logiciel) permet fréquemment d'identifier l'implémentation exacte — Dovecot, Courier-IMAP/POP3, Microsoft Exchange — et d'orienter ensuite la recherche de vulnérabilités connues (CVE) propres à cette version.

**Scan automatisé via Nmap :**

```bash
# Identification des capacités et de la bannière du serveur POP3
nmap -p110,995 --script pop3-capabilities mail.cible.com

# Brute-force d'identifiants directement intégré au moteur NSE
nmap -p110 --script pop3-brute \
     --script-args userdb=users.txt,passdb=passwords.txt \
     mail.cible.com
```

### Vecteurs d'attaque courants

**Sniffing des identifiants en clair sur le port 110 :**

```bash
# Capture du trafic POP3 non chiffré pour extraire USER/PASS
tcpdump -i eth0 -A 'tcp port 110' | grep -E "^(USER|PASS)"
```

```text
USER victime
PASS MotDePasse2026!
```

!!! danger "Capture immédiate des identifiants en clair"
    Sur une connexion POP3 sans élévation `STLS`, les commandes `USER` et `PASS` transmettent l'identifiant et le mot de passe en texte intégralement lisible. Toute position d'écoute sur le chemin réseau (Wi-Fi partagé, commutateur mal segmenté, proxy transparent) suffit à exfiltrer des identifiants valides sans aucune interaction avec la victime — la capture peut également être réalisée visuellement via Wireshark en filtrant sur `pop.request`.

**Faiblesses du mécanisme APOP :**

`APOP` visait historiquement à éviter la transmission du mot de passe en clair, en s'appuyant sur un hash MD5 combinant un horodatage serveur et le secret partagé. Cependant :

- L'algorithme **MD5** souffre de faiblesses de collision documentées, réduisant la confiance cryptographique du mécanisme dans son ensemble.
- Le serveur doit conserver le mot de passe en clair (ou dans une forme équivalente réversible) pour recalculer le digest attendu, ce qui empêche tout stockage haché robuste côté serveur — un compromis architectural défavorable comparé aux mécanismes SASL modernes.
- Des attaques par collision ciblée sur le digest APOP ont été démontrées dans la littérature académique, affaiblissant la garantie théorique du mécanisme face à un adversaire actif.

!!! warning "APOP n'est plus une réponse suffisante en 2026"
    Même lorsqu'il est disponible, `APOP` ne doit plus être considéré comme une alternative sécurisée suffisante à un canal TLS complet (`STLS` ou POP3S implicite) — il s'agit d'un mécanisme d'appoint historique, non d'un substitut au chiffrement de transport.

**Attaques de type STLS Stripping :**

À l'image du STARTTLS Stripping sur SMTP/IMAP, un attaquant en position de Man-in-the-Middle peut intercepter la réponse annonçant la disponibilité de `STLS` et la supprimer avant qu'elle n'atteigne le client, incitant ce dernier à poursuivre l'authentification en clair si aucune politique côté client n'impose strictement le chiffrement.

**Brute-force d'identifiants via Hydra / Medusa :**

```bash
# Brute-force d'identifiants POP3 sur le port en clair (110)
hydra -L users.txt -P passwords.txt pop3://mail.cible.com

# Équivalent ciblant explicitement POP3S (995, TLS implicite)
hydra -L users.txt -P passwords.txt -s 995 -S pop3://mail.cible.com
```

```bash
# Brute-force équivalent via Medusa
medusa -h mail.cible.com -U users.txt -P passwords.txt -M pop3
```

!!! warning "Absence de rate-limiting = brute-force praticable"
    Comme pour IMAP, l'absence de limitation du nombre de tentatives par IP ou par compte rend un brute-force ciblé sur un dictionnaire raisonnable praticable en un temps limité, particulièrement sur des mots de passe issus de fuites publiques déjà connues (credential stuffing).

---

## 5. Hardening & remédiation (Blue Team)

### Restriction du port en clair au profit de POP3S ou imposition de STLS

```ini
# /etc/dovecot/conf.d/10-master.conf — désactivation de l'écoute en clair (port 110)
# au profit exclusif du port 995 (POP3S implicite)
service pop3-login {
  inet_listener pop3 {
    port = 0   # désactive complètement l'écoute en clair sur le port 110
  }
  inet_listener pop3s {
    port = 995
    ssl = yes
  }
}
```

```ini
# /etc/dovecot/conf.d/10-ssl.conf — configuration TLS de référence, partagée avec IMAP
ssl = required
ssl_cert = </etc/ssl/certs/mail.cible.com.pem
ssl_key = </etc/ssl/private/mail.cible.com.key
ssl_min_protocol = TLSv1.2
```

### Interdiction de l'authentification en clair hors canal chiffré

```ini
# /etc/dovecot/conf.d/10-auth.conf — interdiction de USER/PASS hors connexion déjà chiffrée
disable_plaintext_auth = yes
auth_mechanisms = plain login
```

!!! tip "Cohérence avec la configuration IMAP"
    Cette directive est strictement identique à celle recommandée dans la fiche IMAP — Dovecot mutualise la même logique d'authentification entre les deux protocoles. `USER`/`PASS` redeviennent acceptées uniquement une fois un canal TLS établi (`STLS` négocié avec succès, ou connexion POP3S implicite dès l'ouverture).

### Migration recommandée vers des standards modernes

```text
En raison de la vétusté fonctionnelle de POP3 (absence de synchronisation,
absence de gestion de dossiers, modèle mono-client historique) :

- Privilégier une migration vers IMAP/IMAPS pour tout usage multi-appareils
  ou nécessitant une cohérence d'état entre plusieurs clients.
- En environnement Microsoft 365 / Google Workspace, privilégier l'API
  Graph ou l'API Gmail avec authentification OAuth2, reléguant POP3/IMAP
  à un rôle de compatibilité descendante uniquement.
- Lorsque POP3 doit être maintenu pour des raisons de compatibilité,
  n'autoriser que POP3S (995) ou STLS imposé — jamais le port 110 ouvert
  sans contrainte de chiffrement.
```

### Filtrage réseau et limitation de débit

```bash
# Limitation au niveau pare-feu (exemple iptables) : blocage temporaire d'une IP
# après un seuil de tentatives de connexion rapprochées sur le port 995
iptables -A INPUT -p tcp --dport 995 -m recent --name pop3_bruteforce \
  --update --seconds 60 --hitcount 10 -j DROP
iptables -A INPUT -p tcp --dport 995 -m recent --name pop3_bruteforce --set
```

```ini
# /etc/dovecot/conf.d/10-auth.conf — délai progressif après échec d'authentification
auth_failure_delay = 2s
```

!!! danger "Ne jamais exposer le port 110 sans contrainte au-delà du périmètre interne"
    Un port 110 accessible depuis Internet sans restriction de chiffrement constitue, à lui seul, une vulnérabilité de conception immédiatement exploitable par simple sniffing passif — indépendamment de toute autre faiblesse applicative. La remédiation prioritaire dans un audit POP3 est quasi systématiquement : imposer TLS avant toute autre recommandation.

---

## 6. Anti-sèche commandes CLI (Cheat Sheet)

```bash
# Connexion brute en clair (port 110) via netcat
nc mail.cible.com 110

# Connexion brute en clair via telnet (équivalent)
telnet mail.cible.com 110

# Connexion chiffrée implicite POP3S (port 995)
openssl s_client -connect mail.cible.com:995 -quiet

# Élévation STLS sur le port en clair (110)
openssl s_client -starttls pop3 -connect mail.cible.com:110 -quiet
```

```bash
# Vérification rapide du certificat présenté sur POP3S
openssl s_client -connect mail.cible.com:995 -servername mail.cible.com </dev/null 2>/dev/null \
  | openssl x509 -noout -dates -subject -issuer
```

**Séquence interactive complète (sur un canal déjà chiffré, POP3S ou après STLS) :**

```text
+OK POP3 server ready

USER utilisateur
+OK

PASS motdepasse
+OK Logged in.

STAT
+OK 2 2048

LIST
+OK 2 messages (2048 octets)
1 1024
2 1024
.

RETR 1
+OK 1024 octets
Return-Path: <expediteur@exemple.com>
Subject: Test
[corps du message]
.

QUIT
+OK Bye
```

!!! tip "Vérifier le comportement DELE/RSET avant tout test en environnement réel"
    Lors d'un audit avec des identifiants de test valides, toujours privilégier `RETR` puis `QUIT` **sans** `DELE`, afin de ne jamais provoquer de suppression accidentelle de messages réels. Si un test de `DELE` est explicitement requis par le périmètre de l'engagement, valider immédiatement son effet avec `RSET` avant de fermer la session, sauf si l'objectif du test est précisément de confirmer l'irréversibilité post-`QUIT`.

---

## 7. Références

- RFC 1939 — *Post Office Protocol — Version 3 (POP3)* : [https://www.rfc-editor.org/rfc/rfc1939](https://www.rfc-editor.org/rfc/rfc1939)
- RFC 2595 — *Using TLS with IMAP, POP3 and ACAP* (introduction de la commande `STLS`) : [https://www.rfc-editor.org/rfc/rfc2595](https://www.rfc-editor.org/rfc/rfc2595)
- RFC 8314 — *Cleartext Considered Obsolete: Use of TLS for Email Submission and Access* : [https://www.rfc-editor.org/rfc/rfc8314](https://www.rfc-editor.org/rfc/rfc8314)
- RFC 1734 — *POP3 AUTHentication command* (extension d'authentification SASL pour POP3) : [https://www.rfc-editor.org/rfc/rfc1734](https://www.rfc-editor.org/rfc/rfc1734)