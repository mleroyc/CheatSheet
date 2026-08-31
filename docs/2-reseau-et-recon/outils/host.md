# 🛠️ Commande : host

## 1. Description rapide (Rôle et cas d'usage)

`host` est un outil de résolution DNS conçu pour la simplicité et la lisibilité immédiate. Il affiche par défaut l'essentiel (A/AAAA/MX) en une ligne par enregistrement, sans le bruit verbeux de `dig`. Idéal pour une vérification humaine rapide ou des one-liners dans des scripts légers.

## 2. Syntaxe de base

```bash
host [OPTIONS] domaine [serveur]
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| (aucune) | Requête A/AAAA/MX par défaut, format lisible |
| `-t TYPE` | Spécifie un type d'enregistrement (`mx`, `txt`, `ns`, `soa`...) |
| `-a` | Dump complet façon fichier de zone (équivalent `-v -t ANY`) |
| `-v` | Mode verbeux |
| `-l` | Tente un transfert de zone (list) sur le domaine |
| `serveur` (dernier argument) | Cible un serveur DNS spécifique pour la requête |

## 4. Exemples pratiques & Cas d'usage

**Vérification rapide de la résolution d'un domaine**
```bash
host example.com
```

**Consulter les enregistrements MX pour valider la config mail**
```bash
host -t mx example.com
```

**Lire les enregistrements TXT (SPF, DKIM, vérifications diverses)**
```bash
host -t txt example.com
```

**Résolution inverse directe d'une IP**
```bash
host 203.0.113.10
```

**Cibler explicitement un serveur DNS spécifique (audit multi-résolveurs)**
```bash
host example.com 8.8.8.8
```

**Tenter un transfert de zone en audit de sécurité externe**
```bash
host -l target.com ns1.target.com
```

## 5. Astuces & Pièges à éviter

!!! tip "host pour un one-liner express"
    Quand `dig` est trop verbeux pour un simple contrôle visuel, `host domaine` donne une réponse lisible en une seule ligne — parfait pour un contrôle manuel rapide pendant une intervention.

!!! warning "host -l dépend des mêmes permissions qu'un AXFR dig"
    `host -l target.com ns1.target.com` réalise un transfert de zone, exactement comme `dig axfr`. Si le serveur cible autorise cette opération à un client non habilité, c'est une vraie faille de sécurité à signaler — ne pas confondre avec une simple fonctionnalité "pratique".

!!! tip "host -a pour un aperçu complet type zonefile"
    `host -a domaine` combine verbosité et type `ANY`, pratique pour un premier balayage rapide de tous les enregistrements disponibles avant de creuser avec `dig`.

| Critère | `host` | `dig` | `nslookup` |
|---|---|---|---|
| Lisibilité par défaut | ✅ Excellente (une ligne/enreg.) | ⚠️ Verbeux | Moyenne |
| Détail technique (TTL, flags) | ❌ Minimal | ✅ Complet | ⚠️ Partiel |
| Transfert de zone (AXFR) | ✅ `host -l` | ✅ `dig axfr` | ❌ |
| Scriptabilité | ✅ Bonne pour usage simple | ✅ Excellente (`+short`) | ⚠️ Limitée |
| Mode interactif | ❌ | ❌ | ✅ |
