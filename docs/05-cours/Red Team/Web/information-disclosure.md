# 🔍 Vulnérabilité Web : Divulgation d'Informations (Information Disclosure)

!!! info "Fiche de référence"
    **Public cible :** pentesters, auditeurs de sécurité, Red Teamers, développeurs et équipes DevSecOps.
    **Catégories associées :** OWASP Top 10 — *A05:2021 Security Misconfiguration*, *A01:2021 Broken Access Control* · CWE-200, CWE-209, CWE-215, CWE-538, CWE-540, CWE-548.

---

## 1. Généralités & Définitions

### 1.1 Définition

La **divulgation d'informations** (*Information Disclosure* ou *Information Leakage*) désigne la **révélation non intentionnelle d'informations sensibles** aux utilisateurs d'un système. Selon le contexte, ces informations peuvent être :

| Catégorie | Exemples |
|---|---|
| **Données utilisateurs** | Identifiants, jetons de session, données personnelles, informations de compte |
| **Données financières / commerciales** | Montants, tarifs internes, informations clients, propriété intellectuelle |
| **Détails techniques de l'infrastructure** | Versions de frameworks, chemins système, schéma de base de données, topologie réseau, adresses IP internes |
| **Secrets applicatifs** | Clés API, mots de passe de BDD, clés de chiffrement, tokens d'accès cloud |

### 1.2 Nuance tactique

!!! info "Pourquoi une fuite « mineure » ne l'est jamais vraiment"
    L'utilité immédiate d'une donnée divulguée peut sembler **faible** (un numéro de version, un nom de dossier, un commentaire HTML). Pourtant, ces éléments constituent très souvent **le point de départ de la phase de reconnaissance** et permettent de bâtir des attaques complexes sur une **surface d'attaque beaucoup plus large** : exploitation de CVE ciblées, injection SQL guidée, contournement de contrôle d'accès, etc.

Une fuite d'information est rarement une fin en soi : c'est un **multiplicateur de force** pour tout autre vecteur d'attaque.

### 1.3 Mode d'apparition

La divulgation peut se manifester de deux manières :

- **Passive / immédiate :** dès la simple visite du site (bannière de version, commentaire HTML visible dans le code source, `robots.txt`).
- **Active / approfondie :** nécessite une **interaction soutenue** avec l'application et une **analyse minutieuse des réponses HTTP** (en-têtes, différences de comportement, temps de réponse, messages d'erreur provoqués).

### 1.4 Exemples typiques

- Répertoires cachés révélés via `/robots.txt`.
- Accès au **code source** via des fichiers de sauvegarde temporaires (`.bak`, `~`, `.swp`).
- Mention explicite de **noms de tables ou de colonnes** dans des messages d'erreur SQL.
- Exposition de **secrets hard-codés** : clés API, adresses IP internes, identifiants de base de données.

```text
# Exemple : robots.txt révélant un chemin sensible
User-agent: *
Disallow: /admin-backup/
Disallow: /internal-api/v1/
Disallow: /old-site/
```

---

## 2. Origines & Causes des Failles

Les fuites d'informations proviennent généralement de **trois familles de causes** :

### 2.1 Échec du nettoyage avant mise en production

- Commentaires de développement oubliés dans le HTML, le JavaScript ou les templates.
- Contenus internes (TODO, identifiants de test, URLs de préproduction) non retirés.
- Fichiers temporaires ou de sauvegarde laissés dans la racine web.

### 2.2 Mauvaise configuration des serveurs et technologies sous-jacentes

- **Mode debug activé** en production (Django `DEBUG=True`, Laravel `APP_DEBUG=true`, Flask debugger, Spring Boot Actuator exposé, etc.).
- **Verbosité excessive** : pages d'erreur détaillées, stack traces complètes, en-têtes `Server` / `X-Powered-By` bavards.
- Listing de répertoires activé (`Options +Indexes`, `autoindex on`).
- Méthodes HTTP superflues actives (`TRACE`, `OPTIONS` trop permissif).

### 2.3 Comportement applicatif défectueux (oracle d'inférence)

L'application renvoie des **réponses structurellement différentes** selon l'existence ou non d'une donnée. L'attaquant exploite cette différence comme un **oracle** pour inférer des informations :

| Scénario | Réponse si la donnée existe | Réponse si elle n'existe pas |
|---|---|---|
| Authentification | « Mot de passe incorrect » | « Utilisateur inconnu » |
| Récupération de mot de passe | « Un email a été envoyé » | « Aucun compte associé » |
| Accès à une ressource | `403 Forbidden` | `404 Not Found` |
| Temps de traitement | Réponse lente (requête BDD effectuée) | Réponse rapide |

!!! tip "Principe de l'oracle"
    Toute différence **observable** (contenu, taille, code HTTP, temps de réponse, en-têtes) entre deux cas métier distincts est une fuite potentielle d'information. C'est le fondement de l'**énumération d'utilisateurs**.

---

## 3. Impacts Potentiels

L'impact dépend de **la nature de l'information divulguée** et de **l'objectif global de l'application**. Il peut être **direct** ou **indirect**.

| Type d'impact | Description | Exemple |
|---|---|---|
| **Direct** | La donnée divulguée est elle-même critique | Fuite de données personnelles, de clés API, de code source propriétaire |
| **Indirect** | La donnée facilite une attaque ultérieure | Version d'un framework → exploitation d'une CVE connue |
| **Fuite de propriété intellectuelle** | Accès à la logique métier ou aux algorithmes | Code source récupéré via `.git` |
| **Élévation de privilèges facilitée** | Découverte de comptes, rôles ou endpoints cachés | Panneau d'administration trouvé via `robots.txt` |
| **Compromission complète de l'infrastructure** | Combinaison de secrets et de topologie interne | Identifiants BDD + IP interne + SSRF |

!!! warning "Chaîne d'attaque"
    En audit, une divulgation d'informations classée « Faible » ou « Info » doit être **évaluée dans le contexte de sa chaînabilité**. Un identifiant cloud exposé dans un fichier JS peut basculer instantanément en sévérité **Critique**.

---

## 4. Méthodologie de Test & Outils d'Analyse

### 4.1 Éviter l'effet tunnel (*Tunnel Vision*)

!!! warning "Ne pas se focaliser sur un seul point d'entrée"
    Les fuites de données peuvent provenir de **n'importe quel endpoint ou fonctionnalité** : formulaire de contact, API mobile, page 404, fichier statique, en-tête de réponse, webhook, endpoint de healthcheck, etc.

    **La phase de reconnaissance est déterminante** : une cartographie exhaustive (Site Map complète, endpoints API, sous-domaines, ressources statiques) conditionne la qualité de toute la suite de l'audit.

Bonnes pratiques :

1. Parcourir **l'intégralité** de l'application en mode proxy (Burp / ZAP) avant toute attaque ciblée.
2. Examiner **toutes** les réponses, y compris celles qui semblent inintéressantes (images, JS, CSS, redirections).
3. Comparer systématiquement le comportement **authentifié vs non authentifié**, **utilisateur vs administrateur**.

### 4.2 Outils d'engagement Burp Suite

| Outil | Rôle | Usage recommandé |
|---|---|---|
| **Search** | Recherche d'expressions spécifiques dans l'ensemble du trafic proxifié | Chercher `password`, `secret`, `api_key`, `token`, `BEGIN RSA`, `internal`, `TODO`, `debug` |
| **Find Comments** | Extraction automatisée des commentaires de développement des requêtes/réponses | `Engagement tools` → `Find comments` : repérer commentaires HTML `<!-- -->`, JS `//` et `/* */` |
| **Discover Content** | Test de répertoires et fichiers pour enrichir le plan du site (*Site Map*) | Découvrir des chemins non référencés (`/backup/`, `/old/`, `/admin/`) |
| **Logger++** | Extension d'analyse approfondie du trafic (filtres avancés, regex, colonnes personnalisées) | Filtrer sur des motifs sensibles, des en-têtes spécifiques, des tailles de réponse |

```text
# Exemples de filtres Logger++ (syntaxe indicative)
Response.Body CONTAINS "stack trace"
Response.Body MATCHES "(?i)(api[_-]?key|secret|passwd|password)\s*[:=]"
Response.Headers CONTAINS "X-Powered-By"
```

!!! tip "Astuce Burp : Target Scope"
    Définissez toujours le **scope** de la cible avant d'utiliser `Search` ou `Find comments`, afin de limiter le bruit et rester dans le périmètre autorisé de l'audit.

### 4.3 Fuzzing & Analyse des réponses

#### Envoi de données inattendues

Soumettre aux paramètres des valeurs **hors norme** pour observer les réactions de l'application :

- Types incorrects (chaîne à la place d'un entier, tableau à la place d'une chaîne).
- Caractères spéciaux : `'`, `"`, `\`, `%00`, `{{`, `<`, `${`.
- Valeurs extrêmes : très longues chaînes, nombres négatifs, `null`, valeurs vides.

#### Automatisation de la comparaison (Burp Intruder)

Comparer entre les requêtes :

- **Codes HTTP** (`200`, `302`, `403`, `404`, `500`).
- **Tailles de contenu** (*Content-Length*, longueur de la réponse).
- **Temps de réponse** (détection d'oracles temporels).
- ***Grep matching* / *Grep extract*** : recherche de chaînes caractéristiques (`error`, `exception`, `SQL`, `Warning`, `Traceback`).

```http
GET /product?id=1 HTTP/1.1
Host: cible.example

GET /product?id=abc HTTP/1.1
Host: cible.example

GET /product?id=1' HTTP/1.1
Host: cible.example
```

> Comparer les **trois** réponses : toute divergence (taille, code, message) mérite investigation.

#### Déclenchement volontaire d'erreurs

Injecter des valeurs **non valides** pour provoquer des messages d'erreur verbeux et observer :

- Le **type de données** attendu par le paramètre.
- Le **framework** et sa **version** (en-têtes, stack trace).
- Les **chemins de fichiers** côté serveur.
- Les **noms de tables, colonnes, requêtes SQL**.

```text
# Exemple de message d'erreur révélateur
Fatal error: Uncaught PDOException: SQLSTATE[42S22]: Column not found:
1054 Unknown column 'usr_pwd' in 'field list' in /var/www/html/app/models/User.php:42
```

!!! info "Ce que cette erreur révèle"
    - Moteur : MySQL/MariaDB
    - Nom de colonne : `usr_pwd`
    - Chemin absolu : `/var/www/html/app/models/User.php`
    - Technologie : PHP + PDO

### 4.4 Checklist de reconnaissance rapide

- [ ] `/robots.txt`, `/sitemap.xml`, `/.well-known/security.txt`
- [ ] Commentaires dans le HTML, JS, CSS
- [ ] En-têtes de réponse (`Server`, `X-Powered-By`, `X-AspNet-Version`, `Via`)
- [ ] Pages d'erreur personnalisées vs par défaut (404, 500, 403)
- [ ] Fichiers de sauvegarde / temporaires (`.bak`, `.old`, `~`, `.swp`)
- [ ] Dossier `/.git/`, `/.svn/`, `/.env`, `/.DS_Store`
- [ ] Méthode `TRACE` / `OPTIONS`
- [ ] Endpoints de debug (`/debug`, `/actuator`, `/phpinfo.php`, `/server-status`)
- [ ] Source maps JavaScript (`*.js.map`)
- [ ] Différences de réponse (énumération d'utilisateurs)

---

## 5. Sources Principales de Divulgation d'Informations

### 5.1 Fichiers pour robots d'indexation : `/robots.txt` et `/sitemap.xml`

Ces fichiers servent à guider les moteurs de recherche, mais **ne constituent en aucun cas un contrôle d'accès**. Ils exposent souvent des **règles de référencement et des chemins sensibles**.

```bash
curl -s https://cible.example/robots.txt
curl -s https://cible.example/sitemap.xml
```

```text
User-agent: *
Disallow: /admin/
Disallow: /backup/
Disallow: /api/internal/
```

!!! warning "Un `Disallow` n'est pas une protection"
    Lister un chemin dans `robots.txt` revient à **le signaler à un attaquant**. La seule protection valable est une **authentification / autorisation côté serveur**.

### 5.2 Commentaires de développement

Les commentaires laissés dans le code livré au client donnent des indices sur :

- Des **répertoires cachés** ou des environnements de test.
- Des **fonctionnalités dépréciées** mais encore actives.
- La **logique interne** de l'application.
- Parfois des **identifiants** ou des **notes de débogage**.

```html
<!-- TODO: supprimer l'endpoint /api/v1/admin/export avant la mise en prod -->
<!-- Compte de test : admin / Test1234 (à retirer) -->
<!-- Ancien site disponible sur /legacy/ -->
```

**Méthode :** Burp → `Engagement tools` → `Find comments`, ou recherche regex sur le DOM / les fichiers JS récupérés.

### 5.3 Messages d'erreur

Les messages d'erreur verbeux révèlent :

- Le **type de données attendu** pour un paramètre.
- Les **frameworks** et **versions** utilisés (utile pour cibler des CVE).
- Le **comportement interne** : requêtes SQL, chemins, noms de classes, stack traces.

```text
Server Error in '/' Application.
Input string was not in a correct format.
Version Information: Microsoft .NET Framework Version:4.0.30319; ASP.NET Version:4.8.4250.0
```

!!! tip "Pour l'attaquant comme pour l'auditeur"
    Un message d'erreur unique peut valider une hypothèse de stack technique et orienter l'intégralité de la suite des tests.

### 5.4 Données de débogage (*Debug Data*)

Messages ou pages de debug personnalisés exposant :

- **Clés de session** ou variables de session.
- **Identifiants backend** (BDD, services tiers).
- **Chemins de fichiers** et configuration serveur.
- **Clés de chiffrement** ou secrets de signature.

```text
# Exemple : page de diagnostic exposée
/debug
/phpinfo.php
/actuator/env
/_profiler/
/console   (Werkzeug / H2 console)
```

!!! warning "Impact majeur"
    Des variables d'environnement ou une clé de signature (JWT, `SECRET_KEY`) exposées peuvent mener à une **compromission complète** (forge de session, exécution de code selon le framework).

### 5.5 Pages de comptes utilisateur

Les pages de profil ou de compte contiennent par nature des données sensibles. Elles deviennent une source de divulgation lorsqu'une **faille d'autorisation** permet d'accéder à des comptes tiers (**IDOR** / *Broken Access Control*).

```http
GET /my-account?id=wiener HTTP/1.1
Host: cible.example
Cookie: session=...

GET /my-account?id=carlos HTTP/1.1
Host: cible.example
Cookie: session=...
```

**Points de test :**

- Modifier les identifiants de paramètres (`id`, `user`, `account`, `uuid`).
- Tester les identifiants prévisibles (incrémentaux) comme non prévisibles (GUID divulgués ailleurs).
- Vérifier si la réponse **redirige** vers une autre page mais **contient quand même** les données dans le corps de la réponse.

### 5.6 Code source via fichiers de sauvegarde & d'historique

#### Révélation du code source et des secrets

L'accès au code source permet à l'attaquant de réaliser un **audit en boîte blanche** de la cible et d'extraire des **secrets hard-codés** (clés API, identifiants de BDD, logique d'authentification).

#### Fichiers de sauvegarde servis en texte brut

Un serveur web **interprète** un fichier `index.php` mais **sert en texte brut** un fichier `index.php.bak` : le code source est alors directement lisible.

| Motif | Exemple |
|---|---|
| Suffixe `~` | `index.php~` |
| Extensions de sauvegarde | `.bak`, `.old`, `.orig`, `.save`, `.copy`, `.tmp` |
| Archives | `backup.zip`, `site.tar.gz`, `dump.sql` |
| Fichiers de swap Vim | `.index.php.swp`, `.index.php.swo` |
| Fichiers d'éditeur | `index.php.swp`, `#index.php#` |

```bash
# Test manuel de variantes
curl -sI https://cible.example/index.php.bak
curl -sI https://cible.example/index.php~
curl -sI https://cible.example/.index.php.swp
```

!!! warning "Dangerosité des fichiers `.bak` exposés en production"
    Un fichier `.bak`, `.old` ou `~` accessible en production expose **l'intégralité du code source** du fichier concerné, avec ses **secrets hard-codés**, sa logique de validation et ses éventuelles vulnérabilités. **Sévérité souvent élevée à critique.**

#### Contrôle de version exposé : dossier `.git`

Le dossier `.git` accessible via `/.git/` permet de **récupérer l'historique complet du dépôt** : code, anciennes versions, branches, messages de commit et **secrets supprimés mais toujours présents dans l'historique**.

```bash
# Vérification de la présence du dépôt
curl -sI https://cible.example/.git/HEAD
curl -s  https://cible.example/.git/config
```

```bash
# Récupération du dépôt pour analyse (dans le cadre d'un audit autorisé)
git-dumper https://cible.example/.git/ ./dump

# Analyse de l'historique local
cd dump
git log --oneline
git show <commit>
git diff <commit_a> <commit_b>
```

!!! warning "Exposition de `.git` : gravité maximale"
    Un dossier `.git` exposé en production donne accès à **tout l'historique du projet**, y compris des **commits où un secret a été « supprimé »**. Supprimer un secret dans un commit ultérieur **ne l'efface pas** de l'historique. Tout secret ainsi exposé doit être considéré comme **compromis et révoqué / renouvelé immédiatement**.

!!! info "Autres artefacts de contrôle de version et de configuration"
    `/.svn/`, `/.hg/`, `/.env`, `/.DS_Store`, `/.idea/`, `/WEB-INF/web.xml`, `composer.json`, `package.json`, `*.js.map`.

### 5.7 Erreurs de configuration serveur

Maintien d'options de débogage ou de diagnostic en production. Exemple classique : la **méthode HTTP `TRACE`**, qui renvoie la requête reçue telle quelle. Elle peut révéler des **en-têtes d'authentification internes** ajoutés par des proxys ou reverse-proxys.

```http
TRACE / HTTP/1.1
Host: cible.example
```

```http
HTTP/1.1 200 OK
Content-Type: message/http

TRACE / HTTP/1.1
Host: cible.example
X-Internal-Auth: 9f8a7c...      <-- en-tête ajouté par un composant interne
X-Forwarded-For: 10.0.0.12
```

```bash
# Test des méthodes autorisées
curl -i -X OPTIONS https://cible.example/
curl -i -X TRACE   https://cible.example/
```

!!! info "Pourquoi c'est dangereux"
    L'en-tête interne révélé peut ensuite être **forgé par l'attaquant** pour contourner une authentification supposée « interne », menant à un accès administrateur ou à un contournement de contrôle d'accès.

---

## 6. Mesures de Prévention & Remédiation

### 6.1 Principes directeurs

1. **Sensibiliser** l'ensemble des équipes (développement, QA, exploitation) aux données considérées comme sensibles, **même celles qui paraissent inoffensives** (versions, chemins, commentaires).
2. **Auditer systématiquement** le code dans les processus de build / QA.
3. **Automatiser** : suppression des commentaires de développement et recherche de secrets dans le pipeline CI/CD.
4. **Uniformiser** les messages d'erreur : réponses **génériques** vers le client, détails **journalisés côté serveur uniquement**.
5. **Désactiver** rigoureusement le debug, les fonctions de diagnostic et les méthodes HTTP superflues en production.
6. **Analyser et sécuriser** la configuration des composants tiers (frameworks, serveurs, CMS, bibliothèques).

### 6.2 Tableau de remédiation par source

| Source | Mesure corrective |
|---|---|
| `robots.txt` / `sitemap.xml` | Ne jamais y lister de chemins sensibles ; protéger les ressources par authentification |
| Commentaires de dev | Minification / suppression automatique au build ; revue de code |
| Messages d'erreur | Pages d'erreur génériques ; logs détaillés côté serveur uniquement |
| Debug data | `DEBUG=false`, retrait des endpoints de diagnostic, contrôle d'accès strict |
| Pages de comptes | Contrôles d'autorisation **côté serveur** sur chaque objet (anti-IDOR) |
| Sauvegardes / `.git` | Ne jamais déployer depuis le dépôt de travail ; bloquer l'accès aux fichiers cachés et aux extensions de sauvegarde |
| Configuration serveur | Désactiver `TRACE`, `autoindex`, bannières de version ; durcissement (*hardening*) |

### 6.3 Exemples de durcissement

**Nginx : bloquer l'accès aux fichiers cachés et de sauvegarde, désactiver les bannières**

```nginx
server_tokens off;

# Interdire l'accès aux fichiers/dossiers cachés (.git, .env, .svn...)
location ~ /\.(?!well-known) {
    deny all;
    return 404;
}

# Interdire les fichiers de sauvegarde et temporaires
location ~* \.(bak|old|orig|save|swp|swo|tmp|sql|log)$|~$ {
    deny all;
    return 404;
}

autoindex off;
```

**Apache : désactiver TRACE, la signature serveur et le listing de répertoires**

```apache
TraceEnable Off
ServerTokens Prod
ServerSignature Off
Options -Indexes

<FilesMatch "(\.(bak|old|orig|save|swp|swo|tmp|sql|log)|~)$">
    Require all denied
</FilesMatch>

<DirectoryMatch "/\.(git|svn|hg)">
    Require all denied
</DirectoryMatch>
```

**PHP : masquer les erreurs côté client, les journaliser côté serveur**

```ini
display_errors = Off
log_errors = On
expose_php = Off
error_log = /var/log/php/error.log
```

### 6.4 Intégration dans la chaîne CI/CD (Secure Development)

```yaml
# Exemple indicatif de job CI : détection de secrets
secret-scan:
  stage: test
  script:
    - gitleaks detect --source . --verbose --redact
    - trufflehog filesystem . --only-verified
```

- **Scan de secrets** (Gitleaks, TruffleHog, detect-secrets) sur chaque commit / pull request.
- **Pre-commit hooks** pour bloquer les secrets avant qu'ils n'atteignent le dépôt.
- **Pipeline de build** qui construit un artefact propre : pas de `.git`, pas de fichiers de sauvegarde, pas de source maps en production (ou protégées).
- **Tests DAST** automatisés (ZAP, Burp Scanner, Nuclei) pour détecter les endpoints de debug et en-têtes bavards.

!!! tip "Principe de défense en profondeur"
    Combinez **prévention** (hygiène de build, configuration durcie), **détection** (scans de secrets, DAST, surveillance des logs) et **réaction** (procédure de rotation immédiate des secrets exposés).

!!! warning "En cas de fuite avérée"
    1. **Révoquer / renouveler** immédiatement tout secret exposé (clés API, mots de passe, tokens, clés de signature).
    2. **Retirer** le contenu exposé et vérifier les caches / CDN / moteurs d'archivage.
    3. **Analyser les logs** pour déterminer si l'information a été consultée.
    4. **Notifier** selon les obligations réglementaires applicables (ex. RGPD en cas de données personnelles).

---

## 7. Récapitulatif pour l'auditeur

| Phase | Action clé | Outil |
|---|---|---|
| Cartographie | Parcours complet + découverte de contenu | Burp Proxy, Discover Content |
| Recherche passive | Commentaires, en-têtes, fichiers robots | Find Comments, Search |
| Recherche active | Fuzzing de paramètres, erreurs provoquées | Intruder, Repeater, Logger++ |
| Fichiers sensibles | Sauvegardes, `.git`, `.env`, debug endpoints | Discover Content, ffuf, Nuclei |
| Contrôle d'accès | Tests IDOR sur les pages de compte | Repeater, Autorize |
| Configuration | Méthodes HTTP, bannières, mode debug | `curl`, Nmap, Nikto |
| Évaluation | Analyse de chaînabilité et sévérité réelle | Revue manuelle |

!!! tip "Règle d'or"
    **Ne jamais sous-estimer une fuite « mineure ».** En Red Team comme en audit, chaque information est une pièce du puzzle : documentez-la, corrélez-la, et évaluez son potentiel de chaînage avant de statuer sur sa criticité.

---

## 8. Références

- [OWASP — Information Exposure](https://owasp.org/www-community/Improper_Error_Handling)
- [OWASP Web Security Testing Guide — Information Gathering](https://owasp.org/www-project-web-security-testing-guide/)
- [PortSwigger Web Security Academy — Information disclosure](https://portswigger.net/web-security/information-disclosure)
- [MITRE CWE-200 : Exposure of Sensitive Information to an Unauthorized Actor](https://cwe.mitre.org/data/definitions/200.html)
- [MITRE CWE-209 : Generation of Error Message Containing Sensitive Information](https://cwe.mitre.org/data/definitions/209.html)
- [MITRE CWE-538 : Insertion of Sensitive Information into Externally-Accessible File or Directory](https://cwe.mitre.org/data/definitions/538.html)
