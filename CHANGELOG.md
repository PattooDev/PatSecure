# Historique des versions de PatSecure

Toutes les modifications importantes de PatSecure sont décrites dans ce fichier.

## [0.4.0] — 1er septembre 2026

### Ajouté

- Création de deux rapports distincts après chaque audit : **privé** et **partageable**.
- Dossiers séparés `reports/private/` et `reports/shareable/`.
- Rapport partageable sans adresse IP, adresse MAC, nom de machine ni nom d'utilisateur.
- Politique explicite : PatSecure n'interroge aucun service externe pour découvrir l'adresse IP publique.
- Conservation des sorties réseau brutes uniquement dans le rapport privé.
- Détection des écoutes réseau limitées à la boucle locale.
- Détection des écoutes génériques acceptant potentiellement des connexions sur plusieurs interfaces.
- Reconnaissance de services réseau courants : Avahi/mDNS sur UDP 5353, DHCPv6/NetworkManager sur UDP 546 et CUPS sur TCP 631.
- Contrôle de la présence d'IPv6 global sans enregistrer les adresses.
- Vérification de la prise en charge IPv6 par UFW et de la politique entrante par défaut.
- Détection UPnP/IGD lorsque `upnpc` est disponible, sans afficher ni enregistrer l'adresse externe.
- Diagnostic explicite du timeout UPnP lorsque la passerelle ne répond pas dans le délai prévu.
- Repli sur nftables lorsque UFW n'est pas installé.
- Résumé chiffré des résultats `OK`, `ATTENTION`, `ERREUR` et `INFO`.
- Consultation séparée du dernier rapport privé et du dernier rapport partageable.
- Options `--last-private-report` et `--last-shareable-report`.
- Documentation `docs/RAPPORTS.md`.

### Modifié

- Les rapports sont créés avec des permissions restrictives (`600`).
- Le détail de `dpkg --audit`, UFW, nftables et `ss` n'est plus recopié dans le rapport partageable.
- L'audit des ports distingue désormais les services connus des écoutes multi-interface inconnues.
- Une écoute sur plusieurs interfaces ne déclenche plus d'avertissement générique lorsqu'elle correspond uniquement à un service connu.
- IPv6 global est classé `OK` lorsque UFW est actif, gère IPv6 et applique une politique entrante `deny` ou `reject`.
- Un timeout UPnP est classé `INFO` et n'est plus présenté comme un résultat indéterminé.
- L'affichage des ressources ne publie plus le nom du périphérique de stockage dans le rapport partageable.
- Le menu principal distingue maintenant les rapports privés et partageables.
- Le nombre de sections d'audit passe de 6 à 7.

### Sécurité

- Réduction du risque de publier accidentellement une information réseau exploitable.
- Aucun appel à un service du type « quelle est mon IP » n'est effectué.
- La détection UPnP conserve seulement un résultat synthétique et ne stocke pas l'adresse externe annoncée par le routeur.
- Le diagnostic IPv6 s'appuie sur la configuration réelle d'UFW au lieu de considérer la seule présence d'IPv6 comme une alerte.
- Validation réelle sur Deepin 25 : audit final avec `9 OK`, `0 ATTENTION`, `0 ERREUR`.
- Validation séparée du rapport partageable : aucun motif IPv4, aucune adresse locale exacte, aucune adresse MAC, aucun nom de machine et aucun nom d'utilisateur détectés.

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

Cette version mélangeait l'audit et la maintenance. Elle est conservée dans l'historique, mais la v0.4.0 est désormais la version stable recommandée.
