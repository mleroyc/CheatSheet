# Le protocole DNS — théorie et configuration

Cheat sheet sur le fonctionnement du DNS (Domain Name System), son architecture, ses enregistrements et sa configuration côté système Linux.

---

## Architecture & mécanisme de résolution

### Arborescence DNS

Le DNS est structuré en arbre hiérarchique inversé, chaque niveau étant délégué au suivant.

```text
.                     # Root — la racine, représentée par un point implicite
├── .com               # TLD générique
│   └── domain.com          # Domaine enregistré
│       └── www.domain.com  # Sous-domaine
├── .fr                # TLD national (ccTLD)
│   └── exemple.fr
└── .org, .net, .io    # Autres TLD
```

!!! info "Le point final"
    Un nom de domaine pleinement qualifié (FQDN) se termine techniquement par un point : `www.domain.com.`. Ce point représente la racine et est généralement omis par confort dans l'usage courant.

### Résolution récursive vs itérative

Deux rôles coexistent dans une résolution DNS complète :

- **Requête récursive** : le client demande au résolveur une réponse finale et complète. Le résolveur se charge de tout le travail.
- **Requête itérative** : le résolveur interroge successivement chaque serveur de la chaîne, chacun renvoyant soit la réponse, soit l'adresse du serveur suivant à contacter.

```text
Client → Cache local (OS/navigateur) → cache miss
       → Resolver (FAI, 8.8.8.8, 1.1.1.1...)
             ├──▶ Root Server ('.')      → adresse du TLD
             ├──▶ TLD Server ('.com')    → adresse du serveur autoritaire
             └──▶ Authoritative Server   → réponse finale (IP, MX...)
       → Réponse renvoyée au client (mise en cache selon le TTL)
```

!!! info "Rôle du TTL"
    Chaque enregistrement possède un TTL (Time To Live, en secondes) qui détermine sa durée de mise en cache. Un TTL court facilite les changements rapides (bascule d'infrastructure) mais augmente la charge sur les serveurs autoritaires.

---

## Types d'enregistrements DNS

| Type | Nom complet | Rôle | Exemple de valeur |
|---|---|---|---|
| `A` | Address | Associe un nom à une adresse IPv4 | `192.0.2.10` |
| `AAAA` | IPv4 Address (v6) | Associe un nom à une adresse IPv6 | `2001:db8::1` |
| `CNAME` | Canonical Name | Alias vers un autre nom de domaine | `www` → `domain.com` |
| `MX` | Mail Exchange | Désigne le(s) serveur(s) de messagerie, avec priorité | `10 mail.domain.com` |
| `NS` | Name Server | Indique les serveurs faisant autorité sur la zone | `ns1.domain.com` |
| `TXT` | Text | Stocke des données arbitraires (SPF, DKIM, DMARC, validations) | `v=spf1 include:_spf... ~all` |
| `PTR` | Pointer | Résolution inverse, IP vers nom (zone `in-addr.arpa`) | `10.2.0.192.in-addr.arpa` |
| `SOA` | Start of Authority | Décrit la zone : serveur primaire, contact, TTL par défaut, numéro de série | — |

!!! info "TXT et sécurité mail"
    Trois mécanismes anti-spoofing s'appuient sur les TXT : **SPF** (serveurs autorisés à envoyer), **DKIM** (signature cryptographique) et **DMARC** (politique appliquée en cas d'échec SPF/DKIM).

---

## Fichiers & configuration système (Linux)

### Ordre de résolution — `/etc/nsswitch.conf`

Définit l'ordre des sources consultées pour résoudre un nom (fichiers locaux, DNS, etc.).

```bash
cat /etc/nsswitch.conf | grep hosts   # Affiche l'ordre de résolution configuré
```

```text
hosts: files dns    # Consulte d'abord /etc/hosts, puis le DNS
```

### Fichier hôte local — `/etc/hosts`

Résolution statique, prioritaire sur le DNS si `nsswitch.conf` place `files` en premier.

```bash
cat /etc/hosts                        # Affiche les résolutions statiques locales
# 127.0.0.1       localhost
# 192.168.1.50    serveur-interne.local
```

### Résolveurs classiques — `/etc/resolv.conf`

Définit les serveurs DNS interrogés par le système (souvent généré automatiquement).

```bash
cat /etc/resolv.conf                  # Affiche les résolveurs DNS configurés
# nameserver 8.8.8.8     -> serveur DNS primaire
# nameserver 1.1.1.1     -> serveur DNS secondaire
# search domain.local    -> suffixe appliqué aux noms courts
```

!!! info "Fichier généré automatiquement"
    Sur de nombreuses distributions modernes, `/etc/resolv.conf` est généré dynamiquement par `systemd-resolved` ou `NetworkManager` : une modification manuelle peut être écrasée au redémarrage.

### Gestionnaire moderne — `systemd-resolved`

```bash
resolvectl status                     # Affiche les résolveurs actifs par interface
resolvectl query domain.com           # Résout un nom via systemd-resolved
resolvectl flush-caches               # Vide le cache DNS local
resolvectl statistics                 # Statistiques sur le cache et les requêtes
```

---

## Sécurité du protocole

### Transfert de zone (AXFR)

Le transfert de zone permet à un serveur secondaire de répliquer l'intégralité d'une zone depuis le serveur primaire.

!!! warning "Risque d'exposition"
    Un serveur autoritaire mal configuré peut répondre à une requête AXFR provenant de n'importe quel client, exposant ainsi l'ensemble des enregistrements de la zone (sous-domaines internes, infrastructure). Le transfert doit être restreint aux serveurs secondaires légitimes (ACL, TSIG).

### Principes de DNSSEC

DNSSEC (DNS Security Extensions) ajoute une authentification cryptographique au DNS, sans chiffrer les échanges.

- **Objectif** : garantir l'**authenticité** et l'**intégrité** des réponses, pas leur confidentialité.
- **Mécanisme** : chaque zone signe ses enregistrements avec une clé privée ; le résolveur vérifie avec la clé publique correspondante.
- **Chaîne de confiance** : la validation remonte jusqu'à la racine (`.`), de bout en bout.

| Enregistrement DNSSEC | Rôle |
|---|---|
| `RRSIG` | Signature cryptographique d'un ensemble d'enregistrements |
| `DNSKEY` | Clé publique utilisée pour vérifier les signatures de la zone |
| `DS` | Empreinte de la clé, déposée dans la zone parente (chaîne de confiance) |
| `NSEC` / `NSEC3` | Prouve l'absence d'un enregistrement (protection anti-énumération) |

!!! info "DNSSEC ne chiffre rien"
    DNSSEC protège contre la falsification de réponses (cache poisoning, spoofing) mais ne masque pas les requêtes. Pour la confidentialité, ce sont des protocoles comme **DoH** (DNS over HTTPS) ou **DoT** (DNS over TLS) qui interviennent.

---

## Voir aussi

- RFC 1034 / 1035 — Concepts et spécifications du DNS
- RFC 4033 à 4035 — Introduction à DNSSEC
- Fiche complémentaire : `dns-outils.md` pour l'inspection en ligne de commande
