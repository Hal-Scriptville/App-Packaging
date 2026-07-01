<#
.SYNOPSIS
    Map a shared network printer (UNC) for all users on this device.

.DESCRIPTION
    Designed for Intune Win32 app deployment (SYSTEM context, machine-wide).
    Reads config.json from the same directory. The printer connection is stored
    in HKLM and appears for every user who signs in.

    Exit 0 = success (including already-installed)
    Exit 1 = failure

.NOTES
    Install command:
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install-NetworkPrinter.ps1

    Intune app settings:
        Install behavior: System
        Device restart behavior: No specific action
#>

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$ts] [$Level] $Message"
}

# ── Load config ──────────────────────────────────────────────────────────────

$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
    Write-Log "config.json not found at $configPath" "ERROR"
    exit 1
}

try {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Log "Failed to parse config.json: $_" "ERROR"
    exit 1
}

$PrinterUNC  = $config.PrinterUNC
$PrinterName = $config.PrinterName

if (-not $PrinterUNC -or -not $PrinterName) {
    Write-Log "config.json missing required fields (PrinterUNC, PrinterName)" "ERROR"
    exit 1
}

Write-Log "Target printer : $PrinterName"
Write-Log "UNC path       : $PrinterUNC"

# ── Check if already installed ────────────────────────────────────────────────

$existing = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Log "Printer '$PrinterName' already installed. Nothing to do."
    exit 0
}

# ── Test print server reachability ───────────────────────────────────────────

$server = ($PrinterUNC -replace '^\\\\', '').Split('\')[0]
Write-Log "Testing connectivity to print server: $server"

$ping = Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue
if (-not $ping) {
    Write-Log "Print server '$server' is not reachable. Aborting." "ERROR"
    exit 1
}

# ── Add the printer connection (machine-wide via SYSTEM) ──────────────────────

Write-Log "Adding printer connection..."

try {
    Add-Printer -ConnectionName $PrinterUNC
    Write-Log "Printer connection added."
} catch {
    Write-Log "Add-Printer failed: $_" "ERROR"
    exit 1
}

# ── Rename to friendly name if the share name differs ────────────────────────

Start-Sleep -Seconds 2

$shareName = $PrinterUNC.TrimStart('\').Split('\')[-1]
$added = Get-Printer -ErrorAction SilentlyContinue |
         Where-Object { $_.Name -eq $shareName -or $_.PortName -like "*$PrinterUNC*" } |
         Select-Object -First 1

if ($added -and $added.Name -ne $PrinterName) {
    try {
        Rename-Printer -InputObject $added -NewName $PrinterName
        Write-Log "Renamed from '$($added.Name)' to '$PrinterName'."
    } catch {
        Write-Log "Rename failed (non-fatal): $_" "WARN"
    }
}

# ── Verify ────────────────────────────────────────────────────────────────────

$verified = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
if (-not $verified) {
    Write-Log "Printer '$PrinterName' not found after install — possible rename mismatch." "WARN"
    Write-Log "Currently installed printers:"
    Get-Printer | ForEach-Object { Write-Log "  $($_.Name)" }
}

Write-Log "Install complete."
exit 0
