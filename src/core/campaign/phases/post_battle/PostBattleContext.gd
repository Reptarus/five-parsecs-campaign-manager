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
## CampaignPhaseManager autoload. Owns `story_track` and `intro_campaign`, so
## StoryTrackProcessor needs it to advance the Story Clock (Core Rules p.153)
## and the Introductory Campaign turn (Compendium pp.104-109) after a battle.
var campaign_phase_manager: Variant = null

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
	# NONE (0), NOT 1. GlobalEnums.DifficultyLevel is
	# {NONE=0, EASY=1, NORMAL=2, ...}, so the old `return 1` fallback reported
	# EASY whenever game_state_manager was absent — handing out the Core Rules
	# p.64 Easy-mode concessions (PaymentProcessor +1 credit at :45, the
	# invasion-roll modifier at :124, the XP modifier in
	# ExperienceTrainingProcessor:286) to campaigns that were not on Easy.
	# NONE matches no real mode, so every difficulty branch correctly declines.
	return GlobalEnums.DifficultyLevel.NONE

# --- Crew Helpers ---

func get_crew_members() -> Array:
	## Get crew members via campaign or game state. Dictionary check FIRST —
	## Dictionary has no has_method(), so guarding with .has_method() before the
	## `is Dictionary` branch hard-errors on a dict campaign (crew can be dicts).
	var crew: Array = []
	if campaign is Dictionary:
		crew = campaign.get("crew", [])
	elif campaign:
		if campaign.has_method("get_crew_members"):
			crew = campaign.get_crew_members()
		elif "crew_members" in campaign:
			crew = campaign.crew_members
	if crew.is_empty() and game_state and game_state.current_campaign:
		var gc = game_state.current_campaign
		if gc is Dictionary:
			crew = gc.get("crew", [])
		elif gc.has_method("get_crew_members"):
			crew = gc.get_crew_members()
	return crew

func get_crew_member(crew_id: String) -> Variant:
	## Revives the has_method("get_crew_member") guards at InjuryProcessor.gd:54,
	## ExperienceTrainingProcessor.gd, CharacterEventEffects.gd — GameStateManager
	## never defined this, so those guarded lookups always fell through.
	if crew_id.is_empty():
		return null
	for member in get_crew_members():
		var mid: String = ""
		if member is Dictionary:
			mid = str(member.get("character_id", member.get("id", "")))
		elif "character_id" in member:
			mid = str(member.character_id)
		if mid == crew_id:
			return member
	return null

func apply_crew_death(crew_id: String) -> bool:
	## Mark a crew member killed by a post-battle injury (Core Rules pp.94-95).
	##
	## THE BUG THIS FIXES: InjuryProcessor.process_single_injury() returns EARLY on a
	## fatal roll (`if is_fatal: return processed_injury`) and never reached
	## apply_crew_injury — and nothing else wrote a death either. Grep confirmed
	## `status == "DEAD"` is READ (PostBattleCompletion.gd:205, to pick the journal
	## outcome) and never WRITTEN. PostBattleSequence only appends the string
	## "(FATAL)" to a UI label (:2194).
	##
	## So a crew member killed by the injury table stayed fully active: still
	## deployable (GameStateManager.filter_deployable checks status DEAD), still
	## eligible for Crew Tasks, still counted for upkeep, and their battle journal
	## entry recorded them as "survived".
	##
	## Writes the shape the existing readers already look for, rather than inventing
	## a new field: status "DEAD" is what filter_deployable and PostBattleCompletion
	## test, and is_dead/in_sick_bay keep the dashboard and task gates consistent.
	var member = get_crew_member(crew_id)
	if member == null:
		return false
	if member is Dictionary:
		member["status"] = "DEAD"
		member["is_dead"] = true
		member["is_wounded"] = true
		member["in_sick_bay"] = false  # dead, not recovering
		member["recovery_turns"] = 0
	elif member is Object:
		if "status" in member:
			member.status = "DEAD"
		if "is_dead" in member:
			member.is_dead = true
	return true


func apply_luck_death_save(crew_id: String) -> bool:
	## Core Rules p.121 (step 8, Determine Injuries and Recovery), verbatim:
	##   "If a character with Luck would be slain through a roll on this table, they
	##    miraculously survive, but immediately lose ALL Luck points. They can earn
	##    additional points as normal in the future. Unless this occurs, Luck points
	##    are now recovered automatically."
	##
	## This is a DIFFERENT rule from the in-battle Luck save (p.46, "lose 1 point of
	## Luck instead" of becoming a casualty). The in-battle one needs no campaign
	## write: both resolvers deep-copy the crew before the fight
	## (BattleResolver.gd:177 `crew.duplicate(true)`), so campaign Luck is never
	## depleted by a battle and "recovered automatically" is already satisfied.
	##
	## The post-battle one was NOT implemented on the live path at all. InjuryProcessor
	## went straight to apply_crew_death() on any fatal roll, so a crew member holding
	## Luck was killed outright — permanent character loss the book explicitly prevents.
	##
	## Returns true if Luck was spent to save them (caller must NOT kill the character).
	var member = get_crew_member(crew_id)
	if member == null:
		return false
	if _get_character_stat(member, "luck") <= 0:
		return false
	# "immediately lose ALL Luck points" — zero, not decrement.
	_set_character_stat(member, "luck", 0)
	return true


func apply_crew_injury(crew_id: String, injury: Dictionary) -> bool:
	## GameStateManager has no apply_crew_injury — the guarded calls at
	## InjuryProcessor.gd:141,181 were dead, so rolled injuries never mutated the
	## crew member. Mutate here (Dictionary + Resource paths, Core Rules pp.94-95).
	var member = get_crew_member(crew_id)
	if member == null:
		return false
	var recovery: int = int(injury.get("recovery_turns", 0))
	var effect: Dictionary = {
		"type": injury.get("type", "injury"),
		"severity": injury.get("severity", 1),
		"duration": recovery,
		"description": injury.get("description", "Injury sustained"),
	}
	# Write the CANONICAL Sick Bay shape, not a private counter.
	#
	# This used to set only `injury_recovery_turns`, a field NO reader knows. Every
	# Sick Bay consumer checks something else, so a post-battle injury enforced
	# nothing at all: the crew member stayed deployable
	# (GameStateManager.filter_deployable), stayed eligible for Crew Tasks
	# (CrewTaskComponent.gd:182-183), and still counted for upkeep
	# (UpkeepPhaseComponent.gd:151-153, UpkeepSystem.gd:73-77). Core Rules p.55 /
	# p.76 / p.99 were unenforced for every injury rolled after a battle.
	#
	# The canonical shape, confirmed against each reader:
	#   injuries[]      Array of {type, recovery_turns, ...}; the turn-rollover
	#                   countdown (CampaignPhaseManager.gd:296-313) decrements each
	#                   entry and removes it at 0.
	#   in_sick_bay     bool, the primary gate for tasks and upkeep exemption.
	#   recovery_turns  int, UpkeepPhaseComponent's fallback when in_sick_bay is absent.
	#   status          "injured", which CrewTaskComponent.gd:183 ORs into its gate.
	# `injury_recovery_turns` is still written so anything already reading it keeps
	# working, but it is no longer the only home.
	var turn_sustained: int = int(battle_result.get("turn", 0))
	var injury_record := {
		"type": effect["type"],
		"recovery_turns": recovery,
		"description": effect["description"],
		"turn_sustained": turn_sustained,
	}
	if member is Dictionary:
		member["is_wounded"] = true
		member["injury_recovery_turns"] = maxi(int(member.get("injury_recovery_turns", 0)), recovery)
		if not member.has("injuries"):
			member["injuries"] = []
		member["injuries"].append(injury_record)
		if recovery > 0:
			member["in_sick_bay"] = true
			member["recovery_turns"] = maxi(int(member.get("recovery_turns", 0)), recovery)
			member["status"] = "injured"
		if not member.has("status_effects"):
			member["status_effects"] = []
		member["status_effects"].append(effect)
	else:
		if "is_wounded" in member:
			member.is_wounded = true
		if "injury_recovery_turns" in member:
			member.injury_recovery_turns = maxi(int(member.injury_recovery_turns), recovery)
		if "injuries" in member and member.injuries is Array:
			member.injuries.append(injury_record)
		if recovery > 0:
			if "in_sick_bay" in member:
				member.in_sick_bay = true
			if "recovery_turns" in member:
				member.recovery_turns = maxi(int(member.recovery_turns), recovery)
			if "status" in member:
				member.status = "injured"
		apply_character_status_effect(member, effect)
	return true

func get_random_crew_member() -> Variant:
	if crew_participants.size() > 0:
		return crew_participants[randi() % crew_participants.size()]
	var crew := get_crew_members()
	if crew.size() > 0:
		return crew[randi() % crew.size()]
	return null

func get_participating_crew() -> Array:
	var crew: Array = []
	# Producers fill crew_participants with character OBJECTS (not IDs). The old
	# loop treated them as IDs behind a dead gsm.get_crew_member guard and always
	# returned []. Pass objects through; resolve only String ids.
	if not crew_participants.is_empty():
		for participant in crew_participants:
			if participant is String:
				var member = get_crew_member(participant)
				if member != null:
					crew.append(member)
			elif participant != null:
				crew.append(participant)
		return crew
	if game_state_manager and game_state_manager.has_method("get_crew_members"):
		crew = game_state_manager.get_crew_members()
	elif game_state and game_state.current_campaign:
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
	## Check if character is Bot, Soulless, or Assault Bot
	## (excluded from character events per Core Rules pp.15, 21, 128)
	var origin: String = get_character_origin(character).to_lower()
	if origin in ["bot", "soulless", "assault bot"]:
		return true
	# Also check species_id for Strange Characters
	var sid: String = ""
	if character is Dictionary:
		sid = character.get("species_id", "").to_lower()
	elif "species_id" in character:
		sid = str(character.species_id).to_lower()
	return sid == "assault_bot"

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

func add_story_points(amount: int) -> void:
	## Add story points to campaign via GameStateManager
	if game_state_manager \
			and game_state_manager.has_method("add_story_points"):
		game_state_manager.add_story_points(amount)

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
	# RESOURCE BRANCH — the live 5PFH campaign is a FiveParsecsCampaignCore RESOURCE,
	# never a Dictionary, so gating on `gc is Dictionary` alone skipped the whole body.
	# add_rival() below was fixed for exactly this; its four siblings were not. They
	# also targeted fields that do not exist on the Resource (gc["rumors"], gc["patrons"]
	# as a dict key) while the canonical owners are quest_rumors: int (:49) and
	# patrons: Array (:47) on FiveParsecsCampaignCore.
	elif "quest_rumors" in gc:
		gc.quest_rumors += 1

func remove_quest_rumor() -> void:
	var gc = _get_current_campaign()
	if gc == null:
		return
	if gc is Dictionary:
		var rumors: Array = gc.get("rumors", [])
		if rumors.size() > 0:
			rumors.remove_at(randi() % rumors.size())
			gc["rumors"] = rumors
	elif "quest_rumors" in gc:
		gc.quest_rumors = maxi(0, int(gc.quest_rumors) - 1)

func add_rival(rival_name: String) -> void:
	## Adds an event-sourced rival to the canonical `rivals` list.
	##
	## This used to be gated on `if gc is Dictionary` alone. The live 5PFH campaign
	## is a FiveParsecsCampaignCore RESOURCE, not a Dictionary, so the whole body was
	## skipped and every event-granted rival was silently dropped. It used the RIGHT
	## key and still wrote nothing, which is why it never looked wrong. Same class of
	## defect as RivalPatronResolver's `active_rivals`, opposite cause.
	var gc = _get_current_campaign()
	if gc == null:
		return
	var rival_id: String = "rival_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
	var rival := {
		"id": rival_id,
		"name": rival_name,
		"type": ["Criminal", "Corporate", "Personal", "Gang"][randi() % 4],
		"hostility": randi_range(3, 5),
		"resources": randi_range(1, 3),
		"source": "event"
	}
	if gc is Dictionary:
		var rivals: Array = gc.get("rivals", [])
		rivals.append(rival)
		gc["rivals"] = rivals
	elif "rivals" in gc:
		gc.rivals.append(rival)
	else:
		return
	if planet_data_manager and planet_data_manager.current_planet_id != "":
		planet_data_manager.add_contact_to_planet(planet_data_manager.current_planet_id, rival_id)

func remove_patron(patron_id: String) -> bool:
	## Errata v1.06 (Core Rules p.119): "Failing a job you have accepted from a
	## known Patron causes them to be removed from your list of known Patrons."
	## Returns true if a matching Patron was actually dropped.
	if patron_id.is_empty():
		return false
	var gc = _get_current_campaign()
	if gc == null:
		return false
	var patrons: Array = []
	if gc is Dictionary:
		patrons = gc.get("patrons", [])
	elif "patrons" in gc and gc.patrons is Array:
		patrons = gc.patrons
	else:
		return false
	for i in range(patrons.size() - 1, -1, -1):
		var p = patrons[i]
		var pid: String = ""
		# NAME IS A VALID IDENTITY HERE. campaign.patrons is a MIXED array — the
		# creation tables append bare name Strings, events append dicts — so an
		# entry may have no id at all, and a String entry matched nothing under the
		# old id-only read. JobOfferComponent._patron_identity() falls back to the
		# name for exactly this reason; the two must agree or the errata v1.06
		# removal silently misses every name-only Patron.
		if p is Dictionary:
			var pd: Dictionary = p
			pid = str(pd.get("id", pd.get("patron_id", pd.get("name", ""))))
		elif p != null and typeof(p) == TYPE_STRING:
			pid = str(p)
		elif p != null and "id" in p:
			pid = str(p.id)
		if pid == patron_id:
			patrons.remove_at(i)
			if gc is Dictionary:
				gc["patrons"] = patrons
			return true
	return false

func _append_patron(patron: Dictionary) -> void:
	## Append a KNOWN patron to the canonical list, idempotently. p.119 says you
	## "may add the Patron to your list of contacts on this planet" — running the
	## same job twice must not create a duplicate contact.
	var gc = _get_current_campaign()
	if gc == null:
		return
	var patrons: Array = []
	if gc is Dictionary:
		patrons = gc.get("patrons", [])
	elif "patrons" in gc and gc.patrons is Array:
		patrons = gc.patrons
	else:
		return

	var new_id: String = str(patron.get("id", patron.get("name", "")))
	if new_id != "":
		for existing in patrons:
			var eid: String = ""
			if existing is Dictionary:
				var ed: Dictionary = existing
				eid = str(ed.get("id", ed.get("patron_id", ed.get("name", ""))))
			else:
				eid = str(existing)
			if eid == new_id:
				return

	patrons.append(patron)
	if gc is Dictionary:
		gc["patrons"] = patrons
	if planet_data_manager and planet_data_manager.current_planet_id != "" and new_id != "":
		planet_data_manager.add_contact_to_planet(
			planet_data_manager.current_planet_id, new_id)

func remove_random_patron() -> void:
	var gc = _get_current_campaign()
	if gc == null:
		return
	if gc is Dictionary:
		var patrons: Array = gc.get("patrons", [])
		if patrons.size() > 0:
			patrons.remove_at(randi() % patrons.size())
			gc["patrons"] = patrons
	elif "patrons" in gc and gc.patrons is Array and gc.patrons.size() > 0:
		gc.patrons.remove_at(randi() % gc.patrons.size())

func add_patron(patron: Dictionary = {}) -> void:
	## With no argument this GENERATES a new contact — correct for the campaign and
	## character events that hand you one out of nowhere (CampaignEventEffects,
	## CharacterEventEffects).
	##
	## Post-battle Step 2 is NOT that case. Core Rules p.119: "If you succeeded in
	## a Patron mission, you may add THE Patron to your list of contacts on this
	## planet" — the one whose job you just finished. Calling this bare meant a
	## successful job added a randomly-named stranger ("Lady Silver", "Old Sal")
	## with a rolled persistence flag, while the Patron you actually worked for was
	## never recorded. Pass their identity and they are added as themselves.
	if not patron.is_empty():
		_append_patron(patron)
		return
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
	elif "patrons" in gc and gc.patrons is Array:
		var patron_types2: Array = ["Corporate", "Government", "Criminal", "Private", "Mercenary"]
		var patron_names2: Array = ["The Broker", "Lady Silver", "Commander Vex", "Old Sal", "The Collector"]
		var pid: String = "patron_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
		gc.patrons.append({
			"id": pid,
			"name": patron_names2[randi() % patron_names2.size()],
			"type": patron_types2[randi() % patron_types2.size()],
			"relationship": randi_range(1, 3),
			"persistent": randi_range(1, 6) >= 4,
			"source": "event"
		})
		if planet_data_manager and planet_data_manager.current_planet_id != "":
			planet_data_manager.add_contact_to_planet(planet_data_manager.current_planet_id, pid)

# --- Character Mutation Helpers ---

func add_character_xp(character: Variant, xp_amount: int) -> void:
	## DICTIONARY BRANCH FIRST — has_method() on a Dictionary is an INVALID CALL that
	## unwinds the whole function, so this mutator silently did nothing for the crew
	## shape the project actually uses (crew members are canonically Dictionaries per
	## the data-ownership table). Every caller was affected: the post-battle XP award,
	## award_xp_to_random_crew and award_xp_to_all_crew.
	##
	## Third occurrence of this exact trap found today — see InjuryProcessor and
	## get_crew_members(), which already documents the rule at :130.
	if character == null:
		return
	if character is Dictionary:
		var d: Dictionary = character
		d["experience"] = int(d.get("experience", 0)) + xp_amount
		return
	if character is Object:
		if character.has_method("add_experience"):
			character.add_experience(xp_amount)
		elif "experience" in character:
			character.experience += xp_amount

func award_xp_to_random_crew(xp_amount: int) -> void:
	var crew := get_crew_members()
	if crew.size() > 0:
		add_character_xp(crew[randi() % crew.size()], xp_amount)

func award_xp_to_all_crew(xp_amount: int) -> void:
	var crew := get_crew_members()
	for member in crew:
		add_character_xp(member, xp_amount)

func award_xp_to_captain(xp_amount: int) -> void:
	## THIS METHOD DID NOT EXIST. CampaignEventEffects.gd:162 called it directly,
	## with no has_method() guard, for the Core Rules p.126 campaign event
	## "You've managed to settle some old business ... If you have no Rivals, your
	## captain earns +1 XP instead." A call to a nonexistent method is an INVALID
	## CALL that aborts the enclosing function, so apply_effect() unwound: the
	## captain gained nothing AND the event's result string was never returned.
	##
	## The captain is the crew member carrying is_captain == true — it MUST live in
	## crew_data["members"], not only in captain_data (data-ownership table).
	## Falls back to the first member so the book's XP is never silently dropped
	## on a campaign whose captain flag is missing.
	var crew := get_crew_members()
	if crew.is_empty():
		return
	for member in crew:
		var flagged := false
		if member is Dictionary:
			flagged = bool((member as Dictionary).get("is_captain", false))
		elif member is Object and "is_captain" in member:
			flagged = bool(member.is_captain)
		if flagged:
			add_character_xp(member, xp_amount)
			return
	add_character_xp(crew[0], xp_amount)

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

func apply_character_status_effect(character: Variant, effect: Dictionary) -> void:
	## Apply a persistent status effect from a Character Event (Core Rules pp.128-130).
	## Handles both Resource-based and Dictionary-format crew members.
	if not character:
		return
	if character is Resource and character.has_method("add_status_effect"):
		character.add_status_effect(effect)
	elif character is Dictionary:
		if not character.has("status_effects"):
			character["status_effects"] = []
		character["status_effects"].append(effect)

# Ability maximums (Core Rules p.123 Ability Increase Table). Luck handled separately.
const ABILITY_MAX := {"reaction": 6, "combat": 5, "speed": 8, "savvy": 5, "toughness": 6}

func _get_character_stat(character: Variant, stat: String) -> int:
	if character is Dictionary:
		return int(character.get(stat, 0))
	if character and stat in character:
		return int(character.get(stat))
	return 0

func _set_character_stat(character: Variant, stat: String, value: int) -> void:
	if character is Dictionary:
		character[stat] = value
	elif character:
		character.set(stat, value)

func apply_luck_increase(character: Variant, amount: int = 1) -> bool:
	## Core Rules p.123: Luck max is 1 (3 for Humans). Used by Charmed Existence (p.129).
	if not character:
		return false
	var current: int = _get_character_stat(character, "luck")
	var origin: String = ""
	if character is Dictionary:
		origin = str(character.get("origin", character.get("species", ""))).to_lower()
	elif "origin" in character:
		origin = str(character.origin).to_lower()
	var max_luck: int = 3 if (origin == "human" or origin == "baseline human") else 1
	if current >= max_luck:
		return false
	_set_character_stat(character, "luck", mini(current + amount, max_luck))
	return true

func apply_random_ability_increase(character: Variant) -> String:
	## Core Rules p.129 Personal Breakthrough: +1 to one ability not yet at its max.
	## Returns the ability raised (empty string if all abilities are maxed).
	if not character:
		return ""
	var origin: String = ""
	if character is Dictionary:
		origin = str(character.get("origin", character.get("species", ""))).to_lower()
	elif "origin" in character:
		origin = str(character.origin).to_lower()
	var candidates: Array = []
	for ability in ABILITY_MAX:
		var cap: int = ABILITY_MAX[ability]
		# Core Rules p.123: Engineers cannot raise Toughness above 4.
		if ability == "toughness" and origin == "engineer":
			cap = 4
		if _get_character_stat(character, ability) < cap:
			candidates.append(ability)
	if candidates.is_empty():
		return ""
	var chosen: String = candidates[randi() % candidates.size()]
	_set_character_stat(character, chosen, _get_character_stat(character, chosen) + 1)
	return chosen

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
#
# DAMAGED GEAR IS A STATUS-EFFECT MARKER ON THE OWNER, not a field on the item.
# The live representation everywhere in this codebase is
#   {type: "item_damaged", damaged_item: <item name>}
# appended to the owning crew member's status_effects. Character Events write it
# (CharacterEventEffects, "Don't Make Them Like They Used To"), travel events
# write it (TravelEventResolver._damage_random_item), and Repair Your Kit READS
# it (CrewTaskComponent._first_damaged_item / _resolve_damaged_item, p.78).
#
# Anything that damages equipment must write THIS shape. An item flag such as
# `damaged: true` or `condition: "damaged"` is invisible to the repair task, so
# gear marked that way can never be fixed.

static func _entry_item_name(entry: Variant) -> String:
	return str(entry.get("name", "")) if entry is Dictionary else str(entry)

func _member_equipment(member: Variant) -> Array:
	## Returns the LIVE array so callers can mutate through to the campaign.
	if member is Dictionary:
		var eq: Variant = member.get("equipment", null)
		return eq if eq is Array else []
	if member and "equipment" in member and member.equipment is Array:
		return member.equipment
	return []

func _member_status_effects(member: Variant) -> Array:
	if member is Dictionary:
		if not (member.get("status_effects", null) is Array):
			member["status_effects"] = []
		return member["status_effects"]
	if member and "status_effects" in member and member.status_effects is Array:
		return member.status_effects
	return []

func _member_is_dead(member: Variant) -> bool:
	if member is Dictionary:
		return bool(member.get("is_dead", false)) \
			or str(member.get("status", "")) == "DEAD"
	if member and "is_dead" in member:
		return bool(member.is_dead)
	return false

func _is_item_already_damaged(member: Variant, item_name: String) -> bool:
	for eff in _member_status_effects(member):
		if eff is Dictionary and str(eff.get("type", "")) == "item_damaged" \
				and str(eff.get("damaged_item", "")) == item_name:
			return true
	return false

func mark_item_damaged(member: Variant, item_name: String, source: String) -> bool:
	## Returns false when there was nothing to do (no name, or already damaged) so
	## callers can report an honest count instead of claiming a hit every time.
	if member == null or item_name.is_empty():
		return false
	if _is_item_already_damaged(member, item_name):
		return false
	apply_character_status_effect(member, {
		"type": "item_damaged",
		"name": "Damaged Equipment",
		"description": "%s is damaged and cannot be used until Repaired (Core Rules p.78)." % item_name,
		"duration": 0,
		"damaged_item": item_name,
		"source_event": source,
	})
	return true

func _damage_random_item_on(member: Variant, source: String) -> String:
	if member == null:
		return ""
	# Already-damaged items are excluded: otherwise a second Equipment Loss result
	# can "damage" the same broken rifle and cost the player nothing.
	var candidates: Array = []
	for entry in _member_equipment(member):
		var item_name: String = _entry_item_name(entry)
		if not item_name.is_empty() and not _is_item_already_damaged(member, item_name):
			candidates.append(item_name)
	if candidates.is_empty():
		return ""
	var chosen: String = candidates[randi() % candidates.size()]
	mark_item_damaged(member, chosen, source)
	return chosen

func damage_random_equipment_for(crew_id: String, source: String = "Injury Table") -> String:
	## Core Rules p.122, Injury Table 17-30 and Bot Injury Table 16-30:
	## "Random carried item is damaged." Returns the item name, "" if none.
	return _damage_random_item_on(get_crew_member(crew_id), source)

func damage_all_equipment_for(crew_id: String, source: String = "Injury Table") -> Array:
	## Core Rules p.122, Injury Table 1-5 Gruesome fate and Bot 1-5 Obliterated:
	## "...and all carried equipment is damaged." DAMAGED, not lost — the gear
	## survives the character and is repairable under p.78.
	var member: Variant = get_crew_member(crew_id)
	if member == null:
		return []
	var damaged: Array = []
	for entry in _member_equipment(member):
		var item_name: String = _entry_item_name(entry)
		if mark_item_damaged(member, item_name, source):
			damaged.append(item_name)
	return damaged

func lose_all_equipment_for(crew_id: String) -> Array:
	## Core Rules p.122, Injury Table 16 Miraculous escape: "The character
	## survives and receives +1 Luck, but all items carried are PERMANENTLY
	## LOST." Distinct from Gruesome fate — these items leave the game entirely,
	## so no repair marker is written and the entries are removed outright.
	var member: Variant = get_crew_member(crew_id)
	if member == null:
		return []
	var equipment: Array = _member_equipment(member)
	var lost: Array = []
	for entry in equipment:
		var item_name: String = _entry_item_name(entry)
		if not item_name.is_empty():
			lost.append(item_name)
	if lost.is_empty():
		return []
	# Mutating the live array writes through to the campaign; reassigning a new
	# array would not (and on a Character it would hit the Array[String] setter).
	equipment.clear()
	# Outstanding damage markers now point at items that no longer exist, which
	# would leave Repair Your Kit offering to fix thin air forever.
	var effects: Array = _member_status_effects(member)
	for i in range(effects.size() - 1, -1, -1):
		var eff: Variant = effects[i]
		if eff is Dictionary and str(eff.get("type", "")) == "item_damaged":
			effects.remove_at(i)
	return lost

func damage_random_equipment() -> void:
	## Campaign Event 45-48 "Equipment Malfunction" (Core Rules p.127): one random
	## item somewhere in the crew is damaged. Called by CampaignEventEffects.
	##
	## THE BUG THIS FIXES: the body ended at `var _random_index: int = randi() %
	## all_equipment.size()` under the comment "Damage is informational —
	## condition tracking handled by EquipmentManager". EquipmentManager does no
	## such thing; the index was computed and discarded, so the event damaged
	## nothing, ever. It also gathered from `weapons`/`items`, which the canonical
	## crew-member shape does not carry — owner gear lives in `equipment` — so on
	## the live shape the candidate list was empty before the discard even
	## mattered.
	var owners: Array = []
	for member in get_crew_members():
		if _member_is_dead(member):
			continue
		if not _member_equipment(member).is_empty():
			owners.append(member)
	if owners.is_empty():
		return
	_damage_random_item_on(
		owners[randi() % owners.size()],
		"Campaign Event: Equipment Malfunction")

func apply_permanent_stat_reduction(crew_id: String, stats: Array, amount: int) -> Dictionary:
	## Core Rules p.122, Injury Table 31-45 Crippling wound: "-1 permanent
	## reduction to highest of Speed or Toughness."
	##
	## Picks the highest of the listed stats (ties resolve to the first listed —
	## the book does not break them, and either is legal), floors the result at 0,
	## and returns {stat, from, to}. Empty when nothing could be reduced.
	var member: Variant = get_crew_member(crew_id)
	if member == null or stats.is_empty() or amount == 0:
		return {}
	var chosen: String = ""
	var best: int = -1
	for s in stats:
		var stat_name: String = str(s)
		var value: int = _get_character_stat(member, stat_name)
		if value > best:
			best = value
			chosen = stat_name
	if chosen.is_empty() or best <= 0:
		return {}
	var reduced: int = maxi(0, best + amount)
	if reduced == best:
		return {}
	_set_character_stat(member, chosen, reduced)
	return {"stat": chosen, "from": best, "to": reduced}

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
