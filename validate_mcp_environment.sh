#!/bin/bash
# MCP Environment Validation & Auto-Fix Script
# Production-ready environment diagnosis and correction

set -euo pipefail

echo "🔧 MCP Production Environment Diagnostic"
echo "========================================"

# Color output for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validation functions
check_python() {
    echo -n "🐍 Python accessibility: "
    if command -v python3 &> /dev/null; then
        PYTHON_PATH=$(which python3)
        PYTHON_VERSION=$(python3 --version)
        echo -e "${GREEN}✓ Found at $PYTHON_PATH ($PYTHON_VERSION)${NC}"
        return 0
    else
        echo -e "${RED}✗ python3 not found in PATH${NC}"
        return 1
    fi
}

check_node() {
    echo -n "📦 Node.js accessibility: "
    if command -v node &> /dev/null; then
        NODE_PATH=$(which node)
        NODE_VERSION=$(node --version)
        echo -e "${GREEN}✓ Found at $NODE_PATH ($NODE_VERSION)${NC}"
        return 0
    else
        echo -e "${RED}✗ node not found in PATH${NC}"
        return 1
    fi
}

check_npx() {
    echo -n "🚀 NPX accessibility: "
    if command -v npx &> /dev/null; then
        NPX_PATH=$(which npx)
        echo -e "${GREEN}✓ Found at $NPX_PATH${NC}"
        return 0
    else
        echo -e "${RED}✗ npx not found in PATH${NC}"
        return 1
    fi
}

check_bridge_directory() {
    echo -n "🌉 Bridge directory: "
    BRIDGE_DIR="/mnt/c/Users/elija/Claude-Bridge-State"
    if [ -d "$BRIDGE_DIR" ]; then
        echo -e "${GREEN}✓ Accessible at $BRIDGE_DIR${NC}"
        
        # Create subdirectories if they don't exist
        mkdir -p "$BRIDGE_DIR/mcp_bridge/requests"
        mkdir -p "$BRIDGE_DIR/mcp_bridge/responses"
        echo "   Created bridge subdirectories"
        return 0
    else
        echo -e "${RED}✗ Not accessible at $BRIDGE_DIR${NC}"
        return 1
    fi
}

check_mcp_packages() {
    echo "📋 MCP Package availability:"
    
    PACKAGES=(
        "@modelcontextprotocol/server-memory@latest"
        "@modelcontextprotocol/server-filesystem@latest" 
        "@wonderwhy-er/desktop-commander@latest"
    )
    
    for package in "${PACKAGES[@]}"; do
        echo -n "   $package: "
        if npx --yes "$package" --version &> /dev/null; then
            echo -e "${GREEN}✓ Available${NC}"
        else
            echo -e "${YELLOW}⚠ Not cached, will download on demand${NC}"
        fi
    done
}

check_python_paths() {
    echo "🔍 Python environment paths:"
    
    PYTHON_PATHS=(
        "/mnt/c/Users/elija/Creative-Tools-MCP/community-mcp-servers/claude-gemini-mcp-slim-main/gemini_mcp_server.py"
        "/mnt/c/Users/elija/AppData/Roaming/Claude/Claude Extensions/ant.dir.cursortouch.windows-mcp/main.py"
    )
    
    for path in "${PYTHON_PATHS[@]}"; do
        echo -n "   $(basename "$path"): "
        if [ -f "$path" ]; then
            echo -e "${GREEN}✓ Found${NC}"
        else
            echo -e "${RED}✗ Missing at $path${NC}"
        fi
    done
}

# Environment fixes
fix_environment() {
    echo -e "\n🛠 Applying Environment Fixes"
    echo "=============================="
    
    # Ensure bridge directory exists with proper structure
    BRIDGE_DIR="/mnt/c/Users/elija/Claude-Bridge-State"
    echo "Creating bridge directory structure..."
    mkdir -p "$BRIDGE_DIR/mcp_bridge/requests"
    mkdir -p "$BRIDGE_DIR/mcp_bridge/responses"
    chmod 755 "$BRIDGE_DIR" "$BRIDGE_DIR/mcp_bridge" "$BRIDGE_DIR/mcp_bridge/requests" "$BRIDGE_DIR/mcp_bridge/responses"
    echo -e "${GREEN}✓ Bridge directory structure created${NC}"
    
    # Test write permissions
    TEST_FILE="$BRIDGE_DIR/mcp_bridge/requests/test_$(date +%s).json"
    if echo '{"test": "validation"}' > "$TEST_FILE" 2>/dev/null; then
        rm "$TEST_FILE"
        echo -e "${GREEN}✓ Bridge directory writable${NC}"
    else
        echo -e "${RED}✗ Bridge directory not writable${NC}"
    fi
}

# Generate configuration validation
validate_mcp_config() {
    echo -e "\n📋 MCP Configuration Validation"
    echo "==============================="
    
    CONFIG_FILE="/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/.mcp.json"
    echo -n "Configuration file: "
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}✓ Found${NC}"
        
        # Validate JSON syntax
        if python3 -m json.tool "$CONFIG_FILE" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Valid JSON syntax${NC}"
        else
            echo -e "${RED}✗ Invalid JSON syntax${NC}"
        fi
    else
        echo -e "${RED}✗ Missing configuration file${NC}"
    fi
}

# Main execution
main() {
    echo "Starting comprehensive MCP environment validation..."
    echo
    
    # Core environment checks
    check_python
    check_node  
    check_npx
    check_bridge_directory
    check_mcp_packages
    check_python_paths
    
    # Apply fixes
    fix_environment
    
    # Configuration validation
    validate_mcp_config
    
    echo -e "\n🎯 Validation Complete"
    echo "====================="
    echo "If all checks show ✓, restart Cursor IDE and test MCP functionality."
    echo "If issues persist, check the debug console for specific error details."
    echo
    echo "Production monitoring command:"
    echo "watch -n 5 'ls -la /mnt/c/Users/elija/Claude-Bridge-State/mcp_bridge/requests/'"
}

main "$@"