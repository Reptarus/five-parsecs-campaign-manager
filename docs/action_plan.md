# Updated Prioritized Action Plan for Five Parsecs Campaign Manager

## Documentation Consolidation (March 2024)
The project documentation has been consolidated and organized:
- Created `docs/docs_summary.md` as a central index of all documentation
- Archived completed/obsolete documentation in `docs/archive/`
- Updated references to archived documents
- Standardized documentation format and organization

## ✅ Phase 1: Core Game Loop Implementation (COMPLETED)
All high-priority components from Phase 1 have been successfully implemented, including:
- Campaign Phase Management with Victory Condition Tracking
- World Generation Tables
- Mission Generation and React Tables
- Battle Results Recording
- Equipment and Loot System
- Rival and Patron System

## ✅ Phase 2: Equipment and Resource Management (COMPLETED)

### 1. Item and Equipment System (Medium Priority) ✅
- **Equipment Management**
  - **File:** `src/core/character/Equipment/EquipmentManager.gd`
  - **Task:** Enhance equipment handling (equipping, trading, upgrading) from p.56-74
  - **Data Integration:** Use `data/weapons.json`, `data/armor.json`, and `data/gear_database.json`
  - **Status:** Implemented

- **Resource Tracking** ✅
  - **File:** `src/core/state/GameState.gd`
  - **Task:** Implement tracking for credits, resources, and items from p.45-46
  - **Data Integration:** Use `data/resources.json`
  - **Status:** Implemented

### 2. Ship Management (Medium Priority) ✅
- **Ship System Implementation**
  - **File:** `src/core/ships/Ship.gd`
  - **Task:** Implement ship types, upgrades and maintenance from p.75-77
  - **Data Integration:** Use `data/ship_components.json`
  - **Status:** Implemented

- **Crew Assignments and Ship Roles** ✅
  - **File:** `src/game/ships/FiveParsecsShipRoles.gd`
  - **Task:** Implement crew assignment to ship roles
  - **Data Integration:** Use crew information from character system
  - **Status:** Implemented

## 🔄 Phase 3: UI Implementation and Data Binding (IN PROGRESS)

### 0. Code Architecture Refinement (High Priority) 🔄
- **Script Reference Management** 🔄
  - **Task:** Address class_name conflicts across the codebase
  - **Implementation:** Replace problematic class_name declarations with preload/load approach
  - **Status:** In progress (multiple files fixed)
  - **Guidelines:**
    - Avoid using `class_name` for classes that might conflict with global scripts
    - Use absolute paths in preload/load statements (`res://path/to/file.gd`)
    - Prefer `load()` over `preload()` when dealing with potential circular dependencies
    - Document classes that have had class_name removed in a central location

- **Cache Errors and Script Resolution** 🔄
  - **Task:** Address "Error while getting cache for script" errors throughout the codebase
  - **Implementation:** Replace inner classes with factory functions returning dictionaries
  - **Status:** In progress (ActionPanel.gd, EventLog.gd, and test files fixed)
  - **Guidelines:**
    - Avoid using nested classes that might conflict with global scripts
    - Use factory functions that return dictionaries instead of class instances
    - Structure code to use data objects (dictionaries) instead of class instances where possible
    - Use static helper functions for operations on data objects
    - Document refactoring patterns used to address cache errors
    - For test files, ensure proper inheritance paths are used in extends statements
    - Be cautious when using track_test_resource() with non-Resource objects

- **Component Duplication Resolution** ✅
  - **Task:** Consolidate duplicate ship components to a single implementation
  - **Implementation:** Removed duplicate components from game directory, keeping the core versions
  - **Status:** Completed with documentation
  - **Guidelines:** 
    - Added `SHIP_COMPONENTS_README.md` in the components directory to explain usage
    - Ship components should always be loaded from `src/core/ships/components/`
    - Prefer using absolute paths for all component loading

- **Terrain System Consolidation** ✅
  - **Task:** Consolidate duplicate terrain system implementations
  - **Implementation:** Removed duplicate TerrainSystem.gd files from game directories
  - **Status:** Completed with documentation
  - **Guidelines:**
    - Added `TERRAIN_SYSTEM_README.md` in the terrain directory to explain usage
    - TerrainSystem should always be loaded from `src/core/terrain/`
    - Fixed class_name conflicts in TerrainSystem.gd

- **Dependency Management** 🔄
  - **Task:** Audit and refine script dependencies to prevent circular references
  - **Implementation:** Use systematic approach to organize script hierarchy
  - **Status:** In progress
  - **Guidelines:**
    - Map out dependency tree for core systems
    - Use forward declarations where possible
    - Consider using dependency injection pattern for complex systems

- **Script Organization Review** 🔄
  - **Task:** Review script locations and organization for clarity and maintainability
  - **Implementation:** Document script organization and enforce consistent patterns
  - **Status:** In progress
  - **Guidelines:**
    - Ensure scripts are in appropriate directories based on functionality
    - Use consistent naming patterns for related scripts
    - Maintain clear separation between core/base and game-specific implementations

### 1. UI Architecture Cleanup (High Priority) ✅
- **UI File Organization** ✅
  - **Task:** Organize UI files into logical directory structure
  - **Status:** Completed with scripts for organization and reference updates

- **UI Documentation** ✅
  - **Files:** Created documentation in `docs/` directory
  - **Task:** Document UI structure, standards, and cleanup process
  - **Status:** Completed with comprehensive documentation files

- **UI Reference Management** ✅
  - **Task:** Update references to UI files after reorganization
  - **Status:** Completed with reference detection and update scripts

### 2. Phase-Specific UI Panels (High Priority) 🔄
- **Campaign Dashboard Completion**
  - **File:** `src/ui/screens/campaign/CampaignDashboard.tscn` and related scripts
  - **Task:** Complete the main dashboard with all campaign information
  - **Data Integration:** Bind to campaign state data
  - **Status:** In progress
  - **Implementation Guidelines:**
    - Implement MVC pattern for UI components
    - Create data binding utilities to simplify connections between UI and data
    - Add validation for data displayed in UI elements
    - Include error handling for missing or invalid data

- **Phase Panel Implementation**
  - **Files:** Various `src/ui/screens/campaign/phases/*.gd` files
  - **Task:** Complete all phase-specific UI panels
  - **Data Integration:** Connect each panel to relevant game data
  - **Status:** In progress
  - **Implementation Guidelines:**
    - Create consistent interfaces for all phase panels
    - Implement stepwise verification before transitions between phases
    - Add progress indicators for multi-step processes
    - Include help/reference information accessible from each panel

### 3. Mission and Story System (Medium Priority) 🔄
- **Mission Generation and Management UI**
  - **File:** `src/core/mission/MissionManager.gd` and related UI files
  - **Task:** Implement mission generation UI and tracking from p.89-91
  - **Data Integration:** Use `data/mission_templates.json` and `data/mission_tables/`
  - **Status:** Core functionality implemented, UI integration in progress
  - **Implementation Guidelines:**
    - Create clear separation between mission data and UI representation
    - Implement progressive disclosure for complex mission information
    - Add mission history tracking and visualization

- **Patron and Connection System UI**
  - **Files:** `src/game/campaign/PatronManager.gd` and related UI files
  - **Task:** Implement patron and connection UI from p.92-94
  - **Data Integration:** Use `data/patron_types.json` and `data/expanded_connections.json`
  - **Status:** Core functionality implemented, UI integration in progress
  - **Implementation Guidelines:**
    - Create relationship visualization tools
    - Implement patron interaction history tracking
    - Add context-sensitive actions based on patron relationships

### 4. Component Standardization (Medium Priority)
- **ResponsiveContainer Consolidation**
  - **File:** Create standardized `src/ui/components/base/ResponsiveContainer.gd`
  - **Task:** Standardize container components and update implementations
  - **Status:** Planning phase
  - **Implementation Guidelines:**
    - Create clear documentation with usage examples
    - Implement responsive sizing based on viewport changes
    - Add layout options for different screen orientations

- **UI Component Library**
  - **File:** Various files in `src/ui/components/`
  - **Task:** Create reusable UI components with consistent APIs
  - **Status:** Planning phase
  - **Implementation Guidelines:**
    - Create component inventory with categorization
    - Implement consistent API patterns across components
    - Add automated tests for component behavior
    - Include accessibility features in core components

### 5. Testing and Verification for Phase 3
- **UI Integration Testing**
  - **Task:** Create tests to verify UI elements correctly display and update data
  - **Implementation:** Add testing utilities for UI components
  - **Status:** Not started
  - **Guidelines:**
    - Create test fixtures for UI components
    - Implement tests for data binding correctness
    - Add visual regression testing for critical UI components

- **Performance Benchmarking**
  - **Task:** Benchmark UI performance, especially for complex screens
  - **Implementation:** Add performance measurement tools
  - **Status:** Not started
  - **Guidelines:**
    - Measure render times for complex UI components
    - Test performance with large datasets
    - Identify optimization targets based on benchmarks

## Phase 4: State Management and Persistence (2-3 weeks)

### 1. Save/Load System (High Priority)
- **Enhanced Save System**
  - **File:** `src/core/state/SaveManager.gd`
  - **Task:** Complete save/load functionality with validation
  - **Data Integration:** Ensure all game state data is properly serialized
  - **Gap Being Filled:** Save system incomplete
  - **Implementation Guidelines:**
    - Create versioned save format for future compatibility
    - Implement incremental saving for large campaigns
    - Add save data compression and encryption options

- **Campaign State Validation**
  - **File:** Create new file `src/core/state/ValidationManager.gd`
  - **Task:** Implement state validation for all game systems
  - **Data Integration:** Validate against data files for correctness
  - **Gap Being Filled:** State validation missing
  - **Implementation Guidelines:**
    - Create schema validation for campaign data
    - Implement error correction for common data issues
    - Add validation reports for debugging

### 2. Error Handling and Recovery (Medium Priority)
- **Error Recovery System**
  - **File:** Create new file `src/core/state/ErrorRecoveryManager.gd`
  - **Task:** Implement error detection and recovery
  - **Gap Being Filled:** Error recovery missing
  - **Implementation Guidelines:**
    - Create error classification system
    - Implement recovery strategies by error type
    - Add telemetry for error frequency and patterns

- **Campaign History**
  - **File:** Create new file `src/core/state/CampaignHistory.gd`
  - **Task:** Implement full campaign history tracking
  - **Rulebook Alignment:** Record elements recommended in rulebook for campaign narrative
  - **Gap Being Filled:** History tracking may be minimal
  - **Implementation Guidelines:**
    - Create event-based history recording
    - Implement filtering and search for history entries
    - Add visualization tools for campaign timeline

## Phase 5: Testing and Refinement (Ongoing)

### 1. Integration Testing (High Priority)
- **Campaign Flow Tests**
  - **File:** Create tests in `tests/integration/campaign/`
  - **Task:** Test full campaign flow from creation to completion
  - **Gap Being Filled:** Integration tests incomplete
  - **Implementation Guidelines:**
    - Create test scenarios for common campaign paths
    - Implement regression tests for fixed bugs
    - Add stress tests for edge cases and unusual configurations

- **Character Management Tests**
  - **File:** Create tests in `tests/integration/character/`
  - **Task:** Test character creation, advancement, and equipment management
  - **Gap Being Filled:** Character tests incomplete
  - **Implementation Guidelines:**
    - Create comprehensive test suite for character lifecycle
    - Test character interactions with other systems
    - Implement performance tests for character operations

- **Rules Compliance Tests**
  - **File:** Create tests in `tests/rules/`
  - **Task:** Create tests that verify compliance with specific rulebook mechanics
  - **Rulebook Alignment:** Test against specific rule examples from rulebook
  - **Gap Being Filled:** Rules compliance testing may be missing
  - **Implementation Guidelines:**
    - Create test cases directly from rulebook examples
    - Implement verification against calculation examples
    - Add traceability between tests and rulebook sections

### 2. Performance Optimization (Low Priority)
- **Resource Management**
  - **File:** Various core system files
  - **Task:** Implement proper resource cleanup and optimization
  - **Gap Being Filled:** Performance optimization missing
  - **Implementation Guidelines:**
    - Profile resource usage in key systems
    - Implement memory optimization for large campaigns
    - Add background processing for intensive operations

## Implementation Notes

### Core Rules Integration
1. **Campaign Turn Sequence**: Follow the exact flow from p.78-100 of core_rules.md
   - Travel Steps (ship movement)
   - New World Arrival (world generation)
   - World Steps (story events, missions, trading)

2. **Character System**: Implement according to p.26-41
   - Start with the crew creation process
   - Follow the exact stat blocks and mechanics

3. **Battle Results**: Focus on recording results rather than simulation
   - Players will handle the physical battle on the table
   - App should focus on setup and outcome recording

4. **Rulebook Accuracy**: For each system, directly reference the corresponding rulebook pages
   - Copy exact tables and algorithms where possible
   - Match the exact terminology used in the rulebook
   - When in doubt, prioritize rulebook accuracy over implementation convenience

### Data Utilization Strategy
1. Use the extensive JSON data files in the `/data` directory as primary sources:
   - `character_creation_data.json` for character generation
   - `mission_templates.json` for mission creation
   - `planet_types.json` and `location_types.json` for world generation
   - `weapons.json` and `armor.json` for equipment

2. Create data loaders for each major system that:
   - Load and validate data at startup
   - Provide efficient access methods
   - Include error handling for missing or corrupt data

### UI Standards (Updated)
1. **File Organization**:
   - **Screens**: All UI screens should be placed in `src/ui/screens/` and organized by feature
   - **Components**: Reusable UI components should be placed in `src/ui/components/`
   - **Resources**: UI resources (themes, styles, etc.) should be placed in `src/ui/resource/`

2. **Component Design**:
   - Components should have clear separation of concerns
   - Components should be designed for reusability
   - Complex screens should be composed of smaller components

3. **Responsive Design**:
   - Use the standardized ResponsiveContainer for responsive layouts
   - Design UI for multiple screen sizes and orientations

4. **Documentation**:
   - Each directory should have a README.md file
   - Each component should have clear usage examples
   - Document the purpose and integration points for complex UI screens

### Script Architecture Lessons Learned
1. **Class Name Management**:
   - Avoid using `class_name` for scripts that might be referenced in multiple places
   - Use explicit preload/load references with absolute paths
   - Document global script classes in a central registry

2. **Dependency Management**:
   - Create clear dependency hierarchies to avoid circular references
   - Use load() instead of preload() when dealing with potential circular dependencies
   - Consider using dependency injection for complex systems

3. **Error Prevention**:
   - Implement progressive validation during development
   - Add runtime checks for critical dependencies
   - Create diagnostic tools for identifying reference issues

4. **Code Organization**:
   - Maintain clear separation between base classes and implementations
   - Use consistent naming conventions across the project
   - Organize scripts by functionality rather than inheritance

5. **Cache Error Prevention**:
   - Avoid using nested inner classes in scripts, especially when they're instantiated frequently
   - Use dictionary-based factory functions instead of class constructors (examples in ActionPanel.gd, EventLog.gd)
   - When refactoring existing code with cache errors:
     - Replace classes with static factory functions that return dictionaries
     - Add helper functions for common operations that would have been class methods
     - Structure object interfaces to be explicit about available properties
   - In test files:
     - Use absolute paths in extends statements (e.g., extends "res://tests/fixtures/specialized/battle_test.gd")
     - Be careful with track_test_resource() when using dictionaries instead of Resources
     - Create specific test utility methods that work with dictionary-based data objects

### Rulebook Mechanics Already Implemented
Several key rulebook mechanics have already been successfully implemented:
- **✓ Experience Calculation** - Updated to match rulebook's XP system (character advancement)
- **✓ Injury Tables** - Added detailed injury tables with proper outcomes and recovery times
- **✓ Loot Generation** - Updated to use the appropriate loot tables from rulebook
- **✓ Rival System** - Added proper rival generation mechanics per rulebook
- **✓ Patron Relationships** - Added patron relationship tracking per rulebook 