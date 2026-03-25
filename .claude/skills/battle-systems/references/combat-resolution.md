# Combat Resolution Reference

## BattleResolver.gd
- **Path**: `src/core/battle/BattleResolver.gd`
- **extends**: RefCounted
- **class_name**: BattleResolver
- **Usage**: Static methods only — never instantiate as Node

## Main Entry Point

```gdscript
static func resolve_battle(
    crew_deployed: Array,
    enemies_deployed: Array,
    battlefield_data: Dictionary,
    deployment_condition: Dictionary,
    dice_roller: Callable
) -> Dictionary
```

**Returns**:
```json
{
  "success": true,
  "rounds_fought": 4,
  "crew_casualties": 1,
  "enemies_defeated": 5,
  "held_field": true,
  "loot_opportunities": [],
  "battlefield_finds": 2,
  "crew_units_final": [],
  "enemy_units_final": [],
  "deployment_effects": {}
}
```

## Constants (Five Parsecs Rules)
```
MAX_COMBAT_ROUNDS := 6    (p.118)
MIN_COMBAT_ROUNDS := 3
HOLD_FIELD_ENEMY_THRESHOLD := 3    (Core Rules p.119)
VICTORY_LOSS_RATIO_MULTIPLIER := 1.5
DEFAULT_TOUGHNESS := 3
```

## Deployment Modifiers
```
AMBUSH_HIT_BONUS := 2
SURROUNDED_ENEMY_BONUS := 2
SURROUNDED_CREW_PENALTY := -1
DEFENSIVE_COVER_BONUS := 1
HEADLONG_ASSAULT_HIT_BONUS := 1
```

Applied in `initialize_battle()` based on `deployment_condition` dict.

## Battle Flow

```
1. initialize_battle(crew, enemies, deployment_condition)
   → Apply deployment condition effects
   → Return initial battle state

2. For each round (MIN_COMBAT_ROUNDS to MAX_COMBAT_ROUNDS):
   execute_combat_round(round, crew_units, enemy_units, battlefield_data, condition_effects, dice_roller)
   → Each side attacks
   → Check for battle end conditions

3. calculate_battle_outcome(crew_casualties, enemy_casualties, crew_deployed, enemies_deployed)
   → Determine victory/defeat
   → Calculate held_field
```

## Initiative Check
```
_check_initiative(crew_units, dice_roller) -> bool
# 2d6 + highest Savvy >= 10 (Core Rules p.117)
```

## Key Helper Methods
```
_count_alive_units(units: Array) -> int
_find_alive_target(defenders: Array) -> Dictionary
_estimate_range(attacker, target, battlefield_data) -> float
_has_cover(unit, battlefield_data, condition_effects) -> bool
_clear_round_status(units: Array) -> void
_execute_unit_attacks(attackers, defenders, is_crew, battlefield, conditions, dice) -> Dictionary
```

## Debug Logging
```
BattleResolver.enable_debug_logging() -> void
BattleResolver.disable_debug_logging() -> void
# Static var DEBUG_COMBAT_FLOW: bool
```

## Combat Rules PDF Source

All combat constants (hit thresholds, range bands, damage, toughness saves) must match the rulebooks:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf` (combat: pp.113-125)
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python page extraction**: `py -c "import fitz; doc = fitz.open('path'); print(doc[PAGE].get_text())"` (PyMuPDF 1.27.1 via `py` launcher)
