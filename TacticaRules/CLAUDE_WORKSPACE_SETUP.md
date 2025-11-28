# Age of Fantasy Digital - Claude Workspace Setup

**Document Version**: 1.0
**Created**: 2024-11-22
**Purpose**: Configure Claude Code workspace for optimal development

---

## Overview

This guide sets up Claude Code with:
- Specialized agents for different development tasks
- CLAUDE.md project instructions
- MCP tool preferences
- Testing constraints
- Project-specific rules

---

## Step 1: Create Project CLAUDE.md

Create `CLAUDE.md` in your project root with this content:

```markdown
# Age of Fantasy Digital - Development Guide

**Project Type**: 3D Tactical Battle Game
**Engine**: Godot 4.3+
**Last Updated**: [DATE]

---

## Project Status

**Phase**: [CURRENT_PHASE]
**Milestone**: [NEXT_MILESTONE]

---

## Directory Structure

```
project_root/
├── src/
│   ├── core/           # Managers and autoloads
│   ├── units/          # Unit scripts
│   ├── terrain/        # Terrain scripts
│   ├── ai/             # AI logic
│   ├── ui/             # UI scripts
│   └── utils/          # Utilities
├── scenes/
│   ├── battle/         # Battle scene
│   ├── units/          # Unit prefabs
│   ├── terrain/        # Terrain pieces
│   ├── ui/             # UI scenes
│   └── effects/        # Visual effects
├── resources/
│   ├── units/          # Unit profiles
│   ├── weapons/        # Weapon profiles
│   └── configurations/ # Settings
├── assets/
│   ├── models/
│   ├── textures/
│   ├── materials/
│   ├── shaders/
│   └── audio/
└── tests/
    ├── unit/
    └── integration/
```

---

## MCP Tool Usage

### Primary Tools (Daily Use)

1. **Desktop Commander** (90% of operations)
   - `read_file` - Always read before editing
   - `edit_block` - Surgical edits with exact string match
   - `search_code` - Find patterns in codebase

2. **Git** (Version control)
   - All changes tracked
   - Descriptive commit messages
   - No force pushes

### Tool Preferences

```
✅ ALWAYS: Desktop Commander for file operations
✅ ALWAYS: Git for version control
✅ ALWAYS: PowerShell for Godot test runner
❌ NEVER: Godot MCP test runner (headless crash)
❌ NEVER: Memory MCP (not needed for this workflow)
```

---

## Testing Infrastructure

### Framework
- **gdUnit4 v6.0.1+**
- **NEVER use --headless flag** (signal 11 crash)
- Max 13 tests per file for stability

### Running Tests

```powershell
# PowerShell command - adjust path as needed
& 'C:\path\to\Godot_console.exe' `
  --path 'C:\path\to\project' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_file.gd `
  --quit-after 60
```

### Test Organization
```
tests/
├── unit/
│   ├── test_combat_resolution.gd
│   ├── test_movement_validation.gd
│   └── test_morale_system.gd
└── integration/
    ├── test_battle_flow.gd
    └── test_turn_sequence.gd
```

---

## Code Standards

### GDScript Style
- Strict typing for all functions
- snake_case for functions/variables
- PascalCase for classes
- UPPER_CASE for constants/enums

```gdscript
# Good
func resolve_combat(attacker: GameBaseUnit, target: GameBaseUnit) -> Dictionary:
    var result: Dictionary = {}
    return result

# Bad
func ResolveCombat(attacker, target):
    var result = {}
    return result
```

### Scene Organization
- Keep hierarchies shallow (max 5 levels)
- Use exported properties for configuration
- Document unusual node structures

### Signal Pattern
- Call down, signal up
- Managers emit signals, UI listens
- No direct cross-manager references

---

## Physics Layers

```
Layer 1: Ground
Layer 2: Units
Layer 3: Terrain
Layer 4: Areas
Layer 5: Selection
Layer 6: Projectiles
```

---

## Development Workflow

### Before Any Edit
1. Read current implementation
2. Understand context
3. Plan surgical edit

### After Any Change
1. Test affected systems
2. Validate with git diff
3. Commit with descriptive message

### Session Start
1. Check current phase status
2. Review recent commits
3. Run test suite

---

## Quick Reference

### Godot Console Path
```
C:\path\to\Godot_console.exe
```

### Project Path
```
C:\path\to\age-of-fantasy-digital
```

### Key Files
- `src/core/BattleManager.gd` - Phase management
- `src/core/CombatManager.gd` - Combat resolution
- `src/units/GameBaseUnit.gd` - Unit behavior
- `resources/units/*.tres` - Unit profiles

---

## Do NOT

- Create Manager/Coordinator classes that just delegate
- Skip testing combat math
- Hardcode values that should be configurable
- Use --headless flag for tests
- Create files under 50 lines (merge instead)

---

## Important Instructions

Do what has been asked; nothing more, nothing less.
NEVER create files unless absolutely necessary.
ALWAYS prefer editing existing files.
NEVER proactively create documentation files unless requested.
```

---

## Step 2: Configure Agents

Create `.claude/agents/` directory with these agent configurations:

### godot-technical-specialist.md

```markdown
# Godot Technical Specialist

Use this agent when implementing Godot 4.x technical solutions including:
- Signal architecture
- UI container systems
- Mobile optimization
- Scene tree organization
- GDScript performance optimization
- 3D physics and raycasting
- Navigation and pathfinding

This agent translates designs into performant Godot implementations.

## Tools Available
All tools (*), focusing on:
- Read, Write, Edit for code
- Bash for testing
- Glob, Grep for searching

## Examples

### Implementing a component from spec
User: "Implement the unit selection system with raycasting"
Agent: Creates SelectionManager.gd with proper physics layers, raycast implementation, and signal architecture.

### Performance optimization
User: "The movement range visualization is causing frame drops"
Agent: Analyzes current implementation, switches to shader-based approach, optimizes draw calls.

### Signal wiring
User: "Connect the combat signals between CombatManager and UI"
Agent: Implements signal connections following call-down-signal-up patterns.
```

### campaign-data-architect.md

```markdown
# Campaign Data Architect

Use this agent when working on:
- Save/load systems
- Data persistence
- Resource schemas
- Unit/weapon profiles
- Migration systems
- State serialization

## Tools Available
All tools (*), focusing on:
- Read, Write, Edit for resources
- Bash for testing save/load

## Examples

### Designing data structures
User: "Create the resource structure for weapon profiles"
Agent: Designs WeaponProfile.gd with appropriate exports, serialization, and validation.

### Save system implementation
User: "Implement battle state saving with unit positions"
Agent: Creates BattleSaveData resource with Vector3 serialization and file I/O.

### Migration between versions
User: "Need to add new fields to UnitProfile without breaking existing saves"
Agent: Implements versioned migration with backwards compatibility.
```

### qa-integration-specialist.md

```markdown
# QA & Integration Specialist

Use this agent when you need:
- Comprehensive testing
- Integration validation
- Quality assurance
- Performance profiling
- Test suite creation

## Tools Available
All tools (*), focusing on:
- Bash for running tests
- Read for analyzing test results
- Write for creating tests

## Examples

### Writing test suites
User: "Create comprehensive tests for the combat resolution system"
Agent: Creates GdUnit4 test suite covering all combat scenarios, edge cases, and rules compliance.

### Validating signal flows
User: "Verify signals between TurnManager and BattleHUD work correctly"
Agent: Creates integration tests and validates connections.

### Performance testing
User: "Ensure 60 FPS with 50 units on battlefield"
Agent: Creates performance benchmarks and identifies bottlenecks.

## Critical Constraints
- NEVER use --headless flag (signal 11 crash)
- Use PowerShell test runner
- Max 13 tests per file
```

### battle-systems-designer.md

```markdown
# Battle Systems Designer

Use this agent when designing:
- Combat mechanics
- Turn structure
- Movement rules
- Morale system
- Special rules implementation

## Tools Available
All tools (*), focusing on:
- Read for understanding rules
- Write/Edit for implementation
- Research for game design patterns

## Examples

### Implementing game rules
User: "Implement the alternating activation turn system"
Agent: Designs TurnManager with proper activation tracking and team switching per AoF rules.

### Balance analysis
User: "Analyze if the combat math matches the tabletop game"
Agent: Reviews implementation against rules document, identifies discrepancies.

### Special rules implementation
User: "Add the Blast special rule for weapons"
Agent: Implements splash damage with proper target selection and partial damage.
```

---

## Step 3: Project Settings

### Allowed Directories
Add to `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allowedDirectories": [
      "C:\\path\\to\\age-of-fantasy-digital"
    ]
  }
}
```

### Auto-Approved Commands
Add patterns for common operations:

```json
{
  "autoApprove": [
    "Bash(git status:*)",
    "Bash(git log:*)",
    "Bash(git diff:*)",
    "Bash(git add:*)",
    "Bash(git commit:*)",
    "Read(*)",
    "Glob(*)",
    "Grep(*)"
  ]
}
```

### Godot Console Command
Add your Godot path:

```json
{
  "autoApprove": [
    "Bash(\"C:\\path\\to\\Godot_console.exe\" --path * --script addons/gdUnit4/bin/GdUnitCmdTool.gd *)"
  ]
}
```

---

## Step 4: Testing Setup

### Install gdUnit4

1. Download from Godot Asset Library or GitHub
2. Enable in Project Settings → Plugins
3. Configure in `res://addons/gdUnit4/plugin.cfg`

### Create Test Template

`tests/unit/test_template.gd`:

```gdscript
class_name TestTemplate
extends GdUnitTestSuite

# Shared test fixtures
var manager: Node

func before_test() -> void:
    # Set up before each test
    manager = Node.new()
    add_child(manager)

func after_test() -> void:
    # Clean up after each test
    manager.queue_free()

func test_example() -> void:
    # Arrange
    var expected = 1

    # Act
    var actual = 1

    # Assert
    assert_int(actual).is_equal(expected)
```

### Test Runner Script

Create `run_tests.ps1`:

```powershell
param(
    [string]$TestFile = "tests/unit/",
    [int]$Timeout = 60
)

$GodotPath = "C:\path\to\Godot_console.exe"
$ProjectPath = "C:\path\to\project"

& $GodotPath `
    --path $ProjectPath `
    --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
    -a $TestFile `
    --quit-after $Timeout
```

---

## Step 5: Workflow Templates

### Starting a New Feature

1. Create todo list for tasks
2. Write failing tests first
3. Implement feature
4. Run tests
5. Commit with descriptive message

### Debugging an Issue

1. Reproduce issue
2. Add diagnostic prints
3. Write test that fails
4. Fix issue
5. Verify test passes
6. Clean up diagnostics
7. Commit

### Code Review Checklist

- [ ] Strict typing on all functions
- [ ] Signals documented
- [ ] Tests written and passing
- [ ] No hardcoded values
- [ ] Physics layers correct
- [ ] No memory leaks (queue_free called)

---

## Quick Start Checklist

### Day 1 Setup

- [ ] Create project directory
- [ ] Copy CLAUDE.md to root
- [ ] Create .claude/agents/ with agent files
- [ ] Configure settings.local.json
- [ ] Install gdUnit4
- [ ] Create test template
- [ ] Verify Godot console path
- [ ] Run first test

### First Session

- [ ] Review ARCHITECTURE_DEEP_DIVE.md
- [ ] Create Battle.tscn basic structure
- [ ] Create BaseUnit.tscn
- [ ] Implement camera controls
- [ ] Test selection system

---

## Troubleshooting

### "Signal 11" Crash During Tests
- Cause: Using --headless flag
- Fix: Use UI mode via PowerShell runner

### "Class not found" Errors
- Cause: Missing class_name declaration
- Fix: Add `class_name ClassName` to script

### Physics Raycast Returns Nothing
- Cause: Wrong collision mask
- Fix: Verify layer configuration matches

### Signals Not Connecting
- Cause: Wrong signal name or missing emit
- Fix: Check signal declarations and emissions

---

## Resources

### Documentation
- [Godot 4.x Documentation](https://docs.godotengine.org/)
- [gdUnit4 Documentation](https://mikeschulze.github.io/gdUnit4/)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)

### Project Documents
- ARCHITECTURE_DEEP_DIVE.md - System design
- SCENE_IMPLEMENTATION_GUIDE.md - How to build scenes
- PROTOTYPE_ROADMAP.md - Development phases
- CODE_TRANSFER_GUIDE.md - Reusable patterns
- TECHNICAL_DECISIONS.md - Key decisions

---

This setup provides a complete development environment optimized for the lessons learned from Five Parsecs development. Adjust paths and preferences as needed for your system.
