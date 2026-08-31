# 🛠️ dig & nslookup — Interrogation DNS

## 1. Description rapide

**dig** (*Domain Information Groper*) est l'outil de référence pour interroger les serveurs DNS en ligne de commande. Sortie riche et précise, idéal pour l'audit et le pentest. **nslookup** est son équivalent plus simple, disponible nativement sur Linux et Windows. Les deux permettent de tester la résolution de noms, d'interroger des types de records spécifiques et de cibler un serveur DNS précis.

---

## 2. Syntaxe de base

```bash
dig [@serveur] domaine [type]

nslookup [domaine] [serveur]
```

---

## 3. Options et fanions principaux

### dig

| Flag / Option | Rôle |
| --- | --- |
| `@IP` | Serveur DNS à interroger (ex: `@8.8.8.8`) |
| `A` | Record IPv4 (défaut si omis) |
| `AAAA` | Record IPv6 |
| `MX` | Serveurs de messagerie |
| `NS` | Serveurs DNS autoritaires |
| `TXT` | Enregistrements texte (SPF, DKIM, DMARC) |
| `SOA` | Start of Authority |
| `PTR` | Reverse DNS (IP → nom) |
| `ANY` | Tous les records disponibles |
| `+short` | Affiche uniquement la valeur (sortie épurée) |
| `+noall +answer` | Affiche seulement la section Answer |
| `+trace` | Trace la résolution depuis les serveurs racines |
| `-x IP` | Reverse DNS lookup (PTR) |
| `axfr` | Tentative de transfert de zone |

### nslookup

| Option | Rôle |
| --- | --- |
| `-type=MX` | Spécifie le type de record |
| `server IP` | Change le serveur DNS (en mode interactif) |

---

## 4. Exemples pratiques

```bash
# Résolution A simple d'un domaine (sortie épurée)
dig +short example.com A
```

```bash
# Interroger un DNS spécifique (Google) pour le record MX
dig @8.8.8.8 example.com MX +short
```

```bash
# Reverse DNS lookup : IP → nom d'hôte
dig -x 93.184.216.34 +short
```

```bash
# Lister les serveurs NS autoritaires du domaine
dig example.com NS +noall +answer
```

```bash
# Tentative de transfert de zone complet (axfr) — pentest reconnaissance
dig axfr @ns1.target.com target.com
```

```bash
# Tracer la résolution DNS depuis les serveurs racines (diagnostic de délégation)
dig +trace example.com
```

---

## 5. Astuces & Pièges à éviter

!!! tip "dig +short pour les scripts"
    `dig +short example.com A` retourne uniquement l'IP, sans formatage. Idéal pour les scripts shell et les pipelines : `IP=$(dig +short monsite.com A | head -1)`.

!!! tip "Tester SPF et DMARC rapidement"
    ```bash
    dig TXT example.com +short | grep -E "spf|dmarc"
    dig TXT _dmarc.example.com +short
    ```
    Permet de vérifier la configuration email anti-spoofing en une commande.

!!! warning "axfr rarement autorisé sur les serveurs publics"
    La plupart des serveurs DNS modernes refusent le transfert de zone avec `REFUSED`. Tenter `axfr` sur les différents NS du domaine — les secondaires sont parfois moins restrictifs. Un succès expose **toute la zone DNS** (tous les sous-domaines, IPs internes).

!!! warning "nslookup utilise le cache du résolveur local"
    `nslookup` interroge le résolveur système (`/etc/resolv.conf`) qui peut avoir mis en cache des réponses obsolètes. Pour tester le serveur autoritaire directement, toujours spécifier `@ns1.domain.com` avec `dig`.
