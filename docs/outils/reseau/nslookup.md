# 🛠️ Commande : nslookup

## 1. Description rapide (Rôle et cas d'usage)

`nslookup` est un outil de requête DNS disponible nativement sur Linux, macOS **et Windows**, ce qui en fait l'outil universel de dépannage réseau lorsque `dig` n'est pas installé. Il fonctionne en mode direct (une commande, une réponse) ou en mode interactif, permettant d'enchaîner plusieurs requêtes contre un même résolveur sans le réinvoquer à chaque fois.

## 2. Syntaxe de base

```bash
# Mode direct
nslookup [OPTIONS] domaine [serveur]

# Mode interactif
nslookup
> commande
```

## 3. Options et fanions principaux

| Option / Commande | Contexte | Effet |
|---|---|---|
| `-type=mx` | Mode direct | Interroge les enregistrements MX |
| `-type=txt` | Mode direct | Interroge les enregistrements TXT |
| `-type=ns` | Mode direct | Interroge les enregistrements NS |
| `domaine serveur` | Mode direct | Cible un serveur DNS spécifique |
| `server IP` | Mode interactif | Change le résolveur utilisé pour la session |
| `set type=TYPE` | Mode interactif | Définit le type d'enregistrement pour les requêtes suivantes |
| `exit` | Mode interactif | Quitte la session |

## 4. Exemples pratiques & Cas d'usage

**Résolution simple en mode direct**
```bash
nslookup example.com
```

**Interroger les enregistrements MX directement**
```bash
nslookup -type=mx example.com
```

**Résolution inverse d'une adresse IP**
```bash
nslookup 203.0.113.10
```

**Cibler un serveur DNS précis en une seule commande**
```bash
nslookup example.com 8.8.8.8
```

**Session interactive pour énumérer plusieurs types sur le même résolveur (pentest/recon)**
```text
$ nslookup
> server ns1.target.com
> set type=ns
> target.com
> set type=txt
> target.com
> exit
```

**Vérifier rapidement la config DNS sur un poste Windows (compatibilité universelle)**
```powershell
nslookup -type=mx example.com
```

## 5. Astuces & Pièges à éviter

!!! warning "nslookup est officiellement déprécié au profit de dig"
    La documentation de l'ISC recommande `dig` ou `host` plutôt que `nslookup` pour un usage scripté fiable : son format de sortie a changé au fil des versions et son parsing automatique est fragile. Réservez `nslookup` au dépannage interactif ou aux environnements où `dig` est absent (typiquement Windows).

!!! tip "Mode interactif pour l'énumération manuelle"
    Le mode interactif (`server` + `set type=`) évite de retaper le serveur cible à chaque requête — pratique en reconnaissance manuelle pour tester plusieurs types d'enregistrements contre un même serveur autoritaire sans relancer la commande.

!!! tip "Seul outil DNS garanti présent sur Windows"
    Sur un poste Windows sans outils tiers, `nslookup` est généralement le seul outil de requête DNS disponible nativement — c'est souvent le point de départ obligé en dépannage terrain avant de basculer vers un environnement Linux/macOS avec `dig`.

| Critère | `nslookup` | `dig` | `host` |
|---|---|---|---|
| Disponibilité Windows | ✅ Native | ❌ (nécessite install) | ❌ (nécessite install) |
| Mode interactif | ✅ | ❌ | ❌ |
| Fiabilité du parsing en script | ⚠️ Fragile | ✅ Excellente (`+short`) | ✅ Bonne |
| Transfert de zone (AXFR) | ❌ Non supporté | ✅ `dig axfr` | ✅ `host -l` |
| Statut | ⚠️ Déprécié pour usage scripté | ✅ Recommandé | ✅ Recommandé (usage simple) |
