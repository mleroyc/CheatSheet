# 🛠️ Commande : base64

## 1. Description rapide (Rôle et cas d'usage)

`base64` est un utilitaire qui **encode** et **décode** des données binaires ou textuelles selon le schéma Base64, un format qui représente n'importe quelle séquence d'octets à l'aide de 64 caractères ASCII imprimables (`A-Z`, `a-z`, `0-9`, `+`, `/`, et `=` pour le padding).

!!! danger "Rappel fondamental"
    Base64 est un **schéma d'encodage** destiné au transport de données sur des canaux limités au texte — ce n'est **absolument pas** un chiffrement ni une mesure de sécurité. Toute donnée encodée en Base64 est trivialement réversible, sans clé ni mot de passe.

**Principaux cas d'usage :**

- **Intégration de secrets dans Kubernetes** (champ `data:` des ressources `Secret`, qui exige un encodage Base64).
- **Stockage de certificats/clés** dans des fichiers de configuration ou variables d'environnement (certificats TLS, clés SSH, clés API).
- **Transfert de fichiers binaires sur des canaux textuels** : pièces jointes MIME/email, champs JSON, requêtes HTTP, payloads Web et de pentest (contournement de filtres, exfiltration de données, encodage de charges utiles).

---

## 2. Syntaxe de base

**Encoder :**

```bash
base64 [options] [FICHIER]
```

ou via un pipe :

```bash
echo -n "chaine" | base64
```

**Décoder :**

```bash
base64 -d [options] [FICHIER]
```

ou via un pipe :

```bash
echo "chaine_encodée" | base64 -d
```

---

## 3. Options et fanions principaux

| Option | Forme longue | Description |
|---|---|---|
| `-d` | `--decode` | Décode les données Base64 fournies au lieu de les encoder. |
| `-i` | `--ignore-garbage` | Lors du décodage, ignore les caractères non-Base64 rencontrés au lieu de renvoyer une erreur. |
| `-w COLS` | `--wrap=COLS` | Définit le retour à la ligne automatique tous les `COLS` caractères (défaut : 76). `-w 0` (ou `-w0`) désactive tout retour à la ligne, produisant une sortie sur une seule ligne continue. |

!!! tip "Astuce mémo"
    `-w 0` est l'option la plus utilisée en contexte DevOps/scripting : elle évite d'avoir à recoller manuellement des lignes fragmentées avant d'injecter la valeur dans un JSON, un YAML ou une variable d'environnement.

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Encodage d'une chaîne simple sans saut de ligne

`echo -n` supprime le retour à la ligne final avant l'encodage — critique pour ne pas altérer la valeur encodée :

```bash
echo -n "MonMotDePasse123" | base64
# TW9uTW90RGVQYXNzZTEyMw==
```

### 2. Décodage d'une chaîne encodée

Extrait le contenu lisible depuis un pipeline, via l'option `-d` :

```bash
echo "TW9uTW90RGVQYXNzZTEyMw==" | base64 -d
# MonMotDePasse123
```

### 3. Encodage et décodage d'un fichier binaire complet

Traite un fichier binaire (image, exécutable, archive) et produit sa représentation Base64 dans un fichier texte :

```bash
# Encodage
base64 fichier.png > fichier.b64

# Décodage (reconstruction du fichier binaire original)
base64 -d fichier.b64 > fichier_restaure.png
```

### 4. Utilisation dans Kubernetes / DevOps

Génère les valeurs à insérer dans le champ `data:` d'une ressource `Secret` Kubernetes (qui exige un encodage Base64 sans saut de ligne) :

```bash
echo -n "admin" | base64 -w 0       # -> YWRtaW4=
echo -n "S3cr3tP@ss!" | base64 -w 0  # -> UzNjcjN0UEBzcyE=
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  username: YWRtaW4=
  password: UzNjcjN0UEBzcyE=
```

### 5. Désactivation du wrap (`-w 0`)

Sans `-w 0`, `base64` insère un retour à la ligne tous les 76 caractères par défaut, ce qui casse toute injection directe dans un JSON ou une variable d'environnement :

```bash
# Sortie fragmentée sur plusieurs lignes (comportement par défaut)
base64 certificat.pem

# Sortie sur une seule ligne continue, prête à l'injection
base64 -w 0 certificat.pem
```

### 6. Encodage URL-Safe / Décodage sous Linux

Le Base64 standard utilise `+`, `/` et `=`, des caractères problématiques dans une URL. `tr` permet de convertir vers/depuis une variante URL-safe (RFC 4648 §5) en complément de `base64` :

```bash
# Encodage URL-safe : remplace + par -, / par _
echo -n "data+critique/à==coder" | base64 -w 0 | tr '+/' '-_'

# Décodage : inverse la substitution avant de repasser à base64 -d
echo "ZGF0YSNjcml0aXF1ZS_DoD09Y29kZXI=" | tr '-_' '+/' | base64 -d
```

---

## 5. Astuces & Pièges à éviter

!!! warning "Piège du saut de ligne avec `echo` (`\n`)"
    `echo "mot"` ajoute par défaut un caractère de fin de ligne (`\n`) avant l'encodage, contrairement à `echo -n "mot"`. Le résultat Base64 est donc **différent** entre les deux commandes :

    ```bash
    echo "secret" | base64      # -> c2VjcmV0Cg==  (inclut le \n)
    echo -n "secret" | base64   # -> c2VjcmV0       (sans le \n)
    ```

    Ce piège est particulièrement dangereux pour l'encodage de **mots de passe ou tokens** : un système qui décode la valeur `c2VjcmV0Cg==` obtient `secret\n` au lieu de `secret`, ce qui peut faire échouer silencieusement une authentification. **Toujours utiliser `echo -n`** (ou `printf '%s'`) avant `base64` pour des valeurs sensibles.

!!! danger "Sécurité et faux sentiment de confidentialité"
    Base64 n'apporte **aucune confidentialité**. N'importe qui peut décoder une chaîne Base64 en une fraction de seconde, sans outil spécifique (terminal, navigateur, ou site web quelconque) :

    ```bash
    echo "cGFzc3dvcmQxMjM=" | base64 -d
    # password123
    ```

    Ne **jamais** considérer une donnée "encodée en Base64" comme protégée. Les secrets Kubernetes eux-mêmes ne sont **pas chiffrés** par défaut (seulement encodés) — pour une réelle protection, utiliser un chiffrement au repos (`EncryptionConfiguration`, Sealed Secrets, Vault, SOPS, etc.).

!!! warning "Compatibilité GNU (Linux) vs BSD (macOS)"
    Le comportement de `base64` diffère entre l'implémentation **GNU coreutils** (Linux) et l'implémentation **BSD** (macOS) :

    - **Décodage** : `-d`/`--decode` sur Linux, mais `-D` (majuscule) ou `--decode` sur macOS — `base64 -d` échoue sur certaines versions de macOS.
    - **Wrap** : l'option `-w`/`--wrap` n'existe **pas** sous la même forme sur macOS ; pour désactiver le retour à la ligne ou reformatter la sortie, il faut passer par `fold` :

    ```bash
    # Linux (GNU)
    base64 -w 0 fichier.bin

    # macOS (BSD) — décodage
    base64 -D -i fichier.b64

    # macOS (BSD) — reformattage manuel avec fold si besoin d'un wrap spécifique
    base64 fichier.bin | fold -w 76
    ```

    Pour un script portable multi-plateforme, prévoir une détection de l'OS (`uname`) ou tester la disponibilité des options avant exécution.
