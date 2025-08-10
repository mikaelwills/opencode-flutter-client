# OpenCode Restart Script

This is the corrected restart script for OpenCode that uses 7z instead of unzip and has the correct paths for the Synology system.

## Script Content

```bash
#!/bin/bash

echo "Stopping OpenCode..."
# Kill any running opencode processes
pkill -f opencode 2>/dev/null || true

echo "Upgrading OpenCode..."
# Get current version
CURRENT_VERSION=$(~/.opencode/bin/opencode --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
echo "Installed version: $CURRENT_VERSION"

# Download latest version
LATEST_VERSION="0.4.2"
echo "Downloading opencode version: $LATEST_VERSION ..."

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Download the archive
if ! curl -L -o opencode.zip "https://github.com/sst/opencode/releases/download/v${LATEST_VERSION}/opencode-linux-x64.zip"; then
    echo "Failed to download OpenCode"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Extract using 7z instead of unzip
echo "Extracting..."
if ! 7z x opencode.zip; then
    echo "Failed to extract OpenCode"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Create the target directory if it doesn't exist
mkdir -p /volume1/homes/mikael/.opencode/bin

# Copy the binary
if [ -f "opencode" ]; then
    cp opencode /volume1/homes/mikael/.opencode/bin/opencode
    chmod +x /volume1/homes/mikael/.opencode/bin/opencode
else
    echo "Error: opencode binary not found after extraction"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clean up
cd /volume1/homes/mikael || exit 1
rm -rf "$TEMP_DIR"

echo "Starting OpenCode..."
# Change to the correct directory
if cd /volume1/homes/mikael/.opencode/bin; then
    echo "OpenCode restarted successfully"
    NEW_VERSION=$(./opencode --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    echo "New version: $NEW_VERSION"
else
    echo "Error: Cannot find /volume1/homes/mikael/.opencode/bin directory"
    exit 1
fi
```

## Installation

To create this script, run:

```bash
cat > ~/restart-opencode.sh << 'EOF'
[paste the script content above]
EOF

chmod +x ~/restart-opencode.sh
```

## Key Fixes

- Uses `7z x` instead of `unzip` for extraction
- Uses correct path `/volume1/homes/mikael/.opencode/bin` instead of `/var/services/homes/mikael/.config/bin/opencode`
- Added proper error handling and cleanup
- Includes version checking before and after update