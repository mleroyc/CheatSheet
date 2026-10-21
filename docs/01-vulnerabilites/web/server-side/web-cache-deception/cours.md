# Web Cache Deception — Cours de référence

## 1. Définition

La **Web Cache Deception (WCD)** est une vulnérabilité qui permet à un attaquant d'amener un **cache web** à stocker une réponse **dynamique et sensible**, normalement destinée à un seul utilisateur authentifié, puis à récupérer cette réponse en interrogeant lui-même la même URL. Les composants concernés sont le **serveur de cache** (ou le CDN) et le **serveur d'origine**, qui jouent chacun un rôle de décision distinct : le serveur d'origine décide quel contenu produire pour une requête donnée, et le cache décide indépendamment si cette réponse peut être stockée et réutilisée. Le défaut devient exploitable lorsque ces deux composants interprètent différemment une même URL (son chemin, ses délimiteurs, sa normalisation), de sorte que le cache croit traiter une ressource statique alors que le serveur d'origine traite réellement une requête dynamique et personnelle. La propriété de sécurité compromise est la **confidentialité** : des informations censées être protégées par un mécanisme d'authentification deviennent accessibles à un utilisateur non autorisé, via le cache plutôt que via un contournement direct de l'authentification.

**Formulation simplifiée :** la Web Cache Deception consiste à piéger un cache pour qu'il stocke par erreur la page privée d'une victime, puis à redemander cette même page pour en récupérer une copie.

Cette définition distingue bien la WCD d'une simple fuite de données : ce n'est pas l'application qui expose directement l'information à un tiers, c'est le cache, en toute bonne foi vis-à-vis de ses propres règles, qui sert à l'attaquant une réponse qui ne lui était pas destinée.

## 2. Cause racine

La cause racine de la Web Cache Deception est un **désaccord d'interprétation entre deux composants distincts** (le cache et le serveur d'origine) qui doivent pourtant coopérer sur la base d'une même donnée d'entrée : l'URL de la requête HTTP.

Chaîne causale :

**Le cache et le serveur d'origine appliquent des logiques différentes pour interpréter le chemin d'une URL (mapping, délimiteurs, normalisation) → une même URL peut donc désigner, pour le cache, une ressource statique cacheable, et pour le serveur d'origine, un endpoint dynamique renvoyant des données propres à l'utilisateur → le cache applique sa règle de mise en cache en se fondant sur sa propre interprétation, sans connaître le contenu réel généré par le serveur d'origine → une réponse contenant des données personnelles se retrouve stockée sous une clé de cache que d'autres utilisateurs peuvent légitimement interroger → violation de la frontière entre contenu privé (lié à une session) et contenu partagé (le cache).**

Deux hypothèses incorrectes sont en jeu :

- Le cache suppose implicitement que **sa propre logique d'interprétation de l'URL correspond à celle du serveur d'origine**, alors que ces deux composants peuvent être développés par des équipes différentes, reposer sur des technologies différentes (un CDN générique face à un framework applicatif précis), et évoluer indépendamment.
- Les règles de cache supposent souvent qu'une caractéristique superficielle de l'URL (une extension de fichier, un préfixe de répertoire, un nom de fichier connu) est un indicateur fiable de la nature du contenu réellement renvoyé, alors que cette caractéristique peut être ajoutée par l'attaquant sans influencer le traitement effectué par le serveur d'origine.

Il est important de distinguer cette cause racine générale (désaccord d'interprétation + règle de cache fondée sur une heuristique de l'URL) des mécanismes précis qui produisent ce désaccord dans chaque variante (mapping de chemins, délimiteurs, normalisation — détaillés en section 7). Il faut également éviter de confondre cette vulnérabilité avec un défaut d'authentification : l'application protège correctement ses données ; c'est l'interaction avec le cache qui contourne cette protection.

## 3. Fonctionnement normal

En l'absence de vulnérabilité, le cycle de traitement d'une requête par un cache web suit ces étapes :

1. **Requête du client** : l'utilisateur demande une ressource ; sa requête HTTP est d'abord reçue par le cache, positionné en intermédiaire entre lui et le serveur d'origine (ce rôle est souvent assuré par un CDN, un réseau de serveurs répartis géographiquement qui stockent des copies de contenus pour les distribuer plus rapidement et réduire la charge du serveur d'origine).
2. **Génération de la clé de cache** : le cache construit une clé de cache à partir de certains éléments de la requête (chemin de l'URL, paramètres de requête, parfois certains en-têtes ou le type de contenu). Cette clé sert à déterminer si une réponse déjà stockée peut être réutilisée.
3. **Vérification** : le cache compare la clé obtenue à son contenu stocké.
   - Si aucune entrée ne correspond, il s'agit d'un **cache miss** : la requête est transmise au serveur d'origine.
   - Si une entrée valide existe, il s'agit d'un **cache hit** : la réponse stockée est renvoyée directement, sans contacter le serveur d'origine.
4. **Traitement par le serveur d'origine** (en cas de miss) : celui-ci génère la réponse. Pour un contenu **statique** (image, CSS, JavaScript), la réponse est la même pour tous les utilisateurs. Pour un contenu **dynamique** (profil, commande, données de session), la réponse dépend de l'utilisateur authentifié.
5. **Application des règles de cache** : à la réception de la réponse, le cache applique ses règles préconfigurées (généralement fondées sur l'extension de fichier, un préfixe de répertoire ou un nom de fichier connu) pour décider si cette réponse peut être stockée, et éventuellement pour combien de temps.
6. **Envoi au client puis réutilisation** : la réponse est transmise à l'utilisateur ; si elle a été stockée, une requête ultérieure correspondant à la même clé de cache peut recevoir directement cette copie.

Dans ce fonctionnement normal, les règles de cache ciblent les ressources statiques précisément parce qu'elles ne varient pas d'un utilisateur à l'autre : les mettre en cache ne pose pas de problème de confidentialité, puisque leur contenu est identique pour tous. Le contenu dynamique, à l'inverse, n'est en principe jamais mis en cache, car il est censé être régénéré à chaque requête pour refléter l'identité et les données de l'utilisateur courant.

## 4. Fonctionnement vulnérable

Le comportement bascule vers la vulnérabilité lorsque le cache **et** le serveur d'origine reçoivent la même URL mais en tirent des conclusions différentes sur la nature de la ressource demandée.

| Aspect | Fonctionnement normal | Fonctionnement vulnérable |
|---|---|---|
| Entrée | URL correspondant sans ambiguïté soit à une ressource statique, soit à un endpoint dynamique | URL construite pour ressembler à une ressource statique aux yeux du cache, tout en restant résolue comme un endpoint dynamique par le serveur d'origine |
| Traitement | Le cache et le serveur d'origine s'accordent implicitement sur la nature de la ressource | Le cache applique sa règle (extension, répertoire, nom de fichier) sans savoir ce que le serveur d'origine a réellement généré |
| Décision | Mise en cache uniquement pour un contenu réellement statique | Mise en cache d'une réponse dynamique, parce que le cache l'associe à tort à une règle de ressource statique |
| Résultat | Le contenu stocké est identique pour tous les utilisateurs | Le contenu stocké contient des données propres à la victime qui a déclenché la mise en cache |
| Conséquence de sécurité | Aucune | Un autre utilisateur interrogeant la même URL peut recevoir la copie stockée contenant les données de la victime |

Le scénario d'attaque type se déroule ainsi :

1. **Construction d'une URL malveillante** : l'attaquant élabore une URL qui exploite une différence d'interprétation connue entre le cache et le serveur d'origine ciblés.
2. **Visite par la victime** : la victime, authentifiée, visite cette URL (par exemple via un lien envoyé par l'attaquant). Sa requête porte sa session valide.
3. **Interprétation incorrecte par le cache** : le cache considère la requête comme portant sur une ressource statique cacheable.
4. **Génération d'une réponse sensible** : le serveur d'origine traite la même requête comme une demande de contenu dynamique, et renvoie des informations propres à la victime.
5. **Stockage dans le cache** : le cache conserve cette réponse, car ses règles internes l'y autorisent.
6. **Récupération par l'attaquant** : l'attaquant envoie à son tour une requête vers la même URL. Si le cache la lui sert directement sans revérifier les droits d'accès (ce qui est le comportement attendu d'un cache hit), il obtient les données de la victime.

Il faut noter que la clé de cache utilisée pour stocker et retrouver la réponse ne tient généralement pas compte de l'identité de l'utilisateur ni de son état d'authentification : c'est précisément cette absence de prise en compte, combinée à l'erreur d'interprétation de l'URL, qui rend l'attaque possible.

## 5. Modèle technique

### 5.1. Vue d'ensemble

```mermaid
sequenceDiagram
    participant Attaquant
    participant Victime
    participant Cache
    participant Origine as Serveur d'origine

    Attaquant->>Victime: Envoie une URL piégée (ex. /profile;foo.css)
    Victime->>Cache: Requête GET avec sa session authentifiée
    Cache->>Origine: Cache miss, requête transmise telle quelle
    Origine-->>Cache: Réponse dynamique (données de la victime)<br/>car le serveur ignore le segment ajouté
    Note over Cache: Le cache applique sa règle sur<br/>l'extension/segment perçu comme statique
    Cache-->>Victime: Réponse transmise + mise en cache
    Attaquant->>Cache: Requête vers la même URL
    Cache-->>Attaquant: Réponse stockée (cache hit)<br/>contenant les données de la victime
```

Ce schéma illustre le chemin complet : l'entrée contrôlée par l'attaquant est l'URL envoyée à la victime (point 1), elle traverse le cache puis le serveur d'origine lors de la première requête de la victime (point 2), le point de traitement incorrect est la décision de mise en cache fondée sur une interprétation de l'URL que le serveur d'origine ne partage pas (point 3), le comportement inattendu est le stockage d'une réponse personnelle sous une clé générique (point 4), et l'impact de sécurité est la récupération de cette réponse par l'attaquant via une simple requête ultérieure (point 5).

### 5.2. Explication du schéma

La **frontière de confiance** franchie ici sépare les données destinées à un utilisateur authentifié spécifique des données que le cache considère comme partageables entre tous les visiteurs. Le cache ne connaît pas la sémantique métier de la réponse qu'il stocke : il se fie uniquement à des signaux superficiels dans l'URL ou les en-têtes.

Le désaccord d'interprétation se situe entre le cache, qui applique une règle générique et rapide fondée sur la forme de l'URL (le plus souvent indépendante du framework applicatif réel), et le serveur d'origine, dont la logique de routage (REST, correspondance de fichiers, gestion des délimiteurs propre à son framework) peut tolérer ou ignorer des éléments de chemin que le cache, lui, prend en compte intégralement.

### 5.3. Exemple technique commenté

```http
GET /settings/users/list;aaa.js HTTP/1.1
Host: example.com
Cookie: session=<session_victime>
```

- `/settings/users/list` est l'endpoint dynamique réel, qui renvoie des informations sensibles liées à la session de l'utilisateur.
- `;aaa.js` est un segment ajouté par l'attaquant : le point-virgule (`;`) peut être traité comme un délimiteur par certains frameworks serveur (par exemple pour introduire des paramètres de matrice), qui tronquent alors le chemin avant ce caractère et traitent la requête comme si elle visait uniquement `/settings/users/list`.
- Le cache, s'il ne reproduit pas cette interprétation du point-virgule, peut analyser le chemin dans son intégralité et reconnaître l'extension `.js`, qu'il associe à une règle de mise en cache des ressources statiques.
- Résultat : le serveur d'origine renvoie les données dynamiques de `list`, et le cache les stocke sous la clé correspondant au chemin complet avec `.js`.
- Ce qui dépend du contexte : la présence effective d'un tel comportement dépend entièrement du framework utilisé par le serveur d'origine et de la logique propre du cache ou du CDN ; un point-virgule n'est pas un délimiteur universel, et cette technique doit être vérifiée empiriquement pour chaque cible.

## 6. Conditions nécessaires à l'exploitation

| Condition | Pourquoi elle est importante | Obligatoire ou dépendante du scénario ? |
|---|---|---|
| Il existe un endpoint dynamique renvoyant des informations sensibles liées à l'utilisateur authentifié | Sans contenu sensible à exposer, la mise en cache d'une réponse dynamique n'a pas d'impact de confidentialité | Obligatoire |
| Le cache et le serveur d'origine interprètent différemment une même URL (mapping, délimiteur ou normalisation) | C'est le mécanisme technique permettant qu'une requête dynamique soit perçue comme statique par le cache | Obligatoire |
| Le cache applique une règle de mise en cache fondée sur une caractéristique de l'URL que l'attaquant peut reproduire (extension, préfixe, nom de fichier) | Détermine la forme concrète de l'URL piégée à construire | Dépendante du scénario (varie selon le type de règle en place) |
| La clé de cache ne prend pas en compte l'identité ou la session de l'utilisateur | Permet qu'une réponse stockée pour un utilisateur donné soit resservie à un autre utilisateur sans contrôle d'accès | Obligatoire |
| L'attaquant peut amener la victime à visiter l'URL piégée (lien, ingénierie sociale) | Nécessaire pour que la réponse sensible de la victime soit effectivement générée et mise en cache | Obligatoire pour l'attaque complète, mais pas pour la seule découverte de la différence d'interprétation |
| L'application ne définit pas de `Cache-Control` strict (`no-store`, `private`) sur les réponses dynamiques, ou le cache ne respecte pas ces directives | Sans cela, le cache ne devrait en principe jamais stocker la réponse, quelle que soit l'interprétation de l'URL | Obligatoire |
| L'attaquant peut relire la même URL après la visite de la victime, sans contrôle d'accès supplémentaire du cache | Condition finale pour récupérer effectivement la réponse stockée | Obligatoire |

Trois situations sont à bien distinguer :

- **Identifier une différence d'interprétation** : démontrer, par exemple en ajoutant un segment arbitraire à une URL, que le serveur d'origine et/ou le cache traitent certains chemins de façon non standard. Cela ne prouve pas encore qu'une donnée sensible puisse être exfiltrée.
- **Démontrer la mise en cache effective d'une réponse dynamique** : confirmer, via les en-têtes (`X-Cache`, `Cache-Control`) ou les temps de réponse, qu'une réponse contenant potentiellement des données sensibles a bien été stockée.
- **Démontrer l'impact réel** : obtenir, depuis une requête distincte (simulant un attaquant), la donnée sensible effectivement associée à une autre session. C'est seulement à ce stade que la vulnérabilité est pleinement confirmée.

## 7. Variantes et cas particuliers

Les variantes de Web Cache Deception se distinguent principalement par le **type de règle de cache exploitée**, qui détermine la nature de l'URL piégée à construire.

### 7.1. Exploitation des règles basées sur l'extension de fichier

Le cache stocke les réponses dont l'URL se termine par une extension associée à des ressources statiques (`.css`, `.js`, etc.). Deux mécanismes distincts peuvent produire la différence d'interprétation nécessaire :

- **Différence de correspondance de chemins (path mapping discrepancy)** : le serveur d'origine utilise un mapping de type REST, où l'URL désigne une ressource logique (un profil, une commande) indépendamment de tout fichier physique, et où un segment supplémentaire en fin de chemin peut être ignoré par le routeur applicatif (exemple : `/user/123/profile/wcd.css` toujours résolu comme `/user/123/profile`). Le cache, lui, peut appliquer une logique plus proche d'une correspondance traditionnelle de fichiers et reconnaître l'extension `.css` en fin de chemin.
- **Différence de délimiteur (delimiter discrepancy)** : certains caractères sont traités comme marquant la fin du chemin significatif par le serveur d'origine, mais pas par le cache. Le point-virgule (`;`) dans des frameworks comme Spring (où il introduit des *matrix variables*), le point (`.`) dans des frameworks comme Ruby on Rails (où il indique un format de réponse, ignoré s'il n'est pas reconnu), ou un octet nul encodé (`%00`) dans certaines configurations serveur, peuvent chacun jouer ce rôle selon la technologie en place. Ces comportements sont propres à chaque framework ou serveur et ne se généralisent pas automatiquement d'une cible à l'autre.

### 7.2. Exploitation des règles basées sur le répertoire statique

Le cache associe un préfixe de chemin (`/static`, `/assets`) à des ressources cacheables. La différence exploitée ici relève de la **normalisation des chemins** : le décodage de caractères encodés (par exemple `%2f` pour `/`) et la résolution des segments de traversal (`..`) peuvent être effectués par l'un des deux composants et pas par l'autre. Deux sous-cas symétriques existent :

- Le **serveur d'origine normalise**, mais pas le cache : une URL comme `/assets/..%2fprofile` est vue par le cache comme relevant du préfixe `/assets` (donc cacheable), tandis que le serveur d'origine la résout en `/profile` (contenu dynamique).
- Le **cache normalise**, mais pas le serveur d'origine : il faut alors combiner le traversal avec un délimiteur supplémentaire (par exemple `;`) pour que le serveur d'origine tronque le chemin au bon endroit, faute de quoi il tenterait de résoudre littéralement les caractères encodés et renverrait une erreur.

### 7.3. Exploitation des règles basées sur le nom de fichier

Certains caches ciblent des noms de fichiers précis et fréquents (`robots.txt`, `favicon.ico`) plutôt qu'une extension générique. Le principe reste la normalisation de chemin, mais la situation exploitable est plus restreinte : seul le cas où **le cache normalise les segments encodés alors que le serveur d'origine ne le fait pas** permet de faire correspondre une URL contenant un contenu dynamique réel à un nom de fichier reconnu par le cache.

Ces trois variantes partagent la même cause racine (désaccord d'interprétation d'URL + règle de cache fondée sur une heuristique) mais reposent sur des mécanismes techniques distincts (mapping REST, délimiteurs spécifiques à un framework, normalisation de traversal) : une technique qui fonctionne pour contourner une règle d'extension (section 7.1) ne s'applique pas nécessairement à une règle de répertoire (section 7.2), car les points de divergence testés et les formes d'URL construites diffèrent.

## 8. Impact et limites de l'impact

| Impact possible | Mécanisme | Conditions supplémentaires nécessaires | Limites potentielles |
|---|---|---|---|
| Divulgation de données personnelles d'un utilisateur précis (profil, coordonnées, jetons affichés en clair) | Réponse dynamique de la victime mise en cache et resservie à l'attaquant | L'attaquant doit connaître ou deviner l'URL visitée par la victime, et devoir l'y attirer | Si le contenu sensible dépend d'un identifiant dans l'URL (ex. `/user/123/profile`), l'attaque ne vise qu'un utilisateur à la fois, pas l'ensemble des utilisateurs |
| Vol de jetons de session ou de CSRF présents dans une page dynamique | Le contenu mis en cache contient un jeton que l'application affichait pour la victime | Le jeton doit apparaître dans le corps ou les en-têtes de la réponse mise en cache, et rester valide le temps de l'exploitation | Rotation fréquente des jetons, jetons liés à d'autres facteurs (IP, user-agent) peuvent limiter l'exploitation |
| Exposition à grande échelle si l'URL piégée est largement diffusée ou générique | Plusieurs victimes visitent la même URL piégée, chacune générant potentiellement une mise en cache de ses propres données | Dépend de la capacité de l'attaquant à diffuser le lien, et du fait que chaque victime écrase ou coexiste avec les réponses précédentes selon la politique de cache | Une clé de cache par utilisateur réduirait cet impact à un seul utilisateur par URL ciblée |

Une même application présentant un désaccord d'interprétation d'URL entre son cache et son serveur d'origine peut avoir un risque très variable selon la nature des données exposées par l'endpoint ciblé : une page de profil affichant un nom d'utilisateur n'a pas le même impact qu'une page exposant un numéro de carte bancaire partiellement masqué ou un jeton de session actif. Le risque dépend donc autant du contenu réellement renvoyé par l'application que de la présence du désaccord d'interprétation lui-même.

## 9. Signaux d'identification et observations pertinentes

| Observation | Interprétation possible | Autres explications | Ce qui reste à démontrer |
|---|---|---|---|
| Une requête vers `/endpoint/aaa` (segment arbitraire ajouté) renvoie la même réponse que `/endpoint` | Le serveur d'origine ignore ou abstrait ce segment supplémentaire | Une redirection, une règle de réécriture, ou un comportement spécifique à l'application peuvent produire le même résultat sans lien avec un mapping REST tolérant | Le segment est-il réellement ignoré par le routage interne, ou simplement redirigé vers la même ressource pour une autre raison ? |
| Une requête vers une URL contenant une extension statique ajoutée (`/endpoint/aaa.js`) obtient un en-tête `X-Cache: hit` lors d'une requête répétée | Le cache a appliqué une règle de mise en cache fondée sur cette extension | Le hit peut provenir d'une autre ressource légitimement statique partageant un chemin similaire, ou d'un cache buster mal configuré ayant produit une collision de clé | Le contenu réellement stocké correspond-il bien à une réponse dynamique et sensible, ou à un contenu générique sans valeur ? |
| Une deuxième requête vers la même URL piégée est nettement plus rapide que la première | Possible signe d'un cache hit, le contenu étant servi depuis le cache sans repasser par le serveur d'origine | La latence réseau, la charge du serveur, la réutilisation de connexion ou de simples variations temporaires peuvent aussi expliquer un temps de réponse plus court | Faut-il confirmer par d'autres indices (en-têtes, comparaison de plusieurs requêtes dans des conditions similaires) avant de conclure à un cache hit |
| Le contenu d'une réponse mise en cache contient des données qui semblent liées à un utilisateur précis (nom, identifiant, jeton) | La réponse dynamique d'un utilisateur a potentiellement été stockée et pourrait être resservie à un tiers | Il peut s'agir de données de test ou d'un contenu générique ressemblant à des données personnelles sans en être | Un autre utilisateur (ou une session non authentifiée) peut-il effectivement récupérer cette même réponse stockée ? |

Ces observations constituent des indices à confirmer, et non des preuves d'impact : un cache hit confirmé sur une URL piégée ne garantit pas, à lui seul, que le contenu stocké est réellement sensible ni qu'un autre utilisateur peut y accéder sans restriction supplémentaire.

## 10. Défenses et prévention

### 10.1. Marquer explicitement les réponses dynamiques comme non cacheables (correction de la cause racine)

La mesure la plus directe consiste à définir, pour toute réponse dynamique et sensible, l'en-tête `Cache-Control: no-store, private`. `no-store` empêche tout stockage de la réponse, y compris temporaire, et `private` indique qu'elle ne doit être conservée que par un cache dédié à un seul utilisateur (par exemple le navigateur local), jamais par un cache partagé. Cette mesure traite directement la cause racine en supprimant la possibilité même de mise en cache, indépendamment de toute différence d'interprétation de l'URL.

### 10.2. S'assurer que l'infrastructure de cache respecte ces directives

Il ne suffit pas que l'application émette les bons en-têtes : le cache ou le CDN doit être configuré pour ne pas les outrepasser. Certaines infrastructures appliquent des règles de cache qui peuvent, selon leur configuration, ignorer ou remplacer le comportement suggéré par `Cache-Control`. Cette mesure complète la précédente, car une directive correcte côté application reste inefficace si l'infrastructure de cache ne la respecte pas réellement.

### 10.3. Activer les protections dédiées du CDN

Certains fournisseurs de CDN proposent des protections spécifiques contre la Web Cache Deception, qui vérifient par exemple que le `Content-Type` effectivement renvoyé par le serveur d'origine correspond bien à l'extension présente dans l'URL avant d'autoriser la mise en cache (l'exemple cité dans le cours source est Cloudflare Cache Deception Armor). Cette défense agit comme un filet de sécurité complémentaire, utile notamment lorsque la cause racine (désaccord d'interprétation) ne peut pas être entièrement éliminée côté application.

### 10.4. Éliminer les différences d'interprétation des URL

La correction la plus profonde consiste à aligner la logique d'interprétation du cache et celle du serveur d'origine : normalisation cohérente des chemins, traitement identique des délimiteurs, mapping d'URL sans ambiguïté. Cette mesure est généralement plus complexe à mettre en œuvre que les précédentes, car elle peut nécessiter une intervention sur des composants tiers (CDN, framework) dont le comportement n'est pas toujours configurable finement.

### 10.5. Limites générales de ces défenses

Ces mesures sont complémentaires plutôt que substituables. Des en-têtes `Cache-Control` corrects n'empêchent rien si l'infrastructure de cache ne les respecte pas ; des protections de CDN génériques peuvent ne pas couvrir toutes les variantes (par exemple une différence de délimiteur propre à un framework non anticipé par l'éditeur du CDN) ; et l'élimination complète des différences d'interprétation dépend de la maîtrise effective de tous les composants impliqués, ce qui n'est pas toujours possible lorsque le cache est un service tiers.

## 11. Synthèse conceptuelle

### 11.1. Le mécanisme en quelques phrases

La Web Cache Deception exploite un désaccord entre le cache et le serveur d'origine sur l'interprétation d'une même URL : le cache croit reconnaître une ressource statique, tandis que le serveur d'origine traite en réalité une requête dynamique et personnelle. Lorsqu'une victime authentifiée visite une URL construite pour exploiter ce désaccord, sa réponse personnelle se retrouve stockée dans le cache sous une clé générique, ne tenant pas compte de son identité. Un attaquant peut alors récupérer cette réponse en interrogeant la même URL. L'exploitation repose sur trois familles de divergences possibles : le mapping des chemins, le traitement des délimiteurs, et la normalisation des chemins encodés.

### 11.2. Les points fondamentaux à retenir

- La vulnérabilité provient d'un désaccord entre deux composants (cache et serveur d'origine), pas d'un défaut d'authentification de l'application.
- La clé de cache ne tient généralement pas compte de l'identité de l'utilisateur, ce qui permet qu'une réponse stockée pour une victime soit resservie à un attaquant.
- Trois mécanismes distincts peuvent produire le désaccord d'interprétation : mapping de chemin, délimiteur, normalisation — chacun avec ses propres conditions et limites.
- Confirmer une mise en cache (via `X-Cache` ou les temps de réponse) ne suffit pas : il faut démontrer que le contenu stocké est réellement sensible et accessible à un tiers.

### 11.3. Les confusions à éviter

- Confondre la **Web Cache Deception** et la **Web Cache Poisoning** : la première vise à faire stocker du contenu sensible pour le récupérer soi-même, la seconde vise à faire stocker du contenu malveillant pour le distribuer à d'autres utilisateurs — les objectifs et les mécanismes exploités diffèrent.
- Considérer qu'une réponse marquée `Cache-Control: public, max-age=...` est nécessairement mise en cache : cet en-tête indique seulement qu'elle est **autorisée** à l'être, pas qu'elle l'a été effectivement, ni qu'elle a été servie depuis le cache.
- Croire qu'un temps de réponse plus court prouve systématiquement un cache hit, sans tenir compte des autres facteurs de latence possibles.
- Généraliser une technique de délimiteur propre à un framework donné (par exemple le point-virgule sous Spring) à toute cible, alors que ce comportement dépend strictement de la technologie serveur utilisée.
- Présenter une différence d'interprétation d'URL confirmée comme une preuve d'impact, alors qu'elle ne démontre que la possibilité de déclencher le comportement, pas l'accès effectif à une donnée sensible d'un tiers.

## 12. Glossaire des termes techniques

| Terme | Définition | Rôle dans la vulnérabilité WCD |
|---|---|---|
| Cache web | Système intermédiaire stockant temporairement des copies de réponses HTTP pour les resservir plus rapidement | Composant qui peut être trompé pour stocker une réponse sensible |
| Serveur d'origine | Serveur hébergeant l'application et générant les réponses | Composant dont l'interprétation de l'URL peut diverger de celle du cache |
| Contenu dynamique | Contenu généré en fonction de l'utilisateur, de sa session ou de ses données | Type de contenu visé par l'attaque, censé ne jamais être mis en cache |
| Contenu statique | Contenu identique pour tous les utilisateurs (image, CSS, JS) | Type de contenu que les règles de cache sont censées cibler légitimement |
| Clé de cache (cache key) | Identifiant construit à partir d'éléments de la requête, utilisé pour déterminer si une réponse peut être réutilisée | Mécanisme central : son absence de prise en compte de l'identité utilisateur permet la réutilisation abusive |
| Cache hit / cache miss | Hit : une réponse stockée correspondante existe ; Miss : aucune réponse utilisable n'est trouvée, la requête est transmise au serveur d'origine | Indicateurs utilisés pour détecter si une réponse a été servie depuis le cache |
| Règle de cache (cache rule) | Configuration déterminant quelles réponses peuvent être stockées et pour combien de temps | Le point précis que l'attaquant cherche à satisfaire avec une URL trompeuse |
| Path mapping | Processus par lequel un chemin d'URL est associé à une ressource ou une opération (traditionnel ou de type REST) | Source possible de divergence si le serveur ignore un segment que le cache prend en compte |
| Delimiter discrepancy | Différence de traitement d'un caractère considéré comme marquant la fin du chemin significatif par l'un des composants et pas par l'autre | Mécanisme exploité pour faire percevoir une extension statique au cache sans affecter le routage du serveur |
| Normalisation de chemin | Transformation d'un chemin URL en une forme standardisée (décodage, résolution des segments `.`/`..`) | Source de divergence lorsqu'un composant normalise et l'autre non |
| Cache buster | Valeur ajoutée à une requête pour modifier sa clé de cache et éviter la réutilisation d'une réponse stockée lors de tests | Outil méthodologique pour fiabiliser les tests, non un mécanisme de la vulnérabilité elle-même |
| CDN (Content Delivery Network) | Réseau de serveurs distribués géographiquement, stockant des copies de contenu pour réduire la latence et la charge du serveur d'origine | Infrastructure la plus courante jouant le rôle de cache dans ce contexte |

## 13. Ressources et références

- Document de cours source fourni pour cette fiche (notes de formation sur la Web Cache Deception).
- PortSwigger Web Security Academy — *Web cache deception* : ressource de référence couvrant les mécanismes de désaccord d'interprétation d'URL, les règles de cache par extension, répertoire et nom de fichier, ainsi que les méthodes de détection, dont une partie des concepts de ce cours sont directement issus. Disponible sur le site officiel de PortSwigger (portswigger.net), dans la section Web Security Academy.

Aucune autre référence externe n'a pu être vérifiée dans le cadre de la rédaction de cette fiche. Il est recommandé de consulter en complément la documentation du CDN ou du système de cache effectivement utilisé par l'application étudiée (par exemple la documentation de Cloudflare sur ses protections anti-WCD), afin de confirmer les options précises de configuration disponibles pour cette infrastructure.
