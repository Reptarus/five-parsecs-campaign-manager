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

## Events whose resolution needs a player choice, a battle, or a sub-table
## dialog. Listed by title so the data file stays the single source of ranges.
const INTERACTIVE_TITLES: PackedStringArray = [
	"Asteroids",
	"Raided",
	"Drive Trouble",
	"Distress Call",
	"Patrol Ship",
	"Escape Pod",
	"Locked in the Library Data",
]


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
static func apply(campaign, event: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"applied": [], "requires_interaction": false, "reroll": false,
	}
	if campaign == null or event.is_empty():
		return out

	var title: String = str(event.get("title", ""))
	if title in INTERACTIVE_TITLES:
		out["requires_interaction"] = true
		return out

	var crew: Array = _crew_of(campaign)

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
