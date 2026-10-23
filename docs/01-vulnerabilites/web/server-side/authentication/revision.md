# Broken Authentication — Fiche de révision

> **Notice d'utilisation.** Réponds à chaque question sans consulter le cours, la méthodologie d'exploitation ou la cheat sheet. Réponds à voix haute ou par écrit, puis compare ta réponse au corrigé situé après l'ensemble des questions. Ne regarde pas le corrigé avant d'avoir répondu.

> **Note sur le périmètre.** Le cours regroupe six variantes distinctes sous une même cause racine (énumération de comptes, bypass de rate-limiting, bypass 2FA, forge de cookie remember-me, faiblesses du workflow de reset, IDOR sur le changement de mot de passe). Les questions ci-dessous couvrent ces six variantes, mais privilégient le principe commun qui les relie plutôt qu'une liste exhaustive de chaque technique. OAuth/OIDC, les attaques d'infrastructure sur SMS/e-mail et l'exploitation détaillée de l'authentification HTTP Basic sont explicitement hors périmètre des documents source.

---

## 1. Comprendre

**1.** Quelle est la confusion de confiance unique qui sous-tend toutes les variantes de Broken Authentication présentées dans le cours ? Formule-la comme une question générale, indépendante de toute technique précise.

**2.** Quelle est la différence entre authentification et autorisation, et pourquoi la confusion entre les deux est-elle une source fréquente de vulnérabilités de ce type ?

**3.** Pourquoi le cours affirme-t-il que la majorité de ces failles ne relève pas d'un défaut cryptographique ? Donne un exemple tiré du cours où l'algorithme est correct mais le workflow reste exploitable.

**4.** En quoi l'authentification HTTP Basic illustre-t-elle une faiblesse structurelle différente de celles classées comme « erreurs de logique applicative » ?

## 2. Reconnaître

**5.** Tu observes qu'une requête de login avec un username probable renvoie un code 200 avec le message « Invalid password », tandis qu'un username manifestement inexistant renvoie un code 404 avec « User not found ». Qu'est-ce que cela rend plausible, et que dois-tu encore vérifier avant d'automatiser ce différentiel sur une wordlist ?

**6.** Un endpoint `POST /api/login` accepte un corps JSON et ne semble pas appliquer de validation de schéma stricte, d'après la documentation technique disponible. Qu'est-ce que cette seule observation rend plausible, et que ne prouve-t-elle pas encore ?

**7.** Après un login réussi en étape mot de passe, tu observes dans la réponse un `Set-Cookie: session=...; HttpOnly` suivi d'une redirection vers `/2fa-verify`. Qu'est-ce que la présence de ce cookie, à ce stade précis du workflow, rend plausible ?

**8.** Tu décodes un cookie `remember-me` en Base64 et obtiens une chaîne qui ressemble à un identifiant opaque de 32 caractères hexadécimaux. Est-ce un signal fort en faveur d'une forge possible ? Justifie.

## 3. Tester

**9.** Avant de tenter le moindre test de timing sur l'énumération de comptes, quelle action préalable est indispensable, et pourquoi un écart de latence mesuré une seule fois n'est-il pas suffisant ?

**10.** Tu veux tester si le 2FA est une vraie barrière serveur. Quel est le test minimal à effectuer immédiatement après l'étape mot de passe, et quelle condition faut-il respecter pour que ce test soit valide (non faussé) ?

**11.** Tu soupçonnes qu'un cookie `remember-me` encode le username et un timestamp. Quel test minimal permettrait d'isoler la composante liée au username de celle liée au timestamp ?

**12.** Tu disposes d'un compte authentifié et d'un second `user_id` de test connu. Quel est le test minimal pour vérifier si le changement de mot de passe dérive la cible de la session ou d'un paramètre client ?

## 4. Interpréter

**13.** Un `POST /account/change-password` avec un `user_id` substitué renvoie un code 200 avec un message de succès générique. Cela suffit-il à conclure à un IDOR confirmé ? Justifie.

**14.** Tu testes l'accès direct à `/dashboard` sans OTP sur un compte, et l'accès est refusé avec redirection vers `/2fa-verify`. Peux-tu conclure que le 2FA de l'application entière est hermétique ? Justifie.

**15.** Un test de password spraying avec un mot de passe commun sur 50 comptes ne produit aucune authentification réussie. Que peux-tu conclure, et que ne peux-tu pas conclure ?

**16.** Tu compares la structure d'un cookie `remember-me` sur deux comptes de longueurs de username différentes et n'observes aucune corrélation. Est-ce suffisant pour conclure que le jeton est un CSPRNG sans lien avec les données utilisateur ?

## 5. Exploiter

**17.** Tu as confirmé un canal d'énumération (variante 1) et un bypass de rate-limiting par tableau JSON (variante 2). Comment ces deux résultats s'articulent-ils pour construire une chaîne d'exploitation cohérente vers un ATO, plutôt que de rester deux constats isolés ?

**18.** Tu as confirmé que le cookie émis après l'étape mot de passe donne un accès direct à `/dashboard` sans OTP. Quelle est la preuve minimale qui transforme cette observation en preuve d'impact, et pourquoi un simple code 200 sur `/dashboard` ne suffit-il pas ?

**19.** Pour un même objectif (contourner le rate-limiting), le cours décrit trois vecteurs possibles : manipulation de structure JSON, fenêtre glissante, password spraying. Sur quel critère choisirais-tu l'ordre dans lequel les tester, et pourquoi ce choix n'est pas arbitraire ?

**20.** Tu as confirmé une IDOR sur le changement de mot de passe (variante 6) et, séparément, une absence de vérification du mot de passe actuel (variante 6b). Comment la combinaison de ces deux failles change-t-elle la gravité du scénario d'exploitation par rapport à chacune prise isolément ?

## 6. Déboguer et transférer

**21.** Le différentiel de l'étape d'énumération n'est jamais reproductible malgré plusieurs tentatives. Quelles sont les deux causes à distinguer, et quel test permet de les différencier ?

**22.** Le compteur de tentatives échouées ne semble pas s'incrémenter après soumission d'un tableau de mots de passe, mais aucun des mots de passe testés n'est accepté. Comment distingues-tu un bypass réel du rate-limiting d'une simple série de mots de passe incorrects ?

**23.** L'accès direct à `/dashboard` échoue sur un compte de test mais réussit sur un autre, alors que les deux comptes semblent similaires. Quelles causes possibles dois-tu envisager avant de conclure à une inconsistance applicative réelle ?

**24.** Tu maîtrises désormais le principe « cette décision repose-t-elle sur une donnée client ou sur un état garanti par le serveur ? » appliqué à l'authentification. Quels éléments de ce raisonnement transfères-tu tels quels à une autre famille de vulnérabilités (autorisation, gestion de session), et quels éléments techniques restent spécifiques à l'authentification, à ne pas généraliser ?

---

# Corrigé — Réponses attendues et raisonnement

### 1. Comprendre

**1.** Le serveur traite une donnée **fournie ou influençable par le client** (un paramètre, un en-tête HTTP, un état affiché côté front-end) comme si elle avait la valeur de vérité d'un **état de session garanti côté serveur**. Reformulée en question générale et transférable : « cette décision repose-t-elle sur quelque chose que je contrôle en tant que client, ou sur un fait que seul le serveur peut garantir ? »

**2.** **Authentification** = « Qui êtes-vous ? » (vérifie l'identité). **Autorisation** = « Qu'avez-vous le droit de faire ? » (vérifie les privilèges une fois l'identité établie). Les confondre est source fréquente de vulnérabilités car un contrôle d'authentification robuste peut coexister avec une **autorisation absente** sur certaines routes — l'application vérifie correctement qui se connecte, mais pas ce que cette identité a réellement le droit de faire une fois connectée.

**3.** Parce que la plupart des failles proviennent d'une **rupture de la chaîne de confiance côté serveur** dans l'enchaînement des étapes du workflow (erreur de logique applicative), et non d'un défaut de l'algorithme cryptographique employé. Exemple : le bypass 2FA par accès direct — l'algorithme TOTP/HOTP sous-jacent peut être parfaitement robuste, mais si le cookie de session émis après l'étape mot de passe est déjà pleinement privilégié et que l'état « 2FA validé » n'est pas revérifié à chaque requête sur une ressource protégée, l'exploitation ne touche jamais le calcul cryptographique du code OTP — elle contourne simplement l'étape de vérification.

**4.** HTTP Basic est listée parmi les **mécanismes intrinsèquement faibles** : identifiants transmis en clair (encodés, non chiffrés) à chaque requête, absence de protection CSRF native, absence de gestion de session, vulnérabilité structurelle à la force brute — des faiblesses de conception du protocole lui-même. Les **erreurs de logique applicative** (2FA contournable, IDOR sur reset) supposent au contraire un mécanisme cryptographique correct, mais un enchaînement d'étapes du workflow mal protégé.

*Ce qu'il serait prématuré de conclure :* qu'une application exempte de HTTP Basic est de ce fait protégée contre les erreurs de logique applicative — les deux catégories de failles sont indépendantes.

### 2. Reconnaître

**5.** Cela rend plausible un **canal auxiliaire d'énumération de comptes** (différentiel de code de statut et de message). Avant d'automatiser ce différentiel sur une wordlist, il faut vérifier la **reproductibilité** du signal (répéter sur plusieurs usernames et plusieurs essais) : un écart isolé reste ambigu, seul un écart reproductible sur plusieurs mesures constitue un signal fiable.

**6.** Cela rend plausible un **bypass du rate-limiting par manipulation de structure de requête** (variante 2). Cela ne prouve rien tant qu'un test actif (soumission d'un tableau de valeurs dans le champ `password`) n'a pas été effectué : l'absence de validation visible dans la documentation n'équivaut pas à un comportement confirmé empiriquement sur la cible.

**7.** Cela rend plausible l'hypothèse qu'un cookie **pleinement privilégié** soit déjà émis avant la validation du second facteur — c'est précisément l'indice de reconnaissance identifié par la méthodologie pour le bypass 2FA (variante 3). Cela ne confirme rien tant que l'accès direct à une ressource protégée n'a pas été testé sans soumission d'OTP.

**8.** Non. Une seule comparaison sur un seul compte ne suffit pas : la prévisibilité (ou son absence) ne peut être établie qu'après comparaison sur **plusieurs** comptes de test isolant les segments qui varient selon le username ou le timestamp. Un identifiant qui « ressemble » à de l'aléatoire sur un seul échantillon reste un échantillon trop faible pour conclure.

### 3. Tester

**9.** Établir un **comportement de référence** : effectuer un login avec un username connu et un mot de passe faux, répété plusieurs fois pour obtenir une plage de latence normale. C'est indispensable car la timing attack repose sur un **écart mesurable**, et le bruit réseau doit être caractérisé au préalable pour distinguer un écart significatif d'une simple variation normale.

**10.** Le test minimal : après soumission réussie du couple username/mot de passe (avant soumission de l'OTP), inspecter le `Set-Cookie` puis tenter un accès direct à une ressource protégée (`GET /dashboard`) sans jamais soumettre de code OTP. Condition indispensable : tester depuis une **session/navigateur neuf**, sans état d'authentification résiduel d'un test précédent — sinon le résultat est faussé.

**11.** Créer **deux comptes de test avec des usernames de longueurs différentes**, activer « se souvenir de moi » pour chacun, et comparer la structure Base64/Hex des cookies générés en isolant les segments qui varient uniquement selon le username.

*Réponse alternative acceptable :* ajouter un troisième compte avec un timestamp délibérément espacé pour isoler plus fermement la composante temporelle, utile si une suspicion subsiste après la première comparaison.

**12.** Authentifié sur son propre compte, soumettre `POST /account/change-password` en substituant le `user_id` du body par l'identifiant d'un autre compte de test connu, puis observer **quel compte voit effectivement son mot de passe modifié** (celui de la session, ou celui désigné par `user_id`).

### 4. Interpréter

**13.** Non. Il faut vérifier que l'acceptation correspond à une **modification réelle** (par exemple une connexion réussie sur le compte ciblé avec le nouveau mot de passe), et non à une réponse 200 générique sans effet — distinction entre un résultat potentiellement trompeur et une preuve d'impact réelle.

**14.** Non. Un refus sur une seule ressource ne garantit pas l'absence de bypass sur **d'autres** ressources protégées de l'application ; il faut répéter le test sur d'autres endpoints sensibles avant de conclure à une protection hermétique sur l'ensemble du périmètre.

**15.** On peut conclure à une **absence de succès sur l'échantillon testé** (ces 50 comptes, ce mot de passe précis) — pas à une absence de risque générale : le résultat dépend de la robustesse réelle des mots de passe des comptes cibles, hors du contrôle du testeur. C'est non concluant à ce stade, pas une infirmation définitive.

**16.** Non. Un échantillon de deux comptes est faible pour une conclusion définitive. Il est recommandé de répéter sur un troisième compte avec un timestamp délibérément espacé pour isoler plus fermement la composante temporelle avant de conclure à un CSPRNG sans lien avec les données utilisateur.

### 5. Exploiter

**17.** La liste de usernames valides obtenue par différentiel (variante 1) **réduit l'espace de recherche** du test de tableau JSON ou du brute force ciblé (variante 2) : au lieu de tester des mots de passe sur des comptes potentiellement inexistants, l'attaquant concentre son effort sur des comptes confirmés comme valides. Les deux résultats s'enchaînent logiquement — l'un alimente l'autre — plutôt que de rester deux constats isolés sans lien exploitable.

**18.** La preuve minimale est le **contenu retourné par la ressource protégée**, montrant des données propres au compte victime (non génériques) — confirmant un accès effectif. Un simple code 200 sur `/dashboard` ne suffit pas car il pourrait correspondre à une page générique ou une redirection cosmétique sans accès réel aux données spécifiques du compte ciblé.

**19.** Le critère est l'**ordre de dépendance logique** donné par la méthodologie : tester d'abord la manipulation de structure JSON (test direct, peu coûteux en requêtes), puis en cas d'échec la fenêtre glissante (qui suppose un défaut d'implémentation différent), puis en dernier recours le password spraying classique, pivot générique qui ne dépend d'aucune faille de rate-limiting spécifique. Chaque résultat négatif oriente logiquement vers le test suivant — le choix n'est donc pas arbitraire.

**20.** Isolément, l'IDOR (variante 6) suppose déjà d'être authentifié sur son propre compte pour cibler un autre `user_id`, tandis que l'absence de vérification du mot de passe actuel (variante 6b) est documentée comme un **facteur aggravant** d'une autre vulnérabilité de vol de session, pas comme un vecteur d'entrée autonome. Combinées : un attaquant disposant seulement d'une **session volée** (XSS, CSRF, poste partagé), sans connaître aucun mot de passe, peut directement évincer l'utilisateur légitime — la gravité du scénario combiné dépasse la somme des deux failles prises séparément.

### 6. Déboguer et transférer

**21.** Causes à distinguer : (a) les réponses sont réellement uniformisées (implémentation durcie) ; (b) le bruit réseau masque un écart réel mais faible. Test de diagnostic : comparer la **distribution complète** des temps de réponse (pas seulement une moyenne) entre compte valide et invalide, répétée un grand nombre de fois dans des conditions identiques.

**22.** Le bypass concerne le **comptage**, pas la **validité** des mots de passe testés. Vérification : soumettre volontairement le bon mot de passe dans le tableau testé, pour confirmer qu'il est bien évalué par le serveur. Si le bon mot de passe est accepté → bypass confirmé ; sinon → le tableau n'est peut-être pas itéré comme supposé, et il faut revoir l'hypothèse.

**23.** Causes possibles : (a) une configuration par rôle diffère entre les deux comptes (ex. un compte admin traité différemment) ; (b) un état de session résiduel a faussé un test précédent. Il faut comparer des comptes de **rôles identiques**, avec des **sessions fraîches**, avant de conclure à une inconsistance applicative réelle à investiguer séparément.

**24.** Se transfère : la nécessité d'établir une **référence** avant de chercher un différentiel ; la question centrale « donnée client vs état serveur garanti », applicable bien au-delà de l'authentification (autorisation, gestion de session, logique métier en général) ; la distinction entre **comportement anormal**, **vulnérabilité confirmée** et **impact démontré**. Reste spécifique à l'authentification, à ne pas généraliser : les seuils de latence indicatifs (~150 ms vs ~5 ms, liés au hachage bcrypt/argon2) et l'itération non comptabilisée d'un tableau JSON par certains rate-limiters, qui est une faiblesse d'implémentation propre à certains frameworks backend non nommés par le cours — à vérifier empiriquement sur chaque cible, jamais supposée par défaut.

### Barème d'auto-évaluation

- **0 — Bloqué :** impossible de fournir une réponse pertinente sans consulter les notes.
- **1 — Avec aide :** réponse partielle ou obtenue après consultation d'un indice.
- **2 — Autonome sur un cas connu :** réponse correcte et raisonnement cohérent dans un scénario familier.
- **3 — Transfert :** réponse correcte dans une situation modifiée, avec justification et interprétation des limites.

La note porte autant sur le **raisonnement** que sur la conclusion. Une réponse correcte obtenue par hasard, ou sans pouvoir justifier les conditions et les limites, ne doit pas être notée comme une maîtrise complète.

---

# Cartes de révision — Broken Authentication

## Comprendre

**Recto C1.** Quelle question unique permet de tester, à n'importe quelle étape du cycle de vie de l'authentification, si une décision est exploitable ?
**Verso C1.** « Cette décision repose-t-elle sur une donnée que je contrôle en tant que client, ou sur un état que seul le serveur peut garantir ? »

**Recto C2.** Quelle est la différence entre authentification et autorisation ?
**Verso C2.** Authentification = vérifier l'identité revendiquée (« Qui êtes-vous ? »). Autorisation = vérifier les privilèges une fois l'identité établie (« Qu'avez-vous le droit de faire ? »). Les confondre laisse parfois une authentification robuste sans contrôle d'accès équivalent sur certaines routes.

**Recto C3.** Pourquoi le bypass 2FA par accès direct ne remet-il pas en cause la robustesse de l'algorithme TOTP/HOTP ?
**Verso C3.** Parce que la faille se situe dans l'enchaînement des étapes du workflow (un cookie pleinement privilégié émis avant validation de l'OTP, non revérifié à chaque requête), pas dans le calcul cryptographique du code lui-même — c'est une erreur de logique applicative, pas un défaut cryptographique.

## Reconnaître

**Recto R1.** Un code 200 « Invalid password » vs un code 404 « User not found » selon le username testé. Qu'est-ce que cela rend plausible, sans le confirmer à lui seul ?
**Verso R1.** Un canal auxiliaire d'énumération de comptes (différentiel de statut/message) — à confirmer par répétition sur plusieurs usernames avant de l'automatiser sur une wordlist.

**Recto R2.** Un cookie de session apparaît dans la réponse juste après l'étape mot de passe, avant la validation du code OTP. Que cela suggère-t-il ?
**Verso R2.** Que ce cookie pourrait déjà être pleinement privilégié, ce qui ferait du 2FA une simple façade côté client — à vérifier par un test d'accès direct à une ressource protégée sans soumettre l'OTP.

**Recto R3.** Un test de password spraying sur 50 comptes ne produit aucune connexion réussie. Cela infirme-t-il l'existence de mots de passe faibles dans l'application ?
**Verso R3.** Non — cela montre seulement l'absence de succès sur l'échantillon de comptes et de mots de passe testés ; cela dépend de la robustesse réelle des mots de passe, hors du contrôle du testeur, donc non concluant à ce stade.

## Tester

**Recto T1.** Avant un test de timing sur l'énumération de comptes, quelle action préalable est indispensable ?
**Verso T1.** Établir une plage de latence normale en répétant plusieurs fois le login avec un username connu et un mot de passe faux — sans cette référence, un écart isolé ne peut pas être distingué du bruit réseau.

**Recto T2.** Quel test minimal vérifie si le 2FA est une vraie barrière serveur ou une simple étape d'interface ?
**Verso T2.** Après succès de l'étape mot de passe (avant soumission de l'OTP), tenter un accès direct à une ressource protégée (`GET /dashboard`) — depuis une session fraîche, sans état résiduel d'un test précédent.

**Recto T3.** Comment isoler, dans un cookie remember-me, la composante liée au username de celle liée au timestamp ?
**Verso T3.** Créer deux comptes de test avec des usernames de longueurs différentes, comparer la structure des cookies générés, et au besoin ajouter un troisième compte avec un timestamp délibérément espacé pour isoler la composante temporelle.

## Interpréter

**Recto I1.** Un `user_id` substitué dans un changement de mot de passe renvoie un code 200 avec message de succès. Cela suffit-il à confirmer un IDOR ?
**Verso I1.** Non — il faut vérifier que le mot de passe du compte ciblé a réellement changé, par exemple via une tentative de connexion réussie sur ce compte, pour écarter une réponse de succès trompeuse sans effet réel.

**Recto I2.** L'accès direct à `/dashboard` sans OTP échoue sur un compte testé. Peut-on conclure que le 2FA de toute l'application est hermétique ?
**Verso I2.** Non — un refus sur une seule ressource ne garantit pas l'absence de bypass sur d'autres ressources protégées ; il faut répéter le test sur d'autres endpoints sensibles avant de conclure.

**Recto I3.** Aucune corrélation n'apparaît en comparant un cookie remember-me sur deux comptes. Est-ce suffisant pour conclure à un CSPRNG sans lien avec les données utilisateur ?
**Verso I3.** Non — un échantillon de deux comptes est faible ; il est recommandé de tester un troisième compte avec un timestamp délibérément espacé avant de conclure à l'absence de structure déductible.

## Exploiter

**Recto E1.** Comment le résultat de l'étape d'énumération (variante 1) alimente-t-il concrètement l'étape de bypass du rate-limiting (variante 2) ?
**Verso E1.** La liste de usernames valides obtenue par différentiel réduit l'espace de recherche : le test de tableau JSON ou le brute force ciblé se concentre alors sur des comptes confirmés, au lieu de tester des mots de passe sur des comptes potentiellement inexistants.

**Recto E2.** Pourquoi un simple code 200 sur `/dashboard`, obtenu après un bypass 2FA, ne suffit-il pas comme preuve d'impact ?
**Verso E2.** Parce qu'il pourrait correspondre à une page générique sans contenu réel. La preuve d'impact exige un contenu retourné propre au compte ciblé (données spécifiques, non génériques), démontrant un accès effectif.

**Recto E3.** Pourquoi une IDOR sur le changement de mot de passe et une absence de vérification du mot de passe actuel deviennent-elles plus graves une fois combinées ?
**Verso E3.** Isolément, l'IDOR suppose déjà un compte authentifié, et l'absence de vérification du mot de passe actuel n'est qu'un facteur aggravant d'un vol de session. Combinées : un attaquant disposant seulement d'une session volée (sans connaître aucun mot de passe) peut directement évincer l'utilisateur légitime.

## Déboguer et transférer

**Recto D1.** Le différentiel d'énumération n'est jamais reproductible malgré plusieurs tentatives. Quelles deux causes distinguer, et comment ?
**Verso D1.** (a) réponses réellement uniformisées ; (b) bruit réseau masquant un écart réel mais faible. Comparer la distribution complète des temps de réponse (pas seulement une moyenne), répétée en conditions identiques.

**Recto D2.** Le compteur de tentatives échouées ne semble pas s'incrémenter après un tableau de mots de passe, mais aucun n'est accepté. Comment distinguer un bypass réel d'une série de mots de passe simplement incorrects ?
**Verso D2.** Soumettre volontairement le bon mot de passe dans le tableau testé — s'il est accepté, le bypass du comptage est confirmé ; sinon, le tableau n'est peut-être pas itéré comme supposé, et il faut revoir l'hypothèse.

**Recto D3.** Quel principe de raisonnement de l'authentification se transfère tel quel à d'autres familles de vulnérabilités (autorisation, gestion de session), et quel élément technique reste spécifique à ne pas généraliser ?
**Verso D3.** Se transfère : la question « donnée client vs état serveur garanti » et la distinction entre comportement anormal, vulnérabilité confirmée et impact démontré. Reste spécifique : les seuils de latence indicatifs (~150 ms vs ~5 ms liés à bcrypt/argon2) et l'itération non comptabilisée d'un tableau JSON par certains rate-limiters — à vérifier empiriquement sur chaque cible, le cours ne nommant pas de frameworks précis.

---

## Organisation des révisions

### Première tentative

1. Répondre sans consulter les autres supports.
2. Marquer les questions bloquantes.
3. Noter les réponses incomplètes ou reposant sur une supposition.
4. Consulter le corrigé seulement après avoir répondu.
5. Évaluer chaque réponse de 0 à 3.

### Après correction

Pour chaque erreur, identifier sa nature : mécanisme mal compris, condition oubliée, mauvais choix de test, résultat mal interprété, chaîne d'exploitation incomplète, diagnostic insuffisant, ou difficulté à transférer les connaissances.

| Difficulté | Support à retravailler |
|---|---|
| Je ne comprends pas pourquoi la faille existe. | Cours de référence (section 1 et synthèse de révision finale) |
| Je ne sais pas quoi tester ensuite. | Méthodologie d'exploitation (sections 3 et 4) |
| Je connais le test, mais j'oublie la syntaxe exacte. | Cheat sheet (sections 3 à 5) |
| Je n'arrive pas à interpréter mes essais. | Méthodologie (sections 3.2, 7 et 8) |
| Je reproduis un cas connu, mais pas une variante. | Cours, puis méthodologie (section 10 — leçons transférables) |

Revoir en priorité la partie responsable du blocage, puis tenter à nouveau de répondre de mémoire — ne pas relire l'intégralité des notes après chaque erreur.

### Révisions espacées

- Jour 0 : première récupération active.
- Jour 1 : révision des éléments difficiles.
- Jour 3 : nouvelle tentative sans notes.
- Jour 7 : révision des erreurs persistantes.
- Jour 14 : questions de transfert.
- Jour 30 : vérification globale de la maîtrise.

Ces intervalles sont indicatifs : les cartes échouées doivent être revues plus tôt que les cartes maîtrisées. Un calendrier fixe ne garantit pas, à lui seul, la mémorisation.
