#!/bin/bash

# Quick setup script for offline development environment
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🎯 Keep Offline Development Setup"
echo "=================================="

# Check prerequisites
echo "🔍 Checking prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker is required but not installed."
    exit 1
fi

if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "❌ Docker Compose is required but not installed."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Make scripts executable
chmod +x "$REPO_ROOT/scripts/prepare-offline-deps.sh"

# Run dependency preparation
echo "📦 Preparing dependencies for offline development..."
"$REPO_ROOT/scripts/prepare-offline-deps.sh"

echo ""
echo "🎉 Setup complete!"
echo ""
echo "🚀 To start development:"
echo "   ./vendor/start-offline-dev.sh"
echo ""
echo "🔧 Alternative (separate services):"
echo "   docker-compose -f docker-compose.offline-dev-separate.yml up --build"
echo ""
echo "📚 Documentation:"
echo "   ./vendor/README-OFFLINE-DEV.md"
