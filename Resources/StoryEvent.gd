# StoryEvent.gd
class_name StoryEvent
extends Resource

var event_id: String
var description: String
var campaign_turn_modifications: Dictionary
var battle_setup: Dictionary
var rewards: Dictionary
var next_event_ticks: int

func _init(data: Dictionary = {}):
    event_id = data.get("event_id", "")
    description = data.get("description", "")
    campaign_turn_modifications = data.get("campaign_turn_modifications", {})
    battle_setup = data.get("battle_setup", {})
    rewards = data.get("rewards", {})
    next_event_ticks = data.get("next_event_ticks", 0)

func apply_event_effects(game_state: GameState):
    # Apply campaign turn modifications
    for key in campaign_turn_modifications:
        if game_state.has_method(key):
            game_state.call(key, campaign_turn_modifications[key])

func setup_battle(battle: Battle):
    # Apply battle setup modifications
    for key in battle_setup:
        if battle.has_method(key):
            battle.call(key, battle_setup[key])

func apply_rewards(game_state: GameState):
    # Apply rewards
    for key in rewards:
        if game_state.has_method(key):
            game_state.call(key, rewards[key])

func serialize() -> Dictionary:
    return {
        "event_id": event_id,
        "description": description,
        "campaign_turn_modifications": campaign_turn_modifications,
        "battle_setup": battle_setup,
        "rewards": rewards,
        "next_event_ticks": next_event_ticks
    }

static func deserialize(data: Dictionary) -> StoryEvent:
    return StoryEvent.new(data)