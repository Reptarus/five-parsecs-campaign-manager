class_name InfestationSystem
extends Node

## InfestationSystem
##
## Manages colony infestation levels and environmental corruption for Bug Hunt DLC.
## Tracks how deeply bugs have infested the colony and generates appropriate hazards.
##
## Usage:
##   InfestationSystem.set_infestation_level(3)
##   var hazards = InfestationSystem.generate_environmental_hazards()
##   InfestationSystem.process_hive_expansion()

signal infestation_changed(old_level: int, new_level: int)
signal hazard_spawned(hazard: Dictionary)
signal hive_expansion(new_hive_locations: Array)
signal colony_overrun()

## Infestation levels (0-5)
enum InfestationLevel {
	CLEAR = 0,        # No infestation
	MINOR = 1,        # Early stage
	MODERATE = 2,     # Spreading
	SEVERE = 3,       # Heavy corruption
	CRITICAL = 4,     # Nearly overrun
	OVERRUN = 5       # Colony lost
}

## Current infestation level
var infestation_level: InfestationLevel = InfestationLevel.MINOR

## Active environmental hazards
var active_hazards: Array = []

## Hive chamber locations
var hive_chambers: Array = []

## Campaign turn counter (for hive expansion)
var turns_since_last_expansion: int = 0

## Content filter
var content_filter: ContentFilter = null

func _ready() -> void:
	content_filter = ContentFilter.new()

## Set infestation level
func set_infestation_level(level: int) -> void:
	var old_level := infestation_level
	infestation_level = clampi(level, InfestationLevel.CLEAR, InfestationLevel.OVERRUN) as InfestationLevel

	if infestation_level != old_level:
		print("InfestationSystem: Infestation level: %s → %s" % [
			InfestationLevel.keys()[old_level],
			InfestationLevel.keys()[infestation_level]
		])

		infestation_changed.emit(old_level, infestation_level)

		# Check for colony overrun
		if infestation_level == InfestationLevel.OVERRUN:
			_trigger_colony_overrun()

## Increase infestation level
func increase_infestation(amount: int = 1) -> void:
	set_infestation_level(infestation_level + amount)

## Decrease infestation level (from successful cleansing)
func decrease_infestation(amount: int = 1) -> void:
	set_infestation_level(infestation_level - amount)

## Generate environmental hazards based on infestation level
func generate_environmental_hazards() -> Array:
	var hazards := []
	var hazard_count := _get_hazard_count()

	for i in range(hazard_count):
		var hazard := _roll_random_hazard()
		hazards.append(hazard)
		active_hazards.append(hazard)
		hazard_spawned.emit(hazard)

	print("InfestationSystem: Generated %d environmental hazards (level %d)" % [
		hazards.size(),
		infestation_level
	])

	return hazards

## Process hive expansion (call each campaign turn)
func process_hive_expansion() -> void:
	turns_since_last_expansion += 1

	# Hive expands every N turns based on infestation level
	var expansion_frequency := _get_expansion_frequency()

	if turns_since_last_expansion >= expansion_frequency:
		_expand_hive()
		turns_since_last_expansion = 0

## Get deployment point modifier for infestation level
func get_deployment_modifier() -> int:
	match infestation_level:
		InfestationLevel.CLEAR:
			return 0
		InfestationLevel.MINOR:
			return 1
		InfestationLevel.MODERATE:
			return 2
		InfestationLevel.SEVERE:
			return 4
		InfestationLevel.CRITICAL:
			return 6
		InfestationLevel.OVERRUN:
			return 10
		_:
			return 0

## Get environmental penalties for infestation level
func get_environmental_penalties() -> Dictionary:
	var penalties := {
		"movement_penalty": 0,      # inches of movement reduction
		"visibility_penalty": 0,    # penalty to detection rolls
		"damage_per_round": 0,      # ambient damage from environment
		"morale_penalty": 0         # panic check penalty
	}

	match infestation_level:
		InfestationLevel.CLEAR:
			pass # No penalties

		InfestationLevel.MINOR:
			penalties.morale_penalty = -1

		InfestationLevel.MODERATE:
			penalties.movement_penalty = 1
			penalties.morale_penalty = -1

		InfestationLevel.SEVERE:
			penalties.movement_penalty = 1
			penalties.visibility_penalty = -1
			penalties.morale_penalty = -2

		InfestationLevel.CRITICAL:
			penalties.movement_penalty = 2
			penalties.visibility_penalty = -2
			penalties.damage_per_round = 1
			penalties.morale_penalty = -2

		InfestationLevel.OVERRUN:
			penalties.movement_penalty = 2
			penalties.visibility_penalty = -2
			penalties.damage_per_round = 2
			penalties.morale_penalty = -3

	return penalties

## Check if location has hive chamber
func has_hive_chamber(location: Vector2) -> bool:
	for chamber in hive_chambers:
		var chamber_pos: Vector2 = chamber.get("position", Vector2.ZERO)
		if location.distance_to(chamber_pos) < chamber.get("radius", 4.0):
			return true
	return false

## Cleanse a hive chamber
func cleanse_hive_chamber(location: Vector2) -> bool:
	for i in range(hive_chambers.size() - 1, -1, -1):
		var chamber := hive_chambers[i]
		var chamber_pos: Vector2 = chamber.get("position", Vector2.ZERO)

		if location.distance_to(chamber_pos) < chamber.get("radius", 4.0):
			hive_chambers.remove_at(i)
			print("InfestationSystem: Hive chamber cleansed at %s" % location)

			# Decrease infestation when hive is cleansed
			decrease_infestation(1)
			return true

	return false

## Get infestation status report
func get_status() -> Dictionary:
	return {
		"level": infestation_level,
		"level_name": InfestationLevel.keys()[infestation_level],
		"deployment_modifier": get_deployment_modifier(),
		"active_hazards": active_hazards.size(),
		"hive_chambers": hive_chambers.size(),
		"penalties": get_environmental_penalties(),
		"turns_until_expansion": _get_expansion_frequency() - turns_since_last_expansion
	}

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _get_hazard_count() -> int:
	# Number of hazards based on infestation level
	match infestation_level:
		InfestationLevel.CLEAR:
			return 0
		InfestationLevel.MINOR:
			return 1
		InfestationLevel.MODERATE:
			return 2
		InfestationLevel.SEVERE:
			return 3
		InfestationLevel.CRITICAL:
			return 4
		InfestationLevel.OVERRUN:
			return 6
		_:
			return 0

func _roll_random_hazard() -> Dictionary:
	var hazard_types := [
		{
			"name": "Alien Resin",
			"type": "difficult_terrain",
			"description": "Thick alien secretions cover the floor",
			"effect": "Movement reduced by 2\" when crossing"
		},
		{
			"name": "Acid Pool",
			"type": "damage_zone",
			"description": "Corrosive acid puddle",
			"effect": "1D3 damage per round if in contact, ignores armor"
		},
		{
			"name": "Fire",
			"type": "damage_zone",
			"description": "Spreading flames",
			"effect": "2\" radius, 1D6 damage per round, spreads on 5+"
		},
		{
			"name": "Explosive Canister",
			"type": "interactive",
			"description": "Damaged fuel canister",
			"effect": "If hit or shot, explodes for 2D6 damage in 3\" radius"
		},
		{
			"name": "Damaged Bulkhead",
			"type": "structural",
			"description": "Weakened wall section",
			"effect": "May collapse if damaged (6\" radius, 1D6 damage)"
		},
		{
			"name": "Failing Life Support",
			"type": "atmospheric",
			"description": "Toxic atmosphere leak",
			"effect": "All in area pass Toughness check each round or take 1 damage"
		},
		{
			"name": "Egg Chamber",
			"type": "spawn_point",
			"description": "Cluster of alien eggs",
			"effect": "1D3 Worker Bugs spawn if disturbed"
		},
		{
			"name": "Ventilation Shaft",
			"type": "terrain",
			"description": "Open vent with alien movement",
			"effect": "Bugs may emerge from shaft (ambush point)"
		}
	]

	var hazard := hazard_types[randi() % hazard_types.size()].duplicate(true)

	# Add random position
	hazard.position = Vector2(randf() * 24.0, randf() * 24.0)
	hazard.radius = randf_range(2.0, 4.0)

	return hazard

func _get_expansion_frequency() -> int:
	# How often (in turns) hive expands
	match infestation_level:
		InfestationLevel.CLEAR:
			return 999 # Never
		InfestationLevel.MINOR:
			return 5
		InfestationLevel.MODERATE:
			return 4
		InfestationLevel.SEVERE:
			return 3
		InfestationLevel.CRITICAL:
			return 2
		InfestationLevel.OVERRUN:
			return 1
		_:
			return 5

func _expand_hive() -> void:
	var new_chambers := []

	# Number of new chambers based on infestation
	var chamber_count := 1 if infestation_level < InfestationLevel.CRITICAL else 2

	for i in range(chamber_count):
		var chamber := {
			"position": Vector2(randf() * 24.0, randf() * 24.0),
			"radius": 4.0,
			"created_on_turn": turns_since_last_expansion
		}
		hive_chambers.append(chamber)
		new_chambers.append(chamber)

	print("InfestationSystem: Hive expanded. New chambers: %d (total: %d)" % [
		new_chambers.size(),
		hive_chambers.size()
	])

	hive_expansion.emit(new_chambers)

	# Increase infestation when hive expands
	if hive_chambers.size() >= 5 and infestation_level < InfestationLevel.CRITICAL:
		increase_infestation(1)

func _trigger_colony_overrun() -> void:
	print("InfestationSystem: COLONY OVERRUN - Mission critical!")
	colony_overrun.emit()
