# John the Ripper — Modes d'Attaque, Formats & Sessions

---

## 1. Modes d'Attaque Principaux

### Wordlist Mode — Dictionnaire
```bash
# Attaque par dictionnaire simple
john hash.txt --wordlist=/usr/share/wordlists/rockyou.txt
```

```bash
# Avec spécification du format de hash
john hash.txt --wordlist=/usr/share/wordlists/rockyou.txt --format=NT
```

```bash
# Avec règles de mutation activées (meilleure couverture)
john hash.txt --wordlist=/usr/share/wordlists/rockyou.txt --rules
```

### Single Crack Mode — Déduction contextuelle
```bash
# Déduit des candidats depuis les métadonnées (nom d'utilisateur, GECOS)
# Le fichier doit être au format login:hash ou GECOS inclus
john hash.txt --single
```

```bash
# Single crack sur un fichier /etc/shadow unshadowed
john shadow_combined.txt --single --format=sha512crypt
```

!!! note "Single Crack Mode"
    John génère des variantes du nom d'utilisateur (`john`, `John`, `john1`, `JOHN`...) et les teste comme mots de passe. Efficace contre les comptes mal configurés. Nécessite le format `user:hash` dans le fichier cible.

### Incremental Mode — Brute-force intégral
```bash
# Brute-force complet avec le jeu de caractères "All" (lent)
john hash.txt --incremental
```

```bash
# Limiter au jeu de caractères "Digits" (chiffres uniquement)
john hash.txt --incremental=Digits
```

```bash
# Limiter au jeu de caractères "Alpha" (lettres uniquement)
john hash.txt --incremental=Alpha
```

### Synthèse — Tableau des modes

| Mode | Flag | Vitesse | Cas d'usage |
| --- | --- | --- | --- |
| Wordlist | `--wordlist=FILE` | Rapide | Premier essai systématique |
| Wordlist + Rules | `--wordlist=FILE --rules` | Moyen | Mots de passe avec variations courantes |
| Single Crack | `--single` | Très rapide | Hash avec métadonnées disponibles |
| Incremental All | `--incremental` | Très lent | Dernier recours, mots de passe courts |
| Incremental Digits | `--incremental=Digits` | Rapide | PINs, codes numériques |

---

## 2. Traitement des Formats & Extraction

### Préparer les fichiers avant le crack

#### Hashes Linux (`/etc/shadow`)
```bash
# Combiner /etc/passwd et /etc/shadow en un seul fichier crackable
unshadow /etc/passwd /etc/shadow > shadow_combined.txt
john shadow_combined.txt --wordlist=/usr/share/wordlists/rockyou.txt
```

#### Archives ZIP protégées
```bash
# Extraire le hash d'une archive ZIP chiffrée
zip2john archive.zip > zip_hash.txt
john zip_hash.txt --wordlist=/usr/share/wordlists/rockyou.txt
```

#### Archives RAR protégées
```bash
# Extraire le hash d'une archive RAR chiffrée
rar2john archive.rar > rar_hash.txt
john rar_hash.txt --wordlist=/usr/share/wordlists/rockyou.txt
```

#### Clés privées SSH protégées
```bash
# Extraire le hash d'une clé SSH chiffrée par passphrase
ssh2john id_rsa > ssh_hash.txt
john ssh_hash.txt --wordlist=/usr/share/wordlists/rockyou.txt
```

#### Autres utilitaires de la suite
```bash
# KeePass (.kdbx)
keepass2john database.kdbx > keepass_hash.txt
```

```bash
# Documents Office chiffrés (.docx, .xlsx)
office2john document.docx > office_hash.txt
```

```bash
# Hash de mot de passe Windows NTLM (depuis un dump SAM)
# Format attendu : user:RID:LMhash:NThash:::
# Coller directement dans un fichier et spécifier --format=NT
john ntlm_hashes.txt --format=NT --wordlist=/usr/share/wordlists/rockyou.txt
```

### Tableau des utilitaires d'extraction

| Source | Utilitaire | Commande |
| --- | --- | --- |
| `/etc/shadow` | `unshadow` | `unshadow /etc/passwd /etc/shadow > out.txt` |
| Archive ZIP | `zip2john` | `zip2john archive.zip > out.txt` |
| Archive RAR | `rar2john` | `rar2john archive.rar > out.txt` |
| Clé SSH | `ssh2john` | `ssh2john id_rsa > out.txt` |
| KeePass `.kdbx` | `keepass2john` | `keepass2john db.kdbx > out.txt` |
| Document Office | `office2john` | `office2john doc.docx > out.txt` |
| PDF protégé | `pdf2john` | `pdf2john document.pdf > out.txt` |

---

## 3. Spécification des Formats & Masques

### Identifier et forcer le format de hash
```bash
# John tente l'auto-détection mais elle peut être incorrecte → toujours forcer le format
john hash.txt --format=NT                  # NTLM (Windows)
john hash.txt --format=md5crypt            # MD5 Linux ($1$)
john hash.txt --format=sha256crypt         # SHA-256 Linux ($5$)
john hash.txt --format=sha512crypt         # SHA-512 Linux ($6$)
john hash.txt --format=bcrypt              # bcrypt ($2y$)
john hash.txt --format=raw-md5             # MD5 brut (non salé)
john hash.txt --format=raw-sha1            # SHA-1 brut (non salé)
john hash.txt --format=raw-sha256          # SHA-256 brut (non salé)
```

```bash
# Lister tous les formats supportés
john --list=formats
```

```bash
# Filtrer les formats par nom
john --list=formats | grep -i "ntlm\|krb\|net"
```

### Tableau des formats courants

| Hash / Source | Format John | Préfixe / Signature |
| --- | --- | --- |
| NTLM (Windows) | `NT` | Pas de préfixe |
| MD5crypt Linux | `md5crypt` | `$1$` |
| SHA-256crypt Linux | `sha256crypt` | `$5$` |
| SHA-512crypt Linux | `sha512crypt` | `$6$` |
| bcrypt | `bcrypt` | `$2a$` / `$2y$` |
| MD5 brut | `raw-md5` | 32 hex |
| SHA-1 brut | `raw-sha1` | 40 hex |
| SHA-256 brut | `raw-sha256` | 64 hex |
| NetNTLMv2 | `netntlmv2` | Format Responder |
| Kerberos 5 AS-REP | `krb5asrep` | `$krb5asrep$` |

### Attaque par masque (--mask)
```bash
# Masque : ?l=minuscule ?u=majuscule ?d=chiffre ?s=symbole ?a=tous
# Tester toutes les combinaisons de 8 caractères minuscules + chiffres
john hash.txt --mask='?l?l?l?l?d?d?d?d'
```

```bash
# Mot de passe avec majuscule initiale, 6 minuscules, 2 chiffres
john hash.txt --mask='?u?l?l?l?l?l?l?d?d'
```

```bash
# Longueur variable : tester de 6 à 8 caractères (avec --min-length/--max-length)
john hash.txt --mask='?a?a?a?a?a?a?a?a' --min-length=6 --max-length=8
```

| Masque | Jeu de caractères |
| --- | --- |
| `?l` | `abcdefghijklmnopqrstuvwxyz` |
| `?u` | `ABCDEFGHIJKLMNOPQRSTUVWXYZ` |
| `?d` | `0123456789` |
| `?s` | `!@#$%^&*()...` (symboles) |
| `?a` | `?l?u?d?s` (tous) |

---

## 4. Règles de Mutation & Gestion des Sessions

### Règles de mutation (`--rules`)
```bash
# Appliquer les règles par défaut (Jumbo ruleset sur JtR communautaire)
john hash.txt --wordlist=rockyou.txt --rules
```

```bash
# Appliquer un jeu de règles spécifique
john hash.txt --wordlist=rockyou.txt --rules=Jumbo
john hash.txt --wordlist=rockyou.txt --rules=KoreLogic
john hash.txt --wordlist=rockyou.txt --rules=Single
```

```bash
# Lister les jeux de règles disponibles
john --list=rules
```

### Mutations appliquées par les règles (exemples)

| Règle | Exemple |
| --- | --- |
| Capitalisation | `password` → `Password` |
| Majuscules | `password` → `PASSWORD` |
| Leet speak | `password` → `p@ssw0rd` |
| Ajout de chiffres | `password` → `password1`, `password123` |
| Suffixe année | `password` → `password2023` |
| Préfixe + suffixe | `password` → `!password!` |
| Inversion | `password` → `drowssap` |
| Duplication | `pass` → `passpass` |

### Gestion des sessions
```bash
# Démarrer une session nommée (reprise possible en cas d'interruption)
john hash.txt --wordlist=rockyou.txt --session=mission_client
```

```bash
# Reprendre une session interrompue (Ctrl+C ou crash)
john --restore=mission_client
```

```bash
# Reprendre la dernière session (sans nommer)
john --restore
```

### Affichage des résultats crackés
```bash
# Afficher les mots de passe trouvés pour un fichier de hashes
john hash.txt --show
```

```bash
# Afficher avec spécification du format (si auto-détection incorrecte)
john hash.txt --show --format=NT
```

```bash
# Compter le nombre de hashes crackés vs total
john hash.txt --show | tail -1
# Output : 3 password hashes cracked, 7 left
```

!!! warning "Fichier ~/.john/john.pot"
    Tous les mots de passe crackés sont mis en cache dans `~/.john/john.pot`. Si un hash a déjà été cracké, John **ne le recracke pas** même avec une nouvelle wordlist. Supprimer `john.pot` (ou utiliser `--pot=nouveau_fichier`) pour forcer un nouveau scan complet.
