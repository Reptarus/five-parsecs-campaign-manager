# Core Scripts Reference

## Battle System Components

### CombatResolver
- Location: `src/core/battle/CombatResolver.gd`
- Purpose: Handles combat resolution mechanics, dice rolls, and modifiers
- Key Features:
  - Transparent dice roll system with manual override support
  - Detailed modifier tracking and validation
  - Combat event logging and verification
  - Integration with house rules system

### CombatManager
- Location: `src/core/battle/CombatManager.gd`
- Purpose: Manages overall combat state and flow
- Key Features:
  - State tracking and validation
  - Combat phase management
  - Integration with manual overrides
  - House rules application
  - Combat event broadcasting

### BattleRules
- Location: `src/core/battle/BattleRules.gd`
- Purpose: Defines and enforces battle rules and modifiers
- Key Features:
  - Core rule definitions
  - House rules support
  - Modifier calculation and validation
  - Rule state verification

## UI Components

### Manual Override Panel
- Location: `src/ui/components/combat/overrides/manual_override_panel.gd`
- Purpose: Provides interface for manual combat value overrides
- Key Features:
  - Value input and validation
  - Override request handling
  - Context-aware modifications
  - Integration with combat system

### Combat Log Controller
- Location: `src/ui/components/combat/log/combat_log_controller.gd`
- Purpose: Manages combat event logging and visualization
- Key Features:
  - Event filtering and categorization
  - Detailed combat logging
  - Export functionality
  - State verification integration
  - Manual override tracking

### House Rules Panel
- Location: `src/ui/components/combat/rules/house_rules_panel.gd`
- Purpose: Interface for managing house rules
- Key Features:
  - Rule creation and modification
  - Validation checks
  - Combat system integration
  - State tracking

### State Verification Panel
- Location: `src/ui/components/combat/state/state_verification_panel.gd`
- Purpose: Provides tools for verifying game state
- Key Features:
  - State comparison and validation
  - Error reporting
  - Manual correction tools
  - Integration with combat system

## Core Systems

### GameState
- Location: `src/core/systems/GameState.gd`
- Purpose: Manages global game state
- Key Features:
  - State persistence
  - Save/load functionality
  - Event broadcasting
  - System integration

### ResourceSystem
- Location: `src/core/systems/ResourceSystem.gd`
- Purpose: Handles resource management
- Key Features:
  - Resource tracking
  - Modification validation
  - State persistence
  - Event broadcasting

## Testing Framework

### Test Runner
- Location: `src/tests/run_tests.gd`
- Purpose: Manages test execution and reporting
- Key Features:
  - Automated test discovery
  - Result reporting
  - Coverage tracking
  - Integration tests support 