extends Node

signal tutorial_step_changed(step: String)

var current_step: String = ""
var is_tutorial_active: bool = false
var tutorial_type: String = ""

func start_tutorial(type: String):
    tutorial_type = type
    is_tutorial_active = true
    set_step("crew_size_selection")

func set_step(step: String):
    current_step = step
    emit_signal("tutorial_step_changed", step)

func end_tutorial():
    is_tutorial_active = false
    tutorial_type = ""
    current_step = ""

func get_tutorial_text(step: String) -> String:
    match step:
        "crew_size_selection":
            return "Choose the size of your crew. This will determine how many characters you'll create."
        "campaign_setup":
            return "Set up your campaign by choosing difficulty options."
        "character_creation":
            return "Create your crew members. Each character has unique traits and abilities."
        "ship_creation":
            return "Build your ship by selecting components and customizing its features."
        "connections_creation":
            return "Establish connections between your crew members to enhance their relationships."
        "save_campaign":
            return "Save your campaign to continue your adventure later."
        _:
            return "Continue with the tutorial."
