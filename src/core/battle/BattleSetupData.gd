class_name BattleSetupData
extends Resource

## Pre-Battle → Battle data contract
## Contains all data needed to initialize a battle from pre-battle phase
##
## Usage:
##   var setup := BattleSetupData.new()
##   setup.initialize(crew, enemies, mission)
##   SignalBus.pre_battle_setup_complete.emit(setup)

# Core participants - Accept both Resources and Dictionaries for testing flexibility
@export var crew: Array = []  # Character resources or dictionaries
@export var enemies: Array = []  # Enemy resources or dictionaries
@export var mission: Variant = null  # Mission resource or dictionary

# Pre-battle roll results
@export var deployment_condition: String = "standard"
@export var deployment_condition_effect: String = ""
@export var notable_sights: Array[String] = []
@export var notable_sight_effects: Array[String] = []

# Initiative
@export var initiative_seized: bool = false
@export var initiative_roll: int = 0
@export var initiative_savvy_bonus: int = 0

# Terrain configuration
@export var terrain_pieces: Array[Dictionary] = []
@export var terrain_layout_type: int = 0  # 0=OPEN, 1=DENSE, 2=ASYMMETRIC, 3=CORRIDOR, 4=SCATTERED

# Battle context
@export var battle_type: int = 0  # GlobalEnums.BattleType
@export var difficulty: int = 1  # 1-5 difficulty level
@export var is_rival_battle: bool = false
@export var rival_id: String = ""
@export var is_patron_mission: bool = false
@export var patron_id: String = ""

# Deployment zones
@export var crew_deployment_zone: Dictionary = {}  # {min_x, max_x, min_y, max_y}
@export var enemy_deployment_zone: Dictionary = {}

# Metadata
@export var setup_timestamp: float = 0.0
@export var setup_id: String = ""

func _init() -> void:
	setup_id = "setup_" + str(randi()) + "_" + str(Time.get_ticks_msec())
	setup_timestamp = Time.get_ticks_msec() / 1000.0

## Initialize with core battle participants
func initialize(p_crew: Array, p_enemies: Array, p_mission: Variant) -> bool:
	if p_crew.is_empty():
		push_error("BattleSetupData: Crew cannot be empty")
		return false

	crew.clear()
	for c in p_crew:
		if c is Resource or c is Dictionary:
			crew.append(c)

	enemies.clear()
	for e in p_enemies:
		if e is Resource or e is Dictionary:
			enemies.append(e)

	mission = p_mission

	# Extract mission context
	if mission:
		battle_type = _safe_get(mission, "battle_type", 0)
		difficulty = _safe_get(mission, "difficulty", 1)
		is_rival_battle = _safe_get(mission, "is_rival_battle", false)
		rival_id = _safe_get(mission, "rival_id", "")
		is_patron_mission = _safe_get(mission, "is_patron_mission", false)
		patron_id = _safe_get(mission, "patron_id", "")

	return true

## Set initiative results from pre-battle phase
func set_initiative_results(seized: bool, roll: int, savvy_bonus: int) -> void:
	initiative_seized = seized
	initiative_roll = roll
	initiative_savvy_bonus = savvy_bonus

## Set deployment condition from D100 roll
func set_deployment_condition(condition: String, effect: String) -> void:
	deployment_condition = condition
	deployment_condition_effect = effect

## Add notable sight from D100 roll
func add_notable_sight(sight: String, effect: String) -> void:
	notable_sights.append(sight)
	notable_sight_effects.append(effect)

## Add terrain piece
func add_terrain_piece(terrain: Dictionary) -> void:
	# Expected: {type, position, effects, confirmed}
	terrain_pieces.append(terrain)

## Get crew count
func get_crew_count() -> int:
	return crew.size()

## Get enemy count
func get_enemy_count() -> int:
	var total := 0
	for enemy in enemies:
		var count: int = _safe_get(enemy, "count", 1)
		total += count
	return total

## Validate setup data before battle
func validate() -> Array[String]:
	var errors: Array[String] = []

	if crew.is_empty():
		errors.append("No crew members selected")

	if enemies.is_empty():
		errors.append("No enemies generated")

	if initiative_roll == 0:
		errors.append("Initiative not rolled")

	return errors

## Check if setup is valid
func is_valid() -> bool:
	return validate().is_empty()

## Get highest crew savvy (for initiative calculations)
func get_highest_crew_savvy() -> int:
	var max_savvy := 0
	for crew_member in crew:
		var savvy: int = _safe_get(crew_member, "savvy", 0)
		if savvy == 0:
			savvy = _safe_get(crew_member, "stats", {}).get("savvy", 0)
		max_savvy = maxi(max_savvy, savvy)
	return max_savvy

## Export to dictionary for serialization
func to_dictionary() -> Dictionary:
	return {
		"setup_id": setup_id,
		"setup_timestamp": setup_timestamp,
		"crew_count": crew.size(),
		"enemy_count": get_enemy_count(),
		"battle_type": battle_type,
		"difficulty": difficulty,
		"initiative_seized": initiative_seized,
		"initiative_roll": initiative_roll,
		"initiative_savvy_bonus": initiative_savvy_bonus,
		"deployment_condition": deployment_condition,
		"deployment_condition_effect": deployment_condition_effect,
		"notable_sights": notable_sights,
		"terrain_pieces_count": terrain_pieces.size(),
		"terrain_layout_type": terrain_layout_type,
		"is_rival_battle": is_rival_battle,
		"is_patron_mission": is_patron_mission
	}

## Safe property access helper
func _safe_get(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value

	if obj is Resource and property in obj:
		var value = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)

	return default_value
