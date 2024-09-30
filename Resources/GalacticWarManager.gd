class_name GalacticWarManager
extends Node

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
var game_state_manager: GameStateManagerNode
var game_state: GameState

func _init() -> void:
    game_state_manager = get_node("/root/GameState")
    if not game_state_manager:
        push_error("GameStateManagerNode not found. Make sure it's properly set up as an AutoLoad.")
        return
    
    game_state = game_state_manager.get_game_state()
    if not game_state:
        push_error("GameState not found in GameStateManagerNode.")
        return

func _ready() -> void:
    randomize()

func create_faction(faction_name: String, faction_strength: int = 0, faction_power: int = 0) -> Faction:
    var final_strength = faction_strength if faction_strength > 0 else (randi() % 6 + 2)  # 1D6+1
    var final_power = faction_power if faction_power > 0 else (randi() % 3 + 3)  # 1D3+2
    
    var faction = Faction.new(faction_name, final_strength, final_power)
    factions.append(faction)
    return faction

func resolve_faction_actions() -> void:
    for faction in factions:
        for i in range(faction.actions):
            if randi() % 6 + 1 >= faction.power:
                print_debug(faction.name + " succeeded in an action.")
                # TODO: Implement specific events or plot advancements

func faction_attack(attacker: Faction, defender: Faction) -> void:
    if attacker.strength >= defender.strength or randi() % 6 + 1 == 6:
        defender.strength -= 1
        print_debug(attacker.name + " successfully attacked " + defender.name)
    else:
        print_debug(attacker.name + " failed to damage " + defender.name)
    
    if defender.strength <= 0:
        print_debug(defender.name + " has been defeated and no longer exists.")
        factions.erase(defender)

func increase_faction_strength(faction: Faction) -> void:
    var successes = 0
    for i in range(faction.strength):
        if randi() % 6 + 1 >= faction.power:
            successes += 1
    
    if successes == faction.strength:
        faction.strength += 1
        print_debug(faction.name + " increased its strength to " + str(faction.strength))
    else:
        print_debug(faction.name + " failed to increase its strength.")

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
