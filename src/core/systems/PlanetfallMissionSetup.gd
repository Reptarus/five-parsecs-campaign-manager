class_name PlanetfallMissionSetup
extends RefCounted

## Mission briefing resolver — loads enriched mission_types.json and provides
## full briefing data, force limits, opposition setup, and objective resolution
## for each of the 13 Planetfall mission types.
## Also loads Slyn and Sleeper profiles for mission opposition setup.
## Source: Planetfall pp.114-133, 152-155

var _missions: Array = []
var _slyn_profile: Dictionary = {}
var _sleeper_profile: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	var mission_data: Dictionary = _load_json(
		"res://data/planetfall/mission_types.json")
	_missions = mission_data.get("missions", [])

	_slyn_profile = _load_json("res://data/planetfall/slyn_profile.json")
	_sleeper_profile = _load_json("res://data/planetfall/sleeper_profile.json")

	_loaded = not _missions.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallMissionSetup: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallMissionSetup: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## MISSION BRIEFING
## ============================================================================

func get_mission_briefing(mission_id: String) -> Dictionary:
	## Returns the full mission entry for the given ID, including all briefing
	## data (table_size, player_forces, opposition, objectives, rewards, etc.).
	for mission in _missions:
		if mission is Dictionary and mission.get("id", "") == mission_id:
			return mission.duplicate(true)
	return {}


func get_all_missions() -> Array:
	## Returns all mission entries.
	return _missions.duplicate(true)


func get_available_missions(campaign: Resource) -> Array:
	## Filter missions based on campaign state (map sectors, tactical enemies, events).
	## Returns missions that the player can currently select.
	var available: Array = []
	for mission in _missions:
		if mission is not Dictionary:
			continue
		var mid: String = mission.get("id", "")

		# Event-triggered missions need their trigger condition
		if mission.get("event_triggered", false):
			continue  # Only shown when triggered by events

		# Forced missions are always shown if their condition is met
		if mission.get("forced", false):
			continue  # Shown only when forced

		# Tactical enemy requirement
		if mission.get("requires_tactical_enemies", false):
			if campaign and "tactical_enemies" in campaign:
				var has_active: bool = false
				for te in campaign.tactical_enemies:
					if te is Dictionary and not te.get("defeated", false):
						has_active = true
						break
				if not has_active:
					continue

		available.append(mission.duplicate(true))
	return available


func get_forced_missions(campaign: Resource) -> Array:
	## Returns missions that are currently forced by campaign events.
	## (e.g., Pitched Battle from enemy attack)
	var forced: Array = []
	# Check for enemy attacks that force Pitched Battle
	if campaign and "tactical_enemies" in campaign:
		for te in campaign.tactical_enemies:
			if te is Dictionary and te.get("attacking", false):
				for mission in _missions:
					if mission is Dictionary and mission.get("id", "") == "pitched_battle":
						forced.append(mission.duplicate(true))
						break
				break
	return forced


## ============================================================================
## FORCE LIMITS
## ============================================================================

func get_force_limits(mission_id: String) -> Dictionary:
	## Returns {max_characters: int, max_grunts: int, grunt_fireteams: int}
	## for the given mission type.
	var briefing: Dictionary = get_mission_briefing(mission_id)
	var forces: Dictionary = briefing.get("player_forces", {})
	return {
		"max_characters": forces.get("max_characters", 6),
		"max_grunts": forces.get("max_grunts", 0),
		"grunt_fireteams": forces.get("grunt_fireteams", 0)
	}


## ============================================================================
## SLYN AGGRESSION CHECK
## ============================================================================

func check_slyn_aggression(mission_id: String, roll_2d6: int) -> bool:
	## Check if the Slyn attack during this mission type.
	## Returns true if Slyn are attacking.
	var briefing: Dictionary = get_mission_briefing(mission_id)
	var opposition: Dictionary = briefing.get("opposition", {})
	var aggression: Variant = opposition.get("slyn_aggression", null)
	if aggression is Dictionary:
		var range_min: int = aggression.get("slyn_range_min", 0)
		var range_max: int = aggression.get("slyn_range_max", 0)
		return roll_2d6 >= range_min and roll_2d6 <= range_max
	return false


func is_slyn_immune(mission_id: String) -> bool:
	## Returns true if Slyn will not interfere with this mission.
	var briefing: Dictionary = get_mission_briefing(mission_id)
	var opposition: Dictionary = briefing.get("opposition", {})
	return opposition.get("slyn_immune", false)


## ============================================================================
## PROFILES
## ============================================================================

func get_slyn_profile() -> Dictionary:
	return _slyn_profile.duplicate(true)


func get_slyn_combat_profile() -> Dictionary:
	return _slyn_profile.get("profile", {}).duplicate(true)


func get_slyn_encounter_size(roll_d6: int) -> int:
	var sizes: Dictionary = _slyn_profile.get("encounter_sizes", {})
	var entries: Array = sizes.get("entries", [])
	for entry in entries:
		if entry is Dictionary:
			if roll_d6 >= entry.get("min", 0) and roll_d6 <= entry.get("max", 0):
				return entry.get("count", 6)
	return 6


func get_sleeper_profile() -> Dictionary:
	return _sleeper_profile.duplicate(true)


func get_sleeper_combat_profile() -> Dictionary:
	return _sleeper_profile.get("profile", {}).duplicate(true)


func roll_sleeper_weapon() -> Dictionary:
	## Roll D6 for Sleeper weapon. Returns weapon profile.
	var roll: int = roll_d6()
	var weapons: Dictionary = _sleeper_profile.get("weapons", {})
	var entries: Array = weapons.get("entries", [])
	for entry in entries:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {"id": "beam_weapon", "name": "Beam weapon", "range": 12, "shots": 1, "damage": 1}


## ============================================================================
## OBJECTIVE RESOLUTION
## ============================================================================

func resolve_mission_objective(mission_id: String, roll: int) -> Dictionary:
	## For missions with objective sub-tables (e.g., Investigation D6 table,
	## Skirmish D6 objective table), resolve a roll.
	var briefing: Dictionary = get_mission_briefing(mission_id)
	var objectives: Dictionary = briefing.get("objectives", {})

	# Check for investigation_table
	var inv_table: Dictionary = objectives.get("investigation_table", {})
	if not inv_table.is_empty():
		return _lookup_entries(inv_table.get("entries", []), roll)

	# Check for skirmish_objective_table
	var skirmish_table: Dictionary = objectives.get("skirmish_objective_table", {})
	if not skirmish_table.is_empty():
		return _lookup_entries(skirmish_table.get("entries", []), roll)

	return {}


## ============================================================================
## DICE HELPERS
## ============================================================================

func roll_d6() -> int:
	return randi_range(1, 6)


func roll_2d6() -> int:
	return randi_range(1, 6) + randi_range(1, 6)


## ============================================================================
## PRIVATE
## ============================================================================

func _lookup_entries(entries: Array, roll: int) -> Dictionary:
	for entry in entries:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func is_loaded() -> bool:
	return _loaded
