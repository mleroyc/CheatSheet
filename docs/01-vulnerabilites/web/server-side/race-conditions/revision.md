# Fiche de révision active — Race Conditions (Concurrence)

> **Avant de commencer :** cette fiche doit être utilisée **sans consulter** `cours.md`, `exploitation.md` ou `cheatsheet.md`. Répondez à chaque question à voix haute ou par écrit, **puis seulement** comparez votre réponse au corrigé situé après la dernière question. Ne lisez pas le corrigé avant d'avoir répondu — l'objectif est de tester ce que vous savez réellement restituer et raisonner sans support, dans des conditions proches d'un examen pratique (eJPT, OSCP).

---

## Partie 1 — Fiche de révision active

### Catégorie 1 — Comprendre

**Q1.** Définissez une race condition web en précisant le défaut de nature exacte en jeu (pas seulement « deux requêtes en même temps »), puis expliquez le lien entre le schéma TOCTOU et la « fenêtre de tir » (*race window*).

**Q2.** Décrivez les trois étapes du mécanisme de Limit Overrun (Check / Use / Update) et expliquez précisément *entre quelles étapes* se situe la fenêtre exploitable — pas seulement « entre le début et la fin ».

**Q3.** Pourquoi une requête concurrente lancée pendant la fenêtre de tir obtient-elle le même résultat « disponible » qu'une première requête, indépendamment du nombre de requêtes déjà engagées dans les étapes suivantes ? Formulez la réponse au niveau du mécanisme, pas de l'exemple.

**Q4.** Quelle est la condition technique commune à **toutes** les variantes de race condition couvertes par cette fiche (Limit Overrun, multi-endpoints, contexte croisé, séquence cachée, construction partielle), indépendamment du scénario métier précis ?

**Q5.** Cette fiche précise explicitement ne pas couvrir certains sujets proches. Citez-en au moins deux, et expliquez pourquoi leur absence ne constitue pas une lacune du raisonnement mais une délimitation assumée du périmètre.

---

### Catégorie 2 — Reconnaître

**Q6.** Lors d'un test en parallèle sur un endpoint de rachat de code promo, vous obtenez un code `409 Conflict` sur l'ensemble des requêtes du groupe. Ce résultat est-il, à lui seul, un signal de vulnérabilité ? Justifiez.

**Q7.** Après une rafale de 15 requêtes identiques envoyées en paquet unique sur un endpoint de crédit de solde, toutes les réponses individuelles affichent un code 200 cohérent avec un succès isolé, mais une requête de vérification indépendante révèle un solde supérieur au montant théorique attendu. Quel est le niveau de preuve atteint ici ?

**Q8.** Vous testez un Limit Overrun avec la technique du dernier octet sous HTTP/1.1 et n'observez aucune déviation sur un seul essai. Que suggère cette observation isolée, et que ne permet-elle **pas encore** de conclure ?

**Q9.** Deux signaux sont observés sur des endpoints différents : (a) un code `500` apparaît dans le groupe de requêtes parallèles ; (b) un code `409 Conflict` apparaît systématiquement. Lequel de ces deux signaux pointe le plus directement vers une collision réelle, et pourquoi l'autre doit-il être interprété avec prudence ?

**Q10.** Un `Content-Length` varie entre deux réponses apparemment identiques dans un groupe de requêtes parallèles envoyées sur le même endpoint avec le même corps de requête. Que suggère cette observation, et quelle vérification reste nécessaire avant de la documenter comme preuve ?

---

### Catégorie 3 — Tester

**Q11.** Formulez l'hypothèse, le test minimal, la condition d'interprétation, le résultat attendu et ce que le test permettrait de conclure pour un **Limit Overrun** sur un endpoint de rachat de code promo, en incluant explicitement l'étape de référence préalable.

**Q12.** Vous devez choisir entre l'attaque par paquet unique (HTTP/2) et la technique du dernier octet (HTTP/1.1) pour synchroniser un groupe de requêtes. Quel test préalable détermine ce choix, et pourquoi un résultat négatif obtenu avec la technique du dernier octet doit-il être interprété différemment d'un résultat négatif obtenu avec le paquet unique ?

**Q13.** Vous suspectez qu'un verrouillage de session PHP masque l'effet de concurrence recherché. Décrivez le test de dissociation de session, la condition préalable nécessaire pour le réaliser, et ce qu'un résultat positif confirmerait.

**Q14.** Avant de tester une race condition **multi-endpoints** (ex. panier + checkout), quelle précaution opérationnelle faut-il prendre, et pourquoi son omission risquerait de fausser l'interprétation du résultat ?

**Q15.** Vous voulez tester une **séquence multi-étapes cachée** de type contournement de MFA. Décrivez le test minimal (quelles requêtes, dans quel mode d'envoi), la condition nécessaire pour l'interpréter correctement, et ce qu'un résultat positif démontrerait exactement.

---

### Catégorie 4 — Interpréter

**Q16.** Vous testez un Limit Overrun avec la technique du dernier octet sous HTTP/1.1 (HTTP/2 non disponible sur la cible) et n'observez aucune déviation après plusieurs tentatives. Que pouvez-vous conclure avec certitude, et que reste-t-il d'incertain compte tenu de la technique utilisée ?

**Q17.** Un endpoint renvoie systématiquement un code `409 Conflict` sur toutes les requêtes du groupe parallèle, mais une vérification de l'état final révèle malgré tout une incohérence (plus d'utilisations enregistrées que de succès apparents). Comment interprétez-vous cette combinaison de signaux ?

**Q18.** Une déviation (code 200 inattendu) n'apparaît qu'une seule fois sur vingt tentatives de la même rafale. Pouvez-vous considérer cela comme une vulnérabilité confirmée ? Que manque-t-il pour passer de ce signal à un niveau de preuve supérieur ?

**Q19.** Aucune déviation n'est observée sur un test multi-endpoints (panier + checkout) envoyé en paquet unique HTTP/2 correctement configuré. Citez au moins deux causes distinctes, autres qu'une absence réelle de vulnérabilité, qu'il faut écarter avant de documenter une protection comme robuste.

**Q20.** Un test de construction partielle (paramètre envoyé sous forme de tableau vide) ne produit aucun effet observable. Que pouvez-vous en conclure sur l'objet testé précisément, et que ne pouvez-vous pas généraliser à partir de ce seul résultat ?

---

### Catégorie 5 — Exploiter

**Q21.** Construisez la chaîne complète d'exploitation d'un **Limit Overrun** sur un code promo à usage unique : point d'entrée, primitive technique, déclenchement, effet intermédiaire, aboutissement, preuve. Précisez explicitement en quoi la preuve diffère d'un simple code 200 isolé dans le groupe.

**Q22.** Construisez la chaîne d'exploitation d'une race condition **multi-endpoints** entre panier et checkout. Expliquez pourquoi cette variante ne peut pas être détectée en testant chaque endpoint isolément, et quelle précaution opérationnelle conditionne la validité du résultat.

**Q23.** Construisez la chaîne d'exploitation d'un **contournement de verrouillage de session PHP** permettant de révéler une fenêtre de tir sous-jacente par ailleurs masquée. Précisez à quel moment de la chaîne se situe la dissociation technique qui rend l'exploitation possible.

**Q24.** Construisez la chaîne d'exploitation d'un **contournement de MFA par séquence cachée**. Identifiez précisément la fenêtre exploitée (entre quelles micro-étapes internes) et la preuve minimale qui démontrerait un impact réel plutôt qu'une simple tentative.

**Q25.** Construisez la chaîne d'exploitation d'une **fuite de jeton entre comptes** via un pool de workers insuffisamment cloisonné (endpoint `/forgot-password`). Précisez la condition architecturale nécessaire à cette chaîne, et ce qui la distingue structurellement d'un Limit Overrun classique.

---

### Catégorie 6 — Déboguer et transférer

**Q26.** Aucune collision n'est observée malgré un envoi en paquet unique HTTP/2 correctement configuré sur un endpoint pourtant suspecté vulnérable. Citez les **trois causes alternatives** que la méthodologie demande explicitement de vérifier avant de conclure à une protection robuste.

**Q27.** Un endpoint renvoie `409 Conflict` sur toutes les requêtes du groupe. Un collègue en conclut immédiatement à une protection efficace et passe à un autre endpoint sans vérification complémentaire. Quelle erreur commet-il, et quelle vérification minimale manque-t-il ?

**Q28.** Un test multi-endpoints (panier + checkout) ne produit aucune déviation. Diagnostiquez au moins deux causes distinctes liées à l'infrastructure (pas à l'absence de vulnérabilité elle-même) pouvant expliquer ce résultat, et la vérification qui permettrait de les écarter.

**Q29.** Un test de construction partielle sur un paramètre `api-key[]=` ne produit aucun effet. Diagnostiquez la cause la plus probable évoquée par la méthodologie, et proposez un ajustement qui ne consiste pas à abandonner cette piste d'exploitation.

**Q30.** Vous passez d'un contexte web classique (API REST, sessions HTTP) à un contexte différent (par exemple une application mobile communiquant avec un backend via un protocole propriétaire, ou un système de traitement par files de messages asynchrones). Quels principes de raisonnement de cette fiche restent directement transférables, et quels éléments techniques précis (outillage, hypothèses sur le protocole) doivent impérativement être revérifiés avant toute réutilisation ?

---

## Corrigé — Réponses attendues et raisonnement

**R1.** Une race condition web est un défaut de **logique métier** (pas un défaut d'implémentation cryptographique ou de validation d'entrée) survenant lorsqu'une application traite des requêtes concurrentes **sans verrouillage adéquat**, permettant à plusieurs processus d'interagir simultanément sur les mêmes données et de produire un résultat divergent du comportement attendu en exécution séquentielle. Le schéma TOCTOU (*Time-Of-Check to Time-Of-Use*) décrit la cause structurelle : le moment où une condition est **vérifiée** et le moment où elle est **effectivement utilisée/écrite** sont séparés dans le temps, et c'est cet intervalle — la fenêtre de tir — qu'une requête concurrente peut exploiter en s'y intercalant avant que l'écriture définitive n'ait eu lieu.

**R2.** Les trois étapes : (1) **Vérification (Check)** — le serveur interroge la base pour déterminer si la ressource/action est disponible ou autorisée ; (2) **Application (Use)** — le serveur applique effectivement l'action (réduction, crédit, vote) ; (3) **Mise à jour (Update)** — le serveur écrit en base que la ressource vient d'être consommée. La fenêtre exploitable se situe **entre l'étape 1 et l'étape 3** (et non simplement « entre le début et la fin ») : tant que l'étape 3 n'a pas été exécutée par une requête, toute autre requête exécutant sa propre étape 1 obtient encore le résultat « disponible », quel que soit l'avancement des autres requêtes dans les étapes 2 ou 3.

**R3.** Parce que l'état « disponible » n'est modifié en base qu'à l'étape 3 (Update) — tant que cette écriture n'a pas été effectuée par **aucune** des requêtes concurrentes, chaque nouvelle requête qui exécute sa propre étape 1 (Check) interroge un état encore non modifié et obtient donc la même réponse positive. C'est précisément l'absence de verrouillage entre la lecture et l'écriture qui permet à un nombre arbitraire de requêtes de « passer » l'étape 1 avec succès avant qu'aucune écriture définitive ne vienne fermer cette fenêtre.

**R4.** La condition commune est l'existence d'une **opération suivant un schéma vérification → application → mise à jour (check → use → update) avec une fenêtre de temps entre la vérification et l'écriture définitive de l'état**, combinée à la **capacité technique d'envoyer plusieurs requêtes suffisamment synchronisées** pour qu'elles soient traitées par le serveur dans cette même fenêtre — cette seconde condition étant une condition d'outillage, distincte de la vulnérabilité elle-même, mais nécessaire pour la révéler et la démontrer.

**R5.** Éléments explicitement hors périmètre : (1) les race conditions au niveau **système d'exploitation ou système de fichiers** (TOCTOU classique hors contexte web, ex. symlink race) — le cours se limite explicitement au périmètre web/applicatif ; (2) le détail des **mécanismes internes de verrouillage de session propres à des frameworks autres que PHP**, mentionné uniquement comme exemple représentatif, pas comme description exhaustive ; (3) les **techniques précises de détection automatisée** en dehors de Burp Suite/Turbo Intruder. Leur absence n'est pas une lacune de raisonnement : la fiche délimite volontairement son champ aux techniques et contextes effectivement documentés par les sources, plutôt que d'inventer des détails non vérifiés pour les frameworks ou contextes non couverts.

**R6.** Non, ce résultat **n'est pas, à lui seul, un signal de vulnérabilité** — au contraire, un `409 Conflict` isolé ou systématique peut indiquer qu'une **détection de collision est déjà en place côté application** (protection partielle ou totale), ce qui est l'inverse d'un indice de vulnérabilité. Il ne faut cependant pas conclure immédiatement à une protection effective sans vérification complémentaire : il faut contrôler si l'état final en base reflète malgré tout une incohérence malgré ces codes 409, ce qui indiquerait une protection seulement partielle.

**R7.** Le niveau de preuve atteint est celui d'un **effet de second ordre confirmé** — une incohérence d'état final démontrée par une vérification indépendante, même si aucune réponse individuelle du groupe ne semblait anormale. C'est précisément le type de preuve que la méthodologie identifie comme essentiel à rechercher systématiquement : se fier uniquement aux codes de réponse individuels (tous 200, apparemment cohérents) aurait conduit à manquer cette collision, qui ne devient visible qu'en comparant l'état final observé au résultat théorique attendu.

**R8.** Cette observation isolée suggère soit une **absence réelle de fenêtre de tir exploitable** (protection effective), soit — et c'est l'explication à envisager en priorité selon la méthodologie — une **synchronisation réseau insuffisante** propre à la technique du dernier octet sous HTTP/1.1, structurellement moins fiable que le paquet unique HTTP/2 pour fermer des fenêtres de tir très courtes. Cela ne permet **pas encore** de conclure à une absence de vulnérabilité : il faudrait d'abord vérifier si HTTP/2 est disponible pour tenter le paquet unique, technique nettement plus fiable, avant d'interpréter un résultat négatif comme significatif.

**R9.** Le code `500` pointe plus directement vers une collision réelle : il révèle typiquement une **exception non gérée** côté serveur, signe que le traitement concurrent a rencontré un état inattendu qu'il n'a pas su gérer correctement — signal positif de dysfonctionnement lié à la concurrence. Le `409 Conflict`, à l'inverse, doit être interprété avec prudence car il indique le plus souvent qu'une **détection partielle de collision est déjà en place** côté application (un mécanisme qui *réagit* à la concurrence plutôt qu'un signe que la concurrence a *réussi* à provoquer un dysfonctionnement) — sa présence seule n'est donc pas une preuve de vulnérabilité, contrairement au 500.

**R10.** Cela suggère un **traitement divergent** entre des requêtes supposées identiques, ce qui peut être un signe de collision (chaque requête ayant observé un état différent au moment de son traitement). Vérification nécessaire avant de documenter cela comme preuve : **lire le corps de chaque réponse** pour identifier concrètement la nature de cette divergence (message d'erreur différent, contenu partiellement différent, etc.), et comparer ce comportement au comportement séquentiel de référence établi au préalable — une variation isolée de `Content-Length` sans examen du contenu réel ne constitue pas en soi une preuve exploitable.

**R11.**
- **Hypothèse** : le code promo peut être appliqué plusieurs fois si les requêtes de rachat sont suffisamment synchronisées, du fait d'une fenêtre check-use-update non verrouillée.
- **Référence préalable** : envoyer la requête une seule fois en séquentiel, noter le code HTTP (200 attendu), le `Content-Length`, et vérifier qu'un second envoi séquentiel produit un refus (400/409 « code déjà utilisé »).
- **Test minimal** : envoyer N copies identiques de la requête de rachat (`POST /redeem-promo {"code": "PROMO10"}`) en paquet unique HTTP/2 (10 à 30 copies selon la fenêtre estimée).
- **Condition d'interprétation** : disposer de cette référence séquentielle stable pour distinguer un comportement provoqué par la concurrence d'un comportement déjà présent isolément.
- **Résultat attendu si vraie** : plusieurs réponses 200 dans le groupe, et/ou un état final en base (vérifié par requête indépendante) montrant une réduction appliquée plus d'une fois.
- **Ce que cela permet de conclure** : uniquement que la fenêtre de tir est exploitable sur cet endpoint précis — pas que l'ampleur du dépassement observé représente la limite maximale exploitable, qui nécessiterait des tests supplémentaires à plus grande échelle (dans les limites autorisées du test).

**R12.** Le test préalable qui détermine ce choix est la **vérification du protocole négocié par la cible** (HTTP/2 disponible ou non, observable dans Burp Suite via l'indicateur de protocole sur les requêtes/réponses). Un résultat négatif avec la technique du **dernier octet** doit être interprété avec plus de prudence qu'un résultat négatif avec le **paquet unique** : le dernier octet reste structurellement moins fiable pour fermer des fenêtres de tir très courtes (inférieures à quelques millisecondes), du fait du jitter réseau résiduel entre connexions TCP distinctes — un échec avec cette technique peut donc refléter une synchronisation insuffisante plutôt qu'une absence réelle de fenêtre, alors qu'un échec avec le paquet unique (la technique la plus fiable disponible) constitue un signal négatif plus solide, bien que non définitif à lui seul (voir R26 sur les autres causes à vérifier).

**R13.** Test : répéter l'envoi synchronisé du groupe de requêtes en fournissant à chaque requête un identifiant de session (`PHPSESSID`) **distinct**, tout en restant authentifié sur le **même compte**. Condition préalable nécessaire : disposer de **plusieurs sessions valides distinctes pour un même compte**, obtenues par exemple en se ré-authentifiant plusieurs fois avant la salve de test (si l'application n'invalide pas les sessions précédentes), ou via tout mécanisme émettant des jetons d'API indépendants. Un résultat positif (déviation apparaissant alors qu'elle était absente avec une session partagée) confirmerait que le framework **sérialisait silencieusement** les requêtes du même identifiant de session, masquant une fenêtre de tir sous-jacente par ailleurs réellement exploitable.

**R14.** Précaution : **réchauffer la connexion** par l'envoi préalable d'une requête anodine (ex. GET sur une ressource publique) avant de lancer la salve de test multi-endpoints. Son omission risquerait de fausser l'interprétation car le **premier paquet** envoyé sur une connexion nouvellement établie peut subir un traitement différent (allocation de ressources, TLS handshake, initialisation de contexte) — un délai ou un comportement atypique observé sur ce premier paquet pourrait alors être interprété à tort comme un signe de collision métier, alors qu'il reflète simplement un effet d'infrastructure sans lien avec la logique applicative testée.

**R15.** Test minimal : envoyer en **paquet unique HTTP/2** une requête de connexion avec mot de passe valide (`POST /login`) et une requête vers une ressource protégée post-MFA (`GET /dashboard`, avec le cookie de session obtenu/attendu de l'étape 1). Condition nécessaire pour l'interpréter correctement : disposer d'un indice qu'une session « pré-MFA » est créée dès la validation du mot de passe, avant l'activation effective de l'exigence du second facteur (fenêtre plausible entre ces deux sous-étapes internes). Un résultat positif (accès effectif au contenu du dashboard sans avoir soumis le code MFA) démontrerait exactement qu'une fenêtre existe entre la création de la session et l'activation effective du verrou MFA sur cette session, permettant un contournement complet du second facteur.

**R16.** On peut conclure avec certitude uniquement que **cette technique précise de synchronisation (dernier octet, HTTP/1.1), dans ces conditions de test, n'a pas produit de déviation observable** — rien de plus définitif. Ce qui reste incertain : si HTTP/2 était disponible et testé avec le paquet unique (technique la plus fiable), un résultat différent pourrait apparaître, la fenêtre de tir pouvant être trop courte pour être révélée par la synchronisation imparfaite du dernier octet. Un résultat négatif obtenu avec une technique de synchronisation moins fiable ne doit jamais être interprété avec la même confiance qu'un résultat négatif obtenu avec la technique la plus fiable disponible.

**R17.** Cette combinaison révèle une **protection partielle plutôt qu'effective** : les codes `409` montrent qu'un mécanisme de détection de collision existe et réagit, mais l'incohérence persistante de l'état final prouve que ce mécanisme **n'empêche pas complètement** le dépassement du plafond métier — certaines requêtes concurrentes parviennent malgré tout à aboutir avant que le verrou/la détection ne s'applique effectivement. Il faut documenter cette protection comme **incomplète** plutôt que comme robuste, et investiguer plus avant la cause de cette fuite résiduelle.

**R18.** Non, ce signal **ne constitue pas encore une vulnérabilité confirmée** au sens d'un impact démontré — la méthodologie le qualifie explicitement de « signal à investiguer », pas de preuve exploitable en l'état. Ce qui manque pour passer à un niveau de preuve supérieur : un **taux de reproductibilité quasi systématique** obtenu sur un script minimal et nettoyé (en-têtes superflus retirés), condition posée explicitement pour qu'un proof-of-concept soit considéré comme fiable — ce qui peut nécessiter d'affiner la synchronisation (vérifier le réchauffement de connexion, tenter le paquet unique si ce n'était pas déjà le cas, augmenter N) pour identifier et corriger la cause de l'irrégularité observée.

**R19.** Au moins deux causes à écarter avant de conclure à une protection robuste : (1) la **connexion n'a pas été réchauffée** au préalable, le premier paquet d'une connexion nouvellement établie pouvant subir un traitement différent faussant le résultat ; (2) un **bridage de ressources (throttling)** a pu être déclenché par la détection d'un pic de requêtes simultanées, masquant ou imitant un comportement de collision réel. Il faut vérifier et écarter ces deux causes (réchauffement effectué, volume de requêtes ajusté) avant de documenter l'absence d'état partagé exploitable entre ces endpoints comme une conclusion fiable.

**R20.** On peut conclure uniquement que **ce paramètre précis**, testé de cette façon spécifique (tableau vide), n'a produit aucun effet observable sur **cet objet précis** — possiblement parce que le framework/langage cible initialise tous les attributs dans la même transaction pour ce cas de figure. Ce qui ne peut pas être généralisé : que l'objet entier est créé de façon parfaitement atomique dans toutes ses dimensions — d'autres attributs de sécurité créés en étapes distinctes (non testés ici) pourraient présenter une fenêtre de construction partielle similaire ; il faudrait explorer systématiquement d'autres attributs avant de conclure à une absence générale de ce type de vecteur sur cet endpoint.

**R21.**
- **Point d'entrée** : endpoint de rachat de code promo à usage unique.
- **Primitive technique** : fenêtre check-use-update entre la vérification de disponibilité du code et l'écriture de son statut « consommé ».
- **Déclenchement** : envoi synchronisé (paquet unique HTTP/2) de N copies identiques de la requête de rachat.
- **Effet intermédiaire** : plusieurs requêtes obtiennent la réponse « disponible » lors de leur propre vérification, avant qu'aucune écriture définitive n'ait eu lieu.
- **Aboutissement** : le code promo est appliqué plus d'une fois, constaté dans l'état final en base.
- **Preuve** : vérification indépendante de l'état final (ex. liste des commandes/réductions appliquées) confirmant un nombre d'applications supérieur à 1, avec reproductibilité quasi systématique sur un script minimal. Différence avec un simple code 200 isolé : un code 200 unique dans le groupe pourrait correspondre au comportement attendu (un seul succès légitime) — la preuve exige de constater **plusieurs** succès effectifs et/ou un état final incohérent avec le plafond métier attendu, vérifié indépendamment des réponses individuelles.

**R22.** Chaîne : point d'entrée = paire d'endpoints `/cart/add` et `/cart/checkout` partageant l'état du panier → primitive technique = fenêtre entre l'ajout effectif d'un article et la validation du montant total de la commande → déclenchement = envoi synchronisé en paquet unique des deux requêtes (connexion préalablement réchauffée) → effet intermédiaire = le checkout traite un état du panier différent de celui réellement validé → aboutissement = un article est ajouté après la validation du montant mais tout de même inclus dans la commande livrée (ou l'inverse), aboutissant à une livraison non facturée correctement. Cette variante ne peut pas être détectée en testant chaque endpoint isolément car **la vulnérabilité réside précisément dans l'interaction entre les deux routes** sur un état partagé — tester `/cart/add` seul ou `/cart/checkout` seul ne révèle aucune collision, celle-ci n'existant que dans la fenêtre temporelle où les deux opèrent simultanément sur le même panier. Précaution conditionnant la validité : le réchauffement préalable de la connexion, pour éviter qu'un effet d'infrastructure sur le premier paquet ne soit confondu avec un effet métier.

**R23.** Chaîne : point d'entrée = endpoint de rachat de code promo sur une cible PHP avec verrouillage de session par défaut → primitive technique = fenêtre check-use-update normalement exploitable mais masquée par la sérialisation des requêtes d'une même session → déclenchement = envoi synchronisé du groupe avec un `PHPSESSID` **distinct** sur chaque requête, tout en restant authentifié sur le même compte → effet intermédiaire = les requêtes ne sont plus sérialisées par le verrou de session et sont désormais traitées en parallèle effectif → aboutissement = la fenêtre de tir sous-jacente redevient exploitable, avec dépassement du plafond métier observable. La dissociation technique se situe précisément au **moment du déclenchement** : c'est le choix d'attribuer des identifiants de session distincts à chaque requête, avant leur envoi synchronisé, qui lève le verrou qui aurait autrement neutralisé toute la chaîne malgré une synchronisation réseau par ailleurs correcte.

**R24.** Fenêtre exploitée : entre l'**étape 1** (validation du mot de passe → création d'une session « pré-MFA ») et l'**étape 3** (activation effective de l'exigence du code MFA sur cette session) — une micro-étape interne de traitement sépare ces deux moments, même si elles semblent atomiques du point de vue du client. Chaîne : point d'entrée = séquence de connexion MFA → primitive technique = cette fenêtre interne entre création de session et activation du verrou MFA → déclenchement = envoi en paquet unique de `POST /login` (mot de passe valide) et `GET /dashboard` (ressource post-MFA) avec le cookie de session obtenu → effet intermédiaire = la requête vers `/dashboard` est traitée par le serveur avant que l'activation du verrou MFA (étape 3) ne soit effective → aboutissement = accès à la ressource protégée. Preuve minimale démontrant un impact réel : une réponse 200 effective sur `/dashboard` contenant le contenu réellement protégé, obtenue **sans avoir jamais soumis le second facteur**, reproductible de façon quasi systématique — une seule tentative réussie isolée resterait un signal à investiguer plutôt qu'une preuve d'impact confirmée.

**R25.** Chaîne : point d'entrée = endpoint unique `/forgot-password` traitant des requêtes de comptes différents via un pool de threads/workers partagé → primitive technique = entremêlement de variables de contexte entre threads traitant des requêtes concurrentes de sessions/comptes distincts → déclenchement = envoi simultané de deux requêtes `/forgot-password`, l'une pour le compte attaquant, l'autre pour le compte victime → effet intermédiaire = le contexte de traitement de la requête victime s'entremêle avec celui de la requête attaquant au niveau du pool de workers → aboutissement = le jeton de réinitialisation destiné à la victime est renvoyé par erreur dans la réponse adressée à l'attaquant. Condition architecturale nécessaire : un **pool de threads ou de workers insuffisamment cloisonné** entre requêtes concurrentes de contextes différents — condition distincte de celle d'un Limit Overrun. Ce qui distingue structurellement cette chaîne d'un Limit Overrun classique : il ne s'agit pas d'un dépassement de plafond sur une **même donnée répétée** (même endpoint, même paramètre), mais d'une **fuite de données entre deux contextes utilisateurs distincts** traités en parallèle sur le **même endpoint** — le défaut porte sur le cloisonnement du contexte, pas sur l'atomicité d'une mise à jour.

**R26.** Les trois causes alternatives à vérifier explicitement : (1) la **fiabilité réelle de la synchronisation réseau** utilisée — même avec paquet unique HTTP/2, une configuration incorrecte ou un nombre insuffisant de requêtes (N) peut ne pas révéler une fenêtre très étroite ; (2) un **verrouillage de session masquant silencieusement l'effet de concurrence** (test de dissociation de session à effectuer avant toute conclusion) ; (3) des **effets de second ordre non visibles dans les réponses individuelles** — vérifier systématiquement l'état final via une requête indépendante, même si chaque réponse du groupe semblait normale, avant de documenter une protection comme robuste.

**R27.** Erreur commise : conclure à une protection efficace **uniquement** sur la base des codes de réponse individuels, sans vérifier l'**état final en base** via une requête indépendante. Vérification minimale manquante : interroger l'état final (compteur d'utilisation, solde, liste des codes consommés) après la salve de test — un `409 Conflict` systématique peut coexister avec une incohérence résiduelle de l'état final, révélant une protection seulement **partielle** (le mécanisme de détection réagit mais n'empêche pas totalement le dépassement) ; passer à un autre endpoint sans cette vérification risque de documenter à tort une protection comme robuste.

**R28.** Au moins deux causes liées à l'infrastructure : (1) **connexion non réchauffée** — le premier paquet d'une connexion nouvellement établie peut subir un délai d'initialisation (TLS handshake, allocation de workers) faussant le résultat sans lien avec la logique métier testée ; (2) **bridage de ressources (throttling)** déclenché par la détection du pic de requêtes simultanées, pouvant masquer ou imiter un comportement de collision. Vérification pour les écarter : répéter le test après avoir explicitement réchauffé la connexion par une requête anodine préalable, et en réduisant le volume de requêtes simultanées pour écarter un déclenchement de throttling — si la déviation apparaît alors, les causes infrastructurelles expliquaient l'échec initial plutôt qu'une absence réelle d'état partagé exploitable.

**R29.** Cause la plus probable : le framework/langage cible **initialise tous les attributs de l'objet dans la même transaction** pour ce cas de figure précis, ne laissant pas de fenêtre de construction partielle exploitable via ce paramètre particulier. Ajustement constructif plutôt qu'un abandon de la piste : **tester d'autres attributs** potentiellement générés de façon différée (pas seulement `api-key[]=`), car la méthodologie précise explicitement que l'absence d'effet sur un paramètre précis ne garantit en rien l'absence de construction partielle sur d'autres attributs de sécurité du même objet ou d'autres endpoints de création en plusieurs étapes.

**R30.** Principes transférables : établir systématiquement une **référence de comportement fiable** avant d'interpréter une déviation ; distinguer explicitement un **signal isolé** d'une **preuve confirmée** reproductible de façon quasi systématique ; avant de conclure à l'absence de vulnérabilité après un échec, vérifier les **causes alternatives propres au contexte technique** (fiabilité de la synchronisation, mécanismes de verrouillage spécifiques à la stack, effets de second ordre non visibles) plutôt que de conclure directement ; prioriser les surfaces de test par **impact métier réel** plutôt que par fréquence d'occurrence naturelle. Éléments techniques à impérativement revérifier, jamais transposables tels quels : l'**outillage de synchronisation** lui-même (l'attaque par paquet unique est spécifique au multiplexage natif de HTTP/2 — un protocole propriétaire ou un système de messages asynchrones nécessite un mécanisme de synchronisation entièrement différent, à identifier spécifiquement) ; les **hypothèses sur le verrouillage** (le verrouillage de session par fichier est une spécificité de PHP en configuration par défaut, non généralisable à d'autres stacks ou à un contexte hors session HTTP) ; la pertinence même de la notion de « fenêtre de tir check-use-update », qui doit être réétablie dans le nouveau contexte (un système de files de messages asynchrones peut présenter des fenêtres de concurrence de nature différente, liées à l'ordonnancement des messages plutôt qu'à la synchronisation réseau de requêtes HTTP).

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
**Recto :** Entre quelles étapes précises du mécanisme Check → Use → Update se situe la fenêtre de tir exploitable d'un Limit Overrun ?
**Verso :** Entre l'étape 1 (**Check**) et l'étape 3 (**Update**) — tant que l'écriture définitive (étape 3) n'a pas eu lieu, toute requête concurrente exécutant sa propre vérification (étape 1) obtient encore le résultat « disponible ».

**Carte 2**
**Recto :** Quelle est la condition technique commune à toutes les variantes de race condition de cette fiche, au-delà du scénario métier précis ?
**Verso :** Une opération suivant un schéma check-use-update avec une fenêtre temporelle exploitable, **combinée** à la capacité technique d'envoyer des requêtes suffisamment synchronisées pour les faire traiter dans cette même fenêtre.

**Carte 3**
**Recto :** Que désigne le schéma TOCTOU, et quel est son lien avec la notion de « fenêtre de tir » ?
**Verso :** TOCTOU (*Time-Of-Check to Time-Of-Use*) désigne la séparation temporelle entre le moment où une condition est vérifiée et le moment où elle est effectivement utilisée/écrite — cet intervalle constitue la fenêtre de tir exploitable.

### Reconnaître

**Carte 4**
**Recto :** Un code `409 Conflict` apparaît sur l'ensemble des requêtes d'un groupe parallèle. Est-ce un signal de vulnérabilité ?
**Verso :** Non — au contraire, cela suggère le plus souvent qu'une **détection de collision est déjà en place** côté application. Il faut néanmoins vérifier l'état final pour écarter une protection seulement partielle.

**Carte 5**
**Recto :** Toutes les réponses individuelles d'une rafale semblent normales (200 cohérents), mais une vérification indépendante révèle un état final incohérent. Que vient-on de détecter ?
**Verso :** Un **effet de second ordre** — la preuve réelle d'une collision, invisible dans les réponses individuelles et détectable uniquement par une vérification de l'état final en base.

**Carte 6**
**Recto :** Entre un code `500` et un code `409` observés dans un groupe de requêtes parallèles, lequel pointe le plus directement vers une collision réelle ?
**Verso :** Le `500` — il révèle typiquement une exception non gérée liée à un état inattendu provoqué par la concurrence. Le `409` indique le plus souvent une protection déjà active, à interpréter avec prudence.

### Tester

**Carte 7**
**Recto :** Pourquoi faut-il établir une référence séquentielle (benchmarking) avant tout test en parallèle ?
**Verso :** Sans cette référence, il est impossible de distinguer une déviation réellement provoquée par la concurrence d'un comportement déjà présent en exécution séquentielle normale.

**Carte 8**
**Recto :** Quel test préalable détermine le choix entre attaque par paquet unique (HTTP/2) et technique du dernier octet (HTTP/1.1) ?
**Verso :** La vérification du **protocole négocié par la cible**. Le paquet unique est la technique la plus fiable mais nécessite HTTP/2 ; en son absence, le dernier octet reste disponible mais structurellement moins fiable pour les fenêtres très courtes.

**Carte 9**
**Recto :** Quelle précaution faut-il prendre avant un test multi-endpoints, et pourquoi ?
**Verso :** Réchauffer la connexion par une requête anodine préalable — le premier paquet d'une connexion nouvellement établie peut subir un traitement différent (TLS handshake, allocation de ressources) faussant l'interprétation du résultat.

### Interpréter

**Carte 10**
**Recto :** Une déviation n'apparaît qu'une fois sur vingt tentatives. Est-ce une vulnérabilité confirmée ?
**Verso :** Non — c'est un « signal à investiguer » selon la méthodologie, pas une preuve exploitable. Il faut viser une reproductibilité quasi systématique sur un script minimal avant de documenter un impact.

**Carte 11**
**Recto :** Un endpoint renvoie `409` systématiquement, mais l'état final révèle malgré tout une incohérence. Comment qualifier cette protection ?
**Verso :** **Partielle**, pas robuste — le mécanisme de détection réagit mais n'empêche pas totalement le dépassement ; une fuite résiduelle persiste et mérite d'être approfondie.

**Carte 12**
**Recto :** Aucune déviation n'est observée malgré un paquet unique HTTP/2 bien configuré. Que ne faut-il jamais conclure directement ?
**Verso :** Qu'il s'agit d'une protection robuste — il faut d'abord écarter un verrouillage de session masquant l'effet, et vérifier les effets de second ordre non visibles dans les réponses individuelles.

### Exploiter

**Carte 13**
**Recto :** Dans la chaîne d'un Limit Overrun confirmé, en quoi la preuve diffère-t-elle d'un simple code 200 isolé dans le groupe ?
**Verso :** La preuve exige de constater **plusieurs** succès effectifs et/ou un état final incohérent avec le plafond attendu, vérifié **indépendamment** des réponses individuelles — un seul 200 peut correspondre au comportement légitime attendu.

**Carte 14**
**Recto :** Pourquoi une race condition multi-endpoints ne peut-elle pas être détectée en testant chaque endpoint isolément ?
**Verso :** Parce que la vulnérabilité réside dans l'**interaction** entre les deux routes sur un état partagé — elle n'existe que dans la fenêtre temporelle où les deux opèrent simultanément, invisible en testant chaque route séparément.

**Carte 15**
**Recto :** Qu'est-ce qui distingue structurellement une fuite de jeton entre comptes (`/forgot-password`) d'un Limit Overrun classique ?
**Verso :** Le Limit Overrun dépasse un plafond sur une **même donnée répétée** (même endpoint/paramètre) ; la fuite de jeton résulte d'un **cloisonnement de contexte insuffisant** entre deux requêtes de comptes différents traitées en parallèle sur le même endpoint.

### Déboguer et transférer

**Carte 16**
**Recto :** Quelles sont les trois causes alternatives à vérifier avant de conclure à une protection robuste après un échec de collision ?
**Verso :** (1) Fiabilité réelle de la synchronisation réseau ; (2) verrouillage de session masquant silencieusement l'effet ; (3) effets de second ordre non visibles dans les réponses individuelles.

**Carte 17**
**Recto :** Un test multi-endpoints ne produit aucune déviation. Quelles sont deux causes infrastructurelles à écarter avant de conclure ?
**Verso :** Connexion non réchauffée (effet du premier paquet) et bridage de ressources (throttling) déclenché par le pic de requêtes — toutes deux sans lien avec une absence réelle de vulnérabilité.

**Carte 18**
**Recto :** En changeant de contexte (protocole propriétaire, système de messages asynchrones), quel élément technique de cette fiche ne doit jamais être réutilisé tel quel ?
**Verso :** L'outillage de synchronisation (attaque par paquet unique spécifique au multiplexage HTTP/2) et les hypothèses de verrouillage (verrouillage de session PHP non généralisable) — seuls les principes de raisonnement (référence, preuve reproductible, causes alternatives) restent transférables.

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
| « Je ne comprends pas pourquoi la fenêtre de tir existe / pourquoi la faille existe. » | `cours.md` |
| « Je ne sais pas quelle technique de synchronisation choisir, ou dans quel ordre tester les variantes. » | `exploitation.md` (méthodologie, arbre de décision) |
| « Je connais le principe, mais j'oublie la syntaxe exacte du script Turbo Intruder / des requêtes. » | `cheatsheet.md` |
| « Je ne sais pas si mon observation suffit à conclure / ce qu'il reste à vérifier. » | `exploitation.md`, sections « Indices et faux positifs » et « Diagnostic des échecs » |
| « Je confonds un signal de protection (409) avec un signal de vulnérabilité (500). » | `exploitation.md`, section 3.2 et `cheatsheet.md`, section « Signaux caractéristiques » |
| « Je ne sais pas comment qualifier le niveau de preuve atteint (signal / confirmé / démontré). » | `exploitation.md`, section « Vérification de l'exploitation et preuve de l'impact » |

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
