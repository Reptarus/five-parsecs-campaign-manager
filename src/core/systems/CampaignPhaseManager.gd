@tool
extends Node

## Dependencies
const TableProcessor := preload("res://src/core/systems/TableProcessor.gd")
const TableLoader := preload("res://src/core/systems/TableLoader.gd")
const Campaign := preload("res://src/core/systems/Campaign.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

## Signals
signal phase_changed(new_phase: Dictionary)
signal phase_event_occurred(event: Dictionary)
signal phase_transition_failed(reason: String)

## Variables
var table_processor: TableProcessor
var current_phase: Dictionary
var campaign_ref: Campaign

## Constants
const CAMPAIGN_TABLES_PATH := "res://data/campaign_tables"
const MIN_PHASE_DURATION := 5 # Minimum missions per phase
const RESOURCE_THRESHOLDS := {
    "MID_GAME": 1000,
    "LATE_GAME": 2500
}
const REPUTATION_THRESHOLDS := {
    "MID_GAME": 10,
    "LATE_GAME": 25
}

## Phase roll ranges
const PHASE_ROLL_RANGES := {
    "EARLY_GAME": [1, 33],
    "MID_GAME": [34, 66],
    "LATE_GAME": [67, 100]
}

func _init() -> void:
    table_processor = TableProcessor.new()
    _load_campaign_tables()

func _load_campaign_tables() -> void:
    var tables := TableLoader.load_tables_from_directory(CAMPAIGN_TABLES_PATH)
    for table_name in tables:
        table_processor.register_table(tables[table_name])

## Setup the manager with a campaign reference
func setup(campaign: Campaign) -> void:
    campaign_ref = campaign
    _initialize_campaign_phase()

## Initialize the starting campaign phase
func _initialize_campaign_phase() -> void:
    var phase_result := table_processor.roll_table(
        "campaign_phases",
        PHASE_ROLL_RANGES["EARLY_GAME"][0] # Always start with early game
    )
    
    if phase_result["success"]:
        current_phase = phase_result["result"]
        phase_changed.emit(current_phase)
    else:
        push_error("Failed to initialize campaign phase")

## Check and potentially trigger phase transition
func check_phase_transition() -> void:
    if not _can_transition_phase():
        return
    
    var next_phase := _determine_next_phase()
    if next_phase.is_empty():
        phase_transition_failed.emit("Could not determine next phase")
        return
    
    current_phase = next_phase
    phase_changed.emit(current_phase)

## Generate a phase event
func generate_phase_event() -> Dictionary:
    var event_result := table_processor.roll_table(
        "phase_events",
        current_phase["type"]
    )
    
    if event_result["success"]:
        var event: Dictionary = event_result["result"]
        if _validate_event_requirements(event):
            phase_event_occurred.emit(event)
            return event
    
    return {}

## Check if phase transition is possible
func _can_transition_phase() -> bool:
    var missions_completed: int = campaign_ref.get_completed_missions_count()
    if missions_completed < MIN_PHASE_DURATION:
        return false
    
    var current_resources: int = campaign_ref.get_total_resources()
    var current_reputation: int = campaign_ref.get_reputation()
    
    match current_phase["type"]:
        "EARLY_GAME":
            return (current_resources >= RESOURCE_THRESHOLDS["MID_GAME"] and
                    current_reputation >= REPUTATION_THRESHOLDS["MID_GAME"])
        "MID_GAME":
            return (current_resources >= RESOURCE_THRESHOLDS["LATE_GAME"] and
                    current_reputation >= REPUTATION_THRESHOLDS["LATE_GAME"])
        _:
            return false

## Determine the next campaign phase
func _determine_next_phase() -> Dictionary:
    var next_phase_type := ""
    var roll_value := 0
    
    match current_phase["type"]:
        "EARLY_GAME":
            next_phase_type = "MID_GAME"
            roll_value = PHASE_ROLL_RANGES["MID_GAME"][0]
        "MID_GAME":
            next_phase_type = "LATE_GAME"
            roll_value = PHASE_ROLL_RANGES["LATE_GAME"][0]
        _:
            return {}
    
    var phase_result := table_processor.roll_table(
        "campaign_phases",
        roll_value # Use the start of the range for the desired phase
    )
    
    return phase_result["result"] if phase_result["success"] else {}

## Validate event requirements
func _validate_event_requirements(event: Dictionary) -> bool:
    var requirements: Array = event.get("requirements", [])
    
    for requirement in requirements:
        match requirement:
            "exploration_capability":
                if not campaign_ref.has_exploration_capability():
                    return false
            "active_crew":
                if campaign_ref.get_active_crew_count() <= 0:
                    return false
            "minimum_reputation":
                if campaign_ref.get_reputation() < 5:
                    return false
            "active_rivals":
                if campaign_ref.get_active_rivals_count() <= 0:
                    return false
            "advanced_equipment":
                if not campaign_ref.has_advanced_equipment():
                    return false
            "story_progress":
                if not campaign_ref.has_story_progress():
                    return false
            "high_reputation":
                if campaign_ref.get_reputation() < 20:
                    return false
    
    return true

## Get current phase modifiers
func get_current_modifiers() -> Dictionary:
    return {
        "resource_multiplier": current_phase.get("resource_multiplier", 1.0),
        "encounter_difficulty": current_phase.get("encounter_difficulty", 1.0),
        "available_mission_types": current_phase.get("available_mission_types", ["RED_ZONE"])
    }

## Get current phase special features
func get_special_features() -> Array:
    return current_phase.get("special_features", [])