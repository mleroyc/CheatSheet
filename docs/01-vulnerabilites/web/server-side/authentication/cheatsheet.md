# Vulnérabilités de l'Authentification — Cheat Sheet

## 1. Périmètre et conventions

Cette fiche couvre les techniques offensives sur les mécanismes d'authentification (catégorie OWASP *A07:2021 – Identification and Authentication Failures*), classées selon le cheminement logique d'un test : énumération de comptes, contournement des protections anti-brute-force, bypass du 2FA, forge de cookie de persistance (*remember-me*), faiblesses du workflow de réinitialisation de mot de passe, et IDOR/logique applicative sur le changement de mot de passe.

**Principe directeur commun à toutes les techniques :** une étape du workflow d'authentification délègue, même partiellement, une décision à une donnée fournie par le client (paramètre, en-tête `Host`, tableau JSON, état côté front-end) plutôt qu'à un fait établi côté serveur (session authentifiée).

**Outils utilisés :** Burp Suite (Intruder, Repeater), scripts Python (`requests`), wordlists OSINT.

**Conditions générales :** pentest sous contrat, CTF ou lab autorisé (type PortSwigger Web Security Academy, HackTheBox). Ne jamais appliquer ces tests sans autorisation écrite explicite.

**Conventions des exemples :**

| Placeholder | Signification |
|---|---|
| `cible.exemple` | Nom d'hôte fictif, à remplacer par la cible réelle autorisée |
| `admin` / `victime` | Username cible, générique ou déduit par OSINT |
| `XYZ` / `token` | Jeton de réinitialisation ou de session, à obtenir dans le contexte testé |
| `123` | Identifiant utilisateur (`user_id`) de test, à adapter |

Les comptes, tokens et sessions utilisés dans les exemples doivent être créés dans l'environnement de test ; aucun n'est réutilisable tel quel d'un environnement à l'autre.

---

## 2. Tableau de repérage rapide

| Objectif | Technique ou syntaxe | Quand l'utiliser | Signal attendu | Limite principale |
|---|---|---|---|---|
| Détecter une fuite d'énumération | Comparer `admin`+mdp faux vs `zzzz_test_9999`+mdp faux | Avant toute attaque sur mot de passe | Code/corps/timing différents entre les deux requêtes | Les serveurs durcis renvoient des réponses strictement identiques |
| Construire une liste de comptes valides | Automatiser le différentiel sur une wordlist | Après confirmation d'un canal d'énumération | Sous-ensemble de usernames produisant un signal distinct | Dépend de la fiabilité du signal choisi (timing bruité en réseau) |
| Contourner un rate-limiter par structure de requête | Tableau JSON dans le champ `password` | Après obtention de usernames valides | Compteur de tentatives incrémenté d'une seule unité pour N valeurs testées | Nécessite un endpoint JSON mal validé côté schéma |
| Contourner un rate-limiter par fenêtre glissante | Intercaler des `GET /login` entre tentatives | Le tableau JSON échoue | Compteur réinitialisé malgré les tentatives | Dépend d'une implémentation naïve de la fenêtre glissante |
| Rester sous le seuil de verrouillage par compte | Password spraying (1 mot de passe, N comptes) | Rate-limiter par compte correctement implémenté | Connexion réussie sur un sous-ensemble de comptes | Nécessite une large base de comptes valides |
| Vérifier l'étanchéité serveur du 2FA | Accès direct à `/dashboard` sans soumettre le code OTP | Juste après succès du login étape 1 | Accès accordé sans validation du facteur 2 | Nécessite d'intercepter la réponse post-login (cookie `Set-Cookie`) |
| Contourner le 2FA par substitution de cookie | Soumettre son propre code OTP avec le `2fa_pending` de la victime | L'accès direct échoue | Le serveur valide l'étape 2FA de la victime avec le code de l'attaquant | Nécessite de connaître/intercepter le cookie `2fa_pending` de la victime |
| Forger un cookie *remember-me* | Comparer la structure Base64/Hex de deux cookies sur comptes de longueur différente | Cookie de persistance observé | Pattern lisible (`username:timestamp`) après décodage | Jeton CSPRNG sans structure déductible = non exploitable |
| Contourner la revérification du reset | Altérer/supprimer le `token` dans le `POST` final | Après validation du `GET` avec token valide | Le `POST` aboutit malgré l'absence du token | Le serveur revalide correctement à chaque étape = non exploitable |
| Détourner le lien de reset envoyé par e-mail | En-tête `Host` modifié sur `POST /forgot-password` | Workflow de reset déclenché par e-mail | Le lien généré pointe vers le `Host` arbitraire | L'application doit utiliser `Host` plutôt qu'une URL de config fixe |
| Modifier le mot de passe d'un autre compte | Substituer `user_id` dans `POST /account/change-password` | Authentifié sur un compte de test | Le compte ciblé par `user_id` est modifié, pas celui de la session | L'identité doit être dérivée d'un paramètre client, pas de la session |

Ce tableau sert d'index ; les sections 3 à 5 détaillent chaque technique dans l'ordre du cheminement logique d'un test.

---

## 3. Techniques classées par objectif

### 3.1 Détecter — Énumération de comptes

#### Différentiel de code de statut HTTP

**Objectif :** établir si le serveur distingue un compte existant d'un compte inexistant via le code HTTP renvoyé.

**Quand l'utiliser :** en tout début de test, avant toute tentative de brute force.

**Prérequis :** endpoint de login accessible.

**Syntaxe minimale :**

```http
POST /login HTTP/1.1
Host: cible.exemple
Content-Type: application/x-www-form-urlencoded

username=admin&password=wrongpass
```

**Éléments à personnaliser :** `username` (connu/probable vs manifestement inexistant), `password` (volontairement invalide dans les deux cas).

**Signal attendu :**

```text
Compte existant     -> HTTP/1.1 200 OK   {"error": "Invalid password"}
Compte inexistant   -> HTTP/1.1 404 Not Found   {"error": "User not found"}
```

**Interprétation :** un différentiel de code ou de corps confirme une énumération exploitable via canal auxiliaire. Des réponses strictement identiques (code, corps, en-têtes, timing) indiquent une implémentation durcie — la faille n'est pas exploitable par ce vecteur.

**Limites :** le différentiel peut n'apparaître que sur un sous-ensemble des champs comparés (ex. corps identique mais en-tête différent) ; comparer systématiquement code, corps, en-têtes **et** timing avant de conclure.

**Source :** cours fourni, étape 1 du workflow et §2.3-a.

#### Différentiel de message d'erreur

**Objectif :** identifier une fuite d'information dans le texte du message retourné.

**Quand l'utiliser :** en complément du test de code de statut, notamment si les codes sont identiques.

**Prérequis :** aucun au-delà de l'accès à l'endpoint.

**Syntaxe minimale :** identique à la requête précédente ; comparer uniquement le texte du message.

```text
"Nom d'utilisateur inconnu"   -> fuite d'information
"Identifiants invalides"      -> réponse générique correcte
```

**Signal attendu :** un message distinct selon l'existence du compte.

**Interprétation :** un message explicite (« utilisateur inconnu ») confirme l'énumération même si le code HTTP est identique dans les deux cas.

**Limites :** certains messages sont génériques en apparence mais trahissent l'existence via un détail secondaire (ex. champ `field` pointant vers `username` vs `password`) — lire le corps complet, pas seulement le texte principal.

**Source :** cours fourni, §2.3-b.

#### Timing attack

**Objectif :** détecter une fuite d'information via le temps de traitement du serveur.

**Quand l'utiliser :** lorsque code et message sont strictement identiques.

**Prérequis :** capacité à mesurer un timing fiable (accès réseau stable, nombreuses mesures pour lisser le bruit).

**Syntaxe minimale :** requête identique au test précédent, mesure du délai de réponse.

```text
Compte existant    -> ~150ms (hachage bcrypt/argon2 effectivement calculé)
Compte inexistant  -> ~5ms (serveur court-circuite avant le hachage)
```

**Éléments à personnaliser :** nombre de mesures par compte pour obtenir une moyenne stable.

**Signal attendu :** écart de latence reproductible de plusieurs dizaines de ms entre comptes existants et inexistants.

**Interprétation :** un écart systématique et reproductible confirme l'énumération par timing. Un écart isolé ou non reproductible ne suffit pas — recommencer plusieurs fois avant de conclure.

**Limites :** fortement sensible au bruit réseau et à la charge serveur ; nécessite idéalement un accès local ou un grand nombre d'échantillons pour une conclusion fiable.

**Source :** cours fourni, §2.3-c.

---

### 3.2 Contourner une contrainte identifiée — Anti-brute-force

#### Bypass du rate-limiting par manipulation de structure de requête

**Objectif :** faire comptabiliser plusieurs tentatives de mot de passe comme une seule requête par le rate-limiter.

**Quand l'utiliser :** après obtention d'une liste de usernames valides (étape précédente) ou avec une wordlist générique.

**Prérequis :** endpoint acceptant un corps JSON, validation de schéma potentiellement absente.

**Syntaxe minimale :**

```http
POST /api/login HTTP/1.1
Content-Type: application/json

{"username": "victime", "password": ["pass1","pass2","pass3","pass4"]}
```

**Éléments à personnaliser :** `username`, liste de valeurs dans le tableau `password`.

**Signal attendu :** le compteur de tentatives échouées s'incrémente d'une seule unité malgré plusieurs mots de passe testés dans le même appel.

**Interprétation :** confirme que le framework backend itère sur le tableau sans que le rate-limiter ne compte chaque itération comme une tentative distincte. Un verrouillage après une seule tentative (ou un compteur augmentant de N pour N valeurs) indique une validation stricte du schéma — non exploitable par ce vecteur.

**Limites :** ne fonctionne que si l'endpoint accepte effectivement un tableau là où une valeur scalaire est attendue ; à tester également sur d'autres champs structurés (ex. `username` en tableau).

**Source :** cours fourni, étape 2 du workflow et §2.4.

#### Contournement par fenêtre glissante

**Objectif :** réinitialiser le compteur de tentatives en exploitant une implémentation naïve de la fenêtre glissante.

**Quand l'utiliser :** le bypass par tableau JSON échoue (compteur correctement incrémenté).

**Prérequis :** connaître l'endpoint de login et une route neutre acceptée (`GET /login`).

**Syntaxe minimale :** intercaler une requête `GET /login` entre chaque tentative `POST /login`.

**Éléments à personnaliser :** fréquence d'intercalation, selon la fenêtre de temps observée du rate-limiter.

**Signal attendu :** le seuil de verrouillage n'est jamais atteint malgré un nombre de tentatives `POST` qui le dépasserait normalement.

**Interprétation :** confirme une fenêtre glissante mal implémentée (ex. comptage par requête HTTP totale plutôt que par tentative de login spécifique).

**Limites :** dépend fortement de l'implémentation précise du rate-limiter ciblé ; approche empirique nécessitant plusieurs essais pour calibrer la fréquence.

**Source :** cours fourni, étape 2 du workflow et §2.4.

#### Password spraying

**Objectif :** tester un mot de passe commun sur un grand nombre de comptes, en restant sous le seuil de verrouillage par compte.

**Quand l'utiliser :** le rate-limiter par compte est correctement implémenté (les deux bypass précédents échouent).

**Prérequis :** liste de comptes valides (issue de l'étape d'énumération) ; mot de passe commun plausible (ex. saisonnier `Summer2024!`).

**Syntaxe minimale :** une requête de login par compte, avec le même mot de passe, espacée dans le temps.

**Signal attendu :** connexion réussie sur un sous-ensemble des comptes testés.

**Interprétation :** confirme la réutilisation d'un mot de passe faible/commun par au moins un utilisateur, sans jamais déclencher le verrouillage individuel d'un compte.

**Limites :** taux de succès généralement faible ; nécessite une base de comptes suffisamment large.

**Source :** cours fourni, étape 2 du workflow et §2.4.

---

### 3.3 Confirmer — Bypass du 2FA

#### Accès direct aux ressources protégées sans validation 2FA

**Objectif :** établir si l'état « 2FA validé » est vérifié côté serveur à chaque requête, ou seulement au niveau de l'interface.

**Quand l'utiliser :** immédiatement après un login réussi (username/mot de passe), avant toute soumission de code OTP.

**Prérequis :** intercepter la réponse `Set-Cookie` émise après l'étape 1 du login.

**Syntaxe minimale :**

```text
1. POST /login (username + password) -> 200 OK, redirection vers /2fa
2. Inspecter la réponse Set-Cookie
3. GET /dashboard directement, sans jamais soumettre de code OTP
```

**Signal attendu :** accès accordé à `/dashboard` malgré l'absence de validation du facteur 2.

**Interprétation :** si l'accès est accordé, le cookie de session émis après l'étape 1 est déjà pleinement privilégié et le 2FA n'est qu'une façade côté client — l'ATO est complet dès le login. Un refus (redirection forcée vers `/2fa-verify`, session marquée non privilégiée) indique une vérification serveur correcte.

**Limites :** certaines applications appliquent une vérification partielle (certaines routes protégées, d'autres non) — tester plusieurs ressources sensibles, pas uniquement `/dashboard`.

**Source :** cours fourni, étape 3 du workflow et §3.3-a/b.

#### Substitution de jeton `2fa_pending` entre comptes

**Objectif :** confirmer l'absence de liaison stricte entre le cookie temporaire, le code OTP et le compte visé.

**Quand l'utiliser :** l'accès direct échoue (vérification serveur présente), mais une substitution de session 2FA reste à tester.

**Prérequis :** compte attaquant propre, avec son propre code OTP valide ; connaissance des identifiants de la victime (username + mot de passe, issus d'une étape antérieure).

**Syntaxe minimale :**

```text
1. Attaquant se connecte avec SON compte -> reçoit 2fa_pending=abc123
2. Attaquant initie le login avec le compte VICTIME (identifiants volés)
3. Le serveur génère 2fa_pending=xyz789 pour la victime
4. Attaquant soumet SON propre code OTP avec le cookie xyz789 de la victime
```

**Éléments à personnaliser :** valeurs de cookies selon le contexte réel observé.

**Signal attendu :** le serveur valide l'étape 2FA de la victime avec le code de l'attaquant.

**Interprétation :** confirme l'absence de liaison cryptographique entre le cookie `2fa_pending` et le compte concerné — l'étape 2FA de la victime peut être validée par un code n'appartenant pas à ce compte.

**Limites :** nécessite déjà de connaître les identifiants de la victime (ce test ne contourne que le facteur 2, pas le facteur 1).

**Source :** cours fourni, étape 3 du workflow et §3.3-c.

#### Force brute sur les codes 2FA

**Objectif :** établir si l'espace de recherche limité d'un code OTP (6 chiffres) est protégé par un rate-limiting suffisant.

**Quand l'utiliser :** en complément des tests de bypass logique, sur un code 2FA numérique court.

**Prérequis :** session en attente de validation 2FA (`2fa_pending`).

**Signal attendu :** acceptation d'un code après de nombreuses tentatives, sans invalidation de session.

**Interprétation :** un code à 6 chiffres représente 1 000 000 combinaisons — automatisable en quelques minutes sans rate-limiting ni invalidation après N échecs.

**Limites :** fortement ralenti ou bloqué par un rate-limiting correct (ex. 5 tentatives puis invalidation) — vérifier le comportement après un faible nombre d'essais avant de lancer une attaque complète.

**Source :** cours fourni, §3.4.

---

### 3.4 Confirmer — Forge du cookie "remember-me"

**Objectif :** déterminer si le jeton de persistance est prévisible/forgeable à partir de données connues (username, timestamp).

**Quand l'utiliser :** cookie `remember-me` observé après connexion persistante.

**Prérequis :** capacité à créer deux comptes de test avec des usernames de longueurs différentes.

**Syntaxe minimale :**

```python
# Comparer la structure Base64/Hex des cookies generes pour deux comptes
# de longueurs de username differentes, en isolant les segments qui varient
```

```python
# Exemple de génération vulnérable observable côté serveur
cookie_value = base64.b64encode(f"{username}:{timestamp}".encode())
# ex: YWRtaW46MTcyNzUxMjAwMA== -> "admin:1727512000"
```

**Éléments à personnaliser :** usernames des comptes de test, segments de cookie isolés pour la comparaison.

**Signal attendu :** décodage révélant un pattern lisible (`username:timestamp` en clair, ou un hash reproductible via `MD5(username)`).

**Interprétation :** un pattern déductible permet de reconstruire ou brute-forcer un jeton valide pour un username cible connu, sans jamais connaître le mot de passe. L'absence de structure déductible (entropie uniforme, aucune corrélation observable) indique un jeton probablement généré par CSPRNG — non exploitable par cette méthode.

**Limites :** la plage de timestamps plausibles à brute-forcer peut rester très large sans information complémentaire (heure de création du compte, par exemple) ; approche alternative en cas d'échec : vol de cookie existant via une XSS ailleurs sur l'application, pour analyse hors ligne.

**Source :** cours fourni, étape 4 du workflow et §4.1/4.3.

---

### 3.5 Confirmer — Réinitialisation de mot de passe

#### Absence de revérification du jeton en fin de workflow

**Objectif :** établir si le `token` de reset est revalidé à chaque étape, ou uniquement à l'affichage du formulaire.

**Quand l'utiliser :** sur tout workflow de reset en deux temps (`GET` d'affichage + `POST` de soumission).

**Prérequis :** un `token` valide obtenu légitimement (ex. via une demande de reset sur un compte de test).

**Syntaxe minimale :**

```text
1. GET /reset-password?token=XYZ   -> valide, affiche le formulaire
2. POST /reset-password            -> supprimer ou altérer le token dans le body
```

**Éléments à personnaliser :** valeur du `token` (supprimée ou altérée).

**Signal attendu :** le `POST` aboutit malgré l'absence ou l'altération du `token`.

**Interprétation :** confirme que seule l'étape `GET` (affichage) était protégée, pas l'action de modification elle-même — un attaquant disposant uniquement de l'URL du formulaire (sans le token valide, via referer leak ou historique partagé) peut rejouer le `POST`. Un rejet sans token valide dans le body/session indique une revalidation correcte à chaque étape.

**Limites :** nécessite d'obtenir d'abord l'URL exacte du formulaire affiché (étape `GET`) pour que le test soit représentatif du scénario réel d'exploitation.

**Source :** cours fourni, étape 5 du workflow et §5.3-b.

#### Host Header Injection sur le workflow de reset

**Objectif :** établir si le lien de réinitialisation envoyé par e-mail est construit à partir de l'en-tête `Host` fourni par le client.

**Quand l'utiliser :** le workflow de reset échoue à la revérification précédente, ou en test complémentaire.

**Prérequis :** accès à l'endpoint `POST /forgot-password` et capacité à observer le contenu de l'e-mail généré (boîte de test ou outil d'interception type `interactsh`/Burp Collaborator).

**Syntaxe minimale :**

```http
POST /forgot-password HTTP/1.1
Host: attacker.com
Content-Type: application/x-www-form-urlencoded

email=victime@cible.exemple
```

**Éléments à personnaliser :** valeur de l'en-tête `Host` (domaine contrôlé par l'auditeur), `email` cible.

**Signal attendu :** l'e-mail généré contient un lien pointant vers le `Host` arbitraire soumis.

```text
# E-mail envoyé à la victime :
Cliquez ici pour réinitialiser : http://attacker.com/reset?token=XYZ789
```

**Interprétation :** si le lien reflète le `Host` injecté, un attaquant qui pousse la victime légitime à cliquer sur un lien de reset authentique peut capturer le `token` valide dans ses propres logs serveur, avant la victime elle-même. Un lien généré depuis une valeur de configuration serveur fixe (`APP_BASE_URL`) n'est pas exploitable par ce vecteur.

**Limites :** nécessite que la victime clique réellement sur le lien reçu (composante d'ingénierie sociale) ; le simple fait d'observer le `Host` reflété dans le lien ne constitue qu'une confirmation technique, pas une preuve d'exploitation complète.

**Source :** cours fourni, étape 5 du workflow et §5.3-c.

#### Jetons de reset prédictibles

**Objectif :** établir si le jeton de réinitialisation est généré de façon déductible plutôt qu'aléatoire.

**Quand l'utiliser :** en amont des deux tests précédents, sur tout jeton de reset observé.

**Prérequis :** capacité à générer plusieurs demandes de reset successives pour comparer les jetons produits.

**Exemples de constructions vulnérables :**

```python
token = md5(user.email)
token = str(int(time.time())) + str(user.id)   # séquentiel/déductible
```

**Signal attendu :** un jeton reproductible à partir de données connues (email, timestamp, id utilisateur) plutôt qu'un CSPRNG à haute entropie.

**Interprétation :** un jeton déductible permet de le reconstruire ou de le brute-forcer sans jamais intercepter l'e-mail de reset.

**Limites :** nécessite plusieurs échantillons de jetons pour établir un pattern fiable ; un seul jeton isolé ne permet généralement pas de conclure.

**Source :** cours fourni, §5.3-a.

---

### 3.6 Confirmer — Changement de mot de passe authentifié

#### IDOR — substitution de paramètre d'identité

**Objectif :** établir si le compte ciblé par un changement de mot de passe est dérivé de la session serveur ou d'un paramètre client.

**Quand l'utiliser :** sur tout endpoint de changement de mot de passe authentifié.

**Prérequis :** être authentifié sur un compte de test (session valide) ; connaître l'identifiant d'un second compte de test.

**Syntaxe minimale :**

```http
POST /account/change-password HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Cookie: session=att4ck3r_session_valide

user_id=123&new_password=Hacked123!
```

**Éléments à personnaliser :** `user_id` (identifiant du compte ciblé), `new_password`.

**Signal attendu :** le mot de passe du compte visé par `user_id` est effectivement modifié, et non celui de la session courante.

**Interprétation :** confirme que le serveur fait confiance à un paramètre client pour déterminer le compte cible — un ATO direct sur n'importe quel `user_id` énumérable. Une requête échouant, ou ne modifiant que le compte de la session courante quel que soit `user_id`, indique une dérivation correcte depuis la session.

**Limites :** nécessite un `user_id` valide et énumérable ; sans énumération préalable des identifiants, la portée réelle de l'exploitation reste à établir.

**Source :** cours fourni, étape 6 du workflow et §6.1.

#### Absence de vérification du mot de passe actuel

**Objectif :** établir si un changement de mot de passe exige la confirmation du mot de passe courant.

**Quand l'utiliser :** l'IDOR précédent échoue, ou en test complémentaire — pertinent en cas de session volée (XSS/CSRF/poste partagé).

**Prérequis :** session active (volée ou légitime).

**Syntaxe minimale :**

```http
POST /account/change-password HTTP/1.1
Cookie: session=session_volee_via_xss

new_password=Attacker123!
```

**Signal attendu :** le mot de passe est modifié sans qu'aucun ancien mot de passe n'ait été soumis.

**Interprétation :** un attaquant exploitant une session déjà ouverte peut évincer l'utilisateur légitime sans jamais connaître son mot de passe d'origine.

**Limites :** suppose déjà un accès à une session active (ce test ne crée pas cet accès, il en démontre l'impact).

**Source :** cours fourni, §6.2.

---

### 3.7 Diagnostiquer — Authentification HTTP de base (Basic Auth)

**Objectif :** documenter les faiblesses structurelles d'un endpoint protégé par Basic Auth.

**Quand l'utiliser :** tout endpoint utilisant l'en-tête `Authorization: Basic`.

**Syntaxe minimale :**

```http
GET /admin HTTP/1.1
Host: cible.exemple
Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=
```

**Interprétation :** `YWRtaW46cGFzc3dvcmQxMjM=` est le Base64 (non chiffré, trivialement réversible) de `admin:password123`. Les identifiants sont transmis en clair (encodés, pas chiffrés) à chaque requête ; aucune protection CSRF native ; vulnérable au MITM sans TLS strict ; chaque requête constitue une tentative indépendante, ce qui facilite la force brute en l'absence de rate-limiting dédié.

**Limites :** ce constat est structurel au mécanisme Basic Auth lui-même — il ne nécessite pas de « test » actif au sens des autres techniques, seulement une revue de configuration (présence de TLS, présence d'un rate-limiting compensatoire).

**Source :** cours fourni, §2.5.

---

## 4. Payloads et syntaxes représentatifs

| Intention | Payload de référence | Contexte d'insertion | Variante utile | Différence apportée |
|---|---|---|---|---|
| Énumération de compte | `username=admin&password=wrongpass` | Corps `POST /login` | Remplacer `admin` par un username manifestement inexistant | Isoler l'effet du seul changement de username, à mot de passe identique |
| Bypass rate-limiting par structure | `{"password": ["p1","p2","p3"]}` | Corps JSON `POST /login` | Tester également `username` en tableau | Teste une hypothèse différente (quel champ est itéré sans comptage) |
| Password spraying | Un seul mot de passe commun, N comptes | Corps `POST /login`, requêtes successives | Faire varier le mot de passe testé selon un pattern saisonnier (`Summer2024!`) | Reste sous le seuil de verrouillage par compte, contrairement à un brute force classique |
| Bypass 2FA par accès direct | `GET /dashboard` sans code OTP | Après succès du `POST /login` étape 1 | — | Un seul test suffit : le résultat est binaire (accès accordé ou refusé) |
| Bypass 2FA par substitution | Code OTP de l'attaquant + cookie `2fa_pending` de la victime | Requête de validation OTP | — | Combine deux sessions distinctes, pas une simple variante de payload |
| Forge remember-me | `base64(f"{username}:{timestamp}")` | Valeur du cookie `remember-me` | Faire varier uniquement le `username` entre deux comptes de test | Isole la partie du cookie corrélée au username de celle liée au timestamp |
| Suppression du token de reset | Body `POST /reset-password` sans champ `token` | Étape finale du workflow de reset | Altérer le `token` plutôt que le supprimer | Teste si une valeur invalide est traitée différemment d'une valeur absente |
| Host Header Injection | `Host: attacker.com` | En-tête de `POST /forgot-password` | — | Un seul payload de référence ; l'effet se lit dans le lien généré par l'e-mail, pas dans la réponse HTTP |
| IDOR changement de mot de passe | `user_id=123&new_password=...` | Corps `POST /account/change-password` | Faire varier uniquement `user_id` vers d'autres comptes de test connus | Isole l'effet du paramètre d'identité, à `new_password` constant |

---

## 5. Exemples de requêtes HTTP

### 5.1 Énumération par différentiel de statut

```http
# Référence — username probable
POST /login HTTP/1.1
Host: cible.exemple
Content-Type: application/x-www-form-urlencoded

username=admin&password=wrongpass
```

```http
# Version modifiée — username manifestement inexistant
POST /login HTTP/1.1
Host: cible.exemple
Content-Type: application/x-www-form-urlencoded

username=zzzz_test_9999&password=wrongpass
```

- **Changement clé :** uniquement le `username`, le `password` invalide reste identique.
- **Pourquoi important :** isole l'effet du seul paramètre dont l'existence est testée.
- **Prérequis :** aucun.
- **Signal recherché :** code HTTP, corps de réponse, en-têtes et timing — comparer les quatre dimensions.
- **Ce que cela ne prouve pas seul :** un différentiel de timing isolé (une seule mesure) ne suffit pas ; répéter plusieurs fois avant de conclure à une timing attack exploitable.

### 5.2 Bypass 2FA par accès direct

```http
# Référence — déroulement attendu
POST /login HTTP/1.1
Host: cible.exemple

username=victime&password=motdepasse_correct

# Réponse attendue :
HTTP/1.1 200 OK
Set-Cookie: session=...; HttpOnly
Location: /2fa-verify
```

```http
# Version modifiée — accès direct sans passer par /2fa-verify
GET /dashboard HTTP/1.1
Host: cible.exemple
Cookie: session=<valeur recue a l'etape precedente>
```

- **Changement clé :** omission complète de l'étape de soumission du code OTP.
- **Pourquoi important :** révèle si l'état « 2FA validé » est une contrainte serveur ou une simple redirection côté client.
- **Prérequis :** avoir intercepté le cookie de session émis après l'étape 1.
- **Signal recherché :** code 200 avec contenu de `/dashboard`, plutôt qu'une redirection forcée vers `/2fa-verify`.
- **Ce que cela ne prouve pas seul :** un accès accordé à `/dashboard` ne garantit pas que toutes les ressources protégées souffrent du même défaut — tester plusieurs routes sensibles.

### 5.3 IDOR sur le changement de mot de passe

```http
# Référence — comportement attendu pour son propre compte
POST /account/change-password HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Cookie: session=att4ck3r_session_valide

new_password=NouveauMdp123!
```

```http
# Version modifiée — ciblage d'un compte tiers via user_id
POST /account/change-password HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Cookie: session=att4ck3r_session_valide

user_id=123&new_password=Hacked123!
```

- **Changement clé :** ajout du paramètre `user_id` pointant vers un compte tiers.
- **Pourquoi important :** teste si le serveur dérive l'identité cible de la session ou d'un paramètre client.
- **Prérequis :** connaître l'identifiant d'un second compte de test.
- **Signal recherché :** le mot de passe du compte `123` change effectivement, et non celui de la session de l'attaquant.
- **Ce que cela ne prouve pas seul :** confirme l'IDOR sur ce endpoint précis ; ne garantit pas que d'autres endpoints de gestion de compte souffrent du même défaut.

---

## 6. Outils et commandes

| Outil | Fonction | Quand l'utiliser | Exemple minimal | Limite ou précaution |
|---|---|---|---|---|
| Burp Intruder | Automatisation de requêtes variables (usernames, mots de passe, tokens) | Énumération de comptes, brute force 2FA, password spraying | Positionner le payload sur `username` ou `password`, charger une wordlist | Respecter le rate-limiting et le périmètre autorisé ; peut déclencher un blocage IP |
| Script Python + `requests` | Mesure fine du timing, automatisation de workflows multi-étapes (reset, 2FA) | Timing attack, substitution de jeton 2fa_pending, host header injection | Script envoyant N requêtes et mesurant le délai de réponse | Nécessite de lisser le bruit réseau par répétition des mesures |
| Burp Repeater | Test manuel d'une requête unique, modification rapide de champs | Tests ponctuels (IDOR `user_id`, suppression de `token`, `Host` header) | Modifier un champ puis renvoyer la requête | Peu adapté à des tests nécessitant un grand volume de requêtes |
| Burp Collaborator / `interactsh` | Observer si une URL générée côté serveur pointe vers un domaine contrôlé par l'auditeur | Confirmation du Host Header Injection sur le workflow de reset | Utiliser le domaine fourni comme valeur de l'en-tête `Host` | Nécessite que l'e-mail de reset soit effectivement envoyé et observable |

---

## 7. Signaux caractéristiques et vérifications

| Observation | Ce qu'elle peut indiquer | Vérification complémentaire | Conclusion à éviter |
|---|---|---|---|
| Code HTTP ou message différent entre username connu/inconnu | Énumération de comptes exploitable | Reproduire sur plusieurs usernames pour confirmer la systématicité | Qu'un seul test isolé suffit à conclure, sans répétition |
| Écart de timing entre deux requêtes de login | Énumération par canal temporel | Répéter plusieurs fois pour écarter le bruit réseau | Qu'un seul échantillon de timing constitue une preuve |
| Compteur de tentatives échouées n'augmentant que d'une unité pour un tableau de mots de passe | Bypass de rate-limiting par structure de requête | Confirmer en testant un tableau de taille différente | Que l'absence d'erreur HTTP garantit à elle seule le bypass — vérifier le compteur réel |
| Accès accordé à une ressource protégée sans code OTP soumis | Bypass 2FA par accès direct | Tester plusieurs ressources protégées, pas uniquement une | Qu'un seul endpoint non protégé implique que tout le 2FA est contournable |
| Pattern lisible après décodage Base64/Hex d'un cookie remember-me | Jeton de persistance forgeable | Confirmer sur plusieurs comptes de test pour isoler les segments variables | Qu'une structure apparente sur un seul échantillon est définitivement déductible |
| `POST` de reset acceptant l'absence du `token` | Absence de revérification en fin de workflow | Confirmer que le mot de passe est effectivement changé en base (pas seulement un 200 renvoyé) | Qu'un code 200 seul prouve le changement effectif |
| Lien de reset reflétant le `Host` injecté dans l'e-mail envoyé | Host Header Injection confirmée | Vérifier la réception effective du lien, pas seulement la génération côté serveur | Que la vulnérabilité technique équivaut à une exploitation réussie sans l'étape d'ingénierie sociale |
| Mot de passe d'un `user_id` tiers modifié après soumission sur son propre compte | IDOR sur le changement de mot de passe | Confirmer sur un second `user_id` de test pour écarter une coïncidence | Qu'un seul test réussi généralise automatiquement à tous les `user_id` sans vérification |

**Contrôle comparatif recommandé :** toujours exécuter le scénario légitime (référence) puis le scénario modifié, et comparer explicitement les deux résultats — notamment pour les tests d'énumération et d'IDOR.

---

## 8. Diagnostic rapide des erreurs

| Problème constaté | Causes possibles | Vérification à effectuer | Ajustement pertinent | Ce que cela permet de conclure |
|---|---|---|---|---|
| Aucun différentiel observé en énumération | Réponses réellement uniformisées, ou bruit réseau masquant un écart de timing réel | Répéter le test plusieurs fois, comparer code/corps/en-têtes séparément du timing | Isoler le timing avec davantage d'échantillons avant de conclure | Que ce canal précis ne fuit rien d'observable — pas que l'énumération est impossible par un autre canal |
| Tableau JSON rejeté avec erreur 400 | Validation de schéma stricte côté serveur | Vérifier le message d'erreur exact (rejet de type vs rejet générique) | Tester la fenêtre glissante ou le password spraying classique | Que ce vecteur précis de bypass est fermé, pas que le rate-limiting est globalement robuste |
| Accès à `/dashboard` refusé malgré accès direct | Vérification serveur de l'état 2FA correctement implémentée | Tester d'autres ressources protégées pour écarter une protection partielle | Pivoter vers la substitution de jeton `2fa_pending` | Que ce point d'entrée précis est protégé — pas que l'ensemble du 2FA l'est |
| Cookie remember-me sans structure déductible | Jeton probablement généré par CSPRNG | Comparer sur davantage de comptes de longueurs variées | Pivoter vers le vol de cookie via XSS si disponible ailleurs | Que la forge directe n'est pas praticable ici, pas que le cookie est inattaquable par tout vecteur |
| `POST /reset-password` rejeté sans token valide | Revalidation correcte à chaque étape | Confirmer en testant également une altération partielle du token (pas seulement sa suppression) | Pivoter vers le test Host Header Injection | Que la revérification fonctionne sur ce workflow précis |
| Lien de reset généré ignorant l'en-tête `Host` injecté | URL construite depuis une configuration serveur fixe | Vérifier si une whitelist de `Host` est appliquée en amont | Aucun pivot nécessaire sur ce vecteur | Que ce workflow précis n'est pas vulnérable au Host Header Injection |
| `user_id` injecté sans effet sur le compte ciblé | Identité dérivée correctement de la session serveur | Confirmer qu'aucun autre paramètre (`account_id`, `target_user`...) n'a le même rôle | Pivoter vers le test d'absence de vérification du mot de passe actuel | Que ce paramètre précis n'est pas exploitable — pas que l'endpoint est globalement sûr |

---

## 9. Checklist d'utilisation

- [ ] L'objectif du test est clairement identifié (énumération, bypass 2FA, forge remember-me, reset, IDOR...).
- [ ] Le cheminement logique est respecté : énumération avant brute force, authentification avant 2FA, 2FA avant persistance/reset.
- [ ] Les prérequis de la technique sont réunis (comptes de test, jeton valide obtenu légitimement, session active).
- [ ] Une requête de référence est systématiquement comparée à la requête modifiée.
- [ ] Le signal attendu est défini avant l'envoi du test (code, message, timing, persistance effective).
- [ ] Une observation isolée (un seul échantillon de timing, un seul `user_id` testé) n'est pas présentée comme une preuve définitive.
- [ ] Une seule variable est modifiée à la fois lors des essais (username seul, token seul, `Host` seul).
- [ ] Les résultats importants sont reproduits (plusieurs comptes, plusieurs mesures) avant d'être documentés comme findings.
- [ ] L'impact réel est confirmé (relecture de l'état modifié), pas seulement le code de statut HTTP renvoyé.

---

## 10. Sources et liens de référence

Le document source ne fournit pas de liste de liens dédiée ; les références suivantes sont citées nommément dans le cours et doivent être vérifiées directement auprès de leur organisme émetteur :

- OWASP Top 10 — catégorie *A07:2021 – Identification and Authentication Failures* (owasp.org)
- RFC 6238 — TOTP: Time-Based One-Time Password Algorithm (IETF Datatracker)
- RFC 4226 — HOTP: An HMAC-Based One-Time Password Algorithm (IETF Datatracker)
- `zxcvbn` — bibliothèque d'estimation de robustesse de mots de passe (référencée comme alternative aux règles de complexité rigides)

Pour l'exploitation détaillée d'OAuth 2.0/OIDC (fixation de `redirect_uri`, confusion de `scope`, `state` prévisible), le cours renvoie explicitement à une fiche dédiée, hors périmètre de ce document.
