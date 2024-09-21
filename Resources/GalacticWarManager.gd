extends Node

class Faction:
    var name: String
    var strength: int
    var power: int
    var actions: int

    func _init(p_name: String, p_strength: int, _p_power: int):
        name = p_name
        strength = p_strength
        power = power
        actions = 2 if p_strength <= 5 else 3  # Solarsystem-wide (2) or sector-sized (3)

var factions: Array[Faction] = []

func _ready():
    randomize()

func create_faction(faction_name: String, faction_strength: int = 0, faction_power: int = 0) -> Faction:
    var final_strength = faction_strength
    var final_power = faction_power
    
    if final_strength == 0:
        final_strength = randi() % 6 + 2  # 1D6+1
    if final_power == 0:
        final_power = randi() % 3 + 3  # 1D3+2
    
    var faction = Faction.new(faction_name, final_strength, final_power)
    factions.append(faction)
    return faction

func resolve_faction_actions():
    for faction in factions:
        for i in range(faction.actions):
            var roll = randi() % 6 + 1
            if roll >= faction.power:
                print(faction.name + " succeeded in an action.")
                # Here you could trigger specific events or plot advancements

func faction_attack(attacker: Faction, defender: Faction):
    if attacker.strength >= defender.strength:
        defender.strength -= 1
        print(attacker.name + " successfully attacked " + defender.name)
    else:
        var roll = randi() % 6 + 1
        if roll == 6:
            defender.strength -= 1
            print(attacker.name + " successfully attacked stronger faction " + defender.name)
        else:
            print(attacker.name + " failed to damage stronger faction " + defender.name)
    
    if defender.strength <= 0:
        print(defender.name + " has been defeated and no longer exists.")
        factions.erase(defender)

func increase_faction_strength(faction: Faction):
    var successes_needed = faction.strength
    var successes = 0
    for i in range(successes_needed):
        var roll = randi() % 6 + 1
        if roll >= faction.power:
            successes += 1
    
    if successes == successes_needed:
        faction.strength += 1
        print(faction.name + " increased its strength to " + str(faction.strength))
    else:
        print(faction.name + " failed to increase its strength.")

func process_galactic_war_turn():
    resolve_faction_actions()
    
    # Example of faction interactions
    if factions.size() >= 2:
        faction_attack(factions[0], factions[1])
    
    for faction in factions:
        if randf() < 0.3:  # 30% chance to attempt strength increase
            increase_faction_strength(faction)

# Example usage
func _on_new_campaign_turn():
    process_galactic_war_turn()

# Initialize factions at the start of a campaign
func initialize_factions():
    create_faction("Galactic Empire")
    create_faction("Rebel Alliance")
    create_faction("Trade Federation")
