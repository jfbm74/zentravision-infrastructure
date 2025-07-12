#!/bin/bash
set -e

echo "🧪 Testing Ansible Configuration..."

cd ansible

# Test syntax
echo "📋 Checking playbook syntax..."
ansible-playbook --syntax-check -i inventories/prod playbooks/site.yml

# Test connection
echo "🔗 Testing connection to hosts..."
ansible -i inventories/prod zentravision -m ping

# Test variables
echo "📊 Testing variables..."
ansible -i inventories/prod zentravision -m setup -a "filter=ansible_distribution*"

echo "✅ Ansible test completed"
