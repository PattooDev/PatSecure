# PatSecure v0.4.1 — Classification réseau contextuelle

Publication du 10 septembre 2026.

Cette version améliore principalement l’audit réseau afin de réduire les faux avertissements tout en conservant une détection prudente des services réellement à vérifier.

## Principaux changements

- classification des sockets selon le protocole, la portée, le port et le processus associé ;
- distinction explicite entre boucle locale, interface réseau et écoute sur toutes les interfaces ;
- écoutes limitées à `127.0.0.1` ou `::1` classées `OK` ;
- Avahi/mDNS, DHCPv6/NetworkManager et sockets UDP éphémères identifiées classés `INFO` ;
- écoutes TCP hors boucle locale classées `ATTENTION` sans conclure à une exposition Internet ;
- sockets UDP non reconnues et non éphémères conservées en `ATTENTION` ;
- regroupement des doublons IPv4/IPv6 dans l’affichage synthétique ;
- sortie brute de `ss` conservée uniquement dans le rapport privé ;
- rapport partageable sans adresse IP, adresse MAC, nom de machine ni nom d’utilisateur ;
- suppression d’anciens scripts obsolètes qui pouvaient encore lancer `full-upgrade -y` / `autoremove -y` ;
- documentation réseau et tests dédiés ajoutés.

## Validation sur Deepin 25

- tests unitaires du classificateur : **11 PASS, 0 FAIL** ;
- test réseau réel : **OK=5, INFO=3, ATTENTION=0, ERREUR=0** ;
- audit complet : **12 OK, 12 INFO, 0 ATTENTION, 0 ERREUR** ;
- UFW actif avec politique entrante restrictive ;
- IPv6 pris en charge par UFW ;
- aucune adresse IP affichée dans la synthèse réseau.

## Important

PatSecure ne déduit jamais une exposition Internet à partir de `ss` seul. Une écoute sur `0.0.0.0` ou `[::]` signifie qu’un service écoute sur la machine, mais ne prouve pas qu’il est accessible depuis Internet. L’exposition réelle dépend également du pare-feu, du routeur, des redirections de ports et du filtrage IPv6.

Voir aussi le [CHANGELOG](../CHANGELOG.md).
