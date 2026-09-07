# 🛠️ Commande : openssl

## 1. Description rapide (Rôle et cas d'usage)

`openssl` est le couteau suisse de la cryptographie en ligne de commande : une boîte à outils complète pour la gestion **SSL/TLS** et **PKI** (Public Key Infrastructure). Il regroupe des dizaines de sous-commandes couvrant la génération de clés, la gestion de certificats, le chiffrement, le hachage et le diagnostic de connexions sécurisées.

**Principaux cas d'usage :**

- **Génération de paires de clés** (RSA, EC, Ed25519) pour l'authentification et le chiffrement.
- **Création de demandes de signature de certificat (CSR)** à soumettre à une Autorité de Certification.
- **Gestion d'Autorités de Certification (CA) internes**, pour des environnements d'entreprise ou de développement.
- **Conversion de formats de certificats** (PEM, DER, PKCS#12) entre outils et plateformes hétérogènes.
- **Chiffrement/déchiffrement de fichiers** avec des algorithmes symétriques (AES, etc.).
- **Inspection et débogage de connexions TLS distantes**, essentiel en diagnostic réseau et en pentest.

---

## 2. Syntaxe de base

**Structure générale :**

```bash
openssl [commande_secondaire] [options_commande] [arguments]
```

`openssl` fonctionne comme une méta-commande : la première partie après `openssl` sélectionne la sous-commande (module) à utiliser, chacune disposant de ses propres options.

**Commandes secondaires principales :**

- `req` : gestion des CSR et création de certificats.
- `x509` : inspection, conversion et signature de certificats X.509.
- `genrsa` : génération de clés RSA (syntaxe historique).
- `pkey` : gestion et conversion de clés (syntaxe moderne, générique à tous les algorithmes).
- `s_client` : client interactif SSL/TLS pour tester des services distants.
- `enc` : chiffrement/déchiffrement symétrique.
- `dgst` : calcul d'empreintes cryptographiques (hash).
- `pkcs12` : gestion des bundles `.pfx` / `.p12`.

---

## 3. Principales sous-commandes et fanions

| Sous-commande | Rôle |
|---|---|
| `openssl req` | Gère les demandes de signature de certificat (CSR) et permet de créer des certificats auto-signés (`-x509`). |
| `openssl x509` | Inspecte (`-text`), convertit (`-outform`) et signe manuellement des certificats au format X.509. |
| `openssl pkey` / `genpkey` | Génère et convertit des clés privées/publiques, pour tout type d'algorithme (RSA, EC, Ed25519) — syntaxe moderne recommandée. |
| `openssl s_client` | Client SSL/TLS interactif permettant de se connecter à un service distant pour inspecter sa chaîne de certificats et sa poignée de main. |
| `openssl enc` | Chiffre/déchiffre des fichiers avec des algorithmes symétriques (AES, ChaCha20, etc.). |
| `openssl dgst` | Calcule des empreintes cryptographiques (MD5, SHA256, SHA512) sur un fichier ou un flux. |
| `openssl pkcs12` | Crée, extrait et manipule des bundles PKCS#12 (`.pfx` / `.p12`) combinant certificat et clé privée. |

!!! tip "Astuce mémo"
    En cas de doute sur les options d'une sous-commande, `openssl <sous-commande> -help` (ou `--help` selon la version) affiche l'aide contextuelle correspondante.

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Génération rapide d'une clé privée et d'un certificat auto-signé (One-Liner)

Crée en une seule commande une clé RSA 4096 bits et un certificat X.509 auto-signé, valable 365 jours :

```bash
openssl req -x509 -newkey rsa:4096 -keyout cle.pem -out cert.pem -days 365 -nodes \
  -subj "/C=FR/ST=Occitanie/L=Tarbes/O=MonOrg/CN=test.local"
```

`-nodes` désactive le chiffrement de la clé privée (pratique pour des environnements de test automatisés, à proscrire en production — voir section 5).

### 2. Création d'une clé et d'une demande de signature (CSR)

Génère une clé privée EC (ou RSA) et le fichier `.csr` associé, destiné à être soumis à une CA :

```bash
# Clé EC (courbe P-256) + CSR
openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -keyout serveur.key -out serveur.csr \
  -subj "/C=FR/O=MonOrg/CN=app.exemple.com"

# Équivalent RSA classique
openssl req -new -newkey rsa:2048 -nodes -keyout serveur.key -out serveur.csr
```

### 3. Inspection et vérification de certificats et CSR (Lecture)

Analyse le contenu lisible d'un certificat au format texte :

```bash
openssl x509 -in cert.crt -text -noout
```

Vérifie uniquement la date d'expiration :

```bash
openssl x509 -in cert.crt -noout -enddate
```

Extrait les noms alternatifs (SAN) :

```bash
openssl x509 -in cert.crt -noout -ext subjectAltName
```

### 4. Test de connexion TLS distante & Débogage (`s_client`)

Inspecte la chaîne de certificats et le déroulement de la poignée de main TLS d'un serveur Web distant :

```bash
openssl s_client -connect domain.com:443 -servername domain.com
```

Pour une sortie non interactive limitée aux informations de certificat (pratique en script) :

```bash
echo | openssl s_client -connect domain.com:443 -servername domain.com 2>/dev/null | openssl x509 -noout -dates -subject -issuer
```

### 5. Conversion de formats de certificats (PEM, DER, PKCS12)

Conversion PEM vers DER :

```bash
openssl x509 -in cert.pem -outform der -out cert.der
```

Conversion PEM (certificat + clé) vers PKCS#12 (`.pfx` / `.p12`) :

```bash
openssl pkcs12 -export -in cert.pem -inkey cle.pem -out bundle.pfx
```

Extraction depuis un `.pfx` vers PEM :

```bash
openssl pkcs12 -in bundle.pfx -out extrait.pem -nodes
```

### 6. Vérification de la correspondance Clé Privée ↔ Certificat

Compare le hash du Modulus du certificat et celui de la clé privée : une correspondance confirme que la clé appartient bien au certificat.

```bash
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in cle.pem | openssl md5
# Les deux empreintes doivent être strictement identiques
```

---

## 5. Astuces, Sécurité & Pièges à éviter

!!! danger "SNI obligatoire avec `s_client`"
    Sur un serveur hébergeant plusieurs sites/vhosts avec des certificats distincts (SNI - Server Name Indication), omettre `-servername` interroge le **certificat par défaut** du serveur — potentiellement différent de celui réellement servi aux clients pour le domaine ciblé, faussant totalement le diagnostic.

    ```bash
    # INCORRECT : peut retourner le certificat du vhost par défaut
    openssl s_client -connect domain.com:443

    # CORRECT : force le SNI, garantit le bon certificat
    openssl s_client -connect domain.com:443 -servername domain.com
    ```

!!! warning "Protection des clés privées"
    Toute clé privée manipulée dans un contexte de production doit être **chiffrée par passphrase** et disposer de **permissions restrictives** au niveau du système de fichiers :

    ```bash
    # Chiffrement AES-256 de la clé privée (demande une passphrase)
    openssl genpkey -algorithm RSA -aes256 -out cle_privee.pem

    # Permissions strictes : lecture/écriture réservées au propriétaire
    chmod 600 cle_privee.pem
    ```

    L'option `-nodes` (No DES — clé non chiffrée) vue dans les exemples 1 et 2 est acceptable pour des tests automatisés jetables, mais **jamais** pour une clé destinée à un environnement de production.

!!! tip "Évolution de la syntaxe (OpenSSL 1.1.1 vs 3.0+)"
    Les commandes historiques spécifiques à un algorithme (`genrsa`, `dsaparam`, `ecparam` combiné à `genkey`) sont progressivement dépréciées au profit d'une syntaxe **générique**, indépendante de l'algorithme, introduite avec `genpkey`/`pkey` :

    ```bash
    # Syntaxe historique (toujours fonctionnelle, mais datée)
    openssl genrsa -out cle.pem 2048

    # Syntaxe moderne recommandée (OpenSSL 1.1.1+, généralisée en 3.0+)
    openssl genpkey -algorithm RSA -out cle.pem -pkeyopt rsa_keygen_bits:2048
    ```

    Privilégier `genpkey`/`pkey` dans tout nouveau script pour garantir la portabilité vers les futures versions d'OpenSSL, notamment lors du passage à des algorithmes modernes (Ed25519, X25519) qui ne disposent pas d'équivalent dans l'ancienne syntaxe.

!!! danger "Certificats modernes et SAN (Subject Alternative Name)"
    Depuis plusieurs années, les navigateurs modernes (Chrome, Firefox) et la plupart des clients TLS **rejettent** les certificats ne comportant pas d'extension **SAN (Subject Alternative Name)**, même si le champ Common Name (CN) est correctement renseigné. Un certificat auto-signé généré sans SAN explicite (comme un `openssl req -x509` basique sans configuration additionnelle) produira des erreurs de validation.

    **Solution :** fournir explicitement l'extension SAN via un fichier de configuration ou l'option `-addext` :

    ```bash
    openssl req -x509 -newkey rsa:4096 -keyout cle.pem -out cert.pem -days 365 -nodes \
      -subj "/CN=app.exemple.com" \
      -addext "subjectAltName=DNS:app.exemple.com,DNS:www.app.exemple.com,IP:127.0.0.1"
    ```
