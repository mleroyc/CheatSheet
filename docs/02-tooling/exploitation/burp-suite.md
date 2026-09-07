# Burp Suite — fiche de triche terrain

---

## 1. Configuration Proxy & Scope

```text
Proxy > Options > Proxy Listeners > 127.0.0.1:8080   :: Listener par défaut, à configurer dans le navigateur
Firefox/Chrome > Paramètres réseau > Proxy manuel > 127.0.0.1:8080
```

### Installation du certificat CA

```text
1. Naviguer vers http://burp (avec le proxy actif dans le navigateur)
2. Cliquer sur "CA Certificate" pour télécharger le certificat au format DER
3. Importer le certificat dans le magasin de confiance du navigateur/OS
```

```bash
openssl x509 -inform DER -in cacert.der -out cacert.pem   # Convertit le certificat DER en PEM
```

!!! warning "Sans certificat CA importé"
    Toute cible en HTTPS renverra une erreur de certificat invalide côté navigateur tant que le certificat CA de Burp n'est pas explicitement importé et marqué de confiance.

### Filtrage du Scope

```text
Target > Scope > Add   :: Ajoute un domaine/IP au périmètre autorisé
Proxy > Options > Intercept Client Requests > "And URL Is in target scope"
Proxy > HTTP history > filtre "Show only in-scope items"
```

!!! tip "Toujours définir le Scope en premier"
    Un Scope correctement filtré réduit drastiquement le bruit dans l'historique Proxy (assets tiers, télémétrie, CDN) et évite d'intercepter accidentellement du trafic hors périmètre autorisé.

---

## 2. Raccourcis clavier & interception

| Raccourci | Action |
|---|---|
| `Ctrl+R` | Envoie la requête sélectionnée vers Repeater |
| `Ctrl+I` | Envoie la requête sélectionnée vers Intruder |
| `Ctrl+Shift+B` | Envoie vers le Comparer |
| `Ctrl+Space` | Exécute la requête dans Repeater |
| `Ctrl+F` | Recherche dans l'onglet actif |
| `Ctrl+Shift+O` | Ouvre les paramètres globaux (Options) |

```text
Proxy > Intercept > "Intercept is on/off"   :: Bascule l'interception des requêtes
Forward   :: Laisse passer la requête interceptée vers sa destination
Drop      :: Bloque définitivement la requête interceptée
```

!!! tip "Interception ciblée"
    Laisser l'interception activée en permanence ralentit la navigation. Activer `Intercept is on` uniquement pour capturer une requête précise (ex : formulaire de login), puis la désactiver pour naviguer normalement.

---

## 3. Repeater & Match and Replace

```text
Repeater > [Onglet requête] > Modifier un en-tête ou paramètre > Ctrl+Space
:: Renvoie la requête modifiée autant de fois que nécessaire, sans repasser par le Proxy
```

| Élément modifiable typique | Exemple |
|---|---|
| En-tête `User-Agent` | Simuler un autre navigateur/client |
| En-tête `Cookie` | Tester une session ou un token différent |
| Paramètre GET/POST | Injecter un payload (SQLi, XSS, LFI) |
| Méthode HTTP | Basculer `GET` en `POST`/`PUT`/`DELETE` |

### Match and Replace

```text
Proxy > Options > Match and Replace > Add
Type: Request header
Match: User-Agent: .*
Replace: User-Agent: Mozilla/5.0 (Custom-Pentest-Agent)
```

```text
Type: Response header
Match: X-Frame-Options: .*
Replace: (vide)
:: Supprime automatiquement un en-tête de sécurité sur chaque réponse, à des fins de test client-side
```

!!! warning "Règles persistantes et globales"
    Une règle Match and Replace s'applique à **tout** le trafic transitant par le proxy tant qu'elle reste active, y compris hors du Scope défini. Penser à la désactiver après usage pour éviter des effets de bord sur d'autres cibles.

---

## 4. Intruder — modes d'attaque & payloads

| Mode | Positions de payload | Comportement |
|---|---|---|
| **Sniper** | Une seule liste, appliquée successivement à chaque position | Teste chaque position isolément, une à la fois |
| **Battering Ram** | Une seule liste, appliquée simultanément à toutes les positions | Même valeur injectée partout à chaque itération |
| **Pitchfork** | Une liste distincte par position | Avance en parallèle sur toutes les listes (position N ↔ valeur N) |
| **Cluster Bomb** | Une liste distincte par position | Teste toutes les combinaisons possibles entre les listes |

```text
Intruder > Positions > Sélectionner le texte à tester > Add §
:: Encadre la position d'injection avec le symbole § (ex : username=§admin§)
```

| Type de payload | Usage typique |
|---|---|
| Simple list | Wordlist statique (utilisateurs, mots de passe courants) |
| Runtime file | Fichier volumineux lu ligne par ligne sans chargement mémoire complet |
| Numbers | Séquence numérique (ex : brute-force d'ID incrémentaux) |
| Character substitution | Génère des variantes orthographiques (leetspeak, casse) |
| Custom iterator | Combine plusieurs jeux de caractères en génération exhaustive |

!!! tip "Cluster Bomb pour un login brute-force classique"
    Deux positions (username, password), deux wordlists distinctes, mode Cluster Bomb : teste l'intégralité des combinaisons username × password, au prix d'un nombre de requêtes multiplicatif.

!!! warning "Version Community : throttling"
    La version gratuite de Burp Suite limite le débit de requêtes d'Intruder, rendant les attaques à grand volume de payloads significativement plus lentes qu'en version Professional.

---

## 5. Modules utiles & extensions

```text
Decoder > Coller le texte > Encode as / Decode as
:: Base64, URL, HTML, Hex, Gzip, ASCII Hex — encodage et décodage à la volée, chaînable
```

```text
Comparer > Send to Comparer (words / bytes)
:: Compare deux requêtes ou réponses pour repérer un différentiel (utile en Boolean-Based Blind SQLi)
```

| Extension BApp Store | Usage |
|---|---|
| **Logger++** | Journalisation avancée et filtrage regex de tout le trafic proxy |
| **Autorize** | Détection automatisée de failles de contrôle d'accès (IDOR, privilege escalation) |
| **Param Miner** | Découverte de paramètres HTTP cachés non documentés |
| **JSON Web Tokens** | Décodage, édition et falsification de tokens JWT |
| **Turbo Intruder** | Attaques à très haut débit via scripting Python, contourne le throttling Community |
| **Active Scan++** | Étend les vérifications du scanner actif (payloads additionnels) |

!!! tip "Extensions Jython/Python"
    Certaines extensions BApp Store (notamment historiques) nécessitent l'installation préalable de Jython dans `Extensions > Extensions settings > Python environment` pour fonctionner correctement.
