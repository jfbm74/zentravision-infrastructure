#!/bin/bash
set -e

echo "🧪 Testing Terraform Infrastructure..."

# Test plan
echo "📋 Running terraform plan..."
cd terraform/environments/prod
terraform init
terraform plan -detailed-exitcode

echo "✅ Infrastructure test completed"
