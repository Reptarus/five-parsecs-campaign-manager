extends GdUnitTestSuite

## Compendium p.13, FIRST Krag armor clause — the free Trade-roll selection.
##
## Verbatim (PyPDF2 idx 14, page tail reads "13Character Options"):
##
##   "Armor acquired from a Trade table roll must be selected by the player to be
##    Krag-armor or not. Krag-armor is designed to fit Krag only, although
##    Skulkers and Engineers can wear both Krag and non-Krag armor without
##    modification."
##   "Armor found from other sources will not fit Krag. Armor can be modified to
##    fit Krag for 2 Credits (and reversed for the same cost), while doing your
##    shopping during Post-battle Step 11: Purchase Items."
##
## Clause 2 was live and correct. CLAUSE 1 HAD NO IMPLEMENTATION AT ALL until
## 2026-09-10: the only writer of `is_krag_armor` anywhere in the codebase was the
## 2-credit toggle, so every piece of armor in the game arrived non-Krag and a
## Krag paid 2 Credits for all of it — including the one case the book gives away.
##
## The signal that was supposed to carry it, `acquired_from_trade`, was stamped by
## EquipmentManager._generate_random_db_armor() — a function inside a nine-strong
## dead generation component, with zero callers — and had zero readers. Both ends
## missing is why no census found it: there was no key mismatch to grep, only a
## parameter nobody passed.
##
## The chain is REACHABLE, not theoretical: Trade rows 45-48 and 87-91 route to
## the p.131 Loot Table, whose gear_subtable yields "Combat Armor" and
## "Flex-Armor", both of which live in equipment_database.json's `armor` array.

const CrewTaskComponentClass = preload(
	"res://src/ui/screens/world/components/CrewTaskComponent.gd")
const AssignEquipmentComponentClass = preload(
	"res://src/ui/screens/world/components/AssignEquipmentComponent.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _gs
var _saved_campaign

func before_test() -> void:
	_gs = get_node_or_null("/root/GameState")
	_saved_campaign = _gs.current_campaign if _gs and "current_campaign" in _gs else null
	_gs.current_campaign = CampaignCore.new()

func after_test() -> void:
	_gs.current_campaign = _saved_campaign


func _trade_armor() -> Dictionary:
	return {"type": "Armor", "name": "Combat Armor", "acquired_from_trade": true}

func _looted_armor() -> Dictionary:
	## Armor from a battlefield salvage roll — "found from other sources" (clause 2).
	return {"type": "Armor", "name": "Combat Armor"}


# ── The free selection exists, and only where the book says it does ──────────

func test_armor_off_a_trade_roll_is_owed_a_free_selection() -> void:
	assert_bool(EquipmentManager.has_unspent_krag_choice(_trade_armor())).is_true()

func test_armor_from_any_other_source_is_owed_nothing() -> void:
	## This is the whole distinction the rule turns on. If this case ever goes
	## green-for-the-wrong-reason the free fit becomes universal and clause 2
	## (the 2-credit charge) stops being reachable at all.
	assert_bool(EquipmentManager.has_unspent_krag_choice(_looted_armor())).is_false()

func test_a_trade_acquired_weapon_is_not_offered_an_armor_choice() -> void:
	var rifle := {"type": "weapon", "name": "Hand Laser", "acquired_from_trade": true}
	assert_bool(EquipmentManager.has_unspent_krag_choice(rifle)).is_false()


# ── Spending it: free, one-shot, and un-forgeable ────────────────────────────

func test_the_free_fit_costs_nothing_and_marks_the_choice_spent() -> void:
	GameStateManager.set_credits(10)
	var item := _trade_armor()
	assert_bool(EquipmentManager.choose_krag_fit(item, true)).is_true()
	assert_bool(item.get("is_krag_armor", false)).is_true()
	assert_bool(item.get("krag_fit_chosen", false)).is_true()
	# The entire point of the rule: p.13 clause 1 charges NOTHING.
	assert_int(GameStateManager.get_credits()).is_equal(10)

func test_the_free_fit_is_refused_on_armor_that_did_not_come_from_a_trade_roll() -> void:
	## Without this guard the new call would be a free bypass of the 2-credit
	## charge for ALL armor — a strictly worse defect than the one it fixes.
	GameStateManager.set_credits(10)
	var item := _looted_armor()
	assert_bool(EquipmentManager.choose_krag_fit(item, true)).is_false()
	assert_bool(item.has("is_krag_armor")).is_false()
	assert_int(GameStateManager.get_credits()).is_equal(10)

func test_the_free_choice_is_one_shot() -> void:
	GameStateManager.set_credits(10)
	var item := _trade_armor()
	assert_bool(EquipmentManager.choose_krag_fit(item, true)).is_true()
	# "must be SELECTED by the player" — one selection, not a free toggle.
	assert_bool(EquipmentManager.choose_krag_fit(item, false)).is_false()
	assert_bool(item.get("is_krag_armor", false)).is_true()
	assert_int(GameStateManager.get_credits()).is_equal(10)

func test_reversing_the_free_fit_afterwards_costs_two_credits() -> void:
	## "(and reversed for the same cost)" — the free selection does not make the
	## item permanently free to flip.
	GameStateManager.set_credits(10)
	var item := _trade_armor()
	assert_bool(EquipmentManager.choose_krag_fit(item, true)).is_true()
	assert_int(GameStateManager.get_credits()).is_equal(10)
	assert_bool(EquipmentManager.modify_armor_for_krag(item)).is_true()
	assert_bool(item.get("is_krag_armor", false)).is_false()
	assert_int(GameStateManager.get_credits()).is_equal(8)

func test_selecting_not_krag_armor_also_spends_the_choice() -> void:
	## The book's selection is "Krag-armor or not", so both answers are answers.
	## Nothing in the UI offers the "not" button (see _offer_free_krag_fit's
	## docblock for why), but the rule layer must still honour it.
	var item := _trade_armor()
	assert_bool(EquipmentManager.choose_krag_fit(item, false)).is_true()
	assert_bool(item.get("is_krag_armor", true)).is_false()
	assert_bool(EquipmentManager.has_unspent_krag_choice(item)).is_false()


# ── The bridge: an event knows which table it came off ───────────────────────

func test_a_trade_event_is_recognised_from_the_result_it_carries() -> void:
	var comp = auto_free(CrewTaskComponentClass.new())
	add_child(comp)
	# This is the real shape _build_event_queue() produces: base["result_ref"]
	# is the LIVE result dict, and base.duplicate() is shallow so every
	# classified event carries that same reference.
	var event := {"result_ref": {"task_id": "trade", "task_name": "Trade"}}
	assert_bool(comp._is_trade_event(event)).is_true()

func test_an_explore_event_is_not_a_trade_event() -> void:
	## Compendium p.13 says "a Trade table roll" — the Exploration table is a
	## different table and grants no free fit. If this case ever passes for the
	## wrong reason, half the crew-task rewards silently become free Krag armor.
	var comp = auto_free(CrewTaskComponentClass.new())
	add_child(comp)
	var event := {"result_ref": {"task_id": "explore", "task_name": "Explore"}}
	assert_bool(comp._is_trade_event(event)).is_false()

func test_an_event_with_no_result_reference_is_not_a_trade_event() -> void:
	var comp = auto_free(CrewTaskComponentClass.new())
	add_child(comp)
	assert_bool(comp._is_trade_event({})).is_false()
	assert_bool(comp._is_trade_event({"result_ref": "not a dictionary"})).is_false()


# ── The producer: armor reaching the stash carries its provenance ────────────

func _stash_entry(comp, item_name: String, from_trade: bool) -> Dictionary:
	## Add one item and hand back the dict that actually landed in storage.
	## Reads the cache rather than clearing it, so this suite never destroys
	## equipment state a sibling suite may be relying on.
	var before: int = EquipmentManager.get_all_equipment().size()
	comp._add_item_to_stash(item_name, from_trade)
	var after: Array = EquipmentManager.get_all_equipment()
	if after.size() <= before:
		return {}
	return after[after.size() - 1]

func test_armor_from_a_trade_roll_reaches_the_stash_carrying_its_provenance() -> void:
	var comp = auto_free(CrewTaskComponentClass.new())
	add_child(comp)
	var landed: Dictionary = _stash_entry(comp, "Combat Armor", true)
	assert_str(str(landed.get("name", ""))).is_equal("Combat Armor")
	assert_bool(landed.get("acquired_from_trade", false)).is_true()
	assert_bool(EquipmentManager.has_unspent_krag_choice(landed)).is_true()

func test_the_same_armor_from_anywhere_else_reaches_the_stash_unmarked() -> void:
	## THE DISCRIMINATING CONTROL. Without it every case above would still pass
	## with _add_item_to_stash() stamping unconditionally — which would hand the
	## free fit to battlefield loot and salvage too.
	var comp = auto_free(CrewTaskComponentClass.new())
	add_child(comp)
	var landed: Dictionary = _stash_entry(comp, "Combat Armor", false)
	assert_str(str(landed.get("name", ""))).is_equal("Combat Armor")
	assert_bool(landed.has("acquired_from_trade")).is_false()
	assert_bool(EquipmentManager.has_unspent_krag_choice(landed)).is_false()

func test_a_non_armor_trade_reward_is_not_stamped() -> void:
	## The key is meaningful for armor alone; stamping every grenade would grow
	## each save file with a bool no reader will ever consult.
	var comp = auto_free(CrewTaskComponentClass.new())
	add_child(comp)
	var landed: Dictionary = _stash_entry(comp, "Frakk Grenade", true)
	assert_bool(landed.has("acquired_from_trade")).is_false()


# ── The wiring: the real handlers pass provenance through ───────────────────
#
# Everything above drives _add_item_to_stash() directly, so all five call
# sites could stop passing _is_trade_event(event_data) with the suite still
# green. These drive the HANDLERS instead — the documented "test the screen,
# not just the builder it calls" trap, which is how both sheet-export
# device defects hid behind 28 passing tests.

func _trade_loot_event() -> Dictionary:
	## The shape _build_event_queue() -> _classify_result() actually produces
	## for a Trade row that says "roll on the Loot Table".
	return {
		"type": CrewTaskEventDialog.EventType.ROLL_ON_TABLE,
		"items_to_resolve": ["Combat Armor"],
		"result_ref": {"task_id": "trade", "task_name": "Trade"},
	}

func test_the_auto_resolve_handler_carries_provenance_to_the_stash() -> void:
	var comp = auto_free(CrewTaskComponentClass.new())
	add_child(comp)
	var before: int = EquipmentManager.get_all_equipment().size()
	comp._auto_resolve_event(_trade_loot_event())
	var after: Array = EquipmentManager.get_all_equipment()
	assert_int(after.size()).is_greater(before)
	assert_bool(after[after.size() - 1].get("acquired_from_trade", false)).is_true()

func test_the_auto_resolve_handler_does_not_invent_provenance_for_explore() -> void:
	## The control arm. Without it the case above would still pass with the
	## call site hardcoding `true`, which would hand the free fit to every
	## Exploration reward as well.
	var comp = auto_free(CrewTaskComponentClass.new())
	add_child(comp)
	var event: Dictionary = _trade_loot_event()
	event["result_ref"] = {"task_id": "explore", "task_name": "Explore"}
	var before: int = EquipmentManager.get_all_equipment().size()
	comp._auto_resolve_event(event)
	var after: Array = EquipmentManager.get_all_equipment()
	assert_int(after.size()).is_greater(before)
	assert_bool(after[after.size() - 1].has("acquired_from_trade")).is_false()

func test_the_interactive_handler_carries_provenance_to_the_stash() -> void:
	## The other handler family. _on_event_completed() is what the dialog and
	## the narrative path both route through (_present_crew_event_via_narrative
	## calls _on_event_completed({}, event_data)), so this covers all three
	## presentation modes.
	var comp = auto_free(CrewTaskComponentClass.new())
	add_child(comp)
	var before: int = EquipmentManager.get_all_equipment().size()
	comp._on_event_completed({}, _trade_loot_event())
	var after: Array = EquipmentManager.get_all_equipment()
	assert_int(after.size()).is_greater(before)
	assert_bool(after[after.size() - 1].get("acquired_from_trade", false)).is_true()


# ── The consumer: the assign screen has somewhere to route to ────────────────

## These build the component but deliberately do NOT add it to the tree.
## AssignEquipmentComponent._ready() builds a detail strip and registers
## $VBoxContainer/MainContainer, neither of which exists on a bare .new(), so an
## add_child()'d instance leaks 3 orphan nodes per case. Everything asserted
## below is reachable without the tree: _is_krag_member() only reads its
## argument, and the provenance half is an autoload call.
func test_the_assign_screen_exposes_the_free_fit_branch() -> void:
	## A text scan cannot see a file that stopped compiling (Sep 3 2026), so this
	## instantiates the script and asks the object. It is the cheapest guard that
	## the free-fit path was not deleted or renamed out from under the router in
	## _offer_krag_modification().
	var comp = auto_free(AssignEquipmentComponentClass.new())
	assert_bool(comp.has_method("_offer_free_krag_fit")).is_true()
	assert_bool(comp.has_method("_offer_krag_modification")).is_true()

func test_trade_armor_satisfies_both_halves_of_the_routing_condition() -> void:
	## _offer_krag_modification() is reached when _krag_needs_modification() is
	## true, and routes to the FREE clause when has_unspent_krag_choice() is ALSO
	## true. Assert the two agree on one item, or the free branch is unreachable in
	## product however correct each predicate is on its own.
	##
	## _krag_needs_modification() is that conjunction: a Krag, an armor item, and
	## not already Krag-fitted. It is decomposed here so the component never needs
	## the tree -- same three facts, no orphans.
	var comp = auto_free(AssignEquipmentComponentClass.new())
	var krag := {"species_id": "krag", "character_name": "Bruul"}
	var item := _trade_armor()
	assert_bool(comp._is_krag_member(krag)).is_true()
	assert_bool(EquipmentManager.is_armor_item(item)).is_true()
	assert_bool(item.get("is_krag_armor", false)).is_false()
	assert_bool(EquipmentManager.has_unspent_krag_choice(item)).is_true()

## Build an AssignEquipmentComponent that is IN THE TREE (the predicate below
## resolves /root/EquipmentManager, and a detached node calling
## get_node_or_null on an absolute path ERRORS and aborts the caller) without
## leaking the detail strip.
##
## _build_detail_strip() makes an HBox + 2 PanelContainers and inserts them
## before ConfirmButton. A bare .new() has no authored scene tree, so that
## insert never happens and the 3 nodes are built-but-unparented. In product
## the .tscn supplies ConfirmButton and they are parented normally — this is
## an artefact of script-only instantiation, so it is handled here rather than
## by changing the component.
func _routing_component():
	var comp = auto_free(AssignEquipmentComponentClass.new())
	add_child(comp)
	if comp._detail_strip != null and not comp._detail_strip.is_inside_tree():
		auto_free(comp._detail_strip)
	return comp

func test_the_router_sends_trade_armor_down_the_free_clause() -> void:
	## The predicate _offer_krag_modification() branches on. Without this the
	## free clause has no detection arm: both clauses build the same popup
	## class, so nothing downstream can tell which branch ran.
	assert_bool(_routing_component()._krag_fit_is_free(_trade_armor())).is_true()

func test_the_router_sends_looted_armor_down_the_two_credit_clause() -> void:
	## The discriminating half. If this returns true, every piece of armor in
	## the game becomes free to fit and clause 2 stops being reachable.
	var comp = _routing_component()
	assert_bool(comp._krag_fit_is_free(_looted_armor())).is_false()
	assert_bool(comp._krag_fit_is_free("not a dictionary")).is_false()

func test_a_non_krag_is_never_asked_about_krag_fit() -> void:
	## The situational half of the rule: a crew with no Krag must never see this
	## dialog, whatever provenance its armor carries. This is what keeps the fix
	## from putting a popup in front of every player who ever loots armor.
	var comp = auto_free(AssignEquipmentComponentClass.new())
	assert_bool(comp._is_krag_member({"species_id": "human", "character_name": "Ila"})).is_false()
	assert_bool(comp._is_krag_member({"species_id": "skulker"})).is_false()
	## Legacy saves store species under `origin`, so the predicate reads both.
	assert_bool(comp._is_krag_member({"origin": "krag"})).is_true()
