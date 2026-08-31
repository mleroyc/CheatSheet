# 🛠️ Commande : whoami

## 1. Description rapide

`whoami` affiche le **nom d'utilisateur effectif** du processus courant. Un seul rôle, zéro ambiguïté. Utilisé en post-exploitation pour confirmer l'identité après un exploit, un `sudo`, une impersonation ou un changement de contexte. Équivalent fonctionnel de `id -un`, mais plus rapide à taper et universellement disponible.

---

## 2. Syntaxe de base

```bash
whoami
```

Aucun argument requis. Aucune option impactante. Retourne une seule ligne : le nom d'utilisateur courant.

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `--help` | Affiche l'aide |
| `--version` | Affiche la version de l'utilitaire |

!!! note "Commande sans options"
    `whoami` est intentionnellement minimaliste. Pour une inspection plus riche (UID, GID, groupes), utiliser `id`. Pour l'identité dans un contexte SUID ou `sudo -u`, combiner avec `id`.

---

## 4. Exemples pratiques & Cas d'usage

```bash
# Vérifier l'identité courante (réflexe systématique en post-exploitation)
whoami
# → root
```

```bash
# Différence entre whoami et id -un (fonctionnellement identiques)
whoami
id -un
# Les deux retournent le nom d'utilisateur effectif — whoami est plus concis
```

```bash
# Utilisation dans un script pour une action conditionnelle selon l'utilisateur
if [ "$(whoami)" = "root" ]; then
    echo "Exécution avec droits root"
else
    echo "Utilisateur non privilégié : $(whoami)"
fi
```

```bash
# Vérifier l'identité après sudo (confirm que le contexte a bien changé)
sudo -u www-data whoami
# → www-data
```

```bash
# Confirmation d'identité dans une chaîne de commandes post-exploitation
whoami && id && hostname && cat /etc/passwd | grep "$(whoami)"
```

```bash
# Vérifier l'UID effectif dans un contexte SUID (identité peut différer du shell parent)
ls -la /usr/bin/whoami
# -rwsr-xr-x → si le binaire était SUID root, whoami retournerait "root"
```

---

## 5. Astuces & Pièges à éviter

!!! tip "Réflexe post-exploitation systématique"
    Après chaque élévation de privilèges (`sudo`, exploitation d'un SUID, `su`, reverse shell), enchaîner immédiatement `whoami && id` pour confirmer l'identité effective et les groupes avant d'aller plus loin.

!!! tip "whoami dans les scripts CI/CD et cron"
    Dans un script automatisé, `echo "Script lancé par : $(whoami)"` en début de log permet de tracer quel utilisateur a exécuté le script — indispensable pour le débogage des permissions en cron ou en pipeline CI.

!!! warning "whoami ≠ $USER dans tous les contextes"
    La variable `$USER` est définie par l'environnement shell et peut être incorrecte après un `su` sans `-l` ou dans certains contextes SUID. `whoami` interroge directement le noyau (via `geteuid()`) et retourne **toujours** l'identité effective réelle. Préférer `whoami` à `$USER` dans les scripts de sécurité.

!!! warning "Absence de whoami sur certains systèmes embarqués"
    Sur des systèmes très allégés (busybox minimal, containers stripped), `whoami` peut être absent. Alternative : `id -un` ou `grep "^$(id -u):" /etc/passwd | cut -d: -f1`.
