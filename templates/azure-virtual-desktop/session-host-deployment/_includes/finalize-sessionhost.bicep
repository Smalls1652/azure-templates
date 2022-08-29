param vmName string
param hostPoolName string
param deploymentScriptPrincipal object
param domainName string
param svcLocation string = resourceGroup().location
param randomHashString string = newGuid()

resource vmItem 'Microsoft.Compute/virtualMachines@2021-07-01' existing = {
  scope: resourceGroup()
  name: vmName
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2021-07-12' existing = {
  scope: resourceGroup()
  name: hostPoolName
}

resource finalizeSessionHost 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzurePowerShell'
  location: svcLocation
  name: 'FinalizeSessionHost-${vmName}-${take(randomHashString, 4)}'

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptPrincipal.id}': {}
    }
  }

  properties: {
    azPowerShellVersion: '7.5'

    scriptContent: loadTextContent('./_scripts/Invoke-SessionHostFinalize.ps1')
    arguments: '-TenantId \\"${subscription().tenantId}\\" -SubscriptionId \\"${subscription().id}\\" -VmResourceId \\"${vmItem.id}\\" -HostPoolName \\"${hostPool.name}\\" -AdDomainName \\"${domainName}\\"'

    timeout: 'PT2H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
}
