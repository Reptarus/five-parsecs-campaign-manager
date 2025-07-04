# CLAUDE.md

This file provides comprehensive guidance to Claude Code (claude.ai/code) when working with code in this repository. Follow these protocols for accurate, comprehensive codebase analysis.

## Project Overview

Five Parsecs Campaign Manager is a digital campaign management tool for the "Five Parsecs from Home" tabletop miniatures game. Built with Godot 4.4, it implements the complete Five Parsecs ruleset while maintaining tabletop authenticity.

**Project Status**: Production-ready with 97.7% test success rate (764/782 tests passing)

## Enhanced Analysis Protocols for Claude Code

### Critical: Follow Systematic Investigation Methodology

When analyzing this codebase, use this enhanced protocol to ensure comprehensive and accurate assessment:

#### Phase 1: Comprehensive File Discovery (30% of analysis time)

**REQUIRED: Complete Directory Exploration**
```bash
# ALWAYS explore these directories completely:
src/
├── autoload/           # System initialization and singletons
├── base/              # Foundation classes and interfaces  
├── core/              # Core game systems (EXPLORE ALL SUBDIRECTORIES)
│   ├── battle/        # Combat systems
│   ├── campaign/      # Campaign management (CHECK crew/ subdirectory)
│   ├── character/     # Character systems (CHECK Management/, Generation/)
│   ├── managers/      # System managers
│   ├── systems/       # Core utilities (DiceManager, etc.)
│   └── utils/         # Core utilities
├── game/              # Five Parsecs specific implementations
├── ui/screens/        # User interface (EXPLORE ALL SUBDIRECTORIES)
│   ├── campaign/      # Campaign UI
│   ├── crew/          # Crew creation UI
│   ├── character/     # Character UI
│   └── */             # All other UI screens
├── utils/             # Universal safety systems
└── data/              # JSON data files
```

**File Discovery Checklist - MUST VERIFY:**
- [ ] Found all *Manager.gd files (CharacterManager, CampaignManager, etc.)
- [ ] Located all *Creation.gd files (CrewCreation, CharacterCreation, etc.)  
- [ ] Identified all *Generation.gd files (CharacterGeneration, etc.)
- [ ] Found UI to logic connections (*UI.gd files)
- [ ] Located Base/Core/Game layer inheritance chains
- [ ] Identified Universal*.gd utility systems
- [ ] Found GlobalEnums.gd and configuration files

#### Phase 2: Architectural Pattern Recognition (25% of analysis time)

**ALWAYS Identify These Architectural Patterns:**
1. **Three-Tiered Architecture**: Base → Core → Game layer separation
2. **Universal Safety System**: Crash prevention in src/utils/
3. **Manager Pattern**: Cross-system communication via GameStateManager
4. **Autoload System**: Singleton initialization and dependency injection
5. **Signal-Based Architecture**: Observer pattern with UniversalSignalManager
6. **Inheritance Hierarchies**: Character.gd → FPCM_Character.gd → CoreCharacter.gd

**Quality Indicators to Assess:**
- [ ] Consistent naming conventions (PascalCase, Manager suffixes)
- [ ] Universal safety utilities for crash prevention
- [ ] Comprehensive error handling and graceful degradation
- [ ] Manager registration system for cross-system communication
- [ ] Signal safety with context and validation
- [ ] Resource loading with fallbacks and protection

#### Phase 3: Cross-File Integration Analysis (25% of analysis time)

**Integration Mapping Protocol:**
1. **Trace Inheritance Chains**: Follow extends and class_name declarations
2. **Map Signal Connections**: Find signal definitions and .connect() calls
3. **Analyze Data Flow**: UI → Validation → Processing → Storage
4. **Check Manager Registration**: How systems communicate via GameStateManager
5. **Verify Resource Loading**: UniversalResourceLoader patterns and dependencies

**Integration Gap Detection:**
- [ ] UI components without backend logic connections
- [ ] Incomplete signal wiring between components
- [ ] Missing data validation or transformation steps
- [ ] Broken or incomplete inheritance chains
- [ ] Resource loading without proper fallbacks

#### Phase 4: Accuracy Calibration (20% of analysis time)

**BEFORE concluding analysis, verify:**
- [ ] Explored src/core/ completely (all subdirectories)
- [ ] Found sophisticated systems like CrewCreation.gd (200+ lines)
- [ ] Identified comprehensive architectures like CampaignCreationUI.gd
- [ ] Assessed Universal Safety System sophistication
- [ ] Balanced bug identification with architectural strength recognition
- [ ] Calibrated completeness assessment based on actual file discovery

**Avoid These Common Assessment Errors:**
❌ Underestimating system complexity
❌ Missing nested critical files in subdirectories
❌ Focusing only on bugs without recognizing architectural sophistication
❌ Surface-level analysis without cross-file integration understanding
❌ Incomplete exploration leading to inaccurate completeness assessments

## Development Commands

### Testing
```bash
# Run all tests using gdUnit4
godot --headless --run-tests

# Run tests through build script
godot -s build.gd --run-tests

# Run specific test suite (from within Godot editor)
# Navigate to: Tests -> Run specific test file
```

### Build & Export
```bash
# Build project with validation
godot -s build.gd

# Export for platforms (configured presets: Windows, macOS, Linux, Android, iOS, Web)
godot --export-release "Windows Desktop" builds/windows/FiveParsecsManager.exe
godot --export-release "Linux/X11" builds/linux/FiveParsecsManager.x86_64
```

### Development Tools
```bash
# Run project in debug mode
godot --debug

# Enable verbose output
godot --verbose

# Run headless for CI/CD
godot --headless
```

### MCP Integration (Enhanced Workflow)
```bash
# Quick MCP interface for Obsidian and Desktop Commander integration
./scripts/mcp.sh help

# Document rule implementations
./scripts/mcp.sh rules document "Rule Name" "Implementation details"

# Search documentation
./scripts/mcp.sh obsidian search "query"

# Build and test through MCP
./scripts/mcp.sh build
./scripts/mcp.sh test

# See docs/MCP_Integration.md for complete guide
```

## Architecture Overview

### Three-Tiered System Architecture
1. **Base Layer** (`src/base/`) - Abstract foundation classes and interfaces
2. **Core Layer** (`src/core/`) - Core game systems and managers
3. **Game Layer** (`src/game/`) - Five Parsecs specific implementations

### Critical Autoload Systems
- **GlobalEnums**: 1120+ enumerations for type safety across all systems
- **GameStateManager**: Campaign state and progression management
- **GameDataManager**: JSON data loading and game content management
- **CharacterManager**: Character creation, advancement, and crew management
- **CampaignManager**: Turn-based campaign progression and rule enforcement
- **DiceManager**: Five Parsecs dice mechanics (2d6/3, d66, d10 combat rolls)
- **BattleStateMachine**: Combat state management and resolution

### Universal Connection Validation System
The project uses a comprehensive crash prevention system located in `src/utils/`. All critical operations use:
- `UniversalNodeAccess.gd` - Safe node operations with null checks
- `UniversalResourceLoader.gd` - Protected resource loading with fallbacks
- `UniversalSignalManager.gd` - Safe signal connections with context
- `UniversalDataAccess.gd` - Protected data structure access

**CRITICAL FOR ANALYSIS**: This Universal Safety System represents sophisticated architectural design that must be recognized and assessed when evaluating system quality.

## Five Parsecs Rules Implementation

### Campaign Turn Structure (Official Rulebook Compliance)
The system implements the exact four-phase structure:
1. **Travel Phase** - Flee invasion, travel events, world arrival
2. **World Phase** - Upkeep, crew tasks (8 types), job offers, equipment, rumors, battle choice
3. **Battle Phase** - Tactical combat with terrain generation
4. **Post-Battle Phase** - 14 sequential steps including rival status, injuries, experience

### Character System
- **Creation Rules**: 2d6÷3 (rounded up) attribute generation, background/motivation tables
- **Character Classes**: Soldier, Scout, Medic, Engineer, Pilot, Merchant, Security, Broker, Bot Tech
- **Species System**: 3 humans + 3 others rule with species-specific bonuses
- **Training Levels**: Pilot, Mechanic, Medical, Security, etc. with mechanical benefits

### Combat Resolution
- **Range Bands**: Point Blank, Short, Medium, Long with modifiers
- **Target Numbers**: Base 4+ on d10 + Combat skill
- **Cover System**: +2 to target number when in cover
- **Critical Hits**: Natural 10 rolls for bonus damage

## Key Development Patterns

### Safe Resource Loading Pattern
```gdscript
# Always use Universal utilities for crash prevention
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")

var GameEnums = UniversalResourceLoader.load_script_safe(
    "res://src/core/systems/GlobalEnums.gd", 
    "Context description"
)
```

### Manager Registration System
```gdscript
# Register managers with GameStateManager for cross-system communication
func _ready() -> void:
    if GameState and GameState.has_method("register_manager"):
        GameState.register_manager("ManagerName", self)
```

### Five Parsecs Dice Patterns
```gdscript
# Standard Five Parsecs dice mechanics
DiceManager.roll_2d6_divided_by_3()  # Attribute generation
DiceManager.roll_d66()               # Table lookups
DiceManager.roll_d10()               # Combat resolution
```

### MCP Integration Pattern
```gdscript
# Document rule implementations from within Godot
MCPBridge.document_character_system("System Name", "Implementation details")
MCPBridge.document_combat_system("Combat Feature", "Five Parsecs compliance notes")
MCPBridge.document_campaign_system("Campaign Feature", "Turn structure implementation")

# Search and create documentation
var mcp = MCPBridge.new()
mcp.search_obsidian_vault("Five Parsecs combat rules")
mcp.create_obsidian_note("Dev Note", "Progress update", "Five Parsecs/Development")
```

## Data Management

### JSON Data Structure
All game data is stored in JSON files under `data/` directory:
- **Character Creation**: `character_creation_data.json`
- **Equipment**: `weapons.json`, `armor.json`, `gear_database.json`
- **Enemies**: `enemy_types.json` with 15+ categories
- **World Generation**: `world_traits.json`, `planet_types.json`
- **Mission Templates**: `mission_templates.json`

### Save System
```gdscript
# Campaign save/load through SaveManager
SaveManagerAutoload.save_campaign(campaign_data, "save_name")
var loaded_data = SaveManagerAutoload.load_campaign("save_name")
```

## Testing Infrastructure

### Test Framework: gdUnit4
- **Unit Tests**: 630+ tests covering individual components
- **Integration Tests**: 74 tests for system interactions
- **Performance Tests**: 41 tests for load and memory validation
- **Mobile Tests**: 15 tests for touch interface compatibility

### Test Organization
```
tests/
├── unit/           # Component-level tests
├── integration/    # System interaction tests
├── performance/    # Load and memory tests
├── mobile/         # Touch interface tests
└── fixtures/       # Test utilities and runners
```

## UI System Architecture

### Responsive Design
- **Mobile Threshold**: 768px width
- **Tablet Threshold**: 1024px width
- **Touch Zones**: Minimum 44x44 points for accessibility
- **Multi-Platform Input**: Touch, mouse, keyboard support

### Scene Router System
The `SceneRouter` autoload manages scene transitions:
```gdscript
SceneRouter.change_scene("res://src/ui/screens/character/CharacterCreation.tscn")
```

## Performance Considerations

### Memory Management
- Object pooling for frequently created entities (bullets, effects)
- Proper cleanup of status effects and temporary objects
- Resource preloading for critical game data

### Frame Rate Targets
- **Desktop**: 60 FPS minimum
- **Mobile**: 30 FPS minimum with 60 FPS preferred
- **Performance Monitoring**: Built-in FPS display in debug builds

## Critical File Dependencies

### Core System Files
- `src/core/systems/GlobalEnums.gd` - Type safety foundation (1120+ lines)
- `src/core/managers/GameStateManager.gd` - Campaign progression control
- `src/core/character/Base/Character.gd` - Character class hierarchy root
- `src/autoload/CoreSystemSetup.gd` - Initialization orchestration

### Character System (MUST ANALYZE COMPLETELY)
- `src/core/character/CharacterGeneration.gd` - Five Parsecs character creation (306 lines)
- `src/core/character/Management/CharacterManager.gd` - Crew management
- `src/core/campaign/crew/CrewCreation.gd` - Comprehensive crew creation system (200+ lines)
- `src/ui/screens/crew/InitialCrewCreation.gd` - UI component for crew creation

### Campaign System (COMPREHENSIVE ANALYSIS REQUIRED)
- `src/ui/screens/campaign/CampaignCreationUI.gd` - Multi-step campaign wizard
- `src/core/campaign/CampaignCreationManager.gd` - Campaign creation logic
- `src/core/campaign/crew/` - Complete crew subsystem (multiple files)

### Universal Utilities (Crash Prevention)
- `src/utils/UniversalNodeAccess.gd`
- `src/utils/UniversalResourceLoader.gd`
- `src/utils/UniversalSignalManager.gd`
- `src/utils/UniversalDataAccess.gd`

## Analysis Quality Assurance

### Before Submitting Analysis, Verify:
- [ ] Explored ALL directories in src/core/ (every subdirectory)
- [ ] Found and analyzed src/core/campaign/crew/CrewCreation.gd
- [ ] Located src/core/character/CharacterGeneration.gd and assessed its sophistication
- [ ] Identified the Universal Safety System and its architectural implications
- [ ] Mapped inheritance hierarchies (Character → FPCM_Character → CoreCharacter)
- [ ] Analyzed cross-file integration between UI and logic systems
- [ ] Assessed system completeness based on comprehensive file discovery
- [ ] Balanced technical issues with architectural strength recognition

### Expected Discovery Metrics:
- **Core System Files**: 50+ files in src/core/ and subdirectories
- **Character System**: 10+ files including generation, management, UI
- **Campaign System**: 15+ files including creation wizard and crew systems
- **UI Components**: 20+ files in src/ui/screens/ and subdirectories
- **Universal Utilities**: 10+ files providing crash prevention and safety

## Development Standards

### Code Style (from .cursor/rules/)
- Strict typing enforced throughout codebase
- Class names use PascalCase with descriptive suffixes
- Full function type annotations required
- Documentation following Five Parsecs rules references

### Signal Safety
All signal connections must use Universal utilities for protection:
```gdscript
UniversalSignalManager.emit_signal_safe(self, "signal_name", [args], "context")
```

### Error Handling
The project uses structured error handling with graceful degradation. Critical system failures are logged with context but don't crash the application.

## Platform Support

**Export Presets Configured**: Windows, macOS, Linux, Android, iOS, Web
**Touch Support**: Enabled for mobile platforms
**Multi-Resolution**: Responsive design scales from mobile to 4K displays

---

## SUCCESS CRITERIA FOR CLAUDE CODE ANALYSIS

A successful analysis of this codebase should:
1. **Discover 95%+ of relevant implementation files** through systematic exploration
2. **Recognize architectural sophistication** including Universal Safety System and three-tiered design
3. **Accurately assess system completeness** (typically 90-98% for major systems)
4. **Map cross-file integration** and identify specific gaps vs. sophisticated implementations
5. **Balance bug identification with architectural strength recognition**
6. **Provide specific, actionable recommendations** with correct file paths and line numbers

Remember: This is a sophisticated, production-ready codebase with extensive safety systems and architectural patterns. Comprehensive exploration and analysis is required to provide accurate assessments.