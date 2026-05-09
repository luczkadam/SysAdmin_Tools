#!/bin/bash
#
# Skrypt porównujący zawartość /etc/fstab z aktualnie zamontowanymi
# systemami plików. Kompatybilny z RHEL 4 -> RHEL 10.
#

FSTAB="/etc/fstab"
MOUNTS="/proc/mounts"
SWAPS="/proc/swaps"

echo "======================================================================"
echo " PORÓWNANIE /etc/fstab Z AKTUALNIE ZAMONTOWANYMI SYSTEMAMI PLIKÓW"
echo "======================================================================"
printf "%-32s %-12s %-25s\n" "PUNKT MONTOWANIA" "TYP (fstab)" "STATUS"
echo "----------------------------------------------------------------------"

# 1. Sprawdzanie wpisów z /etc/fstab względem rzeczywistości
while read -r dev mnt fstype opts dump pass; do
    # Ignoruj puste linie i zakomentowane wpisy
    if [[ -z "$dev" || "$dev" == \#* ]]; then
        continue
    fi

    # Obsługa wpisów noauto (nie oczekujemy, że są zamontowane z automatu)
    if [[ "$opts" == *"noauto"* ]]; then
        printf "%-32s %-12s %-25s\n" "$mnt" "$fstype" "[ POMINIĘTO (noauto) ]"
        continue
    fi

    # Obsługa partycji wymiany (swap nie mapuje się do normalnych punktów montowania)
    if [[ "$fstype" == "swap" ]]; then
        # Sprawdzamy czy w ogóle widnieje jakikolwiek aktywny swap w systemie
        swap_count=$(wc -l < "$SWAPS")
        if [ "$swap_count" -gt 1 ]; then
            printf "%-32s %-12s %-25s\n" "SWAP" "swap" "[ OK - AKTYWNY ]"
        else
            printf "%-32s %-12s %-25s\n" "SWAP" "swap" "[ BŁĄD - BRAK AKTYWNEGO SWAP ]"
        fi
        continue
    fi

    # Wyszukanie punktu montowania w /proc/mounts (kolumna 2)
    # Zmienna awk "m" radzi sobie z ewentualnymi spacjami w postaci \040
    mount_match=$(awk -v m="$mnt" '$2 == m {print $3}' "$MOUNTS" 2>/dev/null | head -n 1)

    if [[ -n "$mount_match" ]]; then
        # Jeśli zamontowano, sprawdzamy zgodność systemu plików (z wyjątkiem trybu auto i mount bind)
        if [[ "$fstype" == "auto" || "$fstype" == "$mount_match" || "$opts" == *"bind"* ]]; then
            printf "%-32s %-12s %-25s\n" "$mnt" "$fstype" "[ OK - ZAMONTOWANY ]"
        else
            printf "%-32s %-12s %-25s\n" "$mnt" "$fstype" "[ UWAGA - INNY TYP ($mount_match) ]"
        fi
    else
        printf "%-32s %-12s %-25s\n" "$mnt" "$fstype" "[ BŁĄD - NIEZAMONTOWANY ]"
    fi

done < "$FSTAB"

echo "----------------------------------------------------------------------"
echo " FIZYCZNE DYSKI ZAMONTOWANE W SYSTEMIE, ALE BRAKUJĄCE W /etc/fstab"
echo "----------------------------------------------------------------------"

# 2. Weryfikacja w drugą stronę: co jest zamontowane, a nie ma tego w fstab?
# Ograniczamy wyrażenie regularne do najczęstszych fizycznych i sieciowych systemów 
# plików, aby uniknąć zalania ekranu przez setki wpisów wirtualnych 
# (sysfs, proc, devtmpfs, cgroup - problematyczne zwłaszcza na nowszych RHEL od v7).

awk '$3 ~ /^(ext[2-4]|xfs|btrfs|nfs4?|cifs|vfat|ntfs.*|jfs|reiserfs)$/ {print $2, $3}' "$MOUNTS" | while read -r cur_mnt cur_fstype; do
    # Sprawdzamy czy dany punkt montowania jest wpisany do fstab jako aktywny
    in_fstab=$(awk -v m="$cur_mnt" '$1 !~ /^#/ && $2 == m {print "yes"}' "$FSTAB")
    
    if [[ -z "$in_fstab" ]]; then
        printf "%-32s %-12s %-25s\n" "$cur_mnt" "$cur_fstype" "[ INFO - POZA FSTAB ]"
    fi
done

echo "======================================================================"
