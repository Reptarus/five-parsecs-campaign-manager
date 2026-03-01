# Official Campaign Rules Implementation - Five Parsecs Campaign Manager

## Implementation Status: COMPLETE (Updated Feb 2026)

The Five Parsecs Campaign Manager implements the **complete Nine-Phase Campaign Turn structure** with full rules compliance. The turn flow was expanded from 4 phases to 9 in February 2026 to support all campaign activities.

## Official Campaign Turn Structure

### Turn Flow (Updated Feb 2026)
```
STORY → TRAVEL → UPKEEP → MISSION → POST_MISSION → ADVANCEMENT → TRADING → CHARACTER → RETIREMENT → (next turn)
```

### Phase Types
- **Handler-driven** (4): Travel, World/Upkeep, Battle/Mission, PostBattle/PostMission
- **UI-driven** (5): Story, Advancement, Trading, Character, Retirement

---

### **PHASE 0: STORY PHASE** - IMPLEMENTED
**File:** `src/ui/screens/campaign/panels/StoryPhasePanel.gd`

- Story events trigger each turn before Travel
- Player resolves or skips story content
- Wired in Sprint 3

---

### **PHASE 1: TRAVEL PHASE** - IMPLEMENTED
**File:** `src/core/campaign/phases/TravelPhase.gd`

**Sub-Steps Implemented:**
1. **Flee Invasion** - Invasion escape mechanics (2D6, 8+ to escape)
2. **Decide Whether to Travel** - Cost calculation (5 credits starship, 1 per crew commercial)
3. **Starship Travel Event** - D100 travel events table with full mechanics
4. **New World Arrival Steps** - World trait generation, rival tracking, licensing

---

### **PHASE 2: UPKEEP PHASE (World Phase)** - IMPLEMENTED
**File:** `src/core/campaign/phases/WorldPhase.gd`

**Sub-Steps Implemented:**
1. **Upkeep and Ship Repairs** - Complete cost calculation
2. **Assign and Resolve Crew Tasks** - All 8 crew tasks
3. **Determine Job Offers** - Patron system integration
4. **Assign Equipment** - Equipment redistribution and stash management
5. **Resolve any Rumors** - Quest trigger system
6. **Choose Your Battle** - Mission selection with rival attack checks

---

### **PHASE 3: MISSION PHASE (Battle Phase)** - IMPLEMENTED
**File:** `src/core/campaign/phases/BattlePhase.gd`

**Features:**
- Automatic transition from Upkeep Phase mission selection
- Battle Phase Manager (tabletop companion, 3-tier tracking)
- Battle result data collection for Post-Battle processing
- When no battle selected, routes through POST_MISSION with `battle_skipped` flag

---

### **PHASE 4: POST_MISSION PHASE (Post-Battle)** - IMPLEMENTED
**File:** `src/core/campaign/phases/PostBattlePhase.gd`

**All 14 Sub-Steps Implemented:**
1. **Resolve Rival Status** - D6+modifiers for rival elimination
2. **Resolve Patron Status** - Contact management
3. **Determine Quest Progress** - D6+Quest Rumors advancement
4. **Get Paid** - Base payment + danger pay + difficulty multiplier
5. **Battlefield Finds** - Search mechanics with item discovery
6. **Check for Invasion** - 2D6, 9+ with difficulty modifiers
7. **Gather the Loot** - Enemy-specific loot tables
8. **Determine Injuries and Recovery** - D100 injury table, Stars of Story protection
9. **Experience and Character Upgrades** - 7 XP sources, bot skip
10. **Invest in Advanced Training** - 2D6 approval, 8 course types
11. **Purchase Items** - Equipment marketplace
12. **Roll for a Campaign Event** - D100 events, Precursor double-roll
13. **Roll for a Character Event** - Personal crew events
14. **Check for Galactic War Progress** - 2D6 per invaded planet

**Post-Completion Processing:**
- Injury recovery tick (runs every turn, including no-battle turns)
- Morale adjustment (MoraleSystem, Sprint 9)
- Character lifetime statistics update
- Battle journal entry creation

**Data Persistence (Verified Feb 2026):**
All 18+ data types persist directly to GameState/campaign during processing:
credits, rivals, patrons, quest progress, invasion status, loot, injuries, XP,
training, Stars of Story, galactic war, character stats, morale, journal entries

---

### **PHASE 5: ADVANCEMENT PHASE** - IMPLEMENTED
**File:** `src/ui/screens/campaign/panels/AdvancementPhasePanel.gd`

- XP spending on stat improvements
- Bot/Precursor credit-based upgrades (Sprint 10)
- UI-driven phase with ContinueButton

---

### **PHASE 6: TRADING PHASE** - IMPLEMENTED
**File:** `src/ui/screens/campaign/panels/TradePhasePanel.gd`

- Equipment purchase/sale via EquipmentManager
- Trading backend wired in Sprint 6
- UI-driven phase

---

### **PHASE 7: CHARACTER PHASE** - IMPLEMENTED
**File:** `src/ui/screens/campaign/panels/CharacterPhasePanel.gd`

- Crew events with weighted random table
- Character development opportunities
- Created in Sprint 1

---

### **PHASE 8: RETIREMENT PHASE** - IMPLEMENTED
**File:** `src/ui/screens/campaign/panels/EndPhasePanel.gd`

- Turn summary with snapshot/delta display (Sprint 5)
- Victory condition checking (21 types, Sprint 4)
- Triggers `start_new_campaign_turn()` on completion

---

## Updated Enum Structure (Feb 2026)

### **Phase System**
```gdscript
enum FiveParsecsCampaignPhase {
    NONE,
    SETUP,              # Initial crew creation
    STORY,              # Story events
    TRAVEL,             # Phase 1: Travel Phase
    PRE_MISSION,        # Legacy: combined pre-mission
    UPKEEP,             # Phase 2: World/Upkeep Phase
    MISSION,            # Phase 3: Battle/Mission Phase
    BATTLE_SETUP,       # Battle sub-phase
    BATTLE_RESOLUTION,  # Battle sub-phase
    POST_MISSION,       # Phase 4: Post-Battle Phase
    ADVANCEMENT,        # Phase 5: XP spending
    TRADING,            # Phase 6: Equipment trading
    CHARACTER,          # Phase 7: Character events
    RETIREMENT,         # Phase 8: Turn end/victory check
}
```

### **Sub-Phase Systems**
```gdscript
enum TravelSubPhase {
    NONE, FLEE_INVASION, DECIDE_TRAVEL, TRAVEL_EVENT, WORLD_ARRIVAL
}

enum WorldSubPhase {
    NONE, UPKEEP, CREW_TASKS, JOB_OFFERS, EQUIPMENT, RUMORS, BATTLE_CHOICE
}

enum PostBattleSubPhase {
    NONE, RIVAL_STATUS, PATRON_STATUS, QUEST_PROGRESS, GET_PAID,
    BATTLEFIELD_FINDS, CHECK_INVASION, GATHER_LOOT, INJURIES,
    EXPERIENCE, TRAINING, PURCHASES, CAMPAIGN_EVENT,
    CHARACTER_EVENT, GALACTIC_WAR
}
```

---

## Campaign Phase Manager

**File:** `src/core/campaign/CampaignPhaseManager.gd` (~761 lines, rewritten Feb 2026)

**Key Features:**
- 9-phase turn coordination with transition table
- 4 phase handlers instantiated as child nodes
- 5 UI-driven phases with `complete_current_phase()`
- Turn-start snapshot for delta calculations
- Data handoff via `_last_phase_completion_data`
- Battle skip path routes through POST_MISSION gracefully

**Signals:**
```gdscript
signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed(phase: int, completion_data: Dictionary)
signal phase_started(phase: int)
signal campaign_turn_started(turn_number: int)
signal campaign_turn_completed(turn_number: int)
```

---

## Rules Compliance

- **9-Phase Campaign Turn**: Complete implementation
- **All Sub-Steps**: Every mechanic from core rulebook
- **Proper Dice Mechanics**: All D6, D10, D100 rolls
- **Table Integration**: All required tables with proper results
- **Resource Economy**: Credits, supplies, equipment management
- **Character Development**: XP, injuries, advancement, training
- **Story Progression**: Quests, events, galactic war tracking
- **Data Persistence**: All 18+ data types verified (Feb 2026)
- **Battle Phase Manager**: Tabletop companion with 3-tier tracking

---

## Compendium DLC Expansion (Feb 2026)

The Five Parsecs Compendium is implemented as paid DLC gated by `DLCManager` with 35 ContentFlags across 3 DLC packs. All compendium features have **zero impact on the core campaign turn flow** when disabled.

### Compendium Additions to Campaign Phases

| Phase | Compendium Addition | DLC Pack |
|-------|-------------------|----------|
| **STORY** | Introductory Campaign guided missions | Fixer's Guidebook |
| **TRAVEL** | Fringe World Strife events at arrival, Psionic legality check | Fixer's / Trailblazer's |
| **UPKEEP** | Expanded Loans, Name Generation | Fixer's Guidebook |
| **MISSION** | Stealth Missions, Street Fights, Salvage Jobs, No-Minis Combat | Fixer's / Freelancer's |
| **POST_MISSION** | Enemy Psionics detection, Salvage trading, Bot injury routing | Trailblazer's / Fixer's |
| **ADVANCEMENT** | Advanced Training (5 types), Bot Upgrades (6 types), Psionic XP | Trailblazer's Toolkit |
| **TRADING** | Psionic Equipment (3 items), Compendium gear | Trailblazer's Toolkit |
| **CHARACTER** | Krag/Skulker species events, Prison Planet option | All packs |
| **RETIREMENT** | Progressive Difficulty tier changes | Freelancer's Handbook |

### Key Compendium Systems
- **Krag & Skulker**: 2 new species with unique rules (Origin enum sync across 2 files)
- **Psionics**: Legality system, 10 enemy powers, PsionicManager campaign integration
- **3 New Mission Types**: Stealth, Street Fight, Salvage (each with dedicated generators)
- **Difficulty System**: Progressive turn-based scaling + 18 individual toggles
- **No-Minis Combat**: Abstract zone-based battles without physical miniatures

See [COMPENDIUM_IMPLEMENTATION.md](COMPENDIUM_IMPLEMENTATION.md) for detailed content specifications.

---

**Last Updated**: 2026-02-08
**Engine**: Godot 4.6-stable
**Test Framework**: GUT (Godot Unit Test)
