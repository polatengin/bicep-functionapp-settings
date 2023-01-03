param random string

param appServicePlanName string = 'asp${random}'
param functionAppName string = 'fa${random}'
param storageAccountName string = 'strg${random}'
param appInsightsName string = 'ai${random}'
param location string = resourceGroup().location

