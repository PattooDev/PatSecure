#!/usr/bin/env bash

# ==========================================================
# PatSecure v0.4.0
# Audit de sécurité et maintenance pour Deepin Linux
# ==========================================================

set -u
umask 077

VERSION="0.4.0"

VERT="\e[32m"
ROUGE="\e[31m"
JAUNE="\e[33m"
BLEU="\e[36m"
GRAS="\e[1m"
FIN="\e[0m"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/patsecure"
REPORT_DIR="$STATE_DIR/reports"
PRIVATE_REPORT_DIR="$REPORT_DIR/private"
SHARE_REPORT_DIR="$REPORT_DIR/shareable"

PRIVATE_REPORT_FILE=""
SHARE_REPORT_FILE=""
AUDIT_SUDO=0

COUNT_OK=0
COUNT_ATTENTION=0
COUNT_ERREUR=0
COUNT_INFO=0

clear_screen() {
    if [[ -t 1 && -n "${TERM:-}" ]]; then
        clear
    fi
}

pause_screen() {
    if [[ -t 0 ]]; then
        echo
        read -r -p "Appuyez sur Entrée pour continuer..." _
    fi
}

confirm() {
    local prompt="$1"
    local answer

    read -r -p "$prompt [o/N] " answer
    [[ "$answer" =~ ^[oOyY]$ ]]
}

title() {
    clear_screen
    echo -e "${BLEU}${GRAS}"
    echo "====================================================="
    echo "                 PatSecure v${VERSION}"
    echo "       Audit et maintenance de Deepin Linux"
    echo "====================================================="
    echo -e "${FIN}"
}

report_line() {
    local line="$*"

    if [[ -n "$PRIVATE_REPORT_FILE" ]]; then
        printf '%s\n' "$line" >> "$PRIVATE_REPORT_FILE"
    fi

    if [[ -n "$SHARE_REPORT_FILE" ]]; then
        printf '%s\n' "$line" >> "$SHARE_REPORT_FILE"
    fi
}

private_line() {
    if [[ -n "$PRIVATE_REPORT_FILE" ]]; then
        printf '%s\n' "$*" >> "$PRIVATE_REPORT_FILE"
    fi
}

section() {
    echo
    echo -e "${BLEU}${GRAS}$1${FIN}"
    report_line ""
    report_line "$1"
}

result() {
    local level="$1"
    local message="$2"

    case "$level" in
        OK)
            ((COUNT_OK+=1))
            echo -e "  ${VERT}[OK]${FIN} $message"
            ;;
        ATTENTION)
            ((COUNT_ATTENTION+=1))
            echo -e "  ${JAUNE}[ATTENTION]${FIN} $message"
            ;;
        ERREUR)
            ((COUNT_ERREUR+=1))
            echo -e "  ${ROUGE}[ERREUR]${FIN} $message"
            ;;
        INFO)
            ((COUNT_INFO+=1))
            echo "  [INFO] $message"
            ;;
        *)
            ((COUNT_INFO+=1))
            echo "  [INFO] $message"
            level="INFO"
            ;;
    esac

    report_line "[$level] $message"
}

start_reports() {
    local timestamp
    local today

    mkdir -p -- "$PRIVATE_REPORT_DIR" "$SHARE_REPORT_DIR" || {
        echo -e "${ROUGE}Impossible de créer le dossier des rapports.${FIN}"
        return 1
    }

    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
    today="$(date '+%Y-%m-%d')"

    PRIVATE_REPORT_FILE="$PRIVATE_REPORT_DIR/audit-$timestamp.txt"
    SHARE_REPORT_FILE="$SHARE_REPORT_DIR/audit-partageable-$timestamp.txt"

    {
        echo "PatSecure v${VERSION} — Rapport d'audit privé"
        echo "Date : $(date '+%d/%m/%Y %H:%M:%S %Z')"
        echo "Utilisateur : ${USER:-inconnu}"
        echo "Machine : $(hostname 2>/dev/null || echo inconnue)"
        echo "Système : $(uname -srmo 2>/dev/null || echo inconnu)"
        echo ""
        echo "Ce rapport privé peut contenir des détails locaux techniques."
        echo "Ne pas le publier sans vérification."
    } > "$PRIVATE_REPORT_FILE"

    {
        echo "PatSecure v${VERSION} — Rapport partageable"
        echo "Date : $today"
        echo ""
        echo "Confidentialité :"
        echo "- aucune adresse IP publique n'est interrogée ni enregistrée ;"
        echo "- aucune adresse IP locale n'est copiée dans ce rapport ;"
        echo "- aucune adresse MAC n'est copiée dans ce rapport ;"
        echo "- le nom de la machine et le nom d'utilisateur sont omis ;"
        echo "- les sorties brutes des commandes réseau restent uniquement dans le rapport privé."
    } > "$SHARE_REPORT_FILE"

    chmod 600 "$PRIVATE_REPORT_FILE" "$SHARE_REPORT_FILE" 2>/dev/null || true
}

prepare_read_only_sudo() {
    echo
    echo "Certains contrôles en lecture seule sont plus précis avec les droits administrateur."
    echo "Aucune modification ne sera effectuée pendant l'audit."

    if confirm "Autoriser ces contrôles"; then
        if sudo -v; then
            AUDIT_SUDO=1
            result INFO "Contrôles administrateur en lecture seule autorisés."
        else
            result ATTENTION "Droits administrateur non obtenus ; audit limité."
        fi
    else
        result INFO "Audit lancé sans droits administrateur."
    fi
}

audit_updates() {
    local count
    local dpkg_output

    section "[1/7] Mises à jour et paquets"

    if command -v apt >/dev/null 2>&1; then
        count="$(apt list --upgradable 2>/dev/null | sed '1d' | awk 'NF' | wc -l | tr -d ' ')"
        if [[ "$count" == "0" ]]; then
            result OK "Aucune mise à jour connue en attente dans le cache APT actuel."
        else
            result ATTENTION "$count mise(s) à jour connue(s) en attente dans le cache APT actuel."
        fi
    else
        result ERREUR "La commande apt est introuvable."
    fi

    if command -v dpkg >/dev/null 2>&1; then
        dpkg_output="$(dpkg --audit 2>&1)"
        if [[ -z "$dpkg_output" ]]; then
            result OK "Aucun paquet incomplet détecté par dpkg."
        else
            result ATTENTION "dpkg signale des paquets à vérifier."
            private_line "Détail dpkg --audit :"
            private_line "$dpkg_output"
        fi
    fi

    if command -v flatpak >/dev/null 2>&1; then
        result INFO "Flatpak est installé ; les mises à jour Flatpak ne sont pas appliquées pendant l'audit."
    else
        result INFO "Flatpak n'est pas installé."
    fi
}

audit_firewall() {
    local ufw_output
    local nft_output

    section "[2/7] Pare-feu"

    if command -v ufw >/dev/null 2>&1; then
        if (( AUDIT_SUDO == 0 )); then
            result ATTENTION "UFW est installé, mais son état réel n'est pas vérifié sans droits administrateur."
            return
        fi

        ufw_output="$(LC_ALL=C sudo ufw status verbose 2>&1)"
        private_line "Détail UFW :"
        private_line "$ufw_output"

        if grep -q '^Status: active' <<< "$ufw_output"; then
            result OK "Le pare-feu UFW est actif."
        else
            result ATTENTION "Le pare-feu UFW est inactif ou son état est indéterminé."
        fi
        return
    fi

    if command -v nft >/dev/null 2>&1; then
        if (( AUDIT_SUDO == 0 )); then
            result INFO "UFW absent ; nftables est disponible mais ses règles ne sont pas lues sans droits administrateur."
            return
        fi

        nft_output="$(sudo nft list ruleset 2>&1 || true)"
        private_line "Détail nftables :"
        private_line "$nft_output"

        if [[ -n "$(sed '/^[[:space:]]*$/d' <<< "$nft_output")" ]]; then
            result INFO "UFW absent ; un jeu de règles nftables est présent."
        else
            result ATTENTION "Aucune règle UFW ou nftables exploitable n'a été détectée."
        fi
        return
    fi

    result ATTENTION "Aucun outil de pare-feu UFW ou nftables n'a été détecté."
}

service_exists() {
    local service="$1"
    systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null | grep -q "^${service}\.service"
}

audit_services() {
    local ssh_service=""

    section "[3/7] Services sensibles"

    if service_exists ssh; then
        ssh_service="ssh"
    elif service_exists sshd; then
        ssh_service="sshd"
    fi

    if [[ -z "$ssh_service" ]]; then
        result INFO "Serveur SSH non installé."
    elif systemctl is-active --quiet "$ssh_service"; then
        result ATTENTION "Le serveur SSH est actif ; vérifier qu'il est réellement nécessaire."
    else
        result OK "Le serveur SSH est installé mais inactif."
    fi

    if ! service_exists fail2ban; then
        result INFO "Fail2ban n'est pas installé."
    elif systemctl is-active --quiet fail2ban; then
        result OK "Fail2ban est actif."
    else
        result ATTENTION "Fail2ban est installé mais inactif."
    fi
}

audit_listening_ports() {
    local ports_output
    local tcp_count
    local udp_count
    local wildcard_count
    local loopback_count

    section "[4/7] Ports réseau à l'écoute"

    if ! command -v ss >/dev/null 2>&1; then
        result ERREUR "La commande ss est introuvable."
        return
    fi

    if (( AUDIT_SUDO == 1 )); then
        ports_output="$(sudo ss -tulpnH 2>&1)"
    else
        ports_output="$(ss -tulnH 2>&1)"
    fi

    if [[ -z "$ports_output" ]]; then
        result OK "Aucun port TCP ou UDP à l'écoute n'a été détecté."
        return
    fi

    private_line "Détail des ports à l'écoute :"
    private_line "$ports_output"

    tcp_count="$(awk '$1 == "tcp" {count++} END {print count+0}' <<< "$ports_output")"
    udp_count="$(awk '$1 == "udp" {count++} END {print count+0}' <<< "$ports_output")"
    wildcard_count="$(awk '$5 ~ /^0\.0\.0\.0:/ || $5 ~ /^\[::\]:/ || $5 ~ /^\*:/ {count++} END {print count+0}' <<< "$ports_output")"
    loopback_count="$(awk '$5 ~ /^127\./ || $5 ~ /^\[::1\]:/ {count++} END {print count+0}' <<< "$ports_output")"

    result INFO "$tcp_count écoute(s) TCP et $udp_count écoute(s) UDP détectée(s)."
    result INFO "$loopback_count écoute(s) limitée(s) à la boucle locale détectée(s)."

    if (( wildcard_count > 0 )); then
        result ATTENTION "$wildcard_count écoute(s) accepte(nt) potentiellement des connexions sur plusieurs interfaces. Cela ne prouve pas une exposition Internet."
    else
        result OK "Aucune écoute générique sur toutes les interfaces n'a été repérée."
    fi

    echo "  Le détail technique reste uniquement dans le rapport privé."
}

audit_network_exposure() {
    local ipv6_count
    local upnp_output=""
    local upnp_status=2

    section "[5/7] Exposition réseau et confidentialité"

    result OK "PatSecure n'interroge aucun service externe pour connaître l'adresse IP publique."
    result OK "Le rapport partageable exclut les adresses IP, les adresses MAC, le nom de machine et le nom d'utilisateur."

    if command -v ip >/dev/null 2>&1; then
        ipv6_count="$(ip -6 -o addr show scope global 2>/dev/null | wc -l | tr -d ' ')"
        if (( ipv6_count > 0 )); then
            result ATTENTION "IPv6 global est présent sur au moins une interface ; l'exposition dépend du pare-feu et des services en écoute."
        else
            result INFO "Aucune adresse IPv6 globale n'a été détectée sur les interfaces."
        fi
    else
        result INFO "La commande ip est introuvable ; contrôle IPv6 ignoré."
    fi

    if command -v upnpc >/dev/null 2>&1; then
        if command -v timeout >/dev/null 2>&1; then
            if upnp_output="$(timeout 7 upnpc -l 2>&1)"; then
                upnp_status=0
            else
                upnp_status=$?
            fi
        else
            if upnp_output="$(upnpc -l 2>&1)"; then
                upnp_status=0
            else
                upnp_status=$?
            fi
        fi

        if grep -qi 'No IGD UPnP Device found' <<< "$upnp_output"; then
            result OK "Aucune passerelle UPnP/IGD n'a été trouvée sur le réseau local."
        elif (( upnp_status == 0 )); then
            result ATTENTION "Une passerelle UPnP/IGD répond sur le réseau local. Son adresse externe n'est ni affichée ni enregistrée par PatSecure."
        else
            result INFO "La détection UPnP n'a pas permis de conclure."
        fi
    else
        result INFO "L'outil upnpc n'est pas installé ; la détection active UPnP est ignorée."
    fi
}

audit_resources() {
    local disk_percent
    local memory_percent

    section "[6/7] Ressources du système"

    disk_percent="$(df -P / 2>/dev/null | awk 'NR == 2 {print $5}')"
    memory_percent="$(free -m 2>/dev/null | awk '/^Mem:/ {if ($2 > 0) printf "%.0f%%", ($3/$2)*100}')"

    if [[ -n "$disk_percent" ]]; then
        result INFO "Occupation du disque système : $disk_percent."
    else
        result INFO "Occupation du disque système non déterminée."
    fi

    if [[ -n "$memory_percent" ]]; then
        result INFO "Mémoire utilisée au moment de l'audit : $memory_percent."
    else
        result INFO "Utilisation mémoire non déterminée."
    fi
}

audit_summary() {
    section "[7/7] Résumé"

    echo "  [OK]         $COUNT_OK"
    echo "  [ATTENTION]  $COUNT_ATTENTION"
    echo "  [ERREUR]     $COUNT_ERREUR"
    echo "  [INFO]       $COUNT_INFO"

    report_line "[RÉSUMÉ] OK=$COUNT_OK ATTENTION=$COUNT_ATTENTION ERREUR=$COUNT_ERREUR INFO=$COUNT_INFO"
    report_line "[INFO] L'audit n'a effectué aucune mise à jour, suppression ou modification."
    report_line "[INFO] Une écoute réseau ou la présence d'IPv6 ne suffit pas, à elle seule, à prouver une exposition depuis Internet."
    report_line "[INFO] Les éléments [ATTENTION] doivent être vérifiés avant toute réparation."
}

run_audit() {
    title

    AUDIT_SUDO=0
    COUNT_OK=0
    COUNT_ATTENTION=0
    COUNT_ERREUR=0
    COUNT_INFO=0
    PRIVATE_REPORT_FILE=""
    SHARE_REPORT_FILE=""

    echo "Mode AUDIT : lecture seule, sans modification du système."
    echo "Deux rapports seront produits : privé et partageable."

    if ! start_reports; then
        pause_screen
        return
    fi

    prepare_read_only_sudo
    audit_updates
    audit_firewall
    audit_services
    audit_listening_ports
    audit_network_exposure
    audit_resources
    audit_summary

    echo
    echo "====================================================="
    echo -e "${VERT}Audit terminé sans modification.${FIN}"
    echo "Rapport privé      : $PRIVATE_REPORT_FILE"
    echo "Rapport partageable: $SHARE_REPORT_FILE"
    echo "====================================================="

    private_line ""
    private_line "Audit terminé sans modification."
    report_line ""
    report_line "Fin du rapport."

    pause_screen
}

run_maintenance() {
    local apt_result

    title
    echo -e "${JAUNE}${GRAS}Mode MAINTENANCE${FIN}"
    echo "Les commandes susceptibles de modifier le système demanderont confirmation."
    echo

    if ! sudo -v; then
        echo -e "${ROUGE}Droits administrateur non obtenus. Maintenance annulée.${FIN}"
        pause_screen
        return
    fi

    if ! confirm "Actualiser la liste des paquets avec apt update"; then
        echo "Maintenance annulée."
        pause_screen
        return
    fi

    if ! sudo apt update; then
        echo -e "${ROUGE}Échec de apt update. Aucune autre opération n'est lancée.${FIN}"
        pause_screen
        return
    fi

    echo
    echo "Mises à jour disponibles :"
    apt list --upgradable 2>/dev/null

    if confirm "Installer les mises à jour normales avec apt upgrade"; then
        if ! sudo apt upgrade; then
            echo -e "${ROUGE}La mise à jour s'est terminée avec une erreur.${FIN}"
        fi
    else
        echo "Installation des mises à jour ignorée."
    fi

    echo
    echo "Simulation du nettoyage des paquets inutiles :"
    apt_result="$(sudo apt-get --simulate autoremove 2>&1)"
    printf '%s\n' "$apt_result"

    if confirm "Lancer apt autoremove sans réponse automatique"; then
        sudo apt autoremove
    else
        echo "Suppression des paquets inutiles ignorée."
    fi

    if confirm "Nettoyer les anciens fichiers de paquets avec apt autoclean"; then
        sudo apt autoclean
    else
        echo "Nettoyage du cache ignoré."
    fi

    echo
    echo -e "${VERT}Maintenance terminée.${FIN}"
    pause_screen
}

latest_report() {
    local directory="$1"
    local pattern="$2"

    if [[ -d "$directory" ]]; then
        find "$directory" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
            | sort -nr | head -n 1 | cut -d' ' -f2-
    fi
}

show_last_report() {
    local type="$1"
    local latest=""
    local directory=""
    local pattern=""
    local label=""

    title

    case "$type" in
        private)
            directory="$PRIVATE_REPORT_DIR"
            pattern='audit-*.txt'
            label="privé"
            ;;
        shareable)
            directory="$SHARE_REPORT_DIR"
            pattern='audit-partageable-*.txt'
            label="partageable"
            ;;
        *)
            echo "Type de rapport inconnu."
            pause_screen
            return
            ;;
    esac

    latest="$(latest_report "$directory" "$pattern")"

    if [[ -z "$latest" || ! -f "$latest" ]]; then
        echo "Aucun rapport $label n'est encore disponible."
    else
        echo "Dernier rapport $label : $latest"
        echo "====================================================="
        sed -n '1,260p' "$latest"
    fi

    pause_screen
}

main_menu() {
    local choice

    while true; do
        title
        echo "1) Audit de sécurité — aucune modification"
        echo "2) Maintenance — actions confirmées une par une"
        echo "3) Afficher le dernier rapport privé"
        echo "4) Afficher le dernier rapport partageable"
        echo "5) Quitter"
        echo
        read -r -p "Votre choix : " choice

        case "$choice" in
            1) run_audit ;;
            2) run_maintenance ;;
            3) show_last_report private ;;
            4) show_last_report shareable ;;
            5) echo "Au revoir."; exit 0 ;;
            *)
                echo -e "${JAUNE}Choix invalide.${FIN}"
                sleep 1
                ;;
        esac
    done
}

case "${1:-}" in
    --audit)
        run_audit
        ;;
    --last-private-report)
        show_last_report private
        ;;
    --last-shareable-report)
        show_last_report shareable
        ;;
    --version)
        echo "PatSecure v${VERSION}"
        ;;
    --help|-h)
        echo "Utilisation : $0 [--audit|--last-private-report|--last-shareable-report|--version|--help]"
        ;;
    "")
        main_menu
        ;;
    *)
        echo "Option inconnue : $1" >&2
        echo "Utilisation : $0 [--audit|--last-private-report|--last-shareable-report|--version|--help]" >&2
        exit 2
        ;;
esac
