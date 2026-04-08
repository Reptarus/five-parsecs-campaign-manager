class_name CharacterTransferService
extends RefCounted

## Handles character transfer between standard Five Parsecs and Bug Hunt campaigns.
##
## Enlistment (5PFH → Bug Hunt, Compendium p.212):
##   - Roll 2D6 + Combat Skill: need 7+ to succeed
##   - All equipment stashed (except one Pistol)
##   - Stats carry over, game_mode set to "bug_hunt"
##   - completed_missions/reputation reset to 0
##
## Mustering Out (Bug Hunt → 5PFH):
##   - Military equipment stripped
##   - Stats carry over, game_mode set to "standard"
##   - Luck stat restored to base value
##   - Added as new crew member in target campaign

const ENLISTMENT_TARGET := 7  # 2D6 + Combat Skill >= 7+ (Compendium p.212)

## Stashed equipment storage: character_id -> Array of equipment dicts
var _stashed_equipment: Dictionary = {}


func validate_enlistment(character_data: Dictionary) -> Dictionary:
	## Check if a standard character is eligible for Bug Hunt enlistment.
	## Returns {eligible: bool, reason: String, combat_bonus: int}
	var game_mode: String = character_data.get("game_mode", "standard")
	if game_mode != "standard":
		return {"eligible": false, "reason": "Character is already in Bug Hunt mode", "combat_bonus": 0}

	var status: String = character_data.get("status", "active")
	if status != "active":
		return {"eligible": false, "reason": "Character must be active (not injured/dead)", "combat_bonus": 0}

	var combat: int = character_data.get("combat_skill", character_data.get("combat", 0))
	return {"eligible": true, "reason": "Eligible", "combat_bonus": combat}


func attempt_enlistment(character_data: Dictionary) -> Dictionary:
	## Roll 2D6 + Combat Skill. On 8+, character enlists as Bug Hunter.
	## Returns {success: bool, roll: int, target: int, transferred_character: Dictionary}
	var validation := validate_enlistment(character_data)
	if not validation.eligible:
		return {"success": false, "roll": 0, "target": ENLISTMENT_TARGET, "reason": validation.reason}

	var combat_bonus: int = validation.combat_bonus
	var die1: int = (randi() % 6) + 1
	var die2: int = (randi() % 6) + 1
	var total: int = die1 + die2 + combat_bonus
	var success: bool = total >= ENLISTMENT_TARGET

	if not success:
		return {
			"success": false,
			"roll": total,
			"dice": [die1, die2],
			"combat_bonus": combat_bonus,
			"target": ENLISTMENT_TARGET,
			"reason": "Enlistment rejected (rolled %d+%d+%d=%d, needed %d)" % [die1, die2, combat_bonus, total, ENLISTMENT_TARGET]
		}

	# Transfer successful — create Bug Hunt version
	var transferred := _convert_to_bug_hunt(character_data)

	return {
		"success": true,
		"roll": total,
		"dice": [die1, die2],
		"combat_bonus": combat_bonus,
		"target": ENLISTMENT_TARGET,
		"transferred_character": transferred,
		"stashed_equipment": _stashed_equipment.get(character_data.get("id", character_data.get("character_id", "")), [])
	}


func validate_muster_out(character_data: Dictionary) -> Dictionary:
	## Check if a Bug Hunt character is eligible for mustering out to 5PFH.
	var game_mode: String = character_data.get("game_mode", "standard")
	if game_mode != "bug_hunt":
		return {"eligible": false, "reason": "Character is not in Bug Hunt mode"}

	if character_data.get("is_grunt", false):
		return {"eligible": false, "reason": "Grunts cannot muster out to individual campaigns"}

	var status: String = character_data.get("status", "active")
	if status != "active":
		return {"eligible": false, "reason": "Character must be active"}

	return {"eligible": true, "reason": "Eligible for transfer"}


func muster_out(character_data: Dictionary) -> Dictionary:
	## Transfer a Bug Hunt character to a standard Five Parsecs campaign.
	## Returns {success: bool, transferred_character: Dictionary}
	var validation := validate_muster_out(character_data)
	if not validation.eligible:
		return {"success": false, "reason": validation.reason}

	var transferred := _convert_to_standard(character_data)
	return {
		"success": true,
		"transferred_character": transferred
	}


func get_stashed_equipment(character_id: String) -> Array:
	## Retrieve equipment stashed when a character enlisted.
	return _stashed_equipment.get(character_id, [])


func _convert_to_bug_hunt(char_data: Dictionary) -> Dictionary:
	## Strip equipment, keep stats, change game_mode.
	var char_id: String = char_data.get("id", char_data.get("character_id", ""))

	# Stash all equipment except pistols
	var all_equipment: Array = char_data.get("equipment", [])
	var stashed: Array = []
	var kept_pistol: bool = false

	for item in all_equipment:
		var item_name: String = ""
		if item is Dictionary:
			item_name = item.get("name", item.get("id", "")).to_lower()
		elif item is String:
			item_name = item.to_lower()

		if not kept_pistol and ("pistol" in item_name):
			kept_pistol = true
			# Keep this pistol
		else:
			stashed.append(item)

	_stashed_equipment[char_id] = stashed

	# Build transferred character
	return {
		"id": char_id,
		"character_id": char_id,
		"name": char_data.get("name", char_data.get("character_name", "Unknown")),
		"character_name": char_data.get("name", char_data.get("character_name", "Unknown")),
		"game_mode": "bug_hunt",
		"is_grunt": false,
		"reactions": char_data.get("reactions", char_data.get("reaction", 1)),
		"speed": char_data.get("speed", 4),
		"combat_skill": char_data.get("combat_skill", char_data.get("combat", 0)),
		"toughness": char_data.get("toughness", 3),
		"savvy": char_data.get("savvy", 0),
		"luck": 0,  # Bug Hunt doesn't use Luck
		"xp": 0,
		"completed_missions_count": 0,
		"reputation_contribution": 0,
		"muster_number": 0,
		"equipment": ["service_pistol", "trooper_armor"],
		"origin": "Transfer from %s" % char_data.get("species", "Unknown"),
		"status": "active",
		"transferred_from_campaign": true
	}


func _convert_to_standard(char_data: Dictionary) -> Dictionary:
	## Mustering Out to 5PFH — Compendium p.213
	## - Retain profile and unused XP
	## - Retain Service Pistol if 10+ Completed Missions
	## - 1 Credit per 2 Completed Missions
	## - +1 Story Point
	## - Add Sector Government Patron to contacts
	var char_id: String = char_data.get("id", char_data.get("character_id", ""))
	var completed_missions: int = char_data.get("completed_missions_count", 0)

	# Restore stashed equipment if available
	var restored_equipment: Array = get_stashed_equipment(char_id)

	# Retain Service Pistol only if 10+ completed missions (Compendium p.213)
	if completed_missions >= 10:
		var has_pistol := false
		for item in restored_equipment:
			var item_name: String = ""
			if item is Dictionary:
				item_name = item.get("name", item.get("id", "")).to_lower()
			elif item is String:
				item_name = item.to_lower()
			if "service pistol" in item_name or "service_pistol" in item_name:
				has_pistol = true
				break
		if not has_pistol:
			restored_equipment.append({"id": "service_pistol", "name": "Service Pistol"})

	# Mustering out benefit: 1 Credit per 2 Completed Missions
	var mustering_credits: int = completed_missions / 2

	return {
		"id": char_id,
		"character_id": char_id,
		"name": char_data.get("name", char_data.get("character_name", "Unknown")),
		"character_name": char_data.get("name", char_data.get("character_name", "Unknown")),
		"game_mode": "standard",
		"is_grunt": false,
		"reaction": char_data.get("reactions", 1),
		"speed": char_data.get("speed", 4),
		"combat": char_data.get("combat_skill", 0),
		"toughness": char_data.get("toughness", 3),
		"savvy": char_data.get("savvy", 0),
		"luck": 1,  # Restore base Luck for standard campaigns
		"xp": char_data.get("xp", 0),
		"equipment": restored_equipment,
		"status": "active",
		"transferred_from_bug_hunt": true,
		"bug_hunt_missions_completed": completed_missions,
		# Mustering out rewards (Compendium p.213)
		"mustering_credits": mustering_credits,
		"bonus_story_points": 1,
		"add_sector_government_patron": true
	}


## ============================================================================
## PENDING TRANSFER PERSISTENCE (user://transfers/)
## ============================================================================

static func load_pending_transfers() -> Array:
	## Load all pending transfer files from user://transfers/.
	## Returns Array of validated transfer Dictionaries.
	var transfers: Array = []
	var dir := DirAccess.open("user://transfers/")
	if not dir:
		return transfers

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path := "user://transfers/" + file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var data = JSON.parse_string(file.get_as_text())
				file.close()
				if _validate_transfer_data(data):
					data["_file_path"] = path
					transfers.append(data)
		file_name = dir.get_next()
	dir.list_dir_end()
	return transfers


static func _validate_transfer_data(data) -> bool:
	## Validate a transfer file has required fields and safe types.
	if not data is Dictionary:
		return false
	if not data.has("character") or not data.character is Dictionary:
		return false
	var char_dict: Dictionary = data.character
	# Must have an ID
	if not char_dict.has("id") and not char_dict.has("character_id"):
		return false
	# Must have core stats
	for stat in ["toughness", "speed"]:
		if not char_dict.has(stat):
			return false
	# Rewards must be non-negative if present
	var credits = data.get("mustering_credits", 0)
	if not (credits is int or credits is float) or credits < 0:
		return false
	var sp = data.get("bonus_story_points", 0)
	if not (sp is int or sp is float) or sp < 0:
		return false
	return true


static func apply_transfer_rewards(
		campaign, transfer_data: Dictionary) -> Dictionary:
	## Apply mustering-out rewards to a standard campaign.
	## Returns {success: bool, character: Dictionary, summary: String}.
	## IMPORTANT: deep-copies the character to prevent shared references.
	if not campaign:
		return {"success": false, "summary": "No campaign provided"}

	var char_data: Dictionary = transfer_data.get("character", {})
	if char_data.is_empty():
		return {"success": false, "summary": "No character data in transfer"}

	# Deep copy to prevent cross-campaign reference sharing
	var safe_char: Dictionary = char_data.duplicate(true)

	var summary_parts: Array = []

	# Apply credits (Compendium p.213: 1 credit per 2 completed missions)
	var credits: int = int(transfer_data.get("mustering_credits", 0))
	if credits > 0:
		var gsm = Engine.get_main_loop().root.get_node_or_null(
			"/root/GameStateManager") if Engine.get_main_loop() else null
		if gsm and gsm.has_method("add_credits"):
			gsm.add_credits(credits)
		summary_parts.append("+%d credits" % credits)

	# Apply Story Points
	var sp: int = int(transfer_data.get("bonus_story_points", 0))
	if sp > 0:
		summary_parts.append("+%d Story Point(s)" % sp)

	# Sector Government Patron
	if transfer_data.get("add_sector_government_patron", false):
		summary_parts.append("+Sector Government Patron")

	# Delete the transfer file to prevent double-import
	var file_path: String = transfer_data.get("_file_path", "")
	if not file_path.is_empty() and FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)

	return {
		"success": true,
		"character": safe_char,
		"summary": ", ".join(summary_parts) if not summary_parts.is_empty() else "Character transferred"
	}
