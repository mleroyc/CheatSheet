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
    Ce workflow est un guide opérationnel pour un test d'intrusion **autorisé**. Chaque étape suppose un périmètre validé par contrat.

L'objectif de cette section est de fournir un arbre de décision pour prioriser les tests sur le terrain, dans l'ordre où un attaquant (ou un pentester) les enchaînerait logiquement : d'abord cartographier la surface (usernames valides), puis attaquer le canal le plus faible (mot de passe), puis les couches suivantes (2FA, persistance, reset, changement de mot de passe).

---

### Étape 1 — Le point d'entrée réagit-il différemment selon le username ?

**Test.** Soumettre `POST /login` avec un username **connu/probable** (`admin`) et un mot de passe volontairement invalide, puis comparer avec un username **manifestement inexistant** (`zzzz_test_9999`) et le même mot de passe invalide. Comparer code HTTP, corps de réponse, en-têtes et temps de réponse (cf. §2.3).

**Interprétation**

- **J'obtiens des réponses strictement identiques** (code, corps, timing) → La faille d'énumération **n'est pas exploitable** de cette manière car le serveur uniformise sa réponse quel que soit l'état du compte — c'est le comportement attendu d'une implémentation durcie.
- **J'obtiens un différentiel** (code 404 vs 200, message « User not found » vs « Invalid password », ou écart de latence > quelques dizaines de ms) → La faille est **confirmée et exploitable** sous la forme d'une **énumération de comptes par canal auxiliaire** (variante *status code*, *message d'erreur* ou *timing attack*, §2.3) car le serveur laisse fuiter, via un signal indirect, une information qu'il ne devrait révéler qu'après authentification complète.

**Décision.** Si confirmé → constituer une liste de usernames valides via un différentiel automatisé, puis pivoter vers l'Étape 2. Si non exploitable → passer directement à l'Étape 2 avec une wordlist générique (patterns OSINT / comptes par défaut, §2.1).

---

### Étape 2 — Les protections anti-brute-force sont-elles réellement effectives ?

**Test.** Une fois une liste de usernames valides (ou probables) en main, injecter un tableau de valeurs dans le champ `password` d'une requête JSON (`{"password": ["p1","p2","p3"]}`, §2.4) et observer si le compteur de tentatives échouées s'incrémente d'une seule unité malgré plusieurs mots de passe testés.

**Interprétation**

- **Le compte se verrouille après une tentative** (ou le compteur augmente de N pour N valeurs soumises) → La faille de contournement **n'est pas exploitable** de cette manière car le serveur valide strictement le schéma de la requête et comptabilise chaque valeur individuellement.
- **Le compte n'est pas verrouillé malgré plusieurs mots de passe testés en un seul appel** → La faille est **confirmée et exploitable** sous la forme d'un **bypass du rate-limiting par manipulation de structure de requête** car le framework backend itère sur le tableau sans que le rate-limiter ne compte chaque itération comme une tentative distincte.

**Décision.** Si confirmé → mener un brute force ciblé (ou un password spraying sur la liste de comptes de l'Étape 1) via ce vecteur. Si non exploitable → tester le contournement par fenêtre glissante (intercaler des `GET /login` entre tentatives) ou pivoter vers le **password spraying classique** (un seul mot de passe commun sur tous les comptes, §2.4), qui reste sous le seuil de verrouillage par compte même avec un rate-limiter correctement implémenté.

---

### Étape 3 — Une fois authentifié en étape 1, le 2FA est-il une vraie barrière serveur ?

**Test.** Après soumission réussie de username/mot de passe (avant validation du code 2FA), inspecter la réponse `Set-Cookie` puis tenter d'accéder directement à une ressource protégée (`GET /dashboard`) sans jamais soumettre de code OTP (§3.3-a et 3.3-b).

**Interprétation**

- **L'accès à `/dashboard` est refusé (redirection forcée vers `/2fa-verify`, session marquée non privilégiée)** → Le bypass **n'est pas exploitable** de cette manière car l'état « 2FA validé » est vérifié côté serveur à chaque requête sur une ressource protégée.
- **L'accès à `/dashboard` est accordé** → La faille est **confirmée et exploitable** sous la forme d'un **bypass 2FA par accès direct**, car le cookie de session émis après l'étape 1 est déjà pleinement privilégié et la vérification 2FA n'est qu'une façade côté client.

**Décision.** Si confirmé → l'ATO (Account Takeover) est complet dès l'étape 1, le 2FA n'apporte aucune protection réelle. Si non exploitable → pivoter vers le test de **substitution de jeton 2fa_pending entre comptes** (§3.3-c) : initier une session 2FA sur son propre compte, puis vérifier si le code OTP légitime de l'attaquant est accepté avec le cookie `2fa_pending` généré pour la victime.

---

### Étape 4 — Le jeton "remember-me" est-il prévisible ou forgeable ?

**Test.** Créer deux comptes de test avec des usernames de longueurs différentes et comparer la structure Base64/Hex des cookies `remember-me` générés (§4.1 et 4.3), en isolant les segments qui varient uniquement selon le username.

**Interprétation**

- **Le jeton ne présente aucune structure déductible malgré la comparaison** (entropie uniforme, aucune corrélation avec username/timestamp) → La faille **n'est pas exploitable** de cette manière car le jeton est probablement généré par un CSPRNG sans lien direct avec les données utilisateur.
- **Le décodage révèle un pattern lisible** (`username:timestamp` en clair après Base64, ou un hash reproductible via `MD5(username)`) → La faille est **confirmée et exploitable** sous la forme d'une **forge de cookie de persistance** car un attaquant connaissant le username cible peut reconstruire ou brute-forcer un jeton valide sans jamais connaître le mot de passe.

**Décision.** Si confirmé → forger un cookie pour un username cible connu (obtenu à l'Étape 1) et tenter une connexion persistante. Si non exploitable → pivoter vers le vol de cookie existant via une éventuelle XSS ailleurs sur l'application, pour analyse hors ligne (§4.3).

---

### Étape 5 — Le workflow de réinitialisation de mot de passe revérifie-t-il le jeton à chaque étape ?

**Test.** Lancer un `GET /reset-password?token=XYZ` valide pour afficher le formulaire, **supprimer ou altérer** le `token` dans le body du `POST /reset-password` final, et observer si le changement de mot de passe est malgré tout accepté (§5.3-b).

**Interprétation**

- **Le `POST` est rejeté sans `token` valide dans le body/session** → La faille **n'est pas exploitable** de cette manière car le serveur revalide le jeton à chaque étape sensible du workflow.
- **Le `POST` aboutit malgré l'absence/altération du `token`** → La faille est **confirmée et exploitable** sous la forme d'une **absence de revérification du jeton en fin de workflow**, car seule l'étape GET (affichage) était protégée, pas l'action de modification elle-même.

**Décision.** Si confirmé → combiner avec un vol d'URL de formulaire (referer leak, historique navigateur partagé) pour rejouer le POST sans connaître le token. Si non exploitable → tester le vecteur **Host Header Injection** (§5.3-c) : soumettre `POST /forgot-password` avec un en-tête `Host` modifié et vérifier si le lien généré dans l'e-mail pointe vers ce domaine arbitraire plutôt que vers l'URL de configuration serveur.

---

### Étape 6 — Le changement de mot de passe authentifié dérive-t-il l'identité de la session ou d'un paramètre client ?

**Test.** Authentifié sur **son propre compte de test**, soumettre `POST /account/change-password` en substituant le `user_id` du body par l'identifiant d'un autre compte de test connu (§6.1).

**Interprétation**

- **La requête échoue ou ne modifie que le compte de la session courante, quel que soit le `user_id` soumis** → La faille IDOR **n'est pas exploitable** de cette manière car l'identité de la cible est dérivée exclusivement de la session serveur authentifiée.
- **Le mot de passe du compte visé par `user_id` est effectivement modifié** → La faille est **confirmée et exploitable** sous la forme d'un **IDOR sur le changement de mot de passe**, car le serveur fait confiance à un paramètre fourni par le client pour déterminer le compte cible plutôt qu'à l'état de session.

**Décision.** Si confirmé → il s'agit d'un ATO direct sur n'importe quel `user_id` énumérable. Si non exploitable → vérifier l'**absence de vérification du mot de passe actuel** (§6.2) en soumettant directement un nouveau mot de passe sans fournir l'ancien, pertinent en cas de session volée (XSS/CSRF/poste partagé).

---

### Synthèse du cheminement

```text
Énumération (Étape 1) ──► identifiants valides ──► Brute force / bypass rate-limit (Étape 2)
        │                                                  │
        └── non concluant ──► wordlist générique ──────────┘
                                                             ▼
                                        Accès post-authentification (Étape 3 : 2FA)
                                                             │
                                        ┌────────────────────┴────────────────────┐
                                        ▼                                         ▼
                          Persistance (Étape 4 : remember-me)         Reset de mot de passe (Étape 5)
                                        │                                         │
                                        └──────────────► Changement de mot de passe authentifié (Étape 6)
```

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

## 🧠 Synthèse de révision (Flashcard mentale)

### 1. Mécanisme de base (Cause racine)

L'authentification cassée (*Broken Authentication*) ne provient presque jamais d'un défaut de l'algorithme cryptographique lui-même, mais d'une **confusion de confiance** : le serveur traite une donnée **contrôlée par le client** (un paramètre de formulaire, un en-tête HTTP, un état affiché côté front-end) comme si elle avait la valeur de vérité d'un **état de session côté serveur**. Autrement dit, une étape du workflow d'identité (qui-suis-je / suis-je pleinement authentifié / ai-je le droit de modifier cette ressource) est déléguée, même partiellement, à une donnée que l'utilisateur peut lui-même façonner. Dès que cette frontière entre « donnée fournie par le client » et « fait établi côté serveur » s'estompe, le mécanisme devient contournable, quelle que soit la robustesse du hachage ou du chiffrement sous-jacent.

### 2. Vecteurs & Formes d'exploitation

- **Énumération par canal auxiliaire** — la logique métier fuit une information (existence d'un compte) via un signal secondaire (code HTTP, message, timing) plutôt que par la réponse principale elle-même.
- **Contournement de limitation** — la protection anti-abus est appliquée à un niveau de granularité incorrect (par requête plutôt que par tentative logique), ce qui permet de faire passer plusieurs actions sensibles pour une seule.
- **Bypass de facteur additionnel** — un mécanisme conçu comme une barrière supplémentaire n'est en réalité qu'une étape d'interface, sans verrou équivalent côté serveur.
- **Forge ou prédiction de jeton** — un identifiant censé être aléatoire est en réalité dérivé de données connues ou observables, rendant sa reconstruction possible sans force brute exhaustive.
- **Détournement de flux via une donnée d'environnement** — une valeur d'apparence anodine transmise par le client (comme l'hôte cible d'une requête) est réutilisée par le serveur pour construire un artefact sensible destiné à un tiers.
- **Substitution d'identité par paramètre** — l'action sensible s'applique à une cible désignée par une valeur du client au lieu de la cible déduite de la session, permettant d'agir pour le compte d'autrui.

### 3. Workflow de diagnostic synthétique

1. Vérifier si la surface d'authentification laisse fuiter une information distinctive selon l'état d'un compte (existant/inexistant) — c'est le point d'entrée pour réduire l'espace de recherche.
2. Vérifier si les protections anti-abus comptent réellement chaque tentative logique, ou seulement chaque requête réseau.
3. Vérifier si un facteur additionnel (2FA, revalidation) est appliqué comme une contrainte serveur systématique, ou seulement comme une étape d'interface contournable en accédant directement à la ressource protégée.
4. Vérifier si tout jeton (persistance, réinitialisation) est réellement imprévisible, à usage unique, et revérifié à **chaque** étape sensible du workflow — pas uniquement à l'affichage initial.
5. Vérifier si toute action sensible sur un compte dérive sa cible de la session authentifiée, et non d'un paramètre transmis par le client.
6. À chaque étape, la question centrale reste la même : « cette décision repose-t-elle sur un état que je contrôle en tant que client, ou sur un état que seul le serveur peut garantir ? »

### 4. Remédiation & Sécurisation

- **Uniformisation systématique des réponses** (code HTTP, corps, temps de traitement) indépendamment de l'existence réelle d'un compte, pour supprimer tout canal auxiliaire d'énumération.
- **Limitation des tentatives à double granularité** (par identifiant ET par origine), avec une validation stricte du schéma des requêtes pour empêcher qu'une action groupée ne soit comptée comme une action unique.
- **Application de tout contrôle de facteur additionnel exclusivement côté serveur**, avec un état de session qui reste non privilégié tant que l'ensemble des facteurs requis n'a pas été validé, et une liaison cryptographique stricte entre le jeton temporaire et le compte concerné.
- **Génération de tout identifiant sensible via un générateur cryptographiquement sûr**, sans lien déductible avec des données utilisateur connues, stocké sous forme hachée côté serveur, à usage unique et à durée de vie limitée.
- **Dérivation systématique de l'identité cible depuis la session serveur authentifiée**, jamais depuis une valeur fournie par le client, à chaque point d'entrée du cycle de vie du compte (connexion, réinitialisation, changement de facteur, changement de mot de passe).
- **Revalidation de tout jeton ou état de confiance à chaque étape du workflow**, y compris les étapes finales d'exécution, et non uniquement à l'étape d'affichage initial.
- **Journalisation et notification proactive** des événements sensibles (changement de mot de passe, réinitialisation, échecs répétés d'un second facteur) afin de détecter une exploitation même lorsque le contrôle préventif a été contourné.
