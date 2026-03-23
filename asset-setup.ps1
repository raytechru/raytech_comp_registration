# VERSION: 2.0 STABLE
# Features:
# - Interactive menu
# - Computer status (local registry)
# - Add new device (Google + CSV + Registry)
# - No update / no auth
# Stable local version

$regPath = "HKLM:\SOFTWARE\Company\Asset"
$url = "https://script.google.com/macros/s/AKfycbxTi07kyNcvCLWN9TrjCVO-a0xcwC3NRhRy2RuSL0pxTOAh2o-ChuUdQvv0EZCincieQg/exec"
$apiUrl = $url


# ==============================
# FUNCTION: GETTING HASH
# ==============================
function Get-Hash($text) {
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ""
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $hash = $sha.ComputeHash($bytes)
    return ($hash | ForEach-Object { $_.ToString("x2") }) -join ""
}


# ==============================
# FUNCTION: TEST-LOGIN
# ==============================
function Test-Login {

    Write-Host ""
    $password = Read-Host "Enter password"
    $password = $password.Trim()

    $hash = Get-Hash $password

    $body = @{
        action = "verify"
        hash   = $hash
    } | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod `
            -Uri $apiUrl `
            -Method POST `
            -Body $body `
            -ContentType "application/json; charset=utf-8"

        return [bool]$response.success
    }
    catch {
        Write-Host ""
        Write-Host "Auth server unavailable. Access blocked." -ForegroundColor Red
        Write-Host ""
        pause
        exit
    }
}

# ==============================
# ADMIN CHECK
# ==============================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltinRole]::Administrator)) {

    Write-Host "Run as administrator!" -ForegroundColor Red
    exit
}

# ==============================
# TLS FIX
# ==============================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# ==============================
# LOGIN
# ==============================
Write-Host ""
Write-Host "=== AUTHORIZATION REQUIRED ===" -ForegroundColor Cyan

if (-not (Test-Login)) {
    Write-Host "Access denied" -ForegroundColor Red
    exit
}


# ==============================
# FUNCTION: REQUIRED INPUT
# ==============================
function Read-Required($prompt) {

    do {
        $value = Read-Host $prompt

        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host "Value cannot be empty. Please enter a valid value." -ForegroundColor Yellow
        }

    } until (-not [string]::IsNullOrWhiteSpace($value))

    return $value
}


# ==============================
# FUNCTION: STATUS
# ==============================
function Show-Status {

    Write-Host ""
    Write-Host "=== COMPUTER STATUS ===" -ForegroundColor Cyan

    if (Test-Path $regPath) {

        $data = Get-ItemProperty $regPath

        if ($data.AssetID) { Write-Host "AssetID :" $data.AssetID } else { Write-Host "AssetID : empty" }
        if ($data.Owner)   { Write-Host "Owner   :" $data.Owner }   else { Write-Host "Owner   : empty" }
        if ($data.Model)   { Write-Host "Model   :" $data.Model }   else { Write-Host "Model   : empty" }
        if ($data.Serial)  { Write-Host "Serial  :" $data.Serial }  else { Write-Host "Serial  : empty" }

    }
    else {
        Write-Host "AssetID : empty"
        Write-Host "Owner   : empty"
        Write-Host "Model   : empty"
        Write-Host "Serial  : empty"
    }

    Write-Host ""
}


# ==============================
# FUNCTION: ADD DEVICE
# ==============================
function Add-Device {

    Write-Host "=== PC Setup ===" -ForegroundColor Cyan


# ==============================
# TYPE VALIDATION
# ==============================
do {
    $type = (Read-Host "Enter type (NB/PC/NT)").ToUpper()

    if ($type -notin @("NB","PC","NT")) {
        Write-Host "Invalid type. Allowed: NB (laptop), PC (desktop), NT (nettop)" -ForegroundColor Yellow
    }

} until ($type -in @("NB","PC","NT"))


# ==============================
# CITY VALIDATION
# ==============================
do {
    $city = (Read-Host "Enter city code (3 letters, e.g. MSK)").ToUpper()

    if ($city -notmatch '^[A-Z]{3}$') {
        Write-Host "Invalid city code. Must be exactly 3 letters (e.g. MSK, VRN)" -ForegroundColor Yellow
    }

} until ($city -match '^[A-Z]{3}$')


# ==============================
# GET REGISTRATION NUMBER FROM
# ==============================
    $nextNumber = $null

    try {
        $requestUrl = "$($url)?city=$city&type=$type"
    Write-Host "Request: Corp Database for next empty cell number!"

        $response = Invoke-RestMethod -Uri $requestUrl -Method Get -ErrorAction Stop

        if ($response.next) {
            $nextNumber = [int]$response.next
        } else {
            throw "Invalid response"
        }

    Write-Host "Next cell number is: $nextNumber" -ForegroundColor Green
    }
    catch {
    Write-Host "Database unavailable - manual number required" -ForegroundColor Yellow

        do {
            $manual = Read-Host "Enter number manually (e.g. 001)"
        } until ($manual -match '^\d{1,3}$')

        $nextNumber = [int]$manual
    }

# format number
    $number = "{0:D3}" -f $nextNumber

# names
    $asset = "$type-$city-$number"
    $hostname = $asset

# === OWNER ===
    $owner = Read-Required "Enter owner (lastname)"

# === MODEL ===
    $autoModel = (Get-CimInstance Win32_ComputerSystemProduct).Name
    Write-Host "Detected model: $autoModel"
    $confirmModel = Read-Host "Correct? (Y/N)"

    if ($confirmModel -eq "Y") {
        $model = $autoModel
    } else {
        $model = Read-Required "Enter model manually"
    }

# === SERIAL ===
    $autoSerial = (Get-CimInstance Win32_BIOS).SerialNumber
    Write-Host "Detected serial: $autoSerial"
    $confirmSerial = Read-Host "Correct? (Y/N)"

    if ($confirmSerial -eq "Y") {
        $serial = $autoSerial
    } else {
        $serial = Read-Required "Enter model manually"
    }

# === DESCRIPTION ===
    $desc = "$model | $owner"

# === PREVIEW ===
    Write-Host ""
    Write-Host "=== CHECK ===" -ForegroundColor Cyan
    Write-Host "AssetID :" $asset
    Write-Host "Owner   :" $owner
    Write-Host "Model   :" $model
    Write-Host "Serial  :" $serial
    Write-Host "Description  :" $desc

    $confirm = Read-Host "Save? (Y/N)"

    if ($confirm -ne "Y") {
        Write-Host "Cancelled"
    return
    }

# === SAVE TO REGISTRY ===
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "AssetID" -Value $asset
    Set-ItemProperty -Path $regPath -Name "Owner" -Value $owner
    Set-ItemProperty -Path $regPath -Name "Model" -Value $model
    Set-ItemProperty -Path $regPath -Name "Serial" -Value $serial

# === SAVE DESCRIPTION ===
    Set-ItemProperty `
      -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
      -Name "srvcomment" `
      -Value $desc

# ==============================
# SAVE LOCAL (FIXED PATH)
# ==============================

# базовый путь Documents
$basePath = [Environment]::GetFolderPath("MyDocuments")

# папка
$folderPath = Join-Path $basePath "comp_registration"

# создать папку если нет
if (-not (Test-Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory | Out-Null
}

# имя файла
$safeName = "$asset - $owner" -replace '[\\/:*?""<>|]', '_'

# ПОЛНЫЙ путь к файлу
$filePath = Join-Path $folderPath "$safeName.csv"

# данные
$data = [PSCustomObject]@{
    Date     = (Get-Date)
    AssetID  = $asset
    Owner    = $owner
    Model    = $model
    Serial   = $serial
    City     = $city
    Hostname = $hostname
}

# сохранение
$data | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8

Write-Host "Saved locally: $filePath" -ForegroundColor Green

# открыть папку
if (Test-Path $folderPath) {
    Start-Process explorer.exe $folderPath
}

#====================================
#       GOOGLE Company Database
#====================================
    try {
        $body = @{
            asset    = $asset
            owner    = $owner
            model    = $model
            serial   = $serial
            city     = $city
            hostname = $hostname
        } | ConvertTo-Json

        Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json"

        Write-Host "Saved to Google Sheets" -ForegroundColor Green
    }
    catch {
        Write-Host "Google copy NOT saved (no connection)" -ForegroundColor Yellow
    }
}

# ==============================
# MAIN MENU
# ==============================
while ($true) {

    Write-Host "=============================="
    Write-Host "1 - Computer status"
    Write-Host "2 - Add new device"
    Write-Host "0 - Exit"
    Write-Host "=============================="

    $choice = Read-Host "Select option"

    switch ($choice) {

        "1" { Show-Status }

        "2" { Add-Device }

        "0" {
            Write-Host "Exiting..." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 2000 # Пауза 0.5 секунды [1, 14]
            pause
        }

        default {
            Write-Host "Invalid option" -ForegroundColor Red
        }
    }
}