#!/bin/bash
set -e

# --- Configuration ---
REPO="kelvonix/kelvonix-agent"
BINARY_NAME="kelvonix-agent"
INSTALL_PATH="/usr/local/bin/$BINARY_NAME"

# --- Argument Parsing ---
TOKEN=""
SERVER=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --token) TOKEN="$2"; shift ;;
        --server) SERVER="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$TOKEN" ] || [ -z "$SERVER" ]; then
    echo "Error: --token and --server are required."
    exit 1
fi

# --- 1. Download Binary ---
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')

echo "⬇️ Finding latest release for $OS ($ARCH)..."
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep "browser_download_url" | grep "$OS" | grep "$ARCH" | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Error: Could not find a matching release asset for $OS-$ARCH."
    exit 1
fi

echo "⬇️ Downloading asset from $DOWNLOAD_URL..."
curl -L "$DOWNLOAD_URL" -o "${BINARY_NAME}.tar.gz"

echo "📦 Extracting..."
tar -xzf "${BINARY_NAME}.tar.gz"
chmod +x "$BINARY_NAME"

echo "🔧 Installing to $INSTALL_PATH..."
sudo mv "$BINARY_NAME" "$INSTALL_PATH"
# Clean up archive
rm "${BINARY_NAME}.tar.gz"

# --- 2. Registration ---
echo "🔑 Registering agent..."
sudo "$INSTALL_PATH" register --token "$TOKEN" --server "$SERVER"

# --- 3. Create Systemd Service ---
echo "⚙️ Creating systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/kelvonix-agent.service > /dev/null
[Unit]
Description=Kelvonix Agent Service
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_PATH
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# --- 4. Start Service ---
echo "🚀 Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable kelvonix-agent
sudo systemctl start kelvonix-agent

echo "✅ Successfully installed, registered, and started Kelvonix Agent!"
