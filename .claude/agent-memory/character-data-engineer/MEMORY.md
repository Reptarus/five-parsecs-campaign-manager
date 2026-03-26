# Character Data Engineer — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: enum sync issues, stat edge cases, serialization gotchas, equipment key bugs -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules PDF and Compendium PDF are the **canonical, final authority** for ALL game mechanics, values, names, stats, tables, and terminology. If code disagrees with the book, the code is wrong. No exceptions. No "balancing." No "improvements." Extract values with `py -c "import fitz; doc = fitz.open('docs/rules/...'); print(doc[PAGE].get_text())"`.

---

## Critical Gotchas — Must Remember

### 1. Three-Enum Sync Rule

Any enum change MUST touch all three files simultaneously:
- `src/core/systems/GlobalEnums.gd` (autoload)
- `src/core/enums/GameEnums.gd` (class_name)
- `src/game/campaign/crew/FiveParsecsGameEnums.gd` (CharacterClass)

Values and ordering must match across all three. Misalignment causes wrong enum-to-int mapping and silent data corruption.

### 2. Flat Stats — No Sub-Object

Characters use flat properties directly. There is NO `stats` sub-object:
```gdscript
# CORRECT
character.combat = 3
character.reactions = 2

# WRONG — CharacterStats.gd exists but is NOT used as a property
character.stats.combat = 3  # Does not exist
```

Stats: `combat`, `reactions`, `toughness`, `savvy`, `tech`, `move`, `speed`, `luck`

### 3. Equipment Key is "equipment"

Ship stash: `campaign.equipment_data["equipment"]` — **NOT** `"pool"`.
Using `"pool"` was a systemic bug fixed in Phase 22.

### 4. Dual-Key Aliases

`Character.to_dictionary()` returns BOTH:
- `"id"` AND `"character_id"` (must be identical)
- `"name"` AND `"character_name"` (must be identical)

Always include both aliases when creating character dicts manually (tests, factories).

### 5. PDF Rulebooks & Python Extraction Tools

Source PDFs are available for direct data extraction — NEVER guess game values:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python**: `py` launcher (NOT `python`), PyPDF2 3.0.1, PyMuPDF 1.27.1 (fitz) installed
- **Example**: `py -c "import fitz; doc = fitz.open('path/to/pdf'); print(doc[PAGE].get_text())"`

Always extract from the PDF when `data/RulesReference/` doesn't have the value you need.

### 6. BaseCharacterResource Combat Interface (Session 10)

`BaseCharacterResource` now implements 22 combat methods required by `CombatResolver._validate_character_interface()`. Methods delegate to existing flat stats and equipment arrays. Key mappings:
- `get_combat_skill()` → `combat`, `get_speed()` → `speed`, `is_mechanical()` → `is_bot`
- `get_equipped_weapon()` → `weapons[0]` as Dictionary
- `apply_damage()`/`heal_damage()` → modify `health`, set `is_wounded`/`is_dead`
- Property aliases: `name`→`character_name`, `bot`→`is_bot`, `soulless`→`is_soulless`
- Transient battle state: `_action_points`, `_combat_modifiers`, `position`, `in_cover`, `elevation`, `active_effects`, `has_moved_this_turn`, `is_player_controlled`, `is_swift`

### 7. KeywordDB Now Loads from JSON (Session 11-12, Mar 26)

`KeywordDB.gd` now loads 89 keywords from `data/keywords.json` at startup via `_load_keywords_from_json()`. Hardcoded defaults are fallback only. 14 weapon trait definitions in keywords.json corrected to Core Rules p.51. CharacterCreator.gd already correctly loads bonuses from `character_creation_bonuses.json` — no changes needed.

### 8. Injury/XP JSON Data Files (Session 13, Mar 26)

Two injury-related JSON files exist — both verified against Core Rules p.122-123:

- `data/injury_results.json` — Canonical source for PostBattleProcessor, ExperienceTrainingProcessor, BattleCalculations. Contains human (9) + bot (6) injury tables, XP awards (7 conditions), processing rules.
- `data/injury_table.json` — Older format, referenced by DataManager/GameDataManager. Same injury data, different structure.
- `data/unique_individual.json` — Unique Individual presence mechanics (threshold 9, difficulty modifiers, exclusions). Wired to BattlePhase.gd. Types table is in `data/enemy_types.json["unique_individuals"]` (21 types).

### 9. Godot 4.6 Type Inference

`var x := dict["key"]` will NOT compile — Dictionary values are always Variant.
Always use explicit type annotation: `var x: Type = dict["key"]`. Zero exceptions.
Same applies to untyped Array access and any method returning Variant.
