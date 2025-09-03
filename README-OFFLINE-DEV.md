# Keep Offline Development Environment

This setup provides a fully offline (air-gapped) development environment for the Keep monorepo, supporting both the Python backend (`keep/`) and Node.js frontend (`keep-ui/`) with hot-reload capabilities.

## 🎯 Features

- ✅ **Fully Air-Gapped**: All dependencies pre-downloaded to `vendor/` directory
- ✅ **Hot Reload**: Both Python backend and React frontend support live reloading
- ✅ **pnpm Support**: Prefers pnpm, falls back to npm if unavailable
- ✅ **Poetry Integration**: Uses existing Poetry configuration
- ✅ **Shared Container**: Single developer image with both environments
- ✅ **Persistent State**: Database and configs persist between runs
- ✅ **WebSocket Support**: Includes real-time features

## 🚀 Quick Start

### 1. Initial Setup (One-time)

```bash
# Make setup script executable and run it
chmod +x scripts/setup-offline-dev.sh
./scripts/setup-offline-dev.sh
```

This will:
- Check Docker prerequisites
- Download all Python and Node.js dependencies
- Create the vendor directory structure
- Generate configuration files and startup scripts

### 2. Start Development Environment

```bash
# Use the generated startup script
./vendor/start-offline-dev.sh

# OR manually with docker-compose
docker-compose -f docker-compose.offline-dev.yml up --build
```

### 3. Access Your Services

- **Frontend**: http://localhost:3000 (Next.js with hot reload)
- **Backend API**: http://localhost:8080 (FastAPI with auto-reload)
- **WebSocket**: http://localhost:6001 (Real-time features)

## 📁 Project Structure

```
keep/                                    # Repository root
├── Dockerfile.offline-dev              # Multi-stage Docker image
├── docker-compose.offline-dev.yml      # Single container setup
├── docker-compose.offline-dev-separate.yml  # Separate containers
├── scripts/
│   ├── prepare-offline-deps.sh         # Download dependencies
│   └── setup-offline-dev.sh           # One-time setup
├── vendor/                             # Generated offline dependencies
│   ├── python-packages/               # Downloaded pip packages
│   ├── npm-cache/ or pnpm-store/      # Node.js package cache
│   ├── node_modules.tar.gz            # Pre-built dependencies
│   ├── state/                          # Persistent app state
│   ├── requirements.txt               # Python requirements
│   ├── offline-dev-config.env         # Configuration
│   ├── start-offline-dev.sh          # Start development
│   ├── stop-offline-dev.sh           # Stop development
│   └── README-OFFLINE-DEV.md          # Vendor directory docs
├── keep/                               # Python backend (subdirectory)
│   ├── pyproject.toml                 # Poetry configuration
│   └── keep-ui/                       # Node.js frontend
│       └── package.json               # Node.js dependencies
└── README-OFFLINE-DEV.md              # This file
```

## 🔧 Configuration Options

### Single Container (Recommended)

Uses `docker-compose.offline-dev.yml` - runs both backend and frontend in one container:

```bash
docker compose -f docker-compose.offline-dev.yml up --build
```

**Pros:**
- Lower resource usage
- Simpler networking
- Faster startup

### Separate Containers

Uses `docker-compose.offline-dev-separate.yml` - separate containers for each service:

```bash
docker compose -f docker-compose.offline-dev-separate.yml up --build
```

**Pros:**
- Better isolation
- Independent scaling
- Easier debugging

## 🛠️ Development Workflow

### Making Changes

1. **Python Backend**: Edit files in `keep/` - uvicorn will auto-reload
2. **Node.js Frontend**: Edit files in `keep-ui/` - Next.js will hot-reload
3. **Dependencies**: Re-run `./scripts/prepare-offline-deps.sh` after adding new packages

### Package Management

The setup automatically detects and uses:
- **pnpm** (preferred) - if available
- **npm** (fallback) - if pnpm is not installed

### Database & State

- **Database**: SQLite stored in `vendor/state/db.sqlite3`
- **Configs**: Persistent files in `vendor/state/`
- **Logs**: Available via `docker-compose logs`

## 🐛 Troubleshooting

### Container Issues

```bash
# View logs
docker-compose -f docker-compose.offline-dev.yml logs -f

# Rebuild containers
docker-compose -f docker-compose.offline-dev.yml build --no-cache

# Clean restart
docker-compose -f docker-compose.offline-dev.yml down -v
./vendor/start-offline-dev.sh
```

### Dependency Issues

```bash
# Refresh all dependencies
./scripts/prepare-offline-deps.sh

# Check vendor directory
ls -la vendor/

# Verify Python packages
ls -la vendor/python-packages/

# Verify Node.js cache
ls -la vendor/npm-cache/ || ls -la vendor/pnpm-store/
```

### Port Conflicts

If ports 3000, 8080, or 6001 are in use:

```bash
# Check what's using the ports
lsof -i :3000
lsof -i :8080
lsof -i :6001

# Stop conflicting services or modify docker-compose.yml ports
```

### Performance Issues

```bash
# Monitor container resources
docker stats

# Check disk space
df -h
du -sh vendor/

# Prune unused Docker resources
docker system prune -a
```

## 🔄 Updating Dependencies

### Python Dependencies

```bash
cd keep/
poetry add <new-package>
poetry lock
cd ../
./scripts/prepare-offline-deps.sh
```

### Node.js Dependencies

```bash
cd keep/keep-ui/
npm install <new-package>
# OR
pnpm add <new-package>
cd ../../
./scripts/prepare-offline-deps.sh
```

## 🏗️ Architecture

### Multi-Stage Docker Build

1. **node-deps**: Downloads and caches Node.js dependencies
2. **python-deps**: Downloads and installs Python dependencies  
3. **final**: Combines both environments with runtime dependencies

### Environment Variables

Key environment variables for development:

```bash
# Python Backend
PYTHONPATH=/app
POSTHOG_DISABLED=true
DATABASE_CONNECTION_STRING=sqlite:////state/db.sqlite3

# Node.js Frontend  
NODE_ENV=development
NEXT_PUBLIC_API_URL=http://localhost:8080
SENTRY_DISABLED=true

# WebSocket
PUSHER_HOST=keep-websocket-server
PUSHER_PORT=6001
```

## 📚 Additional Resources

- **Keep Documentation**: `keep/README.md`
- **Frontend Documentation**: `keep/keep-ui/README.md`
- **Docker Compose Reference**: https://docs.docker.com/compose/
- **Poetry Documentation**: https://python-poetry.org/docs/
- **pnpm Documentation**: https://pnpm.io/

## 🆘 Getting Help

1. Check the logs: `docker-compose logs -f`
2. Verify dependencies: `ls -la vendor/`
3. Rebuild from scratch: `docker-compose build --no-cache`
4. Check Docker resources: `docker system df`

---

**Happy coding! 🚀**
