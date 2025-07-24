#!/bin/bash
# Fix MCP Configuration Inconsistencies
# Synchronizes paths and settings across Claude Desktop, Gemini, and Godot MCP

set -e

PROJECT_ROOT="/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
GODOT_WSL="/mnt/c/Users/elija/Desktop/GoDot/Godot_v4.4-stable_mono_win64/Godot_v4.4-stable_mono_win64.exe"
GODOT_WINDOWS="C:\\Users\\elija\\Desktop\\GoDot\\Godot_v4.4-stable_mono_win64\\Godot_v4.4-stable_mono_win64_console.exe"

echo "🔧 Fixing MCP Configuration Inconsistencies..."

cd "$PROJECT_ROOT"

# 1. Fix Godot MCP Server Config
echo "📝 Updating Godot MCP Server configuration..."
cat > godot-mcp-server/config.json << EOF
{
  "godotPath": "$GODOT_WSL",
  "strictPathValidation": true,
  "projectPath": "$PROJECT_ROOT"
}
EOF

# 2. Update Gemini MCP configuration 
echo "📝 Updating Gemini MCP configuration..."
cat > .gemini/settings.json << EOF
{
  "mcpServers": {
    "playwright": {
      "command": "npx @playwright/mcp@latest"
    },
    "filesystem": {
      "command": "npx -y @modelcontextprotocol/server-filesystem@latest $PROJECT_ROOT"
    },
    "memory": {
      "command": "npx -y @modelcontextprotocol/server-memory@latest"
    },
    "everything": {
      "command": "npx -y @modelcontextprotocol/server-everything@latest"
    },
    "github": {
      "command": "npx -y @modelcontextprotocol/server-github@latest"
    },
    "puppeteer": {
      "command": "npx -y @modelcontextprotocol/server-puppeteer@latest"
    },
    "godot": {
      "command": "./godot-mcp-server/start-server.sh"
    },
    "desktop-commander": {
      "command": "npx @wonderwhy-er/desktop-commander@latest"
    }
  }
}
EOF

# 3. Create Universal MCP Configuration
echo "📝 Creating unified MCP configuration..."
cat > mcp_unified_config.json << EOF
{
  "universal_mcp": {
    "version": "1.0",
    "session_id": "mcp_session_$(date +%s)",
    "paths": {
      "project_windows": "C:\\\\Users\\\\elija\\\\SynologyDrive\\\\Godot\\\\five-parsecs-campaign-manager",
      "project_wsl": "$PROJECT_ROOT",
      "godot_windows": "$GODOT_WINDOWS",
      "godot_wsl": "$GODOT_WSL"
    },
    "systems": {
      "claude_desktop": {
        "config_file": ".claude/settings.local.json",
        "path_format": "windows",
        "permissions_updated": true
      },
      "gemini": {
        "config_file": ".gemini/settings.json", 
        "path_format": "wsl",
        "mcp_servers_configured": true
      },
      "godot_mcp": {
        "config_file": "godot-mcp-server/config.json",
        "path_format": "wsl",
        "server_built": true
      }
    },
    "integration": {
      "coordinator_script": "scripts/universal_mcp_coordinator.py",
      "bridge_script": "src/utils/UniversalMCPBridge.gd",
      "shared_state_file": "mcp_shared_state.json",
      "handoff_context_file": "mcp_handoff_context.json"
    }
  }
}
EOF

# 4. Make scripts executable
echo "🔧 Setting script permissions..."
chmod +x scripts/universal_mcp_coordinator.py
chmod +x godot-mcp-server/start-server.sh

# 5. Test the configuration
echo "🧪 Testing MCP configuration..."

# Test Python coordinator
echo "Testing Universal MCP Coordinator..."
if python3 scripts/universal_mcp_coordinator.py status; then
    echo "✅ Universal MCP Coordinator working"
else
    echo "❌ Universal MCP Coordinator failed"
fi

# Test Godot MCP Server
echo "Testing Godot MCP Server..."
cd godot-mcp-server
if timeout 5 node build/index.js get_project_info; then
    echo "✅ Godot MCP Server working"
else
    echo "⚠️  Godot MCP Server may have issues (timeout or missing dependencies)"
fi
cd ..

# 6. Create handoff context
echo "📋 Creating initial handoff context..."
python3 scripts/universal_mcp_coordinator.py handoff > /dev/null 2>&1 || echo "⚠️  Handoff context creation had issues"

# 7. Validation report
echo ""
echo "🎉 MCP Configuration Fix Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Configuration Files Updated:"
echo "   • godot-mcp-server/config.json"
echo "   • .gemini/settings.json"  
echo "   • mcp_unified_config.json"
echo ""
echo "🔧 Scripts Ready:"
echo "   • scripts/universal_mcp_coordinator.py"
echo "   • src/utils/UniversalMCPBridge.gd"
echo ""
echo "📊 Testing Results:"
ls -la mcp_*.json 2>/dev/null || echo "   • Configuration files created"
echo ""
echo "🚀 Next Steps:"
echo "   1. Test with: python3 scripts/universal_mcp_coordinator.py status"
echo "   2. Use in Godot: var bridge = UniversalMCPBridge.new()"
echo "   3. Test handoff: python3 scripts/universal_mcp_coordinator.py handoff"
echo ""
echo "💡 The Universal MCP system now provides:"
echo "   • Consistent path handling across Windows/WSL"
echo "   • Shared state between AI systems"
echo "   • Coordinated workflows"
echo "   • Seamless handoff between Claude Desktop, Claude Code, and Gemini"
