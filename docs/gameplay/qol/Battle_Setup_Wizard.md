# Battle Setup Wizard

**Priority**: P2 - Medium | **Effort**: 3-4 days | **Phase**: 2

## Overview
One-click battle generation from rule tables. Auto-generate enemies, deployment conditions, terrain, and mission parameters.

## Key Features
- Auto-generate enemy composition from tables
- Set deployment zones automatically
- Calculate mission objectives
- Terrain suggestion system
- "Start Battle" quick launch

## Wizard Flow
```
Step 1: Mission Type
  ○ Patrol  ○ Defense  ● Opportunity  ○ Quest

Step 2: Enemy (Auto-Generated)
  Enemy Type: Vent Crawlers (rolled: 6)
  Count: 8 enemies (crew size × 2)
  
Step 3: Deployment
  Crew Zone: Table edge 1-6" (rolled: West edge)
  Enemy Zone: 18"+ from crew (rolled: Scattered)
  
Step 4: Terrain
  Suggested pieces: 6-8 terrain features
  [Auto-Place] [Manual Adjust]
  
[Generate Battlefield →]
```

## Implementation
```gdscript
# BattleSetupWizard.gd
func generate_battle_from_mission(mission: Mission) -> Dictionary
func roll_enemy_type() -> String
func calculate_enemy_count(crew_size: int) -> int
func determine_deployment() -> Dictionary
func suggest_terrain() -> Array[TerrainPiece]
```

## Integration
- Hooks into existing `BattlefieldGenerator.gd`
- Uses `EnemyGenerator.gd` for enemy creation
- Leverages `TerrainFactory.gd` for terrain

---
**Status**: Extends existing battle systems
