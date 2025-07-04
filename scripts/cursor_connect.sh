#!/bin/bash

# Quick Cursor IDE Integration for Five Parsecs Campaign Manager
# Provides real-time error monitoring and IDE integration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔗 Cursor IDE Integration for Five Parsecs Campaign Manager${NC}"
echo "============================================================"

case "$1" in
    "monitor"|"watch")
        echo -e "${GREEN}Starting real-time error monitoring...${NC}"
        python3 "$SCRIPT_DIR/cursor_mcp_bridge.py" monitor --project "$PROJECT_ROOT" --duration 300
        ;;
    
    "errors"|"check"|"status")
        echo -e "${YELLOW}Checking current project status...${NC}"
        python3 "$SCRIPT_DIR/simple_cursor_bridge.py" status --project "$PROJECT_ROOT"
        ;;
    
    "test")
        echo -e "${BLUE}Running quick project test...${NC}"
        python3 "$SCRIPT_DIR/simple_cursor_bridge.py" test --project "$PROJECT_ROOT"
        ;;
    
    "validate")
        echo -e "${GREEN}Validating enhanced character creation system...${NC}"
        python3 "$SCRIPT_DIR/simple_cursor_bridge.py" validate --project "$PROJECT_ROOT"
        ;;
    
    "quick")
        echo -e "${YELLOW}Quick status check...${NC}"
        echo "Files: $(find "$PROJECT_ROOT/src/core/character" -name "*.gd" | wc -l) GDScript files in character system"
        echo "Tests: $(find "$PROJECT_ROOT/tests" -name "*character*" | wc -l) character-related test files"
        echo "Data: $(find "$PROJECT_ROOT/data" -name "*.json" | wc -l) JSON data files"
        
        # Quick error check
        error_output=$(python3 "$SCRIPT_DIR/cursor_mcp_bridge.py" errors --project "$PROJECT_ROOT" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Error monitoring operational${NC}"
        else
            echo -e "${YELLOW}⚠️ Error monitoring may need setup${NC}"
        fi
        ;;
    
    "help"|""|"-h"|"--help")
        echo "Cursor IDE Integration Commands:"
        echo ""
        echo "  monitor/watch     - Start real-time error monitoring (5 min)"
        echo "  errors/check      - Get current error status"
        echo "  test              - Run tests with IDE integration"
        echo "  build             - Build project with error monitoring"
        echo "  validate          - Validate enhanced character creation system"
        echo "  quick             - Quick status overview"
        echo "  help              - Show this help"
        echo ""
        echo "Examples:"
        echo "  ./scripts/cursor_connect.sh monitor   # Start watching for errors"
        echo "  ./scripts/cursor_connect.sh validate  # Check our implementation"
        echo "  ./scripts/cursor_connect.sh quick     # Quick status"
        ;;
    
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Use './scripts/cursor_connect.sh help' for available commands"
        exit 1
        ;;
esac