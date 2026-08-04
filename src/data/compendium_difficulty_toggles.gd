class_name CompendiumDifficultyToggles
extends RefCounted
## Compendium Difficulty Toggles & Combat Options Data
##
## Data-driven difficulty/combat option definitions from the Compendium.
## Extends house_rules_definitions.gd pattern with sub-toggles and categories.
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
##
## Categories:
##   encounter_scaling  - Enemy count/composition (DIFFICULTY_TOGGLES)
##   economy            - Credits/upkeep/progression (DIFFICULTY_TOGGLES)
##   combat_difficulty  - Enemy stat boosts (DIFFICULTY_TOGGLES)
##   time_pressure      - Round limits/spawns (DIFFICULTY_TOGGLES)
##   ai_behavior        - D6 enemy AI type (AI_VARIATIONS)
##   casualty           - Casualty tables (CASUALTY_TABLES)
##   injury_detail      - Detailed injuries (DETAILED_INJURIES)
##   dramatic           - Dramatic combat effects (DRAMATIC_COMBAT)


## ============================================================================
## JSON DATA LOADING (RulesReference canonical, const fallback)
## ============================================================================

static var _ref_data: Dictionary = {}
static var _ref_loaded: bool = false

static func _ensure_ref_loaded() -> void:
	if _ref_loaded:
		return
	_ref_loaded = true
	var path := "res://data/RulesReference/DifficultyOptions.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_ref_data = json.data
	file.close()

static func get_ref_data() -> Dictionary:
	_ensure_ref_loaded()
	return _ref_data


## ============================================================================
## DLC GATING HELPER
## ============================================================================

static func _get_dlc_manager() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


static func _is_flag_enabled(flag_name: String) -> bool:
	var dlc_mgr := _get_dlc_manager()
	if not dlc_mgr:
		return false
	var flag_value: int = dlc_mgr.ContentFlag.get(flag_name, -1)
	if flag_value < 0:
		return false
	return dlc_mgr.is_feature_enabled(flag_value)



## ============================================================================
## COMPENDIUM DATA LOADING (from JSON)
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/difficulty_toggles.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumDifficultyToggles: Could not load difficulty_toggles.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()

static var DIFFICULTY_TOGGLES: Array:
	get:
		_ensure_loaded()
		return _data.get("difficulty_toggles", [])

static var AI_VARIATION_TABLES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("ai_variation_tables", {})

static var AI_BEHAVIOR_TABLE: Array:
	get:
		_ensure_loaded()
		return _data.get("ai_behavior_table", [])

static var CASUALTY_TABLES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("casualty_tables", {})

## CASUALTY_TABLE was DELETED (Aug 3 2026). It read `casualty_table`, a key whose
## value in difficulty_toggles.json is the empty array `[]` — the real p.99-100
## data has always been in `casualty_tables` (three tables keyed
## humanoid/cybernetic/beast, each with regular/boss COLUMNS, not a flat `roll`).
## roll_casualty() iterated the empty one looking for `entry.roll`, so it returned
## {} on every call and the Compendium casualty rules never once fired.

static var DETAILED_INJURY_TABLE: Array:
	get:
		_ensure_loaded()
		return _data.get("detailed_injury_table", [])

static var DRAMATIC_COMBAT_RULES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("dramatic_combat_rules", {})

static var DRAMATIC_EFFECTS: Array:
	get:
		_ensure_loaded()
		return _data.get("dramatic_effects", [])

## ============================================================================
## WHICH TOGGLES ARE ON — the chokepoint every pp.32-34 rule reads
## ============================================================================
##
## THE GAP THIS FILLS. Two UIs have collected toggle selections since they were
## written — ExpandedConfigPanel into `local_campaign_config["difficulty_toggles"]`
## and the Settings DifficultyTogglesPanel into `user://difficulty_toggles.cfg` —
## and NOTHING in the game ever read a toggle id. The creation panel's selection
## did not even leave the panel: `CampaignCreationCoordinator
## .update_campaign_config_state` is a whitelist and it did not name the key, so
## the array was dropped at the panel boundary. All 12 options were switches
## wired to nothing.
##
## SSOT is the CAMPAIGN: `campaign.progress_data["difficulty_toggles"]`, an
## Array[String] of ids, written by CampaignFinalizationService — the same shape
## and the same write site as `progressive_difficulty_options`.
##
## The `user://difficulty_toggles.cfg` file is a FALLBACK, not a second owner. It
## is consulted only when there is no campaign at all, which is the Battle
## Simulator (a standalone battle with no campaign to carry settings). A loaded
## campaign always wins, so the two can never disagree about a live game.

const TOGGLE_STATE_KEY := "difficulty_toggles"
const TOGGLE_CFG_PATH := "user://difficulty_toggles.cfg"


static func _current_campaign() -> Variant:
	if not Engine.get_main_loop():
		return null
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs == null:
		return null
	if gs.has_method("get_current_campaign"):
		return gs.get_current_campaign()
	if "current_campaign" in gs:
		return gs.current_campaign
	return null


## Creation-time override.
##
## "Starting in the Gutter" (p.34) is a CHARACTER CREATION rule, and during the
## wizard there is no campaign yet to read the selection from — worse, GameState
## may still be holding the PREVIOUS campaign, so a plain campaign read would
## silently apply the last campaign's options to the new one. The coordinator
## sets this while the wizard is open and finalization clears it, so creation
## reads the choices the player is making right now.
static var _creation_override: Variant = null


static func set_creation_toggles(toggle_ids: Variant) -> void:
	_creation_override = toggle_ids if toggle_ids is Array else null


static func clear_creation_toggles() -> void:
	_creation_override = null


## The toggle ids active right now. Empty when the option pack is off.
static func get_active_toggles() -> Array:
	if not _is_flag_enabled("DIFFICULTY_TOGGLES"):
		return []
	if _creation_override is Array:
		return _creation_override
	var campaign: Variant = _current_campaign()
	if campaign != null:
		var pd: Variant = null
		if campaign is Dictionary:
			pd = campaign.get("progress_data", {})
		elif "progress_data" in campaign:
			pd = campaign.progress_data
		if pd is Dictionary:
			var ids = pd.get(TOGGLE_STATE_KEY, [])
			if ids is Array:
				return ids
		# A campaign with no toggle array selected none. Do NOT fall through to
		# the cfg here: that would let a Settings screen silently re-arm options
		# the player did not pick for THIS campaign.
		return []

	# No campaign — Battle Simulator and other standalone paths.
	var config := ConfigFile.new()
	if config.load(TOGGLE_CFG_PATH) != OK:
		return []
	var out: Array = []
	for key in config.get_section_keys("toggles"):
		if bool(config.get_value("toggles", key, false)):
			out.append(str(key))
	return out


## Is one pp.32-34 option in force? This is the single call every rule site uses.
static func is_toggle_active(toggle_id: String) -> bool:
	return toggle_id in get_active_toggles()


## ============================================================================
## p.32 "MONEY IS TIGHT" HELPERS
## ============================================================================

## p.32: "Whenever you would roll 1D6 for credits, roll 1D6-1 instead (minimum
## score 1). This applies both during character creation and during game play.
## Any modifiers to the roll are applied normally."
##
## Every 1D6-for-credits site calls this instead of rolling directly, so the
## option cannot be half-applied. The minimum is on the DIE, before the caller's
## modifiers — the book applies those "normally", i.e. afterwards.
static func roll_credit_die() -> int:
	if is_toggle_active("slaves_to_stargrind_money"):
		return maxi(randi_range(1, 6) - 1, 1)
	return randi_range(1, 6)


## p.32: "Taking Find a Patron or Repair Your Kit actions costs 1 credit."
## Returns the surcharge in credits for a crew task id, 0 when not applicable.
static func crew_task_surcharge(task_id: String) -> int:
	if not is_toggle_active("slaves_to_stargrind_money"):
		return 0
	return 1 if task_id in ["find_patron", "repair_kit", "repair_your_kit"] else 0


## p.32: "You do not receive 1 point of free Hull Point repair each turn. All
## repairs must be paid for unless granted by a random event or similar."
static func free_hull_repair_denied() -> bool:
	return is_toggle_active("slaves_to_stargrind_money")


## ============================================================================
## p.32 "SLOWER PROGRESSION"
## ============================================================================
##
## The Compendium reprints the whole Ability Increase Table with new numbers.
## Core Rules p.123 vs Compendium p.32:
##
##   ABILITY        CORE cost/max      SLOWER cost/max
##   Reactions      7 / 6              8 / 4
##   Combat Skill   7 / +5             8 / +3
##   Speed          5 / 8"             5 / 8"     (unchanged)
##   Savvy          5 / +5             5 / +5     (unchanged)
##   Toughness      6 / 6              8 / 5
##   Luck           10 / 1 (3 Human)   10 / 3
##
## Costs are REPLACED. Maximums are applied as a CAP that can only LOWER the
## existing maximum, never raise it — which is what keeps the Luck row honest:
## the Compendium prints a bare "3" where the Core Rules print "1 (3 Human)",
## and reading that as a flat 3 would hand every non-Human species a Luck cap of
## 3 in a chapter whose entire purpose is to make the game harder. The
## Humans-only-above-1 rule is a SPECIES rule (Core Rules p.12), not part of
## either upgrade table.
const SLOWER_PROGRESSION_COSTS := {
	"reactions": 8,
	"combat_skill": 8,
	"speed": 5,
	"savvy": 5,
	"toughness": 8,
	"luck": 10,
}

const SLOWER_PROGRESSION_MAXIMUMS := {
	"reactions": 4,
	"combat_skill": 3,
	"speed": 8,
	"savvy": 5,
	"toughness": 5,
	"luck": 3,
}


## The XP cost to raise `stat_name` by +1, or `base_cost` when the option is off.
static func progression_cost(stat_name: String, base_cost: int) -> int:
	if not is_toggle_active("slaves_to_stargrind_progression"):
		return base_cost
	return int(SLOWER_PROGRESSION_COSTS.get(stat_name, base_cost))


## The maximum value for `stat_name`. Only ever lowers `base_max` — see the note
## on the Luck row above.
static func progression_maximum(stat_name: String, base_max: int) -> int:
	if not is_toggle_active("slaves_to_stargrind_progression"):
		return base_max
	if not SLOWER_PROGRESSION_MAXIMUMS.has(stat_name):
		return base_max
	return mini(base_max, int(SLOWER_PROGRESSION_MAXIMUMS[stat_name]))


## ============================================================================
## QUERY METHODS (DLC-gated)
## ============================================================================

## Get all difficulty toggles. Empty if DLC not enabled.
static func get_difficulty_toggles() -> Array[Dictionary]:
	if not _is_flag_enabled("DIFFICULTY_TOGGLES"):
		return []
	var result: Array[Dictionary] = []
	result.assign(DIFFICULTY_TOGGLES)
	return result


## Get toggles filtered by category.
static func get_toggles_by_category(category: String) -> Array[Dictionary]:
	var toggles := get_difficulty_toggles()
	var filtered: Array[Dictionary] = []
	for t in toggles:
		if t.get("category", "") == category:
			filtered.append(t)
	return filtered


## Roll D6 for enemy AI behavior. Returns behavior dict or empty if disabled.
static func roll_ai_behavior() -> Dictionary:
	if not _is_flag_enabled("AI_VARIATIONS"):
		return {}
	var roll := randi_range(1, 6)
	for entry in AI_BEHAVIOR_TABLE:
		if entry.roll == roll:
			return entry
	return {}


## Get AI behavior by roll value.
static func get_ai_behavior(roll: int) -> Dictionary:
	if not _is_flag_enabled("AI_VARIATIONS"):
		return {}
	for entry in AI_BEHAVIOR_TABLE:
		if entry.roll == roll:
			return entry
	return {}


## Roll D6 on a Casualty Table (Compendium pp.99-100). Returns the row plus the
## roll and the column used, or {} when the option is off or the category is
## unknown.
##
## p.99: "roll D6 on the appropriate table below. Use the most suitable category
## for the type of creature. The Regular column is used for your crew figures and
## normal enemies (including specialists). The Boss column is used for your crew
## captain, any enemy leader and unique personalities."
##
## `bonus` carries the +1 the Damaged (cybernetic) and Bleeding (beast) rows add
## to FUTURE casualty rolls, and the Critical Hit option's extra roll is made by
## the caller rolling twice and keeping the highest (p.100).
static func roll_casualty(category: String = "humanoid", is_boss: bool = false,
		bonus: int = 0) -> Dictionary:
	if not _is_flag_enabled("CASUALTY_TABLES"):
		return {}
	var table: Dictionary = CASUALTY_TABLES.get(category, {})
	var entries: Array = table.get("entries", []) if table is Dictionary else []
	if entries.is_empty():
		return {}
	var roll: int = clampi(randi_range(1, 6) + bonus, 1, 6)
	var column := "boss" if is_boss else "regular"
	for entry in entries:
		var span: Array = entry.get(column, [])
		if span.size() == 2 and roll >= int(span[0]) and roll <= int(span[1]):
			var out: Dictionary = entry.duplicate(true)
			out["roll"] = roll
			out["column"] = column
			out["table"] = category
			return out
	return {}


## Which Casualty Table a figure uses (p.99 "the most suitable category").
static func casualty_category_for(is_mechanical: bool, is_beast: bool) -> String:
	if is_mechanical:
		return "cybernetic"
	if is_beast:
		return "beast"
	return "humanoid"


## Roll D100 on the Detailed Post-Battle Injury table (Compendium p.102).
## Returns the row, with the roll attached, or {} when the option is off.
##
## Was `randi_range(1, 6) + randi_range(1, 6)` — 2D6 against a D100 table — and
## then matched `entry.roll`, a key these rows do not have (they carry `roll_min`
## / `roll_max`). Both faults independently guaranteed {}, so the table never
## resolved once. Note roll_min 0 on the Death row is the book's tens-digit
## notation for "01-10"; matching an inclusive 1-100 roll against the span is
## correct for it and for the 96-00 row alike.
static func roll_detailed_injury() -> Dictionary:
	if not _is_flag_enabled("DETAILED_INJURIES"):
		return {}
	var roll := randi_range(1, 100)
	for entry in DETAILED_INJURY_TABLE:
		if roll >= int(entry.get("roll_min", -1)) and roll <= int(entry.get("roll_max", -1)):
			var out: Dictionary = entry.duplicate(true)
			out["roll"] = roll
			return out
	return {}


## Get dramatic effect text for a weapon type. Returns empty if disabled.
static func get_dramatic_effect(weapon_type: String) -> String:
	if not _is_flag_enabled("DRAMATIC_COMBAT"):
		return ""
	for entry in DRAMATIC_EFFECTS:
		if entry.weapon_type == weapon_type:
			return entry.instruction
	return ""


## Get Adjusted Shooting hit thresholds (Compendium p.87) when Dramatic Combat
## is on. Returns {"open": int, "cover": int} or empty dict when disabled.
static func get_adjusted_shooting_thresholds() -> Dictionary:
	if not _is_flag_enabled("DRAMATIC_COMBAT"):
		return {}
	var rules: Dictionary = DRAMATIC_COMBAT_RULES.get("adjusted_shooting", {})
	if rules.is_empty():
		return {}
	return {
		"open": int(rules.get("in_open_threshold", 5)),
		"cover": int(rules.get("in_cover_threshold", 6)),
	}


## Get the dramatic weapons stat override for a given weapon id (Compendium
## pp.88-89). Returns empty dict when disabled or the weapon has no override
## (callers fall back to the equipment_database baseline).
static func get_dramatic_weapon_stats(weapon_id: String) -> Dictionary:
	if not _is_flag_enabled("DRAMATIC_COMBAT"):
		return {}
	_ensure_loaded()
	var table: Dictionary = _data.get("dramatic_weapons_stats", {})
	var key := weapon_id.to_lower().strip_edges().replace(" ", "_").replace("-", "_")
	var stats = table.get(key, {})
	return stats if stats is Dictionary else {}


## Overlay the Compendium pp.88-89 Dramatic Weapons profile onto a resolved
## weapon dict. Returns the input untouched when Dramatic Combat is off or the
## weapon has no override row.
##
## p.88: "If using this weapons table, you should also use the 'Adjusted
## Shooting' hit numbers from the Dramatic Combat section" — the two halves of
## the option travel together, so they share the one DRAMATIC_COMBAT flag.
static func apply_dramatic_weapon_profile(weapon: Dictionary) -> Dictionary:
	if weapon.is_empty():
		return weapon
	var key: String = str(weapon.get("id", ""))
	var stats: Dictionary = get_dramatic_weapon_stats(key)
	if stats.is_empty():
		stats = get_dramatic_weapon_stats(str(weapon.get("name", "")))
	if stats.is_empty():
		return weapon
	var out: Dictionary = weapon.duplicate(true)
	# Only the four columns the book's table actually prints. Cost, rarity and
	# description stay on the baseline profile.
	for stat_key in ["range", "shots", "damage", "traits"]:
		if stats.has(stat_key):
			out[stat_key] = stats[stat_key]
	out["dramatic_profile"] = true
	return out


## Aggregated rule-text instructions for the BattlePhase setup screen.
## Returns the Adjusted Shooting / Duck Back / Lunge bullet strings so the
## tabletop player has the actual rules in front of them, not just per-weapon
## flavor strings. Returns [] when DRAMATIC_COMBAT is disabled.
static func get_dramatic_combat_rule_instructions() -> Array[String]:
	var out: Array[String] = []
	if not _is_flag_enabled("DRAMATIC_COMBAT"):
		return out
	var rules: Dictionary = DRAMATIC_COMBAT_RULES
	for key in ["adjusted_shooting", "duck_back", "lunging"]:
		var block = rules.get(key, {})
		if block is Dictionary:
			var instr: String = str(block.get("instruction", ""))
			if not instr.is_empty():
				out.append(instr)
	return out


## Get all toggle categories.
static func get_categories() -> Array[String]:
	return [
		"encounter_scaling",
		"economy",
		"combat_difficulty",
		"time_pressure",
	]


## Get category display name.
static func get_category_name(category: String) -> String:
	match category:
		"encounter_scaling":
			return "Encounter Scaling"
		"economy":
			return "Economy & Progression"
		"combat_difficulty":
			return "Combat Difficulty"
		"time_pressure":
			return "Time Pressure"
	return category.capitalize()
