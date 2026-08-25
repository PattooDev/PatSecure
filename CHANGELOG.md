# Historique des versions de PatSecure

Toutes les modifications importantes de PatSecure sont décrites dans ce fichier.

## [0.3.0] — 25 août 2026

### Ajouté

- Menu principal séparant l'audit, la maintenance et les rapports.
- Création automatique d'un rapport texte après chaque audit.
- Consultation du dernier rapport depuis le menu.
- Vérification des mises à jour connues en attente.
- Vérification des paquets incomplets avec `dpkg --audit`.
- Contrôle en lecture seule de l'état réel du pare-feu UFW.
- Détection du serveur SSH et avertissement lorsqu'il est actif.
- Vérification de Fail2ban.
- Comptage des ports TCP et UDP à l'écoute.
- Enregistrement du détail des ports dans le rapport.
- Options `--audit`, `--version` et `--help`.
- Lanceur portable recherchant automatiquement l'installation de PatSecure.
- Solution de repli lorsque Deepin Terminal n'est pas disponible.

### Modifié

- L'audit est désormais strictement séparé des opérations de maintenance.
- Les droits administrateur sont facultatifs pendant l'audit et servent uniquement aux contrôles en lecture seule.
- `apt upgrade` remplace la mise à niveau générale automatique.
- `apt autoremove` est précédé d'une simulation et d'une confirmation.
- Les opérations de maintenance demandent confirmation une par une.
- L'état d'UFW est obtenu avec `ufw status verbose` au lieu du seul état du service systemd.
- L'affichage réseau prend en compte TCP et UDP.
- Les messages distinguent les informations, les avertissements et les erreurs.

### Supprimé

- Exécution automatique de `apt full-upgrade -y`.
- Exécution automatique de `apt autoremove -y`.
- Chemin personnel `/home/Pattoo` codé en dur dans le lanceur.
- Message laissant croire que l'audit a réussi lorsqu'une opération de maintenance échoue.

## [0.2.1]

### Fonctions présentes

- Actualisation automatique des dépôts avec `apt update`.
- Mise à niveau automatique avec `apt full-upgrade -y`.
- Nettoyage automatique avec `apt autoremove -y` et `apt autoclean`.
- Vérification simple des services SSH, UFW et Fail2ban.
- Affichage de l'espace disque et de la mémoire.
- Affichage partiel des ports réseau en écoute.

Cette version mélangeait l'audit et la maintenance. Elle est conservée dans l'historique, mais la v0.3.0 est recommandée.

