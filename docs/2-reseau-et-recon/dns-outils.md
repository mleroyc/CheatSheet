# Outils DNS en ligne de commande

Cheat sheet dédiée à l'inspection et l'énumération DNS via `dig`, `host` et `nslookup`.

!!! tip "Quel outil choisir ?"
    `dig` est l'outil de référence pour l'administration et l'audit DNS (sortie complète, scriptable). `host` est le plus rapide pour une vérification ponctuelle. `nslookup` reste utile car présent par défaut sur la plupart des systèmes, y compris Windows.

---

## Dig (Domain Information Groper)

L'outil de référence pour l'inspection DNS, fourni avec `bind-utils` / `dnsutils`.

### Requêtes de base

```bash
dig domain.com                     # Requête standard, enregistrement A par défaut
dig domain.com MX                  # Interroge les enregistrements MX (mail)
dig domain.com TXT                 # Interroge les enregistrements TXT (SPF, DKIM...)
dig domain.com NS                  # Liste les serveurs de noms autoritaires
dig domain.com ANY                 # Tente de récupérer tous les types (souvent limité par les résolveurs)
dig domain.com SOA                 # Affiche l'enregistrement Start of Authority
```

### Choisir le serveur DNS interrogé

```bash
dig @8.8.8.8 domain.com            # Interroge directement le résolveur Google
dig @1.1.1.1 domain.com MX         # Interroge Cloudflare pour les enregistrements MX
dig @ns1.target.com domain.com     # Interroge un serveur faisant autorité en particulier
```

!!! tip "Pourquoi cibler un serveur précis ?"
    Comparer la réponse d'un résolveur public à celle du serveur autoritaire permet de détecter des incohérences de propagation ou du DNS caching malveillant (cache poisoning).

### Formats de sortie

```bash
dig domain.com +short              # Sortie condensée, uniquement la valeur utile
dig domain.com +noall +answer      # Affiche uniquement la section ANSWER
dig domain.com +trace              # Trace la résolution depuis les root servers
dig domain.com +nocmd +nostats     # Supprime l'en-tête de commande et les statistiques
```

### Résolution inverse (PTR)

```bash
dig -x 192.168.1.1                 # Reverse DNS Lookup, équivalent à une requête PTR
dig -x 2001:db8::1                 # Fonctionne aussi en IPv6
```

### Transfert de zone (AXFR)

```bash
dig axfr @ns1.target.com target.com   # Tentative de transfert de zone complet
dig axfr @ns1.target.com target.com +noall +answer   # Sortie filtrée si le transfert réussit
```

!!! warning "Transfert de zone AXFR"
    Une réponse positive à une requête AXFR révèle l'intégralité des enregistrements de la zone (sous-domaines, IP internes...). Un serveur correctement configuré doit refuser ce transfert aux clients non autorisés. Ne testez que sur des périmètres pour lesquels vous avez une autorisation explicite.

---

## Host — l'outil rapide

Syntaxe minimaliste, idéale pour des vérifications rapides en une ligne.

```bash
host domain.com                    # Requête simple, affiche A/AAAA/MX par défaut
host -t mx domain.com              # Force le type d'enregistrement interrogé
host -t txt domain.com             # Récupère les enregistrements TXT
host -t ns domain.com              # Liste les serveurs de noms
host -a domain.com                 # Équivalent de dig ANY, sortie détaillée type zonefile
```

### Résolution inverse et serveur cible

```bash
host 192.168.1.1                   # Résolution inverse directe (PTR)
host domain.com 8.8.8.8            # Interroge un serveur DNS spécifique (ici Google)
```

---

## Nslookup — l'outil universel

Disponible nativement sous Windows, Linux et macOS. Fonctionne en mode direct ou interactif.

### Utilisation directe

```bash
nslookup domain.com                # Requête simple en une commande
nslookup -type=mx domain.com       # Interroge les enregistrements MX
nslookup -type=txt domain.com      # Interroge les enregistrements TXT
nslookup domain.com 8.8.8.8        # Interroge un serveur DNS précis
nslookup 192.168.1.1               # Résolution inverse (PTR)
```

### Mode interactif

```bash
nslookup                           # Ouvre la session interactive
```

Puis, dans l'invite `>` :

```text
> server 1.1.1.1                   # Change le serveur DNS utilisé pour la session
> set type=any                     # Modifie le type d'enregistrement recherché
> set type=mx                      # Bascule sur les enregistrements MX
> domain.com                       # Lance la requête avec les paramètres définis
> exit                             # Quitte le mode interactif
```

!!! tip "Mode interactif vs mode direct"
    Le mode interactif est pratique pour enchaîner plusieurs requêtes sur le même serveur DNS sans le répéter à chaque commande, notamment lors d'une phase d'énumération manuelle.

---

## Tableau comparatif des options équivalentes

| Action | `dig` | `host` | `nslookup` |
|---|---|---|---|
| Requête simple | `dig domain.com` | `host domain.com` | `nslookup domain.com` |
| Type d'enregistrement spécifique | `dig domain.com MX` | `host -t mx domain.com` | `nslookup -type=mx domain.com` |
| Cibler un serveur DNS | `dig @8.8.8.8 domain.com` | `host domain.com 8.8.8.8` | `nslookup domain.com 8.8.8.8` |
| Résolution inverse (PTR) | `dig -x 192.168.1.1` | `host 192.168.1.1` | `nslookup 192.168.1.1` |
| Sortie condensée | `dig domain.com +short` | *(sortie déjà courte par défaut)* | *(non disponible nativement)* |
| Tous les types disponibles | `dig domain.com ANY` | `host -a domain.com` | `set type=any` (mode interactif) |
| Transfert de zone | `dig axfr @ns1.target.com target.com` | `host -l target.com ns1.target.com` | non supporté |
| Mode interactif | non natif | non natif | `nslookup` puis `server`, `set type=` |

!!! tip "Cas d'usage recommandé"
    Pour un audit ou un script automatisé, privilégiez `dig` avec `+short` ou `+noall +answer` : la sortie est stable et facilement parsable. Pour une vérification humaine rapide, `host` reste le plus lisible.

---

## Voir aussi

- `dig` man page : `man dig`
- RFC 1035 — Domain Names, Implementation and Specification
- Outils complémentaires : `dnsrecon`, `dnsenum`, `fierce` pour l'énumération automatisée
