# Fiche de révision active — Path Traversal (Directory Traversal)

> **Avant de commencer :** cette fiche doit être utilisée **sans consulter** `cours.md`, `exploitation.md` ou `cheatsheet.md`. Répondez à chaque question à voix haute ou par écrit, **puis seulement** comparez votre réponse au corrigé situé après la dernière question. Ne lisez pas le corrigé avant d'avoir répondu — l'objectif est de tester ce que vous savez réellement restituer et raisonner sans support, dans des conditions proches d'un examen pratique (eJPT, OSCP).

---

## Partie 1 — Fiche de révision active

### Catégorie 1 — Comprendre

**Q1.** Définissez le Path Traversal en précisant le composant applicatif défaillant et l'hypothèse incorrecte que ce composant formule à propos de l'entrée utilisateur. Distinguez ensuite explicitement le Path Traversal de la LFI (*Local File Inclusion*) : en quoi ces deux notions sont-elles liées, et en quoi diffèrent-elles ?

**Q2.** Un serveur résout un chemin comme `/var/www/images/../../../etc/passwd` en `/etc/passwd`. Expliquez, étape par étape, le mécanisme de résolution qui permet à une séquence relative de « sortir » du répertoire de base, sans vous contenter de dire que « `../` remonte d'un niveau ».

**Q3.** Pourquoi est-il possible, et sans risque pour l'attaquant, de répéter une séquence `../` bien au-delà de la profondeur réelle de l'arborescence de l'application (8 à 12 fois, par exemple) ? Que se passe-t-il concrètement quand la remontée dépasse la racine du système de fichiers ?

**Q4.** Quelle est la condition technique fondamentale, commune à toutes les variantes présentées dans cette fiche, sans laquelle aucune forme de Path Traversal n'est exploitable ? Formulez-la au niveau du composant applicatif concerné, pas au niveau du payload utilisé.

**Q5.** Cette fiche precise explicitement ne pas couvrir un certain prolongement technique d'une lecture de fichier confirmée. Lequel, pourquoi ce prolongement est-il hors périmètre ici, et quel type de fiche faudrait-il consulter pour le traiter ?

---

### Catégorie 2 — Reconnaître

**Q6.** Vous testez `?file=../../../../etc/passwd` sur un paramètre de téléchargement de document et obtenez exactement la même réponse qu'avec une valeur de paramètre absente. Que suggère cette observation isolée, et que ne permet-elle **pas encore** de conclure ?

**Q7.** Sur l'endpoint `/loadImage?filename=`, la requête avec `../../../etc/passwd` renvoie une erreur 403 « accès refusé », tandis que la requête avec `/etc/passwd` (chemin absolu, sans séquence relative) renvoie le contenu du fichier. Quel type de filtre cette différence de comportement suggère-t-elle ?

**Q8.** Un paramètre `?template=` renvoie un code 500 générique dès qu'il contient un caractère `.` ou `/`, quelle que soit la combinaison testée (brute, encodée, imbriquée). Ce signal est-il de nature à confirmer ou à écarter un Path Traversal sur ce paramètre ? Justifiez.

**Q9.** Vous obtenez dans la réponse HTTP la chaîne `root:x:0:0:root:/root:/bin/bash` après avoir injecté une séquence de traversée. Quel est le niveau de preuve atteint ici, et que reste-t-il à faire avant de documenter l'étendue réelle de l'impact ?

**Q10.** Deux observations sont faites sur le même paramètre : (a) `../../../../etc/passwd` renvoie une erreur 404 « fichier introuvable » ; (b) `../../../../../../../../etc/passwd` (profondeur augmentée) renvoie le contenu du fichier. Comment interprétez-vous la différence entre ces deux résultats, et quelle erreur de raisonnement auriez-vous commise en s'arrêtant au résultat (a) ?

---

### Catégorie 3 — Tester

**Q11.** Formulez l'hypothèse, le test minimal, la condition d'interprétation, le résultat attendu et ce que le test permettrait de conclure pour une **sonde basique par séquence relative brute** sur un paramètre `?file=` nouvellement identifié.

**Q12.** Vous avez testé la séquence relative brute sans succès net (réponse ambiguë). Vous voulez maintenant tester un **chemin absolu**. Quelle hypothèse précise ce test vérifie-t-il, et pourquoi ce test est-il informatif même en cas d'échec combiné à un indice de préfixe imposé ?

**Q13.** Vous soupçonnez un filtre de type `str_replace("../", "")` non récursif. Décrivez le test des **séquences imbriquées**, en précisant pourquoi il faut tester plusieurs variantes syntaxiques (`....//`, `....\/\`, `..././`) plutôt qu'une seule.

**Q14.** Avant de tester un **double encodage URL**, quelle condition architecturale devez-vous d'abord évaluer, et pourquoi ce test serait-il mal interprété s'il échouait sans que cette condition ait été vérifiée au préalable ?

**Q15.** Vous suspectez un préfixe de répertoire fixe concaténé avant le paramètre. Décrivez le test de **contournement de préfixe**, la condition nécessaire pour l'interpréter correctement, et ce qu'un résultat positif confirmerait sur le mécanisme exact de construction du chemin côté serveur.

---

### Catégorie 4 — Interpréter

**Q16.** Vous testez la séquence relative brute à huit profondeurs différentes (1 à 8 répétitions de `../`) sans jamais obtenir le contenu attendu. Que pouvez-vous conclure avec certitude, et que reste-t-il à tester avant d'affirmer que ce paramètre n'est pas vulnérable ?

**Q17.** Le chemin absolu (`/etc/passwd`) échoue, mais vous disposez d'un indice fort qu'un répertoire `/var/www/images/` est concaténé avant le paramètre (visible dans un message d'erreur). Que devriez-vous tester ensuite, et pourquoi l'échec du chemin absolu seul ne permet-il pas de conclure à une protection robuste ?

**Q18.** Une séquence encodée simplement (`%2e%2e%2f`) échoue, alors que la séquence brute avait déjà échoué également. Quelle explication alternative à « le filtre est robuste contre l'encodage » devez-vous envisager en priorité, et quelle conséquence cela a-t-il sur la technique à tester ensuite ?

**Q19.** Après confirmation d'une traversée fonctionnelle sur `/etc/passwd`, vous testez `/etc/shadow` avec exactement le même payload et obtenez une erreur « permission denied », tandis qu'un autre fichier, `/etc/hosts`, est lu sans problème. Que concluez-vous sur l'état de la vulnérabilité elle-même, et qu'est-ce que cela ne remet pas en cause ?

**Q20.** Vous testez un payload avec null byte (`../../../etc/passwd%00.png`) sur une cible dont vous ignorez la stack technique précise, et il échoue. Quelle interprétation la méthodologie recommande-t-elle explicitement d'éviter ici, et pourquoi ?

---

### Catégorie 5 — Exploiter

**Q21.** Construisez la chaîne complète d'exploitation d'un Path Traversal confirmé par séquence relative brute : point d'entrée, primitive technique, déclenchement, effet intermédiaire, aboutissement, preuve. Précisez explicitement en quoi la preuve diffère d'un simple « comportement différent observé ».

**Q22.** Construisez la chaîne d'exploitation d'un contournement par **double encodage URL** visant un WAF ou reverse-proxy. Expliquez à quel endroit précis de la chaîne se situe le décalage exploité (quel composant décode quoi, et combien de fois), et ce qu'un succès à cette étape révèle sur l'architecture de la cible au-delà du seul Path Traversal.

**Q23.** Construisez la chaîne d'exploitation d'un **contournement de préfixe de répertoire imposé**. Pourquoi est-il essentiel, dans cette chaîne précise, de conserver le préfixe dans le payload plutôt que de le remplacer entièrement par un chemin absolu ?

**Q24.** Dans un contexte où une extension est imposée (`.png` systématiquement ajoutée) et où la stack est suspectée obsolète, construisez la chaîne d'exploitation par **null byte**. Précisez la condition technique qui rend cette chaîne obsolète sur une cible moderne, et ce que cela implique pour l'ordre de priorité des tests.

**Q25.** Une fois un premier fichier de test lu avec succès, construisez la démarche permettant de **qualifier l'étendue réelle de l'impact** plutôt que de s'arrêter à cette première preuve. Distinguez explicitement les trois niveaux de preuve évoqués par la méthodologie et précisez ce qui différencie le dernier niveau des deux précédents.

---

### Catégorie 6 — Déboguer et transférer

**Q26.** Un collègue conclut qu'un paramètre n'est « pas vulnérable au Path Traversal » après avoir testé uniquement `../../../etc/passwd` (une seule profondeur, une seule forme). Identifiez précisément ce qui manque à son raisonnement pour que cette conclusion soit valide, en vous appuyant sur au moins deux angles distincts (pas seulement la profondeur).

**Q27.** Un double encodage échoue systématiquement sur une cible. Deux causes radicalement différentes peuvent l'expliquer. Lesquelles, et comment les distingueriez-vous avant de passer à une autre technique ?

**Q28.** Un payload fonctionnel sur `/etc/passwd` échoue sur `/etc/shadow` avec une erreur distincte (« permission denied » plutôt qu'une erreur de chemin). Diagnostiquez la cause la plus probable et expliquez pourquoi il serait incorrect de documenter cet échec comme la preuve que la vulnérabilité de traversée elle-même ne fonctionne pas.

**Q29.** Une séquence encodée simple (`%2e%2e%2f`) ne produit aucun effet alors que la séquence brute avait elle aussi échoué. Diagnostiquez la cause la plus probable évoquée par la méthodologie, et expliquez pourquoi tester un double encodage sans avoir d'abord évalué la plausibilité d'un composant intermédiaire rendrait ce test suivant moins interprétable en cas d'échec.

**Q30.** Vous passez d'un contexte classique (paramètre HTTP → fonction de lecture de fichier sur disque) à un contexte différent (par exemple, un paramètre de chemin utilisé pour accéder à un objet dans un stockage cloud, ou un chemin utilisé côté client dans une application de bureau). Quels principes de raisonnement de cette fiche restent directement transférables, et quels éléments techniques précis (payloads, séparateurs, fichiers cibles) ne doivent jamais être réutilisés tels quels sans vérification ?

---

## Corrigé — Réponses attendues et raisonnement

**R1.** Le composant défaillant est celui qui **transmet une entrée utilisateur à une fonction d'entrée/sortie du système de fichiers sans assainissement** (sans validation du chemin final résolu). L'hypothèse incorrecte est que la valeur reçue (un nom de fichier, un chemin relatif) restera cantonnée au répertoire de base prévu (*document root* ou répertoire applicatif), alors que des caractères de contrôle de chemin (`../`, `..\`) permettent à l'attaquant de modifier la résolution finale. Distinction avec la LFI : le Path Traversal vise la **lecture** d'un fichier arbitraire ; la LFI est un cas particulier où ce chemin traversé est en plus **inclus et exécuté** par l'application (ex. `include()` en PHP) — toute LFI implique potentiellement un mécanisme de traversée, mais tout Path Traversal ne mène pas nécessairement à une exécution de code.

**R2.** Le serveur ne traite pas la chaîne comme une suite de caractères opaque : il la fait passer à une fonction de résolution de chemin qui interprète chaque segment successivement. Partant du répertoire de base (`/var/www/images/`), chaque occurrence de `../` fait remonter la résolution d'un niveau dans l'arborescence (vers `/var/www/`, puis `/var/`, puis `/`), jusqu'à épuisement des occurrences `../` ; les segments restants (`etc/passwd`) sont alors résolus à partir de ce nouveau point de départ. Le résultat final est un chemin absolu équivalent (`/etc/passwd`), totalement indépendant du répertoire de base initial dès lors que suffisamment de remontées ont été appliquées.

**R3.** Remonter au-delà de la racine du système de fichiers (`/` sous Linux, `C:\` sous Windows) ne provoque aucune erreur : la résolution de chemin reste simplement bloquée à la racine, les occurrences `../` excédentaires étant sans effet supplémentaire une fois la racine atteinte. Concrètement, `../../../../../../../../../../etc/passwd` et `../../../etc/passwd` résolvent au même résultat dès lors que la profondeur testée est suffisante — ce qui permet à un attaquant de « sur-remonter » systématiquement (8 à 12 répétitions) sans avoir besoin de connaître la profondeur exacte de l'arborescence réelle de l'application, et sans risque d'erreur lié à un excès de remontées.

**R4.** La condition fondamentale est qu'**un paramètre, un champ ou un en-tête contrôlé par l'utilisateur soit utilisé pour construire un chemin de fichier transmis à une fonction d'E/S système, sans validation suffisante portant sur le chemin final canonisé**. C'est le défaut commun à toutes les variantes de la fiche (brute, encodée, imbriquée, préfixe/suffixe) — ces variantes ne sont que des formes syntaxiques différentes exploitant toutes la même absence de validation sur le résultat final de la résolution de chemin, pas sur la chaîne reçue elle-même.

**R5.** Le prolongement non couvert est l'**escalade d'une lecture de fichier confirmée vers une exécution de code** (inclusion dynamique via `include()`/`require()`, wrappers PHP, log/session poisoning, RFI). Ce prolongement est hors périmètre ici car le cours source ne mentionne la LFI que comme distinction terminologique et évoque le log poisoning uniquement comme vecteur possible de RCE, sans en détailler la méthodologie technique. Pour cette escalade, il faut consulter une fiche LFI/RFI dédiée (explicitement référencée par le cheatsheet comme fiche complémentaire).

**R6.** Cela suggère soit une **absence totale de lien** entre ce paramètre et une opération de fichier, soit un **filtre actif** bloquant spécifiquement cette forme de payload. Cela ne permet **pas encore** de conclure dans un sens ou dans l'autre : il faut d'abord faire varier la profondeur de remontée (le paramètre peut simplement nécessiter plus de `../`), puis tester les autres familles de contournement (chemin absolu, imbrication, encodage) avant d'écarter ce paramètre comme non pertinent.

**R7.** Cette différence suggère un **filtre spécifiquement ciblé sur les séquences relatives** (`../`) qui ne traite pas les chemins absolus — typiquement un filtre de type « suppression ou blocage de `../` » sans validation plus large du chemin final résolu. C'est exactement le scénario que vise le Bypass par chemin absolu : l'application accepte une valeur quelconque tant qu'elle ne contient pas la séquence explicitement filtrée.

**R8.** Ce signal est **ambigu et non concluant** dans un sens comme dans l'autre : une erreur 500 générique systématique sur tout caractère `.` ou `/` peut aussi bien indiquer une validation de format stricte en amont (non liée spécifiquement à un filtre anti-traversée) qu'un comportement d'erreur non lié du tout à une tentative de traversée. Il ne permet ni de confirmer ni d'écarter un Path Traversal — il faut chercher si le message d'erreur révèle une contrainte de format exacte, ce qui orienterait vers un ajustement du payload plutôt qu'un abandon de cette surface.

**R9.** Le niveau de preuve atteint est celui d'une **vulnérabilité confirmée** par un premier fichier de test (motif caractéristique `root:x:0:0:` reconnu sans ambiguïté). Ce qui reste à faire avant de documenter l'étendue réelle de l'impact : tester systématiquement d'autres fichiers sensibles pertinents selon l'OS identifié (`.env`, `id_rsa`, logs, etc.), pour distinguer une simple preuve de concept d'un **impact étendu réellement qualifié** — ces deux niveaux de preuve sont explicitement différenciés dans la méthodologie.

**R10.** Le résultat (a) ne permet de conclure **qu'à une profondeur insuffisante à ce stade précis** — pas à une absence de vulnérabilité. Le résultat (b) confirme que la vulnérabilité existe bel et bien, simplement masquée par un test de profondeur trop faible lors du premier essai. L'erreur de raisonnement à éviter : interpréter une erreur 404 après un seul test de profondeur comme une preuve d'absence de vulnérabilité, alors que le sur-remontage au-delà de la racine réelle ne provoque jamais d'erreur et que la seule explication d'un échec à faible profondeur est que l'arborescence réelle est simplement plus profonde que prévu.

**R11.**
- **Hypothèse** : le paramètre est concaténé à un chemin de base sans validation du chemin final, permettant de sortir du répertoire prévu.
- **Test minimal** : envoyer `../../../../etc/passwd` (Linux) ou l'équivalent Windows, en faisant varier la profondeur de 1 à 8 répétitions si le premier essai échoue.
- **Condition d'interprétation** : disposer d'une référence établie au préalable (requête légitime, requête invalide anodine) pour distinguer un comportement provoqué d'un comportement normal.
- **Résultat attendu si vraie** : apparition du motif caractéristique du fichier cible (`root:x:0:0:` ou section `[fonts]`) dans la réponse, à une profondeur donnée.
- **Ce que cela permet de conclure** : uniquement que la séquence brute, sans contournement, suffit à confirmer la traversée — pas que d'autres fichiers plus sensibles sont nécessairement accessibles (chaque cible doit être testée individuellement).

**R12.** Hypothèse vérifiée : l'application ne valide pas que le chemin fourni reste relatif à son répertoire de base, acceptant un chemin absolu tel quel, indépendamment du traitement appliqué aux séquences `../`. Ce test reste informatif même en cas d'échec : combiné à un indice de préfixe imposé (visible par exemple dans un message d'erreur révélant un répertoire de base), un échec du chemin absolu seul **ne signifie pas** une protection robuste — il peut simplement indiquer qu'un préfixe fixe est systématiquement concaténé avant le paramètre, nécessitant de tester la combinaison préfixe + séquence relative (étape distincte), plutôt que le chemin absolu seul.

**R13.** Test : envoyer successivement `....//....//....//etc/passwd`, `....\/\....\/`, et `..././..././etc/passwd` à la place de la séquence brute. Il faut tester plusieurs variantes syntaxiques car l'implémentation exacte du filtre non récursif peut réagir différemment selon la forme exacte testée — un filtre codé comme `str_replace("../", "")` ne réagira pas nécessairement de la même façon à `....//`que' `..././`, selon la manière précise dont le remplacement est implémenté et selon les séparateurs qu'il reconnaît explicitement. Se limiter à une seule variante risquerait un faux négatif si cette variante précise ne correspond pas au pattern exact reconnu par le filtre en place.

**R14.** Condition architecturale à évaluer d'abord : la **présence plausible d'un reverse-proxy ou d'un WAF en amont de l'application**, susceptible de décoder une fois la requête avant de la transmettre (laissant l'application effectuer un second décodage). Sans cette vérification préalable, un échec du double encodage serait mal interprété : il pourrait aussi bien signifier « aucun composant intermédiaire n'effectue de décodage partiel » (cause neutre, sans lien avec la robustesse de la cible) que « le WAF normalise correctement et de façon récursive avant filtrage » (bonne pratique de sécurité) — deux causes très différentes que seule la vérification préalable de l'architecture permet de distinguer.

**R15.** Test : faire suivre le préfixe supposé (par exemple `/var/www/images/`) d'une séquence de traversée suffisante pour remonter au-delà de ce préfixe, par exemple `/var/www/images/../../../etc/passwd`. Condition nécessaire pour l'interpréter correctement : avoir un indice (message d'erreur, comportement observé) suggérant l'existence probable de ce préfixe fixe avant de construire ce test ciblé. Un résultat positif confirmerait que le chemin final résolu par le serveur est de la forme `<préfixe fixe><valeur du paramètre>`, sans validation du chemin **final canonisé** — c'est-à-dire que la validation, si elle existe, porte sur la chaîne brute reçue et non sur le résultat de la résolution complète du chemin.

**R16.** On peut conclure avec certitude uniquement que **cette forme précise de payload (séquence brute), à ces profondeurs testées, n'a pas produit le résultat attendu** — rien de plus. Il reste à tester : un chemin absolu (pour écarter un filtre spécifiquement ciblé sur `../`), des séquences imbriquées (pour détecter un filtre non récursif), des encodages (pour détecter un filtre comparant des chaînes littérales), et à vérifier la plausibilité d'un préfixe/suffixe imposé — un échec à l'étape 1 seule n'autorise aucune conclusion sur la vulnérabilité réelle du paramètre.

**R17.** Il faudrait tester le **contournement de préfixe** : faire suivre le préfixe supposé (`/var/www/images/`) d'une séquence relative suffisante pour remonter au-delà, plutôt que de tenter un chemin absolu seul qui ignore ce préfixe. L'échec du chemin absolu seul ne permet pas de conclure à une protection robuste car il ne teste qu'une seule hypothèse (absence totale de restriction au répertoire de base) — il ne dit rien sur la combinaison précise préfixe-fixe-plus-traversée-relative, qui est un scénario distinct et potentiellement vulnérable même quand le chemin absolu seul échoue.

**R18.** Explication alternative à privilégier : un **décodage automatique en amont du filtre applicatif** (par le serveur web, le framework, ou un composant intermédiaire) a probablement déjà neutralisé la forme encodée avant que le filtre ne s'exécute — rendant cette forme équivalente, du point de vue du filtre, à la séquence brute déjà testée et déjà bloquée. Conséquence sur la technique suivante : il ne sert à rien de s'acharner sur d'autres variantes d'encodage simple ; il faut d'abord vérifier la plausibilité d'un composant intermédiaire (reverse-proxy/WAF) avant de passer au double encodage, qui exploite un mécanisme architectural différent (décodage partiel par un composant distinct de l'application).

**R19.** On conclut que la **vulnérabilité de traversée fonctionne bel et bien** (confirmée par la lecture réussie de `/etc/hosts` avec le même payload) — l'échec sur `/etc/shadow` est dû à une **restriction de droits du compte applicatif** sur ce fichier précis, cause totalement distincte d'un échec de la technique de traversée elle-même. Cela ne remet absolument pas en cause la confirmation de la vulnérabilité : il faut documenter les deux résultats séparément (vulnérabilité confirmée + limite de droits sur certains fichiers précis), sans présenter l'échec sur `/etc/shadow` comme une preuve d'absence de vulnérabilité.

**R20.** La méthodologie recommande explicitement d'éviter d'interpréter cet échec comme un échec de la démarche ou un signe que d'autres techniques échoueront également. Le null byte est corrigé depuis PHP ≥ 5.3.4 et absent des runtimes managés modernes : un résultat négatif ici est **l'issue attendue dans la majorité des contextes actuels**, et non un indicateur de robustesse générale de la cible — ce test reste pertinent par exhaustivité (stacks obsolètes), mais son échec ne doit jamais être généralisé à une conclusion sur les autres techniques (imbrication, encodage, préfixe).

**R21.** 
- **Point d'entrée** : paramètre HTTP contrôlant un chemin de fichier résolu côté serveur.
- **Primitive technique** : séquence relative brute (`../../../../etc/passwd`), forme la plus simple de contournement.
- **Déclenchement** : requête HTTP transmettant ce payload au paramètre vulnérable.
- **Effet intermédiaire** : résolution par le serveur d'un chemin hors du répertoire prévu, avec lecture effective du fichier.
- **Aboutissement** : extension potentielle à d'autres fichiers sensibles accessibles selon les droits du compte applicatif.
- **Preuve** : contenu caractéristique et vérifiable du fichier lu (motif non ambigu, reproductible sur plusieurs tentatives). Différence avec un « comportement différent observé » : ce dernier n'est qu'un signal (ex. code HTTP différent, erreur distincte) — la preuve exige la présence **effective et identifiable** du contenu du fichier ciblé, non une simple divergence de comportement qui pourrait avoir d'autres causes.

**R22.** Décalage exploité : un **composant intermédiaire** (reverse-proxy/WAF) décode une première fois la séquence doublement encodée (`%252e%252e%252f` → `%2e%2e%2f`), ce qui — n'étant pas reconnu comme une séquence de traversée active par ses règles de filtrage — laisse passer la requête ; l'**application**, en aval, effectue à son tour un second décodage (`%2e%2e%2f` → `../`), révélant alors la séquence active. Le décalage se situe donc précisément entre le nombre de décodages effectués par chaque couche. Ce qu'un succès révèle au-delà du Path Traversal : la **présence confirmée d'un composant de décodage intermédiaire** dans l'architecture réseau de la cible — information réutilisable pour d'autres classes de vulnérabilités impliquant potentiellement le même décalage de normalisation.

**R23.** Il est essentiel de conserver le préfixe dans le payload car, dans ce scénario précis, l'application **concatène systématiquement ce préfixe avant la valeur du paramètre** pour construire le chemin final — un chemin absolu remplaçant entièrement le préfixe ne modifierait que la valeur transmise en paramètre, pas le chemin réellement résolu côté serveur (qui reste `<préfixe fixe><valeur du paramètre>`). En conservant le préfixe puis en ajoutant la séquence de traversée après lui (`/var/www/images/../../../etc/passwd`), on satisfait la construction attendue par l'application tout en remontant hors du répertoire autorisé une fois la résolution effectuée.

**R24.** Condition technique rendant cette chaîne obsolète : le **comportement de troncature au byte nul** (`\0`) des appels système sous-jacents en C, qui a été corrigé en PHP ≥ 5.3.4 et n'existe pas dans les runtimes managés modernes — l'application moderne ne tronque simplement plus la chaîne au null byte, rendant `%00.png` sans effet particulier (le suffixe reste traité normalement). Implication pour l'ordre de priorité : cette technique doit être testée **en dernier**, par exhaustivité, uniquement si une stack obsolète est spécifiquement suspectée — elle ne doit jamais être priorisée avant les techniques génériquement plus efficaces (imbrication, encodage) sur une cible dont l'âge de la stack n'est pas confirmé.

**R25.** Démarche : réutiliser la forme de payload déjà validée en substituant systématiquement la cible à une liste de fichiers sensibles pertinents selon l'OS identifié (ex. `.env`, `id_rsa`, logs d'authentification pour Linux ; `web.config`, `SAM` pour Windows), et qualifier précisément la nature de chaque fuite obtenue. Les trois niveaux de preuve : (1) **preuve de comportement anormal** — une différence de réponse est observée sans contenu de fichier identifiable (signal, pas une preuve) ; (2) **preuve de vulnérabilité confirmée** — le contenu d'au moins un fichier cible de test est obtenu de façon reproductible ; (3) **preuve d'impact étendu** — plusieurs fichiers sensibles pertinents sont effectivement accessibles, qualifiant la portée réelle au-delà d'un simple fichier de démonstration. Ce qui différencie le troisième niveau des deux précédents : il ne se contente pas de démontrer que la technique fonctionne, il **mesure et documente l'étendue réelle de l'exposition**, condition nécessaire pour évaluer correctement la sévérité du finding.

**R26.** Ce qu'il manque, sur au moins deux angles distincts : (1) la **profondeur** — une seule profondeur testée ne garantit rien, il faut faire varier de 1 à 8-12 remontées avant de conclure, le sur-remontage étant sans risque ; (2) la **forme du payload** — une seule forme (séquence brute) ne couvre pas les autres mécanismes de contournement (chemin absolu, séquences imbriquées, encodages simples/doubles, préfixe/suffixe imposé), chacun ciblant une hypothèse de filtre différente. Un filtre actif mais contournable produit le même symptôme apparent (échec) qu'une absence totale de vulnérabilité — seule une couverture systématique de ces deux dimensions permet de distinguer les deux cas.

**R27.** Deux causes radicalement différentes : (a) **aucun composant intermédiaire** n'effectue de décodage partiel (le double encodage n'a simplement aucun mécanisme à exploiter dans cette architecture) ; (b) un **WAF normalise correctement et récursivement** l'URL avant d'appliquer ses règles de filtrage (bonne pratique de sécurité qui neutralise précisément cette technique). Distinction : rechercher des indices d'infrastructure indépendants (en-têtes `Via`, `X-Forwarded-For`, bannières de réponse révélant un reverse-proxy, temps de réponse caractéristiques) avant de conclure — la présence confirmée d'un tel composant par ailleurs dans l'audit oriente vers la cause (b) ; son absence totale d'indice oriente vers la cause (a). Dans les deux cas, il ne sert à rien d'insister sur cette technique précise ; passer aux encodages non standard ou au préfixe/suffixe imposé.

**R28.** Cause la plus probable : une **restriction de droits de lecture du compte applicatif** sur `/etc/shadow` spécifiquement (fichier historiquement protégé, nécessitant des privilèges élevés), distincte d'un échec du mécanisme de traversée lui-même. Il serait incorrect de documenter cela comme un échec de la vulnérabilité de traversée car le payload atteint bien la fonction d'E/S système (comme démontré par son succès sur `/etc/passwd`) — seul l'accès à ce fichier précis est refusé par le système d'exploitation, une couche de contrôle totalement indépendante de la vulnérabilité applicative testée. Documenter ces deux éléments séparément (vulnérabilité confirmée + limite de droits sur certains fichiers) donne une image fidèle de l'impact réel.

**R29.** Cause la plus probable : un **décodage automatique en amont du filtre applicatif** a déjà neutralisé la forme encodée avant que le filtre ne s'exécute, rendant cette forme équivalente à la séquence brute déjà testée (et déjà bloquée) — ce n'est donc pas une preuve de robustesse du filtre face à l'encodage en tant que tel. Pourquoi passer directement au double encodage sans vérification préalable rendrait ce test suivant moins interprétable : un échec du double encodage pourrait alors avoir deux causes indiscernables — absence de composant intermédiaire décodant partiellement (cause neutre), ou normalisation récursive correcte de ce composant (bonne pratique) — sans avoir établi au préalable la plausibilité même d'un tel composant, on ne peut pas savoir laquelle de ces deux causes explique l'échec, ce qui empêche d'orienter correctement la suite du test.

**R30.** Principes transférables : progresser par niveaux de sophistication croissante (forme simple avant contournements) ; distinguer explicitement un échec dû à l'absence de vulnérabilité d'un échec dû à une cause externe (droits, profondeur, architecture) ; ne jamais conclure après un seul test, en faisant varier systématiquement profondeur/encodage/contexte ; relier chaque technique de contournement à l'hypothèse précise de filtre qu'elle cible plutôt que de tester au hasard. Éléments techniques à revérifier systématiquement, jamais réutilisables tels quels : les **payloads exacts** (séparateurs de chemin, syntaxe d'encodage propres à un système de fichiers ou un protocole particulier) ; les **fichiers cibles** (les chemins Linux/Windows cités ici n'ont aucun sens dans un stockage cloud, où la notion même de « racine » et de résolution relative peut ne pas exister de la même façon) ; la pertinence de techniques historiques (double encodage, overlong UTF-8, Unicode IIS, null byte) qui dépendent entièrement de composants et de versions spécifiques, potentiellement absents du nouveau contexte.

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
**Recto :** Quelle est la différence exacte entre Path Traversal et LFI (*Local File Inclusion*) ?
**Verso :** Le Path Traversal vise la **lecture** d'un fichier arbitraire hors du répertoire prévu. La LFI est un cas particulier où ce fichier traversé est en plus **inclus et exécuté** par l'application (ex. `include()` PHP) — toute LFI implique une traversée, mais toute traversée ne mène pas nécessairement à une exécution de code.

**Carte 2**
**Recto :** Pourquoi peut-on « sur-remonter » (répéter `../` 8 à 12 fois) sans risque d'erreur, même si la profondeur réelle de l'arborescence est inconnue ?
**Verso :** Remonter au-delà de la racine du système de fichiers (`/` ou `C:\`) ne provoque aucune erreur : la résolution reste simplement bloquée à la racine, les remontées excédentaires étant sans effet supplémentaire.

**Carte 3**
**Recto :** Quelle est la condition technique fondamentale commune à toutes les variantes de Path Traversal couvertes par cette fiche ?
**Verso :** Un paramètre contrôlé par l'utilisateur est utilisé pour construire un chemin de fichier transmis à une fonction d'E/S système, **sans validation suffisante portant sur le chemin final canonisé** (et non sur la chaîne brute reçue).

### Reconnaître

**Carte 4**
**Recto :** `../../../../etc/passwd` et une valeur de paramètre absente produisent exactement la même réponse. Que peut-on en conclure à ce stade ?
**Verso :** Rien de définitif : soit le paramètre n'est pas lié à une opération de fichier, soit un filtre actif bloque spécifiquement cette forme. Il faut faire varier la profondeur et tester d'autres contournements avant de conclure.

**Carte 5**
**Recto :** Un chemin relatif échoue (403) mais un chemin absolu (`/etc/passwd`) réussit. Que suggère cette différence ?
**Verso :** Un filtre spécifiquement ciblé sur les séquences relatives (`../`), qui ne valide pas plus largement le chemin final — l'application accepte toute valeur ne contenant pas la séquence explicitement filtrée.

**Carte 6**
**Recto :** Le contenu `root:x:0:0:root:/root:/bin/bash` apparaît dans la réponse après injection d'une séquence de traversée. Quel niveau de preuve est atteint ?
**Verso :** **Vulnérabilité confirmée** (motif caractéristique non ambigu). Il reste à tester d'autres fichiers sensibles pour passer à un niveau de preuve d'**impact étendu qualifié**.

### Tester

**Carte 7**
**Recto :** Pourquoi faut-il faire varier systématiquement la profondeur de remontée (`../` répété) avant de conclure à l'échec d'une sonde basique ?
**Verso :** Parce qu'un échec à une profondeur donnée peut simplement indiquer une profondeur insuffisante, et que le sur-remontage au-delà de la racine réelle ne provoque jamais d'erreur — rien n'empêche de tester systématiquement 1 à 12 répétitions.

**Carte 8**
**Recto :** Pourquoi faut-il tester plusieurs variantes syntaxiques de séquences imbriquées (`....//`, `..././`, etc.) plutôt qu'une seule ?
**Verso :** Parce que l'implémentation exacte d'un filtre non récursif (`str_replace` par exemple) peut réagir différemment selon la forme exacte testée — se limiter à une variante risque un faux négatif si elle ne correspond pas au pattern reconnu par ce filtre précis.

**Carte 9**
**Recto :** Quelle condition architecturale doit être évaluée avant de tester un double encodage URL ?
**Verso :** La plausibilité d'un **reverse-proxy ou WAF en amont** décodant une fois la requête avant transmission à l'application. Sans cette vérification, un échec serait ambigu entre « absence de composant intermédiaire » et « normalisation récursive correcte ».

### Interpréter

**Carte 10**
**Recto :** Un payload de traversée échoue à toutes les profondeurs testées (1 à 8). Que peut-on en conclure avec certitude ?
**Verso :** Uniquement que **cette forme précise**, à ces profondeurs, n'a pas fonctionné — rien de plus. Il reste à tester chemin absolu, imbrication, encodages et préfixe/suffixe avant toute conclusion sur l'absence de vulnérabilité.

**Carte 11**
**Recto :** Un fichier `/etc/shadow` renvoie « permission denied » avec un payload qui fonctionne sur `/etc/hosts`. Que conclure sur la vulnérabilité elle-même ?
**Verso :** La vulnérabilité de traversée **fonctionne bel et bien** — l'échec sur `/etc/shadow` est dû à une restriction de droits du compte applicatif sur ce fichier précis, cause distincte et sans rapport avec le mécanisme de traversée.

**Carte 12**
**Recto :** Un test de null byte échoue sur une cible dont la stack est inconnue. Quelle interprétation faut-il éviter ?
**Verso :** Ne pas généraliser cet échec à une conclusion sur les autres techniques — le null byte est corrigé depuis PHP ≥ 5.3.4 et absent des runtimes modernes : son échec est l'issue **attendue** dans la majorité des contextes actuels, pas un signe de robustesse générale.

### Exploiter

**Carte 13**
**Recto :** Dans la chaîne d'exploitation d'un double encodage réussi, où se situe précisément le décalage exploité ?
**Verso :** Entre le **nombre de décodages** effectués par chaque couche : le composant intermédiaire (WAF/proxy) décode une fois (`%252e` → `%2e`, jugé inoffensif), l'application décode une seconde fois (`%2e` → `.`), révélant la séquence active.

**Carte 14**
**Recto :** Dans un scénario de préfixe de répertoire imposé, pourquoi faut-il conserver le préfixe dans le payload plutôt que le remplacer par un chemin absolu ?
**Verso :** Parce que l'application concatène systématiquement ce préfixe avant la valeur du paramètre pour construire le chemin final — un chemin absolu seul ne modifierait que la valeur transmise, pas le chemin réellement résolu (`<préfixe><valeur>`).

**Carte 15**
**Recto :** Quels sont les trois niveaux de preuve distingués par la méthodologie, du plus faible au plus fort ?
**Verso :** (1) Comportement anormal observé (signal, pas une preuve) ; (2) vulnérabilité confirmée (contenu d'un fichier de test obtenu de façon reproductible) ; (3) impact étendu qualifié (plusieurs fichiers sensibles effectivement accessibles, portée réelle mesurée).

### Déboguer et transférer

**Carte 16**
**Recto :** Un paramètre est jugé « non vulnérable » après un seul test (`../../../etc/passwd`, une seule forme, une seule profondeur). Quelles sont les deux dimensions manquantes à ce raisonnement ?
**Verso :** La **profondeur** (une seule valeur testée ne suffit pas) et la **forme du payload** (une seule technique ne couvre pas les autres hypothèses de filtre : chemin absolu, imbrication, encodages, préfixe/suffixe).

**Carte 17**
**Recto :** Le double encodage échoue systématiquement. Quelles sont les deux causes radicalement différentes possibles, et comment les distinguer ?
**Verso :** (a) Aucun composant intermédiaire ne décode partiellement ; (b) un WAF normalise correctement et récursivement. Distinction : rechercher des indices d'infrastructure indépendants (en-têtes `Via`/`X-Forwarded-*`, bannières, temps de réponse) avant de conclure.

**Carte 18**
**Recto :** En changeant de contexte technique (ex. stockage cloud au lieu d'un système de fichiers classique), quels éléments de cette fiche ne doivent jamais être réutilisés tels quels ?
**Verso :** Les **payloads exacts** (séparateurs, encodages propres à un système de fichiers), les **fichiers cibles** (chemins Linux/Windows sans équivalent dans un stockage objet), et la pertinence de techniques historiques (double encodage, overlong UTF-8, null byte) dépendant de composants et versions spécifiques.

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
| « Je ne comprends pas pourquoi la remontée de chemin fonctionne / pourquoi la faille existe. » | `cours.md` |
| « Je ne sais pas quel bypass tester ensuite selon le filtre observé. » | `exploitation.md` (méthodologie, arbre de décision) |
| « Je connais le principe du test, mais j'oublie la syntaxe exacte d'un encodage. » | `cheatsheet.md` |
| « Je ne sais pas si mon observation suffit à conclure / ce qu'il reste à vérifier. » | `exploitation.md`, sections « Indices et faux positifs » et « Diagnostic des échecs » |
| « Je confonds un échec de la technique avec une restriction de droits ou une cause externe. » | `exploitation.md`, section « Diagnostic des échecs » |
| « Je ne sais pas comment qualifier l'étendue réelle de l'impact. » | `exploitation.md`, section « Vérification de l'exploitation et preuve de l'impact » |

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
