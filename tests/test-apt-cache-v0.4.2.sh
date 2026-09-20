#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Le garde d'exécution de patsecure.sh permet de sourcer les fonctions sans ouvrir le menu.
# shellcheck source=../patsecure.sh
source "$ROOT_DIR/patsecure.sh"

PASS=0
FAIL=0
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

pass() {
    printf '[PASS] %s\n' "$1"
    ((PASS+=1))
}

fail() {
    printf '[FAIL] %s\n' "$1"
    ((FAIL+=1))
}

expect_equal() {
    local label="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        pass "$label -> $actual"
    else
        fail "$label -> attendu=$expected obtenu=$actual"
    fi
}

sample_output=$'Listing... Done\nlinux-image/stable 1.2 amd64 [upgradable from: 1.1]\nEn train de lister... Fait\nfirefox/stable 3.0 amd64 [upgradable from: 2.9]\n'
count="$(printf '%s' "$sample_output" | patsecure_count_upgradable_lines)"
expect_equal "Comptage indépendant du texte d'en-tête" "2" "$count"

missing_age="$(patsecure_apt_cache_age_hours "$TMP_DIR/inexistant")"
expect_equal "Répertoire APT absent" "-1" "$missing_age"

touch -d '10 hours ago' "$TMP_DIR/depot_InRelease"
touch -d '20 hours ago' "$TMP_DIR/autre_Release"
age="$(patsecure_apt_cache_age_hours "$TMP_DIR")"
if [[ "$age" =~ ^[0-9]+$ ]] && (( age >= 9 && age <= 11 )); then
    pass "Âge du cache récent -> ${age} h"
else
    fail "Âge du cache récent -> obtenu=${age}"
fi

rm -f -- "$TMP_DIR/depot_InRelease" "$TMP_DIR/autre_Release"
touch -d '200 hours ago' "$TMP_DIR/depot_InRelease"
age="$(patsecure_apt_cache_age_hours "$TMP_DIR")"
if [[ "$age" =~ ^[0-9]+$ ]] && (( age > 168 )); then
    pass "Cache ancien détecté -> ${age} h"
else
    fail "Cache ancien non détecté -> obtenu=${age}"
fi

echo
printf 'Résultat : %d PASS, %d FAIL\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
