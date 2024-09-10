@description('User name for the Virtual Machine')
param adminUsername string = 'jbossuser'

@description('Type of authentication to use on the Virtual Machine')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Password or SSH key for the Virtual Machine')
@minLength(12)
@secure()
param adminPasswordOrSSHKey string

@description('Location for all resources')
param location string = resourceGroup().location

@description('User name for the JBoss EAP Manager')
param jbossEAPUserName string

@description('Password for the JBoss EAP Manager')
@minLength(12)
@secure()
param jbossEAPPassword string

@description('User name for Red Hat subscription Manager')
param rhsmUserName string = newGuid()

@description('Password for Red Hat subscription Manager')
@secure()
param rhsmPassword string = newGuid()

@description('Red Hat Subscription Manager Pool ID (Should have EAP entitlement)')
param rhsmPoolEAP string = newGuid()

@description('Red Hat Subscription Manager Pool ID (Should have RHEL entitlement). Mandartory if you select the BYOS RHEL OS License Type')
param rhsmPoolRHEL string = newGuid()

@allowed([
  'on'
  'off'
])
param bootDiagnostics string = 'off'

@description('Specify whether to create a new or use an existing Storage Account.')
@allowed([
  'New'
  'Existing'
])
param bootStorageNewOrExisting string = 'New'

@description('Name of the existing Storage Account Name')
param existingStorageAccount string = ''

@description('Name of the Storage Account.')
param bootStorageAccountName string = 'jbboot${uniqueString(resourceGroup().id)}'

@description('Storage account kind')
param storageAccountKind string = 'Storage'

@description('Name of the resource group for the existing storage account')
param storageAccountResourceGroupName string = resourceGroup().name

@description('Select the Replication Strategy for the Storage account')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param bootStorageReplication string = 'Standard_LRS'

@description('Specify whether to create a new or existing virtual network for the VM.')
@allowed([
  'new'
  'existing'
])
param virtualNetworkNewOrExisting string = 'new'

@description('Name of the existing or new VNET')
param virtualNetworkName string = 'jbosseap-vnet'

@description('Resource group of VIrtual network')
param virtualNetworkResourceGroupName string = resourceGroup().name

@description('Address prefix of the VNET.')
param addressPrefixes array = [
  '10.0.0.0/16'
]

@description('Name of the existing or new Subnet')
param subnetName string = 'jbosseap-server-subnet'

@description('Address prefix of the subnet')
param subnetPrefix string = '10.0.0.0/24'

@description('String used as a base for naming resources (9 characters or less). A hash is prepended to this string for some resources, and resource-specific information is appended')
@maxLength(9)
param vmssName string = 'jbossvmss'

@description('Number of VM instances (100 or less)')
@minValue(2)
@maxValue(100)
param instanceCount int = 2

@description('The size of the Virtual Machine scale set')
param vmSize string = 'Standard_DS2_v2'

@description('The JDK version of the Virtual Machine')
param jdkVersion string = 'openjdk17'

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated')
@secure()
param artifactsLocationSasToken string = ''

@description('Connect to an existing Red Hat Satellite Server.')
param connectSatellite bool = false

@description('Red Hat Satellite Server activation key.')
param satelliteActivationKey string = newGuid()

@description('Red Hat Satellite Server organization name.')
param satelliteOrgName string = newGuid()

@description('Red Hat Satellite Server VM FQDN name.')
param satelliteFqdn string = newGuid()

param guidValue string = take(replace(newGuid(), '-', ''), 6)

@description('true to set up Application Gateway ingress.')
param enableAppGWIngress bool = false

@description('Name of the existing or new Subnet')
param subnetForAppGateway string = 'jboss-appgateway-subnet'

@description('Address prefix of the subnet')
param subnetPrefixForAppGateway string = '10.0.1.0/24'

@description('Price tier for Key Vault.')
param keyVaultSku string = 'Standard'

@description('UTC value for generating unique names.')
param utcValue string = utcNow()

@description('DNS prefix for ApplicationGateway')
param dnsNameforApplicationGateway string = 'jbossgw'

@description('The name of the secret in the specified KeyVault whose value is the SSL Certificate Data for Appliation Gateway frontend TLS/SSL.')
param keyVaultSSLCertDataSecretName string = 'kv-ssl-data'

@description('true to enable cookie based affinity.')
param enableCookieBasedAffinity bool = false

@description('Boolean value indicating, if user wants to enable database connection.')
param enableDB bool = false
@allowed([
  'mssqlserver'
  'postgresql'
  'oracle'
  'mysql'
])
@description('One of the supported database types')
param databaseType string = 'postgresql'
@description('JNDI Name for JDBC Datasource')
param jdbcDataSourceJNDIName string = 'jdbc/contoso'
@description('JDBC Connection String')
param dsConnectionURL string = 'jdbc:postgresql://contoso.postgres.database:5432/testdb'
@description('User id of Database')
param dbUser string = 'contosoDbUser'
@secure()
@description('Password for Database')
param dbPassword string = newGuid()

var containerName = 'eapblobcontainer'
var var_eapStorageAccountName = 'jbosstrg${uniqueString(resourceGroup().id)}'
var eapstorageReplication = 'Standard_LRS'
var var_vmssInstanceName = 'jbosseap-server${vmssName}'
var nicName = 'jbosseap-server-nic'
var bootDiagnosticsCheck = ((bootStorageNewOrExisting == 'New') && (bootDiagnostics == 'on'))
var var_bootStorageName = ((bootStorageNewOrExisting == 'Existing') ? existingStorageAccount : bootStorageAccountName)
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrSSHKey
      }
    ]
  }
}
var imageReference = {
  publisher: 'redhat'
  offer: 'rhel-byos'
  sku: 'rhel-lvm86-gen2'
  version: 'latest'
}
var plan = {
  name: 'rhel-lvm86-gen2'
  publisher: 'redhat'
  product: 'rhel-byos'
}
// A workaround for publishing private plan in Partner center, see issue: https://github.com/Azure/rhel-jboss-templates/issues/108
// This change is coupled with .github/workflows/validate-byos-vmss.yaml#77
var scriptFolder = 'scripts'
var fileToBeDownloaded = 'eap-session-replication.war'
var scriptArgs = '-a \'${uri(artifactsLocation, '.')}\' -t "${artifactsLocationSasToken}" -p ${scriptFolder} -f ${fileToBeDownloaded}'
var obj_uamiForDeploymentScript = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${uamiDeployment.outputs.uamiIdForDeploymentScript}': {}
  }
}
var name_keyVaultName = take('jboss-kv${guidValue}', 24)
var name_dnsNameforApplicationGateway = '${dnsNameforApplicationGateway}${take(uniqueString(utcValue), 6)}'
var name_rgNameWithoutSpecialCharacter = replace(replace(replace(replace(resourceGroup().name, '.', ''), '(', ''), ')', ''), '_', '') // remove . () _ from resource group name
var name_domainLabelforApplicationGateway = take('${name_dnsNameforApplicationGateway}-${toLower(name_rgNameWithoutSpecialCharacter)}', 63)
var const_azureSubjectName = format('{0}.{1}.{2}', name_domainLabelforApplicationGateway, location, 'cloudapp.azure.com')
var name_appgwFrontendSSLCertName = 'appGatewaySslCert'
var name_appGateway = 'appgw${uniqueString(utcValue)}'
var property_subnet_with_app_gateway = [
  {
    name: subnetName
    properties: {
      addressPrefix: subnetPrefix
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
  {
    // Assume it is acceptable to create a subnet for the App Gateway, even if the user
    // has not requested an App Gateway.  In support of this assumption we can note: the user may want an App 
    // Gateway after deployment.
    name: subnetForAppGateway
    properties: {
      addressPrefix: subnetPrefixForAppGateway
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
]
var property_subnet_without_app_gateway = [
  {
    name: subnetName
    properties: {
      addressPrefix: subnetPrefix
    }
  }
]
var name_publicIPAddress = '-pubIp'
var name_networkSecurityGroup = 'jboss-nsg'
var name_appGatewayPublicIPAddress = 'gwip'
var const_azcliVersion = '2.53.0'

module pids './modules/_pids/_pid.bicep' = {
  name: 'initialization'
}

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-b57c8aee-4919-4cbb-8399-f966d39d4064-partnercenter'
  params: {}
}

module byosVmssStartPid './modules/_pids/_pid.bicep' = {
  name: 'byosVmssStartPid'
  params: {
    name: pids.outputs.byosVmssStart
  }
  dependsOn: [
    pids
  ]
}

module uamiDeployment 'modules/_uami/_uamiAndRoles.bicep' = {
  name: 'uami-deployment'
  params: {
    location: location
  }
}

module appgwSecretDeployment 'modules/_azure-resources/_keyvaultForGateway.bicep' = if (enableAppGWIngress) {
  name: 'appgateway-certificates-secrets-deployment'
  params: {
    identity: obj_uamiForDeploymentScript
    location: location
    sku: keyVaultSku
    subjectName: format('CN={0}', const_azureSubjectName)
    keyVaultName: name_keyVaultName
  }
}

// Get existing VNET.
resource existingVnet 'Microsoft.Network/virtualNetworks@${azure.apiVersionForVirtualNetworks}' existing = if (virtualNetworkNewOrExisting != 'new') {
  name: virtualNetworkName
  scope: resourceGroup(virtualNetworkResourceGroupName)
}

// Get existing subnet.
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@${azure.apiVersionForVirtualNetworks}' existing = if (virtualNetworkNewOrExisting != 'new') {
  name: subnetForAppGateway
  parent: existingVnet
}

module appgwDeployment 'modules/_appgateway.bicep' = if (enableAppGWIngress) {
  name: 'app-gateway-deployment'
  params: {
    appGatewayName: name_appGateway
    dnsNameforApplicationGateway: name_dnsNameforApplicationGateway
    gatewayPublicIPAddressName: name_appGatewayPublicIPAddress
    gatewaySubnetId: virtualNetworkNewOrExisting == 'new' ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetForAppGateway) : existingSubnet.id
    gatewaySslCertName: name_appgwFrontendSSLCertName
    location: location
    sslCertDataSecretName: (enableAppGWIngress ? appgwSecretDeployment.outputs.sslCertDataSecretName : keyVaultSSLCertDataSecretName)
    _pidAppgwStart: pids.outputs.appgwStart
    _pidAppgwEnd: pids.outputs.appgwEnd
    keyVaultName: name_keyVaultName
    enableCookieBasedAffinity: enableCookieBasedAffinity
  }
  dependsOn: [
    appgwSecretDeployment
    pids
    virtualNetworkName_resource
  ]
}

// Create new network security group.
resource nsg 'Microsoft.Network/networkSecurityGroups@${azure.apiVersionForNetworkSecurityGroups}' = if (enableAppGWIngress && virtualNetworkNewOrExisting == 'new') {
  name: name_networkSecurityGroup
  location: location
  properties: {
    securityRules: [
      {
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 500
          direction: 'Inbound'
        }
        name: 'ALLOW_APPGW'
      }
      {
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 510
          direction: 'Inbound'
          destinationPortRanges: [
            '80'
            '443'
            '9990'
            '8080'
          ]
        }
        name: 'ALLOW_HTTP_ACCESS'
      }
    ]
  }
}

resource bootStorageName 'Microsoft.Storage/storageAccounts@${azure.apiVersionForStorage}' = if (bootDiagnosticsCheck) {
  name: var_bootStorageName
  location: location
  sku: {
    name: bootStorageReplication
  }
  kind: storageAccountKind
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
}

resource eapStorageAccountName 'Microsoft.Storage/storageAccounts@${azure.apiVersionForStorage}' = {
  name: var_eapStorageAccountName
  location: location
  sku: {
    name: eapstorageReplication
  }
  kind: 'Storage'
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
}

resource eapStorageAccountName_default_containerName 'Microsoft.Storage/storageAccounts/blobServices/containers@${azure.apiVersionForStorageBlobService}' = {
  name: '${var_eapStorageAccountName}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    eapStorageAccountName
  ]
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@${azure.apiVersionForVirtualNetworks}' = if (virtualNetworkNewOrExisting == 'new') {
  name: virtualNetworkName
  location: location
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: enableAppGWIngress ? property_subnet_with_app_gateway : property_subnet_without_app_gateway
  }
}

module dbConnectionStartPid './modules/_pids/_pid.bicep' = if (enableDB) {
  name: 'dbConnectionStartPid'
  params: {
    name: pids.outputs.dbStart
  }
  dependsOn: [
    pids
    appgwDeployment
    virtualNetworkName_resource
    bootStorageName
  ]
}

resource vmssInstanceName 'Microsoft.Compute/virtualMachineScaleSets@${azure.apiVersionForVirtualMachineScaleSets}' = {
  name: var_vmssInstanceName
  location: location
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: instanceCount
  }
  plan: plan
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: imageReference
      }
      osProfile: {
        computerNamePrefix: var_vmssInstanceName
        adminUsername: adminUsername
        adminPassword: adminPasswordOrSSHKey
        linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: nicName
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
                    }
                    applicationGatewayBackendAddressPools: enableAppGWIngress ? [
                      {
                        id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, 'managedNodeBackendPool')
                      }
                    ] : null
                    publicIPAddressConfiguration: {
                      name: '${var_vmssInstanceName}${name_publicIPAddress}'
                    }
                  }
                }
              ]
            }
          }
        ]
      }
      diagnosticsProfile: ((bootDiagnostics == 'on') ? json('{"bootDiagnostics": {"enabled": true,"storageUri": "${reference(resourceId(storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts/', var_bootStorageName), '2021-06-01').primaryEndpoints.blob}"}}') : json('{"bootDiagnostics": {"enabled": false}}'))
      extensionProfile: {
        extensions: [
          {
            name: 'jbosseap-setup-extension'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.0'
              autoUpgradeMinorVersion: true
              settings: {
                fileUris: [
                  uri(artifactsLocation, 'scripts/jbosseap-setup-redhat.sh${artifactsLocationSasToken}')
                  uri(artifactsLocation, 'scripts/create-ds-postgresql.sh${artifactsLocationSasToken}')
                  uri(artifactsLocation, 'scripts/create-ds-mssqlserver.sh${artifactsLocationSasToken}')
                  uri(artifactsLocation, 'scripts/create-ds-oracle.sh${artifactsLocationSasToken}')
                  uri(artifactsLocation, 'scripts/create-ds-mysql.sh${artifactsLocationSasToken}')
                ]
              }
              protectedSettings: {
                commandToExecute: 'sh jbosseap-setup-redhat.sh ${scriptArgs} \'${jbossEAPUserName}\' \'${base64(jbossEAPPassword)}\' \'${rhsmUserName}\' \'${base64(rhsmPassword)}\' \'${rhsmPoolEAP}\' \'${var_eapStorageAccountName}\' \'${containerName}\' \'${base64(listKeys(eapStorageAccountName.id, '2021-04-01').keys[0].value)}\' \'${rhsmPoolRHEL}\' \'${connectSatellite}\' \'${base64(satelliteActivationKey)}\' \'${base64(satelliteOrgName)}\' \'${satelliteFqdn}\' \'${jdkVersion}\' \'${enableDB}\' \'${databaseType}\' \'${base64(jdbcDataSourceJNDIName)}\' \'${base64(dsConnectionURL)}\' \'${base64(dbUser)}\' \'${base64(dbPassword)}\''
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    appgwDeployment
    virtualNetworkName_resource
    bootStorageName
  ]
}

module dbConnectionEndPid './modules/_pids/_pid.bicep' = if (enableDB) {
  name: 'dbConnectionEndPid'
  params: {
    name: pids.outputs.dbEnd
  }
  dependsOn: [
    pids
    vmssInstanceName
  ]
}

module byosVmssEndPid './modules/_pids/_pid.bicep' = {
  name: 'byosVmssEndPid'
  params: {
    name: pids.outputs.byosVmssEnd
  }
  dependsOn: [
    dbConnectionEndPid
  ]
}

resource deploymentScriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'deploymentScriptIdentity'
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, deploymentScriptIdentity.id, 'Reader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader role
    principalId: deploymentScriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource getAdminConsolesScripts 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: 'fetchPublicIPs'
  location: location
  kind: 'AzureCLI'
  identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
      '${deploymentScriptIdentity.id}': {}
      }
  }
  properties: {
    azCliVersion: const_azcliVersion
    timeout: 'PT10M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'VMSS_NAME'
        value: vmssInstanceName
      }
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
    ]
    scriptContent: '''
      #!/bin/bash
      set -e

      max_attempts=10
      attempt=1

      while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt to fetch public IPs..."
        public_ips=$(az vmss list-instance-public-ips --name $VMSS_NAME --resource-group $RESOURCE_GROUP --query "[].ipAddress" -o tsv)

        if [ -n "$public_ips" ]; then
          echo "Public IPs found: $public_ips"
          formatted_urls=$(echo $public_ips | tr ' ' '\n' | sed 's|^|http://|; s|$|:9990/*console*/index|' | paste -sd ';')
          echo "{\"urls\":\"$formatted_urls\"}" > $AZ_SCRIPTS_OUTPUT_PATH
          exit 0
        else
          echo "No public IPs found. Waiting 30 seconds before next attempt..."
          sleep 30
        fi

        attempt=$((attempt + 1))
      done

      echo "No public IPs found after $max_attempts attempts. Exiting."
      echo "{\"urls\":\"No public IPs found after $max_attempts attempts\"}" > $AZ_SCRIPTS_OUTPUT_PATH
      exit 1
    '''
  }
  dependsOn: [
    vmss
    roleAssignment
  ]
}

output appGatewayEnabled bool = enableAppGWIngress
output appHttpURL string = enableAppGWIngress ? uri(format('http://{0}/', appgwDeployment.outputs.appGatewayURL), 'eap-session-replication/') : ''
output appHttpsURL string = enableAppGWIngress ? uri(format('https://{0}/', appgwDeployment.outputs.appGatewaySecuredURL), 'eap-session-replication/') : ''
output adminUsername string = jbossEAPUserName
output adminConsoles string = getAdminConsolesScripts.properties.outputs.urls