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

# Simuler APT dans ce processus de test : aucune commande APT réelle, aucun rapport écrit.
# Vérifier le compteur ET le premier diagnostic émis par audit_updates.
apt() {
    case "$apt_case" in
        zero) printf 'Listing... Done\n' ;;
        two)
            printf 'Listing... Done\nalpha/stable 2 amd64\nbeta/stable 3 amd64\n'
            ;;
        failure) return 100 ;;
        partial)
            printf 'Listing... Done\nalpha/stable 2 amd64\n'
            return 100
            ;;
    esac
}
dpkg() { return 0; }
section() { :; }
result() { printf '[%s] %s\n' "$1" "$2"; }
patsecure_apt_cache_age_hours() { printf '10\n'; }

for apt_case in zero two failure partial; do
    case "$apt_case" in
        zero)
            expected_count=0
            expected_result="[OK] Aucune mise à jour connue en attente dans le cache APT actuel."
            ;;
        two)
            expected_count=2
            expected_result="[ATTENTION] 2 mise(s) à jour connue(s) en attente dans le cache APT actuel."
            ;;
        failure|partial)
            expected_count=-1
            expected_result="[ATTENTION] Le nombre de mises à jour APT n'a pas pu être déterminé."
            ;;
    esac
    expect_equal "Comptage APT ($apt_case)" "$expected_count" "$(patsecure_apt_upgradable_count)"
    diagnostic="$(audit_updates)"
    expect_equal "Diagnostic APT ($apt_case)" "$expected_result" "${diagnostic%%$'\n'*}"
done

# Conserver également le comportement quand APT est introuvable.
command() {
    if [[ "${1:-}" == '-v' && "${2:-}" == 'apt' ]]; then
        return 1
    fi
    builtin command "$@"
}
expect_equal "Commande APT absente" "-1" "$(patsecure_apt_upgradable_count)"
diagnostic="$(audit_updates)"
expect_equal "Diagnostic sans APT" "[ERREUR] La commande apt est introuvable." "${diagnostic%%$'\n'*}"


echo
printf 'Résultat : %d PASS, %d FAIL\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
