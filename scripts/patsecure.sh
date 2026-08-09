#!/bin/bash

# ==========================================================
# PatSecure v0.2.1
# Audit de sécurité Deepin Linux
# ==========================================================

VERT="\e[32m"
ROUGE="\e[31m"
JAUNE="\e[33m"
BLEU="\e[36m"
FIN="\e[0m"

clear

echo -e "${BLEU}"
echo "====================================================="
echo "                 PatSecure v0.2.1"
echo "          Audit de sécurité Deepin Linux"
echo "====================================================="
echo -e "${FIN}"

# ---------- Fonction ----------
check_service() {

    SERVICE="$1"

    if ! systemctl list-unit-files | grep -q "^${SERVICE}\.service"; then
        echo -e "  ${SERVICE} : ${JAUNE}Non installé${FIN}"
        return
    fi

    if systemctl is-active --quiet "$SERVICE"; then
        echo -e "  ${SERVICE} : ${VERT}Actif${FIN}"
    else
        echo -e "  ${SERVICE} : ${ROUGE}Inactif${FIN}"
    fi
}

echo
echo "[1/7] Mise à jour des dépôts"
sudo apt update

echo
echo "[2/7] Installation des mises à jour"
sudo apt full-upgrade -y

echo
echo "[3/7] Nettoyage"
sudo apt autoremove -y
sudo apt autoclean

echo
echo "[4/7] Vérification des services"

check_service ssh
check_service ufw
check_service fail2ban

echo
echo "[5/7] Utilisation du disque"

df -h /

echo
echo "[6/7] Mémoire"

free -h

echo
echo "[7/7] Ports réseau à l'écoute"

ss -tuln | grep LISTEN

echo
echo "====================================================="
echo -e "${VERT}Audit terminé.${FIN}"
echo "====================================================="

echo
read -p "Appuyez sur Entrée pour quitter..."
