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
  "consumed_items": [],
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

## Campaign Crew Size in Combat (Session 39)

**Critical distinction**: `get_crew_size()` = roster count, `get_campaign_crew_size()` = fixed 4/5/6 setting.

### Enemy Count Formulas (EnemyGenerator.gd)

| Setting | Standard (p.63) | Raided Event (p.70) |
|---------|-----------------|---------------------|
| Crew 6  | 2D6 pick higher | 3D6 pick highest    |
| Crew 5  | 1D6             | 2D6 pick highest    |
| Crew 4  | 2D6 pick lower  | 1D6                 |

- **Numbers modifier**: "+0" to "+3" from enemy type template, added AFTER dice roll
- **Quest reroll** (p.99): During Quest missions, reroll any die scoring 1 once
- **Fielding fewer** (p.93): Deploy 2+ below setting → subtract 1 from enemy count
- **Reaction dice** (p.118): Roll D6 matching campaign setting, NOT living crew count
- **Deployment cap**: PreBattleUI enforces max = campaign_crew_size

### Methods

```gdscript
EnemyGenerator._calculate_enemy_count(difficulty, crew_size, is_quest) -> int  # Standard
EnemyGenerator.calculate_raided_enemy_count(campaign_crew_size) -> int         # Raided event
EnemyGenerator._parse_numbers_modifier(numbers_str) -> int                     # "+2" → 2
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

## Seize Initiative — Difficulty Modifier (Session 40)

`BattleCalculations.check_seize_initiative(die1, die2, highest_savvy, difficulty_modifier=0)` now applies the Core Rules p.65 difficulty modifier (Hardcore: -2, Insanity: -3). The modifier flows through:

1. `BattlePhase._simulate_battle_outcome()` injects `battlefield_data["seize_initiative_modifier"]` via `DifficultyModifiers.get_seize_initiative_modifier(difficulty)`
2. `BattleResolver._check_initiative()` reads it from `battlefield_data.get("seize_initiative_modifier", 0)`
3. `BattleCalculations.check_seize_initiative()` adds it to the 2D6 + savvy total

`SeizeInitiativeSystem.gd` (UI component path) already applied difficulty independently via `set_difficulty_mode()`. The Session 40 fix covers the automated resolution path.

## Battle Flow (Session 47 — Equipment Pipeline Wired)

```
1. initialize_battle(crew, enemies, deployment_condition)
   → Apply deployment condition effects
   → Extract armor/screen from crew equipment (_extract_protective_equipment)
   → Extract enemy saving throws from special_rules (_extract_enemy_saving_throw)
   → Set deflector_uses, battle_dress reactions bonus
   → Return initial battle state

2. For each round:
   execute_combat_round(...)
   → _check_initiative reads difficulty from battlefield_data
   → Each unit attacks:
     • moved_this_turn heuristic (50% random for auto-resolve)
     • Overheat shot reduction if fired_hot_weapon_last_round
     • Flex-armor +1 Toughness, stealth gear -1 hit, camo cloak cover
     • Deflector field auto-deflect (1 per battle)
     • resolve_ranged_attack() with get_weapon_trait_effects()
       - Hit modifiers: Heavy(-1 moved), Snap Shot(+1 close), Stealth(-1)
       - Shrapnel overrides all modifiers (fixed 5+)
       - Stun bypasses Toughness, applies even on save
       - Flak screen: Area damage -1
       - Frag vest: 6+→5+ vs Area, Screen generator: no save vs Area/Melee
     • Stim-pack prevents elimination (→ stun instead)
     • Track consumed single-use items
   → Rotate fired_hot_weapon flags, clear round status
   → Aggregate consumed_items

3. calculate_battle_outcome(...)
   → Victory/defeat, held_field
   → consumed_items returned in result dict
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

## PostBattleProcessor — Data-Driven from JSON

`FPCM_PostBattleProcessor` (`src/core/battle/PostBattleProcessor.gd`) now loads injury tables and XP awards from `data/injury_results.json`:

- **XP awards**: Static lazy loader `_load_injury_json()` → accessor `_get_xp(key, fallback)`. Properties `XP_BECAME_CASUALTY`, `XP_SURVIVED_WON`, etc. are getters.
- **Injury tables**: `_roll_human_injury_table()` and `_roll_bot_injury_table()` iterate JSON entries via `_match_injury_entry(entries, roll)`. Dynamic dice expressions (`"1d6"`, `"1d3+1"`) resolved via `_resolve_dice_expression()`.
- **Fallbacks**: If JSON unavailable, hardcoded defaults used (Minor injuries / Just a few dents).

## BattlePhase — Unique Individual from JSON

`BattlePhase._determine_unique_individual()` loads thresholds from `data/unique_individual.json`:

- `_get_ui_threshold()` → base roll threshold (default 9)
- `_get_ui_double_threshold()` → Insanity double check (default 11)
- `_get_ui_interested_parties_modifier()` → +1 when `enemy_category == "interested_parties"`
- Difficulty modifiers still via `DifficultyModifiers` (Hardcore +1, Insanity forced)

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
