@tool
class_name TestDataFactory
extends RefCounted

## Test data factory for creating consistent test data across all test suites
## Replaces mock objects with real data structures that match production systems

# Five Parsecs rules-compliant test data

## Create a complete test character with Five Parsecs attributes
static func create_test_character(character_name: String = "Test Character", is_captain: bool = false) -> Dictionary:
	return {
		"character_name": character_name,
		"is_captain": is_captain,
		# Five Parsecs attributes (2-6 range, generated via 2d6/3 rounded up)
		"combat": 3,
		"reaction": 4,
		"toughness": 3,
		"savvy": 2,
		"tech": 2,
		"move": 4,
		# Five Parsecs character details
		"background": "Colonist",
		"motivation": "Escape",
		"species": "Human",
		"health": 5,  # toughness + 2
		"max_health": 5,
		"experience": 0,
		"skill_points": 0,
		"equipment": [],
		"relationships": [],
		"injuries": [],
		"story_connections": []
	}

## Create a complete captain with leadership abilities
static func create_test_captain(character_name: String = "Captain Test") -> Dictionary:
	var captain_data = create_test_character(character_name, true)
	captain_data.merge({
		"leadership_bonuses": {
			"crew_morale": 1,
			"mission_success": 0.1,
			"negotiation": 1
		},
		"special_abilities": [
			"Inspiring Presence",
			"Tactical Awareness",
			"Command Voice"
		],
		"command_experience": 5,
		"reputation": 2
	})
	return captain_data

## Create a balanced test crew following Five Parsecs rules
static func create_test_crew(size: int = 3, include_captain: bool = true) -> Dictionary:
	var crew_members = []
	
	if include_captain:
		crew_members.append(create_test_captain("Captain Alpha"))
	
	# Add crew members with different specializations
	var member_count = size - (1 if include_captain else 0)
	var specializations = ["Tech Specialist", "Heavy Gunner", "Scout", "Medic", "Engineer"]
	
	for i in range(member_count):
		var specialization = specializations[i % specializations.size()]
		var member = create_test_character("Crew Member %d" % (i + 1))
		
		# Customize based on specialization
		match specialization:
			"Tech Specialist":
				member.tech = 5
				member.savvy = 4
				member.background = "Academic"
			"Heavy Gunner":
				member.combat = 5
				member.toughness = 4
				member.background = "Military"
			"Scout":
				member.reaction = 5
				member.move = 5
				member.background = "Feral World"
			"Medic":
				member.savvy = 4
				member.tech = 3
				member.background = "Unity"
			"Engineer":
				member.tech = 4
				member.savvy = 3
				member.background = "Colony"
		
		crew_members.append(member)
	
	return {
		"members": crew_members,
		"size": size,
		"has_captain": include_captain,
		"completion_level": 0.95,
		"backend_generated": true,
		"crew_morale": 3,
		"cohesion": 2
	}

## Create test campaign configuration
static func create_test_campaign_config(campaign_name: String = "Test Campaign") -> Dictionary:
	return {
		"campaign_name": campaign_name,
		"difficulty_level": 2,
		"victory_condition": "escape",  # Five Parsecs victory conditions
		"story_track_enabled": true,
		"house_rules": {
			"advanced_reactions": true,
			"injury_tables": true,
			"expanded_weapons": false
		},
		"starting_credits": 1000,
		"starting_supplies": 50,
		"campaign_length": 25,  # Standard Five Parsecs campaign length
		"fringe_world_benefits": true
	}

## Create test ship following Five Parsecs rules
static func create_test_ship(ship_name: String = "Test Ship") -> Dictionary:
	return {
		"name": ship_name,
		"type": "light_freighter",  # Five Parsecs ship type
		"hull_points": 15,
		"fuel_capacity": 8,
		"cargo_capacity": 12,
		"weapon_mounts": 2,
		"upgrades": [
			"Improved Engines",
			"Better Armor",
			"Enhanced Sensors"
		],
		"current_damage": 0,
		"debt": 0,
		"insurance": false,
		"is_configured": true,
		"travel_range": 3,
		"maintenance_cost": 1
	}

## Create test equipment following Five Parsecs gear rules
static func create_test_equipment() -> Dictionary:
	return {
		"equipment": [
			{
				"name": "Military Rifle",
				"type": "weapon",
				"damage": "2d6",
				"range": 24,
				"shots": 1,
				"traits": ["Assault Weapon"],
				"value": 12
			},
			{
				"name": "Scrap Pistol",
				"type": "weapon", 
				"damage": "1d6",
				"range": 8,
				"shots": 2,
				"traits": ["Pistol"],
				"value": 4
			},
			{
				"name": "Combat Armor",
				"type": "armor",
				"protection": 2,
				"encumbrance": 1,
				"traits": ["Body Armor"],
				"value": 8
			},
			{
				"name": "Med-kit",
				"type": "consumable",
				"uses": 3,
				"effect": "heal_wound",
				"value": 6
			},
			{
				"name": "Scanner",
				"type": "gear",
				"function": "detect_enemies",
				"range": 12,
				"value": 15
			},
			{
				"name": "Stim Pack",
				"type": "consumable",
				"uses": 1,
				"effect": "+1 Reaction for battle",
				"value": 8
			}
		],
		"total_value": 53,
		"is_complete": true,
		"backend_generated": true,
		"generation_method": "balanced_loadout",
		"credits_remaining": 947
	}

## Create test mission following Five Parsecs mission structure
static func create_test_mission(mission_type: String = "patrol") -> Dictionary:
	return {
		"mission_id": "test_mission_%d" % Time.get_unix_time_from_system(),
		"name": "Test Patrol Mission",
		"description": "Patrol the local area and report any unusual activity.",
		"mission_type": mission_type,
		"difficulty": 2,
		"patron": "Local Authority",
		"location": "Frontier Settlement",
		"objective": "Complete patrol without casualties",
		"rewards": {
			"credits": 120,
			"experience": 1,
			"reputation": 1,
			"items": []
		},
		"risks": {
			"enemy_type": "Roving Gangs",
			"enemy_count": 3,
			"environmental_hazards": ["Difficult Terrain"]
		},
		"requirements": {
			"minimum_crew": 2,
			"equipment_needed": ["Weapons"],
			"skills_preferred": ["Combat", "Tactics"]
		},
		"time_limit": 3,  # turns
		"is_story_mission": false
	}

## Create test enemy following Five Parsecs rules
static func create_test_enemy(enemy_type: String = "Gang Fighter") -> Dictionary:
	return {
		"name": enemy_type,
		"type": "humanoid",
		"combat": 3,
		"toughness": 3,
		"speed": 4,
		"ai_type": "Aggressive",
		"weapons": ["Scrap Pistol"],
		"armor": 0,
		"special_rules": [],
		"motivation": "Loot",
		"panic_value": 2,
		"deployment_group": "Standard",
		"xp_value": 1
	}

## Create test story event following Five Parsecs story track
static func create_test_story_event() -> Dictionary:
	return {
		"event_id": "test_story_event_%d" % Time.get_unix_time_from_system(),
		"title": "Mysterious Signal",
		"description": "Your crew detects a strange signal coming from an abandoned facility.",
		"event_type": "investigation",
		"choices": [
			{
				"choice_text": "Investigate the signal source",
				"requirements": ["Tech 3+"],
				"outcomes": {
					"success": {
						"description": "You discover valuable salvage",
						"rewards": {"credits": 50, "experience": 1}
					},
					"failure": {
						"description": "The facility is trapped",
						"consequences": {"injury_risk": 1}
					}
				}
			},
			{
				"choice_text": "Report the signal to authorities",
				"requirements": [],
				"outcomes": {
					"success": {
						"description": "You receive a small reward for the tip",
						"rewards": {"credits": 20, "reputation": 1}
					}
				}
			},
			{
				"choice_text": "Ignore the signal and move on",
				"requirements": [],
				"outcomes": {
					"success": {
						"description": "You continue your journey safely",
						"rewards": {}
					}
				}
			}
		],
		"prerequisites": [],
		"consequences": [],
		"is_mandatory": false
	}

## Create test battle event
static func create_test_battle_event() -> Dictionary:
	return {
		"event_id": "test_battle_event_%d" % Time.get_unix_time_from_system(),
		"name": "Equipment Malfunction",
		"description": "A piece of equipment fails at a critical moment.",
		"trigger": "round_start",
		"target": "random_character",
		"effect": {
			"type": "equipment_failure",
			"duration": 1,
			"severity": "minor"
		},
		"resolution": {
			"auto_resolve": false,
			"skill_check": "Tech",
			"difficulty": 2
		}
	}

## Create test world/location
static func create_test_world() -> Dictionary:
	return {
		"name": "Test World",
		"type": "Colony World",
		"government": "Corporate",
		"traits": ["Peaceful", "High Tech"],
		"trade_goods": ["Electronics", "Refined Metals"],
		"population": 2000000,
		"tech_level": 4,
		"law_level": 3,
		"services": {
			"starport": true,
			"medical": true,
			"repair": true,
			"trade": true,
			"recruitment": false
		},
		"quest_rumors": 2,
		"patron_jobs": 3
	}

## Create complete campaign state for testing
static func create_complete_test_campaign() -> Dictionary:
	return {
		"config": create_test_campaign_config("Complete Test Campaign"),
		"crew": create_test_crew(4, true),
		"captain": create_test_captain("Captain Complete"),
		"ship": create_test_ship("Complete Test Ship"),
		"equipment": create_test_equipment(),
		"world": create_test_world(),
		"metadata": {
			"creation_timestamp": Time.get_unix_time_from_system(),
			"test_generated": true,
			"version": "1.0",
			"generator": "TestDataFactory"
		}
	}

## Create validation test data with known issues
static func create_invalid_test_data() -> Dictionary:
	return {
		"empty_crew": {
			"members": [],
			"size": 0,
			"has_captain": false
		},
		"invalid_character": {
			"character_name": "",  # Empty name
			"combat": 0,  # Invalid attribute (below 1)
			"toughness": 7,  # Invalid attribute (above 6)
			"is_captain": true
		},
		"broken_ship": {
			"hull_points": -5,  # Negative hull points
			"fuel_capacity": 0,  # No fuel capacity
			"name": ""  # Empty name
		},
		"invalid_config": {
			"campaign_name": "",  # Empty name
			"difficulty_level": 0,  # Invalid difficulty
			"victory_condition": "invalid_condition"
		}
	}

## Get random valid test data for fuzz testing
static func get_random_test_character() -> Dictionary:
	var names = ["Alex", "Jordan", "Casey", "Morgan", "Riley", "Taylor"]
	var backgrounds = ["Military", "Colonist", "Academic", "Unity", "Feral World"]
	var motivations = ["Escape", "Wealth", "Adventure", "Revenge", "Fame"]
	
	var character = create_test_character(names.pick_random())
	character.background = backgrounds.pick_random()
	character.motivation = motivations.pick_random()
	
	# Randomize attributes within Five Parsecs rules (2-6)
	character.combat = randi_range(2, 6)
	character.reaction = randi_range(2, 6)
	character.toughness = randi_range(2, 6)
	character.savvy = randi_range(2, 6)
	character.tech = randi_range(2, 6)
	character.move = randi_range(2, 6)
	character.health = character.toughness + 2
	character.max_health = character.health
	
	return character