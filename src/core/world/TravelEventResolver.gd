class_name TravelEventResolver
extends RefCounted
## Applies the mechanical effects of the Starship Travel Events Table
## (Core Rules pp.70-72).
##
## THE GAP THIS CLOSES. TravelEventTable.gd says it outright at line 10:
## "'effects' are hint tags for the resolving UI (not mechanically applied
## here)" — and no resolving UI ever existed. The only consumer,
## UpkeepPhaseComponent._display_travel_event(), builds a title Label and a
## description Label and stops. A repo-wide grep for the effect tags
## (asteroids, lose_story_point, drive_trouble, patrol_inspection,
## rescue_choice, world_choice) found no consumer in any live file.
##
## So travel was mechanically free of both risk and reward: Navigation Trouble
## never cost a story point, Down-time never granted the XP or the free repair,
## Cosmic Phenomenon never granted its once-per-campaign +1 Luck, Accident never
## injured anyone. The player read a paragraph of flavour text and clicked past.
##
## SCOPE, stated honestly. This resolves every event whose effect is
## DETERMINISTIC — no player decision, no battle setup, no sub-table dialog.
## The seven interactive events (Asteroids, Raided, Drive Trouble, Distress
## Call, Patrol Ship, Escape Pod, Locked in the Library) are returned with
## requires_interaction = true so the caller can say so, rather than silently
## applying nothing the way the whole table used to.
##
## Static and tree-free so it is testable without the World Phase UI.

## Events that ask the player something before they can be resolved. The
## resolver returns a `pending_choice` for these; the caller answers and calls
## apply() again with that answer in `choices`.
const CHOICE_TITLES: PackedStringArray = [
	"Asteroids",
	"Distress Call",
	"Escape Pod",
	"Locked in the Library Data",
]


static func _savvy_of(member) -> int:
	if member is Dictionary:
		return int(member.get("savvy", 0))
	if member != null and "savvy" in member:
		return int(member.savvy)
	return 0


static func _best_savvy(crew: Array):
	## The book repeatedly says "select a crew member" for a Savvy test. The
	## player would always pick their best, so picking it for them costs nothing
	## and avoids a dialog per die roll.
	var best = null
	for member in crew:
		if best == null or _savvy_of(member) > _savvy_of(best):
			best = member
	return best


static func _add_credits(campaign, amount: int) -> void:
	if campaign == null or not ("credits" in campaign):
		return
	campaign.credits = maxi(0, int(campaign.credits) + amount)


static func _blank_report() -> Dictionary:
	return {
		"applied": [],
		"reroll": false,
		"pending_choice": {},
		"hull_damage": 0,
		"forced_battle": {},
		"grounded_turns": 0,
	}


static func _crew_of(campaign) -> Array:
	if campaign == null:
		return []
	if campaign.has_method("get_crew_members"):
		return campaign.get_crew_members()
	if "crew_data" in campaign:
		return campaign.crew_data.get("members", [])
	return []


static func _name_of(member) -> String:
	if member is Dictionary:
		return str(member.get("character_name", member.get("name", "A crew member")))
	if member != null and "character_name" in member:
		return str(member.character_name)
	return "A crew member"


static func _bump(member, field: String, amount: int) -> void:
	## Crew members are canonically Dictionaries after creation, but a stray
	## Character Resource must not abort the whole resolution (the 2-arg
	## Dictionary.get() trap).
	if member is Dictionary:
		member[field] = int(member.get(field, 0)) + amount
	elif member != null and field in member:
		member.set(field, int(member.get(field)) + amount)


static func _status_effects(member) -> Array:
	if member is Dictionary:
		if not (member.get("status_effects", null) is Array):
			member["status_effects"] = []
		return member["status_effects"]
	if member != null and "status_effects" in member and member.status_effects is Array:
		return member.status_effects
	return []


static func _add_story_points(campaign, amount: int) -> void:
	if campaign == null or not ("story_points" in campaign):
		return
	campaign.story_points = maxi(0, int(campaign.story_points) + amount)


static func _has_precursor(campaign) -> bool:
	for member in _crew_of(campaign):
		var species: String = ""
		if member is Dictionary:
			species = str(member.get("species_id", member.get("origin", "")))
		elif member != null and "species_id" in member:
			species = str(member.species_id)
		if species.to_lower() == "precursor":
			return true
	return false


static func _damage_random_item(member) -> String:
	## p.71 Accident: "one item they carry is damaged." Recorded the same way
	## Character Events record it, so Repair Your Kit (p.78) can find it.
	var equipment: Array = []
	if member is Dictionary and member.get("equipment", null) is Array:
		equipment = member["equipment"]
	elif member != null and "equipment" in member and member.equipment is Array:
		equipment = member.equipment
	if equipment.is_empty():
		return ""
	var entry = equipment[randi() % equipment.size()]
	var item_name: String = str(entry.get("name", "")) if entry is Dictionary else str(entry)
	if item_name.is_empty():
		return ""
	_status_effects(member).append({
		"type": "item_damaged",
		"name": "Maintenance Accident",
		"description": "%s is damaged. Must be Repaired before use." % item_name,
		"duration": 0,
		"damaged_item": item_name,
		"source_event": "Travel Event: Accident",
	})
	return item_name


static func _repair_one_item(campaign) -> String:
	## "You can Repair one damaged item" / "can Repair 1 damaged item with no roll
	## required" — clears the first item_damaged marker found across the crew.
	for member in _crew_of(campaign):
		var effects: Array = _status_effects(member)
		for i in range(effects.size()):
			var eff = effects[i]
			if eff is Dictionary and str(eff.get("type", "")) == "item_damaged":
				var item_name: String = str(eff.get("damaged_item", "an item"))
				effects.remove_at(i)
				return item_name
	return ""


## Apply one rolled travel event.
##
## Returns {applied: Array[String], requires_interaction: bool, reroll: bool}.
## `reroll` carries the book's explicit "then roll again on this table" clauses.
static func _choice_for(title: String, campaign) -> Dictionary:
	match title:
		"Asteroids":
			return {"id": title,
				"prompt": "Rocky debris everywhere. Chart a course around it (1D6, 5+), or push through the field?",
				"options": [
					{"id": "avoid", "label": "Try to avoid (1D6, 5+)"},
					{"id": "through", "label": "Go through the field"},
				]}
		"Distress Call":
			return {"id": title,
				"prompt": "\"This is Licensed Trader Cyberwolf.\" Do you come to their aid?",
				"options": [
					{"id": "aid", "label": "Respond to the distress call"},
					{"id": "ignore", "label": "Stay on course"},
				]}
		"Escape Pod":
			return {"id": title,
				"prompt": "An escape pod drifts across your path. Rescue whoever is inside?",
				"options": [
					{"id": "rescue", "label": "Rescue them (1D6)"},
					{"id": "ignore", "label": "Leave it"},
				]}
		"Locked in the Library Data":
			# p.72: three worlds are rolled up and the player must visit one of
			# them. All three stay in the campaign.
			var opts: Array = []
			var worlds: Array = _library_worlds(campaign)
			for i in range(worlds.size()):
				opts.append({"id": str(i), "label": str(worlds[i].get("name", "World %d" % (i + 1)))})
			return {"id": title,
				"prompt": "The captain has unearthed records on three nearby worlds. Fuel limits you to one.",
				"options": opts, "worlds": worlds}
	return {}


static func _library_worlds(campaign) -> Array:
	## p.72: "You can roll up the planetary info ... for three worlds and select
	## which you wish to visit ... All three generated worlds remain in the
	## campaign, and can be visited later."
	var gen_script = load("res://src/core/campaign/WorldGenerator.gd")
	if gen_script == null:
		return []
	var turn: int = 1
	if campaign != null and "progress_data" in campaign:
		turn = int(campaign.progress_data.get("turns_played", 1))
	var out: Array = []
	for _i in range(3):
		var gen = gen_script.new()
		if gen and gen.has_method("generate_world"):
			var w: Dictionary = gen.generate_world(turn)
			if not w.is_empty():
				out.append(w)
		if gen:
			gen.free()
	return out


static func _resolve_asteroids(campaign, crew: Array, choice: String) -> Dictionary:
	## p.70, verbatim: "If you wish to avoid it, roll 1D6, requiring a 5+ to chart
	## a safe path. If successful, roll again on this table. To go through the
	## field, select a crew member and roll 1D6+Savvy three times, requiring a 4+
	## to succeed each time. Each failed roll inflicts 1D6 Hull Point damage."
	var out: Dictionary = _blank_report()
	if choice == "avoid":
		var avoid_roll: int = randi_range(1, 6)
		if avoid_roll >= 5:
			out["applied"].append("Charted a safe path (rolled %d, needed 5+)" % avoid_roll)
			out["reroll"] = true
			return out
		out["applied"].append(
			"Failed to chart a way around (rolled %d) — into the field" % avoid_roll)

	var pilot = _best_savvy(crew)
	var savvy: int = _savvy_of(pilot)
	var damage: int = 0
	var failures: int = 0
	for _attempt in range(3):
		if randi_range(1, 6) + savvy < 4:
			failures += 1
			damage += randi_range(1, 6)
	if failures == 0:
		out["applied"].append("%s threaded the field cleanly" % _name_of(pilot))
	else:
		out["hull_damage"] = damage
		out["applied"].append("%d of 3 passes failed — %d Hull Points of damage" % [
			failures, damage])
	return out


static func _resolve_raided(campaign, crew: Array) -> Dictionary:
	## p.70: "Intimidation might work: Select a crew member and roll 1D6+Savvy. A
	## 6+ is required to avoid conflict. Otherwise, set up a battle in cramped
	## territory, using the Criminal Elements Encounter Table ... Enemy numbers
	## are determined by rolling 3D6, picking the highest die (with campaign crew
	## size 5, roll 2D6 and pick highest; with campaign crew size 4, roll 1D6).
	## Add the numbers indicated in the enemy table, +1 extra figure. There is no
	## objective ... Note that this battle is an 'out of sequence' encounter, and
	## does not count as the main Battle stage for the campaign turn."
	var out: Dictionary = _blank_report()
	var talker = _best_savvy(crew)
	var roll: int = randi_range(1, 6) + _savvy_of(talker)
	if roll >= 6:
		out["applied"].append(
			"%s talked the pirates down (%d, needed 6+)" % [_name_of(talker), roll])
		return out

	var crew_size: int = 6
	if campaign != null and campaign.has_method("get_campaign_crew_size"):
		crew_size = int(campaign.get_campaign_crew_size())
	elif campaign != null and "campaign_crew_size" in campaign:
		crew_size = int(campaign.campaign_crew_size)

	var dice: int = 3
	if crew_size == 5:
		dice = 2
	elif crew_size <= 4:
		dice = 1
	var best: int = 0
	for _d in range(dice):
		best = maxi(best, randi_range(1, 6))

	out["applied"].append(
		"Intimidation failed (%d) — boarders incoming" % roll)
	out["forced_battle"] = {
		"objective": "none",
		"objective_description":
			"No objective. Drive them off and they flee back to their ship (Core Rules p.70).",
		"mission_source": "opportunity",
		"enemy_category": "criminal_elements",
		"base_enemy_count": best + 1,   # "+1 extra figure"
		"terrain": "cramped",
		"out_of_sequence": true,        # does not consume the campaign turn's Battle stage
		"travel_event_raid": true,
	}
	return out


static func _resolve_drive_trouble(campaign, crew: Array) -> Dictionary:
	## p.70: "Select 3 crew members and have each roll 1D6+Savvy. A 6+ is required
	## for success. For each failure, you are grounded on the next world for one
	## campaign turn while the drive is reset."
	var out: Dictionary = _blank_report()
	var pool: Array = crew.duplicate()
	pool.sort_custom(func(a, b): return _savvy_of(a) > _savvy_of(b))
	var failures: int = 0
	for i in range(mini(3, pool.size())):
		if randi_range(1, 6) + _savvy_of(pool[i]) < 6:
			failures += 1
	# With fewer than 3 crew the remaining attempts cannot be made at all.
	failures += maxi(0, 3 - pool.size())
	if failures == 0:
		out["applied"].append("The drive was reset in transit — no delay")
		return out
	out["grounded_turns"] = failures
	if campaign != null and "progress_data" in campaign:
		campaign.progress_data["drive_grounded_turns"] = failures
	out["applied"].append(
		"%d repair attempt(s) failed — grounded on arrival for %d campaign turn(s)"
		% [failures, failures])
	return out


static func _resolve_distress_call(campaign, crew: Array, choice: String) -> Dictionary:
	## p.71 subtable, rolled only if the crew responds.
	var out: Dictionary = _blank_report()
	if choice != "aid":
		out["applied"].append("You stayed on course")
		return out

	var d6: int = randi_range(1, 6)
	match d6:
		1:
			out["hull_damage"] = randi_range(1, 6) + 1
			out["applied"].append(
				"The drive detonated as you closed — %d Hull Points of damage"
				% out["hull_damage"])
		2:
			out["applied"].append("Only drifting wreckage remained")
		3, 4:
			out["applied"].append("A survivor was recovered — treat as the Escape Pod event")
			var pod: Dictionary = _resolve_escape_pod(campaign, crew, "rescue")
			(out["applied"] as Array).append_array(pod.get("applied", []))
			out["hull_damage"] += int(pod.get("hull_damage", 0))
		_:
			# 5-6: "roll 1D6+Savvy. A 7+ is required to succeed, but you may make
			# three attempts. If you succeed ... Roll three times on the Gear
			# Table and once on the Gadget Table. If you fail, the drive
			# detonates, and your ship is damaged as if you had rolled a 1."
			var engineer = _best_savvy(crew)
			var saved: bool = false
			for _attempt in range(3):
				if randi_range(1, 6) + _savvy_of(engineer) >= 7:
					saved = true
					break
			if saved:
				out["applied"].append(
					"%s saved their drive — 3 Gear Table rolls and 1 Gadget Table roll owed"
					% _name_of(engineer))
			else:
				out["hull_damage"] = randi_range(1, 6) + 1
				out["applied"].append(
					"The drive detonated — %d Hull Points of damage" % out["hull_damage"])
	return out


static func _resolve_patrol_ship(campaign) -> Dictionary:
	## p.71: "Roll 1D6-3 twice. Each die that scores above a 0 results in that
	## number of items being confiscated as contraband ... Due to the military
	## presence, the next world you visit cannot be Invaded."
	var out: Dictionary = _blank_report()
	var confiscate: int = 0
	for _d in range(2):
		confiscate += maxi(0, randi_range(1, 6) - 3)

	if campaign != null and "progress_data" in campaign:
		campaign.progress_data["next_world_cannot_be_invaded"] = true
	out["applied"].append("Military presence — the next world you visit cannot be Invaded")

	if confiscate <= 0:
		out["applied"].append("The patrol found nothing to confiscate")
		return out

	var stash: Array = []
	if campaign != null and "equipment_data" in campaign:
		var raw: Variant = campaign.equipment_data.get("equipment", [])
		if raw is Array:
			stash = raw
	var taken: int = 0
	while taken < confiscate and not stash.is_empty():
		stash.remove_at(stash.size() - 1)
		taken += 1
	out["applied"].append("%d item(s) confiscated as contraband" % taken)
	if taken < confiscate:
		out["applied"].append(
			"%d more owed — hand over items carried by the crew (p.71)"
			% (confiscate - taken))
	return out


static func _resolve_escape_pod(campaign, crew: Array, choice: String) -> Dictionary:
	## p.71 subtable, rolled only if the crew opts to rescue.
	var out: Dictionary = _blank_report()
	if choice != "rescue":
		out["applied"].append("You left the pod drifting")
		return out

	var d6: int = randi_range(1, 6)
	match d6:
		1:
			# "They're a wanted criminal." Letting them go is the default read:
			# the alternative (turn them in) trades 1D6 credits for a Rival, and
			# the book frames the favour as the interesting branch.
			if campaign != null and "progress_data" in campaign:
				campaign.progress_data["criminal_favor_owed"] = true
			out["applied"].append(
				"A wanted criminal — released on arrival. The next new Rival can be"
				+ " removed on a 1D6 roll of 4+ (p.71)")
		2, 3:
			var credits: int = randi_range(1, 3)
			_add_credits(campaign, credits)
			out["applied"].append(
				"Rescued for %d credits, plus a Loot Table roll on arrival" % credits)
		4:
			_add_story_points(campaign, 1)
			if campaign != null and "progress_data" in campaign:
				var rumors: int = int(campaign.progress_data.get("quest_rumors", 0))
				campaign.progress_data["quest_rumors"] = rumors + 1
			out["applied"].append("Interesting information: +1 Quest Rumor and +1 story point")
		_:
			# 5: joins with no equipment at all. 6: as 5, but with 10 unspent XP.
			var xp: int = 10 if d6 == 6 else 0
			out["applied"].append(
				"A survivor willing to join the crew%s — recruit them from the"
				% (" with 10 unspent XP" if xp > 0 else "")
				+ " crew screen; they bring no equipment (p.71)")
			if campaign != null and "progress_data" in campaign:
				campaign.progress_data["escape_pod_recruit_xp"] = xp
	return out


static func _resolve_library(campaign, choice) -> Dictionary:
	## p.72: three worlds are generated, the player must visit one, and all three
	## "remain in the campaign, and can be visited later".
	var out: Dictionary = _blank_report()
	var worlds: Array = []
	if choice is Dictionary and choice.get("worlds", null) is Array:
		worlds = choice["worlds"]
	if worlds.is_empty():
		worlds = _library_worlds(campaign)
	if worlds.is_empty():
		return out

	var picked: int = 0
	if choice is Dictionary:
		picked = int(str(choice.get("id", "0")).to_int())
	elif choice is String and str(choice).is_valid_int():
		picked = str(choice).to_int()
	picked = clampi(picked, 0, worlds.size() - 1)

	if campaign != null and "progress_data" in campaign:
		var known: Array = campaign.progress_data.get("known_worlds", [])
		if not (known is Array):
			known = []
		known.append_array(worlds)
		campaign.progress_data["known_worlds"] = known
		campaign.progress_data["library_destination"] = worlds[picked]
	out["applied"].append(
		"Three worlds charted; heading for %s. The other two remain on file."
		% str(worlds[picked].get("name", "the chosen world")))
	return out


static func apply(campaign, event: Dictionary, choices: Dictionary = {}) -> Dictionary:
	var out: Dictionary = _blank_report()
	if campaign == null or event.is_empty():
		return out

	var title: String = str(event.get("title", ""))
	var crew: Array = _crew_of(campaign)

	# Ask first if this event needs an answer we do not have yet.
	if title in CHOICE_TITLES and not choices.has(title):
		out["pending_choice"] = _choice_for(title, campaign)
		if not (out["pending_choice"] as Dictionary).is_empty():
			return out

	match title:
		"Asteroids":
			return _resolve_asteroids(campaign, crew, str(choices.get(title, "through")))
		"Raided":
			return _resolve_raided(campaign, crew)
		"Drive Trouble":
			return _resolve_drive_trouble(campaign, crew)
		"Distress Call":
			return _resolve_distress_call(campaign, crew, str(choices.get(title, "ignore")))
		"Patrol Ship":
			return _resolve_patrol_ship(campaign)
		"Escape Pod":
			return _resolve_escape_pod(campaign, crew, str(choices.get(title, "ignore")))
		"Locked in the Library Data":
			return _resolve_library(campaign, choices.get(title, ""))

	match title:
		"Navigation Trouble":
			# p.70: "Lose 1 story point as you drift through empty space, then
			# roll again on this table." Plus: if the ship already has Hull Point
			# damage, "a random crew member must roll on the Injury Table".
			_add_story_points(campaign, -1)
			out["applied"].append("Lost 1 story point")
			out["reroll"] = true
			var ship: Dictionary = campaign.ship_data if "ship_data" in campaign else {}
			var hull: int = int(ship.get("hull_points", 0))
			var max_hull: int = int(ship.get("max_hull", hull))
			if max_hull > 0 and hull < max_hull and not crew.is_empty():
				var victim = crew[randi() % crew.size()]
				_bump(victim, "recovery_turns", 1)
				if victim is Dictionary:
					victim["in_sick_bay"] = true
				out["applied"].append(
					"%s injured by life-support failure" % _name_of(victim))

		"Deep Space Wreckage":
			# p.70: "you get 2 rolls on the Gear Subtable. Both items are damaged
			# and need to be Repaired."
			out["applied"].append(
				"2 Gear Subtable rolls owed — both items arrive damaged (p.132)")

		"Down-time":
			# p.71: "+1 XP" to a crew member of choice, and "can Repair 1 damaged
			# item with no roll required".
			if not crew.is_empty():
				_bump(crew[0], "experience", 1)
				out["applied"].append("%s earned +1 XP" % _name_of(crew[0]))
			var repaired: String = _repair_one_item(campaign)
			if not repaired.is_empty():
				out["applied"].append("Repaired %s for free" % repaired)

		"Cosmic Phenomenon":
			# p.71: "+1 Luck (if they are able). This event can only ever happen
			# once in a campaign. Treat as nothing happening, if it happens
			# again." Plus a Precursor in the crew adds +1 story point.
			var seen: bool = false
			if "progress_data" in campaign:
				seen = bool(campaign.progress_data.get("cosmic_phenomenon_seen", false))
			if seen:
				out["applied"].append("Already witnessed this campaign — no effect")
			elif not crew.is_empty():
				if "progress_data" in campaign:
					campaign.progress_data["cosmic_phenomenon_seen"] = true
				_bump(crew[0], "luck", 1)
				out["applied"].append("%s gained +1 Luck" % _name_of(crew[0]))
				if _has_precursor(campaign):
					_add_story_points(campaign, 1)
					out["applied"].append("Precursor read it as an omen: +1 story point")

		"Accident":
			# p.71: "A crew member gets Injured ... They must rest up for one
			# campaign turn ... and one item they carry is damaged."
			if not crew.is_empty():
				var hurt = crew[randi() % crew.size()]
				_bump(hurt, "recovery_turns", 1)
				if hurt is Dictionary:
					hurt["in_sick_bay"] = true
				out["applied"].append("%s injured — 1 turn of rest" % _name_of(hurt))
				var broken: String = _damage_random_item(hurt)
				if not broken.is_empty():
					out["applied"].append("%s was damaged" % broken)

		"Travel-time":
			# p.72: "Any Injured crew may rest for one campaign turn."
			var rested: int = 0
			for member in crew:
				var turns: int = 0
				if member is Dictionary:
					turns = int(member.get("recovery_turns", 0))
				elif member != null and "recovery_turns" in member:
					turns = int(member.recovery_turns)
				if turns > 0:
					_bump(member, "recovery_turns", -1)
					rested += 1
			if rested > 0:
				out["applied"].append("%d injured crew recovered a turn" % rested)

		"Uneventful Trip":
			# p.72: "You can Repair one damaged item."
			var fixed: String = _repair_one_item(campaign)
			if fixed.is_empty():
				out["applied"].append("Nothing damaged to repair")
			else:
				out["applied"].append("Repaired %s" % fixed)

		"Time to Reflect":
			# p.72: "Add +1 story point."
			_add_story_points(campaign, 1)
			out["applied"].append("Gained 1 story point")

		"Time to Read a Book":
			# p.72: "Roll 1D6. On a 1-2, a random crew member earns +3 XP. On a
			# 3-4, a random crew member earns +2 XP and a second random crew
			# member earns +1 XP. On a 5-6, three random crew each earn +1 XP."
			if not crew.is_empty():
				var d6: int = randi_range(1, 6)
				var shuffled: Array = crew.duplicate()
				shuffled.shuffle()
				if d6 <= 2:
					_bump(shuffled[0], "experience", 3)
					out["applied"].append("%s earned +3 XP" % _name_of(shuffled[0]))
				elif d6 <= 4:
					_bump(shuffled[0], "experience", 2)
					out["applied"].append("%s earned +2 XP" % _name_of(shuffled[0]))
					if shuffled.size() > 1:
						_bump(shuffled[1], "experience", 1)
						out["applied"].append("%s earned +1 XP" % _name_of(shuffled[1]))
				else:
					for i in range(mini(3, shuffled.size())):
						_bump(shuffled[i], "experience", 1)
						out["applied"].append("%s earned +1 XP" % _name_of(shuffled[i]))

	return out
