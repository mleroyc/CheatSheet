# Modèle IAAA

## 1. Les 4 Piliers du Modèle IAAA

```text
[Identification] → [Authentification] → [Autorisation] → [Imputabilité/Traçabilité]
   "Qui prétends-tu    "Prouve-le"         "Qu'as-tu le      "Que peut-on prouver
    être ?"                                 droit de faire ?"  que tu as fait ?"
```

| Pilier | Définition | Objectif | Exemple concret |
|---|---|---|---|
| Identification | Déclaration d'une identité par un sujet | Associer une action à une entité nommée | Saisie d'un login `jdupont` |
| Authentification | Vérification que l'identité déclarée est authentique | Prouver l'identité par une preuve vérifiable | Mot de passe, empreinte digitale, certificat client |
| Autorisation | Attribution de droits/permissions à une identité authentifiée | Restreindre les actions au strict nécessaire (moindre privilège) | ACL fichier, rôle RBAC `lecteur-financier` |
| Imputabilité / Traçabilité (Accountability) | Capacité à relier une action à son auteur de façon indiscutable | Permettre l'audit, la détection d'abus, la non-répudiation | Log `4624` horodaté + `SubjectUserName` |

!!! note "Ordre logique"
    Les 4 piliers s'enchaînent séquentiellement dans une session type : on **s'identifie**, on **s'authentifie**, le système **autorise** un accès, et chaque action est **tracée**. Un défaut sur un pilier compromet la fiabilité de tous les suivants.

---

## 2. Mécanismes d'Authentification

### Facteurs d'authentification

| Facteur | Catégorie | Exemples |
|---|---|---|
| Ce que l'on **sait** (knowledge) | Type 1 | Mot de passe, code PIN, question secrète |
| Ce que l'on **possède** (possession) | Type 2 | Token OTP, carte à puce, clé FIDO2/U2F, smartphone (SMS/app) |
| Ce que l'on **est** (inherence) | Type 3 | Empreinte digitale, reconnaissance faciale, iris |

### MFA vs 2FA

| Concept | Définition |
|---|---|
| 2FA (Two-Factor Authentication) | Exactement **2** facteurs de catégories **différentes** |
| MFA (Multi-Factor Authentication) | **2 facteurs ou plus**, de catégories différentes (englobe le 2FA) |

!!! warning "Faux MFA"
    Deux mots de passe (ou mot de passe + question secrète) restent tous deux du facteur "savoir" → ce n'est **pas** du MFA, malgré l'apparence de double étape.

### Protocoles d'authentification modernes

| Protocole | Rôle principal | Mécanisme clé | Cas d'usage typique |
|---|---|---|---|
| Kerberos | Authentification réseau via tickets | KDC délivre TGT puis Service Ticket, chiffrement symétrique | Authentification AD Windows (SSO domaine) |
| OAuth 2.0 | **Autorisation** déléguée (pas authentification pure) | Émission de tokens d'accès (`access_token`) via flows (Authorization Code, Client Credentials) | Autoriser une appli tierce à accéder à une API au nom de l'utilisateur |
| OpenID Connect (OIDC) | Authentification, construite **sur** OAuth 2.0 | Ajoute un `id_token` (JWT) contenant l'identité de l'utilisateur | SSO web ("Se connecter avec Google/Microsoft") |
| SAML 2.0 | Authentification + SSO fédéré | Échange d'assertions XML signées entre IdP et SP | SSO d'entreprise vers applications SaaS (legacy) |

```text
Kerberos — flux simplifié
  Client → AS  : demande TGT (avec identifiant)
  AS → Client  : TGT chiffré (clé KDC)
  Client → TGS : demande Service Ticket (présente le TGT)
  TGS → Client : Service Ticket
  Client → Service : présente le Service Ticket → accès autorisé
```

!!! danger "OAuth 2.0 ≠ Authentification"
    OAuth 2.0 est un protocole d'**autorisation** délivrant des jetons d'accès à une ressource — il ne prouve pas nativement l'identité de l'utilisateur final. Utiliser **OIDC** (qui ajoute l'`id_token`) dès qu'une authentification est réellement requise.

---

## 3. Modèles de Contrôle d'Accès

| Modèle | Principe | Qui décide des droits ? | Flexibilité | Cas d'usage typique |
|---|---|---|---|---|
| DAC (Discretionary Access Control) | Le propriétaire de la ressource définit les droits | Le propriétaire de l'objet | Élevée | Partages fichiers Windows/Linux (`chmod`, ACL NTFS) |
| MAC (Mandatory Access Control) | Politique centrale imposée, basée sur des niveaux de classification | Autorité centrale / système | Faible (rigide) | Environnements militaires/gouvernementaux (SELinux, classification Secret/TopSecret) |
| RBAC (Role-Based Access Control) | Droits attribués via des rôles, utilisateurs affectés à des rôles | Administrateur (gestion des rôles) | Moyenne | Entreprise : rôles `RH`, `Comptable`, `Admin-IT` |
| ABAC (Attribute-Based Access Control) | Droits calculés dynamiquement selon attributs (utilisateur, ressource, contexte) | Moteur de règles / policy engine | Très élevée | Cloud, Zero Trust : accès conditionné à l'heure, la localisation, l'appareil |

### Matrice d'évaluation

| Critère | DAC | MAC | RBAC | ABAC |
|---|---|---|---|---|
| Simplicité d'administration | Facile (petite échelle) | Complexe | Moyenne | Complexe |
| Scalabilité (grande organisation) | Faible | Moyenne | Élevée | Élevée |
| Granularité du contrôle | Moyenne | Faible | Moyenne | Très élevée |
| Résistance à l'erreur humaine | Faible (propriétaire décide seul) | Élevée (politique centrale) | Moyenne | Élevée (règles centralisées) |
| Support du contexte dynamique (heure, device, localisation) | Non | Non | Non (nativement) | Oui |

!!! tip "Combinaison des modèles"
    En environnement réel, RBAC (structure des rôles) et ABAC (règles contextuelles Zero Trust) sont fréquemment combinés — RBAC pour l'attribution de base, ABAC en surcouche pour des conditions dynamiques (ex: accès refusé hors VPN d'entreprise).

---

## 4. Traçabilité & Non-Répudiation

| Mécanisme | Rôle |
|---|---|
| Journaux d'audit (audit logs) | Enregistrement horodaté et immuable des actions (qui, quoi, quand, depuis où) |
| Signature numérique | Preuve cryptographique de l'auteur et de l'intégrité d'un document/message |
| Horodatage certifié (RFC 3161) | Preuve de l'existence d'une donnée à un instant T, via un tiers de confiance (TSA) |
| Protection anti-altération des logs | Garantit que les journaux n'ont pas été modifiés a posteriori |

```text
Signature numérique — principe
  Émetteur : hash(document) → chiffrement avec clé PRIVÉE → signature
  Récepteur : déchiffrement signature avec clé PUBLIQUE → comparaison avec hash(document reçu)
              → match = intégrité + authenticité + non-répudiation
```

### Protection contre l'altération des logs

| Technique | Principe |
|---|---|
| Write-Once (WORM) | Stockage en écriture unique, non modifiable après écriture |
| Chaînage cryptographique (hash chaining) | Chaque entrée inclut le hash de la précédente (type blockchain) — toute modification casse la chaîne |
| Envoi temps réel vers collecteur distant | Centralisation immédiate sur un serveur syslog séparé, hors de portée d'un attaquant local |
| Signature périodique des fichiers de log | Hash + signature régulière des logs archivés pour détecter toute modification ultérieure |

!!! danger "Non-répudiation ≠ Authentification seule"
    La non-répudiation exige que l'auteur ne puisse **pas nier** avoir réalisé une action — cela nécessite une preuve cryptographique (signature) en plus de la simple authentification, qui seule ne suffit pas juridiquement.

!!! note "RFC 3227 et logs"
    Lors d'une investigation, les logs doivent être traités comme une preuve numérique : hashés dès collecte, chaîne de traçabilité documentée (voir fiche *digital-forensics-acquisition*).

---

## 5. Défauts d'Implémentation & Vecteurs d'Attaque

| Pilier | Faiblesse courante | Vecteur d'attaque associé |
|---|---|---|
| Identification | Identifiants prévisibles ou énumérables | Username enumeration, OSINT sur formats d'email |
| Authentification | Mots de passe faibles, absence de MFA, stockage en clair/hash faible | Brute force, credential stuffing, password spraying, cassage de hash (MD5/SHA1 non salé) |
| Authentification | Faille dans l'implémentation Kerberos | Kerberoasting, Golden/Silver Ticket, Pass-the-Ticket |
| Authentification | Mauvaise validation des tokens OAuth/OIDC | Token replay, redirect_uri non validé, confused deputy |
| Autorisation | Contrôle d'accès manquant côté serveur (contrôle uniquement côté client) | IDOR (Insecure Direct Object Reference), privilege escalation horizontale/verticale |
| Autorisation | Rôles/permissions mal segmentés (sur-attribution) | Abus de droits légitimes, mouvement latéral via compte sur-privilégié |
| Imputabilité | Logs absents, incomplets ou non protégés | Anti-forensics, effacement de traces (Event ID `1102`), attaque "living off the land" indétectée |
| Imputabilité | Horloge système non synchronisée (pas de NTP) | Corrélation d'événements faussée, timeline d'incident non fiable |

!!! warning "Chaîne de dépendance"
    Une faiblesse sur l'**authentification** invalide la fiabilité de l'**autorisation** (accès obtenu sous fausse identité) et de l'**imputabilité** (logs attribués à la mauvaise personne) — les 4 piliers doivent être renforcés de façon cohérente, pas isolément.
