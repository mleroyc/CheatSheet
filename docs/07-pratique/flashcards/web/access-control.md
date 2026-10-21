# Broken Access Control (BAC)

## 1. Mécanisme fondamental

**Cause racine :** l'application exécute une action ou renvoie une ressource sans revérifier, côté serveur et à chaque requête, que l'utilisateur authentifié a réellement le droit de faire cette action sur cette ressource précise. Le contrôle d'accès repose sur trois piliers qu'il faut distinguer : l'authentification (qui es-tu), la gestion de session (associer les requêtes à une identité) et le contrôle d'accès proprement dit (as-tu le droit). Une authentification solide ne compense jamais un contrôle d'accès absent après connexion.

Trois familles de contrôle, à ne pas confondre :
- **Vertical** : quels rôles ont accès à quelles fonctions (ex. suppression d'utilisateur réservée à l'admin).
- **Horizontal** : même rôle, mais chaque utilisateur ne doit voir/modifier que ses propres instances de données.
- **Contextuel / séquentiel** : l'état du workflow (étape du processus) conditionne si l'action est légitime.

**Principe sous-jacent : deny by default.** Toute ressource ou action est confidentielle tant qu'une règle explicite ne l'autorise pas côté serveur. Cacher un lien dans l'UI, complexifier une URL ou faire confiance à une donnée fournie par le client (cookie, paramètre, header) ne constitue jamais une vérification — ce sont des indices observables, pas des causes de sécurité.

À bien séparer : l'**indice** (pas de lien visible, URL complexe), la **cause** (absence de vérification serveur) et la **conséquence** (accès non autorisé à une fonction ou à une donnée).

## 2. Reconnaissance et surface d'attaque

Où regarder en priorité :
- Toute fonctionnalité qui distingue des rôles (back-office, modération, administration).
- Tout endpoint prenant un **identifiant de ressource** en paramètre (id numérique, GUID visible, nom de fichier) → terrain IDOR.
- Tout **processus multi-étapes** (wizard, changement de rôle, paiement) → terrain séquentiel.
- Les en-têtes que le serveur « croit » venir d'une infrastructure de confiance : `Referer`, `X-Forwarded-For`, `CF-IPCountry`, `X-Original-URL`, `X-Rewrite-URL`.
- `robots.txt`, code JavaScript côté client, commentaires HTML, réponses d'API (souvent plus verbeuses que l'UI) : sources classiques pour découvrir des endpoints non liés dans l'interface.

Hiérarchie de preuve, à ne jamais aplatir :
- Un **indice** (route trouvée dans `robots.txt`, lien caché en JS, paramètre `role=admin`) justifie un test, ne prouve rien.
- Un **résultat cohérent** après manipulation (données différentes renvoyées, action exécutée) renforce l'hypothèse.
- Une **confirmation** suffisante exige la reproductibilité et la preuve d'un effet réel propre à un autre compte/rôle, pas seulement un masquage d'UI contourné.

Avant de conclure à un BAC, exclure les explications alternatives : bug fonctionnel, cache partagé affichant une ressource par accident, erreur réseau indépendante de la couche applicative.

## 3. Méthodologie de diagnostic

**Étape 1 — Cartographier rôles et ressources**
*Objectif* : savoir qui peut faire quoi. *Test* : utiliser deux comptes de même rôle (A, B) et si possible un compte admin. *Observation* : fonctionnalités par rôle, identifiants exposés dans URLs/réponses. *Interprétation* : un ID d'objet visible = piste IDOR ; une fonction visible pour un seul rôle = piste verticale. *Suite* : prioriser les endpoints exposant directement un identifiant.

**Étape 2 — Établir une baseline**
*Objectif* : connaître le comportement normal (codes HTTP, contenu, redirections) pour une requête autorisée et une requête refusée connue. *Interprétation* : sans référence, un `200 OK` ou un contenu renvoyé ne signifie rien dans l'absolu — comparez toujours à cette baseline, pas à une intuition.

**Étape 3 — Tester le contrôle vertical**
*Test* : accéder directement aux endpoints identifiés sans suivre l'UI ; varier méthode HTTP, casse, suffixe, slash final ; tester les headers de réécriture. *Observation* : l'action s'exécute-t-elle réellement (effet constaté), ou la page se charge-t-elle seulement sans conséquence ? *Interprétation* : charger une page ≠ exécuter l'action. *Suite* : en cas de blocage, tester une divergence d'interprétation d'URL entre proxy et backend avant d'abandonner.

**Étape 4 — Tester le contrôle horizontal (IDOR)**
*Test* : substituer l'identifiant du compte A par celui du compte B, sur toutes les méthodes (pas seulement en lecture). *Interprétation* : un GUID non devinable réduit le risque de brute-force, pas le risque si ce GUID fuite ailleurs (avis, historique partagé, export) — ne concluez pas « pas d'IDOR » sur ce seul critère. *Suite* : si l'ID testé appartient par hasard à un admin, chercher explicitement la bascule horizontal → vertical.

**Étape 5 — Tester le contrôle séquentiel**
*Test* : rejouer ou sauter des requêtes d'un processus multi-étapes, en appelant directement l'étape finale. *Interprétation* : un contrôle correct à l'étape 1 ne garantit rien sur l'étape 3 — l'application suppose souvent à tort que l'ordre normal a été respecté.

**Étape 6 — Explorer les canaux de confiance implicite**
*Test* : falsifier `Referer`, en-têtes de géolocalisation/proxy, cookies de rôle, sur une requête directe vers la ressource protégée. *Interprétation* : un succès confirme fortement que l'autorisation repose sur une donnée client ; un échec n'exclut pas d'autres vecteurs (étapes 3 à 5).

Ces méthodes sont indépendantes : il n'existe pas d'ordre universel « A avant B » — le choix dépend des indices collectés en reconnaissance.

## 4. Techniques principales et choix de la méthode

| Technique | Principe | Adaptée quand… | Limite / erreur fréquente |
|---|---|---|---|
| Force brute de répertoires (ex. *Discover content* de Burp) | Deviner des chemins non liés (`/admin`, `/manage`) | Aucune fonction admin visible dans l'UI | Un échec ne prouve pas l'absence de panel admin (nom imprévisible) |
| Manipulation de paramètres/cookies cachés | Modifier une valeur de rôle stockée côté client (`?admin=true`, cookie) | L'autorisation semble décidée une fois au login | Ne fonctionne que si le serveur fait confiance à cette valeur sans revalidation |
| Manipulation de méthode HTTP | Remplacer POST/DELETE par GET/HEAD sur une action sensible | La restriction ne cible qu'une méthode précise | Ne traite pas une architecture où toutes les méthodes sont filtrées uniformément |
| Divergence d'interprétation d'URL | Casse différente, suffixe ajouté, slash final | Filtre de sécurité et serveur applicatif parsent l'URL différemment | Dépend fortement du framework (ex. anciens Spring avec `useSuffixPatternMatch`) — ne pas généraliser à toutes les stacks |
| Header de réécriture (`X-Original-URL`/`X-Rewrite-URL`) | Faire exécuter par le backend une URL différente de celle vue par le proxy frontal | Architecture avec proxy inverse (IIS, Symfony…) qui réécrit les routes | Ne s'applique pas si le backend ignore ces en-têtes |
| IDOR sur objets BDD / fichiers statiques | Modifier un identifiant numérique ou séquentiel | Paramètre identifiant une ressource, fichier nommé de façon prévisible | Un test en lecture seule peut passer inaperçu alors que l'écriture est vulnérable (ou l'inverse) |
| Referer / géolocalisation | Falsifier une donnée que le serveur croit fiable | Contrôle visiblement basé sur l'historique de navigation ou le pays | Preuve forte en cas de succès, mais un échec n'élimine pas les autres vecteurs |

## 5. Erreurs fréquentes

1. Confondre « lien absent de l'UI » avec « fonction protégée » et arrêter l'investigation trop tôt.
2. Tester l'IDOR uniquement en lecture (GET) sans vérifier les actions d'écriture (POST/PUT/DELETE).
3. Conclure à l'absence de faille après un seul test négatif, sans essayer les variantes (casse, suffixe, slash, méthode, headers de réécriture).
4. Considérer un identifiant complexe (GUID) comme une protection suffisante en soi, en oubliant les fuites possibles ailleurs dans l'application.
5. Se fier au seul code de statut HTTP (`200 OK`) sans vérifier le contenu réel ou l'effet concret de l'action.
6. Généraliser une technique propre à une technologie précise (ex. suffixe Spring) comme si elle s'appliquait à toutes les stacks.
7. Oublier de retester les étapes intermédiaires d'un processus métier en supposant que seule la dernière étape compte.

## 6. Remédiation

- **Deny by default + vérification serveur systématique par route/action** → corrige la cause racine ; une URL complexe ou un lien masqué ne sont qu'une réduction d'information divulguée, jamais une protection à part entière.
- **Centraliser la logique d'autorisation** (middleware/filtre transversal) → réduit le risque d'oubli dispersé dans le code, traite la cause racine structurelle.
- **Vérifier la propriété de la ressource à chaque action**, pas seulement le rôle → corrige spécifiquement l'IDOR (cause racine horizontale).
- **Revalider les permissions à chaque étape** d'un processus, sans supposer que les étapes précédentes ont été respectées → corrige la cause racine séquentielle.
- **Ne jamais fonder une décision d'autorisation sur une donnée modifiable côté client** (cookie, paramètre, `Referer`, header de géolocalisation) → corrige la cause racine des contournements par confiance implicite.
- **Éviter d'exposer des données sensibles dans une réponse de redirection/refus** → réduction de l'impact et de l'information divulguée, pas une correction en soi.
- **Tests de non-régression automatisés et audits réguliers** → défense en profondeur et détection ; n'empêche pas la faille d'exister, mais limite sa durée de vie en production.

## 7. Flashcards de rappel actif

### Flashcard 1 — Cause racine
**Question :** Pourquoi un contrôle d'accès basé uniquement sur la dissimulation d'une URL ou d'un lien UI est-il intrinsèquement défaillant ?
**Réponse :** Parce que l'autorisation n'est jamais vérifiée côté serveur ; quiconque devine ou découvre l'URL (robots.txt, JS, brute force) exécute l'action, car « caché » n'équivaut pas à « protégé ».

### Flashcard 2 — Reconnaissance
**Question :** Quel type de paramètre doit systématiquement déclencher un test IDOR ?
**Réponse :** Tout identifiant de ressource fourni par le client (numérique, nom de fichier, GUID) servant à retrouver un objet, car rien ne garantit que le serveur vérifie son appartenance à l'utilisateur courant.

### Flashcard 3 — Choix de méthode
**Question :** Pourquoi faut-il tester un IDOR sur les actions d'écriture et pas seulement en lecture ?
**Réponse :** Un contrôle peut exister en lecture et manquer en écriture (ou l'inverse) ; se limiter à GET masque des failles plus critiques comme la modification ou la suppression de données d'autrui.

### Flashcard 4 — Interprétation d'un résultat
**Question :** Un identifiant non prédictible (GUID) rend-il une ressource définitivement protégée contre l'IDOR ?
**Réponse :** Non. Cela empêche seulement le brute-force ; si le GUID fuite ailleurs (avis publics, historique partagé, export), l'absence de vérification serveur reste exploitable.

### Flashcard 5 — Distinction entre deux techniques
**Question :** Quelle différence entre une escalade verticale directe et le passage « horizontal → vertical » ?
**Réponse :** La verticale exploite directement une fonction réservée à un rôle supérieur ; le passage horizontal → vertical exploite une IDOR classique dont la cible ciblée ou rencontrée par hasard se trouve être un administrateur, changeant l'impact sans changer la technique.

### Flashcard 6 — Limites d'une méthode
**Question :** Pourquoi un test négatif sur l'en-tête `Referer` ne permet-il pas de conclure à l'absence de toute faille de contrôle d'accès ?
**Réponse :** Il écarte uniquement ce vecteur précis ; d'autres mécanismes (paramètres cachés, headers de réécriture, étapes séquentielles) peuvent rester vulnérables indépendamment.

### Flashcard 7 — Raisonnement après un échec
**Question :** Un accès direct à `/admin/deleteUser` échoue. Quelles variantes tester avant d'abandonner la piste ?
**Réponse :** Casse différente (`/ADMIN/DELETEUSER`), suffixe ajouté selon le framework, slash final ajouté/retiré, méthode HTTP alternative, et en-têtes de réécriture (`X-Original-URL`/`X-Rewrite-URL`).

### Flashcard 8 — Remédiation
**Question :** Pourquoi stocker le statut « admin » dans un cookie ou un paramètre après le login est-il une erreur, même si la vérification initiale est correcte ?
**Réponse :** Parce que cette donnée côté client est modifiable par l'utilisateur ; l'autorisation doit être revérifiée côté serveur à chaque requête sensible, jamais déduite d'un état figé en début de session.

## 8. Checklist mentale avant de conclure

1. Ai-je vérifié l'effet réel de l'action (donnée modifiée, action confirmée), pas seulement le code de statut HTTP ?
2. Ai-je testé toutes les méthodes HTTP pertinentes, pas seulement celle utilisée par l'UI ?
3. Ai-je exclu une explication alternative (cache, bug fonctionnel, faux positif d'outil) ?
4. Le résultat est-il reproductible avec un second compte ou une seconde session ?
5. Ai-je testé le vecteur à la fois en lecture et en écriture ?
6. En cas d'échec initial, ai-je essayé les variantes connues (casse, suffixe, slash, headers) avant de conclure « non vulnérable » ?
7. Ai-je identifié précisément la vérification serveur manquante, plutôt que de me contenter du symptôme observé ?
8. Quel est l'impact réel si j'exploite cette faille, et dois-je m'arrêter à la preuve de concept ?

---

## Référence technique complémentaire

**Exemple de bypass par header de réécriture :**
```http
POST / HTTP/1.1
Host: vulnerable-website.com
X-Original-URL: /admin/deleteUser
```
Le proxy frontal filtre sur `/`, mais certains backends (configurations IIS, Symfony) lisent et exécutent la valeur de `X-Original-URL` ou `X-Rewrite-URL` en interne.

**Exemple de bypass basé sur le `Referer` :**
```http
GET /admin/deleteUser?username=carlos HTTP/1.1
Host: vulnerable-website.com
Referer: https://vulnerable-website.com/admin
```

**Divergence d'interprétation d'URL — cas par cas :**
- Casse : le filtre bloque `/admin/deleteUser` mais le backend normalise en minuscules.
- Suffixe (frameworks type Spring avec `useSuffixPatternMatch` activé, désactivé par défaut depuis la version 5.3) : `/admin/deleteUser.anything` peut rester routé vers l'action d'origine.
- Slash final : `/admin/deleteUser` et `/admin/deleteUser/` parfois traités comme deux routes distinctes par le composant de sécurité.

**Découverte d'endpoints non liés dans l'UI :**
- `robots.txt` (répertoires exclus de l'indexation mais pas de l'accès).
- Outil *Discover content* de Burp Suite pour le brute-force de répertoires (`/admin`, `/administrator`, `/manage`).
- Outil *Find comments* de Burp Suite / lecture du JavaScript exécuté côté client, qui peut révéler des URLs d'administration même quand le lien n'est affiché qu'après vérification du rôle.

**IDOR sur fichiers statiques :** des ressources nommées de façon séquentielle (`/static/12144.txt`) sont énumérables en incrémentant/décrémentant l'identifiant si aucun contrôle d'accès applicatif n'est appliqué au niveau du serveur web.

**Bypass de géolocalisation :** VPN/proxy pour changer l'IP source, ou falsification directe des en-têtes `X-Forwarded-For` / `CF-IPCountry` quand l'application fait confiance à ces métadonnées transmises par un proxy frontal sans vérifier l'IP réelle du client.

## Points à vérifier

- Le comportement précis de `useSuffixPatternMatch` varie selon la version exacte de Spring Framework utilisée par la cible ; sur une stack récente, vérifier la configuration réelle avant de supposer cette technique applicable.
- L'efficacité des bypasses par header (`X-Forwarded-For`, `CF-IPCountry`, `X-Original-URL`) dépend entièrement de la configuration du proxy/CDN en amont : certains environnements neutralisent ou réécrivent ces en-têtes avant qu'ils n'atteignent le backend.
