extends Control

## InjuryResultCard Usage Example
## Demonstrates how to use the InjuryResultCard component in post-battle systems

func _ready() -> void:
	_example_usage()

func _example_usage() -> void:
	"""Example of how to use InjuryResultCard component"""

	# Example 1: Minor injury
	var minor_injury_card := InjuryResultCard.new()
	minor_injury_card.setup({
		"crew_id": "crew_001",
		"crew_name": "Sarah Chen",
		"injury_type": "Light Wound",
		"severity": "minor",
		"recovery_turns": 2,
		"is_fatal": false
	})
	minor_injury_card.crew_selected.connect(_on_crew_selected)
	add_child(minor_injury_card)

	# Example 2: Serious injury
	var serious_injury_card := InjuryResultCard.new()
	serious_injury_card.setup({
		"crew_id": "crew_002",
		"crew_name": "Marcus Kane",
		"injury_type": "Broken Ribs",
		"severity": "serious",
		"recovery_turns": 5,
		"is_fatal": false
	})
	serious_injury_card.crew_selected.connect(_on_crew_selected)
	add_child(serious_injury_card)

	# Example 3: Critical/Fatal injury
	var fatal_injury_card := InjuryResultCard.new()
	fatal_injury_card.setup({
		"crew_id": "crew_003",
		"crew_name": "Viktor Kozlov",
		"injury_type": "Fatal Head Trauma",
		"severity": "critical",
		"recovery_turns": 0,
		"is_fatal": true
	})
	fatal_injury_card.crew_selected.connect(_on_crew_selected)
	add_child(fatal_injury_card)

	print("InjuryResultCard: Examples created successfully")

func _on_crew_selected(crew_id: String) -> void:
	"""Handle crew selection signal"""
	print("InjuryResultCard: Crew selected - %s" % crew_id)
	# In actual implementation, would open crew details screen or injury management panel
