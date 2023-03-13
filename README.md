# Azure deployment overwrites app settings between deployments

[Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/overview) can store application specific settings in the _AppSettings_ configuration feature (official documentation can be found on; [Configure an App Service app](https://learn.microsoft.com/en-us/azure/app-service/configure-common?tabs=cli)).

These settings are stored on `Azure`, provided to the application as _Environment Variables_ and are _not_ part of the application code.

Azure App Service settings can be set using the [Azure Portal](https://portal.azure.com), [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/), [Azure Az PowerShell module](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps), [ARM templates](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/overview), or [Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/).

In the bicep example, the settings are set using the `appSettings` property of the `Microsoft.Web/sites` resource.

```bicep
resource appService 'Microsoft.Web/sites@2020-06-01' = {
  name: 'my-app-service'
  location: resourceGroup().location
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
          value: '1.0.0'
        }
      ]
    }
  }
}
```

## Scenario

Imagine the infra deployment set certain app settings during the provisioning step, and the application itself modify, add, or, delete settings over the time, along it works.

When a change happens to the infrastructure as code, code (IaC code), infrastructure gets re-deployed (most probably by a pipeline, triggered by the change)

Since Azure deployments are idempotent, assumption is, modified settings will be preserved during the deployment.

## Reality

Azure deployments reset the appsettings back to it's definition on the `.bicep` file.

## Repro

You can run the [deploy.sh](./deploy.sh) script to;

- Deploy the Bicep template
- Save the settings to a file (`0.fresh.json`)
- Set new settings, update existing settings
- Save the settings to a file (`1.before-deployment.json`)
- Deploy the Bicep template again
- Save the settings to a file (`2.after-deployment.json`)

Expectation is `1.before-deployment.json` and `2.after-deployment.json` are same, but actually, `0.fresh.json` and `2.after-deployment.json` are the same.

[![asciicast](https://asciinema.org/a/549280.png)](https://asciinema.org/a/549280)

## Solutions

A few solutions can be used for the issue

- Creating a KeyVault to store and retrieve app settings for an environment
- Creating an App Configuration to store and retrieve app settings for an environment
- Combination of KeyVault and App configuration to store and retrieve app settings for an environment
- Backup existing configuration _before_ the deployment, restore the configuration _after_ the deployment

### Solution #1 (using KeyVault)

With the sample bicep module below, WebApp can have a KeyVault as the configuration store

```bicep
resource appServicePlan 'Microsoft.Web/serverfarms@2021-01-01' = {
  name: 'appservice-sample'
  location: 'westus2'
  sku: {
    name: 'F1'
    tier: 'Free'
    size: 'F1'
    family: 'F'
    capacity: 0
  }
}
resource appService 'Microsoft.Web/sites@2021-01-01' = {
  name: 'webapp-sample'
  location: 'westus2'
  kind: 'app'
  properties: {
    enabled: true
    serverFarmId: appServicePlan.id
  }
  identity:{
     type: 'SystemAssigned'
  }
}
resource vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv-sample'
  location: 'westus2'
  properties: {
    accessPolicies:[
      {
        tenantId: subscription().tenantId
        objectId: svcPrincipalObjectId
        permissions: {
          secrets: ['get', 'list']
          certificates: ['get', 'list']
          keys: ['get', 'list']
        }
      }
    ]
    enableRbacAuthorization: false
    enableSoftDelete: false
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}
resource secret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: vault
  name: 'samplesecret'
  properties: {
    contentType: 'text/plain'
    value: 'samplevalue'
  }
}
resource vaultAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: '${appService.name} Key Vault Secret User ${uniqueString(resourceGroup().id,appService.name)}'
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId) // this is the role "Key Vault Secrets User"
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
resource appSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'appsettings'
  parent: appService
  properties: {
    AppSecret: '@Microsoft.KeyVault(SecretUri=${vault.properties.secretUri})'
    }
  dependsOn:[
    vaultAssignment
  ]
}
```

### Solution #2 (using App Configuration)

With the sample bicep module below, an _App Configuration_ resource is created on Azure

```bicep
resource configStore 'Microsoft.AppConfiguration/configurationStores@2021-10-01-preview' = {
  name: 'config-sample'
  location: 'westus2'
  sku: {
    name: 'standard'
  }
}

resource configStoreKeyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2021-10-01-preview' = {
  parent: configStore
  name: 'samplesecret'
  properties: {
    value: 'samplevalue'
    contentType: 'text/plain'
  }
}
```

Quickstart documentation and Tutorials to use the App Configuration resource from your app (.net, asp.net java, python, ) can be found here; https://learn.microsoft.com/en-us/azure/azure-app-configuration/

### Solution #3 (combination of KeyVault and App Configuration)

Configuration can be stored in a KeyVault instance, and an App Configuration service can be configured to get items from the KeyVault.

Application can be configured to read configuration from the App Configuration service (actually from KeyVault, thru App Configuration)

### Solution #4 (backup settings, restore settings)

Until `preserveSettings` feature (or a feature like that) is introduced and provided by the Azure Deployment backend API, we should _backup_ the settings _before_ the deployment, and _restore_ it back _after_ the deployment.

_Before_ the deployment, we can backup `appSettings` for a webapp;

```bash
az webapp config appsettings list --name "${WEB_APP_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" | jq -r '.' > backup.json
```

Then do the deployment

```bash
az deployment group create --resource-group "${RESOURCE_GROUP_NAME}" --template-file "main.bicep" --output "none"
```

_After_ the deployment, we can restore the `appSettings` back;

```bash
az webapp config appsettings set --name "${WEB_APP_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" --settings "@backup.json" --output "none"
```
