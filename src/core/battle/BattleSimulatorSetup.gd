class_name BattleSimulatorSetup
extends RefCounted

## Generates a standalone Core Rules battle for the Battle Simulator.
##
## Everything a rule decides is decided by the SAME code the campaign uses, so a
## Simulator battle is set up the way the book sets one up rather than by a parallel
## copy of the rules:
##   crew size and enemy numbers  Core Rules p.63, through EnemyGenerator
##   difficulty mode              pp.64-65, EnemyGenerator + SeizeInitiativeSystem
##   enemy type                   pp.94-98 D100 tables, through EnemyGenerator
##   objective / Notable Sight    p.89, through MissionTableManager
##   Deployment Condition         p.88, through FPCM_DeploymentConditionsSystem
##   set-up consequences          BattleSetupRules.compute() (e.g. Small Encounter)
##   Seize the Initiative         p.112, SeizeInitiativeSystem.build_battle_context()
##
## Until 2026-10-29 it rolled none of these. It fielded a flat 5 enemies plus an
## invented difficulty bonus, identical clones, a crew whose stats were random ranges
## in neither book, and "Hard (+1 enemy)" / "Brutal (+2 enemies)" difficulty levels the
## book does not have.
##
## The returned mission carries `standalone: true` (T11-49), which is what keeps this
## battle from reading or writing the campaign GameState auto-loads at every launch.

const CharacterTableRoller := preload("res://src/core/character/Generation/CharacterTableRoller.gd")
const EnemyGeneratorScript := preload("res://src/core/systems/EnemyGenerator.gd")
const MissionTableManagerScript := preload("res://src/core/mission/MissionTableManager.gd")
const DeploymentConditionsScript := preload("res://src/core/battle/DeploymentConditionsSystem.gd")
const BattleSetupRulesScript := preload("res://src/core/battle/BattleSetupRules.gd")
const SeizeInitiativeScript := preload("res://src/core/battle/SeizeInitiativeSystem.gd")
const StartingEquipmentScript := preload(
	"res://src/core/character/Equipment/StartingEquipmentGenerator.gd")

const ENEMY_TYPES_PATH := "res://data/enemy_types.json"
const MISSION_TEMPLATES_PATH := "res://data/mission_templates.json"

## Core Rules p.63: "The default campaign crew size is 6 crew members ... you may set
## the campaign crew size to 5 or even 4." Enemy numbers follow from it.
const CREW_SIZES: Array[int] = [4, 5, 6]
const DEFAULT_CREW_SIZE := 6

## Core Rules pp.64-65, the five difficulty modes, as GlobalEnums.DifficultyLevel
## ordinals (EASY 1, NORMAL 2, CHALLENGING 4, HARDCORE 6, INSANITY 8). HARD, NIGHTMARE
## and ELITE are deprecated aliases that are in neither book.
const DIFFICULTY_MODES: Array[int] = [1, 2, 4, 6, 8]
const DEFAULT_DIFFICULTY_MODE := 2

## Core Rules p.15, Baseline Human: "They begin the game with the following profile:
## REACTIONS 1, SPEED 4", COMBAT SKILL +0, TOUGHNESS 3, SAVVY +0." The Simulator makes
## no p.24-27 creation-table rolls, so this is every crew member's profile; a player
## fielding their own crew uses their own sheets at the table.
const BASELINE_HUMAN := {
	"reactions": 1, "speed": 4, "combat_skill": 0, "toughness": 3, "savvy": 0, "luck": 0,
}

var _enemy_data: Dictionary = {}
var _mission_data: Dictionary = {}


func _init() -> void:
	_enemy_data = _load_json(ENEMY_TYPES_PATH)
	_mission_data = _load_json(MISSION_TEMPLATES_PATH)


## Returns enemy categories for UI dropdown: [{id, name}]
func get_enemy_categories() -> Array:
	var categories: Array = []
	for cat in _enemy_data.get("enemy_categories", []):
		categories.append({
			"id": cat.get("id", ""),
			"name": cat.get("name", "Unknown")
		})
	return categories


## Returns enemies within a specific category
func get_enemies_for_category(category_id: String) -> Array:
	for cat in _enemy_data.get("enemy_categories", []):
		if cat.get("id", "") == category_id:
			return cat.get("enemies", [])
	return []


## Returns the mission types for the UI dropdown: [{type, name}]. The four are the
## Core Rules job sources (Opportunity, Patron, Quest, Rival); each picks its own
## column of the p.88 condition, p.89 objective and p.94 encounter tables.
func get_mission_types() -> Array:
	var types: Array = []
	for template in _mission_data.get("mission_templates", []):
		var type_id: String = str(template.get("type", "UNKNOWN"))
		types.append({"type": type_id, "name": type_id.capitalize()})
	return types


## Generate a complete battle context from the player's choices.
## config: {crew_size: int (4-6), difficulty_mode: int (GlobalEnums.DifficultyLevel),
##          enemy_category: String ("" / "random" rolls one), enemy_type: String (id;
##          "" / "random" rolls one), mission_type: String ("" / "RANDOM" picks one)}
## Returns: {crew, enemies, mission_data, crew_size, sitting_out, spare_weapons}
func generate_battle_context(config: Dictionary) -> Dictionary:
	var crew_size: int = int(config.get("crew_size", DEFAULT_CREW_SIZE))
	if not crew_size in CREW_SIZES:
		crew_size = clampi(crew_size, CREW_SIZES[0], CREW_SIZES[-1])
	var difficulty_mode: int = normalize_difficulty_mode(
		int(config.get("difficulty_mode", DEFAULT_DIFFICULTY_MODE)))

	var mission: Dictionary = _generate_mission(str(config.get("mission_type", "")))
	mission["difficulty_mode"] = difficulty_mode
	# T11-49: DECLARE that this battle owns no campaign state.
	#
	# TacticalBattleUI is shared with the campaign and decided ownership by ABSENCE -
	# no `battle_mode`, and no `GameState.current_campaign`. Battle Simulator sets no
	# battle_mode, and `GameState._try_auto_load_last_campaign()` puts a campaign in
	# current_campaign at EVERY launch, gating only on `last_campaign` being non-empty
	# - so the second signal can never fire once the player has any save. Measured on
	# deploy #28: a Battle Simulator battle checkpointed itself into
	# `campaign.progress_data["active_battle"]`, and ERASED it on Return.
	#
	# ⚠ Deliberately NOT `battle_mode`. That field routes
	# `BattleResolverRouter.resolve()` and vetoes the narrative wrap
	# (`CampaignTurnController._should_present_narrative_wrap` treats any non-empty,
	# non-"standard" value as another gamemode), so stamping a mode here would change
	# auto-resolve behaviour as a side effect of a data-safety fix.
	#
	# EnemyGenerator reads the same flag, so the auto-loaded campaign's Compendium
	# toggles, house rules and Progressive Difficulty do not reach this force either.
	mission["standalone"] = true

	var generator = EnemyGeneratorScript.new()
	var enemy_name: String = _chosen_enemy_name(generator,
		str(config.get("enemy_category", "")), str(config.get("enemy_type", "")))
	if not enemy_name.is_empty():
		mission["enemy_type"] = enemy_name
	var enemies: Array = generator.generate_enemies_as_dicts(mission, crew_size)

	var crew: Array = _generate_crew(crew_size)
	var weapons: Array = _issue_starting_weapons(crew)

	# p.88 consequences, computed where the campaign computes them.
	var setup: Dictionary = BattleSetupRulesScript.compute(mission, enemies.size(), crew.size())
	mission["setup_rules"] = setup
	if int(setup.get("enemy_delta", 0)) != 0 and not enemies.is_empty():
		enemies = BattleSetupRulesScript.apply_enemy_delta(enemies, int(setup["enemy_delta"]))
	var sitting_out: Array = []
	var cap_delta: int = int(setup.get("crew_cap_delta", 0))
	while cap_delta < 0 and crew.size() > 1:
		# p.88 Small Encounter: "a random crew member" sits the fight out.
		var pick: int = _roll(crew.size(), "Battle Simulator: crew member sitting out") - 1
		sitting_out.append(crew[pick].get("character_name", ""))
		crew.remove_at(pick)
		cap_delta += 1

	var first_enemy: Dictionary = enemies[0] if not enemies.is_empty() else {}
	mission["enemy_name"] = first_enemy.get("type", first_enemy.get("name", ""))
	mission["initiative_context"] = SeizeInitiativeScript.build_battle_context(
		crew, enemies.size(), difficulty_mode,
		int(first_enemy.get("seize_initiative_modifier", 0)),
		str(first_enemy.get("type", "Enemy")),
		bool(setup.get("can_seize_initiative", true)), "")

	return {
		"crew": crew,
		"enemies": enemies,
		"mission_data": mission,
		"crew_size": crew_size,
		"sitting_out": sitting_out,
		"spare_weapons": weapons.slice(crew_size),
	}


## A difficulty ordinal the Simulator offers, or Normal. Anything else (the deprecated
## HARD / NIGHTMARE / ELITE aliases, or the 1-5 scale this screen used to send) is
## not a Core Rules mode.
static func normalize_difficulty_mode(mode: int) -> int:
	return mode if mode in DIFFICULTY_MODES else DEFAULT_DIFFICULTY_MODE


## Baseline Human crew (p.15) with names from the shared name tables.
func _generate_crew(count: int) -> Array:
	var crew: Array = []
	for i in range(count):
		# One name, both keys (a second call was rolled and then overwritten).
		var crew_name: String = CharacterTableRoller.generate_random_name()
		var member: Dictionary = BASELINE_HUMAN.duplicate()
		member["name"] = crew_name
		member["character_name"] = crew_name
		member["species_id"] = "human"
		crew.append(member)
	return crew


## Core Rules p.28 Crew Equipment: "3 rolls on the Military Weapon Table" and "3 rolls on
## the Low-tech Weapon Table", which "can be issued and distributed to your characters
## as you see fit". The Simulator issues one each in roll order, Military first; with a
## crew under six the rest are returned as spares. Rolled through the same tables and
## DiceManager contexts as campaign creation ("Equipment: military_weapon").
func _issue_starting_weapons(crew: Array) -> Array:
	var dm: Node = _dice_manager()
	var counts: Dictionary = StartingEquipmentScript.crew_weapon_roll_counts()
	var weapons: Array = []
	for table: String in ["military_weapon", "low_tech_weapon"]:
		for i in range(int(counts.get(table, 0))):
			var name: String = StartingEquipmentScript.roll_on_weapon_table(table, dm)
			if not name.is_empty():
				weapons.append(name)
	for i in range(mini(crew.size(), weapons.size())):
		crew[i]["weapon_name"] = weapons[i]
		crew[i]["equipment"] = [weapons[i]]
	return weapons


## The enemy the player picked, the book's roll within a picked category, or "" to let
## EnemyGenerator roll the category itself off the mission's p.94 column.
func _chosen_enemy_name(generator, category_id: String, enemy_id: String) -> String:
	if category_id.is_empty() or category_id == "random":
		return ""
	if not enemy_id.is_empty() and enemy_id != "random":
		for enemy in get_enemies_for_category(category_id):
			if str(enemy.get("id", "")) == enemy_id:
				return str(enemy.get("name", ""))
	return str(generator.roll_core_enemy_type(category_id).get("name", ""))


## Mission identity plus the p.88 / p.89 rolls, made in the campaign's order.
func _generate_mission(mission_type: String) -> Dictionary:
	var templates: Array = _mission_data.get("mission_templates", [])
	var template: Dictionary = {}
	if mission_type.is_empty() or mission_type.to_upper() == "RANDOM":
		if not templates.is_empty():
			template = templates[_roll(templates.size(), "Battle Simulator: mission type") - 1]
	else:
		for t in templates:
			if str(t.get("type", "")) == mission_type:
				template = t
				break
		if template.is_empty() and not templates.is_empty():
			template = templates[0]

	var type_id: String = str(template.get("type", "OPPORTUNITY"))
	var source: String = type_id.to_lower()
	var mission: Dictionary = {
		"title": _mission_title(template),
		"type": type_id,
		"mission_source": source,
		"battle_type": 0,
	}

	var mtm = MissionTableManagerScript.new()
	var objective: Dictionary = mtm.roll_mission_objective(
		mtm.get_objective_table_for_type(source))
	mission["objective_details"] = objective
	mission["objective"] = str(objective.get("name", ""))
	mission["objective_type"] = str(objective.get("type", ""))
	if str(objective.get("victory_condition", "")) != "":
		mission["victory_condition"] = objective["victory_condition"]
	if str(objective.get("placement_rules", "")) != "":
		mission["placement_rules"] = objective["placement_rules"]
	mission["notable_sight"] = mtm.roll_notable_sight(
		mtm.get_deployment_column_for_type(source))

	var conditions = DeploymentConditionsScript.new()
	var condition = conditions.roll_deployment_condition(_condition_column(source))
	var deployment_condition: Dictionary = {}
	if condition:
		deployment_condition = {
			"condition_id": condition.condition_id,
			"title": condition.title,
			"description": condition.description,
			"effects": condition.effects,
			"effects_summary": conditions.get_condition_effects_summary(condition),
		}
	mission["deployment_condition"] = deployment_condition
	mission["deployment"] = deployment_condition
	return mission


func _condition_column(source: String) -> int:
	match source:
		"patron": return DeploymentConditionsScript.MissionType.PATRON
		"rival": return DeploymentConditionsScript.MissionType.RIVAL
		"quest": return DeploymentConditionsScript.MissionType.QUEST
	return DeploymentConditionsScript.MissionType.OPPORTUNITY


## A flavour title from the template's own text and the location list. Not a rule.
func _mission_title(template: Dictionary) -> String:
	var titles: Array = template.get("title_templates", [])
	if titles.is_empty():
		return "Battle Simulation"
	var title: String = str(titles[_roll(titles.size(), "Battle Simulator: mission title") - 1])
	var places: Array = _mission_data.get("mission_locations", [])
	var place: String = str(places[_roll(places.size(), "Battle Simulator: location") - 1]) \
		if not places.is_empty() else "the Fringe"
	return title.replace("{LOCATION}", place)


## 1..sides through DiceManager when it is reachable (this class is built with .new()
## and is never in the scene tree, so the autoload is reached through the main loop).
func _roll(sides: int, context: String) -> int:
	if sides <= 1:
		return 1
	var dm: Node = _dice_manager()
	if dm != null and dm.has_method("legacy_randi_range"):
		return clampi(int(dm.legacy_randi_range(sides, context)), 1, sides)
	return randi_range(1, sides)


func _dice_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/DiceManager")
	return null


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("BattleSimulatorSetup: Could not load %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		file.close()
		return json.data
	file.close()
	return {}
