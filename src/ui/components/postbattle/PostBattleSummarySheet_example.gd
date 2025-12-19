extends Control

## PostBattleSummarySheet Usage Example
## Demonstrates comprehensive post-battle summary setup

@onready var summary_sheet: PostBattleSummarySheet = $PostBattleSummarySheet

func _ready() -> void:
	# Connect signals
	summary_sheet.continue_pressed.connect(_on_summary_continue_pressed)

	# Example 1: Victory scenario with mixed results
	_example_victory_with_casualties()

	# Example 2: Defeat scenario
	# _example_defeat_scenario()

	# Example 3: Victory with invasion warning
	# _example_victory_with_invasion()

func _example_victory_with_casualties() -> void:
	"""Realistic victory scenario with some casualties and good loot"""
	var summary_data := {
		"mission_title": "Patrol Mission: Sector 7",
		"victory": true,
		"rounds": 8,
		"enemies_defeated": 12,
		"casualties": 2,
		"credits_earned": 450,
		"injuries": [
			{
				"character_name": "Marcus Kane",
				"injury_type": "Light Wound",
				"recovery_time": 1
			},
			{
				"character_name": "Sarah Chen",
				"injury_type": "Serious Injury",
				"recovery_time": 3
			}
		],
		"xp_gains": [
			{
				"character_name": "Marcus Kane",
				"xp_gained": 2,
				"new_total": 8
			},
			{
				"character_name": "Sarah Chen",
				"xp_gained": 2,
				"new_total": 5
			},
			{
				"character_name": "Elena Rodriguez",
				"xp_gained": 3,
				"new_total": 12
			},
			{
				"character_name": "Pavel Volkov",
				"xp_gained": 2,
				"new_total": 6
			}
		],
		"deaths": [],
		"loot": [
			{
				"item_name": "Infantry Laser",
				"type": "weapon",
				"value": 150
			},
			{
				"item_name": "Combat Armor",
				"type": "armor",
				"value": 200
			},
			{
				"item_name": "Stimpack",
				"type": "consumable",
				"value": 50
			},
			{
				"item_name": "Advanced Scanner",
				"type": "gear",
				"value": 100
			}
		],
		"rivals_change": 0,
		"patrons_change": 1,
		"quest_progress": "Eliminated 12/20 pirates for Patron Quest",
		"invasion_pending": false
	}

	summary_sheet.setup(summary_data)

func _example_defeat_scenario() -> void:
	"""Defeat scenario with casualties and deaths"""
	var summary_data := {
		"mission_title": "Defense Mission: Colony Outpost",
		"victory": false,
		"rounds": 6,
		"enemies_defeated": 8,
		"casualties": 4,
		"credits_earned": 0,
		"injuries": [
			{
				"character_name": "Marcus Kane",
				"injury_type": "Serious Injury",
				"recovery_time": 3
			},
			{
				"character_name": "Pavel Volkov",
				"injury_type": "Light Wound",
				"recovery_time": 1
			}
		],
		"xp_gains": [
			{
				"character_name": "Marcus Kane",
				"xp_gained": 1,
				"new_total": 9
			},
			{
				"character_name": "Pavel Volkov",
				"xp_gained": 1,
				"new_total": 7
			}
		],
		"deaths": [
			"Sarah Chen",
			"Elena Rodriguez"
		],
		"loot": [],
		"rivals_change": 1,
		"patrons_change": 0,
		"quest_progress": "",
		"invasion_pending": false
	}

	summary_sheet.setup(summary_data)

func _example_victory_with_invasion() -> void:
	"""Victory scenario with invasion warning"""
	var summary_data := {
		"mission_title": "Scout Mission: Frontier Sector",
		"victory": true,
		"rounds": 5,
		"enemies_defeated": 6,
		"casualties": 0,
		"credits_earned": 300,
		"injuries": [],
		"xp_gains": [
			{
				"character_name": "Marcus Kane",
				"xp_gained": 2,
				"new_total": 10
			},
			{
				"character_name": "Sarah Chen",
				"xp_gained": 2,
				"new_total": 7
			},
			{
				"character_name": "Elena Rodriguez",
				"xp_gained": 2,
				"new_total": 14
			}
		],
		"deaths": [],
		"loot": [
			{
				"item_name": "Plasma Rifle",
				"type": "weapon",
				"value": 250
			},
			{
				"item_name": "Alien Artifact",
				"type": "gear",
				"value": 500
			}
		],
		"rivals_change": 0,
		"patrons_change": 0,
		"quest_progress": "",
		"invasion_pending": true  # Triggers pulsing warning!
	}

	summary_sheet.setup(summary_data)

func _on_summary_continue_pressed() -> void:
	"""Handle continue button - transition to campaign dashboard"""
	print("Example: Transitioning to Campaign Dashboard...")
	# In real implementation:
	# get_tree().change_scene_to_file("res://src/ui/screens/campaign/CampaignDashboard.tscn")
