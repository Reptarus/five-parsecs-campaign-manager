class_name PatronContact
extends RefCounted

## A new Patron contact (Core Rules p.83 Patron Table, p.84 Persistent).
##
## ONE producer. Until 2026-10-29 four places made a new Patron and every one of
## them invented it: PostBattleContext.add_patron() picked from five made-up names
## ("Lady Silver", "Old Sal") and five made-up types, and gave half of them the
## Persistent flag on a flat 1D6 4+; GameStateManager.add_patron() read
## PatronManager.generate_patron() (influence 1-5, 5000-20000 credits, a
## "specialization", "preferences"); and both Find a Patron / gain-a-Patron sites in
## CrewTaskComponent read PatronJobManager.roll_patron_contact(), which always
## "succeeded" with a minor tier, an invented job and a generated person's name.
##
## What the book gives a Patron is a TYPE: one D10 on the p.83 Patron Table. It
## names no Patron, so the type is the name, which is what JobOfferComponent already
## printed for a Patron with no name. Persistent is a Benefit a JOB can carry
## (p.84, 8-9 on the Benefits subtable), not something you roll on meeting someone,
## so a new contact starts without it and NewWorldArrival.is_persistent_patron()
## reads false (p.72: "All Patrons remain behind unless they are Persistent").
##
## The roll goes through DiceManager as "Patron Type", so QA can force it.

const PatronJobEffectsRef = preload("res://src/core/patrons/PatronJobEffects.gd")
const ROLL_CONTEXT := "Patron Type"


## One D10 on the p.83 Patron Table.
static func roll_type() -> String:
	return PatronJobEffectsRef.patron_type_for_roll(_roll_d10())


## A new contact. `forced_type` skips the roll for a rule that fixes the type, such
## as the p.74 Corporate State world trait ("Patrons are always Corporations").
## `source` records where the contact came from, for the journal and for debugging.
static func make(source: String, forced_type: String = "") -> Dictionary:
	var ptype: String = forced_type if not forced_type.is_empty() else roll_type()
	return {
		"id": "patron_%d_%d" % [Time.get_ticks_usec(), randi() % 100000],
		"name": ptype,
		"type": ptype,
		# The two fields the Patrons screen reads besides name and type.
		"status": "Active",
		"jobs_offered": 0,
		"source": source,
	}


static func _roll_d10() -> int:
	var loop := Engine.get_main_loop()
	var dm: Node = null
	if loop is SceneTree:
		dm = (loop as SceneTree).root.get_node_or_null("/root/DiceManager")
	if dm != null and dm.has_method("roll_d10"):
		return int(dm.roll_d10(ROLL_CONTEXT))
	return randi_range(1, 10)
