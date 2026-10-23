# Information Disclosure — Cheat sheet

## 1. Périmètre et conventions

Cette fiche couvre la **divulgation d'informations** (*Information Disclosure*), c'est-à-dire la révélation non intentionnelle de données sensibles (secrets, code source, détails techniques, données utilisateurs) suite à :

- un **nettoyage incomplet** avant mise en production (commentaires, fichiers de sauvegarde/édition, dossier `.git`/`.svn`) ;
- une **mauvaise configuration serveur** (mode debug actif, bannières de version, listing de répertoires, méthode `TRACE`, endpoints de diagnostic) ;
- un **comportement applicatif défectueux** servant d'oracle d'inférence (différences de réponse selon l'existence d'une donnée, accès non contrôlé à des pages de compte tiers).

Cette fiche ne couvre pas : l'exploitation complète d'un IDOR au-delà de sa détection comme source de divulgation ; l'exploitation d'une CVE identifiée grâce à une version de framework divulguée (méthodologie propre à chaque CVE) ; les techniques avancées d'extraction de secrets depuis un historique Git récupéré au-delà de `git log`/`git show`/`git diff`. La démarche complète (couverture systématique des surfaces, arbre de décision, évaluation de chaînabilité) relève de la fiche de méthodologie dédiée, pas de cette cheat sheet.

**Outils cités :** Burp Suite (Search, Find Comments, Discover Content, Intruder, Repeater, Logger++), `curl`, `git-dumper`, Nuclei, Nikto, Autorize.

**Conventions utilisées :**

| Valeur fictive | Signification |
|---|---|
| `cible.example` | Nom d'hôte fictif — remplacer par la cible réellement autorisée |
| `index.php`, `index.php.bak` | Fichier d'entrée illustratif et sa variante de sauvegarde — adapter aux fichiers réels de l'application |
| `wiener` / `carlos` | Identifiants illustratifs pour un test IDOR sur page de compte |
| `<commit>`, `<commit_a>`, `<commit_b>` | Références de commit à remplacer par celles réellement trouvées dans l'historique Git récupéré |

Un résultat positif à l'une de ces techniques (code `200`, contenu inhabituel) doit toujours être évalué selon sa **chaînabilité** avec d'autres éléments déjà identifiés avant de conclure à son impact réel — voir section 8.

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Repérer des chemins non protégés | Lecture de `robots.txt`/`sitemap.xml` | Tout début d'audit | Chemins listés dans `Disallow` | `Disallow` n'est jamais une protection — révèle l'existence, pas l'accessibilité |
| Trouver des indices laissés par les développeurs | Recherche de commentaires (`Find Comments`) et de motifs sensibles (`Search`) | Sur l'ensemble du trafic proxifié, HTML/JS/CSS inclus | Commentaires contenant identifiants, chemins, notes internes | Dépend entièrement de l'hygiène de développement de la cible |
| Identifier la stack technique | Lecture des en-têtes `Server`/`X-Powered-By` | Systématiquement, en passif | Version précise d'un composant | L'exploitabilité dépend d'une CVE réellement applicable à cette version |
| Provoquer un message d'erreur verbeux | Soumission de valeurs hors norme (type, caractère spécial, valeur extrême) | Sur tout paramètre, après établissement d'un comportement de référence | Stack trace, nom de table/colonne, chemin absolu dans la réponse | Une gestion d'erreur uniformisée bloque ce vecteur sans garantir l'absence d'autres fuites |
| Trouver un endpoint de diagnostic actif | Requête directe sur des chemins connus (`/actuator/env`, `/_profiler/`, `/console`) | Stack au moins partiellement identifiée | Code `200` avec variables d'environnement/config exposées | Liste de chemins non exhaustive — dépend du framework réel |
| Lire le code source d'un fichier interprété | Variante de nom (`.bak`, `~`, `.swp`) sur un fichier d'entrée connu | Sur chaque fichier d'entrée identifié en cartographie | Code `200`, contenu en texte brut (non interprété) | Un échec sur un fichier ne garantit rien sur les autres fichiers |
| Récupérer l'historique complet d'un dépôt | Requête sur `/.git/HEAD` et `/.git/config` | Systématiquement, sans prérequis particulier | Contenu cohérent avec un dépôt Git réel | Le déploiement doit avoir copié le répertoire `.git` dans la racine web |
| Révéler un en-tête interne ajouté par un proxy | Requête `TRACE` | Après vérification que `TRACE` est listé dans `Allow` | La requête reçue par le serveur, en-têtes internes inclus | Sans effet si aucun composant interne n'ajoute d'en-tête |
| Détecter un oracle d'énumération | Comparaison de réponses entre valeur valide et invalide | Sur authentification, réinitialisation de mot de passe, accès à une ressource | Différence reproductible de message/code/taille/temps | Un résultat non reproductible peut être du bruit réseau — répéter le test |
| Détecter un IDOR sur page de compte | Modification du paramètre d'identifiant (`id`, `user`, `uuid`) | Sur toute page de compte/profil | Données d'un autre utilisateur dans la réponse, y compris en cas de redirection | Vérifier le corps de la redirection, pas seulement son code HTTP |

---

## 3. Techniques classées par objectif

### 3.1 Détecter — Reconnaissance passive

#### Fichiers pour robots d'indexation

**Objectif :** repérer des chemins sensibles signalés sans le vouloir par `robots.txt`/`sitemap.xml`.

**Quand l'utiliser :** en tout début d'audit, avant toute interaction active.

**Prérequis :** aucun.

**Syntaxe minimale :**

```bash
curl -s https://cible.example/robots.txt
curl -s https://cible.example/sitemap.xml
```

**Éléments à personnaliser :** le nom d'hôte cible.

**Signal attendu :** chemins listés dans les directives `Disallow`.

**Interprétation :** un chemin listé révèle seulement son **existence probable**, pas son accessibilité réelle ni l'absence de contrôle d'accès — chaque chemin découvert doit être testé individuellement pour son accessibilité (section 3.3).

**Limites :** un `Disallow` n'est en aucun cas une protection ; son absence ne garantit pas l'absence de chemins sensibles ailleurs.

**Source :** cours de référence, §5.1.

#### Commentaires de développement

**Objectif :** repérer des indices techniques (chemins, identifiants de test, logique interne) laissés dans le code livré au client.

**Quand l'utiliser :** sur l'ensemble du trafic proxifié, y compris les ressources jugées inintéressantes (JS, CSS).

**Prérequis :** proxy d'interception configuré, scope défini.

**Syntaxe minimale (usage de l'outil) :** Burp → `Engagement tools` → `Find comments`, appliqué sur l'ensemble du trafic du scope.

**Signal attendu :** commentaires HTML (`<!-- -->`), JS (`//`, `/* */`) contenant des identifiants, chemins internes, ou notes de type `TODO`.

**Interprétation :** un commentaire révélant un identifiant de test ou un chemin interne constitue une fuite directe si l'élément reste valide ou accessible — à vérifier séparément (ex. tester l'identifiant de test sur le formulaire de connexion réel).

**Limites :** dépend entièrement de l'hygiène de développement de l'équipe cible ; l'absence de commentaires exploitables ne dit rien des autres vecteurs.

**Source :** cours de référence, §5.2 ; §4.2.

#### Recherche de motifs sensibles sur le trafic proxifié

**Objectif :** automatiser la détection de secrets ou de mots-clés sensibles sur l'ensemble des requêtes/réponses capturées.

**Quand l'utiliser :** en parallèle du parcours complet de l'application en mode proxy.

**Prérequis :** scope Burp défini, pour limiter le bruit et rester dans le périmètre autorisé.

**Syntaxe minimale (motifs à rechercher via `Search`) :**

```text
password
secret
api_key
token
BEGIN RSA
internal
TODO
debug
```

**Syntaxe minimale (filtres Logger++, indicatifs) :**

```text
Response.Body CONTAINS "stack trace"
Response.Body MATCHES "(?i)(api[_-]?key|secret|passwd|password)\s*[:=]"
Response.Headers CONTAINS "X-Powered-By"
```

**Signal attendu :** occurrences des motifs recherchés dans le corps ou les en-têtes des réponses.

**Interprétation :** une occurrence doit être examinée en contexte — un mot-clé seul (ex. `token` dans un nom de variable JS non sensible) n'est pas automatiquement une fuite exploitable.

**Limites :** la liste de motifs n'est jamais exhaustive ; adapter les motifs à la stack et au métier de l'application testée.

**Source :** cours de référence, §4.2.

### 3.2 Provoquer un effet contrôlé — Déclenchement d'erreurs et oracles

#### Soumission de valeurs hors norme

**Objectif :** provoquer un message d'erreur verbeux révélant la stack technique, un chemin de fichier ou la structure interne (tables/colonnes SQL).

**Quand l'utiliser :** sur tout paramètre, après avoir établi le comportement de référence (requête légitime et requête invalide anodine).

**Prérequis :** comportement de référence du paramètre connu.

**Syntaxe minimale (comparaison à effectuer) :**

```http
GET /product?id=1 HTTP/1.1
Host: cible.example

GET /product?id=abc HTTP/1.1
Host: cible.example

GET /product?id=1' HTTP/1.1
Host: cible.example
```

**Éléments à personnaliser :** le paramètre ciblé, les catégories de valeur testées — type incorrect, caractère spécial (`'`, `"`, `\`, `%00`, `{{`, `<`, `${`), valeur extrême (chaîne très longue, nombre négatif, `null`, valeur vide).

**Signal attendu :** divergence de taille, de code HTTP ou de contenu entre les réponses ; présence de motifs caractéristiques (`error`, `exception`, `SQL`, `Warning`, `Traceback`).

**Interprétation :** un message d'erreur verbeux (ex. `SQLSTATE[42S22]... Column not found: 'usr_pwd'... /var/www/html/app/models/User.php:42`) révèle simultanément le moteur de BDD, un nom de colonne, un chemin absolu et la technologie — un seul message peut valider une hypothèse de stack complète et orienter toute la suite de l'audit.

**Limites :** une réponse générique uniforme indique une gestion d'erreur durcie sur ce paramètre précis, mais ne garantit rien sur les autres paramètres ou catégories de valeurs non testées.

**Source :** cours de référence, §4.3 ; §5.3.

#### Comparaison différentielle automatisée

**Objectif :** systématiser la détection de divergences entre requêtes proches (code HTTP, taille, temps de réponse).

**Quand l'utiliser :** en complément du test manuel, sur un volume de paramètres ou de valeurs important.

**Prérequis :** Burp Intruder configuré avec un point d'injection sur le paramètre ciblé.

**Syntaxe minimale (critères de comparaison à activer dans Intruder) :** codes HTTP, `Content-Length`/taille de réponse, temps de réponse, *grep matching*/*grep extract* sur motifs caractéristiques.

**Signal attendu :** une ligne du tableau de résultats Intruder se distingue significativement des autres sur un ou plusieurs critères.

**Interprétation :** une divergence isolée mérite une investigation manuelle — elle peut révéler un oracle (section 3.4) ou une erreur applicative (ci-dessus), pas nécessairement les deux.

**Limites :** le bruit réseau peut produire de fausses divergences de temps de réponse — toujours répéter la mesure avant de conclure.

**Source :** cours de référence, §4.3.

#### Oracle de différence (énumération)

**Objectif :** établir qu'une réponse applicative diffère structurellement selon l'existence d'une donnée, exploitable pour une énumération.

**Quand l'utiliser :** sur l'authentification, la réinitialisation de mot de passe, l'accès à une ressource, ou tout mécanisme comparant une entrée à une donnée stockée.

**Prérequis :** une valeur connue comme valide et une valeur connue comme invalide pour le même paramètre.

**Syntaxe minimale (scénarios à comparer) :**

| Scénario | Réponse si la donnée existe | Réponse si elle n'existe pas |
|---|---|---|
| Authentification | « Mot de passe incorrect » | « Utilisateur inconnu » |
| Récupération de mot de passe | « Un email a été envoyé » | « Aucun compte associé » |
| Accès à une ressource | `403 Forbidden` | `404 Not Found` |
| Temps de traitement | Réponse lente (requête BDD effectuée) | Réponse rapide |

**Signal attendu :** une différence reproductible de message, code HTTP, taille ou temps de réponse entre les deux cas.

**Interprétation :** toute différence **observable** entre deux cas métier distincts est un oracle potentiel, fondement de l'énumération d'utilisateurs. Un oracle confirmé facilite une attaque ultérieure (énumération) mais ne constitue pas en lui-même un accès à des données.

**Limites :** un résultat non reproductible sur plusieurs tentatives peut être du bruit réseau plutôt qu'un oracle réel — répéter le test avant de conclure.

**Source :** cours de référence, §2.3 ; §5 (tableau scénarios).

### 3.3 Confirmer — Fichiers sensibles et configuration

#### Fichiers de sauvegarde et d'édition

**Objectif :** établir qu'une variante de nom d'un fichier interprété est servie en texte brut, exposant le code source.

**Quand l'utiliser :** sur chaque fichier d'entrée connu de l'application (page d'accueil, contrôleurs identifiés en cartographie).

**Prérequis :** au moins un fichier d'entrée connu (ex. `index.php`).

**Syntaxe minimale :**

```bash
curl -sI https://cible.example/index.php.bak
curl -sI https://cible.example/index.php~
curl -sI https://cible.example/.index.php.swp
```

**Éléments à personnaliser :** le nom du fichier de base (`index.php`), le suffixe/extension testée parmi : `~`, `.bak`, `.old`, `.orig`, `.save`, `.copy`, `.tmp`, archives (`backup.zip`, `site.tar.gz`, `dump.sql`), fichiers de swap Vim (`.<nom>.swp`, `.<nom>.swo`), fichiers d'éditeur (`<nom>.swp`, `#<nom>#`).

**Signal attendu :** code `200` avec un `Content-Type` de texte brut plutôt que le résultat de l'exécution du fichier original.

**Interprétation :** un code `200` confirme une divulgation de code source — avec les secrets hard-codés, la logique de validation et les éventuelles vulnérabilités qu'il contient. Un échec sur un fichier ne garantit rien sur les autres fichiers d'entrée de l'application.

**Limites :** la technique ne fonctionne que si le handler serveur ne reconnaît pas l'extension de la variante testée.

**Source :** cours de référence, §5.6.

#### Exposition du contrôle de version (`.git`)

**Objectif :** établir que le répertoire de travail du dépôt a été déployé directement dans la racine web, exposant tout l'historique du projet.

**Quand l'utiliser :** systématiquement, sans prérequis particulier.

**Prérequis :** aucun.

**Syntaxe minimale :**

```bash
curl -sI https://cible.example/.git/HEAD
curl -s  https://cible.example/.git/config
```

**Syntaxe minimale (récupération, si confirmé) :**

```bash
git-dumper https://cible.example/.git/ ./dump
cd dump
git log --oneline
git show <commit>
git diff <commit_a> <commit_b>
```

**Éléments à personnaliser :** `<commit>`, `<commit_a>`, `<commit_b>` — à remplacer par les références réellement trouvées dans l'historique récupéré.

**Signal attendu :** `/.git/HEAD` retourne un code `200` avec un contenu de type `ref: refs/heads/...` ; `/.git/config` retourne un contenu cohérent avec une configuration Git réelle.

**Interprétation :** une exposition confirmée donne accès à **tout l'historique**, y compris des commits où un secret a été « supprimé » sans être réellement effacé — tout secret ainsi trouvé doit être considéré comme compromis, quelle que soit son ancienneté dans l'historique.

**Limites :** un code `404` sur `/.git/HEAD` ne garantit pas l'absence d'autres artefacts (`.svn`, `.env`, `.idea`, `composer.json`, `package.json`, `*.js.map`) — à tester séparément.

**Source :** cours de référence, §5.6.

#### Endpoints de debug et de diagnostic

**Objectif :** établir qu'un endpoint de diagnostic propre au framework reste accessible sans authentification en production.

**Quand l'utiliser :** une fois la stack technique au moins partiellement identifiée (en-têtes, erreurs provoquées).

**Prérequis :** connaître ou deviner le framework cible, pour prioriser les chemins pertinents.

**Syntaxe minimale (chemins à tester) :**

```text
/debug
/phpinfo.php
/actuator/env
/_profiler/
/console
/server-status
```

**Éléments à personnaliser :** le chemin testé — à adapter strictement à la stack identifiée (`/actuator/env` pour Spring Boot, `/_profiler/` pour Symfony, `/console` pour Werkzeug/H2).

**Signal attendu :** code `200` avec variables d'environnement, configuration ou clé de signature exposées.

**Interprétation :** une clé de signature (JWT, `SECRET_KEY`) exposée ici peut mener à une compromission complète (forge de session, exécution de code selon le framework) — à traiter avec une priorité d'évaluation immédiate, sans attendre la fin de l'audit.

**Limites :** la liste de chemins n'est jamais exhaustive pour la stack réelle ; compléter avec `Discover Content` avant de conclure à une absence.

**Source :** cours de référence, §5.4 ; §4.4.

#### Méthode HTTP `TRACE`

**Objectif :** révéler des en-têtes internes ajoutés par un proxy ou reverse-proxy en amont, en observant la requête telle que reçue par le serveur.

**Quand l'utiliser :** après vérification que `TRACE` figure dans l'en-tête `Allow` d'une requête `OPTIONS`.

**Prérequis :** `TRACE` activé côté serveur.

**Syntaxe minimale :**

```bash
curl -i -X OPTIONS https://cible.example/
curl -i -X TRACE   https://cible.example/
```

**Signal attendu :** réponse de code `200` avec `Content-Type: message/http`, contenant la requête telle qu'envoyée, potentiellement augmentée d'en-têtes ajoutés par un composant interne (ex. `X-Internal-Auth`, `X-Forwarded-For`).

**Interprétation :** un en-tête interne révélé peut ensuite être **forgé par l'attaquant** pour tenter de contourner une authentification supposée interne. L'acceptation de `TRACE` seule, sans en-tête supplémentaire révélé, a un impact nettement plus limité.

**Limites :** sans effet si aucun composant interne n'ajoute d'en-tête à la requête relayée.

**Source :** cours de référence, §5.7.

### 3.4 Confirmer — Autorisation sur les pages de compte (IDOR)

#### Modification de l'identifiant de compte

**Objectif :** établir qu'un contrôle d'autorisation côté serveur est absent ou insuffisant sur une page de compte/profil.

**Quand l'utiliser :** sur toute page affichant des données propres à un compte via un identifiant en paramètre.

**Prérequis :** un identifiant tiers connu ou prévisible (incrémental, ou GUID découvert ailleurs dans l'audit).

**Syntaxe minimale :**

```http
GET /my-account?id=wiener HTTP/1.1
Host: cible.example
Cookie: session=...

GET /my-account?id=carlos HTTP/1.1
Host: cible.example
Cookie: session=...
```

**Éléments à personnaliser :** le nom du paramètre (`id`, `user`, `account`, `uuid`), les identifiants testés.

**Signal attendu :** la seconde requête retourne des données appartenant au compte `carlos`, et non une erreur ou un refus.

**Interprétation :** vérifier systématiquement si une réponse de **redirection** contient malgré tout les données dans son corps — une redirection n'implique pas, à elle seule, l'absence de fuite.

**Limites :** une protection effective doit être vérifiée aussi bien avec des identifiants prévisibles (incrémentaux) qu'avec des identifiants non prévisibles divulgués ailleurs dans l'audit (ex. via commentaires ou fichiers de sauvegarde, section 3.1/3.3).

**Source :** cours de référence, §5.5.

---

## 4. Payloads et syntaxes représentatifs

| Payload / valeur | Ce qu'il teste | Contexte d'insertion | Différence utile | Limite |
|---|---|---|---|---|
| `'` (apostrophe simple) | Rupture de syntaxe SQL potentielle, déclenchement d'erreur verbeuse | Paramètre de requête | Révèle souvent le moteur SQL et sa structure dans le message d'erreur | Peut aussi révéler une injection SQL exploitable — orienter vers la méthodologie dédiée si suggéré |
| `abc` sur un paramètre numérique | Erreur de typage | Paramètre de requête | Révèle le type de donnée attendu | N'indique rien sur la structure interne au-delà du typage |
| `%00` (octet nul) | Troncature de chaîne dans certains runtimes | Paramètre de requête ou nom de fichier | Comportement de troncature spécifique à certains environnements anciens | Peu pertinent sur des stacks modernes |
| `{{`, `${` | Détection d'injection de template (SSTI) via message d'erreur | Paramètre de requête | Révèle un moteur de templating si l'erreur le mentionne | Hors périmètre de cette fiche si confirmé — orienter vers une méthodologie SSTI dédiée |
| Chaîne très longue | Dépassement de limite / erreur de validation non filtrée | Paramètre de requête | Révèle parfois une limite de buffer ou de validation mal gérée | Risque de déni de service involontaire si la cible est fragile — rester proportionné |

Cette fiche ne multiplie pas les payloads au-delà de ceux documentés : l'objectif ici n'est pas l'exploitation d'une injection confirmée (SQL, SSTI) mais la **détection du signal** qu'une erreur verbeuse constitue une fuite — toute confirmation d'un vecteur d'injection oriente vers la méthodologie propre à ce vecteur.

---

## 5. Encodages, formats et représentation des entrées

Le cours source ne documente pas de transformation d'encodage spécifique à la divulgation d'informations elle-même (contrairement aux techniques de contournement de filtre d'autres vulnérabilités). Les seules variations pertinentes concernent la **forme du nom de ressource testée**, résumées ci-dessous :

| Transformation | Origine | Transformée | Contexte pertinent | Effet attendu |
|---|---|---|---|---|
| Ajout de suffixe de sauvegarde | `index.php` | `index.php.bak`, `index.php~`, `.index.php.swp` | Fichier d'entrée connu de l'application | Le serveur sert le fichier en texte brut au lieu de l'interpréter, l'extension/suffixe n'étant pas reconnu par le handler |
| Chemin de configuration connu | — | `/.git/HEAD`, `/.env`, `/.svn/entries` | Racine de l'application | Accès direct à un fichier normalement non destiné à être servi publiquement |

Aucune transformation d'encodage (URL, HTML, null byte) n'est documentée dans le cours comme pertinente pour cette vulnérabilité — ne pas en inventer sans hypothèse technique précise liée à un composant identifié.

---

## 6. Exemples de requêtes HTTP

### 6.1 Comparaison différentielle sur un paramètre

**Référence :**
```http
GET /product?id=1 HTTP/1.1
Host: cible.example
```

**Modifiée :**
```http
GET /product?id=1' HTTP/1.1
Host: cible.example
```

- Changement : ajout d'une apostrophe simple à la valeur du paramètre `id`.
- Pourquoi : teste si le paramètre est inséré sans échappement dans une requête interne, susceptible de provoquer une erreur verbeuse.
- Prérequis : avoir d'abord observé la réponse à `id=1` (référence) et `id=abc` (erreur de typage anodine) pour disposer d'une base de comparaison à trois états.
- Signal à rechercher : message d'erreur contenant un nom de moteur de BDD, de table/colonne, ou un chemin de fichier absolu.
- Ce que cela ne prouve pas à lui seul : qu'une injection SQL est exploitable — seule la confirmation d'un vecteur d'injection, hors périmètre de cette fiche, permettrait cette conclusion ; ici, seule la fuite d'information (stack, structure) est établie.

### 6.2 Révélation d'en-tête interne via `TRACE`

**Référence :**
```http
OPTIONS / HTTP/1.1
Host: cible.example
```

**Modifiée :**
```http
TRACE / HTTP/1.1
Host: cible.example
```

- Changement : méthode `OPTIONS` → `TRACE`.
- Pourquoi : `TRACE` renvoie la requête telle que reçue par le serveur, y compris les en-têtes ajoutés par des composants en amont (proxy, reverse-proxy).
- Prérequis : `TRACE` doit figurer dans l'en-tête `Allow` de la réponse `OPTIONS`.
- Signal à rechercher : présence, dans le corps de la réponse `message/http`, d'en-têtes non envoyés par le testeur (ex. `X-Internal-Auth`, `X-Forwarded-For`).
- Ce que cela ne prouve pas à lui seul : que l'en-tête révélé est effectivement réutilisable pour contourner un contrôle d'accès — cette confirmation nécessiterait de forger une requête avec cet en-tête et d'observer un accès autrement refusé, étape distincte hors périmètre détaillé de cette fiche.

### 6.3 Accès à une page de compte tiers

**Référence :**
```http
GET /my-account?id=wiener HTTP/1.1
Host: cible.example
Cookie: session=<session_du_testeur>
```

**Modifiée :**
```http
GET /my-account?id=carlos HTTP/1.1
Host: cible.example
Cookie: session=<session_du_testeur>
```

- Changement : seule la valeur du paramètre `id` change, la session utilisée reste celle du testeur authentifié.
- Pourquoi : teste si l'autorisation sur la ressource est vérifiée côté serveur ou si elle repose uniquement sur la valeur du paramètre.
- Prérequis : connaître ou deviner un identifiant tiers valide (`carlos`).
- Signal à rechercher : données propres au compte `carlos` dans la réponse (nom, email, informations de profil), y compris si la réponse est une redirection — vérifier alors le corps de cette redirection.
- Ce que cela ne prouve pas à lui seul : rien de plus que la fuite elle-même ; une exploitation plus poussée (modification de données tierces, par exemple) relève d'une méthodologie IDOR dédiée, hors périmètre de cette fiche.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| Burp Suite — Search | Recherche de motifs sensibles sur l'ensemble du trafic proxifié | Dès le début de l'audit, en continu pendant le parcours de l'application | Recherche de `password`, `secret`, `api_key`, `token` sur le scope défini | Nécessite un scope correctement défini pour limiter le bruit |
| Burp Suite — Find Comments | Extraction automatisée des commentaires HTML/JS | Après un parcours complet de l'application en mode proxy | `Engagement tools` → `Find comments` sur le site map | Ne détecte que les commentaires capturés dans le trafic proxifié |
| Burp Suite — Discover Content | Découverte de chemins/fichiers non référencés | Pour enrichir la liste des endpoints de debug ou de fichiers de sauvegarde à tester | Lancer *Discover Content* sur un répertoire suspecté | Dépend de la wordlist utilisée, ne garantit pas l'exhaustivité |
| Burp Suite — Intruder | Automatisation de la comparaison de réponses (code, taille, temps) | Fuzzing de paramètres avec un volume de valeurs important | Payload position sur `id`, comparaison des colonnes Status/Length/Time | Les variations de temps de réponse peuvent être bruitées par la charge réseau |
| Logger++ (extension Burp) | Filtrage avancé du trafic par regex/colonnes personnalisées | Recherche ciblée de motifs sensibles à grande échelle | `Response.Body MATCHES "(?i)(api[_-]?key|secret|passwd)\s*[:=]"` | Syntaxe de filtre à adapter à la version de l'extension |
| `curl` | Requêtes HTTP manuelles ciblées (fichiers, méthodes HTTP) | Tests rapides de chemins connus, scripts de reconnaissance | `curl -sI https://cible.example/index.php.bak` | Ne gère pas l'interaction JS ni le rendu de page |
| `git-dumper` | Récupération d'un dépôt Git exposé pour analyse hors ligne | `/.git/HEAD` confirmé comme accessible | `git-dumper https://cible.example/.git/ ./dump` | Usage réservé à un cadre d'audit autorisé par écrit |
| Nuclei / Nikto | Scan automatisé d'endpoints de debug et en-têtes bavards connus | Complément de la reconnaissance manuelle, en DAST | Lancer un scan ciblé sur le domaine audité | Les templates/signatures doivent être à jour pour rester pertinents |
| Autorize (extension Burp) | Détection automatisée de failles d'autorisation (dont IDOR) | Sur des pages de compte/profil nécessitant une comparaison de rôles | Configurer une session à privilège réduit et comparer aux réponses du rôle normal | Nécessite une configuration précise des sessions comparées |

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Code `200` sur un chemin de fichier de sauvegarde ou `.git/HEAD` là où un `404` était attendu | Fichier ou dossier sensible exposé | Examiner le contenu retourné (texte brut du code source, structure Git réelle) | Qu'un code `200` seul, sans examen du contenu, suffit à qualifier la fuite |
| Message d'erreur contenant un chemin absolu, un nom de table/colonne, ou une trace complète | Divulgation technique exploitable pour cibler la suite de l'audit | Confirmer que le contenu correspond bien à la stack réelle (pas un message générique trompeur) | Que l'information est nécessairement exploitable en impact direct sans évaluation de chaînabilité |
| Différence de taille de contenu ou de code HTTP entre deux valeurs de paramètre | Oracle potentiel (énumération) ou erreur applicative | Répéter le test plusieurs fois pour écarter le bruit réseau | Qu'une différence observée une seule fois est un oracle confirmé |
| Requête `TRACE` acceptée avec en-tête interne renvoyé | Composant interne (proxy) ajoutant des en-têtes exploitables | Comparer la requête envoyée et reçue champ par champ | Que l'acceptation seule de `TRACE`, sans en-tête révélé, constitue une fuite significative |
| Chemin listé dans `robots.txt` | Existence probable d'une ressource sensible | Tester l'accessibilité réelle du chemin listé | Qu'un chemin listé est nécessairement accessible sans authentification |
| Réponse de redirection suite à un accès à un compte tiers | Protection apparente, à vérifier | Inspecter explicitement le corps de la réponse de redirection | Qu'une redirection suffit à elle seule à démontrer une protection effective |
| En-tête `Server`/`X-Powered-By` exposant une version précise | Divulgation technique indirecte | Rechercher une CVE réellement applicable à cette version précise | Que la seule présence d'une version constitue un impact démontré |

---

## 9. Variantes de syntaxe et adaptation

| Variante | Problème qu'elle vise à résoudre | Changement par rapport à la référence | Nouveau signal attendu | Ce qu'il faut garder identique |
|---|---|---|---|---|
| `index.php~` au lieu de `index.php.bak` | Le filtre/serveur peut bloquer une extension de sauvegarde mais pas une autre | Seul le suffixe de nom change | Code `200` là où `.bak` échoue | Le chemin du fichier de base, pour isoler l'effet du seul suffixe |
| `.index.php.swp` (fichier de swap Vim) au lieu d'un suffixe `.bak` | Les éditeurs de texte laissent des artefacts au format différent des sauvegardes manuelles | Changement du motif de nom complet (préfixe `.`, suffixe `.swp`) | Code `200` révélant un fichier généré par interruption d'édition | Le fichier source ciblé, pour rester comparable |
| `/.env` au lieu de `/.git/HEAD` | `.git` peut être spécifiquement bloqué sans que les autres artefacts le soient | Chemin de configuration testé | Contenu de configuration exposé (variables d'environnement) | La méthode de requête (`GET`/`HEAD`) et l'absence d'authentification |
| Identifiant incrémental au lieu d'un GUID découvert ailleurs | Teste si la prévisibilité de l'identifiant facilite l'énumération, indépendamment du contrôle d'autorisation | Nature de l'identifiant testé sur la page de compte | Accès obtenu ou refusé selon la prévisibilité de l'identifiant | Le paramètre et l'endpoint ciblés, pour isoler l'effet de la seule nature de l'identifiant |

**Règle importante :** lors d'un test de fichier de sauvegarde ou de configuration, ne changer qu'un seul élément du nom à la fois (suffixe, préfixe, extension) — modifier plusieurs éléments simultanément empêche de savoir lequel a produit l'effet observé.

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Aucune fuite trouvée après un seul passage de reconnaissance | Effet tunnel : ressources statiques non examinées, un seul rôle testé | Vérifier la couverture des surfaces (JS/CSS inclus, comparaison authentifié/non authentifié) | Reprendre le parcours en couvrant explicitement les surfaces manquantes | Rien n'est encore établi sur l'absence de divulgation — pas toutes les surfaces couvertes |
| Message d'erreur générique quelle que soit l'entrée testée | Gestion d'erreur uniformisée, ou catégorie de valeur non testée | Vérifier si type incorrect, caractère spécial et valeur extrême ont tous été testés | Tester systématiquement les trois catégories avant de conclure | Gestion d'erreur durcie sur ce paramètre précis seulement |
| Fichier de sauvegarde absent sur le fichier d'entrée principal | Fichier simplement non présent sur ce fichier précis | Comparer sur plusieurs fichiers d'entrée distincts | Tester au moins trois fichiers d'entrée différents identifiés en cartographie | Rien sur les autres fichiers de l'application — pas une absence générale |
| `/.git/HEAD` retourne `404` | Dossier `.git` réellement absent, ou bloqué spécifiquement | Comparer avec un autre chemin caché connu (`.env`, `.svn`) | Tester si tous les chemins cachés sont bloqués de façon identique (règle générique) ou seulement `.git` (règle spécifique) | Niveau de protection observé, sans généraliser à tous les artefacts sans test individuel |
| `TRACE` accepté mais aucun en-tête interne révélé | Absence de proxy ajoutant des en-têtes dans ce contexte, ou en-têtes filtrés avant renvoi | Comparer requête envoyée et reçue champ par champ | Ajouter un en-tête personnalisé à la requête `TRACE` et vérifier s'il est répercuté | Absence d'en-tête interne exploitable dans ce contexte précis |
| Oracle testé mais résultat non reproductible | Bruit réseau plutôt qu'oracle réel, ou marge temporelle trop faible | Répéter le test un nombre suffisant de fois, comparer une distribution plutôt qu'une mesure unique | Augmenter le nombre de répétitions | Absence d'oracle exploitable de façon fiable, si la distribution reste indifférenciée malgré répétition |

---

## 11. Checklist d'utilisation

- [ ] L'objectif du test est clairement identifié (reconnaissance passive, erreur provoquée, fichier sensible, oracle, IDOR).
- [ ] Le comportement de référence a été établi avant toute modification (requête légitime, requête invalide anodine).
- [ ] Le bon emplacement de la technique est identifié (paramètre, chemin, méthode HTTP, en-tête).
- [ ] Les valeurs propres à l'application ont été adaptées (fichiers d'entrée réels, identifiants tiers, chemins connus de la stack).
- [ ] Un exemple minimal a été privilégié avant d'étendre à d'autres variantes.
- [ ] Le signal attendu est défini avant l'envoi du test.
- [ ] Les résultats sont comparés à une référence pertinente (requête légitime vs modifiée, rôle vs rôle).
- [ ] Un résultat positif isolé n'est pas présenté comme une preuve d'impact sans évaluation de sa chaînabilité.
- [ ] Les oracles et différences temporelles sont vérifiés par répétition, pas sur une seule mesure.
- [ ] Le niveau de preuve atteint est explicitement qualifié (observation / qualification / usage démontré).

---

## 12. Sources et liens de référence

- [OWASP — Information Exposure](https://owasp.org/www-community/Improper_Error_Handling)
- [OWASP Web Security Testing Guide — Information Gathering](https://owasp.org/www-project-web-security-testing-guide/)
- [PortSwigger Web Security Academy — Information disclosure](https://portswigger.net/web-security/information-disclosure)
- [MITRE CWE-200 : Exposure of Sensitive Information to an Unauthorized Actor](https://cwe.mitre.org/data/definitions/200.html)
- [MITRE CWE-209 : Generation of Error Message Containing Sensitive Information](https://cwe.mitre.org/data/definitions/209.html)
- [MITRE CWE-538 : Insertion of Sensitive Information into Externally-Accessible File or Directory](https://cwe.mitre.org/data/definitions/538.html)
