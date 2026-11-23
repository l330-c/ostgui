@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar.ps1"
if errorlevel 1 (echo Falha na instalacao.& pause & exit /b 1)
pause
