RANDOM_STRING=$(openssl rand -base64 10 | tr -dc 'a-z0-9')

rm -rf *.json

az group create --location "westus" --name "rg-${RANDOM_STRING}" --output none

az deployment group create --resource-group "rg-${RANDOM_STRING}" --template-file "main.bicep" --parameters "random=${RANDOM_STRING}" --output none

az webapp config appsettings list --name "fa${RANDOM_STRING}" --resource-group "rg-${RANDOM_STRING}" > "0.fresh.json"

az webapp config appsettings set --name "fa${RANDOM_STRING}" --resource-group "rg-${RANDOM_STRING}" --settings "new=setting" --output none
az webapp config appsettings set --name "fa${RANDOM_STRING}" --resource-group "rg-${RANDOM_STRING}" --settings "APPINSIGHTS_INSTRUMENTATIONKEY=${RANDOM_STRING}" --output none
az webapp config appsettings set --name "fa${RANDOM_STRING}" --resource-group "rg-${RANDOM_STRING}" --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=${RANDOM_STRING}" --output none

az webapp config appsettings list --name "fa${RANDOM_STRING}" --resource-group "rg-${RANDOM_STRING}" > "1.before-deployment.json"

az deployment group create --resource-group "rg-${RANDOM_STRING}" --template-file "main.bicep" --parameters "random=${RANDOM_STRING}" --output none

az webapp config appsettings list --name "fa${RANDOM_STRING}" --resource-group "rg-${RANDOM_STRING}" > "2.after-deployment.json"

echo "These are the differences between the app settings before and after the deployment"
diff 1.before-deployment.json 2.after-deployment.json

echo "Interestingly, the app settings are the same as when the app was first created, even though the deployment changed the app settings"
diff 0.fresh.json 2.after-deployment.json
