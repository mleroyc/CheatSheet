---
title: "API Security Testing — Sécurité & Audit des API"
description: "Méthodologie offensive et défensive pour l'audit d'API : reconnaissance, documentation OpenAPI/Swagger, surface d'attaque cachée, Mass Assignment, Server-Side Parameter Pollution (SSPP) et remédiation."
tags:
  - web
  - api
  - rest
  - openapi
  - swagger
  - mass-assignment
  - sspp
  - parameter-pollution
  - xxe
  - owasp-api
---

# 🔌 Sécurité & Audit des API (API Security Testing)

!!! warning "Cadre légal"
    Les techniques décrites ci-dessous ne doivent être mises en œuvre que dans un cadre d'audit autorisé par écrit, ou en environnement de laboratoire.

!!! info "Fiche complémentaire"
    Cette fiche se concentre sur la **méthodologie de reconnaissance d'API** et sur la **pollution de paramètres côté serveur (SSPP)**, un vecteur spécifique peu documenté. Pour une exploitation approfondie du détournement de méthodes HTTP et du Mass Assignment avec exemples de code applicatif détaillés, se référer également à la fiche *Pentesting & Audit : Sécurité des API RESTful*.

---

## 1. Généralités sur les Tests d'API

### 1.1 Évolution architecturale

Les applications web modernes ont profondément évolué d'une logique de **rendu serveur monolithique** vers une architecture où une **interface utilisateur découplée** (SPA, application mobile) **pilote des architectures d'API sous-jacentes** via des appels structurés (REST, GraphQL). **Auditer directement l'API** permet de tester **le cœur logique et les flux de données réels** de l'application, indépendamment de toute contrainte ou filtrage introduit par la couche de présentation.

### 1.2 Affranchissement du Front-End

!!! danger "L'audit d'API ne se limite jamais à ce que montre l'interface"
    Contrairement à un audit centré sur l'**IHM**, l'audit d'une API **RESTful ou JSON** exige de **manipuler directement les endpoints**, en s'affranchissant totalement du parcours utilisateur visible. Un attaquant — comme un auditeur sérieux — ne se limite jamais aux requêtes que le navigateur émet naturellement : il reconstruit et modifie des requêtes directement à destination du serveur.

### 1.3 Surface d'attaque cachée

Les architectures API présentent, de façon quasi systématique, une **surface d'attaque bien plus large** que celle visible depuis l'interface :

- **Endpoints orphelins** : routes existantes côté serveur mais jamais reliées à un élément d'interface.
- **Méthodes HTTP alternatives** (`PUT`, `DELETE`, `PATCH`) : souvent implémentées sur une route dont seul `GET` ou `POST` est exploité par le front-end.
- **Paramètres d'administration** : inactifs ou absents de l'interface standard, mais parfaitement **fonctionnels côté serveur** pour un rôle à privilèges.

### 1.4 Spécificités techniques des architectures API

Au-delà des vulnérabilités web classiques, les architectures API — en particulier celles reposant sur une **passerelle (gateway)** relayant des requêtes vers des **microservices internes** — introduisent des vecteurs propres, au premier rang desquels la **pollution de paramètres côté serveur** (*Server-Side Parameter Pollution* — **SSPP**), détaillée en section 5, et qui constitue l'un des vecteurs les plus spécifiques et les moins triviaux à détecter dans ce type d'architecture.

---

## 2. Reconnaissance & Découverte de la Documentation (API Recon)

### 2.1 Analyse du trafic

L'interception du trafic via un **proxy** (Burp Suite) reste le point de départ de toute reconnaissance d'API, permettant d'identifier :

```text
Préfixes de routage typiques :
/api/v1/
/api/v2/
/graphql

Sous-domaines dédiés :
api.example.com
api-internal.example.com
```

### 2.2 Fichiers de spécification orphelins

Les **fichiers de documentation machine** laissés accessibles en production constituent la cible de reconnaissance la plus rentable :

```bash
curl -s https://cible.com/swagger.json
curl -s https://cible.com/openapi.yaml
curl -s https://cible.com/api-docs/
curl -s https://cible.com/redoc
curl -s https://cible.com/swagger/index.html
curl -s https://cible.com/v2/api-docs
curl -s https://cible.com/v3/api-docs
```

!!! danger "Une spécification Swagger exposée équivaut à une cartographie complète livrée clé en main"
    La découverte d'un fichier `swagger.json` ou `openapi.yaml` accessible sans authentification sur un environnement de **production** doit être traitée comme une **fuite d'information critique** : elle documente intégralement l'ensemble des endpoints, paramètres, schémas de données et méthodes HTTP de l'API — y compris des routes **jamais exposées** au front-end public, parfois réservées à un usage interne ou administratif. Cette découverte réduit l'effort de reconnaissance restant à une fraction de ce qu'il aurait fallu pour une API totalement opaque.

### 2.3 Méthodes de découverte des documentations cachées

**Crawling et exploration manuelle**

Parcours exhaustif de l'application en mode proxy, combiné aux outils de découverte de contenu de Burp Suite (*Discover Content*), pour repérer tout lien ou référence menant vers une ressource de documentation.

**Analyse régressive des chemins (*Base Path Investigation*)**

```bash
# Remontée systématique de l'arborescence à partir d'un endpoint connu
BASE_ENDPOINT="/api/v1/users/123"
CANDIDATS=("" "swagger" "swagger.json" "docs" "openapi.yaml" "api-docs" "redoc")

for c in "${CANDIDATS[@]}"; do
  echo "Test: /api/v1/$c"
  curl -s -o /dev/null -w "%{http_code}\n" "https://cible.com/api/v1/$c"
done
```

**Fuzzing de répertoires ciblé**

```bash
ffuf -u https://cible.com/FUZZ -w wordlist-api-docs.txt \
  -e .json,.yaml,.yml \
  -mc 200,401,403
```

### 2.4 Exploitation du contrat d'API

**Test systématique de toutes les méthodes HTTP**

```http
OPTIONS /api/v1/users/123 HTTP/1.1
Host: cible.com
```

```http
HTTP/1.1 200 OK
Allow: GET, POST, PUT, DELETE, PATCH, OPTIONS
```

!!! tip "Tester chaque méthode listée, même non documentée"
    L'en-tête `Allow` renvoyé par une requête `OPTIONS` révèle fréquemment des méthodes (`PUT`, `DELETE`, `PATCH`) **jamais exploitées par le front-end** mais pourtant actives côté serveur. Chacune doit être testée individuellement avec le contexte d'autorisation disponible.

**Manipulation des en-têtes `Content-Type` et `Accept`**

```http
POST /api/v1/orders HTTP/1.1
Host: cible.com
Content-Type: application/xml
Accept: application/json

<?xml version="1.0"?>
<order><productId>42</productId></order>
```

**Test de robustesse des types de données**

```json
// Variations de typage à soumettre systématiquement sur un même champ
{"quantity": "1"}
{"quantity": [1, 2]}
{"quantity": true}
{"quantity": {"value": 1}}
{"quantity": null}
```

### 2.5 Automatisation via la documentation machine

Une spécification OpenAPI/Swagger récupérée doit être **immédiatement importée** dans des outils générant automatiquement une collection de tests exploitables :

| Outil | Usage |
|---|---|
| **Burp Scanner** | Import natif OpenAPI, génération automatique de requêtes de base par endpoint puis scan actif |
| **Extension *OpenAPI Parser*** (BApp Store) | Peuplement automatique du Site Map Burp sans parcours manuel |
| **Postman** | Import direct en collection structurée, environnements de test réutilisables |
| **SoapUI** | Génération de suites de tests fonctionnels et de sécurité |

---

## 3. Interaction avec les Endpoints & Surface d'Attaque Cachée

### 3.1 Analyse des fichiers JavaScript minifiés

```bash
curl -s https://cible.com/static/js/main.a1b2c3.js | grep -oE '"/api/[a-zA-Z0-9/_-]+"'
```

```bash
# LinkFinder : extraction automatisée de routes depuis des bundles JS
python3 linkfinder.py -i https://cible.com/static/js/main.a1b2c3.js -o cli
```

!!! tip "Cibler les mots-clés révélateurs"
    Prioriser la recherche de segments contenant `admin`, `internal`, `debug`, `_private`, `legacy`, `v0` dans les chaînes extraites : ces fragments trahissent très souvent des **routes internes**, des **paramètres de débogage** ou des **fonctions d'administration** jamais destinées à un usage public.

### 3.2 Manipulation des verbes & types de médias

Forcer le serveur à **basculer de parseur** en modifiant le `Content-Type` déclaré, afin de contourner un WAF calibré sur un format unique ou de déclencher une faille de parsing :

```http
POST /api/v1/import HTTP/1.1
Host: cible.com
Content-Type: application/xml

<?xml version="1.0"?>
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<data>&xxe;</data>
```

!!! danger "Passage JSON → XML : un double risque"
    Au-delà du simple contournement de filtre, forcer l'interprétation d'un corps de requête par un **parseur XML** sous-jacent — souvent supporté nativement par le framework même s'il n'est jamais sollicité en conditions normales — ouvre potentiellement la voie à une injection **XXE** (*XML External Entity*), pouvant elle-même déboucher sur une divulgation de fichiers locaux, voire un SSRF (voir les fiches dédiées *SSRF* et *File Upload*).

### 3.3 Fuzzing de chemins (Path Fuzzing)

```bash
ffuf -u https://cible.com/api/v1/FUZZ -w api-endpoints-wordlist.txt \
  -H "Authorization: Bearer <token>" \
  -mc 200,401,404
```

| Code observé | Signification |
|---|---|
| `200` | Route existante et accessible avec le contexte fourni |
| `401` | Route existante mais nécessitant une authentification valide — cible de contournement prioritaire |
| `404` | Route probablement inexistante (sous réserve d'un comportement volontairement trompeur) |

### 3.4 Recherche de paramètres cachés

```text
POST /api/v1/user/update HTTP/1.1
Host: cible.com
Content-Type: application/json

{"§candidat_param§": "valeur_test"}
```

!!! tip "Param Miner : automatiser la découverte de paramètres non documentés"
    L'extension **Param Miner** teste, à grande échelle, des listes de noms de paramètres GET/POST et d'en-têtes HTTP contre un endpoint cible, en détectant les **variations de comportement** révélant qu'un paramètre est réellement **consommé** côté serveur malgré son absence de toute documentation — vecteur d'entrée direct vers le **Mass Assignment** (section 4).

---

## 4. Mass Assignment (Attribution de Masse)

### 4.1 Définition

Le **Mass Assignment** (ou *auto-binding*) est une vulnérabilité survenant lorsqu'un **framework backend lie automatiquement** l'ensemble des paramètres reçus dans une requête HTTP aux **propriétés d'un objet interne ou d'un modèle en base de données**, **sans filtrage explicite** des champs réellement autorisés en écriture par le client.

### 4.2 Méthode d'identification

!!! tip "Comparer lecture et écriture"
    1. Récupérer la **représentation complète** d'un objet via un endpoint en lecture (`GET`), qui expose fréquemment **davantage de champs** que ceux attendus en modification (`id`, `role`, `isAdmin`, `balance`, `createdAt`...).
    2. Comparer cette liste exhaustive aux champs **effectivement envoyés** par le front-end lors d'une mise à jour (`PATCH`/`PUT`).
    3. **Injecter** méthodiquement chacun des champs présents en lecture mais absents en écriture, et observer si le serveur l'accepte silencieusement.

```json
// Réponse GET /api/v1/user/me — représentation complète de l'objet
{
  "id": 1001,
  "username": "alice",
  "email": "alice@example.com",
  "isAdmin": false,
  "accountBalance": 0
}
```

```json
// Corps PATCH légitime attendu par le front-end (sous-ensemble restreint)
{
  "username": "alice",
  "email": "alice@example.com"
}
```

### 4.3 Exploitation

```http
PATCH /api/v1/user/me HTTP/1.1
Host: cible.com
Authorization: Bearer <token_utilisateur_standard>
Content-Type: application/json
Content-Length: 70

{"username": "alice", "email": "alice@example.com", "isAdmin": true}
```

!!! danger "Un champ non requis, une élévation de privilèges complète"
    Si le champ `isAdmin`, présent dans la représentation en lecture mais **jamais destiné à être modifiable** par le client, est néanmoins **lié sans filtrage** par le framework à l'objet persisté, l'injection de `"isAdmin": true` dans une requête `PATCH`/`PUT` apparemment anodine suffit à obtenir une **élévation de privilèges persistante**, sans exploiter la moindre faille de contrôle d'accès au sens strict.

---

## 5. Server-Side Parameter Pollution (SSPP)

### 5.1 Définition

La **pollution de paramètres côté serveur** (*Server-Side Parameter Pollution* — SSPP) survient lorsqu'une **application intermédiaire** — typiquement une **passerelle d'API** (API gateway) — **injecte dynamiquement des données fournies par l'utilisateur** dans la construction d'une **requête interne** adressée à un **microservice backend**, **sans encodage ni validation suffisante** de ces données avant leur insertion.

!!! info "Le cœur du problème : une concaténation de confiance"
    La gateway fait implicitement confiance à la donnée utilisateur qu'elle relaie et la **concatène directement** dans l'URL, le chemin ou le corps de la requête interne, sans traiter cette donnée comme potentiellement **structurante** pour la syntaxe de cette requête interne — exactement le même principe de confiance mal placée qu'une injection SQL, appliqué ici à la construction de requêtes HTTP internes.

### 5.2 SSPP dans les Query Strings

**Troncature via le dièse URL-encodé (`%23`)**

```text
Requête externe reçue par la gateway :
GET /api/v1/profile?name=alice%23&internal_param=secret

Requête interne construite par la gateway (concaténation naïve) :
GET /internal/profile?user=alice#&internal_param=secret
```

!!! danger "Le `#` coupe net l'interprétation du reste de la requête"
    Une fois **décodé** par la gateway puis réinjecté dans la requête interne, le caractère `#` (introduisant un **fragment**) peut amener le composant interne consommant cette URL à **ignorer purement et simplement** tout ce qui suit — y compris des paramètres internes légitimes (`internal_param=secret`) que l'attaquant n'était jamais censé pouvoir influencer, sans même avoir besoin de les connaître à l'avance : leur simple **suppression effective** peut suffire à altérer le comportement attendu du microservice interne.

**Injection de nouveaux paramètres via l'esperluette URL-encodée (`%26`)**

```text
Requête externe reçue par la gateway :
GET /api/v1/profile?name=alice%26role=admin

Requête interne construite par la gateway (après décodage) :
GET /internal/profile?user=alice&role=admin
```

!!! danger "Injection d'un paramètre interne non prévu"
    Le décodage du `%26` en `&` **avant** la construction de la requête interne permet à l'attaquant d'**injecter un paramètre supplémentaire** (`role=admin`) directement dans la requête adressée au microservice, alors que ce paramètre n'était jamais censé provenir d'une entrée utilisateur — il s'agissait, du point de vue du microservice interne, d'un paramètre **exclusivement réservé** à un usage interne de la gateway.

**Surcharge de paramètres (*Parameter Overshadowing*)**

Lorsque l'attaquant parvient à injecter un **second paramètre de même nom** que celui déjà présent dans la requête interne construite par la gateway, le comportement résultant dépend **entièrement de la technologie backend** consommant la requête polluée :

| Backend | Comportement en cas de paramètre dupliqué |
|---|---|
| **PHP** | Conserve la **dernière** occurrence du paramètre |
| **ASP.NET** | **Combine** les valeurs dupliquées en une seule chaîne séparée par une virgule (`valeur1,valeur2`) |
| **Node.js / Express** | Conserve la **première** occurrence du paramètre (comportement par défaut selon le middleware de parsing utilisé) |

!!! warning "Un comportement non uniforme, donc exploitable de façon ciblée"
    Cette **divergence de traitement** entre technologies backend est précisément ce qui rend la surcharge de paramètres exploitable : un attaquant qui connaît (ou déduit, par test empirique) la pile technologique du microservice interne ciblé peut **positionner stratégiquement** son paramètre injecté — avant ou après le paramètre légitime — pour garantir que **sa propre valeur** soit celle effectivement retenue par le composant final, en toute connaissance de la règle de résolution appliquée.

```bash
# Exemple de test empirique de la règle de résolution du backend cible
curl "https://cible.com/api/v1/profile?name=legitime&name=injecte"
# Observer, via le comportement applicatif résultant, laquelle des deux valeurs a été retenue
```

### 5.3 SSPP dans les chemins REST

L'injection de **séquences de traversée de répertoire** (`../`) dans une valeur destinée à être concaténée au sein du **chemin** d'une requête interne permet de **remonter dans l'arborescence** des routes internes du microservice.

```text
Requête externe reçue par la gateway :
GET /api/v1/users/alice%2f..%2f..%2fadmin%2fdashboard

Requête interne construite par la gateway (après décodage) :
GET /internal/users/alice/../../admin/dashboard
→ résolue par le microservice interne en :
GET /internal/admin/dashboard
```

!!! danger "Atteindre une route interne jamais destinée à être exposée"
    Si le composant interne normalise le chemin reçu (résolution des `../`) **après** avoir reçu la requête de la gateway, cette dernière peut être amenée à relayer, sans le savoir, une requête vers une route **totalement différente** de celle initialement prévue — potentiellement un panneau d'administration ou une API de gestion jamais censée être atteignable depuis l'extérieur du réseau interne.

### 5.4 SSPP dans les formats structurés (JSON/XML)

Lorsque la gateway insère une valeur utilisateur **à l'intérieur** d'une structure JSON ou XML destinée au microservice interne, l'injection de **caractères de contrôle** propres à ces formats (guillemets, accolades, chevrons) peut **corrompre la structure** et permettre l'insertion de **clés non prévues**.

```text
Valeur utilisateur injectée dans le champ "name" :
alice", "role": "admin

Corps JSON interne résultant (concaténation naïve côté gateway) :
{"user": {"name": "alice", "role": "admin", "originalField": "..."}}
```

```xml
<!-- Équivalent XML : injection de balises structurantes -->
<!-- Valeur utilisateur : alice</name><role>admin</role><name> -->
<user>
  <name>alice</name><role>admin</role><name></name>
</user>
```

!!! danger "Une injection de structure, pas seulement de valeur"
    Dans les deux cas, l'attaquant ne se contente pas d'injecter une **valeur** dans un champ existant : il **brise la structure syntaxique** du document interne pour y insérer de **nouvelles clés ou balises entières**, directement interprétées par le microservice de destination comme des éléments légitimes de la requête — avec potentiellement le même impact qu'un Mass Assignment (section 4), mais orchestré depuis l'extérieur via la gateway elle-même.

### 5.5 Outils de détection

| Outil | Rôle |
|---|---|
| **Burp Scanner** | Détection automatisée de certains motifs de pollution de paramètres lors d'un scan actif ciblé |
| **Backslash Powered Scanner** (extension Burp) | Détection générique de points d'injection basée sur l'analyse différentielle de caractères spéciaux (guillemets, barres obliques, caractères d'échappement), particulièrement adaptée à la détection de SSPP dans des contextes où la charge utile finale n'est pas connue à l'avance |

!!! tip "Tester systématiquement l'ensemble des caractères structurants"
    Face à tout point d'entrée suspecté de transiter par une gateway avant d'atteindre un microservice interne, tester systématiquement l'injection de `#`, `&`, `../`, `"`, `{`, `}`, `<`, `>` — encodés une ou plusieurs fois — en observant les **effets de second ordre** sur le comportement applicatif final, la SSPP étant par nature une vulnérabilité dont l'exploitation se manifeste **en aval**, au niveau du microservice interne, et non directement dans la réponse immédiate de la gateway.

---

## 6. Sécurisation & Bonnes Pratiques de Protection des API

### 6.1 Principes directeurs

!!! danger "Ne jamais se fier au front-end"
    Appliquer rigoureusement le **principe du moindre privilège** et **valider l'intégralité des entrées** côté serveur, sur **chaque** endpoint et **chaque** méthode HTTP exposée. Le front-end ne constitue **jamais** un mécanisme de sécurité : toute restriction visible côté client doit être intégralement revalidée côté serveur.

### 6.2 Listes blanches strictes (allowlists)

| Axe | Mesure |
|---|---|
| **Méthodes HTTP** | N'autoriser, par endpoint, que les verbes strictement nécessaires ; rejeter explicitement les autres |
| **Types de contenu** | N'accepter qu'un `Content-Type` unique et attendu ; désactiver les parseurs alternatifs (XML notamment) si non requis |
| **Paramètres modifiables** | Définir la liste exhaustive et explicite des champs acceptés par opération d'écriture ; tout champ hors liste est ignoré ou rejeté |

### 6.3 Objets de transfert de données (DTO) et filtres stricts

!!! tip "Le DTO, barrière structurelle contre le Mass Assignment"
    Ne **jamais lier directement** le corps de requête entrant au modèle de données interne. Utiliser systématiquement un **objet de transfert de données (DTO)** n'exposant que les champs explicitement autorisés pour l'opération concernée, puis transposer manuellement les valeurs validées vers le modèle interne.

```python
class UserUpdateDTO:
    """Seuls ces champs sont acceptés en modification par le client."""
    username: str
    email: str
    # isAdmin, role, accountBalance : volontairement absents
```

### 6.4 Contre-mesures spécifiques à la SSPP

- **Encoder systématiquement** toute donnée utilisateur avant de la concaténer dans une requête interne (encodage d'URL complet pour les query strings, échappement structurel pour le JSON/XML).
- **Privilégier des requêtes internes construites par assemblage structuré** (bibliothèques de construction d'URL typées, sérialiseurs JSON/XML dédiés) plutôt que par **concaténation de chaînes brutes**.
- **Normaliser et valider le chemin** d'une requête interne **avant** toute résolution de séquences de traversée, au niveau de la gateway elle-même.
- **Documenter et tester explicitement** le comportement de résolution des paramètres dupliqués de chaque technologie backend interne, plutôt que de supposer un comportement uniforme à travers l'infrastructure.

### 6.5 Synthèse — checklist de remédiation

- [ ] Fichiers de spécification (`swagger.json`, `openapi.yaml`) **jamais exposés** en production sans authentification
- [ ] Chaque endpoint n'accepte que les **méthodes HTTP strictement nécessaires**
- [ ] `Content-Type` restreint à une liste blanche fermée ; parseurs alternatifs désactivés si non requis
- [ ] Chaque opération d'écriture repose sur un **DTO explicite**, jamais sur une liaison automatique brute
- [ ] Toute donnée utilisateur relayée par une **gateway** vers un microservice interne est **encodée et validée** avant concaténation
- [ ] Les requêtes internes sont construites par **assemblage structuré**, jamais par concaténation de chaînes brutes
- [ ] Le comportement de résolution des **paramètres dupliqués** est connu et testé pour chaque backend interne de l'infrastructure
- [ ] Campagnes de **Path Fuzzing**, **Param Mining** et de **tests SSPP** intégrées aux cycles d'audit réguliers

---

## 7. Références

- [OWASP API Security Top 10 (2023)](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [PortSwigger Research — Server-Side Parameter Pollution](https://portswigger.net/research/server-side-parameter-pollution)
- [PortSwigger Web Security Academy — API testing](https://portswigger.net/web-security/api-testing)
- [PortSwigger — Backslash Powered Scanner](https://portswigger.net/bappstore/3e879ebe660b4890ace5e766867dcd2a)
- [OWASP Mass Assignment Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html)
- [MITRE CWE-915 : Improperly Controlled Modification of Dynamically-Determined Object Attributes](https://cwe.mitre.org/data/definitions/915.html)
