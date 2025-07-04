#!/bin/bash
# Five Parsecs MCP Interface - Quick Commands

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MCP_INTERFACE="$SCRIPT_DIR/mcp_interface.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
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

# Check if python is available
if ! command -v python3 &> /dev/null; then
    log_error "Python3 is required but not installed"
    exit 1
fi

# Main command handler
case "$1" in
    "obsidian")
        case "$2" in
            "search")
                if [ -z "$3" ]; then
                    log_error "Usage: mcp obsidian search <query>"
                    exit 1
                fi
                log_info "Searching Obsidian vault for: $3"
                python3 "$MCP_INTERFACE" obsidian-search "$3"
                ;;
            "note")
                if [ -z "$3" ] || [ -z "$4" ]; then
                    log_error "Usage: mcp obsidian note <title> <content> [folder]"
                    exit 1
                fi
                log_info "Creating Obsidian note: $3"
                python3 "$MCP_INTERFACE" obsidian-note "$3" "$4" "$5"
                ;;
            *)
                echo "Obsidian commands:"
                echo "  mcp obsidian search <query>     - Search vault"
                echo "  mcp obsidian note <title> <content> [folder] - Create note"
                ;;
        esac
        ;;
    
    "desktop")
        if [ -z "$2" ]; then
            log_error "Usage: mcp desktop <command> [args...]"
            exit 1
        fi
        log_info "Executing desktop command: $2"
        shift 2
        python3 "$MCP_INTERFACE" desktop-cmd "$@"
        ;;
    
    "rules")
        case "$2" in
            "document")
                if [ -z "$3" ] || [ -z "$4" ]; then
                    log_error "Usage: mcp rules document <rule_name> <implementation>"
                    exit 1
                fi
                log_info "Documenting rule implementation: $3"
                python3 "$MCP_INTERFACE" document-rule "$3" "$4"
                ;;
            "search")
                if [ -z "$3" ]; then
                    log_error "Usage: mcp rules search <term>"
                    exit 1
                fi
                log_info "Searching rules documentation for: $3"
                python3 "$MCP_INTERFACE" search-rules "$3"
                ;;
            *)
                echo "Rules commands:"
                echo "  mcp rules document <name> <impl> - Document rule implementation"
                echo "  mcp rules search <term>          - Search rules documentation"
                ;;
        esac
        ;;
    
    "build")
        log_info "Building Five Parsecs Campaign Manager..."
        python3 "$MCP_INTERFACE" build
        if [ $? -eq 0 ]; then
            log_success "Build completed"
        else
            log_error "Build failed"
            exit 1
        fi
        ;;
    
    "test")
        log_info "Running tests..."
        python3 "$MCP_INTERFACE" test
        if [ $? -eq 0 ]; then
            log_success "Tests completed"
        else
            log_error "Tests failed"
            exit 1
        fi
        ;;
    
    "export")
        PLATFORM="${2:-Windows Desktop}"
        log_info "Exporting for platform: $PLATFORM"
        python3 "$MCP_INTERFACE" export "$PLATFORM"
        if [ $? -eq 0 ]; then
            log_success "Export completed"
        else
            log_error "Export failed"
            exit 1
        fi
        ;;
    
    "help"|"--help"|"-h"|"")
        echo "Five Parsecs Campaign Manager - MCP Interface"
        echo ""
        echo "Usage: mcp <command> [options]"
        echo ""
        echo "Commands:"
        echo "  obsidian search <query>          - Search Obsidian vault"
        echo "  obsidian note <title> <content>  - Create Obsidian note"
        echo "  desktop <command> [args...]      - Execute desktop command"
        echo "  rules document <name> <impl>     - Document rule implementation"
        echo "  rules search <term>              - Search rules documentation"
        echo "  build                            - Build the project"
        echo "  test                             - Run tests"
        echo "  export [platform]                - Export project (default: Windows Desktop)"
        echo "  help                             - Show this help"
        echo ""
        echo "Examples:"
        echo "  mcp obsidian search \"character creation\""
        echo "  mcp rules document \"Combat Resolution\" \"Implemented d10+skill vs target 4+\""
        echo "  mcp build"
        echo "  mcp test"
        echo "  mcp export \"Linux/X11\""
        ;;
    
    *)
        log_error "Unknown command: $1"
        echo "Use 'mcp help' for available commands"
        exit 1
        ;;
esac