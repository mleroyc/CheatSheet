# Cheat Sheet : `su` — Changement d'utilisateur (Substitute User)

!!! tip "Usage principal"
    Ouvrir une session complète sous l'identité d'un autre utilisateur (souvent root), en conservant cette identité jusqu'à sortie explicite du shell.

## 1. Syntaxe de base

```bash
# Structure générale
su [options] [utilisateur]
```

## 2. Commandes rapides & Cas d'usage fréquents

### Passer root
```bash
# Demande le mot de passe root et ouvre un shell root
su
```

### Passer root avec l'environnement complet
```bash
# Charge aussi les variables d'environnement et le .bashrc de root (recommandé)
su -
```

### Basculer vers un utilisateur précis
```bash
# Passe sous l'identité d'alice (demande son mot de passe)
su alice
```

### Exécuter une seule commande sous une autre identité
```bash
# Exécute la commande puis revient automatiquement à l'utilisateur d'origine
su -c "whoami" alice
```

## 3. Synthèse des Flags & Options (Tableau)

| Flag / Option | Rôle | Exemple d'utilisation |
| --- | --- | --- |
| `-` ou `-l` | Simule une connexion complète (environnement, répertoire home, `.bashrc`) | `su -` |
| `-c "cmd"` | Exécute une commande unique puis revient à l'utilisateur d'origine | `su -c "id" alice` |
| `-s /bin/bash` | Force le shell à utiliser pour la nouvelle session | `su -s /bin/bash alice` |
| (aucun argument) | Bascule vers root par défaut | `su` |

## 4. One-Liners & Pièges courants

```bash
# Vérifier rapidement l'identité après un su pour confirmer le contexte de privilège
su - && whoami
```

!!! warning "Attention"
    `su` sans le tiret (`-`) **conserve l'environnement de l'utilisateur d'origine** (variables `PATH`, alias, etc.), ce qui peut masquer des comportements attendus sous root ou, à l'inverse, être détourné pour exécuter un binaire malveillant placé dans un `PATH` modifié. Préférez systématiquement `su -` pour un changement d'identité propre. Contrairement à `sudo`, `su` nécessite de connaître le mot de passe du compte cible, pas celui de l'utilisateur courant.
