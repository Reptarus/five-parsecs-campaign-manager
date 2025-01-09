# Core Scripts Reference

## Battle System

### CombatResolver
- Handles combat resolution and dice rolls
- Supports manual overrides for tabletop play
- Provides detailed combat logging
- Integrates with house rules system
- Emits signals for UI feedback

### CombatManager
- Manages overall combat state
- Handles turn sequencing
- Integrates with state verification
- Supports house rules application
- Provides state validation

### BattleRules
- Defines base game rules
- Supports house rule modifications
- Handles rule validation
- Manages combat modifiers
- Provides rule query interface

## UI Components

### Manual Override Panel
- Allows manual input of values
- Provides context-aware overrides
- Validates input against rules
- Emits override signals
- Supports multiple override types

### Combat Log Panel
- Displays combat events in real-time
- Supports event filtering
- Provides detailed event information
- Auto-scrolls with new events
- Allows event selection

### House Rules Panel
- Manages custom rule configurations
- Supports rule categories
- Provides rule editing interface
- Validates rule consistency
- Handles rule import/export

### State Verification Panel
- Displays current and expected states
- Supports auto-verification
- Provides manual correction interface
- Color-codes state differences
- Exports verification results

## Core Systems

### GameStateManager
- Manages global game state
- Handles state transitions
- Provides state validation
- Supports state serialization
- Emits state change signals

### ResourceSystem
- Manages game resources
- Handles resource calculations
- Provides resource validation
- Supports resource modifications
- Tracks resource history

### CampaignSystem
- Manages campaign progression
- Handles campaign events
- Provides campaign validation
- Supports campaign saving/loading
- Tracks campaign history

## Utility Scripts

### GlobalEnums
- Defines game enumerations
- Provides type definitions
- Supports system integration
- Ensures type consistency
- Documents value meanings

### ValidationUtils
- Provides validation helpers
- Supports type checking
- Handles error reporting
- Ensures data consistency
- Provides format validation

### StateUtils
- Helps with state management
- Provides state comparison
- Supports state serialization
- Handles state validation
- Manages state history

## Test Framework

### TestRunner
- Manages test execution
- Provides test reporting
- Supports async testing
- Handles test cleanup
- Reports test coverage

### UnitTests
- Tests individual components
- Validates functionality
- Ensures consistency
- Provides coverage metrics
- Documents expected behavior

### IntegrationTests
- Tests component interaction
- Validates system flow
- Ensures compatibility
- Tests edge cases
- Documents system behavior

## Notes
- All scripts follow GDScript best practices
- Documentation is maintained inline
- Signals are used for loose coupling
- Error handling is consistent
- Type hints are used where possible 