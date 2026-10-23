# LFI / RFI / Path Traversal & Bypass d'Upload — Fiche de révision

Cette fiche doit être utilisée **sans consulter** le cours, la méthodologie ou la cheat sheet lors de la première tentative.

Pour chaque question : réponds à voix haute ou par écrit, puis compare ta réponse au corrigé (section dédiée, plus bas). Note ta réponse de 0 à 3 avec le barème fourni avant de passer à la question suivante.

---

## 1. Comprendre

Objectif : reconstruire le modèle mental de la vulnérabilité — pourquoi elle existe, ce qui distingue ses variantes, ce qu'elle permet réellement.

**Q1.** Quel défaut de conception permet à une Local File Inclusion (LFI) d'aller au-delà d'une simple lecture de fichier et de mener à une exécution de code ?

**Q2.** Pourquoi un Path Traversal confirmé en lecture (ex. contenu de `/etc/passwd` obtenu) ne démontre-t-il pas automatiquement une possibilité d'exécution de code ?

**Q3.** Quelle différence fondamentale existe entre une LFI et une RFI en termes de prérequis côté serveur ?

**Q4.** Pourquoi deux applications présentant toutes deux une LFI non filtrée peuvent-elles aboutir à des impacts très différents l'une de l'autre ?

**Q5.** Quel est le point précis où le comportement normal d'une fonctionnalité d'upload dévie pour devenir exploitable en RCE via chaining avec une LFI ?

---

## 2. Reconnaître

Objectif : identifier quand la vulnérabilité devient plausible à partir d'observations, sans sauter aux conclusions.

**Q6.** Tu observes qu'un paramètre `?page=accueil` affiche une page différente selon la valeur fournie, et que remplacer la valeur par un nom de page inexistant produit une erreur PHP exposant un chemin absolu local. Quels éléments rendent une vulnérabilité de manipulation de chemin plausible ici, et que faudrait-il encore vérifier ?

**Q7.** Une application de documentation propose `?doc=manual.pdf` pour télécharger un fichier. Un testeur remplace la valeur par un autre nom de fichier, toujours présent dans la liste des documents prévus, et observe que le fichier correspondant est bien renvoyé. Ce comportement suffit-il à conclure à une vulnérabilité ? Quelles observations supplémentaires seraient nécessaires ?

**Q8.** Un formulaire d'upload d'avatar renvoie le message « Type de fichier non autorisé » lorsqu'on tente d'envoyer un fichier `.exe`. Quelle hypothèse peux-tu formuler sur le mécanisme de validation, et quelle incertitude subsiste ?

**Q9.** Une application ne présente aucune différence de comportement entre une requête avec `?file=../../../../etc/passwd` et une requête avec une valeur légitime. Quelles explications alternatives restent possibles avant de conclure à l'absence de vulnérabilité ?

**Q10.** Tu remarques qu'une page affiche systématiquement le même contenu, quelle que soit la valeur fournie à un paramètre qui semble pourtant correspondre à un nom de fichier. Quelle conclusion serait prématurée, et quel mécanisme pourrait expliquer cette stabilité ?

---

## 3. Tester

Objectif : choisir, pour une hypothèse donnée, le test minimal pertinent — et savoir justifier pourquoi ce test-là plutôt qu'un autre.

**Q11.** Tu soupçonnes qu'un paramètre `?file=` est vulnérable à une traversée de répertoire, mais la séquence `../../../../etc/passwd` ne produit aucun changement visible. Quelle est ton hypothèse concernant ce résultat, quel test minimal effectuerais-tu ensuite, et quelle condition est nécessaire pour l'interpréter correctement ?

**Q12.** Une traversée de répertoire classique fonctionne (contenu de `/etc/passwd` retourné), mais tu ignores encore si le mécanisme sous-jacent est une inclusion dynamique ou une simple lecture de fichier. Quel test choisirais-tu pour trancher, et pourquoi ce test en particulier plutôt qu'une inclusion directe du fichier `.php` ciblé ?

**Q13.** Tu veux déterminer si le serveur autorise l'inclusion d'une ressource distante (RFI). Quel est le test minimal à effectuer, et quelle observation côté serveur de l'attaquant est plus fiable qu'une observation côté application cible pour interpréter un résultat négatif ?

**Q14.** Une fonctionnalité d'upload refuse un fichier `.php` avec un message « extension non autorisée ». Quel est le test minimal suivant pour déterminer si le filtre repose sur une liste noire plutôt qu'une liste blanche, sans encore tenter un contournement complet ?

**Q15.** Tu disposes d'une LFI confirmée en lecture mais ignores si `allow_url_include` est actif. Quels tests effectuerais-tu, dans quel ordre, et pourquoi cet ordre plutôt qu'un autre ?

---

## 4. Interpréter

Objectif : distinguer une preuve utile d'un signal ambigu ou trompeur, sans sombrer dans un doute systématique.

**Q16.** Une requête avec `php://filter/read=convert.base64-encode/resource=index.php` retourne une chaîne de caractères qui ressemble à du Base64, mais le décodage produit un texte illisible. Que peux-tu en conclure, et que resterait-il à vérifier ?

**Q17.** Un test de log poisoning via le `User-Agent` suivi d'une inclusion du journal Apache produit une erreur de type « permission denied ». Cette observation permet-elle d'écarter la LFI elle-même ? Que peux-tu réellement en conclure ?

**Q18.** Tu obtiens un code 500 générique en réponse à une valeur de traversée de répertoire. Ce résultat constitue-t-il une preuve de vulnérabilité ? Quelle autre explication est au moins aussi plausible ?

**Q19.** Un fichier uploadé avec une signature `GIF89a` passe la vérification `getimagesize()` côté serveur. Que cela permet-il de conclure sur l'exécutabilité du code PHP qu'il contient, et que resterait-il à démontrer ?

**Q20.** Deux tests consécutifs de log poisoning donnent des résultats différents (le premier échoue, le second réussit) sans qu'aucun paramètre n'ait changé côté testeur. Quelles hypothèses expliqueraient cette apparente contradiction ?

---

## 5. Exploiter

Objectif : reconstruire une chaîne d'exploitation cohérente, en explicitant les dépendances entre les étapes plutôt qu'en énumérant des techniques isolées.

**Q21.** Tu as confirmé une inclusion dynamique via `php://filter`, mais `allow_url_include` semble désactivé (RFI et `php://input` sans effet). Identifie les éléments d'une chaîne d'exploitation alternative que tu pourrais encore tenter, et explique la dépendance entre chaque étape.

**Q22.** Dans un scénario de chaining Upload + LFI, quelles sont les conditions qui doivent être réunies simultanément pour que l'exécution de code aboutisse, et que se passe-t-il si une seule d'entre elles manque ?

**Q23.** Tu disposes d'une LFI confirmée et d'une fonctionnalité d'upload qui accepte les fichiers `.phtml`. L'upload réussit mais aucune URL ou chemin n'est retourné dans la réponse. Peux-tu encore construire une chaîne d'exploitation complète ? Que faudrait-il trouver ?

**Q24.** Pourquoi le résultat d'une commande comme `id` est-il considéré comme une preuve plus forte que le simple fait qu'un wrapper `php://filter` retourne du Base64 ? Situe ces deux éléments dans les différents niveaux de preuve d'une exploitation LFI.

**Q25.** Une LFI confirmée permet d'inclure des fichiers situés dans `/var/log/`, mais pas ceux situés dans `/var/www/html/uploads/` (restriction de répertoire observée). Quel effet cela a-t-il sur une stratégie de chaining Upload + LFI, et quelle autre voie resterait exploitable ?

---

## 6. Déboguer et transférer

Objectif : diagnostiquer précisément un échec et distinguer ce qui reste transférable d'un cas à l'autre de ce qui ne l'est pas.

**Q26.** Un payload injecté via le `User-Agent` ne produit aucun résultat lors de l'inclusion du journal Apache. Quel maillon de la chaîne suspecterais-tu en premier, et quelle vérification minimale permettrait de le confirmer ?

**Q27.** Tu obtiens une exécution de commande réussie via `php://input` lors d'un premier test, mais le test échoue systématiquement lors d'une nouvelle tentative identique quelques minutes plus tard. Quelles hypothèses structurelles (au-delà d'une simple erreur de frappe) expliqueraient cette instabilité ?

**Q28.** Un fichier polyglotte `GIF89a` + PHP est correctement uploadé et son chemin est connu, mais son inclusion via la LFI retourne le contenu brut du fichier (signature et code PHP visibles en clair) sans exécution. Quelle cause probable identifies-tu, et quelle connaissance du cas général reste applicable ici ?

**Q29.** Tu as réussi une LFI → RCE sur une application Linux via log poisoning Apache. Tu rencontres maintenant une application similaire mais tournant sur Windows avec IIS. Quelles connaissances du cas initial restent transférables telles quelles, et lesquelles doivent être entièrement reconsidérées ?

**Q30.** Le null byte (`%00`) fonctionnait pour tronquer une extension ajoutée automatiquement par l'application lors d'un engagement précédent, mais échoue systématiquement sur la cible actuelle. Quelle hypothèse faut-il vérifier en premier avant d'abandonner cette technique ?

---

# Corrigé — Réponses attendues et raisonnement

## 1. Comprendre

**R1.** La cause racine est l'utilisation d'une fonction d'**inclusion dynamique** (`include()`/`require()` ou équivalent) sur une entrée contrôlée par l'utilisateur. Contrairement à une fonction de lecture statique (`file_get_contents()`, `readfile()`), `include()` **interprète** le fichier chargé comme du code PHP s'il en contient — c'est cette interprétation qui transforme un accès à un fichier en exécution de code. *Prématuré :* conclure qu'un paramètre de type chemin est forcément relié à `include()` sans l'avoir testé (voir section Tester).

**R2.** Parce que lire le contenu de `/etc/passwd` prouve seulement qu'un chemin arbitraire peut être **lu** — rien n'indique que le mécanisme sous-jacent est une inclusion dynamique plutôt qu'une fonction de lecture statique. Le passage de la lecture à l'exécution est un palier distinct, qui doit être vérifié séparément (typiquement via `php://filter` sur un fichier `.php`).

**R3.** La LFI exploite des fichiers **locaux** au serveur (aucune dépendance réseau sortante), alors que la RFI nécessite d'inclure une ressource **distante**, ce qui impose `allow_url_include = On` **et** `allow_url_fopen = On` — une configuration désactivée par défaut depuis PHP 5.2. La LFI a donc une surface de prérequis bien plus large et reste exploitable même quand la RFI est fermée.

**R4.** Parce que l'impact dépend de facteurs qui varient d'une application à l'autre : droits de lecture du compte applicatif sur les journaux ou fichiers de session, présence ou non d'une fonctionnalité d'upload combinable, activation de `allow_url_include`, version de PHP (pertinence du null byte), ou encore restrictions de répertoire sur la LFI elle-même. Deux LFI identiques en apparence peuvent donc aboutir, pour l'une, à une simple lecture, et pour l'autre, à une RCE complète.

**R5.** Le point de bascule se situe au moment où un fichier déposé par l'upload (même renommé, même dans un répertoire dédié) devient un **contenu injectable** réutilisable par une LFI existante. Tant que l'upload et le point d'inclusion dynamique sont évalués séparément, le risque reste sous-estimé ; c'est leur combinaison qui transforme un upload « anodin » et une LFI « en lecture seule » en chaîne RCE.

## 2. Reconnaître

**R6.** Éléments en faveur de la plausibilité : le paramètre influence visiblement le contenu affiché (donc sert bien à sélectionner un fichier), et l'erreur PHP expose un **chemin absolu local**, ce qui confirme qu'une fonction de fichier est appelée avec ce paramètre. *Reste à vérifier :* si une séquence de traversée (`../`) modifie effectivement le fichier résolu, et si le mécanisme est une inclusion dynamique ou une lecture statique. *Prématuré :* conclure à une LFI exploitable sans avoir testé la traversée elle-même.

**R7.** Non, ce comportement seul ne suffit pas : le fichier renvoyé appartenait déjà à la liste prévue, ce qui ne prouve aucune sortie du périmètre attendu. *Observations supplémentaires nécessaires :* tenter une valeur hors de cette liste (ex. un chemin de traversée vers un fichier système) et comparer avec le comportement de référence sur une valeur invalide anodine.

**R8.** Hypothèse plausible : une validation basée au moins en partie sur l'extension ou le type déclaré. *Incertitude :* on ignore si la validation porte sur une liste blanche stricte (robuste) ou une liste noire (potentiellement incomplète), et si elle vérifie aussi le contenu binaire réel (Magic Bytes). Un seul test négatif sur `.exe` ne permet pas de trancher.

**R9.** Plusieurs explications restent ouvertes avant de conclure à l'absence de vulnérabilité : le paramètre peut ne pas être utilisé dans une opération de fichier ; un filtre peut bloquer `../` en clair tout en laissant passer une variante encodée (`%2e%2e%2f`, `....//`) ; ou une normalisation robuste (`realpath()` + whitelist) peut être en place. *Prématuré :* conclure à l'absence de vulnérabilité après une seule variante testée.

**R10.** Conclusion prématurée : que le paramètre n'est pas du tout traité ou qu'aucun mécanisme de fichier n'est en jeu. Un mécanisme alternatif plausible : un système de template qui résout systématiquement le chemin à l'intérieur d'un répertoire fixe via une fonction de sécurisation (`basename()`, whitelist) — ce comportement stable ne signifie pas une absence totale de traitement du paramètre, seulement une neutralisation efficace à ce stade.

## 3. Tester

**R11.** Hypothèse : soit le paramètre n'est pas utilisé pour une opération de fichier, soit un filtre partiel (suppression non récursive de `../`, décodage unique) bloque la séquence brute. *Test minimal :* tester une variante de contournement une par une (`....//`, double encodage `%252e%252e%252f`), en gardant la même cible (`/etc/passwd`) pour isoler l'effet de la variante. *Condition nécessaire :* changer une seule variable à la fois pour pouvoir attribuer le résultat à la variante testée et non à un autre facteur.

**R12.** Test choisi : `php://filter/read=convert.base64-encode/resource=` sur un fichier `.php` connu de l'application. *Pourquoi ce test plutôt qu'une inclusion directe :* inclure directement un `.php` l'exécute au lieu de l'afficher — si le fichier ne produit pas d'effet visible ou génère une erreur, le résultat est ambigu. Le wrapper encode le contenu en Base64 avant affichage, évitant l'exécution et donnant une preuve interprétable sans ambiguïté (présence ou non d'une chaîne Base64 décodable).

**R13.** Test minimal : héberger un fichier texte inoffensif sur un serveur contrôlé par le testeur et pointer le paramètre vulnérable vers cette URL. *Observation plus fiable côté attaquant :* la réception effective d'une requête sortante sur le serveur hébergeant le fichier. Un résultat négatif côté cible peut avoir deux causes très différentes (configuration désactivée, ou pare-feu sortant bloquant la connexion) — seule l'absence de requête entrante côté attaquant permet de distinguer un blocage réseau d'un blocage de configuration.

**R14.** Test minimal : tester une **seule** extension alternative connue pour être parfois interprétée nativement (ex. `.phtml`) sans encore passer au Content-Type falsifié ni au polyglotte. Si cette extension passe, cela confirme une liste noire incomplète. *Ce qu'il ne faut pas encore faire :* multiplier plusieurs techniques de contournement différentes (extension + MIME + polyglotte) dans le même test, ce qui empêcherait d'attribuer le succès à une cause précise.

**R15.** Ordre recommandé : d'abord `php://input` (ne dépend que de `allow_url_include`, pas d'infrastructure externe), puis la RFI si `php://input` échoue ou pour confirmer par un second vecteur, puis le log/session poisoning (qui ne dépend pas de `allow_url_include` mais des droits de lecture). *Justification :* tester d'abord les vecteurs dont l'échec est le plus facile à interpréter (dépendance à un seul paramètre de configuration) avant des vecteurs dont l'échec peut avoir plusieurs causes (droits, chemin de journal erroné, rotation des logs).

## 4. Interpréter

**R16.** Conclusion possible : le wrapper semble fonctionner (une chaîne encodée est bien retournée), mais le décodage incorrect peut indiquer un fichier cible différent de celui attendu, un encodage partiellement appliqué par une couche intermédiaire, ou une erreur de copie de la chaîne. *À vérifier :* retester avec `resource=` pointant vers un fichier dont le contenu attendu est connu avec certitude (ex. un fichier créé par le testeur si possible), pour isoler la cause. *Prématuré :* conclure que le wrapper ne fonctionne pas du tout.

**R17.** Non, cela n'écarte pas la LFI : l'erreur « permission denied » indique seulement que le compte applicatif manque de **droits de lecture sur ce journal précis** — c'est une cause d'échec distincte de l'absence du mécanisme LFI lui-même, qui reste confirmé par ailleurs (si `php://filter` a déjà réussi). *Réellement conclu :* ce vecteur d'escalade précis est fermé ; d'autres vecteurs (session poisoning, wrappers) restent à tester.

**R18.** Non, un code 500 générique n'est pas une preuve : il peut provenir d'une erreur applicative totalement indépendante de l'opération de fichier (ex. une autre validation qui échoue). *Explication au moins aussi plausible :* une erreur de l'application non liée à l'inclusion. *Ce qui manque :* comparer ce résultat à la requête de référence (valeur légitime) et à une valeur invalide anodine, pour voir si le code 500 est spécifique à la séquence de traversée ou systématique.

**R19.** Cela confirme seulement que le fichier **passe la vérification de signature** — `getimagesize()` vérifie que les premiers octets sont parsables comme une image, pas l'absence de code PHP après cette signature. *Reste à démontrer :* que le fichier est effectivement interprété comme du PHP lorsqu'il est inclus via la LFI (étape distincte, qui nécessite un test d'inclusion séparé). *Prématuré :* conclure à une RCE sur la seule base de l'acceptation de l'upload.

**R20.** Hypothèses possibles : plusieurs instances applicatives derrière un load balancer (journaux non partagés entre instances, ou fichier temporaire propre à chaque instance), un système de rotation des logs ayant archivé l'entrée empoisonnée entre les deux tentatives, ou d'autres requêtes légitimes ayant « dilué » le payload dans le journal entre-temps. *Prématuré :* conclure que la technique de log poisoning est intrinsèquement non fiable sans avoir exploré ces causes structurelles.

## 5. Exploiter

**R21.** Chaîne alternative : (1) tester le log poisoning ou le session poisoning — ces vecteurs ne dépendent pas de `allow_url_include` mais des droits de lecture sur les journaux/sessions ; (2) si ces vecteurs échouent et qu'une fonctionnalité d'upload existe, tenter un chaining Upload + LFI (contournement du filtre d'upload, puis inclusion du fichier déposé). *Dépendance entre étapes :* chaque étape ne devient pertinente que si la précédente a échoué pour une raison identifiée (pas par substitution arbitraire) — le chaining upload n'est une voie logique que lorsque les vecteurs ne nécessitant pas d'upload ont été épuisés.

**R22.** Conditions à réunir simultanément : le fichier uploadé doit être **lisible** par le processus PHP ; son **chemin** doit être connu ou devinable ; la LFI ne doit **pas restreindre** l'accès au répertoire d'upload ; l'**extension finale stockée** ne doit pas empêcher l'exécution via `include()` ; et le répertoire d'upload ne doit pas avoir l'exécution PHP **désactivée** (`.htaccess` avec `php_flag engine off`). *Si une seule manque :* la chaîne échoue à l'étape correspondante (upload invisible, inclusion impossible, ou contenu brut renvoyé sans exécution) — ce n'est pas un échec global mais un maillon précis à diagnostiquer.

**R23.** Pas directement : sans chemin connu ou devinable, le vecteur LFI ne peut pas être construit vers ce fichier précis. *Ce qu'il faudrait trouver :* une fuite indirecte du chemin de stockage (une autre fonctionnalité exposant l'URL du fichier, comme une galerie ou un profil utilisateur) ou une convention de nommage prévisible observée sur d'autres uploads. Sans cela, le chaining reste bloqué côté information, pas côté technique.

**R24.** `php://filter` confirme uniquement le **mécanisme** (une inclusion dynamique est bien en jeu), ce qui reste une « preuve de vulnérabilité confirmée » mais pas encore un impact démontré. Le résultat d'une commande système constitue la « preuve d'impact » : il démontre que le mécanisme confirmé est effectivement exploitable jusqu'à l'exécution de code, le niveau de preuve le plus élevé de la chaîne (anomalie observée → mécanisme confirmé → impact démontré).

**R25.** Effet : la restriction de répertoire bloque spécifiquement l'inclusion des fichiers déposés par l'upload, rendant le chaining Upload + LFI non praticable **à travers ce point d'inclusion précis**, même si l'upload lui-même réussit. *Voie alternative :* chercher un autre point d'inclusion dynamique dans l'application qui ne présenterait pas cette même restriction, ou se rabattre sur les vecteurs qui n'impliquent pas le répertoire d'upload (log/session poisoning, wrappers, RFI) si l'un d'eux reste applicable.

## 6. Déboguer et transférer

**R26.** Maillon suspecté en premier : les **droits de lecture** du compte applicatif sur le journal ciblé, car c'est la cause d'échec la plus fréquente de cette technique. *Vérification minimale :* comparer le message d'erreur retourné par l'inclusion du journal à celui d'un fichier manifestement inexistant — un message de type « permission denied » confirme un problème de droits, tandis qu'un message « no such file » oriente plutôt vers un chemin de journal erroné (distribution ou serveur web différent de celui supposé).

**R27.** Hypothèses structurelles : une architecture avec plusieurs instances applicatives derrière un load balancer (le corps POST de `php://input` n'est traité que par l'instance ayant reçu la requête, sans état partagé nécessaire ici mais le comportement peut différer selon l'instance qui répond) ; ou une protection dynamique apparue entre les deux tentatives (WAF adaptatif, rate limiting déclenché après un premier succès suspect). *Connaissance du cas initial qui reste utile :* le mécanisme lui-même (`php://input` + `allow_url_include = On`) demeure valide, seule sa fiabilité d'exécution est en cause.

**R28.** Cause probable : soit le point d'inclusion utilisé n'est pas réellement un `include()`/`require()` sur ce chemin précis (fonction de lecture statique), soit l'exécution PHP est désactivée dans le répertoire d'upload (`.htaccess` avec `php_flag engine off`, ou configuration Nginx équivalente). *Connaissance transférable :* le principe du polyglotte lui-même (signature valide + code PHP après) reste correct — c'est la configuration du point de déclenchement qui est en cause, pas le fichier préparé.

**R29.** *Reste transférable :* le principe général de l'escalade (injecter un payload dans un journal via un champ contrôlé, puis l'inclure via la LFI) et la logique de diagnostic (distinguer droits insuffisants, chemin erroné, protection active). *À reconsidérer entièrement :* les chemins de fichiers cibles (`/etc/passwd` → `C:\Windows\win.ini`), le séparateur de répertoire (`/` → `\`), les chemins de journaux (`/var/log/apache2/access.log` n'a pas d'équivalent direct sous IIS, dont le mécanisme de journalisation diffère), et la pertinence de techniques spécifiques à PHP/Linux (le null byte, par exemple, reste lié à la version de PHP et non à l'OS).

**R30.** Hypothèse à vérifier en premier : la **version de PHP** de la cible actuelle. Le null byte n'est exploitable que sous PHP < 5.3.4 ; un échec systématique est cohérent avec une version plus récente, ce qui rend la technique inapplicable **par principe** et non par erreur de mise en œuvre — il ne sert à rien de réessayer la même technique sans vérifier cette condition au préalable.

### Barème d'auto-évaluation

- **0 — Bloqué :** impossible de fournir une réponse pertinente sans consulter les notes.
- **1 — Avec aide :** réponse partielle ou obtenue après consultation d'un indice.
- **2 — Autonome sur un cas connu :** réponse correcte et raisonnement cohérent dans un scénario familier.
- **3 — Transfert :** réponse correcte dans une situation modifiée, avec justification et interprétation des limites.

La note porte autant sur le raisonnement que sur la conclusion. Une réponse correcte obtenue par hasard, ou sans pouvoir justifier les conditions et les limites, ne doit pas être notée comme une maîtrise complète.

---

# Cartes de révision — LFI / RFI / Path Traversal & Bypass d'Upload

18 cartes réparties en six compétences (3 cartes chacune). Chaque carte est autonome : le recto se comprend sans consulter une autre carte, le verso tient en quelques lignes.

## Comprendre

**Carte 1**
Recto : Quelle est la cause racine qui transforme une simple fonction de lecture de fichier en risque d'exécution de code arbitraire (RCE) ?
Verso : L'utilisation d'`include()`/`require()` (inclusion dynamique) sur une entrée utilisateur non validée. Contrairement à `file_get_contents()` ou `readfile()`, ces fonctions interprètent le fichier inclus comme du code PHP s'il en contient, transformant une lecture en exécution.

**Carte 2**
Recto : Quelle condition serveur est indispensable pour qu'une RFI soit exploitable, et pourquoi cette condition est-elle rare en production moderne ?
Verso : `allow_url_include = On`, associé à `allow_url_fopen = On`, dans `php.ini`. Cette directive est désactivée par défaut depuis PHP 5.2 en raison de son risque critique, donc rarement active sur des serveurs à jour.

**Carte 3**
Recto : Pourquoi la validation côté client (JavaScript, attribut HTML `accept`) n'offre-t-elle aucune protection réelle contre un bypass d'upload ?
Verso : Elle s'exécute avant l'envoi de la requête HTTP. Un proxy d'interception permet de modifier librement le nom de fichier, le `Content-Type` et le contenu après cette validation — le serveur ne reçoit que la requête forgée.

## Reconnaître

**Carte 4**
Recto : Une erreur PHP affichée au client contient « Warning: include(/var/www/html/pages/...) ». Quel mécanisme cette erreur révèle-t-elle, indépendamment de toute exploitation réussie ?
Verso : Qu'une fonction d'inclusion dynamique (`include`/`require`) est utilisée avec un chemin absolu local exposé — un indice fort de point d'inclusion exploitable, mais pas encore une preuve de traversée réussie.

**Carte 5**
Recto : Un upload de fichier `.php` est refusé (« extension non autorisée »), mais un upload de `.phtml` est accepté. Que cela révèle-t-il sur le mécanisme de validation ?
Verso : Une validation par liste noire d'extensions, incomplète : elle énumère les extensions dangereuses connues (`.php`) sans couvrir toutes les variantes interprétées par le serveur (`.phtml`, `.php5`, etc.).

**Carte 6**
Recto : Une page affiche un code 404 personnalisé identique pour un fichier inexistant et pour une valeur contenant une séquence de traversée. Pourquoi ce comportement complique-t-il le diagnostic ?
Verso : Il masque la différence entre « fichier réellement inexistant » et « chemin bloqué par un filtre ». Il faut comparer plusieurs valeurs (légitime, invalide anodine, traversée) plutôt que de se fier au code de réponse seul.

## Tester

**Carte 7**
Recto : Quel test minimal permet de distinguer une LFI en simple lecture d'une LFI exploitant réellement `include()`/`require()` ?
Verso : Utiliser `php://filter/read=convert.base64-encode/resource=` sur un fichier `.php` connu de l'application : une chaîne Base64 décodable en code source confirme l'inclusion dynamique, sans déclencher l'exécution du fichier.

**Carte 8**
Recto : Pour tester une RFI, quelle observation côté serveur de l'attaquant est plus fiable qu'une observation côté application cible ?
Verso : La réception effective d'une requête sortante sur le serveur hébergeant le fichier distant — elle confirme ou infirme `allow_url_include`/`allow_url_fopen` indépendamment de ce que renvoie (ou non) l'application cible.

**Carte 9**
Recto : Avant de tenter un fichier polyglotte pour contourner une vérification d'upload, quels deux tests plus simples faut-il avoir essayés, et dans quel ordre ?
Verso : D'abord une extension alternative (liste noire), puis un `Content-Type` falsifié (vérification MIME déclarée). Ce sont des contournements plus simples ; le polyglotte ne devient pertinent que si le serveur vérifie réellement le contenu binaire (Magic Bytes).

## Interpréter

**Carte 10**
Recto : Un test de traversée de répertoire produit un code 500 générique. Que peux-tu en conclure sur la présence d'une vulnérabilité ?
Verso : Rien de définitif. Un 500 peut provenir d'une erreur applicative sans lien avec l'inclusion de fichier — il faut comparer avec une requête de référence et chercher un signal plus spécifique (contenu du fichier cible, message d'erreur mentionnant un chemin).

**Carte 11**
Recto : `getimagesize()` confirme qu'un fichier uploadé est un GIF valide. Est-ce une garantie que ce fichier ne contient pas de code PHP exécutable ?
Verso : Non. `getimagesize()` vérifie seulement que les premiers octets sont parsables comme une image, pas l'absence de code après la signature. Un fichier polyglotte passe ce test tout en restant exécutable via une inclusion ultérieure.

**Carte 12**
Recto : Une inclusion de journal (log poisoning) échoue avec une erreur « permission denied ». Cette observation permet-elle d'écarter la LFI comme vulnérabilité ?
Verso : Non. Elle indique seulement que le compte applicatif manque de droits de lecture sur ce journal précis — une cause d'échec distincte de l'absence de LFI, qui reste à tester via d'autres vecteurs (session poisoning, wrappers).

## Exploiter

**Carte 13**
Recto : Dans un chaining Upload + LFI, pourquoi un upload accepté avec un chemin retourné dans la réponse n'est-il pas encore une preuve d'exploitation réussie ?
Verso : Il reste à vérifier que le fichier est lisible par le processus PHP et que le répertoire de destination n'a pas l'exécution PHP désactivée (`.htaccess` avec `php_flag engine off`) — sinon l'inclusion échoue ou ne renvoie que du contenu brut.

**Carte 14**
Recto : Pourquoi le résultat d'une commande système (ex. sortie de `id`) constitue-t-il un niveau de preuve supérieur à une chaîne Base64 retournée par `php://filter` ?
Verso : Le Base64 confirme seulement le mécanisme (inclusion dynamique exploitable). Le résultat de commande démontre l'impact réel : une exécution de code arbitraire effective, pas seulement la possibilité théorique.

**Carte 15**
Recto : `allow_url_include` est désactivé et le compte applicatif n'a pas les droits de lecture sur les journaux système. Quelle voie d'exploitation reste encore disponible si une fonctionnalité d'upload existe ?
Verso : Le chaining Upload + LFI : déposer un fichier polyglotte ou à extension alternative via l'upload, puis l'inclure via la LFI. Cette voie ne dépend ni de `allow_url_include` ni des droits sur les journaux.

## Déboguer et transférer

**Carte 16**
Recto : Un fichier polyglotte uploadé et inclus via la LFI renvoie son contenu brut (signature et code PHP visibles) au lieu d'être exécuté. Quelle cause faut-il vérifier en priorité ?
Verso : Que le point d'inclusion utilisé réalise bien un `include()`/`require()` réel et non une fonction de lecture statique, et que l'exécution PHP n'est pas désactivée dans le répertoire d'upload (`.htaccess` avec `php_flag engine off`).

**Carte 17**
Recto : Le null byte (`%00`) fonctionnait sur une cible précédente mais échoue sur la cible actuelle. Quelle connaissance reste transférable, et quelle hypothèse faut-il réviser ?
Verso : Le principe de troncature après un caractère spécial reste valide conceptuellement, mais le null byte n'est exploitable que sous PHP < 5.3.4 — il faut vérifier la version PHP de la nouvelle cible plutôt que de réessayer la même technique.

**Carte 18**
Recto : Deux tentatives identiques de log poisoning donnent des résultats différents (succès puis échec) sans changement côté testeur. Quelle piste faut-il explorer avant de conclure à une technique instable ?
Verso : La présence de plusieurs instances applicatives derrière un load balancer (journaux non partagés) ou une protection dynamique (WAF adaptatif, rate limiting) — répéter le test à intervalle court et chercher des indices d'infrastructure multi-instance.

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
