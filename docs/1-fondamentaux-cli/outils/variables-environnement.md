# 🛠️ Notion / Shell : Variables d'environnement

## 1. Description rapide (Rôle et cas d'usage)

Les variables d'environnement stockent des valeurs accessibles par le shell et les processus qu'il lance. Une variable simple (`VAR=valeur`) reste locale au shell courant, tandis qu'une variable exportée (`export VAR=valeur`) devient accessible à tous les processus enfants. Elles configurent le comportement du système (`PATH`, `HOME`) et des applications (proxy, tokens d'API, mode debug).

## 2. Syntaxe de base

```bash
VAR=valeur              # variable locale au shell courant
export VAR=valeur       # variable exportée, héritée par les processus enfants
env
printenv [VAR]
```

## 3. Options, fanions et opérateurs principaux

| Élément | Effet |
|---|---|
| `VAR=valeur` | Déclare une variable locale au shell courant (non héritée par les enfants) |
| `export VAR=valeur` | Déclare/exporte une variable dans l'environnement des processus enfants |
| `env` | Affiche toutes les variables d'environnement exportées |
| `printenv VAR` | Affiche la valeur d'une variable d'environnement précise |
| `unset VAR` | Supprime une variable |
| `VAR=valeur commande` | Définit une variable pour la durée d'exécution d'une seule commande |
| `$VAR` / `${VAR}` | Référence la valeur de la variable |

## 4. Exemples pratiques & Cas d'usage

**Ajouter un répertoire de binaires personnels au PATH**
```bash
export PATH="$HOME/bin:$PATH"
```

**Définir un token d'API temporairement pour une seule commande**
```bash
API_TOKEN=abc123 ./deploiement.sh
```

**Rendre une variable de proxy permanente pour toutes les sessions**
```bash
echo 'export HTTPS_PROXY="http://proxy.local:3128"' >> ~/.bashrc
source ~/.bashrc
```

**Vérifier les variables clés d'un environnement avant de déboguer un script**
```bash
printenv USER HOME SHELL PWD
```

**Configurer une variable système globale pour tous les utilisateurs**
```bash
echo 'JAVA_HOME="/opt/java17"' | sudo tee -a /etc/environment
```

**Inspecter l'environnement complet d'un processus suspect (analyse d'incident)**
```bash
cat /proc/<PID>/environ | tr '\0' '\n'
```

## 5. Astuces & Pièges à éviter

!!! warning "Un PATH mal configuré est un risque d'injection de commande"
    Si `.` (répertoire courant) ou un répertoire accessible en écriture par d'autres utilisateurs figure dans `PATH` **avant** les répertoires système (`/usr/bin`), un attaquant peut y déposer un binaire malveillant portant le même nom qu'une commande courante (`ls`, `sudo`) pour qu'il soit exécuté à sa place. Vérifiez toujours l'ordre du `PATH` avec `echo $PATH`.

!!! tip "Variable locale vs exportée : bien distinguer la portée"
    `VAR=valeur` seul n'est visible que dans le shell courant, pas dans les scripts ou commandes lancés depuis ce shell. Sans `export`, un script appelé ne verra jamais la variable — erreur fréquente en débogage de script.

!!! tip "Choisir le bon fichier de persistance"
    `~/.bashrc` : variables pour les sessions interactives d'un utilisateur. `~/.profile` : variables chargées au login (shells de connexion). `/etc/environment` : variables globales pour tous les utilisateurs du système, indépendamment du shell utilisé.
