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
    sh /tmp/get-docker.sh
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
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

echo "⚙️  Installing Azure Functions Core Tools..."
# Ensure lsb-release is available
if ! command -v lsb_release &> /dev/null; then
    apt-get update -y && apt-get install -y lsb-release
fi

curl --fail --show-error https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
mv /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
sh -c "echo \"deb [arch=amd64] https://packages.microsoft.com/debian/\$(lsb_release -rs | cut -d'.' -f 1)/prod \$(lsb_release -cs) main\" > /etc/apt/sources.list.d/dotnetdev.list"
apt-get update -y && apt-get install -y azure-functions-core-tools-4

echo "📦 Installing npm dependencies..."
npm install

echo "⚙️  Setting up API..."
(cd api && npm install)

echo "🔧 Creating local settings..."
(cd api && node ../scripts/setup-local-settings.js)

echo "✅ Setup complete!"
