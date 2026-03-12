@echo off
:: Skrypt do analizy przyczyn restartu Windows Server (CMD)
:: Wymagane uprawnienia: Administrator

:: Ustawienie sciezki raportu
set REPORT="C:\reboot_analysis.txt"

echo === RAPORT ANALIZY PO RESTARCIE (WINDOWS) === > %REPORT%
echo Nazwa serwera: %COMPUTERNAME% >> %REPORT%
echo Data wygenerowania: %date% %time% >> %REPORT%
echo =========================================== >> %REPORT%

echo. >> %REPORT%
echo --- 1. SPRAWDZENIE MINIDUMP (Blue Screen of Death) --- >> %REPORT%
if exist "C:\Windows\MEMORY.DMP" (
    echo [UWAGA] Znaleziono glowny zrzut pamieci: C:\Windows\MEMORY.DMP >> %REPORT%
) else (
    echo Brak glownego pliku MEMORY.DMP. >> %REPORT%
)
if exist "C:\Windows\Minidump\*.dmp" (
    echo [UWAGA] Znaleziono pliki minidump w C:\Windows\Minidump\: >> %REPORT%
    dir /b "C:\Windows\Minidump\*.dmp" >> %REPORT%
) else (
    echo Brak plikow zrzutow w C:\Windows\Minidump. >> %REPORT%
)

echo. >> %REPORT%
echo --- 2. ZDARZENIE 41 (Kernel-Power) - Nagla utrata zasilania / twardy reset --- >> %REPORT%
:: Pobiera 3 ostatnie zdarzenia ID 41 od najnowszych
wevtutil qe System /q:"*[System[(EventID=41)]]" /c:3 /f:text /rd:true >> %REPORT%

echo. >> %REPORT%
echo --- 3. ZDARZENIE 6008 (EventLog) - Nieoczekiwane zamkniecie systemu --- >> %REPORT%
wevtutil qe System /q:"*[System[(EventID=6008)]]" /c:3 /f:text /rd:true >> %REPORT%

echo. >> %REPORT%
echo --- 4. ZDARZENIE 1001 (BugCheck) - Kody bledu Blue Screen --- >> %REPORT%
wevtutil qe System /q:"*[System[(EventID=1001)]]" /c:3 /f:text /rd:true >> %REPORT%

echo. >> %REPORT%
echo --- 5. ZDARZENIE 1074 / 1076 - Standardowe restarty (np. Windows Update) --- >> %REPORT%
wevtutil qe System /q:"*[System[(EventID=1074) or (EventID=1076)]]" /c:5 /f:text /rd:true >> %REPORT%

echo =========================================== >> %REPORT%
echo Analiza zakonczona. >> %REPORT%

:: Wyswietlenie zawartosci raportu w konsoli
type %REPORT%

echo.
echo [!] Raport zostal w calosci zapisany w pliku: %REPORT%
pause
