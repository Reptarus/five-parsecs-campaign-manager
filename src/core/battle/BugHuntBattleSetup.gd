class_name BugHuntBattleSetup
extends RefCounted

## Generates Bug Hunt battle parameters from mission context.
## Creates contact markers, tactical locations, spawn points,
## and battle context for TacticalBattleUI.

const TACTICAL_LOCATIONS_PATH := "res://data/bug_hunt/bug_hunt_tactical_locations.json"
const SPAWN_RULES_PATH := "res://data/bug_hunt/bug_hunt_spawn_rules.json"
const WEAPONS_PATH := "res://data/bug_hunt/bug_hunt_weapons.json"
const ARMOR_PATH := "res://data/bug_hunt/bug_hunt_armor.json"

var _tactical_data: Dictionary = {}
var _spawn_data: Dictionary = {}
var _weapons_data: Dictionary = {}
var _armor_data: Dictionary = {}


func _init() -> void:
	_tactical_data = _load_json(TACTICAL_LOCATIONS_PATH)
	_spawn_data = _load_json(SPAWN_RULES_PATH)
	_weapons_data = _load_json(WEAPONS_PATH)
	_armor_data = _load_json(ARMOR_PATH)


func generate_battle_context(mission_context: Dictionary, campaign: Resource = null) -> Dictionary:
	## Build a complete battle context dict for TacticalBattleUI.
	var priority: int = mission_context.get("priority", 1)
	var spawn_rating: int = mission_context.get("spawn_rating", 1)
	var contact_count: int = mission_context.get("contact_markers", 4)
	# `objectives`, PLURAL. This read was `objective`, singular -- a key the
	# producer (BugHuntMissionPanel's stamp) has never written, so the objectives
	# reached the battle as {} and the battle screen had nothing to show. The
	# documented consumer-reads-a-key-no-producer-writes shape, and `.get()`
	# returning a silent default is why nothing ever errored.
	var objectives: Array = mission_context.get("objectives", [])
	var use_signals: bool = mission_context.get("use_signals", false)

	# Generate contact marker positions
	var contact_markers: Array = _generate_contact_markers(contact_count)

	# Signals optional rule (Compendium p.208): 1D6 Signals, remaining slots are TacLocs
	var signals: Array = []
	var tac_loc_count: int = 6
	if use_signals:
		# Prefer the STAMPED count. The panel rolls it when the player turns the
		# rule on, so the initial number is on the mission before the battle --
		# which is what p.201's "if the mission had 4 or more signals initially"
		# has to be measured against afterwards. Rolling a second, different 1D6
		# here would mean the briefing and the debrief disagreed.
		var signal_count: int = int(mission_context.get("signals_total", 0))
		if signal_count <= 0:
			signal_count = _roll_d6("Bug Hunt Signals: count")  # 1D6
		tac_loc_count = maxi(6 - signal_count, 0)
		signals = _generate_signals(signal_count)

	# Generate tactical locations (Compendium p.192: total = 6 minus signals)
	var tactical_locations: Array = _generate_tactical_locations_count(tac_loc_count)

	# Generate spawn points
	var spawn_points: Array = _generate_spawn_points(spawn_rating)

	return {
		"battle_mode": "bug_hunt",
		"no_morale": true,
		"priority": priority,
		"spawn_rating": spawn_rating,
		"objectives": objectives,
		"contact_markers": contact_markers,
		"tactical_locations": tactical_locations,
		"signals": signals,
		"spawn_points": spawn_points,
		# ⚠ These three keys used to be contact_table_rules / aggression_dice / chance_dice,
		# and the last two read `aggression` and `chance`, keys the data file does not have
		# (it nests both dice under `movement`), so they were always {}. Nothing read any
		# of the three. The battle now reads the whole blocks through BugHuntBattleGuide.
		"contact_rules": _spawn_data.get("contact_markers", {}),
		"spawn_point_rules": _spawn_data.get("spawn_points", {}),
		# The difficulty row in force for this mission (p.186, with the p.194 Numbers
		# adjustment). Stamped by BugHuntMissionPanel, so the battle and the briefing
		# read the same row.
		"difficulty": str(mission_context.get("difficulty", "mess_me_up")),
		"difficulty_rules": mission_context.get("difficulty_rules", {}),
		# p.187 loadout and pp.188-189 support, as BugHuntMissionPanel decided them.
		# ⚠ This return is a FIXED key literal, so a key the panel stamps and this
		# list does not name never reaches the battle (MG-8, MG-9).
		"loadout": (mission_context.get("loadout", {}) as Dictionary).duplicate(true),
		"support": (mission_context.get("support", []) as Array).duplicate(true),
		"weapons_table": _weapons_data.get("weapons", []),
		"armor_table": _armor_data.get("armor", [])
	}

## Look up weapon stats by ID from bug_hunt_weapons.json
func get_weapon(weapon_id: String) -> Dictionary:
	for weapon in _weapons_data.get("weapons", []):
		if weapon.get("id", "") == weapon_id:
			return weapon
	return {}

## Look up armor stats by ID from bug_hunt_armor.json
func get_armor(armor_id: String) -> Dictionary:
	for armor in _armor_data.get("armor", []):
		if armor.get("id", "") == armor_id:
			return armor
	return {}


func _generate_contact_markers(count: int) -> Array:
	## Place contact markers in random sectors.
	var markers: Array = []
	# Bug Hunt uses a 4x4 sector grid (16 sectors)
	var available_sectors: Array = []
	for r in range(4):
		for c in range(4):
			available_sectors.append({"row": r, "col": c})

	# Shuffle and pick
	available_sectors.shuffle()
	for i in range(mini(count, available_sectors.size())):
		markers.append({
			"id": "contact_%d" % (i + 1),
			"sector": available_sectors[i],
			"revealed": false,
			"enemy_type": "",
			"enemy_count": 0
		})

	return markers


func _generate_tactical_locations() -> Array:
	## Default: 6 Tactical Locations (Compendium p.192).
	return _generate_tactical_locations_count(6)


func _generate_tactical_locations_count(count: int) -> Array:
	## Generate a specific number of tactical locations.
	var tac_locs_data: Dictionary = _tactical_data.get("tactical_locations", {})
	var location_types: Array = tac_locs_data.get("types", [])
	if location_types.is_empty():
		return []

	var locations: Array = []
	for i in range(count):
		# Roll D6 for type (Compendium p.191)
		var roll: int = _roll_d6("Bug Hunt Tactical Location: type")
		var loc: Dictionary = {}
		for lt in location_types:
			if lt is not Dictionary:
				continue
			if lt.has("d6_value") and lt.d6_value == roll:
				loc = lt
				break
			if lt.has("d6_range"):
				var r: Array = lt.d6_range
				if r.size() >= 2 and roll >= r[0] and roll <= r[1]:
					loc = lt
					break
		if loc.is_empty() and not location_types.is_empty():
			loc = location_types[randi() % location_types.size()]

		locations.append({
			"id": "tac_loc_%d" % (i + 1),
			"type": loc.get("name", "Unknown"),
			"name": loc.get("name", "Unknown"),
			"effect": loc.get("effect", ""),
			"d6_roll": roll,
			"activated": false,
			"compromised": false,
			"failures": 0,
			"sector": {"row": randi() % 4, "col": randi() % 4}
		})

	return locations


func _generate_signals(count: int) -> Array:
	## Generate Signal markers (optional rule, Compendium p.208).
	var signals_data: Dictionary = _tactical_data.get("signals", {})
	var signal_table: Array = signals_data.get("signal_table", [])

	var signals: Array = []
	for i in range(count):
		signals.append({
			"id": "signal_%d" % (i + 1),
			"investigated": false,
			"result": {},
			"sector": {"row": randi() % 4, "col": randi() % 4}
		})
	return signals


func _generate_spawn_points(spawn_rating: int) -> Array:
	## Generate spawn points based on spawn rating.
	var points: Array = []
	# The number of Spawn Points IS the Spawn Rating. bug_hunt_spawn_rules.json
	# says so in its own words -- "Mission creation dictates a Spawn Rating
	# determining how many Spawn Points will be revealed. If 0, spawn points are
	# not used." -- and declares NO base_count key, so `get("base_count", 2)` was
	# a phantom default that added two spawn points to every mission and turned
	# the book's "if 0, none" into "if 0, two".
	var total: int = maxi(spawn_rating, 0)

	# Place spawn points along map edges (Bug Hunt convention)
	for i in range(total):
		var edge: int = randi() % 4  # 0=top, 1=right, 2=bottom, 3=left
		var pos: Dictionary = {}
		match edge:
			0: pos = {"row": 0, "col": randi() % 4}
			1: pos = {"row": randi() % 4, "col": 3}
			2: pos = {"row": 3, "col": randi() % 4}
			3: pos = {"row": randi() % 4, "col": 0}

		points.append({
			"id": "spawn_%d" % (i + 1),
			"sector": pos,
			"active": true
		})

	return points


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		file.close()
		return json.data
	file.close()
	return {}


## ── Dice routing ────────────────────────────────────────────────────────────
## Book table rolls go through the DiceManager autoload so they are recorded in
## the roll history and can be forced from the QA dialog in a debug build.
##
## This is RefCounted, so it reaches the autoload through
## Engine.get_main_loop().root — a bare get_node_or_null() from a .new() object
## does not return null, it ERRORS and aborts the enclosing function.
##
## Map PLACEMENT (contact sectors, spawn edges, signal positions) is deliberately
## left on raw randi(): 5PFH's BattlefieldGenerator.gd has zero DiceManager
## references and seeds a local RNG for placement. Routing it would flood the
## forced-roll queue with entries a tester never asked to control.
func _dice_manager() -> Node:
	if Engine.get_main_loop() == null:
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DiceManager")


func _roll_d6(context: String) -> int:
	var dm: Node = _dice_manager()
	if dm:
		return int(dm.roll_d6(context))
	return randi_range(1, 6)
