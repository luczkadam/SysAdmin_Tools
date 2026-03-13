# ==============================================================================
# Script Name:   win_vm_network_verifier.ps1
# Description:   Saves and verifies the network configuration (IP, Netmask, 
#                Routing, and MAC addresses) of a Windows Virtual Machine 
#                before and after hypervisor migration.
# Compatibility: Windows Server 2012 and newer (Requires PowerShell 3.0+)
#
# Usage: 
#   Step 1 (Pre-migration) : powershell.exe -ExecutionPolicy Bypass -File .\win_vm_network_verifier.ps1 Save
#   Step 2 (Post-migration): powershell.exe -ExecutionPolicy Bypass -File .\win_vm_network_verifier.ps1 Verify
#
# Note: The state file is saved on the current user's Desktop.
# ==============================================================================

<#
.SYNOPSIS
    Windows VM Network Migration Verifier
.DESCRIPTION
    Saves and verifies the network configuration (IP, Netmask, 
    Routing, and MAC addresses) of a Windows Virtual Machine 
    before and after hypervisor migration.
    The state file is saved on the current user's Desktop.
#>

param (
    # Position=0 pozwala na podanie wartości bez wpisywania "-Mode"
    [Parameter(Position=0)]
    [string]$Mode
)

$DesktopPath = [Environment]::GetFolderPath("Desktop")
$StateFile = Join-Path -Path $DesktopPath -ChildPath "VM_NetworkState.xml"

if ($Mode -ieq "Save") {
    Write-Host "=== Saving pre-migration network state ===" -ForegroundColor Cyan
    
    $NetState = @{
        IPs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object InterfaceAlias -NotMatch "Loopback" | Select-Object InterfaceAlias, IPAddress, PrefixLength
        Routes = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object NextHop -ne "0.0.0.0" | Select-Object DestinationPrefix, NextHop
        Adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, MacAddress
    }
    
    $NetState | Export-Clixml -Path $StateFile
    Write-Host "[SUCCESS] Network state saved to your desktop: $StateFile" -ForegroundColor Green
    Write-Host "You can now migrate the VM. After reboot, run the script with 'Verify' parameter." -ForegroundColor Gray
}
elseif ($Mode -ieq "Verify") {
    if (-not (Test-Path $StateFile)) {
        Write-Host "[ERROR] Cannot find $StateFile. Run the script with 'Save' parameter first." -ForegroundColor Red
        exit
    }
    
    $OldState = Import-Clixml -Path $StateFile
    Write-Host "=== Verifying post-migration network state ===" -ForegroundColor Cyan

    Write-Host "`n--- IP Addresses and Subnets ---" -ForegroundColor White
    foreach ($oldIp in $OldState.IPs) {
        $found = Get-NetIPAddress -IPAddress $oldIp.IPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($found) {
            if ($found.InterfaceAlias -eq $oldIp.InterfaceAlias) {
                Write-Host "[OK] Address $($oldIp.IPAddress)/$($oldIp.PrefixLength) configured correctly on interface '$($oldIp.InterfaceAlias)'" -ForegroundColor Green
            } else {
                Write-Host "[OK] Address $($oldIp.IPAddress)/$($oldIp.PrefixLength) found, but on a DIFFERENT interface: '$($found.InterfaceAlias)' (was: '$($oldIp.InterfaceAlias)')" -ForegroundColor Green
            }
        } else {
            Write-Host "[ERROR] Missing address $($oldIp.IPAddress)/$($oldIp.PrefixLength) in the system!" -ForegroundColor Red
        }
    }

    Write-Host "`n--- Routing ---" -ForegroundColor White
    foreach ($oldRoute in $OldState.Routes) {
        $foundRoute = Get-NetRoute -DestinationPrefix $oldRoute.DestinationPrefix -NextHop $oldRoute.NextHop -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($foundRoute) {
            Write-Host "[OK] Route to $($oldRoute.DestinationPrefix) via $($oldRoute.NextHop) exists." -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Missing route to $($oldRoute.DestinationPrefix) via $($oldRoute.NextHop)!" -ForegroundColor Red
        }
    }

    Write-Host "`n--- MAC Addresses (Informational) ---" -ForegroundColor White
    $CurrentAdapters = Get-NetAdapter -ErrorAction SilentlyContinue
    foreach ($oldMac in $OldState.Adapters) {
        $current = $CurrentAdapters | Where-Object Name -eq $oldMac.Name
        if ($current) {
            if ($current.MacAddress -eq $oldMac.MacAddress) {
                Write-Host "[OK] MAC for interface '$($oldMac.Name)' matches ($($oldMac.MacAddress))." -ForegroundColor Green
            } else {
                Write-Host "[INFO] MAC for interface '$($oldMac.Name)' has changed!" -ForegroundColor Yellow
                Write-Host "       Old: $($oldMac.MacAddress) | New: $($current.MacAddress)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "[INFO] Interface named '$($oldMac.Name)' no longer exists (OS might have renamed it)." -ForegroundColor Yellow
            Write-Host "       Its old MAC was: $($oldMac.MacAddress)" -ForegroundColor DarkGray
        }
    }
}
else {
    # Co się stanie, gdy użytkownik nie poda parametru lub poda błędny:
    Write-Host "Usage: .\win_vm_network_verifier.ps1 {Save|Verify}" -ForegroundColor Yellow
    Write-Host "Example to save:   powershell.exe -ExecutionPolicy Bypass -File .\win_vm_network_verifier.ps1 Save" -ForegroundColor Gray
    Write-Host "Example to verify: powershell.exe -ExecutionPolicy Bypass -File .\win_vm_network_verifier.ps1 Verify" -ForegroundColor Gray
}
