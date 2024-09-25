# Scripts/Missions/CombatManager.gd
extends Node

signal combat_started
signal combat_ended(player_victory: bool)
signal turn_started(character)
signal turn_ended(character)

enum CoverType { NONE, PARTIAL, FULL }
enum BattlePhase { REACTION_ROLL, QUICK_ACTIONS, ENEMY_ACTIONS, SLOW_ACTIONS, END_PHASE }

var game_state: GameStateManager
var current_mission: Mission
var terrain_generator: TerrainGenerator
var battlefield: Array
var turn_order: Array
var current_turn_index: int = 0
var current_round: int = 1
var current_phase: BattlePhase = BattlePhase.REACTION_ROLL

const GRID_SIZE: Vector2i = Vector2i(24, 24)  # 24" x 24" battlefield

@onready var battle_grid: GridContainer = $"../BattleGrid"
@onready var turn_label: Label = $"../SidePanel/VBoxContainer/TurnLabel"
@onready var current_character_label: Label = $"../SidePanel/VBoxContainer/CurrentCharacterLabel"
@onready var battle_log: TextEdit = $"../SidePanel/VBoxContainer/BattleLog"

func initialize(_game_state: GameStateManager, _mission: Mission):
    game_state = _game_state
    current_mission = _mission
    terrain_generator = TerrainGenerator.new()
    battlefield = terrain_generator.generate_terrain()
    setup_battlefield()
    setup_characters()
    place_objectives()
    start_combat()

func setup_battlefield():
    battle_grid.columns = GRID_SIZE.x
    for x in range(GRID_SIZE.x):
        for y in range(GRID_SIZE.y):
            var cell = ColorRect.new()
            cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
            cell.color = get_terrain_color(battlefield[x][y])
            battle_grid.add_child(cell)

func get_terrain_color(terrain_type) -> Color:
    match terrain_type:
        TerrainGenerator.TerrainType.LARGE:
            return Color(0.2, 0.6, 0.2)
        TerrainGenerator.TerrainType.SMALL:
            return Color(0.6, 0.4, 0.2)
        TerrainGenerator.TerrainType.LINEAR:
            return Color(0.2, 0.2, 0.6)
        _:
            return Color(0.2, 0.2, 0.2)

func setup_characters():
    var crew = game_state.current_crew.characters
    var enemies = current_mission.get_enemies()
    
    for character in crew + enemies:
        character.position = find_valid_spawn_position(character in crew)

func find_valid_spawn_position(is_crew: bool) -> Vector2i:
    var x_range = range(0, 6) if is_crew else range(18, 24)
    var valid_positions = []
    for x in x_range:
        for y in range(GRID_SIZE.y):
            if battlefield[x][y] == null:
                valid_positions.append(Vector2i(x, y))
    return valid_positions[randi() % valid_positions.size()]

func start_combat():
    current_round = 1
    current_phase = BattlePhase.REACTION_ROLL
    emit_signal("combat_started")
    start_battle_round()

func start_battle_round():
    log_action("Starting Round " + str(current_round))
    perform_reaction_roll()

func perform_reaction_roll():
    turn_order.clear()
    var crew = game_state.current_crew.characters
    var enemies = current_mission.get_enemies()
    
    for character in crew + enemies:
        var roll = roll_dice(1, 6)
        if roll <= character.reactions:
            turn_order.append(character)
    
    for character in crew + enemies:
        if not character in turn_order:
            turn_order.append(character)
    
    current_phase = BattlePhase.QUICK_ACTIONS
    current_turn_index = 0
    start_next_turn()

func start_next_turn():
    if current_turn_index >= turn_order.size():
        advance_phase()
        return

    var current_character = turn_order[current_turn_index]
    emit_signal("turn_started", current_character)
    update_ui(current_character)

    if current_character in current_mission.get_enemies():
        perform_enemy_turn(current_character)
    else:
        # Wait for player input
        # This will be handled by the UI buttons
        pass

func advance_phase():
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

func end_battle_round():
    current_phase = BattlePhase.END_PHASE
    perform_morale_check()
    if not check_battle_end():
        current_round += 1
        start_battle_round()

func update_ui(current_character):
    turn_label.text = "Round: " + str(current_round) + " | Phase: " + BattlePhase.keys()[current_phase]
    current_character_label.text = "Current Character: " + current_character.name

func log_action(action: String):
    battle_log.text += action + "\n"

func roll_dice(num_dice: int, sides: int) -> int:
    var total = 0
    for i in range(num_dice):
        total += randi() % sides + 1
    log_action("Rolled " + str(num_dice) + "d" + str(sides) + ": " + str(total))
    return total

func perform_enemy_turn(enemy: Character):
    var target = find_nearest_enemy(enemy)
    if can_attack(enemy, target):
        perform_attack(enemy, target)
    else:
        var move_position = find_nearest_cover(enemy)
        move_character(enemy, move_position)

func move_character(character: Character, new_position: Vector2i):
    if is_valid_move(character, new_position):
        character.position = new_position
        update_character_position(character)

func is_valid_move(character: Character, new_position: Vector2i) -> bool:
    var distance = character.position.distance_to(new_position)
    return is_valid_position(new_position) and distance <= character.speed and battlefield[new_position.x][new_position.y] == null

func update_character_position(character: Character):
    # Update the visual representation of the character on the battlefield
    # This will be implemented when we update the UI
    pass

func perform_attack(attacker: Character, target: Character):
    if can_attack(attacker, target):
        var hit_roll = roll_dice(1, 6) + attacker.combat_skill
        var hit_threshold = 5 if get_cover_type(target) == CoverType.NONE else 6
        
        if hit_roll >= hit_threshold:
            var damage = attacker.weapon.roll_damage()
            apply_damage(target, damage)
            log_action(attacker.name + " hit " + target.name + " for " + str(damage) + " damage!")
        else:
            log_action(attacker.name + " missed " + target.name + "!")

func can_attack(attacker: Character, target: Character) -> bool:
    var distance = attacker.position.distance_to(target.position)
    return distance <= attacker.weapon.range and has_line_of_sight(attacker.position, target.position)

func apply_damage(target: Character, damage: int):
    if damage >= target.toughness:
        target.is_defeated = true
        log_action(target.name + " is defeated!")
        remove_character(target)
    else:
        # Apply stun logic here
        pass

func remove_character(character: Character):
    turn_order.erase(character)
    if character in game_state.current_crew.characters:
        game_state.current_crew.characters.erase(character)
    elif character in current_mission.get_enemies():
        current_mission.remove_enemy(character)

func find_nearest_enemy(character: Character) -> Character:
    var enemies = current_mission.get_enemies() if character in game_state.current_crew.characters else game_state.current_crew.characters
    var nearest_enemy = null
    var min_distance = INF
    for enemy in enemies:
        var distance = character.position.distance_to(enemy.position)
        if distance < min_distance:
            min_distance = distance
            nearest_enemy = enemy
    return nearest_enemy

func find_nearest_cover(character: Character) -> Vector2i:
    var best_cover = null
    var min_distance = INF
    for x in range(GRID_SIZE.x):
        for y in range(GRID_SIZE.y):
            var pos = Vector2i(x, y)
            if get_cover_type(pos) != CoverType.NONE:
                var distance = character.position.distance_to(pos)
                if distance < min_distance:
                    min_distance = distance
                    best_cover = pos
    return best_cover if best_cover else find_random_position()

func find_random_position() -> Vector2i:
    var x = randi() % GRID_SIZE.x
    var y = randi() % GRID_SIZE.y
    return Vector2i(x, y)

func get_cover_type(position: Vector2i) -> CoverType:
    var adjacent_positions = [
        Vector2i(position.x - 1, position.y),
        Vector2i(position.x + 1, position.y),
        Vector2i(position.x, position.y - 1),
        Vector2i(position.x, position.y + 1)
    ]

    var cover_count = 0
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
    var dx = abs(to_pos.x - from_pos.x)
    var dy = abs(to_pos.y - from_pos.y)
    var x = from_pos.x
    var y = from_pos.y
    var n = 1 + dx + dy
    var x_inc = 1 if to_pos.x > from_pos.x else -1
    var y_inc = 1 if to_pos.y > from_pos.y else -1
    var error = dx - dy
    dx *= 2
    dy *= 2

    for _i in range(n):
        if not is_valid_position(Vector2i(x, y)) or battlefield[x][y] == TerrainGenerator.TerrainType.LARGE:
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

func perform_morale_check():
    var enemies = current_mission.get_enemies()
    var casualties = enemies.filter(func(e): return e.is_defeated)
    
    for i in range(casualties.size()):
        var roll = roll_dice(1, 6)
        if roll <= enemies[0].panic_range:
            var fleeing_enemy = enemies[randi() % enemies.size()]
            fleeing_enemy.flee()
            log_action(fleeing_enemy.name + " has fled the battle!")

func check_battle_end() -> bool:
    if check_victory_conditions():
        emit_signal("combat_ended", true)
        return true
    elif check_defeat_conditions():
        emit_signal("combat_ended", false)
        return true
    return false

# Implement victory and defeat condition checks here

func _on_move_button_pressed():
    var current_character = turn_order[current_turn_index]
    # Implement move logic
    pass

func _on_attack_button_pressed():
    var current_character = turn_order[current_turn_index]
    # Implement attack logic
    pass

func _on_end_turn_button_pressed():
    current_turn_index += 1
    start_next_turn()