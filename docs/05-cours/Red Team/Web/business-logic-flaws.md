# 🧠 Vulnérabilité Web : Failles de Logique Métier (Business Logic Flaws)

!!! info "Résumé express"
    Les failles de logique métier ne reposent pas sur une charge utile « malformée » (SQLi, XSS…) mais sur le **détournement de fonctionnalités légitimes** dans un ordre, un contexte ou avec des valeurs que les concepteurs n'avaient pas prévus. Chaque requête, prise isolément, peut paraître parfaitement valide.

---

## 1. Généralités & Définitions

### 1.1 Définition

Les **failles de logique métier** (*Business Logic Flaws*, ou *Application Logic Vulnerabilities*) sont des défauts de **conception et d'implémentation** qui permettent à un attaquant de provoquer un **comportement indésirable** de l'application en **détournant des fonctionnalités légitimes** pour atteindre un objectif malveillant (fraude, contournement de contrôle d'accès, élévation de privilèges, gain financier, déni de service métier, etc.).

### 1.2 Origine conceptuelle

Le défaut provient de l'**incapacité à anticiper et à sécuriser les états inhabituels ou non linéaires** de l'application : valeurs hors bornes, étapes sautées ou rejouées, combinaisons de fonctionnalités jamais testées ensemble, interactions entre composants aux interprétations divergentes.

### 1.3 Caractéristiques clés

| Caractéristique | Implication pour l'audit |
|---|---|
| **Extrêmement variées** et **hautement spécifiques** à chaque application ou domaine d'activité | Aucune liste de payloads universelle ; il faut raisonner au cas par cas |
| Nécessitent une **expertise humaine** (compréhension fine du métier et des objectifs de l'attaquant) | L'auditeur doit se mettre à la place du développeur *et* du fraudeur |
| **Inefficacité totale des scanners automatisés** | Les outils ne comprennent pas la sémantique métier : ils ne savent pas qu'un prix négatif est absurde |

!!! warning "Non automatisable"
    Un scanner de vulnérabilités (DAST) ne peut ni connaître les règles métier, ni deviner qu'une remise appliquée puis conservée après suppression d'un article constitue une faille. Un rapport « propre » d'un outil automatisé **ne dit rien** sur la robustesse de la logique métier. Ces failles se trouvent **à la main**, avec de la compréhension fonctionnelle et de la curiosité.

---

## 2. Origines de l'Apparition des Failles Logiques

Ces failles résultent presque toujours de **raccourcis mentaux** des équipes de conception et de développement :

- **Hypothèses erronées** sur la façon dont les utilisateurs interagiront avec l'application (« personne ne fera ça »).
- **Postulat naïf** selon lequel les utilisateurs passent **exclusivement par l'interface web officielle** et suivent le parcours prévu, alors qu'un attaquant dialogue directement avec l'API HTTP.
- **Dépendance excessive aux contrôles front-end** (validation JavaScript, champs `readonly`, boutons désactivés, listes déroulantes limitées) qui ne constituent **aucune barrière de sécurité**.
- **Complexité accrue** : systèmes distribués, microservices, composants tiers, chacun avec ses propres hypothèses implicites.
- **Documentation insuffisante** des flux, états attendus et dépendances entre composants.
- **Silos d'équipes** : un module est correct isolément, mais l'**interaction** entre deux modules crée la faille.

!!! info "Principe fondamental"
    Tout ce qui s'exécute côté client est sous le contrôle de l'attaquant. **Le serveur est la seule source de vérité.**

---

## 3. Vecteurs d'Attaque & Cas Pratiques

### A. Confiance excessive dans les contrôles côté client

**Mécanisme.** L'application accepte les données telles que reçues, sans contrôle d'intégrité ni validation rigoureuse côté serveur. Les restrictions existent uniquement dans l'interface (JS, attributs HTML, champs cachés).

**Bypass.** Manipulation directe des requêtes HTTP via un proxy d'interception (Burp Suite, ZAP) ou `curl`, en ignorant totalement le front-end.

Exemple : un prix transmis par le client dans un champ caché.

```http
POST /cart/checkout HTTP/1.1
Host: shop.example.com
Content-Type: application/x-www-form-urlencoded
Cookie: session=abc123

productId=1&quantity=1&price=133700
```

Modification de la valeur contrôlée par le client :

```http
productId=1&quantity=1&price=1
```

Même test en ligne de commande :

```bash
curl -i -X POST 'https://shop.example.com/cart/checkout' \
  -H 'Cookie: session=abc123' \
  -d 'productId=1&quantity=1&price=1'
```

!!! tip "Réflexe d'audit"
    Pour chaque champ, se demander : *« Cette valeur devrait-elle être décidée par le client ? »* Prix, rôle, identifiants d'objet, statuts, drapeaux (`isAdmin`, `discountApplied`, `approved`) ne devraient **jamais** être acceptés tels quels.

---

### B. Incapacité à gérer des entrées non conformes (Boundary & Types)

**Mécanisme.** L'application ne gère pas correctement les valeurs aux limites ou de type inattendu : quantité supérieure au stock réel, **valeurs négatives** pour des entiers (quantités, prix, montants de transfert), valeurs nulles, très grandes (dépassement d'entier), décimales, chaînes là où un nombre est attendu.

**Exemple : quantité négative.** Un panier accepte `-1` et diminue le total à payer, voire crédite le compte.

```http
POST /cart HTTP/1.1
Host: shop.example.com
Content-Type: application/x-www-form-urlencoded
Cookie: session=abc123

productId=2&quantity=-5
```

**Exemple : dépassement d'entier.** Une valeur proche de la limite d'un entier signé 32 bits (`2147483647`) peut provoquer un retour à une valeur négative ou erronée lors d'un calcul de total.

```http
productId=1&quantity=2147483647
```

**Questions clés d'audit :**

- Quelles sont les **limites imposées** aux données (min, max, longueur, type, format) ?
- Que se passe-t-il **lorsque ces limites sont atteintes ou dépassées** (erreur, troncature, saturation, retour à zéro) ?
- Une **normalisation ou transformation** est-elle appliquée en amont (troncature de chaîne, conversion de type, arrondi, changement de casse, décodage d'URL) ? Que se passe-t-il après cette transformation ?

!!! warning "Attention aux transformations silencieuses"
    Une valeur validée *avant* transformation peut devenir dangereuse *après* (troncature qui fait disparaître un suffixe de contrôle, arrondi qui ramène un prix à 0, conversion de casse qui crée une collision avec un compte existant).

---

### C. Hypothèses erronées sur le comportement des utilisateurs & Séquencement

#### C.1 Principe de non-confiance

Le serveur doit **vérifier systématiquement** chaque champ **et** chaque état à chaque requête, sans présumer de ce qui s'est passé dans les requêtes précédentes ni de ce que l'interface permet.

#### C.2 Technique de suppression de paramètres (*Parameter Deletion*)

Principe : **supprimer un paramètre à la fois** (**nom ET valeur**, pas seulement la valeur) pour isoler les chemins d'exécution et observer les traitements distincts.

```http
# Requête d'origine
POST /account/change-password HTTP/1.1
Host: app.example.com
Content-Type: application/x-www-form-urlencoded
Cookie: session=abc123

current-password=Old123!&new-password=New456!&confirm=New456!
```

```http
# Variante 1 : suppression du paramètre current-password
new-password=New456!&confirm=New456!

# Variante 2 : suppression du paramètre confirm
current-password=Old123!&new-password=New456!

# Variante 3 : paramètre présent mais valeur vide
current-password=&new-password=New456!&confirm=New456!
```

Points d'attention :

- Si le code teste `if (param != null) { verifier(param) }`, **l'absence** du paramètre peut **sauter entièrement la vérification**.
- **Suivre les flux multi-étapes jusqu'à leur terme** pour identifier l'impact d'un paramètre amont sur le comportement aval (un paramètre omis à l'étape 1 peut provoquer une anomalie seulement à l'étape 3).

!!! tip "Astuce Burp"
    Dans Repeater, dupliquer la requête, retirer un paramètre à la fois, comparer les réponses (code, longueur, contenu, redirection, cookies) et conserver un tableau de résultats.

#### C.3 Non-respect du workflow prévu (*Flaws of Sequence*)

De nombreux processus (inscription, paiement, authentification multi-facteurs, validation d'un dossier) supposent un **ordre strict** des étapes. Si le serveur ne **vérifie pas l'état d'avancement**, l'attaquant peut manipuler cet ordre pour placer l'application dans un **état inattendu**.

**Exemple : contournement de la 2FA.**

```text
Flux attendu :
  1. POST /login            → identifiants valides
  2. GET  /login/2fa        → saisie du code
  3. POST /login/2fa        → code valide
  4. GET  /account          → accès au compte

Test d'audit :
  1. POST /login            → identifiants valides
  2. GET  /account          → saut direct de l'étape 2 et 3 : accès accordé ?
```

**Navigation forcée (*Forced Browsing*).** Rejouer des requêtes dans un **ordre arbitraire** :

- **sauter** des étapes (aller directement à l'étape finale) ;
- **répéter** une étape (rejouer un bon de réduction, une validation, un remboursement) ;
- **revenir en arrière** (modifier le panier après validation du paiement) ;
- **mélanger les sessions** (démarrer le flux avec un compte, le terminer avec un autre).

**Analyse des erreurs et fuites d'informations.** Les requêtes hors séquence génèrent souvent des **exceptions non gérées** (stack traces, messages verbeux, noms de classes, requêtes SQL) qui **révèlent la logique interne** : noms de variables d'état, étapes attendues, règles de calcul.

!!! warning "Une erreur n'est pas qu'une erreur"
    Une exception provoquée par une requête hors séquence est une **source de renseignement** sur le modèle d'état du serveur, souvent plus précieuse que l'exploitation elle-même.

---

### D. Insécurité spécifique au domaine (*Domain-Specific Flaws*)

**Mécanisme.** Ces vulnérabilités dépendent du **secteur d'activité** (e-commerce, fintech, réseaux sociaux, assurance, SaaS B2B, billetterie…) et des règles propres au métier.

**Exemple classique : gestion des réductions et des prix.**

1. Le panier contient un article à 50 €. Une offre accorde 20 % de remise au-delà de 100 €.
2. L'attaquant **ajoute un article** supplémentaire pour franchir le seuil → la remise est calculée et enregistrée.
3. Il **supprime l'article** ajouté avant le paiement.
4. Si le panier n'est **pas dynamiquement réévalué**, la remise reste appliquée alors que la condition n'est plus remplie.

```text
Étape 1 : POST /cart  productId=A (50 €)      → total 50 €
Étape 2 : POST /cart  productId=B (60 €)      → total 110 € → remise 20 % → 88 €
Étape 3 : POST /cart/remove productId=B       → total attendu 50 €
                                                 total observé (faille) : 40 € (remise conservée)
```

**Autres exemples de scénarios métier à tester :**

- **Codes promotionnels** : cumul de codes, rejeu du même code, alternance entre deux codes pour contourner la règle « un code par commande ».
- **Programmes de fidélité** : transfert ou génération de points en boucle.
- **Fintech** : transferts en parallèle, remboursements supérieurs au paiement initial, arrondis exploitables.
- **Réseaux sociaux** : détournement de mécanismes d'invitation, de parrainage ou de modération.
- **Workflows d'approbation** : l'initiateur peut-il aussi approuver sa propre demande ?

!!! info "Rôle critique de la connaissance du domaine"
    Les effets de bord surgissent des **combinaisons de fonctionnalités complexes**. Sans comprendre ce que l'application est censée faire (et ce que l'entreprise perd si elle échoue), on ne sait même pas quoi chercher.

---

### E. Présence d'un oracle de chiffrement (*Encryption Oracle*)

**Définition.** Un **oracle de chiffrement** est une fonctionnalité où une **entrée contrôlée par l'utilisateur** est **chiffrée par l'application** puis **restituée** à l'utilisateur sous forme de texte chiffré (*ciphertext*), par exemple dans un cookie, un paramètre d'URL ou un jeton.

**Exemple de situation à risque :**

```http
POST /comment HTTP/1.1
Host: blog.example.com
Cookie: session=abc123
Content-Type: application/x-www-form-urlencoded

email=attacker%40example.com&comment=Hello
```

```http
HTTP/1.1 302 Found
Set-Cookie: notification=Zk9vYmFyQmF6UXV4...; HttpOnly
Location: /post?id=7
```

Ici, l'e-mail fourni par l'utilisateur est chiffré avec **la clé du serveur** et renvoyé dans le cookie `notification`.

**Exploitation :**

1. Identifier une fonctionnalité qui chiffre une entrée contrôlée et la restitue (l'**oracle**).
2. Utiliser cet oracle pour **chiffrer des données arbitraires avec la clé du serveur, sans la connaître**.
3. **Réinjecter le ciphertext cross-fonctionnalité** dans d'autres paramètres partageant le **même mécanisme de chiffrement** (ex : cookie de session persistante, jeton d'authentification, jeton de réinitialisation).
4. Si deux fonctionnalités partagent la même clé et le même format, un jeton généré par l'une peut être **accepté par l'autre**, ce qui peut aboutir à une **usurpation d'identité**.

```text
Fonctionnalité A (oracle)       : entrée utilisateur ──chiffre──► notification=<ciphertext>
Fonctionnalité B (authentif.)   : stay-logged-in=<ciphertext> ──déchiffre──► identité utilisateur

Si A et B partagent clé + format, le <ciphertext> de A peut être rejoué dans B.
```

**Rôle symétrique : l'oracle de déchiffrement.** Une fonctionnalité qui **déchiffre** une valeur fournie par l'utilisateur et en révèle le contenu (ou les messages d'erreur associés) permet d'**analyser la structure interne des données** (préfixe, format, séparateurs, longueur) et d'affiner la construction d'un ciphertext valide.

!!! warning "Chiffrement ≠ authenticité"
    Chiffrer une donnée n'en garantit ni l'**intégrité** ni la **provenance**. Utiliser un chiffrement authentifié (AEAD), des **clés distinctes par usage**, et inclure un **contexte** (finalité, expiration) dans la donnée protégée.

---

### F. Divergences d'analyse des adresses e-mail (*Email Parsing Discrepancies*)

**Contexte.** L'analyse syntaxique d'une adresse e-mail est **bien plus complexe qu'il n'y paraît** (normes RFC : commentaires, parties locales entre guillemets, caractères spéciaux, *encoded-words*, domaines internationalisés…).

**Problème.** Une même application utilise souvent **plusieurs composants** pour traiter une adresse (validation front, API, base de données, bibliothèque de messagerie, fournisseur tiers). Si ces composants **interprètent différemment** la même chaîne, un attaquant peut faire passer une adresse **valide aux yeux du filtre** mais **interprétée autrement par le backend**.

**Contournement par encodage/masquage.** Des techniques d'encodage ou de formes syntaxiques exotiques (valides au regard des RFC mais rares) peuvent tromper la validation d'un composant.

```text
# Exemples illustratifs de formes syntaxiques à tester (à adapter à la cible)
user+tag@example.com                       # sous-adressage
"user name"@example.com                    # partie locale entre guillemets
user(commentaire)@example.com              # commentaire RFC
=?utf-8?q?...?=@example.com                # encoded-word (RFC 2047)
```

**Impact typique : élévation de privilèges.** Une application accorde des droits spécifiques (accès administrateur, espace interne) aux adresses d'un **domaine restreint** (ex : `@entreprise.com`).

```text
1. Le filtre front/API vérifie : « le domaine est-il celui de la société ? »  → réponse : NON
   (l'adresse est jugée externe)
2. L'adresse est transmise à un autre composant (envoi du mail de validation,
   analyseur différent) qui l'interprète comme appartenant au domaine restreint.
3. Le compte est créé/validé avec les privilèges du domaine interne.
```

!!! tip "Méthode"
    Tester **chaque point d'entrée** acceptant une adresse e-mail (inscription, invitation, changement d'adresse, SSO, réinitialisation). Observer **où** l'adresse est validée, **où** elle est réutilisée, et si le même résultat de parsing est obtenu partout.

---

## 4. Méthodologie d'Audit & Test des Logiques Métier

### 4.1 Cartographie complète des workflows

- Inventorier **tous les workflows** applicatifs : inscription, authentification, paiement, gestion de profil, invitations, remboursement, export, administration.
- Pour chacun, distinguer :
    - le **Happy Path** (parcours nominal prévu) ;
    - les **Edge Cases** (limites, absence de données, échecs partiels, concurrence, annulation, rejeu).
- Lister pour chaque étape les **hypothèses implicites** du développeur (« ce champ ne peut pas être vide », « l'étape 2 a forcément eu lieu »).

### 4.2 Tests systématiques

| Axe de test | Questions / actions |
|---|---|
| **Limites & types** | Valeurs négatives, zéro, très grandes, décimales, chaînes à la place de nombres, tableaux, `null`, vide |
| **Sauts d'étapes** | Accéder directement à l'étape N+k sans passer par les étapes précédentes |
| **Répétition & rejeu** | Rejouer une même requête (coupon, remboursement, validation) |
| **Retour en arrière** | Modifier un état après une étape censée le verrouiller |
| **Modification des états de session** | Changer de compte/rôle en cours de flux, réutiliser des jetons d'une autre session, mélanger les contextes |
| **Suppression de paramètres** | Retirer nom + valeur, un paramètre à la fois |
| **Concurrence** | Requêtes parallèles sur une même ressource (double dépense, sur-vente de stock) |
| **Parsing & normalisation** | Comparer le comportement des composants face aux mêmes entrées (e-mail, URL, casse, Unicode) |
| **Combinaisons de fonctionnalités** | Enchaîner des fonctions légitimes dans un ordre ou un contexte inhabituel |

### 4.3 État d'esprit de l'auditeur

1. **Comprendre** l'objectif métier de la fonctionnalité.
2. **Identifier** ce que le serveur suppose.
3. **Violer** cette hypothèse (valeur, ordre, rôle, timing).
4. **Observer** l'écart (réponse, état, effet de bord, message d'erreur).
5. **Évaluer l'impact** en termes métier (perte financière, fraude, fuite, compromission).

!!! tip "Outillage"
    Burp Suite (Proxy, Repeater, Intruder, Turbo Intruder pour la concurrence, Logger++), `curl`, scripts Python (`requests`). Les outils servent à **exécuter et comparer**, jamais à **trouver** la faille à votre place.

---

## 5. Mesures de Protection & Remédiation

| Mesure | Détail |
|---|---|
| **Compréhension du domaine** | Assurer une compréhension approfondie du domaine d'activité par les équipes de développement **et** de test (revues avec les métiers, scénarios d'abus ou *abuse cases* en plus des *user stories*) |
| **Zéro hypothèse implicite** | Ne faire aucune supposition sur le comportement des utilisateurs ni sur celui de composants tiers |
| **Validation serveur stricte et centralisée** | Vérifier la cohérence de **toute entrée** avant traitement : type, bornes, format, présence, appartenance, autorisation, état attendu. Centraliser dans une couche unique plutôt que de disséminer les contrôles |
| **Machine à états côté serveur** | Modéliser explicitement les workflows et **refuser toute transition illégitime** (l'état d'avancement est stocké côté serveur, jamais dans un champ client) |
| **Recalcul côté serveur** | Prix, remises, totaux, droits : **toujours recalculés** à partir de données serveur au moment de l'opération sensible (paiement, validation) |
| **Documentation précise** | Documenter les conceptions, les flux de données, les hypothèses d'état et les dépendances croisées entre composants |
| **Cohérence entre composants** | Utiliser **une seule bibliothèque de parsing/normalisation** partagée, ou normaliser une fois puis réutiliser la forme canonique |
| **Cryptographie maîtrisée** | Éviter les oracles de chiffrement : clés distinctes par usage, chiffrement authentifié, contexte lié au jeton |
| **Gestion d'erreurs sûre** | Messages génériques côté client, détails uniquement dans les logs |
| **Tests ciblés** | Tests unitaires/d'intégration des cas limites et abus, revues de code orientées logique, tests d'intrusion manuels réguliers |

### Exemple de validation serveur centralisée (pseudo-code)

```python
def process_order(user, cart_id, payload):
    cart = cart_repository.get(cart_id)

    # 1. Autorisation : le panier appartient-il à l'utilisateur ?
    if cart.owner_id != user.id:
        raise Forbidden()

    # 2. Cohérence de l'état : le panier est-il dans l'état attendu ?
    if cart.state != "READY_FOR_PAYMENT":
        raise InvalidState()

    # 3. Validation stricte des entrées (types, bornes)
    for item in cart.items:
        if not isinstance(item.quantity, int) or not (1 <= item.quantity <= MAX_PER_ORDER):
            raise InvalidInput("quantity")
        if item.quantity > stock.available(item.product_id):
            raise InvalidInput("stock")

    # 4. Recalcul intégral côté serveur (jamais le prix venant du client)
    total = pricing.compute(cart)         # prix catalogue + remises recalculées
    if total <= 0:
        raise InvalidInput("total")

    # 5. Transition d'état explicite
    return payment.charge(user, total)
```

!!! warning "À retenir"
    - Aucun scanner ne détectera ces failles : **l'approche humaine est irremplaçable**.
    - Tout contrôle côté client est **cosmétique**.
    - Chaque étape, chaque paramètre et chaque transition d'état doit être **vérifié par le serveur**.
    - La meilleure défense est une **compréhension partagée du métier** entre développeurs, testeurs et auditeurs.

---

## 6. Aide-mémoire (Cheat Sheet)

- [ ] Les champs sensibles (prix, rôle, statut, ID) sont-ils acceptés depuis le client ?
- [ ] Les valeurs négatives, nulles, extrêmes ou de mauvais type sont-elles correctement rejetées ?
- [ ] Que se passe-t-il quand un paramètre est **supprimé** (nom + valeur) ?
- [ ] Peut-on **sauter**, **répéter** ou **inverser** les étapes d'un workflow ?
- [ ] Les totaux/remises sont-ils **recalculés** à chaque modification et avant paiement ?
- [ ] Existe-t-il une fonctionnalité qui **chiffre/déchiffre** une entrée utilisateur (oracle) ?
- [ ] Les adresses e-mail sont-elles **parsées de façon cohérente** entre tous les composants ?
- [ ] Les messages d'erreur divulguent-ils la logique interne ?
- [ ] Les requêtes concurrentes peuvent-elles contourner une limite (double dépense, stock) ?
- [ ] Les hypothèses métier sont-elles **documentées** et **testées** ?
