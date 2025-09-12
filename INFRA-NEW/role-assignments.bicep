// Role assignments for Container App's System-Assigned and User-Assigned Managed Identities
// This template should be deployed after the main infrastructure

@description('The principal ID of the Container App\'s system-assigned managed identity')
param containerAppPrincipalId string

@description('The principal ID of the user-assigned managed identity')
param userAssignedIdentityPrincipalId string

@description('The resource ID of the Key Vault')
param keyVaultResourceId string

@description('The resource ID of the Storage Account')
param storageAccountResourceId string

@description('The resource ID of the Container Registry')
param containerRegistryResourceId string

@description('The resource ID of the PostgreSQL Flexible Server')
param postgresServerResourceId string

// Reference existing resources for role assignments
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: last(split(keyVaultResourceId, '/'))
  scope: resourceGroup()
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: last(split(storageAccountResourceId, '/'))
  scope: resourceGroup()
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: last(split(containerRegistryResourceId, '/'))
  scope: resourceGroup()
}

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' existing = {
  name: last(split(postgresServerResourceId, '/'))
  scope: resourceGroup()
}

// Key Vault Secrets Officer role assignment
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultResourceId, containerAppPrincipalId, 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets Officer
    principalId: containerAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Contributor role assignment  
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountResourceId, containerAppPrincipalId, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: containerAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Container Registry AcrPull role assignment for System-Assigned Identity
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistryResourceId, containerAppPrincipalId, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: containerAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Container Registry AcrPull role assignment for User-Assigned Identity
resource acrUserAssignedRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistryResourceId, userAssignedIdentityPrincipalId, '7f951dda-4ed3-4680-a7ca-43fe172d538d-uai')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// PostgreSQL AAD Administrator assignment for Container App's System-Assigned Managed Identity
resource postgresAadAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2023-03-01-preview' = {
  parent: postgresServer
  name: containerAppPrincipalId
  properties: {
    principalType: 'ServicePrincipal'
    principalName: 'placeholder-name'  // This will be automatically resolved by Azure
    tenantId: subscription().tenantId
  }
}

// Outputs
output keyVaultRoleAssignmentId string = keyVaultRoleAssignment.id
output storageRoleAssignmentId string = storageRoleAssignment.id
output acrRoleAssignmentId string = acrRoleAssignment.id
output acrUserAssignedRoleAssignmentId string = acrUserAssignedRoleAssignment.id
output postgresAadAdminId string = postgresAadAdmin.id
