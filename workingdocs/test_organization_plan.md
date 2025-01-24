# Test Organization Plan

## Directory Structure

```
tests/
├── unit/                    # Unit tests for individual components
│   ├── character/          # Character-related tests
│   ├── combat/            # Combat system tests
│   ├── mission/           # Mission system tests
│   ├── terrain/           # Terrain system tests
│   ├── campaign/          # Campaign system tests
│   ├── core/             # Core system tests
│   ├── ui/               # UI component tests
│   └── equipment/         # Equipment system tests
├── integration/            # Tests for component interactions
│   ├── campaign_flow/     # Campaign phase interactions
│   ├── combat_flow/       # Combat system interactions
│   └── mission_flow/      # Mission system interactions
├── performance/            # Performance benchmarks
│   ├── combat/           # Combat system performance
│   ├── terrain/          # Terrain system performance
│   └── campaign/         # Campaign system performance
├── mobile/                # Mobile-specific tests
├── fixtures/              # Test helpers and shared resources
│   ├── base_test.gd      # Base test class
│   ├── game_test.gd      # Game-specific test utilities
│   └── mock_data/        # Mock data for tests
├── reports/               # Test results and coverage
└── logs/                 # Test execution logs
```

## File Standardization Steps

1. **Base Test Class Structure**
   ```gdscript
   @tool
   extends "res://tests/fixtures/base_test.gd"
   
   const TestedClass = preload("res://path/to/tested/class.gd")
   
   var _instance: TestedClass
   
   func before_each() -> void:
       await super.before_each()
       _instance = TestedClass.new()
       add_child(_instance)
       track_test_node(_instance)
   
   func after_each() -> void:
       await super.after_each()
       _instance = null
   ```

2. **Test Method Naming**
   - `test_feature_being_tested`
   - `test_feature_specific_condition`
   - `test_feature_error_condition`

3. **Resource Management**
   - Use `track_test_node()` for nodes
   - Use `track_test_resource()` for resources
   - Clean up in `after_each()`

## Migration Process

1. **Phase 1: Directory Setup**
   - [x] Create unit test directories
   - [x] Create integration test directories
   - [x] Create performance test directories
   - [x] Set up reports directory
   - [x] Configure logging

2. **Phase 2: File Migration**
   - [x] Move character tests
     - [x] test_character_manager.gd → unit/character/
     - [x] test_character_data_manager.gd → unit/character/
   - [x] Move combat tests
     - [x] test_battlefield_generator.gd → unit/combat/
     - [x] test_combat_log_controller.gd → unit/combat/
     - [x] test_combat_log_panel.gd → unit/combat/
     - [x] test_battle_state_machine.gd → unit/combat/
   - [x] Move mission tests
     - [x] test_mission.gd → unit/mission/
     - [x] test_mission_generator.gd → unit/mission/
   - [x] Move terrain tests
     - [x] test_terrain_layout.gd → unit/terrain/
   - [ ] Move UI tests
     - [ ] test_manual_override_panel.gd → unit/ui/
     - [ ] test_house_rules_panel.gd → unit/ui/
     - [ ] test_rule_editor.gd → unit/ui/
     - [ ] test_state_verification_panel.gd → unit/ui/
     - [ ] test_house_rules_controller.gd → unit/ui/
     - [ ] test_ui_state.gd → unit/ui/
   - [ ] Move campaign tests
     - [ ] test_campaign_state.gd → unit/campaign/
     - [ ] test_campaign_system.gd → unit/campaign/
     - [ ] test_game_state_manager.gd → unit/campaign/
     - [ ] test_resource_system.gd → unit/campaign/
   - [ ] Move core tests
     - [ ] test_error_logger.gd → unit/core/
     - [ ] test_core_features.gd → unit/core/

3. **Phase 3: File Updates**
   - [x] Update base class references
   - [ ] Fix resource paths
   - [ ] Add missing lifecycle methods
   - [x] Implement resource tracking

4. **Phase 4: Test Coverage**
   - [ ] Add missing enum tests
   - [ ] Complete partial tests
   - [ ] Add error condition tests
   - [ ] Add boundary tests

## GUT Integration

1. **Configuration Updates**
   ```json
   {
       "dirs": [
           "res://tests/unit",
           "res://tests/integration",
           "res://tests/performance"
       ],
       "include_subdirs": true,
       "prefix": "test_",
       "suffix": ".gd"
   }
   ```

2. **Test Running**
   - Configure test running scene
   - Set up test shortcuts
   - Configure test filters

## Implementation Order

1. **Week 1: Infrastructure**
   - Day 1: Directory structure
   - Day 2: Base class updates
   - Day 3: GUT configuration
   - Day 4-5: File migration

2. **Week 2: Test Updates**
   - Day 1-2: Character system tests
   - Day 3-4: Combat system tests
   - Day 5: Mission system tests

3. **Week 3: Coverage**
   - Day 1-2: Add missing tests
   - Day 3: Performance tests
   - Day 4-5: Integration tests

## Standards

1. **File Naming**
   - Unit tests: `test_<class_name>.gd`
   - Integration tests: `test_<system>_flow.gd`
   - Performance tests: `perf_test_<system>.gd`

2. **Test Structure**
   ```gdscript
   # Test category
   func test_feature_name() -> void:
       # Arrange
       var input = setup_test_data()
       
       # Act
       var result = _instance.method_under_test(input)
       
       # Assert
       assert_eq(result, expected_value, "Message explaining the test")
   ```

3. **Documentation**
   ```gdscript
   ## Test class for CharacterManager functionality
   ##
   ## Tests character creation, modification, and management
   ```

## Quality Checks

1. **Before Committing**
   - Run all tests
   - Check coverage
   - Verify naming
   - Update documentation

2. **Regular Maintenance**
   - Weekly coverage review
   - Test performance check
   - Documentation updates

## Success Criteria

1. **Organization**
   - All tests in correct directories
   - Consistent file structure
   - Clear naming scheme

2. **Coverage**
   - All enums tested
   - Edge cases covered
   - Error conditions tested

3. **Performance**
   - Tests run under 5 minutes
   - No resource leaks
   - Clean test reports

## Current Progress Tracking

- ✅ Directory structure completed
- ✅ Base test class defined
- ✅ Character tests migrated
- ✅ Combat tests migrated
- ✅ Mission tests migrated
- ✅ Terrain tests migrated
- ⏳ UI tests pending
- ⏳ Campaign tests pending
- ⏳ Core tests pending
- ❌ Integration tests pending

## Next Steps
1. Create missing directories:
   - Create `/tests/unit/core/` directory
   - Create `/tests/unit/ui/` directory if not exists

2. Move remaining files:
   - Move UI tests to `/tests/unit/ui/`
   - Move campaign tests to `/tests/unit/campaign/`
   - Move core tests to `/tests/unit/core/`

3. Clean up:
   - Remove test files (test_basic.gd, test_first.gd, test_simple.gd)
   - Update any broken references in moved files

4. Begin Phase 3:
   - Review and fix resource paths in moved files
   - Add missing lifecycle methods
   - Ensure proper error handling

5. Documentation:
   - Update test README.md with new directory structure
   - Document test patterns and standards
   - Add examples of proper test structure 