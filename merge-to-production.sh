#!/bin/bash

# Script para mergear branch dev a production en todos los repos
# Uso: ./merge-to-production.sh

set -e  # Exit on error

echo "======================================"
echo "Merging dev → production"
echo "======================================"

# Backend
echo ""
echo "📦 Processing smart-ops-backend..."
cd ../smart-ops-backend
git checkout production || git checkout -b production
git pull origin production || true
git merge dev -m "Merge dev to production - $(date +%Y-%m-%d)"
git push origin production
echo "✅ Backend merged successfully"

# Frontend
echo ""
echo "📦 Processing smart-ops-frontend..."
cd ../smart-ops-frontend
git checkout production || git checkout -b production
git pull origin production || true
git merge dev -m "Merge dev to production - $(date +%Y-%m-%d)"
git push origin production
echo "✅ Frontend merged successfully"

# Infrastructure
echo ""
echo "📦 Processing smart-ops-infrastructure..."
cd ../smart-ops-infrastructure
git checkout production || git checkout -b production
git pull origin production || true
git merge dev -m "Merge dev to production - $(date +%Y-%m-%d)"

# Update submodule references to point to production branches
git submodule foreach 'git checkout production'
git add smart-ops-backend smart-ops-frontend
git commit -m "Update submodule references to production - $(date +%Y-%m-%d)" || true
git push origin production
echo "✅ Infrastructure merged successfully"

echo ""
echo "======================================"
echo "✅ All repositories merged to production!"
echo "======================================"
echo ""
echo "Next steps:"
echo "The push to production triggers the EC2 deploy automatically (GitHub Actions)."
