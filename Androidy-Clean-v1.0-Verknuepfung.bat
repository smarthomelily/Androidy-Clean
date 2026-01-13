@echo off
:: Erstellt eine Desktop-Verknuepfung fuer Androidy Clean
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0Androidy-Clean-v1.0-Verknuepfung.ps1"
