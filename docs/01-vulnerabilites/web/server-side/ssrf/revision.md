# Fiche de révision active — SSRF (Server-Side Request Forgery)

> **Mode d'emploi — Partie 1**
> Répondez à toutes les questions ci-dessous **sans consulter** `cours.md`, `exploitation.md` ou `cheatsheet.md`, et sans revenir en arrière une fois la lecture de la question commencée. Notez vos réponses avant de passer au corrigé. Ce n'est qu'après avoir répondu à l'ensemble des 30 questions que vous devez ouvrir la section « Corrigé ». Travailler avec les sources ouvertes fausse l'auto-évaluation et prive l'entraînement de son intérêt.

---

## 1. Comprendre

**Q1.** Quelle relation de confiance implicite le SSRF exploite-t-il fondamentalement ? Formulez en une phrase pourquoi une requête provenant d'une origine réseau donnée (locale, interne) ne devrait jamais être confondue avec une authentification.

**Q2.** Expliquez pourquoi un modèle de sécurité périmétrique de type « château fort » (tout ce qui est interne est digne de confiance, seul le périmètre externe est défendu) est structurellement mis en échec par le SSRF, et en quoi le serveur applicatif devient littéralement un « proxy involontaire » de l'attaquant.

**Q3.** Un service d'administration local répond sans authentification sur `127.0.0.1`. Expliquez pourquoi un reverse-proxy ou un WAF positionné en amont de l'application n'intercepte jamais ce trafic, même s'il filtre correctement tout le trafic entrant depuis Internet.

**Q4.** Un SSRF aveugle (Blind SSRF) ne restitue jamais le contenu de la réponse distante à l'attaquant. Expliquez pourquoi cette absence de visibilité ne signifie pas une absence d'impact exploitable, en citant au moins deux formes d'impact qui ne nécessitent pas de lire la réponse.

**Q5.** Pourquoi la validation d'une URL fournie par l'utilisateur doit-elle impérativement s'effectuer après résolution et normalisation complètes, avec la même bibliothèque de parsing que celle utilisée pour établir la connexion réelle, plutôt que par une comparaison de sous-chaîne ou une regex sur la chaîne brute ?

---

## 2. Reconnaître

**Q6.** Au-delà d'une fonctionnalité explicite de « récupération d'URL » visible dans l'interface, citez trois surfaces distinctes où un SSRF peut se dissimuler, et pour chacune expliquez pourquoi elle échappe fréquemment à un audit limité aux fonctionnalités évidentes.

**Q7.** Vous observez qu'une URL contenant littéralement `localhost` est rejetée, mais que son équivalent en notation décimale (`2130706433`) ne l'est pas. Que pouvez-vous en déduire sur la nature du filtre en place, et pourquoi ce filtre ne doit pas être qualifié de « liste blanche » sur cette seule observation ?

**Q8.** Vous recevez une interaction DNS sur votre domaine de callback, mais aucune requête HTTP ne suit. Quelle hypothèse ce signal, pris isolément, permet-il de formuler sur le comportement côté serveur, et pourquoi ce signal reste-t-il néanmoins un point d'entrée à approfondir plutôt qu'à écarter ?

**Q9.** L'application renvoie une erreur générique strictement identique, que la destination interne testée soit active ou non, et quel que soit le port ciblé. Quelles sont les deux hypothèses distinctes à distinguer avant de conclure quoi que ce soit sur la présence d'un SSRF ?

**Q10.** Un paramètre `redirectUrl` renvoie un code `302` suivi d'un en-tête `Location` vers une destination différente du paramètre fourni. Quelle famille de vecteurs SSRF cette observation doit-elle immédiatement vous faire envisager, indépendamment de tout filtre déjà identifié sur ce paramètre ?

---

## 3. Tester

**Q11.** Décrivez la séquence minimale de tests permettant de détecter un SSRF contre la boucle locale, en précisant pourquoi un échec sur un seul chemin testé (`/admin`) ne permet pas de conclure à l'absence de service local exploitable.

**Q12.** Décrivez la méthodologie rigoureuse de test d'un contournement de liste noire par notations alternatives d'adresse IP, en précisant pourquoi tester une seule notation ne suffit jamais à qualifier le filtre comme robuste ou comme contournable.

**Q13.** Les quatre techniques de contournement de liste blanche (`@`, `#`, sous-domaine inversé, double encodage) ciblent chacune une ambiguïté de parsing différente. Pourquoi faut-il les tester indépendamment les unes des autres, et que risque-t-on à s'arrêter après l'échec de la première testée ?

**Q14.** Décrivez la démarche de test d'un Open Redirect chaîné vers une ressource interne, en précisant la condition côté client HTTP serveur qui doit être vérifiée pour que cette technique ait une chance de fonctionner.

**Q15.** Décrivez la méthodologie de détection d'un Blind SSRF par OAST, en précisant la différence de signal entre une interaction DNS seule et une interaction DNS suivie d'une requête HTTP complète, et ce que chacune permet de conclure.

---

## 4. Interpréter

**Q16.** Un test direct sur `http://localhost/admin` produit une erreur strictement identique à celle obtenue pour un chemin manifestement inexistant. Que pouvez-vous en déduire, et quelle conclusion serait prématurée à ce stade concernant l'existence d'un service local exploitable ?

**Q17.** Les notations décimale, octale, abrégée et hexadécimale de `127.0.0.1` échouent toutes de façon identique contre un filtre. Que pouvez-vous raisonnablement en déduire sur le fonctionnement probable de ce filtre, et quelle technique de contournement resterait pertinente à tester avant de documenter une protection robuste ?

**Q18.** Le bypass par caractère `@` échoue contre une liste blanche, mais vous n'avez pas encore testé les trois autres techniques (`#`, sous-domaine inversé, double encodage). Pourquoi l'échec du premier test ne permet-il aucune conclusion sur les trois autres ?

**Q19.** Un scan aveugle sur une plage d'adresses internes ne produit aucune différence de temps de réponse ni de code HTTP, quelle que soit l'adresse testée. Citez deux explications distinctes à cette absence de différence, et la vérification qui permettrait de les distinguer.

**Q20.** Une requête contenant un domaine de callback OAST dans l'en-tête `Referer` ne produit aucune interaction après plusieurs minutes d'attente, alors que le même domaine inséré dans un paramètre d'URL classique produit une interaction immédiate. Comment interprétez-vous cette différence entre les deux surfaces testées ?

---

## 5. Exploiter

**Q21.** Construisez la chaîne de raisonnement complète permettant d'exfiltrer des identifiants IAM temporaires d'une instance cloud via SSRF, depuis la détection initiale jusqu'à la preuve d'impact, en précisant l'adresse et le chemin spécifiques ciblés.

**Q22.** Décrivez le mécanisme complet d'un contournement par DNS Rebinding, en expliquant précisément à quel moment du cycle de vie de la requête (validation vs connexion réelle) le changement de résolution DNS doit intervenir pour être efficace, et pourquoi un TTL court est nécessaire à l'attaquant.

**Q23.** Construisez la chaîne d'exploitation complète d'un Open Redirect chaîné vers une ressource interne, en identifiant précisément à quel moment la liste blanche est validée et à quel moment elle cesse de s'appliquer.

**Q24.** Décrivez comment une vulnérabilité XXE peut être exploitée comme vecteur SSRF à part entière, y compris dans un contexte où l'application n'expose aucune fonctionnalité explicite de récupération d'URL, et quel type de document peut servir de point d'entrée au-delà d'un simple fichier XML.

**Q25.** Vous confirmez un SSRF aveugle par interaction HTTP complète sur votre domaine OAST, sans jamais obtenir le moindre contenu de réponse. Décrivez deux pistes d'exploitation distinctes qui restent possibles malgré cette absence totale de visibilité, et ce que chacune permettrait de démontrer comme preuve d'impact.

---

## 6. Déboguer et transférer

**Q26.** Un test direct de `http://localhost/admin` échoue sans résultat exploitable. Avant de conclure à l'absence de SSRF contre la boucle locale, quelles variations systématiques (au-delà du simple changement de notation d'adresse) devez-vous envisager ?

**Q27.** Vous avez testé les quatre techniques de contournement de liste blanche et elles échouent toutes de façon cohérente. Quelles sont les deux hypothèses distinctes à envisager sur la robustesse réelle de ce filtre, et quelle direction de test reste encore ouverte avant de le documenter comme robuste ?

**Q28.** Aucune interaction OAST n'est reçue après plusieurs minutes sur un point d'entrée testé. Citez au moins deux causes distinctes et non mutuellement exclusives, et précisez laquelle devrait vous conduire à tester d'autres points d'entrée plutôt qu'à conclure sur celui-ci.

**Q29.** Le principe « une origine réseau n'est jamais une authentification », central au raisonnement SSRF, peut se transférer à d'autres contextes de sécurité applicative. Formulez ce principe de façon suffisamment générale pour l'appliquer à une classe de vulnérabilité différente du SSRF, avec un exemple concret où sa violation produirait une faille exploitable.

**Q30.** Le raisonnement SSRF distingue systématiquement la question de la visibilité du résultat (réponse visible vs aveugle) de la question de la destination atteignable (locale, interne, externe). Transférez ce principe de séparation à l'audit d'une autre vulnérabilité « aveugle » par nature (au choix, hors SSRF) : comment cette distinction orienterait-elle votre choix de technique de détection dans ce nouveau contexte ?

---

## Corrigé — Réponses attendues et raisonnement

**R1.** Le SSRF exploite la confiance implicite accordée à l'origine réseau d'une requête (locale, interne à l'organisation) comme si cette origine constituait en elle-même une preuve de légitimité. Une requête provenant de `127.0.0.1` ou d'une plage interne ne devrait jamais être traitée comme authentifiée car dès qu'une fonctionnalité applicative permet d'émettre une requête arbitraire au nom du serveur, cette origine peut être falsifiée par quiconque détourne cette fonctionnalité — l'origine réseau n'est qu'une information de routage, jamais une preuve d'identité.

**R2.** Le modèle « château fort » repose sur l'hypothèse que seul le périmètre externe nécessite une défense active, tout composant interne étant implicitement digne de confiance. Le SSRF contourne cette défense sans jamais la franchir directement : l'application web publique, positionnée à la frontière du périmètre et censée en être le point de défense, devient elle-même l'instrument qui relaie la requête de l'attaquant vers l'intérieur — elle agit comme si elle se trouvait physiquement à l'intérieur du réseau de confiance, rendant inopérante toute défense reposant uniquement sur la position réseau.

**R3.** Le reverse-proxy ou le WAF n'inspecte que le trafic entrant depuis l'extérieur vers l'application ; une requête émise par le serveur applicatif lui-même, à destination de sa propre interface locale (`127.0.0.1`), constitue un trafic interne au serveur qui ne transite jamais physiquement par ce composant de filtrage positionné en amont — ce composant est structurellement absent du chemin réseau emprunté par une requête loopback.

**R4.** L'absence de visibilité sur le contenu de la réponse n'empêche pas l'exécution effective de la requête côté serveur, qui reste exploitable pour : (1) déclencher des actions destructrices ou des effets de bord sur le service interne ciblé, sans nécessiter de lire sa réponse pour confirmer l'effet ; (2) atteindre potentiellement une exécution de code à distance si le service backend atteint est lui-même vulnérable, indépendamment de toute visibilité sur la sortie — l'impact dépend de ce qui est atteint et exécuté, pas de ce qui est renvoyé à l'attaquant.

**R5.** Un filtre appliqué sur la chaîne brute (comparaison de sous-chaîne, regex) peut être trompé par toute forme équivalente non prévue par ses motifs (notation alternative d'IP, encodage, casse, ambiguïté de parsing `@`/`#`/sous-domaine). Seule une validation effectuée après résolution et normalisation complètes — avec la même bibliothèque que celle qui établira effectivement la connexion — garantit que la valeur comparée au filtre est exactement celle qui sera utilisée pour la connexion réelle, éliminant par construction tout décalage entre ce qui est validé et ce qui est exécuté.

**R6.** Trois surfaces possibles parmi : (1) les URLs partielles, où seul un fragment (sous-domaine, chemin, identifiant) est contrôlé par l'utilisateur et concaténé côté serveur à une structure fixe — négligée car le contrôle apparaît limité ; (2) les points d'entrée XML/SVG/documents bureautiques dont le parseur résout les entités externes (XXE), négligés car hors du périmètre évident d'une « fonctionnalité réseau » ; (3) l'en-tête `Referer`, librement falsifiable, suivi automatiquement par des scripts d'analyse d'audience côté serveur, négligé car l'attaquant n'interagit jamais directement avec une fonctionnalité de récupération d'URL visible.

**R7.** Vous pouvez en déduire que le filtre compare probablement la chaîne fournie à une liste de motifs littéraux (liste noire) sans normaliser ni résoudre l'adresse réellement visée — c'est précisément la définition d'un filtre par liste noire incomplet. Il ne faut pas pour autant le qualifier de liste blanche sur cette seule observation : une liste blanche valide la présence d'un hôte *autorisé*, tandis qu'ici le filtre bloque un motif *interdit* ; les deux familles de filtres ciblent des défauts différents et appellent des familles de contournement distinctes.

**R8.** Ce signal isolé permet de formuler l'hypothèse que le serveur effectue une validation côté serveur qui résout le nom de domaine (par exemple pour vérifier qu'il ne pointe pas vers une IP privée) sans jamais établir la connexion réseau complète. Ce signal reste un point d'entrée à approfondir plutôt qu'à écarter car il révèle une faille potentielle de type TOCTOU : si la résolution DNS utilisée pour la validation diffère de celle utilisée au moment de la connexion réelle, un DNS rebinding pourrait exploiter ce décalage temporel.

**R9.** Deux hypothèses distinctes : (1) un filtre bloque effectivement toute destination interne, produisant une erreur générique uniforme indépendamment de l'activité réelle de la cible ; (2) le traitement de l'application est asynchrone (réponse immédiate générique indépendante du résultat réel du traitement différé), masquant toute différence de comportement sur les canaux habituels. Ces deux hypothèses ne peuvent être distinguées sans test complémentaire — notamment un test OAST, seul capable de révéler une exécution effective dans les deux cas.

**R10.** Cette observation doit immédiatement faire envisager un **Open Redirect chaîné** : si ce comportement de redirection est présent sur un domaine par ailleurs accepté par un filtre de liste blanche en amont (sur une autre fonctionnalité de l'application), et que le client HTTP côté serveur suit automatiquement les redirections 3xx sans revalidation, cette redirection ouverte peut être détournée pour atteindre une ressource interne hors du périmètre de validation initial.

**R11.** Séquence minimale : (1) établir une référence avec l'URL légitime du paramètre identifié ; (2) remplacer la valeur par `http://localhost/admin` ou `http://127.0.0.1/admin` ; (3) comparer le résultat à la référence (contenu, code de réponse). Un échec sur ce seul chemin ne permet pas de conclure à l'absence de service local exploitable car l'absence de résultat sur un chemin précis peut simplement signifier qu'aucun service n'écoute sur ce chemin particulier, sans rien démontrer sur l'existence d'autres chemins ou ports de services internes — il faut élargir systématiquement aux autres chemins/ports courants avant toute conclusion.

**R12.** Méthodologie : tester chaque notation alternative (décimale, octale, abrégée, hexadécimale, encodage URL des séparateurs, variation de casse) individuellement, en conservant le même chemin cible pour chaque test, afin de pouvoir attribuer sans ambiguïté un succès ou un échec à la notation précise testée. Une seule notation testée ne suffit jamais à qualifier le filtre car un filtre bloquant une représentation littérale spécifique ne bloque pas nécessairement les représentations équivalentes non couvertes par sa liste de motifs — chaque notation constitue un test indépendant.

**R13.** Chacune des quatre techniques exploite une ambiguïté de parsing structurellement différente : la sémantique des identifiants d'URL pour `@`, la sémantique du fragment (non transmis au serveur) pour `#`, la hiérarchie de résolution DNS de droite à gauche pour le sous-domaine inversé, et le décalage entre couches de décodage pour le double encodage. L'échec d'une seule de ces techniques ne renseigne en rien sur les trois autres, puisqu'un même filtre peut neutraliser un mécanisme de parsing précis tout en restant vulnérable aux trois autres — s'arrêter après le premier échec risquerait de documenter à tort un filtre comme robuste alors qu'un autre vecteur de la même famille reste exploitable.

**R14.** Démarche : (1) identifier une fonctionnalité de redirection ouverte (paramètre `path`/`next`/`redirect` non validé) sur un domaine par ailleurs accepté par le filtre de liste blanche ; (2) construire une URL vers ce domaine de confiance intégrant, dans son paramètre de redirection, l'adresse interne réellement visée ; (3) soumettre cette URL au point d'entrée SSRF et observer si le contenu de la ressource interne apparaît dans la réponse finale. La condition côté client HTTP à vérifier : que ce client suive automatiquement les redirections HTTP 3xx sans revalider la destination finale selon la même politique de liste blanche que l'URL initiale — sans cette condition, la technique échoue par construction.

**R15.** Méthodologie : injecter un domaine de callback unique (type Burp Collaborator/Interactsh) dans chaque point d'entrée suspecté, y compris les surfaces cachées (`Referer`, fragments d'URL), puis consulter le service d'écoute externe. Différence de signal : une interaction DNS seule confirme uniquement une résolution de nom côté serveur, signal plus faible qui peut correspondre à une simple validation sans connexion réelle ; une interaction DNS suivie d'une requête HTTP complète confirme une connexion TCP et l'émission effective de la requête SSRF — preuve irréfutable d'exécution côté serveur, indépendamment de tout contenu de réponse visible.

**R16.** Vous pouvez en déduire que ce test particulier (ce chemin précis) ne révèle rien de concluant — l'erreur identique à un chemin manifestement inexistant suggère simplement qu'aucun service n'écoute à ce chemin exact, sans indiquer si un filtre bloque spécifiquement `localhost` ou si aucun service local n'existe du tout. Il serait prématuré de conclure à l'absence totale de service local exploitable : d'autres chemins (`/status`, `/health`, d'autres ports) n'ont pas été testés, et aucune notation alternative n'a encore été essayée pour écarter l'hypothèse d'un filtre actif.

**R17.** Vous pouvez raisonnablement en déduire que le filtre résout probablement le DNS et compare l'adresse IP résolue aux plages bloquées, plutôt que de se contenter d'une comparaison littérale sur la chaîne brute — une protection plus robuste que celle visée par ces quatre notations. La technique restant pertinente avant de documenter une protection robuste : le DNS Rebinding, qui exploite un décalage temporel entre la résolution utilisée pour la validation et celle utilisée au moment de la connexion réelle, contournant une vérification d'IP résolue si la résolution n'est pas fixée pour toute la durée de la connexion.

**R18.** Chacune des quatre techniques cible un mécanisme de parsing structurellement distinct (identifiants, fragment, hiérarchie DNS, décodage) et un filtre peut neutraliser l'un de ces mécanismes sans être protégé contre les trois autres — par exemple, un parseur qui extrait correctement le hostname avant le `@` peut rester vulnérable à une construction en sous-domaine inversé, mécanisme totalement différent. Conclure sur les trois techniques non testées à partir de l'échec de la première reviendrait à généraliser un résultat obtenu sur un vecteur précis à des vecteurs dont le mécanisme sous-jacent n'a aucun rapport.

**R19.** Deux explications distinctes : (1) aucun service actif n'existe aux adresses de la plage réellement testée (l'adressage réel du réseau interne de la cible est inconnu de l'auditeur externe) ; (2) un filtrage réseau en sortie uniforme masque toute différence de comportement observable depuis l'extérieur, indépendamment de l'activité réelle des services internes. La vérification permettant de les distinguer : comparer le comportement avec au moins une adresse de référence connue comme active par ailleurs dans l'audit — si même cette adresse connue ne produit aucune différence mesurable, l'hypothèse du filtrage réseau uniforme devient la plus probable.

**R20.** Cette différence suggère qu'aucun composant d'analyse d'audience côté serveur ne traite automatiquement le contenu de l'en-tête `Referer` sur cette application précise — ou, si un tel composant existe, qu'il ne suit pas automatiquement l'URL qu'il contient sans validation préalable. Le succès sur le paramètre d'URL classique confirme que le SSRF est bien réel et que le canal OAST fonctionne correctement en général ; l'échec spécifique sur `Referer` documente donc l'absence (ou la robustesse) de cette surface cachée précise, sans remettre en cause la vulnérabilité confirmée par ailleurs.

**R21.** Chaîne complète : (1) détecter un point d'entrée SSRF confirmé (loopback, réseau interne, ou surface cachée) ; (2) cibler l'adresse de métadonnées d'instance cloud `169.254.169.254` (plage link-local) avec le chemin `/latest/meta-data/` pour confirmer l'accès à la surface de métadonnées ; (3) affiner le chemin vers `/latest/meta-data/iam/security-credentials/` pour obtenir le nom du rôle IAM attaché à l'instance ; (4) lire le contenu retourné, qui contient les identifiants temporaires du rôle (clé d'accès, clé secrète, jeton de session) ; (5) documenter la preuve d'impact par la lecture effective de ces identifiants, éventuellement confirmée par leur utilisation sur un appel API légitime dans les limites autorisées.

**R22.** Le changement de résolution DNS doit intervenir strictement entre le moment où le serveur valide la destination (résolution DNS initiale, qui doit pointer vers une IP publique inoffensive pour passer cette validation) et le moment où il établit effectivement la connexion réseau pour émettre la requête (seconde résolution, qui doit alors pointer vers l'IP interne ciblée). Un TTL très court (de l'ordre de la seconde) est nécessaire pour que le cache DNS côté serveur expire rapidement entre ces deux moments, garantissant que la seconde résolution interroge à nouveau le serveur DNS de l'attaquant — qui peut alors renvoyer une réponse différente de la première.

**R23.** La liste blanche est validée une seule fois, au moment où le serveur reçoit et vérifie l'URL initiale fournie par l'attaquant (le domaine de confiance y figure, donc elle passe). Elle cesse de s'appliquer dès que le serveur, ayant validé cette URL initiale, exécute la requête vers ce domaine de confiance et que celui-ci répond par une redirection HTTP 302 vers l'adresse interne réellement visée : si le client HTTP suit cette redirection automatiquement, aucune revalidation n'intervient sur cette nouvelle destination, qui n'a jamais été soumise au filtre de liste blanche — la chaîne complète va donc de la validation initiale (sur l'URL de confiance) à l'exécution finale (sur l'URL interne, jamais validée).

**R24.** Un parseur XML configuré pour résoudre les entités externes peut être détourné en définissant une entité (`<!ENTITY xxe SYSTEM "http://...">`) pointant vers une URL interne arbitraire ; lors du traitement du document, le parseur résout cette entité en émettant lui-même une requête HTTP vers cette URL, transformant la vulnérabilité XXE en vecteur SSRF à part entière, sans qu'aucune fonctionnalité explicite de « récupération d'URL » ne soit exposée à l'utilisateur. Au-delà d'un simple fichier `.xml`, tout format bureautique construit sur XML peut servir de point d'entrée — notamment les documents `.docx`, `.xlsx`, ou les fichiers SVG, dès lors que leur parseur résout les entités externes.

**R25.** Deux pistes distinctes : (1) un scan/sweep du réseau interne en aveugle, mesurant des différences de code HTTP ou de temps de réponse entre adresses testées (timeout sur une IP inactive vs réponse rapide sur une IP active), permettant une cartographie partielle du réseau interne sans jamais lire de contenu ; (2) le déclenchement d'une action destructrice ou d'un effet de bord sur le service interne identifié, confirmé par un canal indépendant de la réponse HTTP immédiate (dans les limites strictement autorisées du test), ce qui démontre un impact effectif sans nécessiter de lecture directe de la réponse. Une troisième piste (hors périmètre détaillé mais mentionnée) : l'attaque de la bibliothèque cliente HTTP elle-même via une CVE connue, pouvant transformer un SSRF aveugle anodin en exécution de code à distance.

**R26.** Variations à envisager : tester d'autres chemins courants de services internes (`/status`, `/health`, interfaces d'administration alternatives) au-delà du seul `/admin` supposé ; tester d'autres ports usuels de services internes (`8080`, `8443`, `9200`, `6379`, `27017`, `5432` selon le cheatsheet) en plus du port par défaut ; et seulement ensuite, si ces variations échouent également, tester les notations alternatives d'adresse pour écarter l'hypothèse d'un filtre actif plutôt que d'une simple absence de service au chemin/port testés initialement.

**R27.** Deux hypothèses distinctes : (1) le filtre analyse réellement la structure de l'URL de façon robuste (extraction du hostname canonique plutôt qu'une comparaison de sous-chaîne), neutralisant par construction l'ensemble de ces quatre techniques précises ; (2) le client HTTP côté serveur parse l'URL différemment de l'hypothèse testée, de sorte que les payloads construits n'atteignent en réalité jamais la destination visée, indépendamment de la robustesse réelle du filtre. Direction de test restant ouverte : vérifier le comportement de parsing réel du client HTTP (messages d'erreur révélant la structure interprétée, ou test d'une URL légitime avec chaque caractère spécial isolément pour observer son traitement de référence) avant de documenter la protection comme définitivement robuste.

**R28.** Deux causes distinctes : (1) une restriction réseau sortante complète (DNS et HTTP) côté serveur empêche toute interaction, qu'il s'agisse de ce point d'entrée précis ou de n'importe quel autre de l'application — cause qui devrait conduire à tester systématiquement d'autres points d'entrée (y compris les surfaces cachées) avant de conclure, car un blocage réseau général affecterait également les autres vecteurs ; (2) ce point d'entrée précis n'initie en réalité aucune requête sortante à partir de cette valeur (mauvaise hypothèse sur ce paramètre spécifique) — cause spécifique à ce point d'entrée, qui ne remet pas en cause la possibilité d'un SSRF ailleurs dans l'application.

**R29.** Formulation générale : ne jamais traiter une caractéristique de contexte ou d'origine (adresse réseau, canal de transmission, position dans une architecture) comme une preuve d'identité ou d'autorisation implicite, sans vérification explicite indépendante de ce contexte. Exemple de transfert possible (plusieurs réponses acceptées) : une API interne qui fait confiance à un en-tête `X-Internal-Request: true` sous prétexte qu'il n'est censé être positionné que par un composant interne de confiance est vulnérable dès qu'un attaquant externe peut forger cet en-tête lui-même — l'en-tête, comme l'origine réseau en SSRF, n'est qu'une donnée manipulable, jamais une preuve d'authentification en soi.

**R30.** Le principe de séparation signifie qu'il faut d'abord déterminer, indépendamment de la technique d'exploitation elle-même, si un canal de confirmation visible existe pour cette vulnérabilité précise, avant de choisir la famille de techniques de détection à appliquer. Exemple de transfert (plusieurs réponses acceptées, l'important étant la cohérence) : pour une injection de commande OS aveugle, la même séparation s'applique — déterminer d'abord si la sortie de la commande est restituée dans la réponse (cas avec réponse visible, exploitation directe) ou si elle ne l'est jamais (cas aveugle, nécessitant un canal hors bande comme une requête DNS sortante déclenchée par la commande injectée, ou une mesure de délai via une commande `sleep` injectée) — la nature de la cible (commande OS vs requête réseau) change, mais la démarche de diagnostic (chercher d'abord un canal visible, basculer sur un canal hors bande seulement après confirmation de son absence) reste transférable telle quelle.

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
Recto : Quelle relation de confiance implicite le SSRF exploite-t-il fondamentalement ?
Verso : La confiance accordée à l'origine réseau d'une requête (locale, interne) comme si elle constituait une preuve d'authentification.

**Carte 2**
Recto : Pourquoi un WAF/reverse-proxy ne bloque-t-il jamais un SSRF ciblant `127.0.0.1` ?
Verso : Une requête loopback émise par le serveur vers lui-même ne transite jamais par ce composant de filtrage positionné en amont du trafic entrant.

**Carte 3**
Recto : Pourquoi un Blind SSRF reste-t-il exploitable sans aucune visibilité sur la réponse ?
Verso : L'exécution côté serveur reste garantie — exploitable pour des effets de bord destructeurs ou une RCE, indépendamment de toute lecture de la réponse.

### Reconnaître

**Carte 4**
Recto : Citez trois surfaces SSRF cachées au-delà d'une fonctionnalité explicite de récupération d'URL.
Verso : Les URLs partielles concaténées côté serveur, les parseurs XML/XXE, et l'en-tête `Referer` suivi automatiquement par un script d'analyse.

**Carte 5**
Recto : `localhost` est bloqué mais `2130706433` ne l'est pas : que révèle cette observation ?
Verso : Un filtre de type liste noire, comparant des motifs littéraux sans normaliser ni résoudre l'adresse réellement visée.

**Carte 6**
Recto : Une interaction DNS seule (sans HTTP) sur votre domaine OAST signifie quoi ?
Verso : Une validation côté serveur résolvant le nom sans établir la connexion complète — signal plus faible, mais piste de DNS rebinding à approfondir.

### Tester

**Carte 7**
Recto : Comment tester rigoureusement un contournement de liste noire par notations alternatives ?
Verso : Tester chaque notation (décimale, octale, abrégée, hexadécimale, encodage, casse) individuellement, en conservant le même chemin cible.

**Carte 8**
Recto : Pourquoi les 4 techniques de bypass de liste blanche doivent-elles être testées indépendamment ?
Verso : Chacune cible une ambiguïté de parsing différente (`@`, `#`, hiérarchie DNS, double encodage) — l'échec de l'une ne renseigne rien sur les autres.

**Carte 9**
Recto : Quelle condition côté client HTTP est nécessaire pour qu'un Open Redirect chaîné fonctionne ?
Verso : Que le client HTTP serveur suive automatiquement les redirections 3xx sans revalider la destination finale.

### Interpréter

**Carte 10**
Recto : Toutes les notations alternatives d'IP échouent contre un filtre : que probablement en déduire ?
Verso : Le filtre résout probablement le DNS et compare l'IP résolue, plutôt qu'une simple comparaison littérale — tester le DNS Rebinding en complément.

**Carte 11**
Recto : Un scan aveugle du réseau interne ne montre aucune différence de timing : deux explications ?
Verso : Aucun service actif dans la plage testée, ou filtrage réseau sortant uniforme masquant toute différence — à distinguer via une IP de référence connue active.

**Carte 12**
Recto : Pourquoi une erreur identique quelle que soit l'IP interne injectée ne prouve-t-elle pas l'absence de SSRF ?
Verso : Elle peut indiquer un filtre actif, ou un traitement asynchrone masquant toute différence — seul l'OAST permet de trancher.

### Exploiter

**Carte 13**
Recto : Quel chemin cibler sur `169.254.169.254` pour exfiltrer des identifiants IAM ?
Verso : `/latest/meta-data/iam/security-credentials/` (après confirmation via `/latest/meta-data/`).

**Carte 14**
Recto : À quel moment précis le DNS Rebinding doit-il faire pointer le domaine vers la cible interne ?
Verso : Après la validation initiale (résolution vers une IP publique inoffensive) mais avant la connexion réseau réelle — grâce à un TTL très court.

**Carte 15**
Recto : Quel format de document, au-delà du XML brut, peut servir de vecteur XXE-SSRF ?
Verso : Tout format bureautique basé sur XML (`.docx`, `.xlsx`) ou les fichiers SVG, dès lors que le parseur résout les entités externes.

### Déboguer et transférer

**Carte 16**
Recto : Un test loopback sur `/admin` échoue : quelles variations tester avant de conclure ?
Verso : D'autres chemins (`/status`, `/health`) et d'autres ports courants de services internes, avant de tester les notations alternatives.

**Carte 17**
Recto : Aucune interaction OAST reçue après plusieurs minutes : quelle cause distinguer d'un simple échec de ce point d'entrée ?
Verso : Une restriction réseau sortante complète côté serveur — affecterait alors tous les points d'entrée, pas seulement celui testé.

**Carte 18**
Recto : Quel principe général du SSRF se transfère à d'autres classes de vulnérabilités ?
Verso : Ne jamais traiter une caractéristique de contexte ou d'origine comme une preuve d'autorisation implicite sans vérification explicite indépendante.

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
| « Je ne comprends pas pourquoi l'origine réseau n'est pas une preuve de sécurité » | `cours.md` |
| « Je ne sais pas dans quel ordre tester les différentes familles de bypass » | `exploitation.md` |
| « Je ne me souviens plus de la syntaxe exacte d'une notation ou d'un bypass » | `cheatsheet.md` |
| « J'ai confondu un signal isolé (DNS seul, erreur générique) avec une preuve confirmée » | `exploitation.md` (sections 3.2 et 8 — indices, faux positifs, diagnostic des échecs) |
| « Je ne sais pas comment adapter ce raisonnement à un autre contexte » | `exploitation.md` (section 11 — leçons transférables) |

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
