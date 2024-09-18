# StreetFightsManager.gd
class_name StreetFightsManager
extends Node

var game_state: GameState

const STREET_FIGHT_TYPES = ["Gang War", "Turf Defense", "Revenge Hit", "Protection Racket"]

func _init(_game_state: GameState):
    game_state = _game_state

func generate_street_fight() -> Mission:
    var mission = Mission.new()
    mission.type = Mission.Type.STREET_FIGHT
    mission.objective = _generate_street_fight_objective()
    mission.location = _generate_street_fight_location()
    mission.difficulty = randi() % 5 + 1  # 1 to 5
    mission.rewards = _generate_street_fight_rewards(mission.difficulty)
    mission.special_rules = _generate_street_fight_special_rules()
    return mission

func _generate_street_fight_objective() -> String:
    return STREET_FIGHT_TYPES[randi() % STREET_FIGHT_TYPES.size()]

func _generate_street_fight_location() -> String:
    var locations = [
        "Abandoned Warehouse",
        "Back Alley",
        "Neon-lit Street",
        "Underground Fighting Arena",
        "Rooftop"
    ]
    return locations[randi() % locations.size()]

func _generate_street_fight_rewards(difficulty: int) -> Dictionary:
    return {
        "credits": 800 * difficulty,
        "reputation": difficulty + 1,
        "territory_control": randf() < 0.5  # 50% chance for territory control
    }

func _generate_street_fight_special_rules() -> Array:
    var rules = []
    if randf() < 0.3:
        rules.append("Civilian Bystanders")
    if randf() < 0.3:
        rules.append("Environmental Hazards")
    return rules

func setup_street_fight(mission: Mission):
    # Set up combatants
    var player_team = game_state.current_crew.get_combat_ready_members()
    var enemy_team = _generate_enemy_team(mission.difficulty)
    
    # Set up the combat environment
    var combat_map = _generate_combat_map(mission.location.name)
    
    # Initialize combat state
    mission.combat_state = {
        "player_team": player_team,
        "enemy_team": enemy_team,
        "map": combat_map,
        "turn": 0,
        "active_effects": []
    }
    
    # Apply special rules
    for rule in mission.special_rules:
        _apply_special_rule(rule, mission.combat_state)

func resolve_street_fight(mission: Mission) -> bool:
    var combat_manager = CombatManager.new(game_state)
    combat_manager.setup_combat(mission.combat_state)
    
    while not combat_manager.is_combat_finished():
        combat_manager.execute_turn()
        mission.combat_state.turn += 1
    
    var player_victory = combat_manager.is_player_team_victorious()
    
    # Clean up combat state
    mission.combat_state = null
    
    return player_victory

func generate_street_fight_aftermath(mission: Mission) -> Dictionary:
    var aftermath = {}
    
    if mission.success:
        aftermath["reputation_gain"] = mission.rewards["reputation"]
        aftermath["credits_earned"] = mission.rewards["credits"]
        if mission.rewards["territory_control"]:
            aftermath["territory_gained"] = _calculate_territory_gain(mission)
    else:
        aftermath["reputation_loss"] = mission.difficulty
        aftermath["credits_lost"] = mission.rewards["credits"] * 0.1
    
    aftermath["injuries"] = _calculate_injuries(mission)
    aftermath["loot"] = _generate_loot(mission)
    
    return aftermath

func _generate_enemy_team(difficulty: int) -> Array:
    var enemy_team = []
    var enemy_count = difficulty + 1
    
    for i in range(enemy_count):
        var enemy = game_state.character_generator.generate_enemy(difficulty)
        enemy_team.append(enemy)
    
    return enemy_team

func _generate_combat_map(location: String) -> Dictionary:
    # This would be more complex in a real implementation
    return {
        "size": Vector2(10, 10),
        "obstacles": _generate_obstacles(location),
        "cover_points": _generate_cover_points(location)
    }

func _apply_special_rule(rule: String, combat_state: Dictionary):
    match rule:
        "Civilian Bystanders":
            combat_state["civilians"] = _generate_civilians()
        "Environmental Hazards":
            combat_state["hazards"] = _generate_hazards()

func _calculate_territory_gain(mission: Mission) -> float:
    return 0.1 * mission.difficulty  # 10% per difficulty level

func _calculate_injuries(mission: Mission) -> Array:
    var injuries = []
    for character in mission.combat_state.player_team:
        if character.health < character.max_health * 0.5:
            injuries.append({
                "character": character,
                "severity": "minor" if character.health > 0 else "major"
            })
    return injuries

func _generate_loot(mission: Mission) -> Array:
    var loot = []
    var loot_chance = 0.2 * mission.difficulty
    
    if randf() < loot_chance:
        loot.append(game_state.item_generator.generate_random_item(mission.difficulty))
    
    return loot

func _generate_obstacles(location: String) -> Array:
    var obstacles = []
    var obstacle_count = randi() % 5 + 3  # 3 to 7 obstacles
    
    for _i in range(obstacle_count):
        var obstacle = {
            "position": Vector2(randi() % 10, randi() % 10),
            "size": Vector2(randi() % 2 + 1, randi() % 2 + 1)
        }
        
        match location:
            "Mining Colony":
                obstacle["type"] = ["ore container", "mining equipment", "support beam"].pick_random()
            "Space Station":
                obstacle["type"] = ["cargo crate", "computer terminal", "maintenance robot"].pick_random()
            "Industrial World":
                obstacle["type"] = ["machinery", "storage tank", "conveyor belt"].pick_random()
            _:
                obstacle["type"] = ["debris", "crate", "barrier"].pick_random()
        
        obstacles.append(obstacle)
    
    return obstacles

func _generate_cover_points(location: String) -> Array:
    var cover_points = []
    var cover_count = randi() % 4 + 2  # 2 to 5 cover points
    
    for _i in range(cover_count):
        var cover = {
            "position": Vector2(randi() % 10, randi() % 10),
            "protection": randi() % 3 + 1  # 1 to 3 protection value
        }
        
        match location:
            "Mining Colony":
                cover["type"] = ["rock formation", "mining vehicle", "ore processor"].pick_random()
            "Space Station":
                cover["type"] = ["bulkhead", "airlock", "storage unit"].pick_random()
            "Industrial World":
                cover["type"] = ["factory equipment", "shipping container", "power generator"].pick_random()
            _:
                cover["type"] = ["wall", "pillar", "overturned table"].pick_random()
        
        cover_points.append(cover)
    
    return cover_points

func _generate_civilians() -> Array:
    var civilians = []
    var civilian_count = randi() % 3 + 1  # 1 to 3 civilians
    
    for _i in range(civilian_count):
        var civilian = {
            "position": Vector2(randi() % 10, randi() % 10),
            "type": ["bystander", "worker", "local resident"].pick_random(),
            "behavior": ["panicked", "curious", "hiding"].pick_random()
        }
        civilians.append(civilian)
    
    return civilians

func _generate_hazards() -> Array:
    var hazards = []
    var hazard_count = randi() % 2 + 1  # 1 to 2 hazards
    
    for _i in range(hazard_count):
        var hazard = {
            "position": Vector2(randi() % 10, randi() % 10),
            "type": ["fire", "toxic spill", "electrical malfunction", "unstable ground"].pick_random(),
            "danger_level": randi() % 3 + 1  # 1 to 3 danger level
        }
        hazards.append(hazard)
    
    return hazards
