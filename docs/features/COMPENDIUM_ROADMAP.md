# Five Parsecs Campaign Manager - Compendium Integration Roadmap

> **HISTORICAL PLANNING DOCUMENT** (February 2026)
>
> All phases described below are now **COMPLETE**. The Compendium DLC system was fully implemented
> in 10 sprints (Feb 2026). See `docs/gameplay/COMPENDIUM_IMPLEMENTATION.md` for actual implementation
> details and `src/data/compendium_*.gd` for the 6 data files.
>
> Key implementation files:
> - `src/core/systems/DLCManager.gd` — Autoloaded DLC manager with 33 ContentFlags across 3 packs
> - `src/data/compendium_species.gd` — Krag & Skulker species (Trailblazer's Toolkit)
> - `src/data/compendium_equipment.gd` — Advanced training, bot upgrades, ship parts, psionic gear
> - `src/data/compendium_missions_expanded.gd` — Expanded objectives, PvP/Co-op, introductory campaign
> - `src/data/compendium_no_minis.gd` — No-minis combat zones and AI tables
> - `src/data/compendium_world_options.gd` — Fringe world strife, expanded loans, name generation
> - `src/data/compendium_difficulty_toggles.gd` — Difficulty toggles, AI variations, casualty tables
> - `src/core/mission/StealthMissionGenerator.gd` — Stealth mission generation
> - `src/core/mission/StreetFightGenerator.gd` — Street fight generation
> - `src/core/mission/SalvageJobGenerator.gd` — Salvage job generation
> - `src/ui/dialogs/DLCManagementDialog.gd` — DLC ownership + feature toggle UI

## Overview

This document outlines the integration plan for Five Parsecs compendium content into the campaign turn simulator. The core campaign loop (Phases 1-5) is complete. This roadmap covers Phase 7+ expansion features.

---

## Phase 7: Faction System Integration

### Status: COMPLETE (Sprint 7, February 2026)
### Existing Code: `src/core/systems/FactionSystem.gd` (876 lines, fully functional)

### Integration Points

#### 1. Faction Reputation (POST-5)
**Location:** `simulate_campaign_turns.gd:817-819`
**Current:** Simple +1/-1 reputation modifier
**Enhancement:**
```gdscript
# Replace simple reputation with faction-specific tracking
var faction_system = load("res://src/core/systems/FactionSystem.gd").new()

# After battle, update reputation with relevant factions
if battle_result.enemy_faction:
    faction_system.modify_faction_standing(battle_result.enemy_faction, -1)  # Defeated enemy
    # Update allied factions based on battle outcome
```

#### 2. Named Factions
**Compendium Reference:** `docs/gameplay/compendium.md:7300-7700`
**Factions:** Unity, K'Erin, Swift, Precursor

#### 3. Faction Jobs & Loyalty
**FactionSystem.gd Reference:** Lines 395-412 (`generate_faction_mission`)
**Benefits:** Better rewards, faction-specific equipment, storyline integration

### Implementation Checklist
- [ ] Load FactionSystem.gd in simulator initialization
- [ ] Replace generic reputation with `modify_faction_standing()`
- [ ] Track faction standings in campaign_data
- [ ] Generate faction-specific missions instead of generic quests
- [ ] Display faction standings in campaign report

---

## Phase 8: Rival Progression System

### Status: COMPLETE (Sprint 7, February 2026) — Rival location persistence added in 4-Feature Plan Sprint 1-3
### Existing Code: `src/core/systems/FactionSystem.gd:249-323` (Rival management with 6 status levels)

### Integration Points

#### 1. Rival Evolution (POST-6)
**Location:** `simulate_campaign_turns.gd:823-826`
**Current:** Rivals removed on defeat only
**Enhancement:**
- Track rival progression through 6 status levels
- Equipment upgrades after each encounter
- Increasing threat levels
- Rivalry escalation mechanics

#### 2. Rival Reputation Tracking
**Current:** Binary (active/defeated)
**Enhancement:**
```gdscript
# Rival data structure
var rival = {
    "id": "rival_001",
    "name": "Hostile Faction",
    "status_level": 1,  # 1-6 progression
    "equipment_tier": 1,  # Upgrades on encounters
    "encounters": 0,  # Tracks history
    "last_outcome": "PENDING"  # VICTORY, DEFEAT, ESCAPE
}
```

### Implementation Checklist
- [ ] Extend rival structure with progression data
- [ ] Implement post-battle rival equipment upgrades
- [ ] Add rival escalation on defeats
- [ ] Track encounter history
- [ ] Display rival progression in reports

---

## Phase 9: Patron Loyalty & Jobs

### Status: FOUNDATION EXISTS
### Current: Generic quest system with 3-rumor threshold

### Integration Points

#### 1. Patron Jobs (WORLD-5)
**Location:** `simulate_campaign_turns.gd:441-444`
**FactionSystem.gd Reference:** `generate_faction_mission()` (lines 395-412)
**Enhancement:**
- Replace rumor-based quests with patron-specific jobs
- Loyalty tracking (success/failure impact)
- Patron-specific rewards and equipment

#### 2. Patron Discovery
**Current:** Passive discovery through events
**Enhancement:**
- Active patron search during World Phase
- Faction affiliation affects patron availability
- Loyalty levels unlock better jobs

### Implementation Checklist
- [ ] Create PatronManager class or use FactionSystem
- [ ] Track patron loyalty scores (0-100)
- [ ] Generate patron-specific mission types
- [ ] Implement loyalty-based job quality
- [ ] Add patron loss conditions (low loyalty)
- [ ] Display patron relationships in reports

---

## Phase 10: Story Track System

### Status: NOT IMPLEMENTED
### Reference: Five Parsecs Core Rulebook Appendix V, p.153

### Overview
Story Track provides narrative structure through sequential campaign events. Alternative to open-ended campaigns.

### Integration Points

#### 1. Story Track Initialization
**Location:** Campaign creation (`generate_campaign_headless.gd`)
**Data Structure:**
```gdscript
var story_track = {
    "enabled": false,
    "current_stage": 0,
    "total_stages": 20,
    "stages": []  # Pre-defined narrative events
}
```

#### 2. Story Progression
**Location:** TRAVEL-4 (Campaign Events) or POST-Battle
**Mechanics:**
- Certain events advance story track
- Stage-specific challenges and rewards
- Victory condition: Complete all story stages

### Implementation Checklist
- [ ] Design 20-stage story progression
- [ ] Create story event triggers
- [ ] Implement stage-specific challenges
- [ ] Add story track UI/reporting
- [ ] Victory condition integration

---

## Phase 11: Advanced Character Systems

### Potential Expansions (Not in Core Compendium)

#### 1. Crew Relationships
**Status:** NOT CONFIRMED IN OFFICIAL RULES
**Concept:** Track bonds between crew members
**Effects:** Combat synergies, morale events, storylines

#### 2. Character Backgrounds Expansion
**Compendium:** Trailblazer's Toolkit
**New Species, Backgrounds, Motivations**

---

## Implementation Priority

### High Priority (Immediate Value)
1. **Faction Reputation** - Existing system, easy integration
2. **Rival Progression** - Adds depth to combat encounters
3. **Patron Jobs** - Better mission variety

### Medium Priority (Enhanced Gameplay)
4. **Story Track** - Alternative campaign mode
5. **Advanced Faction Features** - Faction-specific equipment, events

### Low Priority (Polish)
6. **Crew Relationships** (if official)
7. **Extended Character Backgrounds**

---

## Testing Strategy

### Integration Testing (Each Phase)
1. Run 20-turn campaign to verify feature works
2. Run 50-turn campaign to verify no state corruption
3. Save/load testing for new state variables
4. Victory condition verification

### Regression Testing
- Ensure core campaign loop (Phases 1-5) still works
- Verify all state variables persist correctly
- Validate no performance degradation

---

## Code Quality Guidelines

### Before Adding Features
1. ✅ Check Framework Bible compliance (20-file limit, no Manager classes)
2. ✅ Review existing FactionSystem.gd for reusable code
3. ✅ Add TODO markers with compendium references
4. ✅ Document integration points

### During Implementation
1. Keep functions focused and single-purpose
2. Use existing patterns from Phases 1-5
3. Add validation in `_validate_campaign_state()`
4. Update save/load in `_save_turn_state()` and `_load_existing_campaign()`

### After Implementation
1. Update this roadmap with actual implementation details
2. Run full regression test suite
3. Update campaign report to show new features
4. Document any deviations from compendium rules

---

## References

### Documentation
- **Compendium Source:** `docs/gameplay/compendium.md` (493KB, 16,949 lines)
- **Core Rulebook:** `docs/gameplay/rules/core_rulebook.txt`
- **Framework Bible:** In Memory MCP (5P Framework Bible entity)

### Existing Systems
- **FactionSystem.gd:** `src/core/systems/FactionSystem.gd` (876 lines)
  - Lines 47-51: Faction standings & relations
  - Lines 249-323: Rival management
  - Lines 313+: Faction loyalty variables
  - Lines 348-356: `get_faction_standing()`, `modify_faction_standing()`
  - Lines 395-412: `generate_faction_mission()`

### Integration Hooks (Current Code)
- **Faction Reputation:** `simulate_campaign_turns.gd:817-819`
- **Rival Progression:** `simulate_campaign_turns.gd:823-826`
- **Patron Jobs:** `simulate_campaign_turns.gd:441-444`

---

## Notes

This is a **living document**. Update as features are implemented or priorities change. The goal is to maintain a clear roadmap while staying flexible to gameplay discoveries during implementation.

**Last Updated:** Implementation of Phases 4-6 (Character Progression, State Persistence, Victory Detection)
**Next Milestone:** Phase 7 - Faction System Integration
