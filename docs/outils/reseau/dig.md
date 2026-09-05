# 🛠️ Commande : dig

## 1. Description rapide (Rôle et cas d'usage)

`dig` (*Domain Information Groper*) est l'outil de référence pour le diagnostic DNS avancé. Il permet d'interroger précisément n'importe quel type d'enregistrement, de cibler un serveur DNS spécifique, de tracer la chaîne de résolution complète et de produire des sorties facilement parsables en script. C'est l'outil de choix pour l'audit de zone et le pentest réseau.

## 2. Syntaxe de base

```bash
dig [@serveur] domaine [TYPE] [OPTIONS]
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `@ip` / `@serveur` | Interroge un serveur DNS spécifique (ex: `@8.8.8.8`, `@1.1.1.1`) |
| `A`, `MX`, `TXT`, `NS`, `SOA`, `ANY` | Spécifie le type d'enregistrement recherché |
| `-x` | Résolution inverse (PTR) à partir d'une IP |
| `+short` | Sortie minimaliste, une valeur par ligne |
| `+noall +answer` | N'affiche que la section réponse, sans en-têtes ni stats |
| `+trace` | Trace toute la chaîne de résolution depuis les root servers |
| `+nocmd +nostats` | Supprime la ligne de commande et les statistiques de la sortie |
| `axfr` | Tente un transfert de zone complet |

## 4. Exemples pratiques & Cas d'usage

**Résolution simple d'un enregistrement A**
```bash
dig example.com A +short
```

**Interroger un résolveur public spécifique (Cloudflare)**
```bash
dig @1.1.1.1 example.com A
```

**Auditer les enregistrements MX pour la sécurité mail**
```bash
dig example.com MX +noall +answer
```

**Tracer la résolution complète depuis les serveurs racine**
```bash
dig example.com +trace
```

**Résolution inverse d'une IP en pentest de reconnaissance**
```bash
dig -x 203.0.113.10 +short
```

**Tenter un transfert de zone complet sur le serveur autoritaire (audit de sécurité)**
```bash
dig axfr @ns1.target.com target.com
```

## 5. Astuces & Pièges à éviter

!!! warning "Un transfert de zone (AXFR) réussi est une faille critique"
    Si `dig axfr @ns1.target.com target.com` renvoie l'intégralité de la zone, cela signifie que le serveur autoritaire autorise les transferts de zone à des tiers non autorisés — une fuite d'information majeure exploitable en reconnaissance offensive. Un serveur bien configuré doit refuser cette requête (`Transfer failed`) sauf pour les IP de secondaires légitimes.

!!! tip "+short pour scripter proprement"
    `+short` est indispensable dans des scripts bash pour récupérer une valeur brute exploitable directement (`ip=$(dig +short example.com)`), sans parsing complexe.

!!! tip "dig vs host vs nslookup"
    `dig` est le plus complet et le plus scriptable des trois : il expose tous les détails du paquet DNS (TTL, flags, sections complètes) et supporte nativement `+trace` et `axfr`, ce que `host` et `nslookup` ne proposent que partiellement (voir tableau ci-dessous).

| Critère | `dig` | `host` | `nslookup` |
|---|---|---|---|
| Verbosité / détail | Très élevée (TTL, flags, sections) | Faible, format condensé | Moyenne |
| Scriptabilité (`+short`) | ✅ Excellente | ✅ Bonne | ⚠️ Limitée (parsing fragile) |
| Transfert de zone (AXFR) | ✅ `dig axfr` | ✅ `host -l` | ❌ Non natif |
| Mode interactif | ❌ | ❌ | ✅ |
| Disponibilité par défaut | Linux/macOS (paquet `dnsutils`/`bind-utils`) | Linux/macOS | Universel (Linux/macOS/Windows) |
