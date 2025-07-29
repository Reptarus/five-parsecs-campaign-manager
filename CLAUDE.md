# Five Parsecs Campaign Manager - Complete Project Knowledge

## ⚠️ CRITICAL PROJECT INFORMATION ⚠️

### 📁 **Project Location**
**Primary Project Path**: `C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\`

### 🛠️ **Godot Console Path**  
**Console Executable**: `"C:\Users\elija\Desktop\GoDot\Godot 4.4\Godot_v4.4.1-stable_win64_console.exe"`

### 🔧 **MCP Tool Usage & Integration**
**ALWAYS Available**: I can use MCP (Model Context Protocol) tools on every single message to:
- Read/write files directly
- Execute commands
- Browse project structure
- Analyze codebase in real-time

#### **Available MCP Servers**
1. **Playwright MCP** (`playwright`): Browser automation and web testing
   - **Use Cases**: UI testing, web scraping, browser automation
   - **Command**: `npx @playwright/mcp@latest`
   - **Integration**: Prefix tools with `mcp__playwright__`

2. **Context7 MCP** (`context7`): Enhanced context management and code analysis
   - **Use Cases**: Advanced code analysis, context-aware development
   - **URL**: `https://mcp.context7.com/mcp`
   - **Integration**: Prefix tools with `mcp__context7__`

3. **Filesystem MCP** (`filesystem`): Enhanced file system operations
   - **Use Cases**: Advanced file operations, directory management
   - **Command**: `npx -y @modelcontextprotocol/server-filesystem@latest`
   - **Integration**: Enhanced file system access for project files

4. **Memory MCP** (`memory`): Persistent memory across sessions
   - **Use Cases**: Session state management, persistent data storage
   - **Command**: `npx -y @modelcontextprotocol/server-memory@latest`
   - **Integration**: Maintain context across development sessions

5. **Everything MCP** (`everything`): File search and indexing
   - **Use Cases**: Fast file search, content indexing, project navigation
   - **Command**: `npx -y @modelcontextprotocol/server-everything@latest`
   - **Integration**: Enhanced project file discovery and search

6. **GitHub MCP** (`github`): GitHub integration and operations
   - **Use Cases**: Repository management, issue tracking, PR operations
   - **Command**: `npx -y @modelcontextprotocol/server-github@latest`
   - **Integration**: Direct GitHub operations from development workflow

7. **Puppeteer MCP** (`puppeteer`): Additional browser automation
   - **Use Cases**: Alternative browser automation, advanced web testing
   - **Command**: `npx -y @modelcontextprotocol/server-puppeteer@latest`
   - **Integration**: Extended browser automation capabilities

#### **MCP Integration Best Practices**
- **Priority**: Always check for MCP tools with `mcp__` prefix before using standard tools
- **Web Operations**: Use Playwright/Puppeteer MCP for browser-based testing and automation
- **Code Analysis**: Leverage Context7 MCP for enhanced semantic code understanding
- **File Operations**: Use Everything MCP for fast file search and Filesystem MCP for advanced operations
- **Session Management**: Use Memory MCP to maintain development context across sessions
- **Repository Operations**: Use GitHub MCP for direct repository management and operations
- **Project Navigation**: Use Everything MCP for enhanced file discovery and content indexing

#### **MCP Tool Activation**
**IMPORTANT**: MCP tools are currently active and available! The following tools are ready for use:
1. **Active MCP Tools**: All 7 MCP servers are configured and working
2. **Tool Prefixes**: Use `mcp__` prefix for MCP tools (e.g., `mcp__playwright__browser_navigate`, `mcp__context7__resolve_library_id`)
3. **Verification**: MCP tools are loaded and functional in current session
4. **Session Management**: Memory MCP maintains context across development sessions

---

## 🏗️ PROJECT OVERVIEW

**Five Parsecs Campaign Manager** is a digital adaptation of the "Five Parsecs from Home" tabletop RPG built in **Godot 4.4**. This is NOT a typical game project - it's a sophisticated **campaign management tool** implementing complex tabletop rules digitally.

### 🎯 **Current Status: 85% Complete**
- ✅ **Architecture**: Enterprise-grade with base/core/game separation
- ✅ **Core Systems**: Story Track (20/20 tests), Battle Events (22/22 tests), Digital Dice System
- ✅ **State Management**: Production-ready CampaignCreationStateManager
- ⚠️ **Integration Gaps**: 15% remaining - signal wire-up and campaign finalization

---

## 📁 ARCHITECTURE & FILE STRUCTURE

### **Three-Tier Architecture**
```
src/
├── base/              # Abstract base classes and interfaces
│   ├── campaign/      # Campaign base classes
│   ├── character/     # Character base classes
│   ├── combat/        # Combat base classes
│   ├── items/         # Item base classes
│   ├── mission/       # Mission base classes
│   ├── ships/         # Ship base classes
│   ├── state/         # State management base classes
│   └── world/         # World base classes
├── core/              # Core systems and managers
│   ├── battle/        # ✅ Battle Events System
│   ├── campaign/      # Campaign management core
│   ├── character/     # Character system core
│   ├── data/          # Data management
│   ├── economy/       # Economic systems
│   ├── equipment/     # Equipment systems
│   ├── story/         # ✅ Story Track System
│   ├── systems/       # ✅ Core game systems (DiceSystem)
│   └── [other dirs]   # Additional core systems
├── game/              # Five Parsecs specific implementations
├── ui/                # User interface components
├── data/              # Data definitions and containers
├── scenes/            # Scene implementations
└── utils/             # Utility functions and helpers
```

### **Key Files Status**
- ✅ `src/core/campaign/creation/CampaignCreationStateManager.gd` - **Enterprise-grade, complete**
- ⚠️ `src/ui/screens/campaign/CampaignCreationUI.gd` - **Needs signal integration**
- ✅ `src/ui/screens/campaign/panels/*.gd` - **All panels emit proper signals**

---

## 🏭 PRODUCTION CONFIGURATION SYSTEM

### **ProductionConfig.gd - Centralized Configuration Management**
```gdscript
# Production-safe configuration with environment detection
const ProductionConfig = preload("res://src/core/config/ProductionConfig.gd")

# Environment-based feature flags
if ProductionConfig.is_production():
    # Production mode - strict validation, no debug features
    enable_strict_validation = true
    show_debug_panels = false
else:
    # Development mode - full debugging capabilities
    enable_debug_logging = true
    show_developer_shortcuts = true

# Production-safe logging
ProductionConfig.log_debug("Debug information", "CampaignCreation")
ProductionConfig.log_error("Critical error occurred", "DataManager")
```

### **Environment Detection**
- **PRODUCTION**: Strict validation, minimal logging, no debug features
- **STAGING**: Moderate logging, validation enabled, limited debug
- **DEVELOPMENT**: Full debug capabilities, extensive logging

### **Configuration Guidelines**
- Never use `const DEBUG_MODE = true` - use ProductionConfig instead
- All validation must run in production (no skip flags)
- Use production-safe logging methods
- Feature flags controlled by environment detection

---

## 🚀 CODING STANDARDS & PATTERNS

### **GDScript Best Practices (Godot 4.4)**
```gdscript
# Strict typing for all variables and functions
class_name CharacterManager
extends RefCounted

# Strongly-typed arrays and collections
var characters: Array[Character] = []
var equipment: Dictionary = {}  # Use sparingly, prefer custom resources

# Function signatures with full type annotations
func create_character(background: CharacterBackground, motivation: CharacterMotivation) -> Character:
    var character := Character.new()
    character.initialize(background, motivation)
    return character

# Use await for async operations
func load_character_data(character_id: String) -> CharacterData:
    var http_request := HTTPRequest.new()
    add_child(http_request)
    http_request.request("api/character/" + character_id)
    
    var response = await http_request.request_completed
    http_request.queue_free()
    return _parse_character_data(response[3])
```

### **File Naming Conventions**
- **Classes**: PascalCase (`CharacterManager.gd`, `CampaignState.gd`)
- **Scene files**: PascalCase (`CharacterCreator.tscn`, `BattleMap.tscn`)
- **Resource files**: snake_case (`character_template.tres`, `weapon_data.res`)
- **Test files**: snake_case with `_test` suffix (`character_manager_test.gd`)
- **Interfaces**: Prefix with `I` (`ICharacter.gd`, `ICampaignPhase.gd`)
- **Enums**: Suffix with `Enums` (`FiveParsecsGameEnums.gd`, `CombatEnums.gd`)

### **Class Naming Patterns**
- **Base classes**: `Base{Type}` (`BaseMission`, `BaseCharacter`)
- **Interfaces**: `I{Type}` (`ICombatable`, `IStorable`)
- **Implementations**: `FiveParsecs{Type}` (`FiveParsecsMission`, `FiveParsecsCharacter`)
- **Managers**: `{Type}Manager` (`CombatManager`, `CampaignManager`)
- **UI Components**: `{Type}Component` (`InventoryComponent`, `CharacterSheet`)

---

## 🎲 FIVE PARSECS IMPLEMENTATION GUIDELINES

### **Core Rules Implementation**
```gdscript
## Character creation following Five Parsecs Core Rules p.12-17
func create_character(background: int, motivation: int, character_class: int) -> Character:
    var character := Character.new()
    
    # Generate attributes using Five Parsecs method (2d6/3 rounded up)
    character.combat = DiceSystem.generate_attribute()
    character.reaction = DiceSystem.generate_attribute()
    character.toughness = DiceSystem.generate_attribute()
    character.savvy = DiceSystem.generate_attribute()
    character.tech = DiceSystem.generate_attribute()
    character.move = DiceSystem.generate_attribute()
    
    # Set health based on toughness (Core Rules p.13)
    character.max_health = character.toughness + 2
    character.current_health = character.max_health
    
    # Apply background and class bonuses
    _apply_background_bonuses(character, background)
    _apply_class_bonuses(character, character_class)
    
    return character
```

### **Campaign Turn Structure**
```gdscript
## Implementation of Five Parsecs campaign turn sequence (Core Rules p.34-52)
class CampaignTurnManager:
    enum TurnPhase {
        UPKEEP,      # Maintenance costs, ship payments
        STORY,       # Story progression and events
        CAMPAIGN,    # Travel, patrons, jobs, world events
        BATTLE,      # Combat encounters
        RESOLUTION   # Injury recovery, loot, advancement
    }
```

### **Dice System Integration**
```gdscript
## Five Parsecs dice patterns implementation
class DiceSystem:
    ## Generate Five Parsecs attribute (2d6/3 rounded up)
    static func generate_attribute() -> int:
        var roll := roll_dice(2, 6)
        return ceili(float(roll) / 3.0)
    
    ## Roll d66 for tables (two d6 read as tens and ones)
    static func d66() -> int:
        var tens := randi() % 6 + 1
        var ones := randi() % 6 + 1
        return tens * 10 + ones
    
    ## Combat resolution d10
    static func d10() -> int:
        return randi() % 10 + 1
```

---

## ⚠️ CRITICAL IMPLEMENTATION GAPS (15% Remaining)

### **Priority 1: Signal Integration (90 minutes)**
**File**: `src/ui/screens/campaign/CampaignCreationUI.gd`
**Issue**: `_connect_panel_signals()` method exists but is empty
**Fix**: Connect panel signals to state manager

### **Priority 2: Campaign Finalization (120 minutes)**
**File**: `src/ui/screens/campaign/CampaignCreationUI.gd`  
**Issue**: `_on_finish_button_pressed()` doesn't create campaigns
**Fix**: Implement complete campaign creation workflow

### **Priority 3: Navigation State Updates (45 minutes)**
**File**: `src/ui/screens/campaign/CampaignCreationUI.gd`
**Issue**: Next/Back buttons don't respect validation
**Fix**: Add `_update_navigation_state()` integration

---

## 🧪 TESTING STANDARDS

### **Testing Framework**: GDUnit4
- **Target Coverage**: 85% overall, 100% for critical paths
- **Current Achievement**: Story Track (20/20), Battle Events (22/22), Digital Dice System (100%)

### **MCP-Enhanced Testing Strategy**
- **UI Testing**: Use Playwright/Puppeteer MCP for browser-based UI testing and validation
- **Code Analysis**: Leverage Context7 MCP for deep semantic test validation
- **File System Testing**: Use Filesystem MCP for advanced file operation testing
- **Integration Testing**: Combine MCP tools with GDUnit4 for comprehensive testing
- **Session Testing**: Use Memory MCP to maintain test context across sessions
- **Repository Testing**: Use GitHub MCP for automated repository validation

### **Test Patterns**
```gdscript
extends GdUnitTestSuite

func test_character_creation_with_valid_background():
    # Arrange
    var background = CharacterBackground.SOLDIER
    var motivation = CharacterMotivation.REVENGE
    var character_manager = CharacterManager.new()
    
    # Act
    var character = character_manager.create_character(background, motivation)
    
    # Assert
    assert_that(character).is_not_null()
    assert_that(character.background).is_equal(background)
    assert_that(character.combat).is_between(2, 6)
```

---

## 🔒 SECURITY & DATA HANDLING

### **Input Validation Pattern**
```gdscript
class InputValidator:
    static func validate_character_name(name: String) -> ValidationResult:
        var result = ValidationResult.new()
        
        if name.length() < 2:
            result.valid = false
            result.error = "Character name must be at least 2 characters"
            return result
        
        # Sanitize for security
        var sanitized = name.strip_edges()
        result.valid = true
        result.sanitized_value = sanitized
        return result
```

### **Save Data Protection**
```gdscript
class SaveManager:
    func save_campaign(campaign: Campaign, file_path: String) -> SaveResult:
        # Validate data before saving
        var validation = CampaignValidator.validate_save_data(campaign)
        if not validation.valid:
            result.success = false
            result.error = validation.error_message
            return result
        
        # Create backup before saving
        if FileAccess.file_exists(file_path):
            var backup_path = file_path + ".backup"
            DirAccess.copy_absolute(file_path, backup_path)
```

---

## 🎯 DEVELOPMENT WORKFLOW

### **Feature Development Process**
1. **Planning**: Review Five Parsecs rules and create implementation plan
2. **Design**: Create base classes and interfaces  
3. **Implementation**: Build core functionality with tests
   - **Use Context7 MCP** for enhanced semantic code analysis
   - **Leverage Playwright MCP** for any UI testing requirements
4. **Integration**: Connect with existing systems
5. **Testing**: Unit, integration, and performance tests
   - **UI Testing**: Use Playwright MCP for browser-based testing
   - **Code Analysis**: Use Context7 MCP for deep semantic validation
6. **Documentation**: Update guides and API documentation
7. **Review**: Code review and quality assurance
8. **Deployment**: Merge and release

### **MCP-Enhanced Development Workflow**
- **Code Analysis**: Always use Context7 MCP for semantic code understanding
- **UI Testing**: Leverage Playwright/Puppeteer MCP for browser automation needs
- **File Operations**: Use Everything MCP for fast file search and Filesystem MCP for advanced operations
- **Session Management**: Use Memory MCP to maintain development context across sessions
- **Repository Operations**: Use GitHub MCP for direct repository management
- **Quality Assurance**: Integrate all MCP tools into testing and validation processes
- **Documentation**: Use MCP tools to generate and maintain accurate documentation

### **Commit Guidelines**
- **Format**: `type(scope): description`
  - `feat(character): add character relationship system`
  - `fix(combat): resolve range calculation bug`
  - `docs(api): update character creation documentation`
  - `refactor(state): improve campaign state validation`
  - `test(battle): add battle event system tests`

---

## 🚀 PERFORMANCE STANDARDS

### **Memory Management**
- **Object pooling** for frequently created objects
- **Resource-based design** with automatic cleanup
- **Signal disconnection** on object destruction
- **Performance target**: 60 FPS on target platforms

### **Async Loading Patterns**
```gdscript
func load_resource_async(path: String) -> Resource:
    ResourceLoader.load_threaded_request(path)
    
    while true:
        var status = ResourceLoader.load_threaded_get_status(path)
        match status:
            ResourceLoader.THREAD_LOAD_LOADED:
                var resource = ResourceLoader.load_threaded_get(path)
                loading_complete.emit(resource)
                return resource
```

---

## 📋 UI/UX STANDARDS

### **Responsive Design**
- Support desktop and mobile targets
- Adaptive layouts for different screen sizes
- Touch-friendly interface elements

### **Accessibility Features**
- Keyboard navigation support
- Screen reader compatibility  
- High contrast mode support
- Proper focus management

---

## 🔧 MCP TOOL INTEGRATION PATTERNS

### **Context7 MCP Usage Examples**
```bash
# Enhanced code analysis and semantic understanding
# Use Context7 MCP for:
# - Deep semantic code analysis
# - Context-aware development suggestions
# - Enhanced code completion and navigation
# - Intelligent refactoring assistance
```

### **Playwright MCP Usage Examples**
```bash
# Browser automation and UI testing
# Use Playwright MCP for:
# - Automated UI testing for web-based campaign tools
# - Browser-based validation of export functionality
# - End-to-end testing of web interfaces
# - Screenshot-based UI regression testing
```

### **MCP Tool Selection Matrix**
| Task Type | Primary Tool | Secondary Tool | Use Case |
|-----------|--------------|----------------|----------|
| Code Analysis | Context7 MCP | Standard Tools | Deep semantic understanding |
| UI Testing | Playwright MCP | Puppeteer MCP | Browser automation and testing |
| File Operations | Everything MCP | Filesystem MCP | Fast search and advanced operations |
| Web Scraping | Playwright MCP | Puppeteer MCP | Dynamic content extraction |
| Documentation | Context7 MCP | Standard Tools | Context-aware documentation |
| Session Management | Memory MCP | Standard Tools | Persistent development context |
| Repository Operations | GitHub MCP | Standard Tools | Direct GitHub integration |
| Project Navigation | Everything MCP | Standard Tools | Enhanced file discovery |

### **MCP Integration Checklist**
- [x] Check for `mcp__` prefixed tools before using standard alternatives
- [x] Use Context7 MCP for complex code analysis tasks
- [x] Leverage Playwright/Puppeteer MCP for browser-based operations
- [x] Use Everything MCP for fast file search and project navigation
- [x] Use Filesystem MCP for advanced file operations
- [x] Use Memory MCP for session management and persistent context
- [x] Use GitHub MCP for repository operations and management
- [x] Combine MCP tools with existing project tools for enhanced functionality
- [x] Document MCP tool usage in commit messages and development notes

### **MCP Command Reference**
```bash
# MCP Server Management
claude mcp list                    # List configured MCP servers
claude mcp add <name> <command>     # Add stdio MCP server
claude mcp add --transport http <name> <url>  # Add HTTP MCP server
claude mcp remove <name>            # Remove MCP server
claude mcp get <name>               # Get MCP server details

# Current Active Configuration
claude mcp list
# playwright: npx @playwright/mcp@latest
# context7: https://mcp.context7.com/mcp (HTTP)
# filesystem: npx -y @modelcontextprotocol/server-filesystem@latest /project/path
# memory: npx -y @modelcontextprotocol/server-memory@latest
# everything: npx -y @modelcontextprotocol/server-everything@latest
# github: npx -y @modelcontextprotocol/server-github@latest
# puppeteer: npx -y @modelcontextprotocol/server-puppeteer@latest
```

### **MCP Tool Usage Examples**
```bash
# Context7 MCP - Enhanced code analysis
mcp__context7__resolve_library_id    # Resolve library IDs for documentation
mcp__context7__get_library_docs      # Get enhanced library documentation

# Playwright MCP - Browser automation
mcp__playwright__browser_navigate    # Navigate to URL
mcp__playwright__browser_click       # Click elements
mcp__playwright__browser_screenshot  # Take screenshots
mcp__playwright__browser_snapshot    # Capture page state

# File Operations - Enhanced project navigation
# Everything MCP provides enhanced file search
# Filesystem MCP provides advanced file operations
# Memory MCP maintains session context
# GitHub MCP provides repository operations
```

---

## 🔮 FUTURE DEVELOPMENT

### **Roadmap Considerations**
- **Modding Support**: Design APIs for community modifications
- **Multiplayer**: Consider architecture for future multiplayer features
- **Mobile Optimization**: Ensure responsive design scales to mobile
- **Accessibility**: Implement comprehensive accessibility features
- **Performance**: Monitor and optimize for lower-end devices
- **Localization**: Prepare string management for multiple languages

---

## ✅ DEVELOPMENT STATUS SUMMARY

### **Production Ready Systems**
- ✅ **Story Track System** (20/20 tests passing)
- ✅ **Battle Events System** (22/22 tests passing)  
- ✅ **Digital Dice System** (Production ready with visual interface)
- ✅ **Campaign Creation State Manager** (Enterprise-grade validation)
- ✅ **Universal Safety Framework** (Runtime error prevention)

### **Integration Required** (15% remaining)
- ⚠️ Signal wire-up in CampaignCreationUI
- ⚠️ Campaign finalization workflow
- ⚠️ Navigation state validation

### **Ready for Alpha Release**
After completing the 3 integration priorities (approximately 4-6 hours of work), the project will be ready for alpha release with:
- Functional campaign creation workflow
- Complete validation and error handling
- Production-ready core systems
- Comprehensive testing coverage

---

**This knowledge base provides complete context for the Five Parsecs Campaign Manager project. All development should follow these established patterns and standards.**