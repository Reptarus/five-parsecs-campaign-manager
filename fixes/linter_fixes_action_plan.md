# Five Parsecs Campaign Manager - Linter Error Resolution Plan

## Executive Summary
Systematic approach to resolve 200+ GDScript linter errors across 6 core files. Priority-based fixing strategy focusing on type safety, code quality, and maintainability.

## Error Categories & Priorities

### 🔴 CRITICAL (Severity 8) - Compilation Blockers
- **Missing Type Definitions**: `FPCM_UnifiedTerrainSystem`, `FPCM_PreBattleUI` 
- **Undefined Identifiers**: `UniversalNodeValidator` import issues
- **Type Mismatches**: Property access on `int` types instead of objects

### 🟡 HIGH (Code 9, 15, 17, 18) - Type Safety & Architecture  
- **Shadowed Global Identifiers**: Constants conflicting with global classes
- **Untyped Declarations**: Variables missing explicit type annotations
- **Unsafe Method/Property Access**: Dynamic typing causing runtime risks

### 🟢 MEDIUM (Code 2, 5, 6, 22) - Code Quality
- **Unused Code**: Variables, parameters, signals
- **Discarded Return Values**: Ignored function results
- **Dead Code**: Unreachable statements

## Phase 1: Type System Foundation (Priority 1)

### 1.1 Fix Missing Type Definitions

**Problem**: Classes referenced with FPCM_ prefix don't exist
**Root Cause**: Naming convention inconsistency

**Solution**: Create type aliases or fix references

```gdscript
# Option A: Create type aliases in a central types file
# res://src/core/types/TypeAliases.gd
class_name FPCM_Types

# Type aliases for consistency
typedef FPCM_UnifiedTerrainSystem = UnifiedTerrainSystem
typedef FPCM_PreBattleUI = PreBattleUI
typedef FPCM_CampaignManager = CampaignManager

# Option B: Fix references directly (RECOMMENDED)
# Change: var _terrain_system_script: FPCM_UnifiedTerrainSystem
# To:     var _terrain_system_script: UnifiedTerrainSystem
```

### 1.2 Fix ErrorDisplay.gd Type Issues

**Problem**: Accessing properties on `int` instead of error objects
**Root Cause**: Generic array/dictionary handling

**Solution**: Strongly type error structures

```gdscript
# Create proper error class structure
class_name GameError extends RefCounted

var _id: String
var timestamp: float
var category: ErrorCategory
var severity: ErrorSeverity
var message: String
var context: Dictionary = {}
var stack_trace: PackedStringArray = []
var resolved: bool = false
var resolution_timestamp: float = 0.0
var resolution_notes: String = ""

enum ErrorCategory { SYSTEM, VALIDATION, NETWORK, USER_INPUT }
enum ErrorSeverity { INFO, WARNING, ERROR, CRITICAL }
```

## Phase 2: Type Safety Implementation (Priority 2)

### 2.1 Add Explicit Type Annotations

**Strategy**: Convert all `var` declarations to strongly typed equivalents

```gdscript
# Before (Problematic)
var progress_percent = float(current_step) / float(total_steps) * 100.0
var tween = create_tween()
var errors = ErrorLogger.get_active_errors()

# After (Type Safe)  
var progress_percent: float = float(current_step) / float(total_steps) * 100.0
var tween: Tween = create_tween()
var errors: Array[GameError] = ErrorLogger.get_active_errors()
```

### 2.2 Resolve Shadowed Global Identifiers

**Problem**: Constants mask global class names
**Solution**: Rename with prefixes or use different approach

```gdscript
# Before (Conflicting)
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Mission = preload("res://src/core/systems/Mission.gd")

# After (Resolved)
const CharacterManager = preload("res://src/core/character/Management/CharacterDataManager.gd")
const MissionSystem = preload("res://src/core/systems/Mission.gd")
# OR use different import strategy
const Imports = {
    "Character": preload("res://src/core/character/Management/CharacterDataManager.gd"),
    "Mission": preload("res://src/core/systems/Mission.gd")
}
```

## Phase 3: Method Safety & Architecture (Priority 3)

### 3.1 Fix Unsafe Method Access

**Pattern**: Replace dynamic calls with proper interfaces

```gdscript
# Before (Unsafe)
if component.has_method("setup_preview"):
    component.setup_preview()

# After (Type Safe)
if component is PreviewableComponent:
    component.setup_preview()
# OR use interfaces
if component.implements_preview():
    component.setup_preview()
```

### 3.2 Implement Proper Signal Handling

**Strategy**: Check connections before using signals

```gdscript
# Safe signal connection pattern
func connect_campaign_signals(manager: Node) -> void:
    if not manager.has_signal("creation_step_changed"):
        push_error("Manager missing required signal: creation_step_changed")
        return
    
    var result := manager.creation_step_changed.connect(_on_creation_step_changed)
    if result != OK:
        push_error("Failed to connect creation_step_changed signal")
```

## Phase 4: Code Quality & Cleanup (Priority 4)

### 4.1 Remove Unused Code

**Automated approach**: Use regex patterns to identify and remove

```bash
# Find unused variables pattern
grep -r "var.*=.*" --include="*.gd" | grep "_.*:" 

# Find unused parameters  
grep -r "func.*unused_param" --include="*.gd"
```

### 4.2 Handle Return Values Properly

**Strategy**: Either use return values or explicitly discard

```gdscript
# Before (Warning)
button.connect("pressed", _on_button_pressed)

# After (Explicit)  
var _connection_result := button.connect("pressed", _on_button_pressed)
# OR if intentionally ignored
var _ignored := button.connect("pressed", _on_button_pressed)
# OR suppress with void
button.connect("pressed", _on_button_pressed) # @warning_ignore:return_value_discarded
```

## Implementation Timeline

### Week 1: Foundation
- [ ] Create type system foundations
- [ ] Fix all severity 8 errors (compilation blockers)
- [ ] Establish proper import/export patterns

### Week 2: Type Safety  
- [ ] Add explicit type annotations (batch process)
- [ ] Resolve shadowed identifiers
- [ ] Implement safe method access patterns

### Week 3: Quality & Polish
- [ ] Remove unused code  
- [ ] Fix return value handling
- [ ] Add proper error handling

### Week 4: Validation & Documentation
- [ ] Run full linter validation
- [ ] Update development guidelines
- [ ] Create type safety standards document

## Tools & Automation

### 1. Regex Patterns for Batch Fixes
```regex
# Find untyped variable declarations
var\s+(\w+)\s*=\s*

# Find unsafe method calls  
\.has_method\(.*\).*\n.*\.call\(

# Find discarded return values
^\s*\w+\.\w+\(.*\)(?!\s*$)
```

### 2. GDScript Linter Configuration
```gdscript
# project.godot additions
[debug]
gdscript/completion/autocomplete_setters_and_getters=true
gdscript/warnings/untyped_declaration=true
gdscript/warnings/unsafe_property_access=true
gdscript/warnings/unsafe_method_access=true
gdscript/warnings/unsafe_cast=true
```

## Success Metrics
- [ ] Zero severity 8 errors (compilation)
- [ ] <10 type safety warnings remaining  
- [ ] All files pass strict linting
- [ ] Performance regression tests pass
- [ ] Documentation updated with new patterns

## Risk Mitigation
- **Backup Strategy**: Git branch per phase
- **Testing**: Unit tests for all modified methods
- **Rollback Plan**: Maintain working branch at each phase
- **Performance**: Profile before/after major changes
