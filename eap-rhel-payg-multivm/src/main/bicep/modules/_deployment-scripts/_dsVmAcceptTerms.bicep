param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param location string
param name string = ''
param identity object = {}
param plan object = {}
param utcValue string = utcNow()
@description('${label.tagsLabel}')
param tagsByResource object

var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var urn = '${plan.publisher}:${plan.product}:${plan.name}'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: name
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: '2.41.0'
    environmentVariables: [
      {
        name: 'URN'
        value: urn
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, 'vm-accept-terms.sh${_artifactsLocationSasToken}')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
  tags: tagsByResource['${identifier.deploymentScripts}']
}
