#!/usr/bin/env bash

# ==========================================================
# PatSecure v0.3.0
# Audit de sécurité et maintenance pour Deepin Linux
# ==========================================================

set -u

VERSION="0.3.0"

VERT="\e[32m"
ROUGE="\e[31m"
JAUNE="\e[33m"
BLEU="\e[36m"
GRAS="\e[1m"
FIN="\e[0m"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/patsecure"
REPORT_DIR="$STATE_DIR/reports"
REPORT_FILE=""
AUDIT_SUDO=0

clear_screen() {
    if [[ -t 1 && -n "${TERM:-}" ]]; then
        clear
    fi
}

pause_screen() {
    echo
    read -r -p "Appuyez sur Entrée pour continuer..." _
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
    if [[ -n "$REPORT_FILE" ]]; then
        printf '%s\n' "$*" >> "$REPORT_FILE"
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
            echo -e "  ${VERT}[OK]${FIN} $message"
            ;;
        ATTENTION)
            echo -e "  ${JAUNE}[ATTENTION]${FIN} $message"
            ;;
        ERREUR)
            echo -e "  ${ROUGE}[ERREUR]${FIN} $message"
            ;;
        *)
            echo "  [INFO] $message"
            level="INFO"
            ;;
    esac

    report_line "[$level] $message"
}

start_report() {
    local timestamp

    mkdir -p -- "$REPORT_DIR" || {
        echo -e "${ROUGE}Impossible de créer le dossier des rapports.${FIN}"
        return 1
    }

    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
    REPORT_FILE="$REPORT_DIR/audit-$timestamp.txt"

    {
        echo "PatSecure v${VERSION} — Rapport d'audit"
        echo "Date : $(date '+%d/%m/%Y %H:%M:%S %Z')"
        echo "Utilisateur : ${USER:-inconnu}"
        echo "Machine : $(hostname 2>/dev/null || echo inconnue)"
        echo "Système : $(uname -srmo 2>/dev/null || echo inconnu)"
    } > "$REPORT_FILE"
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

    section "[1/6] Mises à jour et paquets"

    if command -v apt >/dev/null 2>&1; then
        count="$(apt list --upgradable 2>/dev/null | sed '1d' | awk 'NF' | wc -l | tr -d ' ')"
        if [[ "$count" == "0" ]]; then
            result OK "Aucune mise à jour connue en attente."
        else
            result ATTENTION "$count mise(s) à jour connue(s) en attente."
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
            report_line "$dpkg_output"
        fi
    fi
}

audit_firewall() {
    local ufw_output

    section "[2/6] Pare-feu"

    if ! command -v ufw >/dev/null 2>&1; then
        result ATTENTION "UFW n'est pas installé."
        return
    fi

    if (( AUDIT_SUDO == 0 )); then
        result ATTENTION "État réel d'UFW non vérifié sans droits administrateur."
        return
    fi

    ufw_output="$(LC_ALL=C sudo ufw status verbose 2>&1)"
    report_line "$ufw_output"

    if grep -q '^Status: active' <<< "$ufw_output"; then
        result OK "Le pare-feu UFW est actif."
    else
        result ATTENTION "Le pare-feu UFW est inactif ou son état est indéterminé."
    fi
}

service_exists() {
    local service="$1"
    systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null | grep -q "^${service}\.service"
}

audit_services() {
    local ssh_service=""

    section "[3/6] Services sensibles"

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

audit_ports() {
    local ports_output
    local tcp_count
    local udp_count

    section "[4/6] Ports réseau à l'écoute"

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

    tcp_count="$(awk '$1 == "tcp" {count++} END {print count+0}' <<< "$ports_output")"
    udp_count="$(awk '$1 == "udp" {count++} END {print count+0}' <<< "$ports_output")"
    result INFO "$tcp_count port(s) TCP et $udp_count port(s) UDP détecté(s)."
    report_line "Détail des ports :"
    report_line "$ports_output"
    echo "  Le détail complet est enregistré dans le rapport."
}

audit_resources() {
    local disk_output
    local memory_output

    section "[5/6] Ressources du système"

    disk_output="$(df -hP / 2>&1 | tail -n 1)"
    memory_output="$(free -h 2>&1 | awk '/^Mem:/ {print}')"

    result INFO "Disque système : $disk_output"
    result INFO "Mémoire : $memory_output"
}

audit_security_updates_note() {
    section "[6/6] Résumé"
    result INFO "L'audit n'a effectué aucune mise à jour, suppression ou modification."
    result INFO "Les éléments [ATTENTION] doivent être vérifiés avant toute réparation."
}

run_audit() {
    title
    echo "Mode AUDIT : lecture seule, sans modification du système."

    if ! start_report; then
        pause_screen
        return
    fi

    prepare_read_only_sudo
    audit_updates
    audit_firewall
    audit_services
    audit_ports
    audit_resources
    audit_security_updates_note

    echo
    echo "====================================================="
    echo -e "${VERT}Audit terminé sans modification.${FIN}"
    echo "Rapport : $REPORT_FILE"
    echo "====================================================="
    report_line ""
    report_line "Audit terminé sans modification."
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

show_last_report() {
    local latest=""

    title

    if [[ -d "$REPORT_DIR" ]]; then
        latest="$(find "$REPORT_DIR" -maxdepth 1 -type f -name 'audit-*.txt' -printf '%T@ %p\n' 2>/dev/null \
            | sort -nr | head -n 1 | cut -d' ' -f2-)"
    fi

    if [[ -z "$latest" || ! -f "$latest" ]]; then
        echo "Aucun rapport d'audit n'est encore disponible."
    else
        echo "Dernier rapport : $latest"
        echo "====================================================="
        sed -n '1,240p' "$latest"
    fi

    pause_screen
}

main_menu() {
    local choice

    while true; do
        title
        echo "1) Audit de sécurité — aucune modification"
        echo "2) Maintenance — actions confirmées une par une"
        echo "3) Afficher le dernier rapport"
        echo "4) Quitter"
        echo
        read -r -p "Votre choix : " choice

        case "$choice" in
            1) run_audit ;;
            2) run_maintenance ;;
            3) show_last_report ;;
            4) echo "Au revoir."; exit 0 ;;
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
    --version)
        echo "PatSecure v${VERSION}"
        ;;
    --help|-h)
        echo "Utilisation : $0 [--audit|--version|--help]"
        ;;
    "")
        main_menu
        ;;
    *)
        echo "Option inconnue : $1" >&2
        echo "Utilisation : $0 [--audit|--version|--help]" >&2
        exit 2
        ;;
esac
