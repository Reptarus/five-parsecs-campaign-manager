# ExtendedConnectionsManager.gd
class_name ExtendedConnectionsManager
extends Node

signal connection_applied(connection: Dictionary)

var game_state: GameState
var connections_data: Dictionary

func _init(_game_state: GameState):
	game_state = _game_state
	_load_connections_data()

func _load_connections_data():
	var file = FileAccess.open("res://data/expanded_connections.json", FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		connections_data = json.data
	else:
		push_error("JSON Parse Error: " + json.get_error_message())

func generate_connection() -> Dictionary:
	var connection_types = connections_data["connection_types"]
	var connection = connection_types[randi() % connection_types.size()]
	var duration = _roll_duration(connection["duration"])
	
	return {
		"type": connection["name"],
		"description": connection["description"],
		"effects": connection["effects"],
		"duration": duration
	}

func _roll_duration(duration_string: String) -> int:
	var parts = duration_string.split("+")
	var dice = parts[0].split("D")
	var base = int(dice[0])
	var sides = int(dice[1])
	var bonus = int(parts[1]) if parts.size() > 1 else 0
	
	var total = 0
	for i in range(base):
		total += randi() % sides + 1
	
	return total + bonus

func apply_connection_effect(connection: Dictionary):
	match connection["type"]:
		"Psionic":
			apply_psionic_connection_effect(connection)
		"Faction":
			apply_faction_connection_effect(connection)
		"Equipment":
			apply_equipment_connection_effect(connection)
		"Military":
			apply_military_connection_effect(connection)
		_:
			# For general connections
			for effect in connection["effects"]:
				match effect["type"]:
					"modify_stat":
						game_state.modify_character_stat(effect["stat"], effect["value"])
					"add_ability":
						game_state.add_character_ability(effect["ability"])
					"modify_resource":
						game_state.modify_resource(effect["resource"], effect["value"])
					"trigger_event":
						game_state.trigger_event(effect["event"])
	
	# Apply duration
	game_state.add_active_connection(connection)
	connection_applied.emit(connection)

func generate_psionic_connection() -> Dictionary:
	var psionic_connections = connections_data["psionic_connections"]
	var psionic_connection = psionic_connections[randi() % psionic_connections.size()]
	var duration = _roll_duration(psionic_connection["duration"])
	return {
		"type": "Psionic",
		"name": psionic_connection["name"],
		"description": psionic_connection["description"],
		"effects": psionic_connection["effects"],
		"duration": duration,
		"psionic_power": psionic_connection["psionic_power"]
	}

func apply_psionic_connection_effect(connection: Dictionary):
	var psionic_power = connection["psionic_power"]
	game_state.add_psionic_power(psionic_power)

func generate_faction_connection() -> Dictionary:
	var faction_connections = connections_data["faction_connections"]
	var connection = faction_connections[randi() % faction_connections.size()]
	var duration = _roll_duration(connection["duration"])
	
	return {
		"type": "Faction",
		"name": connection["name"],
		"description": connection["description"],
		"effects": connection["effects"],
		"duration": duration,
		"faction": connection["faction"]
	}

func apply_faction_connection_effect(connection: Dictionary):
	var faction = connection["faction"]
	game_state.modify_faction_standing(faction, connection["effects"]["standing_change"])

func generate_equipment_connection() -> Dictionary:
	var equipment_connections = connections_data["equipment_connections"]
	var connection = equipment_connections[randi() % equipment_connections.size()]
	var duration = _roll_duration(connection["duration"])
	
	return {
		"type": "Equipment",
		"name": connection["name"],
		"description": connection["description"],
		"effects": connection["effects"],
		"duration": duration,
		"equipment": connection["equipment"]
	}

func apply_equipment_connection_effect(connection: Dictionary):
	var equipment = connection["equipment"]
	if equipment is String:
		game_state.add_equipment(equipment)
	elif equipment is Dictionary:
		for item_name in equipment:
			var item_details = equipment[item_name]
			if item_details.has("quantity"):
				for i in range(item_details["quantity"]):
					game_state.add_equipment(item_name)
			else:
				game_state.add_equipment(item_name)
	
	if connection["effects"].has("training"):
		var training = connection["effects"]["training"]
		game_state.add_training(training)
	
	if connection["effects"].has("bot_upgrade"):
		var bot_upgrade = connection["effects"]["bot_upgrade"]
		game_state.apply_bot_upgrade(bot_upgrade)
	
	if connection["effects"].has("ship_part"):
		var ship_part = connection["effects"]["ship_part"]
		game_state.add_ship_part(ship_part)
	
	if connection["effects"].has("psionic_equipment"):
		var psionic_equipment = connection["effects"]["psionic_equipment"]
		game_state.add_psionic_equipment(psionic_equipment)

func generate_military_connection() -> Dictionary:
	var military_connections = connections_data["military_connections"]
	var connection = military_connections[randi() % military_connections.size()]
	var duration = _roll_duration(connection["duration"])
	
	return {
		"type": "Military",
		"name": connection["name"],
		"description": connection["description"],
		"effects": connection["effects"],
		"duration": duration,
		"military_bonus": connection["military_bonus"]
	}

func apply_military_connection_effect(connection: Dictionary):
	var military_bonus = connection["military_bonus"]
	game_state.apply_military_bonus(military_bonus)

func generate_mission_from_connection(connection: Dictionary) -> Mission:
	var mission_generator = MissionGenerator.new()
	mission_generator.init(game_state)
	var mission = mission_generator.generate_mission()
	
	# Modify mission based on connection type
	match connection["type"]:
		"Alliance":
			mission.difficulty = max(1, mission.difficulty - 1)
		"Rivalry":
			mission.difficulty += 1
		"Trade Agreement":
			mission.rewards["credits"] = int(mission.rewards["credits"] * 1.2)
		"Information Network":
			mission.rewards["reputation"] = min(5, mission.rewards["reputation"] + 1)
	
	return mission

func check_elite_rival_persistence():
	for rival in game_state.get_elite_rivals():
		if game_state.roll_dice(1, 6) >= 4:
			game_state.rival_follows_to_new_world(rival)

func generate_elite_enemy_composition(squad_size: int) -> Dictionary:
	var composition = {
		"basic": 0,
		"specialists": 0,
		"lieutenants": 0,
		"captain": 0
	}
	
	if squad_size < 4:
		squad_size = 4
	
	if squad_size == 4:
		composition.basic = 3
		composition.specialists = 1
	elif squad_size == 5:
		composition.basic = 2
		composition.specialists = 2
		composition.lieutenants = 1
	elif squad_size == 6:
		composition.basic = 3
		composition.specialists = 2
		composition.lieutenants = 1
	else:  # 7+
		composition.basic = 3
		composition.specialists = 2
		composition.lieutenants = 1
		composition.captain = 1
		composition.basic += squad_size - 7  # Add extra basic enemies for larger squads
	
	return composition

func apply_elite_enemy_upgrades(enemy: Character, enemy_type: String):
	match enemy_type:
		"specialist":
			enemy.equip_specialist_weapon()
			if enemy.combat_skill == 0:
				enemy.combat_skill = 1
		"lieutenant":
			enemy.equip_basic_weapon()
			enemy.equip_blade()
		"captain":
			enemy.equip_specialist_weapon()
			enemy.equip_blade()
			enemy.combat_skill = max(2, enemy.combat_skill)
