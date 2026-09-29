---
title: "Vulnérabilités de l'Authentification : Attaques, Logique Applicative et Hardening"
description: "Guide complet sur la sécurité des mécanismes d'authentification : force brute, énumération, bypass 2FA, faiblesses de réinitialisation/changement de mot de passe, cookies 'Remember-me' et contre-mesures."
tags:
  - authentication
  - broken-authentication
  - red-team
  - blue-team
  - 2fa
  - web-security
  - vulnerability
  - remediation
---

## 🧭 Workflow de décision pour l'identification

!!! danger "Cadre d'usage"
    Ce workflow est destiné à des activités de test d'intrusion **autorisées** (pentest sous contrat, CTF, labs type PortSwigger/HackTheBox). Ne jamais tester ces techniques sur un système sans autorisation écrite explicite.

Cet arbre de décision donne l'ordre opératoire à suivre sur le terrain : que tester en premier, comment lire une réponse serveur, et vers quoi pivoter en cas d'échec. Il suit la logique **"Si je teste X → Si j'obtiens Y → Alors..."** décrite dans le corps de la fiche (sections 2 à 6).

```mermaid
flowchart TD
    A[Cible : mécanisme d'authentification] --> B[Étape 1 : Énumération de comptes]
    B -->|Confirmé| C[Étape 2 : Brute force / Rate-limiting]
    B -->|Non exploitable| C
    C -->|Bypass trouvé| D[Étape 3 : Logique 2FA]
    C -->|Rate-limit robuste| D
    D -->|Bypass trouvé| E[Étape 4 : Password Reset]
    D -->|2FA robuste| E
    E -->|Faille trouvée| F[Étape 5 : Password Change / IDOR]
    E -->|Reset robuste| F
    F -->|IDOR confirmé| G[Étape 6 : Remember-me / Tokens]
    F -->|Pas d'IDOR| G
```

### Étape 1 — Énumération de comptes utilisateur

**Test / payload de détection.** Envoyer deux requêtes de login avec un identifiant *connu invalide* et un identifiant *probable* (ex. `admin`), en conservant tous les autres paramètres strictement identiques :

```http
POST /login HTTP/1.1
Content-Type: application/x-www-form-urlencoded

username=zzzz_inexistant&password=Test123!
```
```http
POST /login HTTP/1.1
Content-Type: application/x-www-form-urlencoded

username=admin&password=Test123!
```

**Interprétation du résultat**

| Résultat obtenu | Verdict |
|---|---|
| Code HTTP différent (`200` vs `404`), corps de réponse différent (`"Invalid password"` vs `"User not found"`), ou écart de latence > ~50-100 ms reproductible | ✅ **Faille confirmée**, sous la forme **énumération par canal auxiliaire** (statut HTTP / message d'erreur / timing), car le serveur traite différemment le cas "compte existant" et "compte inexistant" avant même la vérification du mot de passe. |
| Réponses strictement identiques (code, corps, en-têtes, temps de réponse stable sur plusieurs mesures) | ❌ **Non exploitable de cette manière**, car le serveur normalise sa réponse indépendamment de l'existence du compte (bonne pratique appliquée). |

**Décision / pivot.** Si confirmé → construire une wordlist de comptes valides (Burp Intruder / script `requests`) avant de passer à l'étape 2 pour cibler le brute force. Si non exploitable → passer directement à l'étape 2 avec un jeu d'identifiants génériques (`admin`, patterns e-mail OSINT).

---

### Étape 2 — Brute force & contournement du rate-limiting

**Test / payload de détection.** Envoyer un mot de passe unique sous forme de tableau JSON au lieu d'une valeur scalaire :

```http
POST /api/login HTTP/1.1
Content-Type: application/json

{"username": "victime", "password": ["pass1","pass2","pass3","pass4"]}
```

**Interprétation du résultat**

- **J'obtiens une réponse traitant chaque valeur du tableau comme une tentative distincte (plusieurs `Invalid password` ou un `200 OK` sur l'une des valeurs), sans déclenchement de blocage** → **Faille confirmée**, sous la forme **contournement du rate-limiting par parsing de tableau**, car le compteur de tentatives côté serveur comptabilise l'appel HTTP comme une seule requête au lieu d'itérer sur chaque valeur testée.
- **J'obtiens un rejet immédiat (`400 Bad Request`, erreur de schéma) ou un blocage après un seuil identique à une requête scalaire** → **Non exploitable de cette manière**, car le serveur valide strictement le type de champ attendu.

**Décision / pivot.** Si confirmé → automatiser le brute force via ce vecteur, ou tester le **password spraying** (un seul mot de passe commun sur de nombreux comptes) pour rester sous le seuil de verrouillage par compte. Si non exploitable → tester l'intercalation de requêtes légitimes (`GET /login`) entre les tentatives pour évaluer une fenêtre glissante mal implémentée ; si toujours robuste, pivoter vers l'étape 3 (2FA), le facteur mot de passe étant traité comme suffisamment protégé.

---

### Étape 3 — Logique applicative du 2FA

**Test / payload de détection.** Après un login valide (étape 1 réussie), au lieu de soumettre le code 2FA, naviguer directement vers une ressource protégée en réutilisant le cookie de session émis à l'issue du login :

```text
1. POST /login (username + password) -> 200 OK, redirection vers /2fa-verify
2. Observer le Set-Cookie de l'étape 1
3. GET /dashboard  (avec ce cookie, SANS passer par /2fa-verify)
```

**Interprétation du résultat**

- **J'obtiens un accès complet à `/dashboard` (200 OK, contenu privilégié)** → **Faille confirmée**, sous la forme **bypass 2FA par attribution prématurée de session**, car le cookie émis après la seule étape mot de passe est déjà pleinement privilégié côté serveur ; la vérification 2FA n'est qu'une façade front-end.
- **J'obtiens une redirection forcée vers `/2fa-verify` ou un `401/403`** → **Faille non exploitable de cette manière**, car l'état "2FA validé" est vérifié côté serveur à chaque requête protégée.

**Décision / pivot.** Si non exploitable → tester la variante "substitution de cookie `2fa_pending` entre comptes" : ouvrir une session sur son propre compte, initier en parallèle un login avec les identifiants de la victime, puis soumettre son propre code OTP valide avec le cookie `2fa_pending` de la victime. Si les deux échouent → considérer le 2FA comme robuste et pivoter vers l'étape 4 (Password Reset).

---

### Étape 4 — Workflow de réinitialisation de mot de passe

**Test / payload de détection.** Soumettre directement l'étape finale du reset (`POST`) sans jeton valide dans le corps de la requête, après avoir simplement chargé la page du formulaire (`GET` avec token) :

```text
1. GET /reset-password?token=XYZ   -> formulaire affiché (token validé ici)
2. POST /reset-password            -> new_password=Hacked123!  (SANS renvoyer XYZ)
```

En parallèle, tester l'injection d'un en-tête `Host` arbitraire sur la demande de reset :

```http
POST /forgot-password HTTP/1.1
Host: attacker.com

email=victime@cible.exemple
```

**Interprétation du résultat**

| Test | Résultat A (confirmé) | Résultat B (non exploitable) |
|---|---|---|
| POST sans token | Mot de passe changé malgré l'absence de token dans le body → **faille confirmée : absence de revalidation du jeton à l'étape finale**, le serveur se fiant à un état de session temporaire posé lors du GET | `403`/erreur "token requis" → **non exploitable**, le token est revérifié à chaque étape |
| Host Header | Le lien reçu par e-mail pointe vers `attacker.com/reset?token=...` → **faille confirmée : Host Header Injection**, l'URL de reset est construite dynamiquement à partir d'un en-tête client non fiable | Le lien reçu pointe toujours vers le domaine légitime → **non exploitable**, l'URL provient d'une variable serveur fixe (`APP_BASE_URL`) |

**Décision / pivot.** Si l'un des deux est confirmé → vecteur d'Account Takeover prioritaire, à documenter immédiatement (impact critique). Si les deux sont robustes → vérifier la prédictibilité du token lui-même (`md5(email)`, concaténation timestamp/id) par génération de plusieurs tokens successifs et analyse d'entropie ; si le token est un CSPRNG haché à usage unique, pivoter vers l'étape 5.

---

### Étape 5 — Changement de mot de passe (IDOR)

**Test / payload de détection.** Depuis une session authentifiée sur **son propre compte**, altérer un identifiant de compte transmis côté client :

```http
POST /account/change-password HTTP/1.1
Cookie: session=att4ck3r_session_valide

user_id=123&new_password=Hacked123!
```

**Interprétation du résultat**

- **J'obtiens un `200 OK` et le mot de passe du compte `123` (qui n'est pas le mien) est effectivement modifié** → **Faille confirmée**, sous la forme **IDOR (Insecure Direct Object Reference)**, car le serveur détermine le compte cible à partir d'un paramètre fourni par le client plutôt que de l'identité liée à la session serveur.
- **J'obtiens un `403 Forbidden` ou le mot de passe modifié reste celui de mon propre compte malgré le `user_id` altéré** → **Non exploitable de cette manière**, car l'identité cible est dérivée server-side de la session, indépendamment du paramètre client.

**Décision / pivot.** Si confirmé → vérifier également l'absence de vérification du mot de passe actuel sur ce même endpoint (permet le vol de compte via session volée sans connaître le mot de passe d'origine). Si non exploitable → pivoter vers l'étape 6 (cookies persistants).

---

### Étape 6 — Cookies "Remember-me" & jetons de persistance

**Test / payload de détection.** Créer deux comptes de test avec des usernames proches, comparer la structure des cookies `remember-me` émis, puis décoder :

```python
import base64
base64.b64decode("YWRtaW46MTcyNzUxMjAwMA==")
# -> b'admin:1727512000'
```

**Interprétation du résultat**

- **Le décodage révèle une structure lisible/déductible (`username:timestamp`, `MD5(username)` sans sel, etc.) et un cookie forgé manuellement pour un autre compte est accepté par le serveur** → **Faille confirmée**, sous la forme **génération prédictible / cryptographie faible du token de persistance**, car le cookie n'est pas un secret aléatoire imprévisible mais une donnée déductible ou un simple encodage réversible.
- **Le décodage ne révèle aucune structure exploitable (valeur haute entropie, aucune corrélation observable entre plusieurs comptes de test) et un cookie forgé est rejeté** → **Non exploitable de cette manière**, le jeton est vraisemblablement un CSPRNG opaque stocké haché côté serveur.

**Décision / pivot.** Si confirmé → tenter le brute force de la plage de timestamps plausible pour un username cible connu. Si non exploitable → l'ensemble du périmètre "logique d'authentification" testé aux étapes 1-6 est jugé robuste ; documenter les résultats et, si le périmètre l'autorise, étendre l'analyse à la couche OAuth/OIDC tierce (hors détail de cette fiche, cf. section 7.1).

---

# Vulnérabilités de l'Authentification : Attaques, Logique Applicative et Hardening

!!! danger "Cadre d'usage"
    Ce document est destiné à des activités de test d'intrusion **autorisées** (pentest sous contrat, CTF, labs type PortSwigger/HackTheBox) ou à la conception de contre-mesures défensives. Ne jamais tester ces techniques sur un système sans autorisation écrite explicite.

## 1. Généralités & Concepts Fondamentaux

**Définition.** L'authentification est le processus par lequel un système vérifie l'identité revendiquée (*claim*) par un utilisateur, avant de lui accorder un accès.

**Les 3 facteurs d'authentification**

| Facteur | Principe | Exemples |
|---|---|---|
| Connaissance | Ce que l'on sait | Mot de passe, code PIN, question de sécurité |
| Possession | Ce que l'on possède | Clé physique (FIDO2), token OTP, téléphone |
| Inhérence | Ce que l'on est/fait | Empreinte digitale, reconnaissance faciale, biométrie comportementale |

!!! note "Authentification vs Autorisation"
    - **Authentification** : « Qui êtes-vous ? » — vérifie l'identité.
    - **Autorisation** : « Qu'avez-vous le droit de faire ? » — vérifie les privilèges une fois l'identité établie.

    Confondre les deux est une source fréquente de vulnérabilités (ex : un contrôle d'authentification robuste mais une autorisation absente sur certaines routes).

**Origine des vulnérabilités.** La catégorie *Broken Authentication* (OWASP Top 10 — regroupée aujourd'hui dans *A07:2021 – Identification and Authentication Failures*) recouvre deux grandes familles de failles :

- **Mécanismes intrinsèquement faibles** : absence de rate-limiting, hachage inadéquat, transport en clair.
- **Erreurs de logique applicative** : le mécanisme cryptographique est correct, mais l'enchaînement des étapes (workflow) contient une faille exploitable (ex : validation 2FA contournable, IDOR sur reset de mot de passe).

**Impacts.**

- Compromission intégrale de compte (Account Takeover — ATO).
- Élévation de privilèges (accès à un compte admin via bypass).
- Accès à des interfaces d'administration internes.
- Extension de la surface d'attaque (pivot vers d'autres systèmes via SSO/API keys liées au compte).

---

## 2. Authentification par Mot de Passe & Force Brute

### 2.1 Ciblage des identifiants (Usernames)

Avant toute attaque sur le mot de passe, un attaquant cherche à énumérer des noms d'utilisateur valides :

- Patterns d'adresses e-mail d'entreprise (`prenom.nom@societe.com`), déductibles via OSINT (LinkedIn, sites corporate, fuites de données).
- Comptes à privilèges aux identifiants prévisibles : `admin`, `administrator`, `root`, `test`.
- Inspection des réponses HTTP (en-têtes, corps de réponse, messages d'erreur) pour confirmer l'existence d'un compte.

### 2.2 Mots de passe & biais humains

Les politiques de complexité et de rotation induisent des comportements prévisibles :

```text
Politique : 8 caractères, majuscule, chiffre, spécial
mypassword          -> Mypassword1!

Politique : rotation obligatoire tous les 90 jours
Mypassword1!  -> Mypassword2!  -> Mypassword3!
```

!!! tip "Contre-mesure"
    Privilégier des politiques basées sur la **longueur** et l'estimation de robustesse réelle (ex. `zxcvbn`) plutôt que des règles de complexité rigides, qui encouragent des incrémentations triviales.

### 2.3 Énumération de comptes utilisateur

Trois canaux auxiliaires (*side channels*) permettent de distinguer un compte existant d'un compte inexistant :

**a) Différentiels de code de statut HTTP**

```http
POST /login HTTP/1.1
Host: cible.exemple
Content-Type: application/x-www-form-urlencoded

username=admin&password=wrongpass

# Réponse si le compte existe :
HTTP/1.1 200 OK
{"error": "Invalid password"}

# Réponse si le compte n'existe pas :
HTTP/1.1 404 Not Found
{"error": "User not found"}
```

**b) Différentiels de message d'erreur**

```text
"Nom d'utilisateur inconnu"        -> fuite d'information
"Identifiants invalides"           -> réponse générique correcte
```

**c) Timing attacks**

```text
# Compte existant : le serveur calcule le hash du mot de passe fourni
#   -> temps de réponse ~ 150ms (opération bcrypt/argon2)
# Compte inexistant : le serveur court-circuite avant le hachage
#   -> temps de réponse ~ 5ms
```

!!! warning "Exploitation"
    Un attaquant automatisé (Burp Intruder, script Python + `requests`) mesure ces écarts sur une wordlist de usernames pour ne conserver que les comptes valides, réduisant drastiquement la surface d'attaque avant la phase de brute force sur les mots de passe.

!!! tip "Contre-mesures"
    - Réponses HTTP identiques (code, corps, en-têtes) que le compte existe ou non.
    - Messages génériques : *"Identifiants invalides"*.
    - Temps de réponse uniformisé (hachage systématique même sur compte inexistant, ou délai artificiel constant).

### 2.4 Contournement des protections contre la force brute

**Limites de l'Account Lockout / blocage IP**

- **Password Spraying** : un seul mot de passe commun (`Summer2024!`) testé sur un grand nombre de comptes, plutôt qu'un grand nombre de mots de passe sur un seul compte → reste sous le seuil de verrouillage par compte.
- **Credential Stuffing** : réutilisation d'identifiants issus de fuites de données publiques (combolists), exploitant la réutilisation de mots de passe entre services.

**Contournement du rate-limiting applicatif**

```http
POST /api/login HTTP/1.1
Content-Type: application/json

{"username": "victime", "password": ["pass1","pass2","pass3","pass4"]}
```

Certains frameworks backend, mal configurés, itèrent sur un tableau de valeurs et ne comptabilisent l'opération que comme **une seule requête** côté rate-limiter, permettant de tester plusieurs mots de passe en un seul appel.

Autre variante : réinitialisation du compteur en intercalant des requêtes légitimes (ex : `GET /login`) entre les tentatives pour éviter le déclenchement du seuil basé sur une fenêtre glissante mal implémentée.

!!! tip "Contre-mesures"
    - Rate-limiting **par IP ET par compte**, avec compteurs indépendants et fenêtres glissantes robustes côté serveur (Redis, etc.).
    - Validation stricte du schéma de la requête (rejet des tableaux là où une valeur scalaire est attendue).
    - Temporisation progressive (*exponential backoff*).
    - CAPTCHA contextuel après N échecs.
    - Détection de password spraying par corrélation inter-comptes (SIEM).

### 2.5 Authentification HTTP de base (Basic Auth)

```http
GET /admin HTTP/1.1
Host: cible.exemple
Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=
```

`YWRtaW46cGFzc3dvcmQxMjM=` est le Base64 (non chiffré) de `admin:password123`.

**Faiblesses :**

- Identifiants transmis en clair (encodés, non chiffrés) à **chaque requête**.
- Vulnérable au Man-in-the-Middle si TLS absent ou mal configuré.
- Aucune protection CSRF native (le navigateur renvoie automatiquement l'en-tête).
- Vulnérable à la force brute (pas de gestion de session, chaque requête est une tentative indépendante).

---

## 3. Authentification Multifacteur (2FA / MFA)

### 3.1 Types de jetons

| Type | Mécanisme | Robustesse |
|---|---|---|
| TOTP (RFC 6238) | Code temporel dérivé d'un secret partagé | Bonne |
| HOTP (RFC 4226) | Code basé sur un compteur | Bonne |
| SMS | Code envoyé par SMS | Faible |
| E-mail | Code envoyé par e-mail | Faible |
| FIDO2/WebAuthn | Clé cryptographique matérielle | Excellente |

### 3.2 Faiblesses des canaux SMS/E-mail

!!! warning "L'e-mail n'est pas un second facteur"
    Si le compte e-mail est protégé par le même mot de passe (ou un mot de passe faible), recevoir le code 2FA par e-mail revient à utiliser **deux fois le même facteur de connaissance**, annulant le bénéfice du MFA.

- **SIM Swapping** : l'attaquant convainc l'opérateur téléphonique de porter le numéro de la victime vers une carte SIM qu'il contrôle.
- **Interception SS7** : faiblesses protocolaires du réseau de signalisation téléphonique permettant l'interception de SMS.

### 3.3 Failles de logique applicative en 2FA

**a) Accès direct aux ressources internes sans validation 2FA**

```text
1. POST /login (username + password) -> 200 OK, redirection vers /2fa
2. Le serveur crée déjà une session "authentifiée" à cette étape
3. L'attaquant navigue directement vers /dashboard sans passer par /2fa
   -> Accès accordé si le serveur ne revérifie pas l'état "2FA validé"
```

**b) Attribution prématurée du cookie de session**

```http
HTTP/1.1 200 OK
Set-Cookie: session=eyJhbGciOiJIUzI1NiJ9...; HttpOnly
Location: /2fa-verify
```

Si ce cookie est **déjà pleinement privilégié** avant la validation du code 2FA, l'étape 2FA n'est qu'une façade côté client (contrôlée par le front-end via redirection JS), contournable en manipulant directement les requêtes API.

**c) Substitution de jeton/cookie entre comptes**

```text
1. Attaquant se connecte avec SON compte -> reçoit un cookie 2fa_pending=abc123
2. Attaquant initie le login avec le compte VICTIME (username + password volés)
3. Le serveur génère un nouveau 2fa_pending=xyz789 pour la victime
4. Si l'attaquant soumet SON propre code 2FA valide avec le cookie xyz789 de la victime
   -> Le serveur valide l'étape 2FA de la victime avec le code de l'attaquant
   -> Faille : absence de liaison stricte entre cookie, code OTP et compte utilisateur
```

### 3.4 Force brute sur les codes 2FA

```text
Code à 6 chiffres = 1 000 000 combinaisons possibles
Sans rate-limiting ni invalidation de session après N échecs
-> Brute force automatisable en quelques minutes (Burp Intruder / script)
```

!!! tip "Contre-mesures"
    - Verrouiller strictement l'état de session serveur : aucune ressource protégée accessible tant que le facteur 2 n'est pas validé côté serveur (jamais uniquement côté client/redirection).
    - Lier cryptographiquement le jeton "2FA pending" au compte concerné (pas de session partagée/réutilisable entre utilisateurs).
    - Rate-limiting strict sur la soumission du code OTP (ex. 5 tentatives puis invalidation complète de la session).
    - Expiration courte des codes OTP (30-60s pour TOTP).
    - Prioriser FIDO2/WebAuthn ou TOTP applicatif plutôt que SMS/e-mail.

---

## 4. Persistance & Cookies "Se souvenir de moi" (Remember-me)

### 4.1 Génération prédictible

```python
# Implémentation vulnérable
cookie_value = base64.b64encode(f"{username}:{timestamp}".encode())
# ex: YWRtaW46MTcyNzUxMjAwMA== -> "admin:1727512000"
```

Si le format est déductible (concaténation `username` + `timestamp`), un attaquant qui connaît le username cible peut forger un cookie valide en devinant/brute-forçant une plage de timestamps plausible.

### 4.2 Cryptographie faible

- **Simple encodage** : Base64/Hex ne sont **pas** du chiffrement — réversibles instantanément.
- **Hachage sans sel** : `MD5(username)` ou `SHA1(username:password)` sans sel unique est vulnérable aux **rainbow tables** et permet la comparaison directe entre comptes.

### 4.3 Rétro-ingénierie

- Création de plusieurs comptes de test pour comparer la structure des cookies générés et déduire l'algorithme (différences observées quand seul le username change, par exemple).
- Audit du code source (si accessible — app open source, décompilation mobile).
- Vol de cookies existants via XSS pour analyse hors ligne.

!!! tip "Contre-mesures"
    - Jeton *remember-me* aléatoire (CSPRNG), **sans rapport déductible** avec les données utilisateur.
    - Sel unique par utilisateur pour tout hachage.
    - Stockage côté serveur d'un hash du jeton (jamais le jeton en clair), avec possibilité de révocation.
    - Rotation du jeton à chaque utilisation (*token rotation*) pour détecter le rejeu.

---

## 5. Réinitialisation de Mot de Passe (Password Reset)

### 5.1 Canaux non sécurisés

Envoi d'un **mot de passe temporaire en clair** par e-mail : le canal e-mail n'étant pas garanti confidentiel (boîte compromise, interception), cette pratique est déconseillée au profit de liens à jeton unique.

### 5.2 Architecture sécurisée basée sur les jetons

Un jeton de réinitialisation robuste doit être :

- **Unique** (CSPRNG, ≥128 bits d'entropie).
- **Éphémère** (expiration courte, 15-60 min).
- **À usage unique** (invalidé après le premier usage).
- **Stocké sous forme de hash** en base de données (jamais en clair — en cas de fuite BDD, le jeton en clair transmis par mail reste inutilisable).

### 5.3 Vecteurs d'attaque

**a) Jetons prédictibles**

```python
# Vulnérable
token = md5(user.email)
token = str(int(time.time())) + str(user.id)   # séquentiel/déductible
```

**b) Absence de revérification du jeton à l'étape finale**

```text
1. GET /reset-password?token=XYZ    -> serveur valide XYZ, affiche le formulaire
2. POST /reset-password             -> serveur enregistre le nouveau mot de passe
                                        SANS revalider XYZ dans le body/session
```

Si le `token` n'est vérifié qu'à l'étape GET (affichage du formulaire) et non revalidé lors du POST final, un attaquant qui intercepte/devine l'URL du formulaire (sans le token valide) peut potentiellement soumettre directement le POST.

**c) Host Header Injection**

```http
POST /forgot-password HTTP/1.1
Host: attacker.com
Content-Type: application/x-www-form-urlencoded

email=victime@cible.exemple
```

Si l'application génère dynamiquement le lien de réinitialisation à partir de l'en-tête `Host` de la requête plutôt que d'une valeur serveur fixe :

```text
# E-mail envoyé à la victime :
Cliquez ici pour réinitialiser : http://attacker.com/reset?token=XYZ789
```

La victime légitime clique sur un lien pointant vers le domaine de l'attaquant, qui capture alors le `token` valide dans ses propres logs serveur et peut l'utiliser pour réinitialiser le mot de passe de la victime avant elle.

!!! tip "Contre-mesures"
    - Ne **jamais** construire d'URL sensible à partir de l'en-tête `Host` (utiliser une valeur de configuration serveur fixe, type `APP_BASE_URL`).
    - Validation stricte de l'en-tête `Host` (whitelist) si son usage est inévitable.
    - Jeton CSPRNG stocké haché, revérifié systématiquement à **chaque** étape du workflow (GET **et** POST).
    - Invalidation immédiate du jeton après usage, et de tous les jetons actifs après un changement de mot de passe réussi.
    - Notification à l'utilisateur (e-mail) après toute réinitialisation effectuée.

---

## 6. Changement de Mot de Passe (Password Change)

### 6.1 IDOR — Substitution de paramètre d'identité

```http
POST /account/change-password HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Cookie: session=att4ck3r_session_valide

user_id=123&new_password=Hacked123!
```

Si le serveur détermine le compte cible via un paramètre `user_id` fourni par le client (formulaire, champ caché) plutôt que via l'identité liée à la session serveur, un attaquant authentifié sur **son propre compte** peut modifier le `user_id` pour cibler un compte arbitraire :

```html
<input type="hidden" name="user_id" value="123">
```

### 6.2 Absence de vérification du mot de passe actuel

Sans exigence du mot de passe courant, un attaquant profitant d'une session déjà ouverte (poste partagé, vol de session via XSS/CSRF) peut changer le mot de passe et évincer l'utilisateur légitime, sans même connaître son mot de passe d'origine.

```http
POST /account/change-password HTTP/1.1
Cookie: session=session_volee_via_xss

new_password=Attacker123!
```

### 6.3 Exposition à la force brute

Si la validation du "mot de passe actuel" n'est pas soumise à rate-limiting, un attaquant disposant d'une session active peut brute-forcer ce champ pour confirmer un mot de passe deviné par ailleurs.

!!! tip "Contre-mesures"
    - Identité de l'utilisateur cible **toujours** dérivée de la session serveur authentifiée, jamais d'un paramètre client.
    - Exiger systématiquement le mot de passe actuel (re-authentification) avant tout changement sensible.
    - Rate-limiting sur la vérification du mot de passe actuel.
    - Invalider toutes les autres sessions actives après un changement de mot de passe.
    - Notification e-mail de l'événement.

---

## 7. Authentification Tierce & Synthèse Blue Team

### 7.1 Authentification tierce (OAuth 2.0 / OIDC)

L'authentification déléguée via **OAuth 2.0** / **OpenID Connect (OIDC)** déplace une partie de la surface d'attaque vers la gestion :

- Des **redirections** (`redirect_uri` non whitelistée → vol de code d'autorisation).
- Du **state token** (protection CSRF du flux OAuth — son absence permet des attaques de fixation de session OAuth).

!!! note "Hors périmètre détaillé"
    Les vulnérabilités spécifiques à OAuth/OIDC (fixation de `redirect_uri`, confusion de `scope`, `state` prévisible) mériteraient une fiche dédiée tant la surface est large.

### 7.2 Matrice synthétique des bonnes pratiques

| Domaine | Recommandation |
|---|---|
| **Protections réseau** | HTTPS strict (HSTS), aucun identifiant en clair sur le réseau |
| **Robustesse des mots de passe** | Estimation via `zxcvbn` plutôt que règles de complexité rigides |
| **Prévention de l'énumération** | Messages d'erreur génériques, réponses/temps de réponse uniformisés |
| **Anti brute-force** | Rate-limiting par IP + par compte, backoff progressif, CAPTCHA contextuel |
| **Logique applicative** | Identité toujours dérivée de la session serveur, jamais d'un paramètre client, à **tous** les points d'entrée (login, reset, 2FA, changement de mot de passe) |
| **MFA** | Prioriser TOTP/FIDO2/WebAuthn ; éviter SMS/e-mail comme facteur unique |
| **Jetons (reset, remember-me)** | CSPRNG, usage unique, expiration courte, stockage haché, revérification systématique |
| **Supervision** | Alerting sur password spraying, tentatives 2FA répétées, changements de mot de passe atypiques |

!!! danger "Principe directeur"
    La majorité des failles décrites dans ce document ne relèvent pas d'un défaut cryptographique, mais d'une **rupture de la chaîne de confiance côté serveur** : dès qu'une étape d'authentification se fie à une donnée fournie par le client (paramètre, en-tête `Host`, état côté front-end) plutôt qu'à l'état de session serveur, le mécanisme devient contournable.

---

## 🧠 Synthèse de révision (Flashcard mentale)

### 1. Mécanisme de base (Cause racine)

La *Broken Authentication* repose sur une confusion unique et récurrente : **le serveur accorde sa confiance à une donnée ou à un état contrôlé par le client, à la place de son propre état de session.** Concrètement, dès qu'une étape du workflow d'authentification (identification, second facteur, réinitialisation, changement de mot de passe) s'appuie sur un paramètre transmis par le navigateur, un en-tête HTTP, ou une variable côté front-end plutôt que sur une vérification effectuée et mémorisée côté serveur, la frontière entre "ce que le client affirme" et "ce que le serveur a réellement vérifié" s'efface. La faille n'est donc généralement pas un défaut de l'algorithme cryptographique lui-même, mais une rupture dans l'enchaînement logique des étapes qui composent le processus d'authentification.

### 2. Vecteurs & Formes d'exploitation

- **Par canal auxiliaire (side-channel)** : l'attaquant n'attaque pas directement le secret, mais observe des différences indirectes (code de statut, message d'erreur, temps de réponse) pour déduire une information sensible, comme l'existence d'un compte.
- **Par volume / débit (brute force distribué)** : l'attaquant exploite l'absence ou la contournabilité d'une limite de débit pour tester un grand nombre de combinaisons, en dispersant l'effort soit sur les mots de passe, soit sur les comptes ciblés.
- **Par rupture de séquence (logique de workflow)** : l'attaquant saute ou détourne une étape censée être obligatoire dans un enchaînement multi-étapes, en exploitant le fait que le serveur n'a pas revérifié l'état à chaque point de contrôle.
- **Par substitution de référence (paramètre d'identité)** : l'attaquant remplace la valeur d'un identifiant censé désigner "sa propre" ressource par celle d'une ressource appartenant à un tiers, profitant de l'absence de recoupement avec l'identité de session.
- **Par prédictibilité (faiblesse de génération)** : l'attaquant reconstruit ou devine un secret censé être aléatoire (jeton, cookie) parce que sa méthode de génération repose sur des données déductibles ou un encodage réversible plutôt que sur une source d'aléa cryptographique.
- **Par abus de canal tiers (ingénierie sociale / infrastructure)** : l'attaquant contourne le facteur d'authentification en s'attaquant non pas à l'application, mais au canal de transport du secret (opérateur téléphonique, protocole de signalisation, boîte e-mail).

### 3. Workflow de diagnostic synthétique

1. **Cartographier** l'ensemble des points d'entrée liés à l'identité (login, 2FA, reset, changement de mot de passe, remember-me, SSO tiers).
2. **Tester l'énumération** pour établir en amont un périmètre de comptes valides.
3. **Évaluer le débit** : la limitation de tentatives est-elle réelle, par compte ET par IP, et résiste-t-elle aux variantes de format de requête ?
4. **Auditer chaque enchaînement multi-étapes** (2FA, reset) en se demandant systématiquement : *"Que se passe-t-il si je saute directement à l'étape finale, ou si je rejoue une étape avec un contexte différent ?"*
5. **Chercher les paramètres d'identité manipulables** sur toute action sensible, en comparant ce que le serveur *devrait* déduire de la session à ce qu'il accepte en pratique du client.
6. **Évaluer l'entropie et la structure** de tout secret généré côté serveur (token, cookie) avant de conclure à sa robustesse.
7. **Conclure** en distinguant clairement une faiblesse intrinsèque (mécanisme faible) d'une faille de logique applicative (workflow contournable), car la remédiation diffère.

### 4. Remédiation & Sécurisation

- **Ancrer l'identité côté serveur** : toute action sensible doit dériver l'identité de l'utilisateur exclusivement de l'état de session serveur authentifié, jamais d'un paramètre, en-tête ou champ transmis par le client.
- **Revalider à chaque étape** : dans tout processus multi-étapes, chaque étape doit revérifier indépendamment les conditions requises (jeton, statut du facteur précédent), sans supposer qu'une vérification antérieure suffit pour la suite.
- **Uniformiser les réponses observables** : codes de statut, messages d'erreur et temps de traitement doivent être indistinguables entre un cas valide et un cas invalide, pour supprimer les canaux auxiliaires d'information.
- **Limiter le débit de façon robuste et multi-dimensionnelle** : rate-limiting combiné par identifiant et par origine réseau, avec ralentissement progressif et validation stricte du format des requêtes pour empêcher les contournements structurels.
- **Générer les secrets par un aléa cryptographique fort** : tout jeton ou cookie sensible doit provenir d'un générateur pseudo-aléatoire cryptographiquement sûr, à haute entropie, sans lien déductible avec des données utilisateur, stocké haché côté serveur, à usage unique et à durée de vie limitée.
- **Renforcer le second facteur** : privilégier des mécanismes cryptographiques matériels ou applicatifs plutôt que des canaux dépendant d'infrastructures tierces peu fiables, et lier strictement chaque jeton intermédiaire au compte concerné.
- **Notifier et permettre la révocation** : informer l'utilisateur de tout événement sensible (réinitialisation, changement de mot de passe) et invalider les sessions ou jetons concurrents lors d'un changement d'identifiants.
- **Documenter la distinction faiblesse intrinsèque / faille de logique** dans tout rapport d'audit, car les deux catégories appellent des corrections différentes (durcissement cryptographique vs. refonte du workflow).
