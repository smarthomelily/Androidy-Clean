<#
.SYNOPSIS
    Androidy Clean v1.0 - Windows Cleaning & Privacy Tool
.DESCRIPTION
    Zwei Modi:
    - System-Wartung: Cache & Temp bereinigen (Cookies optional)
    - Datenschutz-Modus: Alle Spuren beseitigen (Privacy)
    Plus: Windows Update Reparatur
.AUTHOR
    smarthomelily
.VERSION
    1.0
.BUILD
    19860526
.LICENSE
    GPL v3 - https://www.gnu.org/licenses/gpl-3.0
    Copyright (c) 2026 smarthomelily
    
    Dieses Programm ist freie Software. Du kannst es weitergeben und/oder
    modifizieren unter den Bedingungen der GNU General Public License v3.
    Abgeleitete Werke muessen ebenfalls unter GPL v3 veroeffentlicht werden.
.LINK
    https://github.com/smarthomelily/Androidy-Clean
#>

#Requires -RunAsAdministrator

# ============================================================================
# KONFIGURATION
# ============================================================================
$script:Version = "1.0"
$script:Build = "19860526"
$script:LogFile = Join-Path $PSScriptRoot "Androidy-Clean.log"
$script:DryRun = $false
$script:fnord = 0

# Encoding auf UTF-8 setzen
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'

# Unterstuetzte Browser und ihre Pfade
$script:BrowserPaths = @{
    "Chrome" = @{
        Cache = "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache*\*"
        Cookies = "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Network\Cookies"
        History = "$env:LOCALAPPDATA\Google\Chrome\User Data\*\History"
    }
    "Firefox" = @{
        Cache = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2\*"
        Cookies = "$env:APPDATA\Mozilla\Firefox\Profiles\*\cookies.sqlite"
        History = "$env:APPDATA\Mozilla\Firefox\Profiles\*\places.sqlite"
    }
    "Edge" = @{
        Cache = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache*\*"
        Cookies = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Network\Cookies"
        History = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\History"
    }
    "Brave" = @{
        Cache = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\*\Cache*\*"
        Cookies = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\*\Network\Cookies"
        History = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\*\History"
    }
    "Opera" = @{
        Cache = "$env:APPDATA\Opera Software\Opera Stable\Cache*\*"
        Cookies = "$env:APPDATA\Opera Software\Opera Stable\Network\Cookies"
        History = "$env:APPDATA\Opera Software\Opera Stable\History"
    }
    "OperaGX" = @{
        Cache = "$env:APPDATA\Opera Software\Opera GX Stable\Cache*\*"
        Cookies = "$env:APPDATA\Opera Software\Opera GX Stable\Network\Cookies"
        History = "$env:APPDATA\Opera Software\Opera GX Stable\History"
    }
    "Vivaldi" = @{
        Cache = "$env:LOCALAPPDATA\Vivaldi\User Data\*\Cache*\*"
        Cookies = "$env:LOCALAPPDATA\Vivaldi\User Data\*\Network\Cookies"
        History = "$env:LOCALAPPDATA\Vivaldi\User Data\*\History"
    }
}

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DRYRUN")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Konsole
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "DRYRUN"  { "Cyan" }
        default   { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
    
    # Datei
    Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Get-DriveSpace {
    param([string]$Drive = $env:SystemDrive)
    try {
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$Drive'" -ErrorAction SilentlyContinue
        if ($disk) {
            return [math]::Round($disk.FreeSpace / 1GB, 2)
        }
    }
    catch {
        $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$Drive'" -ErrorAction SilentlyContinue
        if ($disk) {
            return [math]::Round($disk.FreeSpace / 1GB, 2)
        }
    }
    return 0
}

function Remove-ItemSafely {
    param(
        [string]$Path,
        [string]$Description
    )
    
    try {
        $items = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        $count = ($items | Measure-Object).Count
        
        if ($count -eq 0) {
            Write-Log "$Description - Nichts gefunden" -Level "INFO"
            return
        }
        
        if ($script:DryRun) {
            Write-Log "[DRY-RUN] Wuerde loeschen: $Description ($count Elemente)" -Level "DRYRUN"
            return
        }
        
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        $script:fnord += $count
        Write-Log "$Description geloescht ($count Elemente)" -Level "SUCCESS"
    }
    catch {
        Write-Log "Fehler bei $Description : $_" -Level "ERROR"
    }
}

function Stop-Browsers {
    $browsers = @("chrome", "firefox", "msedge", "brave", "opera", "vivaldi")
    $stopped = @()
    
    foreach ($browser in $browsers) {
        $process = Get-Process -Name $browser -ErrorAction SilentlyContinue
        if ($process) {
            if (-not $script:DryRun) {
                Stop-Process -Name $browser -Force -ErrorAction SilentlyContinue
            }
            $stopped += $browser
        }
    }
    
    if ($stopped.Count -gt 0) {
        $prefix = if ($script:DryRun) { "[DRY-RUN] Wuerde beenden" } else { "Beendet" }
        Write-Log "$prefix : $($stopped -join ', ')" -Level "WARNING"
        Start-Sleep -Seconds 2
    }
}

function Show-Header {
    Clear-Host
    $dryRunHint = if ($script:DryRun) { " [DRY-RUN MODUS]" } else { "" }
    Write-Host ""
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host "      ANDROIDY CLEAN v$($script:Version)$dryRunHint" -ForegroundColor Cyan
    Write-Host "              by smarthomelily" -ForegroundColor DarkCyan
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================================
# CLEANING FUNKTIONEN
# ============================================================================

function Invoke-Cleanmgr {
    param(
        [bool]$UseDialog = $true
    )
    
    if ($UseDialog) {
        # Variante A: Mit Auswahl-Dialog
        Write-Log "Starte Windows Datentraegerbereinigung (erweitert)..." -Level "INFO"
        
        if ($script:DryRun) {
            Write-Log "[DRY-RUN] Wuerde Cleanmgr mit Auswahl-Dialog ausfuehren" -Level "DRYRUN"
            return
        }
        
        Write-Host ""
        Write-Host "  Waehle die zu loeschenden Dateitypen und klicke OK..." -ForegroundColor Yellow
        Write-Host ""
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sageset:65535" -Wait -ErrorAction SilentlyContinue
        
        Write-Log "Fuehre Datentraegerbereinigung aus..." -Level "INFO"
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:65535" -Wait -ErrorAction SilentlyContinue
    }
    else {
        # Variante B: Automatisch ohne Dialog
        Write-Log "Starte Windows Datentraegerbereinigung (automatisch)..." -Level "INFO"
        
        if ($script:DryRun) {
            Write-Log "[DRY-RUN] Wuerde Cleanmgr automatisch ausfuehren" -Level "DRYRUN"
            return
        }
        
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:65535" -Wait -ErrorAction SilentlyContinue
    }
    
    Write-Log "Datentraegerbereinigung abgeschlossen" -Level "SUCCESS"
}

function Clear-AllRecycleBins {
    Write-Log "Leere Papierkorb auf allen Laufwerken..." -Level "INFO"
    
    if ($script:DryRun) {
        # Zaehle Elemente im Papierkorb
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(0xA)
            $count = $recycleBin.Items().Count
            Write-Log "[DRY-RUN] Wuerde Papierkorb leeren ($count Elemente)" -Level "DRYRUN"
        }
        catch {
            Write-Log "[DRY-RUN] Wuerde Papierkorb leeren" -Level "DRYRUN"
        }
        return
    }
    
    try {
        # Papierkorb leeren (PowerShell 5.1+)
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Log "Papierkorb geleert" -Level "SUCCESS"
    }
    catch {
        # Fallback: Manuell loeschen
        try {
            $drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -ExpandProperty DeviceID
        }
        catch {
            $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -ExpandProperty DeviceID
        }
        foreach ($drive in $drives) {
            $recyclePath = "$drive\`$Recycle.Bin"
            if (Test-Path $recyclePath) {
                Remove-Item -Path "$recyclePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Papierkorb geleert: $drive" -Level "SUCCESS"
            }
        }
    }
}

function Clear-Prefetch {
    Write-Log "Bereinige Prefetch..." -Level "INFO"
    Remove-ItemSafely -Path "$env:SystemRoot\Prefetch\*" -Description "Prefetch"
}

function Clear-TempFolders {
    Write-Log "Bereinige temporaere Ordner..." -Level "INFO"
    
    Remove-ItemSafely -Path "$env:TEMP\*" -Description "User Temp"
    Remove-ItemSafely -Path "$env:SystemRoot\Temp\*" -Description "Windows Temp"
}

function Clear-BrowserCache {
    Write-Log "Bereinige Browser-Caches..." -Level "INFO"
    Stop-Browsers
    
    foreach ($browser in $script:BrowserPaths.Keys) {
        $cachePath = $script:BrowserPaths[$browser].Cache
        if (Test-Path (Split-Path $cachePath -Parent).Replace("*", "Default")) {
            Remove-ItemSafely -Path $cachePath -Description "$browser Cache"
        }
    }
}

function Clear-BrowserCookies {
    Write-Log "Loesche Browser-Cookies..." -Level "INFO"
    Stop-Browsers
    
    foreach ($browser in $script:BrowserPaths.Keys) {
        $cookiePath = $script:BrowserPaths[$browser].Cookies
        $resolved = Resolve-Path $cookiePath -ErrorAction SilentlyContinue
        if ($resolved) {
            foreach ($path in $resolved) {
                if ($script:DryRun) {
                    Write-Log "[DRY-RUN] Wuerde loeschen: $browser Cookies" -Level "DRYRUN"
                } else {
                    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                    Write-Log "$browser Cookies geloescht" -Level "SUCCESS"
                }
            }
        }
    }
}

function Clear-BrowserHistory {
    Write-Log "Loesche Browser-Verlauf..." -Level "INFO"
    Stop-Browsers
    
    foreach ($browser in $script:BrowserPaths.Keys) {
        $historyPath = $script:BrowserPaths[$browser].History
        $resolved = Resolve-Path $historyPath -ErrorAction SilentlyContinue
        if ($resolved) {
            foreach ($path in $resolved) {
                if ($script:DryRun) {
                    Write-Log "[DRY-RUN] Wuerde loeschen: $browser Verlauf" -Level "DRYRUN"
                } else {
                    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                    Write-Log "$browser Verlauf geloescht" -Level "SUCCESS"
                }
            }
        }
    }
}

# ============================================================================
# PRIVACY FUNKTIONEN
# ============================================================================

function Clear-RecentFiles {
    Write-Log "Loesche Recent Files..." -Level "INFO"
    Remove-ItemSafely -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Description "Recent Files"
    Remove-ItemSafely -Path "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Description "Jump Lists (Auto)"
    Remove-ItemSafely -Path "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*" -Description "Jump Lists (Custom)"
}

function Clear-ExplorerHistory {
    Write-Log "Loesche Explorer-Verlauf..." -Level "INFO"
    
    $regPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    )
    
    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            if ($script:DryRun) {
                Write-Log "[DRY-RUN] Wuerde Registry loeschen: $regPath" -Level "DRYRUN"
            } else {
                Remove-ItemProperty -Path $regPath -Name * -ErrorAction SilentlyContinue
                Write-Log "Registry bereinigt: $regPath" -Level "SUCCESS"
            }
        }
    }
}

function Clear-OfficeRecent {
    Write-Log "Loesche Office Recent Documents..." -Level "INFO"
    Remove-ItemSafely -Path "$env:APPDATA\Microsoft\Office\Recent\*" -Description "Office Recent"
}

function Clear-EventLogs {
    Write-Log "Loesche Windows Event-Logs..." -Level "INFO"
    
    if ($script:DryRun) {
        $logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }
        Write-Log "[DRY-RUN] Wuerde $($logs.Count) Event-Logs loeschen" -Level "DRYRUN"
        return
    }
    
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName)
        } catch { }
    }
    Write-Log "Event-Logs geloescht" -Level "SUCCESS"
}

function Clear-DNSCache {
    Write-Log "Loesche DNS Cache..." -Level "INFO"
    
    if ($script:DryRun) {
        Write-Log "[DRY-RUN] Wuerde DNS Cache leeren" -Level "DRYRUN"
        return
    }
    
    Clear-DnsClientCache
    Write-Log "DNS Cache geleert" -Level "SUCCESS"
}

function Clear-Clipboard {
    Write-Log "Loesche Zwischenablage..." -Level "INFO"
    
    if ($script:DryRun) {
        Write-Log "[DRY-RUN] Wuerde Zwischenablage leeren" -Level "DRYRUN"
        return
    }
    
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::Clear()
    Write-Log "Zwischenablage geleert" -Level "SUCCESS"
}

function Clear-ShadowCopies {
    Write-Log "Loesche Schattenkopien und Wiederherstellungspunkte..." -Level "INFO"
    
    if ($script:DryRun) {
        try {
            $shadows = Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction SilentlyContinue
        }
        catch {
            $shadows = Get-WmiObject Win32_ShadowCopy -ErrorAction SilentlyContinue
        }
        $count = ($shadows | Measure-Object).Count
        Write-Log "[DRY-RUN] Wuerde $count Schattenkopien loeschen" -Level "DRYRUN"
        return
    }
    
    try {
        vssadmin delete shadows /all /quiet 2>$null
        Write-Log "Schattenkopien geloescht" -Level "SUCCESS"
    }
    catch {
        Write-Log "Fehler beim Loeschen der Schattenkopien: $_" -Level "ERROR"
    }
}

# ============================================================================
# WINDOWS UPDATE RESET
# ============================================================================

function Reset-WindowsUpdate {
    Write-Log "=== WINDOWS UPDATE RESET ===" -Level "INFO"
    
    $services = @("wuauserv", "cryptSvc", "bits", "msiserver")
    
    # Dienste stoppen
    Write-Log "Stoppe Windows Update Dienste..." -Level "INFO"
    foreach ($service in $services) {
        if ($script:DryRun) {
            Write-Log "[DRY-RUN] Wuerde stoppen: $service" -Level "DRYRUN"
        } else {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Ordner umbenennen
    $folders = @(
        "$env:SystemRoot\SoftwareDistribution",
        "$env:SystemRoot\System32\catroot2"
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    foreach ($folder in $folders) {
        if (Test-Path $folder) {
            $backupName = (Split-Path $folder -Leaf) + ".bak_$timestamp"
            if ($script:DryRun) {
                Write-Log "[DRY-RUN] Wuerde umbenennen: $folder -> $backupName" -Level "DRYRUN"
            } else {
                Rename-Item -Path $folder -NewName $backupName -Force -ErrorAction SilentlyContinue
                Write-Log "Umbenannt: $folder" -Level "SUCCESS"
            }
        }
    }
    
    # Dienste starten
    Write-Log "Starte Windows Update Dienste..." -Level "INFO"
    foreach ($service in $services) {
        if ($script:DryRun) {
            Write-Log "[DRY-RUN] Wuerde starten: $service" -Level "DRYRUN"
        } else {
            Start-Service -Name $service -ErrorAction SilentlyContinue
        }
    }
    
    Write-Log "Windows Update Reset abgeschlossen" -Level "SUCCESS"
    Write-Log "HINWEIS: Bitte PC neu starten und Windows Update erneut versuchen" -Level "WARNING"
}

# ============================================================================
# MODI
# ============================================================================

function Invoke-ModeSystemWartung {
    param(
        [bool]$IncludeCookies = $false,
        [bool]$CleanmgrDialog = $true,
        [bool]$DeleteShadowCopies = $false
    )
    
    $spaceBeforeGB = Get-DriveSpace
    Write-Log "=== MODUS: SYSTEM-WARTUNG ===" -Level "INFO"
    Write-Log "Speicherplatz vorher: $spaceBeforeGB GB frei" -Level "INFO"
    
    Clear-TempFolders
    Clear-Prefetch
    Clear-BrowserCache
    
    if ($IncludeCookies) {
        Clear-BrowserCookies
    }
    
    # Schattenkopien (optional)
    if ($DeleteShadowCopies) {
        Clear-ShadowCopies
    }
    
    Clear-AllRecycleBins
    Invoke-Cleanmgr -UseDialog $CleanmgrDialog
    
    $spaceAfterGB = Get-DriveSpace
    $freedGB = [math]::Round($spaceAfterGB - $spaceBeforeGB, 2)
    
    Write-Host ""
    Write-Log "=== ERGEBNIS ===" -Level "INFO"
    Write-Log "Speicherplatz nachher: $spaceAfterGB GB frei" -Level "SUCCESS"
    Write-Log "Freigegeben: $freedGB GB" -Level "SUCCESS"
}

function Invoke-ModeDatenschutz {
    param(
        [bool]$CleanmgrDialog = $true,
        [bool]$DeleteShadowCopies = $false
    )
    
    $spaceBeforeGB = Get-DriveSpace
    Write-Log "=== MODUS: DATENSCHUTZ ===" -Level "INFO"
    Write-Log "Speicherplatz vorher: $spaceBeforeGB GB frei" -Level "INFO"
    
    # Cleaning
    Clear-TempFolders
    Clear-Prefetch
    Clear-BrowserCache
    
    # Privacy - Browser
    Clear-BrowserCookies
    Clear-BrowserHistory
    
    # Privacy - Windows
    Clear-RecentFiles
    Clear-ExplorerHistory
    Clear-OfficeRecent
    Clear-EventLogs
    Clear-DNSCache
    Clear-Clipboard
    
    # Schattenkopien (optional)
    if ($DeleteShadowCopies) {
        Clear-ShadowCopies
    }
    
    # System
    Clear-AllRecycleBins
    Invoke-Cleanmgr -UseDialog $CleanmgrDialog
    
    $spaceAfterGB = Get-DriveSpace
    $freedGB = [math]::Round($spaceAfterGB - $spaceBeforeGB, 2)
    
    Write-Host ""
    Write-Log "=== ERGEBNIS ===" -Level "INFO"
    Write-Log "Speicherplatz nachher: $spaceAfterGB GB frei" -Level "SUCCESS"
    Write-Log "Freigegeben: $freedGB GB" -Level "SUCCESS"
    Write-Log "Alle Spuren beseitigt!" -Level "SUCCESS"
    
    if (-not $script:DryRun) { exit 23 }
}

# ============================================================================
# HAUPTMENUe
# ============================================================================

function Show-Menu {
    while ($true) {
        Show-Header
        
        Write-Host "  [1] System-Wartung" -ForegroundColor White
        Write-Host "      Caches & Temp bereinigen" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [2] Datenschutz-Modus" -ForegroundColor White
        Write-Host "      Alle Spuren beseitigen" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [3] Windows Update Reparatur" -ForegroundColor White
        Write-Host "      Update-Komponenten zuruecksetzen" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [D] Dry-Run Modus: $(if($script:DryRun){'EIN'}else{'AUS'})" -ForegroundColor $(if($script:DryRun){'Cyan'}else{'DarkGray'})
        Write-Host "  [L] Log-Datei oeffnen" -ForegroundColor DarkGray
        Write-Host "  [0] Beenden" -ForegroundColor DarkGray
        Write-Host ""
        
        $choice = Read-Host "  Auswahl"
        
        switch ($choice.ToUpper()) {
            "1" {
                Show-Header
                Write-Host "  Cookies auch loeschen? [J/N]: " -NoNewline -ForegroundColor Yellow
                $cookieChoice = Read-Host
                $includeCookies = $cookieChoice.ToUpper() -eq "J"
                
                Write-Host ""
                Write-Host "  Schattenkopien/Wiederherstellungspunkte loeschen? [J/N]: " -NoNewline -ForegroundColor Yellow
                $shadowChoice = Read-Host
                $deleteShadows = $shadowChoice.ToUpper() -eq "J"
                
                Write-Host ""
                Write-Host "  Datentraegerbereinigung:" -ForegroundColor Yellow
                Write-Host "  [A] Auswahl-Dialog (erweitert)" -ForegroundColor White
                Write-Host "  [S] Schnell (gespeicherte Einstellungen)" -ForegroundColor White
                Write-Host "  Auswahl [A/S]: " -NoNewline -ForegroundColor Yellow
                $cleanmgrChoice = Read-Host
                $useDialog = $cleanmgrChoice.ToUpper() -ne "S"
                
                Write-Host ""
                Invoke-ModeSystemWartung -IncludeCookies $includeCookies -CleanmgrDialog $useDialog -DeleteShadowCopies $deleteShadows
                Write-Host ""
                Read-Host "  Enter zum Fortfahren"
            }
            "2" {
                Show-Header
                Write-Host "  WARNUNG: Alle Spuren werden geloescht!" -ForegroundColor Red
                Write-Host "  Fortfahren? [J/N]: " -NoNewline -ForegroundColor Yellow
                $confirm = Read-Host
                
                if ($confirm.ToUpper() -eq "J") {
                    Write-Host ""
                    Write-Host "  Schattenkopien/Wiederherstellungspunkte loeschen?" -ForegroundColor Yellow
                    Write-Host "  (Setzt alle Systemwiederherstellung zurueck!)" -ForegroundColor DarkGray
                    Write-Host "  [J/N]: " -NoNewline -ForegroundColor Yellow
                    $shadowChoice = Read-Host
                    $deleteShadows = $shadowChoice.ToUpper() -eq "J"
                    
                    Write-Host ""
                    Write-Host "  Datentraegerbereinigung:" -ForegroundColor Yellow
                    Write-Host "  [A] Auswahl-Dialog (erweitert)" -ForegroundColor White
                    Write-Host "  [S] Schnell (gespeicherte Einstellungen)" -ForegroundColor White
                    Write-Host "  Auswahl [A/S]: " -NoNewline -ForegroundColor Yellow
                    $cleanmgrChoice = Read-Host
                    $useDialog = $cleanmgrChoice.ToUpper() -ne "S"
                    
                    Write-Host ""
                    Invoke-ModeDatenschutz -CleanmgrDialog $useDialog -DeleteShadowCopies $deleteShadows
                }
                Write-Host ""
                Read-Host "  Enter zum Fortfahren"
            }
            "3" {
                Show-Header
                Write-Host "  Windows Update Komponenten zuruecksetzen?" -ForegroundColor Yellow
                Write-Host "  [J/N]: " -NoNewline
                $confirm = Read-Host
                
                if ($confirm.ToUpper() -eq "J") {
                    Write-Host ""
                    Reset-WindowsUpdate
                }
                Write-Host ""
                Read-Host "  Enter zum Fortfahren"
            }
            "D" {
                $script:DryRun = -not $script:DryRun
                $status = if ($script:DryRun) { "aktiviert" } else { "deaktiviert" }
                Write-Log "Dry-Run Modus $status" -Level "INFO"
            }
            "L" {
                if (Test-Path $script:LogFile) {
                    Start-Process notepad.exe -ArgumentList $script:LogFile
                } else {
                    Write-Host "  Keine Log-Datei vorhanden" -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
            }
            "0" {
                Write-Host ""
                Write-Host "  Auf Wiedersehen!" -ForegroundColor Cyan
                Write-Host ""
                return
            }
        }
    }
}

# ============================================================================
# START
# ============================================================================

# Log initialisieren
Write-Log "=== Androidy Clean v$script:Version gestartet ===" -Level "INFO"

# Menue anzeigen
Show-Menu

# Log beenden
Write-Log "=== Androidy Clean beendet ===" -Level "INFO"
