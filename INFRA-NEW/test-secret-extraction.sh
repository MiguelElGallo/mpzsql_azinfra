#!/bin/bash

# Test script to extract all required values for GitHub secrets

echo "🧪 Testing extraction of all required infrastructure values..."

RESOURCE_GROUP="RG-MPZSQL"
DEPLOYMENT_NAME="main"

echo ""
echo "📋 Extracting from Azure deployment outputs..."

# Extract from deployment outputs
POSTGRESQL_SERVER=$(az deployment group show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --query "properties.outputs.postgresServerFqdn.value" \
  --output tsv)

AZURE_STORAGE_ACCOUNT=$(az deployment group show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --query "properties.outputs.storageAccountName.value" \
  --output tsv)

echo "✅ PostgreSQL Server: $POSTGRESQL_SERVER"
echo "✅ Azure Storage Account: $AZURE_STORAGE_ACCOUNT"

echo ""
echo "📄 Extracting from Bicep parameters..."

# Extract from main.bicepparam
POSTGRESQL_USER=$(grep "param postgresAdminUsername" main.bicepparam | sed "s/.*= *'\([^']*\)'.*/\1/")
POSTGRESQL_PASSWORD=$(grep "param postgresAdminPassword" main.bicepparam | sed "s/.*= *'\([^']*\)'.*/\1/")

echo "✅ PostgreSQL User: $POSTGRESQL_USER"
echo "✅ PostgreSQL Password: $POSTGRESQL_PASSWORD"

echo ""
echo "📋 Constants..."

# Constants
AZURE_STORAGE_CONTAINER="data"
POSTGRESQL_CATALOGDB="ducklake_catalog"
POSTGRESQL_PORT="5432"

echo "✅ Azure Storage Container: $AZURE_STORAGE_CONTAINER"
echo "✅ PostgreSQL Catalog DB: $POSTGRESQL_CATALOGDB"
echo "✅ PostgreSQL Port: $POSTGRESQL_PORT"

echo ""
echo "🎯 Summary of all values to be set as GitHub secrets:"
echo "AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT"
echo "AZURE_STORAGE_CONTAINER=$AZURE_STORAGE_CONTAINER"
echo "POSTGRESQL_CATALOGDB=$POSTGRESQL_CATALOGDB"
echo "POSTGRESQL_PASSWORD=$POSTGRESQL_PASSWORD"
echo "POSTGRESQL_USER=$POSTGRESQL_USER"
echo "POSTGRESQL_PORT=$POSTGRESQL_PORT"
echo "POSTGRESQL_SERVER=$POSTGRESQL_SERVER"
echo ""
echo "✅ All values extracted successfully!"
