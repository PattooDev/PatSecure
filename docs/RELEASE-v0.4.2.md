# PatSecure v0.4.2 — Diagnostic APT plus fiable

Publication du 20 septembre 2026.

Cette version améliore la fiabilité de la section « Mises à jour et paquets » sans modifier la philosophie de PatSecure : l’audit reste en lecture seule et ne déclenche aucune mise à jour automatiquement.

## Principaux changements

- comptage de `apt list --upgradable` indépendant du texte d’en-tête et de la langue d’affichage ;
- contrôle de l’âge approximatif des index APT sans lancer `apt update` pendant l’audit ;
- cache APT de moins de 48 h classé `OK` ;
- cache APT entre 48 h et 7 jours signalé en `INFO` ;
- cache APT de plus de 7 jours signalé en `ATTENTION` afin d’éviter un faux sentiment de système à jour ;
- ajout d’un test automatique dédié à ces nouveaux contrôles ;
- possibilité de sourcer `patsecure.sh` depuis les tests sans ouvrir le menu interactif.

## Validation sur Deepin 25

- tests APT : **4 PASS, 0 FAIL** ;
- audit complet réel : **13 OK, 12 INFO, 0 ATTENTION, 0 ERREUR** ;
- index APT détectés comme récents : environ **7 h** au moment du test ;
- UFW actif avec politique entrante restrictive ;
- IPv6 pris en charge par UFW ;
- aucune adresse IP locale/publique, adresse MAC, nom de machine ou nom d’utilisateur ajouté au rapport partageable.

## Important

Le résultat « aucune mise à jour connue » reste volontairement lié au cache APT présent sur la machine. PatSecure indique désormais explicitement si ce cache est récent ou suffisamment ancien pour nécessiter un `apt update` manuel en mode maintenance.

Voir aussi le [CHANGELOG](../CHANGELOG.md).
