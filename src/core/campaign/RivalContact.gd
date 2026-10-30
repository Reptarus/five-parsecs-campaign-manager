class_name RivalContact
extends RefCounted

## A new Rival (Core Rules p.79 Contraband, p.81 Pick a fight and the package
## delivery, the post-battle and campaign events, Planetfall pp.165-166).
##
## ONE producer for the shape every reader expects: id, name, type, planet_id,
## threat_level, created_turn, origin. Until 2026-10-29 the crew-task Rival and the
## deferred-event Rival were each built from five invented types ("Criminal",
## "Corporate", "Military", "Pirate", "Cult") with an invented name ("Rival 42"),
## "hostility" and "resources"; the crew-task one was handed to NPCTracker, a
## history tracker, so it never reached campaign.rivals, never attacked (p.85), and
## never showed on the Rivals screen. The Planetfall Independence-lost Rival was
## written with the type "rival", which no enemy table has.
##
## The book gives a new Rival a TYPE and nothing else: p.94's Unknown Rival column
## when nothing names it. It names no Rival, so the type is the name, as
## PatronContact does for a Patron.
##
## Riders a rule adds at birth ride in `opts` and are only written when present, so
## a consumer can tell "no rider" from "a rider of zero".

const EnemyGeneratorRef = preload("res://src/core/systems/EnemyGenerator.gd")
const RivalEncounterCheckRef = preload("res://src/core/campaign/RivalEncounterCheck.gd")

## Keys a rule may add to a new Rival. Copied through only when the caller sets them.
const RIDERS := ["persistent", "enemy_count_bonus", "first_battle_enemy_modifier",
	"is_elite", "source_event"]


## A Rival's enemy TYPE, without inventing one.
##
## Order: an explicit type that is a real enemy type wins; else the label itself if
## it already names one ("Enforcers" MUST stay Enforcers - the p.96 Cop-killer rule
## keys on it); else roll the p.94 Unknown Rival column. Blank if the table fails to
## load: a made-up type would be honoured downstream as a battle preset.
static func resolve_type(label: String = "", explicit: String = "") -> String:
	return str(resolve_types(label, explicit)[0])


## [type, alternative]. p.92: "If you are not sure, or have acquired an unexpected
## Rival, roll twice and pick the more interesting or appropriate." A ROLLED type
## comes with the second roll as its alternative; a given or named type has none,
## and two equal rolls offer no choice. Until 2026-10-29 the column was rolled once.
static func resolve_types(label: String = "", explicit: String = "") -> Array:
	var wanted: String = explicit.strip_edges()
	if not wanted.is_empty() and EnemyGeneratorRef.is_known_enemy_type(wanted):
		return [wanted, ""]
	var named: String = label.strip_edges()
	if not named.is_empty() and EnemyGeneratorRef.is_known_enemy_type(named):
		return [named, ""]
	var gen = EnemyGeneratorRef.new()
	var first: String = str(gen.select_enemy_for_mission("unknown_rival").get("name", ""))
	var second: String = str(gen.select_enemy_for_mission("unknown_rival").get("name", ""))
	return [first, second if second != first else ""]


## A new Rival. `label` is the name a rule gives it (an event's Rival, "Enforcers");
## empty means the book names none and the rolled type is the name.
static func make(origin: String, label: String = "", opts: Dictionary = {}) -> Dictionary:
	var types: Array = resolve_types(label, str(opts.get("type", "")))
	var rtype: String = str(types[0])
	var rname: String = label.strip_edges()
	if rname.is_empty():
		rname = rtype if not rtype.is_empty() else "Rival"
	var rival: Dictionary = {
		"id": str(opts.get("id", "rival_%d_%d" % [Time.get_ticks_msec(), randi() % 100000])),
		"name": rname,
		"type": rtype,
		"planet_id": str(opts.get("planet_id", "")),
		"threat_level": 1,
		"created_turn": int(opts.get("created_turn", 0)),
		"origin": origin,
	}
	for key in RIDERS:
		if opts.has(key):
			rival[key] = opts[key]
	# p.92: the second roll, offered on the Rivals screen until the first battle.
	if not str(types[1]).is_empty():
		rival["type_alternative"] = str(types[1])
	return rival


## The player's p.92 pick between the two rolls. Swaps the type with the
## alternative, so the choice can be changed back until the Rival is established.
## A name that was only the type follows it. False when there is nothing to pick.
static func swap_type(rival: Dictionary) -> bool:
	var alt: String = str(rival.get("type_alternative", "")).strip_edges()
	if alt.is_empty():
		return false
	var current: String = str(rival.get("type", ""))
	if str(rival.get("name", "")) == current:
		rival["name"] = alt
	rival["type"] = alt
	rival["type_alternative"] = current
	return true


## p.92: "Once a Rival has been established, they will always be the same type."
## Called at the first battle against them, which is what fixes the type.
static func establish(rival: Dictionary) -> void:
	rival.erase("type_alternative")


## Rivals a crew task gave out before 2026-10-29. They live only in NPCTracker's
## history (source "crew_task"), so the p.85 check never saw them. Returns the ones
## not already on `campaign_rivals`, rebuilt through make() with the same id so the
## tracker's encounter history still joins them. The old invented type is not kept:
## re-rolling the Unknown Rival column is how the book types an unknown Rival.
static func legacy_crew_task_rivals(tracker_rivals: Dictionary, campaign_rivals: Array) -> Array:
	var have: Dictionary = {}
	for r in campaign_rivals:
		have[RivalEncounterCheckRef.rival_id_of(r)] = true
	var out: Array = []
	for key in tracker_rivals:
		var t: Variant = tracker_rivals[key]
		if not (t is Dictionary) or str((t as Dictionary).get("source", "")) != "crew_task":
			continue
		var rid: String = str((t as Dictionary).get("rival_id", key))
		if rid.is_empty() or have.has(rid):
			continue
		out.append(make("crew_task", "", {"id": rid,
			"created_turn": int((t as Dictionary).get("created_turn", 0))}))
		have[rid] = true
	return out
