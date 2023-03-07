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

## Solution

There are a few solutions for the issue

- Creating a KeyVault to store and retrieve app settings for an environment
- Creating an App Configuration to store and retrieve app settings for an environment
- Backup existing configuration _before_ the deployment, restore the configuration _after_ the deployment
### Solution #3 (backup settings, restore settings)

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
