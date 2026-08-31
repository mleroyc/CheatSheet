# 🛠️ Commande : groups

## 1. Description rapide

`groups` liste les **noms** de tous les groupes auxquels appartient un utilisateur (principal + secondaires). Plus lisible que `id -Gn` pour un usage humain rapide. Utilisée en audit de droits pour repérer d'un coup d'œil les appartenances à des groupes sensibles sans avoir à parser la sortie de `id`.

---

## 2. Syntaxe de base

```bash
groups [utilisateur]
```

Sans argument : groupes de l'utilisateur **courant**.  
Avec un nom d'utilisateur : groupes de **cet utilisateur** (lecture de `/etc/group`, pas besoin de droits élevés).

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `--help` | Affiche l'aide |
| `--version` | Affiche la version |

!!! note "Commande minimaliste"
    `groups` n'a pas d'options fonctionnelles. Pour des besoins avancés (UID/GID numériques, groupes effectifs vs réels), utiliser `id` avec ses flags (`-G`, `-Gn`, `-r`).

---

## 4. Exemples pratiques & Cas d'usage

```bash
# Lister les groupes de l'utilisateur courant
groups
# → alice sudo docker adm plugdev
```

```bash
# Lister les groupes d'un utilisateur tiers sans droits élevés
groups www-data
# → www-data: www-data
```

```bash
# Repérer rapidement les groupes à privilèges (audit post-exploitation)
groups | tr ' ' '\n' | grep -E "^(sudo|docker|wheel|lxd|disk|shadow|adm)$"
# Chaque ligne retournée = vecteur d'escalade potentiel
```

```bash
# Comparer les groupes de plusieurs utilisateurs du système
for user in $(cut -d: -f1 /etc/passwd); do
    echo "$user: $(groups $user 2>/dev/null)"
done
```

```bash
# Vérifier si l'utilisateur courant appartient au groupe docker (condition de script)
if groups | grep -qw docker; then
    echo "Membre du groupe docker — escalade possible"
fi
```

```bash
# Lister tous les membres d'un groupe spécifique (depuis /etc/group, sens inverse)
getent group docker
# → docker:x:998:alice,bob
```

---

## 5. Astuces & Pièges à éviter

!!! tip "groups vs id -Gn"
    Les deux retournent les noms des groupes. Différence : `groups` préfixe la sortie avec `utilisateur:` quand un argument est fourni (`groups alice` → `alice : alice sudo docker`), tandis que `id -Gn alice` retourne uniquement la liste. Pour les scripts, `id -Gn` est plus propre à parser.

!!! tip "Trouver tous les utilisateurs avec des groupes dangereux"
    ```bash
    for g in sudo docker wheel lxd shadow disk; do
        echo "=== Groupe $g ==="
        getent group $g | cut -d: -f4 | tr ',' '\n'
    done
    ```
    Cartographie rapide des comptes à risque sur un système à auditer.

!!! warning "groups reflète l'état au moment de la connexion"
    Comme `id`, `groups` affiche les groupes de la **session courante**. Si l'utilisateur a été ajouté à un groupe depuis la connexion, le nouveau groupe n'apparaît pas. Vérifier avec `getent group NOM_GROUPE` pour l'état réel du fichier `/etc/group`, indépendamment de la session.

!!! warning "groups ne distingue pas groupe principal et secondaires"
    `groups` liste tous les groupes sans indiquer lequel est le groupe principal (GID). Pour identifier le GID principal, utiliser `id -gn` (groupe principal) séparément de `id -Gn` (tous les groupes).
