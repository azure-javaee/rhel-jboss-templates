param guidValue string = take(replace(newGuid(), '-', ''), 6)

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.')
@secure()
param artifactsLocationSasToken string = ''

@description('Location')
param location string = resourceGroup().location

@description('Domain Prefix')
param domain string = 'domain'

@secure()
@description('Pull secret from cloud.redhat.com. The json should be input as a string')
param pullSecret string = ''

@description('Name of ARO vNet')
param clusterVnetName string = 'aro-vnet-${guidValue}'

@description('ARO vNet Address Space')
param clusterVnetCidr string = '10.100.0.0/15'

@description('Worker node subnet address space')
param workerSubnetCidr string = '10.100.70.0/23'

@description('Master node subnet address space')
param masterSubnetCidr string = '10.100.76.0/24'

@description('Master Node VM Type')
param vmSize string = ''

@description('Worker Node VM Type')
param workerVmSize string = ''

@description('Worker Node Disk Size in GB')
@minValue(128)
@maxValue(256)
param workerVmDiskSize int = 128

@description('Number of Worker Nodes')
param workerCount int = 3

@description('Cidr for Pods')
param podCidr string = '10.128.0.0/14'

@metadata({
  description: 'Cidr of service'
})
param serviceCidr string = '172.30.0.0/16'

@description('Flag indicating whether to create a new cluster or not')
param createCluster bool = true

@description('Unique name for the cluster')
param clusterName string = 'aro-cluster-${guidValue}'

@description('Name for the resource group of the existing cluster')
param clusterRGName string = ''

@description('Api Server Visibility')
@allowed([
  'Private'
  'Public'
])
param apiServerVisibility string = 'Public'

@description('Ingress Visibility')
@allowed([
  'Private'
  'Public'
])
param ingressVisibility string = 'Public'

@description('The application ID of an Microsoft Entra ID client application')
param aadClientId string = ''

@description('The secret of an Microsoft Entra ID client application')
@secure()
param aadClientSecret string = ''

@description('The service principal Object ID of an Microsoft Entra ID client application')
param aadObjectId string = ''

@description('The service principal Object ID of the Azure Red Hat OpenShift Resource Provider')
param rpObjectId string = ''

@description('Flag indicating whether to deploy a S2I application or not')
param deployApplication bool = false

@description('URL to the repository containing the application source code.')
param srcRepoUrl string = ''

@description('The Git repository reference to use for the source code. This can be a Git branch or tag reference.')
param srcRepoRef string = ''

@description('The directory within the source repository to build.')
param srcRepoDir string = ''

@description('Red Hat Container Registry Service account username')
param conRegAccUserName string = ''

@secure()
@description('Red Hat Container Registry Service account password')
param conRegAccPwd string = ''

@description('The name of the project')
param projectName string = 'eap-demo-${guidValue}'

@description('The name of the application')
param applicationName string = 'eap-app-${guidValue}'

@description('The number of application replicas to deploy')
param appReplicas int = 2

@description('${label.tagsLabel}')
param tagsByResource object = {}

var const_clusterRGName = createCluster ? resourceGroup().name: clusterRGName
var const_clusterName = createCluster ? 'aro-cluster-${guidValue}' : clusterName
var const_identityName = 'uami-${guidValue}'
var const_contribRole = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var name_roleAssignmentName = 'roleassignment-${guidValue}'
var name_jbossEAPDsName = 'jbosseap-setup-${guidValue}'
var const_cmdToGetKubeadminCredentials = 'az aro list-credentials -g ${const_clusterRGName} -n ${const_clusterName}'
var const_cmdToGetKubeadminUsername = '${const_cmdToGetKubeadminCredentials} --query kubeadminUsername -o tsv'
var const_cmdToGetKubeadminPassword = '${const_cmdToGetKubeadminCredentials} --query kubeadminPassword -o tsv'
var const_cmdToGetApiServer = 'az aro show -g ${const_clusterRGName} -n ${const_clusterName} --query apiserverProfile.url -o tsv'

var _objTagsByResource = {
  '${identifier.openShiftClusters}': contains(tagsByResource, '${identifier.openShiftClusters}') ? tagsByResource['${identifier.openShiftClusters}'] : json('{}')
  '${identifier.roleAssignments}': contains(tagsByResource, '${identifier.roleAssignments}') ? tagsByResource['${identifier.roleAssignments}'] : json('{}')
  '${identifier.virtualNetworks}': contains(tagsByResource, '${identifier.virtualNetworks}') ? tagsByResource['${identifier.virtualNetworks}'] : json('{}')
  '${identifier.userAssignedIdentities}': contains(tagsByResource, '${identifier.userAssignedIdentities}') ? tagsByResource['${identifier.userAssignedIdentities}'] : json('{}')
  '${identifier.deploymentScripts}': contains(tagsByResource, '${identifier.deploymentScripts}') ? tagsByResource['${identifier.deploymentScripts}'] : json('{}')
}

/*
* Beginning of the offer deployment
*/
module pids './modules/_pids/_pid.bicep' = {
  name: 'initialization-${guidValue}'
}

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-0cc5f6a1-9633-40d9-bc00-f010ad5b365a-partnercenter'
  params: {}
}

resource uami_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@${azure.apiVersionForIdentity}' = {
  name: const_identityName
  location: location
  tags: _objTagsByResource['${identifier.userAssignedIdentities}']
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@${azure.apiVersionForIdentity}' existing = {
  name: const_identityName
}


// Assign Contributor role in subscription scope since we need the permission to get/update resource cross resource group.
module deploymentScriptUAMICotibutorRoleAssignment 'modules/_rolesAssignment/_roleAssignmentinSubscription.bicep' = {
  name: name_roleAssignmentName
  scope: subscription()
  dependsOn:[
    uami_resource
    roleResourceDefinition
  ]
  params: {
    roleDefinitionId: const_contribRole
    principalId: uami.properties.principalId
    tagsByResource: _objTagsByResource
  }
}

resource clusterVnetName_resource 'Microsoft.Network/virtualNetworks@${azure.apiVersionForVirtualNetworks}' = if(createCluster) {
  name: clusterVnetName
  location: location
  tags: _objTagsByResource['${identifier.virtualNetworks}']
  properties: {
    addressSpace: {
      addressPrefixes: [
        clusterVnetCidr
      ]
    }
    subnets: [
      {
        name: 'master'
        properties: {
          addressPrefix: masterSubnetCidr
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'worker'
        properties: {
          addressPrefix: workerSubnetCidr
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
        }
      }
    ]
  }
}

resource vnetRef 'Microsoft.Network/virtualNetworks@${azure.apiVersionForVirtualNetworks}' existing = {
  name: clusterVnetName
}

// Get role resource id in subscription
resource roleResourceDefinition 'Microsoft.Authorization/roleDefinitions@${azure.apiVersionForRoleDefinitions}' existing = {
  name: const_contribRole
}

resource assignRoleAppSp 'Microsoft.Authorization/roleAssignments@${azure.apiVersionForRoleAssignment}' = if(createCluster) {
  name: guid(resourceGroup().id, deployment().name, vnetRef.id, 'assignRoleAppSp')
  tags: _objTagsByResource['${identifier.roleAssignments}']
  scope: vnetRef
  properties: {
    principalId: aadObjectId
    roleDefinitionId: roleResourceDefinition.id
  }
  dependsOn: [
    vnetRef
    roleResourceDefinition
    clusterVnetName_resource
    jbossPreflightDeployment
  ]
}

resource assignRoleRpSp 'Microsoft.Authorization/roleAssignments@${azure.apiVersionForRoleAssignment}' = if(createCluster) {
  name: guid(resourceGroup().id, deployment().name, vnetRef.id, 'assignRoleRpSp')
  tags: _objTagsByResource['${identifier.roleAssignments}']
  scope: vnetRef
  properties: {
    principalId: rpObjectId
    roleDefinitionId: roleResourceDefinition.id
  }
  dependsOn: [
    vnetRef
    roleResourceDefinition
    clusterVnetName_resource
  ]
}

resource clusterName_resource 'Microsoft.RedHatOpenShift/openShiftClusters@${azure.apiVersionForOpenShiftClusters}' = if(createCluster) {
  name: const_clusterName
  location: location
  tags: _objTagsByResource['${identifier.openShiftClusters}']
  properties: {
    clusterProfile: {
      domain: '${domain}-${guidValue}'
      resourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', 'MC_${resourceGroup().name}_${const_clusterName}_${location}')
      pullSecret: pullSecret
      fipsValidatedModules: 'Disabled'
    }
    networkProfile: {
      podCidr: podCidr
      serviceCidr: serviceCidr
    }
    servicePrincipalProfile: {
      clientId: aadClientId
      clientSecret: aadClientSecret
    }
    masterProfile: {
      vmSize: vmSize
      subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', clusterVnetName, 'master')
      encryptionAtHost: 'Disabled'
    }
    workerProfiles: [
      {
        name: 'worker'
        vmSize: workerVmSize
        diskSizeGB: workerVmDiskSize
        subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', clusterVnetName, 'worker')
        count: workerCount
        encryptionAtHost:'Disabled'
      }
    ]
    apiserverProfile: {
      visibility: apiServerVisibility
    }
    ingressProfiles: [
      {
        name: 'default'
        visibility: ingressVisibility
      }
    ]
  }
  dependsOn: [
    assignRoleAppSp
    assignRoleRpSp
    jbossPreflightDeployment
  ]
}

module deployApplicationStartPid './modules/_pids/_pid.bicep' = if (deployApplication) {
  name: 'deployApplicationStartPid-${guidValue}'
  params: {
    name: pids.outputs.appDeployStart
  }
  dependsOn: [
    pids
    clusterName_resource
  ]
}

module jbossPreflightDeployment 'modules/_deployment-scripts/_ds-preflight.bicep' = {
  name: 'jboss-preflight-deployment-${guidValue}'
  params: {
    artifactsLocation: artifactsLocation
    artifactsLocationSasToken: artifactsLocationSasToken
    location: location
    guidValue: guidValue
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', const_identityName)}': {}
      }
    }
    createCluster: createCluster
    aadClientId: aadClientId
    aadObjectId: aadObjectId
    tagsByResource: _objTagsByResource
  }
  dependsOn: [
      deploymentScriptUAMICotibutorRoleAssignment
    ]
}

module jbossEAPDeployment 'modules/_deployment-scripts/_ds-jbossSetup.bicep' = {
  name: name_jbossEAPDsName
  params: {
    artifactsLocation: artifactsLocation
    artifactsLocationSasToken: artifactsLocationSasToken
    location: location
    clusterName: const_clusterName
    clusterRGName: const_clusterRGName 
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', const_identityName)}': {}
      }
    }
    deployApplication: deployApplication
    createCluster: createCluster
    srcRepoUrl: srcRepoUrl
    srcRepoRef: srcRepoRef
    srcRepoDir: srcRepoDir
    conRegAccUserName: conRegAccUserName
    conRegAccPwd: conRegAccPwd
    appReplicas: appReplicas
    projectName: projectName
    applicationName: applicationName
    tagsByResource: _objTagsByResource
    pullSecret: pullSecret
  }
  dependsOn: [
    clusterName_resource
  ]
}

module deployApplicationEndPid './modules/_pids/_pid.bicep' = if (deployApplication) {
  name: 'deployApplicationEndPid-${guidValue}'
  params: {
    name: pids.outputs.appDeployEnd
  }
  dependsOn: [
    pids
    jbossEAPDeployment
  ]
}

output cmdToGetKubeadminCredentials string = const_cmdToGetKubeadminCredentials
output cmdToLoginWithKubeadmin string = 'oc login $(${const_cmdToGetApiServer}) -u $(${const_cmdToGetKubeadminUsername}) -p $(${const_cmdToGetKubeadminPassword})'
output consoleUrl string = jbossEAPDeployment.outputs.consoleUrl
output appEndpoint string = deployApplication ? jbossEAPDeployment.outputs.appEndpoint : ''
