#!/usr/bin/env bash

# PatSecure v0.4.1 - validation du classificateur sur les sockets réels
# Lecture seule. La sortie affichée ne contient aucune adresse IP.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CLASSIFIER="$ROOT_DIR/scripts/network-classifier-v0.4.1.sh"

if [[ ! -r "$CLASSIFIER" ]]; then
    echo "[ERREUR] Classificateur introuvable : $CLASSIFIER" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$CLASSIFIER"

if ! command -v ss >/dev/null 2>&1; then
    echo "[ERREUR] La commande ss est introuvable." >&2
    exit 1
fi

ports_output=""
if sudo -n true >/dev/null 2>&1; then
    ports_output="$(sudo ss -tulpnH 2>/dev/null || true)"
else
    ports_output="$(ss -tulpnH 2>/dev/null || ss -tulnH 2>/dev/null || true)"
fi

if [[ -z "$ports_output" ]]; then
    echo "[OK] Aucun socket TCP/UDP à analyser."
    exit 0
fi

count_ok=0
count_info=0
count_attention=0
count_error=0

echo "PatSecure v0.4.1 — validation réseau réelle"
echo "Lecture seule — aucune adresse IP n'est affichée"
echo

while IFS= read -r line; do
    [[ -n "$line" ]] || continue

    protocol="$(awk '{print $1}' <<< "$line")"
    state="$(awk '{print $2}' <<< "$line")"
    endpoint="$(awk '{print $5}' <<< "$line")"
    process="$(patsecure_process_from_ss_line "$line")"

    # Sans droits suffisants, ss peut ne pas fournir le nom du processus.
    [[ -n "$process" ]] || process="inconnu"

    classification="$(patsecure_classify_socket "$protocol" "$state" "$endpoint" "$process")"
    IFS='|' read -r level scope port process_name reason <<< "$classification"

    case "$level" in
        OK) ((count_ok+=1)) ;;
        INFO) ((count_info+=1)) ;;
        ATTENTION) ((count_attention+=1)) ;;
        *) ((count_error+=1)); level="ERREUR" ;;
    esac

    printf '[%-9s] %-3s port %-5s | %-16s | %-14s | %s\n' \
        "$level" "${protocol^^}" "$port" "$scope" "$process_name" "$reason"
done <<< "$ports_output"

echo
echo "Résumé : OK=$count_ok INFO=$count_info ATTENTION=$count_attention ERREUR=$count_error"
echo "Rappel : une écoute hors boucle locale ne prouve pas une exposition Internet."
