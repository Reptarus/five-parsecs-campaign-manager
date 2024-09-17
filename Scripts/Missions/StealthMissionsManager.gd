class_name StealthMissionsManager
extends Node

var game_state: GameState
var battle_scene: Battle

const MAX_DETECTION_LEVEL: int = 2
const DETECTION_LEVELS = ["Undetected", "Alerted", "Compromised"]

var current_detection_level: int = 0
var enemies: Array[Character] = []
var crew_members: Array[Character] = []

enum StealthAction { STAY_DOWN, DISTRACTION, LURE }

func _init(_game_state: GameState, _battle_scene: Battle):
    game_state = _game_state
    battle_scene = _battle_scene

func generate_stealth_mission() -> Mission:
    var mission = Mission.new()
    mission.type = Mission.Type.INFILTRATION
    mission.objective = Mission.Objective.ACCESS
    mission.location = game_state.get_random_location()
    mission.difficulty = randi() % 5 + 1  # 1 to 5
    mission.rewards = _generate_rewards(mission.difficulty)
    mission.time_limit = randi() % 5 + 3  # 3 to 7 campaign turns
    mission.title = _generate_mission_title(mission.type, mission.location)
    mission.description = _generate_mission_description(mission.type, mission.objective, mission.location)
    
    _generate_stealth_enemies(mission)
    
    return mission

func _generate_stealth_enemies(mission: Mission):
    var num_enemies = game_state.crew_size + 1
    for i in range(num_enemies):
        var enemy = Character.new()
        # Set up basic enemy properties
        enemy.ai_type = _get_random_ai_type()
        enemies.append(enemy)
    
    # Add 1 Specialist and 1 Lieutenant
    var specialist = Character.new()
    specialist.character_class = "Specialist"
    enemies.append(specialist)
    
    var lieutenant = Character.new()
    lieutenant.character_class = "Lieutenant"
    enemies.append(lieutenant)

func _get_random_ai_type() -> int:
    return randi() % OptionalEnemyAI.AIType.size()

func execute_stealth_round():
    _roll_initiative()
    _move_enemies()
    _move_players()
    _check_detection()

func _roll_initiative():
    crew_members.shuffle()
    enemies.shuffle()

func _move_enemies():
    for enemy in enemies:
        if enemy.is_designated:
            _execute_360_degree_scan(enemy)
        else:
            _move_random_direction(enemy)

func _move_random_direction(enemy: Character):
    var direction = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()
    var move_distance = enemy.speed
    enemy.position += direction * move_distance

func _execute_360_degree_scan(enemy: Character):
    for crew_member in crew_members:
        if _is_in_line_of_sight(enemy, crew_member):
            _check_for_detection(enemy, crew_member)

func _move_players():
    # This will be handled by player input in the actual game
    pass

func _check_detection():
    for enemy in enemies:
        for crew_member in crew_members:
            if _is_in_line_of_sight(enemy, crew_member):
                _check_for_detection(enemy, crew_member)

func _is_in_line_of_sight(character1: Character, character2: Character) -> bool:
    # Implement line of sight check
    # For now, we'll use a simple distance check
    return character1.position.distance_to(character2.position) <= 6.0

func _check_for_detection(enemy: Character, crew_member: Character):
    var distance = enemy.position.distance_to(crew_member.position)
    var spotting_value = 6 - enemy.savvy  # Assuming higher savvy means better at spotting
    
    if distance <= spotting_value:
        increase_detection_level()

func increase_detection_level():
    current_detection_level = min(current_detection_level + 1, MAX_DETECTION_LEVEL)
    if current_detection_level == MAX_DETECTION_LEVEL:
        _trigger_alarm()

func _trigger_alarm():
    print("Alarm triggered! Transitioning to normal combat.")
    battle_scene._on_stealth_mission_failed()

func perform_stealth_action(character: Character, action: StealthAction) -> void:
    match action:
        StealthAction.STAY_DOWN:
            _perform_stay_down(character)
        StealthAction.DISTRACTION:
            _perform_distraction(character)
        StealthAction.LURE:
            _perform_lure(character)

func _perform_stay_down(character: Character):
    character.is_staying_down = true
    # Reduce detection chance for this character

func _perform_distraction(character: Character):
    var target_enemy = _find_closest_enemy(character)
    if target_enemy:
        _distract_enemy(target_enemy)

func _perform_lure(character: Character):
    var enemies_in_range = _get_enemies_in_range(character, 8)  # 8" range for lure
    for enemy in enemies_in_range:
        _lure_enemy(enemy, character)

func _find_closest_enemy(character: Character) -> Character:
    var closest_enemy = null
    var closest_distance = INF
    for enemy in enemies:
        var distance = character.position.distance_to(enemy.position)
        if distance < closest_distance:
            closest_distance = distance
            closest_enemy = enemy
    return closest_enemy

func _distract_enemy(enemy: Character):
    enemy.is_distracted = true
    # Implement distraction logic

func _get_enemies_in_range(character: Character, range: float) -> Array:
    var enemies_in_range = []
    for enemy in enemies:
        if character.position.distance_to(enemy.position) <= range:
            enemies_in_range.append(enemy)
    return enemies_in_range

func _lure_enemy(enemy: Character, character: Character):
    enemy.lured_position = character.position
    # Implement lure logic

func use_psionic_ability(character: Character, ability: String) -> void:
    if game_state.psionic_manager.use_power(ability, character):
        match ability:
            "Grab":
                _use_psionic_grab(character)
            "Shock":
                _use_psionic_shock(character)
            "Psionic Scare":
                _use_psionic_scare(character)
    else:
        increase_detection_level()

func _use_psionic_grab(character: Character):
    var target_enemy = _find_closest_enemy(character)
    if target_enemy:
        # Implement grab logic
        pass

func _use_psionic_shock(character: Character):
    var target_enemy = _find_closest_enemy(character)
    if target_enemy:
        # Implement shock logic
        pass

func _use_psionic_scare(character: Character):
    var enemies_in_range = _get_enemies_in_range(character, 6)  # 6" range for scare
    for enemy in enemies_in_range:
        # Implement scare logic
        pass

func check_for_reinforcements() -> void:
    if current_detection_level == MAX_DETECTION_LEVEL:
        var roll = randi() % 6 + 1
        if roll >= 4:  # 50% chance of reinforcements
            _spawn_reinforcements()

func _spawn_reinforcements() -> void:
    var num_reinforcements = game_state.crew_size + 1
    for i in range(num_reinforcements):
        var reinforcement = Character.new()
        # Set up reinforcement properties
        enemies.append(reinforcement)
        _place_reinforcement(reinforcement)

func _place_reinforcement(enemy: Character) -> void:
    var edge = randi() % 4
    enemy.position = _get_entry_position(edge)

func _get_entry_position(edge: int) -> Vector2:
    # Implement logic to get a position on the specified table edge
    return Vector2.ZERO

func check_mission_end_conditions() -> bool:
    if current_detection_level == MAX_DETECTION_LEVEL and enemies.size() == 0:
        return true
    # Add more end conditions as needed
    return false

func _generate_rewards(difficulty: int) -> Dictionary:
    # Implement reward generation based on difficulty
    return {}

func _generate_mission_title(type: int, location: Location) -> String:
    # Implement mission title generation
    return "Stealth Mission"

func _generate_mission_description(type: int, objective: int, location: Location) -> String:
    # Implement mission description generation
    return "Infiltrate the enemy base and complete the objective without being detected."
