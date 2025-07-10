# StreetFightMission.gd
class_name StreetFightMission extends Mission

func _init():
    super._init()
    mission_title = "Street Fight"
    mission_description = "An urban combat encounter with unpredictable elements."

func setup_street_fight_environment() -> void:
    print("Setting up street fight environment...")
    # Logic for generating urban terrain, determining player entry, etc.

func encounter_suspects() -> void:
    print("Encountering suspects...")
    # Logic for rolling on encounter tables and spawning enemies

func resolve_shootout() -> void:
    print("Resolving shootout...")
    # Logic for combat resolution specific to street fights