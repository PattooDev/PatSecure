#!/usr/bin/env bash

# PatSecure v0.4.1 - moteur de classification des sockets réseau
# Fichier de travail : destiné à être intégré dans patsecure.sh après validation.
#
# Sortie de patsecure_classify_socket :
#   NIVEAU|PORTEE|PORT|PROCESSUS|MOTIF
#
# Important : aucune adresse IP n'est renvoyée dans le résultat afin de pouvoir
# réutiliser ce résultat dans le rapport partageable sans fuite d'adresse locale.

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
        # Repli prudent si le noyau ne fournit pas la plage.
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

    if [[ "$process" == "avahi-daemon" && "$port" == "5353" ]]; then
        return 0
    fi

    if [[ "$process" == "NetworkManager" && "$port" == "546" ]]; then
        return 0
    fi

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

    # Boucle locale : non accessible directement depuis le LAN ou Internet.
    if [[ "$scope" == "loopback" ]]; then
        printf 'OK|%s|%s|%s|%s\n' \
            "$scope" "$port" "$process" \
            "écoute limitée à la boucle locale"
        return 0
    fi

    # UDP éphémère + processus identifié : typiquement socket client (QUIC, DNS,
    # synchronisation, etc.). Cela ne doit pas être assimilé à un serveur permanent.
    if [[ "$protocol" == "udp" && "$process" != "inconnu" ]] \
        && patsecure_is_ephemeral_port "$port"; then
        printf 'INFO|%s|%s|%s|%s\n' \
            "$scope" "$port" "$process" \
            "socket UDP éphémère associé à un processus identifié"
        return 0
    fi

    # Quelques usages UDP locaux connus et non suspects par nature.
    if [[ "$protocol" == "udp" ]] \
        && patsecure_process_is_known_local_udp_service "$process" "$port"; then
        printf 'INFO|%s|%s|%s|%s\n' \
            "$scope" "$port" "$process" \
            "service UDP local connu"
        return 0
    fi

    # Clients système / navigateurs identifiés : information, pas alerte serveur.
    if [[ "$protocol" == "udp" ]] \
        && patsecure_process_is_known_udp_client "$process"; then
        printf 'INFO|%s|%s|%s|%s\n' \
            "$scope" "$port" "$process" \
            "socket UDP d'un programme client identifié"
        return 0
    fi

    # Toute écoute TCP hors loopback est un service joignable depuis au moins une
    # interface réseau. Elle mérite vérification, même si un pare-feu peut la filtrer.
    if [[ "$protocol" == "tcp" && "$state" == "LISTEN" ]]; then
        printf 'ATTENTION|%s|%s|%s|%s\n' \
            "$scope" "$port" "$process" \
            "service TCP à l'écoute hors boucle locale ; cela ne prouve pas une exposition Internet"
        return 0
    fi

    # UDP non éphémère non reconnu : peut être un service permanent.
    if [[ "$protocol" == "udp" ]]; then
        if [[ "$process" == "inconnu" ]]; then
            printf 'ATTENTION|%s|%s|%s|%s\n' \
                "$scope" "$port" "$process" \
                "socket UDP non classé sans processus identifié"
        else
            printf 'ATTENTION|%s|%s|%s|%s\n' \
                "$scope" "$port" "$process" \
                "socket UDP non éphémère non classé ; vérifier s'il s'agit d'un service permanent"
        fi
        return 0
    fi

    printf 'INFO|%s|%s|%s|%s\n' \
        "$scope" "$port" "$process" \
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
