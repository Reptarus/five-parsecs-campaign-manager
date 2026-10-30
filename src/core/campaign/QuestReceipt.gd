extends RefCounted
## Receiving a Quest (Core Rules p.85), whichever rule hands it over.
##
## p.85: "You have now received a Quest which you may pursue immediately." Three rules
## reach that sentence: the Resolve Rumors roll (p.85), Letter from home (p.128, "On a
## 5-6 you immediately receive a Quest") and a Traveler's 11-12 (p.22, "the crew
## immediately receives a Quest"). Until 2026-10-29 only the first produced a Quest;
## the other two added a Quest Rumor, so the book's Quest never started.
##
## Two things a Quest received outside the Rumors roll deliberately does NOT do,
## because no page says so:
##   - discard the Rumors already held. Errata v1.06 p.3 discards them on the Rumors
##     route because "they were all related to this Quest";
##   - grant anything while a Quest is already active. p.85 tracks one Quest at a time.

const DeferredCrewEventsRef = preload("res://src/core/campaign/DeferredCrewEvents.gd")

## Flavour only. A Quest carries no content in the book: its objective is rolled per
## battle (p.89) and its progress per post-battle step (p.120).
const _NAME_PREFIXES := ["The Lost", "Hidden", "Ancient", "Stolen", "Mysterious", "Dangerous"]
const _NAME_SUBJECTS := ["Artifact", "Cargo", "Data", "Weapon", "Ship", "Coordinates"]


static func random_name() -> String:
	return "%s %s" % [_NAME_PREFIXES[randi() % _NAME_PREFIXES.size()],
		_NAME_SUBJECTS[randi() % _NAME_SUBJECTS.size()]]


## The one shape an active Quest has, whichever route produced it.
static func record(quest_name: String, description: String, turn_received: int,
		rumors_spent: int, source: String) -> Dictionary:
	return {
		"id": "quest_%d" % randi(),
		"name": quest_name,
		"description": description,
		"turn_received": turn_received,
		"rumors_spent": rumors_spent,
		"stages_completed": 0,
		"source": source,
	}


## Receive a Quest on the live campaign. Returns {received, quest, local_maps, reason}.
static func receive(source: String, description: String) -> Dictionary:
	var gs: Node = _autoload("GameState")
	if gs == null or gs.current_campaign == null:
		return {"received": false, "reason": "no campaign"}
	if gs.has_active_quest():
		return {"received": false, "reason": "already on a Quest"}
	var campaign = gs.current_campaign
	var turn := 0
	if "progress_data" in campaign and campaign.progress_data is Dictionary:
		turn = int(campaign.progress_data.get("turns_played", 0))
	var quest := record(random_name(), description, turn, 0, source)
	gs.set_active_quest(quest)
	return {"received": true, "quest": quest, "local_maps": apply_local_maps(campaign)}


## Core Rules p.79 Trade 25-26 "Local maps": "If you receive a Quest on this or the
## following world, you may immediately add 1 Rumor. Single-use." True if it was spent.
static func apply_local_maps(campaign: Variant) -> bool:
	var gsm: Node = _autoload("GameStateManager")
	if gsm == null or not gsm.has_method("add_quest_rumor") or campaign == null \
			or not "progress_data" in campaign or not campaign.progress_data is Dictionary:
		return false
	var pd: Dictionary = campaign.progress_data
	if DeferredCrewEventsRef.take(pd, "Local maps", int(pd.get("turns_played", 0))).is_empty():
		return false
	gsm.add_quest_rumor()
	return true


## A RefCounted cannot use get_node_or_null("/root/X"); it errors and aborts.
static func _autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/" + autoload_name) if tree else null
