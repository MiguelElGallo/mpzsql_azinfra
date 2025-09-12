#!/bin/bash

# Test script for validating Bicep templates
# This script validates the Bicep template without deploying it

set -e

echo "🧪 Testing DuckLake Infrastructure Bicep Templates"
echo "================================================"

# Check if Bicep CLI is available
if ! command -v bicep &> /dev/null; then
    echo "❌ Bicep CLI not found. Please install it first."
    exit 1
fi

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Please install it first."
    exit 1
fi

# Change to the INFRA-NEW directory
cd "$(dirname "$0")"

echo "📁 Working directory: $(pwd)"

# Validate Bicep syntax
echo "🔍 Validating Bicep syntax..."
bicep build main.bicep --outfile main.json

if [ $? -eq 0 ]; then
    echo "✅ Bicep syntax validation passed"
else
    echo "❌ Bicep syntax validation failed"
    exit 1
fi

# Validate parameters file
echo "🔍 Validating parameters file..."
if [ -f "main.bicepparam" ]; then
    echo "✅ Parameters file found"
else
    echo "❌ Parameters file not found"
    exit 1
fi

# Check if logged in to Azure (optional for syntax validation)
if az account show &> /dev/null; then
    echo "✅ Azure CLI authenticated"
    
    # Perform what-if analysis if resource group exists
    RESOURCE_GROUP="RG-MPZSQL"
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        echo "🔍 Performing what-if analysis..."
        az deployment group what-if \
            --resource-group "$RESOURCE_GROUP" \
            --template-file main.bicep \
            --parameters main.bicepparam \
            --no-pretty-print
        
        if [ $? -eq 0 ]; then
            echo "✅ What-if analysis completed successfully"
        else
            echo "⚠️  What-if analysis had issues (this might be expected)"
        fi
    else
        echo "⚠️  Resource group $RESOURCE_GROUP not found, skipping what-if analysis"
    fi
else
    echo "⚠️  Not authenticated to Azure, skipping what-if analysis"
fi

echo ""
echo "🎉 Template validation completed!"
echo "📋 Next steps:"
echo "   1. Review the generated main.json file"
echo "   2. Deploy using: az deployment group create --resource-group RG-MPZSQL --template-file main.bicep --parameters main.bicepparam"