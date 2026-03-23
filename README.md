# Raytech Computer Registration Tool

## Version
v4.0-auth-stable

---

## Overview

Internal IT tool for automated computer registration, asset management, and naming standardization.

This version introduces secure access via password authentication (SHA-256 hash).

---

## Features

### Security
- Password protection using SHA-256 hash
- Verification via Google Apps Script API
- No password stored locally
- Script execution blocked on failed authentication

---

### Device Registration
- Generates Asset ID:
  TYPE-CITY-XXX (e.g. NB-MSK-001)
- Automatically sets hostname
- Writes to registry:
  HKLM:\SOFTWARE\Company\Asset
- Sets system description (srvcomment)

---

### Cloud Integration
- Google Sheets as primary database
- Automatic next-number generation
- REST API communication (GET / POST)

---

### Local Backup
- CSV file per device
- Stored in:
  Documents\comp_registration\
- Folder auto-created if missing

---

### Menu

1 - Computer status  
2 - Add new device  
0 - Exit  

---

### Status Check

Displays:
- AssetID
- Owner
- Model
- Serial
- Hostname

---

### Validation
- Type: NB / PC / NT
- City: exactly 3 letters
- Required fields enforced
- Input sanitization (Trim)

---

### Fallback Logic
- If Google unavailable → manual number input
- CSV always saved

---

## Architecture

### Client
- PowerShell script (`asset-setup.ps1`)

### Backend
- Google Apps Script (`doGet`, `doPost`)

### Storage
- Google Sheets (primary)
- CSV (local backup)

---

## Launch

### Online
```powershell
irm "https://asset.raytech.ru" | iex