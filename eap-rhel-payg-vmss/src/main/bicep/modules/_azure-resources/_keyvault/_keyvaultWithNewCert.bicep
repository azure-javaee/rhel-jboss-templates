@description('Managed identity to be used for the deployment script. Currently, only user-assigned MSI is supported.')
param identity object = {}

@description('Used to name the new Azure Key Vault resoure.')
param keyVaultName string = 'jboss-kv-${uniqueString(utcValue)}'

param location string

@description('Access permission of the key vault, will applied to all access policies.')
param permission object = {
  certificates: [
    'get'
    'list'
    'update'
    'create'
  ]
}

@description('Used to name the new certificate resource.')
param secretName string = 'mySelfSignedCertificate'

@description('Price tier for Key Vault.')
param sku string = 'Standard'

@description('Subject name to create a new certificate, example: \'CN=contoso.com\'.')
param subjectName string = 'contoso.xyz'
param utcValue string = utcNow()
param guidValue string = ''

var const_identityId = substring(string(identity.userAssignedIdentities), indexOf(string(identity.userAssignedIdentities), '"') + 1, lastIndexOf(string(identity.userAssignedIdentities), '"') - (indexOf(string(identity.userAssignedIdentities), '"') + 1))

resource keyvault 'Microsoft.KeyVault/vaults@${azure.apiVersionForKeyVault}' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: sku
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        // Must specify API version of identity.
        objectId: reference(const_identityId, '2018-11-30').principalId
        tenantId: subscription().tenantId
        permissions: permission
      }
    ]
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableRbacAuthorization: false
    enableSoftDelete: true
  }
  tags:{
    'managed-by-azure-jboss': utcValue
  }
}

resource createAddCertificate 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: 'ds-create-add-appgw-certificate-${guidValue}'
  location: location
  identity: identity
  kind: 'AzurePowerShell'
  properties: {
    forceUpdateTag: utcValue
    azPowerShellVersion: '11.5'
    timeout: 'PT30M'
    arguments: ' -vaultName ${keyVaultName} -certificateName ${secretName} -subjectName ${subjectName}'
    scriptContent: '\n                    param(\n                        [string] [Parameter(Mandatory=$true)] $vaultName,\n                        [string] [Parameter(Mandatory=$true)] $certificateName,\n                        [string] [Parameter(Mandatory=$true)] $subjectName\n                    )\n\n                    $ErrorActionPreference = \'Stop\'\n                    $DeploymentScriptOutputs = @{}\n\n                    $existingCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName\n\n                    if ($existingCert -and $existingCert.Certificate.Subject -eq $subjectName) {\n\n                        Write-Host \'Certificate $certificateName in vault $vaultName is already present.\'\n\n                        $DeploymentScriptOutputs[\'certThumbprint\'] = $existingCert.Thumbprint\n                        $existingCert | Out-String\n                    }\n                    else {\n                        $policy = New-AzKeyVaultCertificatePolicy -SubjectName $subjectName -IssuerName Self -ValidityInMonths 12 -Verbose\n\n                        # private key is added as a secret that can be retrieved in the ARM template\n                        Add-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName -CertificatePolicy $policy -Verbose\n\n                        $newCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName\n\n                        # it takes a few seconds for KeyVault to finish\n                        $tries = 0\n                        do {\n                        Write-Host \'Waiting for certificate creation completion...\'\n                        Start-Sleep -Seconds 10\n                        $operation = Get-AzKeyVaultCertificateOperation -VaultName $vaultName -Name $certificateName\n                        $tries++\n\n                        if ($operation.Status -eq \'failed\')\n                        {\n                            throw \'Creating certificate $certificateName in vault $vaultName failed with error $($operation.ErrorMessage)\'\n                        }\n\n                        if ($tries -gt 120)\n                        {\n                            throw \'Timed out waiting for creation of certificate $certificateName in vault $vaultName\'\n                        }\n                        } while ($operation.Status -ne \'completed\')\n\n                        $DeploymentScriptOutputs[\'certThumbprint\'] = $newCert.Thumbprint\n                        $newCert | Out-String\n                    }\n                '
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    keyvault
  ]
}

output keyVaultName string = keyVaultName
output secretName string = secretName
output identityId string = const_identityId
