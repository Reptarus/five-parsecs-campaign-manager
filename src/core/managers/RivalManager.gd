class_name RivalManager
extends Resource

signal rival_encountered(rival: Dictionary)
signal rival_reputation_changed(rival: Dictionary, change: int)
signal rival_status_changed(rival: Dictionary, new_status: String)

var game_state: GameState
var active_rivals: Array = []
var rival_reputations: Dictionary = {}  # rival_id -> reputation
var rival_statuses: Dictionary = {}  # rival_id -> status

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func generate_rival() -> Dictionary:
    var rival = {
        "id": "rival_" + str(randi()),
        "name": _generate_rival_name(),
        "type": _select_rival_type(),
        "strength": randi_range(1, 5),
        "resources": {
            "credits": randi_range(1000, 5000),
            "ships": randi_range(1, 3),
            "equipment": randi_range(3, 7)
        },
        "characteristics": _generate_rival_characteristics()
    }
    
    active_rivals.append(rival)
    rival_reputations[rival.id] = 0
    rival_statuses[rival.id] = "NEUTRAL"
    
    rival_encountered.emit(rival)
    return rival

func update_rival_reputation(rival_id: String, change: int) -> void:
    if not rival_id in rival_reputations:
        return
    
    rival_reputations[rival_id] = clamp(rival_reputations[rival_id] + change, -100, 100)
    var rival = get_rival(rival_id)
    
    rival_reputation_changed.emit(rival, change)
    _check_reputation_thresholds(rival)

func get_rival(rival_id: String) -> Dictionary:
    for rival in active_rivals:
        if rival.id == rival_id:
            return rival
    return {}

func get_rival_reputation(rival_id: String) -> int:
    return rival_reputations.get(rival_id, 0)

func get_rival_status(rival_id: String) -> String:
    return rival_statuses.get(rival_id, "NEUTRAL")

func get_active_rivals() -> Array:
    return active_rivals

func can_interact_with_rival(rival_id: String) -> bool:
    var rival = get_rival(rival_id)
    if rival.is_empty():
        return false
    
    var status = get_rival_status(rival_id)
    return status != "HOSTILE" and status != "DEFEATED"

func attempt_rival_negotiation(rival_id: String) -> bool:
    if not can_interact_with_rival(rival_id):
        return false
    
    var rival = get_rival(rival_id)
    var success_chance = _calculate_negotiation_chance(rival)
    
    if randf() <= success_chance:
        _improve_rival_relations(rival)
        return true
    else:
        _worsen_rival_relations(rival)
        return false

# Helper Functions
func _generate_rival_name() -> String:
    var prefixes = ["Captain", "Commander", "Boss", "Chief", "Leader"]
    var names = ["Smith", "Jones", "Blake", "Zhang", "Singh"]
    
    return prefixes[randi() % prefixes.size()] + " " + names[randi() % names.size()]

func _select_rival_type() -> String:
    var types = ["MERCENARY", "PIRATE", "TRADER", "BOUNTY_HUNTER", "SMUGGLER"]
    return types[randi() % types.size()]

func _generate_rival_characteristics() -> Array:
    var all_characteristics = ["AGGRESSIVE", "CAUTIOUS", "DIPLOMATIC", "TREACHEROUS", "HONORABLE"]
    var num_characteristics = randi_range(2, 3)
    var characteristics: Array = []
    var available_characteristics = all_characteristics.duplicate()
    
    for _i in range(num_characteristics):
        if available_characteristics.is_empty():
            break
            
        var index = randi() % available_characteristics.size()
        var selected_characteristic = available_characteristics[index]
        characteristics.append(selected_characteristic)
        available_characteristics.remove_at(index)
    
    return characteristics

func _check_reputation_thresholds(rival: Dictionary) -> void:
    var reputation = get_rival_reputation(rival.id)
    var old_status = get_rival_status(rival.id)
    var new_status = old_status
    
    if reputation <= -75:
        new_status = "HOSTILE"
    elif reputation <= -25:
        new_status = "UNFRIENDLY"
    elif reputation <= 25:
        new_status = "NEUTRAL"
    elif reputation <= 75:
        new_status = "FRIENDLY"
    else:
        new_status = "ALLIED"
    
    if new_status != old_status:
        rival_statuses[rival.id] = new_status
        rival_status_changed.emit(rival, new_status)

func _calculate_negotiation_chance(rival: Dictionary) -> float:
    var base_chance = 0.5
    var reputation = get_rival_reputation(rival.id)
    
    # Modify based on reputation
    base_chance += reputation / 200.0  # -0.5 to +0.5
    
    # Modify based on rival characteristics
    for characteristic in rival.characteristics:
        match characteristic:
            "DIPLOMATIC":
                base_chance += 0.2
            "TREACHEROUS":
                base_chance -= 0.2
            "HONORABLE":
                base_chance += 0.1
    
    # Modify based on crew skills
    for crew_member in game_state.crew:
        if crew_member.has_skill("negotiation"):
            base_chance += crew_member.get_skill_level("negotiation") * 0.1
    
    return clamp(base_chance, 0.1, 0.9)

func _improve_rival_relations(rival: Dictionary) -> void:
    var reputation_gain = randi_range(5, 15)
    update_rival_reputation(rival.id, reputation_gain)

func _worsen_rival_relations(rival: Dictionary) -> void:
    var reputation_loss = randi_range(5, 15)
    update_rival_reputation(rival.id, -reputation_loss)