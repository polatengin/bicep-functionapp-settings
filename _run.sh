RANDOM_STRING=$(openssl rand -base64 10 | tr -dc 'a-z0-9')

rm -rf *.json

az group create --location "westus" --name "rg-${RANDOM_STRING}" --output none

az deployment group create --resource-group "rg-${RANDOM_STRING}" --template-file "main.bicep" --parameters "random=${RANDOM_STRING}" --output none

az webapp config appsettings list --name "fa${RANDOM_STRING}" --resource-group "rg-${RANDOM_STRING}" > "0.fresh.json"

