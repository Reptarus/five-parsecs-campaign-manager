# Character Data Engineer — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: enum sync issues, stat edge cases, serialization gotchas, equipment key bugs -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules PDF and Compendium PDF are the **canonical, final authority** for ALL game mechanics, values, names, stats, tables, and terminology. If code disagrees with the book, the code is wrong. No exceptions. No "balancing." No "improvements." Extract values with `py -c "import fitz; doc = fitz.open('docs/rules/...'); print(doc[PAGE].get_text())"`.

---

## Session 40b: Legal + Compendium + Icon SOP (Apr 7, 2026)

- Legal stack shipped: EULA, privacy policy, consent manager, data export/delete (14 files)
- Compendium library: 10 categories, 340+ items — extensible for Planetfall/Tactics
- Icon SOP established: game-icons.net SVGs (CC BY 3.0), white on transparent, `modulate` for color, `assets/icons/{context}/`
- Local icon repo: `C:\Users\admin\Documents\lorcana-tokens\game-icons-sorted-by-artist`
- `data/legal/credits.md` — includes Ivan Sorensen credit + Modiphius staff (PDF-extracted)
- `data/legal/third_party_licenses.md` — all open source + font licenses attributed

---

## Critical Gotchas — Must Remember

### 1. Three-Enum Sync Rule

Any enum change MUST touch all three files simultaneously:
- `src/core/systems/GlobalEnums.gd` (autoload)
- `src/core/enums/GameEnums.gd` (class_name)
- `src/game/campaign/crew/FiveParsecsGameEnums.gd` (CharacterClass)

Values and ordering must match across all three. Misalignment causes wrong enum-to-int mapping and silent data corruption.

### 2. Implant Capacity is Species-Dependent (Session 52)

`const MAX_IMPLANTS` was replaced by `get_max_implants() -> int`. De-converted returns 3 (Core Rules p.19), default returns 2 (Core Rules p.55). All callers use the method now. Test updated in `test_equipment_classes.gd`.

### 3. Strange Character Gameplay — All 16 Types Wired (Session 52)

New Character.gd methods: `get_task_bonus(task_id)` (Empath +1), `get_max_implants()` (species-dependent). New export: `unity_agent_trait_lost: bool` (serialized). Armor saves: `get_natural_armor_save()` now handles De-converted (6+) and Assault Bot (5+). BattleCalculations has 5 new species cases. Feeler breakdown in CharacterEventEffects.

### 4. Engine.has_singleton() vs Autoloads (Session 30)

`Engine.has_singleton("GlobalEnums")` ALWAYS returns false for autoloads. They're scene tree nodes, not C++ singletons. `Character._get_validated_enum_string()` was fixed in Session 30 to use `Engine.get_main_loop().root.get_node_or_null("/root/GlobalEnums")` instead. Without this fix, all character background/motivation/class properties default to fallback values.

### 3. Character.creation_bonuses (Session 30)

`@export var creation_bonuses: Dictionary = {}` — immutable after creation. Set by `CharacterCreator._roll_and_store_creation_bonuses()` using gear_database.json. Contains: `bonus_credits`, `patrons`, `rivals`, `story_points`, `quest_rumors`, `xp`, `starting_rolls`, `credits_dice_sources`. Included in `to_dictionary()` and `from_dictionary()`. All downstream consumers read this — never re-derive from lookups or `CharacterGeneration.roll_character_tables()`.

### 4. Flat Stats — No Sub-Object

Characters use flat properties directly. There is NO `stats` sub-object:
```gdscript
# CORRECT
character.combat = 3
character.reactions = 2

# WRONG — CharacterStats.gd exists but is NOT used as a property
character.stats.combat = 3  # Does not exist
```

Stats: `combat`, `reactions`, `toughness`, `savvy`, `tech`, `move`, `speed`, `luck`

### 5. Campaign Crew Size Property (Session 39)

`FiveParsecsCampaignCore.campaign_crew_size: int` — @export, default 6. Fixed 4/5/6 chosen at creation (Core Rules p.63). Controls enemy number dice formula, deployment cap, reaction dice. NOT the same as `get_crew_size()` (roster count).

- Serialized at top level + config sub-dict + meta sub-dict
- Deserialized with `clampi(value, 4, 6)` and legacy fallback (default 6 for old saves)
- Accessor: `get_campaign_crew_size() -> int`
- Chain: `GameState.get_campaign_crew_size()` → `GameStateManager.get_campaign_crew_size()`
- Set by `CampaignFinalizationService` at campaign creation

### 3. Equipment Key is "equipment"

Ship stash: `campaign.equipment_data["equipment"]` — **NOT** `"pool"`.
Using `"pool"` was a systemic bug fixed in Phase 22.

### 4. Dual-Key Aliases

`Character.to_dictionary()` returns BOTH:
- `"id"` AND `"character_id"` (must be identical)
- `"name"` AND `"character_name"` (must be identical)

Always include both aliases when creating character dicts manually (tests, factories).

### 5. Character.status_effects (Session 51)

`@export var status_effects: Array[Dictionary] = []` — Post-battle Character Events (Core Rules pp.128-130). Each dict: `{type, name, description, duration, source_event}`. 9 types: `skip_next_battle`, `unavailable`, `departed`, `skip_tasks`, `ignore_next_injury`, `item_damaged`, `item_lost_recovery`, `no_xp`, `extra_action`. Serialized in `to_dictionary()`/`from_dictionary()`. Duration decremented by `CampaignPhaseManager._process_character_event_effects()` each turn. Helper methods: `add_status_effect()`, `has_status_effect()`, `get_status_effect()`, `remove_status_effects_of_type()`, `process_status_effect_turn()`. **NOTE**: `BaseCharacterResource` has a separate `status_effects` at line 28 — don't confuse them.

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

### 10. Character.species_degraded (Session 33, Apr 6)

`var species_degraded: bool = false` — set in `_apply_species_bonuses()` when Krag/Skulker origin is present but DLC feature flag is unavailable. Used by CharacterDetailsScreen to show amber degradation banner. NOT serialized (transient runtime flag, recomputed on load).

### 11. Strange Characters & SpeciesDataService (Session 34, Apr 6)

16 Strange Character types (Core Rules pp.19-22) are wired via `SpeciesDataService.gd` (static RefCounted, loads `character_species.json`). Character.gd has `species_id`, `special_rules`, `xp_discount_stat` fields + helper methods. **Character.gd does NOT import SpeciesDataService** (load order issue) — helpers use inline `species_id` string checks.

Key wiring points:
- `CharacterCreator.gd` — dropdown with separator, `_enforce_species_constraints()`, forced fields, Hulker class override
- `LuckSystem.gd` — `_get_species_id()` helper, emo_suppressed blocked
- `ExperienceTrainingProcessor.gd` — hopeful_rookie +1 XP
- `AdvancementSystem.gd` — minor_alien discount via `xp_discount_stat`
- `CrewTaskComponent.gd` — mutant blocked from recruit/find_patron
- `PostBattleCompletion.gd` — traveler disappearance (2D6), manipulator bonus
- `PostBattleContext.gd` — assault_bot excluded from character events
- `InjuryProcessor.gd` — assault_bot routed to bot injury table

`GameEnums.StrangeCharacterType` is DEPRECATED. `FiveParsecsStrangeCharacters.gd` and `BaseStrangeCharacters.gd` were DELETED (fabricated).

### 12. SpeciesDataService Load Order (Session 34)

`SpeciesDataService` has `class_name` but Character.gd cannot reference it at parse time due to Godot's script loading order. The fix: Character helper methods use simple inline string comparisons (`sid != "bot" and sid != "assault_bot"`) instead of calling `SpeciesDataService.is_bot_type()`. Other systems (CharacterCreator, LuckSystem) can reference SpeciesDataService safely since they load later.
