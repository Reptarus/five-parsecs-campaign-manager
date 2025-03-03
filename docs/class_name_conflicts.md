# Class Name Conflict Resolution

This document tracks identified `class_name` conflicts in the codebase and their resolution strategies.

## Identified Conflicts

### InitialCrewCreation

**Files with conflict:**
- `src/core/campaign/InitialCrewCreation.gd`
- `src/core/campaign/crew/InitialCrewCreation.gd`

**Resolution:**
- Keep `class_name InitialCrewCreation` in `src/core/campaign/crew/InitialCrewCreation.gd` (more comprehensive implementation)
- Remove `class_name` from `src/core/campaign/InitialCrewCreation.gd` and update any references to use explicit preloads

**Implementation Notes:**
- The version in `crew/` directory is more comprehensive with UI components and full crew creation workflow
- The version in the campaign directory appears to be a minimal/older implementation

### ValidationManager

**Files with conflict:**
- `src/core/state/StateValidator.gd`
- `src/core/systems/ValidationManager.gd`

**Resolution:**
- Keep `class_name ValidationManager` in `src/core/systems/ValidationManager.gd` (more extensively referenced)
- Remove `class_name` from `src/core/state/StateValidator.gd` and rename to `StateValidationManager`

**Implementation Notes:**
- The version in `systems/` is referenced in the CampaignPhaseManager
- The version in `state/` appears to be used less frequently

### FiveParsecsPathFinder

**Files with conflict:**
- `src/utils/helpers/PathFinder.gd`
- `src/core/utils/PathFinder.gd`

**Resolution:**
- Keep `class_name FiveParsecsPathFinder` in `src/core/utils/PathFinder.gd` (core directory is primary)
- Remove `class_name` from `src/utils/helpers/PathFinder.gd` 

**Implementation Notes:**
- Both files appear to be nearly identical 
- The version in `core/utils/` should be the authoritative version as it follows the core directory structure pattern
- The `utils/helpers/` version appears to be a duplicate that should be removed entirely or redirected

### FiveParsecsStatDistribution

**Files with conflict:**
- `src/utils/helpers/stat_distribution.gd`
- `src/core/utils/stat_distribution.gd`

**Resolution:**
- Keep `class_name FiveParsecsStatDistribution` in `src/core/utils/stat_distribution.gd` (core directory is primary)
- Remove `class_name` from `src/utils/helpers/stat_distribution.gd`

**Implementation Notes:**
- Similar to the PathFinder conflict, this follows the same directory structure pattern
- The version in `core/utils/` should be the authoritative version
- The `utils/helpers/` version appears to be a duplicate that should be consolidated

## Resolution Guidelines

When resolving `class_name` conflicts:

1. **Identify the authoritative class**:
   - Choose the more complete/current implementation
   - Consider which version is referenced more frequently

2. **Update non-authoritative version**:
   - Remove `class_name` declaration
   - Add a comment explaining why class_name was removed
   - Add a reference to the authoritative class if needed

3. **Refactor references**:
   - Update any code referencing the non-authoritative class to use preload() or load() with absolute paths
   - Example: `const AuthClass = preload("res://path/to/auth_class.gd")`

4. **Documentation**:
   - Document the change in this file
   - Consider adding a deprecation warning to the non-authoritative class

## Testing Strategy

After resolving conflicts:
1. Run the game to verify no runtime errors occur
2. Test specific functionality related to the changed classes
3. Look for compilation errors or warnings 