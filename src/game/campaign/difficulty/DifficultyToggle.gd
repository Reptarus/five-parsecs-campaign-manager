# DifficultyToggle.gd
class_name DifficultyToggle extends Resource

enum ToggleType {
    STRENGTH_ADJUSTED_ENEMIES,
    SLAVES_TO_THE_STAR_GRIND,
    HIT_ME_HARDER,
    TIME_IS_RUNNING_OUT,
    STARTING_IN_THE_GUTTER,
    REDUCED_LETHALITY,
}

@export var toggle_name: String
@export var description: String
@export var toggle_type: ToggleType
@export var is_active: bool = false

func apply_effect() -> void:
    is_active = true
    print(str("Applying effect for toggle: ", toggle_name))
    match toggle_type:
        ToggleType.STRENGTH_ADJUSTED_ENEMIES:
            _apply_strength_adjusted_enemies()
        ToggleType.SLAVES_TO_THE_STAR_GRIND:
            _apply_slaves_to_the_star_grind()
        ToggleType.HIT_ME_HARDER:
            _apply_hit_me_harder()
        ToggleType.TIME_IS_RUNNING_OUT:
            _apply_time_is_running_out()
        ToggleType.STARTING_IN_THE_GUTTER:
            _apply_starting_in_the_gutter()
        ToggleType.REDUCED_LETHALITY:
            _apply_reduced_lethality()

func remove_effect() -> void:
    is_active = false
    print(str("Removing effect for toggle: ", toggle_name))
    match toggle_type:
        ToggleType.STRENGTH_ADJUSTED_ENEMIES:
            _remove_strength_adjusted_enemies()
        ToggleType.SLAVES_TO_THE_STAR_GRIND:
            _remove_slaves_to_the_star_grind()
        ToggleType.HIT_ME_HARDER:
            _remove_hit_me_harder()
        ToggleType.TIME_IS_RUNNING_OUT:
            _remove_time_is_running_out()
        ToggleType.STARTING_IN_THE_GUTTER:
            _remove_starting_in_the_gutter()
        ToggleType.REDUCED_LETHALITY:
            _remove_reduced_lethality()

# --- Placeholder functions for specific toggle effects ---

func _apply_strength_adjusted_enemies() -> void:
    # This would modify how enemy counts are generated based on crew size/strength
    print("Strength-adjusted enemies toggle applied.")

func _remove_strength_adjusted_enemies() -> void:
    print("Strength-adjusted enemies toggle removed.")

func _apply_slaves_to_the_star_grind() -> void:
    # Placeholder for "Slaves to the Star-grind" effect
    print("Slaves to the Star-grind toggle applied.")

func _remove_slaves_to_the_star_grind() -> void:
    print("Slaves to the Star-grind toggle removed.")

func _apply_hit_me_harder() -> void:
    # Placeholder for "Hit Me Harder" effect
    print("Hit Me Harder toggle applied.")

func _remove_hit_me_harder() -> void:
    print("Hit Me Harder toggle removed.")

func _apply_time_is_running_out() -> void:
    # Placeholder for "Time is Running Out" effect
    print("Time is Running Out toggle applied.")

func _remove_time_is_running_out() -> void:
    print("Time is Running Out toggle removed.")

func _apply_starting_in_the_gutter() -> void:
    # Placeholder for "Starting in the Gutter" effect
    print("Starting in the Gutter toggle applied.")

func _remove_starting_in_the_gutter() -> void:
    print("Starting in the Gutter toggle removed.")

func _apply_reduced_lethality() -> void:
    # Placeholder for "Reduced Lethality" effect
    print("Reduced Lethality toggle applied.")

func _remove_reduced_lethality() -> void:
    print("Reduced Lethality toggle removed.")