class_name CharacterTransferService
extends RefCounted

## Handles character transfer between Five Parsecs campaigns:
##   - 5PFH ↔ Bug Hunt (Compendium pp.212-213)
##   - 5PFH → Planetfall (Planetfall pp.26-27)
##   - Bug Hunt → Planetfall (Planetfall pp.26-27)
##   - Planetfall → 5PFH (Planetfall p.164, varies by ending)
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
##
## Planetfall Import (5PFH/Bug Hunt → Planetfall, Planetfall pp.26-27):
##   - All ability scores keep. Luck → 1 KP per Luck point (5PFH). Tech → Savvy (Bug Hunt).
##   - 5PFH: personal equipment IF has Planetfall function. Bug Hunt: no equipment (military property).
##   - Up to 3 imported chars can receive Class Training (D6 aptitude test).
##   - Imported characters start as Loyal.
##   - Credits/Reputation have no value in Planetfall.

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


## ============================================================================
## PLANETFALL TRANSFERS (Planetfall pp.26-27, p.164)
## ============================================================================

func convert_to_planetfall(char_data: Dictionary, source: String = "5pfh") -> Dictionary:
	## Convert a 5PFH or Bug Hunt character for Planetfall import.
	## Source: "5pfh" or "bug_hunt"
	## Returns a Planetfall-compatible character dict (no class assigned yet — needs Class Training).
	var char_id: String = char_data.get("id", char_data.get("character_id", ""))

	var result := {
		"id": char_id,
		"name": char_data.get("name", char_data.get("character_name", "Unknown")),
		"class": "",  # Must be assigned via Class Training aptitude test
		"subspecies": "",
		"reactions": char_data.get("reactions", char_data.get("reaction", 1)),
		"speed": char_data.get("speed", 4),
		"combat_skill": char_data.get("combat_skill", char_data.get("combat", 0)),
		"toughness": char_data.get("toughness", 3),
		"savvy": char_data.get("savvy", 0),
		"xp": char_data.get("xp", 0),
		"kp": 0,
		"loyalty": "loyal",  # Imported characters start as Loyal (p.24)
		"motivation": "",
		"prior_experience": char_data.get("background", ""),
		"notable_event": "",
		"abilities": [],
		"is_imported": true,
		"source_campaign": source,
		"game_mode": "planetfall"
	}

	if source == "5pfh":
		# Luck → Kill Points: 1 KP per Luck point (Planetfall p.26)
		var luck: int = char_data.get("luck", 0)
		result.kp = luck
		# Personal equipment carries over IF it has Planetfall function
		# (Items that affect Seize Initiative have no function — Planetfall p.27)
		var equipment: Array = char_data.get("equipment", [])
		result["imported_equipment"] = equipment.duplicate(true)
	elif source == "bug_hunt":
		# Tech → Savvy conversion (Planetfall p.26)
		var tech: int = char_data.get("tech", char_data.get("savvy", 0))
		result.savvy = tech
		# Bug Hunt equipment is military property — not transferred (p.27)
		result["imported_equipment"] = []
		# Keep KP as-is
		result.kp = char_data.get("kp", char_data.get("kill_points", 0))

	return result


func attempt_class_training(char_data: Dictionary, desired_class: String = "") -> Dictionary:
	## Attempt the Class Training aptitude test for an imported character (Planetfall p.27).
	## Up to 3 characters total can be trained (1 per class).
	## Returns {success: bool, assigned_class: String, method: String}
	var background: String = char_data.get("prior_experience", "")
	var char_class: String = char_data.get("character_class", "")

	# Load auto-qualify data
	var classes_json := _load_planetfall_json("res://data/planetfall/character_classes.json")
	var training_data: Dictionary = classes_json.get("class_training", {})
	var auto_quals: Dictionary = training_data.get("auto_qualify_backgrounds", {})

	# Check auto-qualification
	for cls in auto_quals:
		var qualifying: Array = auto_quals[cls]
		if background in qualifying or char_class in qualifying:
			if desired_class.is_empty() or desired_class == cls:
				return {"success": true, "assigned_class": cls, "method": "auto_qualify"}

	# Manual aptitude test (D6)
	var dice := Engine.get_main_loop().root.get_node_or_null("/root/DiceManager") if Engine.get_main_loop() else null
	var roll: int
	if dice and dice.has_method("roll_d6"):
		roll = dice.roll_d6()
	else:
		roll = randi_range(1, 6)

	if roll <= 2:
		return {"success": false, "assigned_class": "", "method": "aptitude_test_failed", "roll": roll}
	elif roll == 3:
		# Random class assignment
		var class_roll: int = randi_range(1, 6)
		var assigned: String
		if class_roll <= 2:
			assigned = "trooper"
		elif class_roll <= 4:
			assigned = "scientist"
		else:
			assigned = "scout"
		return {"success": true, "assigned_class": assigned, "method": "aptitude_test_random", "roll": roll}
	else:  # 4-6
		var chosen: String = desired_class if not desired_class.is_empty() else "trooper"
		return {"success": true, "assigned_class": chosen, "method": "aptitude_test_choice", "roll": roll}


func convert_from_planetfall(char_data: Dictionary, ending: String = "") -> Dictionary:
	## Convert a Planetfall character for export to 5PFH (Planetfall p.164).
	## Export rules vary by campaign ending.
	var char_id: String = char_data.get("id", "")

	var result := {
		"id": char_id,
		"character_id": char_id,
		"name": char_data.get("name", "Unknown"),
		"character_name": char_data.get("name", "Unknown"),
		"game_mode": "standard",
		"reaction": char_data.get("reactions", 1),
		"speed": char_data.get("speed", 4),
		"combat": char_data.get("combat_skill", 0),
		"toughness": char_data.get("toughness", 3),
		"savvy": char_data.get("savvy", 0),
		"luck": 1,  # Restore base Luck
		"xp": char_data.get("xp", 0),
		"equipment": [],
		"status": "active",
		"transferred_from_planetfall": true,
		"planetfall_ending": ending
	}

	# Ending-specific bonuses (Planetfall p.164)
	match ending:
		"independence_won":
			result["bonus_ship"] = true
			result["ship_debt"] = 0
		"independence_lost":
			result["add_rival"] = "Enforcers"  # or Bounty Hunters
		"loyalty":
			result["bonus_ship"] = true
			result["bonus_credits"] = 0  # 2D6 pre-paid (rolled at transfer time)
		"isolation":
			result.luck += 1  # 1 character gains +1 Luck
		"ascension":
			result["gains_psionic"] = true  # 1 character gains psionic abilities

	# Each character can export only 1 artifact (p.164)
	# Planetfall-specific weapons cannot be replaced in other campaigns
	var imported_eq: Array = char_data.get("imported_equipment", [])
	if not imported_eq.is_empty():
		result.equipment = imported_eq.duplicate(true)

	return result


func _load_planetfall_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	return json.data if json.data is Dictionary else {}


## ============================================================================
## TACTICS TRANSFERS (Tactics rulebook p.184)
## ============================================================================

func validate_tactics_enlistment(character_data: Dictionary) -> Dictionary:
	## Check if a 5PFH character is eligible for Tactics enlistment.
	var game_mode: String = character_data.get("game_mode", "standard")
	if game_mode != "standard":
		return {
			"eligible": false,
			"reason": "Character must be from a standard 5PFH campaign",
		}
	var status: String = character_data.get("status", "active")
	if status != "active":
		return {
			"eligible": false,
			"reason": "Character must be active (not injured/dead)",
		}
	return {"eligible": true, "reason": "Eligible for Tactics transfer"}


func convert_to_tactics(
		char_data: Dictionary, source: String = "5pfh") -> Dictionary:
	## Convert a 5PFH or Bug Hunt character for Tactics.
	## Source: "5pfh", "bug_hunt", or "planetfall"
	## Tactics rulebook p.184:
	##   - Stats map directly
	##   - Combat Skill capped at +2
	##   - Each Luck → 1 KP (5PFH)
	##   - Training assigned: +1 (or +2 if military background)
	##   - Equipment is personal property for 5PFH, military for BH
	var char_id: String = char_data.get(
		"id", char_data.get("character_id", ""))

	var combat: int = char_data.get(
		"combat_skill", char_data.get("combat", 0))
	combat = mini(combat, 2)  # Capped at +2

	var toughness: int = char_data.get("toughness", 3)
	toughness = mini(toughness, 5)  # Capped at 5

	# Kill Points: Luck → KP (5PFH), keep KP (others)
	var kp: int = 1
	if source == "5pfh":
		var luck: int = char_data.get("luck", 0)
		kp = maxi(luck, 1)
	elif source == "bug_hunt":
		kp = char_data.get("kp", char_data.get("kill_points", 1))
	elif source == "planetfall":
		kp = maxi(char_data.get("kp", 1) - 1, 1)  # KP -1 (p.184)

	# Training: +1 default, +2 if military background
	var training: int = 1
	var background: String = char_data.get(
		"background", char_data.get("prior_experience", ""))
	var military_backgrounds := [
		"Military Brat", "War-Torn Hell Hole", "Soldier",
		"Mercenary", "Enforcer", "Army", "Freelancer", "Bug Hunter"]
	for mb in military_backgrounds:
		if mb.to_lower() in background.to_lower():
			training = 2
			break

	var result := {
		"id": char_id,
		"name": char_data.get(
			"name", char_data.get("character_name", "Unknown")),
		"game_mode": "tactics",
		"speed": char_data.get("speed", 4),
		"reactions": char_data.get(
			"reactions", char_data.get("reaction", 2)),
		"combat_skill": combat,
		"toughness": toughness,
		"kill_points": kp,
		"savvy": char_data.get("savvy", 0),
		"training": training,
		"saving_throw": 0,
		"is_imported": true,
		"source_campaign": source,
		"transferred_from_5pfh": source == "5pfh",
		"transferred_from_bug_hunt": source == "bug_hunt",
		"transferred_from_planetfall": source == "planetfall",
	}

	# Equipment transfer rules
	if source == "5pfh":
		# Personal equipment carries over
		result["imported_equipment"] = char_data.get(
			"equipment", []).duplicate(true)
	else:
		# Bug Hunt / Planetfall: military property, not transferred
		result["imported_equipment"] = []

	return result


func convert_from_tactics(char_data: Dictionary) -> Dictionary:
	## Convert a Tactics character for export to 5PFH.
	## Tactics rulebook p.184:
	##   - Stats keep (except Training — not used in 5PFH)
	##   - Each KP after 1st → 1 Luck
	##   - Veteran Skills retained when applicable
	##   - Equipment is military property — not transferred
	var char_id: String = char_data.get("id", "")

	var kp: int = char_data.get(
		"kill_points", char_data.get("kp", 1))
	var luck: int = maxi(kp - 1, 0)  # Each KP after 1st → 1 Luck

	return {
		"id": char_id,
		"character_id": char_id,
		"name": char_data.get("name", "Unknown"),
		"character_name": char_data.get("name", "Unknown"),
		"game_mode": "standard",
		"reaction": char_data.get("reactions", 2),
		"speed": char_data.get("speed", 4),
		"combat": char_data.get("combat_skill", 0),
		"toughness": char_data.get("toughness", 3),
		"savvy": char_data.get("savvy", 0),
		"luck": luck,
		"xp": 0,
		"equipment": [],  # Military property — not transferred
		"status": "active",
		"transferred_from_tactics": true,
	}
