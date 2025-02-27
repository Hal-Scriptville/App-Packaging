$regPath = "HKLM:\SOFTWARE\Company\UpdateCheck"
$regName = "InitialUpdateCompleted"

if (Test-Path $regPath) {
    $regValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if ($regValue) {
        Write-Output "Updates were successfully applied on $($regValue.InitialUpdateCompleted)"
        exit 0  # Detection success
    }
}

Write-Output "Update trigger has not been executed"
exit 1  # Detection failed, app will retry
