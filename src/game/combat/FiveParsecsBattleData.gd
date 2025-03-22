@tool
extends "res://src/base/combat/BaseBattleData.gd"

## Five Parsecs implementation of battle data
##
## Extends the base battle data class with Five Parsecs specific functionality

# Signal tracking
var _signal_counts: Dictionary = {}

# Five Parsecs specific battle types
enum BattleType {
    PATROL = 0,
    SEEK_AND_DESTROY = 1,
    HOLD_POSITION = 2,
    ESCORT = 3,
    EXTRACTION = 4,
    SPECIAL = 5
}

# Five Parsecs specific battle configuration
var campaign_turn: int = 0
var location_name: String = ""
var terrain_type: String = ""
var weather_conditions: String = ""

# Five Parsecs specific tracking
var turns_elapsed: int = 0
var casualties: Dictionary = {
    "player": 0,
    "enemy": 0
}

func _init() -> void:
    super._init()
    # Initialize Five Parsecs specific properties

## Configure the battle with Five Parsecs specific settings
## @param config: Dictionary containing battle configuration
func configure(config: Dictionary) -> void:
    super.configure(config)
    
    # Handle Five Parsecs specific configuration
    if config.has("campaign_turn"):
        campaign_turn = config.campaign_turn
    if config.has("location_name"):
        location_name = config.location_name
    if config.has("terrain_type"):
        terrain_type = config.terrain_type
    if config.has("weather_conditions"):
        weather_conditions = config.weather_conditions

## Start a new turn in the battle
func start_new_turn() -> void:
    turns_elapsed += 1

## Record a casualty in the battle
## @param is_player: Whether the casualty is a player character
func record_casualty(is_player: bool) -> void:
    if is_player:
        casualties.player += 1
    else:
        casualties.enemy += 1

## Get the current turn number
## @return: Current turn number
func get_current_turn() -> int:
    return turns_elapsed + 1

## Get the battle statistics
## @return: Dictionary containing battle statistics
func get_battle_statistics() -> Dictionary:
    var stats = {
        "turns_elapsed": turns_elapsed,
        "casualties": casualties.duplicate(),
        "battle_type": battle_type,
        "location": location_name,
        "terrain": terrain_type,
        "weather": weather_conditions
    }
    
    # Add base battle outcome data
    var outcome = get_battle_outcome()
    stats.merge(outcome)
    
    return stats

# Override base methods with Five Parsecs specific implementations
func start_battle() -> void:
    super.start_battle()
    turns_elapsed = 0
    casualties = {
        "player": 0,
        "enemy": 0
    }

func end_battle(victory: bool = false) -> void:
    super.end_battle(victory)
    # Add Five Parsecs specific end battle logic here

func add_combatant(combatant, is_player: bool = true) -> void:
    super.add_combatant(combatant, is_player)
    # Add Five Parsecs specific combatant logic here

func remove_combatant(combatant) -> void:
    super.remove_combatant(combatant)
    # Add Five Parsecs specific combatant removal logic here

# Clear all signal watchers
func clear_signal_watcher() -> void:
    for obj_id in _signal_counts.keys():
        var parts = obj_id.split("_")
        if parts.size() >= 2:
            var obj_instance_id = parts[0].to_int()
            var obj = instance_from_id(obj_instance_id)
            if is_instance_valid(obj):
                for signal_info in obj.get_signal_list():
                    var signal_name = signal_info["name"]
                    var callable = Callable(self, "_on_signal_emitted").bind(obj, signal_name)
                    if obj.is_connected(signal_name, callable):
                        obj.disconnect(signal_name, callable)
    _signal_counts.clear()

# Get the count of assertions made in this test
func get_assert_count() -> int:
    return 0 # This would need proper implementation to track assertions

# Used by GUT to check if pending state should be used
func pending(message: String = "") -> void:
    push_error("Pending: " + message)

# Used by GUT to get the total count of failing assertions
func get_fail_count() -> int:
    return 0 # This would need proper implementation

# Used by GUT to get the total count of passing assertions
func get_pass_count() -> int:
    return 0 # This would need proper implementation

# Mark a test as passing
func pass_test(message: String = "") -> void:
    # Implementation would increment pass count
    pass

# Mark a test as failing
func fail_test(message: String = "") -> void:
    push_error("Test failed: " + message)