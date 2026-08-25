#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PATSECURE_SCRIPT=""

for candidate in \
    "$SCRIPT_DIR/../scripts/patsecure.sh" \
    "$SCRIPT_DIR/patsecure.sh" \
    "$HOME/PatSecure/scripts/patsecure.sh"
do
    if [[ -f "$candidate" ]]; then
        PATSECURE_SCRIPT="$candidate"
        break
    fi
done

if [[ -z "$PATSECURE_SCRIPT" ]]; then
    echo "Erreur : le script patsecure.sh est introuvable." >&2
    echo "Installez-le dans : $HOME/PatSecure/scripts/patsecure.sh" >&2
    read -r -p "Appuyez sur Entrée pour quitter..." _
    exit 1
fi

if command -v deepin-terminal >/dev/null 2>&1; then
    exec deepin-terminal --keep-open --run-script "bash \"$PATSECURE_SCRIPT\""
elif command -v x-terminal-emulator >/dev/null 2>&1; then
    exec x-terminal-emulator -e bash -c 'bash "$1"; read -r -p "Appuyez sur Entrée pour quitter..." _' _ "$PATSECURE_SCRIPT"
else
    exec bash "$PATSECURE_SCRIPT"
fi
