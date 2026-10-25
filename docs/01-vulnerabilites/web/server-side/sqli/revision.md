# Fiche de révision active — SQL Injection (SQLi)

> **Mode d'emploi — Partie 1**
> Répondez à toutes les questions ci-dessous **sans consulter** `cours.md`, `exploitation.md` ou `cheatsheet.md`, et sans revenir en arrière une fois la lecture de la question commencée. Notez vos réponses (sur papier ou dans un fichier séparé) avant de passer au corrigé. Ce n'est qu'après avoir répondu à l'ensemble des 30 questions que vous devez ouvrir la section « Corrigé ». Travailler avec les sources ouvertes fausse l'auto-évaluation et prive l'entraînement de son intérêt : le but est de mesurer ce que vous savez mobiliser seul, pas ce que vous savez relire.

---

## 1. Comprendre

**Q1.** Quelle est la cause structurelle commune à toutes les variantes d'injection SQL (In-Band, Blind, OAST, Second-Order) ? Formulez-la en une phrase qui expliquerait pourquoi le SGBD peut interpréter une entrée utilisateur comme un fragment de syntaxe plutôt que comme une valeur inerte.

**Q2.** Un développeur affirme que son paramètre `id` est protégé contre l'injection « parce qu'il est numérique, donc sans guillemets ». Sous quelle condition précise de construction de la requête cette affirmation est-elle fausse, et quel test permettrait de la réfuter sans attendre d'erreur SQL ?

**Q3.** Expliquez pourquoi les requêtes préparées neutralisent la quasi-totalité des techniques d'injection SQL, en précisant ce qui, structurellement, diffère d'une concaténation de chaînes — sans vous contenter de dire « elles séparent le code de la donnée », précisez *comment* cette séparation est transmise au SGBD.

**Q4.** Pourquoi une injection SQL de second ordre échappe-t-elle typiquement à un scanner automatisé et à un audit qui ne teste que le point de saisie initial ? Qu'est-ce qui, dans le cycle de vie de la donnée, rend cette variante structurellement différente des autres ?

**Q5.** Il existe une hiérarchie implicite entre les canaux d'observation d'une injection Blind (contenu de page, code HTTP, délai, interaction réseau). Sur quel critère cette hiérarchie est-elle construite, et pourquoi ne descend-on au canal suivant qu'après avoir confirmé l'échec du précédent plutôt que de tester les quatre en parallèle d'emblée ?

---

## 2. Reconnaître

**Q6.** Au-delà du champ de formulaire visible, citez au moins trois emplacements structurellement distincts où une requête SQL peut être construite par concaténation d'une entrée utilisateur, et pour chacun expliquez pourquoi il est fréquemment négligé lors d'un audit superficiel.

**Q7.** Vous injectez une apostrophe seule dans un paramètre et obtenez une erreur `500`. Quel second test est indispensable avant de qualifier ce signal de preuve d'injection SQL confirmée, et que démontre précisément ce second test par rapport au premier ?

**Q8.** Une requête contenant le mot `SELECT` en clair reçoit systématiquement un code `403 Forbidden`, y compris sur des paramètres par ailleurs correctement protégés. Que devez-vous en conclure sur la nature de cette protection, et pourquoi ce code ne doit-il pas être interprété comme la preuve d'une absence de vulnérabilité sous-jacente ?

**Q9.** Vous testez une condition supposée vraie (`' OR '1'='1`) et obtenez un résultat de page élargi. Quel second test, construit en miroir, est nécessaire avant de considérer ce canal comme confirmé, et quel risque méthodologique court-on si l'on s'arrête au premier test ?

**Q10.** Vous disposez d'un canal d'injection confirmé mais ignorez le SGBD cible. Citez deux observations distinctes (autres que la simple absence d'erreur) qui permettraient de différencier par élimination au moins trois des quatre moteurs couverts (MySQL/MariaDB, PostgreSQL, SQL Server, Oracle).

---

## 3. Tester

**Q11.** Décrivez la séquence de deux requêtes nécessaires pour confirmer une injection In-Band par rupture de syntaxe, en précisant ce que chacune des deux apporte à la démonstration et pourquoi l'une sans l'autre ne suffit pas.

**Q12.** Décrivez la démarche complète, étape par étape, permettant de passer d'un canal UNION-Based confirmé à l'exfiltration effective de données d'une table arbitraire, en précisant ce que chaque sous-étape doit déterminer avant de passer à la suivante.

**Q13.** Pour un canal Boolean-Based Blind, décrivez précisément la paire de requêtes à construire pour valider le canal, et la condition exacte de divergence qui permet de le qualifier d'exploitable.

**Q14.** Décrivez la méthode rigoureuse de validation d'un canal Time-Based Blind, en précisant pourquoi une seule mesure de délai, même longue, ne suffit jamais à confirmer le canal.

**Q15.** Décrivez le principe de l'extraction caractère par caractère d'une valeur sensible via un canal Blind, et l'optimisation qui permet de réduire drastiquement le nombre de requêtes nécessaires par rapport à un test d'égalité naïf caractère par caractère.

---

## 4. Interpréter

**Q16.** Une apostrophe seule provoque une erreur `500`, mais une double apostrophe ne restaure pas le comportement normal de la page. Que pouvez-vous en déduire sur l'origine probable de l'erreur observée, et quelle conclusion seriez-vous prématuré de tirer à ce stade ?

**Q17.** Votre `UNION SELECT NULL, NULL, NULL` est accepté sans erreur, mais aucune lettre de test ne s'affiche nulle part dans le rendu visuel de la page, quelle que soit la position testée. Quelles sont les deux hypothèses à distinguer, et quelle vérification permettrait de trancher entre elles ?

**Q18.** Vous interrogez `information_schema.tables` sur une cible identifiée comme Oracle et n'obtenez aucun résultat, alors que la syntaxe de votre requête est correcte et que le canal UNION est par ailleurs fonctionnel. Quelle est la cause la plus probable, spécifique à ce SGBD, et quel test permettrait de la confirmer ?

**Q19.** Vous envoyez un payload OAST syntaxiquement correct pour le SGBD identifié et ne recevez aucune interaction sur votre service d'écoute. Citez deux causes distinctes et non mutuellement exclusives, et précisez laquelle remettrait en cause la confirmation de l'injection elle-même et laquelle ne la remettrait pas.

**Q20.** L'application cible répond systématiquement `202 Accepted` de façon immédiate et identique, indépendamment de toute injection testée, suggérant un traitement asynchrone en arrière-plan. Parmi les quatre canaux Blind habituels, lequel reste pertinent dans ce contexte précis, et pourquoi les trois autres sont-ils structurellement inopérants ici ?

---

## 5. Exploiter

**Q21.** Construisez le raisonnement complet d'un contournement d'authentification SQLi, en distinguant le cas où le nom d'utilisateur ciblé est connu du cas où il ne l'est pas, et en expliquant pourquoi la syntaxe de commentaire utilisée doit être adaptée au SGBD réel plutôt que supposée universelle.

**Q22.** Décrivez la chaîne complète d'exploitation UNION-Based, du point d'entrée jusqu'à la preuve d'impact, en identifiant à quel moment précis le fingerprinting du SGBD devient nécessaire et pourquoi il n'est pas indispensable dès la détection initiale.

**Q23.** Décrivez le raisonnement complet permettant d'identifier puis d'exploiter une injection SQL de second ordre, en détaillant ce qui doit être observé à la phase de stockage, ce qui doit être cherché à la phase de réutilisation, et pourquoi un test isolé de la première phase ne révèle jamais rien par construction.

**Q24.** Expliquez comment une technique OAST, une fois le canal confirmé comme fonctionnel, peut être utilisée pour exfiltrer une valeur sensible en une seule requête plutôt que par extraction caractère par caractère, et quelle contrainte technique limite la taille ou le format de la valeur ainsi exfiltrée.

**Q25.** Un payload SQL en clair contenant le mot `SELECT` est bloqué par un `403`. Décrivez la démarche de validation d'un contournement par encodage, en précisant pourquoi il est indispensable de confirmer d'abord le blocage du payload en clair avant de tester une forme encodée.

---

## 6. Déboguer et transférer

**Q26.** Un test `SLEEP(5)` produit un délai mesuré une seule fois, non reproduit lors d'une seconde tentative identique. Quelles sont les étapes de diagnostic à suivre avant de conclure quoi que ce soit sur l'exploitabilité du canal temporel ?

**Q27.** Lors d'une extraction caractère par caractère, aucune position ne confirme de caractère dans l'alphabet alphanumérique testé (a-z, A-Z, 0-9), alors que la longueur de la valeur a été correctement déterminée au préalable. Que devez-vous envisager avant de conclure à un échec de la technique elle-même ?

**Q28.** Un contournement d'authentification par injection est accepté par le serveur (pas d'erreur SQL), mais la connexion échoue malgré tout à donner accès à un compte authentifié. Citez deux facteurs indépendants pouvant expliquer cet échec, et comment les diagnostiquer séparément l'un de l'autre.

**Q29.** Le principe « valider toute hypothèse par un couple de tests opposés vrai/faux plutôt que par une observation isolée » a été appliqué ici à l'injection SQL. Formulez ce même principe de façon suffisamment générale pour qu'il s'applique à une classe de vulnérabilité totalement différente (au choix), en décrivant un exemple concret où un test isolé produirait un faux positif.

**Q30.** Vous auditez une API GraphQL ou un endpoint RPC totalement dépourvu de rendu HTML, où aucune des réponses ne varie jamais visuellement selon vos entrées. En vous appuyant sur la hiérarchie des canaux d'observation vue pour l'injection SQL (contenu > code HTTP > délai > interaction réseau), quelle démarche de diagnostic adopteriez-vous pour déterminer si une injection est malgré tout exploitable dans ce contexte ?

---

## Corrigé — Réponses attendues et raisonnement

**R1.** La cause structurelle commune : l'entrée utilisateur est concaténée directement dans la chaîne de la requête SQL sans séparation structurelle entre le canal de contrôle (la syntaxe de la requête) et le canal de donnée (la valeur), ce qui permet au SGBD d'interpréter tout ou partie de cette entrée comme un fragment de syntaxe SQL exécutable plutôt que comme une valeur inerte. Toute réponse centrée sur « pas de validation d'entrée » sans mentionner l'absence de séparation code/donnée reste incomplète — la validation d'entrée est une parade possible, pas la définition de la cause.

**R2.** L'affirmation est fausse dès lors que la requête est construite par simple concaténation de chaînes (`"WHERE id = " + input`) sans caster réellement la valeur en entier côté application, même en l'absence de guillemets autour du paramètre dans la requête finale. Le test de réfutation ne consiste pas à chercher une erreur, mais à soumettre une expression arithmétique équivalente à la valeur attendue (ex. `id=2-1` pour `id=1`) : si le résultat correspond à une évaluation de l'expression plutôt qu'à un rejet ou une erreur de conversion de type, le paramètre est bien interprété comme une expression SQL évaluée, pas comme un entier validé.

**R3.** Une requête préparée transmet au SGBD la structure de la requête (le squelette avec des emplacements réservés) et les valeurs des paramètres via deux canaux distincts et à des moments distincts du protocole ; le SGBD compile d'abord le squelette de la requête, puis lie ensuite les valeurs à des emplacements déjà fixés, sans jamais reconstruire une chaîne de caractères unique à partir de l'entrée utilisateur. Une valeur transmise par ce canal ne peut donc jamais être réinterprétée comme un fragment de syntaxe, quelle que soit sa forme, puisque la phase de compilation de la structure est déjà achevée avant que la valeur ne soit prise en compte.

**R4.** Le second ordre dissocie dans le temps et dans le code le point où la donnée est stockée (souvent correctement paramétré, donc sans anomalie observable à ce moment) du point où elle est relue et réinjectée par concaténation non sécurisée dans une fonctionnalité distincte. Un scanner ou un audit qui ne teste que le comportement immédiat suivant la soumission d'un payload ne verra jamais rien à la phase de stockage par construction : l'effet n'apparaît que plus tard, ailleurs dans l'application, lors d'une réutilisation qui n'est pas nécessairement anticipée ni cartographiée.

**R5.** La hiérarchie est construite sur la richesse décroissante de l'information que chaque canal peut transmettre par requête : le contenu de page peut révéler un jeu de résultats complet, le code HTTP ne transmet qu'un bit d'information binaire par requête, le délai nécessite une mesure de temps bruitée par la latence réseau, et l'interaction réseau sortante (OAST) ne fonctionne que si le SGBD dispose des droits nécessaires. On descend au canal suivant uniquement après avoir confirmé l'échec du précédent (par un couple de tests opposés, pas une observation isolée) car tester les quatre en parallèle revient à mobiliser des ressources et du bruit disproportionnés alors qu'un canal plus riche, s'il fonctionne, rend les autres inutiles.

**R6.** Au moins trois surfaces distinctes du formulaire principal : (1) un paramètre de tri alimentant une clause `ORDER BY`, négligé car jugé « non risqué » et structurellement non protégeable par une requête préparée classique (le SGBD attend un identifiant de colonne, pas une valeur liée) ; (2) les en-têtes HTTP journalisés (`User-Agent`, `Referer`, `X-Forwarded-For`), négligés car hors du périmètre visible du formulaire, alors qu'ils peuvent alimenter une requête de journalisation distincte et indépendamment vulnérable ; (3) les champs stockés puis réutilisés ailleurs (nom d'affichage, profil), négligés car sains en apparence au moment du stockage, révélant leur vulnérabilité uniquement lors d'une réutilisation différée (Second-Order).

**R7.** Le test indispensable est l'injection d'une double apostrophe (`1''`), qui forme une chaîne vide syntaxiquement valide. S'il restaure le comportement normal de la page, cela démontre que l'erreur initiale est spécifiquement liée à la syntaxe SQL et non à un bug applicatif sans rapport. Sans ce second test, une erreur `500` isolée pourrait provenir de n'importe quelle autre cause applicative coïncidant avec l'apostrophe injectée.

**R8.** Un `403` systématique sur un mot-clé SQL en clair signale généralement un WAF filtrant sur un motif textuel brut, pas une absence de vulnérabilité sous-jacente dans la construction de la requête elle-même. La vulnérabilité de concaténation peut toujours exister derrière ce filtre ; seul un test de contournement par encodage (entités XML, Unicode) permet de vérifier si la couche applicative en aval décode une forme que le WAF ne reconnaît pas, avant de documenter une protection comme réellement robuste.

**R9.** Le second test nécessaire est la condition opposée construite comme fausse (`' AND '1'='2`), qui doit produire un résultat vide ou restreint. Le risque méthodologique à s'arrêter au seul test « vrai » est de confondre un résultat élargi provoqué par l'injection avec un comportement applicatif sans rapport (fallback par défaut, erreur silencieuse renvoyant tous les résultats) : seule la divergence cohérente entre les deux tests opposés constitue une preuve fiable.

**R10.** Deux observations différenciantes possibles parmi : `@@version` valide (sans erreur) restreint le champ à MySQL/MariaDB ou SQL Server ; le format retourné par `version()` différencie ensuite PostgreSQL (chaîne du type `PostgreSQL 15.2...`) de MySQL (format `8.0.34`) ; l'accès réussi à la vue `v$version` est propre à Oracle exclusivement, aucun autre moteur ne l'exposant. Toute combinaison de deux tests différenciants convergents parmi ceux-ci est acceptée, l'essentiel étant de procéder par élimination successive plutôt que par une supposition unique.

**R11.** Première requête : apostrophe seule (`id=1'`), qui doit provoquer une anomalie si l'entrée est concaténée sans échappement. Seconde requête : double apostrophe (`id=1''`), qui forme une chaîne syntaxiquement valide et doit restaurer le comportement normal. La première seule ne suffit pas car une erreur peut provenir d'un bug applicatif sans rapport avec la syntaxe SQL ; c'est la restauration par la seconde requête qui confirme spécifiquement que l'anomalie est liée à la syntaxe SQL et non à une autre cause.

**R12.** (1) Déterminer le nombre de colonnes par incrémentation d'`ORDER BY` jusqu'à erreur ; (2) identifier la ou les colonnes acceptant du texte par substitution progressive de valeurs `'a'` à la place de `NULL`, en observant où la lettre de test s'affiche dans le rendu ; (3) si une erreur de type apparaît avec `NULL`, substituer des valeurs de type cohérent (nombre, date) plutôt que du texte systématiquement ; (4) sur Oracle, ajouter `FROM DUAL` car ce SGBD impose une table source même sans sélection réelle ; (5) une fois la colonne texte confirmée, remplacer la valeur de test par les données réelles à exfiltrer (ex. `UNION SELECT NULL, username, password FROM users`), ou concaténer les valeurs si une seule colonne texte est disponible.

**R13.** La paire de requêtes : une condition construite comme vraie (`' OR '1'='1`) et une condition construite comme fausse (`' AND '1'='2`), appliquées sur le même paramètre. La condition de divergence qualifiante : la condition vraie doit afficher un résultat élargi par rapport à la référence (ex. tous les produits) et la condition fausse un résultat restreint ou vide (zéro résultat) — c'est la cohérence et la reproductibilité de cette divergence, pas un résultat isolé, qui confirme le canal.

**R14.** La méthode : injecter une pause conditionnée à une expression toujours vraie (`' AND SLEEP(5)--`), répéter le test 2 à 3 fois pour écarter une latence réseau ponctuelle, puis tester une seconde valeur de délai distincte (`SLEEP(10)`) pour vérifier que le délai mesuré est proportionnel à la valeur injectée. Une seule mesure, même longue et cohérente avec le délai attendu, ne suffit jamais car elle peut provenir d'une latence réseau ponctuelle sans lien avec l'injection ; seule la répétition combinée à la vérification de proportionnalité sur deux valeurs distinctes permet de conclure.

**R15.** Le principe : déterminer d'abord la longueur de la valeur recherchée (`LENGTH(...)`), puis tester chaque position avec `SUBSTRING(valeur, position, 1)` comparée à chaque caractère candidat jusqu'à confirmation, en itérant sur l'ensemble des positions. L'optimisation : remplacer le test d'égalité caractère par caractère (jusqu'à 62 requêtes par position dans le pire cas) par une recherche dichotomique sur le code ASCII du caractère (`ASCII(SUBSTRING(...)) > 109`), réduisant le nombre de requêtes nécessaires par position à environ 7 (log2 de l'espace des caractères testés) — ou, au-delà d'une démonstration de preuve de concept, automatiser via `sqlmap` ou Burp Intruder en mode Cluster Bomb.

**R16.** Vous pouvez en déduire que le comportement observé n'est probablement **pas** lié à la syntaxe SQL mais à une autre cause applicative (bug distinct coïncidant avec l'apostrophe). Il serait prématuré de conclure à une absence totale de vulnérabilité sur ce paramètre : ce test particulier a échoué à démontrer une injection In-Band, mais d'autres canaux (Boolean-Based, Time-Based, etc.) n'ont pas encore été testés et pourraient révéler une vulnérabilité masquée différemment sur ce même point d'entrée.

**R17.** Deux hypothèses à distinguer : (1) il existe une incompatibilité de type entre colonnes empêchant l'affichage malgré l'absence d'erreur apparente — peu probable puisque l'énoncé précise qu'aucune erreur n'est levée ; (2) plus probable ici, la page peut ne pas refléter visuellement le contenu de certaines colonnes retournées (champs non affichés dans le rendu visuel, mais présents dans le code source HTML — attribut caché, métadonnée, commentaire). La vérification qui permet de trancher : inspecter le code source complet de la réponse HTTP, pas seulement le rendu visuel dans le navigateur, pour rechercher la lettre de test dans l'intégralité du HTML retourné.

**R18.** La cause la plus probable, spécifique à Oracle : une comparaison de casse incorrecte, les métadonnées Oracle (`all_tables`, `all_tab_columns`) stockant les noms d'objets en MAJUSCULES par défaut, alors que la requête teste probablement une valeur en minuscules (`WHERE table_name='users'` au lieu de `'USERS'`). C'est un échec silencieux : la requête est syntaxiquement valide et s'exécute sans erreur, mais ne retourne aucun résultat, ce qui peut être interprété à tort comme une absence de table. Le test de confirmation : retester explicitement avec le nom en majuscules.

**R19.** Deux causes distinctes : (1) la syntaxe du payload ne correspond pas au SGBD réel — cause qui ne remet pas en cause la confirmation de l'injection elle-même, seulement le choix de syntaxe pour ce vecteur précis, et qui se corrige en testant les variantes propres aux autres moteurs ; (2) les droits réseau sortants du compte SGBD sont restreints (environnement durci) — cause qui ne remet pas non plus en cause l'injection elle-même si elle est confirmée par ailleurs sur un autre canal, mais qui signale que ce vecteur précis d'exfiltration n'est pas disponible sur cette cible, sans qu'on puisse conclure à l'absence totale de vulnérabilité.

**R20.** Dans ce contexte, seul le canal OAST (Out-of-Band) reste pertinent. Les trois autres sont structurellement inopérants : le canal de contenu et le canal de code HTTP sont tous deux masqués par la réponse immédiate et générique `202 Accepted`, identique quel que soit le résultat réel du traitement différé ; le canal temporel est lui aussi inexploitable puisque la réponse HTTP est renvoyée avant l'exécution réelle de la requête SQL, donc aucun délai mesurable côté client ne peut refléter un traitement asynchrone exécuté plus tard en arrière-plan. Seule une interaction réseau sortante initiée indépendamment par le SGBD, détectable via un service d'écoute externe, reste observable dans ce contexte.

**R21.** Cas username connu : injecter un commentaire après le nom d'utilisateur supposé exister pour neutraliser la vérification du mot de passe (`administrator'--`), en adaptant la syntaxe de commentaire au SGBD — sous MySQL, un espace est requis après `--` (`administrator'-- `), ou utiliser `#` qui n'en nécessite pas ; cette adaptation n'est pas cosmétique : un commentaire syntaxiquement invalide pour le moteur réel fait échouer le contournement même si le champ est bien vulnérable. Cas username inconnu : injecter une tautologie ciblant la première ligne retournée (`' OR 1=1 LIMIT 1--`), `LIMIT 1` (MySQL) devant être remplacé par `TOP 1`/`ROWNUM=1` ou omis selon le SGBD et le comportement de l'application face à un jeu de résultats multiple — sans cette contrainte, une requête retournant plusieurs lignes peut être mal gérée par l'application et faire échouer la connexion malgré une injection techniquement acceptée.

**R22.** Chaîne complète : (1) détection d'un canal In-Band ou Boolean-Based confirmé sur un paramètre dont la page reflète le contenu d'une requête `SELECT` ; (2) détermination du nombre de colonnes via incrémentation d'`ORDER BY` ; (3) identification de la colonne texte exploitable par substitution `NULL`/`'a'` ; (4) exfiltration de données réelles via cette colonne. Le fingerprinting du SGBD (étape distincte) devient nécessaire à partir du moment où l'on doit adapter une syntaxe spécifique à un moteur — énumération via `information_schema` vs vues Oracle en majuscules, `FROM DUAL`, fonctions de concaténation (`CONCAT()` vs `||`) — mais n'est pas indispensable à la détection initiale ni à la détermination du nombre de colonnes, qui sont indépendantes du moteur exact.

**R23.** Phase de stockage : enregistrer une valeur d'apparence inoffensive contenant un fragment d'injection (ex. `administrator'--` dans un champ `display_name`) via une fonctionnalité correctement paramétrée, et observer l'absence d'anomalie — comportement attendu si le paramétrage est correct à ce stade précis. Phase de réutilisation : cartographier systématiquement toutes les fonctionnalités distinctes de l'application qui relisent et réutilisent cette donnée stockée (traitement différé, fonctionnalité d'administration ou de support), puis observer si l'une d'elles déclenche un comportement anormal lors de cette réutilisation (ex. modification effective d'un mot de passe administrateur sans action explicite sur ce compte). Un test isolé de la phase de stockage ne révèle jamais rien par construction, puisque le point d'injection et le point d'exécution sont dissociés dans le temps et dans le code : l'absence d'anomalie au stockage est le comportement normal attendu, pas un signe d'absence de vulnérabilité.

**R24.** Une fois le canal OAST confirmé fonctionnel, la valeur recherchée peut être concaténée dynamiquement au nom de domaine interrogé par le SGBD (ex. `password` concaténé devant le domaine d'écoute dans une requête `xp_dirtree`), faisant transiter la donnée elle-même dans le sous-domaine observé par le service d'écoute en une seule requête, sans itération caractère par caractère. La contrainte technique : la valeur concaténée doit respecter les contraintes de format d'un nom de domaine (longueur, caractères valides) — une valeur trop longue ou contenant des caractères invalides nécessite une troncature ou un encodage préalable avant concaténation.

**R25.** Démarche : (1) confirmer d'abord explicitement que le payload en clair est bien bloqué par le WAF (réponse `403` reproductible) ; (2) tester ensuite une forme encodée du même payload (entités XML hexadécimales, échappement Unicode JSON selon le format d'échange réellement utilisé par l'application) ; (3) observer si cette forme encodée produit un comportement cohérent avec une exécution SQL normale (via les techniques de détection habituelles). Il est indispensable de confirmer d'abord le blocage en clair car, sans cette étape, il est impossible de distinguer un contournement réellement réussi d'une absence de WAF dès le départ — le test perdrait toute valeur probante.

**R26.** Étapes de diagnostic avant conclusion : répéter le test plusieurs fois pour écarter une latence réseau ponctuelle comme explication du délai initial ; tester une seconde valeur de délai distincte (ex. `SLEEP(10)` après `SLEEP(5)`) pour vérifier la proportionnalité ; si aucune reproductibilité ni proportionnalité n'apparaît sur plusieurs répétitions, envisager que la syntaxe testée ne correspond pas au SGBD réel et tester les variantes propres aux autres moteurs avant de conclure à l'inexploitabilité du canal.

**R27.** Avant de conclure à un échec de la technique, envisager : (1) élargir le jeu de caractères testés au-delà de l'alphanumérique simple (caractères spéciaux, espace, ponctuation), la valeur recherchée pouvant en contenir ; (2) vérifier que la syntaxe de comparaison utilisée (`SUBSTRING`, nom de la colonne, nom de la table) est correcte et adaptée au SGBD identifié ; une longueur correctement déterminée mais aucun caractère confirmé suggère un problème de jeu de caractères testé plutôt qu'un canal non fonctionnel, puisque le canal a déjà démontré sa capacité à répondre correctement lors de la détermination de la longueur.

**R28.** Deux facteurs indépendants : (1) la syntaxe de commentaire propre au SGBD cible peut être incorrecte (ex. espace manquant après `--` sous MySQL, rendant le commentaire syntaxiquement invalide) — à diagnostiquer en vérifiant si l'injection elle-même est acceptée sans erreur SQL ; (2) le compte ciblé peut ne pas exister réellement, ou l'application peut mal gérer un jeu de résultats multiple renvoyé par une tautologie non bornée — à diagnostiquer en ajoutant explicitement `LIMIT 1`/`TOP 1` pour forcer un résultat unique plutôt que de dépendre du comportement par défaut de l'application face à plusieurs lignes. Ces deux facteurs doivent être testés séparément car l'un relève de la syntaxe SQL et l'autre du comportement applicatif en aval de la requête.

**R29.** Formulation générale : avant de conclure qu'un comportement observé est causé par l'entrée testée plutôt que par un facteur indépendant, valider systématiquement par une paire de tests construits pour produire des résultats opposés et prévisibles, plutôt que de se fier à une observation unique. Exemple de transfert possible (plusieurs réponses acceptées, l'important étant la cohérence du raisonnement) : lors d'un test d'IDOR, observer qu'un identifiant modifié renvoie un contenu différent du sien ne suffit pas à prouver l'accès à une ressource d'autrui si l'application renvoie par ailleurs un contenu générique ou une erreur formatée de façon similaire pour tout identifiant invalide — il faut comparer la réponse à un identifiant appartenant réellement à un autre utilisateur connu et à un identifiant délibérément inexistant pour distinguer un accès non autorisé réel d'une page d'erreur générique.

**R30.** Démarche attendue : appliquer la même hiérarchie de canaux, en l'adaptant à ce qui reste observable dans ce contexte précis. Le contenu de la réponse reste examinable même sans rendu HTML (corps JSON, structure de réponse) : comparer une paire de requêtes construites comme vraie/fausse sur ce canal en premier. Si le contenu ne diverge jamais, examiner le code de statut HTTP ou GraphQL (erreurs structurées, codes d'erreur applicatifs) comme second canal. Si aucune divergence n'apparaît, mesurer le délai de réponse avec injection d'une pause conditionnelle, en respectant la même exigence de répétition et de proportionnalité. En dernier recours, si l'API dispose d'un accès réseau sortant côté backend, tester un vecteur OAST. Le point central du transfert : ne jamais présumer qu'un canal est inexploitable sans l'avoir testé explicitement par paire opposée, et ne pas supposer que l'absence de rendu HTML élimine d'office les canaux de contenu ou de code — seule la nature réelle de la réponse de cette API précise permet de le déterminer.

---

## Barème d'auto-évaluation

Pour chaque question, attribuez-vous un score de 0 à 3 avant de consulter le corrigé détaillé ci-dessus si ce n'est pas déjà fait :

| Score | Signification |
|---|---|
| **0 — Bloqué** | Aucune piste de raisonnement mobilisable sans aide. |
| **1 — Avec aide** | Réponse obtenue seulement après un indice ou une reformulation de la question. |
| **2 — Autonome sur un cas connu** | Réponse correcte et complète sur un scénario déjà rencontré, sans transfert testé. |
| **3 — Transfert** | Réponse correcte, raisonnement explicite, et capacité démontrée à l'adapter à un contexte ou un scénario nouveau. |

> Le score porte autant sur la qualité et la complétude du **raisonnement** (hypothèses posées, conditions nécessaires, ce qu'il serait prématuré de conclure) que sur la **justesse de la conclusion finale**. Une bonne conclusion obtenue par un raisonnement erroné ou incomplet ne mérite pas un score de 3.

---

# Partie 2 — Cartes de révision

> 18 cartes, 3 par catégorie. Chaque carte porte sur une seule notion ou un seul réflexe technique. Recto = question ou situation ; Verso = réponse concise et vérifiable en quelques secondes, sans payload long à retaper.

### Comprendre

**Carte 1**
Recto : Quelle est la cause structurelle unique derrière toutes les variantes de SQLi ?
Verso : L'absence de séparation structurelle entre code (syntaxe SQL) et donnée (valeur utilisateur) lors de la construction de la requête par concaténation.

**Carte 2**
Recto : Pourquoi un paramètre numérique sans guillemets peut-il rester vulnérable ?
Verso : Si la requête est construite par concaténation de chaînes sans caster réellement la valeur en entier, le paramètre peut être interprété comme une expression SQL évaluée.

**Carte 3**
Recto : Pourquoi le Second-Order SQLi échappe-t-il aux scanners automatisés ?
Verso : Le point de stockage (souvent paramétré) et le point d'exécution (souvent concaténé ailleurs) sont dissociés dans le temps et dans le code.

### Reconnaître

**Carte 4**
Recto : Citez deux surfaces de test souvent négligées au-delà du formulaire principal.
Verso : Le paramètre de tri alimentant `ORDER BY`, et les en-têtes HTTP journalisés (`User-Agent`, `Referer`, `X-Forwarded-For`).

**Carte 5**
Recto : Une erreur 500 isolée sur une apostrophe suffit-elle à confirmer une injection In-Band ?
Verso : Non — il faut confirmer par double apostrophe (`''`), qui restaure le comportement normal si l'erreur est bien liée à la syntaxe SQL.

**Carte 6**
Recto : Un `403 Forbidden` systématique sur un mot-clé SQL en clair signale quoi ?
Verso : Généralement un WAF filtrant sur motif textuel brut, pas une absence de vulnérabilité sous-jacente.

### Tester

**Carte 7**
Recto : Comment confirmer un canal Boolean-Based Blind de façon fiable ?
Verso : Par une paire de requêtes opposées — une condition vraie (résultat élargi) et une condition fausse (résultat vide) — jamais par un seul test.

**Carte 8**
Recto : Comment déterminer le nombre de colonnes pour un UNION-Based ?
Verso : Incrémenter `ORDER BY 1`, `ORDER BY 2`, etc. jusqu'à obtenir une erreur ; le dernier numéro sans erreur est le nombre de colonnes.

**Carte 9**
Recto : Quelles sont les deux conditions de validation d'un canal Time-Based Blind ?
Verso : Reproductibilité sur plusieurs répétitions, et proportionnalité du délai testée sur au moins deux valeurs distinctes (ex. `SLEEP(5)` puis `SLEEP(10)`).

### Interpréter

**Carte 10**
Recto : UNION accepté sans erreur, mais aucune lettre de test visible sur la page : que vérifier ?
Verso : Le code source HTML complet de la réponse, pas seulement le rendu visuel — la colonne peut être présente mais non affichée visuellement.

**Carte 11**
Recto : `information_schema.tables` ne retourne rien sur une cible Oracle : cause la plus probable ?
Verso : Comparaison de casse incorrecte — les métadonnées Oracle (`all_tables`) stockent les noms d'objets en MAJUSCULES.

**Carte 12**
Recto : Aucune interaction OAST reçue malgré une syntaxe correcte pour le SGBD identifié : que faut-il envisager ?
Verso : Des droits réseau sortants restreints côté SGBD (environnement durci) — sans que cela invalide l'injection si elle est confirmée par un autre canal.

### Exploiter

**Carte 13**
Recto : Pourquoi faut-il un espace après `--` dans un bypass d'authentification sous MySQL ?
Verso : Sans cet espace, le commentaire n'est pas syntaxiquement valide sous MySQL — utiliser `#` comme alternative si l'espace est filtré.

**Carte 14**
Recto : Pourquoi `LIMIT 1` est-il souvent nécessaire dans un bypass d'authentification sans username connu ?
Verso : Pour forcer la sélection d'une seule ligne, certaines applications gérant mal un jeu de résultats multiple (`TOP 1`/`ROWNUM=1` sur MSSQL/Oracle).

**Carte 15**
Recto : Avant de tester un contournement de WAF par encodage, quelle vérification est indispensable ?
Verso : Confirmer d'abord que le payload en clair est effectivement bloqué, sinon impossible de distinguer un bypass réussi d'une absence de WAF.

### Déboguer et transférer

**Carte 16**
Recto : Extraction caractère par caractère : aucun caractère confirmé malgré une longueur correcte. Premier réflexe ?
Verso : Élargir le jeu de caractères testés au-delà de l'alphanumérique simple (caractères spéciaux, espace).

**Carte 17**
Recto : Quelle optimisation remplace le test d'égalité caractère par caractère dans une extraction Blind ?
Verso : La recherche dichotomique sur le code ASCII (`ASCII(SUBSTRING(...)) > N`), réduisant le nombre de requêtes par position.

**Carte 18**
Recto : Quel principe de validation (couple vrai/faux) transfère-t-il à d'autres classes de vulnérabilités ?
Verso : Ne jamais conclure d'une observation isolée — valider systématiquement par une paire de tests construits pour produire des résultats opposés et prévisibles.

---

# Partie 3 — Organisation des révisions

## Première tentative

1. Isolez-vous des trois documents sources (`cours.md`, `exploitation.md`, `cheatsheet.md`) et répondez aux 30 questions de la Partie 1 dans l'ordre, sans retour en arrière une fois une question commencée.
2. Notez vos réponses intégralement avant toute consultation du corrigé, y compris celles dont vous êtes incertain — une réponse partielle notée vaut mieux qu'une réponse non tentée.
3. Comparez chaque réponse au corrigé une par une, et attribuez-vous un score selon le barème (0 à 3) immédiatement après chaque comparaison, pas en bloc à la fin.
4. Passez ensuite aux 18 cartes de la Partie 2 en les traitant comme un test minuté (quelques secondes par carte) plutôt qu'en les relisant passivement.
5. Consignez les questions et cartes où le score est inférieur à 2 : elles constituent la base de votre session « Après correction ».

## Après correction

| Si la difficulté exprimée ressemble à… | Document à retravailler en priorité |
|---|---|
| « Je ne sais pas pourquoi ce comportement est vulnérable / j'ai confondu une cause avec un symptôme » | `cours.md` |
| « Je ne sais pas quelle requête envoyer / dans quel ordre tester les techniques » | `exploitation.md` |
| « Je ne me souviens plus de la syntaxe exacte pour ce SGBD / ce payload » | `cheatsheet.md` |
| « J'ai confondu un signal confirmé avec un signal isolé non validé » | `exploitation.md` (sections 3.2 et 7 — indices, faux positifs, diagnostic des échecs) |
| « Je ne sais pas comment adapter ce raisonnement à un autre contexte » | `cours.md` (section Synthèse de révision) et `exploitation.md` (section 10 — leçons transférables) |

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
