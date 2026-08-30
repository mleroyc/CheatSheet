# Cheat Sheet : Systemd & Services — Gestion, Persistance & Journalisation

!!! tip "Usage principal"
    Gérer le cycle de vie des services, créer des unités persistantes et exploiter `journalctl` pour la supervision — en administration comme en maintien d'accès post-exploitation.

---

## 1. Architecture Systemd vs SysVinit

### Équivalence Runlevels ↔ Targets

| Runlevel SysVinit | Target Systemd | Rôle |
| --- | --- | --- |
| `0` | `poweroff.target` | Arrêt du système |
| `1` | `rescue.target` | Mode maintenance (single-user) |
| `2`, `3`, `4` | `multi-user.target` | Multi-utilisateurs sans interface graphique |
| `5` | `graphical.target` | Multi-utilisateurs avec interface graphique |
| `6` | `reboot.target` | Redémarrage du système |

### Changer de target
```bash
# Bascule immédiatement vers une target (ex: mode maintenance)
systemctl isolate rescue.target
```

```bash
# Définit la target par défaut au prochain démarrage
systemctl set-default multi-user.target
```

```bash
# Affiche la target par défaut actuellement configurée
systemctl get-default
```

---

## 2. Gestion des Services avec `systemctl`

### Commandes fondamentales
```bash
systemctl start nginx      # démarre le service
systemctl stop nginx       # arrête le service
systemctl restart nginx    # arrête puis redémarre (coupe les connexions)
systemctl reload nginx     # recharge la config sans couper les connexions (si supporté)
systemctl status nginx     # affiche l'état, le PID et les derniers logs du service
```

```bash
systemctl enable nginx     # active le démarrage automatique au boot
systemctl disable nginx    # désactive le démarrage automatique au boot
systemctl is-active nginx  # renvoie "active" ou "inactive"
systemctl is-enabled nginx # renvoie "enabled" ou "disabled"
```

### Masquage (empêche tout démarrage, même manuel)
```bash
# mask crée un lien symbolique vers /dev/null, rendant le service inactivable
systemctl mask nginx
systemctl unmask nginx
```

!!! note "restart vs reload"
    `restart` interrompt le service le temps de redémarrer — les connexions actives sont coupées. `reload` demande au processus de relire sa configuration à chaud, sans interruption ; n'est disponible que si le service le supporte (ex: `nginx`, `sshd`).

### Lister et inspecter les services
```bash
systemctl list-units --type=service            # liste tous les services chargés
systemctl list-units --type=service --failed   # liste les services en échec
systemctl cat nginx                            # affiche le contenu du fichier .service actif
systemctl show nginx                           # affiche toutes les propriétés du service
```

---

## 3. Création d'un Service Systemd Persistant

### Emplacement et rechargement
```bash
# Dossier de référence pour les unités personnalisées (prioritaire sur /usr/lib/systemd/)
/etc/systemd/system/

# Toujours recharger le démon après création ou modification d'une unité
systemctl daemon-reload
```

### Structure minimale d'un fichier `.service`
```ini
# /etc/systemd/system/monservice.service

[Unit]
Description=Description courte du service
After=network.target            # s'assure que le réseau est disponible avant de démarrer

[Service]
Type=simple                     # le processus lancé par ExecStart est le service principal
ExecStart=/usr/local/bin/script.sh  # commande lancée au démarrage du service
Restart=always                  # relance automatiquement en cas d'échec ou de crash
RestartSec=5                    # attend 5 secondes avant de relancer
User=nobody                     # utilisateur sous lequel s'exécute le service

[Install]
WantedBy=multi-user.target      # active le service dans la target multi-user (équivalent runlevel 3)
```

### Activation du service personnalisé
```bash
# Activer et démarrer un service après l'avoir créé dans /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now monservice
systemctl status monservice
```

!!! note "Exemple de persistance (Red Team / maintien d'accès)"
    Le fichier `.service` ci-dessus peut servir de modèle pour maintenir en vie n'importe quel script d'arrière-plan : remplacer `ExecStart` par le chemin du binaire ou script souhaité, avec `Restart=always` pour la résilience. En Blue Team, auditer `/etc/systemd/system/` pour détecter des services inconnus — et contrôler `systemctl list-units --type=service --state=enabled` pour une vue complète.

---

## 4. Journalisation centralisée (`journalctl`)

### Filtres courants
```bash
journalctl -u nginx              # logs du service nginx uniquement
journalctl -u nginx -f           # suit les nouveaux logs en temps réel
journalctl -b                    # logs depuis le dernier boot
journalctl -b -1                 # logs du boot précédent (utile après un crash)
journalctl -p err                # uniquement les entrées de priorité "error" et plus
```

```bash
# Filtrage temporel : logs entre deux moments précis
journalctl --since "2024-01-01 08:00" --until "2024-01-01 12:00"
```

```bash
# Depuis un certain temps écoulé
journalctl --since "1 hour ago"
```

```bash
# Exporter les logs en JSON pour intégration SIEM ou analyse externe
journalctl -u nginx -o json > nginx_export.json
```

## Synthèse — Tableau des options `journalctl`

| Option | Rôle |
| --- | --- |
| `-u service` | Filtre par unité/service |
| `-f` | Mode suivi temps réel |
| `-b [N]` | Boot courant (ou N-ième boot précédent) |
| `-p PRIO` | Filtre par priorité (`emerg`, `alert`, `crit`, `err`, `warning`, `notice`, `info`, `debug`) |
| `--since DATE` | Logs à partir d'une date |
| `--until DATE` | Logs jusqu'à une date |
| `-n N` | Affiche les N dernières entrées |
| `-o json` | Export JSON |
| `--disk-usage` | Affiche l'espace disque utilisé par le journal |
| `--vacuum-size=500M` | Réduit le journal à 500 Mo maximum |

---

## 5. Gestion de l'Arrêt et du Redémarrage

```bash
systemctl reboot    # redémarre le système (via systemd)
systemctl poweroff  # arrête et coupe l'alimentation
systemctl halt      # arrête le système sans couper l'alimentation

shutdown -r now         # redémarre immédiatement
shutdown -h +10         # arrêt dans 10 minutes (envoie un message à tous les utilisateurs)
shutdown -c             # annule un arrêt/redémarrage planifié

reboot                  # alias de systemctl reboot
poweroff                # alias de systemctl poweroff
```

!!! tip "Planifier un arrêt avec message"
    `shutdown -h +30 "Maintenance en cours, enregistrez vos travaux."` envoie le message à tous les utilisateurs connectés et programme l'arrêt dans 30 minutes — plus propre qu'un `poweroff` immédiat en environnement multi-utilisateurs.
