class_name PostBattleContext
extends RefCounted

## Shared context for PostBattlePhase subsystems.
## Holds autoload references, campaign state, and cross-cutting helper methods.
## Passed to each subsystem so RefCounted classes can access the scene tree indirectly.

# Preloaded class references (same as PostBattlePhase.gd)
const InjuryConstants = preload("res://src/core/systems/InjurySystemConstants.gd")
const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")
const CharacterRef = preload("res://src/core/character/Character.gd")
const RedZoneSystemRef = preload("res://src/core/mission/RedZoneSystem.gd")
const BlackZoneSystemRef = preload("res://src/core/mission/BlackZoneSystem.gd")

# Autoload references (resolved by PostBattlePhase orchestrator in _ready())
var dice_manager: Variant = null
var game_state_manager: Variant = null
var game_state: Variant = null
var planet_data_manager: Variant = null
var campaign_journal: Variant = null
var equipment_manager: Variant = null
var dlc_manager: Variant = null
var galactic_war_manager: Variant = null

# Campaign and battle state (set per start_post_battle_phase() call)
var campaign: Variant = null
var battle_result: Dictionary = {}
var crew_participants: Array = []
var defeated_enemies: Array = []
var injuries_sustained: Array = []
var loot_earned: Array = []
var mission_successful: bool = false
var enemies_defeated: int = 0

# --- Dice Helpers ---

func roll_d6(context: String = "D6 Roll") -> int:
	if dice_manager and dice_manager.has_method("roll_d6"):
		return dice_manager.roll_d6(context)
	return randi_range(1, 6)

func roll_2d6(context: String = "2D6 Roll") -> int:
	if dice_manager and dice_manager.has_method("roll_d6"):
		return dice_manager.roll_d6(context + " (die 1)") + dice_manager.roll_d6(context + " (die 2)")
	return randi_range(1, 6) + randi_range(1, 6)

func roll_d100(context: String = "D100 Roll") -> int:
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(1, 100, context)
	return randi_range(1, 100)

# --- Campaign Config Access ---

func get_campaign_config(key: String, default_value: Variant = null) -> Variant:
	if campaign:
		match key:
			"difficulty":
				if campaign.has_method("get") and campaign.get("difficulty") != null:
					return campaign.difficulty
				elif "difficulty" in campaign:
					return campaign.difficulty
			"house_rules":
				if campaign.has_method("get_house_rules"):
					return campaign.get_house_rules()
				elif "house_rules" in campaign:
					return campaign.house_rules
			"victory_conditions":
				if campaign.has_method("get_victory_conditions"):
					return campaign.get_victory_conditions()
				elif "victory_conditions" in campaign:
					return campaign.victory_conditions
			"story_track_enabled":
				if campaign.has_method("get_story_track_enabled"):
					return campaign.get_story_track_enabled()
				elif "story_track_enabled" in campaign:
					return campaign.story_track_enabled
	# Fallback to GameStateManager
	if game_state_manager:
		match key:
			"difficulty":
				if game_state_manager.has_method("get_difficulty_level"):
					return game_state_manager.get_difficulty_level()
			"house_rules":
				if game_state_manager.has_method("get_house_rules"):
					return game_state_manager.get_house_rules()
			"victory_conditions":
				if game_state_manager.has_method("get_victory_conditions"):
					return game_state_manager.get_victory_conditions()
			"story_track_enabled":
				if game_state_manager.has_method("get_story_track_enabled"):
					return game_state_manager.get_story_track_enabled()
	return default_value

func get_runtime_state(key: String, default_value: Variant = null) -> Variant:
	if game_state_manager:
		match key:
			"credits":
				if game_state_manager.has_method("get_credits"):
					return game_state_manager.get_credits()
			"turn_number":
				if "turn_number" in game_state_manager:
					return game_state_manager.turn_number
			"current_location":
				if game_state_manager.has_method("get_current_location"):
					return game_state_manager.get_current_location()
			"story_points":
				if game_state_manager.has_method("get_story_points"):
					return game_state_manager.get_story_points()
			"crew_size":
				if game_state_manager.has_method("get_crew_size"):
					return game_state_manager.get_crew_size()
	return default_value

func get_campaign_difficulty() -> int:
	if game_state_manager:
		if game_state_manager.has_method("get_difficulty"):
			return game_state_manager.get_difficulty()
		elif game_state_manager.has_method("get_game_state"):
			var gs = game_state_manager.get_game_state()
			if gs:
				if "difficulty" in gs:
					return gs.difficulty
				elif "difficulty_level" in gs:
					return gs.difficulty_level
	return 1

# --- Crew Helpers ---

func get_crew_members() -> Array:
	## Get crew members via campaign or game state
	var crew: Array = []
	if campaign:
		if campaign.has_method("get_crew_members"):
			crew = campaign.get_crew_members()
		elif campaign is Dictionary:
			crew = campaign.get("crew", [])
		elif "crew_members" in campaign:
			crew = campaign.crew_members
	if crew.is_empty() and game_state and game_state.current_campaign:
		var gc = game_state.current_campaign
		if gc.has_method("get_crew_members"):
			crew = gc.get_crew_members()
		elif gc is Dictionary:
			crew = gc.get("crew", [])
	return crew

func get_random_crew_member() -> Variant:
	if crew_participants.size() > 0:
		return crew_participants[randi() % crew_participants.size()]
	var crew := get_crew_members()
	if crew.size() > 0:
		return crew[randi() % crew.size()]
	return null

func get_participating_crew() -> Array:
	var crew: Array = []
	if not crew_participants.is_empty():
		if game_state_manager and game_state_manager.has_method("get_crew_member"):
			for participant_id in crew_participants:
				var member = game_state_manager.get_crew_member(participant_id)
				if member:
					crew.append(member)
		return crew
	if game_state_manager and game_state_manager.has_method("get_crew_members"):
		crew = game_state_manager.get_crew_members()
	elif game_state_manager and game_state_manager.has_method("get_game_state"):
		var gs = game_state_manager.get_game_state()
		if gs and gs.has_method("get_crew"):
			crew = gs.get_crew()
		elif gs and gs.current_campaign and gs.current_campaign is Dictionary:
			crew = gs.current_campaign.get("crew", [])
	else:
		if game_state and game_state.current_campaign:
			if game_state.current_campaign is Dictionary:
				crew = game_state.current_campaign.get("crew", [])
	return crew

func is_crew_member_bot(crew_id: String) -> bool:
	var crew := get_crew_members()
	for member in crew:
		var member_id: String = ""
		if "character_id" in member:
			member_id = member.character_id
		elif member is Dictionary:
			member_id = member.get("id", member.get("character_id", ""))
		if member_id == crew_id:
			var char_class: String = ""
			if "character_class" in member:
				char_class = str(member.character_class)
			elif member is Dictionary:
				char_class = member.get("class", member.get("character_class", ""))
			return char_class == "Bot" or char_class == "BOT"
	return false

func get_character_origin(character: Variant) -> String:
	## Get the origin/species of a character (Core Rules species: Human, K'Erin, Swift, Engineer, Soulless, Precursor, Feral, Bot)
	if "origin" in character:
		return str(character.origin)
	elif character is Dictionary:
		return character.get("origin", character.get("species", "Human"))
	return "Human"

func has_crew_with_origin(origin_name: String) -> bool:
	## Check if any crew member has the given origin/species
	var crew := get_crew_members()
	for member in crew:
		if get_character_origin(member).to_lower() == origin_name.to_lower():
			return true
	return false

func is_character_bot_or_soulless(character: Variant) -> bool:
	## Check if character is Bot or Soulless (excluded from character events per Core Rules p.128)
	var origin: String = get_character_origin(character).to_lower()
	return origin == "bot" or origin == "soulless"

func has_crew_with_class(character_class: String) -> bool:
	var crew := get_crew_members()
	for member in crew:
		var member_class: String = ""
		if "character_class" in member:
			member_class = member.character_class
		elif member is Dictionary:
			member_class = member.get("class", member.get("character_class", ""))
		if member_class == character_class:
			return true
	return false

# --- Campaign Mutation Helpers ---

func add_quest_rumor() -> void:
	var gc = _get_current_campaign()
	if gc == null:
		return
	if gc is Dictionary:
		var rumors: Array = gc.get("rumors", [])
		var rumor_types: Array = [
			"An extracted data file",
			"Notebook with secret information",
			"Old map showing a location",
			"A tip from a contact",
			"An intercepted transmission"
		]
		var roll: int = randi() % rumor_types.size()
		rumors.append({
			"id": "rumor_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
			"type": roll + 1,
			"description": rumor_types[roll],
			"source": "event"
		})
		gc["rumors"] = rumors

func remove_quest_rumor() -> void:
	var gc = _get_current_campaign()
	if gc == null:
		return
	if gc is Dictionary:
		var rumors: Array = gc.get("rumors", [])
		if rumors.size() > 0:
			rumors.remove_at(randi() % rumors.size())
			gc["rumors"] = rumors

func add_rival(rival_name: String) -> void:
	var gc = _get_current_campaign()
	if gc == null:
		return
	if gc is Dictionary:
		var rivals: Array = gc.get("rivals", [])
		var rival_id: String = "rival_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
		rivals.append({
			"id": rival_id,
			"name": rival_name,
			"type": ["Criminal", "Corporate", "Personal", "Gang"][randi() % 4],
			"hostility": randi_range(3, 5),
			"resources": randi_range(1, 3),
			"source": "event"
		})
		gc["rivals"] = rivals
		if planet_data_manager and planet_data_manager.current_planet_id != "":
			planet_data_manager.add_contact_to_planet(planet_data_manager.current_planet_id, rival_id)

func remove_random_patron() -> void:
	var gc = _get_current_campaign()
	if gc == null:
		return
	if gc is Dictionary:
		var patrons: Array = gc.get("patrons", [])
		if patrons.size() > 0:
			patrons.remove_at(randi() % patrons.size())
			gc["patrons"] = patrons

func add_patron() -> void:
	var gc = _get_current_campaign()
	if gc == null:
		return
	if gc is Dictionary:
		var patrons: Array = gc.get("patrons", [])
		var patron_types: Array = ["Corporate", "Government", "Criminal", "Private", "Mercenary"]
		var patron_names: Array = ["The Broker", "Lady Silver", "Commander Vex", "Old Sal", "The Collector"]
		var patron_id: String = "patron_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
		patrons.append({
			"id": patron_id,
			"name": patron_names[randi() % patron_names.size()],
			"type": patron_types[randi() % patron_types.size()],
			"relationship": randi_range(1, 3),
			"persistent": randi_range(1, 6) >= 4,
			"source": "event"
		})
		gc["patrons"] = patrons
		if planet_data_manager and planet_data_manager.current_planet_id != "":
			planet_data_manager.add_contact_to_planet(planet_data_manager.current_planet_id, patron_id)

# --- Character Mutation Helpers ---

func add_character_xp(character: Variant, xp_amount: int) -> void:
	if not character:
		return
	if character.has_method("add_experience"):
		character.add_experience(xp_amount)
	elif "experience" in character:
		character.experience += xp_amount
	elif character is Dictionary:
		character["experience"] = character.get("experience", 0) + xp_amount

func award_xp_to_random_crew(xp_amount: int) -> void:
	var crew := get_crew_members()
	if crew.size() > 0:
		add_character_xp(crew[randi() % crew.size()], xp_amount)

func award_xp_to_all_crew(xp_amount: int) -> void:
	var crew := get_crew_members()
	for member in crew:
		add_character_xp(member, xp_amount)

func injure_random_crew(recovery_turns: int) -> void:
	var crew := get_crew_members()
	if crew.size() > 0:
		var member = crew[randi() % crew.size()]
		if "injury_recovery_turns" in member:
			member.injury_recovery_turns = recovery_turns

func injure_specific_crew(character: Variant, recovery_turns: int) -> void:
	if not character:
		return
	var injury_data := {
		"type": "injury",
		"severity": 1,
		"recovery_turns": recovery_turns,
		"description": "Injury sustained",
		"is_fatal": false
	}
	if game_state_manager and game_state_manager.has_method("apply_crew_injury"):
		var crew_id: Variant = character.character_name if "character_name" in character else 0
		game_state_manager.apply_crew_injury(crew_id, injury_data)
	else:
		character.is_wounded = true
		if character.get("status_effects") != null:
			character.status_effects.append({
				"type": "injury", "severity": 1,
				"duration": recovery_turns, "description": "Injury sustained"
			})

func reduce_character_recovery(character: Variant, turns: int) -> void:
	if not character:
		return
	if character.get("status_effects") != null:
		for effect in character.status_effects:
			if effect is Dictionary and effect.get("type", "") in ["injury", "MINOR_INJURY", "SERIOUS_INJURY", "CRIPPLING_WOUND"]:
				if "duration" in effect:
					effect.duration = maxi(0, effect.duration - turns)

func reduce_recovery_time(max_crew: int) -> void:
	var crew := get_crew_members()
	var healed_count: int = 0
	for member in crew:
		if healed_count >= max_crew:
			break
		var recovery_turns: int = member.injury_recovery_turns if "injury_recovery_turns" in member else 0
		if recovery_turns > 0:
			if "injury_recovery_turns" in member:
				member.injury_recovery_turns = max(0, recovery_turns - 1)
			healed_count += 1

func heal_crew_in_sickbay() -> void:
	var crew := get_crew_members()
	for member in crew:
		var recovery_turns: int = member.injury_recovery_turns if "injury_recovery_turns" in member else 0
		if recovery_turns > 0:
			if "injury_recovery_turns" in member:
				member.injury_recovery_turns = 0
			return

# --- Equipment Helpers ---

func damage_random_equipment() -> void:
	var all_equipment: Array = []
	if game_state_manager and game_state_manager.has_method("get_crew_members"):
		for member in game_state_manager.get_crew_members():
			if member.get("is_dead") == true:
				continue
			var member_name: String = member.character_name if "character_name" in member else "Unknown"
			if "weapons" in member:
				for w in member.weapons:
					all_equipment.append({"source": "crew", "owner": member_name, "item_name": str(w)})
			if "items" in member:
				for it in member.items:
					all_equipment.append({"source": "crew", "owner": member_name, "item_name": str(it)})
	if all_equipment.is_empty():
		return
	var _random_index: int = randi() % all_equipment.size()
	# Damage is informational — condition tracking handled by EquipmentManager

func add_random_equipment_to_stash() -> void:
	var gc = _get_current_campaign()
	if gc == null:
		return
	var basic_items: Array = [
		{"name": "Blade", "type": "weapon", "value": 1},
		{"name": "Handgun", "type": "weapon", "value": 1},
		{"name": "Colony Rifle", "type": "weapon", "value": 1},
		{"name": "Frag Grenade", "type": "weapon", "value": 2},
		{"name": "Combat Armor", "type": "gear", "value": 3},
		{"name": "Booster Pills", "type": "gear", "value": 2},
		{"name": "Scanner", "type": "gadget", "value": 3},
	]
	var item: Dictionary = basic_items[randi() % basic_items.size()].duplicate()
	item["id"] = "item_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
	if gc is Dictionary:
		var equipment: Array = gc.get("equipment", gc.get("equipment_data", {}).get("equipment", []))
		equipment.append(item)

# --- Internal Helpers ---

func _get_current_campaign() -> Variant:
	if campaign:
		return campaign
	if game_state and game_state.current_campaign:
		return game_state.current_campaign
	return null

func get_char_name(character: Variant) -> String:
	if "character_name" in character:
		return character.character_name
	elif "name" in character:
		return character.name
	elif character is Dictionary:
		return character.get("name", "Unknown")
	return "Unknown"
