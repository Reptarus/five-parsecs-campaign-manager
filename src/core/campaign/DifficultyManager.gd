# DifficultyManager.gd
class_name DifficultyManager extends RefCounted

# DifficultyToggle class definition
class DifficultyToggle extends Resource:
	@export var name: String = ""
	@export var description: String = ""
	@export var effect_data: Dictionary = {}
	
	func apply_effect() -> void:
		print("Applying difficulty toggle effect: ", name)
		# Override in specific toggle implementations
	
	func remove_effect() -> void:
		print("Removing difficulty toggle effect: ", name)
		# Override in specific toggle implementations

@export var active_difficulty_toggles: Array[DifficultyToggle]

func apply_campaign_difficulty(turn_number: int) -> void:
	# Logic for progressive difficulty based on campaign turn number
	# This would modify enemy strength, respawn rates, etc.
	print(str("Applying campaign difficulty for turn: ", turn_number))

	# Example: Increase enemy count every 5 turns
	if turn_number > 0 and turn_number % 5 == 0:
		print("Difficulty increased: More enemies!")
		# This would trigger a modification to enemy generation rules

func add_difficulty_toggle(toggle: DifficultyToggle) -> void:
	if not active_difficulty_toggles.has(toggle):
		active_difficulty_toggles.append(toggle)
		toggle.apply_effect() # Apply the toggle's effect
		print(str("Difficulty toggle activated: ", toggle.name))

func remove_difficulty_toggle(toggle: DifficultyToggle) -> void:
	if active_difficulty_toggles.has(toggle):
		active_difficulty_toggles.erase(toggle)
		toggle.remove_effect() # Remove the toggle's effect
		print(str("Difficulty toggle deactivated: ", toggle.name))
