---
description: Updated project rules and coding standards for the Five Parsecs Campaign Manager project, reflecting current development stage and processes.
globs: ["*.gd", "*.tscn", "*.tres", "*.res", "*.md", "*.json", "*.cfg", "*.import", "src/**/*", "tests/**/*", "assets/**/*", "docs/**/*"]
---

# Five Parsecs Campaign Manager - Project Rules (Updated)

## Project Structure and Organization

### Directory Structure
- **Source Code Structure**:
  - `src/core/`: Core systems and foundational code
  - `src/base/`: Base classes and abstractions
  - `src/game/`: Game-specific implementations
    - `src/game/campaign/`: Campaign-related functionality
    - `src/game/combat/`: Combat systems
    - `src/game/character/`: Character management
    - `src/game/ships/`: Ship management systems
    - `src/game/mission/`: Mission logic and structures
    - `src/game/state/`: Game state management
    - `src/game/items/`: Item implementations
    - `src/game/world/`: World generation and management
    - `src/game/economy/`: Economic systems
    - `src/game/terrain/`: Terrain generation and management
    - `src/game/enemy/`: Enemy AI and management
    - `src/game/tutorial/`: Tutorial systems
    - `src/game/story/`: Story/narrative management
    - `src/game/victory/`: Victory conditions and tracking
  - `src/utils/`: Utility functions and helpers
  - `src/data/`: Data definitions and containers
  - `src/scenes/`: Scene implementations
  - `src/ui/`: User interface components
- **Asset Management**:
  - Store assets in `assets/` directory with appropriate subdirectories
  - Maintain optimized assets in version control
- **Documentation**:
  - Maintain documentation in `docs/` directory
  - Store working documents and planning materials in `workingdocs/` directory
  - Include README files in each major directory explaining its purpose
- **Testing**:
  - Keep tests in `tests/` directory matching src structure

### File Naming Conventions
- Use PascalCase for scene files (.tscn) and GDScript class files (.gd)
  - Example: `CharacterCreator.tscn`, `CampaignManager.gd`
- Use snake_case for resource files (.tres, .res)
  - Example: `character_template.tres`, `ship_data.res`
- Use snake_case for test files with _test suffix
  - Example: `character_manager_test.gd`
- Prefix interface files with I
  - Example: `ICharacter.gd`, `ICampaignPhase.gd`
- Suffix enum files with Enums
  - Example: `FiveParsecsGameEnums.gd`, `CombatEnums.gd`

## Coding Standards

### GDScript Style
- Use strict mode (`@tool` and `class_name` declarations) for all GDScript files
- Implement static typing for all variables and functions
  - Example: `func get_character_data(character_id: String) -> CharacterData:`
- Follow consistent naming conventions:
  - snake_case for functions and variables
  - PascalCase for classes and custom types
  - SCREAMING_SNAKE_CASE for constants and enums
- Use enums for type-safe identifiers and category values
  - Store game-specific enums in designated enum classes (e.g., `FiveParsecsGameEnums`)
- Implement proper signal connections using typed callbacks

### Documentation
- Document all public functions with GDScript doc comments:
```gdscript
## Updates the character's status based on damage taken
## @param character: The character to update
## @param damage: Amount of damage taken
## @return bool: True if character status changed
func update_character_status(character: Character, damage: int) -> bool:
```
- Document all signals with their purpose and parameters
- Maintain comprehensive README.md files in major directories
- Document all exported variables with descriptive comments
- Include usage examples for complex functions and systems
- Keep API documentation updated as code evolves

### Node Organization
- Use PascalCase for node names in the scene tree
- Organize related nodes under descriptive parent nodes
- Follow a consistent pattern for node references and access
- Document node dependencies and required configurations
- Implement proper scene composition with reusable components
- Minimize deep nesting of nodes when possible

## Game Systems Implementation

### Campaign System
- Follow modular design for campaign phases and progression
- Implement proper state validation for all campaign transitions
- Use the Five Parsecs game enums for categorization and type safety
- Document phase transitions and requirements
- Maintain phase history for player reference and state rollback
- Implement campaign type-specific features using the CampaignType enum

### Character Management
- Use character class types from CharacterClass enum for specialization
- Track character status using the CharacterStatus enum
- Implement proper character progression systems
- Maintain character history and statistics
- Use character validation before state changes
- Support proper character relationship tracking

### Ship Management
- Implement ship types according to ShipType enum
- Track ship upgrades and modifications
- Support ship crew assignments and roles
- Validate ship state changes and modifications
- Implement proper ship resource management

## Testing Strategy

### Test Structure
- Maintain unit tests for all core systems and game logic
- Implement integration tests for complex subsystems
- Create end-to-end tests for critical user workflows
- Use mocks and stubs for external dependencies
- Document test coverage and gaps
- Target 85% overall code coverage with critical paths at 100%

### Test Stability
- Implement deterministic test runs with fixed random seeds
- Use proper test setup and teardown processes
- Handle async operations properly with signal-based waiting
- Track and clean up resources to prevent test pollution
- Verify state transitions with assertions
- Implement proper test timeouts and error handling

## State Management

### Validation Rules
- Validate all state changes through appropriate validators
- Implement error recovery for invalid state transitions
- Document state machine transitions and requirements
- Maintain state history for debugging and rollback functionality
- Log all validation failures with appropriate context
- Ensure state consistency across game systems

### Error Handling
- Implement structured error handling throughout the codebase
- Use error codes and descriptive messages
- Log errors through a centralized logging system
- Implement recovery mechanisms for non-critical errors
- Provide user-friendly error messages for player-facing issues
- Use defensive programming to prevent common errors

## UI/UX Standards

### Component Design
- Design UI components for both desktop and mobile interfaces
- Implement responsive layouts that adapt to screen sizes
- Use consistent styling and theming across all interfaces
- Implement proper focus management for keyboard navigation
- Use appropriate font sizes and contrast ratios for accessibility
- Follow the Five Parsecs aesthetic for all UI elements

### Input Management
- Support both mouse/keyboard and touch inputs
- Implement proper input validation and debouncing
- Document input requirements for all interactive elements
- Handle input errors gracefully with feedback
- Implement appropriate touch zones for mobile interfaces
- Support customizable control schemes where appropriate

## Performance Optimization

### Optimization Targets
- Maintain 60 FPS on target platforms
- Optimize resource loading with preloading and background loading
- Implement level of detail systems for complex scenes
- Profile all new features before integration
- Monitor memory usage and implement proper cleanup
- Document performance impacts of major systems

### Memory Management
- Implement proper resource cleanup and garbage collection
- Use object pooling for frequently created/destroyed objects
- Monitor memory usage during development
- Implement reference counting where appropriate
- Optimize asset usage to reduce memory footprint
- Perform regular performance testing on target platforms

## Release Management

### Version Control
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Maintain a comprehensive CHANGELOG.md
- Tag significant releases in the repository
- Create release branches for major versions
- Document breaking changes and migration steps
- Implement proper feature flags for in-progress work

### Quality Assurance
- Perform code reviews for all significant changes
- Run automated tests before merging
- Implement manual testing for UI and gameplay
- Document known issues and workarounds
- Validate releases against quality criteria
- Gather and incorporate user feedback

## Collaboration Standards

### Commit Guidelines
- Use conventional commits format (type: description)
  - feat: Add new character creation feature
  - fix: Resolve campaign transition issue
  - docs: Update API documentation
  - refactor: Improve combat resolution flow
  - test: Add tests for ship management
- Include issue references in commit messages
- Keep commits focused on single concerns
- Write clear, descriptive commit messages
- Document breaking changes prominently

### Pull Request Process
- Create descriptive pull request titles and descriptions
- Link related issues and documentation
- Include test coverage information
- Request reviews from appropriate team members
- Address all review comments
- Ensure CI passes before merging

## Future Development

### Roadmap Integration
- Align development with project roadmap
- Prioritize features based on player impact
- Document technical debt and refactoring needs
- Plan for scalability and extensibility
- Consider modding support in architecture decisions
- Maintain balance between new features and stability 