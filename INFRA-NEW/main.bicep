// Main Bicep template for Azure infrastructure deployment
// Uses Azure Verified Modules (AVM) for standardized, best-practice deployments

metadata name = 'Azure Infrastructure for DuckLake'
metadata description = 'Deploys PostgreSQL, KeyVault, Container App, Storage Account, Container Registry, VNET, and Private DNS zone'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name (e.g., dev, prod)')
param environmentName string = 'dev'

@description('Application name prefix')
param appName string = 'ducklake'

@description('PostgreSQL administrator username')
@secure()
param postgresAdminUsername string

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('Virtual Network address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Container App subnet address prefix')
param containerAppSubnetPrefix string = '10.0.1.0/24'

@description('Database subnet address prefix')
param databaseSubnetPrefix string = '10.0.2.0/24'

@description('Private endpoint subnet address prefix')
param privateEndpointSubnetPrefix string = '10.0.3.0/24'

// Variables
var resourcePrefix = '${appName}-${environmentName}'
var vnetName = '${resourcePrefix}-vnet'
var keyVaultName = '${take(replace(resourcePrefix, '-', ''), 8)}kv${take(uniqueString(resourceGroup().id), 12)}'
var storageAccountName = '${take(replace(resourcePrefix, '-', ''), 8)}st${take(uniqueString(resourceGroup().id), 12)}'
var containerRegistryName = '${take(replace(resourcePrefix, '-', ''), 8)}acr${take(uniqueString(resourceGroup().id), 12)}'
var postgresServerName = '${resourcePrefix}-postgres'
var containerAppEnvName = '${resourcePrefix}-containerenv'
var containerAppName = '${resourcePrefix}-app'
var userAssignedIdentityName = '${resourcePrefix}-identity'
var privateDnsZoneName = 'privatelink.postgres.database.azure.com'
var logAnalyticsWorkspaceName = '${resourcePrefix}-logs'

// Log Analytics Workspace for Container Apps
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.3.4' = {
  name: 'logAnalyticsDeployment'
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    skuName: 'PerGB2018'
    tags: {
      environment: environmentName
      application: appName
    }
  }
}

// User-Assigned Managed Identity for Container App
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'userAssignedIdentityDeployment'
  params: {
    name: userAssignedIdentityName
    location: location
    tags: {
      environment: environmentName
      application: appName
    }
  }
}

// Virtual Network with subnets
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'vnetDeployment'
  params: {
    name: vnetName
    location: location
    addressPrefixes: [vnetAddressPrefix]
    subnets: [
      {
        name: 'containerapp-subnet'
        addressPrefix: containerAppSubnetPrefix
        serviceEndpoints: [
          {
            service: 'Microsoft.KeyVault'
          }
          {
            service: 'Microsoft.Storage'
          }
        ]
      }
      {
        name: 'database-subnet'
        addressPrefix: databaseSubnetPrefix
        delegations: [
          {
            name: 'Microsoft.DBforPostgreSQL.flexibleServers'
            properties: {
              serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
            }
          }
        ]
      }
      {
        name: 'privateendpoint-subnet'
        addressPrefix: privateEndpointSubnetPrefix
        privateEndpointNetworkPolicies: 'Disabled'
      }
    ]
    tags: {
      environment: environmentName
      application: appName
    }
  }
}

// Private DNS Zone for PostgreSQL
module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.3.0' = {
  name: 'privateDnsZoneDeployment'
  params: {
    name: privateDnsZoneName
    location: 'global'
    virtualNetworkLinks: [
      {
        name: '${vnetName}-link'
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
        registrationEnabled: false
      }
    ]
    tags: {
      environment: environmentName
      application: appName
    }
  }
}

// PostgreSQL Flexible Server - Using standard resource instead of AVM due to version issues
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: postgresAdminUsername
    administratorLoginPassword: postgresAdminPassword
    version: '14'
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: virtualNetwork.outputs.subnetResourceIds[1] // database-subnet
      privateDnsZoneArmResourceId: privateDnsZone.outputs.resourceId
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
  }
  tags: {
    environment: environmentName
    application: appName
  }
}

// Role assignments using module approach with roleAssignments parameter
// Key Vault role assignment via the module
module keyVaultWithRoles 'br/public:avm/res/key-vault/vault:0.6.1' = {
  name: 'keyVaultWithRolesDeployment'
  params: {
    name: keyVaultName
    location: location
    sku: 'standard'
    enableRbacAuthorization: true
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: virtualNetwork.outputs.subnetResourceIds[0] // containerapp-subnet
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
    privateEndpoints: [
      {
        name: '${keyVaultName}-pe'
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[2] // privateendpoint-subnet
        privateDnsZoneResourceIds: [
          privateDnsZone.outputs.resourceId
        ]
      }
    ]
    tags: {
      environment: environmentName
      application: appName
    }
  }
}

// Storage Account with Hierarchical Namespace
module storageAccountWithRoles 'br/public:avm/res/storage/storage-account:0.9.1' = {
  name: 'storageWithRolesDeployment'
  params: {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    enableHierarchicalNamespace: true // Enable Hierarchical Namespace for Data Lake
    blobServices: {
      containers: [
        {
          name: 'data'
          publicAccess: 'None'
        }
      ]
    }
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: virtualNetwork.outputs.subnetResourceIds[0] // containerapp-subnet
          action: 'Allow'
        }
      ]
    }
    tags: {
      environment: environmentName
      application: appName
    }
  }
}

// Container Registry
module containerRegistryWithRoles 'br/public:avm/res/container-registry/registry:0.3.1' = {
  name: 'containerRegistryWithRolesDeployment'
  params: {
    name: containerRegistryName
    location: location
    acrSku: 'Premium'
    acrAdminUserEnabled: false
    publicNetworkAccess: 'Enabled' // Enable public network access from all networks
    exportPolicyStatus: 'enabled' // Enable exports when public network access is enabled
    tags: {
      environment: environmentName
      application: appName
    }
  }
}

// Container App Environment
module containerAppEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = {
  name: 'containerAppEnvDeployment'
  params: {
    name: containerAppEnvName
    location: location
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
    infrastructureSubnetId: virtualNetwork.outputs.subnetResourceIds[0] // containerapp-subnet
    internal: false
    tags: {
      environment: environmentName
      application: appName
    }
  }
}

// Container App
module containerApp 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'containerAppDeployment'
  params: {
    name: containerAppName
    location: location
    environmentResourceId: containerAppEnvironment.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: [
        userAssignedIdentity.outputs.resourceId
      ]
    }
    containers: [
      {
        name: 'ducklake-app'
        image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' // Placeholder image
        resources: {
          cpu: json('0.25')
          memory: '0.5Gi'
        }
        env: [
          {
            name: 'POSTGRES_SERVER'
            value: postgresServer.properties.fullyQualifiedDomainName
          }
          {
            name: 'POSTGRES_USERNAME'
            value: postgresAdminUsername
          }
          {
            name: 'KEY_VAULT_URL'
            value: keyVaultWithRoles.outputs.uri
          }
          {
            name: 'STORAGE_ACCOUNT_NAME'
            value: storageAccountWithRoles.outputs.name
          }
          {
            name: 'CONTAINER_REGISTRY_URL'
            value: containerRegistryWithRoles.outputs.loginServer
          }
        ]
      }
    ]
    ingressExternal: true
    ingressTargetPort: 8080
    ingressTransport: 'tcp'
    exposedPort: 8080
    ingressAllowInsecure: false
    tags: {
      environment: environmentName
      application: appName
    }
  }
}

// Role Assignments for Container App's System-Assigned Managed Identity
// Note: Role assignments are deployed separately via role-assignments.bicep

// Outputs
output vnetId string = virtualNetwork.outputs.resourceId
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName
output postgresServerResourceId string = postgresServer.id
output keyVaultUri string = keyVaultWithRoles.outputs.uri
output keyVaultResourceId string = keyVaultWithRoles.outputs.resourceId
output storageAccountName string = storageAccountWithRoles.outputs.name
output storageAccountResourceId string = storageAccountWithRoles.outputs.resourceId
output containerRegistryLoginServer string = containerRegistryWithRoles.outputs.loginServer
output containerRegistryResourceId string = containerRegistryWithRoles.outputs.resourceId
output containerAppFqdn string = containerApp.outputs.fqdn
output containerAppSystemAssignedIdentityId string = containerApp.outputs.systemAssignedMIPrincipalId
output userAssignedIdentityResourceId string = userAssignedIdentity.outputs.resourceId
output userAssignedIdentityPrincipalId string = userAssignedIdentity.outputs.principalId
output userAssignedIdentityClientId string = userAssignedIdentity.outputs.clientId
