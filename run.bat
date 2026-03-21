@echo off

:: Проверка прав администратора
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Запуск от имени администратора...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~f0' -Verb RunAs"
    exit
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0asset-setup.ps1"
pause