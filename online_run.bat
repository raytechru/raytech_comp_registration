@echo off

:: Проверка на администратора
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    pause
)

:: === Уже с правами администратора ===
echo Starting Raytech Asset Tool...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"irm 'https://raw.githubusercontent.com/raytechru/raytech_comp_registration/main/asset-setup.ps1' | iex"

pause