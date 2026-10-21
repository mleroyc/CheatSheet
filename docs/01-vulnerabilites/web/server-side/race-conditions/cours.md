---
title: "Race Conditions — Failles de Concurrence Web & Logique"
description: "Référence offensive et défensive sur les race conditions web : TOCTOU, Limit Overrun, HTTP/2 Single-Packet Attack, Turbo Intruder, séquences multi-étapes cachées et remédiation."
tags:
  - web
  - race-condition
  - toctou
  - limit-overrun
  - http2
  - single-packet-attack
  - turbo-intruder
  - business-logic
  - owasp
---

# 🏎️ Vulnérabilité Web & Logique : Race Conditions (Concurrence)

!!! warning "Cadre légal"
    Les techniques décrites ci-dessous ne doivent être mises en œuvre que dans un cadre d'audit autorisé par écrit, ou en environnement de laboratoire. L'exploitation de race conditions sur un système de production peut générer des effets de bord irréversibles (incohérences financières, corruption de données).

---

## 1. Généralités & Concepts Clés

### 1.1 Définition

Une **race condition** est un défaut de **logique métier** survenant lorsqu'une application gère des **requêtes concurrentes sans verrouillage adéquat**, permettant à **plusieurs processus d'interagir simultanément sur les mêmes données** et provoquant des **collisions** dont le résultat diverge du comportement attendu en exécution séquentielle.

### 1.2 La fenêtre de tir (*Race Window*)

!!! info "Une fraction de seconde suffit"
    La **fenêtre de tir** (*race window*) désigne l'infime **fraction de seconde** qui s'écoule entre **deux interactions distinctes** d'une même opération avec la base de données — typiquement entre le moment où le serveur **vérifie** un état et le moment où il **écrit** le résultat de cette vérification. C'est à l'intérieur de cette fenêtre, aussi brève soit-elle, qu'une seconde requête concurrente peut s'intercaler et provoquer une collision exploitable.

### 1.3 Problématique TOCTOU

La très grande majorité des race conditions web relèvent du schéma **TOCTOU** (*Time-Of-Check to Time-Of-Use*) : le **temps de vérification** d'une condition (ex : « ce code promo a-t-il déjà été utilisé ? ») et le **temps d'utilisation** effective de cette condition (ex : « marquer le code promo comme utilisé ») sont **séparés dans le temps**, créant la fenêtre de tir exploitable.

```text
T0 : Requête A — vérification : "le code promo PROMO10 est-il disponible ?" → OUI
T1 : Requête B — vérification : "le code promo PROMO10 est-il disponible ?" → OUI (toujours, car A n'a pas encore écrit)
T2 : Requête A — application de la réduction + écriture "PROMO10 consommé"
T3 : Requête B — application de la réduction + écriture "PROMO10 consommé"
```

!!! danger "Deux applications pour un seul code"
    Dans l'exemple ci-dessus, les requêtes A et B ont toutes deux **lu un état valide** avant qu'aucune des deux n'ait eu le temps d'**écrire** le changement d'état. Le code promo, censé être à usage unique, est appliqué **deux fois**.

---

## 2. Race Condition de Type Limit Overrun

### 2.1 Principe

Le **Limit Overrun** (dépassement de limite) consiste à **contourner une limite métier** — code promo unique, solde bancaire, plafond de votes, quota d'utilisation — en envoyant des **requêtes simultanées** avant que la mise à jour de l'état correspondant ne soit effectivement écrite en base de données.

### 2.2 Mécanisme détaillé en 3 étapes

| Étape | Nom | Action serveur |
|---|---|---|
| **1** | **Vérification (Check)** | Le serveur interroge la base de données pour déterminer si la ressource ou l'action demandée est **disponible / autorisée** |
| **2** | **Application (Use)** | Le serveur **applique l'action** elle-même (ex : application d'une réduction, crédit d'un solde, décompte d'un vote) |
| **3** | **Mise à jour (Update)** | Le serveur **écrit en base** que la ressource vient d'être consommée, pour empêcher toute réutilisation ultérieure |

```text
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  1. CHECK    │ ──► │  2. USE      │ ──► │  3. UPDATE   │
│ "disponible?"│     │ "appliquer"  │     │ "consommé"   │
└──────────────┘     └──────────────┘     └──────────────┘
        ▲                                         │
        └─────────────── FENÊTRE DE TIR ──────────┘
     (toute requête concurrente lancée ici lit encore "disponible")
```

!!! danger "La fenêtre se situe entre l'étape 1 et l'étape 3"
    Tant que l'**étape 3** n'a pas été exécutée, **toute requête concurrente** exécutant sa propre **étape 1** obtiendra le même résultat « disponible », quel que soit le nombre de requêtes déjà engagées dans les étapes 2 ou 3. C'est ce principe qui permet d'appliquer une réduction, un crédit ou un vote un **nombre arbitraire de fois** en multipliant les requêtes simultanées.

### 2.3 Contextes d'application typiques

| Contexte | Exploitation |
|---|---|
| **Cartes cadeaux / codes promo** | Application d'un même code à usage unique sur plusieurs commandes simultanées |
| **Systèmes de vote** | Dépassement du plafond d'un vote par utilisateur (ballot stuffing) |
| **Opérations bancaires** | Transferts ou retraits simultanés dépassant le solde réel disponible (dépassement de découvert non autorisé) |
| **Contournement de rate-limiting** | Envoi de requêtes en rafale avant que le compteur de limitation ne soit incrémenté et vérifié |
| **Réutilisation de CAPTCHA / OTP** | Validation du même jeton à usage unique sur plusieurs requêtes concurrentes avant son invalidation |

---

## 3. Détection & Exploitation (Burp Suite & Turbo Intruder)

### 3.1 Burp Repeater

**HTTP/1 — Technique du dernier octet**

Sous HTTP/1.1, les requêtes multiples envoyées sur des connexions TCP distinctes sont soumises à un **jitter réseau** (variation de latence) qui désynchronise leur arrivée côté serveur, réduisant drastiquement les chances de collision. La technique du **dernier octet** consiste à :

1. Envoyer le **début de chaque requête** (tous les octets sauf le dernier) sur des connexions séparées, préalablement établies.
2. **Retenir volontairement** l'envoi du **dernier octet** de chaque requête.
3. Envoyer ce dernier octet **simultanément** sur l'ensemble des connexions, de sorte que le serveur reçoive et traite l'intégralité de chaque requête **au même instant**, minimisant la fenêtre de désynchronisation réseau.

**HTTP/2 — Attaque par paquet unique (*Single-Packet Attack*)**

!!! tip "La technique la plus puissante disponible à ce jour"
    L'attaque par **paquet unique** (*single-packet attack*), native à l'onglet **Repeater** de Burp Suite pour les cibles HTTP/2, consiste à regrouper **20 à 30 requêtes** au sein d'un **unique paquet TCP**. Le multiplexage natif de HTTP/2 permet d'envoyer plusieurs requêtes sur un même flux de données sans attendre de réponse intermédiaire. En les faisant transiter dans un **seul paquet réseau**, le serveur les reçoit et commence à les traiter de façon quasi simultanée, **éliminant presque entièrement le jitter réseau** qui limitait l'efficacité de la technique du dernier octet sous HTTP/1.

```text
# Dans Burp Suite Repeater :
1. Sélectionner la requête cible (le groupe de requêtes à envoyer en parallèle)
2. Clic droit → "Send group in sequence" devient "Send group in parallel" (HTTP/2 requis)
3. Choisir le mode "single-packet attack"
4. Observer les réponses : codes HTTP, Content-Length, timing
```

!!! warning "Prérequis HTTP/2 indispensable"
    L'attaque par paquet unique **nécessite que la cible supporte HTTP/2**. Si le serveur ou l'infrastructure intermédiaire (CDN, reverse-proxy) ne négocie que HTTP/1.1, il est nécessaire de revenir à la technique du dernier octet, structurellement moins fiable pour fermer des fenêtres de tir très courtes (inférieures à quelques millisecondes).

### 3.2 Turbo Intruder

Pour les scénarios nécessitant une **automatisation avancée** — grand nombre de requêtes, logique conditionnelle, boucles de validation — l'extension **Turbo Intruder** de Burp Suite, pilotée par des **scripts Python**, offre un contrôle fin du *timing* et du volume d'envoi.

**Configuration du moteur pour une attaque par paquet unique**

```python
def queueRequests(target, wordlists):
    engine = RequestEngine(
        endpoint=target.endpoint,
        concurrentConnections=1,      # une seule connexion : requêtes empilées sur le même flux HTTP/2
        engine=Engine.BURP2,          # moteur HTTP/2, condition nécessaire au single-packet attack
    )

    # Le mécanisme de "porte" (gate) retient toutes les requêtes en file
    # jusqu'à ce que le signal d'ouverture soit explicitement donné
    for letter in ['A', 'B']:
        engine.queue(target.req, gate='1')

    # Ouverture simultanée de la porte : toutes les requêtes en attente
    # sont envoyées d'un seul bloc, au même instant
    engine.openGate('1')

def handleResponse(req, interesting):
    table.add(req)
```

| Paramètre | Rôle |
|---|---|
| `Engine.BURP2` | Force l'utilisation du moteur **HTTP/2**, condition nécessaire pour bénéficier du regroupement en paquet unique |
| `concurrentConnections=1` | Contraint **toutes les requêtes** à transiter sur une **unique connexion TCP** multiplexée, maximisant la synchronisation |
| `gate='1'` | Définit un identifiant de **porte** (*gate*) : les requêtes assignées à cette porte sont **mises en file d'attente** sans être envoyées |
| `engine.queue(..., gate='1')` | Place une requête dans la file d'attente associée à la porte, sans l'envoyer immédiatement |
| `engine.openGate('1')` | **Déclenche l'envoi simultané** de toutes les requêtes accumulées derrière la porte `'1'`, réalisant l'effet de paquet unique au niveau applicatif |

!!! tip "Le mécanisme de porte (gate) est la clé de la synchronisation"
    En Turbo Intruder, séparer la **mise en file** (`queue`) de l'**envoi effectif** (`openGate`) est ce qui permet de garantir que toutes les requêtes partent **au même instant précis**, plutôt que les unes après les autres au fil de leur construction. C'est l'équivalent scriptable et automatisable de la technique manuelle du dernier octet / du paquet unique dans Repeater.

---

## 4. Séquences Multi-Étapes Cachées

### 4.1 Principe

Une **unique requête HTTP**, en apparence atomique du point de vue du client, traverse en réalité fréquemment, côté serveur, une **succession de micro-étapes internes** : validation de session, vérification de permissions, mise à jour de plusieurs tables, invalidation de jetons. Chacune de ces micro-étapes introduit un **sous-état temporaire** potentiellement exploitable, même lorsque l'application ne présente, de l'extérieur, qu'un seul point d'entrée apparent.

### 4.2 Exemple du contournement de MFA

Un scénario d'authentification à facteurs multiples typique traverse plusieurs sous-étapes internes lors d'une unique séquence de connexion :

```text
Étape 1 : Validation du mot de passe → création d'une session "pré-MFA"
Étape 2 : (traitement interne, mise à jour de l'état de session)
Étape 3 : Activation effective de l'exigence du code MFA sur la session
```

!!! danger "Fenêtre critique entre l'étape 1 et l'étape 3"
    Entre le moment où le **mot de passe est validé** et la session créée (étape 1), et le moment où l'**exigence MFA devient effectivement active** sur cette session (étape 3), il existe une **fenêtre critique**, aussi brève soit-elle. Si un attaquant parvient à **synchroniser l'accès à une page sensible** (via une attaque par paquet unique HTTP/2) de sorte que cette requête soit traitée par le serveur **avant** que le verrou MFA ne devienne actif, il peut accéder au contenu protégé **sans jamais fournir le second facteur d'authentification**.

```text
# Séquence d'exploitation synchronisée (illustratif)
Requête A (POST /login avec mot de passe valide)      ─┐
Requête B (GET /dashboard, sensible, post-MFA requis)  ─┼─► envoyées en paquet unique HTTP/2
                                                         ┘
Si B est traitée par le serveur avant l'activation effective du verrou MFA
déclenchée par A → accès à /dashboard sans second facteur.
```

!!! tip "Généraliser le principe au-delà du MFA"
    Ce schéma — recherche d'une fenêtre entre une **étape de session initiale** et l'**activation effective d'un contrôle de sécurité** associé — s'applique à de nombreux autres mécanismes séquentiels : vérification d'email, changement de mot de passe avec invalidation de session, processus de paiement en plusieurs étapes, etc. Toute séquence impliquant plusieurs écritures d'état successives pour une même session mérite d'être testée.

---

## 5. Méthodologie de Test & d'Exploitation

### 5.1 Prédire les collisions

Avant toute tentative d'exploitation, **cibler les endpoints critiques à haut risque** susceptibles de modifier un **même enregistrement** en base de données :

- Authentification et gestion de session (login, MFA, déconnexion).
- Réinitialisation de mot de passe (génération et validation de jetons).
- Panier d'achat et processus de commande (ajout, suppression, validation).
- Transferts financiers, crédits de solde, applications de codes promotionnels.

!!! tip "Prioriser par impact métier, pas par volume"
    Un endpoint à faible trafic mais à **fort impact financier ou de sécurité** (ex : endpoint de transfert bancaire) mérite une attention prioritaire, même si sa probabilité de collision « naturelle » en production est faible — c'est précisément cette faible probabilité naturelle qui explique que la faille n'ait jamais été détectée.

### 5.2 Prober (recherche d'indices)

1. **Établir une référence séquentielle (benchmarking)** : envoyer les requêtes **une par une**, de façon strictement séquentielle, et noter le comportement de référence (codes HTTP, `Content-Length`, contenu de la réponse, état final en base si observable).
2. **Envoyer en parallèle** via la technique du **paquet unique** (section 3.1) pour **éliminer le décalage réseau** et maximiser la probabilité de collision.
3. **Traquer les déviations** par rapport à la référence séquentielle :
   - Codes de statut inattendus (`500` révélant une exception non gérée, `409 Conflict` révélant une détection partielle de collision).
   - Variations de `Content-Length` entre les réponses du groupe, signe d'un traitement divergent.
   - **Effets de second ordre** : état final incohérent observable via une requête de vérification ultérieure (solde, compteur, liste d'utilisation) même si chaque réponse individuelle semblait normale.

```bash
# Exemple de vérification d'effet de second ordre après une rafale
curl -s https://cible.com/api/account/balance \
  -H "Authorization: Bearer <token>"
# Comparer le solde observé au solde théorique attendu après l'opération testée
```

### 5.3 Prouver le concept (PoC)

Une fois une déviation identifiée, **nettoyer le superflu** de la requête (en-têtes inutiles, paramètres non pertinents) pour obtenir un **script minimal et reproductible à 100%**, condition indispensable pour :

- Documenter la vulnérabilité de façon exploitable par l'équipe de développement.
- Démontrer la **fiabilité** de l'exploitation (une collision n'apparaissant qu'une fois sur vingt tentatives reste un signal à investiguer, mais un PoC de qualité doit viser une reproductibilité quasi systématique).

---

## 6. Race Conditions Avancées & Subtilités

### 6.1 Race Conditions Multi-Endpoints

Certaines collisions n'impliquent pas des requêtes répétées sur un **même endpoint**, mais l'envoi simultané vers des **routes différentes** partageant un état sous-jacent commun.

```http
POST /cart/add HTTP/1.1
Host: cible.com
Cookie: session=abc123

{"productId": 42, "quantity": 1}
```

```http
POST /cart/checkout HTTP/1.1
Host: cible.com
Cookie: session=abc123
```

Envoyées en parallèle (paquet unique), ces deux requêtes peuvent exploiter une fenêtre où le panier est **validé pour paiement** alors même qu'un article y est **ajouté simultanément**, aboutissant par exemple à la livraison d'un article jamais réellement payé.

!!! info "Réchauffement de connexion (Connection Warming) et bridage de ressources"
    Lors d'une attaque multi-endpoints, le **premier paquet** envoyé sur une connexion nouvellement établie subit parfois un traitement différent (allocation de ressources, initialisation de contexte) du fait du **réchauffement de connexion** (*connection warming*) côté serveur ou infrastructure (TLS handshake, allocation de workers). De même, certains serveurs appliquent un **bridage de ressources** (*throttling*) dès la détection d'un pic de requêtes simultanées sur une même session. Ces deux effets peuvent **fausser les résultats d'un test** en introduisant un délai non lié à la logique métier elle-même : il est recommandé d'établir et de « réchauffer » la connexion par une requête préalable anodine avant de lancer la salve de test proprement dite.

### 6.2 Endpoint unique, paramètres distincts

Certaines architectures entremêlent plusieurs **threads de traitement** utilisant des **paramètres différents au sein de la même session applicative**, créant des collisions inattendues entre contextes utilisateurs théoriquement cloisonnés.

!!! danger "Exemple : fuite de jeton de réinitialisation entre comptes"
    Un scénario documenté consiste en l'envoi simultané de deux requêtes de **réinitialisation de mot de passe** — l'une pour le compte de l'**attaquant**, l'autre pour le compte de la **victime** — vers un endpoint partageant un **pool de threads ou de workers** insuffisamment cloisonné. Dans certaines implémentations défaillantes, le **jeton de réinitialisation destiné à la victime** est renvoyé par erreur dans la **réponse adressée à l'attaquant**, du fait d'un entremêlement de variables de contexte entre threads concurrents traitant les deux requêtes en parallèle.

```http
POST /forgot-password HTTP/1.1
Host: cible.com

{"email": "attaquant@evil.com"}
```

```http
POST /forgot-password HTTP/1.1
Host: cible.com

{"email": "victime@cible.com"}
```

### 6.3 Verrouillage de session

!!! warning "Le piège du verrouillage de session par les frameworks"
    De nombreux frameworks (notamment **PHP**, dans sa configuration par défaut avec les sessions basées sur fichiers) appliquent un **verrouillage de session** côté serveur : toutes les requêtes partageant le **même identifiant de session** sont traitées de façon **strictement séquentielle**, une requête devant attendre la libération du verrou de session par la précédente avant de pouvoir s'exécuter. Ce comportement, invisible pour l'auditeur, **annule silencieusement tout effet de concurrence recherché**, même en cas d'envoi parfaitement synchronisé en paquet unique.

**Contournement : dissocier les requêtes du verrou de session**

Pour contourner ce verrouillage, il convient de fournir à chaque requête du groupe un **identifiant de session ou un cookie distinct**, évitant ainsi que le framework ne les sérialise automatiquement derrière un unique verrou :

```http
# Requête A — cookie de session dédié
POST /redeem-promo HTTP/1.1
Host: cible.com
Cookie: PHPSESSID=session_dediee_A

{"code": "PROMO10"}
```

```http
# Requête B — cookie de session distinct, mais authentifié sur le même compte
POST /redeem-promo HTTP/1.1
Host: cible.com
Cookie: PHPSESSID=session_dediee_B

{"code": "PROMO10"}
```

!!! tip "Obtenir plusieurs sessions valides pour un même compte"
    Selon l'application, plusieurs sessions distinctes et valides pour un même compte peuvent être obtenues en se **ré-authentifiant plusieurs fois** avant de lancer la salve de test (si l'application n'invalide pas les sessions précédentes à chaque nouvelle connexion), ou via tout mécanisme applicatif permettant l'émission de jetons d'API indépendants pour un même utilisateur.

### 6.4 Construction partielle

Certains objets applicatifs sont créés **en plusieurs étapes successives**, laissant transitoirement certains de leurs attributs **non initialisés** ou dans un état incomplet exploitable.

```http
POST /api/create-resource HTTP/1.1
Host: cible.com
Content-Type: application/x-www-form-urlencoded

name=test&api-key[]=
```

!!! info "Exploitation d'un paramètre temporairement vide"
    L'envoi d'un paramètre sous forme de **tableau vide** (`api-key[]=`) peut, selon le langage et le framework, être interprété différemment par la couche de validation initiale et par la couche de traitement ultérieure, créant une **fenêtre de construction partielle** où l'objet existe en base de données avant que l'ensemble de ses attributs de sécurité (ici, une clé API) ne soit effectivement généré et assigné. Une requête concurrente interrogeant cet objet durant cette fenêtre peut alors observer — voire exploiter — un état incomplet (clé API vide, permissions par défaut non restrictives, propriétaire non assigné).

---

## 7. Mesures de Protection & Remédiation

### 7.1 Atomicité des opérations

!!! danger "La transaction SGBD unique comme fondation"
    Toute séquence **vérification → application → mise à jour** décrite en section 2.2 doit être encapsulée dans une **transaction unique au niveau du SGBD**, garantissant son **atomicité** : soit l'intégralité de la séquence s'exécute sans interférence possible d'une autre transaction concurrente, soit aucune n'est appliquée.

```sql
BEGIN;

-- Verrouillage explicite de la ligne concernée pour la durée de la transaction
SELECT solde FROM comptes WHERE id = 42 FOR UPDATE;

-- Logique métier : vérification puis application dans la même transaction
UPDATE comptes SET solde = solde - 100 WHERE id = 42 AND solde >= 100;

COMMIT;
```

!!! tip "SELECT ... FOR UPDATE : verrouillage pessimiste"
    La clause `FOR UPDATE` (ou équivalent selon le SGBD) pose un **verrou exclusif** sur la ou les lignes sélectionnées pour toute la durée de la transaction : toute autre transaction tentant de lire ou modifier ces mêmes lignes via `FOR UPDATE` est mise en **attente** jusqu'à la libération du verrou, éliminant structurellement la fenêtre de tir au niveau de la base de données elle-même — plutôt que de tenter de la fermer au niveau applicatif.

### 7.2 Contraintes d'intégrité natives

Au-delà de l'atomicité transactionnelle, s'appuyer sur les **contraintes natives du SGBD** en **défense en profondeur**, de sorte qu'une collision résiduelle échoue au niveau base de données même si la logique applicative présentait une faille :

```sql
-- Contrainte d'unicité empêchant l'application multiple d'un même code promo
ALTER TABLE utilisations_promo
ADD CONSTRAINT uq_code_promo_unique UNIQUE (code_promo, utilisateur_id);

-- Contrainte empêchant un solde négatif, quelle que soit la logique applicative en amont
ALTER TABLE comptes
ADD CONSTRAINT chk_solde_positif CHECK (solde >= 0);
```

!!! tip "La défense en profondeur protège contre les régressions"
    Une contrainte d'**unicité** ou de **vérification** (`CHECK`) au niveau du schéma de base de données continue de protéger l'application même si une future modification du code applicatif **réintroduit accidentellement** une fenêtre de race condition — contrairement à une logique de vérification purement applicative, qui doit être correctement réimplémentée à chaque nouveau point d'entrée touchant la même donnée.

### 7.3 Cohérence des couches de stockage et des sessions

- **Séparer clairement les couches de stockage** utilisées pour des décisions différentes (ne pas, par exemple, vérifier un état critique dans un cache applicatif rapide mais non transactionnel, tout en écrivant l'état définitif dans une base relationnelle distincte sans synchronisation stricte entre les deux).
- Assurer la **cohérence globale des sessions** : éviter les architectures où plusieurs workers ou threads peuvent traiter des requêtes d'une même session sans partage d'état correctement synchronisé (cf. le piège inverse du verrouillage de session, section 6.3 — l'objectif n'est pas de bloquer toute concurrence légitime, mais de garantir que les données **critiques** sont protégées par un mécanisme de synchronisation adapté).
- **Ne jamais mélanger plusieurs sources de données** (cache local, base relationnelle, service externe) pour une **même décision de sécurité** sans garantie de cohérence forte entre ces sources ; chaque source supplémentaire introduit une fenêtre TOCTOU additionnelle.

### 7.4 Synthèse — checklist de remédiation

- [ ] Toute séquence **check → use → update** sur une donnée critique est encapsulée dans une **transaction atomique unique**
- [ ] Verrouillage pessimiste (`SELECT ... FOR UPDATE`) ou verrouillage optimiste (version/timestamp) appliqué sur les lignes concernées par une opération sensible
- [ ] **Contraintes d'intégrité natives** (unicité, `CHECK`, clés étrangères) déployées en défense en profondeur sur les colonnes critiques
- [ ] Aucune décision de sécurité ne repose sur la **combinaison non synchronisée** de plusieurs sources de données (cache + BDD, service externe + BDD locale)
- [ ] Tests automatisés incluant des **scénarios de charge concurrente** sur les endpoints critiques identifiés en section 5.1
- [ ] Logique de session **auditée** pour écarter tout risque d'entremêlement de contexte entre threads sur un même pool de workers

---

## 8. Références

- [PortSwigger Web Security Academy — Race conditions](https://portswigger.net/web-security/race-conditions)
- [PortSwigger Research — Smashing the state machine: the true potential of web race conditions](https://portswigger.net/research/smashing-the-state-machine)
- [PortSwigger Research — Single-packet attacks: the next generation of HTTP race condition attacks](https://portswigger.net/research/single-packet-attacks)
- [OWASP Testing Guide — Testing for Race Conditions](https://owasp.org/www-project-web-security-testing-guide/)
- [MITRE CWE-362 : Concurrent Execution using Shared Resource with Improper Synchronization ('Race Condition')](https://cwe.mitre.org/data/definitions/362.html)
- [MITRE CWE-367 : Time-of-check Time-of-use (TOCTOU) Race Condition](https://cwe.mitre.org/data/definitions/367.html)
