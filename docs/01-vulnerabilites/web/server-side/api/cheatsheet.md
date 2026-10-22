# Sécurité & Audit des API — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre trois familles de techniques pour l'audit d'API RESTful/JSON :

- **Reconnaissance d'API** : découverte de documentation machine (Swagger/OpenAPI), surface d'attaque cachée (endpoints orphelins, méthodes HTTP alternatives, paramètres cachés).
- **Mass Assignment** : exploitation de l'auto-binding non filtré côté serveur.
- **Server-Side Parameter Pollution (SSPP)** : injection de données utilisateur dans une requête interne construite par une gateway/passerelle vers un microservice.

Pour l'exploitation approfondie du détournement de méthodes HTTP et des exemples de code applicatif Mass Assignment, voir la fiche *Pentesting & Audit : Sécurité des API RESTful*.

**Outils utilisés :** Burp Suite (Scanner, Discover Content, extensions Param Miner / OpenAPI Parser / Backslash Powered Scanner), `curl`, `ffuf`, `LinkFinder`, Postman, SoapUI.

**Conditions générales :** techniques applicables sur une API accessible (authentifiée ou non) en environnement de test autorisé. Les techniques SSPP supposent une architecture **gateway → microservice interne**.

**Conventions des exemples :**

| Placeholder | Signification |
|---|---|
| `cible.com` | Nom d'hôte fictif, à remplacer par la cible réelle autorisée |
| `<token>` / `Bearer <token_utilisateur_standard>` | Jeton d'authentification à obtenir dans le contexte testé, non réutilisable tel quel |
| `§candidat_param§` | Marqueur Burp Intruder, à remplacer par le nom de paramètre testé |
| `FUZZ` | Position de substitution `ffuf` |

Tous les chemins, noms de champs (`isAdmin`, `role`, `internal_param`...) et wordlists sont illustratifs et doivent être adaptés à l'application réellement auditée.

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Découvrir la doc machine | `curl` sur chemins connus (`/swagger.json`, `/openapi.yaml`...) | Début de toute reconnaissance d'API | Réponse 200 avec JSON/YAML structuré | Doc souvent absente ou protégée en prod |
| Trouver une doc non référencée | Base Path Investigation + fuzzing ciblé | Un endpoint connu existe mais pas de doc visible | Code 200/401/403 sur un chemin candidat | Faux positifs sur pages d'erreur 200 |
| Lister les méthodes actives | `OPTIONS` + en-tête `Allow` | Après identification d'un endpoint | En-tête `Allow` listant plusieurs verbes | L'en-tête peut être incomplet ou absent |
| Déclencher un autre parseur | Modifier `Content-Type` (JSON→XML) | Tester le support natif d'un parseur alternatif | Réponse traitée au lieu de rejetée (415) | Nécessite que le framework supporte XML nativement |
| Extraire des routes cachées | Grep / LinkFinder sur bundle JS | SPA avec logique côté client | Chemins `/api/...` non documentés | Bundle minifié parfois non lisible directement |
| Confirmer un paramètre caché | Param Miner / injection manuelle de champs candidats | Endpoint d'écriture avec champs suspectés | Différence de comportement selon présence du champ | Param Miner génère du bruit, à trier |
| Détecter un Mass Assignment | Comparer GET (lecture complète) vs PATCH (écriture restreinte) | Objet exposé en lecture avec champs sensibles | Champ non envoyé normalement, accepté silencieusement en écriture | Nécessite un compte avec accès en lecture à l'objet |
| Confirmer un SSPP via `#` | Injecter `%23` dans un paramètre relayé par une gateway | Architecture gateway → microservice suspectée | Troncature des paramètres internes suivants | Dépend de l'ordre de décodage/concaténation côté gateway |
| Confirmer un SSPP via `&` | Injecter `%26param=valeur` | Idem | Apparition d'un comportement lié à un paramètre jamais envoyé par le client | Nécessite de deviner ou déduire un nom de paramètre interne |
| Diagnostiquer une résolution de paramètre dupliqué | Envoyer deux fois le même nom de paramètre | Avant d'exploiter un SSPP par surcharge | Valeur retenue = 1ère, dernière, ou concaténée selon backend | Comportement propre à chaque techno backend |

Ce tableau sert d'index ; les sections 3 à 5 détaillent chaque technique.

---

## 3. Techniques classées par objectif

### 3.1 Détecter

#### Découverte de fichiers de spécification orphelins

**Objectif :** identifier une documentation machine (Swagger/OpenAPI) exposée sans authentification.

**Quand l'utiliser :** en tout début d'audit, avant tout test applicatif.

**Prérequis :** aucun.

**Syntaxe minimale :**

```bash
curl -s https://cible.com/swagger.json
curl -s https://cible.com/openapi.yaml
curl -s https://cible.com/api-docs/
curl -s https://cible.com/v2/api-docs
curl -s https://cible.com/v3/api-docs
```

**Éléments à personnaliser :** `cible.com` ; adapter la liste de chemins au framework suspecté (Swagger UI, SpringDoc, NestJS, etc.).

**Signal attendu :** réponse 200 avec un corps JSON/YAML structuré (clés `paths`, `definitions`/`components`, `info`).

**Interprétation :** une spécification exposée en production documente l'intégralité des endpoints, schémas et méthodes — y compris des routes jamais reliées au front-end. Cela réduit drastiquement l'effort de reconnaissance restant, mais ne constitue pas en soi une vulnérabilité d'accès si le fichier est volontairement public.

**Limites :** absente sur la majorité des API en production bien gérées ; peut nécessiter authentification.

**Source :** cours fourni, section 2.2.

#### Analyse régressive des chemins (Base Path Investigation)

**Objectif :** retrouver une documentation non référencée en remontant l'arborescence à partir d'un endpoint connu.

**Quand l'utiliser :** un endpoint API est connu mais aucune doc n'a été trouvée directement.

**Prérequis :** connaître au moins un endpoint fonctionnel.

**Syntaxe minimale :**

```bash
BASE_ENDPOINT="/api/v1/users/123"
CANDIDATS=("" "swagger" "swagger.json" "docs" "openapi.yaml" "api-docs" "redoc")

for c in "${CANDIDATS[@]}"; do
  echo "Test: /api/v1/$c"
  curl -s -o /dev/null -w "%{http_code}\n" "https://cible.com/api/v1/$c"
done
```

**Éléments à personnaliser :** `BASE_ENDPOINT`, liste `CANDIDATS`, hôte cible.

**Signal attendu :** code 200 (ou 401/403 révélant l'existence de la ressource) sur un chemin candidat.

**Interprétation :** un 401/403 confirme l'existence de la route sans donner accès — cible de contournement d'authentification à traiter séparément. Un 404 ne garantit pas l'absence si le serveur renvoie un 404 trompeur par défaut.

**Limites :** liste de candidats nécessairement incomplète ; comportement de 404 « custom » peut fausser l'interprétation.

**Source :** cours fourni, section 2.3.

#### Fuzzing de répertoires ciblé

**Objectif :** automatiser la recherche de documentation ou d'endpoints sur un espace de noms plus large.

**Quand l'utiliser :** après épuisement des chemins connus/candidats manuels.

**Prérequis :** wordlist adaptée à l'API testée.

**Syntaxe minimale :**

```bash
ffuf -u https://cible.com/FUZZ -w wordlist-api-docs.txt \
  -e .json,.yaml,.yml \
  -mc 200,401,403
```

**Éléments à personnaliser :** `cible.com`, `wordlist-api-docs.txt`, extensions `-e`, codes filtrés `-mc`.

**Signal attendu :** réponses 200/401/403 sur une entrée de la wordlist.

**Interprétation :** à combiner avec une revue manuelle — un fuzzing massif génère du bruit (faux positifs sur pages catch-all).

**Limites :** dépend entièrement de la qualité de la wordlist ; peut être bloqué par rate-limiting/WAF.

**Source :** cours fourni, section 2.3.

#### Test systématique des méthodes HTTP (`OPTIONS`)

**Objectif :** révéler des méthodes HTTP actives mais non exploitées par le front-end.

**Quand l'utiliser :** sur chaque endpoint identifié.

**Prérequis :** endpoint accessible (authentifié ou non selon le contexte).

**Syntaxe minimale :**

```http
OPTIONS /api/v1/users/123 HTTP/1.1
Host: cible.com
```

Réponse typique :

```http
HTTP/1.1 200 OK
Allow: GET, POST, PUT, DELETE, PATCH, OPTIONS
```

**Éléments à personnaliser :** chemin de l'endpoint.

**Signal attendu :** en-tête `Allow` listant des verbes au-delà de ceux observés côté front-end (`PUT`, `DELETE`, `PATCH`).

**Interprétation :** chaque méthode listée doit être testée individuellement avec le contexte d'autorisation disponible — l'en-tête confirme la présence du verbe, pas son exploitabilité.

**Limites :** certains serveurs ne reflètent pas fidèlement les méthodes réellement routées ; l'en-tête peut être absent ou générique.

**Source :** cours fourni, section 2.4.

#### Manipulation `Content-Type` / `Accept`

**Objectif :** forcer un changement de parseur côté serveur (contournement de filtre, déclenchement d'une faille de parsing).

**Quand l'utiliser :** endpoint acceptant visiblement un seul format (JSON) côté front-end.

**Prérequis :** endpoint d'écriture ou d'import de données.

**Syntaxe minimale :**

```http
POST /api/v1/orders HTTP/1.1
Host: cible.com
Content-Type: application/xml
Accept: application/json

<?xml version="1.0"?>
<order><productId>42</productId></order>
```

**Éléments à personnaliser :** chemin, structure XML selon le schéma JSON d'origine.

**Signal attendu :** le serveur traite la requête (ne renvoie pas 415) au lieu de la rejeter.

**Interprétation :** la prise en charge native d'un second parseur, souvent présente dans le framework même sans usage prévu, ouvre la voie à des tests spécifiques à ce format (voir variante XXE ci-dessous).

**Limites :** ne constitue pas en soi une preuve d'impact ; nécessite un test de suivi (ex. XXE) pour établir un risque réel.

**Source :** cours fourni, section 2.4 et 3.2.

#### Test de robustesse des types de données

**Objectif :** identifier un traitement non filtré du typage d'un champ (confusion de type, bypass de validation).

**Quand l'utiliser :** sur tout champ JSON accepté en écriture.

**Prérequis :** connaître le nom et le type attendu du champ.

**Syntaxe minimale :**

```json
{"quantity": "1"}
{"quantity": [1, 2]}
{"quantity": true}
{"quantity": {"value": 1}}
{"quantity": null}
```

**Éléments à personnaliser :** nom du champ (`quantity`), valeurs selon le contexte métier.

**Signal attendu :** réponse 200 inattendue, erreur serveur (500) au lieu d'une erreur de validation (400), ou comportement applicatif divergent selon le type soumis.

**Interprétation :** une erreur 500 au lieu d'un 400 indique une validation absente ou mal gérée — à documenter, sans conclure d'emblée à une faille exploitable.

**Limites :** signal souvent faible isolément ; à corréler avec le comportement applicatif observé.

**Source :** cours fourni, section 2.4.

#### Extraction de routes depuis des bundles JavaScript

**Objectif :** révéler des endpoints référencés côté client mais non visibles dans le parcours utilisateur.

**Quand l'utiliser :** application de type SPA.

**Prérequis :** accès aux fichiers JS statiques servis par l'application.

**Syntaxe minimale :**

```bash
curl -s https://cible.com/static/js/main.a1b2c3.js | grep -oE '"/api/[a-zA-Z0-9/_-]+"'

# Extraction automatisée (LinkFinder)
python3 linkfinder.py -i https://cible.com/static/js/main.a1b2c3.js -o cli
```

**Éléments à personnaliser :** chemin du bundle JS.

**Signal attendu :** chaînes de chemins `/api/...`, en particulier contenant `admin`, `internal`, `debug`, `_private`, `legacy`, `v0`.

**Interprétation :** ces fragments trahissent souvent des routes internes ou d'administration jamais destinées à un usage public — à vérifier individuellement.

**Limites :** inefficace sur du code fortement obfusqué ou chargé dynamiquement depuis une API externe (non présent dans le bundle statique).

**Source :** cours fourni, section 3.1.

#### Fuzzing de chemins (Path Fuzzing)

**Objectif :** découvrir des endpoints non documentés par force brute sur les segments de chemin.

**Quand l'utiliser :** après recon passive, pour compléter la cartographie.

**Prérequis :** wordlist de noms d'endpoints API ; token si les routes sont authentifiées.

**Syntaxe minimale :**

```bash
ffuf -u https://cible.com/api/v1/FUZZ -w api-endpoints-wordlist.txt \
  -H "Authorization: Bearer <token>" \
  -mc 200,401,404
```

**Éléments à personnaliser :** hôte, wordlist, token.

**Signal attendu :**

| Code observé | Signification |
|---|---|
| `200` | Route existante et accessible avec le contexte fourni |
| `401` | Route existante nécessitant authentification — cible de contournement prioritaire |
| `404` | Route probablement inexistante (sous réserve d'un comportement volontairement trompeur) |

**Interprétation :** un 401 est souvent plus intéressant qu'un 200 car il révèle une route protégée à cibler pour un bypass d'autorisation.

**Limites :** faux négatifs si le serveur renvoie systématiquement 404 pour masquer l'existence des routes.

**Source :** cours fourni, section 3.3.

#### Recherche de paramètres cachés (Param Mining)

**Objectif :** révéler des paramètres consommés côté serveur mais absents de toute documentation.

**Quand l'utiliser :** sur un endpoint d'écriture avant de chercher un Mass Assignment.

**Prérequis :** endpoint acceptant un corps JSON modifiable.

**Syntaxe minimale :**

```text
POST /api/v1/user/update HTTP/1.1
Host: cible.com
Content-Type: application/json

{"§candidat_param§": "valeur_test"}
```

**Éléments à personnaliser :** `§candidat_param§` (position Burp Intruder/Param Miner), `valeur_test`.

**Signal attendu :** variation de comportement applicatif (code, taille de réponse, contenu) selon le nom de paramètre injecté.

**Interprétation :** une variation de comportement indique qu'un paramètre est réellement consommé côté serveur, même sans effet visible immédiat — point d'entrée direct vers un Mass Assignment.

**Limites :** génère beaucoup de bruit sur de grandes listes ; nécessite un tri manuel des résultats.

**Source :** cours fourni, section 3.4.

---

### 3.2 Confirmer et exploiter — Mass Assignment

#### Identification par comparaison lecture/écriture

**Objectif :** établir qu'un champ sensible exposé en lecture est également modifiable en écriture sans y être destiné.

**Quand l'utiliser :** tout endpoint `PATCH`/`PUT` sur une ressource dont un `GET` correspondant existe.

**Prérequis :** accès en lecture à l'objet complet (`GET`).

**Méthode :**

1. Récupérer la représentation complète via `GET` (champs `id`, `role`, `isAdmin`, `balance`, `createdAt`...).
2. Comparer aux champs effectivement envoyés par le front-end en `PATCH`/`PUT`.
3. Injecter méthodiquement chaque champ présent en lecture mais absent en écriture.

```json
// Réponse GET /api/v1/user/me — représentation complète
{
  "id": 1001,
  "username": "alice",
  "email": "alice@example.com",
  "isAdmin": false,
  "accountBalance": 0
}
```

```json
// Corps PATCH légitime observé côté front-end
{
  "username": "alice",
  "email": "alice@example.com"
}
```

**Signal attendu :** le serveur accepte silencieusement (200/204) un champ non prévu.

**Interprétation :** l'acceptation silencieuse indique un binding non filtré, mais ne prouve l'impact qu'après relecture de l'objet pour confirmer la persistance du champ modifié (étape de preuve, voir ci-dessous).

**Limites :** certains frameworks acceptent le champ en apparence (200) sans le persister réellement — toujours relire l'objet après modification.

**Source :** cours fourni, section 4.2.

#### Exploitation — injection d'un champ privilégié

**Objectif :** démontrer une élévation de privilèges via un champ non filtré.

**Quand l'utiliser :** une fois le champ candidat identifié (étape précédente).

**Prérequis :** jeton d'un compte à privilèges standards ; nom du champ cible confirmé.

**Syntaxe minimale :**

```http
PATCH /api/v1/user/me HTTP/1.1
Host: cible.com
Authorization: Bearer <token_utilisateur_standard>
Content-Type: application/json
Content-Length: 70

{"username": "alice", "email": "alice@example.com", "isAdmin": true}
```

**Éléments à personnaliser :** chemin de l'endpoint, token, champs légitimes du compte, nom du champ sensible (`isAdmin`, `role`, `accountBalance`...).

**Signal attendu :** réponse de succès (200/204) **et** confirmation par relecture (`GET`) que le champ a bien été persisté.

**Interprétation :** la preuve d'impact est la relecture confirmant la persistance (ex. `isAdmin: true` effectivement enregistré), pas seulement le code de statut de la requête `PATCH`. Il s'agit alors d'une élévation de privilèges persistante, sans exploitation d'une faille de contrôle d'accès au sens strict.

**Limites :** un champ accepté peut être silencieusement ignoré par une couche de validation ultérieure (ex. trigger base de données) — vérifier systématiquement l'effet réel.

**Source :** cours fourni, section 4.3.

---

### 3.3 Confirmer et exploiter — Server-Side Parameter Pollution (SSPP)

> **Prérequis général SSPP :** architecture avec une gateway/passerelle relayant des requêtes vers un ou plusieurs microservices internes, construisant la requête interne par **concaténation** de données utilisateur non encodées.

#### Troncature via le dièse URL-encodé (`%23`)

**Objectif :** supprimer des paramètres internes légitimes situés après le paramètre injecté.

**Quand l'utiliser :** architecture gateway suspectée, paramètre utilisateur visiblement relayé vers un service interne.

**Prérequis :** connaître (ou deviner) qu'un paramètre interne suit le paramètre contrôlé par l'utilisateur dans la requête reconstruite.

**Syntaxe minimale :**

```text
Requête externe envoyée :
GET /api/v1/profile?name=alice%23&internal_param=secret

Requête interne résultante (après décodage par la gateway) :
GET /internal/profile?user=alice#&internal_param=secret
```

**Éléments à personnaliser :** nom du paramètre externe (`name`), valeur injectée (`alice%23`).

**Signal attendu :** comportement applicatif identique à une requête où `internal_param` serait absent (effet observable indirectement, en aval, côté microservice).

**Interprétation :** confirme que le `#` décodé est réinjecté tel quel dans la requête interne et que le composant qui la consomme interprète tout ce qui suit comme un fragment ignoré. Ne prouve pas à lui seul un impact exploitable — seulement la pollution.

**Limites :** effet non visible dans la réponse immédiate de la gateway ; nécessite une hypothèse sur ce que `internal_param` contrôle pour en déduire un impact.

**Source :** cours fourni, section 5.2.

#### Injection de nouveaux paramètres via l'esperluette URL-encodée (`%26`)

**Objectif :** injecter un paramètre supplémentaire dans la requête interne.

**Quand l'utiliser :** idem, lorsque la gateway concatène la valeur utilisateur sans encodage avant transmission interne.

**Prérequis :** deviner ou déduire le nom d'un paramètre interne exploitable (ex. `role`).

**Syntaxe minimale :**

```text
Requête externe envoyée :
GET /api/v1/profile?name=alice%26role=admin

Requête interne résultante (après décodage) :
GET /internal/profile?user=alice&role=admin
```

**Éléments à personnaliser :** `name`, le paramètre injecté (`role=admin`) selon l'hypothèse testée.

**Signal attendu :** effet applicatif correspondant à la prise en compte du paramètre injecté (ex. élévation de privilèges, changement de réponse).

**Interprétation :** confirme l'injection d'un paramètre jamais censé provenir d'une entrée utilisateur ; l'impact dépend entièrement de ce que fait le microservice interne de ce paramètre.

**Limites :** suppose de connaître ou deviner un nom de paramètre interne pertinent — approche à combiner avec du fuzzing de noms si inconnu.

**Source :** cours fourni, section 5.2.

#### Surcharge de paramètres (Parameter Overshadowing)

**Objectif :** faire prévaloir une valeur injectée sur la valeur légitime d'un paramètre déjà présent, en exploitant la règle de résolution des doublons du backend.

**Quand l'utiliser :** après confirmation qu'un paramètre interne de même nom existe déjà (via injection `%26`).

**Prérequis :** connaître le comportement du backend interne face à un paramètre dupliqué.

**Comportements connus par backend :**

| Backend | Comportement en cas de paramètre dupliqué |
|---|---|
| **PHP** | Conserve la **dernière** occurrence |
| **ASP.NET** | **Combine** les valeurs (`valeur1,valeur2`) |
| **Node.js / Express** | Conserve la **première** occurrence (selon middleware de parsing) |

**Syntaxe minimale (test empirique) :**

```bash
curl "https://cible.com/api/v1/profile?name=legitime&name=injecte"
# Observer, via le comportement applicatif résultant, laquelle des deux valeurs a été retenue
```

**Éléments à personnaliser :** `name`, valeurs `legitime` / `injecte`.

**Signal attendu :** le comportement applicatif reflète l'une des deux valeurs — à identifier laquelle.

**Interprétation :** une fois la règle de résolution connue, positionner stratégiquement le paramètre injecté (avant ou après) pour garantir que la valeur attaquant soit retenue par le composant final.

**Limites :** règle non uniforme entre technologies ; un test empirique sur la cible réelle reste nécessaire, aucune règle ne doit être supposée sans vérification.

**Source :** cours fourni, section 5.2.

#### SSPP dans les chemins REST (path traversal via la gateway)

**Objectif :** atteindre une route interne non destinée à être exposée en remontant l'arborescence des chemins internes.

**Quand l'utiliser :** un segment de chemin externe est visiblement repris dans la construction du chemin interne.

**Prérequis :** la gateway concatène le segment utilisateur dans le chemin interne sans normalisation préalable.

**Syntaxe minimale :**

```text
Requête externe reçue :
GET /api/v1/users/alice%2f..%2f..%2fadmin%2fdashboard

Requête interne construite (après décodage) :
GET /internal/users/alice/../../admin/dashboard
→ résolue en :
GET /internal/admin/dashboard
```

**Éléments à personnaliser :** segment `alice`, profondeur de traversée (`../`) selon l'arborescence interne visée.

**Signal attendu :** réponse correspondant à une route différente de celle initialement ciblée (ex. contenu d'un panneau d'administration).

**Interprétation :** confirme que le composant interne normalise le chemin **après** réception par la gateway, permettant d'atteindre une route jamais censée être accessible depuis l'extérieur.

**Limites :** nécessite de connaître ou deviner la structure des routes internes cibles ; sans connaissance de l'arborescence, l'exploitation reste exploratoire.

**Source :** cours fourni, section 5.3.

#### SSPP dans les formats structurés (JSON/XML)

**Objectif :** corrompre la structure d'un document interne pour y insérer des clés/balises non prévues.

**Quand l'utiliser :** une valeur utilisateur est insérée par la gateway à l'intérieur d'une structure JSON ou XML destinée au microservice.

**Prérequis :** concaténation naïve côté gateway (pas de sérialiseur structuré).

**Syntaxe minimale :**

```text
Valeur utilisateur injectée dans le champ "name" :
alice", "role": "admin

Corps JSON interne résultant :
{"user": {"name": "alice", "role": "admin", "originalField": "..."}}
```

```xml
<!-- Valeur utilisateur : alice</name><role>admin</role><name> -->
<user>
  <name>alice</name><role>admin</role><name></name>
</user>
```

**Éléments à personnaliser :** champ ciblé (`name`), clé/balise injectée (`role`).

**Signal attendu :** effet applicatif correspondant à la prise en compte de la clé/balise injectée par le microservice interne.

**Interprétation :** il ne s'agit pas d'une simple injection de valeur mais d'une injection de **structure** — avec un impact potentiellement équivalent à un Mass Assignment (section 3.2), mais orchestré depuis l'extérieur via la gateway.

**Limites :** dépend fortement de la façon dont la gateway sérialise la requête interne ; inefficace si un sérialiseur JSON/XML typé est utilisé en interne.

**Source :** cours fourni, section 5.4.

---

## 4. Payloads et syntaxes représentatifs

| Intention | Payload de référence | Contexte d'insertion | Variante utile | Différence apportée |
|---|---|---|---|---|
| Troncature de paramètres internes | `%23` (soit `#`) en fin de valeur | Paramètre de query string relayé par une gateway | — | Un seul payload suffit : effet binaire (coupe ou non) |
| Injection de paramètre interne | `%26nom_param=valeur` | Fin de la valeur d'un paramètre de query string | Varier `nom_param` selon l'hypothèse testée (`role`, `admin`, `internal_param`) | Chaque variante teste une hypothèse différente, pas une syntaxe différente |
| Surcharge de paramètre | Paramètre dupliqué, position avant/après | Query string | Inverser l'ordre des deux occurrences | Teste la règle de résolution du backend (premier/dernier/combiné) |
| Traversée de chemin interne | `..%2f` répété selon la profondeur | Segment de chemin REST | Ajuster le nombre de `../` à la profondeur réelle de l'arborescence interne | Nombre de répétitions dépend uniquement de la structure cible, pas de la technique elle-même |
| Corruption de structure JSON | `", "cle": "valeur` | Valeur d'un champ JSON inséré par la gateway | — | Un seul payload de référence ; adapter uniquement `cle`/`valeur` |
| Corruption de structure XML | `</balise><cle>valeur</cle><balise>` | Valeur d'un champ XML inséré par la gateway | — | Équivalent structurel du payload JSON, adapté à la syntaxe XML |
| Élévation de privilèges Mass Assignment | `"isAdmin": true` ajouté au corps JSON légitime | Corps d'une requête `PATCH`/`PUT` | Remplacer par tout champ sensible identifié en lecture (`role`, `accountBalance`) | Le nom du champ dépend entièrement du modèle de données de la cible |
| Déclenchement XXE via bascule de parseur | `<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><data>&xxe;</data>` | Corps de requête avec `Content-Type: application/xml` | Voir fiche dédiée *XXE* / *SSRF* pour les variantes d'entités | Payload de détection minimal ; l'exploitation complète XXE sort du périmètre de cette fiche |

Aucune variante supplémentaire n'est ajoutée lorsque le document source n'en fournit pas de justification technique distincte.

---

## 5. Encodages, formats et représentation des entrées

| Représentation d'origine | Représentation transformée | Contexte pertinent | Composant décodant/normalisant | Effet attendu |
|---|---|---|---|---|
| `#` | `%23` | Query string relayée par une gateway | Gateway (décodage URL avant concaténation) | Le `#` décodé introduit un fragment, tronquant l'interprétation du reste de l'URL interne |
| `&` | `%26` | Query string relayée par une gateway | Gateway | Le `&` décodé introduit un nouveau paramètre dans la requête interne |
| `/` | `%2f` | Segment de chemin REST relayé par une gateway | Gateway, puis microservice interne (résolution `../`) | Permet d'insérer un séparateur de chemin interprété après transmission à travers la gateway |
| `"`, `{`, `}` | identiques (non encodés) ou échappés selon contexte | Valeur insérée dans un corps JSON par la gateway | Parseur JSON du microservice interne | Corruption de la structure JSON, insertion de clés non prévues |
| `<`, `>` | identiques ou entités XML selon contexte | Valeur insérée dans un corps XML par la gateway | Parseur XML du microservice interne | Corruption de la structure XML, insertion de balises non prévues |

**Condition d'inefficacité :** si la gateway utilise un **assemblage structuré** (bibliothèque d'URL typée, sérialiseur JSON/XML dédié) plutôt qu'une concaténation de chaînes brutes, aucun de ces encodages n'a d'effet — l'hypothèse de concaténation naïve doit être vérifiée avant de multiplier les tests d'encodage.

---

## 6. Exemples de requêtes HTTP

### 6.1 Détection d'un parseur XML alternatif

```http
POST /api/v1/import HTTP/1.1
Host: cible.com
Content-Type: application/xml

<?xml version="1.0"?>
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<data>&xxe;</data>
```

- **Changement clé :** `Content-Type` forcé à `application/xml` sur un endpoint normalement JSON.
- **Pourquoi important :** révèle un support natif XML non sollicité en conditions normales.
- **Prérequis :** endpoint acceptant un corps structuré en entrée.
- **Signal recherché :** réponse traitée (pas de 415) ; contenu de `/etc/passwd` reflété dans la réponse = preuve XXE.
- **Ce que cela ne prouve pas seul :** un simple 200 sans contenu de fichier ne prouve que la bascule de parseur, pas l'exploitabilité XXE (voir fiche dédiée *XXE*).

### 6.2 Exploitation Mass Assignment

```http
# Référence — requête légitime observée côté front-end
PATCH /api/v1/user/me HTTP/1.1
Host: cible.com
Authorization: Bearer <token_utilisateur_standard>
Content-Type: application/json

{"username": "alice", "email": "alice@example.com"}
```

```http
# Version modifiée — champ privilégié ajouté
PATCH /api/v1/user/me HTTP/1.1
Host: cible.com
Authorization: Bearer <token_utilisateur_standard>
Content-Type: application/json
Content-Length: 70

{"username": "alice", "email": "alice@example.com", "isAdmin": true}
```

- **Changement clé :** ajout de `"isAdmin": true`.
- **Pourquoi important :** teste le filtrage des champs modifiables par le framework.
- **Prérequis :** connaître un champ sensible exposé en lecture (`GET`) mais absent du corps légitime.
- **Signal recherché :** réponse de succès **et** persistance confirmée par relecture (`GET`) de l'objet.
- **Ce que cela ne prouve pas seul :** un 200 sur le `PATCH` seul ne garantit pas la persistance réelle du champ — toujours relire l'objet.

### 6.3 SSPP — injection de paramètre via query string

```http
# Référence
GET /api/v1/profile?name=alice HTTP/1.1
Host: cible.com
```

```http
# Version modifiée
GET /api/v1/profile?name=alice%26role=admin HTTP/1.1
Host: cible.com
```

- **Changement clé :** `%26role=admin` ajouté à la valeur du paramètre `name`.
- **Pourquoi important :** teste si la gateway décode et réinjecte la valeur sans validation avant de construire la requête interne.
- **Prérequis :** architecture gateway → microservice interne ; concaténation naïve supposée.
- **Signal recherché :** effet applicatif correspondant à la prise en compte de `role=admin` côté microservice.
- **Ce que cela ne prouve pas seul :** confirme la pollution, pas nécessairement un impact exploitable — dépend de ce que fait le microservice du paramètre injecté.

> Les jetons, cookies et valeurs de session utilisés dans ces exemples doivent être obtenus dans le contexte testé ; ils ne sont jamais réutilisables tels quels d'un environnement à l'autre.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| `curl` | Requêtes HTTP ponctuelles | Vérification rapide d'un endpoint ou d'une doc exposée | `curl -s https://cible.com/swagger.json` | Ne gère pas le fuzzing à grande échelle |
| `ffuf` | Fuzzing de répertoires/chemins | Découverte de doc ou d'endpoints non référencés | `ffuf -u https://cible.com/FUZZ -w liste.txt -mc 200,401,403` | Dépend entièrement de la wordlist fournie |
| `LinkFinder` | Extraction de routes depuis du JS | SPA avec logique métier côté client | `python3 linkfinder.py -i https://cible.com/main.js -o cli` | Inefficace sur JS fortement obfusqué |
| **Burp Scanner** | Scan actif, import OpenAPI natif | Après récupération d'une spec OpenAPI/Swagger | Import de la spec → scan actif | Génère des faux positifs à trier manuellement |
| **Burp — Discover Content** | Crawling/découverte de contenu lié | Recherche manuelle de liens vers de la documentation | Lancer depuis le Site Map Burp | Nécessite un crawl préalable de l'application |
| **Param Miner** (extension Burp) | Détection de paramètres GET/POST/en-têtes non documentés | Avant d'investiguer un Mass Assignment | Exécution via le menu contextuel Burp sur une requête | Produit un volume important de résultats à valider |
| **Backslash Powered Scanner** (extension Burp) | Détection générique de points d'injection par analyse différentielle | Suspicion de SSPP sans charge utile finale connue | Scan actif ciblé sur un point d'entrée transitant par une gateway | Détection indicative, à confirmer manuellement |
| **OpenAPI Parser** (extension Burp) | Peuplement automatique du Site Map depuis une spec OpenAPI | Après récupération d'un `swagger.json`/`openapi.yaml` | Import de la spec dans l'extension | Dépend de la validité/complétude de la spec importée |
| Postman | Import de collection, environnements réutilisables | Travail itératif sur une API déjà documentée | Import direct du fichier OpenAPI | Moins adapté à un fuzzing massif que Burp/ffuf |
| SoapUI | Génération de suites de tests fonctionnels/sécurité | API avec contrat fortement structuré (SOAP/REST) | Import WSDL/OpenAPI puis génération de suite | Plus pertinent pour SOAP que pour REST pur |

Toutes les commandes ci-dessus sont illustratives et doivent être validées dans l'environnement cible réel (version d'outil, configuration, accessibilité réseau).

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Fichier `swagger.json`/`openapi.yaml` accessible sans auth | Fuite de documentation complète de l'API | Confirmer que les routes documentées sont bien actives | Que toutes les routes documentées sont exploitables sans test individuel |
| En-tête `Allow` listant plusieurs verbes | Méthodes HTTP actives au-delà de celles utilisées par le front-end | Tester chaque méthode individuellement avec le contexte d'autorisation | Qu'une méthode listée est automatiquement exploitable |
| Réponse 200 sur un `Content-Type` alternatif (XML) | Support natif d'un second parseur | Tenter un test XXE minimal pour évaluer l'impact | Qu'un changement de parseur constitue déjà une vulnérabilité |
| Champ non envoyé normalement accepté silencieusement en écriture | Candidat Mass Assignment | Relire l'objet (`GET`) pour confirmer la persistance | Qu'un 200 sur le `PATCH` seul prouve l'impact |
| Disparition d'un paramètre interne après injection `%23` | SSPP par troncature probable | Observer un effet applicatif en aval (comportement du microservice) | Qu'une absence d'erreur confirme à elle seule la vulnérabilité |
| Comportement applicatif changeant selon l'ordre d'un paramètre dupliqué | Règle de résolution du backend identifiable (SSPP overshadowing) | Reproduire le test en inversant l'ordre pour confirmer la règle | Qu'une seule observation suffit à généraliser la règle à tout endpoint |
| Contenu de fichier local reflété après bascule `Content-Type: application/xml` | XXE confirmée | Vérifier reproductibilité et portée (fichiers accessibles) | Qu'un simple 200 sans contenu reflété constitue une preuve XXE |

**Contrôle comparatif recommandé :** toujours envoyer la requête de référence (comportement normal) puis la requête modifiée, et comparer explicitement les deux résultats avant de conclure.

---

## 9. Variantes de syntaxe et adaptation

#### Adapter le positionnement d'un paramètre dupliqué (SSPP overshadowing)

**Problème précis :** la valeur injectée n'est pas retenue par le composant interne.

**Pourquoi pertinent :** la règle de résolution des paramètres dupliqués diffère selon le backend (PHP : dernier ; ASP.NET : combiné ; Node/Express : premier, selon middleware).

**Ce qui change :** uniquement l'ordre des deux occurrences du paramètre (`?name=legitime&name=injecte` vs `?name=injecte&name=legitime`).

**Nouveau signal attendu :** la valeur injectée devient celle effectivement prise en compte par l'application.

**Ce qu'il faut conserver identique :** le nom du paramètre et sa valeur injectée — seule la position change, pour isoler l'effet de l'ordre.

#### Adapter la profondeur de traversée (SSPP dans les chemins)

**Problème précis :** la séquence `../` ne permet pas d'atteindre la route interne visée.

**Pourquoi pertinent :** la profondeur nécessaire dépend de l'arborescence interne réelle du microservice, inconnue a priori.

**Ce qui change :** uniquement le nombre de répétitions de `..%2f`.

**Nouveau signal attendu :** atteinte d'une route interne différente (ex. contenu d'un panneau d'administration).

**Ce qu'il faut conserver identique :** l'encodage (`%2f`) et le segment de base — ne pas modifier plusieurs éléments à la fois.

> **Règle importante :** ne jamais changer plusieurs variables à la fois (encodage, position, profondeur, nom de paramètre). Chaque test doit isoler une seule hypothèse pour rester interprétable.

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Aucun changement observable après injection `%23`/`%26` | Gateway utilise un assemblage structuré, pas de concaténation brute | Tester un effet de second ordre (comportement en aval, pas la réponse immédiate) | Chercher un autre point d'entrée transitant par la gateway | Que ce point d'entrée précis n'est probablement pas vulnérable au SSPP par concaténation |
| `415 Unsupported Media Type` sur bascule `Content-Type` | Le framework n'implémente pas de parseur alternatif, ou le rejette explicitement | Vérifier la stack technique (framework, version) | Abandonner cette piste pour cet endpoint | Que ce parseur alternatif n'est pas supporté ici, pas que l'endpoint est sécurisé globalement |
| Champ Mass Assignment accepté (200) mais non persisté | Validation ou filtrage appliqué après le binding initial (ex. couche DTO partielle) | Relire systématiquement l'objet via `GET` | Tester d'autres noms de champs sensibles | Qu'un 200 isolé ne suffit jamais comme preuve — seule la relecture fait foi |
| Résultat SSPP non reproductible | Comportement dépendant du cache, de l'équilibrage de charge entre instances, ou de conditions de concurrence | Répéter le test plusieurs fois, isoler une seule variable à chaque essai | Espacer les requêtes, vérifier la cohérence de l'instance backend sollicitée | Que l'instabilité ne permet pas encore de conclure, ni dans un sens ni dans l'autre |
| Syntaxe de paramètre dupliqué ignorée par le serveur | Middleware de parsing rejetant ou fusionnant silencieusement les doublons selon une règle non documentée | Tester explicitement la règle de résolution (section 3.3, surcharge de paramètres) | Adapter l'ordre une fois la règle connue | Uniquement la règle de résolution du backend testé — ne pas généraliser à d'autres environnements |

---

## 11. Checklist d'utilisation

- [ ] L'objectif du test est clairement identifié (recon, Mass Assignment ou SSPP).
- [ ] Les prérequis de la technique sont réunis (ex. architecture gateway confirmée pour un SSPP).
- [ ] Le bon emplacement de la syntaxe est identifié (query string, chemin, corps JSON/XML).
- [ ] Les valeurs propres à l'application (hôte, token, noms de champs) ont été adaptées.
- [ ] Un exemple minimal a été privilégié avant d'ajouter des variantes.
- [ ] Le signal attendu est défini avant l'envoi du test.
- [ ] Les résultats sont comparés à une requête de référence.
- [ ] Une observation ambiguë (ex. 200 sans relecture) n'est pas présentée comme une preuve définitive.
- [ ] Une seule variable est modifiée à la fois lors des essais SSPP.
- [ ] Les résultats importants (Mass Assignment, SSPP confirmé) sont reproduits avant d'être documentés comme findings.

---

## 12. Sources et liens de référence

- [OWASP API Security Top 10 (2023)](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [PortSwigger Research — Server-Side Parameter Pollution](https://portswigger.net/research/server-side-parameter-pollution)
- [PortSwigger Web Security Academy — API testing](https://portswigger.net/web-security/api-testing)
- [PortSwigger — Backslash Powered Scanner](https://portswigger.net/bappstore/3e879ebe660b4890ace5e766867dcd2a)
- [OWASP Mass Assignment Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html)
- [MITRE CWE-915 : Improperly Controlled Modification of Dynamically-Determined Object Attributes](https://cwe.mitre.org/data/definitions/915.html)
