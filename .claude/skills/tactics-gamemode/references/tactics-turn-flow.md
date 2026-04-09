# Tactics Turn Flow Reference

## Game Modes

Tactics supports three play modes:

| Mode | Description | Campaign Support |
|------|-------------|-----------------|
| **Solo** | Player vs AI system | Full operational campaign |
| **GM-directed** | Game Master creates scenarios | Narrative campaign |
| **Versus** | Head-to-head pick-up | Optional campaign |

## Operational Campaign Turn Phases

The operational campaign is a strategic layer on top of individual battles:

### Campaign Setup
1. Choose point scale (500/750/1000)
2. Select species for player army
3. Build initial army list (army builder wizard)
4. Generate operational map (sector grid)
5. Place initial forces and objectives

### Campaign Turn Sequence
1. **Strategic Phase** — Move forces on operational map, check supply lines
2. **Intelligence Phase** — Scout enemy positions, gather intel
3. **Orders Phase** — Issue orders to platoons (Attack/Defend/Patrol/Reserve)
4. **Battle Phase** — Resolve tactical battles for contested sectors
5. **Reinforcement Phase** — Receive replacements, repair vehicles
6. **Campaign Events** — D100 event table (reinforcements, betrayals, new characters)
7. **Supply Phase** — Check supply lines, manage logistics
8. **Assessment Phase** — Check victory conditions, update campaign status

### Victory Conditions
- **Sector Control**: Hold X of Y operational zones
- **Army Strength**: Reduce enemy below threshold
- **Objective**: Complete scenario-specific goals
- **Cohesion**: Maintain army cohesion above minimum

## Army Builder Wizard Flow

```
MainMenu → "Tactics" → SceneRouter "tactics_creation" → TacticsCreationUI
  Step 0: Campaign Config (name, point scale, play mode)
  Step 1: Species Selection (14 species with previews)
  Step 2: Army Composition (points-based builder)
  Step 3: Vehicle Selection (if species has vehicles)
  Step 4: Operational Map Generation (if campaign mode)
  Step 5: Review & Deploy
```

### Army Builder UI (TacticsArmyBuilderUI — To Be Created)
- Points budget display (spent / total)
- Unit roster with add/remove
- Composition validation (hero limits, duplicate limits, 35% cap)
- Squad organization (drag-to-platoon)
- Vehicle selection with weapon loadouts
- Preview panel with species special rules

## Battle Resolution

### Turn Structure (within a single battle)
1. **Initiative Phase** — Each side rolls, alternating activations
2. **Activation Phase** — Activate one squad/vehicle at a time
   - Move, Shoot, Assault, or Special Action
   - Squad coherency maintained
3. **Morale Phase** — Check morale for units that took casualties
4. **End Phase** — Check victory conditions, clean up

### Key Mechanics Unique to Tactics
- **Suppression**: Units can be suppressed (lose actions) — tracked per-squad
- **Morale Tests**: Uses Training stat (new, not in other modes)
- **Vehicle Combat**: Armor saves, penetration, transport rules
- **Overwatch**: Units can set overwatch to react to enemy movement
- **Indirect Fire**: Artillery/mortar support (off-table)
- **Observation Tests**: Spotting hidden enemies (uses Savvy)
- **Squad Coherency**: Models must stay within coherency distance

## Solo AI System

When playing solo, the AI system controls enemy forces:
- **AI Behavior Tables**: D6 per squad (Advance/Hold/Flank/Retreat)
- **Priority Targeting**: AI targets closest/most dangerous
- **Reinforcement Timing**: D6-based with escalation
- **Vehicle AI**: Separate behavior table for vehicles

## Dashboard Flow (Future)

```
TacticsDashboard
├── Army Overview (species, points, unit count)
├── Operational Map (if campaign mode)
├── Army Roster (expandable unit cards)
├── Campaign Status (sector control, army strength)
├── Start Battle → TacticalBattleUI with battle_mode: "tactics"
└── Army Builder → TacticsArmyBuilderUI (edit army between battles)
```
