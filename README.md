# Azure App Service settings difference between Bicep deployments

Azure App Service service can store application specific settings in the Azure App Service configuration. These settings are stored in the Azure App Service configuration and are not part of the application code.

Azure App Service settings can be set using the Azure Portal, Azure CLI, Azure PowerShell, ARM templates, or Bicep.

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

You can run the `_run.sh` script to;

- Deploy the Bicep template
- Save the settings to a file (`0.fresh.json`)
- Set new settings, update existing settings
- Save the settings to a file (`1.before-deployment.json`)
- Deploy the Bicep template again
- Save the settings to a file (`2.after-deployment.json`)
- Compare the settings before and after the deployment

[![asciicast](https://asciinema.org/a/549280.png)](https://asciinema.org/a/549280)
