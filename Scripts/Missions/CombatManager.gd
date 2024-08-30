class_name CombatManager
extends Node

signal combat_started
signal combat_ended(player_victory: bool)
signal turn_started(character)
signal turn_ended(character)

var game_state: GameState
var current_battle: Battle
var turn_order: Array[Character] = []
var current_turn_index: int = 0
var ai_controller: AIController

const GRID_SIZE: Vector2 = Vector2(24, 24)  # 24" x 24" battlefield
var battlefield: Array = []

enum CoverType { NONE, PARTIAL, FULL }
enum BattlePhase { REACTION_ROLL, QUICK_ACTIONS, ENEMY_ACTIONS, SLOW_ACTIONS, END_PHASE }

var current_phase: BattlePhase = BattlePhase.REACTION_ROLL

func _init(_game_state: GameState):
	game_state = _game_state
	ai_controller = AIController.new(self, game_state)
	initialize_battlefield()

func initialize_battlefield() -> void:
	battlefield = []
	for x in range(GRID_SIZE.x):
		battlefield.append([])
		for y in range(GRID_SIZE.y):
			battlefield[x].append(null)

func start_combat(player_characters: Array[Character], enemies: Array[Character]) -> void:
	current_battle = Battle.new(player_characters, enemies)
	place_characters_on_battlefield()
	seize_initiative()
	emit_signal("combat_started")
	start_battle_round()

func place_characters_on_battlefield() -> void:
	# Place player characters
	for character in current_battle.player_characters:
		var position = find_empty_position(0, GRID_SIZE.x / 2 - 1)
		character.position = position
		battlefield[position.x][position.y] = character

	# Place enemies
	for enemy in current_battle.enemies:
		var position = find_empty_position(GRID_SIZE.x / 2, GRID_SIZE.x - 1)
		enemy.position = position
		battlefield[position.x][position.y] = enemy

func find_empty_position(start_x: int, end_x: int) -> Vector2:
	while true:
		var x = randi() % (end_x - start_x + 1) + start_x
		var y = randi() % int(GRID_SIZE.y)
		if battlefield[x][y] == null:
			return Vector2(x, y)

func seize_initiative() -> void:
	var highest_savvy = 0
	for character in current_battle.player_characters:
		highest_savvy = max(highest_savvy, character.savvy)
	
	var roll = randi() % 6 + randi() % 6 + 2 + highest_savvy  # 2d6 + highest savvy
	
	# Apply modifiers
	if current_battle.player_characters.size() < current_battle.enemies.size():
		roll += 1
	
	# TODO: Add other modifiers based on enemy types and difficulty modes
	
	if roll >= 10:
		for character in current_battle.player_characters:
			# Allow move or fire
			# TODO: Implement move_character and fire_weapon functions
			pass

func start_battle_round() -> void:
	current_phase = BattlePhase.REACTION_ROLL
	perform_reaction_roll()

func perform_reaction_roll() -> void:
	var reaction_rolls = []
	for character in current_battle.player_characters:
		reaction_rolls.append(randi() % 6 + 1)
	
	turn_order = []
	
	# Assign quick actions
	for i in range(reaction_rolls.size()):
		if reaction_rolls[i] <= current_battle.player_characters[i].reactions:
			turn_order.append(current_battle.player_characters[i])
	
	# Add enemies
	turn_order.append_array(current_battle.enemies)
	
	# Add remaining player characters
	for i in range(reaction_rolls.size()):
		if reaction_rolls[i] > current_battle.player_characters[i].reactions:
			turn_order.append(current_battle.player_characters[i])
	
	current_phase = BattlePhase.QUICK_ACTIONS
	current_turn_index = 0
	start_next_turn()

func start_next_turn() -> void:
	if current_turn_index >= turn_order.size():
		end_battle_round()
		return

	var current_character = turn_order[current_turn_index]
	emit_signal("turn_started", current_character)

	if current_character in current_battle.enemies:
		if current_phase == BattlePhase.ENEMY_ACTIONS:
			ai_controller.perform_ai_turn(current_character)
		else:
			end_turn()
	else:
		# Wait for player input
		pass

func end_turn() -> void:
	var current_character = turn_order[current_turn_index]
	emit_signal("turn_ended", current_character)
	current_turn_index += 1
	
	if current_turn_index >= turn_order.size():
		if current_phase == BattlePhase.QUICK_ACTIONS:
			current_phase = BattlePhase.ENEMY_ACTIONS
			current_turn_index = 0
		elif current_phase == BattlePhase.ENEMY_ACTIONS:
			current_phase = BattlePhase.SLOW_ACTIONS
			current_turn_index = 0
	
	start_next_turn()

func end_battle_round() -> void:
	current_phase = BattlePhase.END_PHASE
	check_enemy_morale()
	if not check_battle_end():
		start_battle_round()

func check_enemy_morale() -> void:
	var casualties = current_battle.get_enemy_casualties_this_round()
	if casualties > 0:
		var panic_rolls = []
		for i in range(casualties):
			panic_rolls.append(randi() % 6 + 1)
		
		var bailed_enemies = 0
		for roll in panic_rolls:
			if roll <= current_battle.enemy_panic_range:
				bailed_enemies += 1
		
		for i in range(bailed_enemies):
			if current_battle.enemies.size() > 0:
				var enemy_to_remove = current_battle.enemies.pop_back()
				var pos = enemy_to_remove.position
				battlefield[pos.x][pos.y] = null

func check_battle_end() -> bool:
	if current_battle.are_all_enemies_defeated():
		emit_signal("combat_ended", true)  # Player victory
		return true
	elif current_battle.are_all_players_defeated():
		emit_signal("combat_ended", false)  # Player defeat
		return true
	return false

func perform_action(character: Character, action: String, target: Character = null, target_position: Vector2 = Vector2.ZERO) -> void:
	match action:
		"move":
			move_character(character, target_position)
		"attack":
			attack_character(character, target)
		"use_item":
			use_item(character)
		"snap_fire":
			snap_fire(character, target)

func move_character(character: Character, target_position: Vector2) -> void:
	var start_position = character.position
	var path = find_path(start_position, target_position)

	if path.size() <= character.speed:
		battlefield[start_position.x][start_position.y] = null
		character.position = target_position
		battlefield[target_position.x][target_position.y] = character
	else:
		var new_position = path[character.speed]
		battlefield[start_position.x][start_position.y] = null
		character.position = new_position
		battlefield[new_position.x][new_position.y] = character

func find_path(start: Vector2, end: Vector2) -> Array:
	# Implement A* pathfinding algorithm here
	# For simplicity, we'll use a straight line for now
	var path = []
	var current = start
	while current != end:
		var diff = end - current
		var step = diff.normalized()
		current += step
		path.append(current)
	return path

func attack_character(attacker: Character, target: Character) -> void:
	var weapon = attacker.get_equipped_weapon()
	var distance = attacker.position.distance_to(target.position)

	if distance > weapon.range:
		print("Target is out of range")
		return

	var to_hit_roll = randi() % 6 + 1 + attacker.combat_skill
	var cover = get_cover_type(target)
	var hit_threshold = 4  # Base hit threshold

	match cover:
		CoverType.PARTIAL:
			hit_threshold = 5
		CoverType.FULL:
			hit_threshold = 6

	if to_hit_roll >= hit_threshold:
		var damage = weapon.damage + (randi() % 6 + 1)
		if damage >= target.toughness:
			target.take_damage(damage)
		else:
			target.apply_stun()

func get_cover_type(character: Character) -> CoverType:
	var pos = character.position
	var adjacent_positions = [
		Vector2(pos.x - 1, pos.y),
		Vector2(pos.x + 1, pos.y),
		Vector2(pos.x, pos.y - 1),
		Vector2(pos.x, pos.y + 1)
	]

	var cover_count = 0
	for adj_pos in adjacent_positions:
		if is_valid_position(adj_pos) and battlefield[adj_pos.x][adj_pos.y] is TerrainPiece:
			cover_count += 1

	if cover_count >= 2:
		return CoverType.FULL
	elif cover_count == 1:
		return CoverType.PARTIAL
	else:
		return CoverType.NONE

func is_valid_position(pos: Vector2) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE.x and pos.y >= 0 and pos.y < GRID_SIZE.y

func use_item(character: Character) -> void:
	# Implement item usage logic
	pass

func snap_fire(character: Character, target: Character) -> void:
	# Implement snap fire logic
	pass

class Battle:
	var player_characters: Array[Character]
	var enemies: Array[Character]
	var enemy_panic_range: int = 2  # Default panic range, adjust as needed

	func _init(_player_characters: Array[Character], _enemies: Array[Character]):
		player_characters = _player_characters
		enemies = _enemies

	func are_all_enemies_defeated() -> bool:
		return enemies.is_empty()

	func are_all_players_defeated() -> bool:
		return player_characters.all(func(player): return player.is_defeated())

	func get_enemy_casualties_this_round() -> int:
		# Implement logic to track casualties per round
		return 0  # Placeholder
