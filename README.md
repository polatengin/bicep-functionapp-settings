# Azure App Service settings difference between Bicep deployments

Azure App Service can store application specific settings in the AppSettings configuration feature (official documentation can be found on; [Configure an App Service app](https://learn.microsoft.com/en-us/azure/app-service/configure-common?tabs=cli)).

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

Since Azure deployments are idemponent, between deployments the settings should not change.

You can run the [deploy.sh](./deploy.sh) script to;

- Deploy the Bicep template
- Save the settings to a file (`0.fresh.json`)
- Set new settings, update existing settings
- Save the settings to a file (`1.before-deployment.json`)
- Deploy the Bicep template again
- Save the settings to a file (`2.after-deployment.json`)
- Compare the settings before and after the deployment

[![asciicast](https://asciinema.org/a/549280.png)](https://asciinema.org/a/549280)
