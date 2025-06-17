# Script Reference Management

This document summarizes the work done to address class_name conflicts and script reference issues in the codebase.

## Completed Tasks

### 1. Class Name Conflict Resolution

We identified and resolved several `class_name` conflicts in the codebase:

| Class Name | Files with Conflict | Resolution |
|------------|---------------------|------------|
| `InitialCrewCreation` | `src/core/campaign/InitialCrewCreation.gd`<br>`src/core/campaign/crew/InitialCrewCreation.gd` | Kept in crew/InitialCrewCreation.gd |
| `ValidationManager` | `src/core/state/StateValidator.gd`<br>`src/core/systems/ValidationManager.gd` | Kept in systems/ValidationManager.gd |
| `FiveParsecsPathFinder` | `src/utils/helpers/PathFinder.gd`<br>`src/core/utils/PathFinder.gd` | Kept in core/utils/PathFinder.gd |
| `FiveParsecsStatDistribution` | `src/utils/helpers/stat_distribution.gd`<br>`src/core/utils/stat_distribution.gd` | Kept in core/utils/stat_distribution.gd |

For each conflict, we:
1. Removed the `class_name` declaration from the non-authoritative version
2. Added deprecation comments to the non-authoritative version
3. Updated the class_name_conflicts.md document with details

### 2. Documentation

Created documentation to track and manage script references:
- `docs/class_name_conflicts.md` - Details on identified conflicts and resolution strategies
- `docs/script_reference_management.md` (this file) - Summary and next steps

## Remaining Issues

### Linter Errors

There are still linter errors in some of the modified files:
- `src/core/state/StateValidator.gd` - Errors related to ValidationResult.new() calls
- `src/utils/helpers/PathFinder.gd` - Errors related to PathNode.new() calls

These errors are likely due to the removal of the class_name declarations. They will need to be addressed by:
1. Properly qualifying the class references
2. Creating local class definitions
3. Or replacing with proper preloads

### Additional Work Needed

1. **Comprehensive Search**:
   - Need to perform a more thorough search for additional class_name conflicts
   - Current focus has been on obvious duplications in similar directory structures

2. **Reference Refactoring**:
   - Code referencing the non-authoritative versions needs to be updated to use preload/load
   - This requires identifying all places where these classes are referenced

3. **Consolidation Strategy**:
   - For duplicated files with nearly identical functionality, we should consider:
     - Full consolidation (removing duplicate files)
     - Creating forwarding scripts that load the authoritative versions
     - Adding appropriate deprecation warnings

4. **Testing**:
   - Run the game to verify no runtime errors occur
   - Test specific functionality related to the changed classes

## Next Steps

1. Fix remaining linter errors in modified files
2. Conduct thorough testing to ensure no regressions
3. Continue with next phase of the action plan: Campaign Dashboard Completion
4. Consider a more comprehensive script organization review in the future 