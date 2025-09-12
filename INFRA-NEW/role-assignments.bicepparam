using 'role-assignments.bicep'

// These parameters will be populated from the outputs of the main deployment
param containerAppPrincipalId = '' // Will be filled from main deployment output
param userAssignedIdentityPrincipalId = '' // Will be filled from main deployment output
param keyVaultResourceId = ''       // Will be filled from main deployment output  
param storageAccountResourceId = '' // Will be filled from main deployment output
param containerRegistryResourceId = '' // Will be filled from main deployment output
param postgresServerResourceId = '' // Will be filled from main deployment output
