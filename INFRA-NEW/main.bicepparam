using 'main.bicep'


param location = 'swedencentral' 
param environmentName = 'dev' 
param appName = 'mpzsql'


param postgresAdminUsername = 'ducklakeadmin'
param postgresAdminPassword = 'P@ssw0rd123!'


param vnetAddressPrefix = '10.0.0.0/16'
param containerAppSubnetPrefix = '10.0.0.0/23'
param databaseSubnetPrefix = '10.0.2.0/24'
param privateEndpointSubnetPrefix = '10.0.3.0/24'
