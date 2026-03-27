# Enable Windows Update service
Start-Service wuauserv

# Install PSWindowsUpdate module if not available
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
}

# Import the module
Import-Module PSWindowsUpdate

# Run Windows Update
Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot -Verbose | Out-File C:\ProgramData\WinUpdateLog.txt

# Mark completion in the registry
$regPath = "HKLM:\SOFTWARE\Company\UpdateCheck"
$regName = "InitialUpdateCompleted"
$regValue = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

If (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force | Out-Null
