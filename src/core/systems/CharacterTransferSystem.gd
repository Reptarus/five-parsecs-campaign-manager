class_name CharacterTransferSystem
extends RefCounted

## CharacterTransferSystem
##
## Handles character transfers between Five Parsecs and Bug Hunt campaigns.
## Converts skills, equipment, and backgrounds while maintaining character progression.
##
## Usage:
##   var transfer = CharacterTransferSystem.new()
##   var soldier = transfer.convert_parsecs_to_bughunt(parsecs_character)
##   var spacer = transfer.convert_bughunt_to_parsecs(soldier)

signal transfer_completed(character: Dictionary, from_mode: String, to_mode: String)
signal conversion_warning(message: String)

## Skill conversion tables
const PARSECS_TO_BUGHUNT_SKILLS := {
	"combat_skill": "combat_skill",    # Direct 1:1
	"reactions": "reactions",          # Direct 1:1
	"speed": "speed",                  # Direct 1:1
	"toughness": "toughness",          # Direct 1:1
	"savvy": "savvy"                   # Direct 1:1
}

const BUGHUNT_TO_PARSECS_SKILLS := {
	"combat_skill": "combat_skill",
	"reactions": "reactions",
	"speed": "speed",
	"toughness": "toughness",
	"savvy": "savvy"
}

## Equipment conversion rate (Bug Hunt equipment → Credits)
const EQUIPMENT_TO_CREDITS_RATE := 0.5 # Sell for 50% value

## Convert Five Parsecs character to Bug Hunt soldier
func convert_parsecs_to_bughunt(parsecs_character: Dictionary) -> Dictionary:
	print("CharacterTransferSystem: Converting Five Parsecs character to Bug Hunt soldier...")

	# Create base soldier structure
	var soldier := {
		"id": _generate_soldier_id(),
		"name": parsecs_character.get("name", "Transferred Soldier"),
		"rank": "Private", # Start as Private

		# CORE STATS - Direct transfer (same system!)
		"reactions": parsecs_character.get("reactions", 1),
		"speed": parsecs_character.get("speed", 4),
		"combat_skill": parsecs_character.get("combat_skill", 0),
		"toughness": parsecs_character.get("toughness", 3),
		"savvy": parsecs_character.get("savvy", 0),

		# Transfer XP and level
		"xp": parsecs_character.get("xp", 0),
		"level": parsecs_character.get("level", 1),

		# Bug Hunt specific
		"morale": 10,
		"specialization": _convert_background_to_specialization(parsecs_character),
		"background": "Veteran Spacer", # Special background for transfers
		"kills": 0,

		# Equipment converted to starting loadout
		"equipment": ["Pulse Rifle", "Combat Armor", "Med Kit"],

		# Track original campaign
		"transferred_from": "five_parsecs",
		"original_character_id": parsecs_character.get("id", "")
	}

	# Convert special abilities if any
	if parsecs_character.has("abilities"):
		soldier.transferred_abilities = parsecs_character.abilities.duplicate()

	# Award bonus credits for sold equipment
	var equipment_value := _calculate_equipment_value(parsecs_character)
	soldier.bonus_credits = int(equipment_value * EQUIPMENT_TO_CREDITS_RATE)

	print("CharacterTransferSystem: %s converted. Level %d, Bonus Credits: %d" % [
		soldier.name,
		soldier.level,
		soldier.bonus_credits
	])

	transfer_completed.emit(soldier, "five_parsecs", "bug_hunt")
	return soldier

## Convert Bug Hunt soldier to Five Parsecs character
func convert_bughunt_to_parsecs(soldier: Dictionary) -> Dictionary:
	print("CharacterTransferSystem: Converting Bug Hunt soldier to Five Parsecs character...")

	# Create base character structure
	var character := {
		"id": _generate_character_id(),
		"name": soldier.get("name", "Transferred Spacer"),

		# CORE STATS - Direct transfer (same system!)
		"reactions": soldier.get("reactions", 1),
		"speed": soldier.get("speed", 4),
		"combat_skill": soldier.get("combat_skill", 0),
		"toughness": soldier.get("toughness", 3),
		"savvy": soldier.get("savvy", 0),

		# Transfer XP and level
		"xp": soldier.get("xp", 0),
		"level": soldier.get("level", 1),

		# Five Parsecs specific
		"luck": 0,
		"background": _generate_military_veteran_background(soldier),
		"motivation": "Survival", # Military survivors focus on survival
		"class": _convert_specialization_to_class(soldier),

		# Equipment - start with military gear access
		"equipment": _generate_veteran_equipment(soldier),

		# Track original campaign
		"transferred_from": "bug_hunt",
		"original_soldier_id": soldier.get("id", ""),
		"military_service": true # Unlocks military equipment
	}

	# Convert rank to story points
	var rank_bonus := _convert_rank_to_story_points(soldier)
	character.story_points = rank_bonus

	# Award bonus credits for military service
	character.credits = _calculate_military_severance_pay(soldier)

	print("CharacterTransferSystem: %s converted. Level %d, Credits: %d, Story Points: %d" % [
		character.name,
		character.level,
		character.credits,
		character.story_points
	])

	transfer_completed.emit(character, "bug_hunt", "five_parsecs")
	return character

## Validate character can be transferred
func can_transfer(character: Dictionary, from_mode: String) -> Dictionary:
	var result := {
		"can_transfer": true,
		"requirements_met": true,
		"warnings": [],
		"requirements": []
	}

	# Minimum level requirement
	var min_level := 2 # Must be at least level 2
	if character.get("level", 1) < min_level:
		result.can_transfer = false
		result.requirements_met = false
		result.requirements.append("Character must be level %d or higher" % min_level)

	# Cannot transfer if character is injured (Bug Hunt only)
	if from_mode == "bug_hunt":
		if character.has("injuries") and character.injuries.size() > 0:
			result.warnings.append("Character has injuries - will be healed on transfer")

	# Cannot transfer if character is dead
	if character.get("is_dead", false):
		result.can_transfer = false
		result.requirements_met = false
		result.requirements.append("Cannot transfer dead character")

	# Maximum one transfer per campaign
	if character.has("transferred_from"):
		result.warnings.append("Character has already been transferred once")

	return result

## Get transfer preview (show what will happen)
func get_transfer_preview(character: Dictionary, to_mode: String) -> Dictionary:
	var preview := {
		"character_name": character.get("name", "Unknown"),
		"current_level": character.get("level", 1),
		"stats_transferred": "All stats transfer 1:1",
		"equipment_changes": [],
		"special_bonuses": [],
		"warnings": []
	}

	if to_mode == "bug_hunt":
		# Five Parsecs → Bug Hunt
		preview.equipment_changes.append("Equipment sold for %d credits" %
			int(_calculate_equipment_value(character) * EQUIPMENT_TO_CREDITS_RATE))
		preview.equipment_changes.append("Receives standard military loadout (Pulse Rifle, Combat Armor, Med Kit)")
		preview.special_bonuses.append("Gains 'Veteran Spacer' background")
		preview.special_bonuses.append("Starts as Private rank")

	else:
		# Bug Hunt → Five Parsecs
		var rank: String = character.get("rank", "Private")
		var rank_bonus := _convert_rank_to_story_points(character)
		preview.equipment_changes.append("Receives veteran military equipment")
		preview.special_bonuses.append("Gains 'Military Veteran' background")
		preview.special_bonuses.append("Receives %d story points (rank: %s)" % [rank_bonus, rank])
		preview.special_bonuses.append("Unlocks military equipment access")
		preview.special_bonuses.append("Receives %d credits severance pay" % _calculate_military_severance_pay(character))

	return preview

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _convert_background_to_specialization(character: Dictionary) -> String:
	# Convert Five Parsecs background to Bug Hunt specialization
	var background: String = character.get("background", "")

	# Map backgrounds to specializations
	if "military" in background.to_lower() or "soldier" in background.to_lower():
		return "Standard"
	elif "tech" in background.to_lower() or "engineer" in background.to_lower():
		return "Support"
	elif "criminal" in background.to_lower() or "thug" in background.to_lower():
		return "CQB"
	elif "scout" in background.to_lower() or "explorer" in background.to_lower():
		return "Reconnaissance"
	else:
		return "Standard"

func _convert_specialization_to_class(soldier: Dictionary) -> String:
	# Convert Bug Hunt specialization to Five Parsecs class
	var specialization: String = soldier.get("specialization", "Standard")

	match specialization:
		"Standard":
			return "Soldier"
		"Heavy Weapons":
			return "Gunfighter"
		"CQB":
			return "Brawler"
		"Reconnaissance":
			return "Scout"
		"Support":
			return "Technician"
		_:
			return "Soldier"

func _generate_military_veteran_background(soldier: Dictionary) -> String:
	var rank: String = soldier.get("rank", "Private")
	return "Military Veteran (%s)" % rank

func _generate_veteran_equipment(soldier: Dictionary) -> Array:
	# Military veterans get access to military-grade gear
	var equipment := [
		"Military Rifle", # Similar to Pulse Rifle
		"Armor Vest",     # Similar to Combat Armor
		"Frag Grenade"    # Military equipment
	]

	return equipment

func _convert_rank_to_story_points(soldier: Dictionary) -> int:
	var rank: String = soldier.get("rank", "Private")

	match rank:
		"Private":
			return 0
		"Corporal":
			return 1
		"Sergeant":
			return 2
		"Lieutenant":
			return 3
		"Captain":
			return 5
		_:
			return 0

func _calculate_military_severance_pay(soldier: Dictionary) -> int:
	# Base pay
	var pay := 10

	# Bonus for rank
	var rank: String = soldier.get("rank", "Private")
	match rank:
		"Corporal":
			pay += 5
		"Sergeant":
			pay += 10
		"Lieutenant":
			pay += 20
		"Captain":
			pay += 30

	# Bonus for kills
	var kills := soldier.get("kills", 0)
	pay += int(kills / 5) * 2

	# Bonus for level
	pay += soldier.get("level", 1) * 3

	return pay

func _calculate_equipment_value(character: Dictionary) -> int:
	var total_value := 0
	var equipment: Array = character.get("equipment", [])

	# Simplified equipment value calculation
	for item in equipment:
		# Estimate value based on item type
		if item is String:
			if "rifle" in item.to_lower() or "gun" in item.to_lower():
				total_value += 10
			elif "armor" in item.to_lower():
				total_value += 8
			elif "blade" in item.to_lower() or "sword" in item.to_lower():
				total_value += 5
			else:
				total_value += 3

	return total_value

func _generate_soldier_id() -> String:
	return "soldier_transfer_%d" % Time.get_ticks_msec()

func _generate_character_id() -> String:
	return "character_transfer_%d" % Time.get_ticks_msec()
