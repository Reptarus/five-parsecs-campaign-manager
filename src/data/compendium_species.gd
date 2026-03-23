class_name CompendiumSpecies
extends RefCounted

## Compendium Species Definitions (Trailblazer's Toolkit DLC)
##
## Krag and Skulker species data with exact mechanical specs from the Compendium.
## All rules output as TEXT INSTRUCTIONS for the tabletop companion model.
## Gated by DLCManager.ContentFlag.SPECIES_KRAG / SPECIES_SKULKER.


## ============================================================================
## JSON DATA LOADING (RulesReference canonical, const fallback)
## ============================================================================

static var _ref_data: Dictionary = {}
static var _ref_loaded: bool = false

static func _ensure_ref_loaded() -> void:
	if _ref_loaded:
		return
	_ref_loaded = true
	var path := "res://data/RulesReference/SpeciesList.json"
	if not FileAccess.file_exists(path):
		return
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
## SPECIES DATA
## ============================================================================

const SPECIES: Dictionary = {
	"krag": {
		"id": "krag",
		"name": "Krag",
		"origin_enum": "KRAG",
		"base_stats": {
			"reactions": 1,
			"speed": 4,
			"toughness": 4,
			# combat_skill and savvy are "+" (determined by class/background roll)
		},
		"movement_speed": 4,
		"special_rules": [
			{
				"id": "no_dash",
				"type": "movement_restriction",
				"description": "Cannot take Dash moves under ANY circumstances.",
			},
			{
				"id": "belligerent_reroll",
				"type": "combat_modifier",
				"trigger": "vs_rival",
				"effect": "reroll_natural_1",
				"applies_to": ["firing", "brawl"],
				"uses_per_battle": 1,
				"description": "When fighting Rivals: May reroll a natural 1 once on firing or Brawl dice.",
			},
			{
				"id": "patron_rival_penalty",
				"type": "creation_modifier",
				"effect": "if_patrons_add_rival",
				"count": 1,
				"description": "If character creation generates any Patrons, add 1 Rival.",
			},
			{
				"id": "always_fights",
				"type": "event_modifier",
				"effect": "always_selected_for_fights",
				"bypass_story_points": false,
				"description": "If a random crew member gets into a fight, it is ALWAYS a Krag. Cannot bypass with Story Points.",
			},
		],
		"armor_rules": {
			"requires_modification": true,
			"modification_cost": 2,
			"revert_cost": 2,
			"trade_table_choice": true,  # Player must designate trade-table armor as Krag or non-Krag
			"non_trade_fits": false,  # Armor from other sources does NOT fit Krag
			"compatible_species": ["krag", "skulker", "engineer"],  # These species can wear Krag armor
			"description": "Trade-table armor must be designated Krag or non-Krag. Non-trade armor doesn't fit. Modification: 2 Credits (reversible for 2 Credits). Skulkers and Engineers can wear Krag armor.",
		},
		"colony_world": {
			"discovery_cost_story_points": 1,
			"forced_traits": ["busy_markets", "vendetta_system"],
			"description": "Krag colonies are rare. Always have Busy Markets and Vendetta System traits. Cost: 1 Story Point to add to known worlds.",
		},
	},
	"skulker": {
		"id": "skulker",
		"name": "Skulker",
		"origin_enum": "SKULKER",
		"base_stats": {
			"reactions": 1,
			"speed": 6,
			"toughness": 3,
			# combat_skill and savvy are "+" (determined by class/background roll)
		},
		"movement_speed": 6,
		"special_rules": [
			{
				"id": "reduced_credits",
				"type": "creation_modifier",
				"effect": "d6_becomes_d3",
				"applies_to": "credits",
				"description": "During character creation, any 1D6 Credits result grants only 1D3 Credits.",
			},
			{
				"id": "ignore_first_rival",
				"type": "creation_modifier",
				"effect": "ignore_first_rival",
				"description": "Ignore the first instance of rolling a Rival during character creation.",
			},
			{
				"id": "difficult_ground_immune",
				"type": "movement_modifier",
				"effect": "ignore_difficult_ground",
				"description": "Not subject to movement reductions from difficult ground, mud, slippery ground, or similar.",
			},
			{
				"id": "low_obstacle_ignore",
				"type": "movement_modifier",
				"effect": "ignore_obstacles_up_to_1in",
				"description": "When moving, may ignore any obstacle up to 1\" in height.",
			},
			{
				"id": "climb_discount",
				"type": "movement_modifier",
				"effect": "first_1in_climb_free",
				"description": "Do not count the first 1\" of any climb for movement reduction.",
			},
			{
				"id": "biological_resistance",
				"type": "defense_modifier",
				"trigger": "poison_toxin_gas",
				"save": "d6_3plus",
				"per_round": true,
				"also_affects_beneficial": ["booster_pills", "combat_serum", "rage_out", "still"],
				"exceptions": ["stim_packs"],
				"salvage_poi_protection": true,  # Also protects vs Points of Interest hazards in Salvage missions
				"description": "D6 3+ to shrug off poison, toxin, gas, or biological hazard (re-roll each round). Also affects: Booster Pills, Combat Serum, Rage Out, Still. Exception: Stim-packs work normally.",
			},
			{
				"id": "universal_armor",
				"type": "equipment_modifier",
				"effect": "all_armor_fits",
				"description": "All armor and equipment fits due to flexible skeletal structure.",
			},
		],
		"armor_rules": {
			"requires_modification": false,
			"universal_fit": true,
			"description": "All armor fits without modification (flexible skeleton).",
		},
		"colony_world": {
			"forced_traits": ["adventurous"],
			"alien_restricted_override": "no_result",
			"second_trait": "rolled_normally",
			"description": "Skulker home worlds always have Adventurous trait + one rolled normally. 'Alien species restricted' = no result.",
		},
	},
	"prison_planet": {
		"id": "prison_planet",
		"name": "Prison Planet",
		"origin_enum": "PRISON_PLANET",
		"base_stats": {
			"toughness": 1,   # +1 Toughness (hardened survivor)
			"combat_skill": 1, # +1 Combat Skill (prison fighting)
		},
		"special_rules": [
			{
				"id": "hardened_survivor",
				"type": "background_modifier",
				"description": "Prison Planet origin. Hardened by brutal conditions. +1 Toughness, +1 Combat Skill.",
			},
		],
		"armor_rules": {
			"requires_modification": false,
			"universal_fit": false,
			"description": "Standard armor compatibility.",
		},
	},
}


## ============================================================================
## STATIC HELPER METHODS
## ============================================================================

## Get a species definition by ID. Returns empty dict if not found or DLC not enabled.
static func get_species(id: String) -> Dictionary:
	if not id in SPECIES:
		return {}
	var species_data: Dictionary = SPECIES[id]
	# Check DLC gating
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if dlc_mgr:
		var flag_name := "SPECIES_%s" % id.to_upper()
		var flag: int = -1
		# Look up ContentFlag by name
		if flag_name == "SPECIES_KRAG":
			flag = dlc_mgr.ContentFlag.SPECIES_KRAG
		elif flag_name == "SPECIES_SKULKER":
			flag = dlc_mgr.ContentFlag.SPECIES_SKULKER
		elif flag_name == "SPECIES_PRISON_PLANET":
			flag = dlc_mgr.ContentFlag.PRISON_PLANET_CHARACTER
		if flag >= 0 and not dlc_mgr.is_feature_enabled(flag):
			return {}
	return species_data.duplicate(true)


## Get all available species (only those whose DLC is enabled).
static func get_available_species() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in SPECIES:
		var data := get_species(id)
		if not data.is_empty():
			result.append(data)
	return result


## Get human-readable creation instruction text for a species.
static func get_creation_text(id: String) -> String:
	var data := get_species(id)
	if data.is_empty():
		return ""

	var lines: Array[String] = []
	lines.append("== %s Character Creation Notes ==" % data.get("name", id))

	var stats: Dictionary = data.get("base_stats", {})
	lines.append("Base Stats: Reactions %d, Speed %d\", Toughness %d (Combat Skill and Savvy rolled per class/background)" % [
		stats.get("reactions", 1), stats.get("speed", 6), stats.get("toughness", 3)
	])

	for rule in data.get("special_rules", []):
		if rule.get("type", "") == "creation_modifier":
			lines.append("- %s" % rule.get("description", ""))

	var armor: Dictionary = data.get("armor_rules", {})
	if not armor.is_empty():
		lines.append("Armor: %s" % armor.get("description", ""))

	return "\n".join(lines)


## Get pre-battle reminder lines for a species.
static func get_battle_reminders(id: String) -> Array[String]:
	var data := get_species(id)
	if data.is_empty():
		return []

	var reminders: Array[String] = []
	var name: String = data.get("name", id).to_upper()

	for rule in data.get("special_rules", []):
		var rule_type: String = rule.get("type", "")
		match rule_type:
			"movement_restriction":
				reminders.append("%s: %s" % [name, rule.get("description", "")])
			"combat_modifier":
				reminders.append("%s: %s" % [name, rule.get("description", "")])
			"defense_modifier":
				reminders.append("%s: %s" % [name, rule.get("description", "")])
			"movement_modifier":
				reminders.append("%s: %s" % [name, rule.get("description", "")])

	return reminders


## Get all battle reminders for active compendium species in a crew.
## Pass an array of origin strings (e.g., ["human", "krag", "skulker"]).
static func get_crew_battle_reminders(crew_origins: Array) -> Array[String]:
	var all_reminders: Array[String] = []
	var seen_species: Dictionary = {}  # Avoid duplicates for multiple crew of same species

	for origin in crew_origins:
		var origin_lower: String = str(origin).to_lower()
		if origin_lower in seen_species:
			continue
		if origin_lower in SPECIES:
			seen_species[origin_lower] = true
			all_reminders.append_array(get_battle_reminders(origin_lower))

	return all_reminders
