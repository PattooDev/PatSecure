# PatSecure

**PatSecure** est un outil Bash destiné à l'audit de sécurité et à la maintenance de **Deepin Linux**.

Son objectif est de présenter des contrôles compréhensibles, de ne rien modifier pendant un audit et de demander une confirmation avant chaque opération de maintenance.

## Version en développement

**PatSecure v0.4.0 — 1er septembre 2026**

La v0.4.0 renforce surtout l'audit réseau et la confidentialité des rapports.

### Principales nouveautés

- deux rapports distincts après chaque audit :
  - **rapport privé**, contenant les détails techniques utiles au diagnostic ;
  - **rapport partageable**, conçu pour GitHub, un site, un forum ou une demande d'aide ;
- aucune interrogation d'un service externe pour connaître l'adresse IP publique ;
- aucune adresse IP locale, adresse MAC, nom de machine ou nom d'utilisateur recopié dans le rapport partageable ;
- les sorties brutes de `ss`, UFW, nftables et `dpkg --audit` restent dans le rapport privé ;
- détection des écoutes réseau sur plusieurs interfaces ;
- reconnaissance de services courants comme Avahi/mDNS, DHCPv6/NetworkManager et CUPS ;
- les services multi-interface connus ne déclenchent plus d'avertissement générique ;
- détection de la présence d'IPv6 global sans enregistrer les adresses ;
- vérification de la prise en charge IPv6 par UFW et de la politique entrante par défaut ;
- détection UPnP/IGD lorsque `upnpc` est installé, sans afficher ni enregistrer l'adresse externe ;
- diagnostic explicite d'un timeout UPnP ;
- prise en compte de nftables lorsque UFW n'est pas disponible ;
- résumé chiffré des résultats `OK`, `ATTENTION`, `ERREUR` et `INFO`.

La branche stable `main` reste en v0.3.0 jusqu'à validation de cette version.

## Fonctions de l'audit

L'audit vérifie notamment :

- les mises à jour connues en attente dans le cache APT ;
- les paquets incomplets signalés par `dpkg` ;
- l'état du pare-feu UFW ou la présence de règles nftables ;
- la politique entrante par défaut d'UFW ;
- la prise en charge IPv6 par UFW ;
- l'activité éventuelle du serveur SSH ;
- la présence et l'état de Fail2ban ;
- les ports TCP et UDP à l'écoute ;
- les écoutes limitées à la boucle locale ;
- les écoutes génériques sur plusieurs interfaces ;
- les services réseau courants reconnus ;
- la présence d'IPv6 global ;
- la présence éventuelle d'une passerelle UPnP/IGD si `upnpc` est disponible ;
- l'utilisation du disque système ;
- l'utilisation de la mémoire.

Certains contrôles peuvent demander les droits administrateur. Pendant l'audit, ces droits servent uniquement à lire des informations supplémentaires : aucune mise à jour, suppression ou modification n'est effectuée.

## Confidentialité des rapports

Chaque audit crée deux fichiers.

### Rapport privé

```text
~/.local/state/patsecure/reports/private/
```

Il peut contenir :

- le nom de la machine ;
- le nom de l'utilisateur ;
- les sorties détaillées des commandes réseau ;
- les règles du pare-feu ;
- les informations utiles au diagnostic local.

**Ce rapport n'est pas destiné à être publié tel quel.**

### Rapport partageable

```text
~/.local/state/patsecure/reports/shareable/
```

Il contient uniquement les résultats synthétiques. PatSecure n'y copie pas :

- d'adresse IP locale ou publique ;
- d'adresse MAC ;
- de nom de machine ;
- de nom d'utilisateur ;
- de sortie réseau brute.

PatSecure **ne contacte aucun service Internet pour découvrir l'adresse IP publique**.

Les deux rapports sont créés avec des permissions restrictives (`600`) par défaut.

Voir aussi [`docs/RAPPORTS.md`](docs/RAPPORTS.md).

## Maintenance sécurisée

Le mode maintenance propose séparément :

- l'actualisation des dépôts avec `apt update` ;
- l'affichage des mises à jour disponibles ;
- l'installation des mises à jour normales avec `apt upgrade` ;
- une simulation de `apt autoremove` avant toute suppression ;
- le nettoyage des anciens fichiers de paquets avec `apt autoclean`.

Chaque opération susceptible de modifier le système demande une confirmation. PatSecure n'utilise pas `full-upgrade -y` ni de suppression automatique avec `autoremove -y`.

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

Afficher le dernier rapport privé :

```bash
"$HOME/PatSecure/scripts/patsecure.sh" --last-private-report
```

Afficher le dernier rapport partageable :

```bash
"$HOME/PatSecure/scripts/patsecure.sh" --last-shareable-report
```

## Organisation du dépôt

- `patsecure.sh` : programme principal ;
- `patsecure-launcher.sh` : lanceur compatible avec Deepin Terminal ;
- `CHANGELOG.md` : historique des versions ;
- `docs/INSTALL.md` : installation ;
- `docs/RAPPORTS.md` : confidentialité et utilisation des rapports.

## Limites

PatSecure est un outil d'audit local. Il ne remplace pas un antivirus, un pare-feu correctement configuré ou l'analyse d'un spécialiste en cas d'intrusion suspectée.

Un service en écoute sur plusieurs interfaces, la présence d'IPv6 ou d'UPnP ne signifie pas automatiquement que la machine est accessible depuis Internet. L'exposition réelle dépend notamment du pare-feu, du routeur, de la configuration IPv6 et des redirections de ports.

Les résultats marqués **ATTENTION** doivent être examinés avant d'appliquer une modification.

## Projet

Projet développé par **PattooDev** pour faciliter l'audit et la maintenance de Deepin Linux.
