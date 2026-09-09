# SOC Fundamentals

## 1. Workflow de Tri d'Alertes SOC

```text
[Alerte SIEM/EDR] → [N1: Triage] → [N2: Investigation] → [N3: Threat Hunting / IR avancé]
                          │                │                        │
                          ▼                ▼                        ▼
                    Qualification    Analyse approfondie      Containment,
                    rapide           + corrélation multi-     éradication,
                    (FP/TP évident)  sources                  remédiation
```

| Niveau | Rôle | Compétences | Actions typiques |
|---|---|---|---|
| N1 (Triage) | Premier filtre, qualification initiale | Lecture d'alertes, procédures documentées | Vérifier contexte de base, classer FP/TP évident, escalader si doute |
| N2 (Investigation) | Analyse approfondie des alertes escaladées | Corrélation, forensics léger, connaissance des TTPs | Pivots sur logs, timeline, décision de sévérité, containment initial |
| N3 (Threat Hunting / IR) | Traitement des incidents complexes/avancés | Reverse engineering, forensics poussé, threat intel | Chasse proactive, gestion de crise, coordination IR complète |

### Cycle de qualification d'une alerte

| Résultat | Définition | Action |
|---|---|---|
| Vrai Positif (TP) | Alerte confirmée, activité malveillante/anormale réelle | Escalade N2/N3, ouverture d'incident |
| Faux Positif (FP) | Alerte déclenchée à tort, activité légitime | Clôture, documentation, ajustement de règle si récurrent |
| Vrai Négatif (VN) | Absence d'alerte, activité effectivement normale | Aucune action (baseline correcte) |
| Faux Négatif (FN) | Activité malveillante **non détectée** (découverte a posteriori) | Analyse root-cause de détection, création/tuning de règle |

!!! danger "Faux Négatif = risque silencieux"
    Le FN est la catégorie la plus dangereuse : par définition, il n'a généré aucune alerte. Il n'est identifié qu'après coup (audit, incident découvert autrement, threat hunting). Une gouvernance SOC doit prévoir des revues régulières de détection pour limiter les FN.

---

## 2. Métriques Clés de Performance SOC

| Métrique | Nom complet | Formule | Objectif typique |
|---|---|---|---|
| MTTD | Mean Time To Detect | `Σ(temps détection - temps compromission) / nb incidents` | < 24h (idéal < 1h avec EDR/SIEM mature) |
| MTTI | Mean Time To Investigate | `Σ(temps qualification - temps détection) / nb alertes` | < 30 min (N1) |
| MTTR | Mean Time To Respond/Remediate | `Σ(temps résolution - temps détection) / nb incidents` | < 4h (P1), variable selon sévérité |
| MTTC | Mean Time To Contain | `Σ(temps containment - temps détection) / nb incidents` | < 1h (P1 critique) |
| Taux de Faux Positifs | FP Rate | `(nb FP / nb alertes totales) × 100` | < 10-15 % (au-delà = fatigue d'alerte) |

```text
Chronologie d'un incident type (repères MTTx)

Compromission   Détection      Qualification    Containment      Résolution
     │              │               │                │               │
     ├──MTTD────────┤               │                │               │
                     ├──MTTI────────┤                │               │
                     ├──────MTTC────────────────────┤                │
                     ├──────────────MTTR────────────────────────────┤
```

!!! warning "Fatigue d'alerte (alert fatigue)"
    Un taux de Faux Positifs élevé (> 20-30 %) dégrade la vigilance des analystes N1 et augmente mécaniquement le MTTD/MTTI global — le tuning des règles a un impact direct sur toutes les autres métriques.

!!! note "MTTD dépend de la visibilité"
    Le MTTD n'est mesurable avec précision que si le point de compromission initial est identifiable rétrospectivement (via forensics/log rétention) — sans logs suffisamment rétentionnés, cette métrique reste approximative.

---

## 3. Stratégies de Gestion & Réduction des Faux Positifs

### Tuning de règles de détection

```yaml
# Exemple Sigma — ajout d'un filtre après identification d'un FP récurrent
detection:
    selection:
        Image|endswith: '\powershell.exe'
        CommandLine|contains: '-EncodedCommand'
    filter_legit_sccm:
        ParentImage|endswith: '\SCCMAgent.exe'
    filter_legit_backup:
        User|endswith: 'svc_backup'
    condition: selection and not 1 of filter_legit_*
```

| Levier | Principe | Exemple concret |
|---|---|---|
| Tuning de règles | Affiner les conditions de déclenchement (exclusions ciblées) | Exclure un parent process légitime connu (agent EDR, SCCM) |
| Whitelisting | Exclure explicitement des entités connues et validées | IP interne de scan de vulnérabilité autorisé, compte de service |
| Baselining | Établir une activité normale de référence pour détecter les écarts | Volume de connexions SSH habituel par serveur, horaires de login normaux |
| Enrichissement contextuel (SOAR) | Ajouter automatiquement du contexte à l'alerte avant présentation à l'analyste | Réputation IP, criticité de l'asset, historique utilisateur |

```text
# Playbook SOAR simplifié — enrichissement automatique d'une alerte
Alerte reçue
  → Lookup réputation IP (Threat Intel API)
  → Lookup criticité asset (CMDB)
  → Lookup historique utilisateur (nb alertes 30j)
  → Si IP whitelistée ET asset non-critique → auto-close (FP documenté)
  → Sinon → notification analyste N1 avec contexte enrichi
```

!!! tip "Whitelisting ≠ suppression de règle"
    Toujours privilégier une exclusion **ciblée et documentée** (IP, hash, parent process précis) plutôt que de désactiver une règle entière — préserve la capacité de détection sur le reste du périmètre.

!!! danger "Whitelisting non révisé"
    Une liste blanche jamais réévaluée devient un angle mort permanent. Prévoir une revue périodique (trimestrielle) des exclusions actives.

---

## 4. Matrice de Priorisation & Sévérité des Incidents

```text
Priorité = f(Impact, Urgence)

              Urgence Faible    Urgence Moyenne    Urgence Élevée
Impact Élevé       P2                 P1                P1
Impact Moyen       P3                 P2                P1
Impact Faible      P4                 P3                P2
```

| Priorité | Nom | Critères typiques | Délai de réponse cible |
|---|---|---|---|
| P1 | Critique | Compromission active, ransomware, exfiltration confirmée, asset critique impacté | Immédiat (< 15-30 min) |
| P2 | Élevée | Activité malveillante confirmée, impact limité ou contenu, asset important | < 1h |
| P3 | Moyenne | Anomalie suspecte nécessitant investigation, impact faible | < 4h (heures ouvrées) |
| P4 | Faible | Alerte informative, hygiène de sécurité, faible probabilité de malveillance | < 24-48h |

### Critères d'impact et d'urgence

| Dimension | Facteurs évalués |
|---|---|
| Impact | Criticité de l'asset (CMDB), sensibilité des données, nombre de systèmes affectés, disponibilité du service |
| Urgence | Vitesse de propagation, activité en cours (vs déjà contenue), fenêtre d'exploitation active |

### Critères de déclenchement d'escalade vers la Réponse à Incident

```text
Escalade IR déclenchée SI au moins un critère vrai :
  - Mouvement latéral confirmé (multi-hôtes)
  - Compte à privilèges élevés compromis (Domain Admin, service account critique)
  - Exfiltration de données confirmée ou fortement suspectée
  - Ransomware / chiffrement de fichiers détecté
  - Asset classé "critique" dans la CMDB affecté
  - Alerte corrélée à une campagne de menace active (Threat Intel)
```

!!! warning "P1 = mobilisation immédiate"
    Un incident P1 doit déclencher la procédure de gestion de crise formelle (astreinte, communication, cellule de crise) — ne pas traiter comme une alerte N1 standard même si détectée par le même pipeline SIEM.

---

## 5. Checklist de l'Analyste N1

```text
□ 1. Identifier la règle/source ayant déclenché l'alerte
□ 2. Corrélation temporelle
      - Autres alertes sur le même host/user dans une fenêtre de ±30 min ?
      - Séquence d'événements cohérente avec une attaque connue (kill chain) ?
□ 3. Vérification source/destination
      - IP source : interne ou externe ? Géolocalisation cohérente ?
      - IP destination : asset connu ? Service légitime attendu sur ce port ?
      - Utilisateur : compte actif ? Horaires habituels ? Poste habituel ?
□ 4. Enrichissement Threat Intelligence
      - IP/domaine présents dans un flux de réputation (AbuseIPDB, VirusTotal, MISP) ?
      - Hash de fichier connu comme malveillant (VirusTotal, Hybrid Analysis) ?
      - TTP correspondant à un acteur de menace documenté (MITRE ATT&CK) ?
□ 5. Vérification de contexte asset
      - Criticité de l'asset dans la CMDB
      - Présence de vulnérabilités connues non patchées sur ce système
□ 6. Décision de qualification
      - TP confirmé → escalade N2 avec résumé structuré
      - FP documenté → clôture avec justification (pour tuning ultérieur)
      - Doute persistant → escalade par prudence (ne jamais clôturer un doute)
□ 7. Documentation
      - Horodatage de chaque étape
      - Preuves collectées (captures, extraits logs, hash)
      - Décision et justification consignées dans le ticket
```

```bash
# Exemples de lookups rapides d'enrichissement (CLI)

# Réputation IP via API (exemple générique)
curl -s "https://api.abuseipdb.com/api/v2/check?ipAddress=203.0.113.42" \
  -H "Key: $API_KEY" -H "Accept: application/json"

# Recherche hash sur VirusTotal
curl -s "https://www.virustotal.com/api/v3/files/<SHA256>" \
  -H "x-apikey: $VT_API_KEY"

# Whois rapide sur IP suspecte
whois 203.0.113.42

# Résolution DNS inverse
dig -x 203.0.113.42
```

!!! note "Principe du doute"
    En cas d'incertitude après avoir suivi la checklist, la règle par défaut est **d'escalader**, jamais de clôturer par défaut — le coût d'un FN est structurellement supérieur au coût d'une escalade inutile.

!!! tip "Standardisation du résumé d'escalade"
    Un résumé d'escalade N1→N2 efficace suit systématiquement : **Quoi** (alerte) → **Qui/Quoi** (user/host) → **Quand** (timeline) → **Preuves collectées** → **Raison du doute/TP**.
