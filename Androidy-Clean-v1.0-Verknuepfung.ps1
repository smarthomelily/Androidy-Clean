# Erstellt Desktop-Verknuepfung fuer Androidy Clean

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Desktop = [Environment]::GetFolderPath('Desktop')
$ShortcutPath = Join-Path $Desktop "Androidy Clean.lnk"

Write-Host ""
Write-Host "  Erstelle Desktop-Verknuepfung..." -ForegroundColor Cyan
Write-Host ""

try {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = Join-Path $ScriptDir "Androidy-Clean-v1.0.bat"
    $Shortcut.WorkingDirectory = $ScriptDir
    $Shortcut.IconLocation = Join-Path $ScriptDir "Androidy-Clean-v1.0.ico"
    $Shortcut.Description = "Windows Cleaning & Privacy Tool"
    $Shortcut.Save()
    
    Write-Host "  [OK] Verknuepfung erstellt!" -ForegroundColor Green
    Write-Host "  Pfad: $ShortcutPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  HINWEIS: Fuer Admin-Rechte bei jedem Start:" -ForegroundColor Yellow
    Write-Host "  1. Rechtsklick auf die Verknuepfung"
    Write-Host "  2. Eigenschaften"
    Write-Host "  3. Erweitert..."
    Write-Host "  4. 'Als Administrator ausfuehren' aktivieren"
    Write-Host ""
}
catch {
    Write-Host "  [FEHLER] $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "  Enter zum Beenden"
