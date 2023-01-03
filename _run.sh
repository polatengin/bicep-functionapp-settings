RANDOM_STRING=$(openssl rand -base64 10 | tr -dc 'a-z0-9')

rm -rf *.json

az group create --location "westus" --name "rg-${RANDOM_STRING}" --output none

