# Planetfall Turn Flow Reference

## 18-Step Campaign Turn Sequence (Planetfall pp.55-70)

### PRE-BATTLE (Steps 1-6)

| Step | Name | Description | Key Systems |
|------|------|-------------|-------------|
| 1 | Recovery | Heal characters in Sick Bay (-1 turn each) | `PlanetfallCampaignCore.tick_sick_bay()` |
| 2 | Repairs | Restore Colony Integrity (repair rate + Raw Materials) | `adjust_integrity()`, `spend_raw_materials()` |
| 3 | Scout Reports | Scout Explore action + Scout Discovery table (D100) | Scout class ability, exploration |
| 4 | Enemy Activity | Random Tactical Enemy action (D100: Patrol/Relocate/Occupy/Attack/Raid) | `tactical_enemies`, `enemy_info` |
| 5 | Colony Events | Random colony event (D100, 20 entries) | Colony morale/integrity effects |
| 6 | Mission Determination | Choose mission type based on available options | Mission selection UI |

### BATTLE (Steps 7-8)

| Step | Name | Description | Key Systems |
|------|------|-------------|-------------|
| 7 | Lock and Load | Select characters + equipment from pool for mission | `equipment_pool` assignment |
| 8 | Play Out Mission | Tabletop battle | TacticalBattleUI with `battle_mode: "planetfall"` |

### POST-BATTLE (Steps 9-18)

| Step | Name | Description | Key Systems |
|------|------|-------------|-------------|
| 9 | Injuries | D100 injury table for casualties | Sick bay, character removal |
| 10 | Experience Progression | XP awards + advancement (5 XP per roll, or point-buy) | Per-character XP on roster |
| 11 | Colony Morale Adjustments | -1 auto + -1 per casualty; Crisis check at -10 | `adjust_morale()` |
| 12 | Track Enemy Info & Mission Data | +1 Enemy Info per win; Mission Data processing | `enemy_info`, `mission_data` |
| 13 | Replacements | 2D6 roll for new characters (1 + 1 per Milestone attempts/turn) | `add_roster_character()` |
| 14 | Research | Spend Research Points on Theories/Applications | `research_data` |
| 15 | Building | Spend Build Points on colony Buildings | `buildings_data` |
| 16 | Colony Integrity | Check for Integrity Failure if negative | Integrity failure cascade |
| 17 | Character Event | D100 roleplay event | Per-character narrative |
| 18 | Update Colony Tracking Sheet | Bookkeeping — advance turn | `advance_turn()` |

## Comparison to Other Modes
```
5PFH:        STORY -> TRAVEL -> UPKEEP -> MISSION -> POST_MISSION -> ADVANCEMENT -> TRADING -> CHARACTER -> RETIREMENT
Planetfall:  RECOVERY -> REPAIRS -> SCOUTS -> ENEMY_ACTIVITY -> COLONY_EVENTS -> MISSION_DETERMINATION ->
             LOCK_AND_LOAD -> PLAY_MISSION -> INJURIES -> XP -> MORALE -> TRACK_INFO -> REPLACEMENTS ->
             RESEARCH -> BUILDING -> INTEGRITY -> CHARACTER_EVENT -> UPDATE_SHEET
Bug Hunt:    SPECIAL_ASSIGNMENTS -> MISSION -> POST_BATTLE
```

## PlanetfallPhaseManager (To Be Created)

Should follow BugHuntPhaseManager pattern:

```gdscript
enum PlanetfallPhase {
    RECOVERY,           # 0
    REPAIRS,            # 1
    SCOUT_REPORTS,      # 2
    ENEMY_ACTIVITY,     # 3
    COLONY_EVENTS,      # 4
    MISSION_DETERMINATION, # 5
    LOCK_AND_LOAD,      # 6
    PLAY_MISSION,       # 7
    INJURIES,           # 8
    EXPERIENCE,         # 9
    MORALE,             # 10
    TRACK_INFO,         # 11
    REPLACEMENTS,       # 12
    RESEARCH,           # 13
    BUILDING,           # 14
    INTEGRITY_CHECK,    # 15
    CHARACTER_EVENT,    # 16
    UPDATE_SHEET        # 17
}

signal phase_changed(phase: PlanetfallPhase)
signal phase_completed(phase: PlanetfallPhase, result: Dictionary)
signal turn_completed(turn_number: int)
```

## Dashboard Navigation Flow

```
MainMenu → "Planetfall" → SceneRouter "planetfall_dashboard" → PlanetfallDashboard
  ├─ Colony Overview (stat strip: Turn, Morale, Integrity, Grunts, Milestones, SP)
  ├─ Roster Cards (class pills, loyalty badges)
  ├─ Colony Systems Hub (Buildings, Research, Map — TODO)
  ├─ Start Turn → SceneRouter "planetfall_turn_controller" → PlanetfallTurnController
  └─ Back to Main Menu
```

## Creation Wizard (6-Step Flow)

```
MainMenu → "New Planetfall Campaign" → SceneRouter "planetfall_creation" → PlanetfallCreationUI
  Step 0: Expedition Type (D100 roll — PlanetfallExpeditionPanel)
  Step 1: Character Roster (class selection, sub-species — PlanetfallRosterPanel)
  Step 2: Backgrounds (Motivation + Prior Experience + Notable Event — PlanetfallBackgroundsPanel)
  Step 3: Map Generation (grid size, home sector — PlanetfallMapPanel)
  Step 4: Tutorial Missions (Beacons/Analysis/Perimeter — PlanetfallTutorialPanel)
  Step 5: Final Review (PlanetfallReviewPanel)
```

### Coordinator Pattern
`PlanetfallCreationCoordinator` extends `Node`:
- `signal navigation_updated(can_back, can_forward, can_finish)`
- `signal step_changed(step, total_steps)`
- Accumulated state: `config_data`, `roster_data`, `background_data`, `map_config`, `tutorial_results`
- Step completion flags: `_step_complete: Array[bool]`

### PlanetfallCreationUI Pattern
- Extends `Control` directly (NOT PlanetfallScreenBase — thin shell pattern)
- Uses `preload()` for all panel scripts
- Uses `const` for UIColors references
- `MAX_FORM_WIDTH := 800`
- STEP_NAMES array for step labels
