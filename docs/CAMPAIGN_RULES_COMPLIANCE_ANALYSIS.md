# Five Parsecs Campaign Manager - Rules Compliance Analysis

## Executive Summary

After thorough analysis of the Five Parsecs from Home core rules, our current campaign implementation has **significant gaps** compared to the official Four-Phase campaign turn structure. We need substantial updates to achieve 1:1 rules compliance.

## Official Campaign Turn Structure (Core Rules)

### **PHASE 1: TRAVEL PHASE** ⚠️ **MISSING**
1. **Flee Invasion** (if applicable) - ❌ Not implemented
2. **Decide Whether to Travel** - ❌ Not implemented  
3. **Starship Travel Event** (if applicable) - ❌ Not implemented
4. **New World Arrival Steps** (if applicable) - ❌ Not implemented

### **PHASE 2: WORLD PHASE** ⚠️ **PARTIAL**
1. **Upkeep and Ship Repairs** - ✅ Partially implemented in UpkeepPhaseUI.gd
2. **Assign and Resolve Crew Tasks** - ❌ Not fully implemented
3. **Determine Job Offers** - ✅ Partially implemented in JobOffersPanel.gd
4. **Assign Equipment** - ❌ Not implemented
5. **Resolve any Rumors** - ❌ Not implemented
6. **Choose Your Battle** - ❌ Not implemented

### **PHASE 3: TABLETOP BATTLE** ✅ **IMPLEMENTED**
- Battle mechanics are well-developed in our combat system

### **PHASE 4: POST-BATTLE SEQUENCE** ⚠️ **PARTIAL**  
1. **Resolve Rival Status** - ❌ Not implemented
2. **Resolve Patron Status** - ❌ Not implemented
3. **Determine Quest Progress** - ❌ Not implemented
4. **Get Paid** - ❌ Not implemented
5. **Battlefield Finds** - ❌ Not implemented
6. **Check for Invasion** - ❌ Not implemented
7. **Gather the Loot** - ❌ Not implemented
8. **Determine Injuries and Recovery** - ❌ Not implemented
9. **Experience and Character Upgrades** - ❌ Not implemented
10. **Invest in Advanced Training** - ❌ Not implemented
11. **Purchase Items** - ❌ Not implemented
12. **Roll for a Campaign Event** - ❌ Not implemented
13. **Roll for a Character Event** - ❌ Not implemented
14. **Check for Galactic War Progress** - ❌ Not implemented

## Current vs Official Phase Structure Comparison

### **Our Current Phases (INCORRECT)**
```
SETUP → UPKEEP → STORY → CAMPAIGN → BATTLE_SETUP → BATTLE_RESOLUTION → ADVANCEMENT → TRADE → END
```

### **Official Rules Phases (CORRECT)**
```
TRAVEL → WORLD → BATTLE → POST_BATTLE
```

## Critical Implementation Gaps

### **1. Travel Phase System - COMPLETELY MISSING**
**Required Files:**
- `src/core/campaign/phases/TravelPhase.gd` - Core travel logic
- `src/core/campaign/phases/InvasionHandler.gd` - Handle invasion events
- `src/core/campaign/phases/StarshipTravelEvents.gd` - Travel event processor
- `src/core/campaign/phases/WorldArrivalHandler.gd` - New world mechanics
- `src/ui/screens/campaign/phases/TravelPhasePanel.gd` - UI implementation

**Key Mechanics:**
- Invasion escape mechanics (2D6, 8+ to escape)
- Travel cost calculation (5 credits starship, 1 per crew commercial)
- Starship travel events table (D100)
- World trait generation and licensing

### **2. World Phase Sub-Steps - MOSTLY MISSING**
**Required Files:**
- `src/core/campaign/phases/CrewTasksManager.gd` - Crew activity assignment
- `src/core/campaign/phases/UpkeepManager.gd` - Enhanced upkeep handling
- `src/core/campaign/phases/RumorsManager.gd` - Rumor and quest system
- `src/core/campaign/phases/EquipmentAssignment.gd` - Equipment management
- `src/core/campaign/phases/BattleChoiceManager.gd` - Mission selection

**Key Mechanics:**
- 8 different crew tasks (Find Patron, Train, Trade, Recruit, Explore, Track, Repair, Decoy)
- Upkeep cost calculation (1 credit for 4-6 crew, +1 per additional)
- Rumor-to-Quest conversion system
- Equipment redistribution and Stash management

### **3. Post-Battle Sequence - COMPLETELY MISSING**
**Required Files:**
- `src/core/campaign/phases/PostBattlePhase.gd` - Enhanced post-battle logic
- `src/core/campaign/phases/RivalManager.gd` - Rival status resolution
- `src/core/campaign/phases/PatronManager.gd` - Patron relationship management
- `src/core/campaign/phases/QuestProgressManager.gd` - Quest advancement
- `src/core/campaign/phases/LootManager.gd` - Battlefield finds and loot
- `src/core/campaign/phases/InjuryManager.gd` - Injury and recovery system
- `src/core/campaign/phases/AdvancementManager.gd` - XP and character growth
- `src/core/campaign/phases/EventManager.gd` - Campaign and character events
- `src/ui/screens/campaign/phases/PostBattlePhasePanel.gd` - UI implementation

**Key Mechanics:**
- 14-step post-battle sequence
- Rival elimination mechanics
- Quest progression system
- Injury and recovery tables
- Experience and advancement system
- Campaign event system

## Required Table Systems

### **Missing Core Tables**
1. **Starship Travel Events Table** (D100) - Travel complications
2. **World Traits Table** (D100) - Planet characteristics
3. **Crew Tasks Results Tables** - For each of 8 crew activities
4. **Exploration Table** (D100) - Exploration results
5. **Trade Table** - Trading opportunities
6. **Injury Tables** - Character damage resolution
7. **Campaign Events Table** - Random campaign events
8. **Character Events Table** - Personal crew events
9. **Loot Tables** - Battlefield rewards by enemy type

### **Partially Implemented Tables**
1. **Patron Tables** - Need enhancement for persistence and contacts
2. **Enemy Tables** - Need integration with loot system

## Documentation Updates Required

### **1. Update GlobalEnums.gd**
```gdscript
enum FiveParcsecsCampaignPhase {
    NONE,
    TRAVEL,        # Official Phase 1
    WORLD,         # Official Phase 2  
    BATTLE,        # Official Phase 3
    POST_BATTLE    # Official Phase 4
}

enum TravelSubPhase {
    NONE,
    FLEE_INVASION,
    DECIDE_TRAVEL,
    TRAVEL_EVENT,
    WORLD_ARRIVAL
}

enum WorldSubPhase {
    NONE,
    UPKEEP,
    CREW_TASKS,
    JOB_OFFERS,
    EQUIPMENT,
    RUMORS,
    BATTLE_CHOICE
}

enum PostBattleSubPhase {
    NONE,
    RIVAL_STATUS,
    PATRON_STATUS,
    QUEST_PROGRESS,
    GET_PAID,
    BATTLEFIELD_FINDS,
    CHECK_INVASION,
    GATHER_LOOT,
    INJURIES,
    EXPERIENCE,
    TRAINING,
    PURCHASES,
    CAMPAIGN_EVENT,
    CHARACTER_EVENT,
    GALACTIC_WAR
}
```

### **2. Create Official Rules Documentation**
- `docs/rules/OFFICIAL_CAMPAIGN_TURNS.md` - Complete turn structure
- `docs/rules/TRAVEL_PHASE_RULES.md` - Travel phase mechanics
- `docs/rules/WORLD_PHASE_RULES.md` - World phase mechanics  
- `docs/rules/POST_BATTLE_RULES.md` - Post-battle sequence
- `docs/rules/CORE_TABLES.md` - All required tables

### **3. Update Implementation Guides**
- `docs/DEVELOPMENT_IMPLEMENTATION_GUIDE.md` - Add rules compliance section
- `docs/architecture.md` - Update with correct phase structure
- `docs/project_status.md` - Reflect rules compliance status

## Priority Implementation Order

### **Phase 1: Critical Structure Updates**
1. Update GlobalEnums.gd with correct phase structure
2. Create base classes for each official phase
3. Update existing phase managers to use correct structure

### **Phase 2: Travel Phase Implementation**
1. Create TravelPhase.gd with all sub-steps
2. Implement invasion mechanics
3. Implement travel events system
4. Create world arrival mechanics

### **Phase 3: World Phase Enhancement**
1. Expand UpkeepManager with full mechanics
2. Create CrewTasksManager for 8 crew activities
3. Implement rumors and quest system
4. Create equipment assignment system

### **Phase 4: Post-Battle Implementation**
1. Create comprehensive PostBattlePhase.gd
2. Implement all 14 post-battle sub-steps
3. Create injury and advancement systems
4. Implement campaign event system

### **Phase 5: Table Systems**
1. Implement all missing core tables
2. Create table lookup and processing systems
3. Integrate tables with phase mechanics

## Expected Outcome

Upon completion, our Five Parsecs Campaign Manager will achieve:

- ✅ **100% rules compliance** with official campaign turn structure
- ✅ **Complete coverage** of all four official phases
- ✅ **Full implementation** of all sub-steps and mechanics
- ✅ **Accurate table systems** matching core rulebook
- ✅ **Seamless integration** between digital and tabletop play

This will make our application the definitive digital companion for Five Parsecs from Home campaigns.