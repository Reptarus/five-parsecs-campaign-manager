class_name CombatManager
extends Node

signal combat_started
signal combat_ended(player_victory: bool)
signal turn_started(character: Character)
signal turn_ended(character: Character)
signal ui_update_needed(round: int, phase: BattlePhase, current_character: Character)
signal log_action(action: String)
signal character_moved(character: Character, new_position: Vector2i)
signal enable_player_controls(character: Character)
signal update_turn_label(round: int)
signal update_current_character_label(character_name: String)
signal highlight_valid_positions(positions: Array[Vector2i])

enum CoverType { NONE, PARTIAL, FULL }
enum BattlePhase { REACTION_ROLL, QUICK_ACTIONS, ENEMY_ACTIONS, SLOW_ACTIONS, END_PHASE }

const GRID_SIZE: Vector2i = Vector2i(24, 24)  # 24" x 24" battlefield
const CELL_SIZE: Vector2i = Vector2i(32, 32)  # Size of each cell in pixels

var game_state: GameState
var current_mission: Mission
var terrain_generator: TerrainGenerator
var battlefield: Array[Array]
var turn_order: Array[Character]
var current_turn_index: int = 0
var current_round: int = 1
var current_phase: BattlePhase = BattlePhase.REACTION_ROLL
var battle_grid: GridContainer

# Initialization and Setup
func initialize(_game_state: GameState, _mission: Mission, _battle_grid: GridContainer) -> void:
	game_state = _game_state
	current_mission = _mission
	battle_grid = _battle_grid
	terrain_generator = TerrainGenerator.new()
	battlefield = terrain_generator.generate_terrain(GlobalEnums.TerrainSize.MEDIUM)
	setup_battlefield()
	setup_characters()
	place_objectives()
	start_combat()

func setup_battlefield() -> void:
	battle_grid.columns = GRID_SIZE.x
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var cell := ColorRect.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cell.color = get_terrain_color(battlefield[x][y])
			battle_grid.add_child(cell)

func setup_characters() -> void:
	var crew: Array[Character] = game_state.current_crew.members
	var enemies: Array[Character] = current_mission.get_enemies()
	
	for character in crew + enemies:
		character.position = find_valid_spawn_position(character in crew)

func place_objectives() -> void:
	# Implement objective placement logic here
	pass

# Combat Flow
func start_battle_round() -> void:
	emit_signal("log_action", "Starting Round " + str(current_round))
	perform_reaction_roll()

func perform_reaction_roll() -> void:
	turn_order.clear()
	var crew: Array[Character] = game_state.current_crew.members
	var enemies: Array[Character] = current_mission.get_enemies()
	
	for character in crew + enemies:
		var roll := roll_dice(1, 6)
		if roll <= character.reactions:
			turn_order.append(character)
	
	for character in crew + enemies:
		if not character in turn_order:
			turn_order.append(character)
	
	current_phase = BattlePhase.QUICK_ACTIONS
	current_turn_index = 0
	start_next_turn()

func start_next_turn() -> void:
	if current_turn_index >= turn_order.size():
		advance_phase()
		return

	var current_character: Character = turn_order[current_turn_index]
	emit_signal("turn_started", current_character)
	update_ui(current_round, current_phase, current_character)  # Fixed: Added current_character as the third argument
	if current_character in current_mission.get_enemies():
		perform_enemy_turn(current_character)
	else:
		emit_signal("enable_player_controls", current_character)
		emit_signal("update_turn_label", current_round)
		emit_signal("update_current_character_label", current_character.name)
		emit_signal("log_action", current_character.name + "'s turn started")
		var valid_move_positions = get_valid_move_positions(current_character)
		emit_signal("highlight_valid_positions", valid_move_positions)

func advance_phase() -> void:
	match current_phase:
		BattlePhase.QUICK_ACTIONS:
			current_phase = BattlePhase.ENEMY_ACTIONS
		BattlePhase.ENEMY_ACTIONS:
			current_phase = BattlePhase.SLOW_ACTIONS
		BattlePhase.SLOW_ACTIONS:
			end_battle_round()
			return
	
	current_turn_index = 0
	start_next_turn()

func end_battle_round() -> void:
	current_phase = BattlePhase.END_PHASE
	perform_morale_check()
	if not check_battle_end():
		current_round += 1
		start_battle_round()

# Character Actions
func perform_enemy_turn(enemy: Character) -> void:
	var target := find_nearest_enemy(enemy)
	if can_attack(enemy, target):
		perform_attack(enemy, target)
	else:
		var move_position := find_nearest_cover(enemy)
		move_character(enemy, move_position)

func perform_attack(attacker: Character, target: Character) -> void:
	if can_attack(attacker, target):
		var hit_roll: int = roll_dice(1, 6) + attacker.combat_skill
		var hit_threshold: int = 5 if get_cover_type(target.position) == CoverType.NONE else 6
		
		if hit_roll >= hit_threshold:
			var damage: int = attacker.weapon.roll_damage()
			apply_damage(target, damage)
			log_action.emit("%s hit %s for %d damage!" % [attacker.name, target.name, damage])
		else:
			log_action.emit("%s missed %s!" % [attacker.name, target.name])

# Helper Functions
func roll_dice(num_dice: int, sides: int) -> int:
	var total := 0
	for i in range(num_dice):
		total += randi() % sides + 1
	log_action.emit("Rolled " + str(num_dice) + "d" + str(sides) + ": " + str(total))
	return total

func is_valid_move(character: Character, new_position: Vector2i) -> bool:
	var distance := character.position.distance_to(new_position)
	return is_valid_position(new_position) and distance <= character.speed and battlefield[new_position.x][new_position.y] == null

func update_character_position(character: Character) -> void:
	var unit_node := get_node_or_null("../Battlefield/Units/" + character.name)
	if unit_node:
		var grid_position := character.position * CELL_SIZE
		unit_node.position = grid_position
		character_moved.emit(character, grid_position)
	else:
		push_error("Character node not found: %s" % character.name)

func can_attack(attacker: Character, target: Character) -> bool:
	var distance := attacker.position.distance_to(target.position)
	return distance <= attacker.weapon.range and has_line_of_sight(attacker.position, target.position)

func apply_damage(target: Character, damage: int) -> void:
	if damage >= target.toughness:
		target.is_defeated = true
		log_action.emit(target.name + " is defeated!")
		remove_character(target)
	else:
		var stun_roll := roll_dice(1, 6)
		if stun_roll <= damage:
			target.is_stunned = true
			log_action.emit(target.name + " is stunned!")
		else:
			log_action.emit(target.name + " resists being stunned!")

func remove_character(character: Character) -> void:
	turn_order.erase(character)
	if character in game_state.current_crew.members:
		game_state.current_crew.members.erase(character)
	elif character in current_mission.get_enemies():
		current_mission.remove_enemy(character)

func find_nearest_enemy(character: Character) -> Character:
	var enemies: Array[Character] = current_mission.get_enemies() if character in game_state.current_crew.members else game_state.current_crew.members
	var nearest_enemy: Character = null
	var min_distance := INF
	for enemy in enemies:
		var distance := character.position.distance_to(enemy.position)
		if distance < min_distance:
			min_distance = distance
			nearest_enemy = enemy
	return nearest_enemy

func find_nearest_cover(character: Character) -> Vector2i:
	var best_cover: Vector2i = Vector2i.ZERO
	var min_distance := INF
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var pos := Vector2i(x, y)
			if get_cover_type(pos) != CoverType.NONE:
				var distance := character.position.distance_to(pos)
				if distance < min_distance:
					min_distance = distance
					best_cover = pos
	return best_cover if best_cover != Vector2i.ZERO else find_random_position()

func find_random_position() -> Vector2i:
	var x := randi() % GRID_SIZE.x
	var y := randi() % GRID_SIZE.y
	return Vector2i(x, y)

func get_cover_type(position: Vector2i) -> CoverType:
	var adjacent_positions := [
		Vector2i(position.x - 1, position.y),
		Vector2i(position.x + 1, position.y),
		Vector2i(position.x, position.y - 1),
		Vector2i(position.x, position.y + 1)
	]

	var cover_count := 0
	for adj_pos in adjacent_positions:
		if is_valid_position(adj_pos) and battlefield[adj_pos.x][adj_pos.y] != null:
			cover_count += 1

	if cover_count >= 2:
		return CoverType.FULL
	elif cover_count == 1:
		return CoverType.PARTIAL
	else:
		return CoverType.NONE

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE.x and pos.y >= 0 and pos.y < GRID_SIZE.y

func has_line_of_sight(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	var dx: int = abs(to_pos.x - from_pos.x)
	var dy: int = abs(to_pos.y - from_pos.y)
	var x: int = from_pos.x
	var y: int = from_pos.y
	var n: int = 1 + dx + dy
	var x_inc: int = 1 if to_pos.x > from_pos.x else -1
	var y_inc: int = 1 if to_pos.y > from_pos.y else -1
	var error: int = dx - dy
	dx *= 2
	dy *= 2

	for _i in range(n):
		var current_pos := Vector2i(x, y)
		if not is_valid_position(current_pos) or battlefield[current_pos.x][current_pos.y] == GlobalEnums.TerrainFeature.AREA:
			return false
		if error > 0:
			x += x_inc
			error -= dy
		elif error < 0:
			y += y_inc
			error += dx
		else:
			x += x_inc
			y += y_inc
			error -= dy
			error += dx

	return true

func perform_morale_check() -> void:
	var enemies: Array[Character] = current_mission.get_enemies()
	var casualties := enemies.filter(func(e: Character) -> bool: return e.is_defeated)
	
	for i in range(casualties.size()):
		var roll := roll_dice(1, 6)
		if roll <= enemies[0].panic_range:
			var fleeing_enemy: Character = enemies[randi() % enemies.size()]
			fleeing_enemy.flee()
			emit_signal("log_action", fleeing_enemy.name + " has fled the battle!")

func check_battle_end() -> bool:
	if check_victory_conditions():
		emit_signal("combat_ended", true)
		return true
	elif check_defeat_conditions():
		emit_signal("combat_ended", false)
		return true
	return false

func get_valid_move_positions(character: Character) -> Array[Vector2i]:
	var valid_positions: Array[Vector2i] = []
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var pos = Vector2i(x, y)
			if is_valid_move(character, pos):
				valid_positions.append(pos)
	return valid_positions

func check_victory_conditions() -> bool:
	match current_mission.objective:
		GlobalEnums.MissionObjective.MOVE_THROUGH:
			var crew_members = current_mission.get_crew_members()
			return crew_members.all(func(member: Character) -> bool: return member.position.x >= GRID_SIZE.x - 1)
		_:
			push_warning("Unhandled mission objective in victory conditions")
			return false

func check_defeat_conditions() -> bool:
	var crew_members = current_mission.get_crew_members()
	if crew_members.all(func(member: Character) -> bool: return member.is_defeated):
		return true
	
	if current_mission.is_expired(current_round):
		return true
	
	return false

func check_escape_condition() -> bool:
	var escape_zone = Rect2(Vector2.ZERO, Vector2(3, GRID_SIZE.y))
	return current_mission.get_crew_members().any(func(member: Character) -> bool: return escape_zone.has_point(member.position))

func handle_move(character: Character, new_position: Vector2i) -> void:
	if is_valid_move(character, new_position):
		move_character(character, new_position)
		emit_signal("character_moved", character, new_position)

func handle_attack(attacker: Character, target: Character) -> void:
	if can_attack(attacker, target):
		perform_attack(attacker, target)

func handle_end_turn() -> void:
	current_turn_index += 1
	start_next_turn()

func get_terrain_color(terrain_type: GlobalEnums.TerrainFeature) -> Color:
	match terrain_type:
		GlobalEnums.TerrainFeature.AREA:
			return Color(0.2, 0.6, 0.2)
		GlobalEnums.TerrainFeature.INDIVIDUAL:
			return Color(0.6, 0.4, 0.2)
		GlobalEnums.TerrainFeature.LINEAR:
			return Color(0.2, 0.2, 0.6)
		_:
			return Color(0.2, 0.2, 0.2)

func find_valid_spawn_position(is_crew: bool) -> Vector2i:
	var x_range := range(0, 6) if is_crew else range(18, 24)
	var valid_positions: Array[Vector2i] = []
	for x in x_range:
		for y in range(GRID_SIZE.y):
			if battlefield[x][y] == null:
				valid_positions.append(Vector2i(x, y))
	return valid_positions[randi() % valid_positions.size()]

# Signal Emitters
func start_combat() -> void:
	combat_started.emit()

func end_combat(player_victory: bool) -> void:
	combat_ended.emit(player_victory)

func start_turn(character: Character) -> void:
	turn_started.emit(character)

func end_turn(character: Character) -> void:
	turn_ended.emit(character)

func update_ui(round_num: int, phase: BattlePhase, current_character: Character) -> void:
	ui_update_needed.emit(round_num, phase, current_character)

func add_log_entry(action: String) -> void:
	log_action.emit(action)

func move_character(character: Character, new_position: Vector2i) -> void:
	character_moved.emit(character, new_position)

func enable_controls(character: Character) -> void:
	enable_player_controls.emit(character)

func update_turn(turn_round: int) -> void:
	update_turn_label.emit(turn_round)

func update_current_character(character_name: String) -> void:
	update_current_character_label.emit(character_name)

func show_valid_positions(positions: Array[Vector2i]) -> void:
	highlight_valid_positions.emit(positions)

