# 🛠️ Commande / Notion : alias

## 1. Description rapide (Rôle et cas d'usage)

Un alias définit un raccourci pour une commande longue ou fréquemment utilisée. `alias` crée le raccourci, `unalias` le supprime. Un alias créé en session est temporaire ; pour le rendre permanent, il doit être ajouté au fichier de configuration du shell (`~/.bashrc`, `~/.zshrc` ou `~/.bash_aliases`). Les alias servent aussi bien à gagner en productivité qu'à sécuriser des commandes destructrices par défaut.

## 2. Syntaxe de base

```bash
alias nom='commande'
unalias nom
```

## 3. Options, fanions et raccourcis principaux

| Élément | Effet |
|---|---|
| `alias nom='cmd'` | Crée un alias temporaire pour la session courante |
| `alias` (seul) | Liste tous les alias actifs |
| `unalias nom` | Supprime un alias actif |
| `unalias -a` | Supprime tous les alias actifs |
| `\commande` | Exécute la commande réelle en ignorant tout alias existant |
| `command commande` | Idem : contourne l'alias et appelle le binaire d'origine |
| `source ~/.bashrc` | Recharge la configuration du shell après modification |

## 4. Exemples pratiques & Cas d'usage

**Créer un raccourci de productivité pour un listing détaillé**
```bash
alias ll='ls -la'
```

**Sécuriser les commandes destructrices en session interactive**
```bash
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
```

**Rendre un alias permanent en le plaçant dans le fichier de configuration**
```bash
echo "alias ll='ls -la'" >> ~/.bashrc
source ~/.bashrc
```

**Créer un alias pour un scan réseau récurrent en pentest**
```bash
alias qscan='nmap -sV -T4 -oN scan_rapide.txt'
```

**Créer un alias pour surveiller rapidement les connexions réseau actives**
```bash
alias netcheck='ss -tulpn'
```

**Contourner temporairement un alias de sécurité pour un usage ponctuel**
```bash
alias rm='rm -i'
\rm -f fichier_temporaire.log
```

## 5. Astuces & Pièges à éviter

!!! tip "Centraliser ses alias dans ~/.bash_aliases"
    Plutôt que de surcharger `~/.bashrc`, créez un fichier dédié `~/.bash_aliases` et faites-le charger depuis `~/.bashrc` via `if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi` — plus lisible et plus simple à versionner séparément (dotfiles).

!!! warning "Un alias de sécurité (rm -i) n'est actif qu'en session interactive"
    `alias rm='rm -i'` protège contre les suppressions accidentelles au clavier, mais un script shell exécuté (`.sh`) n'utilise **pas** les alias par défaut : `rm` s'y comportera normalement (sans confirmation). Ne comptez jamais sur un alias pour sécuriser un script automatisé.

!!! tip "Contourner un alias sans le supprimer"
    `\commande` ou `command commande` permettent d'exécuter le binaire réel en ignorant temporairement l'alias, sans avoir à faire `unalias` puis le redéfinir ensuite — pratique pour un usage ponctuel de la commande "brute".

!!! warning "Toujours recharger la config après modification"
    Ajouter un alias dans `~/.bashrc` n'a aucun effet sur les sessions déjà ouvertes tant que `source ~/.bashrc` n'a pas été exécuté (ou qu'un nouveau terminal n'a pas été ouvert) — une source d'erreur fréquente ("mon alias ne marche pas").
