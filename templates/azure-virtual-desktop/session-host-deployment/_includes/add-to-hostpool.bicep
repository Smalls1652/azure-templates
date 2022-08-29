param vmName string
param hostPoolName string
param deploymentScriptPrincipal object
param location string = resourceGroup().location

resource vmItem 'Microsoft.Compute/virtualMachines@2021-07-01' existing = {
  scope: resourceGroup()
  name: vmName
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2021-07-12' existing = {
  scope: resourceGroup()
  name: hostPoolName
}

resource hostPoolRegInfo 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzurePowerShell'
  location: location
  name: 'Get-HostPoolRegInfo-${uniqueString(resourceGroup().id)}'

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptPrincipal.id}': {}
    }
  }

  properties: {
    azPowerShellVersion: '7.5'
    
    scriptContent: loadTextContent('./_scripts/Get-HostPoolRegInfo.ps1')
    arguments: '-TenantId \\"${subscription().tenantId}\\" -SubscriptionId \\"${subscription().id}\\" -ResourceGroupName \\"${resourceGroup().name}\\" -HostPoolName \\"${hostPool.name}\\"'

    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT6H'
  }
}

resource addVmToHostpool 'Microsoft.Compute/virtualMachines/runCommands@2021-07-01' = {
  parent: vmItem
  location: location
  name: 'AddVmToHostpool'
  properties: {

    source: {
      script: loadTextContent('./_scripts/Invoke-AvdAgentInstall.ps1')
    }

    timeoutInSeconds: 1800
    asyncExecution: true

    parameters: [
      {
        name: 'RegistrationToken'
        value: hostPoolRegInfo.properties.outputs.regToken
      }
    ]
  }

  tags: {
    VirtualMachine: vmName
  }
}
