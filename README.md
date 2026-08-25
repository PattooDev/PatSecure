# PatSecure

**PatSecure** est un outil en Bash destiné à l'audit de sécurité et à la maintenance de **Deepin Linux**.

Son objectif est de présenter des contrôles compréhensibles, de ne rien modifier pendant un audit et de demander une confirmation avant chaque opération de maintenance.

## Version actuelle

**PatSecure v0.3.0 — 25 août 2026**

Cette version sépare clairement les fonctions en trois parties :

1. **Audit de sécurité** : contrôles en lecture seule, sans modification du système.
2. **Maintenance** : mise à jour et nettoyage avec confirmations successives.
3. **Rapports** : consultation du dernier rapport d'audit enregistré.

## Fonctions de l'audit

L'audit vérifie actuellement :

- les mises à jour connues en attente ;
- les paquets incomplets signalés par `dpkg` ;
- la présence et l'état réel du pare-feu UFW ;
- l'activité éventuelle du serveur SSH ;
- la présence et l'état de Fail2ban ;
- les ports TCP et UDP à l'écoute ;
- l'utilisation du disque système ;
- l'utilisation de la mémoire.

Certains contrôles peuvent demander les droits administrateur. Pendant l'audit, ces droits servent uniquement à lire des informations supplémentaires : aucune mise à jour, suppression ou modification n'est effectuée.

## Maintenance sécurisée

Le mode maintenance propose séparément :

- l'actualisation des dépôts avec `apt update` ;
- l'affichage des mises à jour disponibles ;
- l'installation des mises à jour normales avec `apt upgrade` ;
- une simulation de `apt autoremove` avant toute suppression ;
- le nettoyage des anciens fichiers de paquets avec `apt autoclean`.

Chaque opération susceptible de modifier le système demande une confirmation. PatSecure n'utilise plus `full-upgrade -y` ni de suppression automatique avec `autoremove -y`.

## Rapports

Chaque audit crée un rapport texte dans :

```text
~/.local/state/patsecure/reports/
```

Le rapport contient les résultats de l'audit et le détail des ports détectés. Il peut être affiché depuis le menu principal.

## Installation

### 1. Cloner le dépôt

```bash
git clone https://github.com/PattooDev/PatSecure.git
cd PatSecure
```

### 2. Installer les scripts

```bash
mkdir -p "$HOME/PatSecure/scripts" "$HOME/PatSecure/launch"
install -m 755 patsecure.sh "$HOME/PatSecure/scripts/patsecure.sh"
install -m 755 patsecure-launcher.sh "$HOME/PatSecure/launch/patsecure-launcher.sh"
```

### 3. Lancer PatSecure

```bash
"$HOME/PatSecure/launch/patsecure-launcher.sh"
```

Le lanceur utilise Deepin Terminal lorsqu'il est disponible et possède un mécanisme de repli pour les autres terminaux Linux.

## Utilisation directe

Afficher le menu :

```bash
"$HOME/PatSecure/scripts/patsecure.sh"
```

Afficher la version :

```bash
"$HOME/PatSecure/scripts/patsecure.sh" --version
```

Lancer directement l'audit :

```bash
"$HOME/PatSecure/scripts/patsecure.sh" --audit
```

## Organisation du dépôt

- `patsecure.sh` : programme principal ;
- `patsecure-launcher.sh` : lanceur compatible avec Deepin Terminal ;
- `CHANGELOG.md` : historique des versions ;
- `docs/` : documentation complémentaire ;
- `images/` et `screenshots/` : illustrations du projet.

## Limites actuelles

PatSecure v0.3.0 est une première base d'audit local. Il ne remplace pas un antivirus, un pare-feu correctement configuré ou l'analyse d'un spécialiste en cas d'intrusion suspectée.

Les résultats marqués **ATTENTION** doivent être examinés avant d'appliquer une modification.

## Projet

Projet développé par **PattooDev** pour faciliter l'audit et la maintenance de Deepin Linux.
