#!/bin/bash
# Context7 MCP Server Setup for Godot Development
# Integrates Upstash Context7 for persistent context management

set -e

echo "🚀 Setting up Context7 MCP for Godot development..."

# Configuration
PROJECT_ROOT="/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
MCP_SERVERS_DIR="$PROJECT_ROOT/mcp-servers"
CONTEXT7_DIR="$MCP_SERVERS_DIR/context7"

# Create MCP servers directory
mkdir -p "$MCP_SERVERS_DIR"
cd "$MCP_SERVERS_DIR"

# Clone context7 MCP server
echo "📦 Cloning context7 from Upstash..."
if [ ! -d "$CONTEXT7_DIR" ]; then
    git clone https://github.com/upstash/context7.git context7
else
    echo "✅ Context7 already cloned, updating..."
    cd context7
    git pull
    cd ..
fi

# Install dependencies
echo "📦 Installing context7 dependencies..."
cd "$CONTEXT7_DIR"

# Check if package.json exists
if [ -f "package.json" ]; then
    npm install
else
    # Initialize as Node.js MCP server if not already
    npm init -y
    npm install @modelcontextprotocol/sdk axios dotenv
fi

echo "✅ Context7 MCP server setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure Upstash credentials in .env file"
echo "2. Add context7 to Claude Desktop configuration"
echo "3. Test the connection"
