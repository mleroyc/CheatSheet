# Information Disclosure — Fiche de révision

Cette fiche doit être utilisée **sans consulter** le cours, la méthodologie ou la cheat sheet lors de la première tentative.

Pour chaque question : réponds à voix haute ou par écrit, puis compare ta réponse au corrigé (section dédiée, plus bas). Note ta réponse de 0 à 3 avec le barème fourni avant de passer à la question suivante.

---

## 1. Comprendre

Objectif : reconstruire le modèle mental de cette vulnérabilité — pourquoi elle forme une famille de vecteurs indépendants plutôt qu'un mécanisme unique, et ce qui détermine son impact réel.

**Q1.** Pourquoi l'Information Disclosure n'est-elle pas une vulnérabilité « à mécanisme unique » comme une injection SQL ou une LFI ? Quelle conséquence cela a-t-il sur la façon de mener l'audit ?

**Q2.** Quelles sont les trois grandes familles de causes à l'origine d'une divulgation d'informations ? Donne un exemple caractéristique de chacune.

**Q3.** Pourquoi une fuite d'information qualifiée de « mineure » (un numéro de version, un chemin de dossier) ne doit-elle jamais être écartée sans évaluation plus poussée ?

**Q4.** Quelle est la différence entre un impact « direct » et un impact « indirect » d'une divulgation d'informations ? Donne un exemple de chaque.

**Q5.** Qu'est-ce qu'un « oracle d'inférence » dans le contexte de cette vulnérabilité, et pourquoi ce principe repose-t-il sur une notion de différence **observable** plutôt que sur un type précis de signal ?

---

## 2. Reconnaître

Objectif : identifier quand une surface donnée devient plausiblement une source de fuite, à partir d'observations précises plutôt que de suppositions.

**Q6.** `robots.txt` liste `Disallow: /internal-reports/`. Que peux-tu en conclure sur la sécurité de ce chemin, et que faudrait-il vérifier avant de conclure quoi que ce soit ?

**Q7.** Une requête sur un paramètre numérique avec la valeur `abc` renvoie une page d'erreur personnalisée mais générique, sans aucun détail technique. Peux-tu conclure que l'application est protégée contre toute divulgation via message d'erreur ?

**Q8.** Un en-tête de réponse `X-Powered-By: PHP/7.2.1` est présent sur toutes les pages de l'application. Qu'est-ce que cela révèle, et qu'est-ce que cela ne permet pas encore de conclure ?

**Q9.** Une page de récupération de mot de passe répond systématiquement « Si un compte existe, un email a été envoyé » quelle que soit l'adresse testée, avec un code 200 identique et une taille de réponse identique. Cette application te semble-t-elle vulnérable à un oracle d'énumération sur ce point précis ?

**Q10.** Tu identifies, lors de la cartographie, que l'application est développée en Spring Boot. Quelle surface de test spécifique à ce framework ta reconnaissance doit-elle désormais prioriser, et pourquoi ce choix dépend-il de cette identification précise ?

---

## 3. Tester

Objectif : choisir, pour une surface donnée, le test minimal pertinent, sans sauter à une conclusion ni multiplier les variantes sans hypothèse précise.

**Q11.** Tu veux établir si un fichier `config.php` connu de l'application possède une variante de sauvegarde exposée. Quel est le test minimal, et quelle règle dois-tu respecter sur le nombre d'éléments modifiés par essai ?

**Q12.** Tu soupçonnes que le dossier `.git` a été déployé par erreur dans la racine web. Quel est le test minimal pour le confirmer, en deux requêtes précises ?

**Q13.** Tu veux établir si la méthode `TRACE` est exploitable pour révéler un en-tête interne ajouté par un proxy. Quelle doit être ta première requête, avant même de tenter `TRACE`, et pourquoi cet ordre est-il nécessaire ?

**Q14.** Tu veux tester si un paramètre déclenche une erreur verbeue. Quelles sont les trois catégories de valeurs hors norme à tester, et pourquoi n'est-il pas suffisant de n'en tester qu'une seule avant de conclure ?

**Q15.** Tu veux établir si une page de compte (`/my-account?id=`) présente une faille d'autorisation de type IDOR. Quel est le test minimal, et quelle vérification supplémentaire est nécessaire même si la réponse semble être un refus ?

---

## 4. Interpréter

Objectif : distinguer une preuve utile d'un signal ambigu, sans conclure prématurément ni douter systématiquement de toute observation.

**Q16.** Une requête sur `/admin/config.bak` renvoie un code 200. Que peux-tu réellement en conclure à ce stade précis, avant même d'avoir examiné le contenu de la réponse ?

**Q17.** Une comparaison de temps de réponse entre deux valeurs d'un paramètre d'authentification montre une différence de 200ms lors d'un seul test. Cette observation constitue-t-elle la preuve d'un oracle temporel exploitable ?

**Q18.** Une requête sur `/.git/HEAD` renvoie un code 404. Que peux-tu en conclure sur la présence d'autres artefacts sensibles (`.env`, `.svn`, source maps) ?

**Q19.** Un message d'erreur revient identique quelle que soit la catégorie de valeur hors norme testée sur un paramètre (type incorrect, caractère spécial, valeur extrême). Que peux-tu en conclure sur la robustesse générale de l'application face aux divulgations par message d'erreur ?

**Q20.** Un accès à `/my-account?id=carlos` avec la session du testeur produit une redirection HTTP 302 vers `/login`. Cette observation suffit-elle à conclure à l'absence de fuite sur cet endpoint ?

---

## 5. Exploiter — Évaluer l'impact et la chaînabilité

Cette compétence se reformule pour cette vulnérabilité : il ne s'agit pas de construire une chaîne d'exploitation technique unique, mais d'évaluer comment une fuite isolée se combine avec d'autres informations ou vulnérabilités déjà identifiées, et de distinguer les niveaux de preuve (observation / qualification / usage démontré).

**Q21.** Tu as trouvé une version précise de framework exposée via un en-tête `X-Powered-By`, et par ailleurs une page de connexion accessible sans limitation de tentatives. Comment ces deux éléments pourraient-ils se combiner pour renforcer l'impact global de l'audit ?

**Q22.** Un commentaire HTML révèle un identifiant de test (`admin / Test1234`), et une page d'administration a été découverte via `robots.txt` mais nécessite une authentification. Décris la chaîne d'usage que ces deux fuites, prises isolément « mineures », permettent de construire ensemble.

**Q23.** Pourquoi la découverte d'un secret dans l'historique Git (via un commit « supprimant » ce secret) doit-elle être traitée avec la même gravité qu'un secret présent dans le code actuellement déployé ?

**Q24.** Distingue les trois niveaux de preuve applicables à une fuite d'information (observation / qualification / usage démontré) à partir de l'exemple d'une clé `SECRET_KEY` trouvée sur un endpoint `/actuator/env`.

**Q25.** Un en-tête `X-Internal-Auth` est révélé via une requête `TRACE`. Quelle étape supplémentaire, distincte de la simple observation de cet en-tête, serait nécessaire pour démontrer un usage réel de cette fuite ?

---

## 6. Déboguer et transférer

Objectif : diagnostiquer précisément un résultat négatif ou ambigu, et distinguer ce qui reste transférable d'un cas à l'autre de ce qui est spécifique au contexte observé.

**Q26.** Après un premier passage de reconnaissance passive (robots.txt, commentaires, en-têtes), aucune fuite n'a été trouvée. Quelle erreur de méthode faut-il écarter en priorité avant de conclure à l'absence de divulgation ?

**Q27.** Une technique de détection d'endpoints de debug qui fonctionnait sur une application Spring Boot (`/actuator/env`) échoue totalement sur une nouvelle cible identifiée comme Symfony. Quelle connaissance reste transférable, et laquelle doit être entièrement reconsidérée ?

**Q28.** Un test d'oracle sur la réinitialisation de mot de passe produit des résultats différents à chaque répétition, sans tendance claire. Quel maillon du raisonnement cela concerne-t-il, et quelle adaptation de méthode (plutôt que d'hypothèse) permettrait de clarifier la situation ?

**Q29.** Un `.htaccess`/une règle de blocage semble empêcher l'accès à `/.git/` (404 systématique), mais `/.env` reste accessible sans restriction. Quelle hypothèse structurelle cette divergence permet-elle de formuler sur la nature de la protection en place ?

**Q30.** Une fuite de code source via fichier `.bak` a été démontrée sur une application précédente en testant uniquement le fichier d'entrée principal (`index.php`). Sur une nouvelle cible, ce même test échoue sur le fichier d'entrée principal. Quelle erreur de généralisation faut-il éviter avant de conclure à l'absence de cette vulnérabilité sur la nouvelle cible ?

---

# Corrigé — Réponses attendues et raisonnement

## 1. Comprendre

**R1.** Contrairement à une injection SQL ou une LFI, qui reposent sur un mécanisme technique précis exploité par une séquence de tests croissante, l'Information Disclosure regroupe des **vecteurs indépendants** partageant un seul critère commun : toute différence observable entre deux états (contenu, code, taille, en-tête, temps) est un signal à investiguer. *Conséquence :* l'audit ne suit pas une chaîne d'étapes progressives mais doit **couvrir systématiquement chaque famille de vecteurs** sans effet tunnel, car chaque surface est potentiellement indépendante des autres.

**R2.** (1) **Échec du nettoyage avant mise en production** — ex. commentaires de développement oubliés, fichiers `.bak` laissés dans la racine web. (2) **Mauvaise configuration serveur** — ex. mode debug actif en production, méthode `TRACE` active. (3) **Comportement applicatif défectueux (oracle d'inférence)** — ex. messages différents selon qu'un compte existe ou non lors d'une tentative de connexion.

**R3.** Parce qu'une fuite « mineure » est rarement une fin en soi : elle constitue souvent le **point de départ de la reconnaissance** et peut se **chaîner** avec d'autres informations ou vulnérabilités pour bâtir une attaque bien plus large (CVE ciblée grâce à une version exposée, identifiants de test réutilisables, etc.). Sa sévérité réelle ne peut être évaluée qu'en contexte, jamais isolément.

**R4.** Un impact **direct** signifie que la donnée divulguée est elle-même critique (ex. clé API, données personnelles). Un impact **indirect** signifie que la donnée facilite une attaque ultérieure sans être elle-même sensible en soi (ex. une version de framework qui permet de cibler une CVE connue). La même fuite technique peut avoir l'un ou l'autre impact selon le contexte.

**R5.** Un oracle d'inférence est une **différence structurelle et observable** (message, code HTTP, taille, temps de réponse) entre deux réponses applicatives correspondant à deux cas métier distincts (ex. compte existant vs inexistant). *Pourquoi la notion de différence observable prime sur le type de signal :* l'oracle peut se manifester par n'importe quel canal mesurable — ce n'est pas la nature du signal qui compte mais le fait qu'il permette de **distinguer de façon fiable** deux états que l'attaquant ne devrait normalement pas pouvoir différencier.

## 2. Reconnaître

**R6.** Cela ne révèle que l'**existence probable** de ce chemin, jamais sa protection réelle — un `Disallow` est une directive pour les robots d'indexation, pas un contrôle d'accès. *À vérifier avant de conclure quoi que ce soit :* l'accessibilité réelle du chemin via une requête directe, et la présence ou non d'une authentification effective dessus.

**R7.** Non, une seule catégorie testée (type incorrect) ne permet pas cette conclusion. La gestion d'erreur peut être durcie pour les erreurs de typage tout en restant verbeuse face à un caractère spécial ou une valeur extrême — ces trois catégories ciblent des points de défaillance différents et doivent toutes être testées avant de conclure à une protection générale.

**R8.** Cela révèle une **divulgation technique indirecte** : la version précise du moteur PHP utilisé. *Ce que cela ne permet pas encore de conclure :* que cette information constitue un impact réel — il faudrait vérifier séparément si une CVE **réellement applicable** à cette version précise existe et reste exploitable sur cette cible.

**R9.** Non, sur la base de cette seule observation, l'application ne présente **pas** de signe d'oracle exploitable sur ce point : la réponse est structurellement identique (message, code, taille) quelle que soit l'existence du compte — c'est précisément le comportement attendu d'une gestion durcie contre l'énumération. Il faudrait néanmoins encore vérifier le temps de réponse (oracle temporel potentiel) avant de conclure définitivement à une protection complète.

**R10.** La surface à prioriser est l'endpoint de diagnostic **`/actuator/env`**, spécifique à Spring Boot (Spring Boot Actuator). *Pourquoi ce choix dépend de l'identification précise :* les chemins de debug sont propres à chaque framework (`/_profiler/` pour Symfony, `/console` pour Werkzeug/H2) — tester une liste générique sans l'adapter à la stack identifiée gaspille des efforts et peut manquer l'endpoint réellement pertinent pour cette cible.

## 3. Tester

**R11.** Test minimal : tester une seule variante à la fois (`config.php.bak`, puis si besoin `config.php~`, puis `.config.php.swp`...) en gardant le nom de fichier de base identique. *Règle à respecter :* ne changer **qu'un seul élément** du nom par essai (suffixe ou extension) — modifier plusieurs éléments simultanément empêcherait d'attribuer un succès éventuel à la variante précise responsable.

**R12.** Deux requêtes précises : `curl -sI https://cible.example/.git/HEAD` (vérifier un code 200 avec un contenu de type `ref: refs/heads/...`) et `curl -s https://cible.example/.git/config` (vérifier un contenu cohérent avec une configuration Git réelle). Ces deux requêtes combinées confirment ou infirment l'exposition sans nécessiter d'extraction complète à ce stade.

**R13.** Première requête nécessaire : une requête `OPTIONS` pour vérifier que `TRACE` figure bien dans l'en-tête `Allow` de la réponse. *Pourquoi cet ordre est nécessaire :* tenter directement `TRACE` sans cette vérification préalable revient à tester une méthode potentiellement désactivée — l'en-tête `Allow` confirme d'abord que la méthode est activée côté serveur avant d'investir du temps dans l'interprétation de sa réponse.

**R14.** Les trois catégories : **types incorrects** (chaîne pour un entier), **caractères spéciaux** (`'`, `"`, `\`, `%00`, `{{`, `${`), et **valeurs extrêmes** (chaînes très longues, nombres négatifs, `null`, valeurs vides). *Pourquoi tester les trois :* chacune cible un point de défaillance distinct dans la validation applicative — une gestion d'erreur peut être durcie pour l'une tout en restant verbeuse pour une autre ; n'en tester qu'une seule donne une image incomplète de la robustesse réelle.

**R15.** Test minimal : accéder à `/my-account?id=` avec la session du testeur, en remplaçant l'identifiant propre par un identifiant tiers connu ou prévisible, et observer si des données appartenant à ce tiers apparaissent dans la réponse. *Vérification supplémentaire nécessaire même en cas de refus apparent :* inspecter explicitement le **corps** d'une éventuelle réponse de redirection — une redirection peut malgré tout contenir les données sensibles dans son corps avant que le navigateur ne la suive.

## 4. Interpréter

**R16.** À ce stade, cela confirme seulement qu'une ressource existe à ce chemin et répond avec succès — **rien de plus** tant que le contenu n'a pas été examiné. Un code 200 pourrait correspondre à une page d'erreur personnalisée renvoyant ce code par défaut, ou à une redirection déguisée. *Prématuré :* conclure à une fuite de code source confirmée sans avoir vérifié le `Content-Type` et le contenu réel de la réponse.

**R17.** Non, une seule mesure ne suffit pas à conclure. Une différence de 200ms peut tout à fait être due au bruit réseau ou à la charge serveur du moment, sans lien avec le comportement applicatif testé. *Ce qu'il faudrait faire avant de conclure :* répéter la comparaison un nombre suffisant de fois pour observer une **distribution** cohérente plutôt qu'une mesure isolée, et vérifier que l'écart reste systématique.

**R18.** Rien de définitif. Un `404` sur `/.git/HEAD` indique seulement que ce chemin précis n'est pas accessible (dossier absent, ou bloqué spécifiquement par une règle ciblée sur `.git`) — cela ne garantit **pas** l'absence d'autres artefacts (`.env`, `.svn`, `.idea`, source maps) qui doivent être testés individuellement, car une règle de blocage peut viser spécifiquement `.git` sans couvrir les autres chemins cachés.

**R19.** Cela indique une **gestion d'erreur uniformisée sur ce paramètre et ces catégories testées précisément** — une bonne pratique a priori. *Prématuré :* généraliser cette conclusion à l'absence totale de divulgation par message d'erreur sur l'ensemble de l'application, puisque seul ce paramètre et ces trois catégories de valeurs ont été testés ; d'autres paramètres ou endroits de l'application peuvent présenter un comportement différent.

**R20.** Non. Une redirection HTTP (302) peut sembler neutraliser l'accès, mais son **corps de réponse** peut malgré tout contenir les données sensibles avant même que le navigateur ne suive la redirection. *Vérification nécessaire :* inspecter explicitement le contenu du corps de cette réponse de redirection plutôt que de se fier uniquement au code HTTP retourné.

## 5. Exploiter — Évaluer l'impact et la chaînabilité

**R21.** La version de framework exposée oriente la recherche vers une **CVE applicable** à cette version précise (ex. une CVE de contournement d'authentification ou de brute-force facilité) ; combinée à l'absence de limitation de tentatives sur la page de connexion, ces deux fuites « mineures » prises séparément se combinent en un vecteur d'attaque concret — soit une exploitation de CVE ciblée, soit une attaque par force brute facilitée par l'absence de protection, potentiellement renforcée par la connaissance de la stack.

**R22.** L'identifiant de test découvert via un commentaire devient directement **réutilisable** sur la page d'administration localisée grâce à `robots.txt` — alors qu'isolément, le commentaire semblait anodin (identifiant « à retirer ») et la page d'administration semblait protégée par une authentification. La combinaison des deux transforme deux fuites mineures en un **accès administrateur potentiel**, illustrant précisément le principe de chaînabilité central à cette méthodologie.

**R23.** Parce que la suppression d'un commit ultérieur **n'efface pas** l'historique Git : le secret reste présent et récupérable dans les commits antérieurs tant que le dossier `.git` reste exposé. Un attaquant disposant de l'historique complet (via `git log`/`git show`) accède à ce secret exactement comme s'il était encore dans le code actuel — la notion de « suppression » n'a donc aucun effet protecteur une fois le dépôt exposé.

**R24.** **Observation** : une chaîne de caractères ressemblant à une clé a été repérée dans la réponse de `/actuator/env`, sans analyse plus poussée. **Qualification** : l'analyse confirme qu'il s'agit bien d'une `SECRET_KEY` au format cohérent avec le framework identifié (ex. structure attendue pour une clé de signature). **Usage démontré** : la clé est effectivement utilisée pour forger un jeton de session valide (ou tout autre usage concret dans le périmètre autorisé du test), démontrant l'impact réel au-delà de la simple présence de la valeur.

**R25.** Il faudrait **forger une requête réutilisant cet en-tête** (`X-Internal-Auth`) vers une ressource normalement protégée, et observer si cela permet d'obtenir un accès autrement refusé. La simple observation de l'en-tête via `TRACE` ne démontre que sa présence, pas sa réutilisabilité effective pour contourner un contrôle d'accès — ces deux étapes correspondent respectivement aux niveaux « qualification » et « usage démontré ».

## 6. Déboguer et transférer

**R26.** Erreur de méthode à écarter en priorité : l'**effet tunnel** — s'être limité aux pages principales de l'application sans examiner les ressources jugées inintéressantes (fichiers JS/CSS, réponses de redirection), ou n'avoir testé qu'un seul rôle d'accès (non authentifié) sans comparaison avec un autre rôle. Un résultat négatif sur une reconnaissance passive incomplète ne permet aucune conclusion tant que l'ensemble des surfaces n'a pas été couvert.

**R27.** *Reste transférable :* le principe général (chercher les endpoints de diagnostic propres au framework identifié, une fois la stack reconnue) et la méthode de vérification (code 200 avec variables/configuration exposées). *À reconsidérer entièrement :* le chemin précis — `/actuator/env` est spécifique à Spring Boot ; sur Symfony, le chemin pertinent devient `/_profiler/`, un endpoint totalement différent dans sa forme bien que jouant un rôle équivalent.

**R28.** Cela concerne le maillon de l'**oracle temporel** — la variabilité sans tendance claire est cohérente avec du bruit réseau plutôt qu'avec une différence structurelle réelle. *Adaptation de méthode plutôt que d'hypothèse :* augmenter significativement le nombre de répétitions et comparer une **distribution de résultats** plutôt qu'une mesure isolée, avant de conclure soit à l'absence d'oracle, soit à sa confirmation par une tendance statistiquement significative.

**R29.** Hypothèse structurelle : la règle de blocage en place est probablement **spécifique au chemin `.git`** (ex. une `DirectoryMatch` ciblant explicitement ce dossier) plutôt qu'une règle générique bloquant l'ensemble des fichiers/dossiers cachés commençant par un point. Cette divergence de comportement entre deux chemins cachés distincts est précisément le signal permettant de distinguer une protection générique d'une protection ciblée et donc incomplète.

**R30.** Erreur à éviter : généraliser un résultat négatif obtenu sur **un seul fichier d'entrée testé** (`index.php`) à l'ensemble de l'application. L'absence de fichier de sauvegarde sur le point d'entrée principal ne garantit rien sur les autres fichiers d'entrée identifiés lors de la cartographie (contrôleurs, autres pages) — il faut tester systématiquement plusieurs fichiers d'entrée distincts avant de conclure à l'absence de cette vulnérabilité sur la nouvelle cible.

### Barème d'auto-évaluation

- **0 — Bloqué :** impossible de fournir une réponse pertinente sans consulter les notes.
- **1 — Avec aide :** réponse partielle ou obtenue après consultation d'un indice.
- **2 — Autonome sur un cas connu :** réponse correcte et raisonnement cohérent dans un scénario familier.
- **3 — Transfert :** réponse correcte dans une situation modifiée, avec justification et interprétation des limites.

La note porte autant sur le raisonnement que sur la conclusion. Une réponse correcte obtenue par hasard, ou sans pouvoir justifier les conditions et les limites, ne doit pas être notée comme une maîtrise complète.

---

# Cartes de révision — Information Disclosure

18 cartes réparties en six compétences (3 cartes chacune). Chaque carte est autonome : le recto se comprend sans consulter une autre carte, le verso tient en quelques lignes.

## Comprendre

**Carte 1**
Recto : Pourquoi l'Information Disclosure est-elle une « famille de vecteurs indépendants » plutôt qu'une vulnérabilité à mécanisme unique ?
Verso : Parce qu'elle regroupe des vecteurs très différents (fichiers oubliés, erreurs provoquées, configuration serveur, oracles applicatifs) partageant un seul critère commun : toute différence observable entre deux états est un signal à investiguer. L'audit doit donc couvrir systématiquement chaque famille, sans suivre une chaîne d'étapes unique.

**Carte 2**
Recto : Quelles sont les trois grandes familles de causes d'une divulgation d'informations ?
Verso : (1) Échec du nettoyage avant mise en production (commentaires, fichiers de sauvegarde). (2) Mauvaise configuration serveur (debug actif, méthode TRACE). (3) Comportement applicatif défectueux — oracle d'inférence (différences de réponse selon l'existence d'une donnée).

**Carte 3**
Recto : Qu'est-ce qui distingue un impact « direct » d'un impact « indirect » pour une fuite d'information ?
Verso : Direct : la donnée elle-même est critique (ex. clé API). Indirect : la donnée facilite une attaque ultérieure sans être critique en soi (ex. une version de framework permettant de cibler une CVE connue).

## Reconnaître

**Carte 4**
Recto : `robots.txt` liste un chemin `Disallow: /admin-legacy/`. Que révèle réellement cette information ?
Verso : Seulement l'existence probable du chemin — jamais sa protection réelle. Un `Disallow` est une directive pour les robots d'indexation, pas un contrôle d'accès ; l'accessibilité doit être testée séparément.

**Carte 5**
Recto : Un en-tête `Server: Apache/2.4.29` est présent sur toutes les réponses. Que cela révèle-t-il, et que cela ne prouve-t-il pas encore ?
Verso : Révèle une divulgation technique indirecte (version précise). Ne prouve pas encore d'impact : il faut vérifier séparément si une CVE réellement applicable à cette version existe et reste exploitable sur la cible.

**Carte 6**
Recto : L'application est identifiée comme utilisant Symfony. Quelle surface de reconnaissance spécifique cette identification doit-elle désormais orienter ?
Verso : Le test de l'endpoint `/_profiler/`, spécifique au profiler de debug Symfony — les chemins d'endpoints de diagnostic sont propres à chaque framework, pas une liste générique universelle.

## Tester

**Carte 7**
Recto : Quelle règle faut-il respecter lors du test de variantes de fichiers de sauvegarde (`.bak`, `~`, `.swp`) sur un fichier connu ?
Verso : Ne modifier qu'un seul élément du nom par essai (suffixe ou extension), en conservant le nom de base identique — modifier plusieurs éléments simultanément empêche d'attribuer un succès éventuel à la variante précise responsable.

**Carte 8**
Recto : Avant de tester la méthode `TRACE` pour révéler un en-tête interne, quelle requête préalable faut-il envoyer, et pourquoi ?
Verso : Une requête `OPTIONS`, pour confirmer que `TRACE` figure dans l'en-tête `Allow`. Tester `TRACE` directement sans cette vérification revient à investir du temps dans une méthode potentiellement déjà désactivée.

**Carte 9**
Recto : Quelles sont les trois catégories de valeurs hors norme à tester systématiquement sur un paramètre pour provoquer une erreur verbeuse ?
Verso : Types incorrects, caractères spéciaux (`'`, `"`, `%00`, `{{`), et valeurs extrêmes (chaînes longues, valeurs négatives, null). Chacune cible un point de défaillance distinct — n'en tester qu'une seule donne une image incomplète.

## Interpréter

**Carte 10**
Recto : Une requête sur un fichier `.bak` renvoie un code 200. Que peux-tu en conclure avant même d'avoir examiné le contenu de la réponse ?
Verso : Rien de définitif sur la fuite elle-même — seulement qu'une ressource existe à ce chemin. Il faut vérifier le `Content-Type` et le contenu réel : un code 200 peut correspondre à une page d'erreur personnalisée, pas nécessairement au code source attendu.

**Carte 11**
Recto : Un test d'oracle temporel montre une différence de 150ms lors d'une seule mesure. Cette observation suffit-elle à conclure à un oracle exploitable ?
Verso : Non. Le bruit réseau peut expliquer cette différence à lui seul. Il faut répéter la mesure un nombre suffisant de fois et observer une distribution cohérente, pas une mesure isolée, avant de conclure à un oracle réel.

**Carte 12**
Recto : Un accès à une page de compte tiers produit une redirection HTTP 302. Cette observation suffit-elle à conclure à l'absence de fuite ?
Verso : Non. Le corps de la réponse de redirection peut malgré tout contenir les données sensibles. Il faut toujours inspecter explicitement ce corps, pas seulement le code HTTP retourné.

## Exploiter — Évaluer l'impact et la chaînabilité

**Carte 13**
Recto : Un identifiant de test est trouvé dans un commentaire HTML (« admin / Test1234 »), et une page d'administration protégée est localisée via `robots.txt`. Pourquoi ces deux fuites « mineures » doivent-elles être évaluées ensemble ?
Verso : Parce que l'identifiant trouvé devient directement réutilisable sur la page localisée — isolément, chaque fuite semblait mineure (identifiant « à retirer », page authentifiée), mais leur combinaison transforme le tout en un accès administrateur potentiel.

**Carte 14**
Recto : Pourquoi un secret « supprimé » dans un commit Git ultérieur doit-il toujours être traité comme compromis si le dossier `.git` est exposé ?
Verso : Parce que la suppression d'un commit ultérieur n'efface pas l'historique — le secret reste présent et récupérable dans les commits antérieurs via `git log`/`git show`, exactement comme s'il était encore dans le code actuel.

**Carte 15**
Recto : Quels sont les trois niveaux de preuve applicables à une fuite d'information, du plus faible au plus fort ?
Verso : Observation (une anomalie est notée, sans qualification) → Qualification (la nature exacte de l'information est confirmée, ex. type de secret) → Usage démontré (un impact concret est établi à partir de l'information, ex. jeton forgé avec succès).

## Déboguer et transférer

**Carte 16**
Recto : Aucune fuite n'est trouvée après un premier passage de reconnaissance passive. Quelle erreur de méthode faut-il écarter en priorité avant de conclure ?
Verso : L'effet tunnel : s'être limité aux pages principales sans examiner JS/CSS/redirections, ou n'avoir testé qu'un seul rôle d'accès. Un résultat négatif incomplet ne permet aucune conclusion tant que toutes les surfaces n'ont pas été couvertes.

**Carte 17**
Recto : Une technique de détection d'endpoint de debug qui fonctionnait sur une application Spring Boot échoue sur une nouvelle cible Symfony. Que faut-il reconsidérer ?
Verso : Le chemin précis testé (`/actuator/env` → `/_profiler/`) : il est spécifique au framework. Le principe général (chercher l'endpoint de diagnostic propre à la stack identifiée) reste transférable, mais sa forme concrète change entièrement.

**Carte 18**
Recto : `/.git/HEAD` renvoie 404 mais `/.env` reste accessible sans restriction. Quelle hypothèse structurelle cette divergence permet-elle de formuler ?
Verso : Que la règle de blocage en place cible spécifiquement `.git` plutôt que l'ensemble des fichiers/dossiers cachés — une protection ciblée et donc incomplète, à distinguer d'une règle générique qui bloquerait uniformément tous les chemins commençant par un point.

---

## 7. Organisation des révisions

### Première tentative

1. Répondre à toutes les questions sans consulter le cours, la méthodologie ou la cheat sheet.
2. Marquer les questions bloquantes.
3. Noter les réponses incomplètes ou reposant sur une supposition.
4. Consulter le corrigé seulement après avoir répondu à l'ensemble des questions d'une catégorie.
5. Évaluer chaque réponse de 0 à 3 avec le barème.

### Après correction

Pour chaque erreur, identifier sa nature :

- Mécanisme mal compris.
- Condition oubliée.
- Mauvais choix de test.
- Résultat mal interprété.
- Chaînage/impact mal évalué.
- Diagnostic insuffisant.
- Difficulté à transférer les connaissances.

| Difficulté | Support à retravailler |
|---|---|
| Je ne comprends pas pourquoi cette fuite existe ou pourquoi elle importe. | `cours.md` |
| Je ne sais pas quelle surface tester ensuite, ni dans quel ordre. | `exploitation.md` |
| Je connais le vecteur, mais j'oublie la syntaxe précise. | `cheatsheet.md` |
| Je n'arrive pas à interpréter mes résultats (ambigu vs confirmé). | `exploitation.md`, sections 4 et 7 |
| Je ne sais pas évaluer la chaînabilité de deux fuites entre elles. | `cours.md`, section 3, puis nouveau scénario pratique |

Ne pas relire l'intégralité des notes après chaque erreur : revoir en priorité la partie responsable du blocage, puis retenter de répondre de mémoire.

### Révisions espacées

- Jour 0 : première récupération active.
- Jour 1 : révision des éléments difficiles.
- Jour 3 : nouvelle tentative sans notes.
- Jour 7 : révision des erreurs persistantes.
- Jour 14 : questions de transfert.
- Jour 30 : vérification globale de la maîtrise.

Ces intervalles sont indicatifs : les cartes échouées doivent être revues plus tôt que les cartes maîtrisées. Un calendrier fixe ne garantit pas, à lui seul, la mémorisation.
