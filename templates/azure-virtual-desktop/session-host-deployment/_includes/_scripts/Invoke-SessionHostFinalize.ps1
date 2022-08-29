[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [string]$TenantId,
    [Parameter(Position = 1, Mandatory)]
    [string]$SubscriptionId,
    [Parameter(Position = 2, Mandatory)]
    [string]$VmResourceId,
    [Parameter(Position = 3, Mandatory)]
    [string]$HostPoolName,
    [Parameter(Position = 4)]
    [string]$AdDomainName
)

$writeInfoSplat = @{
    "InformationAction" = "Continue";
}

Connect-AzAccount -Identity -TenantId $TenantId -SubscriptionId $SubscriptionId

$vmObj = Get-AzResource -ResourceId $VmResourceId | Get-AzVM

$vmName = if ($null -eq $AdDomainName) {
    $vmObj.Name
}
else {
    "$($vmObj.Name).$($AdDomainName)"
}

$sessionHostFound = $false
while ($sessionHostFound -eq $false) {
    try {
        Get-AzWvdSessionHost -ResourceGroupName $vmObj.ResourceGroupName -HostPoolName $HostPoolName -Name $vmName -ErrorAction "Stop"
        $sessionHostFound = $true
    }
    catch {
        Write-Warning "Session host not registered yet."
        Start-Sleep -Seconds 30
    }
}

Write-Information @writeInfoSplat -MessageData "Setting session host to drain mode."
$null = Update-AzWvdSessionHost -ResourceGroupName $vmObj.ResourceGroupName -HostPoolName $HostPoolName -Name $vmName -AllowNewSession:$false

Write-Information @writeInfoSplat -MessageData "Waiting for session host to switch to drain mode."
Start-Sleep -Seconds 30
$sessionHostStatusIsAvailable = $false
$sessionHostStatusIsValid = $true
$sessionHostUnavailableCounter = 0
while ($sessionHostStatusIsAvailable -eq $false) {
    $sessionHostStatus = Get-AzWvdSessionHost -ResourceGroupName $vmObj.ResourceGroupName -HostPoolName $HostPoolName -Name $vmName

    switch ($sessionHostStatus.Status) {
        "Available" {
            Write-Information @writeInfoSplat -MessageData "Session host status is available."
            $sessionHostStatusIsAvailable = $true
            break
        }

        "Upgrading" {
            Write-Warning "Session host is still in the upgrading status."
            $sessionHostStatusIsAvailable = $false
            break
        }

        "Unavailable" {
            $sessionHostUnavailableCounter++

            if ($sessionHostUnavailableCounter -gt 10) {
                Write-Warning "Session host is still showing as unavailable."
                $sessionHostStatusIsAvailable = $true
                $sessionHostStatusIsValid = $false
            }
            else {
                Write-Warning "Session host is showing as unavailable. Wait counter is at $($sessionHostUnavailableCounter)."
            }
            break
        }

        Default {
            Write-Warning "Session host has a status that was not expected."
            $sessionHostStatusIsAvailable = $true
            $sessionHostStatusIsValid = $false
            break
        }
    }

    Start-Sleep -Seconds 15
}

if ($sessionHostStatusIsValid -eq $true) {
    Write-Information @writeInfoSplat -MessageData "Restarting VM."
    $null = $vmObj | Restart-AzVM -NoWait -Verbose:$false
}
else {
    Write-Warning "VM was not rebooted due to an invalid status returned by the session host."
}