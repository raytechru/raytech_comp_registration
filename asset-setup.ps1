# === ADMIN CHECK ===
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltinRole]::Administrator)) {

    Write-Host "Run as administrator!" -ForegroundColor Red
    exit
}

# TLS fix
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$regPath = "HKLM:\SOFTWARE\Company\Asset"
$url = "https://script.google.com/macros/s/AKfycbxTi07kyNcvCLWN9TrjCVO-a0xcwC3NRhRy2RuSL0pxTOAh2o-ChuUdQvv0EZCincieQg/exec"

Write-Host "=== PC Setup ===" -ForegroundColor Cyan

# === TYPE + CITY ===
$type = (Read-Host "Enter type (NB/PC)").ToUpper()
$city = (Read-Host "Enter city code (EKB/MSK/VRN)").ToUpper()

# === GET NUMBER FROM GOOGLE ===
$nextNumber = $null

try {
    $requestUrl = "$($url)?city=$city&type=$type"
    Write-Host "Request: Corp database"

    $response = Invoke-RestMethod -Uri $requestUrl -Method Get -ErrorAction Stop

    if ($response.next) {
        $nextNumber = [int]$response.next
    } else {
        throw "Invalid response"
    }

    Write-Host "Next number from Google: $nextNumber" -ForegroundColor Green
}
catch {
    Write-Host "Google unavailable - manual number required" -ForegroundColor Yellow

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
$owner = Read-Host "Enter owner (lastname)"

# === MODEL ===
$autoModel = (Get-CimInstance Win32_ComputerSystemProduct).Name
Write-Host "Detected model: $autoModel"
$confirmModel = Read-Host "Correct? (Y/N)"

if ($confirmModel -eq "Y") {
    $model = $autoModel
} else {
    $model = Read-Host "Enter model manually"
}

# === SERIAL ===
$autoSerial = (Get-CimInstance Win32_BIOS).SerialNumber
Write-Host "Detected serial: $autoSerial"
$confirmSerial = Read-Host "Correct? (Y/N)"

if ($confirmSerial -eq "Y") {
    $serial = $autoSerial
} else {
    $serial = Read-Host "Enter serial manually"
}

# === DESCRIPTION (НОВАЯ ПЕРЕМЕННАЯ) ===
$desc = "$model | $owner"

# === PREVIEW ===
Write-Host ""
Write-Host "=== CHECK ===" -ForegroundColor Cyan
Write-Host "AssetID : $asset"
Write-Host "Hostname: $hostname"
Write-Host "Owner   : $owner"
Write-Host "Model   : $model"
Write-Host "Serial  : $serial"
Write-Host "City    : $city"
Write-Host "Desc    : $desc"

$confirm = Read-Host "Save? (Y/N)"

if ($confirm -ne "Y") {
    Write-Host "Cancelled"
    exit
}

# === SAVE TO REGISTRY ===
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "AssetID" -Value $asset
Set-ItemProperty -Path $regPath -Name "Owner" -Value $owner
Set-ItemProperty -Path $regPath -Name "Model" -Value $model
Set-ItemProperty -Path $regPath -Name "Serial" -Value $serial

# === SAVE DESCRIPTION (ПРАВИЛЬНОЕ МЕСТО) ===
Set-ItemProperty `
  -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
  -Name "srvcomment" `
  -Value $desc

# === RENAME PC ===
if ($hostname -ne $env:COMPUTERNAME) {
    try {
        Rename-Computer -NewName $hostname -Force -ErrorAction Stop
        Write-Host "Hostname changed (reboot required)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Rename failed: $_" -ForegroundColor Red
    }
}

# === SAVE LOCAL (ALWAYS) ===
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$safeName = "$asset - $owner" -replace '[\\/:*?""<>|]', '_'
$filePath = Join-Path $scriptPath "$safeName.csv"

$data = [PSCustomObject]@{
    Date     = (Get-Date)
    AssetID  = $asset
    Owner    = $owner
    Model    = $model
    Serial   = $serial
    City     = $city
    Hostname = $hostname
}

$data | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
Write-Host "Saved locally: $filePath" -ForegroundColor Green

# === SEND TO GOOGLE ===
$body = @{
    asset    = $asset
    owner    = $owner
    model    = $model
    serial   = $serial
    city     = $city
    hostname = $hostname
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json"
    Write-Host "Saved to Google Sheets" -ForegroundColor Green
}
catch {
    Write-Host "Google copy NOT saved (no connection)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done"
Write-Host "Reboot required if hostname changed" -ForegroundColor Yellow