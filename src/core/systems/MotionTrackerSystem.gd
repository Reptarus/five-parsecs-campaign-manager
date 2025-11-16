class_name MotionTrackerSystem
extends Node

## MotionTrackerSystem
##
## Manages motion tracker detection mechanics for Bug Hunt DLC.
## Detects bug movement and provides tactical information via "blips".
##
## Usage:
##   MotionTrackerSystem.initialize_for_battle(battle_data)
##   MotionTrackerSystem.scan(operator, 12) # 12" range
##   var blips = MotionTrackerSystem.get_blips()
##   MotionTrackerSystem.process_round()

signal blip_detected(blip: Dictionary)
signal blip_identified(blip: Dictionary, enemy: Dictionary)
signal tracker_malfunction(reason: String)
signal audio_ping(intensity: int) # For audio cues

## Blip data structure
## Represents unidentified or partially identified contact
class Blip:
	var id: String
	var position: Vector2
	var distance: float
	var direction: String
	var last_seen_round: int
	var identified: bool = false
	var enemy_ref: Dictionary = {}

	func _init(pos: Vector2, dist: float, dir: String, round: int):
		id = "blip_%d" % Time.get_ticks_msec()
		position = pos
		distance = dist
		direction = dir
		last_seen_round = round

## Active blips
var active_blips: Array[Blip] = []

## Current battle data reference
var battle_data: Dictionary = {}

## Current round number
var current_round: int = 0

## Motion tracker operators (soldiers with tracker equipped)
var tracker_operators: Array = []

## Battery drain (reduces range over time)
var battery_level: int = 100

## Tracker interference (environmental)
var interference_level: int = 0

## Content filter
var content_filter: ContentFilter = null

func _ready() -> void:
	content_filter = ContentFilter.new()

## Initialize motion tracker system for battle
func initialize_for_battle(battle_data_ref: Dictionary) -> void:
	battle_data = battle_data_ref
	current_round = 0
	active_blips.clear()
	tracker_operators.clear()
	battery_level = 100
	interference_level = 0

	print("MotionTrackerSystem: Initialized for battle")

## Register soldier as tracker operator
func register_tracker_operator(soldier: Dictionary) -> void:
	if not soldier in tracker_operators:
		tracker_operators.append(soldier)
		print("MotionTrackerSystem: %s equipped motion tracker" % soldier.get("name", "Unknown"))

## Perform motion tracker scan
func scan(operator: Dictionary, max_range: float = 12.0) -> Array:
	if not operator in tracker_operators:
		push_warning("MotionTrackerSystem: Operator doesn't have motion tracker")
		return []

	# Calculate effective range (reduced by battery drain and interference)
	var effective_range := _calculate_effective_range(max_range)

	# Get operator position
	var operator_pos := _get_position(operator)

	# Scan for bugs
	var new_blips: Array = []
	var enemies := battle_data.get("enemies", [])

	for enemy in enemies:
		# Skip dead enemies
		if enemy.get("is_dead", false):
			continue

		var enemy_pos := _get_position(enemy)
		var distance := operator_pos.distance_to(enemy_pos)

		# Check if within effective range
		if distance <= effective_range:
			# Check if bug is detectable (some bugs have stealth)
			if _is_detectable(enemy, distance):
				var blip := _create_or_update_blip(enemy, enemy_pos, distance, operator_pos)
				new_blips.append(blip)

				# Emit signal
				blip_detected.emit(blip)

	# Update battery
	_drain_battery()

	# Generate audio pings
	_generate_audio_cues(new_blips, operator_pos)

	print("MotionTrackerSystem: Scan complete. %d blips detected (range: %.1f\")" % [new_blips.size(), effective_range])

	return new_blips

## Process motion tracker at start of each round
func process_round() -> void:
	current_round += 1

	# Age out old blips
	var blips_to_remove := []
	for blip in active_blips:
		if current_round - blip.last_seen_round > 2:
			blips_to_remove.append(blip)

	for blip in blips_to_remove:
		active_blips.erase(blip)

	# Environmental interference check
	_check_interference()

	print("MotionTrackerSystem: Round %d processed. Active blips: %d" % [current_round, active_blips.size()])

## Get all active blips
func get_blips() -> Array[Blip]:
	return active_blips.duplicate()

## Get blips sorted by distance (nearest first)
func get_blips_by_distance() -> Array[Blip]:
	var sorted_blips := active_blips.duplicate()
	sorted_blips.sort_custom(func(a, b): return a.distance < b.distance)
	return sorted_blips

## Get closest blip
func get_closest_blip() -> Blip:
	if active_blips.is_empty():
		return null

	var sorted := get_blips_by_distance()
	return sorted[0]

## Identify blip (requires direct line of sight)
func identify_blip(blip: Blip, observer: Dictionary) -> bool:
	if blip.identified:
		return true

	# Check line of sight
	var observer_pos := _get_position(observer)
	if not _has_line_of_sight(observer_pos, blip.position):
		return false

	# Identify the blip
	blip.identified = true

	print("MotionTrackerSystem: Blip identified: %s at %.1f\"" % [
		blip.enemy_ref.get("name", "Unknown"),
		blip.distance
	])

	blip_identified.emit(blip, blip.enemy_ref)
	return true

## Get tracker status
func get_tracker_status() -> Dictionary:
	return {
		"battery_level": battery_level,
		"effective_range": _calculate_effective_range(12.0),
		"interference": interference_level,
		"active_blips": active_blips.size(),
		"operators": tracker_operators.size()
	}

## Reset tracker battery (field maintenance)
func replace_battery() -> void:
	battery_level = 100
	print("MotionTrackerSystem: Battery replaced (100%)")

## Get warning level based on closest blips
func get_warning_level() -> int:
	# 0 = No contacts
	# 1 = Distant contacts (12"+)
	# 2 = Medium range (6-12")
	# 3 = Close range (0-6")
	# 4 = CRITICAL (<3")

	if active_blips.is_empty():
		return 0

	var closest := get_closest_blip()
	if closest.distance < 3.0:
		return 4
	elif closest.distance < 6.0:
		return 3
	elif closest.distance < 12.0:
		return 2
	else:
		return 1

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _calculate_effective_range(base_range: float) -> float:
	var range := base_range

	# Battery drain reduces range
	var battery_penalty := (100 - battery_level) / 100.0 * 4.0 # Max -4" at 0% battery
	range -= battery_penalty

	# Interference reduces range
	range -= interference_level * 2.0

	return max(range, 2.0) # Minimum 2" range

func _is_detectable(enemy: Dictionary, distance: float) -> bool:
	# Check for stealth abilities
	var abilities: Array = enemy.get("special_abilities", [])

	for ability in abilities:
		if ability is Dictionary:
			var ability_name: String = ability.get("name", "")

			# Hunter Bugs have stealth until close or attacking
			if ability_name == "Stealth":
				# Not detectable until within 6" or has attacked
				if distance > 6.0 and not enemy.get("has_attacked", false):
					return false

	return true

func _create_or_update_blip(enemy: Dictionary, enemy_pos: Vector2, distance: float, observer_pos: Vector2) -> Blip:
	# Check if blip already exists for this enemy
	var enemy_id := _get_enemy_id(enemy)

	for blip in active_blips:
		if blip.enemy_ref.get("id", "") == enemy_id:
			# Update existing blip
			blip.position = enemy_pos
			blip.distance = distance
			blip.direction = _calculate_direction(observer_pos, enemy_pos)
			blip.last_seen_round = current_round
			return blip

	# Create new blip
	var direction := _calculate_direction(observer_pos, enemy_pos)
	var new_blip := Blip.new(enemy_pos, distance, direction, current_round)
	new_blip.enemy_ref = enemy

	active_blips.append(new_blip)
	return new_blip

func _calculate_direction(from: Vector2, to: Vector2) -> String:
	var angle := rad_to_deg(from.angle_to_point(to))

	# Normalize to 0-360
	if angle < 0:
		angle += 360

	# Convert to compass direction
	if angle >= 337.5 or angle < 22.5:
		return "N"
	elif angle >= 22.5 and angle < 67.5:
		return "NE"
	elif angle >= 67.5 and angle < 112.5:
		return "E"
	elif angle >= 112.5 and angle < 157.5:
		return "SE"
	elif angle >= 157.5 and angle < 202.5:
		return "S"
	elif angle >= 202.5 and angle < 247.5:
		return "SW"
	elif angle >= 247.5 and angle < 292.5:
		return "W"
	else:
		return "NW"

func _drain_battery() -> void:
	# Each scan drains battery
	battery_level = max(0, battery_level - 2)

	if battery_level <= 20:
		print("MotionTrackerSystem: WARNING - Low battery (%d%%)" % battery_level)

	if battery_level <= 0:
		print("MotionTrackerSystem: CRITICAL - Battery depleted!")
		tracker_malfunction.emit("Battery depleted")

func _check_interference() -> void:
	# Environmental interference (random events)
	var roll := randi() % 20 + 1

	if roll == 1:
		interference_level = min(interference_level + 1, 3)
		print("MotionTrackerSystem: Interference increased to level %d" % interference_level)
		tracker_malfunction.emit("Interference")
	elif roll == 20 and interference_level > 0:
		interference_level = max(interference_level - 1, 0)
		print("MotionTrackerSystem: Interference decreased to level %d" % interference_level)

func _generate_audio_cues(blips: Array, observer_pos: Vector2) -> void:
	if blips.is_empty():
		return

	# Calculate ping intensity based on closest blip
	var closest_distance := 999.0
	for blip in blips:
		if blip.distance < closest_distance:
			closest_distance = blip.distance

	# Convert distance to intensity (0-5)
	var intensity := 0
	if closest_distance < 3.0:
		intensity = 5 # VERY CLOSE - rapid beeping
	elif closest_distance < 6.0:
		intensity = 4
	elif closest_distance < 9.0:
		intensity = 3
	elif closest_distance < 12.0:
		intensity = 2
	else:
		intensity = 1

	audio_ping.emit(intensity)

func _get_position(entity: Dictionary) -> Vector2:
	# Get position from entity
	if entity.has("position"):
		var pos = entity.position
		if pos is Vector2:
			return pos

	# Fallback to random position (for testing)
	return Vector2(randf() * 24.0, randf() * 24.0)

func _has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	# Simplified LOS check
	# Full implementation would check terrain/obstacles
	return true

func _get_enemy_id(enemy: Dictionary) -> String:
	return enemy.get("id", "enemy_unknown")
