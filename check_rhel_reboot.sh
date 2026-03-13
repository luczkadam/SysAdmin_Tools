#!/bin/bash
# Skrypt do wstępnej analizy przyczyn nagłego restartu (RHEL 5-9)

# Sprawdzenie uprawnień
if [ "$EUID" -ne 0 ]; then
  echo "BŁĄD: Uruchom ten skrypt jako root."
  exit 1
fi

REPORT_FILE="/root/reboot_analysis_$(date +%Y-%m-%d_%H-%M).txt"

echo "=== RAPORT ANALIZY PO RESTARCIE ===" > "$REPORT_FILE"
echo "Hostname: $(hostname)" >> "$REPORT_FILE"
echo "Data wygenerowania: $(date)" >> "$REPORT_FILE"
echo "Wersja OS: $(cat /etc/redhat-release 2>/dev/null || echo 'Nieznana')" >> "$REPORT_FILE"
echo "===================================" >> "$REPORT_FILE"

# 1. Historia restartów
echo -e "\n--- 1. CZAS OSTATNICH RESTARTÓW (last) ---" >> "$REPORT_FILE"
last -x reboot shutdown | head -n 5 >> "$REPORT_FILE"

# 2. Szukanie zrzutów pamięci (Kdump / Kernel Panic)
echo -e "\n--- 2. ZRZUTY PAMIĘCI (KDUMP) ---" >> "$REPORT_FILE"
if [ -d "/var/crash" ] && [ "$(ls -A /var/crash 2>/dev/null)" ]; then
    echo "UWAGA: Znaleziono pliki w /var/crash! Możliwy Kernel Panic." >> "$REPORT_FILE"
    ls -lh /var/crash >> "$REPORT_FILE"
else
    echo "Katalog /var/crash jest pusty. Prawdopodobnie kdump nie zadziałał lub to nie był Kernel Panic." >> "$REPORT_FILE"
fi

# 3. Analiza logów tuż przed restartem (RHEL 7+ vs RHEL 5/6)
echo -e "\n--- 3. LOGI SYSTEMOWE Z POPRZEDNIEJ SESJI ---" >> "$REPORT_FILE"
if command -v journalctl >/dev/null 2>&1; then
    # RHEL 7, 8, 9 używają systemd
    echo "Wykryto systemd (RHEL 7+)." >> "$REPORT_FILE"
    echo "Ostatnie 50 linii logów przed poprzednim restartem:" >> "$REPORT_FILE"
    # -b -1 oznacza poprzedni boot, -e to koniec logu
    journalctl -b -1 -n 50 --no-pager >> "$REPORT_FILE" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo "Brak logów z poprzedniego uruchomienia! Upewnij się, że journald ma włączone zapisywanie na dysk (Storage=persistent)." >> "$REPORT_FILE"
    fi
else
    # RHEL 5 i 6 używają sysklogd / rsyslog i plików tekstowych
    echo "Brak systemd (Prawdopodobnie RHEL 5 lub 6)." >> "$REPORT_FILE"
    echo "Szukanie słów kluczowych (panic, error, kill, oom) w /var/log/messages:" >> "$REPORT_FILE"
    egrep -i "kernel panic|out of memory|oom-killer|machine check exception|hardware error" /var/log/messages* | tail -n 30 >> "$REPORT_FILE"
fi

# 4. Sprawdzenie błędów sprzętowych
echo -e "\n--- 4. BŁĘDY SPRZĘTOWE (MCE) I OOM W BIEŻĄCYM DMESG ---" >> "$REPORT_FILE"
echo "Dmesg (filtrowane pod kątem sprzętu i pamięci):" >> "$REPORT_FILE"
dmesg -T 2>/dev/null | egrep -i "machine check|hardware error|out of memory|oom-killer|kill process" >> "$REPORT_FILE" || dmesg | egrep -i "machine check|hardware error|out of memory|oom-killer|kill process" >> "$REPORT_FILE"

if [ -f /var/log/mcelog ]; then
    echo -e "\nOstatnie błędy z /var/log/mcelog:" >> "$REPORT_FILE"
    tail -n 20 /var/log/mcelog >> "$REPORT_FILE"
fi

echo -e "\n===================================" >> "$REPORT_FILE"
echo "Analiza zakończona." >> "$REPORT_FILE"

# Wyświetlenie wyników na ekranie
cat "$REPORT_FILE"
echo -e "\n[!] Raport został w całości zapisany w pliku: $REPORT_FILE"
