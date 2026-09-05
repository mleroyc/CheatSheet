# Web Shells — fiche de référence

---

## 1. Principes de fonctionnement & fonctions critiques

| Langage | Fonctions d'exécution système typiques |
|---|---|
| PHP | `system()`, `exec()`, `passthru()`, `shell_exec()`, `popen()`, `proc_open()` |
| ASP / ASP.NET | `Process.Start()`, `Shell()`, `WScript.Shell` (COM object) |
| JSP / Java | `Runtime.getRuntime().exec()`, `ProcessBuilder` |
| Python (CGI/WSGI) | `os.system()`, `subprocess.run()`, `subprocess.Popen()` |

!!! note "Point commun"
    Toutes ces fonctions transmettent une chaîne de caractères contrôlée par l'attaquant directement à l'interpréteur de commandes du système d'exploitation sous-jacent.

### Web Shell vs Reverse/Bind Shell

| | Web Shell | Reverse Shell | Bind Shell |
|---|---|---|---|
| **Canal de communication** | Requêtes HTTP/HTTPS classiques | Connexion sortante initiée par la cible vers l'attaquant | Connexion entrante initiée par l'attaquant vers la cible |
| **Persistance** | Fichier déposé sur le serveur, survit au redémarrage du service web | Généralement en mémoire, non persistant par défaut | Généralement en mémoire, non persistant par défaut |
| **Mode d'exécution** | Synchrone : une commande par requête HTTP, résultat dans la réponse | Asynchrone : session interactive continue | Asynchrone : session interactive continue |
| **Détection réseau** | Se fond dans le trafic HTTP légitime | Connexion sortante inhabituelle, souvent détectable par firewall sortant | Port en écoute inhabituel, détectable par scan interne |

!!! tip "Complémentarité offensive"
    Un web shell sert fréquemment de point d'entrée initial pour déclencher, depuis la commande exécutée, l'établissement d'un reverse shell offrant une session interactive plus confortable que le mode requête/réponse HTTP.

---

## 2. Audit des vulnérabilités d'upload de fichiers

### Principes de validation côté serveur

| Contrôle | Principe | Limite |
|---|---|---|
| **Validation MIME type** | Vérifie l'en-tête `Content-Type` déclaré par le client lors de l'upload | Entièrement falsifiable côté client, aucune garantie |
| **Liste noire d'extensions** | Bloque une liste d'extensions connues comme dangereuses (`.php`, `.jsp`, `.asp`) | Contournable par variantes non listées (`.phtml`, `.php5`, `.pHp`) |
| **Liste blanche d'extensions** | N'autorise qu'un ensemble fini d'extensions explicitement légitimes | Robuste si exhaustive et combinée à d'autres contrôles |
| **Magic Bytes / en-têtes de fichier** | Vérifie la signature binaire réelle du fichier (ex : `FF D8 FF` pour JPEG) | Un fichier peut combiner signature valide et code exécutable (polyglotte) |

```text
Signatures Magic Bytes courantes :
JPEG  : FF D8 FF
PNG   : 89 50 4E 47 0D 0A 1A 0A
GIF   : 47 49 46 38
PDF   : 25 50 44 46
```

!!! warning "Liste noire toujours insuffisante seule"
    Une liste noire d'extensions reste structurellement incomplète face à la diversité des extensions interprétables par un serveur web mal configuré (`.phtml`, `.pht`, `.php7`, `.inc`, `.shtml`...). La liste blanche doit être le mécanisme principal, la liste noire au mieux une défense complémentaire.

### Risques liés au traitement des fichiers téléversés

| Configuration | Risque |
|---|---|
| Upload stocké dans un répertoire exécutable par le serveur web | Exécution directe du fichier déposé via une requête HTTP simple |
| Nom de fichier conservé tel quel (fourni par l'utilisateur) | Path traversal possible via le nom (`../../fichier.php`) |
| Aucune limite de taille ou de type MIME | Déni de service par saturation disque |
| Absence de renommage aléatoire | Prévisibilité du chemin final, facilite l'accès direct au fichier déposé |

!!! tip "Stockage hors-racine web"
    La mesure la plus robuste consiste à stocker les fichiers téléversés hors de l'arborescence servie directement par le serveur web, et à les exposer uniquement via un endpoint applicatif contrôlé qui vérifie les droits d'accès avant de les servir.

---

## 3. Analyse & détection des Web Shells (Blue Team / Forensics)

### Indicateurs de compromission (IoC)

| Indicateur | Explication |
|---|---|
| Requêtes `POST` vers un fichier statique ou un répertoire d'upload | Un répertoire censé ne contenir que des médias ne devrait jamais recevoir de `POST` exécutant du code |
| Fichier avec extension exécutable dans un répertoire d'upload | Signe direct d'un contournement de contrôle d'upload |
| User-Agent absent, générique ou d'outil connu (`curl`, `python-requests`) sur une ressource sensible | Trafic automatisé atypique par rapport à la navigation normale |
| Requêtes répétées avec paramètre unique variable (`?cmd=`, `?x=`) | Motif caractéristique d'une interaction avec un web shell |
| Fichier récemment modifié sans corrélation avec un déploiement connu | Dépôt hors du cycle de release habituel |

### Commandes d'inspection

**Linux**

```bash
grep -rlE "system\(|exec\(|passthru\(|shell_exec\(|eval\(" /var/www/html/
# Recherche récursive de fonctions PHP dangereuses dans l'arborescence web

find /var/www/html/uploads -type f \( -name "*.php" -o -name "*.phtml" -o -name "*.phar" \)
# Recherche de fichiers exécutables dans un répertoire censé ne contenir que des médias

find /var/www/html -type f -mtime -7 -name "*.php"
# Liste les fichiers PHP modifiés durant les 7 derniers jours
```

**Windows**

```cmd
findstr /S /I /M "eval( shell_exec( system( Process.Start" C:\inetpub\wwwroot\*.php *.aspx
:: Recherche récursive de fonctions dangereuses dans l'arborescence web

forfiles /P C:\inetpub\wwwroot\uploads /S /M *.asp* /D -7
:: Liste les fichiers .asp* modifiés durant les 7 derniers jours
```

!!! note "Faux positifs attendus"
    Ces recherches par mot-clé remontent également du code légitime utilisant ces fonctions à des fins non malveillantes ; elles constituent un point de départ d'investigation, pas une confirmation automatique de compromission.

### Bonnes pratiques de sécurisation

```ini
; php.ini — désactive les fonctions d'exécution système les plus critiques
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
```

| Mesure | Principe |
|---|---|
| `disable_functions` (PHP) | Désactive au niveau interpréteur les fonctions d'exécution système non nécessaires à l'application |
| Droits en lecture seule sur les dossiers médias | Le processus web ne doit pas pouvoir écrire de nouveau fichier exécutable dans son propre répertoire servi |
| Séparation exécution / stockage | Le répertoire d'upload ne doit jamais être configuré comme interprétable par le moteur applicatif (directive serveur dédiée) |
| Scan de contenu à l'upload (antivirus/EDR) | Détection de signatures connues de web shells au moment du dépôt |

!!! warning "disable_functions n'est pas une protection absolue"
    Certaines techniques de contournement (LD_PRELOAD, extensions PHP tierces, injection via `mail()` ou `imap_open()` selon configuration) permettent parfois de retrouver une exécution de commandes malgré `disable_functions`. Cette mesure doit s'inscrire dans une défense en profondeur, jamais comme unique rempart.
