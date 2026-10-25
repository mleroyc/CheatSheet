# Fiche de révision active — Web Cache Deception (WCD)

> **Mode d'emploi — Partie 1**
> Répondez à toutes les questions ci-dessous **sans consulter** `cours.md`, `exploitation.md` ou `cheatsheet.md`, et sans revenir en arrière une fois la lecture de la question commencée. Notez vos réponses avant de passer au corrigé. Ce n'est qu'après avoir répondu à l'ensemble des 30 questions que vous devez ouvrir la section « Corrigé ». Travailler avec les sources ouvertes fausse l'auto-évaluation et prive l'entraînement de son intérêt.

---

## 1. Comprendre

**Q1.** Quelle est la cause structurelle de la Web Cache Deception ? Formulez en une phrase pourquoi cette vulnérabilité ne provient pas d'un défaut d'authentification de l'application, mais d'un désaccord entre deux composants distincts.

**Q2.** Un en-tête `Cache-Control: public, max-age=3600` est observé sur une réponse dynamique. Expliquez pourquoi cette seule observation ne permet jamais de conclure que la réponse a effectivement été mise en cache, ni qu'elle a déjà été servie depuis le cache à un autre utilisateur.

**Q3.** Expliquez pourquoi l'absence de prise en compte de l'identité ou de la session dans la clé de cache est une condition nécessaire à l'exploitation de la WCD, en précisant ce qui se passerait concrètement si la clé intégrait systématiquement un identifiant d'utilisateur.

**Q4.** La Web Cache Deception et la Web Cache Poisoning exploitent toutes deux un cache web, mais poursuivent des objectifs différents. Formulez cette distinction en une phrase, en précisant qui est destinataire du contenu détourné dans chaque cas.

**Q5.** Le raisonnement méthodologique distingue trois niveaux de preuve (différence d'interprétation identifiée, mise en cache effective démontrée, impact réel démontré). Pourquoi est-il explicitement interdit de présenter le niveau intermédiaire comme une preuve suffisante de la vulnérabilité ?

---

## 2. Reconnaître

**Q6.** Citez les trois types de règles de cache distincts qui peuvent fonder une URL piégée exploitable, et pour chacun, la caractéristique de l'URL qu'il cible spécifiquement.

**Q7.** Une requête vers `/endpoint/aaa` renvoie exactement le même contenu que `/endpoint`, mais via un code de réponse `3xx` suivi d'une redirection. Pourquoi ce résultat ne doit-il pas être interprété de la même façon qu'une réponse `200` strictement identique sur les deux chemins ?

**Q8.** Vous observez `X-Cache: hit` sur une URL piégée contenant une extension statique ajoutée. Citez deux explications alternatives à cette observation qui n'impliquent pas que le contenu sensible recherché a réellement été mis en cache.

**Q9.** Une seconde requête vers une même URL piégée est nettement plus rapide que la première. Quelle vérification complémentaire est indispensable avant d'interpréter cette différence de timing comme un signe fiable de cache hit ?

**Q10.** Lors de l'étape de démonstration d'impact, la réponse obtenue depuis un contexte distinct de la victime est générique et ne contient aucune donnée de la victime. Quel en-tête de la réponse initiale, s'il est présent, permettrait d'expliquer directement cette observation ?

---

## 3. Tester

**Q11.** Décrivez la séquence de test permettant d'identifier un délimiteur exploitable (différence de délimiteur) côté serveur d'origine, en précisant pourquoi plusieurs délimiteurs candidats doivent être testés comme des hypothèses indépendantes plutôt que supposés universels.

**Q12.** Décrivez les deux sous-cas symétriques de la variante par normalisation de répertoire statique, en précisant la construction d'URL propre à chacun et pourquoi ils sont mutuellement exclusifs sur une même cible à un instant donné.

**Q13.** Décrivez la condition précise qui rend la variante par nom de fichier exploitable, et expliquez pourquoi cette variante est structurellement plus restreinte que les deux précédentes.

**Q14.** Décrivez la méthodologie permettant de confirmer qu'une mise en cache a effectivement eu lieu (au-delà de la simple différence d'interprétation), en précisant les signaux à faire converger avant de considérer cette confirmation comme établie.

**Q15.** Décrivez la démarche finale permettant de démontrer l'impact réel de la vulnérabilité, en précisant depuis quel type de contexte la requête de vérification doit impérativement être émise.

---

## 4. Interpréter

**Q16.** `/endpoint/aaa` renvoie un contenu identique à `/endpoint`. Avant de conclure à un mapping REST tolérant un segment final, quelle vérification complémentaire reste nécessaire, et pourquoi un résultat identique obtenu via une redirection explicite change-t-il l'interprétation à donner ?

**Q17.** Une extension statique ajoutée à un endpoint dynamique produit toujours le contenu sensible attendu (le serveur d'origine ignore l'extension), mais aucune seconde requête ne montre de signe de cache hit. Que pouvez-vous en déduire sur la localisation probable du problème, et quelle action corrective tester avant d'abandonner cette variante ?

**Q18.** Le sous-cas A de la variante répertoire (serveur d'origine normalise, pas le cache) produit une erreur de résolution littérale du traversal encodé. Que devez-vous en déduire sur le comportement réel de normalisation de la cible, et quelle action tester ensuite ?

**Q19.** `X-Cache: hit` est observé sur une URL piégée, mais le contenu retourné diffère de la réponse dynamique sensible initialement générée. Formulez l'hypothèse la plus probable expliquant cette divergence, et la vérification qui permettrait de la confirmer.

**Q20.** À l'étape de démonstration d'impact, la requête émise depuis un contexte distinct renvoie une erreur ou une réponse vide plutôt qu'un contenu générique. Quelle cause distincte de celle évoquée en Q10 devez-vous envisager ici ?

---

## 5. Exploiter

**Q21.** Construisez la chaîne de raisonnement complète permettant d'exploiter une règle de cache basée sur l'extension via un désaccord de mapping de chemin, depuis l'identification de l'endpoint dynamique jusqu'à la confirmation de mise en cache, en précisant à quel moment le contenu obtenu doit être vérifié comme restant dynamique.

**Q22.** Construisez la chaîne d'exploitation du sous-cas B de la variante répertoire (le cache normalise, pas le serveur d'origine), en expliquant précisément pourquoi l'ajout d'un délimiteur supplémentaire est nécessaire dans ce sous-cas et absent du sous-cas A.

**Q23.** Décrivez la démarche complète de démonstration d'impact depuis un contexte distinct, en précisant ce que la comparaison du contenu doit établir précisément pour exclure une coïncidence de contenu générique plutôt qu'une réelle exfiltration de données de la victime.

**Q24.** Un premier délimiteur testé (`;`) échoue à produire le contenu dynamique attendu. Décrivez le raisonnement correct pour la suite du test, en expliquant pourquoi l'échec de ce délimiteur ne permet de tirer aucune conclusion sur les autres délimiteurs candidats ni sur les variantes de répertoire ou de nom de fichier.

**Q25.** Décrivez comment documenter une preuve d'impact complète pour un finding WCD confirmé, en précisant les trois niveaux de preuve distincts qui doivent chacun être explicitement établis et communiqués séparément.

---

## 6. Déboguer et transférer

**Q26.** Le test du segment arbitraire (`/endpoint/aaa`) ne produit aucun résultat exploitable (erreur ou contenu différent). Avant de conclure à l'absence de toute variante WCD exploitable sur cet endpoint, quelles autres pistes indépendantes restent à tester ?

**Q27.** La mise en cache effective est confirmée (étape 4) mais la récupération depuis un contexte distinct (étape 5) échoue systématiquement, renvoyant un contenu générique plutôt que les données de la victime. Quelle cause structurelle devez-vous envisager, et quelle vérification permettrait de la confirmer ?

**Q28.** Aucun en-tête `X-Cache` n'est exposé par l'infrastructure testée. Quelle stratégie alternative reste disponible pour confirmer ou infirmer une mise en cache effective, et quelle précaution méthodologique est nécessaire pour que cette stratégie soit fiable ?

**Q29.** Le principe « deux composants qui doivent coopérer sur la base d'une même donnée d'entrée peuvent interpréter cette donnée différemment, créant une faille exploitable à leur frontière » est au cœur du raisonnement WCD. Formulez ce principe de façon suffisamment générale pour l'appliquer à une classe de vulnérabilité différente, avec un exemple concret.

**Q30.** La discipline des trois niveaux de preuve (signal, confirmation technique, impact démontré sur un tiers) structure toute la méthodologie WCD. Transférez cette discipline à l'audit d'une autre vulnérabilité de votre choix : donnez un exemple concret de ce que seraient, dans ce nouveau contexte, le niveau « signal isolé » et le niveau « impact pleinement démontré », et expliquez pourquoi les confondre serait une erreur.

---

## Corrigé — Réponses attendues et raisonnement

**R1.** La cause structurelle est un désaccord d'interprétation entre le cache et le serveur d'origine sur une même URL : le cache y voit une ressource statique cacheable fondée sur une caractéristique superficielle (extension, préfixe, nom de fichier), tandis que le serveur d'origine y résout en réalité un contenu dynamique et personnel. Ce n'est pas l'application qui expose directement l'information à un tiers — elle protège correctement ses données — c'est le cache, en toute bonne foi vis-à-vis de ses propres règles internes, qui sert à l'attaquant une réponse qui ne lui était pas destinée.

**R2.** `Cache-Control: public, max-age=...` indique seulement qu'une réponse est **autorisée** à être mise en cache, pas qu'elle l'a été **effectivement**, ni qu'elle a déjà été resservie à un autre utilisateur. Cette directive est une politique déclarée par l'application ; le comportement réel dépend de l'infrastructure de cache (si elle choisit de stocker cette réponse précise, selon ses propres règles) et seule une observation directe (en-tête `X-Cache`, timing, contenu effectivement récupéré) permet de confirmer qu'un stockage a réellement eu lieu.

**R3.** Si la clé de cache intégrait systématiquement un identifiant d'utilisateur (ou tout élément propre à sa session), chaque réponse stockée serait associée exclusivement à l'utilisateur qui l'a générée, et une requête émise par un tiers vers la même URL ne pourrait jamais recevoir la copie stockée pour un autre utilisateur, même en cas de désaccord d'interprétation confirmé par ailleurs. L'absence de cette prise en compte est ce qui permet concrètement la réutilisation abusive d'une réponse personnelle par un utilisateur distinct de celui qui l'a générée.

**R4.** La Web Cache Deception vise à faire stocker du contenu **sensible** (appartenant à une victime) pour le **récupérer soi-même** en tant qu'attaquant, tandis que la Web Cache Poisoning vise à faire stocker du contenu **malveillant** (fabriqué par l'attaquant) pour le **distribuer à d'autres utilisateurs** qui visiteront ensuite cette même URL. Dans le premier cas, l'attaquant est le destinataire final du contenu détourné ; dans le second, il en est l'émetteur et d'autres utilisateurs en sont les destinataires.

**R5.** Chaque niveau n'est qu'une condition nécessaire mais non suffisante du suivant : une différence d'interprétation identifiée démontre seulement qu'un comportement non standard peut être déclenché, sans prouver qu'une donnée sensible y est associée ni qu'elle est effectivement stockée ; une mise en cache effective démontrée confirme le stockage mais pas que ce stockage soit récupérable par un tiers sans contrôle d'accès supplémentaire (la clé de cache pourrait malgré tout intégrer un élément distinguant les utilisateurs). Présenter un niveau intermédiaire comme une preuve finale surestimerait l'impact réel et pourrait documenter à tort une vulnérabilité comme pleinement exploitable alors que la récupération par un tiers n'a jamais été vérifiée.

**R6.** Les trois types : (1) règles basées sur l'**extension de fichier** (`.css`, `.js`, etc.), ciblant une URL se terminant par une extension associée à des ressources statiques ; (2) règles basées sur le **préfixe de répertoire statique** (`/static`, `/assets`), ciblant une URL commençant par un chemin reconnu comme répertoire de ressources statiques ; (3) règles basées sur un **nom de fichier précis et fréquent** (`robots.txt`, `favicon.ico`), ciblant une correspondance exacte avec un nom de fichier couramment mis en cache plutôt qu'une extension générique.

**R7.** Un résultat identique obtenu via une redirection HTTP explicite (`3xx`) doit être distingué d'un résultat identique obtenu directement (`200` sur les deux chemins), car ces deux cas ont des implications différentes pour la suite : il faut vérifier si c'est la redirection elle-même qui pourrait être mise en cache, ou si c'est la ressource finale après redirection — ces deux scénarios ne construisent pas la même URL piégée ni ne produisent le même comportement de cache. Un résultat identique en `200` direct suggère davantage un mapping REST réellement tolérant le segment, tandis qu'une redirection peut provenir d'un comportement applicatif totalement distinct (réécriture d'URL) sans lien avec le mécanisme de divergence recherché.

**R8.** Deux explications alternatives : (1) le `X-Cache: hit` peut provenir d'une **autre ressource légitimement statique** partageant un chemin ou une clé de cache similaire, sans rapport avec le contenu dynamique sensible recherché ; (2) il peut résulter d'une **collision de clé due à un cache buster mal configuré** (ou à sa réutilisation involontaire), auquel cas le hit observé correspond à une entrée de cache antérieure sans lien avec le test en cours. Dans les deux cas, le hit seul ne confirme pas que le contenu stocké est bien la réponse sensible recherchée — le contenu exact doit être vérifié.

**R9.** La vérification indispensable est de confirmer cette différence par **d'autres indices convergents** (en-tête `X-Cache` s'il est disponible, répétition du test plusieurs fois dans des conditions similaires, comparaison avec le comportement de référence établi sur une ressource réellement statique) avant de conclure à un cache hit réel. Un temps de réponse plus court peut provenir de la latence réseau, de la charge du serveur, ou de la réutilisation de connexion — facteurs sans lien avec une mise en cache effective — et ne doit jamais être interprété isolément comme une preuve suffisante.

**R10.** L'en-tête `Vary: Cookie` (ou un en-tête équivalent indiquant que la réponse varie selon un élément lié à l'identité/session) présent sur la réponse initiale expliquerait directement cette observation : il indiquerait que la clé de cache intègre en réalité le cookie de session, de sorte qu'une requête émise depuis un contexte distinct (sans ce cookie précis) ne peut structurellement jamais recevoir la copie stockée pour la victime, même si la mise en cache a bien eu lieu par ailleurs.

**R11.** Séquence : tester, un par un et avec un cache buster distinct pour chaque test, les délimiteurs candidats (`;` pour Spring, `.` pour Ruby on Rails, `%00` selon configuration serveur), en comparant à chaque fois le contenu retourné avec et sans le délimiteur pour un même suffixe d'extension — un contenu identique au contenu dynamique de référence confirme que le serveur tronque le chemin au délimiteur testé. Plusieurs délimiteurs doivent être testés indépendamment car chacun est strictement propre à une technologie de serveur d'origine précise : un délimiteur fonctionnant sous Spring ne fonctionne pas nécessairement sous une autre stack, et aucun n'est universel.

**R12.** Sous-cas A (le serveur d'origine normalise, pas le cache) : l'URL piégée est de la forme `/static/..%2f<endpoint>` — le cache perçoit le préfixe `/static` et applique sa règle de répertoire, tandis que le serveur d'origine décode `%2f` en `/` et résout l'endpoint dynamique réel. Sous-cas B (le cache normalise, pas le serveur d'origine) : l'URL piégée combine le traversal avec un délimiteur supplémentaire, `/static/..%2f<endpoint>;wcd.css` — le cache normalise et applique sa règle, tandis que le serveur d'origine, qui ne normalise pas, doit être amené à tronquer le chemin via le délimiteur plutôt que de tenter de résoudre littéralement les caractères encodés. Ces deux sous-cas sont mutuellement exclusifs car le comportement de normalisation de chaque composant est une caractéristique fixe de l'infrastructure testée à un instant donné, pas un choix laissé à l'attaquant — un seul des deux peut être le comportement réel de la cible.

**R13.** La condition précise : le cache doit normaliser les segments encodés (reconnaissant ainsi un nom de fichier précis après résolution du traversal), tandis que le serveur d'origine ne normalise pas et résout un contenu dynamique différent pour le même chemin brut — c'est le symétrique restreint du sous-cas B de la variante répertoire, mais appliqué à un nom de fichier exact plutôt qu'à un préfixe générique. Cette variante est structurellement plus restreinte car elle ne fonctionne que dans ce seul sous-cas de normalisation (un seul des deux comportements possibles la rend exploitable), alors que les variantes extension et répertoire disposent chacune de plusieurs mécanismes ou sous-cas alternatifs à tester.

**R14.** Méthodologie : envoyer une seconde requête identique vers la même URL piégée, puis examiner systématiquement l'en-tête `X-Cache` (ou équivalent propre au CDN) et comparer le temps de réponse à la référence établie sur une ressource réellement statique. Les signaux à faire converger avant de considérer la confirmation comme établie : la présence effective de `X-Cache: hit` (ou équivalent), un temps de réponse significativement et systématiquement plus court cohérent avec le comportement de référence, et surtout la vérification que le contenu de la seconde réponse est strictement identique à la réponse dynamique sensible initiale (pas seulement la présence de l'en-tête, qui peut provenir d'une collision de clé).

**R15.** Démarche : depuis un contexte entièrement distinct de celui de la victime (navigateur en session anonyme, requête sans cookie de session, ou session d'un second compte de test « attaquant »), requêter exactement la même URL piégée, puis comparer précisément le contenu obtenu aux données attendues de la session victime initiale. La requête doit impérativement être émise depuis un contexte **structurellement distinct** — pas une simple répétition depuis le même contexte que la victime — car c'est uniquement cette séparation de contexte qui permet de démontrer qu'un tiers sans accès légitime peut récupérer la donnée, condition qui définit l'impact réel selon la méthodologie.

**R16.** Avant de conclure à un mapping REST tolérant, il reste nécessaire de vérifier que le segment est **réellement ignoré par le routage interne**, et non simplement redirigé vers la même ressource pour une tout autre raison (règle de réécriture, comportement applicatif spécifique sans lien avec le mécanisme recherché). Un résultat identique via une redirection explicite change l'interprétation car il faut alors déterminer si c'est la redirection elle-même ou la ressource finale après redirection qui serait éventuellement mise en cache — ces deux scénarios ne produisent pas la même URL piégée exploitable et nécessitent une vérification distincte avant de poursuivre.

**R17.** Vous pouvez en déduire que le désaccord d'interprétation existe bien **côté serveur d'origine** (qui ignore effectivement l'extension ajoutée et continue de traiter la requête comme dynamique), mais que le problème se situe probablement **côté cache**, qui n'applique peut-être pas sa règle de mise en cache à cette forme précise d'extension. Action corrective à tester avant d'abandonner cette variante : essayer d'autres extensions candidates (`.js`, `.png`, `.ico`, etc.) sur le même point d'entrée, la règle de cache réelle pouvant cibler une liste d'extensions différente de celle initialement testée.

**R18.** Vous devez en déduire que le sous-cas testé (A — serveur d'origine normalise, pas le cache) ne correspond probablement pas au comportement réel de normalisation de cette cible précise : le serveur d'origine tente d'interpréter littéralement `..%2f` comme un chemin invalide plutôt que de le résoudre. Action à tester ensuite : le sous-cas symétrique B (le cache normalise, pas le serveur d'origine), qui nécessite de combiner le traversal avec un délimiteur supplémentaire pour que le serveur d'origine tronque correctement le chemin au lieu de tenter sa résolution littérale.

**R19.** L'hypothèse la plus probable : une **collision de clé** avec une autre ressource légitimement statique partageant une clé de cache similaire, ou une entrée de cache polluée par un test précédent (cache buster mal configuré ou réutilisé). Vérification permettant de la confirmer : répéter le test avec un cache buster rigoureusement nouveau et propre, afin d'isoler une clé de cache non polluée par une entrée antérieure, puis vérifier que le contenu retourné correspond bien, cette fois, à la réponse dynamique sensible attendue.

**R20.** Une cause distincte de celle de Q10 (clé de cache incluant l'identité) : la clé de cache a potentiellement **expiré entre les deux requêtes**, ou la réponse initialement stockée dépendait d'un **élément de contexte non reproduit** lors de la seconde requête (en-têtes spécifiques présents lors de la première requête mais absents de la seconde). Contrairement à une réponse générique (qui indique une clé incluant l'identité), une erreur ou une réponse vide pointe plutôt vers l'absence pure et simple d'entrée de cache valide au moment de la requête de vérification.

**R21.** Chaîne complète : (1) identifier un endpoint dynamique sensible (`/settings/users/list` par exemple) et établir sa réponse de référence avec une session de test ; (2) tester un segment arbitraire (`/aaa`) pour établir si le routage tolère déjà un segment supplémentaire ; (3) ajouter une extension statique en fin de chemin sans délimiteur (`/settings/users/list/wcd.css`) et vérifier que la réponse reste le contenu dynamique sensible — c'est à ce moment précis que le contenu doit être vérifié comme restant dynamique, avant toute conclusion sur le cache ; (4) envoyer une seconde requête identique et observer `X-Cache` et le timing pour confirmer la mise en cache effective. Le mapping de chemin est confirmé si le serveur d'origine ignore systématiquement le segment ajouté tout en continuant à générer la réponse dynamique attendue.

**R22.** Le sous-cas B exige un délimiteur supplémentaire car, dans ce sous-cas, c'est le **cache** qui normalise le traversal encodé (reconnaissant ainsi le préfixe `/static` après résolution de `..%2f`), tandis que le **serveur d'origine ne normalise pas** : sans délimiteur, le serveur d'origine tenterait de résoudre littéralement la séquence `..%2f` dans son propre routage, ce qui produirait une erreur plutôt que la résolution attendue vers l'endpoint dynamique. Le délimiteur ajouté (`;wcd.css`) force le serveur d'origine à tronquer le chemin avant ce caractère, le traitant comme s'il visait uniquement la portion précédente — contournant ainsi son absence de normalisation du traversal. Le sous-cas A, à l'inverse, n'a pas besoin de ce délimiteur car c'est le **serveur d'origine** qui normalise déjà le traversal de lui-même, résolvant directement l'endpoint sans artifice supplémentaire.

**R23.** La comparaison doit établir que le contenu obtenu depuis le contexte distinct correspond **précisément, champ par champ si nécessaire** (nom, identifiant, jeton), aux données générées spécifiquement pour la session victime lors de sa visite initiale — pas seulement un contenu qui « ressemble » à des données personnelles. Cette précision est nécessaire pour exclure une coïncidence de contenu générique (données de test, contenu par défaut ressemblant superficiellement à des données personnelles sans en être) : seule une correspondance exacte et vérifiable entre le contenu récupéré par le tiers et le contenu réellement généré pour la victime constitue une preuve d'exfiltration réelle plutôt qu'une simple ressemblance accidentelle.

**R24.** L'échec de `;` ne permet aucune conclusion sur les autres délimiteurs ni sur les autres variantes car chaque délimiteur est une hypothèse technique indépendante, strictement propre à une technologie de serveur d'origine précise (le point-virgule n'a de sens que pour certains frameworks comme Spring) ; de même, les mécanismes de délimiteur, de mapping de chemin, et de normalisation (répertoire, nom de fichier) sont trois familles techniquement distinctes qui ne se généralisent pas les unes aux autres. Le raisonnement correct : tester ensuite les autres délimiteurs candidats (`.`, `%00`) comme hypothèses indépendantes et documentées séparément, puis, si l'ensemble des délimiteurs échoue, passer à la variante répertoire (normalisation) qui repose sur un mécanisme entièrement distinct — sans jamais conclure à l'absence de toute variante exploitable sur la seule base de l'échec d'un délimiteur.

**R25.** Documentation en trois niveaux distincts : (1) **différence d'interprétation identifiée** — préciser le mécanisme exact confirmé (mapping de chemin, délimiteur, ou normalisation, avec le sous-cas le cas échéant) et l'URL précise qui le déclenche ; (2) **mise en cache effective démontrée** — préciser les signaux convergents observés (en-tête `X-Cache`, timing comparé à la référence statique, contenu identique vérifié) ; (3) **impact réel démontré** — préciser le contenu exact récupéré depuis un contexte structurellement distinct et sa correspondance vérifiée avec les données de la victime. Chaque niveau doit être communiqué séparément plutôt que fusionné, afin que le niveau de preuve réellement atteint soit explicite et non surestimé.

**R26.** Pistes indépendantes à tester : directement un délimiteur explicite (`;`, `.`, `%00`) même en l'absence de tolérance confirmée du segment brut, la tolérance de segment n'étant pas une condition nécessaire si un délimiteur explicite fonctionne par un mécanisme distinct ; et, en parallèle ou ensuite, la variante par normalisation de répertoire si le chemin ciblé est préfixé par un répertoire statique connu de l'application — ces deux pistes reposent sur des mécanismes indépendants du test de segment brut et ne doivent jamais être exclues sur la seule base de son échec.

**R27.** Cause structurelle à envisager : la clé de cache intègre en réalité un élément distinguant l'identité ou la session de l'utilisateur (par exemple un en-tête d'autorisation inclus dans la construction de la clé, ou un en-tête `Vary` indiquant une telle dépendance), neutralisant l'impact malgré la mise en cache confirmée par ailleurs. Vérification : comparer la clé de cache supposée (le chemin seul) au comportement observé en testant la récupération depuis plusieurs variations de contexte (anonyme, second compte de test, avec et sans certains en-têtes) pour isoler précisément quel élément est réellement discriminant dans la construction de la clé.

**R28.** Stratégie alternative : s'appuyer sur la comparaison de **temps de réponse** entre la première requête (cache miss supposé) et une requête répétée vers la même URL piégée, en la comparant systématiquement au comportement de référence établi au préalable sur une ressource réellement statique connue (qui sert d'étalon de ce à quoi ressemble un cache hit authentique sur cette infrastructure). Précaution méthodologique nécessaire : répéter le test plusieurs fois dans des conditions similaires pour écarter les variations de latence réseau ou de charge serveur, et ne jamais conclure à un cache hit sur la base d'une seule mesure de timing isolée, même nettement plus rapide.

**R29.** Formulation générale : lorsque deux composants distincts doivent traiter une même donnée d'entrée de façon cohérente sans jamais synchroniser explicitement leur interprétation de cette donnée, toute divergence entre leurs logiques respectives crée une zone d'exploitation à la frontière de leur coopération implicite. Exemple de transfert possible (plusieurs réponses acceptées) : une faille de contrebande de requêtes HTTP (HTTP Request Smuggling) exploite exactement ce même principe — un proxy frontal et un serveur backend interprètent différemment la limite d'une requête HTTP (via les en-têtes `Content-Length` et `Transfer-Encoding` traités de façon incohérente), permettant à l'attaquant d'injecter une requête que l'un des deux composants perçoit mais pas l'autre.

**R30.** Exemple de transfert possible (plusieurs réponses acceptées, l'important étant la cohérence du raisonnement) : pour une vulnérabilité IDOR, le niveau « signal isolé » correspondrait à observer qu'un identifiant modifié renvoie une réponse `200` différente de celle obtenue pour un identifiant invalide (indice d'un contrôle d'accès potentiellement absent, sans preuve de contenu réellement sensible) ; le niveau « impact pleinement démontré » correspondrait à la récupération vérifiée et comparée de données appartenant réellement à un autre utilisateur identifié, via ce même identifiant modifié, depuis un compte n'ayant aucun droit légitime sur cette ressource. Les confondre serait une erreur car un code `200` différent peut provenir d'un comportement applicatif sans lien avec un accès non autorisé réel (page générique, contenu par défaut) — exactement comme un `X-Cache: hit` isolé en WCD ne prouve pas qu'une donnée sensible a été exfiltrée : dans les deux cas, seule la démonstration d'un accès effectif et vérifié à une donnée appartenant réellement à un tiers constitue une preuve d'impact complète.

---

## Barème d'auto-évaluation

| Score | Signification |
|---|---|
| **0 — Bloqué** | Aucune piste de raisonnement mobilisable sans aide. |
| **1 — Avec aide** | Réponse obtenue seulement après un indice ou une reformulation de la question. |
| **2 — Autonome sur un cas connu** | Réponse correcte et complète sur un scénario déjà rencontré, sans transfert testé. |
| **3 — Transfert** | Réponse correcte, raisonnement explicite, et capacité démontrée à l'adapter à un contexte ou un scénario nouveau. |

> Le score porte autant sur la qualité et la complétude du **raisonnement** (hypothèses posées, conditions nécessaires, ce qu'il serait prématuré de conclure) que sur la **justesse de la conclusion finale**. Une bonne conclusion obtenue par un raisonnement erroné ou incomplet ne mérite pas un score de 3.

---

# Partie 2 — Cartes de révision

> 18 cartes, 3 par catégorie. Recto = question ou situation ; Verso = réponse concise et vérifiable en quelques secondes.

### Comprendre

**Carte 1**
Recto : Quelle est la cause structurelle de la Web Cache Deception ?
Verso : Un désaccord d'interprétation d'une même URL entre le cache (qui y voit une ressource statique) et le serveur d'origine (qui y résout un contenu dynamique personnel).

**Carte 2**
Recto : `Cache-Control: public` sur une réponse prouve-t-il qu'elle a été mise en cache ?
Verso : Non — cet en-tête indique seulement qu'elle est autorisée à l'être, pas qu'elle l'a été effectivement.

**Carte 3**
Recto : Quelle différence sépare WCD et Web Cache Poisoning ?
Verso : WCD fait stocker du contenu sensible pour le récupérer soi-même ; Poisoning fait stocker du contenu malveillant pour le distribuer à d'autres.

### Reconnaître

**Carte 4**
Recto : Citez les trois types de règles de cache exploitables en WCD.
Verso : Règle par extension de fichier, règle par préfixe de répertoire statique, règle par nom de fichier précis.

**Carte 5**
Recto : Deux explications alternatives à un `X-Cache: hit` qui ne confirment pas la WCD ?
Verso : Collision avec une ressource légitimement statique, ou cache buster mal configuré/réutilisé.

**Carte 6**
Recto : Quel en-tête, s'il est présent, explique qu'un tiers ne récupère jamais les données de la victime malgré une mise en cache confirmée ?
Verso : `Vary: Cookie` (ou équivalent) — indique que la clé de cache intègre l'identité/session.

### Tester

**Carte 7**
Recto : Pourquoi tester plusieurs délimiteurs (`;`, `.`, `%00`) indépendamment ?
Verso : Chacun est strictement propre à une technologie de serveur d'origine précise (Spring, Rails...) — aucun n'est universel.

**Carte 8**
Recto : Quelle est la différence entre les deux sous-cas de la variante répertoire ?
Verso : Sous-cas A : le serveur normalise, pas le cache (pas de délimiteur nécessaire). Sous-cas B : le cache normalise, pas le serveur (délimiteur nécessaire).

**Carte 9**
Recto : Depuis quel type de contexte la requête de démonstration d'impact (étape 5) doit-elle être émise ?
Verso : Un contexte structurellement distinct de la victime (session anonyme, autre compte) — jamais une simple répétition depuis le même contexte.

### Interpréter

**Carte 10**
Recto : Contenu dynamique obtenu malgré l'extension ajoutée, mais aucun signe de cache hit : où se situe probablement le problème ?
Verso : Côté cache, qui n'applique probablement pas sa règle à cette extension précise — tester d'autres extensions.

**Carte 11**
Recto : Sous-cas A de normalisation produit une erreur de résolution littérale : que tester ensuite ?
Verso : Le sous-cas B symétrique (cache normalise, pas le serveur), avec délimiteur supplémentaire.

**Carte 12**
Recto : `X-Cache: hit` mais contenu différent de la réponse sensible attendue : hypothèse la plus probable ?
Verso : Collision de clé ou cache buster pollué — répéter avec un buster rigoureusement nouveau.

### Exploiter

**Carte 13**
Recto : À quel moment précis le contenu doit-il être vérifié comme restant dynamique, dans la chaîne d'exploitation par extension ?
Verso : Immédiatement après l'ajout de l'extension/délimiteur, avant toute conclusion sur le comportement du cache.

**Carte 14**
Recto : Pourquoi le sous-cas B de la variante répertoire nécessite-t-il un délimiteur supplémentaire ?
Verso : Pour empêcher le serveur d'origine (qui ne normalise pas) de tenter de résoudre littéralement le traversal encodé, ce qui produirait une erreur.

**Carte 15**
Recto : Que doit établir précisément la comparaison de contenu à l'étape d'impact ?
Verso : Une correspondance exacte, champ par champ si nécessaire, entre le contenu récupéré par le tiers et celui généré pour la victime — pas une simple ressemblance.

### Déboguer et transférer

**Carte 16**
Recto : Le segment arbitraire (`/aaa`) n'est pas ignoré par le routage : que tester malgré tout ?
Verso : Un délimiteur explicite directement, et la variante par normalisation de répertoire — deux mécanismes indépendants du test de segment brut.

**Carte 17**
Recto : Mise en cache confirmée mais récupération par un tiers impossible : cause structurelle à vérifier ?
Verso : La clé de cache intègre probablement un élément d'identité (en-tête d'autorisation, `Vary`) — tester plusieurs variations de contexte pour l'isoler.

**Carte 18**
Recto : Quel principe général du raisonnement WCD se transfère à d'autres vulnérabilités ?
Verso : Deux composants traitant une même entrée sans synchroniser leur interprétation créent une zone d'exploitation à leur frontière (ex. HTTP Request Smuggling).

---

# Partie 3 — Organisation des révisions

## Première tentative

1. Isolez-vous des trois documents sources (`cours.md`, `exploitation.md`, `cheatsheet.md`) et répondez aux 30 questions de la Partie 1 dans l'ordre, sans retour en arrière une fois une question commencée.
2. Notez vos réponses intégralement avant toute consultation du corrigé, y compris celles dont vous êtes incertain.
3. Comparez chaque réponse au corrigé une par une, et attribuez-vous un score selon le barème (0 à 3) immédiatement après chaque comparaison.
4. Passez ensuite aux 18 cartes de la Partie 2 en les traitant comme un test minuté plutôt qu'en les relisant passivement.
5. Consignez les questions et cartes où le score est inférieur à 2 : elles constituent la base de votre session « Après correction ».

## Après correction

| Si la difficulté exprimée ressemble à… | Document à retravailler en priorité |
|---|---|
| « Je ne comprends pas pourquoi ce n'est pas un défaut d'authentification » | `cours.md` |
| « Je ne sais pas dans quel ordre tester les trois variantes ni leurs sous-cas » | `exploitation.md` |
| « Je ne me souviens plus de la syntaxe exacte d'un délimiteur ou d'un encodage » | `cheatsheet.md` |
| « J'ai confondu un signal isolé (X-Cache hit, timing réduit) avec une preuve d'impact » | `exploitation.md` (sections 3.2 et 7 — indices, faux positifs, diagnostic des échecs) |
| « Je ne sais pas comment adapter ce raisonnement à un autre contexte » | `exploitation.md` (section 10 — leçons transférables) |

## Révisions espacées

| Jour | Action |
|---|---|
| Jour 0 | Première tentative complète (questions + cartes) et correction immédiate. |
| Jour 1 | Refaire uniquement les questions et cartes scorées en dessous de 2. |
| Jour 3 | Refaire l'ensemble des 30 questions sans aide ; comparer les scores à ceux du Jour 0. |
| Jour 7 | Refaire uniquement les 18 cartes, en visant une réponse en quelques secondes chacune. |
| Jour 14 | Refaire l'ensemble complet (questions + cartes) comme un nouvel examen blanc. |
| Jour 30 | Dernière passe de consolidation, en se concentrant sur les items encore scorés en dessous de 3. |

> Ces intervalles sont indicatifs : ajustez-les selon vos scores réels — un item resté à 0 ou 1 après plusieurs passages mérite une révision plus rapprochée que ce calendrier par défaut.
