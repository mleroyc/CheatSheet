# File Upload — Fiche de révision

Cette fiche doit être utilisée **sans consulter** le cours, la méthodologie ou la cheat sheet lors de la première tentative.

Pour chaque question : réponds à voix haute ou par écrit, puis compare ta réponse au corrigé (section dédiée, plus bas). Note ta réponse de 0 à 3 avec le barème fourni avant de passer à la question suivante.

---

## 1. Comprendre

Objectif : reconstruire le modèle mental de la vulnérabilité — pourquoi un dépôt de fichier non validé devient dangereux, et ce qui distingue l'acceptation d'un fichier de son exploitation réelle.

**Q1.** Quelle est la différence entre « le serveur accepte un fichier à l'upload » et « le fichier déposé est exploitable » ? Pourquoi cette distinction est-elle centrale pour toute cette vulnérabilité ?

**Q2.** Quels sont les quatre attributs d'un fichier qu'une application peut choisir de valider (ou non) à l'upload ? En quoi leur fiabilité respective diffère-t-elle fortement ?

**Q3.** Pourquoi un même défaut de validation (ex. absence totale de contrôle d'extension) peut-il aboutir, sur deux applications différentes, à des impacts aussi différents qu'une simple divulgation de code source et une compromission complète du serveur ?

**Q4.** Quelle est la différence fondamentale entre un fichier « non exécutable configuré » et un fichier « exécutable non configuré » du point de vue du traitement serveur, et pourquoi cette seconde situation ne doit-elle pas être confondue avec un succès d'exploitation ?

**Q5.** Pourquoi la vulnérabilité d'upload n'est-elle pas seulement une question de RCE ? Quels impacts additionnels existent même en l'absence totale d'exécution de code serveur ?

---

## 2. Reconnaître

Objectif : identifier quand une fonctionnalité d'upload devient plausiblement exploitable, à partir d'observations précises plutôt que de suppositions.

**Q6.** Un formulaire d'avatar accepte un fichier `.jpg` et retourne un chemin de type `/uploads/avatar_a1b2c3d4.jpg` dans sa réponse JSON. Quels éléments de ce comportement orientent déjà ton hypothèse sur la robustesse du mécanisme de stockage, avant même tout test actif ?

**Q7.** Un endpoint d'upload refuse un fichier `.exe` avec le message « Extension non autorisée : .exe ». Quelle hypothèse peux-tu formuler sur le type de filtrage en place, et quelle limite cette hypothèse comporte-t-elle encore ?

**Q8.** Une requête `OPTIONS` sur `/uploads/` renvoie un en-tête `Allow: GET, HEAD, POST, PUT, OPTIONS`. Qu'est-ce que cela révèle, et qu'est-ce que cela ne révèle pas encore ?

**Q9.** Un script PHP brut uploadé sous le nom `test.jpg` est rejeté avec le message « Fichier image invalide ». Quel mécanisme de validation cela suggère-t-il, et quelle famille de contournement devient alors l'hypothèse à tester en priorité ?

**Q10.** Une application accepte l'upload de fichiers `.docx` pour un service de « génération d'aperçu automatique ». Indépendamment de toute faille d'extension ou de MIME, quel autre type de vulnérabilité ce contexte rend-il plausible, et pourquoi ?

---

## 3. Tester

Objectif : choisir, pour une hypothèse donnée, le test minimal pertinent, sans sauter directement à une technique plus sophistiquée que nécessaire.

**Q11.** Tu veux établir si la validation du type de fichier repose uniquement sur le `Content-Type` déclaré. Quel est le test minimal à effectuer, et quelle doit être la seule variable modifiée par rapport à un upload légitime pour que le résultat soit interprétable ?

**Q12.** Un upload de `shell.php` est refusé avec un message mentionnant explicitement l'extension `.php`. Quel est le test minimal suivant, et pourquoi faut-il tester une seule catégorie de variante (ex. extensions alternatives) avant de passer à l'obfuscation de nom ?

**Q13.** Toutes les extensions alternatives et obfuscations de nom échouent. Quel test minimal permet de vérifier si un détournement de fichier de configuration (`.htaccess`) est envisageable, et quel prérequis dois-tu avoir confirmé avant de le tenter ?

**Q14.** Tu soupçonnes une architecture d'upload en deux temps (sandbox puis déplacement). Quel est le test minimal pour confirmer une fenêtre de race condition, et pourquoi un échec après une seule tentative n'est-il pas concluant ?

**Q15.** Un fichier a été déposé avec succès et son chemin est connu. Quel est le test minimal pour distinguer une simple divulgation de code source d'une exécution de code réelle ?

---

## 4. Interpréter

Objectif : distinguer une preuve utile d'un signal ambigu, sans conclure prématurément ni douter systématiquement de toute observation.

**Q16.** Un fichier `polyglotte.jpg` contenant un payload dans ses métadonnées EXIF est accepté à l'upload, là où un script PHP brut était rejeté. Que peux-tu en conclure sur l'impact de cette vulnérabilité à ce stade précis, et que resterait-il à démontrer ?

**Q17.** Une requête GET sur `shell.php` déposé via contournement de liste noire renvoie le code source PHP affiché en clair dans la réponse. Ce résultat constitue-t-il un échec de l'exploitation ? Que peux-tu réellement en conclure ?

**Q18.** Une tentative de race condition échoue après une seule paire de requêtes (upload + GET immédiat). Cette observation permet-elle de conclure à l'absence de fenêtre d'exploitation ?

**Q19.** Un fichier `.htaccess` est accepté à l'upload, mais la requête suivante sur l'extension triviale censée être redirigée vers un handler PHP ne produit aucun effet (le fichier est servi tel quel). Quelles causes distinctes cette observation peut-elle recouvrir ?

**Q20.** Un fichier SVG contenant `<script>` est accepté à l'upload et semble correctement stocké, mais son ouverture directe dans un navigateur ne déclenche aucune exécution de script. Quelles explications alternatives faut-il envisager avant de conclure à l'absence de vulnérabilité XSS ?

---

## 5. Exploiter

Objectif : reconstruire une chaîne d'exploitation cohérente en explicitant les dépendances entre chaque étape, plutôt que d'énumérer des techniques isolées.

**Q21.** Tu disposes d'un fichier polyglotte accepté à l'upload (payload dans les métadonnées EXIF, structure JPEG valide), mais aucun point d'inclusion dynamique (LFI) n'est disponible dans l'application. Quelle chaîne d'exploitation resterait envisageable pour rendre ce fichier exécutable, et quelle condition serveur devrait être réunie ?

**Q22.** Décris les étapes et les dépendances d'une chaîne d'exploitation complète fondée sur le détournement d'un `.htaccess`, du dépôt du fichier de configuration jusqu'à la preuve d'impact. Que se passe-t-il si l'une des étapes intermédiaires échoue ?

**Q23.** Une fonctionnalité d'upload accepte des fichiers `.svg` et les sert directement, sans forçage de téléchargement, depuis le même domaine que l'application. Aucun vecteur RCE n'est exploitable. Quelle chaîne d'exploitation reste construisible, et quel est son objectif final ?

**Q24.** Pourquoi la preuve d'un dépôt réussi (fichier accepté, chemin connu) ne doit-elle jamais être confondue avec la preuve d'un contournement de validation, ni cette dernière avec une preuve d'impact ? Situe ces trois niveaux dans une chaîne d'exploitation typique de cette vulnérabilité.

**Q25.** Un document `.xlsx` contenant une entité XML externe est accepté et traité par un service de « génération de miniature ». Quelle est la chaîne d'exploitation complète jusqu'à la lecture d'un fichier système, et quelle condition sur le parseur XML doit être vérifiée pour que cette chaîne aboutisse ?

---

## 6. Déboguer et transférer

Objectif : diagnostiquer précisément un échec et distinguer ce qui reste transférable d'un cas à l'autre de ce qui est spécifique à la configuration observée.

**Q26.** Un fichier polyglotte EXIF fonctionnait sur une application précédente, mais échoue systématiquement sur la cible actuelle malgré une structure JPEG identique. Quelle hypothèse faut-il vérifier en priorité avant de conclure à une protection plus robuste ?

**Q27.** Une extension alternative (`.phtml`) a permis une exécution de code sur une cible Apache. Face à une nouvelle cible identifiée comme IIS, quelles connaissances du cas initial restent transférables telles quelles, et lesquelles doivent être entièrement reconsidérées ?

**Q28.** Un test de race condition réussit une fois sur dix tentatives environ, de façon non reproductible à volonté. Quel maillon de la chaîne d'exploitation cela concerne-t-il, et quelle adaptation de méthode (plutôt que d'hypothèse) permettrait de fiabiliser le test ?

**Q29.** Le dépôt d'un `.htaccess` est accepté, mais son contenu n'a aucun effet observable sur le répertoire cible. Quelle hypothèse structurelle (indépendante du contenu du fichier lui-même) faut-il vérifier avant de conclure à un échec de la technique ?

**Q30.** Une technique de null byte (`shell.php%00.jpg`) qui fonctionnait sur un environnement de test personnel échoue systématiquement contre une cible en conditions réelles. Quelle connaissance générale reste applicable, et quelle hypothèse précise faut-il vérifier avant d'abandonner cette piste ?

---

# Corrigé — Réponses attendues et raisonnement

## 1. Comprendre

**R1.** L'acceptation à l'upload démontre seulement qu'une ou plusieurs couches de validation (nom, MIME déclaré, contenu, taille) ont été satisfaites — elle ne dit rien du traitement que le serveur appliquera ensuite à ce fichier. L'exploitabilité dépend entièrement de ce qui se passe **après** le dépôt : le fichier est-il interprété comme un script, servi directement à un navigateur, ou traité par un parseur ? Cette distinction est centrale car elle évite de confondre un simple contournement de filtre avec un impact réel, deux preuves de nature différente.

**R2.** Les quatre attributs sont : le **nom** (et son extension), le **type MIME déclaré** (`Content-Type` de la partie multipart), le **contenu binaire réel** du fichier, et sa **taille**. Le nom et le MIME déclaré sont **entièrement contrôlés par le client** et ne constituent aucune garantie en soi ; le contenu binaire réel (magic bytes, structure complète) est la seule donnée que le client ne peut pas falsifier aussi directement, bien qu'il reste contournable par des fichiers polyglottes.

**R3.** L'impact dépend des **restrictions appliquées après l'upload** : si le répertoire de destination interprète les scripts (handler configuré), l'impact peut atteindre la RCE ; si l'extension n'est pas interprétée par le serveur de destination, le même fichier déposé ne produit qu'une divulgation de code source ou une absence totale d'effet. La même faille de validation en amont peut donc produire des résultats très différents selon la configuration serveur en aval, propre à chaque application.

**R4.** Un fichier « exécutable configuré » voit son code **interprété** par le serveur, qui renvoie le résultat de l'exécution (pas le code source) — c'est la condition du web shell fonctionnel. Un fichier « exécutable non configuré » (handler absent sur ce répertoire/cette extension) produit soit une erreur, soit l'**affichage du code source en clair** : c'est une divulgation d'information, un impact réel mais **distinct et moindre** qu'une RCE — ne pas confondre les deux preuves.

**R5.** Même sans aucune capacité d'exécution côté serveur, un fichier HTML/SVG accepté et servi directement peut déclencher un **Stored XSS** dans le navigateur d'une victime consultant le fichier ; un document structuré (`.docx`/`.xlsx`/`.svg`) traité par un parseur XML mal configuré peut permettre une **XXE** (lecture de fichiers arbitraires côté serveur) ; un upload combiné à une absence de contrôle du nom peut permettre un **Path Traversal** écrasant un fichier critique ; et l'absence de limite de taille peut causer un **DoS**.

## 2. Reconnaître

**R6.** Le nom de fichier retourné (`avatar_a1b2c3d4.jpg`) suggère un **renommage aléatoire**, indice d'un contrôle robuste neutralisant à lui seul la plupart des techniques d'obfuscation d'extension. *Reste à vérifier :* si l'extension stockée (`.jpg`) est dérivée du contenu réel validé (magic bytes) ou simplement reprise du nom original fourni par le client — un renommage du nom n'empêche pas forcément une falsification de l'extension conservée.

**R7.** Hypothèse plausible : un filtrage par **liste noire** ou **liste blanche** explicite par extension, puisque le message cite précisément `.exe`. *Limite de cette hypothèse :* un seul test sur `.exe` ne permet pas de distinguer une liste noire (potentiellement incomplète, donc contournable par des variantes) d'une liste blanche stricte (rejetant tout ce qui n'est pas explicitement autorisé) — il faudrait tester une extension dangereuse d'un autre type (ex. `.php`) pour affiner.

**R8.** Cela révèle que la méthode `PUT` est **activée au niveau serveur** sur ce répertoire, un vecteur de dépôt direct potentiellement indépendant du formulaire d'upload classique et de ses validations applicatives. *Ce que cela ne révèle pas :* si `PUT` est effectivement exploitable sans authentification ou autorisation applicative distincte — une tentative de `PUT` peut encore être bloquée par une couche de contrôle d'accès séparée (401/403).

**R9.** Cela suggère une **validation de contenu** allant au-delà du nom/MIME déclaré — probablement une tentative d'extraction de dimensions ou de vérification de magic bytes, qui échoue sur un fichier sans structure d'image réelle. *Famille de contournement à tester en priorité :* le fichier **polyglotte** (payload injecté dans les métadonnées d'une image structurellement valide), qui satisfait cette validation tout en restant porteur d'un contenu exploitable.

**R10.** Ce contexte rend plausible une vulnérabilité **XXE** : un service de « génération d'aperçu automatique » implique qu'un **parseur XML traite réellement le contenu** du document (le format `.docx` est une archive ZIP de fichiers XML), et non pas seulement qu'il soit stocké. Si ce parseur résout les entités externes, le document peut servir de vecteur de lecture de fichiers arbitraires côté serveur, indépendamment de toute faille d'extension.

## 3. Tester

**R11.** Test minimal : uploader un fichier avec une extension dangereuse (ex. `.php`) mais un `Content-Type` déclaré cohérent avec une image légitime (`image/jpeg`). *Seule variable à modifier :* le `Content-Type` déclaré et le contenu du fichier, en conservant une structure de requête par ailleurs identique à l'upload légitime de référence — cela permet d'attribuer un éventuel succès (ou échec) spécifiquement à cette couche de validation.

**R12.** Test minimal : tester une **seule** extension alternative plausible pour la stack cible (ex. `.phtml` pour une cible Apache/PHP) avant de passer à l'obfuscation de nom. *Pourquoi tester une catégorie à la fois :* les extensions alternatives et l'obfuscation de nom ciblent des mécanismes de filtrage **différents** (liste incomplète vs comparaison de chaîne mal implémentée) — mélanger les deux dans un même test empêcherait d'attribuer un succès éventuel à la cause précise.

**R13.** Test minimal : uploader un fichier `.htaccess` minimal contenant une directive `AddType` pour une extension triviale, puis observer s'il est accepté sans rejet par nom. *Prérequis à avoir confirmé :* que le serveur cible est identifié comme **Apache** (pour `.htaccess`) ou **IIS** (pour `web.config`) — cette technique est spécifique à la stack serveur et inutile à tester sur l'autre.

**R14.** Test minimal : envoyer une requête d'upload suivie **immédiatement** d'une requête GET sur le chemin prévisible du fichier, et observer si le contenu exécuté est retourné avant une éventuelle suppression. *Pourquoi un échec après une tentative n'est pas concluant :* la fenêtre de course peut être de l'ordre de la milliseconde — un seul essai a une probabilité très faible de « gagner la course » même si la fenêtre existe réellement ; il faut un volume de requêtes nettement supérieur pour conclure de façon fiable.

**R15.** Test minimal : une requête GET directe sur le chemin du fichier déposé, en observant si la réponse contient le **résultat d'une commande injectée** (ex. `id`) plutôt que le **code source brut** du fichier. Ces deux résultats sont des signaux distincts et non ambigus permettant de trancher immédiatement entre les deux niveaux d'impact.

## 4. Interpréter

**R16.** Cela confirme uniquement que la validation de contenu porte sur la **structure/signature** de l'image (dimensions, magic bytes) mais pas sur l'absence de données additionnelles exploitables dans les métadonnées — c'est une **primitive de dépôt**, pas une preuve d'impact. *Reste à démontrer :* qu'un vecteur permet de faire **interpréter** ce fichier comme du code (détournement d'extension via `.htaccess`, ou LFI disponible séparément) ; sans ce second vecteur, le fichier reste une image stockée inerte.

**R17.** Non, ce n'est pas un échec total : cela indique que le handler d'exécution n'est **pas configuré** sur cette extension dans ce répertoire précis — c'est un **impact distinct** de la RCE, à savoir une **divulgation de code source**, potentiellement critique en soi (secrets, logique métier). *Réellement conclu :* le contournement de filtre a réussi (dépôt accepté), mais le vecteur d'exécution spécifique testé n'est pas disponible à ce chemin — il reste pertinent de tester une extension alternative.

**R18.** Non, un seul échec ne permet pas de conclure. La fenêtre de race condition peut être de l'ordre de la milliseconde, et une seule paire de requêtes a une probabilité très faible de l'atteindre même si elle existe réellement. *Ce qu'il faudrait faire avant de conclure :* répéter le test avec un volume de requêtes nettement supérieur et un contrôle fin du timing (ex. Turbo Intruder) — un échec répété malgré un volume élevé est un signal bien plus fiable d'une opération atomique.

**R19.** Plusieurs causes distinctes possibles : (1) le fichier de configuration local est accepté mais **ignoré par le serveur** (ex. `AllowOverride None` sous Apache, désactivant la prise en compte des `.htaccess` dans ce répertoire) ; (2) l'extension triviale choisie entre en conflit avec une autre règle de configuration déjà présente ; (3) le chemin d'accès au fichier triviale testé ne correspond pas réellement au répertoire où le `.htaccess` a été déposé. *Prématuré :* conclure que la technique de détournement de configuration est intrinsèquement inefficace.

**R20.** Explications alternatives à envisager : le fichier est servi avec un en-tête **`Content-Disposition: attachment`** forçant le téléchargement plutôt que l'affichage direct ; le fichier est servi depuis un **domaine séparé** de l'application, neutralisant l'intérêt du vol de cookies de session dans ce contexte précis ; ou le navigateur de test applique des protections spécifiques (bloqueurs de script) non représentatives du comportement par défaut. *Prématuré :* conclure que le format SVG lui-même n'est pas exploitable pour du XSS.

## 5. Exploiter

**R21.** Chaîne envisageable : (1) tenter un **détournement de fichier de configuration** (`.htaccess`/`web.config`) pour rediriger une extension triviale vers un handler de script, ce qui rendrait le fichier polyglotte (ou une copie renommée avec cette extension) interprétable. *Condition serveur requise :* que le serveur prenne effectivement en compte les fichiers de configuration locaux (`AllowOverride` actif sous Apache) — sans cette condition, cette chaîne échoue également et seule une autre LFI découverte ailleurs resterait exploitable.

**R22.** Étapes : (1) **Point d'entrée** — upload n'excluant pas explicitement les noms `.htaccess`/`web.config` ; (2) **Primitive technique** — dépôt du fichier de configuration redéfinissant le handler pour une extension triviale ; (3) **Déclenchement** — dépôt d'un second fichier avec cette extension contenant le payload ; (4) **Effet intermédiaire** — le répertoire interprète désormais cette extension comme du PHP ; (5) **Aboutissement** — requête GET exécutant le payload ; (6) **Preuve** — résultat de commande dans la réponse. *Si une étape intermédiaire échoue* (ex. `AllowOverride None`), toute la chaîne s'arrête à cette étape précise — ce n'est pas un échec global mais un maillon identifiable (voir section Déboguer).

**R23.** Chaîne construisible : upload d'un fichier SVG contenant un payload JavaScript (`<svg onload="...">`), servi directement et consulté par une victime dans son navigateur — constituant un **Stored XSS**. *Objectif final :* exécution de script dans le contexte d'origine de l'application (vol de cookies de session, actions au nom de la victime), un impact entièrement indépendant de toute capacité d'exécution de code côté serveur.

**R24.** Un dépôt réussi (fichier accepté, chemin connu) démontre seulement que **l'upload a franchi une étape de contrôle** — rien sur l'exploitabilité. Un contournement de validation démontré (ex. extension dangereuse acceptée malgré un filtre identifié) démontre une **faille de validation réelle**, mais pas encore d'impact tant que le traitement serveur en aval n'est pas vérifié. La preuve d'impact (résultat de commande, script exécuté, fichier système lu) démontre l'**aboutissement réel** de la chaîne. Ces trois niveaux correspondent respectivement aux étapes « point d'entrée », « primitive/déclenchement », et « aboutissement/preuve » d'une chaîne d'exploitation typique.

**R25.** Chaîne complète : (1) insertion d'une entité XML externe (`<!ENTITY xxe SYSTEM "file:///etc/passwd">`) dans le fichier `document.xml` de l'archive `.xlsx` ; (2) upload du document modifié ; (3) déclenchement du service de génération de miniature, qui invoque un parseur XML sur le contenu ; (4) si ce parseur résout les entités externes, le contenu du fichier ciblé apparaît dans la sortie du traitement (aperçu, message d'erreur). *Condition sur le parseur :* que la **résolution des entités externes soit activée** — une configuration par défaut vulnérable sur de nombreux parseurs XML non durcis, mais à vérifier explicitement, pas à présumer.

## 6. Déboguer et transférer

**R26.** Hypothèse à vérifier en priorité : que l'application effectue une **re-compression** de l'image côté serveur (reconstruction pixel par pixel via une bibliothèque graphique), ce qui détruit systématiquement les métadonnées EXIF et donc le payload injecté — une contre-mesure plus robuste que la simple validation de structure/magic bytes testée sur l'application précédente. *Prématuré :* conclure directement à une protection générale plus stricte sans identifier ce mécanisme précis.

**R27.** *Reste transférable :* le principe général (contourner une liste noire via des extensions historiquement interprétées par un serveur donné) et la logique de diagnostic (distinguer liste blanche stricte de liste noire incomplète via les messages d'erreur). *À reconsidérer entièrement :* la famille d'extensions pertinente — `.phtml` est spécifique à Apache/PHP ; sur IIS, les variantes pertinentes seraient plutôt `.asa`, `.cer`, `.asax`, et le vecteur de détournement de configuration viserait `web.config` plutôt que `.htaccess`.

**R28.** Cela concerne le maillon du **déclenchement** — la fenêtre de race condition existe bien (certaines tentatives réussissent), mais elle est trop étroite pour être atteinte de façon fiable par le volume/timing actuel. *Adaptation de méthode plutôt que d'hypothèse :* augmenter significativement le volume de requêtes envoyées en rafale et utiliser un outil à contrôle de timing plus fin (ex. Turbo Intruder), plutôt que de changer d'hypothèse sur l'existence même de la fenêtre.

**R29.** Hypothèse structurelle à vérifier : que la configuration serveur **ignore les fichiers de configuration locaux** dans ce répertoire (`AllowOverride None` sous Apache, ou équivalent IIS désactivant l'interprétation locale de `web.config`) — une cause indépendante du contenu précis du `.htaccess` testé. Tester un contenu différent du `.htaccess` sans vérifier cette hypothèse en premier serait une perte de temps, puisque la cause probable est structurelle et non liée au contenu.

**R30.** *Connaissance générale qui reste applicable :* le principe de troncature de nom de fichier à un caractère spécial reste un mécanisme valide dans certains environnements. *Hypothèse précise à vérifier :* la **version de l'environnement d'exécution** cible (PHP < 5.3.4 pour le null byte classique) — cette technique est historiquement datée et inopérante sur des versions modernes ; un échec systématique sur une cible réelle récente est cohérent avec cette limite de version plutôt qu'avec une protection active spécifique.

### Barème d'auto-évaluation

- **0 — Bloqué :** impossible de fournir une réponse pertinente sans consulter les notes.
- **1 — Avec aide :** réponse partielle ou obtenue après consultation d'un indice.
- **2 — Autonome sur un cas connu :** réponse correcte et raisonnement cohérent dans un scénario familier.
- **3 — Transfert :** réponse correcte dans une situation modifiée, avec justification et interprétation des limites.

La note porte autant sur le raisonnement que sur la conclusion. Une réponse correcte obtenue par hasard, ou sans pouvoir justifier les conditions et les limites, ne doit pas être notée comme une maîtrise complète.

---

# Cartes de révision — File Upload

18 cartes réparties en six compétences (3 cartes chacune). Chaque carte est autonome : le recto se comprend sans consulter une autre carte, le verso tient en quelques lignes.

## Comprendre

**Carte 1**
Recto : Quelle distinction fondamentale faut-il toujours établir entre « l'upload est accepté » et « le fichier est exploitable » ?
Verso : L'acceptation démontre seulement qu'une couche de validation a été satisfaite. L'exploitabilité dépend du traitement appliqué par le serveur après le dépôt : interprétation comme script, service direct au navigateur, ou traitement par un parseur. Ces deux questions doivent toujours être évaluées séparément.

**Carte 2**
Recto : Pourquoi le `Content-Type` déclaré dans une requête multipart n'est-il jamais, à lui seul, une preuve fiable de la nature d'un fichier ?
Verso : Parce que c'est une donnée entièrement fournie et contrôlée par le client, modifiable librement via un proxy d'interception — elle ne reflète en rien le contenu binaire réel du fichier transmis.

**Carte 3**
Recto : Quelle différence d'impact distingue un fichier exécutable « non configuré » d'un fichier exécutable « configuré » sur le répertoire de destination ?
Verso : Non configuré : erreur ou affichage du code source en clair (divulgation d'information). Configuré : le serveur interprète le code et renvoie le résultat de l'exécution (impact RCE). Deux niveaux de preuve distincts à ne jamais confondre.

## Reconnaître

**Carte 4**
Recto : Un upload refusé renvoie le message « Extension non autorisée : .exe ». Que cela révèle-t-il, et que cela ne prouve-t-il pas encore ?
Verso : Révèle un filtrage explicite par extension (liste noire ou blanche). Ne prouve pas encore laquelle des deux : une liste noire reste potentiellement contournable par des variantes non listées, à distinguer par un second test.

**Carte 5**
Recto : Une requête `OPTIONS` sur un répertoire d'upload renvoie `PUT` dans l'en-tête `Allow`. Que cela signifie-t-il, et que cela ne garantit-il pas ?
Verso : La méthode `PUT` est activée au niveau serveur. Cela ne garantit pas qu'elle est exploitable sans restriction : une couche d'autorisation applicative distincte peut encore bloquer la requête (401/403).

**Carte 6**
Recto : Une application accepte l'upload de fichiers `.docx` pour une fonctionnalité de « génération d'aperçu ». Quelle famille de vulnérabilité ce contexte rend-il plausible, indépendamment de toute faille d'extension ?
Verso : Une XXE : le format `.docx` est une archive XML, et la génération d'aperçu implique qu'un parseur XML traite réellement le contenu — un terrain propice si la résolution des entités externes n'est pas désactivée.

## Tester

**Carte 7**
Recto : Quel est le test minimal pour établir si la validation d'upload repose uniquement sur le `Content-Type` déclaré ?
Verso : Uploader un fichier avec une extension dangereuse et un contenu malveillant, mais un `Content-Type` déclaré cohérent avec une image légitime (`image/jpeg`). Une acceptation confirme que cette couche seule ne bloque rien.

**Carte 8**
Recto : Avant de tenter un détournement de `.htaccess`, quel prérequis dois-tu avoir confirmé sur la cible ?
Verso : Que le serveur est identifié comme Apache (et idéalement que `AllowOverride` est susceptible d'être actif). Pour une cible IIS, la technique équivalente vise `web.config`, pas `.htaccess`.

**Carte 9**
Recto : Pourquoi un échec de race condition après une seule tentative (upload + GET immédiat) n'est-il pas concluant ?
Verso : La fenêtre d'exploitation peut être de l'ordre de la milliseconde. Une seule tentative a une probabilité très faible de l'atteindre même si elle existe réellement — il faut un volume de requêtes nettement supérieur avant de conclure.

## Interpréter

**Carte 10**
Recto : Un fichier polyglotte EXIF est accepté là où un script brut était rejeté. Que cela prouve-t-il, et que cela ne prouve-t-il pas ?
Verso : Prouve que la validation de contenu ne porte que sur la structure/signature, pas sur les métadonnées. Ne prouve pas l'exécution : le fichier reste une image stockée inerte tant qu'aucun vecteur d'interprétation (configuration détournée, LFI) n'est démontré.

**Carte 11**
Recto : Une requête sur un fichier `.php` déposé renvoie son code source en clair plutôt qu'un résultat de commande. Est-ce un échec total de l'exploitation ?
Verso : Non. C'est une divulgation de code source — un impact réel mais distinct d'une RCE. Le handler d'exécution n'est simplement pas configuré sur cette extension/ce répertoire précis ; une extension alternative reste à tester.

**Carte 12**
Recto : Un `.htaccess` est accepté à l'upload mais n'a aucun effet observable sur le répertoire. Quelle cause structurelle (indépendante du contenu du fichier) faut-il envisager en premier ?
Verso : Que le serveur ignore les fichiers de configuration locaux dans ce répertoire (`AllowOverride None` sous Apache, ou équivalent IIS) — une cause indépendante du contenu exact du `.htaccess` testé.

## Exploiter

**Carte 13**
Recto : Un fichier polyglotte est accepté, mais aucune LFI n'est disponible ailleurs dans l'application. Quelle chaîne d'exploitation reste envisageable pour le rendre exécutable ?
Verso : Détourner la politique d'exécution du répertoire via un fichier de configuration (`.htaccess`/`web.config`) redéfinissant le handler pour l'extension du fichier polyglotte — à condition que le serveur prenne en compte ces fichiers de configuration locaux.

**Carte 14**
Recto : Dans une chaîne d'exploitation par détournement de `.htaccess`, quelles sont les deux étapes de dépôt distinctes et pourquoi sont-elles nécessaires l'une à l'autre ?
Verso : D'abord le dépôt du `.htaccess` redéfinissant le handler pour une extension triviale, puis le dépôt d'un second fichier avec cette extension contenant le payload. La seconde étape ne devient exploitable qu'après le succès de la première, qui change la politique d'interprétation du répertoire.

**Carte 15**
Recto : Pourquoi faut-il toujours distinguer, dans une chaîne d'exploitation d'upload, la « preuve de dépôt réussi » de la « preuve d'impact » ?
Verso : Un dépôt réussi démontre seulement qu'une couche de contrôle a été franchie, sans rien garantir sur le traitement serveur en aval. Seule la preuve d'impact (résultat de commande, script exécuté, fichier système lu) démontre que la chaîne complète aboutit réellement.

## Déboguer et transférer

**Carte 16**
Recto : Un fichier polyglotte EXIF qui fonctionnait sur une application précédente échoue sur la cible actuelle malgré une structure identique. Quelle hypothèse vérifier en priorité ?
Verso : Que l'application effectue une re-compression de l'image côté serveur (reconstruction pixel par pixel), qui détruit systématiquement les métadonnées EXIF — une contre-mesure plus robuste que la simple validation de structure testée précédemment.

**Carte 17**
Recto : Une technique d'extensions alternatives Apache (`.phtml`) a fonctionné sur une cible précédente. Face à une nouvelle cible IIS, quelle partie du raisonnement reste transférable, et laquelle doit changer entièrement ?
Verso : Le principe général (contourner une liste noire via des extensions historiquement interprétées) reste transférable. La famille d'extensions et le vecteur de configuration doivent changer entièrement : viser `.asa`/`.cer`/`.asax` et `web.config` plutôt que `.phtml` et `.htaccess`.

**Carte 18**
Recto : Une technique de null byte qui fonctionnait en environnement de test échoue systématiquement en conditions réelles. Quelle hypothèse précise vérifier avant d'abandonner la piste ?
Verso : La version de l'environnement d'exécution cible — le null byte n'est exploitable que sur des versions anciennes (PHP < 5.3.4). Un échec systématique sur une cible moderne est cohérent avec cette limite de version plutôt qu'avec une protection active spécifique.

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
- Chaîne d'exploitation incomplète.
- Diagnostic insuffisant.
- Difficulté à transférer les connaissances.

| Difficulté | Support à retravailler |
|---|---|
| Je ne comprends pas pourquoi la faille existe. | `cours.md` |
| Je ne sais pas quoi tester ensuite. | `exploitation.md` |
| Je connais le test, mais j'oublie la syntaxe. | `cheatsheet.md` |
| Je n'arrive pas à interpréter mes essais. | `exploitation.md`, sections 4 et 7 |
| Je reproduis un cas connu, mais pas une variante. | `cours.md`, puis nouveau scénario pratique |

Ne pas relire l'intégralité des notes après chaque erreur : revoir en priorité la partie responsable du blocage, puis retenter de répondre de mémoire.

### Révisions espacées

- Jour 0 : première récupération active.
- Jour 1 : révision des éléments difficiles.
- Jour 3 : nouvelle tentative sans notes.
- Jour 7 : révision des erreurs persistantes.
- Jour 14 : questions de transfert.
- Jour 30 : vérification globale de la maîtrise.

Ces intervalles sont indicatifs : les cartes échouées doivent être revues plus tôt que les cartes maîtrisées. Un calendrier fixe ne garantit pas, à lui seul, la mémorisation.
