@minLength(1)
@description('The datacenter location the resources will reside.')
param vmLocation string = resourceGroup().location

@minLength(1)
@description('A string to use as a hash for generating a unique string.')
param randomHashString string = newGuid()

// --- Define variables ---
// Modify the variables below to match your needs.

// The deployment script principal name and resource group (Scope) it's located in.
var deploymentScriptPrincipalItem = {
  name: 'avd-deployment-script-principal'
  scope: resourceGroup('avd-shared-resources')
}

// The log analytics workspace for monitoring the session host.
var logAnalyticsWorkspaceItem = {
  name: 'avd-monitoring-workspace'
  scope: resourceGroup('avd-shared-resources')
}

// The prefix for the VM name.
var vmNamePrefix = 'avd-ex'

// The size of the VM and the VM's OS disk size (In GB).
var vmSize = 'Standard_D8s_v4'
var vmDiskSize = 128

// Set whether the VM should use "Trusted Launch", if the VM size and/or image supports it.
var vmEnableTrustedLaunch = true

// Set whether to install the GPU driver or not.
var vmInstallGpuDriver = false

// The resource group where the vNet is located, what the vNet is named, and the subnet name to use.
var vnetResourceGroupName = 'avd-example-vnets'
var vnetName = 'avd-example-vnet'
var vnetSubnetName = 'avd-example-hostpool-subnet'

// The Azure KeyVault name and resource group (Scope) it's located in.
var keyvaultItem = {
  name: 'avd-keyvault'
  scope: resourceGroup('avd-shared-resources')
}

// The name of the Image Gallery to use and resource group (Scope) it's located in.
var imageGalleryItem = {
  name: 'avd_img_gallery'
  scope: resourceGroup('avd-shared-resources')
}

// The name of the image and the version to use.
var imageName = 'avd-win10-generic-multisession'
var imageVersion = '2022.08.00'

// The name the local admin account should be and
// what the name of the item in the KeyVault is that has it's password.
var vmLocalAdminUsername = 'VmLocalAdmin'
var vmLocalAdminPasswordKeyVaultItemName = 'vm-admin-acct'

// Information for joining the VM to your on-premises AD domain.
var domainName = 'contoso.com'
var domainJoinUserName = 'domainjoin-acct'
var domainJoinPasswordKeyVaultItemName = 'domain-join-account'
var domainJoinOUPath = 'OU=Desktop Hosts,OU=Example Hostpool,OU=Azure Virtual Desktop,DC=contoso,DC=com'

// The name of the hostpool the session host will be apart of.
var hostPoolName = 'Example Hostpool - Desktop'

// Determine how long the random string should be for the
// VM name. This is to help with the NETBIOS name.
var randomStrLength = int(14 - length(vmNamePrefix))

// Generate the name for the VM.
var vmName = '${vmNamePrefix}-${take(uniqueString(subscription().id, resourceGroup().id, randomHashString), randomStrLength)}'

// Get the Key Vault resource for reading the default admin credentials.
// Note: This is useful for fully automating the deployment of a session host securely.
//       Replace the name of the KeyVault, resource group, and, if needed, subscription to
//       what you have.
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyvaultItem.name
  scope: keyvaultItem.scope
}

resource deploymentScriptPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' existing = {
  scope: deploymentScriptPrincipalItem.scope
  name: deploymentScriptPrincipalItem.name
}

module sessionHostVM './_includes/deploy-vm.bicep' = {
  name: 'deployAVDHost_${vmName}'
  params: {
    vmName: vmName
    vmLocation: vmLocation
    vmSize: vmSize

    imageGalleryItem: imageGalleryItem
    imageName: imageName
    imageVersion: imageVersion

    vmInstallGPUDriver: vmInstallGpuDriver
    vmTrustedLaunch: vmEnableTrustedLaunch

    vmDiskSizeGB: vmDiskSize

    vmAdminUserName: vmLocalAdminUsername
    vmAdminPwd: keyVault.getSecret(vmLocalAdminPasswordKeyVaultItemName)

    vnetName: vnetName
    vnetRscGroup: vnetResourceGroupName
    vnetSubnetName: vnetSubnetName

    vmDomainName: domainName
    vmJoinerUserName: domainJoinUserName
    vmJoinerPwd: keyVault.getSecret(domainJoinPasswordKeyVaultItemName)
    vmDomainOUPath: domainJoinOUPath
  }
}

module addMonitoring './_includes/add-avd-monitoring.bicep' = {
  name: 'deployAVDHost_${vmName}_addMonitoring'
  params: {
    logAnalyticsWorkspaceItem: logAnalyticsWorkspaceItem
    vmName: vmName
    location: vmLocation
  }
  
  dependsOn: [
    sessionHostVM
  ]
}

module initFinalizeSessionHost './_includes/finalize-sessionhost.bicep' = {
  name: 'deployAVD_${vmName}_finalizeSessionHost'
  params: {
    vmName: vmName
    hostPoolName: hostPoolName
    deploymentScriptPrincipal: deploymentScriptPrincipal
    domainName: domainName
    svcLocation: vmLocation
  }

  dependsOn: [
    sessionHostVM
    addMonitoring
  ]
}

module addToHostPool './_includes/add-to-hostpool.bicep' = {
  name: 'deployAVD_${vmName}_addToHostPool'
  params: {
    vmName: vmName
    location: vmLocation
    deploymentScriptPrincipal: deploymentScriptPrincipal
    hostPoolName: hostPoolName
  }

  dependsOn: [
    sessionHostVM
    addMonitoring
  ]
}

output vmResourceId string = sessionHostVM.outputs.vm.resourceId
output vmOsDiskResourceId string = sessionHostVM.outputs.vmOsDisk.resourceId
output vmNicResourceId string  = sessionHostVM.outputs.nic.resourceId
