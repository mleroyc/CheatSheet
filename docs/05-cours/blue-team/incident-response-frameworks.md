# Incident Response Frameworks

## 1. Alignement des Frameworks Majeurs

| NIST SP 800-61 Rev. 2 | SANS IR (6 phases) | Correspondance |
|---|---|---|
| 1. Preparation | 1. Preparation | Équivalent direct |
| 2. Detection & Analysis | 2. Identification | Équivalent direct |
| 3. Containment, Eradication & Recovery — *Containment* | 3. Containment | Équivalent direct |
| 3. Containment, Eradication & Recovery — *Eradication* | 4. Eradication | Équivalent direct |
| 3. Containment, Eradication & Recovery — *Recovery* | 5. Recovery | Équivalent direct |
| 4. Post-Incident Activity | 6. Lessons Learned | Équivalent direct |

```text
NIST (4 phases)      SANS (6 phases)
──────────────       ────────────────
Preparation      →   1. Preparation
Detection &      →   2. Identification
Analysis
                  →   3. Containment
Containment,     →   4. Eradication
Eradication &
Recovery          →   5. Recovery
Post-Incident     →   6. Lessons Learned
Activity
```

!!! note "Différence structurelle"
    NIST regroupe Containment/Eradication/Recovery en une seule phase 3, tandis que SANS les sépare en 3 phases distinctes. Le contenu opérationnel est identique — SANS offre simplement un découpage plus granulaire pour le pilotage terrain.

---

## 2. Phase 1 : Préparation

```text
□ Outils
    □ Kit de collecte forensic (write-blocker, disques stériles, câbles)
    □ Postes d'investigation dédiés (jump box IR, hors domaine compromis)
    □ Outils d'acquisition RAM/disque (FTK Imager, KAPE, dd/dcfldd)
    □ Accès EDR/SIEM avec comptes IR pré-provisionnés
    □ Solution de communication hors bande (non dépendante de l'IT compromis)

□ Procédures
    □ Playbooks IR documentés par type d'incident (ransomware, phishing, exfiltration)
    □ Matrice RACI de l'équipe IR (qui décide quoi)
    □ Procédure d'escalade formalisée (voir fiche soc-fundamentals)
    □ Modèles de rapport pré-remplis (timeline, IoC, actions)

□ Accès réseau
    □ Comptes d'urgence "break-glass" avec accès élevé, audité et scellé
    □ Cartographie réseau à jour (segments, VLAN, points de sortie internet)
    □ Accès aux consoles firewall/proxy pour isolation rapide

□ Backups hors-ligne
    □ Sauvegardes déconnectées du réseau (air-gapped) ou immuables (WORM)
    □ Test de restauration effectué et documenté (RTO/RPO validés)
    □ Backups couvrant AD/DC, serveurs critiques, configurations réseau

□ Contacts d'urgence
    □ Liste à jour : RSSI, DPO, direction, communication/PR
    □ Contacts externes : CERT national, assureur cyber, prestataire forensic
    □ Contacts légaux (obligations de notification RGPD/NIS2 sous 72h)
    □ Numéros hors ligne (papier/coffre) — ne pas dépendre du SI compromis
```

!!! warning "Communication hors bande obligatoire"
    Ne jamais planifier la réponse à incident uniquement via des canaux dépendant de l'infrastructure potentiellement compromise (email interne, Teams/Slack sur AD compromis). Prévoir un canal alternatif (téléphone, messagerie externe, Signal).

---

## 3. Phase 2 : Détection & Analyse

```text
Étapes d'identification de la portée
  1. Confirmer l'alerte initiale (voir checklist analyste N1)
  2. Identifier le patient zéro (premier système touché)
  3. Cartographier les systèmes impactés (mouvement latéral, C2, comptes utilisés)
  4. Déterminer la fenêtre temporelle (timestomping, timeline précise)
  5. Évaluer la donnée potentiellement affectée (nature, volume, sensibilité)
```

### Collecte de preuves à chaud (ordre de volatilité)

```bash
# 1. État réseau et processus (avant tout autre action)
netstat -anob > network_state.txt          # Windows
ss -tulpn > network_state.txt               # Linux

# 2. Processus en cours
tasklist /v > processes.txt                 # Windows
ps auxf > processes.txt                     # Linux

# 3. Acquisition mémoire (voir fiche digital-forensics-acquisition)
winpmem_mini_x64_rc2.exe ram_capture.raw

# 4. Sessions et connexions actives
query user                                  # Windows — sessions actives
who -a                                      # Linux — sessions actives

# 5. Artefacts d'exécution (Prefetch, Amcache — voir fiche windows-forensics)
```

### Définition d'un IoC (Indicator of Compromise)

| Type d'IoC | Exemples |
|---|---|
| Atomique | Hash de fichier (SHA256), adresse IP, domaine, URL |
| Comportemental | Séquence de processus, pattern de commande, technique MITRE ATT&CK |
| Basé sur outil | Signature YARA, règle Sigma, fingerprint de C2 |

```yaml
# Exemple de formalisation d'IoC pour diffusion à l'équipe IR
ioc:
  incident_id: "IR-2026-0142"
  type: "hash"
  value: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  context: "Payload dropper identifié sur patient zéro"
  first_seen: "2026-08-28T14:32:00Z"
  confidence: "high"
```

!!! danger "Ne jamais éteindre une machine avant acquisition RAM"
    Éteindre un système compromis avant capture mémoire détruit des preuves irremplaçables (clés de chiffrement en mémoire, processus injectés, connexions actives). Toujours respecter l'ordre RFC 3227.

---

## 4. Phase 3 : Confinement

| Type | Définition | Cas d'usage |
|---|---|---|
| Confinement à chaud (short-term) | Isolation immédiate sans arrêt du système, préserve l'état pour analyse | Ransomware en propagation active, exfiltration en cours |
| Confinement à froid (long-term) | Mesures durables après stabilisation (segmentation, durcissement) | Post-stabilisation, avant éradication complète |

```bash
# Isolation réseau — Windows (pare-feu local, bloque tout sauf IR)
netsh advfirewall firewall add rule name="IR_ISOLATION_BLOCK_ALL" dir=out action=block
netsh advfirewall firewall add rule name="IR_ISOLATION_ALLOW_IR" dir=out action=allow remoteip=10.0.99.5

# Isolation réseau — via EDR (exemple générique de commande d'isolation host)
# (syntaxe variable selon EDR : CrowdStrike, Defender for Endpoint, SentinelOne...)
edr-cli isolate-host --hostname WORKSTATION01 --reason "IR-2026-0142"

# Désactivation de compte compromis — Active Directory
Disable-ADAccount -Identity jdupont
Set-ADAccountPassword -Identity jdupont -Reset -NewPassword (ConvertTo-SecureString "TempP@ss!" -AsPlainText -Force)

# Désactivation de compte — Linux
usermod -L jdupont
usermod -s /usr/sbin/nologin jdupont

# Blocage IP au niveau firewall périmétrique (exemple iptables)
iptables -A INPUT -s 203.0.113.42 -j DROP
iptables -A OUTPUT -d 203.0.113.42 -j DROP
```

### Préservation des artefacts avant containment définitif

```text
□ Snapshot VM (si environnement virtualisé) avant toute action de containment
□ Acquisition mémoire complétée (voir Phase 2)
□ Image disque acquise si éradication imminente (voir digital-forensics-acquisition)
□ Export des logs EDR/SIEM locaux avant coupure réseau (perte de télémétrie possible)
```

!!! warning "Isolation réseau vs télémétrie EDR"
    Isoler un hôte du réseau peut couper la remontée de télémétrie vers l'EDR/SIEM cloud. Privilégier une isolation via l'agent EDR (qui conserve un canal de management) plutôt qu'une coupure réseau brutale, sauf urgence absolue (ransomware actif).

!!! danger "Ne pas alerter l'attaquant prématurément"
    Une désactivation de compte ou un blocage IP visible peut alerter un attaquant encore présent et déclencher une réaction destructive (wiper, chiffrement accéléré). Coordonner le containment simultané de tous les points d'accès identifiés.

---

## 5. Phase 4 : Éradication

```text
□ Suppression de la persistance
    □ Clés de registre Run/RunOnce malveillantes (voir fiche windows-forensics)
    □ Tâches planifiées non légitimes (schtasks /query, crontab -l)
    □ Services créés par l'attaquant
    □ Comptes locaux/AD créés par l'attaquant
    □ Clés SSH autorisées ajoutées (~/.ssh/authorized_keys)

□ Nettoyage de backdoors
    □ Webshells sur serveurs web (recherche par pattern + hash connus)
    □ Implants C2 (identifiés via IoC de la phase 2)
    □ Comptes de service détournés

□ Patching des vulnérabilités d'entrée
    □ Identification du vecteur d'accès initial (phishing, CVE exploitée, RDP exposé)
    □ Application du correctif ou de la mitigation
    □ Vérification qu'aucun autre système ne partage la même exposition
```

```bash
# Recherche de tâches planifiées suspectes — Windows
schtasks /query /fo LIST /v | findstr /i "TaskName Author"

# Recherche de tâches cron suspectes — Linux
for user in $(cut -f1 -d: /etc/passwd); do crontab -u $user -l 2>/dev/null; done
cat /etc/cron.d/* /etc/crontab

# Recherche de clés SSH ajoutées récemment
find / -name "authorized_keys" -mtime -30 2>/dev/null -exec ls -la {} \;

# Recherche de webshells (patterns communs PHP)
grep -rlE "(eval\(base64_decode|system\(\$_|passthru\(\$_)" /var/www/ 2>/dev/null
```

!!! danger "Éradication prématurée = échec"
    Ne jamais éradiquer avant d'avoir confirmé la **portée complète** de la compromission (Phase 2). Une éradication partielle laisse des backdoors résiduelles et l'attaquant peut revenir en quelques heures.

---

## 6. Phases 5 & 6 : Recouvrement & Retour d'Expérience

### Phase 5 — Recouvrement (Recovery)

```text
□ Restauration sécurisée
    □ Restauration depuis backup validé antérieur à la compromission (vérifier date)
    □ Scan complet (AV/EDR) des systèmes restaurés avant remise en production
    □ Rotation de tous les secrets potentiellement exposés (mots de passe, clés API, certificats)
    □ Remise en production progressive avec surveillance renforcée

□ Suivi post-incident (hypercare)
    □ Monitoring renforcé des IoC associés pendant 30-90 jours
    □ Alertes dédiées sur les comptes/systèmes impactés
    □ Point de suivi régulier avec les parties prenantes (quotidien puis hebdomadaire)
```

```powershell
# Rotation de mot de passe krbtgt (obligatoire après compromission AD, x2 avec délai)
# ATTENTION : impact potentiel sur les tickets Kerberos en cours — planifier la fenêtre
Reset-KrbtgtKeyInteractive.ps1  # script communautaire (ex: Microsoft/AD)
```

!!! warning "Restauration = pas de retour au même état"
    Restaurer un système sans corriger le vecteur d'entrée initial (Phase 4) recrée les conditions exactes de la compromission. Toujours valider le patching avant remise en production.

### Phase 6 — Retour d'Expérience (Lessons Learned)

```text
Structure type d'un rapport Post-Mortem
  1. Résumé exécutif (impact, durée, criticité)
  2. Timeline complète de l'incident (détection → résolution)
  3. Vecteur d'accès initial et root cause
  4. Actions réalisées par phase (Preparation → Lessons Learned)
  5. Indicateurs de compromission (IoC) identifiés
  6. Ce qui a bien fonctionné
  7. Ce qui a mal fonctionné / axes d'amélioration
  8. Actions correctives avec responsable et échéance
  9. Annexes techniques (logs, captures, artefacts)
```

| Question clé du debrief | Objectif |
|---|---|
| Quand la compromission a-t-elle réellement commencé vs quand a-t-elle été détectée ? | Évaluer et réduire le MTTD |
| Les procédures/playbooks ont-ils été suivis ? | Valider la pertinence de la préparation |
| Quels outils ont manqué ou ont été insuffisants ? | Prioriser les investissements outillage |
| La communication (interne/externe/légale) a-t-elle été adéquate et dans les délais ? | Conformité réglementaire (ex: NIS2, RGPD 72h) |

!!! tip "Réunion sans blâme (blameless post-mortem)"
    Le retour d'expérience doit rester factuel et orienté processus, jamais accusatoire envers un individu — l'objectif est l'amélioration systémique, pas la recherche d'un responsable.

!!! note "Boucle de rétroaction"
    Les actions correctives issues du Lessons Learned doivent directement alimenter la Phase 1 (Préparation) du prochain cycle : mise à jour des playbooks, ajout de règles de détection (voir fiche siem-fundamentals-rules), renforcement du tuning SOC.
