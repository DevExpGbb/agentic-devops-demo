#!/bin/bash
set -euo pipefail

# Check for Docker socket availability
if [ ! -S /var/run/docker.sock ]; then
    echo "⚠️  Warning: Docker socket not found at /var/run/docker.sock"
    echo "   Docker commands may not work. Check devcontainer.json mounts configuration."
fi

# Install Docker CLI if not already present
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker CLI..."
    # Official Docker installation script (recommended by Docker)
    # See: https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    bash /tmp/get-docker.sh
    rm /tmp/get-docker.sh
else
    echo "✓ Docker CLI already installed ($(docker --version))"
fi

# Ensure docker-compose is available (Docker Desktop style)
if ! command -v docker-compose &> /dev/null; then
    echo "📦 Installing Docker Compose standalone..."
    DOCKER_COMPOSE_VERSION="v2.24.0"
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) COMPOSE_ARCH="x86_64" ;;
        aarch64|arm64) COMPOSE_ARCH="aarch64" ;;
        *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
    esac
    curl -fSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    # Verify Docker Compose installation
    if ! docker-compose --version &> /dev/null; then
        echo "❌ Docker Compose installation failed"
        exit 1
    fi
    echo "✓ Docker Compose installed ($(docker-compose --version))"
fi

echo "⚙️  Installing Azure Functions Core Tools..."
# Ensure lsb-release is available
if ! command -v lsb_release &> /dev/null; then
    apt-get update -y && apt-get install -y lsb-release
fi

curl --fail --show-error https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
mv /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
ARCH=$(dpkg --print-architecture)
sh -c "echo \"deb [arch=${ARCH}] https://packages.microsoft.com/debian/\$(lsb_release -rs | cut -d'.' -f 1)/prod \$(lsb_release -cs) main\" > /etc/apt/sources.list.d/dotnetdev.list"
# The following command requires root privileges. The dev container runs as root by default.
apt-get update -y && apt-get install -y azure-functions-core-tools-4
# Verify Azure Functions Core Tools installation
if ! command -v func &> /dev/null; then
    echo "❌ Azure Functions Core Tools installation failed"
    exit 1
fi
echo "✓ Azure Functions Core Tools installed ($(func --version))"

# Validate required directories and files exist
if [ ! -d "api" ]; then
    echo "❌ api directory not found"
    exit 1
fi

if [ ! -f "scripts/setup-local-settings.js" ]; then
    echo "❌ scripts/setup-local-settings.js not found"
    exit 1
fi

echo "📦 Installing npm dependencies..."
npm install || { echo "❌ Failed to install npm dependencies"; exit 1; }
echo "✓ Dependencies installed"

echo "⚙️  Setting up API..."
(cd api && npm install) || { echo "❌ Failed to install API dependencies"; exit 1; }
echo "✓ API dependencies installed"

echo "🔧 Creating local settings..."
(cd api && node ../scripts/setup-local-settings.js) || { echo "❌ Failed to create local settings"; exit 1; }
echo "✓ Local settings created"

echo "✅ Setup complete!"
