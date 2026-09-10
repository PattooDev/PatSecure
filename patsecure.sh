#!/usr/bin/env bash

# ==========================================================
# PatSecure v0.4.1
# Audit de sécurité et maintenance pour Deepin Linux
# ==========================================================

set -u
umask 077

VERSION="0.4.1"

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

UFW_ACTIVE=0
UFW_IPV6=0
UFW_DEFAULT_INCOMING="unknown"

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
        echo
        echo "Ce rapport privé peut contenir des détails locaux techniques."
        echo "Ne pas le publier sans vérification."
    } > "$PRIVATE_REPORT_FILE"

    {
        echo "PatSecure v${VERSION} — Rapport partageable"
        echo "Date : $today"
        echo
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
    local ufw_output=""
    local nft_output=""
    local ipv6_setting=""

    section "[2/7] Pare-feu"

    UFW_ACTIVE=0
    UFW_IPV6=0
    UFW_DEFAULT_INCOMING="unknown"

    if [[ -r /etc/default/ufw ]]; then
        ipv6_setting="$(grep -E '^IPV6=' /etc/default/ufw 2>/dev/null | tail -n 1 | cut -d= -f2 | tr -d '\"[:space:]')"
        if [[ "${ipv6_setting,,}" == "yes" ]]; then
            UFW_IPV6=1
        fi
    fi

    if command -v ufw >/dev/null 2>&1; then
        if (( AUDIT_SUDO == 0 )); then
            result ATTENTION "UFW est installé, mais son état réel n'est pas vérifié sans droits administrateur."
            return
        fi

        ufw_output="$(LC_ALL=C sudo ufw status verbose 2>&1)"
        private_line "Détail UFW :"
        private_line "$ufw_output"

        if grep -q '^Status: active' <<< "$ufw_output"; then
            UFW_ACTIVE=1
            result OK "Le pare-feu UFW est actif."
        else
            result ATTENTION "Le pare-feu UFW est inactif ou son état est indéterminé."
        fi

        if grep -q '^Default: deny (incoming)' <<< "$ufw_output"; then
            UFW_DEFAULT_INCOMING="deny"
            result OK "La politique UFW refuse les connexions entrantes par défaut."
        elif grep -q '^Default: reject (incoming)' <<< "$ufw_output"; then
            UFW_DEFAULT_INCOMING="reject"
            result OK "La politique UFW rejette les connexions entrantes par défaut."
        elif grep -q '^Default: allow (incoming)' <<< "$ufw_output"; then
            UFW_DEFAULT_INCOMING="allow"
            result ATTENTION "La politique UFW autorise les connexions entrantes par défaut."
        else
            result INFO "La politique entrante par défaut d'UFW n'a pas été déterminée."
        fi

        if (( UFW_IPV6 == 1 )); then
            result OK "UFW est configuré pour prendre en charge IPv6."
        else
            result ATTENTION "UFW ne semble pas configuré pour prendre en charge IPv6."
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

# ----------------------------------------------------------
# Classification réseau v0.4.1
# ----------------------------------------------------------

patsecure_endpoint_port() {
    local endpoint="${1:-}"
    printf '%s\n' "${endpoint##*:}"
}

patsecure_socket_scope() {
    local endpoint="${1:-}"

    case "$endpoint" in
        127.*:*|\[::1\]:*) printf '%s\n' "loopback" ;;
        0.0.0.0:*|\[::\]:*|\*:*) printf '%s\n' "all-interfaces" ;;
        *) printf '%s\n' "interface" ;;
    esac
}

patsecure_ephemeral_range() {
    local low high

    if read -r low high < /proc/sys/net/ipv4/ip_local_port_range 2>/dev/null \
        && [[ "$low" =~ ^[0-9]+$ && "$high" =~ ^[0-9]+$ ]]; then
        printf '%s %s\n' "$low" "$high"
    else
        printf '%s %s\n' "32768" "60999"
    fi
}

patsecure_is_ephemeral_port() {
    local port="${1:-}"
    local low high

    [[ "$port" =~ ^[0-9]+$ ]] || return 1
    read -r low high < <(patsecure_ephemeral_range)
    (( port >= low && port <= high ))
}

patsecure_process_is_known_udp_client() {
    local process="${1:-}"

    case "$process" in
        firefox|firefox-bin|chrome|chrome-bin|chromium|chromium-browse|chromium-browser|brave|brave-browser|systemd-timesyncd|NetworkManager)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

patsecure_process_is_known_local_udp_service() {
    local process="${1:-}"
    local port="${2:-}"

    [[ "$process" == "avahi-daemon" && "$port" == "5353" ]] && return 0
    [[ "$process" == "NetworkManager" && "$port" == "546" ]] && return 0
    return 1
}

patsecure_classify_socket() {
    local protocol="${1:-}"
    local state="${2:-}"
    local local_endpoint="${3:-}"
    local process="${4:-inconnu}"
    local port scope

    protocol="${protocol,,}"
    port="$(patsecure_endpoint_port "$local_endpoint")"
    scope="$(patsecure_socket_scope "$local_endpoint")"
    [[ -n "$process" ]] || process="inconnu"

    if [[ "$scope" == "loopback" ]]; then
        printf 'OK|%s|%s|%s|%s\n' "$scope" "$port" "$process" \
            "écoute limitée à la boucle locale"
        return 0
    fi

    if [[ "$protocol" == "udp" && "$process" != "inconnu" ]] \
        && patsecure_is_ephemeral_port "$port"; then
        printf 'INFO|%s|%s|%s|%s\n' "$scope" "$port" "$process" \
            "socket UDP éphémère associé à un processus identifié"
        return 0
    fi

    if [[ "$protocol" == "udp" ]] \
        && patsecure_process_is_known_local_udp_service "$process" "$port"; then
        printf 'INFO|%s|%s|%s|%s\n' "$scope" "$port" "$process" \
            "service UDP local connu"
        return 0
    fi

    if [[ "$protocol" == "udp" ]] \
        && patsecure_process_is_known_udp_client "$process"; then
        printf 'INFO|%s|%s|%s|%s\n' "$scope" "$port" "$process" \
            "socket UDP d'un programme client identifié"
        return 0
    fi

    if [[ "$protocol" == "tcp" && "$state" == "LISTEN" ]]; then
        printf 'ATTENTION|%s|%s|%s|%s\n' "$scope" "$port" "$process" \
            "service TCP à l'écoute hors boucle locale ; cela ne prouve pas une exposition Internet"
        return 0
    fi

    if [[ "$protocol" == "udp" ]]; then
        if [[ "$process" == "inconnu" ]]; then
            printf 'ATTENTION|%s|%s|%s|%s\n' "$scope" "$port" "$process" \
                "socket UDP non classé sans processus identifié"
        else
            printf 'ATTENTION|%s|%s|%s|%s\n' "$scope" "$port" "$process" \
                "socket UDP non éphémère non classé ; vérifier s'il s'agit d'un service permanent"
        fi
        return 0
    fi

    printf 'INFO|%s|%s|%s|%s\n' "$scope" "$port" "$process" \
        "socket réseau non classé"
}

patsecure_process_from_ss_line() {
    local line="${1:-}"
    local process

    process="$(sed -n 's/.*users:(("\([^"]*\)".*/\1/p' <<< "$line")"
    if [[ -n "$process" ]]; then
        printf '%s\n' "$process"
    else
        printf '%s\n' "inconnu"
    fi
}

patsecure_scope_label() {
    case "${1:-}" in
        loopback) printf '%s\n' "boucle locale" ;;
        all-interfaces) printf '%s\n' "toutes interfaces" ;;
        interface) printf '%s\n' "interface réseau" ;;
        *) printf '%s\n' "portée inconnue" ;;
    esac
}

audit_listening_ports() {
    local ports_output
    local tcp_count udp_count raw_count unique_count
    local line protocol state local_endpoint process classification
    local level scope port reason scope_label key
    declare -A seen=()

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

    private_line "Détail brut des sockets réseau (rapport privé uniquement) :"
    private_line "$ports_output"

    tcp_count="$(awk '$1 == "tcp" {count++} END {print count+0}' <<< "$ports_output")"
    udp_count="$(awk '$1 == "udp" {count++} END {print count+0}' <<< "$ports_output")"
    raw_count=$(( tcp_count + udp_count ))

    result INFO "$tcp_count socket(s) TCP et $udp_count socket(s) UDP détecté(s)."

    unique_count=0
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue

        protocol="$(awk '{print $1}' <<< "$line")"
        state="$(awk '{print $2}' <<< "$line")"
        local_endpoint="$(awk '{print $5}' <<< "$line")"
        process="$(patsecure_process_from_ss_line "$line")"

        classification="$(patsecure_classify_socket "$protocol" "$state" "$local_endpoint" "$process")"
        IFS='|' read -r level scope port process reason <<< "$classification"

        key="${protocol,,}|$level|$scope|$port|$process|$reason"
        if [[ -n "${seen[$key]+x}" ]]; then
            continue
        fi
        seen[$key]=1
        ((unique_count+=1))

        scope_label="$(patsecure_scope_label "$scope")"
        result "$level" "${protocol^^} $port — $process — $scope_label — $reason."
    done <<< "$ports_output"

    if (( raw_count > unique_count )); then
        result INFO "$((raw_count - unique_count)) socket(s) IPv4/IPv6 redondant(s) regroupé(s) dans l'affichage."
    fi

    result INFO "La mention « toutes interfaces » signifie une écoute sur la machine ; elle ne démontre pas une accessibilité depuis Internet."
    echo "  Les adresses exactes et la sortie brute de ss restent uniquement dans le rapport privé."
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
            if (( UFW_ACTIVE == 1 && UFW_IPV6 == 1 )) && [[ "$UFW_DEFAULT_INCOMING" == "deny" || "$UFW_DEFAULT_INCOMING" == "reject" ]]; then
                result OK "IPv6 global est présent et couvert par UFW avec une politique entrante restrictive."
            elif (( UFW_ACTIVE == 1 && UFW_IPV6 == 1 )); then
                result ATTENTION "IPv6 global est présent et géré par UFW, mais la politique entrante par défaut n'est pas restrictive ou n'a pas été confirmée."
            elif (( UFW_ACTIVE == 1 )); then
                result ATTENTION "IPv6 global est présent ; UFW est actif mais sa prise en charge d'IPv6 n'a pas été confirmée."
            else
                result ATTENTION "IPv6 global est présent ; son filtrage n'a pas été confirmé par PatSecure."
            fi
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

        if (( upnp_status == 124 )); then
            result INFO "Aucune réponse UPnP reçue dans le délai de 7 secondes ; aucune passerelle UPnP/IGD n'a été confirmée."
        elif grep -qiE 'No IGD|No valid.*IGD|No UPnP.*found|No.*UPnP.*Device' <<< "$upnp_output"; then
            result OK "Aucune passerelle UPnP/IGD n'a été trouvée sur le réseau local."
        elif grep -qiE 'Found valid IGD|InternetGatewayDevice|GetExternalIPAddress|ExternalIPAddress' <<< "$upnp_output"; then
            result ATTENTION "Une passerelle UPnP/IGD répond sur le réseau local. Son adresse externe n'est ni affichée ni enregistrée par PatSecure."
        elif (( upnp_status == 0 )); then
            result INFO "Une réponse UPnP a été reçue, mais son format n'a pas permis de confirmer une passerelle IGD."
        else
            result INFO "Le contrôle UPnP s'est terminé sans résultat exploitable ; aucune adresse externe n'a été affichée ou enregistrée."
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
    UFW_ACTIVE=0
    UFW_IPV6=0
    UFW_DEFAULT_INCOMING="unknown"
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
