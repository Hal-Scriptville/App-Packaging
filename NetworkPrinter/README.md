# Intune Network Printer Deployment — Win32 App Template

Maps a shared network printer (UNC path) to all users on a device.
Deployed via Intune Win32 app in **SYSTEM context** (machine-wide).

---

## Package Contents

| File | Purpose |
|------|---------|
| `config.json` | Printer UNC path and display name (edit per deployment) |
| `Install-NetworkPrinter.ps1` | Install script — maps the printer |
| `Detect-NetworkPrinter.ps1` | Detection script — verifies printer is present |
| `Uninstall-NetworkPrinter.ps1` | Uninstall script — removes the printer |

---

## Setup

### 1. Edit `config.json`

```json
{
  "PrinterUNC": "\\\\printserver\\ShareName",
  "PrinterName": "Accounting Printer",
  "SetAsDefault": false
}
```

- **PrinterUNC** — Full UNC path to the shared printer
- **PrinterName** — Friendly display name users will see
- **SetAsDefault** — Unused in SYSTEM context (default printer is per-user)

### 2. Package with IntuneWinAppUtil

```
IntuneWinAppUtil.exe -c . -s Install-NetworkPrinter.ps1 -o .\output
```

All four files must be in the same folder — the scripts load `config.json` from `$PSScriptRoot`.

### 3. Configure in Intune

**Apps > Windows > Add > Windows app (Win32)**

| Setting | Value |
|---------|-------|
| Install command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install-NetworkPrinter.ps1` |
| Uninstall command | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Uninstall-NetworkPrinter.ps1` |
| Install behavior | **System** |
| Device restart behavior | No specific action |
| Detection rule type | **Custom script** → `Detect-NetworkPrinter.ps1`, Run as 32-bit: No |

---

## One Package Per Printer

Create a separate `.intunewin` for each printer, each with its own `config.json`.
Scope each app to the appropriate AAD device group.

---

## Prerequisites

- Device must have **line-of-sight to the print server** at install time
- Print server must have the driver available for auto-push (standard shared printer behavior)
- Device must be **hybrid-joined or on-prem** to reach `\\printserver\`

## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| Install exits 1: "not reachable" | Device can't ping print server — check VPN/network |
| Printer appears under wrong name | Share name differs from `PrinterName`; rename in script ran but Intune detection missed it |
| Detected but not visible to users | Printer mapped in user session, not SYSTEM — confirm Install behavior = System |
| Port removal warning on uninstall | Normal — WSD ports don't always have a matching `Get-PrinterPort` entry |
