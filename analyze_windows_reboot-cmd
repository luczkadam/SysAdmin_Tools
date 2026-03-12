@echo off
setlocal enabledelayedexpansion
:: Skrypt automatycznie odczytujacy i interpretujacy ostatni BugCheck (Blue Screen) z logow

echo === AUTOMATYCZNA INTERPRETACJA OSTATNIEGO BLEDU KRYTYCZNEGO ===
echo Trwa przeszukiwanie logow (Event ID 1001)...
echo.

:: Pobranie tekstu ostatniego zdarzenia BugCheck (ID 1001)
set "CRASH_DATA="
for /f "tokens=*" %%A in ('wevtutil qe System /q:"*[System[(EventID=1001)]]" /c:1 /f:text /rd:true ^| findstr /i "bugcheck"') do (
    set "CRASH_DATA=%%A"
)

:: Sprawdzenie czy znaleziono błąd
if not defined CRASH_DATA (
    echo [OK] Nie znaleziono informacji o ostatnich bledach typu Blue Screen w logach.
    goto :koniec
)

echo Znaleziony wpis:
echo !CRASH_DATA!
echo.
echo --- DIAGNOZA I MOZLIWE PRZYCZYNY ---

:: Prosty slownik dekodujacy najczestsze kody bledow HEX
echo !CRASH_DATA! | findstr /i "0x0000000a 0x0000000A 0xa 0xA" >nul
if !errorlevel!==0 echo [0x0A: IRQL_NOT_LESS_OR_EQUAL] Wskazowka: Zazwyczaj problem z wadliwym sterownikiem (czesto karta sieciowa, kontroler dysku) lub rzadziej - uszkodzony RAM.

echo !CRASH_DATA! | findstr /i "0x0000001e 0x0000001E 0x1e 0x1E" >nul
if !errorlevel!==0 echo [0x1E: KMODE_EXCEPTION_NOT_HANDLED] Wskazowka: Blad sprzetowy lub powazny konflikt sterownikow uzywajacych pamieci jadra.

echo !CRASH_DATA! | findstr /i "0x0000003b 0x0000003B 0x3b 0x3B" >nul
if !errorlevel!==0 echo [0x3B: SYSTEM_SERVICE_EXCEPTION] Wskazowka: Najczesciej awaria sterownika graficznego (zintegrowanego) lub konflikty sterownikow systemowych.

echo !CRASH_DATA! | findstr /i "0x00000050 0x00000050 0x50 0x50" >nul
if !errorlevel!==0 echo [0x50: PAGE_FAULT_IN_NONPAGED_AREA] Wskazowka: System szukal danych w pamieci, ale ich nie znalazl. Zazwyczaj oznacza uszkodzony RAM, blad oprogramowania antywirusowego lub uszkodzony system plikow (NTFS).

echo !CRASH_DATA! | findstr /i "0x0000009f 0x0000009F 0x9f 0x9F" >nul
if !errorlevel!==0 echo [0x9F: DRIVER_POWER_STATE_FAILURE] Wskazowka: Sterownik nie wywiazal sie z obslugi stanow zasilania (np. serwer nie wybudzil urzadzenia poprawnie). Sprawdz sterowniki zarzadzania energia.

echo !CRASH_DATA! | findstr /i "0x000000d1 0x000000D1 0xd1 0xD1" >nul
if !errorlevel!==0 echo [0xD1: DRIVER_IRQL_NOT_LESS_OR_EQUAL] Wskazowka: Jeden z najczestszych bledow. Klasyczny problem z nieaktualnym sterownikiem (zazwyczaj urzadzenie sieciowe, iSCSI lub FC).

echo !CRASH_DATA! | findstr /i "0x000000ef 0x000000EF 0xef 0xEF" >nul
if !errorlevel!==0 echo [0xEF: CRITICAL_PROCESS_DIED] Wskazowka: Krytyczny proces systemowy (np. wininit.exe, csrss.exe) zostal niespodziewanie zabity. Moze sugerowac fizyczny problem z dyskiem (bad sectory) lub infekcje.

:: Jesli skrypt nie odnalazl konkretnego kodu z bazy
echo.
echo Jesli powyzszy slownik nie rozszyfrowal kodu, wyszukaj znaleziony ciag "BugCheckParam1" w oficjalnej dokumentacji Microsoft (Bug Check Code Reference).

:koniec
echo.
echo =========================================================
pause
