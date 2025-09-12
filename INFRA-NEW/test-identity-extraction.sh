#!/bin/bash

# Test script for identity extraction logic

set -e

echo "🧪 Testing identity extraction logic..."

RESOURCE_GROUP="RG-MPZSQL"

# Step 1: Find deployment
echo "📋 Step 1: Finding deployment..."
DEPLOYMENT_NAME=$(az deployment group list \
  --resource-group "${RESOURCE_GROUP}" \
  --query "[?name=='main' && properties.provisioningState=='Succeeded'].name | [0]" \
  --output tsv)

if [ -z "$DEPLOYMENT_NAME" ] || [ "$DEPLOYMENT_NAME" = "null" ]; then
  echo "🔍 No 'main' deployment found, looking for latest successful deployment..."
  DEPLOYMENT_NAME=$(az deployment group list \
    --resource-group "${RESOURCE_GROUP}" \
    --query "[?properties.provisioningState=='Succeeded'] | sort_by(@, &properties.timestamp) | [-1].name" \
    --output tsv)
fi

if [ -z "$DEPLOYMENT_NAME" ]; then
  echo "❌ No successful infrastructure deployment found"
  exit 1
fi

echo "📋 Using deployment: ${DEPLOYMENT_NAME}"

# Step 2: Extract user-assigned identity resource ID
echo "🔑 Step 2: Extracting user-assigned identity resource ID..."
USER_IDENTITY_RESOURCE_ID=$(az deployment group show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --query "properties.outputs.userAssignedIdentityResourceId.value" \
  --output tsv 2>/dev/null || echo "")

if [ -z "$USER_IDENTITY_RESOURCE_ID" ] || [ "$USER_IDENTITY_RESOURCE_ID" = "null" ]; then
  echo "❌ Could not get user-assigned identity resource ID from deployment outputs"
  echo "Available outputs:"
  az deployment group show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${DEPLOYMENT_NAME}" \
    --query "properties.outputs" \
    --output json | jq 'keys'
  exit 1
fi

echo "✅ User-assigned identity resource ID: ${USER_IDENTITY_RESOURCE_ID}"

# Verify the identity exists
echo "🔍 Step 3: Verifying identity exists..."
IDENTITY_NAME=$(echo "$USER_IDENTITY_RESOURCE_ID" | sed 's/.*\///')
echo "Identity name: $IDENTITY_NAME"

if az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo "✅ Identity exists and is accessible"
else
  echo "❌ Identity does not exist or is not accessible"
  exit 1
fi

echo ""
echo "🎉 All tests passed! The identity extraction logic works correctly."
echo "Resource ID: $USER_IDENTITY_RESOURCE_ID"
