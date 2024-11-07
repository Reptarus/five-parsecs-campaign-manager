# GameTutorialManager.gd - Main tutorial management class
class_name GameTutorialManager
extends Node

signal tutorial_step_changed(step: String)
signal tutorial_completed(type: String)
signal tutorial_step_completed(step_id: String)
signal tutorial_track_completed(track_id: String)

enum TutorialTrack {
    STORY_TRACK,  # Core rules tutorial
    COMPENDIUM,   # Advanced mechanics tutorial
    QUICK_START,  # Basic mechanics only
    ADVANCED      # Full campaign mechanics
}

# Tutorial data structure
const TUTORIAL_DATA = {
    TutorialTrack.QUICK_START: {
        "steps": [
            {
                "id": "crew_creation",
                "title": "Create Your Crew",
                "description": "Let's start by creating your first crew members.",
                "required_actions": ["character_created", "crew_named"]
            },
            {
                "id": "first_battle",
                "title": "Your First Fight", 
                "description": "Time to learn basic combat mechanics.",
                "required_actions": ["battle_completed"]
            }
        ]
    },
    TutorialTrack.ADVANCED: {
        "steps": [
            {
                "id": "campaign_setup",
                "title": "Campaign Setup",
                "description": "Configure your full campaign experience.",
                "required_actions": ["difficulty_selected", "victory_condition_set"]
            }
        ]
    }
}

# Tutorial state
var current_tutorial: TutorialTrack
var current_step: String = ""
var is_tutorial_active: bool = false
var story_clock: StoryClock
var story_track: StoryTrack

# Tutorial difficulty modifiers
const TUTORIAL_DICE_BONUS := 1
const TUTORIAL_ENEMY_PENALTY := -1 
const TUTORIAL_REWARD_BONUS := 1.2

# Add to existing TutorialManager.gd
const TUTORIAL_DATA_PATH := {
    TutorialTrack.QUICK_START: "res://data/Tutorials/quick_start_tutorial.json",
    TutorialTrack.ADVANCED: "res://data/Tutorials/advanced_tutorial.json"
}

var tutorial_data: Dictionary = {}

func _ready() -> void:
    var game_state_manager = get_node("/root/GameStateManager")
    if not game_state_manager:
        push_error("GameStateManager not found")
        return
        
    story_clock = StoryClock.new()
    story_track = StoryTrack.new()
    story_track.initialize(game_state_manager.game_state)
    _load_tutorial_data()
    load_progress()

func _load_tutorial_data() -> void:
    for track in TUTORIAL_DATA_PATH:
        var file_path = TUTORIAL_DATA_PATH[track]
        var file = FileAccess.open(file_path, FileAccess.READ)
        if file:
            var json = JSON.new()
            var parse_result = json.parse(file.get_as_text())
            if parse_result == OK:
                tutorial_data[track] = json.data
            else:
                push_error("Failed to parse tutorial data for track %s: %s at line %s" % 
                    [track, json.get_error_message(), json.get_error_line()])
        else:
            push_error("Failed to open tutorial data file: %s" % file_path)

func get_current_step_data() -> Dictionary:
    if not is_tutorial_active or current_tutorial not in tutorial_data:
        return {}
    
    var track_data = tutorial_data[current_tutorial]
    if not "steps" in track_data:
        return {}
        
    for step in track_data.steps:
        if step.id == current_step:
            return step
            
    return {}

func check_required_actions(action: String) -> void:
    var step_data = get_current_step_data()
    if step_data.is_empty() or not "required_actions" in step_data:
        return
        
    if action in step_data.required_actions:
        var all_complete = true
        for required in step_data.required_actions:
            # Check if action is complete - implement tracking system
            pass
            
        if all_complete:
            tutorial_step_completed.emit(current_step)
            advance_tutorial()

func advance_tutorial() -> void:
    var track_data = tutorial_data[current_tutorial]
    if not "steps" in track_data:
        return
        
    var current_index = -1
    for i in range(track_data.steps.size()):
        if track_data.steps[i].id == current_step:
            current_index = i
            break
            
    if current_index >= 0 and current_index < track_data.steps.size() - 1:
        current_step = track_data.steps[current_index + 1].id
        tutorial_step_changed.emit(current_step)
    else:
        end_tutorial()

# Tutorial flow control
func start_tutorial(type: TutorialTrack) -> void:
    current_tutorial = type
    is_tutorial_active = true
    
    # Apply tutorial modifiers
    apply_tutorial_modifiers()
    
    match type:
        TutorialTrack.STORY_TRACK:
            _start_story_track()
        TutorialTrack.COMPENDIUM:
            _start_compendium_track()
        TutorialTrack.QUICK_START:
            _start_quick_start()
        TutorialTrack.ADVANCED:
            _start_advanced_tutorial()

func _start_story_track() -> void:
    story_track.start_tutorial()

func _start_compendium_track() -> void:
    # Load compendium-specific tutorial content
    pass

func _start_quick_start() -> void:
    # Load quick start tutorial content
    pass 

func _start_advanced_tutorial() -> void:
    # Load advanced tutorial content
    pass

# Progress tracking
func save_progress() -> void:
    var save_data = {
        "tutorial_type": current_tutorial,
        "current_step": current_step,
        "story_track": story_track.serialize() if story_track else null,
        "completed_actions": {} # Add action tracking
    }
    
    var file = FileAccess.open("user://tutorial_progress.save", FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data))

func load_progress() -> void:
    if FileAccess.file_exists("user://tutorial_progress.save"):
        var file = FileAccess.open("user://tutorial_progress.save", FileAccess.READ)
        var json = JSON.new()
        var parse_result = json.parse(file.get_as_text())
        if parse_result == OK:
            var save_data = json.get_data()
            current_tutorial = save_data.get("tutorial_type", TutorialTrack.QUICK_START)
            current_step = save_data.get("current_step", "")
            if save_data.has("story_track"):
                story_track = StoryTrack.deserialize(save_data["story_track"])

# Tutorial modifiers
func apply_tutorial_modifiers() -> void:
    var game_state = get_node("/root/GameStateManager").game_state
    game_state.tutorial_dice_bonus = TUTORIAL_DICE_BONUS
    game_state.tutorial_enemy_penalty = TUTORIAL_ENEMY_PENALTY
    game_state.tutorial_reward_bonus = TUTORIAL_REWARD_BONUS

func remove_tutorial_modifiers() -> void:
    var game_state = get_node("/root/GameStateManager").game_state
    game_state.tutorial_dice_bonus = 0
    game_state.tutorial_enemy_penalty = 0
    game_state.tutorial_reward_bonus = 1.0

# Add missing function
func end_tutorial() -> void:
    is_tutorial_active = false
    remove_tutorial_modifiers()
    tutorial_completed.emit(current_tutorial)
    
    # Save final progress
    save_progress()
