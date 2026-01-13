@echo off
:: Androidy Clean v1.0 - Starter
:: Startet das PowerShell-Skript mit Admin-Rechten

:: UTF-8 Codepage setzen
chcp 65001 >nul

:: Admin-Check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Fordere Admin-Rechte an...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: PowerShell-Skript im gleichen Ordner starten
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Androidy-Clean-v1.0.ps1"
pause
