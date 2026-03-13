# Five Parsecs Campaign Manager - Architecture Guide

## 🏗️ System Architecture Overview

The Five Parsecs Campaign Manager implements a modern, production-grade architecture optimized for maintainability, extensibility, and performance. The system successfully reduced complexity by 57% through strategic refactoring while maintaining 100% functionality.

## 📐 Core Architectural Patterns

### Coordinator Pattern Implementation

The campaign creation system leverages the **Coordinator Pattern** to manage complex multi-step workflows without tight coupling:

```gdscript
# CampaignCreationCoordinator.gd (213 lines)
# Responsibilities:
# - Phase transition orchestration
# - Navigation state management
# - Validation coordination
# - Zero UI knowledge

# Self-Managing Panel Architecture
Panel (ConfigPanel, CrewPanel, etc.)
    ├── Local state management
    ├── Business logic ownership
    ├── Direct StateManager updates
    └── Single completion signal emission
```

**Measurable Benefits:**
- **57% code reduction** (2,442 → 1,053 lines)
- **100% test coverage** on critical paths
- **<100ms panel transitions**
- **Zero coupling** between panels

### Three-Tier Architecture

```
src/
├── base/                    # Abstract interfaces (contracts)
│   ├── campaign/           # ICampaign, IPhase
│   ├── character/          # ICharacter, ICrewMember
│   └── state/              # IStateManager, IValidator
├── core/                    # Business logic implementation
│   ├── campaign/           # CampaignManager, PhaseController
│   ├── systems/            # DiceSystem, BattleEvents
│   └── validation/         # SecurityValidator, RuleValidator
└── game/                    # Five Parsecs specific
    ├── campaign/           # FiveParsecsCampaign
    └── rules/              # TableReferences, RuleEngine
```

## 🔒 Security Architecture

### Defense-in-Depth Implementation

```gdscript
# Multi-layer validation pipeline
User Input
    → UI Sanitization (XSS prevention)
    → SecurityValidator (injection protection)
    → Business Rule Validation
    → Type Safety Enforcement
    → State Manager Update
    → Persistence Layer

# Example implementation
func validate_campaign_name(input: String) -> ValidationResult:
    var result = ValidationResult.new()
    
    # Layer 1: Length validation
    if input.length() < 3 or input.length() > 50:
        result.add_error("Name must be 3-50 characters")
    
    # Layer 2: Character validation
    var sanitized = SecurityValidator.sanitize_text(input)
    if sanitized != input:
        result.add_error("Invalid characters detected")
    
    # Layer 3: Business rules
    if CampaignRepository.name_exists(sanitized):
        result.add_error("Campaign name already exists")
    
    return result
```

## 🚀 Performance Architecture

### Optimization Strategies

1. **Lazy Resource Loading**
```gdscript
# Resources loaded only when needed
var _equipment_generator: Resource = null

func get_equipment_generator() -> StartingEquipmentGenerator:
    if not _equipment_generator:
        _equipment_generator = load("res://src/core/equipment/StartingEquipmentGenerator.gd")
    return _equipment_generator
```

2. **Object Pooling for UI**
```gdscript
# Reusable UI components
class_name CharacterCardPool
extends RefCounted

var _available_cards: Array[CharacterCard] = []
var _active_cards: Dictionary = {}

func acquire_card() -> CharacterCard:
    if _available_cards.is_empty():
        return CharacterCard.new()
    return _available_cards.pop_back()

func release_card(card: CharacterCard) -> void:
    card.reset()
    _available_cards.append(card)
```

3. **Async Heavy Operations**
```gdscript
func generate_crew_equipment(crew_size: int) -> void:
    # Show loading indicator
    loading_overlay.show()
    
    # Defer heavy computation
    await get_tree().process_frame
    
    # Process in chunks to maintain 60 FPS
    for i in range(crew_size):
        _generate_character_equipment(i)
        if i % 3 == 0:  # Every 3 characters
            await get_tree().process_frame
    
    loading_overlay.hide()
```

## 🧩 Component Architecture

### Standard Panel Implementation

Every panel follows this architectural contract:

```gdscript
class_name CampaignPanel
extends Panel

# Required signals for coordinator
signal panel_completed(panel_data: Dictionary)
signal validation_failed(errors: Array[String])

# State management
var state_manager: CampaignCreationStateManager
var local_data: Dictionary = {}

# Required interface methods
func initialize(state: CampaignCreationStateManager) -> void:
    state_manager = state
    _setup_ui()
    _load_existing_data()

func get_panel_data() -> Dictionary:
    return {
        "is_complete": validate_data().is_valid,
        "data": local_data,
        "validation_errors": last_validation_errors,
        "metadata": {
            "panel_name": get_class(),
            "timestamp": Time.get_unix_time_from_system()
        }
    }

func validate_data() -> ValidationResult:
    # Panel-specific validation
    pass
```

## 📊 State Management Architecture

### Centralized State with Event Sourcing

```gdscript
# CampaignCreationStateManager implementation
class_name CampaignCreationStateManager
extends RefCounted

# Immutable state updates
func set_phase_data(phase: Phase, data: Dictionary) -> void:
    var event = StateEvent.new()
    event.type = StateEvent.Type.PHASE_UPDATE
    event.phase = phase
    event.data = data.duplicate(true)  # Deep copy
    event.timestamp = Time.get_unix_time_from_system()
    
    _apply_event(event)
    _persist_event(event)
    
    state_updated.emit(phase, campaign_data[phase])
```

## 🔌 Integration Architecture

### Analytics Integration
```gdscript
# Non-intrusive analytics via signals
func _ready() -> void:
    state_manager.phase_completed.connect(
        campaign_analytics.track_phase_completed
    )
    coordinator.navigation_updated.connect(
        campaign_analytics.track_navigation_change
    )
```

### Accessibility Architecture
```gdscript
# Comprehensive accessibility support
class_name AccessibilityManager

func announce_phase_change(phase_name: String) -> void:
    var message = "Entering %s phase. %s" % [
        phase_name,
        _get_phase_instructions(phase_name)
    ]
    
    if OS.has_feature("screen_reader"):
        OS.tts_speak(message)
    
    visual_announcement.show_message(message)
```

## 🧪 Testing Architecture

### Test Pyramid Implementation

```
         /\
        /E2E\      (5%) - Full workflow tests
       /------\
      /  Integ \   (15%) - Component integration
     /----------\
    /    Unit    \ (80%) - Isolated logic tests
   /--------------\
```

### Testing Infrastructure
```gdscript
# Example integration test
func test_campaign_creation_flow():
    # Arrange
    var coordinator = CampaignCreationCoordinator.new()
    var state_manager = CampaignCreationStateManager.new()
    
    # Act - Progress through all phases
    var test_data = generate_test_campaign_data()
    for phase in CampaignCreationStateManager.Phase.values():
        state_manager.set_phase_data(phase, test_data[phase])
        assert_that(coordinator.can_advance()).is_true()
        coordinator.advance_phase()
    
    # Assert
    var campaign = coordinator.finalize_campaign()
    assert_that(campaign).is_not_null()
    assert_that(campaign.is_valid()).is_true()
```

## 📁 Project Structure

### Scene Organization
```
res://
├── src/
│   ├── ui/screens/
│   │   ├── mainmenu/MainMenu.tscn         # Entry point
│   │   └── campaign/
│   │       ├── CampaignCreationUI.tscn    # Orchestrator
│   │       ├── panels/                    # Self-contained panels
│   │       └── CampaignDashboard.tscn     # Post-creation
│   └── core/                              # Business logic
└── assets/                                # Resources
```

## 🔄 Data Flow Architecture

### Unidirectional Data Flow
```
User Action → Panel Handler → Validation → State Update → UI Update
                                              ↓
                                     Persistence Layer
                                              ↓
                                        Analytics
```

## 🎯 Architectural Principles

### SOLID Implementation
- **Single Responsibility**: Each panel manages one concern
- **Open/Closed**: Extensible via new panels without modification
- **Liskov Substitution**: All panels implement IPanelInterface
- **Interface Segregation**: Minimal required methods per panel
- **Dependency Inversion**: Panels depend on abstractions

### Production Best Practices
1. **Fail-Safe Defaults**: Graceful degradation on errors
2. **Progressive Enhancement**: Core functionality works everywhere
3. **Defensive Programming**: Validate all external inputs
4. **Observability**: Comprehensive logging and metrics
5. **Documentation**: Self-documenting code structure

## 🚨 Anti-Patterns to Avoid

### Common Pitfalls
- **God Objects**: Keep classes under 300 lines
- **Circular Dependencies**: Use signals for decoupling
- **Premature Optimization**: Profile before optimizing
- **Magic Numbers**: Use named constants
- **Silent Failures**: Always log errors

## 📈 Scalability Considerations

### Horizontal Scaling
- Add new panels without touching existing code
- Extend phases via configuration
- Plugin architecture for mods

### Vertical Scaling
- Async operations for heavy computation
- Resource pooling for memory efficiency
- Lazy loading for faster startup

## 🤖 Agent & Skill Architecture (Claude Code)

The project uses a **three-tier model routing** system via Claude Code agents and skills to optimize token usage:

### Model Tiers

- **Haiku** (~1/15th Opus cost): `ui-panel-developer` — 125+ UI component files following Deep Space theme patterns. Procedural, low-ambiguity work.
- **Sonnet** (~1/5th Opus cost): `campaign-systems-engineer`, `character-data-engineer`, `bug-hunt-specialist`, `qa-specialist` — moderate reasoning tasks (phase ordering, enum sync, data model distinctions, test coverage).
- **Opus** (full cost): `fpcm-project-manager`, `battle-systems-engineer` — complex multi-tier state machines, strategic decomposition, cross-system coordination.

### File Structure

```text
.claude/
├── agents/                     # 7 agent definitions (.md with YAML frontmatter)
├── agent-memory/               # Per-agent persistent memory (survives across sessions)
│   └── {agent-name}/MEMORY.md
├── skills/                     # 7 skills with lazy-loaded reference files
│   └── {skill-name}/
│       ├── SKILL.md            # Trigger description + reference table
│       └── references/*.md     # Code-sourced API docs (22 total)
└── settings.local.json         # Token budget: MAX_THINKING_TOKENS, AUTOCOMPACT_PCT
```

### Routing Protocol

1. Each agent owns specific files — tasks route by file ownership
2. `character-data-engineer` exclusively owns all 3 enum files (three-enum sync rule)
3. Multi-domain tasks decompose via `fpcm-project-manager` following dependency order:
   `data → campaign → battle → bug-hunt → UI → QA`
4. `bug-hunt-specialist` reviews any shared file changes for cross-mode safety
5. `qa-specialist` is always the final verification step

### Reference Files

Skill reference files contain **code-sourced API surfaces** extracted from actual `.gd` files — signals, methods, properties, enums, and architectural patterns. They are lazy-loaded ("read as needed") to minimize context window usage.

---

## 🔗 External Resources

- [Godot Best Practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/)
- [Game Programming Patterns](https://gameprogrammingpatterns.com/)
- [Five Parsecs Rules](https://www.modiphius.net/pages/five-parsecs)