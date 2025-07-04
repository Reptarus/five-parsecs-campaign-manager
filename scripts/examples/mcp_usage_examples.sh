#!/bin/bash
# Five Parsecs MCP Usage Examples
# Demonstrates how to use MCP tools for development workflow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
MCP="$PROJECT_ROOT/scripts/mcp.sh"

echo "Five Parsecs Campaign Manager - MCP Usage Examples"
echo "=================================================="

# Example 1: Document a new rule implementation
echo ""
echo "Example 1: Documenting Character Creation Implementation"
echo "-------------------------------------------------------"
$MCP rules document "Character Creation System" "Implemented Five Parsecs character generation with 2d6÷3 attribute rolls, background tables, and species traits. Located in src/core/character/ with full test coverage."

# Example 2: Search for existing documentation
echo ""
echo "Example 2: Searching for Combat Rules Documentation"
echo "--------------------------------------------------"
$MCP rules search "combat resolution"

# Example 3: Create a development note
echo ""
echo "Example 3: Creating Development Progress Note"
echo "--------------------------------------------"
PROGRESS_NOTE="# Five Parsecs Development Progress $(date +%Y-%m-%d)

## Completed Today
- [ ] Character creation system
- [ ] Combat resolution mechanics
- [ ] Campaign turn structure

## Next Steps
- [ ] Battle event system integration
- [ ] Story track implementation
- [ ] Equipment database expansion

## Issues
- None currently

## Performance Notes
- All tests passing (97.7% success rate)
- Memory usage optimized

Tags: #five-parsecs #development #progress"

$MCP obsidian note "Dev Progress $(date +%Y-%m-%d)" "$PROGRESS_NOTE" "Five Parsecs/Development"

# Example 4: Build and test workflow
echo ""
echo "Example 4: Build and Test Workflow"
echo "----------------------------------"
echo "Building project..."
$MCP build

echo ""
echo "Running tests..."
$MCP test

# Example 5: Search Obsidian for specific game rules
echo ""
echo "Example 5: Searching for Game Rules Reference"
echo "---------------------------------------------"
$MCP obsidian search "Five Parsecs character background"

# Example 6: Export project
echo ""
echo "Example 6: Export Project for Testing"
echo "-------------------------------------"
echo "Note: This would export the project - commented out for demo"
# $MCP export "Windows Desktop"

echo ""
echo "Examples completed! Check your Obsidian vault for new notes."
echo "These tools can be integrated into your development workflow."