#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/network-classifier-v0.4.1.sh
source "$ROOT_DIR/scripts/network-classifier-v0.4.1.sh"

PASS=0
FAIL=0

expect_level() {
    local expected="$1"
    shift
    local output level

    output="$(patsecure_classify_socket "$@")"
    level="${output%%|*}"

    if [[ "$level" == "$expected" ]]; then
        printf '[PASS] %-10s %s\n' "$expected" "$output"
        ((PASS+=1))
    else
        printf '[FAIL] attendu=%s obtenu=%s -> %s\n' "$expected" "$level" "$output"
        ((FAIL+=1))
    fi
}

read -r EPHEMERAL_LOW EPHEMERAL_HIGH < <(patsecure_ephemeral_range)
EPHEMERAL_TEST=$(( (EPHEMERAL_LOW + EPHEMERAL_HIGH) / 2 ))

# Boucle locale : Ollama, serveur local uniquement.
expect_level OK tcp LISTEN 127.0.0.1:11434 ollama
expect_level OK tcp LISTEN '[::1]:631' cupsd

# Services UDP locaux connus.
expect_level INFO udp UNCONN 0.0.0.0:5353 avahi-daemon
expect_level INFO udp UNCONN '[fe80::1234]:546' NetworkManager

# Socket UDP éphémère associé à Firefox : information seulement.
expect_level INFO udp UNCONN "0.0.0.0:${EPHEMERAL_TEST}" firefox-bin

# Même règle pour un programme identifié non présent dans une liste spéciale :
# le caractère éphémère + l'identité du processus suffisent pour ne pas crier au serveur.
expect_level INFO udp UNCONN "0.0.0.0:${EPHEMERAL_TEST}" programme-client

# Serveurs TCP hors boucle locale : vérification nécessaire.
expect_level ATTENTION tcp LISTEN 0.0.0.0:22 sshd
expect_level ATTENTION tcp LISTEN '[::]:8080' inconnu
expect_level ATTENTION tcp LISTEN '192.0.2.10:9000' programme-serveur

# UDP permanent / non classé : vérification nécessaire.
expect_level ATTENTION udp UNCONN '*:9999' inconnu
expect_level ATTENTION udp UNCONN '192.0.2.10:9999' daemon-test

echo
printf 'Résultat : %d PASS, %d FAIL\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
