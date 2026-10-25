# Fiche de révision active — NoSQL Injection

> **Avant de commencer :** cette fiche doit être utilisée **sans consulter** `cours.md`, `exploitation.md` ou `cheatsheet.md`. Répondez à chaque question à voix haute ou par écrit, **puis seulement** comparez votre réponse au corrigé situé après la dernière question. Ne lisez pas le corrigé avant d'avoir répondu — l'objectif est de tester ce que vous savez réellement restituer et raisonner sans support, dans des conditions proches d'un examen pratique (eJPT, OSCP).

---

## Partie 1 — Fiche de révision active

### Catégorie 1 — Comprendre

**Q1.** Une NoSQL Injection implique un défaut situé dans un composant précis de l'application. Lequel, et quelle hypothèse incorrecte ce composant formule-t-il à propos de l'entrée utilisateur ?

**Q2.** Décrivez la chaîne causale complète qui mène d'une entrée utilisateur non séparée de la syntaxe de requête jusqu'à un impact de sécurité concret. Ne vous contentez pas de citer les deux mécanismes : expliquez *pourquoi* la divergence de logique de requête peut déboucher sur des impacts de nature différente selon le contexte.

**Q3.** Deux mécanismes d'injection NoSQL sont décrits comme « indépendants ». Pour chacun, précisez quelle frontière de confiance est rompue (entre quoi et quoi), et donnez un exemple de condition technique obligatoire pour que ce mécanisme précis soit exploitable.

**Q4.** Une application valide strictement que chaque champ JSON reçu est bien une chaîne de caractères avant de le transmettre au moteur NoSQL. Cette application est-elle protégée contre toute forme de NoSQL Injection ? Justifiez en expliquant ce que cette mesure corrige et ce qu'elle ne corrige pas.

**Q5.** Dans le fonctionnement normal (non vulnérable) d'une requête NoSQL construite à partir d'une entrée utilisateur, à quelle étape précise l'application est-elle censée intervenir pour empêcher toute divergence, et que se passe-t-il concrètement si cette étape est absente ou insuffisante ?

---

### Catégorie 2 — Reconnaître

**Q6.** Lors d'un test sur un paramètre `?category=` d'un endpoint de filtrage, vous envoyez `fizzy'` et obtenez une erreur 500 avec un message générique « Bad Request », alors que `fizzy` seul renvoie une liste de résultats. Que suggère cette observation, et qu'est-ce qu'elle **ne permet pas encore** d'affirmer ?

**Q7.** Vous interceptez une requête de login et remplacez `"password": "test123"` par `"password": {"$gt": ""}`. La requête est acceptée (code 200) sans message d'erreur de type invalide, et la réponse diffère de celle obtenue avec un mot de passe erroné classique. Quel signal cela constitue-t-il, et quelle vérification reste nécessaire avant de parler de vulnérabilité confirmée ?

**Q8.** Sur un paramètre de recherche, vous testez `test' && 0 && 'x` et `test' && 1 && 'x`. Les deux requêtes renvoient exactement la même page, avec le même nombre de résultats. Que pouvez-vous raisonnablement conclure à ce stade, et quelle piste indépendante reste à explorer ?

**Q9.** Un formulaire de contact renvoie une erreur générique « Une erreur est survenue » quel que soit le caractère spécial injecté (`'`, `"`, `\`, `{`). Ce comportement est-il un signal faible, un signal fort, ou une absence de signal concernant une NoSQL Injection ? Justifiez.

**Q10.** Sur un endpoint `/search?q=`, vous observez qu'une requête contenant un `{` provoque un code 400 avec le message « JSON malformé attendu en tant que chaîne », tandis qu'une requête contenant une apostrophe `'` ne provoque aucune différence. Ces deux observations pointent-elles vers le même mécanisme d'injection ou vers deux pistes distinctes ? Expliquez votre raisonnement.

---

### Catégorie 3 — Tester

**Q11.** Vous soupçonnez une injection par syntaxe sur le paramètre `category`. Formulez l'hypothèse testée, décrivez le test minimal à effectuer, la condition nécessaire pour interpréter correctement son résultat, le résultat attendu si l'hypothèse est vraie, et ce que ce test permettrait de conclure (sans aller plus loin que ce que le test démontre réellement).

**Q12.** Un champ `username` est transmis en JSON lors du login. Vous voulez tester si ce champ accepte un objet structuré à la place d'une chaîne. Décrivez le test minimal, la condition pour l'interpréter correctement, et précisez explicitement ce qu'un résultat positif confirmerait — et ce qu'il ne confirmerait **pas encore**.

**Q13.** Vous avez confirmé qu'un champ `password` accepte un objet JSON sans rejet. Vous voulez maintenant vérifier que l'opérateur injecté est **réellement interprété** par le moteur, et non simplement ignoré. Quel test précis effectueriez-vous, et sur quel critère jugeriez-vous le résultat concluant ?

**Q14.** Vous voulez déterminer si le moteur cible autorise l'évaluation d'expressions `$where`. Décrivez un test minimal et sûr pour cela, et expliquez pourquoi il est important de ne pas construire directement un test d'extraction avant d'avoir effectué ce test préalable.

**Q15.** Un champ mot de passe ne produit aucune différence visible de contenu ou de code HTTP entre un préfixe correct et un préfixe incorrect testé via `$regex`. Vous voulez tenter une extraction par canal temporel. Quelles conditions préalables devez-vous établir avant d'envoyer le moindre payload de type `sleep()`, et pourquoi chacune est-elle nécessaire ?

---

### Catégorie 4 — Interpréter

**Q16.** Vous envoyez `{"username": {"$ne": "invalid"}, "password": {"$ne": "invalid"}}` sur un formulaire de login. La requête est acceptée sans erreur de validation de type, mais la connexion échoue avec un message « Identifiants incorrects ». Que pouvez-vous conclure avec certitude, que reste-t-il d'incertain, et quelle vérification complémentaire aiderait à trancher ?

**Q17.** Vous testez `{"password": {"$regex": "^a.*"}}` et obtenez une réponse positive. Vous répétez exactement le même test dix minutes plus tard et obtenez cette fois une réponse négative, sans avoir rien changé. Quelles explications sont envisageables, et laquelle devez-vous exclure en priorité avant de poursuivre l'extraction ?

**Q18.** Lors d'un test d'injection temporelle avec `sleep(5000)`, une requête met 5,3 secondes à répondre alors que la baseline est à 0,2 seconde. Vous n'avez effectué ce test qu'une seule fois. Pouvez-vous considérer l'injection temporelle comme confirmée ? Détaillez ce qui manque pour passer de l'observation à la confirmation.

**Q19.** Un champ `role` accepte `{"$gt": ""}` sans provoquer d'erreur de validation, mais le comportement de l'application (contenu retourné, droits accordés) reste strictement identique à une requête de référence. Que pouvez-vous en conclure sur l'injection par opérateur sur ce champ précis, et que ne pouvez-vous pas généraliser à partir de cette seule observation ?

**Q20.** Un payload `'||'1'=='1` appliqué au paramètre `category` d'un catalogue produit élargit effectivement les résultats retournés à l'ensemble du catalogue, toutes catégories confondues. Le champ `category` ne sert qu'à l'affichage et n'intervient dans aucune décision d'autorisation. Comment qualifieriez-vous la sévérité réelle de cette confirmation technique, et qu'est-ce qui pourrait faire basculer son impact vers un niveau plus élevé ?

---

### Catégorie 5 — Exploiter

**Q21.** Construisez la chaîne complète d'un contournement d'authentification par injection par opérateur : précisez le point d'entrée contrôlable, le composant vulnérable, la condition de déclenchement, l'effet intermédiaire produit au niveau du moteur, le résultat final, et la preuve minimale qui démontrerait un impact réel (pas seulement une absence d'erreur).

**Q22.** Construisez la chaîne d'exploitation d'un élargissement de filtre par injection par syntaxe sur un paramètre de recherche. À quelle condition ce résultat technique constitue-t-il un impact de sécurité réellement significatif, et à quelle condition reste-t-il une curiosité sans conséquence pratique ?

**Q23.** Construisez la chaîne d'exploitation d'une extraction de donnée caractère par caractère via `$regex`, depuis la confirmation de l'injection par opérateur jusqu'à l'obtention de la valeur complète d'un champ sensible. Identifiez explicitement la condition nécessaire qui, si elle est absente, rend cette chaîne inutilisable telle quelle.

**Q24.** Vous avez confirmé que `$where` est disponible sur le moteur cible. Construisez une chaîne d'exploitation qui va au-delà d'une simple extraction de valeur de champ connu, en exploitant une capacité propre à `$where` et absente de `$regex`. Précisez la preuve qui distinguerait un simple test positif d'un usage réellement démontré.

**Q25.** Aucune distinction de contenu ou de code HTTP n'existe entre une condition vraie et une condition fausse sur un champ cible, mais `$where` et une fonction de délai sont disponibles. Construisez la chaîne d'exploitation basée sur le temps, en précisant à quel moment du processus vous établiriez la preuve que le délai observé est bien corrélé à la véracité de la condition, et non à du bruit.

---

### Catégorie 6 — Déboguer et transférer

**Q26.** Vous testez `'`, `"`, `\` et `{` sur un paramètre et n'obtenez aucune différence de comportement dans aucun cas. Un collègue en conclut que le point d'entrée est totalement sûr vis-à-vis des NoSQL Injection. Son raisonnement est-il correct ? Que lui répondriez-vous, et quelle(s) étape(s) manque(nt) avant de pouvoir affirmer une telle conclusion ?

**Q27.** Un champ JSON accepte un objet `{"$ne": "x"}` sans rejet, mais vous n'observez aucun changement de comportement de l'application. Vous voulez déterminer si c'est parce que (a) une validation de structure bloque silencieusement l'opérateur plus loin dans le traitement, ou (b) l'opérateur est transmis au moteur mais n'a simplement aucun effet pertinent sur ce champ précis. Comment distingueriez-vous ces deux causes par un test complémentaire ?

**Q28.** Un contournement d'authentification par `$ne` est techniquement accepté (pas d'erreur de type) mais la connexion échoue systématiquement. Diagnostiquez la cause la plus probable en vous appuyant sur ce que le cours précise à propos du traitement d'un résultat multiple, et proposez une voie alternative d'exploitation sur le même champ qui ne dépend pas de cette même condition.

**Q29.** Une extraction caractère par caractère via `$regex` qui progressait normalement se met soudain à répondre de façon identique quel que soit le caractère testé, après une cinquantaine de requêtes. Distinguez au moins deux causes possibles et indiquez comment les différencier sans supposer d'emblée que l'extraction a échoué définitivement.

**Q30.** Vous passez d'une cible MongoDB à une cible utilisant un moteur NoSQL différent (par exemple un moteur orienté clé-valeur sans opérateurs `$ne`/`$regex`/`$where`). Quels principes de raisonnement de cette fiche restent directement transférables à ce nouveau contexte, et quels éléments techniques précis devez-vous impérativement revérifier avant de réutiliser la moindre syntaxe de cette fiche ?

---

## Corrigé — Réponses attendues et raisonnement

**R1.** Le défaut se situe dans la **couche de construction de requête** de l'application — celle qui intègre une entrée utilisateur dans une requête destinée au moteur NoSQL. L'hypothèse incorrecte est que cette entrée restera nécessairement cantonnée au rôle de **donnée**, quelle que soit sa forme ou son contenu, alors qu'elle peut en réalité influencer soit la syntaxe textuelle de l'expression, soit la structure même de l'objet transmis au moteur.

**R2.** Chaîne attendue : l'application insère une entrée utilisateur dans une requête (par concaténation textuelle ou en laissant l'entrée déterminer la structure de l'objet transmis) → le moteur NoSQL interprète cette entrée non comme une simple valeur mais comme un fragment de syntaxe ou un opérateur légitime → la logique réellement exécutée diverge de celle voulue par l'application → cette divergence élargit, restreint ou modifie les critères de sélection/comparaison/évaluation → selon le contexte d'utilisation du résultat (authentification, affichage, recherche), cette divergence peut produire un contournement de contrôle d'accès, une fuite d'information ou un comportement anormal. La nature de l'impact dépend du contexte d'usage de la requête modifiée, pas seulement du mécanisme technique d'injection — un même mécanisme (élargissement de condition) peut être anodin sur un champ catégorie et critique sur un champ d'autorisation.

**R3.** 
- **Injection par syntaxe** : rompt la frontière entre **texte de requête** et **donnée textuelle** — le moteur ne peut pas distinguer, dans une chaîne concaténée, ce qui vient de l'application de ce qui vient de l'attaquant. Condition obligatoire : l'entrée doit être insérée par concaténation dans une expression textuelle, sans échappement des caractères spéciaux.
- **Injection par opérateur** : rompt la frontière entre **type attendu** et **type réellement reçu** — l'application suppose qu'un champ ne peut recevoir qu'une chaîne, sans valider le type reçu. Condition obligatoire : le format d'échange (JSON) doit permettre de soumettre un objet structuré à la place d'une chaîne, et l'application ne doit pas restreindre les clés/opérateurs acceptés dans les objets transmis.

**R4.** Non, pas nécessairement. Cette validation de type corrige la cause racine de l'**injection par opérateur** (elle empêche la structure de l'entrée de déterminer la logique de la requête). Mais elle ne traite en rien l'**injection par syntaxe** : une chaîne de caractères parfaitement valide du point de vue du type peut toujours contenir des caractères spéciaux (`'`, `"`, `\`) capables de rompre la délimitation d'une expression textuelle si celle-ci est construite par concaténation sans échappement. Les deux défenses sont complémentaires et indépendantes (cours, §10.4).

**R5.** L'application est censée intervenir à l'étape de **validation** de l'entrée, avant la construction de la requête : vérifier que l'entrée correspond strictement au type et au format attendus (une chaîne simple, sans structure ni syntaxe de requête). Si cette étape est absente ou insuffisante, l'entrée est transmise telle quelle à l'étape de construction de requête, où elle peut soit rompre la délimitation syntaxique (si concaténée sans échappement), soit déterminer la structure de l'objet transmis au moteur (si le type n'est pas vérifié) — c'est à cette étape de construction, et non à l'exécution par le moteur, que la divergence entre logique voulue et logique réelle prend naissance.

**R6.** Cela suggère une **détection** d'injection par syntaxe possible : le caractère spécial atteint potentiellement une expression de requête sans être neutralisé. Cela ne permet **pas encore** de conclure à une injection confirmée : une erreur générique de type « Bad Request » peut tout aussi bien provenir d'une validation générique du serveur web ou d'un bug sans rapport avec une injection NoSQL. Il faut passer à l'étape de confirmation par comparaison d'une condition manifestement fausse et manifestement vraie construites avec la même syntaxe, pour vérifier que l'entrée influence réellement la logique de la requête.

**R7.** Ce signal constitue une **détection** d'injection par opérateur : l'absence de rejet indique que l'application ne valide pas strictement le type reçu avant de le transmettre au moteur. La différence de réponse observée est encourageante mais ne suffit pas : il faut vérifier que l'opérateur `$gt` est **réellement interprété** avec sa sémantique attendue (par exemple en comparant son effet à celui d'une chaîne invalide classique, ou en testant un second opérateur à sémantique différente) plutôt que simplement accepté sans effet réel — l'objet peut être accepté pour d'autres raisons légitimes sans que l'opérateur soit effectivement appliqué par le moteur.

**R8.** On peut conclure que, sur ce test précis, l'injection par syntaxe **n'est pas confirmée** : les deux conditions construites pour être respectivement fausse et vraie produisent une réponse identique, ce qui ne permet pas de démontrer que l'entrée influence la logique de la requête. Cela ne garantit en rien l'absence totale de vulnérabilité sur ce point d'entrée : l'injection par opérateur, mécanisme indépendant, reste à tester (si le point d'entrée accepte du JSON), de même que la possibilité que la syntaxe utilisée (`&&`) ne corresponde pas au moteur ou au contexte réel de construction de la requête cible.

**R9.** C'est une **absence de signal exploitable** concernant une injection par syntaxe sur ce champ précis, pas un signal faible positif. Une réponse générique uniforme indique une gestion d'erreur durcie (bonne pratique défensive), mais cela ne permet pas de conclure que le champ est protégé contre toutes les variantes : il faudrait encore tester si le format d'échange du formulaire permet une injection par opérateur, mécanisme totalement indépendant qui ne laisserait pas nécessairement d'erreur visible de ce type.

**R10.** Ces deux observations pointent vers **deux pistes distinctes et indépendantes**. Le rejet explicite sur `{` avec un message évoquant un format JSON suggère que l'application **valide le type attendu** pour ce champ (protection potentielle contre l'injection par opérateur, puisqu'un objet structuré semble détecté et rejeté). L'absence de différence sur l'apostrophe ne dit rien de cette protection : elle indique seulement qu'aucun signal d'injection par syntaxe n'a été détecté sur ce test précis — mécanisme indépendant de la validation de type observée sur `{`. Il ne faut pas déduire une protection générale à partir de l'une ou l'autre observation isolément.

**R11.** 
- **Hypothèse** : l'entrée du paramètre `category` est concaténée sans échappement dans une expression textuelle du type `this.category == '...'`.
- **Test minimal** : envoyer `category` suivi d'une apostrophe (`fizzy'`), puis comparer une condition fausse (`fizzy' && 0 && 'x`) et une condition vraie (`fizzy' && 1 && 'x`) construites selon la même syntaxe.
- **Condition d'interprétation** : disposer au préalable d'une réponse de référence pour la valeur légitime `fizzy`, pour distinguer un changement réel d'un bruit.
- **Résultat attendu si vraie** : la forme `&& 0 &&` produit une réponse cohérente avec une condition fausse (ex. absence de résultats), la forme `&& 1 &&` une réponse cohérente avec une condition vraie (résultats inchangés ou élargis).
- **Ce que cela permettrait de conclure** : uniquement que l'entrée influence réellement la logique de la requête (confirmation) — pas encore qu'un impact exploitable en découle ; l'exploitation (élargissement de filtre) reste une étape ultérieure distincte.

**R12.** 
- **Test minimal** : remplacer la valeur chaîne attendue (`"username": "wiener"`) par un objet contenant un opérateur improbable à provoquer un faux positif, par exemple `{"username": {"$ne": "une_valeur_absurde_et_improbable"}}`.
- **Condition d'interprétation** : disposer de la réponse de référence pour une requête légitime et pour une requête invalide anodine, afin de distinguer un comportement provoqué d'un comportement normal.
- **Ce qu'un résultat positif confirmerait** : que l'application ne valide pas strictement le type du champ avant transmission au moteur (détection d'injection par opérateur).
- **Ce qu'il ne confirmerait pas encore** : que l'opérateur injecté est réellement **interprété** par le moteur selon sa sémantique attendue — l'absence de rejet peut aussi provenir d'une tolérance applicative sans rapport avec une interprétation effective par le moteur de base de données.

**R13.** Test précis : utiliser un opérateur dont la sémantique produit un résultat **vérifiable et discriminant**, par exemple `{"password": {"$regex": "^a.*"}}` avec un `username` connu, puis comparer à un second test avec un motif ne correspondant certainement pas (`^z.*` par exemple, si le mot de passe réel est inconnu mais qu'on peut tester un motif extrême). Critère de conclusion : le résultat doit être **cohérent avec la sémantique de l'opérateur** — la réponse doit varier selon que le motif correspond réellement ou non à la donnée stockée, et non être identique quel que soit le motif testé (ce qui indiquerait un objet accepté mais sans effet réel, donc non concluant).

**R14.** Test minimal et sûr : soumettre une expression `$where` totalement inoffensive et dont le résultat est prévisible dans tous les cas, par exemple `{"$where": "1 == 1"}`. Il est important d'effectuer ce test **avant** toute tentative d'extraction, car la disponibilité de `$where` n'est pas universelle : elle dépend strictement de la configuration du moteur (de nombreuses configurations modernes la restreignent ou la désactivent). Construire directement une extraction sur l'hypothèse non vérifiée que `$where` fonctionne risquerait de confondre un simple rejet de `$where` avec un échec d'extraction, brouillant le diagnostic.

**R15.** Conditions préalables nécessaires :
1. Confirmer que `$where` lui-même est disponible sur le moteur (test préalable distinct, voir Q14) — sans quoi `sleep()` ne pourra de toute façon pas être évalué.
2. Établir une **mesure de référence fiable** du temps de réponse habituel de l'application (plusieurs requêtes témoins sans payload), car de nombreux facteurs externes (réseau, charge serveur) peuvent influencer le temps de réponse et fausser l'interprétation d'une seule mesure.
3. Prévoir de **répéter chaque mesure** plusieurs fois une fois le test lancé, pour comparer une distribution plutôt qu'une valeur unique, le but étant d'écarter le bruit réseau d'un signal temporel réel et reproductible.
Chacune de ces conditions est nécessaire car, sans elles, un délai observé une seule fois ne peut pas être distingué d'une simple variation de latence sans lien avec l'injection testée.

**R16.** Ce que l'on peut conclure avec certitude : l'injection par opérateur a été **confirmée** à un niveau technique — l'objet `$ne` est accepté sans rejet de type. Ce qui reste incertain : pourquoi la connexion échoue malgré cela. Le cours précise explicitement que le contournement d'authentification **n'est pas garanti** : il dépend de la manière dont l'application traite un résultat multiple ou le premier document trouvé — l'application peut appliquer une vérification supplémentaire après l'exécution de la requête (par exemple, vérifier explicitement qu'un seul document correspond). Vérification complémentaire utile : tenter une extraction caractère par caractère du mot de passe sur ce même champ (étape indépendante de cette couche de vérification post-requête), qui pourrait réussir même si le contournement direct échoue.

**R17.** Explications envisageables : (a) comportement non déterministe réel de l'application (peu probable sans autre cause identifiée), (b) changement d'état de la donnée entre les deux tests (le mot de passe a été modifié), (c) **bruit ou erreur de manipulation** lors de l'un des deux tests (payload mal reconstruit, session expirée entre-temps, etc.), (d) un comportement de l'application lié au débit (rate limiting modifiant la réponse après un certain nombre de requêtes). Priorité d'exclusion : avant de poursuivre l'extraction, il faut **répéter immédiatement le test contesté plusieurs fois de suite**, dans des conditions identiques et rapprochées, pour écarter un résultat non reproductible — le cours insiste explicitement sur le fait qu'une différence non reproductible ne doit jamais être traitée comme confirmée sans répétition.

**R18.** Non, ce résultat **ne peut pas être considéré comme confirmé** à partir d'une seule mesure. Il manque : (1) une mesure de référence répétée (plusieurs requêtes témoins sans payload, pas une seule) pour établir une baseline fiable ; (2) une répétition du test avec `sleep()` lui-même, pour vérifier que le délai de ~5 secondes est **reproductible** et non un pic isolé de charge serveur ou de latence réseau ; (3) idéalement, une comparaison avec une condition construite comme fausse selon le même principe, pour vérifier que le délai est bien corrélé à la valeur de vérité de la condition testée et non systématique quel que soit le payload envoyé.

**R19.** On ne peut conclure, sur ce champ précis, qu'à une **absence d'effet observable** de l'opérateur injecté — pas à une absence d'injection par opérateur en général sur l'application. Deux explications restent possibles et doivent être distinguées par un test complémentaire (voir R27) : soit une validation de structure bloque silencieusement l'effet de l'opérateur plus loin dans le traitement, soit l'objet est transmis au moteur mais l'opérateur `$gt` n'a simplement aucun effet pertinent sur ce champ précis (par exemple parce que le champ `role` n'est jamais réellement utilisé dans une comparaison de ce type). Ce qu'on ne peut pas généraliser : que l'injection par opérateur est fermée sur les **autres** champs JSON de l'application — chaque champ doit être testé individuellement, la protection n'étant pas garantie uniforme (cours, §10.4).

**R20.** La confirmation technique est réelle (élargissement de filtre démontré), mais sa **sévérité pratique reste faible** dans ce cas précis : le champ `category` ne sert qu'à l'affichage et n'intervient dans aucune décision d'autorisation — élargir les résultats d'un catalogue produit n'expose rien de sensible en soi. L'impact basculerait vers un niveau plus élevé si le même mécanisme technique (disjonction logique ajoutée à une condition) s'appliquait à un champ utilisé pour une décision d'autorisation ou de visibilité de données sensibles — le cours précise explicitement que l'impact d'un élargissement de filtre dépend entièrement de la sensibilité du champ ciblé, pas seulement de la confirmation technique du mécanisme.

**R21.** 
- **Point d'entrée** : champs `username`/`password` d'un formulaire de login transmis en JSON.
- **Composant vulnérable** : la couche de construction de requête qui ne valide pas le type des champs reçus avant transmission au moteur.
- **Condition de déclenchement** : soumission d'objets `{"$ne": "invalid"}` sur les deux champs (ou `$in` pour un ciblage de compte précis).
- **Effet intermédiaire** : le moteur retourne un ou plusieurs documents correspondant à la condition modifiée, sans connaissance réelle des identifiants.
- **Résultat final** : l'application traite ce résultat comme une authentification valide (condition non garantie, à vérifier empiriquement).
- **Preuve minimale** : accès effectif et vérifiable à une zone/fonctionnalité réservée à un utilisateur authentifié (pas seulement l'absence d'erreur à la soumission du formulaire) — distinction explicitement soulignée dans la méthodologie comme erreur fréquente à éviter.

**R22.** Chaîne : point d'entrée = paramètre de filtre/recherche concaténé dans une expression textuelle → composant vulnérable = construction de requête sans échappement → déclenchement = injection d'une disjonction toujours vraie (`'||'1'=='1`) → effet intermédiaire = la condition de filtre devient structurellement toujours vraie → résultat = retour de documents hors du périmètre attendu par le filtre. Condition pour un impact réellement significatif : le champ ou la fonctionnalité filtrée doit porter sur des données dont la visibilité est censée être restreinte (contrôle d'accès, données privées, autorisation). Condition pour rester une curiosité sans conséquence : le champ filtré ne conditionne rien de sensible (catégorie d'affichage, tri cosmétique) — la confirmation technique existe mais sans impact métier réel.

**R23.** Chaîne : injection par opérateur confirmée comme interprétée avec effet cohérent (étape de confirmation préalable, Q13) → sélection d'un opérateur discriminant (`$regex`) → test itératif de préfixes de longueur croissante (`^a.*`, puis `^ab.*` si positif, sinon `^b.*`...) → à chaque itération, observation de la distinction vrai/faux dans la réponse → reconstruction progressive de la valeur complète. Condition nécessaire sans laquelle la chaîne est inutilisable telle quelle : une **distinction observable** stable entre un résultat positif et un résultat négatif dans la réponse de l'application — en son absence, il faut basculer vers une extraction basée sur le temps (Q25) plutôt que d'insister sur cette chaîne.

**R24.** Capacité propre à `$where` et absente de `$regex` : l'évaluation de **code JavaScript arbitraire**, permettant par exemple la **découverte de noms de champs inconnus** sans connaître le schéma au préalable (`Object.keys(this)[0].match('^.{0}a.*')`), ou un test structurel comme l'accès par index/méthode (`this.password.match(/\d/)`), impossibles avec un simple opérateur de comparaison déclaratif. Chaîne : `$where` confirmé disponible → construction d'une expression testant une propriété ou un index non accessible via `$regex` → observation du comportement cohérent avec la logique testée → itération pour cartographier le schéma ou extraire une propriété. Preuve d'un usage réellement démontré (par opposition à un simple test positif) : obtenir un résultat concret et vérifiable allant au-delà de l'observation — par exemple la liste effective des noms de champs d'un document inconnu, confirmée par recoupement, plutôt qu'une seule expression ponctuelle évaluée comme vraie.

**R25.** Chaîne : absence de distinction de contenu confirmée (étape d'extraction classique ayant échoué) → `$where` et fonction de délai confirmés disponibles (test préalable indépendant) → construction d'une condition combinant le test de caractère et un `sleep()` conditionnel (`this.CHAMP[0] == 'a' && sleep(5000) || true`) → mesure du délai de réponse par rapport à la baseline établie. Moment où la preuve de corrélation doit être établie : **avant** de considérer un seul caractère comme confirmé — il faut comparer le délai mesuré pour la condition testée à la fois à la baseline **et** à une condition construite comme fausse pour la même position, et répéter cette comparaison plusieurs fois pour écarter le bruit, avant de valider ce caractère et de passer au suivant. Valider l'ensemble d'une chaîne extraite sans cette répétition systématique à chaque position expose à accumuler des erreurs individuelles non détectées.

**R26.** Son raisonnement est **incorrect**. L'absence de différence sur les quatre caractères testés ne permet de conclure qu'à l'absence de signal pour l'**injection par syntaxe** sur ce point d'entrée précis — cela ne dit rien de l'**injection par opérateur**, mécanisme totalement indépendant qui ne laisse pas nécessairement de trace via ces caractères. Avant de pouvoir affirmer une absence totale de vulnérabilité NoSQL, il faudrait au minimum tester également la soumission d'un objet structuré à la place d'une chaîne sur ce même champ (si le format d'échange le permet), étape distincte qui n'a pas été réalisée.

**R27.** Test complémentaire pour distinguer les deux causes : soumettre un **second opérateur à sémantique différente** et dont l'effet serait clairement vérifiable, par exemple `{"$regex": "^.*"}` (qui devrait matcher toute valeur non vide) comparé à `{"$regex": "^zzzz_improbable.*"}` (qui ne devrait matcher aucune valeur réelle). Si les deux produisent le même comportement malgré leur sémantique opposée, cela pointe vers (a) une validation de structure bloquant silencieusement l'effet. Si au contraire l'un produit un effet et l'autre non, de façon cohérente avec leur sémantique, cela confirme que les opérateurs **sont** transmis et interprétés, et que c'est spécifiquement `$ne` sur ce champ qui n'a pas d'effet pertinent (cause b) — peut-être parce que le champ `role` contient une valeur rarement égale à `"x"` de toute façon, rendant `$ne` peu discriminant dans ce contexte précis.

**R28.** Cause la plus probable : le cours précise explicitement que le contournement par `$ne` dépend de la manière dont l'application traite **un résultat multiple ou le premier document trouvé** — ici, l'application applique vraisemblablement une **vérification supplémentaire après l'exécution de la requête** (par exemple, elle vérifie explicitement qu'un seul document correspond à la requête, ou comparer un champ supplémentaire), neutralisant le contournement malgré une injection techniquement acceptée au niveau du moteur. Voie alternative ne dépendant pas de cette condition : tenter une **extraction caractère par caractère** du mot de passe réel via `$regex` sur ce même champ — cette technique ne repose pas sur le traitement d'un résultat multiple par l'application, mais uniquement sur une distinction observable entre préfixe correct et incorrect, donc elle n'est pas affectée par la vérification supplémentaire qui bloque le contournement direct.

**R29.** Causes possibles à distinguer : (a) une **limitation de débit ou de tentatives** (rate limiting) déclenchée après un certain nombre de requêtes, modifiant le comportement de l'application de façon temporaire ou définitive ; (b) un **blocage réel** indiquant que l'extraction a atteint une limite technique (fin du champ, caractère hors du jeu testé). Différenciation : observer si le changement de comportement est **progressif** (ralentissement, réponses de plus en plus lentes ou atypiques, caractéristique d'un rate limiting) ou **brutal** (passage immédiat d'un comportement discriminant à un comportement uniforme, pouvant indiquer une fin de valeur ou un verrou). Test pratique : espacer significativement les requêtes suivantes et observer si le comportement discriminant se rétablit — s'il se rétablit, il s'agissait d'une limitation de débit temporaire ; sinon, il faut envisager que l'extraction a atteint ses limites avec le jeu de caractères testé (élargir l'alphabet testé au-delà des lettres simples, par exemple).

**R30.** Principes directement transférables : distinguer **détection / confirmation / impact démontré** avant de conclure quoi que ce soit ; tester les mécanismes d'injection par syntaxe et par opérateur comme deux pistes **indépendantes**, sans présumer qu'une protection contre l'une couvre l'autre ; toujours répéter un test de comparaison avant de le considérer confirmé, en particulier pour tout ce qui repose sur une mesure de temps ; étendre un test confirmé sur un point d'entrée à l'ensemble des points d'entrée comparables, la protection n'étant jamais garantie uniforme. Éléments techniques à impérativement revérifier : la **syntaxe exacte** de délimitation textuelle (les opérateurs logiques `&&`/`||` sont propres à un contexte JavaScript/MongoDB, pas universels) ; l'**existence même** et le **nom** des opérateurs structurés équivalents à `$ne`/`$regex`/`$where` sur le nouveau moteur (un moteur clé-valeur peut n'avoir aucun équivalent à l'injection par opérateur telle que décrite ici, auquel cas seule l'injection par syntaxe resterait pertinente, si le moteur construit ses requêtes par concaténation textuelle) ; la disponibilité d'une fonction de délai équivalente à `sleep()` pour toute tentative d'extraction temporelle.

---

## Barème d'auto-évaluation

Pour chaque question, notez-vous selon l'échelle suivante avant de passer à la suivante :

| Score | Niveau | Description |
|---|---|---|
| **0** | Bloqué | Aucune réponse pertinente possible sans consulter les notes. |
| **1** | Avec aide | Réponse correcte seulement partielle, ou obtenue après un indice/une relecture partielle. |
| **2** | Autonome sur un cas connu | Réponse correcte et complète sur un scénario proche de ceux déjà rencontrés. |
| **3** | Transfert | Réponse correcte, justifiée et assortie de ses limites, y compris sur une situation modifiée ou inédite par rapport aux exemples déjà vus. |

**Important :** ce barème évalue le **raisonnement** autant que la conclusion finale. Une réponse juste obtenue par chance, sans justification solide ni conscience des conditions et limites en jeu, ne constitue pas une maîtrise de niveau 2 ou 3 — réévaluez-vous honnêtement si vous avez deviné juste sans pouvoir expliquer pourquoi.

---

## Partie 2 — Cartes de révision

> 18 cartes, 3 par catégorie. Chaque carte teste une seule compétence ou notion. Recto = question/situation ; Verso = réponse concise et vérifiable.

### Comprendre

**Carte 1**
**Recto :** Quels sont les deux mécanismes d'injection NoSQL décrits comme indépendants, et quelle frontière de confiance chacun rompt-il ?
**Verso :** Injection par **syntaxe** (rompt la frontière texte de requête / donnée textuelle, via rupture de délimitation par concaténation non échappée) et injection par **opérateur** (rompt la frontière type attendu / type réellement reçu, via substitution d'un objet structuré à une chaîne attendue). Les deux exigent des tests et défenses distincts.

**Carte 2**
**Recto :** Pourquoi une application peut-elle être protégée contre l'injection par opérateur tout en restant vulnérable à l'injection par syntaxe (ou l'inverse) ?
**Verso :** Parce que ces deux mécanismes ciblent des couches différentes de la construction de requête : la validation de type (contre l'opérateur) ne corrige rien à l'échappement syntaxique dans une expression textuelle concaténée (contre la syntaxe), et réciproquement. Ce sont deux défenses complémentaires, pas substituables l'une à l'autre.

**Carte 3**
**Recto :** Quelle est la cause racine commune, formulée de façon générale, aux deux mécanismes d'injection NoSQL ?
**Verso :** L'absence de séparation stricte entre les données fournies par l'utilisateur et la syntaxe ou la structure de la requête exécutée par la base de données — l'entrée n'est pas garantie de rester cantonnée au rôle de simple donnée.

### Reconnaître

**Carte 4**
**Recto :** Un paramètre GET renvoie une erreur 500 générique sur l'envoi d'une apostrophe, sans autre précision. Quel est le niveau de preuve atteint ?
**Verso :** Une simple **détection** — un indice, pas une confirmation. L'erreur peut provenir d'une validation générique sans rapport avec une injection NoSQL. Il faut passer à la comparaison vraie/fausse pour confirmer que l'entrée influence réellement la logique de la requête.

**Carte 5**
**Recto :** Un champ JSON accepte un objet `{"$ne": "x"}` sans rejet de type. Suffit-il à confirmer l'injection par opérateur ?
**Verso :** Non. L'absence de rejet confirme seulement l'absence de validation stricte du type. Il faut encore vérifier que l'opérateur produit un effet **cohérent avec sa sémantique attendue** (ex. comparer à un second opérateur discriminant) avant de parler de confirmation.

**Carte 6**
**Recto :** Deux requêtes construites pour être respectivement « manifestement fausse » et « manifestement vraie » selon la même syntaxe d'injection renvoient des réponses strictement identiques. Que peut-on en déduire ?
**Verso :** L'injection par syntaxe **n'est pas confirmée** sur ce test précis — mais cela ne dit rien du mécanisme indépendant (injection par opérateur), qui reste à tester séparément si le point d'entrée le permet.

### Tester

**Carte 7**
**Recto :** Avant de tester une comparaison vraie/fausse pour confirmer une injection par syntaxe, quelle référence faut-il impérativement avoir établie ?
**Verso :** Le comportement de réponse pour la valeur légitime (référence) et pour une valeur invalide anodine — sans cette base de comparaison, impossible de juger si une différence observée est significative.

**Carte 8**
**Recto :** Quel test minimal permet de vérifier qu'un opérateur injecté (ex. `$regex`) est réellement interprété par le moteur, plutôt que simplement accepté sans effet ?
**Verso :** Tester un motif dont la correspondance avec la donnée réelle est connue ou extrême (ex. motif certainement non correspondant), et vérifier que la réponse **varie** selon la correspondance réelle — une réponse identique quel que soit le motif indique un effet non interprété.

**Carte 9**
**Recto :** Pourquoi faut-il tester `{"$where": "1 == 1"}` avant toute tentative d'extraction via `$where` ?
**Verso :** Parce que la disponibilité de `$where` n'est pas universelle (dépend strictement de la configuration du moteur). Construire une extraction sur une hypothèse non vérifiée risquerait de confondre un rejet de `$where` lui-même avec un échec de l'extraction.

### Interpréter

**Carte 10**
**Recto :** Un `$ne` est accepté sans erreur sur les deux champs de login, mais la connexion échoue quand même. Quelle explication le cours donne-t-il explicitement ?
**Verso :** L'application peut appliquer une **vérification supplémentaire après l'exécution de la requête** (ex. contrôle qu'un seul document correspond) — le contournement par résultat multiple n'est jamais garanti, dépendant entièrement du traitement applicatif du résultat.

**Carte 11**
**Recto :** Un délai de 5 secondes est observé une seule fois avec `sleep(5000)`, contre une baseline à 0,2 seconde. Est-ce suffisant pour confirmer une injection temporelle ?
**Verso :** Non. Il manque une baseline établie sur plusieurs mesures, une répétition du test lui-même, et idéalement une comparaison avec une condition construite comme fausse — une mesure isolée ne distingue pas un signal réel d'un pic de charge ou de latence réseau.

**Carte 12**
**Recto :** Un élargissement de filtre confirmé technique s'applique à un champ `category` purement cosmétique, sans rôle dans l'autorisation. Comment qualifier son impact réel ?
**Verso :** Impact technique confirmé mais **sévérité faible** en l'état — le champ ne contrôle aucune donnée sensible. L'impact basculerait vers critique si le même mécanisme s'appliquait à un champ utilisé pour une décision d'autorisation ou de visibilité de données.

### Exploiter

**Carte 13**
**Recto :** Dans la chaîne d'un contournement d'authentification par `$ne`, quelle est la preuve minimale acceptable — et quelle erreur fréquente faut-il éviter ?
**Verso :** Preuve minimale : accès effectif et vérifiable à une zone/fonctionnalité réservée à un utilisateur authentifié. Erreur fréquente : confondre une requête acceptée sans erreur de type avec un contournement réussi, sans vérifier l'accès effectif obtenu.

**Carte 14**
**Recto :** Quelle condition unique détermine si une extraction `$regex` caractère par caractère est utilisable telle quelle sur un champ donné ?
**Verso :** L'existence d'une **distinction observable stable** entre un résultat positif et un résultat négatif dans la réponse de l'application. En son absence, il faut basculer vers une extraction basée sur le temps plutôt que d'insister sur cette technique.

**Carte 15**
**Recto :** Qu'est-ce que `$where` permet de faire qu'un simple opérateur `$regex` ne permet pas ?
**Verso :** Évaluer du **code JavaScript arbitraire** — notamment découvrir des noms de champs inconnus sans schéma préalable (`Object.keys(this)`), ou tester des propriétés/index structurels, au-delà d'une simple comparaison déclarative de chaîne.

### Déboguer et transférer

**Carte 16**
**Recto :** Aucun des quatre caractères spéciaux (`'`, `"`, `\`, `{`) ne produit de différence sur un paramètre. Peut-on conclure à une absence totale de vulnérabilité NoSQL sur ce point d'entrée ?
**Verso :** Non — cela écarte seulement l'injection par **syntaxe** sur ce test précis. L'injection par **opérateur**, mécanisme indépendant, reste à tester séparément (si le format d'échange le permet) avant toute conclusion générale.

**Carte 17**
**Recto :** Un opérateur est accepté sans rejet mais sans effet observable. Comment distinguer une validation de structure bloquant silencieusement l'effet d'un opérateur simplement sans effet pertinent sur ce champ ?
**Verso :** Tester un **second opérateur à sémantique différente** et clairement discriminant (ex. deux motifs `$regex` aux effets opposés attendus). Si les deux restent sans effet cohérent, la cause est probablement une validation en aval ; si l'un produit un effet cohérent avec sa sémantique, l'opérateur initial était simplement non pertinent sur ce champ.

**Carte 18**
**Recto :** Vous changez de cible pour un moteur NoSQL sans opérateurs de type `$ne`/`$regex`/`$where`. Quel principe de raisonnement reste transférable malgré ce changement technique ?
**Verso :** Distinguer systématiquement détection / confirmation / impact démontré, et tester injection par syntaxe et injection par opérateur comme deux pistes indépendantes sans présumer que l'absence de l'une implique l'absence de l'autre — les opérateurs précis, eux, ne sont pas transférables tels quels et doivent être revérifiés sur le nouveau moteur.

---

## Partie 3 — Organisation des révisions

### Première tentative

1. Répondez à toutes les questions **sans consulter** `cours.md`, `exploitation.md`, `cheatsheet.md` ni le corrigé ci-dessus.
2. Marquez immédiatement les questions pour lesquelles vous êtes resté totalement bloqué (score 0 prévisible).
3. Pour les réponses partielles ou devinées, notez-le explicitement à côté de votre réponse avant de comparer — ne corrigez pas rétroactivement votre souvenir après avoir lu le corrigé.
4. Consultez le corrigé **uniquement après** avoir répondu à l'ensemble des 30 questions, pas question par question.
5. Attribuez-vous un score de 0 à 3 par question selon le barème, honnêtement, y compris pour les bonnes réponses obtenues par chance.

### Après correction

Ne relisez jamais l'intégralité des trois documents sources après une première tentative : identifiez précisément la nature de votre blocage et ne consultez que la ressource correspondante, puis reprenez la question de mémoire.

| Difficulté exprimée | Document à consulter |
|---|---|
| « Je ne comprends pas pourquoi les deux mécanismes sont indépendants / pourquoi la vulnérabilité existe. » | `cours.md` |
| « Je ne sais pas quel test effectuer ensuite / dans quel ordre tester syntaxe vs opérateur. » | `exploitation.md` (méthodologie) |
| « Je connais le principe du test, mais j'oublie la syntaxe exacte du payload. » | `cheatsheet.md` |
| « Je ne sais pas si mon observation suffit à conclure / ce qu'il reste à vérifier. » | `exploitation.md`, sections « Indices et faux positifs » et « Diagnostic des échecs » |
| « Je ne sais pas comment relier un résultat technique à un impact réel. » | `exploitation.md`, section « Vérification de l'exploitation et preuve de l'impact » |
| « Je confonds les deux mécanismes entre eux. » | `cours.md`, section 4 (tableau comparatif) |

### Révisions espacées

| Jour | Action |
|---|---|
| **Jour 0** | Première tentative en rappel actif, correction, score par question. |
| **Jour 1** | Revoir uniquement les questions notées 0 ou 1, sans relire les sections non concernées. |
| **Jour 3** | Nouvelle tentative complète sans notes, en conditions proches de l'examen. |
| **Jour 7** | Revoir les questions encore en échec après la tentative du Jour 3. |
| **Jour 14** | Se concentrer sur les questions de transfert (catégories Exploiter et Déboguer et transférer), notamment la Q30. |
| **Jour 30** | Vérification globale de maîtrise sur l'ensemble des 30 questions, en conditions d'examen. |

Ces intervalles sont indicatifs : une carte ou une question systématiquement ratée doit être revue **plus tôt** que ce calendrier, tandis qu'une question maîtrisée dès le Jour 0 avec un score 3 justifié peut être espacée davantage. Un calendrier fixe ne garantit pas, à lui seul, la mémorisation — l'essentiel reste la qualité du rappel actif à chaque tentative.
