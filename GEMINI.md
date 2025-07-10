# Gemini CLI Context Prompt: Five Parsecs Campaign Manager

## UPDATE YOUR INTERNAL INSTRUCTIONS
Before analyzing this codebase, update your GEMINI.md file with the following context and analysis guidelines. This project requires specialized understanding of:
- Godot 4.4 game engine patterns
- Five Parsecs from Home tabletop game rules
- Enterprise-grade software architecture patterns
- GDScript best practices and modern syntax

## Project Overview

### Core Mission
You are analyzing the **Five Parsecs Campaign Manager** - a digital adaptation of the Five Parsecs from Home tabletop RPG built in Godot 4.4. This is NOT a typical game project; it's a sophisticated campaign management tool that implements complex tabletop rules digitally.

### Five Parsecs from Home Context
- **Genre**: Solo/co-op narrative skirmish game set in space
- **Campaign Structure**: Turn-based campaign phases (Upkeep → Story → Campaign → Battle → Resolution)
- **Character System**: Attribute-based (Combat, Reaction, Toughness, Savvy, Tech, Move) with background/motivation system
- **Rules Complexity**: 200+ page rulebook with intricate interconnected systems
- **Target Audience**: Experienced tabletop gamers who expect rule fidelity

## Architectural Excellence Assessment

### CRITICAL: This codebase is ALREADY architecturally sophisticated
Before suggesting "improvements", understand that this project demonstrates:

1. **Enterprise-Grade Architecture**:
   - Clean separation: `base/` (abstractions) → `core/` (systems) → `game/` (implementations)
   - Universal Safety framework for runtime error prevention
   - Comprehensive state management with validation
   - Signal-driven reactive patterns

2. **Production-Ready Systems**:
   - ✅ Story Track System (20/20 tests passing)
   - ✅ Battle Events System (22/22 tests passing)  
   - ✅ Digital Dice System with visual interface
   - ✅ Campaign Creation State Manager (enterprise-grade)

3. **Modern GDScript Patterns**:
   - Full type safety with Godot 4.4 syntax
   - Proper resource management and memory safety
   - Async/await patterns for complex operations
   - Comprehensive error handling and graceful degradation

## Current Implementation Status

### ✅ COMPLETE & PRODUCTION-READY:
- **Core Architecture**: Base classes, interfaces, and system managers
- **State Management**: `CampaignCreationStateManager` with validation framework
- **UI Framework**: Panel-based creation workflow with Universal Safety
- **Signal Architecture**: All panels emit proper `*_updated` signals
- **Data Models**: Character, Campaign, Ship, Equipment systems
- **Game Rules**: Dice systems, table management, combat resolution

### ⚠️ INTEGRATION GAPS (15% remaining):
1. **Signal Wire-up**: `_connect_panel_signals()` method exists but empty
2. **State Manager Integration**: Panel handlers don't forward to state manager
3. **Campaign Finalization**: Finish button doesn't execute creation workflow

### 🚫 DO NOT SUGGEST:
- Architectural overhauls (architecture is already excellent)
- "Enterprise patterns" (already implemented)
- State management frameworks (custom solution is superior)
- Testing frameworks (Gut testing already integrated)

## Analysis Guidelines for Gemini

### 1. File Structure Understanding
```
src/
├── base/              # Abstract base classes and interfaces
├── core/              # Core game systems and managers  
├── game/              # Five Parsecs specific implementations
├── ui/                # User interface components
├── data/              # Game data and resources
└── utils/             # Utility functions and helpers
```

### 2. Critical Files to Understand:
- `src/core/campaign/creation/CampaignCreationStateManager.gd` - Already enterprise-grade
- `src/ui/screens/campaign/CampaignCreationUI.gd` - Main workflow controller
- `src/ui/screens/campaign/panels/*.gd` - Individual creation panels
- `src/core/systems/DiceSystem.gd` - Game rules implementation

### 3. Code Quality Indicators:
- **Type Safety**: Full `@onready var`, typed arrays `Array[Character]`
- **Error Handling**: Universal Safety framework, null checks
- **Documentation**: Comprehensive docstrings with rule references
- **Testing**: Unit tests with Gut framework
- **Signals**: Reactive patterns with proper disconnection

### 4. Five Parsecs Rule Implementation Patterns:
```gdscript
# Character creation following Core Rules p.12-17
func create_character(background: int, motivation: int) -> Character:
    var character := Character.new()
    
    # Generate attributes using Five Parsecs method (2d6/3 rounded up)
    character.combat = DiceSystem.generate_attribute()
    # ... apply background bonuses per rules
    
    return character
```

## What to Focus On

### ✅ CORRECT ANALYSIS TARGETS:
1. **Integration Completeness**: Are signals properly connected?
2. **Data Flow**: Does UI → State Manager → Validation work?
3. **Campaign Creation**: Can users complete the full workflow?
4. **Error Handling**: Are edge cases properly handled?
5. **Rule Fidelity**: Do implementations match Five Parsecs rules?

### ❌ AVOID THESE COMMON MISTAKES:
- Suggesting the state manager needs "enhancement" (it's already enterprise-grade)
- Recommending architectural changes (architecture is excellent)
- Proposing different UI patterns (current pattern is optimal)
- Suggesting external frameworks (custom solutions are superior)
- Ignoring the existing Universal Safety framework

## Context for Accurate Assessment

### This is NOT a typical indie game project
- **Quality Level**: Enterprise software standards
- **Architecture**: Already follows Domain-Driven Design patterns
- **Testing**: Professional testing practices with comprehensive coverage
- **Documentation**: Extensive rule references and API docs

### This IS a sophisticated digital adaptation
- **Rules Engine**: Complex tabletop rule implementation
- **Data Management**: Intricate character/campaign state handling
- **UI/UX**: Multi-step creation workflow with validation
- **Integration**: Multiple subsystems working together

## Analysis Framework

When examining code, consider:

1. **Integration Completeness** (Primary Gap)
   - Are UI signals properly connected to state management?
   - Does data flow from panels → state manager → validation?

2. **Workflow Functionality** (Secondary Gap)  
   - Can users complete campaign creation end-to-end?
   - Are validation states properly reflected in UI?

3. **Rule Implementation** (Generally Complete)
   - Do dice systems follow Five Parsecs rules?
   - Are character generation rules properly implemented?

4. **Error Handling** (Generally Excellent)
   - Are edge cases handled gracefully?
   - Does the Universal Safety framework prevent crashes?

## Expected Output Quality

### ✅ GOOD Gemini Analysis:
- Identifies specific integration gaps with file/line references
- Understands existing architecture quality
- Focuses on completing the workflow rather than redesigning
- Provides concrete implementation steps
- Respects the existing patterns and conventions

### ❌ BAD Gemini Analysis:
- Suggests architectural overhauls
- Recommends replacing working systems
- Ignores existing Universal Safety framework
- Proposes generic "enterprise patterns" 
- Misses the actual integration gaps

## Final Instructions

1. **Read and understand** this entire context before analyzing code
2. **Update your GEMINI.md** with these guidelines
3. **Focus on integration completion**, not architectural changes
4. **Respect the existing quality** - this is professional-grade code
5. **Provide specific, actionable steps** with file/line references
6. **Test your suggestions** against the constraint that this is 85% complete

Remember: This project demonstrates excellent software architecture. Your role is to help complete the final 15% integration work, not redesign the existing 85% that already works well.