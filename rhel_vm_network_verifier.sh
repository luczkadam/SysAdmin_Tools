#!/bin/bash
# ==============================================================================
# Script Name:   rhel_vm_network_verifier.sh
# Description:   Saves and verifies the network configuration (IP, Netmask, 
#                Routing, and MAC addresses) of a RHEL Virtual Machine 
#                before and after hypervisor migration.
# Compatibility: RHEL 4 to RHEL 10
#
# Usage: 
#   Step 1 (Pre-migration) : ./rhel_vm_network_verifier.sh save
#   Step 2 (Post-migration): ./rhel_vm_network_verifier.sh verify
#
# Note: The state file is saved in the current working directory.
# ==============================================================================


# Zapis do aktualnego katalogu roboczego (tam, gdzie uruchamiasz skrypt)
STATE_FILE="$(pwd)/vm_network_state.txt"

if [ "$1" == "save" ]; then
    echo "=== Zapisywanie stanu sieci przed migracją ==="
    > "$STATE_FILE"
    
    # Zapis adresacji IP
    echo "[IP]" >> "$STATE_FILE"
    ip -o -4 addr show | awk '{print $2, $4}' >> "$STATE_FILE"
    
    # Zapis routingu
    echo "[ROUTE]" >> "$STATE_FILE"
    ip -4 route show >> "$STATE_FILE"
    
    # Zapis adresów MAC (czytane z kernela)
    echo "[MAC]" >> "$STATE_FILE"
    for iface in /sys/class/net/*; do
        ifname=$(basename "$iface")
        if [ "$ifname" != "lo" ]; then
            mac=$(cat "$iface/address" 2>/dev/null)
            if [ -n "$mac" ]; then echo "$ifname $mac" >> "$STATE_FILE"; fi
        fi
    done
    
    echo -e "\e[32m[SUKCES]\e[0m Stan sieci zapisany w pliku: $STATE_FILE"
    echo "Możesz teraz migrować maszynę. Po restarcie uruchom skrypt z parametrem 'verify'."

elif [ "$1" == "verify" ]; then
    if [ ! -f "$STATE_FILE" ]; then
        echo -e "\e[31m[BŁĄD]\e[0m Brak pliku $STATE_FILE. Uruchom najpierw skrypt z parametrem 'save'."
        exit 1
    fi

    echo "=== Weryfikacja stanu sieci po migracji ==="
    
    echo -e "\n--- Adresacja IP i Maski ---"
    sed -n '/^\[IP\]/,/^\[/p' "$STATE_FILE" | grep -v '^\[' | while read old_iface old_ip; do
        if ip -o -4 addr show | grep -q "$old_ip"; then
            current_iface=$(ip -o -4 addr show | grep "$old_ip" | awk '{print $2}')
            if [ "$old_iface" == "$current_iface" ]; then
                echo -e "\e[32m[OK]\e[0m Adres $old_ip poprawnie skonfigurowany na $old_iface."
            else
                echo -e "\e[32m[OK]\e[0m Adres $old_ip odnaleziony, ale na \e[1mINNYM interfejsie\e[0m: $current_iface (był: $old_iface)."
            fi
        else
            echo -e "\e[31m[BŁĄD]\e[0m Brak adresu $old_ip w systemie!"
        fi
    done

    echo -e "\n--- Routing ---"
    sed -n '/^\[ROUTE\]/,/^\[/p' "$STATE_FILE" | grep -v '^\[' | while read old_route; do
        route_core=$(echo "$old_route" | sed 's/ dev [^ ]*//g' | sed 's/ linkdown//g')
        current_routes=$(ip -4 route show | sed 's/ dev [^ ]*//g')
        
        if echo "$current_routes" | grep -q -F "$route_core"; then
            echo -e "\e[32m[OK]\e[0m Trasa znaleziona: $route_core"
        else
            echo -e "\e[31m[BŁĄD]\e[0m Brak trasy: $route_core"
        fi
    done

    echo -e "\n--- Adresy MAC (Informacyjnie) ---"
    sed -n '/^\[MAC\]/,/^\[/p' "$STATE_FILE" | grep -v '^\[' | grep -v '^$' | while read old_iface old_mac; do
        current_mac=""
        if [ -f "/sys/class/net/$old_iface/address" ]; then
            current_mac=$(cat "/sys/class/net/$old_iface/address")
        fi
        
        if [ "$old_mac" == "$current_mac" ]; then
            echo -e "\e[32m[OK]\e[0m MAC dla $old_iface zgadza się ($old_mac)."
        else
            echo -e "\e[33m[INFO]\e[0m MAC dla $old_iface uległ zmianie (lub zmieniła się nazwa interfejsu)."
            echo -e "       \e[90mStary: $old_mac | Aktualny: ${current_mac:-Brak interfejsu pod tą nazwą}\e[0m"
        fi
    done
    echo "==========================================="

else
    echo "Użycie: $0 {save|verify}"
fi
