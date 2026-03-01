# World Files Consolidation Plan

## Identified Duplicates

### 1. Planet Files
- `src/core/world/Planet.gd` (FiveParsecsPlanet) - DEPRECATED
- `src/game/world/Planet.gd` (GamePlanet) - Older version
- `src/game/world/GamePlanet.gd` (GamePlanet) - Newer version with world_traits

### 2. Location Files
- `src/core/world/Location.gd` (FiveParsecsLocation)
- `src/game/world/Location.gd` (GameLocation)
- `src/game/world/GameLocation.gd` (GameLocation) - Newer version

### 3. World Manager Files
- `src/core/world/WorldManager.gd` - Minimal implementation
- `src/game/world/WorldManager.gd` - Extended implementation

### 4. GameWorld Files
- `src/core/world/GameWorld.gd` - No class_name
- `src/game/world/GameWorld.gd` - Has class_name FiveParsecsGameWorld

### 5. WorldEconomyManager Files
- `src/core/world/WorldEconomyManager.gd`
- `src/game/world/WorldEconomyManager.gd`

### 6. PlanetCache Files
- `src/core/world/PlanetCache.gd`
- `src/game/world/PlanetCache.gd`

### 7. PlanetNameGenerator Files
- `src/core/world/PlanetNameGenerator.gd`
- `src/game/world/PlanetNameGenerator.gd`

## Consolidation Plan

### Phase 1: Identify the Canonical Files
1. **Planet**: Use `src/game/world/GamePlanet.gd` as the canonical file
2. **Location**: Use `src/game/world/GameLocation.gd` as the canonical file
3. **WorldManager**: Use `src/game/world/GameWorldManager.gd` as the canonical file
4. **GameWorld**: Use `src/game/world/GameWorld.gd` as the canonical file
5. **WorldEconomyManager**: Use `src/game/world/WorldEconomyManager.gd` as the canonical file
6. **PlanetCache**: Use `src/game/world/PlanetCache.gd` as the canonical file
7. **PlanetNameGenerator**: Use either version (they appear identical)

### Phase 2: Update References
1. Scan the codebase for references to the deprecated files
2. Update all references to point to the canonical files
3. Ensure proper class names are used in all references

### Phase 3: Create Migration Utilities
1. Create migration utilities for any data format changes
2. Implement backward compatibility where needed
3. Add deprecation warnings to transitional code

### Phase 4: Remove Duplicates
1. Once all references are updated, remove the duplicate files
2. Verify that the application still functions correctly
3. Update tests to use the canonical files

### Phase 5: Documentation
1. Update documentation to reflect the new file structure
2. Document any API changes
3. Update class diagrams

## Implementation Notes

### GamePlanet Consolidation
- `GamePlanet` in `src/game/world/GamePlanet.gd` is the most up-to-date implementation
- It uses `GameWorldTrait` instead of `world_features`
- It has proper typing for `locations` array
- It includes additional properties like `planet_id`, `sector`, and `coordinates`

### GameLocation Consolidation
- `GameLocation` in `src/game/world/GameLocation.gd` is the most up-to-date implementation
- It includes additional functionality and properties

### WorldManager Consolidation
- `GameWorldManager` in `src/game/world/GameWorldManager.gd` should be the canonical implementation
- It extends a base class and includes additional signals and functionality

## Testing Strategy
1. Create comprehensive tests for each canonical class
2. Verify that all functionality from the deprecated classes is preserved
3. Test migration utilities with various data formats
4. Ensure backward compatibility with saved game data

## Timeline
1. Phase 1: 1 day
2. Phase 2: 2-3 days
3. Phase 3: 1-2 days
4. Phase 4: 1 day
5. Phase 5: 1 day

Total estimated time: 6-8 days 