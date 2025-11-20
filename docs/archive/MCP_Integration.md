# MCP Integration for Five Parsecs Campaign Manager

This document explains how to use the Model Context Protocol (MCP) integration to enhance your development workflow with Obsidian documentation and Desktop Commander automation.

## Overview

The MCP integration provides:
- **Obsidian MCP**: Direct integration with your Obsidian vault for documentation
- **Desktop Commander**: System-level automation and command execution
- **Five Parsecs Tools**: Specialized tools for game rule documentation and development

## Quick Start

### Command Line Interface

Use the `mcp.sh` script for quick operations:

```bash
# Show help
./scripts/mcp.sh help

# Search Obsidian vault
./scripts/mcp.sh obsidian search "character creation"

# Document a rule implementation
./scripts/mcp.sh rules document "Combat System" "Implemented d10+skill resolution"

# Build project
./scripts/mcp.sh build

# Run tests
./scripts/mcp.sh test
```

### GDScript Integration

Use the `MCPBridge` class from within Godot:

```gdscript
# Create bridge instance
var mcp_bridge = MCPBridge.new()

# Connect signals
mcp_bridge.obsidian_search_completed.connect(_on_search_completed)
mcp_bridge.rule_documented.connect(_on_rule_documented)

# Search Obsidian vault
mcp_bridge.search_obsidian_vault("Five Parsecs combat rules")

# Document rule implementation
mcp_bridge.document_rule_implementation(
    "Character Advancement", 
    "Implemented XP tracking and level-up mechanics per Core Rules p.45"
)

# Quick documentation methods
MCPBridge.document_character_system("Skill System", "Implemented skill checks with d10+skill vs difficulty")
MCPBridge.document_combat_system("Range Calculation", "Implemented point-blank to long range with modifiers")
MCPBridge.document_campaign_system("Turn Structure", "Implemented 4-phase turn: Travel, World, Battle, Resolution")
```

## Available Commands

### Obsidian Commands

#### Search Vault
```bash
./scripts/mcp.sh obsidian search "query"
```
Search your Obsidian vault for content related to Five Parsecs development.

#### Create Note
```bash
./scripts/mcp.sh obsidian note "Title" "Content" "Optional/Folder"
```
Create a new note in your Obsidian vault with structured content.

### Desktop Commands

#### Execute System Command
```bash
./scripts/mcp.sh desktop <command> [args...]
```
Execute any system command through Desktop Commander.

Examples:
```bash
# List project files
./scripts/mcp.sh desktop ls "-la"

# Check Godot version
./scripts/mcp.sh desktop godot "--version"

# Git operations
./scripts/mcp.sh desktop git "status"
```

### Five Parsecs Specific Commands

#### Document Rule Implementation
```bash
./scripts/mcp.sh rules document "Rule Name" "Implementation Details"
```
Create structured documentation for how a Five Parsecs rule was implemented.

#### Search Rule Documentation
```bash
./scripts/mcp.sh rules search "search term"
```
Search existing Five Parsecs rule documentation in your vault.

### Project Commands

#### Build Project
```bash
./scripts/mcp.sh build
```
Build the Five Parsecs Campaign Manager project.

#### Run Tests
```bash
./scripts/mcp.sh test
```
Execute the full test suite using gdUnit4.

#### Export Project
```bash
./scripts/mcp.sh export [platform]
```
Export the project for specified platform (default: Windows Desktop).

Available platforms:
- "Windows Desktop"
- "Linux/X11"
- "macOS"
- "Android"
- "iOS"
- "Web"

## Development Workflow Integration

### 1. Rule Implementation Workflow

When implementing a new Five Parsecs rule:

```bash
# 1. Search existing documentation
./scripts/mcp.sh rules search "combat resolution"

# 2. Implement the rule in code
# ... development work ...

# 3. Document the implementation
./scripts/mcp.sh rules document "Combat Resolution" "
Implemented Five Parsecs combat resolution system:
- Base target number: 4+
- Roll: d10 + Combat skill
- Range modifiers: Point-blank (-1), Short (0), Medium (+1), Long (+2)
- Cover penalty: +2 to target number
- Critical hits on natural 10

Located in src/core/battle/CombatResolver.gd
Tests in tests/unit/battle/test_combat_resolver.gd
"

# 4. Build and test
./scripts/mcp.sh build
./scripts/mcp.sh test
```

### 2. Daily Development Notes

Create daily progress notes:

```bash
./scripts/mcp.sh obsidian note "Five Parsecs Dev $(date +%Y-%m-%d)" "
# Development Progress $(date +%Y-%m-%d)

## Completed
- Character creation system enhancements
- Combat resolution bug fixes
- Test coverage improvements

## In Progress
- Campaign turn automation
- Battle event system integration

## Next Steps
- Story track implementation
- Equipment database expansion

## Performance
- Tests: 764/782 passing (97.7%)
- Build time: ~30 seconds
- Memory usage: Optimized

Tags: #five-parsecs #development #daily-notes
" "Five Parsecs/Development"
```

### 3. Architecture Documentation

Document architectural decisions:

```gdscript
# In your code, use MCPBridge to document architecture
MCPBridge.document_character_system(
    "Three-Tier Architecture", 
    "
    Implemented three-tier system:
    - Base Layer: Abstract interfaces and foundation classes
    - Core Layer: Game logic and system managers  
    - Game Layer: Five Parsecs specific implementations
    
    This ensures clean separation of concerns and maintainability.
    "
)
```

## Configuration

### Python Dependencies

The MCP interface requires Python 3 with standard libraries. No additional packages needed.

### Environment Setup

The scripts automatically detect your Obsidian vault and MCP server paths from your Claude Desktop configuration at:
`/mnt/c/Users/elija/AppData/Roaming/Claude/claude_desktop_config.json`

### Custom Configuration

You can modify the paths in `scripts/mcp_interface.py`:

```python
class MCPInterface:
    def __init__(self):
        self.project_root = Path(__file__).parent.parent
        self.obsidian_vault = Path("your/custom/vault/path")
        # ... other settings
```

## Troubleshooting

### Common Issues

1. **"Python3 not found"**
   ```bash
   # Install Python 3
   sudo apt update && sudo apt install python3
   ```

2. **"MCP server not responding"**
   - Check that Obsidian is running
   - Verify MCP plugin is enabled in Obsidian
   - Check API key in configuration

3. **"Permission denied"**
   ```bash
   # Make scripts executable
   chmod +x scripts/mcp.sh
   chmod +x scripts/examples/mcp_usage_examples.sh
   ```

### Debug Mode

Enable debug output by modifying the Python script:

```python
# Add at top of mcp_interface.py
import logging
logging.basicConfig(level=logging.DEBUG)
```

## Examples

See `scripts/examples/mcp_usage_examples.sh` for comprehensive usage examples.

Run the examples:
```bash
./scripts/examples/mcp_usage_examples.sh
```

## Integration with CLAUDE.md

This MCP integration complements the development commands documented in `CLAUDE.md`:

- Use MCP for documentation and external tool integration
- Use standard commands for core development tasks
- Combine both for a complete development workflow

## Best Practices

1. **Document as you develop**: Use `rules document` immediately after implementing features
2. **Search before implementing**: Use `rules search` to check existing documentation
3. **Daily progress notes**: Create structured daily notes for project tracking
4. **Test integration**: Use `build` and `test` commands as part of your workflow
5. **Architecture documentation**: Use GDScript integration to document decisions in code

This MCP integration transforms your development workflow by seamlessly connecting code development with documentation, system automation, and project management.