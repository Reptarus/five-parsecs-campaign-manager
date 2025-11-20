# Five Parsecs Campaign Manager - Project Instructions with MCP-First Development

## 🔴 MANDATORY MCP-FIRST DEVELOPMENT PROTOCOL 🔴

### **CRITICAL DIRECTIVE: Always Use MCP Tools Before Writing Code**
**Every interaction MUST start with MCP tool reconnaissance. Writing code in responses is PROHIBITED when you can edit files directly. This maximizes efficiency and accuracy.**

### **MCP Tool Hierarchy (Use in Order)**
1. **READ** - Always read existing files first: `desktop-commander:read_file`
2. **SEARCH** - Find patterns and dependencies: `desktop-commander:search_code`
3. **EDIT** - Make surgical changes: `desktop-commander:edit_block`
4. **TEST** - Verify changes: `godot:run_project`
5. **TRACK** - Store context: `memory:create_entities`

---

## 📁 **PROJECT CRITICAL PATHS**
```bash
PROJECT_ROOT: C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\
GODOT_CONSOLE: "C:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64_console.exe"
```

### **🔧 MCP Commands for Every Task**
```bash
# ALWAYS START WITH:
desktop-commander:list_directory "$PROJECT_ROOT/src"
desktop-commander:get_file_info [target_file]

# NEVER GUESS - ALWAYS VERIFY:
desktop-commander:search_code -path "src" -pattern "class_name.*YourTarget"
desktop-commander:read_multiple_files [related_files]

# EDIT IN PLACE - DON'T RECREATE:
desktop-commander:edit_block -file_path [path] -old_string [exact] -new_string [replacement]
```

---

## 🏗️ PROJECT OVERVIEW WITH MCP VERIFICATION

### **Current Status: BETA_READY (94/100)**
**Last Updated**: 2025-11-20

**Core Rules Comparison Results:**
- Character Creation: 95% complete ✅
- World Phase: 90% complete (all 7 substeps) ✅
- Battle Phase: 50% complete (UIs exist, no orchestration) ⚠️
- Post-Battle: 75% complete ⚠️
- Turn Loop: 60% complete ⚠️

**Critical Gap**: BattlePhase.gd handler MISSING from CampaignPhaseManager
**Estimated to Functional Beta**: 12-17 hours (~60% integration, ~40% new implementation)

### **Production Ready Systems** ✅
- Story Track System (20/20 tests) - `desktop-commander:read_file "src/core/story/StoryTrackSystem.gd"`
- Battle Events System (22/22 tests) - `desktop-commander:read_file "src/core/battle/BattleEventSystem.gd"`
- Digital Dice System - `desktop-commander:read_file "src/core/systems/DiceSystem.gd"`
- Campaign State Manager - `desktop-commander:read_file "src/core/campaign/creation/CampaignCreationStateManager.gd"`

### **Integration Gaps to Functional Beta** ⚠️

**Priority 1: Create BattlePhase Handler** (~3-4 hours) 🔴 CRITICAL
- File: src/core/campaign/phases/BattlePhase.gd (MISSING)
- Wire into CampaignPhaseManager alongside Travel/World/PostBattle handlers
- Connect battle flow: setup → combat → resolution

**Priority 2: Wire Phase Transitions** (~2-3 hours)
- Connect CampaignTurnController signals to phase handlers
- Implement phase-to-phase handoffs
- Test complete turn loop (Travel → World → Battle → Post-Battle)

**Priority 3: Post-Battle Integration** (~2-3 hours)
- Wire PostBattleSequence.gd to loot/injury/advancement systems
- Complete battlefield find processing
- Integrate character recovery and experience distribution

**Priority 4: Fix E2E Test Failures** (~35 min)
- Source: tests/legacy/test_campaign_e2e_workflow.gd
- 2 tests failing (equipment field mismatch)

---

## 📁 ARCHITECTURE WITH MCP INSPECTION

### **Three-Tier Architecture Verification**
```bash
# NEVER assume structure - ALWAYS verify:
desktop-commander:directory_tree "$PROJECT_ROOT/src"
```

### **Directory MCP Commands**
```bash
src/
├── base/              # READ ALL BASE CLASSES FIRST:
│                      desktop-commander:read_multiple_files ["src/base/**/*.gd"]
│
├── core/              # ANALYZE CORE PATTERNS:
│   ├── battle/        # desktop-commander:search_code -path "src/core/battle" -pattern "class_name"
│   ├── campaign/      # desktop-commander:search_code -path "src/core/campaign" -pattern "extends"
│   ├── story/         # desktop-commander:read_file "src/core/story/StoryTrackSystem.gd"
│   └── systems/       # desktop-commander:read_file "src/core/systems/DiceSystem.gd"
│
├── game/              # CHECK IMPLEMENTATIONS:
│                      desktop-commander:search_code -path "src/game" -pattern "extends Base"
│
├── ui/                # VERIFY SIGNALS:
│                      desktop-commander:search_code -path "src/ui" -pattern "signal.*emit"
│
└── data/              # VALIDATE DATA:
                       desktop-commander:read_multiple_files ["src/data/**/*.json"]
```

---

## 🚀 CODING STANDARDS WITH MCP ENFORCEMENT

### **GDScript 4.4 MCP Workflow**
```bash
# BEFORE writing ANY GDScript:
1. desktop-commander:search_code -pattern "class_name Similar"  # Find patterns
2. desktop-commander:read_file [base_class_path]               # Check inheritance
3. desktop-commander:search_code -pattern "signal.*similar"    # Find signals
4. desktop-commander:edit_block [target_file]                  # Edit in place
5. godot:run_project "$PROJECT_ROOT"                          # Test immediately
```

### **File Operations MCP Commands**
```bash
# Creating new files:
desktop-commander:search_files -pattern "*.tscn"  # Check existing scenes
desktop-commander:write_file [new_file_path]      # Create with proper structure

# Modifying existing files:
desktop-commander:read_file [path] -length 100    # Read context
desktop-commander:edit_block                      # Surgical edits only
desktop-commander:get_file_info [path]           # Verify changes
```

---

## 🎲 FIVE PARSECS IMPLEMENTATION WITH MCP

### **Core Rules Verification**
```bash
# Always verify rule implementations:
desktop-commander:search_code -path "src" -pattern "Core Rules p\."
desktop-commander:search_code -path "src/game" -pattern "FiveParsecs"
desktop-commander:read_file "src/core/systems/DiceSystem.gd"
```

### **Campaign Turn Structure MCP**
```bash
# Check turn implementation:
desktop-commander:search_code -pattern "enum TurnPhase"
desktop-commander:search_code -pattern "UPKEEP|STORY|CAMPAIGN|BATTLE|RESOLUTION"
```

---

## ⚠️ CRITICAL GAPS - MCP REPAIR WORKFLOW

### **Priority 1: Signal Integration**
```bash
# DO NOT write code - EDIT directly:
desktop-commander:read_file "src/ui/screens/campaign/CampaignCreationUI.gd" -offset 1190 -length 50
desktop-commander:search_code -path "src/ui/screens/campaign/panels" -pattern "signal"
desktop-commander:edit_block  # Connect signals directly in file
```

### **Priority 2: Campaign Finalization**
```bash
# Analyze existing implementation:
desktop-commander:read_file "src/ui/screens/campaign/CampaignCreationUI.gd" -offset 1550 -length 100
desktop-commander:search_code -pattern "CampaignFinalizationService"
desktop-commander:edit_block  # Implement finalization
```

---

## 🧪 TESTING WITH MCP

### **Test Discovery & Execution**
```bash
# Find all tests:
desktop-commander:search_files -path "tests" -pattern "*_test.gd"

# Read test patterns:
desktop-commander:read_file [test_file]

# Run tests:
godot:run_project "$PROJECT_ROOT"
godot:get_debug_output
```

### **Coverage Analysis**
```bash
# Check untested code:
desktop-commander:search_code -pattern "class_name" | grep -v test
desktop-commander:search_code -path "src" -pattern "func.*:" | wc -l  # Count functions
```

---

## 🔒 SECURITY WITH MCP VALIDATION

### **Input Validation MCP Check**
```bash
# Audit validation:
desktop-commander:search_code -pattern "validate_.*\(|sanitize"
desktop-commander:search_code -pattern "strip_edges\(\)|escape"
```

### **Save System Security**
```bash
# Check save protection:
desktop-commander:search_code -pattern "FileAccess|DirAccess"
desktop-commander:search_code -pattern "backup|.backup"
```

---

## 🎯 DEVELOPMENT WORKFLOW - MCP MANDATORY

### **Feature Development MCP Process**
```bash
# 1. PLANNING - Read existing implementations:
desktop-commander:search_code -path "src" -pattern [feature_keywords]
desktop-commander:read_multiple_files [related_files]

# 2. DESIGN - Check base classes:
desktop-commander:read_file "src/base/[relevant_base].gd"

# 3. IMPLEMENTATION - Edit in place:
desktop-commander:edit_block [target_file]  # NEVER write code in response

# 4. INTEGRATION - Wire up signals:
desktop-commander:search_code -pattern "connect\(|emit\("
desktop-commander:edit_block  # Connect directly

# 5. TESTING - Run immediately:
godot:run_project "$PROJECT_ROOT"
godot:get_debug_output

# 6. DOCUMENTATION - Update inline:
desktop-commander:edit_block  # Add doc comments

# 7. TRACKING - Store in memory:
memory:create_entities  # Track changes
```

---

## 🚀 PERFORMANCE WITH MCP PROFILING

### **Performance Analysis Commands**
```bash
# Find performance bottlenecks:
desktop-commander:search_code -pattern "for.*in.*for|while.*while"  # Nested loops
desktop-commander:search_code -pattern "Array\[|Dictionary"         # Large collections
desktop-commander:search_code -pattern "_process\(|_physics_process" # Frame updates
```

### **Memory Management Audit**
```bash
# Check for leaks:
desktop-commander:search_code -pattern "new\(\)" | grep -v "queue_free\|free\("
desktop-commander:search_code -pattern "connect\(" | grep -v "disconnect"
```

---

## 📋 UI/UX WITH MCP VERIFICATION

### **Scene Verification**
```bash
# Check all UI scenes:
desktop-commander:search_files -path "src" -pattern "*.tscn"
desktop-commander:search_files -path "src/ui" -pattern "*.gd"

# Verify responsive design:
desktop-commander:search_code -pattern "get_viewport|resize|anchors"
```

---

## 🔮 MCP OPTIMIZATION RULES

### **Token Efficiency Mandates**
1. **NEVER** write >5 lines of code in a response - use `edit_block`
2. **NEVER** recreate entire files - use surgical edits
3. **NEVER** guess file contents - always `read_file` first
4. **NEVER** assume directory structure - always `list_directory`
5. **ALWAYS** chain MCP commands for complex operations

### **MCP Best Practices**
```bash
# Good - Efficient MCP usage:
desktop-commander:read_file [path] -offset 100 -length 50  # Read only what's needed
desktop-commander:edit_block  # Surgical edit
godot:run_project  # Test immediately

# Bad - Wasteful token usage:
"Here's the complete updated file..."  # NEVER DO THIS
"Let me write the implementation..."   # USE EDIT_BLOCK INSTEAD
```

---

## ✅ DEVELOPMENT STATUS WITH MCP TRACKING

### **Memory Integration for Progress**
```bash
# Track project state:
memory:create_entities [{
  "name": "CampaignCreationUI",
  "entityType": "IntegrationGap",
  "observations": ["Signal integration incomplete at line 1200"]
}]

# Query progress:
memory:search_nodes "integration incomplete"
```

### **Ready for Alpha After MCP Fixes**
```bash
# Final verification before alpha:
desktop-commander:search_code -path "src" -pattern "TODO|FIXME"
godot:run_project "$PROJECT_ROOT"  # Full test suite
desktop-commander:search_code -pattern "error\(|Error|crash"
```

---

## 🗺️ FUTURE ENHANCEMENTS ROADMAP

**Based on TODO Audit**: 96 planning TODOs across 34 files (Week 3 Day 5)
**All TODOs Verified**: 100% have meaningful descriptions (no empty/obsolete TODOs found)

### **Component Extraction & Architecture** (11 TODOs)

**WorldPhaseController.gd** - Component extraction planning:
```bash
# Verify current state:
desktop-commander:read_file "src/ui/screens/world/WorldPhaseController.gd" -offset 100 -length 250

# TODOs:
- Initialize CrewTaskComponent, JobOfferComponent, MissionPrepComponent (lines 100, 165)
- Check component completion when extracted (lines 226, 229, 232)
- Implement component signal handlers (lines 284, 289, 294)
- Get results from extracted components (lines 309, 310, 311)
```

**MCP Commands for Component Extraction**:
```bash
# Plan extraction:
desktop-commander:search_code -path "src/ui/screens/world" -pattern "TODO.*component"

# Verify dependencies:
desktop-commander:search_code -path "src" -pattern "CrewTaskComponent|JobOfferComponent|MissionPrepComponent"
```

---

### **Production Monitoring & Configuration** (2 TODOs)

**ProductionMonitoringConfig.gd** - Email alerts and metrics storage:
```bash
# Check monitoring features:
desktop-commander:read_file "src/core/production/ProductionMonitoringConfig.gd" -offset 355 -length 10

# TODOs:
- Implement email alert system (line 358)
- Store metrics for historical analysis (line 362)
```

**MCP Verification**:
```bash
desktop-commander:search_code -path "src/core/production" -pattern "TODO.*monitoring|alert|metrics"
```

---

### **UI/UX Enhancements** (~12 TODOs)

**Dialog & Error Handling**:
- MainMenu.gd:835 - Implement proper error dialog UI
- ErrorDisplay.gd:171 - Export logs functionality
- DiceDisplay.gd:298 - Implement settings dialog
- DiceFeed.gd:338 - Implement settings

**Feature Implementation**:
- ✅ Data Persistence & UI Presentation - Crew data displays correctly (COMPLETED Week 4 Session 2)
- ⚠️ CampaignDashboard.gd:423 - Load campaign data to UI (PARTIAL - crew data working, needs Patrons/Rivals/Rumors scene nodes)
- CampaignDashboard.gd - Add Patrons/Rivals/Rumors labels to HeaderPanel/HBoxContainer (NEW - scene file update needed)
- CrewManagementScreen.gd - Refine UI spacing/layout (NEW - info display cramped, adjust card height/padding)
- CampaignDashboard.gd:411 - Ship management screen
- CampaignCreationUI.gd:1459 - Auto-advance feature (currently disabled)

**MCP Commands**:
```bash
# UI enhancement audit:
desktop-commander:search_code -path "src/ui" -pattern "TODO.*implement|dialog|settings"

# Feature completion check:
desktop-commander:search_code -path "src/ui/screens" -pattern "TODO.*feature"
```

---

### **Battle System Enhancements** (~4 TODOs)

**BattleResolutionUI.gd** - Combat mechanics:
```bash
# Check battle TODOs:
desktop-commander:read_file "src/ui/screens/battle/BattleResolutionUI.gd" -offset 150 -length 170

# TODOs:
- Enhanced crew member display cards (line 156)
- Detailed battle resolution logic (line 285)
- Equipment bonus calculation (line 317)
```

**Combat Systems**:
- combat_log_panel.gd:94 - Entry icon system
- rule_editor_dialog.gd:157 - Form validation
- house_rules_panel.gd:58 - Rule templates loading
- override_controller.gd:104 - Override handling

**MCP Verification**:
```bash
desktop-commander:search_code -path "src/ui/screens/battle" -pattern "TODO"
desktop-commander:search_code -path "src/ui/components/combat" -pattern "TODO.*implement"
```

---

### **Data & Persistence** (~3 TODOs)

**System Integration**:
- DataManager.gd:120 - JSON loading system
- SaveLoadUI.gd:518 - Settings persistence integration
- CharacterInventory.gd:83-84 - Armor and items arrays

**MCP Commands**:
```bash
# Data system check:
desktop-commander:search_code -path "src/core/data" -pattern "TODO.*JSON|load|persist"

# Inventory features:
desktop-commander:read_file "src/core/character/Equipment/CharacterInventory.gd" -offset 80 -length 10
```

---

### **Game Mechanics** (~5 TODOs)

**Job & World Systems**:
- JobSelectionUI.gd:379 - Job difficulty calculation enhancement
- World generation and trait systems

**MCP Verification**:
```bash
desktop-commander:search_code -path "src/ui/screens/world" -pattern "TODO.*difficulty|calculation"
desktop-commander:search_code -path "src/core" -pattern "TODO.*mechanics|rules"
```

---

### **MCP Commands for Roadmap Implementation**

**Track Enhancement Progress**:
```bash
# Memory tracking for feature completion:
memory:create_entities [{
  "name": "Component Extraction Progress",
  "entityType": "Enhancement Roadmap",
  "observations": ["11 TODOs tracked for WorldPhaseController component extraction"]
}]

# Query roadmap status:
memory:search_nodes "enhancement roadmap"
```

**Weekly TODO Audit**:
```bash
# Count remaining TODOs by domain:
desktop-commander:search_code -path "src/ui/screens/world" -pattern "TODO" | wc -l
desktop-commander:search_code -path "src/ui/screens/battle" -pattern "TODO" | wc -l
desktop-commander:search_code -path "src/core/production" -pattern "TODO" | wc -l

# Check for completed work:
desktop-commander:search_code -pattern "TODO.*fix|FIXME" | grep -i "completed|done|fixed"
```

**Priority Matrix** (Week 4-6):
```
HIGH PRIORITY (Week 4):
- Component extraction (11 TODOs) - Architecture improvement
- Battle system enhancements (4 TODOs) - Core gameplay

MEDIUM PRIORITY (Week 5):
- UI/UX enhancements (12 TODOs) - User experience
- Data persistence (3 TODOs) - Save system robustness

LOW PRIORITY (Week 6+):
- Production monitoring (2 TODOs) - Ops features
- Game mechanics refinement (5 TODOs) - Polish
```

---

**⚡ REMEMBER: Every response MUST use MCP tools. Manual code generation is a LAST RESORT only when MCP tools are unavailable. This is not a suggestion - it's a requirement for efficient development. ⚡**

---

**Last Updated**: November 14, 2025 (Week 3 Day 5 - TODO Audit Complete)