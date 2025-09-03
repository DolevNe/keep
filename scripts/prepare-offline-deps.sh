#!/bin/bash

# Script to prepare all dependencies for offline development
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor"

echo "🚀 Preparing offline development dependencies..."
echo "Repository root: $REPO_ROOT"

# Create vendor directory
mkdir -p "$VENDOR_DIR"/{python-packages,node-packages,state}

cd "$REPO_ROOT"

echo "📦 Step 1: Preparing Python dependencies..."

# We're already in the repository root

# Check if we have a virtual environment with dependencies already installed
if [ -f "venv/bin/pip" ]; then
    echo "Using existing virtual environment to generate requirements..."
    # Generate requirements from the existing virtual environment
    venv/bin/pip freeze > "$VENDOR_DIR/requirements.txt"
    
    # Try to download Python packages, but continue even if some fail
    echo "Downloading Python packages (may have some conflicts, that's okay)..."
    if ! venv/bin/pip download -d "$VENDOR_DIR/python-packages" -r "$VENDOR_DIR/requirements.txt" 2>/dev/null; then
        echo "⚠️  Some packages had conflicts. Using alternative approach..."
        # Create a simplified requirements file with main dependencies only
        echo "# Simplified requirements for offline development" > "$VENDOR_DIR/requirements-simple.txt"
        echo "fastapi>=0.115.0" >> "$VENDOR_DIR/requirements-simple.txt"
        echo "uvicorn>=0.32.0" >> "$VENDOR_DIR/requirements-simple.txt"
        echo "pydantic>=1.10.0" >> "$VENDOR_DIR/requirements-simple.txt"
        echo "sqlalchemy>=2.0.0" >> "$VENDOR_DIR/requirements-simple.txt"
        echo "sqlmodel>=0.0.22" >> "$VENDOR_DIR/requirements-simple.txt"
        echo "requests>=2.32.0" >> "$VENDOR_DIR/requirements-simple.txt"
        echo "pyyaml>=6.0.0" >> "$VENDOR_DIR/requirements-simple.txt"
        
        # Download simplified requirements
        venv/bin/pip download -d "$VENDOR_DIR/python-packages" -r "$VENDOR_DIR/requirements-simple.txt" || true
        
        echo "📝 Note: Using simplified requirements due to dependency conflicts."
        echo "   The Docker build will use the existing virtual environment instead."
    fi
    
elif [ -f "pyproject.toml" ]; then
    echo "Using pyproject.toml directly..."
    # Create a basic requirements file from pyproject.toml
    echo "# Basic requirements extracted from pyproject.toml" > "$VENDOR_DIR/requirements.txt"
    echo "fastapi" >> "$VENDOR_DIR/requirements.txt"
    echo "uvicorn" >> "$VENDOR_DIR/requirements.txt"
    echo "pydantic" >> "$VENDOR_DIR/requirements.txt"
    echo "sqlalchemy" >> "$VENDOR_DIR/requirements.txt"
    
    # Download basic packages
    pip download -d "$VENDOR_DIR/python-packages" -r "$VENDOR_DIR/requirements.txt" || true
else
    echo "❌ No pyproject.toml or virtual environment found."
    exit 1
fi

echo "✅ Python dependencies prepared in $VENDOR_DIR/python-packages"

echo "📦 Step 2: Preparing Node.js dependencies..."

# Navigate to frontend directory
cd keep-ui

# Check if pnpm is available, fallback to npm
if command -v pnpm >/dev/null 2>&1; then
    echo "Using pnpm for Node.js dependencies..."
    PACKAGE_MANAGER="pnpm"
    LOCK_FILE="pnpm-lock.yaml"
    
    # Create pnpm-lock.yaml if it doesn't exist
    if [ ! -f "$LOCK_FILE" ]; then
        echo "Creating pnpm lockfile..."
        pnpm install --lockfile-only
    fi
    
    # Download dependencies
    pnpm fetch --offline=false
    
    # Create offline cache
    mkdir -p "$VENDOR_DIR/pnpm-store"
    pnpm store path > "$VENDOR_DIR/pnpm-store-path.txt" 2>/dev/null || echo "$HOME/.pnpm" > "$VENDOR_DIR/pnpm-store-path.txt"
    PNPM_STORE=$(cat "$VENDOR_DIR/pnpm-store-path.txt")
    
    if [ -d "$PNPM_STORE" ]; then
        echo "Copying pnpm store to vendor directory..."
        cp -r "$PNPM_STORE" "$VENDOR_DIR/pnpm-store/"
    fi
    
else
    echo "Using npm for Node.js dependencies..."
    PACKAGE_MANAGER="npm"
    LOCK_FILE="package-lock.json"
    
    # Create npm cache in vendor directory
    NPM_CACHE_DIR="$VENDOR_DIR/npm-cache"
    mkdir -p "$NPM_CACHE_DIR"
    
    # Download dependencies to cache
    npm ci --cache "$NPM_CACHE_DIR" --prefer-offline
    
    # Create node_modules tarball for Docker
    if [ -d "node_modules" ]; then
        echo "Creating node_modules tarball..."
        tar -czf "$VENDOR_DIR/node_modules.tar.gz" node_modules/
    fi
fi

echo "✅ Node.js dependencies prepared"

echo "📦 Step 3: Creating offline configuration..."

# Create offline development configuration
cat > "$VENDOR_DIR/offline-dev-config.env" << EOF
# Offline Development Configuration
# Generated on $(date)

# Package Manager Used
PACKAGE_MANAGER=$PACKAGE_MANAGER

# Python Configuration  
POETRY_VERSION=1.3.2
PYTHON_VERSION=3.13.5

# Node.js Configuration
NODE_VERSION=20
NPM_CACHE_DIR=$VENDOR_DIR/npm-cache
PNPM_STORE_DIR=$VENDOR_DIR/pnpm-store

# Development URLs
FRONTEND_URL=http://localhost:3000
BACKEND_URL=http://localhost:8080
WEBSOCKET_URL=http://localhost:6001

EOF

echo "📦 Step 4: Creating development scripts..."

# Create start script for offline development
cat > "$VENDOR_DIR/start-offline-dev.sh" << 'EOF'
#!/bin/bash

# Start offline development environment
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting Keep offline development environment..."

# Load configuration
if [ -f "$SCRIPT_DIR/offline-dev-config.env" ]; then
    source "$SCRIPT_DIR/offline-dev-config.env"
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Determine Docker Compose command
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

# Build and start the development environment
cd "$REPO_ROOT"

echo "🔨 Building offline development image..."
$DOCKER_COMPOSE -f docker-compose.offline-dev.yml build

echo "🚀 Starting services..."
$DOCKER_COMPOSE -f docker-compose.offline-dev.yml up

EOF

chmod +x "$VENDOR_DIR/start-offline-dev.sh"

# Create stop script
cat > "$VENDOR_DIR/stop-offline-dev.sh" << 'EOF'
#!/bin/bash

# Stop offline development environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🛑 Stopping Keep offline development environment..."

# Determine Docker Compose command
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

cd "$REPO_ROOT"
$DOCKER_COMPOSE -f docker-compose.offline-dev.yml down

echo "✅ Offline development environment stopped."

EOF

chmod +x "$VENDOR_DIR/stop-offline-dev.sh"

echo "📦 Step 5: Creating README for offline development..."

cat > "$VENDOR_DIR/README-OFFLINE-DEV.md" << EOF
# Keep Offline Development Environment

This directory contains all dependencies and scripts needed for fully offline development of the Keep monorepo.

## Contents

- \`python-packages/\` - All Python dependencies (pip packages)
- \`npm-cache/\` or \`pnpm-store/\` - Node.js package cache
- \`node_modules.tar.gz\` - Pre-built Node.js dependencies (if using npm)
- \`state/\` - Persistent application state (database, configs)
- \`requirements.txt\` - Python requirements file
- \`offline-dev-config.env\` - Configuration for offline development

## Scripts

- \`start-offline-dev.sh\` - Start the offline development environment
- \`stop-offline-dev.sh\` - Stop the offline development environment

## Usage

### Starting Development Environment

\`\`\`bash
# From the repository root
./vendor/start-offline-dev.sh
\`\`\`

### Manual Docker Compose

\`\`\`bash
# From the repository root
docker-compose -f docker-compose.offline-dev.yml up --build
\`\`\`

### Accessing Services

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8080  
- **WebSocket**: http://localhost:6001

### Hot Reload

Both Python backend and Node.js frontend support hot reload:

- **Backend**: Changes to Python files will automatically restart the server
- **Frontend**: Changes to React/TypeScript files will trigger hot module replacement

### Package Manager

This environment was prepared using: **$PACKAGE_MANAGER**

## Updating Dependencies

To update dependencies for offline use, run the preparation script again:

\`\`\`bash
./scripts/prepare-offline-deps.sh
\`\`\`

## Troubleshooting

### Container Issues

\`\`\`bash
# Rebuild containers
docker-compose -f docker-compose.offline-dev.yml build --no-cache

# View logs
docker-compose -f docker-compose.offline-dev.yml logs -f
\`\`\`

### Dependency Issues

\`\`\`bash
# Clear all caches and rebuild
docker-compose -f docker-compose.offline-dev.yml down -v
./scripts/prepare-offline-deps.sh
./vendor/start-offline-dev.sh
\`\`\`

EOF

echo "✅ Offline development environment prepared successfully!"
echo ""
echo "📁 Dependencies stored in: $VENDOR_DIR"
echo "🚀 To start development: ./vendor/start-offline-dev.sh"
echo "📚 Read more: ./vendor/README-OFFLINE-DEV.md"
echo ""
echo "Next steps:"
echo "1. Review the generated configuration in $VENDOR_DIR/"
echo "2. Start the offline development environment"
echo "3. Access your services at:"
echo "   - Frontend: http://localhost:3000"
echo "   - Backend: http://localhost:8080"
