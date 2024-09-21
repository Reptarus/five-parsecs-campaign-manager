class_name CombatManager
extends Node

signal combat_started
signal combat_ended(player_victory: bool)
signal turn_started(character)
signal turn_ended(character)
signal player_input_received(action, target)

@export var game_state: GameStateManager
var current_battle: BattleManager
var turn_order: Array = []
var current_turn_index: int = 0
var ai_controller: AIController

const GRID_SIZE: Vector2i = Vector2i(24, 24)  # 24" x 24" battlefield
var battlefield: Array[Array] = []

enum CoverType { NONE, PARTIAL, FULL }
enum BattlePhase { REACTION_ROLL, QUICK_ACTIONS, ENEMY_ACTIONS, SLOW_ACTIONS, END_PHASE }

var current_phase: BattlePhase = BattlePhase.REACTION_ROLL

func _ready():
    initialize()

func initialize():
    ai_controller = AIController.new()
    ai_controller.initialize(self, game_state.get_node())
    initialize_battlefield()

class BattleManager:
    var player_characters: Array
    var enemies: Array
    var enemy_panic_range: int = 2  # Default panic range, adjust as needed
    var enemy_casualties_this_round: int = 0

    func _init(_player_characters: Array, _enemies: Array):
        player_characters = _player_characters
        enemies = _enemies

    func are_all_enemies_defeated() -> bool:
        return enemies.is_empty()

    func are_all_players_defeated() -> bool:
        return player_characters.all(func(player): return player.is_defeated())

    func get_enemy_casualties_this_round() -> int:
        return enemy_casualties_this_round

    func reset_casualties_count() -> void:
        enemy_casualties_this_round = 0

    func increment_casualties_count() -> void:
        enemy_casualties_this_round += 1

func initialize_battlefield() -> void:
    battlefield = []
    for x in range(GRID_SIZE.x):
        battlefield.append([])
        for y in range(GRID_SIZE.y):
            battlefield[x].append(null)

func start_combat(player_characters: Array, enemies: Array) -> void:
    current_battle = BattleManager.new(player_characters, enemies)
    place_characters_on_battlefield()
    seize_initiative()
    combat_started.emit()
    start_battle_round()

func place_characters_on_battlefield() -> void:
    for character in current_battle.player_characters:
        var position = find_empty_position(0, int(GRID_SIZE.x / 2.0) - 1)
        character.position = position
        battlefield[position.x][position.y] = character

    for enemy in current_battle.enemies:
        var position = find_empty_position(int(GRID_SIZE.x / 2.0), GRID_SIZE.x - 1)
        enemy.position = position
        battlefield[position.x][position.y] = enemy

func find_empty_position(start_x: int, end_x: int) -> Vector2i:
    for _attempt in range(100):  # Limit attempts to prevent infinite loop
        var x = randi() % (end_x - start_x + 1) + start_x
        var y = randi() % int(GRID_SIZE.y)
        if battlefield[x][y] == null:
            return Vector2i(x, y)
    return Vector2i.ZERO  # Fallback if no position found

func seize_initiative() -> void:
    var highest_savvy = current_battle.player_characters.map(func(c): return c.savvy).max()
    var roll = randi() % 6 + randi() % 6 + 2 + highest_savvy  # 2d6 + highest savvy
    
    if current_battle.player_characters.size() < current_battle.enemies.size():
        roll += 1
    
    if roll >= 10:
        for character in current_battle.player_characters:
            # Allow move or fire
            perform_action(character, "move_or_fire")

func start_battle_round() -> void:
    current_phase = BattlePhase.REACTION_ROLL
    perform_reaction_roll()

func perform_reaction_roll() -> void:
    turn_order.clear()
    
    for character in current_battle.player_characters:
        var roll = randi() % 6 + 1
        if roll <= character.reactions:
            turn_order.append(character)
    
    turn_order.append_array(current_battle.enemies)
    
    for character in current_battle.player_characters:
        if not character in turn_order:
            turn_order.append(character)
    
    current_phase = BattlePhase.QUICK_ACTIONS
    current_turn_index = 0
    start_next_turn()

func start_next_turn() -> void:
    if current_turn_index >= turn_order.size():
        end_battle_round()
        return

    var current_character = turn_order[current_turn_index]
    turn_started.emit(current_character)

    if current_character in current_battle.enemies:
        if current_phase == BattlePhase.ENEMY_ACTIONS:
            ai_controller.perform_ai_turn(current_character)
        else:
            end_turn()
    else:
        # Wait for player input
        await player_input_received
        end_turn()

func end_turn() -> void:
    var current_character = turn_order[current_turn_index]
    turn_ended.emit(current_character)
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
        combat_ended.emit(true)  # Player victory
        return true
    elif current_battle.are_all_players_defeated():
        combat_ended.emit(false)  # Player defeat
        return true
    return false

func perform_action(character, action: String, target = null, target_position: Vector2i = Vector2i.ZERO) -> void:
    match action:
        "move":
            move_character(character, target_position)
        "attack":
            attack_character(character, target)
        "use_item":
            use_item(character, target)  # Added 'target' parameter
        "snap_fire":
            snap_fire(character, target)
        "move_or_fire":
            if target:
                attack_character(character, target)
            elif target_position != Vector2i.ZERO:
                move_character(character, target_position)

func move_character(character, target_position: Vector2i) -> void:
    var start_position = character.position
    var path = find_path(start_position, target_position)

    if path.size() <= character.movement_points:
        battlefield[start_position.x][start_position.y] = null
        character.position = target_position
        battlefield[target_position.x][target_position.y] = character
    else:
        var new_position = path[character.speed]
        battlefield[start_position.x][start_position.y] = null
        character.position = new_position
        battlefield[new_position.x][new_position.y] = character

func find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
    # Implement A* pathfinding algorithm here
    # For simplicity, we'll use a straight line for now
    var path: Array[Vector2i] = []
    var current = start
    while current != end:
        var diff = end - current
        var step = Vector2i(sign(diff.x), sign(diff.y))
        current += step
        path.append(current)
    return path

func get_cover_type(character) -> CoverType:
    var pos = character.position
    var adjacent_positions = [
        Vector2i(pos.x - 1, pos.y),
        Vector2i(pos.x + 1, pos.y),
        Vector2i(pos.x, pos.y - 1),
        Vector2i(pos.x, pos.y + 1)
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

func use_item(character, item, target = null) -> void:
    match item.type:
        Item.ItemType.CONSUMABLE:
            if item.name == "Booster pills":
                character.remove_all_stun()
                character.double_speed_this_round()
            elif item.name == "Combat serum":
                character.increase_speed(2)
                character.increase_reactions(2)
            elif item.name == "Kiranin crystals":
                character.set_dazzling_effect(true)
                character.increase_reactions(1)
            elif item.name == "Rage out":
                character.increase_speed(2)
                character.increase_brawling(1)
                if character.race == "Kerin":
                    character.set_rage_state(true)
            elif item.name == "Still":
                character.increase_hit(1)
                character.set_immobile(2)
            elif item.name == "Stim-pack":
                character.prevent_next_casualty()
            elif item.name == "Reflective dust":
                character.set_reflective_dust(true)
        
        Item.ItemType.PROTECTIVE:
            if item.name == "Battle dress":
                character.increase_reactions(1, 4)
                character.set_saving_throw(5)
            elif item.name in ["Camo cloak", "Combat armor", "Deflector field", "Flak screen", "Flex-armor", "Frag vest", "Screen generator", "Stealth gear"]:
                character.set_armor(item.name)
        
        Item.ItemType.UTILITY:
            if item.name == "Fog generator":
                character.set_fog_generator(true)
            elif item.name == "Teleportation device":
                # Implement teleportation logic
                pass
            elif item.name == "Bot upgrade":
                character.upgrade_bot()
        
        Item.ItemType.ONBOARD:
            if item.name == "Ship part":
                character.add_ship_part()
            # Implement other onboard item effects
        
        Item.ItemType.PSIONIC:
            if item.name == "Psionic amplifier":
                character.increase_psionic_power(1)

    item.use(character, target)
    character.remove_item(item)

func snap_fire(character, target) -> void:
    var weapon = character.get_equipped_weapon()
    if "Snap Shot" in weapon.traits:
        attack_character(character, target)
    else:
        print("This weapon cannot perform snap fire")

func are_enemies_within_range(character, range_value: float) -> bool:
    for enemy in current_battle.enemies:
        if character.position.distance_to(enemy.position) <= range_value:
            return true
    return false

func can_engage_in_brawl(character) -> bool:
    for enemy in current_battle.enemies:
        if character.position.distance_to(enemy.position) <= 1:  # Assuming 1 unit is melee range
            return true
    return false

func are_enemies_in_open(_character) -> bool:
    for enemy in current_battle.enemies:
        if get_cover_type(enemy) == CoverType.NONE:
            return true
    return false

# Update the attack function to consider weapon mods
func attack_character(attacker, target) -> void:
    var weapon = attacker.get_equipped_weapon()
    var distance = attacker.position.distance_to(target.position)

    if distance > weapon.weapon_range:
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

    # Apply weapon mod bonuses
    to_hit_roll += weapon.get_hit_bonus(distance, attacker.is_aiming, is_in_cover(attacker))

    if to_hit_roll >= hit_threshold:
        var damage = weapon.weapon_damage + (randi() % 6 + 1)
        
        # Check for hot shot pack overheating
        if weapon.check_overheat(to_hit_roll - attacker.combat_skill):
            print("Weapon overheated!")
            weapon.is_damaged = true
        
        if damage >= target.toughness:
            apply_damage(target, damage)
            
            # Apply impact effect if the weapon has it
            if "Impact" in weapon.traits:
                target.apply_stun()
        else:
            target.apply_stun()

# Function to check if a character is in cover
func is_in_cover(character) -> bool:
    return get_cover_type(character) != CoverType.NONE

func apply_damage(character, damage: int) -> void:
    character.take_damage(damage)
    if character.health <= 0:
        character.kill()

func handle_melee_combat(attacker, defender) -> void:
    var attacker_weapon = attacker.get_equipped_weapon()
    var defender_weapon = defender.get_equipped_weapon()
    
    var attacker_roll = randi() % 6 + 1 + attacker.combat_skill + (attacker_weapon.melee_bonus if attacker_weapon.is_melee() else 0)
    var defender_roll = randi() % 6 + 1 + defender.combat_skill + (defender_weapon.melee_bonus if defender_weapon.is_melee() else 0)
    
    if attacker_roll > defender_roll:
        apply_damage(defender, attacker_weapon.damage)
    elif defender_roll > attacker_roll:
        apply_damage(attacker, defender_weapon.damage)
    # If rolls are equal, it's a draw and nothing happens

func calculate_visibility(character) -> int:
    var base_visibility = 12  # Base visibility in inches
    var weapon = character.get_equipped_weapon()
    return base_visibility + weapon.visibility_bonus

func find_distant_cover_position(character) -> Vector2i:
    var best_position = character.position
    var best_distance = 0
    
    for x in range(GRID_SIZE.x):
        for y in range(GRID_SIZE.y):
            var pos = Vector2i(x, y)
            if battlefield[x][y] == null:
                var temp_character = character.duplicate()
                temp_character.position = pos
                if get_cover_type(temp_character) != CoverType.NONE:
                    var distance = character.position.distance_to(pos)
                    if distance > best_distance and are_enemies_within_range(temp_character, 12):
                        best_position = pos
                        best_distance = distance
    
    return best_position

func find_retreat_position(character) -> Vector2i:
    var retreat_direction = (Vector2(character.position) - Vector2(find_nearest_enemy(character).position)).normalized()
    var retreat_position = Vector2(character.position) + (retreat_direction * float(character.speed))
    return Vector2i(retreat_position)

func find_cover_within_range(character, cover_range: float) -> Vector2i:
    var best_position = character.position
    
    for x in range(GRID_SIZE.x):
        for y in range(GRID_SIZE.y):
            var pos = Vector2i(x, y)
            if battlefield[x][y] == null:
                var temp_character = character.duplicate()
                temp_character.position = pos
                if get_cover_type(temp_character) != CoverType.NONE:
                    var distance = character.position.distance_to(pos)
                    if distance <= cover_range and distance > character.position.distance_to(best_position):
                        best_position = pos
    
    return best_position

func find_cover_near_enemy(character) -> Vector2i:
    var nearest_enemy = find_nearest_enemy(character)
    var best_position = character.position
    var best_distance = INF
    
    for x in range(GRID_SIZE.x):
        for y in range(GRID_SIZE.y):
            var pos = Vector2i(x, y)
            if battlefield[x][y] == null:
                var temp_character = character.duplicate()
                temp_character.position = pos
                if get_cover_type(temp_character) != CoverType.NONE:
                    var distance_to_enemy = pos.distance_to(nearest_enemy.position)
                    if distance_to_enemy < best_distance:
                        best_position = pos
                        best_distance = distance_to_enemy
    
    return best_position

func find_nearest_enemy(character):
    var nearest_enemy = null
    var nearest_distance = INF
    
    for enemy in current_battle.player_characters:
        var distance = character.position.distance_to(enemy.position)
        if distance < nearest_distance:
            nearest_enemy = enemy
            nearest_distance = distance
    
    return nearest_enemy

func find_best_target(character):
    var best_target = null
    var best_score = -INF
    
    for enemy in current_battle.player_characters:
        var score = 0.0
        score -= float(character.position.distance_to(enemy.position))  # Prefer closer targets
        score += (1.0 - float(enemy.health) / float(enemy.max_health)) * 10.0  # Prefer wounded targets
        if get_cover_type(enemy) == CoverType.NONE:
            score += 5.0  # Prefer targets out of cover
        
        if score > best_score:
            best_target = enemy
            best_score = score
    
    return best_target

func move_to_brawl(character, target) -> void:
    var path = find_path(character.position, target.position)
    var new_position = path[min(character.speed, path.size() - 1)]
    move_character(character, new_position)

func charge(character, target) -> void:
    move_to_brawl(character, target)
    attack_character(character, target)

func dash(character, target_position: Vector2i) -> void:
    var direction = (Vector2(target_position) - Vector2(character.position)).normalized()
    var dash_position = Vector2(character.position) + direction * (character.speed * 2)
    move_character(character, Vector2i(dash_position))

func retreat(character, retreat_position: Vector2i) -> void:
    move_character(character, retreat_position)

func aim(character) -> void:
    character.is_aiming = true

# Add this method to handle player input
func handle_player_input(action: String, target = null) -> void:
    perform_action(turn_order[current_turn_index], action, target)
    player_input_received.emit()
