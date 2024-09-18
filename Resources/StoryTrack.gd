# StoryTrack.gd
class_name StoryTrack
extends Resource

var events: Array[StoryEvent] = []
var current_event_index: int = -1
var story_clock: StoryClock

func _init():
    story_clock = StoryClock.new()
    _load_events()

func _load_events():
    # Load events from a JSON file or create them manually
    var event_data = [
        {
            "event_id": "foiled",
            "description": "Foiled! Your old rival O'Narr has struck again...",
            "campaign_turn_modifications": {
                "add_rival": "O'Narr",
                "set_forced_action": "look_for_patron"
            },
            "battle_setup": {
                "set_enemy_type": "rival_gang",
                "set_battlefield_size": Vector2(48, 48)
            },
            "rewards": {
                "add_credits": 5,
                "add_story_points": 1
            },
            "next_event_ticks": 3
        },
        # Add more events here
    ]
    
    for data in event_data:
        events.append(StoryEvent.new(data))

func start_tutorial():
    current_event_index = 0
    trigger_current_event()

func trigger_current_event():
    if current_event_index < 0 or current_event_index >= events.size():
        return
    
    var current_event = events[current_event_index]
    story_clock.set_ticks(current_event.next_event_ticks)
    
    # Emit a signal or call a method to display the event description
    # and apply the event effects

func progress_story(game_state: GameState, battle_won: bool):
    story_clock.count_down(battle_won)
    if story_clock.is_event_triggered():
        current_event_index += 1
        if current_event_index < events.size():
            trigger_current_event()
        else:
            # Tutorial completed
            game_state.end_tutorial()