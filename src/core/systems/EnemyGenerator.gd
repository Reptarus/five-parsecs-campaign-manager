class_name EnemyGenerator
extends Resource

## Enemy Generation System for Five Parsecs Campaign Manager
## Enhanced with JSON data integration for comprehensive enemy generation
## Uses data/enemy_types.json for detailed enemy configurations

# DataManager accessed via autoload singleton (not preload)
const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")
const ProgressiveDifficultyRef = preload("res://src/core/systems/ProgressiveDifficultyTracker.gd")
const WorldTraitEffectsClass = preload("res://src/core/world/WorldTraitEffects.gd")
const PatronJobEffectsClass = preload("res://src/core/patrons/PatronJobEffects.gd")
const EnemyTraitRulesClass = preload("res://src/core/systems/EnemyTraitRules.gd")
const CompendiumEliteEnemiesRef = preload("res://src/data/compendium_elite_enemies.gd")

## Red Job Increased Opposition (Core Rules Appendix III p.150). Mirrors
## data/red_zone_jobs.json increased_opposition; kept as named constants so the
## generator reads as the book does.
const RED_ZONE_BASE_FIGURES := 7
const RED_ZONE_SPECIALISTS := 3      # "3 Specialists, one of which is a Lieutenant"
const RED_ZONE_UNIQUE_BONUS := 1     # "+1 to the roll to determine whether a Unique Individual is present"

signal enemies_generated(enemies: Array[Resource])
signal enemy_data_loaded(categories_count: int)

# JSON data loaded from files
var enemy_data: Dictionary = {}
var loot_tables: Dictionary = {}
var spawn_rules: Dictionary = {}
var bestiary_ref: Dictionary = {}  # RulesReference/Bestiary.json
var elite_enemies_ref: Dictionary = {}  # RulesReference/EliteEnemies.json
var data_manager: Node = null  # DataManager autoload

# Legacy compatibility - fallback data
var enemy_categories: Dictionary = {}
var enemy_stats_base: Dictionary = {}

func _init() -> void:
	## Initialize enemy generator with JSON data
	_load_enemy_data()

func _load_enemy_data() -> void:
	## Load enemy data from JSON files
	data_manager = Engine.get_main_loop().root.get_node_or_null("/root/DataManager") if Engine.get_main_loop() else null
	
	# Load main enemy types data
	enemy_data = data_manager.load_json_file("res://data/enemy_types.json")

	# Load RulesReference data for cross-validation and elite enemies
	bestiary_ref = data_manager.load_json_file("res://data/RulesReference/Bestiary.json")
	elite_enemies_ref = data_manager.load_json_file("res://data/RulesReference/EliteEnemies.json")

	if enemy_data.is_empty():
		push_error("Failed to load enemy data from res://data/enemy_types.json")
		_load_fallback_enemy_data()
	else:
		
		# Extract loot tables and spawn rules
		loot_tables = enemy_data.get("enemy_loot_tables", {})
		spawn_rules = enemy_data.get("enemy_spawn_rules", {})
		
		# Build legacy compatibility structures
		_build_legacy_compatibility()
		
		enemy_data_loaded.emit(enemy_data.get("enemy_categories", []).size())

func _load_fallback_enemy_data() -> void:
	## Load fallback enemy data if JSON fails
	# Fallback categories using book names (Core Rules pp.94-103)
	enemy_categories = {
		"criminal_elements": ["Gangers", "Punks", "Raiders", "Cultists", "Pirates"],
		"hired_muscle": ["Unknown Mercs", "Enforcers", "Corporate Security", "Unity Grunts"],
		"interested_parties": ["Vigilantes", "Bounty Hunters", "Colonial Militia", "Salvage Team"],
		"roving_threats": ["Razor Lizards", "Sand Runners", "Large Bugs", "Vent Crawlers"]
	}

	# Book-accurate fallback stats
	enemy_stats_base = {
		"Gangers": {"combat_skill": 0, "toughness": 3, "speed": 4, "weapons": ["Handgun"]},
		"Punks": {"combat_skill": 0, "toughness": 3, "speed": 4, "weapons": ["Scrap Pistol"]},
		"Raiders": {"combat_skill": 1, "toughness": 3, "speed": 4, "weapons": ["Colony Rifle", "Blade"]},
		"Unknown Mercs": {"combat_skill": 1, "toughness": 4, "speed": 5, "weapons": ["Military Rifle"]},
		"Enforcers": {"combat_skill": 1, "toughness": 4, "speed": 4, "weapons": ["Military Rifle"]},
		"Corporate Security": {"combat_skill": 1, "toughness": 4, "speed": 4, "weapons": ["Military Rifle"]},
		"Razor Lizards": {"combat_skill": 1, "toughness": 3, "speed": 6, "weapons": ["Fangs"]},
		"Sand Runners": {"combat_skill": 0, "toughness": 3, "speed": 7, "weapons": ["Fangs"]}
	}

func _build_legacy_compatibility() -> void:
	## Build legacy enemy_categories structure from JSON data
	for category_data in enemy_data.get("enemy_categories", []):
		var category_id = category_data.get("id", "")
		var enemies = []

		for enemy in category_data.get("enemies", []):
			enemies.append(enemy.get("name", "Unknown"))

			# Populate legacy stats — JSON uses flat properties, not nested "stats"/"equipment"
			enemy_stats_base[enemy.get("name", "Unknown")] = {
				"combat_skill": enemy.get("combat_skill", 0),
				"toughness": enemy.get("toughness", 3),
				"speed": enemy.get("speed", 4),
				"weapons": resolve_basic_weapon(enemy.get("weapons", "1 A"))
			}

		enemy_categories[category_id] = enemies

func generate_enemies_for_mission(mission: Resource, crew_size: int = 4) -> Array[Resource]:
	## Generate appropriate enemies for a mission based on Five Parsecs rules
	var enemies: Array[Resource] = []

	var mission_type = mission.get_meta("mission_type") if mission and mission.has_method("get_meta") else "Patrol"
	var difficulty = mission.get_meta("difficulty") if mission and mission.has_method("get_meta") else 1

	var enemy_category: String = _determine_enemy_category(mission_type)
	var enemy_count: int = _calculate_enemy_count(difficulty, crew_size)

	for i: int in range(enemy_count):
		var enemy: Resource = _create_enemy(enemy_category, difficulty)

		enemies.append(enemy)

	enemies_generated.emit(enemies)
	return enemies

func _determine_enemy_category(mission_type: String) -> String:
	## Determine enemy category based on mission type using JSON spawn rules
	var mission_spawn_rules = spawn_rules.get("mission_type", {})
	
	# Check if we have specific spawn rules for this mission type
	if mission_spawn_rules.has(mission_type):
		var rules = mission_spawn_rules[mission_type]
		var primary_categories = rules.get("primary", [])
		var secondary_categories = rules.get("secondary", [])
		
		# 70% chance for primary categories, 30% for secondary
		if randf() < 0.7 and not primary_categories.is_empty():
			return primary_categories.pick_random()
		elif not secondary_categories.is_empty():
			return secondary_categories.pick_random()
		elif not primary_categories.is_empty():
			return primary_categories.pick_random()
	
	# Enhanced fallback logic using JSON category data (Core Rules p.94)
	if not enemy_data.get("enemy_categories", []).is_empty():
		match mission_type:
			"Patrol", "Investigate":
				return _select_from_categories(["criminal_elements", "hired_muscle"])
			"Hunt", "Bounty":
				return _select_from_categories(["criminal_elements", "interested_parties"])
			"Guard", "Defend":
				return _select_from_categories(["hired_muscle", "criminal_elements"])
			"Deliver", "Trade":
				return _select_from_categories(["criminal_elements", "hired_muscle"])
			"Explore":
				return _select_from_categories(["roving_threats", "interested_parties"])
			"Salvage":
				return _select_from_categories(["roving_threats", "interested_parties"])
			_:
				return _select_from_categories(["criminal_elements", "hired_muscle"])
	
	# Ultimate fallback using book category IDs
	match mission_type:
		"Patrol", "Investigate":
			return ["criminal_elements", "hired_muscle"].pick_random()
		"Hunt", "Bounty":
			return ["criminal_elements", "interested_parties"].pick_random()
		"Guard", "Defend":
			return ["hired_muscle", "criminal_elements"].pick_random()
		"Deliver", "Trade":
			return ["criminal_elements", "hired_muscle"].pick_random()
		"Explore":
			return ["roving_threats", "interested_parties"].pick_random()
		"Salvage":
			return ["roving_threats", "interested_parties"].pick_random()
		_:
			return "criminal_elements"

func _select_from_categories(preferred_categories: Array) -> String:
	## Select enemy category from preferred list, fallback to available categories
	var available_categories = []
	
	# Get available category IDs from JSON data
	for category_data in enemy_data.get("enemy_categories", []):
		available_categories.append(category_data.get("id", ""))
	
	# Try preferred categories first
	for category in preferred_categories:
		if category in available_categories:
			return category
	
	# Fallback to any available category
	if not available_categories.is_empty():
		return available_categories.pick_random()
	
	# Ultimate fallback
	return "criminal_elements"

## Is this force from the Interested Parties subtable (Core Rules p.99)? Their
## two special rules — +1 to the Unique Individual roll, and the Quest-mission
## reroll of 1s — are the only ones keyed on the CATEGORY rather than the
## individual enemy, so the check lives here rather than on a per-enemy flag.
func _is_interested_parties(category: String, template: Dictionary) -> bool:
	if category.to_lower().replace(" ", "_") == "interested_parties":
		return true
	return str(template.get("category", "")).to_lower().replace(
		" ", "_") == "interested_parties"

func _calculate_enemy_count(
	difficulty: int, crew_size: int, is_quest: bool = false,
	crew_in_field: int = 0
) -> int:
	## Calculate enemy count based on crew size and difficulty (Core Rules p.63)
	##
	## Crew Size Rules (campaign crew size setting, NOT roster count):
	## - Size 6: Roll 2D6, pick HIGHER result
	## - Size 5: Roll 1D6
	## - Size 4: Roll 2D6, pick LOWER result
	##
	## Difficulty Modifiers (via DifficultyModifiers.gd):
	## - Challenging: Reroll 1s and 2s before picking
	## - Hardcore: Add +1 basic enemy to final count
	## - Insanity: +1 specialist enemy added separately (not here — see BattlePhase)
	## - Easy: Remove 1 Basic enemy if total is 5+ opponents
	##
	## Quest Mission Reroll (Core Rules p.99 — Interested Parties):
	## - During Quest missions, reroll any die scoring 1 once
	var base_count: int = 0
	var is_challenging := DifficultyModifiers.should_reroll_low_enemy_dice(difficulty)

	# Helper: roll a die with difficulty and quest reroll modifiers
	var _roll_die := func() -> int:
		var result := randi() % 6 + 1
		if is_challenging:
			# Reroll 1s and 2s once (Core Rules p.65: reroll before picking)
			if result <= 2:
				result = randi() % 6 + 1
		# Quest missions: reroll any die scoring 1 once (Core Rules p.99)
		elif is_quest and result == 1:
			result = randi() % 6 + 1
		return result

	# Sprint 26.5: Track rolls for debug logging
	var rolls: Array = []
	var roll_method: String = ""

	# Step 1: Calculate base enemy count using crew-size-based dice rolling
	match crew_size:
		6:
			# Roll 2D6, pick higher
			var roll1: int = _roll_die.call()
			var roll2: int = _roll_die.call()
			rolls = [roll1, roll2]
			roll_method = "2D6 pick HIGHER"
			base_count = max(roll1, roll2)
		5:
			# Roll 1D6
			var roll1: int = _roll_die.call()
			rolls = [roll1]
			roll_method = "1D6"
			base_count = roll1
		4:
			# Roll 2D6, pick lower
			var roll1: int = _roll_die.call()
			var roll2: int = _roll_die.call()
			rolls = [roll1, roll2]
			roll_method = "2D6 pick LOWER"
			base_count = min(roll1, roll2)
		_:
			# Default to crew size 6 behavior for other sizes
			var roll1: int = _roll_die.call()
			var roll2: int = _roll_die.call()
			rolls = [roll1, roll2]
			roll_method = "2D6 pick HIGHER (default)"
			base_count = max(roll1, roll2)

	var pre_modifier_count: int = base_count

	# p.93, immediately after the Numbers modifier: "Modify this, based on the
	# size of your crew in the field. If you are fielding a crew of 2 or more
	# figures below the standard size for your campaign (typically 6), subtract 1
	# from the enemy numbers." Unimplemented. A crew that walked in two figures
	# short — after casualties, Sick Bay, a Small Encounter sit-out, or simply
	# choosing to leave people on the ship — still faced the full force, so the
	# book's one concession to a depleted crew never applied. crew_in_field of 0
	# means the caller did not report it; the clause is then skipped rather than
	# assumed, because assuming would penalise every path that omits it.
	var short_crew: int = 0
	if crew_in_field > 0 and crew_size - crew_in_field >= 2:
		short_crew = 1
		base_count -= 1

	# Step 2: Apply difficulty-based modifiers using DifficultyModifiers (Core Rules pp.64-65)
	# Hardcore OR INSANITY: +1 to the final number faced (p.93)
	var modifier: int = DifficultyModifiers.get_enemy_count_modifier(difficulty)
	base_count += modifier
	modifier -= short_crew

	# Easy: Remove 1 Basic enemy if total would be 5+ (Core Rules Easy mode)
	var easy_reduction: int = DifficultyModifiers.get_easy_enemy_reduction(base_count, difficulty)
	base_count -= easy_reduction
	modifier -= easy_reduction

	# Ensure minimum of 1 enemy
	var final_count: int = max(1, base_count)

	# Sprint 26.5: Debug log the calculation
	_debug_log_enemy_count(crew_size, difficulty, roll_method, rolls, pre_modifier_count, modifier, final_count)

	return final_count
	##
func _create_enemy(category: String, difficulty: int) -> Resource:
	## Create a single enemy of specified category and difficulty using JSON data
	var enemy := Resource.new()

	# Try to use JSON data first
	var enemy_template = _get_enemy_template_from_json(category, difficulty)
	if not enemy_template.is_empty():
		return _create_enemy_from_template(enemy_template, difficulty)

	# Fallback to legacy system
	var enemy_types: Array = enemy_categories.get(category, ["Thug"])
	var enemy_type: String = enemy_types.pick_random()

	var base_stats = enemy_stats_base.get(enemy_type, {
		"combat_skill": 1, "toughness": 3, "speed": 4, "weapons": ["Handgun"]
	})

	# Apply difficulty modifiers
	var modified_stats = _apply_difficulty_modifiers(base_stats, difficulty)

	# Varied Armaments (p.104) is a SQUAD-level split into two groups, so it has
	# no meaning when creating one enemy in isolation — it is applied in
	# generate_enemies_as_dicts(), the live squad path.
	var weapons = modified_stats.weapons

	# Set enemy properties
	enemy.set_meta("name", enemy_type)
	enemy.set_meta("category", category)
	enemy.set_meta("combat_skill", modified_stats.combat_skill)
	enemy.set_meta("toughness", modified_stats.toughness)
	enemy.set_meta("speed", modified_stats.speed)
	enemy.set_meta("weapons", weapons)
	enemy.set_meta("difficulty", difficulty)

	return enemy

func _get_enemy_template_from_json(
	category: String, _difficulty: int
) -> Dictionary:
	## Get enemy template from JSON using D100 roll_range (book-accurate).
	## difficulty parameter preserved for API compatibility but not used
	## for selection — the Core Rules use flat D100 tables per category.
	return _roll_enemy_in_category(category)

func _calculate_enemy_threat_level(enemy_template: Dictionary) -> int:
	## Calculate threat level of enemy template
	## JSON uses flat properties: combat_skill, toughness (not nested stats)
	var combat: int = enemy_template.get("combat_skill", 0)
	var toughness: int = enemy_template.get("toughness", 3)

	# Simple threat calculation: (combat + toughness) / 2
	return max(1, (combat + toughness) / 2)

func _create_enemy_from_template(
	template: Dictionary, difficulty: int
) -> Resource:
	## Create enemy from JSON template with difficulty adjustments
	var enemy := Resource.new()

	# Basic information
	enemy.set_meta("id", template.get("id", "unknown"))
	enemy.set_meta("name", template.get("name", "Unknown Enemy"))

	# Stats — JSON uses flat properties, not nested "stats" sub-dict
	var base_stats := {
		"combat_skill": template.get("combat_skill", 0),
		"toughness": template.get("toughness", 3),
		"speed": template.get("speed", 4),
	}
	var modified_stats = _apply_json_difficulty_modifiers(
		base_stats, difficulty
	)

	enemy.set_meta("combat_skill", modified_stats.get("combat_skill", 0))
	enemy.set_meta("toughness", modified_stats.get("toughness", 3))
	enemy.set_meta("speed", modified_stats.get("speed", 4))

	# Weapons — JSON stores Core Rules notation (e.g., "2 A"): the number is the
	# basic weapon column, the letter the Specialist column (p.104).
	var weapons: Array = apply_ai_blade_rule(
		resolve_basic_weapon(template.get("weapons", "1 A")),
		str(template.get("ai", "A")),
		int(modified_stats.get("combat_skill", 0))
	)
	enemy.set_meta("weapons", weapons)

	# AI type and special rules from JSON
	enemy.set_meta("ai", template.get("ai", "A"))
	enemy.set_meta("panic", template.get("panic", "1-2"))
	enemy.set_meta("numbers", template.get("numbers", "+0"))
	enemy.set_meta(
		"special_rules", template.get("special_rules", [])
	)

	# Difficulty and category tracking
	enemy.set_meta("difficulty", difficulty)
	enemy.set_meta(
		"threat_level", _calculate_enemy_threat_level(template)
	)

	return enemy

func _apply_json_difficulty_modifiers(
	base_stats: Dictionary, difficulty: int
) -> Dictionary:
	## Apply difficulty modifiers to enemy stats
	var modified = base_stats.duplicate()

	# Difficulty uses GlobalEnums.DifficultyLevel values
	match difficulty:
		1: # Easy
			modified["combat_skill"] = max(
				0, modified.get("combat_skill", 0) - 1
			)
		3, 4, 5: # Hard, Veteran, Elite
			modified["combat_skill"] = (
				modified.get("combat_skill", 0) + 1
			)
			modified["toughness"] = (
				modified.get("toughness", 3) + 1
			)

	return modified

func _get_difficulty_name(difficulty: int) -> String:
	## Convert difficulty number to name used in spawn rules
	match difficulty:
		1: return "EASY"
		2: return "NORMAL"
		3: return "HARD"
		4: return "VETERAN"
		5: return "ELITE"
		_: return "NORMAL"

func _apply_difficulty_modifiers(base_stats: Dictionary, difficulty: int) -> Dictionary:
	## Apply difficulty modifiers to enemy stats
	var modified = base_stats.duplicate()

	match difficulty:
		1: # Easy - reduce stats slightly
			modified.combat_skill = max(0, modified.combat_skill - 1)
			modified.toughness = max(1, modified.toughness - 1)
		3: # Hard - increase stats
			modified.combat_skill += 1
			modified.toughness += 1
			# Add better weapons for hard enemies
			if modified.weapons.size() == 1:
				modified.weapons.append("Armor")

	return modified

# _roll_varied_weapons() was DELETED (Core Rules p.104). It claimed to implement
# the Varied Armaments optional rule but invented its own mechanic: a 70/30 per
# weapon chance to SWAP the listed weapon for one drawn from a hardcoded pool of
# ten weapon names that is not a table in either book. That both fabricated a
# mechanic and broke "Some enemies have a specific weapon listed, and always
# carries that." The book's actual rule — "split the non-Specialist opponents
# into two groups, and roll for the weapon carried by each group" — is now
# implemented at the squad level in generate_enemies_as_dicts().

func _progressive_strength_bonus(mission_data: Dictionary) -> int:
	## Extra figures from Progressive Difficulty Option 1 "Strength" (Compendium
	## p.30). Returns 0 unless the player enabled BASIC progression at creation.
	##
	## Prefers values stamped on mission_data (the project's "the mission carries
	## its own identity" rule) and falls back to the live campaign, so the option
	## works on the battle paths that do not stamp it.
	var options: Array = mission_data.get("progressive_difficulty_options", [])
	var turn_number: int = int(mission_data.get("campaign_turn", -1))
	if options.is_empty() or turn_number < 0:
		var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") \
			if Engine.get_main_loop() else null
		var campaign = gs.current_campaign if gs else null
		if campaign == null or not ("progress_data" in campaign):
			return 0
		var progress: Dictionary = campaign.progress_data
		if options.is_empty():
			options = progress.get("progressive_difficulty_options", [])
		if turn_number < 0:
			turn_number = int(progress.get("turns_played", 0))
	# Only Option 1 (BASIC) adds figures; Option 2 unlocks difficulty toggles
	# instead, so max() rather than a sum is the correct combination here.
	var bonus: int = 0
	for option: Variant in options:
		bonus = maxi(bonus, ProgressiveDifficultyRef.get_enemy_count_bonus(
			turn_number, int(option)))
	return bonus


func generate_enemies_as_dicts(
	mission_data: Dictionary, campaign_crew_size: int = 6
) -> Array[Dictionary]:
	## Generate enemies as Dictionary array using JSON data.
	## campaign_crew_size: the fixed campaign setting (4/5/6), NOT roster count.
	##
	## Core Rules order of operations (pp.92-93):
	## 1. Select enemy type (D100 encounter tables)
	## 2. Roll base enemy count (crew-size dice formula)
	## 3. Add Numbers modifier from enemy type
	## 4. Apply difficulty modifiers
	var danger_level: int = mission_data.get("danger_level", 2)
	var mission_source: String = mission_data.get(
		"mission_source", "patron"
	)
	var is_quest: bool = mission_data.get("is_quest", false)
	# GlobalEnums.DifficultyLevel ordinal. Needed for the Unique Individual roll
	# (Hardcore +1, Insanity always-present) — Core Rules pp.93-94.
	var difficulty_mode: int = int(mission_data.get("difficulty_mode", 0))

	# Red / Black Zone jobs (Core Rules Appendix III pp.149-151). Both were rolled
	# and PRINTED by MissionPrepComponent and applied nowhere: the generator never
	# read either flag, so a Red Job fielded an ordinary force and a Black Job
	# could draw any encounter category at all.
	var is_red_zone: bool = bool(mission_data.get("is_red_zone", false))
	var is_black_zone: bool = bool(mission_data.get("is_black_zone", false))

	# Step 1: Select enemy type FIRST (Core Rules pp.91-94)
	var category: String = ""
	var template: Dictionary = {}
	var preset_enemy: String = mission_data.get("enemy_type", "")
	if not preset_enemy.is_empty() and preset_enemy != "Unknown Hostiles":
		template = _find_enemy_template_by_name(preset_enemy)
		if not template.is_empty():
			category = template.get("category", "")
	# Fallback: roll random enemy from D100 encounter table
	if template.is_empty():
		if is_black_zone:
			# p.150: "You will always be facing an opponent from the Roving
			# Threats Subtable."
			category = "roving_threats"
		elif not mission_source.is_empty():
			category = _roll_encounter_category(mission_source)
		else:
			var objective: String = mission_data.get("objective", "patrol")
			category = _determine_enemy_category(objective.capitalize())
		template = _roll_enemy_in_category(category)

	# Step 2: Roll base enemy count using campaign crew size (Core Rules p.63)
	#
	# This passed `danger_level` — the p.83 Patron job Danger Pay rating — into a
	# parameter named `difficulty`, which indexes the DIFFICULTY MODE table
	# (EASY=1, NORMAL=2, CHALLENGING=4, HARDCORE=6, INSANITY=8). So the campaign
	# difficulty never reached the enemy count at all: Hardcore never got its +1,
	# Challenging never rerolled its 1s and 2s, Easy never dropped its enemy at
	# 5+. Worse than inert — a job that happened to roll danger_level 1 silently
	# applied EASY's reduction, and danger_level 4 applied CHALLENGING's rerolls,
	# so the Patron's danger rating was scrambling the enemy count using a table
	# it has nothing to do with. `difficulty_mode` was read 30 lines above and
	# used for the Unique Individual roll; it simply was not passed here.
	#
	# p.99 Interested Parties is an ENEMY rule, not a Quest rule: "During Quest
	# missions, when rolling for the number of opponents, reroll any die scoring
	# 1 once" appears in that subtable's entry. It applied to every Quest battle
	# regardless of who was on the other side.
	var quest_mission: bool = is_quest or mission_source == "quest" \
		or mission_source == "quest_finale"
	var interested_parties: bool = quest_mission and _is_interested_parties(
		category, template)
	var base_count: int = _calculate_enemy_count(
		difficulty_mode, campaign_crew_size, interested_parties,
		int(mission_data.get("crew_in_field", 0)))

	# Step 3: Add Numbers modifier from enemy type (Core Rules p.92)
	var numbers_mod: int = _parse_numbers_modifier(
		template.get("numbers", "+0"))

	# World Traits that change the OPPOSITION (Core Rules pp.73-74). All three
	# are keyed on the encounter category, so a Dangerous world does not swell a
	# gang fight and a Rampant Crime world does not swell a pack of Razor Lizards:
	#   "Heavily enforced — When fighting opponents from the Criminal Elements
	#    Encounter Table, the number encountered is reduced by 1."
	#   "Rampant crime — ... add 1 to the number encountered."
	#   "Dangerous — When rolling on the Roving Threats Encounter Table, increase
	#    the number of opponents by +1."
	# The traits were rolled, stored on the planet and printed in the briefing,
	# and changed nothing.
	#
	# Kept SEPARATE from numbers_mod on purpose: the Red Job branch below reuses
	# numbers_mod, and p.150 says the base of 7 takes "any modifier from the enemy
	# type encountered" and "no other modifiers are applied up or down". Folding
	# the trait into numbers_mod would smuggle it past that rule.
	var world_traits: Array = mission_data.get("world_traits", [])
	var effective_category: String = category if not category.is_empty() \
		else str(template.get("category", ""))
	var trait_enemy_mod: int = WorldTraitEffectsClass.enemy_count_modifier(
		world_traits, effective_category)

	# Patron job Benefits and Hazards that change the size of the opposition
	# (Core Rules pp.83-84): "Security Team — -1 enemy this turn", "Dangerous Job
	# — Increase enemy force numbers by +1", "Low Priority — Reduce enemy force
	# numbers by 1". All three were rolled, attached to the job, and printed in
	# the battle screen's PATRON CONDITIONS block; none reached the generator, so
	# a Dangerous Job fielded exactly as many enemies as a Security Team.
	#
	# Held separate from numbers_mod for the same reason as the world traits: the
	# Red Job branch below reuses numbers_mod alone, and p.150 allows the base of
	# 7 "any modifier from the enemy type encountered" and NO other.
	var patron_enemy_mod: int = PatronJobEffectsClass.enemy_count_modifier(mission_data)

	# Enemy traits that swell a force fought AS RIVALS:
	#   "Grudge: If encountered as Rivals, they bring one additional figure"
	#   (p.99, Renegade Soldiers)
	#   "Cop killer: If you ever fight Enforcers as Rivals, add +2 to their
	#   numbers" (p.96) — the book's own punishment for making an enemy of the law
	# Both were printed in the pre-battle briefing and added nobody. Gated on the
	# battle actually being a Rival fight: an Enforcer opportunity job is an
	# ordinary encounter.
	var is_rival_battle: bool = str(mission_data.get("mission_source", "")) == "rival" \
		or str(mission_data.get("rival_id", "")) != ""
	var grudge_mod: int = EnemyTraitRulesClass.rival_number_bonus(
		str(template.get("name", "")), is_rival_battle)

	var enemy_count: int = maxi(
		1, base_count + numbers_mod + trait_enemy_mod + patron_enemy_mod + grudge_mod)

	# Red Job Increased Opposition (p.150), verbatim: "Do not roll for opposing
	# numbers. Instead, you will encounter a base of 7 figures + any modifier
	# from the enemy type encountered. NO OTHER MODIFIERS ARE APPLIED up or
	# down." So the crew-size dice and the difficulty adjustment are discarded
	# outright — this replaces base_count rather than adding to it.
	if is_red_zone:
		enemy_count = maxi(1, RED_ZONE_BASE_FIGURES + numbers_mod)
	else:
		# Progressive Difficulty, Option 1 "Strength" (Compendium p.30): +1 basic
		# enemy from turn 5, +2 from turn 10, +2 and a Lieutenant from 15, +2 with
		# a specialist and a Lieutenant from 20. The player ticks this at campaign
		# creation and it was persisted and then read by NOBODY — every encounter
		# was the same size forever.
		#
		# NOT applied to Red Jobs: p.150 is explicit that the base of 7 stands with
		# "no other modifiers ... up or down", and that verbatim rule wins over the
		# expansion's "each encounter" phrasing.
		enemy_count += _progressive_strength_bonus(mission_data)

	var cat_info: Dictionary = _category_info(category)

	var enemy_name: String = template.get("name", "Unknown Hostiles")
	var base_combat: int = template.get("combat_skill", 0)
	var base_tough: int = template.get("toughness", 3)
	var base_speed: int = template.get("speed", 4)
	# Core Rules p.104: ONE roll on the numbered column arms the rank and file,
	# and the Specialist rolls separately on the lettered Specialist column.
	var weapon_code: Variant = template.get("weapons", "1 A")
	var base_weapons: Array = resolve_basic_weapon(weapon_code)
	var specialist_weapons: Array = resolve_specialist_weapon(weapon_code)

	# "Going medieval: Instead of normal weapons, each carries a Blade.
	# Specialists carry a Brutal Melee Weapon" (Core Rules p.99, Primitives).
	# REPLACES the loadout — "instead of" — so it runs before anything else reads
	# these arrays. The entry's weapon code is a literal "-", which
	# resolve_basic_weapon falls back to a Hand Gun for; a Primitive with a
	# handgun is the opposite of the whole entry.
	#
	# Applied here rather than after the animal check on purpose: a Blade IS a
	# manufactured weapon, so Primitives correctly keep their Specialist (whom
	# the rule explicitly arms) instead of being classed as unarmed animals.
	var going_medieval: Array = EnemyTraitRulesClass.going_medieval_loadout(
		str(template.get("name", "")))
	if not going_medieval.is_empty():
		base_weapons = [str(going_medieval[0])]
		specialist_weapons = [str(going_medieval[1])]

	var ai_code: String = str(template.get("ai", "A"))

	# Core Rules p.93 draws a hard line at animals "that do not use weapons".
	# They take no Blade, no Specialist loadout, and no AI weapon rule — a Sand
	# Runner cannot carry a sword. Detected from the loadout itself: these
	# entries name a natural weapon instead of a table code, which is the same
	# distinction the errata draws when it says "'animal' type enemies that only
	# carry natural melee weapons".
	var uses_weapons: bool = _uses_manufactured_weapons(base_weapons)

	# Optional Rule: Varied Armaments (Core Rules p.104) — "split the
	# non-Specialist opponents into two groups, and roll for the weapon carried
	# by each group." A second basic-column roll arms the back half of the
	# rank and file. Opt-in; off by default, exactly as the book has it.
	var second_group_weapons: Array = []
	var varied_armaments: bool = uses_weapons \
		and HouseRulesHelper.is_enabled("varied_armaments")
	if varied_armaments:
		# Going medieval REPLACES the loadout, so the second group is the same
		# Blade rather than a fresh roll that would hand out a Hand Gun.
		if going_medieval.is_empty():
			second_group_weapons = resolve_basic_weapon(weapon_code)
		else:
			second_group_weapons = [str(going_medieval[0])]

	# Specialist/Lieutenant per Core Rules p.93:
	#   1-2 opponents -> no Specialist; 3-6 -> one; 7+ -> two.
	#   Insanity difficulty -> "one further Specialist will be present".
	# Errata v1.06: "For 'animal' type enemies that only carry natural melee
	# weapons, Specialists are treated as normal combatants" — so animals get
	# no Specialist at all.
	var specialist_count: int = 0
	if uses_weapons:
		if enemy_count >= 7:
			specialist_count = 2
		elif enemy_count >= 3:
			specialist_count = 1
		if difficulty_mode == 8 and specialist_count > 0:  # INSANITY
			specialist_count += 1
		# Red Job (p.150): "Opposing figures will include 3 Specialists, one of
		# which is a Lieutenant." Three special figures TOTAL with the Lieutenant
		# counted among them — so two Specialists sit alongside it, not three.
		# This replaces the p.93 thresholds rather than stacking with them.
		if is_red_zone:
			specialist_count = RED_ZONE_SPECIALISTS - 1
		specialist_count = mini(specialist_count, maxi(0, enemy_count - 1))
	# A Red Job always fields its Lieutenant, even below the p.93 count of 4.
	var has_lieutenant: bool = (enemy_count >= 4) or is_red_zone

	var enemies: Array[Dictionary] = []
	for i in range(enemy_count):
		var role: String = "standard"
		var combat_mod: int = 0
		var weapons: Array = base_weapons.duplicate()
		var extra_weapons: Array = []

		if has_lieutenant and i == 0:
			role = "lieutenant"
			combat_mod = 1
			if uses_weapons:
				# p.93: "They carry a Blade in addition to their normal weapon,
				# and increase their Combat Skill by +1." Specialists and
				# Lieutenants "will both roll separately for their weapons", so
				# the Lieutenant gets its own basic-column roll rather than
				# sharing the rank-and-file result.
				#
				# A Going medieval entry has no column to roll on — the trait
				# replaced the loadout outright — so the fresh call would fall
				# back to a Hand Gun and put a pistol in the Primitive war
				# leader's hands. Caught by the generator-level test, not the
				# resolver one: the replacement at the top of this function is
				# correct and this second site quietly undid it.
				if going_medieval.is_empty():
					weapons = resolve_basic_weapon(weapon_code)
				else:
					weapons = [str(going_medieval[0])]
				extra_weapons = ["Blade"]
			# Otherwise p.93: "If the opponents encountered are animals that do
			# not use weapons, the Lieutenant will be a pack leader; increase
			# Combat Skill by +1, but MAKE NO OTHER CHANGES." No Blade.
		elif specialist_count > 0 and i >= (enemy_count - specialist_count):
			role = "specialist"
			weapons = specialist_weapons.duplicate()

		# Varied Armaments splits only the NON-Specialists (p.104).
		if varied_armaments and role != "specialist" \
				and not second_group_weapons.is_empty() \
				and i >= int(ceil((enemy_count - specialist_count) / 2.0)):
			weapons = second_group_weapons.duplicate()

		var display_name: String = enemy_name
		if role == "lieutenant":
			display_name = "%s Lieutenant" % enemy_name
		elif role == "specialist":
			display_name = "%s Specialist" % enemy_name

		var figure_combat: int = base_combat + combat_mod
		enemies.append({
			"type": enemy_name,
			"name": display_name,
			"role": role,
			"combat_skill": figure_combat,
			"toughness": base_tough,
			"reactions": 2 if role == "lieutenant" else 1,
			"speed": base_speed,
			# p.104 + errata v1.06: Rampaging AI always carry a Blade; Aggressive
			# AI do too unless Combat Skill is +0. Checked against THIS figure's
			# Combat Skill, so a Lieutenant's +1 can qualify it where its mooks
			# do not. Skipped entirely for animals with only natural weapons —
			# Large Bugs and Vent Crawlers are Rampaging (R) AI, and a literal
			# reading would hand a Blade to a creature with mandibles.
			"weapons": apply_ai_blade_rule(
				weapons + extra_weapons, ai_code, figure_combat) \
				if uses_weapons else (weapons + extra_weapons),
			# Errata v1.06: "Enemies with built-in weapons (like claws or fangs)
			# have the Melee weapon trait and thus receive the +2 bonus to
			# Brawling." BattleCalculations._get_brawl_weapon_bonus() already
			# grants +2 for a "melee" trait; natural weapons simply never carried
			# one, because they are not entries in the equipment database. Stamped
			# at the source so the combat math needs no special case for animals.
			"weapon_traits": ([] if uses_weapons else ["melee"]),
			"ai": template.get("ai", "A"),
			"panic": template.get("panic", "1-2"),
			"special_rules": template.get("special_rules", []),
			"is_leader": (role == "lieutenant"),
			"category": category,
			# The type's Numbers entry (Core Rules p.92). PreBattleUI has a NUMBERS
			# column that reads this key and was permanently blank because the live
			# generator never emitted it.
			"numbers": str(template.get("numbers", "")),
			# Category-level rules, including the Seize the Initiative modifier
			# (Core Rules p.112: "When fighting opponents from the Hired Muscle
			# encounter tables, modify by -1"). These were looked up ONLY in
			# select_enemy_for_mission(), which the live path never calls — so the
			# modifier read at the campaign layer was always 0 and PreBattleUI's
			# whole "Category rules" block was dead UI.
			"category_name": cat_info.get("name", ""),
			"category_rules": cat_info.get("rules", ""),
			# The category modifier (p.112 Hired Muscle -1) PLUS this enemy's own
			# named trait: "Careless: You are +1 to Seize the Initiative",
			# "Alert: You are -1" (pp.95-101). The per-enemy half had no consumer,
			# so an Alert opponent was as easy to get the drop on as a Careless one.
			#
			# The parenthetical totals some entries print ("for a final modifier of
			# 0", "for a total of -2") are the category modifier ALREADY folded in,
			# which is why the trait contributes only its own value here — reading
			# the parenthetical as the trait's value would cancel the category rule.
			"seize_initiative_modifier": int(cat_info.get("seize", 0))
				+ EnemyTraitRulesClass.seize_modifier(enemy_name),
			# "Prediction: You cannot Seize the Initiative" (p.100) and
			# "Unpredictable: Seize the Initiative roll is always unmodified"
			# (p.100) are absolutes that no modifier can express.
			"seize_blocked": EnemyTraitRulesClass.blocks_seize(enemy_name),
			"seize_unmodified": EnemyTraitRulesClass.seize_is_unmodified(enemy_name),
		})

	# "VIP — A random enemy will have +1 Toughness and a final Combat Skill of +2
	# (regardless of current value)" (Core Rules p.84 Hazards Subtable). Applied
	# to the rank and file only: the book says "a random enemy", and picking
	# BEFORE the Unique Individual is appended keeps the VIP one of the figures
	# actually rolled for this force rather than a Unique that is "always in
	# addition to those normally encountered" (p.94).
	#
	# Combat Skill is SET, not added — "regardless of current value" is explicit,
	# so a Lieutenant's +1 does not stack to +3.
	if PatronJobEffectsClass.has_vip_enemy(mission_data) and not enemies.is_empty():
		var vip_index: int = randi() % enemies.size()
		var vip: Dictionary = enemies[vip_index]
		vip["toughness"] = int(vip.get("toughness", 3)) \
			+ PatronJobEffectsClass.vip_toughness_bonus(mission_data)
		vip["combat_skill"] = PatronJobEffectsClass.vip_combat_skill_final(mission_data)
		vip["name"] = "%s (VIP)" % str(vip.get("name", enemy_name))
		vip["is_vip"] = true

	# Unique Individuals are added AFTER the roster above, because the book is
	# explicit that the figure "is always in addition to those normally
	# encountered" (Core Rules p.94) — it must not consume a Specialist or
	# Lieutenant slot or change the counts already rolled.
	for unique in roll_unique_individuals(
			mission_data, category, difficulty_mode, template):
		enemies.append(unique)

	return enemies


func roll_unique_individuals(
	mission_data: Dictionary, category: String, difficulty_mode: int = 0,
	base_template: Dictionary = {}
) -> Array[Dictionary]:
	## Core Rules pp.93-94. Returns the Unique Individual figures accompanying this
	## force — usually none.
	##
	## THE GAP THIS FILLS: this roll was never made anywhere. It lived in
	## BattlePhase.gd, which was deleted in 99fad30b2 and never re-homed, leaving
	## only post-battle consumers reading a "unique_kills" key nothing wrote. The
	## table itself (22 entries) has been sitting complete and unused in
	## enemy_types.json.
	##
	## Verbatim (p.93): "Unless fighting an Invasion battle or an enemy from the
	## Roving Threats Subtable, roll 2D6. Add +1 if fighting opponents from the
	## Interested Parties Subtable. If the campaign's difficulty mode is Hardcore,
	## add +1. On a roll of 9+, the opposition is accompanied by a Unique
	## Individual." And (p.94): "If the campaign's difficulty mode is Insanity, a
	## Unique Individual is present, even if fighting a Roving Threat. Roll 2D6
	## without any modifiers. A result of 11-12 means you have to fight 2 Unique
	## Individuals."
	var out: Array[Dictionary] = []
	var table: Array = enemy_data.get("unique_individuals", [])
	if table.is_empty():
		return out

	# GlobalEnums.DifficultyLevel: HARDCORE = 6, INSANITY = 8.
	var is_insanity: bool = difficulty_mode == 8
	var is_hardcore: bool = difficulty_mode == 6
	var is_invasion: bool = bool(mission_data.get("is_invasion", false)) \
		or str(mission_data.get("mission_source", "")) == "invasion"

	var count: int = 0
	if is_insanity:
		# Always present, unmodified roll, 11-12 = two. Applies even to Roving
		# Threats; the book calls that exception out by name.
		count = 2 if (randi_range(1, 6) + randi_range(1, 6)) >= 11 else 1
	else:
		if is_invasion or category == "roving_threats":
			return out
		var roll: int = randi_range(1, 6) + randi_range(1, 6)
		if category == "interested_parties":
			roll += 1
		if is_hardcore:
			roll += 1
		# Red Job (Core Rules p.150): "Add +1 to the roll to determine whether a
		# Unique Individual is present."
		if bool(mission_data.get("is_red_zone", false)):
			roll += RED_ZONE_UNIQUE_BONUS
		count = 1 if roll >= 9 else 0

	# Base profile of the enemy type being fought. Required by the designer's
	# official FAQ (modiphius.net/pages/five-parsecs-faq), verbatim: "The first
	# three Unique Individuals on the table (Enemy Bruiser, Enemy Heavy, Enemy
	# Boss) use the base profile of the enemy type you are fighting with a boost."
	# Their table rows carry "-" (keep the base value) and "+1" (base value plus
	# one) rather than absolute scores, which is meaningless without this.
	var base_combat: int = int(base_template.get("combat_skill", 0))
	var base_tough: int = int(base_template.get("toughness", 3))
	var base_speed: int = int(base_template.get("speed", 4))

	for _i in range(count):
		var entry: Dictionary = _roll_unique_individual_entry(table)
		if entry.is_empty():
			continue
		out.append({
			"type": str(entry.get("name", "Unique Individual")),
			"name": str(entry.get("name", "Unique Individual")),
			"role": "unique",
			"is_unique_individual": true,
			# "Unique Individuals are Fearless and will not be affected by Morale
			# checks" (p.105).
			"is_fearless": true,
			"combat_skill": _stat_or(entry.get("combat_skill", "-"), base_combat),
			"toughness": _stat_or(entry.get("toughness", "-"), base_tough),
			"speed": _stat_or(entry.get("speed", "-"), base_speed),
			"reactions": 1,
			"luck": int(entry.get("luck", 0)),
			# "Note that they may follow a different AI routine than the group they
			# are accompanying" (p.105). An entry with "-" (the Enemy Boss) uses
			# the main force's AI type.
			"ai": str(entry.get("ai", "A")) if str(entry.get("ai", "-")) != "-" else "",
			"weapons": str(entry.get("weapons", "")).split(", ", false),
			"special_rules": entry.get("special_rules", []),
			"category": category,
			"unique_id": str(entry.get("id", "")),
		})
	return out


func _roll_unique_individual_entry(table: Array) -> Dictionary:
	## D100 against the pp.105-107 table's roll_range bounds.
	var roll: int = randi_range(1, 100)
	for entry in table:
		var rng: Array = entry.get("roll_range", [])
		if rng.size() >= 2 and roll >= int(rng[0]) and roll <= int(rng[1]):
			return entry
	return table.back() if not table.is_empty() else {}


func _stat_or(raw: Variant, base: int) -> int:
	## Resolve one Unique Individual stat against the base enemy's profile.
	##
	## The pp.105-107 table mixes three notations, and the designer's FAQ is what
	## makes the first two meaningful: "The first three Unique Individuals on the
	## table (Enemy Bruiser, Enemy Heavy, Enemy Boss) use the base profile of the
	## enemy type you are fighting with a boost."
	##   "-"   keep the base enemy's value       (Enemy Heavy: all three)
	##   "+1"  base enemy's value plus one       (Enemy Bruiser Toughness,
	##                                            Enemy Boss Combat + Toughness)
	##   5     an absolute score                 (every later entry, e.g. Hired
	##                                            Killer 5" / +1 / 5)
	## Treating "+1" as "no data" — which an earlier pass did — silently threw the
	## boost away and gave an Enemy Bruiser the same Toughness as the mooks it
	## leads.
	if raw is int or raw is float:
		return int(raw)
	var s: String = str(raw).strip_edges()
	if s == "" or s == "-":
		return base
	if s.begins_with("+") or s.begins_with("-"):
		var delta: String = s.substr(1)
		if delta.is_valid_int():
			return base + (int(delta) * (-1 if s.begins_with("-") else 1))
		return base
	return int(s) if s.is_valid_int() else base


func _category_info(category_id: String) -> Dictionary:
	## Category-level display name, rules text and Seize modifier for an encounter
	## category (Core Rules p.94 tables / p.112 Seize the Initiative).
	for cat_data in enemy_data.get("enemy_categories", []):
		if cat_data.get("id", "") == category_id:
			return {
				"name": cat_data.get("name", ""),
				"rules": cat_data.get("category_rules", ""),
				"seize": cat_data.get("seize_initiative_modifier", 0),
			}
	return {"name": "", "rules": "", "seize": 0}

func generate_random_encounter() -> Array[Resource]:
	## Generate a random encounter for unexpected battles
	var encounter_types = ["criminal", "wildlife", "hostile"]
	var category = encounter_types.pick_random()
	var count = randi_range(1, 3)
	var difficulty = randi_range(1, 2) # Random encounters are usually easier

	var enemies: Array[Resource] = []
	for i: int in range(count):
		var enemy: Resource = _create_enemy(category, difficulty)

		enemies.append(enemy)

	return enemies

func get_enemy_description(enemy: Resource) -> String:
	## Get a description of an enemy for UI display
	var name = enemy.get_meta("name") if enemy and enemy.has_method("get_meta") else "Unknown"
	var combat: int = enemy.get_meta("combat_skill") if enemy and enemy.has_method("get_meta") else 1
	var toughness: int = enemy.get_meta("toughness") if enemy and enemy.has_method("get_meta") else 3
	var weapons = enemy.get_meta("weapons") if enemy and enemy.has_method("get_meta") else []

	var weapon_text = weapons[0] if weapons.size() > 0 else "Unarmed"

	return "%s (Combat: %d, Toughness: %d) - Armed with %s" % [name, combat, toughness, weapon_text]

func get_enemy_threat_level(enemies: Array) -> String:
	## Calculate overall threat level of enemy group
	var total_threat: int = 0

	for enemy in enemies:
		var combat: int = enemy.get_meta("combat_skill") if enemy and enemy.has_method("get_meta") else 1
		var toughness: int = enemy.get_meta("toughness") if enemy and enemy.has_method("get_meta") else 3
		total_threat += combat + (toughness / 2.0)

	if total_threat <= 6:
		return "Low"
	elif total_threat <= 12:
		return "Medium"
	else:
		return "High"


## ═══════════════════════════════════════════════════════════════════════════════
## D100 ENCOUNTER TABLE METHODS — Core Rules pp.94-103
## ═══════════════════════════════════════════════════════════════════════════════

func select_enemy_for_mission(mission_source: String) -> Dictionary:
	## Roll on D100 encounter tables to select enemy type for a mission.
	## Returns full enemy template dict with "category" key added.
	## mission_source: "patron", "opportunity", "quest", "unknown_rival"
	var category: String = _roll_encounter_category(mission_source)
	var template: Dictionary = _roll_enemy_in_category(category)
	if template.is_empty():
		# Fallback: pick any enemy from any category
		template = _roll_enemy_in_category("criminal_elements")
	template["category"] = category
	# Look up category-level rules (seize initiative modifier, etc.)
	for cat_data in enemy_data.get("enemy_categories", []):
		if cat_data.get("id", "") == category:
			template["category_name"] = cat_data.get("name", "")
			template["category_rules"] = cat_data.get(
				"category_rules", ""
			)
			template["seize_initiative_modifier"] = cat_data.get(
				"seize_initiative_modifier", 0
			)
			break
	return template

func _roll_encounter_category(mission_source: String) -> String:
	## Roll D100 on enemy_encounter_categories table (Core Rules p.94).
	## Returns category ID like "criminal_elements", "hired_muscle", etc.
	var tables: Dictionary = enemy_data.get(
		"enemy_encounter_categories", {}
	)

	# The p.94 table has four columns — Opportunity / Patron / Quest / Unknown
	# Rival — and the live mission vocabulary does not match its key names, so
	# the lookup fell through to a silent `tables.get("patron")` fallback:
	#
	#   "rival"        -> the PATRON column, whose Roving Threats band is 76-100.
	#                     So a quarter of Rival battles were fought against
	#                     wildlife, and the Unknown Rival column has NO Roving
	#                     Threats entry at all ("-" in the book). p.101 says the
	#                     same thing from the other side: "Enemies from this list
	#                     never become Rivals." Its distribution is also far
	#                     harsher — Criminal Elements 1-50 against the Patron
	#                     column's 1-25.
	#   "quest_finale" -> likewise the Patron column instead of Quest.
	#
	# A missing key must never resolve to a plausible-looking neighbour. Unknown
	# sources now warn and take Opportunity, the book's default column.
	var column: String = mission_source
	match mission_source:
		"rival", "unknown_rival":
			column = "unknown_rival"
		"quest", "quest_finale":
			column = "quest"
		"patron", "faction":
			column = "patron"
		"opportunity", "invasion", "":
			column = "opportunity"
		_:
			push_warning(
				"EnemyGenerator: no p.94 encounter column for mission_source '%s'; using Opportunity"
				% mission_source)
			column = "opportunity"

	var source_table: Dictionary = tables.get(column, {})

	if source_table.is_empty():
		return "criminal_elements"

	var roll: int = randi_range(1, 100)
	for category_id in source_table:
		var range_arr: Array = source_table[category_id]
		if range_arr.size() >= 2:
			if roll >= range_arr[0] and roll <= range_arr[1]:
				return category_id

	# Shouldn't reach here if D100 ranges are complete
	return "criminal_elements"

func _roll_enemy_in_category(category_id: String) -> Dictionary:
	## Roll D100 within a category to pick specific enemy type.
	## Uses per-enemy roll_range fields for book-accurate selection.
	##
	## Compendium p.48: the Elite-level tables "TAKE THE PLACE OF the regular
	## encounter tables in the core rulebook", so when that option is on the
	## substitution happens here, at the one point every category roll passes
	## through. Returns {} when the option is off or the category has no elite
	## table, which falls straight through to the core tables below.
	var elite: Dictionary = CompendiumEliteEnemiesRef.roll_enemy_in_category(category_id)
	if not elite.is_empty():
		return elite

	for category_data in enemy_data.get("enemy_categories", []):
		if category_data.get("id", "") == category_id:
			var enemies: Array = category_data.get("enemies", [])
			if enemies.is_empty():
				return {}

			var roll: int = randi_range(1, 100)
			for enemy in enemies:
				var r: Array = enemy.get("roll_range", [0, 0])
				if r.size() >= 2 and roll >= r[0] and roll <= r[1]:
					return enemy

			# Fallback if roll didn't match (shouldn't happen)
			return enemies.pick_random()

	return {}

func _find_enemy_template_by_name(enemy_name: String) -> Dictionary:
	## Search all categories for an enemy matching the given name.
	## Used when a patron job specifies a preset enemy type.
	for category_data in enemy_data.get("enemy_categories", []):
		for enemy in category_data.get("enemies", []):
			if enemy.get("name", "") == enemy_name:
				var result: Dictionary = enemy.duplicate()
				result["category"] = category_data.get("id", "")
				return result
	return {}

## Public wrapper for dice-based enemy count formula (Core Rules p.63).
## Used by BattleSetupWizard and other external callers.
func calculate_enemy_count(
	difficulty: int, crew_size: int, is_quest: bool = false
) -> int:
	return _calculate_enemy_count(difficulty, crew_size, is_quest)

## Calculate enemy count for the Raided starship travel event (Core Rules p.70).
## Uses a DIFFERENT formula than standard battles — one step up in dice:
## - Crew 6: Roll 3D6, pick HIGHEST
## - Crew 5: Roll 2D6, pick HIGHEST
## - Crew 4: Roll 1D6
func calculate_raided_enemy_count(campaign_crew_size: int) -> int:
	match campaign_crew_size:
		6:
			# 3D6 pick highest
			var rolls: Array[int] = []
			for i in range(3):
				rolls.append(randi() % 6 + 1)
			return rolls.max()
		5:
			# 2D6 pick highest
			var roll1: int = randi() % 6 + 1
			var roll2: int = randi() % 6 + 1
			return max(roll1, roll2)
		4:
			# 1D6
			return randi() % 6 + 1
		_:
			# Default to crew 6 formula
			var rolls: Array[int] = []
			for i in range(3):
				rolls.append(randi() % 6 + 1)
			return rolls.max()

## ═══════════════════════════════════════════════════════════════════════════════
## NUMBERS MODIFIER PARSING — Core Rules p.92
## ═══════════════════════════════════════════════════════════════════════════════

func _parse_numbers_modifier(numbers_str) -> int:
	## Parse the Numbers modifier from enemy type (e.g. "+2", "+0", "+3").
	## Returns the integer modifier to add to base enemy count.
	var s: String = str(numbers_str).strip_edges()
	if s.begins_with("+"):
		return int(s.substr(1))
	return int(s)

## ═══════════════════════════════════════════════════════════════════════════════
## WEAPON CODE RESOLUTION — Core Rules weapon tables
## ═══════════════════════════════════════════════════════════════════════════════

## ═══════════════════════════════════════════════════════════════════════════════
## ENEMY WEAPONS — Core Rules p.104
## ═══════════════════════════════════════════════════════════════════════════════
##
## The book: "Enemies are usually listed with a weapon code and a Specialist code
## under Weapons (a number and a letter respectively). To determine the weapon
## carried by the basic opponents (except Specialists), roll once below. Then roll
## for the Specialist weapon if available."
##
## So "2 C" means the rank-and-file roll 1D6 on the WEAPON 2 column, and the
## Specialist rolls 1D6 on the SPECIALIST C column. One roll each, not a count.
##
## THE GAP THIS FIXES: both halves of that notation were read backwards. The
## number was treated as "how many weapons to roll" and the LETTER was mapped
## onto the basic columns (A→weapon_1, B→weapon_2, C→weapon_3). Consequences on
## every enemy in every battle:
##   - a "2 A" enemy got TWO weapons rolled off the WEAPON 1 column
##   - the column actually rolled was chosen by the Specialist code
##   - the entire 18-entry Specialist table was unreachable, so Specialists
##     carried the same gun as the mooks they lead
##   - "Scrap Pistol + Blade" / "Handgun + Ripper Sword" stayed one fused string
##     (the "handle combo weapons" comment sat above a bare `break`)
##   - weapon_tables.ai_weapon_rules in enemy_types.json was never consulted
## The JSON data was correct and complete the whole time.

const _BASIC_COLUMNS := {1: "weapon_1", 2: "weapon_2", 3: "weapon_3"}
const _SPECIALIST_COLUMNS := {
	"A": "specialist_A", "B": "specialist_B", "C": "specialist_C"
}

func _split_combo(weapon_name: String) -> Array:
	## Two table entries list a pair joined by "+" ("Scrap Pistol + Blade",
	## "Handgun + Ripper Sword"). They are two carried weapons, not one item.
	var out: Array = []
	for part in weapon_name.split("+"):
		var trimmed: String = str(part).strip_edges()
		if not trimmed.is_empty():
			out.append(trimmed)
	return out if not out.is_empty() else [weapon_name]

func _roll_on_weapon_table(table_key: String, column: String) -> Array:
	## One D6 roll on one column of one weapon table (Core Rules p.104).
	var table: Array = enemy_data.get("weapon_tables", {}).get(table_key, [])
	if table.is_empty():
		return ["Hand Gun"]
	var roll: int = randi_range(1, 6)
	for row in table:
		if int(row.get("roll", 0)) == roll:
			return _split_combo(str(row.get(column, "Hand Gun")))
	return ["Hand Gun"]

func parse_weapon_code(weapon_code) -> Dictionary:
	## Split an enemy's WEAPONS entry into its two book halves.
	## Returns {"is_table_code", "basic_column", "specialist_column", "fixed"}.
	## `fixed` carries the literal loadout for entries that name their weapons
	## outright ("Hand Cannon, Blade", "Fangs (Damage +1)") — p.104: "Some enemies
	## have a specific weapon listed, and always carries that. No roll is made."
	if weapon_code is Array:
		return {"is_table_code": false, "fixed": (weapon_code as Array).duplicate()}

	var code_str: String = str(weapon_code).strip_edges()
	if code_str.is_empty() or code_str == "-":
		return {"is_table_code": false, "fixed": ["Hand Gun"]}

	var parts: PackedStringArray = code_str.split(" ", false)
	if parts.size() == 2 and parts[0].is_valid_int() \
			and _SPECIALIST_COLUMNS.has(parts[1].to_upper()):
		return {
			"is_table_code": true,
			"basic_column": _BASIC_COLUMNS.get(int(parts[0]), "weapon_1"),
			"specialist_column": _SPECIALIST_COLUMNS[parts[1].to_upper()],
			"fixed": [],
		}

	# A literal loadout, comma-separated for multiples.
	var fixed: Array = []
	for w in code_str.split(","):
		var trimmed: String = str(w).strip_edges()
		if not trimmed.is_empty():
			fixed.append(trimmed)
	return {"is_table_code": false,
		"fixed": fixed if not fixed.is_empty() else [code_str]}

func resolve_basic_weapon(weapon_code) -> Array:
	## The RANK-AND-FILE loadout for an enemy entry: one D6 on the numbered
	## basic-weapon column, or the literal weapons if the entry names them.
	var parsed: Dictionary = parse_weapon_code(weapon_code)
	if not parsed.get("is_table_code", false):
		return parsed.get("fixed", ["Hand Gun"])
	return _roll_on_weapon_table("basic", parsed["basic_column"])

func resolve_specialist_weapon(weapon_code) -> Array:
	## The SPECIALIST loadout: one D6 on the lettered Specialist column. Entries
	## that name a literal loadout have no Specialist column, so the Specialist
	## simply carries the same listed weapons (p.104: "always carries that").
	var parsed: Dictionary = parse_weapon_code(weapon_code)
	if not parsed.get("is_table_code", false):
		return parsed.get("fixed", ["Hand Gun"])
	return _roll_on_weapon_table("specialist", parsed["specialist_column"])

## The natural weapons carried by the animal entries in enemy_types.json. Every
## non-table-code loadout in the file is either one of these or a manufactured
## weapon ("Hand Cannon, Blade"), so this cleanly separates Core Rules p.93's
## "animals that do not use weapons" from armed enemies that happen to have a
## fixed loadout. The errata calls the same set "natural melee weapons".
const _NATURAL_WEAPONS := ["fangs", "claws", "mandibles", "smash", "touch"]

func _uses_manufactured_weapons(weapons: Array) -> bool:
	## False only when EVERY listed weapon is a natural one — a creature with
	## fangs and nothing else. An enemy carrying any manufactured weapon is a
	## weapon user for the p.93 Lieutenant rule and the p.104 AI Blade rule.
	if weapons.is_empty():
		return true
	for w in weapons:
		var name: String = str(w).to_lower()
		var natural: bool = false
		for stem in _NATURAL_WEAPONS:
			if name.begins_with(stem):
				natural = true
				break
		if not natural:
			return true
	return false

func apply_ai_blade_rule(
	weapons: Array, ai_code: String, combat_skill: int
) -> Array:
	## Core Rules p.104, as corrected by the official errata v1.06 ("Replace
	## reference to Psycho AI with Rampaging AI" — there is no Psycho AI type in
	## the p.92 code table; R is Rampage, which is what the Psychos entry uses):
	##   - Rampaging (R) AI ALWAYS carry a Blade in addition to any other weapon.
	##   - Aggressive (A) AI carry a Blade in addition to any listed weapons,
	##     UNLESS their Combat Skill is +0.
	## Was never implemented anywhere; enemy_types.json even ships the rule text
	## under weapon_tables.ai_weapon_rules, unread.
	var code: String = ai_code.strip_edges().to_upper()
	var gets_blade: bool = false
	if code.begins_with("R"):
		gets_blade = true
	elif code.begins_with("A") and combat_skill != 0:
		gets_blade = true
	if not gets_blade or "Blade" in weapons:
		return weapons
	var out: Array = weapons.duplicate()
	out.append("Blade")
	return out

## ═══════════════════════════════════════════════════════════════════════════════
## DEBUG LOGGING - Sprint 26.5: Enemy Count Calculation Tracing
## ═══════════════════════════════════════════════════════════════════════════════

## Debug flag - set to true to enable enemy count debug logging
var DEBUG_ENEMY_COUNT := false

func _debug_log_enemy_count(crew_size: int, difficulty: int, roll_method: String, rolls: Array, base_count: int, modifier: int, final_count: int) -> void:
	## Log enemy count calculation for debugging
	if not DEBUG_ENEMY_COUNT:
		return
	print_verbose("│ Dice Rolls: %s" % str(rolls))
	if modifier != 0:
		pass


func enable_debug_logging() -> void:
	## Enable enemy count debug logging
	DEBUG_ENEMY_COUNT = true


func disable_debug_logging() -> void:
	## Disable enemy count debug logging
	DEBUG_ENEMY_COUNT = false
