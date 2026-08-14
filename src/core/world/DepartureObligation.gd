extends RefCounted
## "This place is rather nice, really" — the Exploration table's 97-100 result
## (Core Rules p.82), which is a DEPARTURE obligation and was implemented as an
## immediate one.
##
## The book, verbatim (verified from the PDF, page index 81 = printed p.82; note
## it does NOT survive a naive substring search because extract_text() breaks the
## line mid-phrase):
##
##   "97-100 This place is rather nice, really. When you are ready to leave this
##    world, unless it is being Invaded, you must pay 1 story point or this crew
##    member will decide to stay behind. If they do, you can keep their
##    equipment, though."
##
## THE GAP THIS FILLS. Four rules in one sentence, and the app honoured none of
## them (T9-42, found on the tablet Aug 13 2026):
##
##   1. "you must pay 1 story point" — `CrewTaskComponent` charged via
##      `GameStateManager.modify_story_progress(-1)`, which clamps
##      `set_story_progress(max(0, ...))`. At 0 story points the charge was a
##      SILENT NO-OP and the dialog still printed "Paid the cost", so the player
##      kept the crew member for free. Observed live at SP 0.
##   2. "When you are ready to leave this world" — it was charged the instant the
##      Explore result came up, often many turns before departure, and the crew
##      member could not be kept by simply staying put.
##   3. "unless it is being Invaded" — no exemption existed. A crew fleeing an
##      Invasion (p.69) still paid.
##   4. "you can keep their equipment, though" — `_remove_crew_member()` dropped
##      the member from the roster and their `Character.equipment` went with them,
##      so the player LOST gear the book explicitly grants.
##
## The data file lost the rule too, not just the UI: the table entry's `effect`
## read "Pay 1 story point or one crew member leaves the crew", which drops all
## three qualifiers and says "one crew member" where the book says "this crew
## member" — the one who explored.
##
## Ownership: obligations live in `progress_data["departure_obligations"]`, and
## every mutation goes through this file. Resolution happens at the single
## departure chokepoint, `UpkeepPhaseComponent._on_travel_pressed()`, alongside
## the p.73 Bureaucratic mess check which is the same shape of rule.

const EquipmentTransferServiceRef = preload(
	"res://src/core/equipment/EquipmentTransferService.gd")

const PENDING_KEY := "departure_obligations"


static func _progress_data(campaign) -> Variant:
	## Guard on the OWNER, never on the container being empty — an empty
	## progress_data is a LEGAL state for a fresh campaign, and treating it as
	## "no campaign" is how salvage was silently disabled for every new game.
	if campaign == null or not ("progress_data" in campaign):
		return null
	var pd = campaign.progress_data
	return pd if pd is Dictionary else null


## Record that a crew member has taken a liking to this world. Called when the
## Explore result comes up; the price is not paid until departure.
##
## `pay_intent` is the player's answer to the dialog, carried forward rather than
## acted on. Departure decides whether they CAN pay — the book's condition is
## about the moment of leaving, and a story point earned in between is exactly
## the kind of thing charging early would have thrown away.
static func record(campaign, crew_id: String, crew_name: String,
		pay_intent: bool = true) -> bool:
	var pd = _progress_data(campaign)
	if pd == null or crew_id.strip_edges().is_empty():
		return false
	var pending: Array = pd.get(PENDING_KEY, [])
	# One obligation per crew member. Rolling the result twice for the same
	# person does not make them leave twice — the later answer just replaces the
	# earlier one.
	for entry in pending:
		if entry is Dictionary and str(entry.get("crew_id", "")) == crew_id:
			entry["pay_intent"] = pay_intent
			return false
	pending.append({
		"crew_id": crew_id,
		"crew_name": crew_name,
		"pay_intent": pay_intent,
	})
	pd[PENDING_KEY] = pending
	return true


static func pending(campaign) -> Array:
	var pd = _progress_data(campaign)
	if pd == null:
		return []
	var raw: Variant = pd.get(PENDING_KEY, [])
	return raw if raw is Array else []


static func has_pending(campaign) -> bool:
	return not pending(campaign).is_empty()


## "you must pay 1 story point" — so one story point must actually be there.
## `modify_story_progress` clamps at 0, which is why the caller cannot simply
## charge and inspect the result: the charge succeeds silently either way.
##
## Core Rules p.65 — Insanity disables story points ENTIRELY, none earned and
## none spent. Such a crew can never pay this, so the member stays behind.
static func can_pay(campaign) -> bool:
	if campaign == null or not ("story_points" in campaign):
		return false
	if "difficulty" in campaign \
			and DifficultyModifiers.are_story_points_disabled(campaign.difficulty):
		return false
	return int(campaign.story_points) >= 1


## Spend the one story point p.82 asks for.
##
## Mirrors TravelEventResolver._add_story_points: prefer the canonical mutator
## when GameStateManager owns THIS campaign, so its cached mirror and the
## story_progress_changed signal (the dashboard SP badge) stay in step; fall back
## to a direct write otherwise, because this file is PARAMETERISED by campaign —
## tests drive a detached CampaignCore — and delegating to a singleton bound to a
## different object would silently drop the charge.
##
## `can_pay()` is the caller's gate, so the manager's max(0, ...) clamp can never
## hide a failed payment here.
static func _spend_story_point(campaign) -> void:
	var gsm: Node = null
	if Engine.get_main_loop():
		gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("modify_story_progress") \
			and gsm.game_state != null \
			and gsm.game_state.current_campaign == campaign:
		gsm.modify_story_progress(-1)
		return
	campaign.story_points = maxi(0, int(campaign.story_points) - 1) # lint:ignore


static func clear(campaign) -> void:
	var pd = _progress_data(campaign)
	if pd != null:
		pd[PENDING_KEY] = []


## Resolve every outstanding obligation at the moment the crew leaves the world.
##
## Each obligation carries its own `pay_intent`, honoured only when a story point
## is actually available — "you MUST pay 1 story point" means one has to be there,
## and `modify_story_progress` clamping at 0 is precisely why the old code could
## not tell the difference. `world_is_invaded` waives the whole thing (p.82's
## "unless it is being Invaded"), which in practice is the p.69 flee departure.
##
## Returns a RECEIPT rather than a bool: a rule that silently half-applied is
## worse than one that did not run, and the caller reports these to the player.
static func resolve_on_departure(campaign, world_is_invaded: bool) -> Dictionary:
	var receipt: Dictionary = {
		"resolved": [], "departed": [], "paid": 0, "waived": false,
	}
	var outstanding: Array = pending(campaign)
	if outstanding.is_empty():
		return receipt

	if world_is_invaded:
		# p.82: the obligation simply does not apply. Nobody pays and nobody
		# stays behind — the crew is fleeing an Invasion together.
		receipt["waived"] = true
		for entry in outstanding:
			if entry is Dictionary:
				receipt["resolved"].append(str(entry.get("crew_name", "")))
		clear(campaign)
		return receipt

	for entry in outstanding:
		if not (entry is Dictionary):
			continue
		var crew_id: String = str(entry.get("crew_id", ""))
		var crew_name: String = str(entry.get("crew_name", "Crew member"))
		if bool(entry.get("pay_intent", true)) and can_pay(campaign):
			_spend_story_point(campaign)
			receipt["paid"] = int(receipt["paid"]) + 1
			receipt["resolved"].append(crew_name)
		else:
			# "this crew member will decide to stay behind. If they do, you can
			# keep their equipment, though."
			_retain_equipment(campaign, crew_id)
			if campaign.has_method("remove_crew_member"):
				campaign.remove_crew_member(crew_id)
			receipt["departed"].append(crew_name)
			receipt["resolved"].append(crew_name)

	clear(campaign)
	return receipt


## "you can keep their equipment, though." Moves every item off the departing
## character's sheet into the ship stash BEFORE they are removed from the roster
## — once the member is gone their equipment array is unreachable.
##
## Routed through EquipmentTransferService so the "one item, one home" invariant
## holds: the item leaves the character and arrives in the stash atomically,
## rather than being copied into a second home.
static func _retain_equipment(campaign, crew_id: String) -> int:
	if campaign == null or not campaign.has_method("get_crew_member_by_id"):
		return 0
	var member = campaign.get_crew_member_by_id(crew_id)
	if member == null:
		return 0
	var items: Array = []
	if member is Dictionary:
		var raw: Variant = member.get("equipment", [])
		if raw is Array:
			items = (raw as Array).duplicate()
	elif "equipment" in member and member.equipment is Array:
		items = member.equipment.duplicate()
	if items.is_empty():
		return 0

	# The campaign goes in through _init — there is no setter, and _init asserts
	# on null, so the owner guard above is load-bearing rather than defensive.
	var service = EquipmentTransferServiceRef.new(campaign)
	var moved: int = 0
	for item in items:
		var item_id: String = ""
		if item is Dictionary:
			item_id = str((item as Dictionary).get("id", ""))
		elif item is String:
			item_id = str(item)
		if item_id.is_empty():
			continue
		if service.has_method("transfer_to_stash") \
				and service.transfer_to_stash(item_id, crew_id):
			moved += 1
	return moved
