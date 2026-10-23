# OS Command Injection — Fiche de révision

> **Notice d'utilisation.** Réponds à chaque question sans consulter le cours, la méthodologie d'exploitation ou la cheat sheet. Réponds à voix haute ou par écrit, puis compare ta réponse au corrigé situé après l'ensemble des questions. Ne regarde pas le corrigé avant d'avoir répondu.

> **Note sur le périmètre.** Cette fiche couvre les quatre familles de confirmation décrites par les documents source (visible/in-band, temporisation, redirection de fichier, Out-of-Band) et la phase de reconnaissance système qui en découle. L'élévation de privilèges, le pivotement réseau effectif et le contournement actif de filtres/WAF spécifiques sont explicitement hors périmètre des documents fournis.

---

## 1. Comprendre

**1.** Quel est le défaut structurel unique qui rend possible toute forme d'injection de commandes OS, quelle que soit la technique de confirmation utilisée (visible, temporisation, fichier, OOB) ?

**2.** En quoi l'injection de commandes OS se distingue-t-elle de l'injection de code (ex. `eval()`) ? Pourquoi cette distinction compte-t-elle pour choisir la défense appropriée ?

**3.** Pourquoi la contre-mesure « liste blanche stricte + validation du type » est-elle présentée comme une mesure de secours, et non comme la défense primaire recommandée ?

**4.** Pourquoi l'échappement manuel des métacaractères shell est-il qualifié de « systématiquement contournable » plutôt que de simplement « risqué » ?

## 2. Reconnaître

**5.** Tu observes qu'un paramètre `storeID` semble transmis à un script externe générant un rapport, sans qu'aucune sortie de script ne soit directement visible dans la réponse HTTP normale. Qu'est-ce que cela rend plausible pour la suite du test, et que dois-tu anticiper quant à la forme probable de l'injection si elle est confirmée ?

**6.** Après injection d'un `%26echo%20abc123%26`, aucune chaîne `abc123` n'apparaît dans la réponse. Qu'est-ce que ce résultat rend plausible, et que ne permet-il **pas** de conclure ?

**7.** Un message d'erreur système inhabituel (erreur de shell, commande introuvable) apparaît après modification d'un paramètre. Qu'est-ce que cela suggère, sans le confirmer à lui seul ?

**8.** Un paramètre rejette systématiquement toute valeur non strictement numérique, avec un message d'erreur cohérent avant tout traitement ultérieur. Est-ce un résultat ambigu à approfondir, ou une probable infirmation ?

## 3. Tester

**9.** Avant tout test d'injection sur un point d'entrée suspecté, quelle référence faut-il établir, et pourquoi est-elle indispensable en particulier pour interpréter un test de temporisation ?

**10.** Tu testes le séparateur `&` sans résultat visible. Quelles sont les erreurs fréquentes à éviter avant de conclure à une absence de vulnérabilité ?

**11.** Tu soupçonnes que l'entrée utilisateur est concaténée à l'intérieur d'une chaîne quotée côté applicatif. Quel test minimal effectuerais-tu, et pourquoi faut-il tester les deux types de guillemets séparément ?

**12.** Tu veux confirmer une injection aveugle par temporisation. Quelle condition dois-tu respecter avant d'interpréter le délai observé comme un signal fiable, au-delà de la simple exécution du payload ?

## 4. Interpréter

**13.** Un délai de réponse plus long qu'à l'habitude est observé une seule fois après injection d'une commande de pause. Peux-tu conclure à une injection confirmée ? Justifie.

**14.** Une requête vers le fichier censé contenir le résultat de la commande redirigée renvoie un code 404. Que peux-tu en conclure, et que ne peux-tu **pas** en conclure ?

**15.** Aucune résolution DNS n'est reçue sur le service OOB après injection du payload `nslookup`. Cela infirme-t-il l'hypothèse d'injection ? Justifie en donnant au moins deux causes alternatives.

**16.** Tu obtiens un résultat cohérent pour `whoami`, mais la commande `cat /etc/passwd` échoue. Que peux-tu conclure sur l'injection elle-même, et que documentes-tu à la place ?

## 5. Exploiter

**17.** Tu as confirmé l'injection par temporisation (Étape 2), mais le fichier de sortie reste inaccessible (Étape 3, 404). Comment construis-tu la suite de ta chaîne d'exploitation sans revenir en arrière sur la confirmation déjà acquise ?

**18.** Pourquoi la méthodologie recommande-t-elle de tester les techniques dans l'ordre visible → temporisation → fichier → OOB, plutôt que de commencer directement par l'OOB, présenté comme le moyen le plus fiable en environnement filtrant ?

**19.** Une fois l'injection confirmée uniquement par temporisation (sans canal de retour exploitable), quelle est la limite de la preuve d'impact que tu peux présenter dans un rapport, par rapport à une confirmation via fichier ou OOB ?

**20.** Tu disposes d'un canal de retour confirmé (ex. OOB). Comment choisis-tu quelles commandes de reconnaissance chaîner, et quelle contrainte de proportionnalité dois-tu respecter ?

## 6. Déboguer et transférer

**21.** Le délai de temporisation n'est pas reproductible d'un essai à l'autre. Quelles sont les deux causes à distinguer, et quel test permet de les différencier ?

**22.** Aucun délai n'est observé avec la syntaxe de pause testée (ex. `ping -c 10`). Quelle hypothèse dois-tu vérifier avant de conclure à une absence d'injection ?

**23.** L'injection est confirmée par temporisation, mais aucune résolution DNS n'est reçue côté OOB. Comment distingues-tu une absence de connectivité sortante d'une absence réelle d'injection ?

**24.** Tu maîtrises désormais la progression « visible → temporisation → fichier → OOB » pour confirmer une injection de commande. Quel principe de cette démarche se transfère tel quel à d'autres vulnérabilités, et quels éléments techniques (séparateurs, syntaxe des commandes de reconnaissance) restent strictement spécifiques à l'injection de commandes OS ?

---

# Corrigé — Réponses attendues et raisonnement

### 1. Comprendre

**1.** L'**absence d'échappement ou de validation des métacaractères shell** lors de la concaténation d'une donnée contrôlée par le client dans une commande exécutée par un interpréteur shell côté serveur — le paramètre est transmis tel quel à un appel système. Visible, temporisation, fichier et OOB ne sont que des **canaux différents** pour observer ce même défaut sous-jacent, pas des mécanismes distincts.

**2.** La command injection exécute une **commande shell préexistante** du système (`whoami`, `ls`...) ; l'injection de code exécute du **code source** interprété directement par le langage applicatif (`eval()`). Cette distinction compte car les défenses diffèrent : pour la command injection, la défense primaire est de ne jamais invoquer de shell depuis la couche applicative (API natives plutôt que `exec()`/`system()`) ; pour l'injection de code, la défense porte sur l'évitement de l'évaluation dynamique de code, un problème de nature différente.

**3.** Parce que la défense primaire recommandée est de **ne jamais faire appel à des commandes OS depuis la couche applicative** (privilégier les API/bibliothèques natives). La liste blanche et la validation de type ne sont mobilisées que « si l'appel système est réellement inévitable » — une mesure de secours pour un cas qui ne devrait idéalement jamais se produire, pas la solution de référence.

**4.** Parce que c'est une approche complexe, sujette aux oublis (encodages, substitutions de commande `$(...)`/`` ` ``, sauts de ligne `%0a`), et que l'historique des vulnérabilités de ce type démontre systématiquement qu'elle est contournable. Contrairement à une liste blanche stricte combinée à l'absence totale d'invocation de shell — qui empêche **structurellement** l'interprétation des métacaractères — l'échappement manuel reste une rustine qui doit anticiper tous les cas possibles, ce qui est en pratique impossible à garantir de façon exhaustive.

### 2. Reconnaître

**5.** Cela rend plausible l'hypothèse que le paramètre est concaténé sans échappement à une commande shell (même mécanisme que le cas illustré par le cours). Comme le résultat du script n'est pas visible en fonctionnement normal, il faut anticiper que l'injection, si confirmée, sera probablement sous forme **aveugle** plutôt que visible (in-band) : il faut se préparer à passer rapidement aux techniques de confirmation aveugle (temporisation, fichier, OOB) en cas d'échec du test visible par séparateur.

**6.** Ce résultat rend plausible soit une absence réelle d'injection, soit une **injection aveugle** (sortie non renvoyée au client), soit un filtrage limité au seul séparateur testé alors que d'autres opérateurs ou syntaxes alternatives ne le sont pas. Il ne permet **pas** de conclure à une absence de vulnérabilité : il n'infirme que l'hypothèse « sortie visible », rien sur l'existence de l'injection elle-même.

**7.** Cela suggère, sans le confirmer, qu'une valeur modifiée atteint potentiellement un interpréteur de commandes (indice indirect). Cela ne constitue pas en soi une preuve d'injection : une erreur HTTP générique (500) peut résulter d'une simple erreur de validation applicative sans rapport avec une exécution shell.

**8.** Une **probable infirmation** — un rejet immédiat et cohérent de toute valeur non numérique correspond exactement à la contre-mesure recommandée par le cours (validation stricte de type), ce n'est pas un résultat ambigu à creuser davantage.

### 3. Tester

**9.** Établir une **référence** : effectuer une requête légitime, noter le code HTTP, le corps de réponse et le temps de réponse, et répéter plusieurs fois pour caractériser la latence normale (bruit réseau). C'est indispensable en particulier pour le test de temporisation car la seule preuve disponible y est un **écart de délai** — sans référence, impossible de distinguer un délai provoqué d'une variation normale.

**10.** Ne tester **qu'un seul séparateur** sans essayer les autres opérateurs du §3.1 (`;`, `&&`, `|`, `||`, `%0a`), alors qu'un filtrage peut ne porter que sur un sous-ensemble des séparateurs possibles ; et oublier d'**encoder** le séparateur dans une requête GET, ce qui peut le faire interpréter comme un délimiteur de paramètres HTTP par un composant intermédiaire avant même d'atteindre l'application.

**11.** Tester la sortie de contexte avec guillemet double (`" ; whoami ; "`) **et** guillemet simple (`' ; whoami ; '`) séparément. Il faut tester les deux car le cours ne précise pas quel type de guillemet est utilisé côté applicatif pour concaténer l'entrée — un échec avec un seul type laisse la question ouverte.

**12.** Il faut que le délai soit **reproductible sur plusieurs répétitions**, et comparé à la **distribution complète** de la référence (pas une seule mesure de référence). Une latence réseau variable peut fausser l'interprétation d'une mesure isolée.

### 4. Interpréter

**13.** Non — un délai observé une seule fois reste un **comportement anormal**, pas une vulnérabilité confirmée. Il faut une mesure reproductible, avec un délai corrélé à la durée de la commande injectée (ex. faire varier le compteur et vérifier que le délai varie en conséquence), pour établir la confirmation.

**14.** On peut seulement conclure qu'**aucun effet n'a été observé sur ce canal précis**. Plusieurs causes possibles : chemin incorrect, absence de droits d'écriture du processus serveur sur ce répertoire, ou absence réelle d'exécution — à distinguer par diagnostic (notamment en croisant avec un résultat positif de temporisation) avant de conclure à une absence d'injection.

**15.** Non, pas à elle seule. Causes alternatives : (a) absence de connectivité sortante du serveur (environnement cloisonné) ; (b) filtrage spécifique de la résolution DNS, sans empêcher l'exécution de commande elle-même. Un résultat négatif à l'OOB, après échec des trois techniques précédentes, est le signal le plus proche d'une infirmation réelle, mais ne l'établit pas avec certitude si la connectivité sortante n'a pas été écartée séparément.

**16.** On peut conclure que l'injection reste **globalement confirmée** (`whoami` a réussi) ; l'échec isolé sur `cat /etc/passwd` documente une **restriction de privilège** du compte système utilisé par le processus serveur, pas une remise en cause de l'injection elle-même — à documenter commande par commande plutôt qu'à généraliser.

### 5. Exploiter

**17.** On passe à la reconnaissance système (Étape 5) en utilisant le canal de retour disponible. L'échec du fichier ne remet **pas** en cause la confirmation déjà acquise par temporisation — il documente simplement une limite de l'environnement (chemin incorrect ou absence de droits). Pour obtenir un retour de données exploitable au-delà de la simple confirmation temporelle, on passe à l'étape suivante disponible (OOB) plutôt que de revenir en arrière.

**18.** Parce que la démarche progresse systématiquement du **signal le plus simple à confirmer** vers le plus complexe, chaque technique n'étant mobilisée que lorsque la précédente ne permet pas de conclure. L'OOB est le moyen « le plus fiable » spécifiquement dans les environnements qui filtrent strictement les sorties — ce n'est pas la méthode à utiliser par défaut, car les techniques plus simples (visible, temporisation) sont plus rapides à mettre en œuvre et à interpréter quand elles suffisent.

**19.** La limite est qu'une confirmation par timing seul démontre l'**exécution de commande** mais pas encore l'**étendue de l'accès** — contrairement à une confirmation via fichier ou OOB, qui permet d'obtenir un résultat de commande de reconnaissance lisible et exploitable, établissant un niveau de **preuve d'impact** documentant l'étendue réelle de l'accès obtenu.

**20.** Choisir les commandes **nécessaires et suffisantes** pour démontrer l'impact (ex. `whoami`, `id`), adaptées à l'OS cible identifié, en les chaînant si besoin en une seule requête pour limiter le nombre d'allers-retours et le bruit généré dans les logs. Contrainte de proportionnalité : la preuve retenue doit rester **minimale, reproductible et proportionnée** — ne pas chaîner un nombre excessif de commandes au-delà de ce qui est requis pour le rapport, au risque de dépasser le périmètre autorisé du test.

### 6. Déboguer et transférer

**21.** Causes à distinguer : (a) bruit réseau ou charge serveur ; (b) absence réelle d'injection. Test de diagnostic : répéter la mesure plusieurs fois à des moments différents et comparer à la **distribution** de la référence (pas à une seule valeur) — si le délai redevient cohérent sur répétition, l'injection est confirmée ; sinon, passer à la technique suivante (fichier).

**22.** Vérifier que la **syntaxe testée correspond bien à l'OS cible réel** (ex. commande Linux testée sur une cible Windows, ou l'inverse) avant de conclure à une absence d'injection — un échec avec la syntaxe d'un OS inadapté ne doit pas être interprété comme une infirmation de l'hypothèse.

**23.** Croiser avec le résultat de la temporisation : si celle-ci a déjà confirmé l'injection, l'échec de l'OOB documente une **restriction de connectivité sortante** (ou un filtrage DNS spécifique), pas une absence de faille — l'injection reste établie, seul le canal de retour OOB n'est pas disponible pour cette cible.

**24.** Se transfère : la **progression systématique** du signal le plus simple vers le plus complexe, en n'escaladant vers la technique suivante que lorsque la précédente ne permet pas de conclure ; la nécessité d'établir une référence avant d'interpréter un signal indirect ; la distinction entre **comportement anormal**, **vulnérabilité confirmée** et **impact démontré**. Reste strictement spécifique à l'injection de commandes OS : la liste précise des séparateurs et leur comportement propre à chaque shell (notamment `&` qui se comporte différemment entre Unix et Windows), qui ne se transpose pas telle quelle à d'autres familles d'injection (SQL, LDAP) ayant leurs propres métacaractères ; et les commandes de reconnaissance elles-mêmes, strictement dépendantes de l'OS cible.

### Barème d'auto-évaluation

- **0 — Bloqué :** impossible de fournir une réponse pertinente sans consulter les notes.
- **1 — Avec aide :** réponse partielle ou obtenue après consultation d'un indice.
- **2 — Autonome sur un cas connu :** réponse correcte et raisonnement cohérent dans un scénario familier.
- **3 — Transfert :** réponse correcte dans une situation modifiée, avec justification et interprétation des limites.

La note porte autant sur le **raisonnement** que sur la conclusion. Une réponse correcte obtenue par hasard, ou sans pouvoir justifier les conditions et les limites, ne doit pas être notée comme une maîtrise complète.

---

# Cartes de révision — OS Command Injection

## Comprendre

**Recto C1.** Quel est le défaut structurel unique derrière toute forme de command injection, quelle que soit la technique de confirmation utilisée ?
**Verso C1.** L'absence d'échappement ou de validation des métacaractères shell lors de la concaténation d'une donnée contrôlée par le client dans une commande exécutée par un interpréteur shell côté serveur — visible, temporisation, fichier et OOB ne sont que des canaux différents pour observer ce même défaut.

**Recto C2.** Quelle est la différence entre injection de commandes OS et injection de code (ex. `eval()`) ?
**Verso C2.** La command injection exécute une commande shell préexistante du système (`whoami`, `ls`...) ; l'injection de code exécute du code source interprété directement par le langage applicatif. La distinction compte car les défenses diffèrent (éviter l'invocation de shell vs éviter l'évaluation dynamique de code).

**Recto C3.** Pourquoi l'échappement manuel des métacaractères shell n'est-il jamais recommandé comme défense primaire ?
**Verso C3.** Parce que c'est une approche complexe, sujette aux oublis (encodages, substitutions `$(...)`, sauts de ligne) et systématiquement contournable en pratique — contrairement à une liste blanche stricte combinée à l'absence totale d'invocation de shell, qui empêche structurellement l'interprétation des métacaractères.

## Reconnaître

**Recto R1.** Un paramètre transmis à un script externe ne produit aucune sortie visible dans la réponse normale. Qu'est-ce que cela laisse anticiper si une injection est confirmée ?
**Verso R1.** Que l'injection sera probablement sous forme aveugle plutôt que visible (in-band) — il faut se préparer à passer rapidement aux techniques de confirmation aveugle (temporisation, fichier, OOB) en cas d'échec du test visible par séparateur.

**Recto R2.** Aucune chaîne injectée n'apparaît après test de tous les séparateurs classiques. Qu'est-ce que ce résultat permet, et ne permet **pas**, de conclure ?
**Verso R2.** Il n'infirme que l'hypothèse « sortie visible » — pas l'existence de l'injection elle-même, qui peut être aveugle ou utiliser une syntaxe alternative (substitution de commande, sortie de contexte) non encore testée.

**Recto R3.** Un paramètre rejette systématiquement toute valeur non numérique avant tout traitement. Est-ce un signal ambigu à approfondir ?
**Verso R3.** Non — c'est la contre-mesure recommandée par le cours appliquée correctement (validation stricte de type), une probable infirmation plutôt qu'un résultat à creuser davantage.

## Tester

**Recto T1.** Quelle référence établir avant tout test d'injection, et pourquoi est-elle indispensable pour un test de temporisation en particulier ?
**Verso T1.** Code HTTP, corps de réponse et temps de réponse d'une requête légitime, répétée plusieurs fois pour caractériser la latence normale — indispensable car la seule preuve disponible en temporisation est un écart de délai, impossible à interpréter sans référence.

**Recto T2.** Le séparateur `&` ne produit aucun effet visible. Quelles sont les deux erreurs fréquentes à éviter avant de conclure ?
**Verso T2.** Ne tester qu'un seul séparateur sans essayer les autres (`;`, `&&`, `|`, `||`, `%0a`) ; et oublier d'encoder le séparateur en GET, ce qui peut le faire interpréter comme délimiteur HTTP par un composant intermédiaire avant d'atteindre l'application.

**Recto T3.** Pourquoi faut-il tester la sortie de contexte avec guillemet simple **et** guillemet double séparément ?
**Verso T3.** Parce que le cours ne précise pas quel type de guillemet est utilisé côté applicatif pour concaténer l'entrée — un échec avec un seul type laisse la question ouverte, les deux doivent être testés indépendamment.

## Interpréter

**Recto I1.** Un délai de réponse plus long est observé une seule fois après injection d'une commande de pause. Est-ce une injection confirmée ?
**Verso I1.** Non — c'est seulement un comportement anormal. Il faut un délai reproductible sur plusieurs répétitions, corrélé à la durée de la commande injectée (ex. varier le compteur), pour établir la vulnérabilité confirmée.

**Recto I2.** Le fichier censé contenir le résultat de la commande redirigée renvoie un 404. Que peut-on en conclure ?
**Verso I2.** Rien de définitif seul — causes possibles : chemin incorrect, absence de droits d'écriture du processus serveur, ou absence réelle d'exécution. À croiser avec un résultat positif de temporisation avant de conclure à une absence d'injection.

**Recto I3.** Aucune résolution DNS n'est reçue sur le service OOB. Cela infirme-t-il l'injection ?
**Verso I3.** Non à elle seule — peut refléter une absence de connectivité sortante du serveur ou un filtrage DNS spécifique, sans rapport avec l'exécution de commande elle-même. À croiser avec les résultats des techniques précédentes (notamment temporisation).

## Exploiter

**Recto E1.** L'injection est confirmée par temporisation mais le fichier de sortie reste inaccessible. Comment poursuivre la chaîne d'exploitation ?
**Verso E1.** L'échec du fichier ne remet pas en cause la confirmation déjà acquise par temporisation — il documente une limite de l'environnement (chemin, droits). On passe à l'étape suivante disponible (OOB) pour obtenir un canal de retour exploitable.

**Recto E2.** Pourquoi tester les techniques dans l'ordre visible → temporisation → fichier → OOB plutôt que de commencer directement par l'OOB, présenté comme le plus fiable ?
**Verso E2.** Parce que la démarche progresse du signal le plus simple à confirmer vers le plus complexe, chaque technique n'étant mobilisée que si la précédente ne permet pas de conclure — l'OOB est le plus fiable en environnement filtrant, pas la méthode par défaut la plus rapide à mettre en œuvre.

**Recto E3.** Quelle est la différence de preuve d'impact entre une injection confirmée uniquement par temporisation et une injection confirmée via fichier ou OOB ?
**Verso E3.** Le timing seul démontre l'exécution de commande mais pas l'étendue de l'accès. Le fichier ou l'OOB permettent d'obtenir un résultat de commande de reconnaissance lisible, établissant un niveau de preuve d'impact documentant l'étendue réelle de l'accès.

## Déboguer et transférer

**Recto D1.** Le délai de temporisation n'est pas reproductible d'un essai à l'autre. Quelles deux causes distinguer, et comment ?
**Verso D1.** (a) bruit réseau/charge serveur ; (b) absence réelle d'injection. Répéter la mesure plusieurs fois à des moments différents et comparer à la distribution de référence — si le délai redevient cohérent, confirmé ; sinon, passer à la technique suivante.

**Recto D2.** Aucun délai n'est observé avec la syntaxe de pause testée. Quelle hypothèse vérifier avant de conclure à une absence d'injection ?
**Verso D2.** Vérifier que la syntaxe testée correspond bien à l'OS cible réel (ex. commande Linux testée sur une cible Windows) — un échec avec la syntaxe d'un OS inadapté ne doit pas être interprété comme une infirmation de l'injection.

**Recto D3.** Quel principe de la progression visible → temporisation → fichier → OOB se transfère à d'autres vulnérabilités, et quel élément reste strictement spécifique à la command injection ?
**Verso D3.** Se transfère : escalader du signal le plus simple vers le plus complexe, et la distinction comportement anormal / vulnérabilité confirmée / impact démontré. Reste spécifique : la liste des séparateurs shell et leur comportement par OS (ex. `&` différent entre Unix et Windows), et les commandes de reconnaissance elles-mêmes, propres à l'OS cible.

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
| Je ne comprends pas pourquoi la faille existe. | Cours de référence (sections 1 et 2) |
| Je ne sais pas quoi tester ensuite. | Méthodologie d'exploitation (sections 3 et 4) |
| Je connais le test, mais j'oublie la syntaxe exacte. | Cheat sheet (sections 3 et 9) |
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
