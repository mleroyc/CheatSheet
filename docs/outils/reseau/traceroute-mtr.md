# 🛠️ traceroute & mtr — Analyse de Route & Diagnostic de Chemin

## 1. Description rapide

**traceroute** trace le chemin L3 (routeurs intermédiaires) entre la source et une destination en exploitant le champ TTL des paquets IP. **mtr** (*My Traceroute*) combine traceroute et ping en une vue dynamique et continue, avec statistiques de perte et latence **par saut**. `mtr` est supérieur à `traceroute` pour le diagnostic de problèmes intermittents.

---

## 2. Syntaxe de base

```bash
# traceroute
traceroute [options] destination

# mtr
mtr [options] destination
```

---

## 3. Options et fanions principaux

### traceroute

| Flag | Rôle |
| --- | --- |
| `-n` | Pas de résolution DNS (plus rapide) |
| `-I` | Utilise ICMP Echo au lieu d'UDP (par défaut) |
| `-T` | Utilise TCP SYN (contourne certains firewalls) |
| `-p PORT` | Port de destination pour le mode TCP |
| `-m N` | Nombre maximum de sauts (défaut : 30) |
| `-q N` | Nombre de sondes par saut (défaut : 3) |
| `-w N` | Timeout par sonde en secondes |
| `-s SIZE` | Taille du paquet de sonde |

### mtr

| Flag | Rôle |
| --- | --- |
| `-n` | Pas de résolution DNS |
| `-r` | Mode rapport (non interactif, affiche le résultat puis quitte) |
| `-c N` | Nombre de cycles de sonde avant de quitter (avec `-r`) |
| `--tcp` | Mode TCP SYN |
| `--udp` | Mode UDP |
| `-P PORT` | Port cible pour TCP/UDP |
| `-i N` | Intervalle entre les sondes (secondes) |
| `-b` | Affiche à la fois l'IP et le hostname |

---

## 4. Exemples pratiques

```bash
# traceroute sans résolution DNS vers une cible (rapide, moins de latence d'affichage)
traceroute -n 8.8.8.8
```

```bash
# traceroute en mode ICMP (passe mieux les firewalls bloquant UDP)
traceroute -I 8.8.8.8
```

```bash
# traceroute TCP sur le port 443 (contourne les firewalls bloquant UDP et ICMP)
traceroute -T -p 443 -n target.com
```

```bash
# mtr en mode rapport (non interactif, 10 cycles, sans résolution DNS)
mtr -n -r -c 10 8.8.8.8
```

```bash
# mtr interactif avec hostname + IP pour identifier les sauts suspects
mtr -b target.com
```

```bash
# Détecter une perte de paquets localisée sur un saut précis (diagnostic ISP)
mtr -n -r -c 50 8.8.8.8 | awk '{if ($3 > 0) print $0}'
```

---

## 5. Astuces & Pièges à éviter

!!! tip "mtr > traceroute pour le diagnostic"
    `traceroute` effectue une mesure ponctuelle qui peut rater les problèmes intermittents. `mtr -r -c 100` effectue 100 cycles et affiche les statistiques min/avg/max/stddev + pourcentage de perte **par saut** — bien supérieur pour localiser un nœud défaillant.

!!! tip "Sauts à * * * ne signifient pas toujours un problème"
    Un saut qui renvoie `* * *` ne répond pas aux sondes ICMP/UDP mais **continue de relayer le trafic**. C'est une configuration courante sur les routeurs d'infrastructure qui désactivent la génération de TTL-expired. Le diagnostic est compromis uniquement si les sauts SUIVANTS sont aussi en `* * *`.

!!! warning "traceroute UDP peut être bloqué en entreprise"
    Le mode par défaut de `traceroute` Linux utilise UDP sur les ports 33434+. Ces ports sont souvent bloqués par les firewalls d'entreprise, donnant des résultats incomplets. Utiliser `-I` (ICMP) ou `-T -p 443` (TCP HTTPS) pour contourner.

!!! warning "mtr en mode interactif modifie le terminal"
    `mtr` en mode interactif utilise ncurses et prend le contrôle du terminal. Appuyer sur `q` pour quitter proprement. Ne pas fermer le terminal brutalement si le rapport final est attendu — utiliser `mtr -r -c N` pour un mode non interactif scriptable.
