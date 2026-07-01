<#
.SYNOPSIS
    Remove a mapped network printer from this device.

.DESCRIPTION
    Designed for Intune Win32 app deployment (SYSTEM context).
    Reads config.json from the same directory.

    Exit 0 = success (including already-removed)
    Exit 1 = failure

.NOTES
    Uninstall command:
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File Uninstall-NetworkPrinter.ps1
#>

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$ts] [$Level] $Message"
}

$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
    Write-Log "config.json not found" "ERROR"
    exit 1
}

try {
    $config      = Get-Content $configPath -Raw | ConvertFrom-Json
    $PrinterUNC  = $config.PrinterUNC
    $PrinterName = $config.PrinterName
} catch {
    Write-Log "Failed to parse config.json: $_" "ERROR"
    exit 1
}

Write-Log "Removing printer: $PrinterName"

# Remove by friendly name
$printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
if ($printer) {
    try {
        Remove-Printer -Name $PrinterName
        Write-Log "Removed '$PrinterName'."
    } catch {
        Write-Log "Remove-Printer failed: $_" "ERROR"
        exit 1
    }
} else {
    # Try removing by share name (rename may not have applied)
    $shareName = $PrinterUNC.TrimStart('\').Split('\')[-1]
    $byShare   = Get-Printer -Name $shareName -ErrorAction SilentlyContinue
    if ($byShare) {
        try {
            Remove-Printer -Name $shareName
            Write-Log "Removed '$shareName' (share name)."
        } catch {
            Write-Log "Remove-Printer (share name) failed: $_" "ERROR"
            exit 1
        }
    } else {
        Write-Log "Printer '$PrinterName' not found — nothing to remove."
    }
}

# Remove the port if it's a dead WSD/IP port left behind (best-effort)
$portName = $PrinterUNC
$port = Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue
if ($port) {
    try {
        Remove-PrinterPort -Name $portName
        Write-Log "Removed port '$portName'."
    } catch {
        Write-Log "Port removal failed (non-fatal): $_" "WARN"
    }
}

Write-Log "Uninstall complete."
exit 0
