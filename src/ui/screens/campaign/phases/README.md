# Campaign Phase Panels

This directory contains the base infrastructure for campaign phase UI panels following the official Five Parsecs from Home rulebook structure.

## Current Status

**MAJOR CLEANUP COMPLETED**: Non-official phase panels have been removed to match the official Four-Phase campaign turn structure from the Five Parsecs from Home rulebook.

## Official Five Parsecs Phase Structure

The official campaign turn consists of exactly **four phases**:

1. **Travel Phase** - Handled by `TravelPhaseUI.tscn` (located in `/src/ui/screens/travel/`)
2. **World Phase** - Handled by `WorldPhaseUI.tscn` (located in `/src/ui/screens/world/`)
3. **Battle Phase** - Handled by `BattlefieldCompanion` system (no UI panel needed in dashboard)
4. **Post-Battle Phase** - Handled by `PostBattleSequence.tscn` (located in `/src/ui/screens/postbattle/`)

## Files in This Directory

- `BasePhasePanel.gd` - Base class for all phase panels
- `README.md` - This documentation file

## Removed Non-Official Phases

The following panels were removed as they don't match the official Five Parsecs rules:

- ❌ `UpkeepPhasePanel` - Functionality moved to World Phase Step 1 (Upkeep and ship repairs)
- ❌ `StoryPhasePanel` - Not an official phase in Five Parsecs rules
- ❌ `CampaignPhasePanel` - Unclear purpose, not official phase
- ❌ `BattleSetupPhasePanel` - Part of Battle Phase, handled by BattlefieldCompanion
- ❌ `BattleResolutionPhasePanel` - Part of Post-Battle Phase
- ❌ `AdvancementPhasePanel` - Part of Post-Battle Phase (Steps 7-11)
- ❌ `TradePhasePanel` - Part of World Phase Step 4 (Assign equipment)
- ❌ `EndPhasePanel` - Campaigns cycle through phases, don't end

## Phase System Architecture

### Official Phase Progression
```
SETUP → TRAVEL → WORLD → BATTLE → POST_BATTLE → TRAVEL (next turn)
```

### Integration Points
- **CampaignPhaseManager** - Coordinates phase transitions using `GameEnums.FiveParsecsCampaignPhase`
- **BattlefieldCompanionManager** - Handles battle phase integration
- **Universal Safety System** - Provides crash prevention and error handling

### Base Panel Structure

All remaining phase panels inherit from `BasePhasePanel` and follow this structure:

1. `setup_phase()` - Initializes the phase
2. `complete_phase()` - Completes the phase  
3. `validate_phase_requirements()` - Validates requirements for phase completion
4. `get_phase_data()` - Returns phase-specific data

## UI Integration Strategy

Phase UI is now distributed to appropriate locations:

- **Travel Phase**: `/src/ui/screens/travel/TravelPhaseUI.tscn`
- **World Phase**: `/src/ui/screens/world/WorldPhaseUI.tscn`
- **Battle Phase**: Handled by BattlefieldCompanion system (no dashboard panel)
- **Post-Battle Phase**: `/src/ui/screens/postbattle/PostBattleSequence.tscn`

## Migration Notes

If you need functionality from removed panels:

1. **Upkeep functionality** → Look in World Phase Step 1 implementation
2. **Advancement functionality** → Look in Post-Battle Phase Steps 7-11
3. **Trade functionality** → Look in World Phase Step 4 implementation
4. **Battle setup/resolution** → Look in BattlefieldCompanion and PostBattleSequence

## Development Guidelines

- Follow official Five Parsecs from Home rulebook for all phase logic
- Use `GameEnums.FiveParsecsCampaignPhase` enum for phase references
- Integrate with existing Travel, World, and Post-Battle UI systems
- Battle phase integration goes through BattlefieldCompanionManager autoload
- Apply Universal Safety System patterns for error handling

---

*Updated: Architectural cleanup completed to match official Five Parsecs rules*