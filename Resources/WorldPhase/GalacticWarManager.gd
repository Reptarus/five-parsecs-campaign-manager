extends Node

signal faction_action_resolved(faction_name: String, success: bool)
signal faction_defeated(faction_name: String)
signal faction_strength_increased(faction_name: String, new_strength: int)

class Faction:
    var name: String
    var strength: int
    var power: int
    var actions: int

    func _init(p_name: String, p_strength: int, p_power: int):
        name = p_name
        strength = p_strength
        power = p_power
        actions = 2 if p_strength <= 5 else 3  # Solarsystem-wide (2) or sector-sized (3)

var factions: Array[Faction] = []
var game_state: GameState

func _init() -> void:
    game_state = GameStateManager.get_singleton()
    if not game_state:
        push_error("GameState singleton not found. Make sure it's properly set up as an AutoLoad.")

func _ready() -> void:
    randomize()
    game_state.connect("new_turn_started", Callable(self, "_on_new_campaign_turn"))

func create_faction(faction_name: String, faction_strength: int = 0, faction_power: int = 0) -> Faction:
    var final_strength = faction_strength if faction_strength > 0 else (randi() % 6 + 2)  # 1D6+1
    var final_power = faction_power if faction_power > 0 else (randi() % 3 + 3)  # 1D3+2
    
    var faction = Faction.new(faction_name, final_strength, final_power)
    factions.append(faction)
    return faction

func resolve_faction_actions() -> void:
    for faction in factions:
        for i in range(faction.actions):
            var success = randi() % 6 + 1 >= faction.power
            faction_action_resolved.emit(faction.name, success)
            if success:
                game_state.fringe_world_strife_manager.update_world_strife(game_state.current_location)

func faction_attack(attacker: Faction, defender: Faction) -> void:
    if attacker.strength >= defender.strength or randi() % 6 + 1 == 6:
        defender.strength -= 1
        if defender.strength <= 0:
            factions.erase(defender)
            faction_defeated.emit(defender.name)
    
func increase_faction_strength(faction: Faction) -> void:
    var successes = 0
    for i in range(faction.strength):
        if randi() % 6 + 1 >= faction.power:
            successes += 1
    
    if successes == faction.strength:
        faction.strength += 1
        faction_strength_increased.emit(faction.name, faction.strength)

func process_galactic_war_turn() -> void:
    resolve_faction_actions()
    
    if factions.size() >= 2:
        faction_attack(factions[0], factions[1])
    
    for faction in factions:
        if randf() < 0.3:  # 30% chance to attempt strength increase
            increase_faction_strength(faction)

func _on_new_campaign_turn() -> void:
    process_galactic_war_turn()

func initialize_factions() -> void:
    create_faction("Galactic Empire")
    create_faction("Rebel Alliance")
    create_faction("Trade Federation")
