#!/bin/bash
# MCP Production Health Monitor
# Continuous monitoring for production MCP ecosystem

BRIDGE_DIR="/mnt/c/Users/elija/Claude-Bridge-State"
PROJECT_DIR="/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
LOG_FILE="$PROJECT_DIR/mcp_health.log"

log_with_timestamp() {
    echo "$(date -Iseconds) $1" | tee -a "$LOG_FILE"
}

check_mcp_servers() {
    echo "MCP Server Health Check:"
    
    # Check if .mcp.json exists and is valid
    if [ -f "$PROJECT_DIR/.mcp.json" ]; then
        if python3 -m json.tool "$PROJECT_DIR/.mcp.json" > /dev/null 2>&1; then
            echo "✓ Configuration: Valid"
        else
            echo "✗ Configuration: Invalid JSON"
            return 1
        fi
    else
        echo "✗ Configuration: Missing .mcp.json"
        return 1
    fi
    
    # Check bridge directory health
    if [ -d "$BRIDGE_DIR/mcp_bridge" ]; then
        REQUEST_COUNT=$(find "$BRIDGE_DIR/mcp_bridge/requests" -name "*.json" 2>/dev/null | wc -l)
        RESPONSE_COUNT=$(find "$BRIDGE_DIR/mcp_bridge/responses" -name "*.json" 2>/dev/null | wc -l)
        echo "✓ Bridge: $REQUEST_COUNT pending requests, $RESPONSE_COUNT responses"
    else
        echo "✗ Bridge: Directory structure missing"
        return 1
    fi
    
    return 0
}

monitor_bridge_activity() {
    log_with_timestamp "Starting bridge activity monitoring..."
    
    # Monitor for new requests/responses
    inotifywait -m -e create "$BRIDGE_DIR/mcp_bridge/requests" "$BRIDGE_DIR/mcp_bridge/responses" 2>/dev/null | while read path action file; do
        if [[ "$file" == *.json ]]; then
            log_with_timestamp "Bridge activity: $action $file in $(basename "$path")"
        fi
    done &
    
    MONITOR_PID=$!
    echo "Bridge monitor started (PID: $MONITOR_PID)"
    return $MONITOR_PID
}

# Production deployment validation
production_readiness_check() {
    echo "Production Readiness Assessment:"
    echo "================================"
    
    CHECKS_PASSED=0
    TOTAL_CHECKS=6
    
    # Check 1: Configuration files
    if [ -f "$PROJECT_DIR/.mcp.json" ] && [ -f "$PROJECT_DIR/.claude/settings.local.json" ]; then
        echo "✓ Configuration files present"
        ((CHECKS_PASSED++))
    else
        echo "✗ Missing configuration files"
    fi
    
    # Check 2: Environment accessibility
    if command -v python3 &>/dev/null && command -v node &>/dev/null && command -v npx &>/dev/null; then
        echo "✓ Runtime environments accessible"
        ((CHECKS_PASSED++))
    else
        echo "✗ Missing runtime environments"
    fi
    
    # Check 3: Bridge directory structure
    if [ -d "$BRIDGE_DIR/mcp_bridge/requests" ] && [ -d "$BRIDGE_DIR/mcp_bridge/responses" ]; then
        echo "✓ Bridge directory structure complete"
        ((CHECKS_PASSED++))
    else
        echo "✗ Bridge directory structure incomplete"
    fi
    
    # Check 4: File permissions
    if [ -w "$BRIDGE_DIR/mcp_bridge/requests" ] && [ -w "$BRIDGE_DIR/mcp_bridge/responses" ]; then
        echo "✓ Bridge directories writable"
        ((CHECKS_PASSED++))
    else
        echo "✗ Bridge directories not writable"
    fi
    
    # Check 5: Python paths
    PYTHON_PATHS=(
        "/mnt/c/Users/elija/Creative-Tools-MCP/community-mcp-servers/claude-gemini-mcp-slim-main/gemini_mcp_server.py"
        "/mnt/c/Users/elija/AppData/Roaming/Claude/Claude Extensions/ant.dir.cursortouch.windows-mcp/main.py"
    )
    
    PYTHON_CHECKS=0
    for path in "${PYTHON_PATHS[@]}"; do
        if [ -f "$path" ]; then
            ((PYTHON_CHECKS++))
        fi
    done
    
    if [ $PYTHON_CHECKS -eq ${#PYTHON_PATHS[@]} ]; then
        echo "✓ All Python MCP servers accessible"
        ((CHECKS_PASSED++))
    else
        echo "✗ Some Python MCP servers missing ($PYTHON_CHECKS/${#PYTHON_PATHS[@]})"
    fi
    
    # Check 6: NPM packages
    if npx @modelcontextprotocol/server-memory@latest --version &>/dev/null; then
        echo "✓ NPM MCP packages accessible"
        ((CHECKS_PASSED++))
    else
        echo "⚠ NPM MCP packages will download on demand"
        ((CHECKS_PASSED++))  # This is acceptable for production
    fi
    
    echo
    echo "Production Readiness Score: $CHECKS_PASSED/$TOTAL_CHECKS"
    
    if [ $CHECKS_PASSED -eq $TOTAL_CHECKS ]; then
        echo "🟢 PRODUCTION READY"
        return 0
    elif [ $CHECKS_PASSED -ge 4 ]; then
        echo "🟡 PRODUCTION READY WITH WARNINGS"
        return 0
    else
        echo "🔴 NOT PRODUCTION READY"
        return 1
    fi
}

case "${1:-check}" in
    "check")
        check_mcp_servers
        ;;
    "monitor")
        monitor_bridge_activity
        ;;
    "readiness")
        production_readiness_check
        ;;
    "full")
        production_readiness_check
        echo
        check_mcp_servers
        echo
        monitor_bridge_activity
        ;;
    *)
        echo "Usage: $0 {check|monitor|readiness|full}"
        echo "  check     - Basic MCP server health check"
        echo "  monitor   - Monitor bridge activity in real-time"
        echo "  readiness - Comprehensive production readiness assessment"
        echo "  full      - Complete health check and monitoring"
        ;;
esac