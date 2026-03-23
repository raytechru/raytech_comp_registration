@echo off

:: Проверка на админа
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0' -Verb RunAs"
    pause
)

:: Основной запуск
echo Starting Raytech Asset Tool...
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/raytechru/raytech_comp_registration/refs/heads/main/asset-setup.ps1' | iex"

pause