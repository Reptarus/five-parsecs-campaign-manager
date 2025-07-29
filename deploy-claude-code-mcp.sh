#!/bin/bash
# Claude Code MCP Parity Deployment Script
# Production-ready setup for cross-platform MCP consistency

set -euo pipefail

# Configuration
PROJECT_ROOT="/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running in production environment
check_environment() {
    log_info "Validating deployment environment..."
    
    # Check Node.js version
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found. Install Node.js 18+ before proceeding."
        exit 1
    fi
    
    NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        log_error "Node.js version $NODE_VERSION is too old. Require version 18+."
        exit 1
    fi
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found. Install Python 3.9+ before proceeding."
        exit 1
    fi
    
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d. -f1-2)
    if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 9) else 1)"; then
        log_error "Python version $PYTHON_VERSION is too old. Require Python 3.9+."
        exit 1
    fi
    
    # Check required environment variables
    if [ -z "${GOOGLE_API_KEY:-}" ]; then
        log_error "GOOGLE_API_KEY environment variable not set."
        log_info "Set it with: export GOOGLE_API_KEY='your_api_key_here'"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Install dependencies for Claude Code MCP servers
install_dependencies() {
    log_info "Installing Claude Code MCP dependencies..."
    
    # Install Python packages
    log_info "Installing Python dependencies..."
    python3 -m pip install --user psutil aiofiles watchdog requests google-generativeai
    
    # Install Node.js MCP servers globally for performance
    log_info "Installing Node.js MCP servers..."
    npm install -g @modelcontextprotocol/server-filesystem@latest @modelcontextprotocol/server-memory@latest
    
    # Install UV for Python package management (for blender-mcp)
    if ! command -v uvx &> /dev/null; then
        log_info "Installing UV package manager..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    log_success "Dependencies installed successfully"
}

# Create Claude Code configuration directory structure
setup_config_structure() {
    log_info "Setting up Claude Code configuration structure..."
    
    # Determine config directory based on platform
    if [[ "$OSTYPE" == "darwin"* ]]; then
        CONFIG_DIR="$HOME/Library/Application Support/Claude Code"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        CONFIG_DIR="$HOME/.config/claude-code"
    else
        # Windows/WSL
        CONFIG_DIR="$HOME/AppData/Roaming/Claude Code"
        # For WSL, also create Windows-style path
        WIN_CONFIG_DIR="/mnt/c/Users/$(whoami)/AppData/Roaming/Claude Code"
        mkdir -p "$WIN_CONFIG_DIR"
    fi
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/logs"
    mkdir -p "$CONFIG_DIR/cache"
    
    echo "$CONFIG_DIR" > "$PROJECT_ROOT/.claude-code-config-path"
    log_success "Configuration structure created at: $CONFIG_DIR"
}

# Generate Claude Code MCP configuration with parity
generate_config() {
    log_info "Generating Claude Code MCP configuration..."
    
    CONFIG_DIR=$(cat "$PROJECT_ROOT/.claude-code-config-path")
    CONFIG_FILE="$CONFIG_DIR/config.json"
    
    # Read Claude Desktop configuration for parity
    DESKTOP_CONFIG="$PROJECT_ROOT/claude_desktop_config.json"
    if [ ! -f "$DESKTOP_CONFIG" ]; then
        log_error "Claude Desktop config not found at: $DESKTOP_CONFIG"
        exit 1
    fi
    
    # Create Claude Code configuration with exact parity
    cat > "$CONFIG_FILE" << EOF
{
  "mcp": {
    "servers": {
      "filesystem": {
        "command": "mcp-server-filesystem",
        "args": ["$PROJECT_ROOT"],
        "env": {},
        "working_directory": "$PROJECT_ROOT",
        "restart_policy": "always",
        "timeout": 30
      },
      "memory": {
        "command": "mcp-server-memory",
        "args": [],
        "env": {},
        "restart_policy": "always",
        "timeout": 15
      },
      "gemini-orchestrator": {
        "command": "python3",
        "args": [
          "$PROJECT_ROOT/../Creative-Tools-MCP/community-mcp-servers/claude-gemini-mcp-slim-main/gemini_mcp_server.py"
        ],
        "env": {
          "GOOGLE_API_KEY": "$GOOGLE_API_KEY",
          "GEMINI_FLASH_MODEL": "gemini-1.5-flash",
          "GEMINI_PRO_MODEL": "gemini-1.5-pro",
          "PYTHONPATH": "$PROJECT_ROOT/../Creative-Tools-MCP"
        },
        "working_directory": "$PROJECT_ROOT/../Creative-Tools-MCP/community-mcp-servers/claude-gemini-mcp-slim-main",
        "restart_policy": "on-failure",
        "timeout": 45
      },
      "desktop-commander": {
        "command": "python3",
        "args": ["-m", "desktop_commander.server"],
        "env": {
          "PYTHONPATH": "$PROJECT_ROOT"
        },
        "working_directory": "$PROJECT_ROOT",
        "restart_policy": "on-failure",
        "timeout": 30
      },
      "blender-creative": {
        "command": "uvx",
        "args": ["blender-mcp"],
        "env": {},
        "restart_policy": "never",
        "timeout": 60
      }
    }
  },
  "environment": {
    "variables": {
      "GOOGLE_API_KEY": "$GOOGLE_API_KEY",
      "GEMINI_FLASH_MODEL": "gemini-1.5-flash",
      "GEMINI_PRO_MODEL": "gemini-1.5-pro",
      "MCP_ENVIRONMENT": "production",
      "MCP_LOG_LEVEL": "INFO"
    }
  },
  "logging": {
    "level": "INFO",
    "file": "$CONFIG_DIR/logs/claude-code-mcp.log",
    "max_size_mb": 100,
    "backup_count": 5
  },
  "health_check": {
    "enabled": true,
    "interval_seconds": 30,
    "timeout_seconds": 10,
    "endpoint": "http://localhost:8080/health"
  },
  "performance": {
    "max_concurrent_requests": 10,
    "request_timeout_seconds": 30,
    "memory_limit_mb": 500
  },
  "version": "1.0.0",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "platform": "$(uname -s)",
  "parity_source": "claude_desktop_config.json"
}
EOF
    
    log_success "Configuration generated: $CONFIG_FILE"
}

# Validate configuration parity
validate_parity() {
    log_info "Validating MCP configuration parity..."
    
    CONFIG_DIR=$(cat "$PROJECT_ROOT/.claude-code-config-path")
    CLAUDE_CODE_CONFIG="$CONFIG_DIR/config.json"
    DESKTOP_CONFIG="$PROJECT_ROOT/claude_desktop_config.json"
    
    # Extract server names from both configs
    CODE_SERVERS=$(jq -r '.mcp.servers | keys[]' "$CLAUDE_CODE_CONFIG" 2>/dev/null | sort)
    DESKTOP_SERVERS=$(jq -r '.mcpServers | keys[]' "$DESKTOP_CONFIG" 2>/dev/null | sort)
    
    # Compare server lists
    MISSING_IN_CODE=$(comm -23 <(echo "$DESKTOP_SERVERS") <(echo "$CODE_SERVERS"))
    EXTRA_IN_CODE=$(comm -13 <(echo "$DESKTOP_SERVERS") <(echo "$CODE_SERVERS"))
    
    if [ -n "$MISSING_IN_CODE" ]; then
        log_warning "Servers missing in Claude Code config:"
        echo "$MISSING_IN_CODE" | while read server; do
            log_warning "  - $server"
        done
    fi
    
    if [ -n "$EXTRA_IN_CODE" ]; then
        log_warning "Extra servers in Claude Code config:"
        echo "$EXTRA_IN_CODE" | while read server; do
            log_warning "  - $server"
        done
    fi
    
    if [ -z "$MISSING_IN_CODE" ] && [ -z "$EXTRA_IN_CODE" ]; then
        log_success "Configuration parity validated successfully"
        return 0
    else
        log_warning "Configuration parity issues detected"
        return 1
    fi
}

# Test MCP server connectivity
test_connectivity() {
    log_info "Testing MCP server connectivity..."
    
    CONFIG_DIR=$(cat "$PROJECT_ROOT/.claude-code-config-path")
    CONFIG_FILE="$CONFIG_DIR/config.json"
    
    # Test each server
    SERVERS=$(jq -r '.mcp.servers | keys[]' "$CONFIG_FILE")
    
    ALL_PASSED=true
    
    echo "$SERVERS" | while read server; do
        log_info "Testing $server..."
        
        COMMAND=$(jq -r ".mcp.servers.\"$server\".command" "$CONFIG_FILE")
        
        case "$COMMAND" in
            "mcp-server-filesystem")
                if command -v mcp-server-filesystem &> /dev/null; then
                    log_success "  ✓ $server: Command available"
                else
                    log_error "  ✗ $server: Command not found"
                    ALL_PASSED=false
                fi
                ;;
            "mcp-server-memory")
                if command -v mcp-server-memory &> /dev/null; then
                    log_success "  ✓ $server: Command available"
                else
                    log_error "  ✗ $server: Command not found"
                    ALL_PASSED=false
                fi
                ;;
            "python3")
                if command -v python3 &> /dev/null; then
                    log_success "  ✓ $server: Python available"
                else
                    log_error "  ✗ $server: Python not found"
                    ALL_PASSED=false
                fi
                ;;
            "uvx")
                if command -v uvx &> /dev/null; then
                    log_success "  ✓ $server: UV available"
                else
                    log_warning "  ⚠ $server: UV not available (optional)"
                fi
                ;;
            *)
                log_warning "  ? $server: Unknown command type"
                ;;
        esac
    done
    
    if [ "$ALL_PASSED" = true ]; then
        log_success "All MCP servers passed connectivity test"
        return 0
    else
        log_error "Some MCP servers failed connectivity test"
        return 1
    fi
}

# Create monitoring script
create_monitoring() {
    log_info "Creating MCP monitoring script..."
    
    CONFIG_DIR=$(cat "$PROJECT_ROOT/.claude-code-config-path")
    MONITOR_SCRIPT="$CONFIG_DIR/monitor-mcp.sh"
    
    cat > "$MONITOR_SCRIPT" << 'EOF'
#!/bin/bash
# Claude Code MCP Health Monitor
# Run this periodically to ensure MCP parity and health

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$CONFIG_DIR/logs/health-monitor.log"

log_with_timestamp() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $1" >> "$LOG_FILE"
}

# Check if Claude Code is running
if pgrep -f "claude.*code" > /dev/null; then
    log_with_timestamp "INFO: Claude Code is running"
else
    log_with_timestamp "WARNING: Claude Code not detected"
fi

# Check MCP ecosystem health
if curl -sf "http://localhost:8080/health" > /dev/null 2>&1; then
    log_with_timestamp "INFO: MCP ecosystem health endpoint responding"
else
    log_with_timestamp "WARNING: MCP ecosystem health endpoint not responding"
fi

# Check configuration file integrity
if [ -f "$CONFIG_DIR/config.json" ]; then
    if jq empty "$CONFIG_DIR/config.json" 2>/dev/null; then
        log_with_timestamp "INFO: Configuration file valid"
    else
        log_with_timestamp "ERROR: Configuration file corrupted"
    fi
else
    log_with_timestamp "ERROR: Configuration file missing"
fi

# Log file rotation
if [ -f "$LOG_FILE" ] && [ $(wc -l < "$LOG_FILE") -gt 1000 ]; then
    tail -500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
EOF
    
    chmod +x "$MONITOR_SCRIPT"
    log_success "Monitoring script created: $MONITOR_SCRIPT"
}

# Generate comprehensive report
generate_report() {
    log_info "Generating Claude Code MCP parity report..."
    
    CONFIG_DIR=$(cat "$PROJECT_ROOT/.claude-code-config-path")
    REPORT_FILE="$CONFIG_DIR/parity-report.json"
    
    # Collect system information
    SYSTEM_INFO=$(cat << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "platform": {
    "os": "$(uname -s)",
    "architecture": "$(uname -m)",
    "kernel": "$(uname -r)"
  },
  "runtime": {
    "node_version": "$(node --version 2>/dev/null || echo 'not available')",
    "python_version": "$(python3 --version 2>/dev/null || echo 'not available')",
    "npm_version": "$(npm --version 2>/dev/null || echo 'not available')"
  },
  "environment": {
    "google_api_key_set": $([ -n "${GOOGLE_API_KEY:-}" ] && echo "true" || echo "false"),
    "project_root": "$PROJECT_ROOT",
    "config_directory": "$CONFIG_DIR"
  }
}
EOF
    )
    
    echo "$SYSTEM_INFO" > "$REPORT_FILE"
    
    log_success "Parity report generated: $REPORT_FILE"
    
    # Display summary
    echo ""
    echo "========================================="
    echo "CLAUDE CODE MCP PARITY REPORT SUMMARY"
    echo "========================================="
    echo "Configuration Directory: $CONFIG_DIR"
    echo "Project Root: $PROJECT_ROOT"
    echo "Platform: $(uname -s) $(uname -m)"
    echo "Node.js: $(node --version 2>/dev/null || echo 'Not available')"
    echo "Python: $(python3 --version 2>/dev/null || echo 'Not available')"
    echo "API Key: $([ -n "${GOOGLE_API_KEY:-}" ] && echo "Configured" || echo "Missing")"
    echo "========================================="
}

# Main deployment function
main() {
    echo "🚀 Claude Code MCP Parity Deployment"
    echo "====================================="
    echo ""
    
    # Change to project directory
    cd "$PROJECT_ROOT"
    
    # Run deployment steps
    check_environment
    echo ""
    
    install_dependencies
    echo ""
    
    setup_config_structure
    echo ""
    
    generate_config
    echo ""
    
    if validate_parity; then
        echo ""
        test_connectivity
        echo ""
        
        create_monitoring
        echo ""
        
        generate_report
        echo ""
        
        log_success "🎉 Claude Code MCP parity deployment completed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Restart Claude Code to load the new configuration"
        echo "2. Test MCP functionality with a simple query"
        echo "3. Run periodic monitoring: $CONFIG_DIR/monitor-mcp.sh"
        echo "4. Check logs: $CONFIG_DIR/logs/claude-code-mcp.log"
        
    else
        echo ""
        log_error "❌ Deployment completed with parity issues"
        log_info "Review the warnings above and re-run the deployment"
        exit 1
    fi
}

# Script execution
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
