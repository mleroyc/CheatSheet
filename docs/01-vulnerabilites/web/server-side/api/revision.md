# Server-Side Parameter Pollution (SSPP) — Fiche de révision

> **Notice d'utilisation.** Réponds à chaque question sans consulter le cours, la méthodologie d'exploitation ou la cheat sheet. Réponds à voix haute ou par écrit, puis compare ta réponse au corrigé situé après l'ensemble des questions. Ne regarde pas le corrigé avant d'avoir répondu.

> **Limite des sources.** Cette fiche s'appuie sur trois documents : le cours de référence, la méthodologie d'exploitation SSPP et la cheat sheet. Le Mass Assignment et l'exploitation détaillée du détournement de méthodes HTTP ne sont traités qu'en tant que mécanismes voisins (le cours renvoie à une fiche dédiée pour leur exploitation applicative complète) ; ils n'apparaissent donc pas comme sujet principal des questions ci-dessous.

---

## 1. Comprendre

**1.** Quel est le défaut structurel précis, commun à toutes les variantes de la SSPP, qui rend cette vulnérabilité possible ?

**2.** Quelle condition architecturale est strictement indispensable à l'existence d'une SSPP, et en quoi un simple reverse-proxy HTTP (load balancer) ne suffit-il pas à la remplir ?

**3.** En quoi le principe de la SSPP est-il comparable à celui d'une injection SQL ? Qu'est-ce qui joue, ici, le rôle du « code » habituellement injecté dans une requête SQL ?

**4.** Pourquoi deux applications présentant toutes deux une architecture gateway → microservice peuvent-elles réagir différemment au même payload structurant (`%23`, `%26`, `../`, `"`) ?

## 2. Reconnaître

**5.** Tu observes qu'une requête vers `/api/v1/profile?name=alice` répond en moyenne en 87 ms, alors qu'une requête vers un autre endpoint du même service répond en 12 ms, et qu'un en-tête interne apparaît occasionnellement dans des erreurs 500. Qu'est-ce que ces indices rendent plausible, et que ne prouvent-ils pas encore ?

**6.** En testant `?name=alice%23` sur un endpoint, tu constates qu'un comportement normalement associé à un paramètre `internal_param` placé après `name` dans la requête légitime disparaît. Quel mécanisme pourrait expliquer cette observation, et quelle autre explication resterait possible ?

**7.** L'injection d'un guillemet dans un champ `name` d'un corps JSON produit une erreur 500 générique, sans message détaillé. Peux-tu conclure à une SSPP confirmée ? Justifie.

**8.** Tu trouves un fichier `openapi.yaml` exposé qui documente une route `/internal/admin/dashboard` jamais reliée au front-end, à côté de routes publiques `/api/v1/...`. Qu'est-ce que cette découverte rend plausible pour la suite de l'audit, sans la confirmer à elle seule ?

## 3. Tester

**9.** Tu soupçonnes qu'un paramètre de query string `name` est relayé par une gateway vers un microservice interne, mais tu n'as encore établi aucune référence. Quelle est la toute première action à effectuer avant d'injecter quoi que ce soit, et pourquoi est-elle indispensable ?

**10.** Tu as confirmé l'architecture gateway/microservice et établi ta référence sur `?name=alice`. Quel est le test minimal suivant, quelle hypothèse vérifie-t-il, et quel résultat confirmerait cette hypothèse ?

**11.** Un segment de chemin `/users/{nom}` semble repris tel quel dans une route interne. Quelle condition dois-tu vérifier avant de tenter une traversée encodée, et pourquoi l'encodage du caractère `/` est-il indispensable au test (pas seulement une bonne pratique) ?

**12.** Tu disposes de trois surfaces candidates (query string, chemin REST, corps JSON) sur le même endpoint, mais d'un temps d'audit limité. Sur quel critère choisirais-tu la surface à tester en priorité ?

## 4. Interpréter

**13.** Après injection de `%26role=admin`, le contenu retourné par l'endpoint change de façon visible. Qu'est-ce que cela démontre avec certitude, et qu'est-ce que cela ne démontre pas encore ?

**14.** Tu répètes le test de troncature `%23` cinq fois sur la même ressource et obtiens trois résultats positifs et deux négatifs. Que peux-tu conclure de cette irrégularité, et quelle vérification mènerais-tu avant d'interpréter plus loin ?

**15.** Un test de surcharge de paramètres (`?name=legitime&name=injecte`) ne produit aucun effet observable. Cette absence d'effet permet-elle d'exclure une SSPP par surcharge sur l'ensemble de l'infrastructure ? Justifie.

**16.** Une injection `%2f..%2f..%2fadmin%2fdashboard` renvoie un code 404. Que peux-tu conclure, et pourquoi un 404 n'est-il pas nécessairement une preuve d'absence de vulnérabilité ?

## 5. Exploiter

**17.** Tu as confirmé qu'un `%26role=admin` injecté change le comportement applicatif de façon claire, mais cet effet ne correspond à aucun gain concret identifiable (pas d'élévation de droits visible, pas d'accès à une donnée sensible). Que te manque-t-il pour transformer cette observation en preuve d'impact exploitable ?

**18.** Pour un même point d'entrée (segment de chemin `/users/{nom}`), tu peux tenter soit une traversée encodée vers une route interne, soit une injection de caractères structurants dans un champ JSON voisin. Sur quels éléments de reconnaissance baserais-tu le choix de la chaîne d'exploitation la plus prometteuse ?

**19.** Tu as identifié, par un test de surcharge, que le backend interne conserve la dernière occurrence d'un paramètre dupliqué. Comment cette information change-t-elle la construction de ta prochaine requête d'exploitation par rapport à une injection `%26` simple ?

**20.** Quelle est la différence entre une « preuve de comportement vulnérable » et une « preuve d'impact » dans le cadre d'une SSPP, et laquelle des deux un rapport d'audit doit-il retenir comme concluante ?

## 6. Déboguer et transférer

**21.** Aucun changement de comportement n'apparaît après l'injection de `%23` ni de `%26` sur un point d'entrée que tu pensais prometteur. Quelles causes possibles dois-tu distinguer, et quel test simple permet de différencier un filtrage en amont (WAF/proxy) d'un encodage correct côté gateway ?

**22.** Le même test de troncature `%23` fonctionne sur l'endpoint `/api/v1/profile` mais pas sur `/api/v1/orders`, alors que les deux semblent passer par la même gateway. Quelle explication la méthodologie privilégie-t-elle, et que dois-tu éviter de conclure ?

**23.** Une surcharge de paramètres confirmée une première fois ne se reproduit pas à l'identique lors d'une nouvelle tentative, dans des conditions apparemment identiques. Quelle hypothèse vérifierais-tu en premier avant de qualifier ce résultat de faux positif ?

**24.** Tu maîtrises désormais la démarche « référence → injection minimale → différentiel → isolation de la cause → effet choisi » sur la SSPP. Quels éléments de ce raisonnement transfères-tu tels quels à une autre vulnérabilité d'injection, et lesquels restent spécifiques à la SSPP, à ne pas généraliser ?

---

# Corrigé — Réponses attendues et raisonnement

### 1. Comprendre

**1.** Le défaut est que la gateway fait confiance à une donnée fournie par le client et la **concatène directement** (sans encodage ni validation) dans l'URL, le chemin ou le corps de la requête interne qu'elle construit pour le microservice, en traitant cette donnée comme une simple valeur alors qu'elle peut devenir **structurante** pour la syntaxe de cette requête interne.

**2.** La présence d'une **application intermédiaire** (gateway applicative) qui **reconstruit** une requête à destination d'un **composant backend distinct**, à partir de données contrôlées par le client. Un reverse-proxy HTTP classique (load balancer) relaie le trafic sans reconstruire de requête à partir de valeurs utilisateur : il n'a donc pas de logique de concaténation exploitable. Seule une gateway qui réassemble activement une nouvelle requête est pertinente.

**3.** Dans les deux cas, un composant fait confiance à une donnée utilisateur et l'insère sans l'échapper dans un langage structuré qu'elle interprète ensuite (SQL pour l'injection SQL, la syntaxe d'URL/JSON/XML pour la SSPP). Ici, ce sont les **caractères structurants** du canal cible (`#`, `&`, `../`, `"`, `{`, `}`, `<`, `>`) qui jouent le rôle de « code » : ils ne sont pas une valeur de donnée mais modifient la structure de la requête interne.

**4.** Parce que l'effet dépend de la **technologie backend interne** consommant la requête polluée : le comportement de résolution des paramètres dupliqués diffère par exemple entre PHP (dernière occurrence), ASP.NET (combinaison) et Node.js/Express (première occurrence selon le middleware) — et plus généralement, la façon dont chaque microservice construit, normalise ou sérialise la requête n'est pas garantie identique sur toute l'infrastructure.

*Ce qu'il serait prématuré de conclure :* qu'un comportement observé sur un backend se généralise à toute l'infrastructure sans vérification empirique.

### 2. Reconnaître

**5.** Ces indices (latence anormale, en-tête révélant un composant interne) rendent **plausible l'existence d'une architecture gateway → microservice**, prérequis indispensable à la SSPP. Ils ne prouvent pas encore qu'une concaténation non sécurisée a lieu : il s'agit seulement d'un indice architectural, pas d'un indice de vulnérabilité.

**6.** Le mécanisme compatible est que la gateway **décode** le `#` fourni puis le **réinjecte tel quel** dans la requête interne, provoquant une troncature de tout ce qui suit (troncature SSPP via `%23`). Une autre explication resterait possible : absence totale de lien entre le paramètre testé et `internal_param` dans la construction réelle de la requête, ou architecture ne correspondant pas à l'hypothèse d'une gateway concaténante.

**7.** Non. Un code 500 générique peut simplement indiquer une **mauvaise gestion d'entrée côté gateway elle-même** (un simple crash de parsing), sans aucune preuve que la donnée ait atteint un microservice interne sous une forme modifiée. Il faut un effet **cohérent avec la prise en compte de la donnée par un composant interne**, pas seulement une erreur générique.

**8.** Cette découverte rend plausible l'existence de **routes internes non destinées à être exposées**, donc d'une architecture à plusieurs composants — c'est un indice de reconnaissance utile (comme pour l'étape 1 de la méthodologie), mais elle ne confirme ni l'architecture gateway/microservice avec certitude, ni a fortiori une SSPP : il reste à vérifier que ces routes sont effectivement atteignables via une concaténation non sécurisée.

### 3. Tester

**9.** Établir la **requête de référence légitime** (méthode, chemin, paramètres, corps, en-têtes `Content-Type`/`Accept`) et observer son comportement normal (code de réponse, structure, champs retournés), si possible répétée sur plusieurs ressources. C'est indispensable car la SSPP se détecte **par différentiel** : sans connaître le comportement normal exact, il est impossible de distinguer un effet de pollution réel d'une variation normale de l'application.

**10.** Le test minimal suivant est l'injection de `%23` en fin de valeur du paramètre testé (`?name=alice%23`). Il vérifie l'hypothèse que la gateway décode le `#` et le réinjecte sans ré-encodage dans la requête interne. Un résultat confirmant l'hypothèse est un comportement cohérent avec la **suppression effective** d'un effet normalement associé à un paramètre interne supposé suivre la valeur injectée.

**11.** Il faut vérifier qu'un **segment de chemin est effectivement concaténé sans normalisation préalable** par la gateway (hypothèse que la résolution des `../` a lieu côté microservice, après construction de la requête). L'encodage `%2f` est indispensable — pas seulement une bonne pratique — car un `/` brut serait immédiatement interprété par le **serveur HTTP lui-même** comme un séparateur de chemin, sans jamais atteindre la logique de concaténation de la gateway sous la forme voulue : le test ne vérifierait alors rien d'utile.

**12.** Le critère est la **cohérence avec les indices de reconnaissance déjà recueillis** (mots-clés `admin`/`internal`/`debug` dans un bundle JS ou une documentation, présence de paramètres internes suspectés après un paramètre candidat, etc.) : prioriser la surface pour laquelle on dispose déjà d'un indice concret plutôt que de tester les trois surfaces de façon générique et simultanée.

*Réponses alternatives acceptables :* commencer par la surface la plus simple à isoler (query string) si aucun indice ne départage les trois, à condition de le justifier explicitement comme un choix par défaut et non comme une règle universelle.

### 4. Interpréter

**13.** Cela démontre la **capacité à injecter un paramètre interne non prévu** et un comportement cohérent avec la définition de la SSPP (signal fort). Cela ne démontre **pas encore** un impact exploitable choisi et vérifiable : il faut confirmer avec un paramètre dont l'effet est vérifiable sans ambiguïté, et écarter une explication accidentelle.

**14.** Une irrégularité de ce type ne permet pas de conclure directement : il faut d'abord déterminer si elle provient d'un **bruit applicatif normal** (cache, répartition de charge entre plusieurs instances, non-déterminisme) plutôt que d'un effet réel de l'injection. La vérification à mener est de **répéter le test dans des conditions strictement identiques** (même session, même ressource) pour isoler la variable.

**15.** Non. Un résultat négatif sur un endpoint ne permet pas de généraliser à toute l'infrastructure : le cours précise explicitement que le comportement de résolution des paramètres dupliqués doit être **documenté et testé pour chaque technologie backend interne**, qui peut différer d'un microservice à l'autre.

**16.** On peut seulement conclure qu'**aucun effet cohérent avec l'atteinte de la route ciblée n'a été observé sur ce test précis**. Un 404 n'est pas nécessairement une preuve d'absence de vulnérabilité car il peut correspondre à un **comportement volontairement trompeur du serveur** (signalé par le cours à propos du fuzzing de chemins en général) ; il ne faut pas l'interpréter automatiquement sans vérification complémentaire.

### 5. Exploiter

**17.** Il manque une **preuve d'impact** : il faut reprendre la reconnaissance pour cibler un paramètre, une route ou une clé **précis et choisis** (plutôt qu'un test générique) dont l'effet est vérifiable sans ambiguïté — par exemple un paramètre identifié comme sensible dans la documentation ou les bundles JS — puis reproduire l'injection sur cette cible précise pour obtenir un effet métier choisi, et non accidentel.

**18.** Le choix se base sur les **indices de reconnaissance déjà disponibles** : si un mot-clé comme `admin` a été repéré dans un bundle JS ou une documentation suggérant une route interne précise, la traversée de chemin est plus prometteuse ; si c'est plutôt un champ texte relayé sans échappement visible qui a été identifié (ex. erreur de parsing JSON lors d'un test précédent), l'injection structurée est plus prometteuse. Le choix n'est donc jamais arbitraire mais dépend de ce qui a déjà été observé.

**19.** Connaître la règle de résolution permet de **positionner stratégiquement** le paramètre injecté (avant ou après le paramètre légitime) pour garantir que c'est la **valeur de l'attaquant** qui sera retenue par le composant interne, plutôt que d'injecter `%26` sans savoir si la valeur ajoutée prévaudra sur une éventuelle valeur légitime de même nom déjà présente dans la requête interne.

**20.** Une **preuve de comportement vulnérable** démontre que la gateway relaie une donnée polluée vers un composant interne (ex. troncature confirmée). Une **preuve d'impact** démontre qu'un effet de sécurité concret et choisi en résulte (ex. accès à une route interne précise, modification d'une valeur sensible). C'est la seconde qui doit être recherchée et retenue avant de considérer le test comme concluant pour un rapport d'audit.

### 6. Déboguer et transférer

**21.** Les causes à distinguer sont : (a) la gateway encode correctement la valeur avant concaténation ; (b) le caractère n'a pas atteint la gateway sous forme décodée (filtrage WAF/proxy en amont) ; (c) il n'y a pas d'architecture gateway/microservice sur ce point d'entrée. Le test de diagnostic est de renvoyer la même valeur avec un **double encodage** (`%2523`) : cela permet de distinguer un simple encodage/décodage normal d'un filtrage actif.

**22.** La méthodologie privilégie l'explication que **chaque endpoint peut être géré par un microservice interne différent**, avec une technologie et un comportement de parsing distincts. Il faut éviter de conclure à une **infrastructure homogène** : le bon réflexe est de documenter le comportement **par endpoint**, pas de généraliser un résultat positif ou négatif à toute l'API.

**23.** Il faut d'abord vérifier si la variation provient d'un **état applicatif changeant** (cache expiré, session différente, plusieurs instances backend en répartition de charge) plutôt que de l'injection elle-même, en reproduisant le test dans des **conditions strictement identiques** (même session, même ressource) avant de le traiter comme un faux positif.

**24.** Se transfère : la démarche générale « établir une référence → injecter un élément minimal → observer un différentiel → isoler la cause exacte → construire un effet choisi plutôt qu'accidentel », applicable à toute vulnérabilité dépendant d'un comportement de parsing ou d'assemblage de données, ainsi que la distinction entre preuve de comportement anormal, vulnérabilité confirmée et exploitation à impact démontré. Reste spécifique à la SSPP, à ne pas généraliser : les règles précises de résolution des paramètres dupliqués par backend (PHP/ASP.NET/Node.js), et le fait que l'exploitation se manifeste typiquement **en aval**, au niveau du microservice, sans être visible dans la réponse immédiate de la gateway — une spécificité qui ne s'applique pas nécessairement à d'autres classes d'injection où l'effet est directement visible.

### Barème d'auto-évaluation

- **0 — Bloqué :** impossible de fournir une réponse pertinente sans consulter les notes.
- **1 — Avec aide :** réponse partielle ou obtenue après consultation d'un indice.
- **2 — Autonome sur un cas connu :** réponse correcte et raisonnement cohérent dans un scénario familier.
- **3 — Transfert :** réponse correcte dans une situation modifiée, avec justification et interprétation des limites.

La note porte autant sur le **raisonnement** que sur la conclusion. Une réponse correcte obtenue par hasard, ou sans pouvoir justifier les conditions et les limites, ne doit pas être notée comme une maîtrise complète.

---

# Cartes de révision — Server-Side Parameter Pollution (SSPP)

## Comprendre

**Recto C1.** Quelle est la différence entre une gateway qui « concatène » une donnée utilisateur et une gateway qui l'assemble de façon « structurée » ?
**Verso C1.** Concaténation = insertion brute d'une chaîne dans l'URL/le chemin/le corps, sans encodage : la donnée peut modifier la syntaxe de la requête interne. Assemblage structuré = bibliothèque d'URL typée ou sérialiseur JSON/XML dédié, qui échappe automatiquement les caractères spéciaux et neutralise l'injection.

**Recto C2.** Pourquoi un simple reverse-proxy HTTP (load balancer) ne suffit-il pas comme prérequis à une SSPP ?
**Verso C2.** Il relaie le trafic sans reconstruire de requête interne à partir de données utilisateur. Seule une gateway applicative qui réassemble une nouvelle requête (URL, chemin ou corps) à partir de valeurs contrôlées par le client peut être vulnérable à la SSPP.

**Recto C3.** Quelle condition explique qu'une même technique SSPP réussisse sur un endpoint et échoue sur un autre de la même API ?
**Verso C3.** Chaque endpoint peut être relayé vers un microservice interne différent, avec une technologie et un comportement de parsing propres (ex. règle de résolution des paramètres dupliqués différente selon le backend).

## Reconnaître

**Recto R1.** Quel type d'indice, observé dans les en-têtes ou la latence d'une réponse, suggère l'existence d'une architecture gateway → microservice ?
**Verso R1.** Un en-tête révélant un composant interne distinct, une latence anormale par rapport aux autres endpoints, ou un message d'erreur mentionnant un service interne — aucun indice isolé ne confirme l'architecture, mais chacun la rend plausible.

**Recto R2.** Un code 500 générique apparaît après l'injection d'un guillemet dans un champ JSON. Est-ce un signal suffisant pour confirmer une SSPP ?
**Verso R2.** Non — cela peut indiquer un simple crash de parsing côté gateway elle-même, sans preuve que la donnée ait atteint un microservice interne sous forme modifiée. Il faut un effet cohérent en aval, pas seulement une erreur générique.

**Recto R3.** Une absence totale de changement de comportement après injection d'un caractère structurant prouve-t-elle l'absence de SSPP ?
**Verso R3.** Non — l'exploitation de la SSPP se manifeste souvent en aval, au niveau du microservice, et peut rester invisible depuis la réponse immédiate de la gateway.

## Tester

**Recto T1.** Avant d'injecter le moindre caractère structurant sur un point d'entrée candidat, quelle action est indispensable ?
**Verso T1.** Établir une référence : capturer la requête légitime (méthode, chemin, paramètres, corps, en-têtes) et son comportement normal, répétée si besoin, pour pouvoir ensuite détecter un différentiel fiable.

**Recto T2.** Pourquoi faut-il encoder le `/` en `%2f` pour tester une traversée de chemin via la gateway, plutôt que d'envoyer un `/` brut ?
**Verso T2.** Un `/` non encodé serait immédiatement interprété par le serveur HTTP lui-même comme un séparateur de chemin, avant même d'atteindre la logique de concaténation de la gateway — le test ne vérifierait alors rien d'utile.

**Recto T3.** Quel est le test minimal permettant de déduire la règle de résolution d'un backend interne face à un paramètre dupliqué ?
**Verso T3.** Envoyer deux fois le même nom de paramètre avec des valeurs différentes (`?name=legitime&name=injecte`) et observer, via le comportement applicatif, laquelle des deux valeurs est retenue — ou si elles sont combinées.

## Interpréter

**Recto I1.** Un effet applicatif change après injection de `%26role=admin`. Cela suffit-il à prouver un impact exploitable ?
**Verso I1.** Non — cela démontre la capacité à injecter un paramètre interne non prévu (preuve de comportement vulnérable), mais il faut encore un effet métier choisi et vérifiable pour parler de preuve d'impact.

**Recto I2.** Un test de troncature `%23` donne un résultat positif une fois sur deux sur la même ressource. Que faire avant d'interpréter ce résultat comme une SSPP confirmée ?
**Verso I2.** Répéter le test plusieurs fois dans des conditions strictement identiques (même session, même ressource) pour écarter une instabilité applicative (cache, répartition de charge) avant de le retenir comme preuve.

**Recto I3.** Un code 404 apparaît après une tentative de traversée de chemin encodée. Peut-on en conclure que la route interne visée n'existe pas ?
**Verso I3.** Pas nécessairement — un 404 peut aussi correspondre à un comportement volontairement trompeur du serveur ; il ne doit pas être interprété automatiquement comme une absence de vulnérabilité sans vérification complémentaire.

## Exploiter

**Recto E1.** Quelle est la différence entre une preuve de comportement vulnérable et une preuve d'impact, pour une SSPP ?
**Verso E1.** La première démontre que la gateway relaie une donnée polluée vers un composant interne (ex. troncature confirmée). La seconde démontre qu'un effet de sécurité concret et choisi en résulte (ex. accès à une route interne précise, modification d'une valeur sensible).

**Recto E2.** La règle de résolution d'un backend interne en cas de paramètre dupliqué est connue (ex. PHP : dernière occurrence conservée). Comment l'utiliser pour maximiser l'effet d'une injection `%26` ?
**Verso E2.** Positionner stratégiquement le paramètre injecté (avant ou après le paramètre légitime) selon la règle déduite, pour garantir que la valeur de l'attaquant soit celle effectivement retenue par le composant interne.

**Recto E3.** Pourquoi une chaîne d'exploitation SSPP ne doit-elle pas cibler un nom de paramètre ou une route choisis au hasard ?
**Verso E3.** Parce qu'un effet accidentel ou arbitraire ne constitue pas une preuve d'impact exploitable — la cible (paramètre, route, clé) doit être choisie à partir des indices de reconnaissance (mots-clés `admin`/`internal`/`debug`, documentation) pour produire un effet choisi et vérifiable.

## Déboguer et transférer

**Recto D1.** Aucune différence de comportement n'apparaît après injection de `%23`/`%26`. Quel test permet de distinguer un filtrage en amont (WAF/proxy) d'un encodage correct côté gateway ?
**Verso D1.** Renvoyer la même valeur avec un double encodage (ex. `%2523`) : une différence de comportement entre simple et double encodage oriente vers un filtrage actif plutôt qu'un simple traitement applicatif normal.

**Recto D2.** Un test SSPP réussit sur un endpoint mais échoue sur un autre endpoint apparemment similaire de la même API. Quelle conclusion éviter ?
**Verso D2.** Éviter de conclure à une infrastructure homogène — chaque endpoint peut être géré par un microservice interne différent, avec une technologie et un comportement de parsing distincts ; documenter le comportement par endpoint plutôt que généraliser.

**Recto D3.** Quels éléments du raisonnement SSPP (« référence → injection minimale → différentiel → isolation de la cause → effet choisi ») se transfèrent à d'autres vulnérabilités d'injection, et lesquels restent spécifiques ?
**Verso D3.** La démarche générale se transfère à toute vulnérabilité dépendant d'un parsing ou d'un assemblage de données. Restent spécifiques à la SSPP : les règles de résolution de paramètres dupliqués propres à chaque backend (PHP/ASP.NET/Node.js), et le fait que l'effet se manifeste typiquement en aval, invisible depuis la réponse immédiate de la gateway.

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
| Je ne comprends pas pourquoi la SSPP existe. | Cours de référence (sections 5.1–5.4) |
| Je ne sais pas quoi tester ensuite. | Méthodologie d'exploitation (sections 3 et 4) |
| Je connais le test, mais j'oublie la syntaxe exacte. | Cheat sheet (sections 3.3 et 4) |
| Je n'arrive pas à interpréter mes essais. | Méthodologie (sections 3.2 et 8) |
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
