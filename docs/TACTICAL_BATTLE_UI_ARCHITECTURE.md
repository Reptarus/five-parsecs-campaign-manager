# TacticalBattleUI - Comprehensive Information Architecture

**Last Updated**: 2026-03-15
**Component Count**: 29 core components + root TacticalBattleUI.tscn
**Tier System**: LOG_ONLY (Tier 0), ASSISTED (Tier 1), FULL_ORACLE (Tier 2)
**Battle Phases**: Reaction Roll, Quick Actions, Enemy Actions, Slow Actions, End Phase
**Special Modes**: Bug Hunt (ContactMarkerPanel), No Minis Combat (NoMinisCombatPanel), Stealth (StealthMissionPanel)

---

## Table of Contents

1. [Scene Structure](#scene-structure)
2. [Master Component Visibility Matrix](#master-component-visibility-matrix)
3. [Tier-Specific Features](#tier-specific-features)
4. [Phase-Specific Enable/Disable Logic](#phase-specific-enabledisable-logic)
5. [Signal Architecture & Parent-Child Relationships](#signal-architecture--parent-child-relationships)
6. [Player Interactions by Tier & Phase](#player-interactions-by-tier--phase)
7. [BattleRoundTracker Integration](#battleround tracker-integration)
8. [Component Groupings & Organization](#component-groupings--organization)
9. [Data Flow Patterns](#data-flow-patterns)
10. [Implementation Notes](#implementation-notes)

---

## Scene Structure

### Root: TacticalBattleUI (Control)

```
TacticalBattleUI (root Control, script: TacticalBattleUI.gd)
├─ MainContainer (VBoxContainer)
│  ├─ TopBar (HBoxContainer, h=52px)
│  │  ├─ TitleLabel ("Tactical Companion", 24pt)
│  │  ├─ TierBadge ("[LOG ONLY]" or "[ASSISTED]" or "[FULL ORACLE]")
│  │  ├─ Spacer (size_flags_horizontal = 3)
│  │  ├─ ReturnButton (blue theme)
│  │  └─ AutoResolveButton (blue theme)
│  │
│  ├─ ContentArea (HBoxContainer, grow_vertical = 3)
│  │  ├─ LeftSidebar (PanelContainer, 280px)
│  │  │  └─ LeftTabs (TabContainer)
│  │  │     ├─ Crew (ScrollContainer)
│  │  │     │  └─ CrewContent (VBoxContainer, unique_name)
│  │  │     ├─ Units (ScrollContainer)
│  │  │     │  └─ UnitsContent (VBoxContainer, unique_name)
│  │  │     └─ Enemies (ScrollContainer)
│  │  │        └─ EnemiesContent (VBoxContainer, unique_name)
│  │  │
│  │  ├─ CenterArea (VBoxContainer, stretch_ratio = 2.0)
│  │  │  ├─ BattlefieldGridPanel (PanelContainer, custom_min_size = (0, 420))
│  │  │  │  └─ [TerrainVisualization - sector grid, shape rendering]
│  │  │  │
│  │  │  └─ CenterTabs (TabContainer)
│  │  │     ├─ Battle Log (VBoxContainer)
│  │  │     │  └─ BattleLogContent (VBoxContainer, unique_name)
│  │  │     │     └─ FallbackLog (RichTextLabel, unique_name, bbcode_enabled)
│  │  │     ├─ Tracking (ScrollContainer)
│  │  │     │  └─ TrackingContent (VBoxContainer, unique_name)
│  │  │     └─ Events (ScrollContainer)
│  │  │        └─ EventsContent (VBoxContainer, unique_name)
│  │  │
│  │  └─ RightSidebar (PanelContainer, 280px)
│  │     └─ RightTabs (TabContainer)
│  │        ├─ Tools (ScrollContainer)
│  │        │  └─ ToolsContent (VBoxContainer, unique_name)
│  │        ├─ Reference (ScrollContainer)
│  │        │  └─ ReferenceContent (VBoxContainer, unique_name)
│  │        └─ Setup (ScrollContainer)
│  │           └─ SetupContent (VBoxContainer, unique_name)
│  │
│  └─ BottomBar (PanelContainer)
│     └─ BottomContent (HBoxContainer)
│        ├─ TurnIndicator (Label, "Deployment Phase", unique_name)
│        ├─ PhaseButtonsContainer (HBoxContainer, unique_name)
│        └─ EndTurnButton (Button, "End Turn", unique_name)
│
└─ OverlayLayer (CanvasLayer, layer=10)
   ├─ OverlayBackground (ColorRect, visible=false, color=(0,0,0,0.85))
   └─ OverlayCenter (CenterContainer, visible=false)
      └─ OverlayContent (VBoxContainer)
```

**Key Layout Metrics**:
- TopBar: 52px height (title + badge + buttons)
- LeftSidebar: 280px fixed width (crew tabs)
- RightSidebar: 280px fixed width (tools/reference tabs)
- CenterArea: stretch_ratio 2.0 (responsive battlefield view)
- BattlefieldGridPanel: minimum 420px height (terrain visualization)
- Touch targets: All interactive elements ≥48px (UIColors.TOUCH_TARGET_MIN)
- Spacing: 4px (XS), 8px (SM), 16px (MD), 24px (LG), 32px (XL)

---

## Master Component Visibility Matrix

### Legend

- **A** = Always visible (independent of tier)
- **0** = Tier 0 (LOG_ONLY)
- **1** = Tier 1 (ASSISTED)
- **2** = Tier 2 (FULL_ORACLE)
- **B** = Bug Hunt mode (conditional on `battle_mode == "bug_hunt"`)
- **—** = Not applicable / hidden at this tier

| Component | Tier 0 | Tier 1 | Tier 2 | Always | Bug Hunt | Stealth | No Minis | Parent Container | Scene Path |
|-----------|--------|--------|--------|--------|----------|---------|----------|------------------|-----------|
| **ALWAYS-VISIBLE CORE** |
| BattleRoundHUD | A | A | A | ✓ | A | A | A | BottomBar | `src/ui/components/battle/BattleRoundHUD.gd` |
| ReactionDicePanel | A | A | A | ✓ | A | A | A | RightTabs/Tools | `src/ui/components/battle/ReactionDicePanel.gd` |
| BattleJournal | A | A | A | ✓ | A | A | A | CenterTabs/Battle Log | `src/ui/components/battle/BattleJournal.gd` |
| DiceDashboard | A | A | A | ✓ | A | A | A | RightTabs/Tools | `src/ui/components/battle/DiceDashboard.gd` |
| CheatSheetPanel | A | A | A | ✓ | A | A | A | RightTabs/Reference | `src/ui/components/battle/CheatSheetPanel.gd` |
| BattlefieldGridPanel | A | A | A | ✓ | A | — | — | CenterArea | `src/ui/components/battle/BattlefieldGridPanel.gd` |
| **TIER 0 (LOG_ONLY)** |
| CharacterStatusCard | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | CrewContent/UnitsContent | `src/ui/components/battle/CharacterStatusCard.gd` |
| **TIER 1 (ASSISTED)** |
| BattleRoundTracker | — | ✓ | ✓ | — | ✓ | — | — | CenterTabs/Tracking | `src/ui/components/battle/BattleRoundTracker.gd` |
| InitiativeCalculator | — | ✓ | ✓ | — | ✓ | — | — | RightTabs/Tools | `src/ui/components/battle/InitiativeCalculator.gd` |
| ReactionDicePanel | — | ✓ | ✓ | — | ✓ | — | — | RightTabs/Tools | `src/ui/components/battle/ReactionDicePanel.gd` |
| EventResolutionPanel | — | ✓ | ✓ | — | ✓ | — | — | CenterTabs/Events | `src/ui/components/battle/EventResolutionPanel.gd` |
| VictoryProgressPanel | — | ✓ | ✓ | — | ✓ | — | — | RightTabs/Reference | `src/ui/components/battle/VictoryProgressPanel.gd` |
| ActivationTrackerPanel | — | ✓ | ✓ | — | ✓ | — | — | RightTabs/Tools | `src/ui/components/battle/ActivationTrackerPanel.gd` |
| CombatCalculator | — | ✓ | ✓ | — | ✓ | — | — | RightTabs/Tools | `src/ui/components/battle/CombatCalculator.gd` |
| MoralePanicTracker | — | ✓ | ✓ | — | ✓ | — | — | RightTabs/Reference | `src/ui/components/battle/MoralePanicTracker.gd` |
| ObjectiveDisplay | — | ✓ | ✓ | — | ✓ | ✓ | — | CenterTabs/Events | `src/ui/components/battle/ObjectiveDisplay.gd` |
| PreBattleChecklist | — | ✓ | ✓ | — | ✓ | — | — | OverlayLayer | `src/ui/components/battle/PreBattleChecklist.gd` |
| BattlefieldMapView | — | ✓ | ✓ | — | ✓ | — | — | RightTabs/Reference | `src/ui/components/battle/BattlefieldMapView.gd` |
| CombatSituationPanel | — | ✓ | ✓ | — | ✓ | — | — | RightTabs/Tools | `src/ui/components/battle/CombatSituationPanel.gd` |
| WeaponTableDisplay | — | ✓ | ✓ | — | ✓ | — | — | RightTabs/Reference | `src/ui/components/battle/WeaponTableDisplay.gd` |
| EnemyIntentPanel | — | ✓ | ✓ | — | ✓ | — | — | RightTabs/Reference | `src/ui/components/battle/EnemyIntentPanel.gd` |
| EnemyGenerationWizard | — | ✓ | ✓ | — | ✓ | — | — | OverlayLayer | `src/ui/components/battle/EnemyGenerationWizard.gd` |
| DeploymentConditionsPanel | — | ✓ | ✓ | — | ✓ | — | — | CenterTabs/Events | `src/ui/components/battle/DeploymentConditionsPanel.gd` |
| **TIER 2 (FULL_ORACLE ONLY)** |
| TierSelectionPanel | — | — | ✓ | — | — | — | — | OverlayLayer | `src/ui/components/battle/TierSelectionPanel.gd` |
| **SPECIAL MODES** |
| ContactMarkerPanel | — | B | B | — | **✓** | — | — | RightTabs/Tools | `src/ui/components/battle/ContactMarkerPanel.gd` |
| StealthMissionPanel | — | — | — | — | — | **✓** | — | CenterTabs/Events | `src/ui/components/battle/StealthMissionPanel.gd` |
| NoMinisCombatPanel | — | — | — | — | — | — | **✓** | CenterArea | `src/ui/components/battle/NoMinisCombatPanel.gd` |
| **UTILITY/REFERENCE** |
| DualInputRoll | — | ✓ | ✓ | — | ✓ | ✓ | — | [Reusable] | `src/ui/components/battle/DualInputRoll.gd` |
| BattlefieldShapeLibrary | A | A | A | ✓ | A | — | — | [Utility] | `src/ui/components/battle/BattlefieldShapeLibrary.gd` |
| UnitActivationCard | — | ✓ | ✓ | — | ✓ | — | — | ActivationTrackerPanel | `src/ui/components/battle/UnitActivationCard.gd` |
| CharacterStatusCardSpeciesExample | — | — | — | — | — | — | — | [Test/Doc] | `src/ui/components/battle/CharacterStatusCardSpeciesExample.gd` |

**Total Components**: 29 documented components

---

## Tier-Specific Features

### Tier 0: LOG_ONLY
**Purpose**: Minimal UI for experienced tabletop players who manage all mechanics manually. Logging focus.

**Visible Components**:
- CharacterStatusCard: Name + health + damage/stun buttons only (minimal stats display)
- BattleRoundHUD, ReactionDicePanel, BattleJournal, DiceDashboard, CheatSheetPanel, BattlefieldGridPanel

**Key Method**: `CharacterStatusCard.set_display_tier(0)` → hides reaction/savvy stats, shows only "Combat + Tough"

**Player Responsibility**: Full manual tracking. Components show only state, no suggestions.

---

### Tier 1: ASSISTED
**Purpose**: Structured tabletop companion with calculation helpers, activation tracking, and AI intent display.

**Visible Components**:
- All of Tier 0
- PLUS: BattleRoundTracker (phase progression), InitiativeCalculator, EventResolutionPanel, VictoryProgressPanel, ActivationTrackerPanel, CombatCalculator (to-hit/damage formulas), MoralePanicTracker, ObjectiveDisplay, PreBattleChecklist, BattlefieldMapView, CombatSituationPanel, WeaponTableDisplay, EnemyIntentPanel, EnemyGenerationWizard, DeploymentConditionsPanel
- ActivationTrackerPanel spawns UnitActivationCard children (72px compact cards)
- DualInputRoll embedded in multiple panels for dice input

**Key Methods**:
- `CharacterStatusCard.set_display_tier(1)` → shows "Combat + Tough + Reaction + Savvy + Weapon", status includes "[ACTIVATED]"
- `BattleRoundTracker.initialize_round()` → progresses phases automatically
- `EnemyIntentPanel.set_oracle_mode(false)` → shows intent icons without oracle suggestions
- `CombatCalculator.quick_to_hit(combat, cover, range_mod)` → returns hit probability

**Workflows**:
- Pre-battle: PreBattleChecklist validates crew/enemy setup, DeploymentConditionsPanel shows conditions
- Deployment Phase: ActivationTrackerPanel manages unit order, InitiativeCalculator runs seize rolls
- Combat: CombatSituationPanel tracks modifiers, CombatCalculator shows to-hit chance, BattleRoundTracker shows current phase
- Post-Battle: VictoryProgressPanel shows victory/defeat condition

---

### Tier 2: FULL_ORACLE
**Purpose**: Advanced mode with AI-powered suggestions, oracle cards, and reference data.

**Visible Components**:
- All of Tier 1
- PLUS: TierSelectionPanel (entrance UI), EnemyIntentPanel in ORACLE mode (showing oracle suggestions)

**Key Methods**:
- `CharacterStatusCard.set_display_tier(2)` → same as Tier 1 (no additional card detail)
- `EnemyIntentPanel.set_oracle_mode(true)` → enables oracle reference/card draws
- `TierSelectionPanel.tier_selected(tier)` → signal to initialize UI at chosen tier

**Oracle Modes** (EnemyIntentPanel):
1. Reference Mode: Links to Five Parsecs rules sections
2. D6 Table Mode: Rolls result on tactical D6 tables
3. Card Oracle Mode: Draws from oracle deck for narrative suggestions

---

## Phase-Specific Enable/Disable Logic

### Five Battle Phases

```
1. REACTION_ROLL      (Setup phase: Initiative/seize rolls)
2. QUICK_ACTIONS      (Movement & reaction fire)
3. ENEMY_ACTIONS      (Enemy turn actions)
4. SLOW_ACTIONS       (Standing/aimed/heavy weapon actions)
5. END_PHASE          (Morale, wound resolution, end-of-round effects)
```

### Phase Visibility Table

| Component | Reaction Roll | Quick Actions | Enemy Actions | Slow Actions | End Phase |
|-----------|---------------|---------------|---------------|--------------|-----------|
| CharacterStatusCard | ✓ | ✓ | ✓ | ✓ | ✓ |
| InitiativeCalculator | ✓ | — | — | — | — |
| BattleRoundTracker | ✓ | ✓ | ✓ | ✓ | ✓ |
| ActivationTrackerPanel | — | ✓ | ✓ | ✓ | — |
| CombatCalculator | — | ✓ | ✓ | ✓ | — |
| CombatSituationPanel | — | ✓ | ✓ | ✓ | — |
| EnemyIntentPanel | — | ✓ | ✓ | — | — |
| MoralePanicTracker | — | — | — | — | ✓ |
| DeploymentConditionsPanel | ✓ | — | — | — | — |
| PreBattleChecklist | ✓ | — | — | — | — |
| VictoryProgressPanel | — | — | — | — | ✓ |
| BattleJournal | ✓ | ✓ | ✓ | ✓ | ✓ |
| BattleRoundHUD | ✓ | ✓ | ✓ | ✓ | ✓ |
| EventResolutionPanel | — | ✓ | ✓ | ✓ | ✓ |
| ObjectiveDisplay | ✓ | ✓ | ✓ | ✓ | ✓ |

**Phase Transition Logic**:
- BattleRoundTracker.advance_phase() triggers:
  1. Hide current phase UI
  2. Update TurnIndicator label
  3. Show next phase UI
  4. Emit phase_changed signal
  5. Freeze EndTurnButton until phase complete

---

## Signal Architecture & Parent-Child Relationships

### Root Signals (TacticalBattleUI.gd)

```gdscript
signal tier_changed(new_tier: int)
signal phase_started(phase: int)
signal phase_completed(phase: int)
signal battle_completed(result: Dictionary)
signal return_requested
signal auto_resolve_requested
```

### Component Signal Hierarchy

#### ALWAYS-VISIBLE → Parent

```
BattleRoundHUD.phase_changed(phase_num)
  ↓ [TacticalBattleUI]
  → Enables/disables phase-specific components

BattleJournal.entry_added(entry_type, text)
  ↓ [TacticalBattleUI]
  → Updates log display

DiceDashboard.dice_rolled(result, dice_string)
  ↓ [TacticalBattleUI]
  → Broadcasts to all components needing roll result

BattleRoundHUD.end_turn_requested
  ↓ [TacticalBattleUI]
  → Validates phase complete, advances to next phase
```

#### TIER 1 Components → Parent

```
BattleRoundTracker.phase_advanced(new_phase)
  ↓ [TacticalBattleUI]
  → Updates UI for new phase

ActivationTrackerPanel.unit_activated(unit_id)
  ↓ [TacticalBattleUI]
  → Marks UnitActivationCard as activated

ActivationTrackerPanel.unit_selected(unit_id)
  ↓ [TacticalBattleUI]
  → Highlights CharacterStatusCard (crew) or EnemyCard (enemies)

CombatCalculator.calculation_completed(calc_type, result)
  ↓ [TacticalBattleUI]
  → Displays result in CombatSituationPanel, logs to BattleJournal

EnemyIntentPanel.intent_revealed(enemy_id, intent_icon)
  ↓ [TacticalBattleUI]
  → Updates EnemyIntentPanel display

EnemyGenerationWizard.enemies_generated(enemies)
  ↓ [TacticalBattleUI]
  → Populates EnemiesContent with generated enemies

PreBattleChecklist.checklist_completed
  ↓ [TacticalBattleUI]
  → Enables phase_started signal, hides overlay

DeploymentConditionsPanel.condition_acknowledged()
  ↓ [TacticalBattleUI]
  → Enables deployment phase UI

CharacterStatusCard.damage_taken(char_name, amount)
  ↓ [TacticalBattleUI]
  → Logs to BattleJournal, updates VictoryProgressPanel

CharacterStatusCard.stun_marked(char_name)
  ↓ [TacticalBattleUI]
  → Logs to BattleJournal, updates MoralePanicTracker

CharacterStatusCard.action_used(char_name, action_type)
  ↓ [TacticalBattleUI]
  → Updates ActivationTrackerPanel if unit acts
```

#### TIER 2 Components → Parent

```
TierSelectionPanel.tier_selected(tier)
  ↓ [TacticalBattleUI]
  → Calls set_display_tier(tier) on all components
  → Hides TierSelectionPanel overlay
  → Emits tier_changed(tier)

EnemyIntentPanel.oracle_instruction_ready(instruction_text)
  ↓ [TacticalBattleUI]
  → Displays in modal, awaits acknowledgment
```

#### BUG HUNT Special Signals

```
ContactMarkerPanel.contact_revealed(marker_id, enemy_data)
  ↓ [TacticalBattleUI]
  → Adds enemy to EnemiesContent, updates BattleJournal

ContactMarkerPanel.priority_spawning_result(new_contacts)
  ↓ [TacticalBattleUI]
  → Spawns new enemy cards in real-time
```

### Parent → Child Method Calls (Downward)

```
TacticalBattleUI._on_tier_selected(tier)
  ├─ CharacterStatusCard.set_display_tier(tier)
  ├─ BattleRoundTracker.set_display_tier(tier)
  ├─ ActivationTrackerPanel.set_display_tier(tier)
  ├─ CombatCalculator.set_display_tier(tier)
  ├─ EnemyIntentPanel.set_display_tier(tier)
  └─ All TIER 1+ components.set_display_tier(tier)

TacticalBattleUI._on_battle_started()
  ├─ PreBattleChecklist.show()
  ├─ BattleRoundTracker.initialize_round(1, REACTION_ROLL)
  └─ TurnIndicator.text = "Reaction Roll Phase"

TacticalBattleUI._on_phase_advanced(new_phase)
  ├─ TurnIndicator.text = phase_names[new_phase]
  ├─ ActivationTrackerPanel.refresh_for_phase(new_phase)
  ├─ CombatCalculator.enable() if combat phase
  ├─ MoralePanicTracker.show() if END_PHASE
  └─ EndTurnButton.disabled = false (allow next phase)

TacticalBattleUI._on_unit_activated(unit_id)
  ├─ [Find UnitActivationCard for unit_id]
  └─ UnitActivationCard.set_activated(true)
```

---

## Player Interactions by Tier & Phase

### Tier 0 (LOG_ONLY)

**Available at all phases** (except where noted):

1. **ReactionDicePanel** — Roll D6 for crew reactions (always)
2. **DiceDashboard** — Quick dice rolls (D3, D6, 2D6, D66, D100)
3. **CharacterStatusCard buttons**:
   - Damage button (apply 1 damage)
   - Stun button (add stun marker)
   - Use Action button (decrement actions_remaining)
4. **BattleJournal** — Read-only chronological log
5. **CheatSheetPanel** — Read-only rules reference (accordion sections)
6. **BattlefieldGridPanel** — View terrain, shape overlays (read-only)

**Disabled Interactions**:
- No activation tracking
- No calculation helpers
- No oracle mode
- No enemy intent display
- No condition modifiers

---

### Tier 1 (ASSISTED)

**All Tier 0 interactions PLUS**:

#### Pre-Battle Phase (Reaction Roll Phase)
1. **PreBattleChecklist** (modal overlay)
   - Checkbox: Crew briefed
   - Checkbox: Enemies generated
   - Checkbox: Deployment conditions rolled
   - Button: Confirm (enable Reaction Roll Phase)

2. **EnemyGenerationWizard** (modal overlay, if needed)
   - Dropdown: Mission Type
   - Slider: Difficulty (1-5)
   - Dropdown: Enemy Category
   - Button: Generate (creates enemies with stats)

3. **DeploymentConditionsPanel**
   - Button: Roll Condition (generates random condition)
   - Button: Details (shows condition effects)
   - Display: Current rolled condition + effects summary

#### Deployment Phase (Quick Actions Phase start)
1. **ActivationTrackerPanel** (RightTabs/Tools)
   - UnitActivationCard list (ordered by initiative)
   - Button per card: Click to mark as activated
   - Display: Green dot = acted, gray dot = not acted, red dot = dead
   - Auto-advance to next un-activated unit

2. **InitiativeCalculator**
   - Input: Attacker combat skill
   - Button: Roll Seize Initiative
   - Display: Result vs threshold
   - Auto-populate ActivationTrackerPanel order

#### Combat Phases (Quick Actions, Enemy Actions, Slow Actions)
1. **CombatSituationPanel** (RightTabs/Tools)
   - Toggles: Cover (light/heavy), Elevation, Point Blank, Long Range, Moving Target, Aimed, Stunned, Prone, Flanking
   - Display: Total modifier (+/-)
   - Method: get_total_modifier() → CombatCalculator

2. **CombatCalculator** (RightTabs/Tools)
   - Dropdown: Calculation Mode (To-Hit, Damage, Brawling, Reaction)
   - Inputs: Combat skill, Cover, Range modifier (mode-dependent)
   - Button: Calculate
   - Display: Rich text explanation + hit probability

3. **EnemyIntentPanel** (RightTabs/Reference, non-Oracle mode)
   - Display: Enemy unit with intent icons [M]=Movement, [A]=Attack, [D]=Defense, [F]=Fire
   - Button: Reveal Next Enemy (reveals intent one by one)
   - Display: Target highlights, coverage badges

4. **WeaponTableDisplay** (RightTabs/Reference)
   - Dropdown tabs: All, Pistols, Rifles, Heavy, Melee, Special
   - Search box: Filter weapons
   - Click weapon: Expands to show Damage, ROF, Range, Cost, Notes
   - Signal: weapon_selected(weapon_data)

5. **BattlefieldMapView** (RightTabs/Reference)
   - Display: 4×4 overhead grid (A1-D4 sectors)
   - Visual: Terrain shapes rendered at 1.0 scale (larger than BattlefieldGridPanel)
   - Interaction: Click sector → highlight in BattlefieldGridPanel

#### End Phase
1. **MoralePanicTracker** (RightTabs/Reference)
   - Display: Enemy morale level (numerical), panic tracker
   - Button: Roll Morale (for enemy units)
   - Display: Panic outcome (flight, break, rally, regrouped)

2. **VictoryProgressPanel** (RightTabs/Reference)
   - Display: Victory condition progress (e.g., "Objectives: 2/5 completed")
   - Display: Battle outcome (in progress / won / lost)

#### Always Accessible
1. **ObjectiveDisplay** (CenterTabs/Events)
   - Read-only mission objectives

2. **BattleRoundTracker** (CenterTabs/Tracking)
   - Display: Round number (1-5+), current phase
   - Button: End Turn (if phase conditions met)
   - Method: advance_phase() → auto-transitions

---

### Tier 2 (FULL_ORACLE)

**All Tier 1 interactions PLUS**:

1. **TierSelectionPanel** (modal overlay at battle start)
   - Three large buttons (LOG_ONLY, ASSISTED, FULL_ORACLE)
   - Color-coded borders (blue, cyan, purple)
   - Signal: tier_selected(tier)
   - Action: Hides overlay, enables selected tier

2. **EnemyIntentPanel** (Oracle Mode)
   - Radio button: Toggle between Reference / D6 Table / Card Oracle
   - **Reference Mode**: Links to Five Parsecs rules (p.XXX)
   - **D6 Table Mode**: 
     - Button: Roll D6
     - Display: Tactical table result (e.g., "Flank maneuver", "Suppressing fire")
   - **Card Oracle Mode**:
     - Button: Draw Card
     - Display: Oracle card text (AI suggestion for enemy action)

---

## BattleRoundTracker Integration

### Primary Responsibility

**BattleRoundTracker.gd** is the phase progression engine. It:
1. Tracks current round number (1-5+ per Five Parsecs rules)
2. Manages phase sequence (REACTION_ROLL → QUICK_ACTIONS → ENEMY_ACTIONS → SLOW_ACTIONS → END_PHASE)
3. Validates phase completion before advancing
4. Emits phase_advanced signal when phase changes
5. Updates TurnIndicator label on TacticalBattleUI

### Integration Points

```
TacticalBattleUI
├─ _on_tier_selected(tier)
│  └─ BattleRoundTracker.set_display_tier(tier)
│
├─ _on_battle_started()
│  ├─ BattleRoundTracker.initialize_round(1, REACTION_ROLL)
│  └─ TurnIndicator.text = "Reaction Roll"
│
├─ _on_phase_advanced(new_phase)
│  ├─ BattleRoundTracker.validate_phase_complete()
│  ├─ BattleRoundTracker.advance_phase()
│  ├─ CenterTabs.current_tab = 1 (switch to Tracking tab)
│  └─ TurnIndicator.text = phase_names[new_phase]
│
└─ _on_end_turn_pressed()
   ├─ BattleRoundTracker.is_phase_complete() [validate]
   ├─ BattleRoundTracker.advance_phase()
   └─ EndTurnButton.disabled = true (freeze until phase ready)

ActivationTrackerPanel
├─ unit_activated(unit_id)
│  └─ [Tracks activation order in BattleRoundTracker]
│
└─ _on_all_units_activated()
   └─ BattleRoundTracker.mark_phase_complete(QUICK_ACTIONS)

BattleRoundTracker
├─ phase_advanced(new_phase)
│  ├─ TacticalBattleUI._on_phase_advanced()
│  └─ All tier-specific components._on_phase_advanced()
│
└─ round_ended()
   ├─ MoralePanicTracker.update_morale()
   └─ CharacterStatusCard.reset_round() [for all cards]
```

### Round Structure

**Five Parsecs Battle Round** (per Core Rules p.38):

```
Round N
├─ Reaction Roll Phase (beginning of round)
│  └─ Each crew rolls 1D6 + Reactions to determine Seize Initiative priority
│  └─ Enemy rolls 1D6 + Reactions
│  └─ Order determines who acts first (highest total acts first)
│
├─ Quick Actions Phase (friendly activation)
│  └─ Activated crew units take quick actions
│  └─ Each unit: 1 Action (shoot, move, etc.) + movement (up to Speed)
│
├─ Enemy Actions Phase
│  └─ Enemy units take actions (same 1 action + movement)
│  └─ May trigger crew Reaction Fire (opportunity fire)
│
├─ Slow Actions Phase (standing/aimed/heavy)
│  └─ Crew take standing actions (aimed shots, heavy weapons, second action)
│  └─ Requires standing still (0 movement)
│
└─ End Phase
   ├─ Morale Rolls (any panicked enemies)
   ├─ Casualty/Wound Resolution
   ├─ Round ends, BattleRoundTracker.current_round++
   └─ Repeat until victory/defeat condition met
```

### Phase Completion Criteria

| Phase | Completion Check | Trigger |
|-------|------------------|---------|
| Reaction Roll | All crew + enemies rolled | EndTurnButton enabled |
| Quick Actions | All crew units activated | ActivationTrackerPanel.all_units_activated() |
| Enemy Actions | All enemies completed | Manual button press (table-driven) |
| Slow Actions | All standing actions resolved | Manual button press |
| End Phase | Morale + casualties resolved | EndTurnButton auto-enabled |

---

## Component Groupings & Organization

### By Spatial Layout

#### TopBar Components
- TitleLabel (display)
- TierBadge (display tier via text)
- ReturnButton (exit battle)
- AutoResolveButton (quick resolution)

#### LeftSidebar Components (CrewContent / EnemiesContent / UnitsContent)
- CharacterStatusCard × N (crew + generics + enemies)
- Generated dynamically per battle setup

#### CenterArea Components
- **BattlefieldGridPanel**: Always visible, terrain + shape rendering
- **BattleRoundHUD**: Battle round/phase display (ALWAYS)
- **BattleJournal** (CenterTabs/Battle Log): Event chronology (ALWAYS)
- **BattleRoundTracker** (CenterTabs/Tracking): Phase progression (ASSISTED+)
- **ObjectiveDisplay** (CenterTabs/Events): Mission goals (ASSISTED+)
- **DeploymentConditionsPanel** (CenterTabs/Events): Pre-battle conditions (ASSISTED+)
- **StealthMissionPanel** (CenterTabs/Events): Stealth mode (STEALTH)
- **EventResolutionPanel** (CenterTabs/Events): Event handling (ASSISTED+)

#### RightSidebar Components
- **RightTabs/Tools** (ASSISTED+):
  - ReactionDicePanel
  - InitiativeCalculator
  - ActivationTrackerPanel (spawns UnitActivationCard children)
  - CombatCalculator
  - CombatSituationPanel
  - ContactMarkerPanel (Bug Hunt)
  
- **RightTabs/Reference** (ASSISTED+):
  - CheatSheetPanel (ALWAYS, but expanded in ASSISTED+)
  - WeaponTableDisplay
  - BattlefieldMapView
  - VictoryProgressPanel
  - MoralePanicTracker
  - EnemyIntentPanel

- **RightTabs/Setup** (ASSISTED+):
  - PreBattleChecklist (in overlay, but spawned from Setup)

#### BottomBar Components
- TurnIndicator (Label, ALWAYS)
- PhaseButtonsContainer (HBoxContainer, phase-specific buttons)
- EndTurnButton (Button, ALWAYS, but disabled between phases)

#### OverlayLayer Components (Modal Dialogs)
- TierSelectionPanel (FULL_ORACLE entry)
- PreBattleChecklist (ASSISTED+ pre-battle)
- EnemyGenerationWizard (ASSISTED+ ad-hoc enemy creation)
- OverlayBackground / OverlayCenter (semi-transparent backdrop)

### By Functional Domain

#### Battle State & Tracking
- BattleRoundHUD (phase/round display)
- BattleRoundTracker (phase progression engine)
- ActivationTrackerPanel (unit activation order + state)
- UnitActivationCard (individual unit status, 72px compact)

#### Character & Unit Status
- CharacterStatusCard (crew member health/actions/status)
- CharacterStatusCard (enemy unit status display)

#### Calculation & Reference
- CombatCalculator (to-hit/damage/brawling formulas)
- CombatSituationPanel (modifier toggles)
- InitiativeCalculator (seize initiative rolls)
- WeaponTableDisplay (weapon reference cards)

#### Tactical Display
- BattlefieldGridPanel (terrain grid with shape overlays)
- BattlefieldMapView (4×4 overhead grid view)
- BattlefieldShapeLibrary (utility: terrain shape classification + rendering)

#### Scenario Management
- PreBattleChecklist (pre-battle validation)
- DeploymentConditionsPanel (deployment condition rolls)
- EnemyGenerationWizard (enemy creation wizard)
- ObjectiveDisplay (mission objectives)

#### Monitoring
- BattleJournal (event log)
- EventResolutionPanel (event/escalation handling)
- DiceManager/DiceDashboard (quick dice rolls)
- ReactionDicePanel (crew reaction tracking)

#### Enemy AI & Strategy
- EnemyIntentPanel (enemy intent display + oracle)
- MoralePanicTracker (enemy morale/panic state)
- ContactMarkerPanel (Bug Hunt scanner blips)

#### Meta
- TierSelectionPanel (tier selection at battle start)
- CheatSheetPanel (rules reference)
- VictoryProgressPanel (victory/defeat tracking)

#### Special Modes
- StealthMissionPanel (stealth mission flow, Stealth mode)
- NoMinisCombatPanel (zone-based abstract combat, No Minis mode)
- ContactMarkerPanel (scanner blips, Bug Hunt mode)

#### Utility (Non-UI)
- BattlefieldShapeLibrary (terrain shape enum + draw primitives)
- DualInputRoll (reusable dual-input dice component)

---

## Data Flow Patterns

### Initialization Flow

```
TacticalBattleUI._ready()
├─ Initialize tier to 0 (LOG_ONLY)
├─ Populate CrewContent with CharacterStatusCard × N
├─ Populate UnitsContent with generic unit cards (mercenaries, etc.)
├─ Populate EnemiesContent with enemy cards (initially empty)
├─ Call show_tier_selection() [Tier 2 only]
└─ Emit tier_changed(tier) after selection

→ TierSelectionPanel.tier_selected(selected_tier)
├─ TacticalBattleUI.set_display_tier(selected_tier)
├─ All components.set_display_tier(selected_tier)
└─ BattleRoundTracker.initialize_round(1, REACTION_ROLL)

→ Battle Setup (Tier 1+)
├─ PreBattleChecklist.show() in overlay
├─ Player checks: Crew briefed? Enemies generated? Conditions rolled?
└─ PreBattleChecklist.checklist_completed() → proceed to Reaction Roll

→ Reaction Roll Phase
├─ ReactionDicePanel: Roll crew reactions (1D6 per crew member)
├─ EnemyIntentPanel: Display enemy intent icons
├─ InitiativeCalculator (if Tier 1+): Calculate seize initiative
└─ EndTurnButton enabled → proceed to Quick Actions

→ Quick Actions Phase
├─ ActivationTrackerPanel: Show unit order (sorted by initiative)
├─ Player clicks each unit card to mark activated
├─ CharacterStatusCard: Show current actions_remaining
└─ All units activated → BattleRoundTracker.mark_phase_complete()

... (continues through remaining phases)
```

### Character Damage Flow

```
Player clicks CharacterStatusCard.DamageButton
├─ CharacterStatusCard.apply_damage(1) [hardcoded, should be dialog]
├─ Update current_health, character_data["health"]
├─ CharacterStatusCard._update_display()
├─ Emit damage_taken(char_name, 1)
│
→ TacticalBattleUI._on_damage_taken(char_name, amount)
├─ Log to BattleJournal.add_entry("damage", "%s took %d damage" % [char_name, amount])
├─ Update VictoryProgressPanel casualties count
├─ If health <= 0:
│  ├─ Log "%s is out of action"
│  ├─ Update ActivationTrackerPanel (mark as dead)
│  ├─ Emit character_casualty(char_name)
│  └─ Check victory condition (VictoryProgressPanel)
└─ If all crew incapacitated: battle_completed("defeat")
```

### Activation Tracking Flow

```
InitiativeCalculator.quick_seize_initiative(crew_reactions, enemy_reactions)
├─ Player enters crew reaction bonuses
├─ Button: Roll Seize Initiative
├─ Calculations: ((crew_roll + bonus) vs (enemy_roll + bonus))
│
→ Result: Crew wins / Enemy wins / Tied
├─ Determine activation order (winner acts first)
├─ Return order list [unit_id, unit_id, ...]
│
→ ActivationTrackerPanel.set_activation_order(order_list)
├─ Create UnitActivationCard × N (in order)
├─ Display in vertical stack
├─ First card highlighted (ready to activate)
│
→ Player clicks UnitActivationCard
├─ UnitActivationCard.set_activated(true)
├─ Visual: dot changes green
├─ Emit activation_toggled(unit_id)
│
→ TacticalBattleUI._on_unit_activated(unit_id)
├─ Find CharacterStatusCard for unit_id (crew only)
├─ Update CharacterStatusCard._is_activated = true
├─ Call CharacterStatusCard._apply_tier_display() [shows "[ACTIVATED]"]
├─ Move focus to next un-activated unit
└─ When all units activated: BattleRoundTracker.mark_phase_complete()
```

### Combat Resolution Flow

```
Player toggles CombatSituationPanel modifiers (cover, aimed, etc.)
├─ CombatSituationPanel.set_modifier("cover_light", true) [+2]
├─ Button: Calculate
│
→ CombatCalculator.quick_to_hit(combat_skill, cover, range_mod)
├─ Formula: effective_target = max(1, (3 + cover + range) - combat_skill)
├─ Hit chance = ((7.0 - effective_target) / 6.0) * 100.0%
├─ Format rich text explanation
├─ Emit calculation_completed("to_hit", result_dict)
│
→ TacticalBattleUI._on_calculation_completed(calc_type, result)
├─ Log to BattleJournal.add_entry("combat", "%s to-hit: %d%%" % [name, hit_chance])
├─ Display result in RichTextLabel (color-coded: cyan for probability)
└─ BattleJournal auto-scrolls to latest entry

[Player rolls dice at table]
→ ReactionDicePanel / DiceDashboard.dice_rolled(result)
├─ Log to BattleJournal: "Player rolled [result] vs [requirement]"
├─ If hit: Log "HIT - [outcome text]"
│  └─ CharacterStatusCard.apply_damage(damage_amount)
│     └─ Cascade: damage_taken signal → BattleJournal update → VictoryProgressPanel check
└─ If miss: Log "MISS"
```

### Enemy Intent Reveal Flow

```
EnemyIntentPanel.reveal_next_enemy() [Tier 1+, non-Oracle mode]
├─ Get next un-revealed enemy from battle state
├─ Roll/determine intent icons [M]/[A]/[D]/[F]
├─ Display enemy card with icons
├─ Highlight target (if [A])
│
→ EnemyIntentPanel.intent_revealed(enemy_id, intent_icons)
├─ Log to BattleJournal: "Enemy: [name] intends [intent description]"
├─ Update EnemyIntentPanel display
└─ Await player acknowledgment (button click)

[Tier 2 FULL_ORACLE mode]
→ EnemyIntentPanel.set_oracle_mode(true)
├─ Enable Reference/D6 Table/Card Oracle buttons
├─ Button: Get Oracle Suggestion
│  └─ Match intent to oracle rules or draw oracle card
├─ Display suggestion text in modal
└─ Player implements suggestion (or ignores, TL choice)
```

---

## Implementation Notes

### Tier-Aware Display Pattern

All ASSISTED+ components use this pattern:

```gdscript
# State variable
var _display_tier: int = 0  # 0=LOG_ONLY, 1=ASSISTED, 2=FULL_ORACLE

# Public setter
func set_display_tier(tier: int) -> void:
    _display_tier = tier
    _apply_tier_display()

# Private applicator
func _apply_tier_display() -> void:
    match _display_tier:
        0:  # LOG_ONLY
            stats_label.text = "Combat: %d | Tough: %d" % [combat, toughness]
            status_label.text = "Ready"
        1:  # ASSISTED
            stats_label.text = "Combat: %d | Tough: %d | React: %d | Savvy: %d" % [combat, toughness, reactions, savvy]
            status_label.text = "[ACTIVATED]" if _is_activated else "Ready"
            weapon_label.show()
        2:  # FULL_ORACLE
            # (same as Tier 1, but oracle buttons enabled)
```

### Phase Transition Validation

BattleRoundTracker enforces phase completion:

```gdscript
func is_phase_complete() -> bool:
    match current_phase:
        REACTION_ROLL:
            return all_crew_reactions_rolled and all_enemies_reactions_rolled
        QUICK_ACTIONS:
            return all_units_activated
        ENEMY_ACTIONS:
            return all_enemies_completed
        SLOW_ACTIONS:
            return all_standing_actions_resolved
        END_PHASE:
            return all_casualties_resolved

func advance_phase() -> void:
    if not is_phase_complete():
        push_error("Cannot advance phase: incomplete")
        return
    
    current_phase += 1
    if current_phase > END_PHASE:
        current_round += 1
        current_phase = REACTION_ROLL
    
    phase_advanced.emit(current_phase)
```

### Signal Naming Convention

All components use consistent signal naming:

- **Upward** (to parent): `signal_name` → `_on_signal_name()`
  - Example: `damage_taken` → parent's `_on_damage_taken(char_name, amount)`
  
- **Downward** (to child): Direct method calls
  - Example: `child.set_display_tier(tier)` (not a signal, direct call)
  
- **Cross-component**: Via parent relay
  - Example: ActivationTrackerPanel emits `unit_activated(unit_id)` → TacticalBattleUI relays to CharacterStatusCard via method call

### UIColors Integration

All ASSISTED+ components use UIColors design system:

```gdscript
# Spacing (8px grid)
SPACING_XS := 4
SPACING_SM := 8
SPACING_MD := 16
SPACING_LG := 24
SPACING_XL := 32

# Touch targets
TOUCH_TARGET_MIN := 48  # UnitActivationCard.custom_minimum_size.y

# Colors
COLOR_BLUE := Color("#2D5A7B")      # Primary accent
COLOR_GREEN := Color("#10B981")     # Success/activated
COLOR_RED := Color("#DC2626")       # Danger/dead
COLOR_AMBER := Color("#D97706")     # Warning/low HP

# Font sizes
FONT_SIZE_SM := 14
FONT_SIZE_MD := 16
FONT_SIZE_LG := 18
```

### Bug Hunt Validation

ContactMarkerPanel and related Bug Hunt code guarded by:

```gdscript
# In TacticalBattleUI._ready()
if get_node_or_null("/root/GameState"):
    var campaign = GameState.current_campaign
    if "main_characters" in campaign:  # Bug Hunt campaign type check
        battle_mode = "bug_hunt"
        _setup_bug_hunt_ui()

# In all shared components
if battle_mode == "bug_hunt":
    ContactMarkerPanel.show()
    CheatSheetPanel._add_compendium_sections()  # Adds Bug Hunt specific rules
```

### DualInputRoll Reusability

DualInputRoll is embedded in multiple components:

```gdscript
# In InitiativeCalculator
var seize_roll = DualInputRoll.new()
seize_roll.set_dice_string("1d6+bonus")
seize_roll.roll_completed.connect(_on_seize_roll_complete)

# In DeploymentConditionsPanel
var condition_roll = DualInputRoll.new()
condition_roll.set_dice_string("2d6")
condition_roll.roll_completed.connect(_on_condition_rolled)
```

### Accessibility via TweenFX

All ASSISTED+ components check animation preference:

```gdscript
func _apply_tier_display() -> void:
    # ... display logic ...
    
    if UIColors.should_animate() and _display_tier >= 1:
        TweenFX.pop_in(stats_label, 0.3)
        TweenFX.fade_in(status_label, 0.2)
```

---

## Gotchas & Common Pitfalls

1. **CharacterStatusCard.apply_damage() is hardcoded to 1**
   - Should open DamageInputDialog (deferred in Phase 25)
   - Currently bypasses dialog, auto-applies 1 damage

2. **PreBattleChecklist modal is not dismissible**
   - Overlay covers entire screen until checklist complete
   - Hides all combat UI during setup
   - Ensure all three checkboxes pass before continuing

3. **BattleRoundTracker.is_phase_complete() has no timeout**
   - If phase completion signal never fires, battle hangs
   - EndTurnButton remains disabled indefinitely
   - Validate all phase completion paths

4. **EnemyIntentPanel dual-mode switching**
   - Switching from Reference → Oracle mode disables Reference buttons
   - Must re-initialize component to switch back
   - Consider debounce on mode toggle

5. **ContactMarkerPanel 4×4 grid is static**
   - Sector labels A1-D4 hardcoded
   - No resizing support for different grid sizes
   - Markers can overlap if multiple spawned in same sector

6. **UnitActivationCard colors are global**
   - Green = activated, Gray = ready, Red = dead
   - No colorblind-friendly pattern (shape/icon)
   - Accessibility issue for ~8% of players

7. **VictoryProgressPanel doesn't auto-check conditions**
   - Must manually call check_victory_condition()
   - Battle may show "won" but continue indefinitely
   - Ensure TacticalBattleUI calls check after each phase

8. **DiceManager.roll() is synchronous**
   - DiceDashboard awaits result immediately
   - No streaming of rolls (one button click = one roll)
   - Cannot queue multiple rolls

9. **BattlefieldShapeLibrary.draw_shapes_packed() is single-pass**
   - Shapes are packed left-to-right, top-to-bottom
   - No re-layout on dynamic cell size changes
   - Recreate shapes if grid cell size changes

10. **CheatSheetPanel accordion state is transient**
    - Expanding/collapsing sections not persisted
    - Refreshing battle resets all sections to collapsed
    - Useful for repeated reads, but state is lost

---

## Summary

**TacticalBattleUI** is a three-tier tabletop companion UI with 29 core components organized across five battle phases. The architecture uses:

- **Visibility tiers** (LOG_ONLY → ASSISTED → FULL_ORACLE) to progressively unlock features
- **Phase-gated components** (only relevant UI shown per phase)
- **Upward signal flow** (child → parent) for state changes
- **Downward method calls** (parent → child) for tier/phase updates
- **Reusable components** (DualInputRoll, UnitActivationCard, CharacterStatusCard) across all modes
- **Special mode support** (Bug Hunt, Stealth, No Minis Combat) via conditional component loading

**Key Design Principles**:
1. Mobile-first (48px touch targets, responsive layout)
2. Tier-aware display (show only relevant information at selected tier)
3. Phase-driven UX (disable UI inappropriate for current phase)
4. Rules-accurate calculations (Five Parsecs formulas in CombatCalculator)
5. Accessibility (DLCManager gating, animation preferences, colorblind-friendly badges planned)

This document serves as the reference for TacticalBattleUI architecture and should be updated whenever new components are added or component visibility rules change.
