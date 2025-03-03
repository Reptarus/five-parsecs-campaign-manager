# Campaign Files Consolidation Plan

## Identified Duplicates/Related Files

### 1. PostBattlePhase Files
- `src/core/campaign/PostBattlePhase.gd` - UI-focused implementation
- `src/game/campaign/FiveParsecsPostBattlePhase.gd` - Game-specific implementation extending BasePostBattlePhase
- `src/base/campaign/BasePostBattlePhase.gd` - Base class

### 2. PreBattleLoop Files
- `src/core/campaign/PreBattleLoop.gd`
- `src/game/campaign/FiveParsecsPreBattleLoop.gd`
- `src/base/campaign/BasePreBattleLoop.gd` - Base class

### 3. Campaign Manager Files
- `src/core/campaign/CampaignManager.gd`
- `src/core/campaign/GameCampaignManager.gd`
- `src/game/campaign/FiveParsecsCampaignManager.gd`

### 4. Campaign Files
- `src/core/campaign/Campaign.gd`
- `src/game/campaign/FiveParsecsCampaign.gd`

### 5. Campaign Creation Files
- `src/core/campaign/CampaignCreationManager.gd`
- `src/core/campaign/CampaignSystem.gd`

### 6. Crew-related Files
- Multiple files in `src/core/campaign/crew/`
- Multiple files in `src/game/campaign/crew/`

## Consolidation Plan

### Phase 1: Analyze Inheritance Structure
1. Verify the inheritance structure for PostBattlePhase and PreBattleLoop
2. Ensure that the base classes provide the necessary functionality
3. Identify any missing functionality in the base classes

### Phase 2: Consolidate PostBattlePhase
1. Determine if `src/core/campaign/PostBattlePhase.gd` should be refactored to extend BasePostBattlePhase
2. Update `src/game/campaign/FiveParsecsPostBattlePhase.gd` to include any missing functionality
3. Create a UI component separate from the core logic if needed

### Phase 3: Consolidate PreBattleLoop
1. Similar approach to PostBattlePhase
2. Ensure proper inheritance and separation of concerns

### Phase 4: Consolidate Campaign Managers
1. Identify the primary responsibilities of each manager
2. Create a clear hierarchy with proper inheritance
3. Eliminate redundant functionality

### Phase 5: Consolidate Campaign Files
1. Ensure proper inheritance from base classes
2. Eliminate redundant functionality
3. Update references throughout the codebase

### Phase 6: Consolidate Crew-related Files
1. Analyze the relationships between crew files
2. Create a clear hierarchy with proper inheritance
3. Eliminate redundant functionality

## Implementation Notes

### PostBattlePhase Consolidation
- `src/core/campaign/PostBattlePhase.gd` appears to be UI-focused
- `src/game/campaign/FiveParsecsPostBattlePhase.gd` extends BasePostBattlePhase and contains game logic
- Consider separating UI and logic more clearly

### PreBattleLoop Consolidation
- Similar considerations to PostBattlePhase
- Ensure proper separation of UI and logic

### Campaign Manager Consolidation
- Determine the primary responsibilities of each manager
- Create a clear hierarchy with proper inheritance
- Consider using composition over inheritance where appropriate

## Testing Strategy
1. Create comprehensive tests for each consolidated class
2. Verify that all functionality from the original classes is preserved
3. Test the interaction between UI and logic components
4. Ensure backward compatibility with saved game data

## Timeline
1. Phase 1: 1-2 days
2. Phase 2: 2 days
3. Phase 3: 2 days
4. Phase 4: 2-3 days
5. Phase 5: 1-2 days
6. Phase 6: 2-3 days

Total estimated time: 10-14 days 