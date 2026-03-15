#!/bin/bash
# ==============================================================================
# Script Name:   rhel_vm_mount_verifier.sh
# Description:   Saves and verifies mounted filesystems (Local, NFS, SMB/CIFS, 
#                SSHFS) and checks /etc/fstab for broken mounts before migration.
# Compatibility: RHEL 4 to RHEL 10
# Usage:
#   Step 1 (Pre-migration) : ./rhel_vm_mount_verifier.sh save
#   Step 2 (Post-migration): ./rhel_vm_mount_verifier.sh verify
# ==============================================================================

STATE_FILE="$(pwd)/vm_mount_state.txt"

# Zaktualizowana lista ignorowanych systemów (dodałem ramfs i fusectl na podstawie logów)
EXCLUDE_FS="(proc|sysfs|tmpfs|devtmpfs|devpts|securityfs|cgroup.*|autofs|rpc_pipefs|mqueue|debugfs|hugetlbfs|pstore|configfs|selinuxfs|binfmt_misc|usbfs|bpf|tracefs|overlay|squashfs|efivarfs|ramfs|fusectl)"

if [ "$1" == "save" ]; then
    echo "=== Zapisywanie stanu zamontowanych zasobów i fstab ==="
    > "$STATE_FILE"
    
    echo "[ACTIVE_MOUNTS]" >> "$STATE_FILE"
    grep -v -E " $EXCLUDE_FS " /proc/mounts | awk '{print $1, $2, $3}' >> "$STATE_FILE"
    
    count_active=$(sed -n '/^\[ACTIVE_MOUNTS\]/,/^\[/p' "$STATE_FILE" | grep -v '^\[' | grep -v '^$' | wc -l)
    echo -e "\e[32m[SUKCES]\e[0m Zapisano $count_active aktywnych punktów montowania."

    echo "[FSTAB_UNMOUNTED]" >> "$STATE_FILE"
    # Przeszukiwanie fstab
    awk '!/^[ \t]*#/ && !/^[ \t]*$/ && $3 !~ /^(swap|proc|sysfs|devpts|tmpfs|devtmpfs|cgroup.*|ramfs|fusectl)$/ {print $1, $2, $3}' /etc/fstab | while read -r f_src f_mp f_fs; do
        if ! awk -v mp="$f_mp" '$2 == mp {found=1; exit} END{if(!found) exit 1}' /proc/mounts; then
            echo "$f_src $f_mp $f_fs" >> "$STATE_FILE"
        fi
    done
    
    # POLICZ WPISY Z PLIKU (Poprawka błędu podpowłoki)
    count_unmounted=$(sed -n '/^\[FSTAB_UNMOUNTED\]/,$p' "$STATE_FILE" | grep -v '^\[' | grep -v '^$' | wc -l)
    
    if [ "$count_unmounted" -gt 0 ]; then
        echo -e "\e[33m[UWAGA]\e[0m Wykryto zasoby w /etc/fstab, które \e[1mNIE SĄ\e[0m obecnie zamontowane:"
        sed -n '/^\[FSTAB_UNMOUNTED\]/,$p' "$STATE_FILE" | grep -v '^\[' | grep -v '^$' | sed 's/\\040/ /g' | awk '{print " -> "$2" ("$3") z "$1}'
    fi
    
    echo "------------------------------------------------"
    echo "Możesz migrować maszynę. Po restarcie użyj parametru 'verify'."

elif [ "$1" == "verify" ]; then
    if [ ! -f "$STATE_FILE" ]; then
        echo -e "\e[31m[BŁĄD]\e[0m Brak pliku $STATE_FILE. Uruchom najpierw z parametrem 'save'."
        exit 1
    fi

    echo "=== Weryfikacja zamontowanych zasobów po migracji ==="
    
    echo -e "\n--- Aktywne zasoby sprzed migracji ---"
    sed -n '/^\[ACTIVE_MOUNTS\]/,/^\[/p' "$STATE_FILE" | grep -v '^\[' | grep -v '^$' | while read -r old_src old_mp old_fs; do
        display_mp=$(echo "$old_mp" | sed 's/\\040/ /g')
        current_entry=$(awk -v mp="$old_mp" '$2 == mp {print $1, $2, $3}' /proc/mounts | head -n 1)
        
        if [ -n "$current_entry" ]; then
            current_src=$(echo "$current_entry" | awk '{print $1}')
            current_fs=$(echo "$current_entry" | awk '{print $3}')
            
            if [ "$current_src" == "$old_src" ]; then
                echo -e "\e[32m[OK]\e[0m Zasób $display_mp ($old_fs) jest zamontowany poprawnie."
            else
                echo -e "\e[33m[UWAGA]\e[0m Punkt $display_mp działa, ale podpięto INNE źródło!"
                echo -e "         \e[90mOczekiwano: $old_src | Jest: $current_src\e[0m"
            fi
        else
            echo -e "\e[31m[BŁĄD]\e[0m Brak zamontowanego zasobu: $display_mp ($old_fs)!"
            echo -e "         \e[90mOczekiwano źródła: $old_src\e[0m"
        fi
    done

    # Weryfikacja "trupów" z fstab
    has_unmounted=$(sed -n '/^\[FSTAB_UNMOUNTED\]/,$p' "$STATE_FILE" | grep -v '^\[' | grep -v '^$' | wc -l)
    if [ "$has_unmounted" -gt 0 ]; then
        echo -e "\n--- Zasoby z fstab (Niezamontowane przed migracją) ---"
        sed -n '/^\[FSTAB_UNMOUNTED\]/,$p' "$STATE_FILE" | grep -v '^\[' | grep -v '^$' | while read -r f_src f_mp f_fs; do
            display_mp=$(echo "$f_mp" | sed 's/\\040/ /g')
            
            if awk -v mp="$f_mp" '$2 == mp {found=1; exit} END{if(!found) exit 1}' /proc/mounts; then
                echo -e "\e[32m[INFO]\e[0m Zasób $display_mp ($f_fs) nie działał przed migracją, ale teraz \e[1mUDAŁO SIĘ GO ZAMONTOWAĆ\e[0m!"
            else
                echo -e "\e[33m[ZIGNOROWANO]\e[0m Zasób $display_mp ($f_fs) \e[1mNADAL NIE JEST\e[0m zamontowany (nie działał już przed migracją)."
            fi
        done
    fi
    echo "==================================================="

else
    echo "Użycie: $0 {save|verify}"
fi
