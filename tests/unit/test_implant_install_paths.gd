extends GdUnitTestSuite
## Implants reach a crew member of either shape, and Nullification surgery works.
##
## Compendium p.27 sells Nullification surgery (Implant, 3 Credits): "The character
## permanently loses all psionic abilities." The trade panel charged 3 credits and
## put it in the stash, where nothing could ever install it. The loot path had the
## same hole one layer down: it installed implants only on Character resources, and
## a loaded campaign holds its crew as Dictionaries, so on every loaded save a looted
## implant went to the stash. One rule, Character.install_implant_on_member(), now
## serves both, following add_implant(): the species cap, one of each type, Core
## Rules p.55 "Bots and Soulless cannot use implants", and Compendium p.18's
## permanent loss of psionics.

const CharacterRef = preload("res://src/core/character/Character.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const LootProcessor = preload("res://src/core/campaign/phases/post_battle/LootProcessor.gd")
const TradePanel = preload("res://src/ui/screens/campaign/phases/TradePhasePanel.gd")
const TRADE_SCENE := "res://src/ui/screens/campaign/phases/TradePhasePanel.tscn"
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _snap: Dictionary = {}
var _prev_campaign = null
var _campaign = null


func before_test() -> void:
	_snap = SaveDirGuard.snapshot()
	_prev_campaign = get_node("/root/GameState").current_campaign


func after_test() -> void:
	get_node("/root/GameState").current_campaign = _prev_campaign
	SaveDirGuard.restore(_snap)


func _member(name: String, species: String, powers: Array = []) -> Dictionary:
	return {"character_name": name, "species_id": species, "psionic_powers": powers,
		"implants": [], "is_bot": false}


func _implant(type: String) -> Dictionary:
	return {"type": type, "name": type.capitalize(), "stat_bonus": {}, "description": ""}


func _use(crew: Array, credits: int = 10) -> void:
	_campaign = CampaignCore.new()
	_campaign.credits = credits
	_campaign.crew_data = {"members": crew}
	get_node("/root/GameState").current_campaign = _campaign


func test_a_saved_crew_member_takes_an_implant() -> void:
	var m := _member("Ana", "human")
	assert_bool(CharacterRef.install_implant_on_member(m, _implant("BODY_WIRE"))).is_true()
	assert_int((m["implants"] as Array).size()).is_equal(1)
	# One of each type.
	assert_bool(CharacterRef.install_implant_on_member(m, _implant("BODY_WIRE"))).is_false()


func test_the_saved_shape_keeps_the_species_cap() -> void:
	var human := _member("Ana", "human")
	for t in ["A", "B"]:
		assert_bool(CharacterRef.install_implant_on_member(human, _implant(t))).is_true()
	assert_bool(CharacterRef.install_implant_on_member(human, _implant("C"))).is_false()
	# Core Rules p.23: an Empath takes none; p.19: De-converted up to 3.
	assert_bool(CharacterRef.install_implant_on_member(_member("E", "empath"), _implant("A"))).is_false()
	var dc := _member("D", "de_converted")
	for t in ["A", "B", "C"]:
		assert_bool(CharacterRef.install_implant_on_member(dc, _implant(t))).is_true()
	assert_bool(CharacterRef.install_implant_on_member(dc, _implant("D"))).is_false()


func test_bots_and_soulless_cannot_use_implants() -> void:
	# Core Rules p.55, both shapes.
	var bot := _member("Unit", "human")
	bot["is_bot"] = true
	assert_bool(CharacterRef.install_implant_on_member(bot, _implant("A"))).is_false()
	assert_bool(CharacterRef.install_implant_on_member(_member("S", "soulless"), _implant("A"))).is_false()
	var res := CharacterRef.new()
	res.is_soulless = true
	assert_bool(CharacterRef.install_implant_on_member(res, _implant("A"))).is_false()


func test_an_implant_ends_psionics_on_a_saved_member() -> void:
	# Compendium p.18: permanently, even if the implant is later removed.
	var m := _member("Ana", "human", ["barrier"])
	assert_bool(CharacterRef.member_has_psionics(m)).is_true()
	CharacterRef.install_implant_on_member(m, _implant("A"))
	assert_bool(CharacterRef.member_has_psionics(m)).is_false()
	assert_bool(bool(m.get("psionics_lost_to_implant"))).is_true()


func test_loot_installs_an_implant_on_a_loaded_crew() -> void:
	var m := _member("Ana", "human")
	_use([m])
	var loot := LootProcessor.new()
	assert_bool(loot._try_install_implant_from_loot("AI Companion")).is_true()
	assert_int((_campaign.crew_data["members"][0]["implants"] as Array).size()).is_equal(1)


func test_only_a_psionic_with_room_is_offered_the_surgery() -> void:
	var psi := _member("Psi", "human", ["barrier"])
	var plain := _member("Plain", "human")
	var full := _member("Full", "human", ["grab"])
	full["implants"] = [_implant("A"), _implant("B")]
	assert_array(TradePanel.nullification_candidates([psi, plain, full])).is_equal(["Psi"])


func test_the_surgery_is_installed_and_charged() -> void:
	var psi := _member("Psi", "human", ["barrier"])
	_use([psi], 10)
	var panel: Control = auto_free((load(TRADE_SCENE) as PackedScene).instantiate())
	add_child(panel)
	panel.setup_phase()
	panel.selected_market_item = {"id": "nullification_surgery", "name": "Nullification surgery",
		"value": 3}
	panel._on_nullification_target_chosen("Psi", 3)
	var after: Dictionary = _campaign.crew_data["members"][0]
	assert_int((after["implants"] as Array).size()).is_equal(1)
	assert_bool(CharacterRef.member_has_psionics(after)).is_false()
	assert_int(panel.current_credits).is_equal(7)


func test_buying_the_surgery_asks_who_rather_than_stashing_it() -> void:
	# The Buy press must not charge, and must not drop the surgery in the stash:
	# it opens the chooser, and the charge happens when a psionic is picked.
	var psi := _member("Psi", "human", ["barrier"])
	_use([psi], 10)
	var panel: Control = auto_free((load(TRADE_SCENE) as PackedScene).instantiate())
	add_child(panel)
	panel.setup_phase()
	var stash_before: int = (_campaign.equipment_data.get("equipment", []) as Array).size()
	panel.selected_market_item = {"id": "nullification_surgery", "name": "Nullification surgery",
		"value": 3}
	panel._on_buy_button_pressed()
	assert_int((_campaign.equipment_data.get("equipment", []) as Array).size()).is_equal(stash_before)
	assert_int(panel.current_credits).is_equal(10)
	var chooser: Window = null
	for child in panel.get_children():
		if child is Window and child.title == "Nullification surgery":
			chooser = child
	assert_object(chooser).is_not_null()
