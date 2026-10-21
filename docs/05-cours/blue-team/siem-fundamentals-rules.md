# SIEM Fundamentals & Rules

## 1. Architecture SIEM & Pipeline de Détection

```text
[Sources] → [Ingestion] → [Normalisation] → [Corrélation] → [Alerting] → [Rétention]
  logs        collecteurs     parsing/CIM        règles         SOC          storage
  agents      (Beats,         mapping champs      Sigma/KQL/     ticket/      hot/warm/
  syslog      Fluentd,        communs             SPL            SOAR         cold tiers
  API         Winlogbeat)     (ECS, CIM)
```

| Étape | Rôle | Exemples d'outils/technos |
|---|---|---|
| Ingestion | Collecte brute des événements depuis les sources (endpoints, réseau, cloud, apps) | Winlogbeat, Filebeat, Fluentd, Syslog-ng, API cloud |
| Normalisation | Parsing et mapping vers un schéma commun (champs uniformisés) | ECS (Elastic Common Schema), CIM (Splunk Common Information Model) |
| Corrélation | Application de règles de détection sur les événements normalisés | Moteur de règles Sigma/KQL/SPL, corrélation temporelle multi-sources |
| Alerting | Génération d'alertes, priorisation, enrichissement (threat intel, contexte asset) | Notable Events (Splunk), Analytics Rules (Sentinel), Detection Rules (Elastic) |
| Rétention | Politique de conservation selon criticité et contraintes légales | Hot/Warm/Cold storage, tiering, archivage conforme (RGPD, PCI-DSS) |

!!! note "Principe de normalisation"
    Un événement brut (`4624` Windows, `Accepted` SSH, log Nginx) doit converger vers des champs communs (`user`, `src_ip`, `dst_ip`, `event.outcome`) afin qu'une seule règle de corrélation puisse s'appliquer à plusieurs sources hétérogènes.

!!! warning "Rétention vs coût"
    Le stockage "hot" (recherche rapide) est coûteux. Arbitrer la durée de rétention par type de log selon la criticité (ex: logs auth 1 an, logs debug 30 jours) et les obligations réglementaires du secteur.

---

## 2. Format de Règle Universel — Sigma

### Structure YAML

| Section | Rôle |
|---|---|
| `title` | Nom court et descriptif de la règle |
| `id` | UUID unique de la règle |
| `status` | `stable`, `test`, `experimental` |
| `description` | Explication du comportement détecté |
| `logsource` | Source de log ciblée (`category`, `product`, `service`) |
| `detection` | Blocs de sélection (`selection`, `filter`) + `condition` |
| `condition` | Expression logique combinant les blocs de `detection` |
| `falsepositives` | Cas connus de faux positifs |
| `level` | Sévérité (`low`, `medium`, `high`, `critical`) |
| `tags` | Références MITRE ATT&CK (`attack.t1059.001`) |

### Exemple — Détection de PowerShell encodé

```yaml
title: Suspicious PowerShell Encoded Command
id: 3c1b7f5e-9a2d-4e1a-8b6f-1234567890ab
status: stable
description: Détecte l'exécution de PowerShell avec une commande encodée en Base64, technique fréquente d'obfuscation.
references:
    - https://attack.mitre.org/techniques/T1059/001/
author: SOC Team
date: 2026/08/30
logsource:
    category: process_creation
    product: windows
detection:
    selection:
        Image|endswith: '\powershell.exe'
        CommandLine|contains:
            - '-EncodedCommand'
            - '-enc '
            - '-e '
    filter_legit:
        ParentImage|endswith: '\SCCMAgent.exe'
    condition: selection and not filter_legit
falsepositives:
    - Scripts d'administration légitimes utilisant l'encodage pour éviter les problèmes d'échappement
level: high
tags:
    - attack.execution
    - attack.t1059.001
    - attack.defense_evasion
    - attack.t1027
```

```bash
# Conversion Sigma → requête native (via sigma-cli / pySigma)
sigma convert -t splunk -p sysmon rule_powershell_encoded.yml
sigma convert -t elasticsearch-lucene -p ecs_windows rule_powershell_encoded.yml
sigma convert -t sentinel -p sysmon rule_powershell_encoded.yml
```

!!! tip "Portabilité"
    Une règle Sigma s'écrit une seule fois et se convertit vers KQL, SPL, Lucene, EQL... via `sigma-cli` — c'est l'intérêt central du format : découpler la logique de détection du moteur SIEM cible.

---

## 3. Détection Fichiers/Mémoire avec YARA

### Structure d'une règle

| Section | Rôle |
|---|---|
| `meta` | Métadonnées libres (auteur, description, date, référence, hash) |
| `strings` | Motifs à rechercher : chaînes texte (`$s`), hex (`$h`), regex (`$r`) |
| `condition` | Expression logique déterminant le match (combinaison de strings, taille, offset) |

### Modificateurs de strings

| Modificateur | Effet |
|---|---|
| `nocase` | Recherche insensible à la casse |
| `wide` | Recherche en encodage UTF-16 (chaînes Windows Unicode) |
| `ascii` | Force la recherche en ASCII (par défaut, combinable avec `wide`) |
| `fullword` | La chaîne doit être un mot complet (bordures non-alphanumériques) |
| `xor` | Recherche la chaîne XORée avec une plage de clés |

### Exemple de règle

```yara
rule Suspicious_Mimikatz_Strings
{
    meta:
        author = "SOC Team"
        description = "Détecte des chaînes caractéristiques de Mimikatz en mémoire ou sur disque"
        date = "2026-08-30"
        reference = "https://attack.mitre.org/software/S0002/"
        threat_level = "high"

    strings:
        $s1 = "sekurlsa::logonpasswords" nocase ascii wide
        $s2 = "gentilkiwi" nocase
        $s3 = "mimikatz" nocase ascii wide fullword
        $hex1 = { 4D 69 6D 69 6B 61 74 7A }  // "Mimikatz" en hex
        $re1 = /admin\$\\[a-z]{8}\.exe/ nocase

    condition:
        uint16(0) == 0x5A4D and  // vérifie l'en-tête MZ (PE valide)
        (2 of ($s*) or $hex1 or $re1) and
        filesize < 5MB
}
```

```bash
# Scan d'un fichier unique
yara suspicious_mimikatz.yar C:\evidence\suspect.exe

# Scan récursif d'un dossier
yara -r suspicious_mimikatz.yar C:\evidence\triage\

# Scan sur un dump mémoire (process memory)
yara -r --scan-list rules_list.txt memory_dump.raw

# Affichage des strings matchées (mode debug)
yara -s suspicious_mimikatz.yar C:\evidence\suspect.exe
```

!!! danger "Faux négatifs — encodage"
    Une chaîne présente uniquement en UTF-16 (Unicode Windows natif, ex: strings extraites d'un exécutable .NET) ne sera **jamais** détectée sans le modificateur `wide`. Toujours tester `ascii wide` en combinaison sur les échantillons Windows.

---

## 4. Langages de Requête SIEM — Comparatif

| Opération | KQL (Microsoft Sentinel) | SPL (Splunk) | Lucene (Elastic Security) |
|---|---|---|---|
| Sélection table/index | `SecurityEvent` | `index=security` | `index:security` |
| Filtre égalité | `\| where EventID == 4625` | `EventID=4625` | `EventID:4625` |
| Filtre texte partiel | `\| where CommandLine contains "powershell"` | `CommandLine="*powershell*"` | `CommandLine:*powershell*` |
| Regex | `\| where CommandLine matches regex "(?i)-enc"` | `\| regex CommandLine="(?i)-enc"` | `CommandLine:/.*-enc.*/` |
| AND / OR | `and` / `or` | `AND` / `OR` (implicite = AND) | `AND` / `OR` |
| Négation | `!=` / `not` | `NOT` | `NOT` / `-` |
| Comptage groupé | `\| summarize count() by SrcIP` | `\| stats count by src_ip` | `aggs: terms field: src_ip` (DSL) |
| Fenêtre temporelle | `\| where TimeGenerated > ago(24h)` | `earliest=-24h` | `range: {"@timestamp": {"gte": "now-24h"}}` |
| Tri | `\| sort by TimeGenerated desc` | `\| sort -_time` | `sort: [{"@timestamp": "desc"}]` |
| Jointure | `\| join kind=inner (...) on Field` | `\| join type=inner field (...)` | via requêtes composées / transforms |

### Exemple équivalent — échecs de connexion par IP (24h)

```kql
// KQL — Microsoft Sentinel
SecurityEvent
| where EventID == 4625
| where TimeGenerated > ago(24h)
| summarize FailCount = count() by IpAddress
| where FailCount > 20
| sort by FailCount desc
```

```spl
# SPL — Splunk
index=security EventID=4625 earliest=-24h
| stats count as FailCount by src_ip
| where FailCount > 20
| sort -FailCount
```

```text
# Lucene — Elastic (query string, utilisé dans Kibana Discover)
event.code:4625 AND @timestamp:[now-24h TO now]

# Agrégation équivalente : Elastic Query DSL (pas Lucene pur)
{
  "query": { "bool": { "filter": [
    { "term": { "event.code": "4625" }},
    { "range": { "@timestamp": { "gte": "now-24h" }}}
  ]}},
  "aggs": {
    "by_ip": { "terms": { "field": "source.ip", "min_doc_count": 20 }}
  }
}
```

!!! note "Lucene vs DSL"
    Lucene query string sert aux recherches simples dans Kibana Discover. Les agrégations et logiques complexes en Elastic Security passent généralement par **EQL** (Event Query Language) ou le **Query DSL** JSON plutôt que par Lucene pur.

!!! tip "Traduction inter-SIEM"
    Formaliser d'abord la logique de détection en pseudo-code ou en Sigma, puis traduire vers le langage cible — évite les erreurs de syntaxe lors de migrations entre plateformes SIEM.
