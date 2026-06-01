extends RefCounted
class_name TravelEventTable

## Starship Travel Events Table (Core Rules pp.70-71).
## Single source of truth for the D100 travel event roll. Both TravelPhaseUI and
## UpkeepPhaseComponent consume this so the table can never diverge again.
##
## Each entry returns: {type, title, description, desc, effects}
##   - "description" and "desc" are identical (different consumers read different keys)
##   - "effects" are hint tags for the resolving UI (not mechanically applied here)
##
## Verified against the Core Rulebook 3e PDF (pp.70-71), all 16 D100 ranges.

const EVENTS: Array = [
	{"min": 1, "max": 7, "type": "danger", "title": "Asteroids",
		"text": "Rocky debris everywhere! Roll to navigate safely or take Hull damage.",
		"effects": ["asteroids"]},
	{"min": 8, "max": 12, "type": "setback", "title": "Navigation Trouble",
		"text": "Is this place even on the star maps? Lose 1 story point.",
		"effects": ["lose_story_point"]},
	{"min": 13, "max": 17, "type": "hostile", "title": "Raided",
		"text": "Pirates have spotted your vessel! Prepare for potential combat.",
		"effects": ["combat_encounter"]},
	{"min": 18, "max": 25, "type": "opportunity", "title": "Deep Space Wreckage",
		"text": "Found an old wreck drifting through space. Roll twice on the Gear Table (items are damaged).",
		"effects": ["gear_rolls"]},
	{"min": 26, "max": 29, "type": "setback", "title": "Drive Trouble",
		"text": "It's not supposed to make that sound. May be grounded next turn.",
		"effects": ["drive_trouble"]},
	{"min": 30, "max": 38, "type": "beneficial", "title": "Down-time",
		"text": "Select a crew member to earn +1 XP. Repair 1 damaged item for free.",
		"effects": ["xp_bonus", "free_repair"]},
	{"min": 39, "max": 44, "type": "choice", "title": "Distress Call",
		"text": "'This is Licensed Trader Cyberwolf.' Do you respond?",
		"effects": ["distress_call"]},
	{"min": 45, "max": 50, "type": "neutral", "title": "Patrol Ship",
		"text": "A Unity patrol vessel hails you. They may confiscate contraband.",
		"effects": ["patrol_inspection"]},
	{"min": 51, "max": 53, "type": "rare", "title": "Cosmic Phenomenon",
		"text": "A crew member sees something strange... and gains +1 Luck! (once per campaign)",
		"effects": ["luck_bonus"]},
	{"min": 54, "max": 60, "type": "choice", "title": "Escape Pod",
		"text": "You find an escape pod drifting through space. Rescue them?",
		"effects": ["rescue_choice"]},
	{"min": 61, "max": 66, "type": "setback", "title": "Accident",
		"text": "A crew member is injured during maintenance (1 turn rest). One item they carry is damaged.",
		"effects": ["injury", "damaged_item"]},
	{"min": 67, "max": 75, "type": "neutral", "title": "Travel-time",
		"text": "Long journey under standard drives. Injured crew may rest.",
		"effects": ["rest_time"]},
	{"min": 76, "max": 85, "type": "neutral", "title": "Uneventful Trip",
		"text": "A lot of time playing cards and cleaning guns. You can Repair one damaged item.",
		"effects": ["free_repair"]},
	{"min": 86, "max": 91, "type": "beneficial", "title": "Time to Reflect",
		"text": "How is the story unfolding? What did it all mean? +1 story point.",
		"effects": ["story_point"]},
	{"min": 92, "max": 95, "type": "beneficial", "title": "Time to Read a Book",
		"text": "Time for education. Roll 1D6: random crew members earn XP.",
		"effects": ["random_xp"]},
	{"min": 96, "max": 100, "type": "beneficial", "title": "Locked in the Library Data",
		"text": "You've found information about multiple worlds. Choose your destination!",
		"effects": ["world_choice"]},
]

## Look up the travel event for a specific D100 roll (1-100).
static func get_event(roll: int) -> Dictionary:
	for entry in EVENTS:
		if roll >= entry["min"] and roll <= entry["max"]:
			return {
				"type": entry["type"],
				"title": entry["title"],
				"description": entry["text"],
				"desc": entry["text"],
				"effects": entry["effects"].duplicate(),
			}
	# Out-of-range fallback (should be unreachable for 1-100)
	return {
		"type": "neutral", "title": "Uneventful Trip",
		"description": "An uneventful journey.", "desc": "An uneventful journey.",
		"effects": [],
	}

## Roll a fresh D100 and return the corresponding event.
static func roll_event() -> Dictionary:
	return get_event(randi() % 100 + 1)
