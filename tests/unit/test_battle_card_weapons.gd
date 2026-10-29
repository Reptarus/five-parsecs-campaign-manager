extends GdUnitTestSuite
## The battle screen's figure cards name the weapons each figure carries.
##
## CharacterStatusCard prints "Weapon: ..." from a `weapon_name` key at tier 1 and
## above. TacticalBattleUI builds each card's dict from the live TacticalUnit in
## _unit_card_dict(), and that dict never carried the key, so no card ever named a
## weapon, in the campaign or in the Battle Simulator (whose crew dicts did set it).
## A Hand Cannon is the case a name-substring filter would miss ("cannon" is not
## "gun"), which is why the crew side reads the equipment database instead.

const TBUI := preload("res://src/ui/screens/battle/TacticalBattleUI.gd")
const CARD := preload("res://src/ui/components/battle/CharacterStatusCard.tscn")


func _card_dict(source: Dictionary, is_crew: bool) -> Dictionary:
	var ui: Node = auto_free(TBUI.new())
	var unit = TBUI.TacticalUnit.new()
	if is_crew:
		unit.initialize_from_crew_member(source)
	else:
		unit.initialize_from_enemy(source)
	return ui._unit_card_dict(unit)


func test_a_crew_card_names_its_weapons_and_not_its_armor() -> void:
	var d := _card_dict({"name": "Ana",
		"equipment": ["Hand Cannon", "Combat Armor", "Colony Rifle"]}, true)
	assert_str(str(d.get("weapon_name", ""))).is_equal("Hand Cannon, Colony Rifle")


func test_an_enemy_card_names_its_generated_loadout() -> void:
	var d := _card_dict({"name": "Raider", "weapons": ["Colony Rifle", "Blade"]}, false)
	assert_str(str(d.get("weapon_name", ""))).is_equal("Colony Rifle, Blade")


func test_the_card_shows_the_weapon_line() -> void:
	var card: Node = auto_free(CARD.instantiate())
	add_child(card)
	await await_idle_frame()
	# The screen's order (TacticalBattleUI._populate_unit_drawer): data, then tier.
	card.set_character_data(_card_dict({"name": "Ana", "equipment": ["Hand Cannon"]}, true))
	card.set_display_tier(1)
	assert_str(card.stats_label.get_parsed_text()).contains("Weapon: Hand Cannon")


func test_a_tap_on_the_card_keeps_its_tier_strip() -> void:
	var card: Node = auto_free(CARD.instantiate())
	add_child(card)
	await await_idle_frame()
	card.set_character_data(_card_dict({"name": "Ana", "equipment": ["Hand Cannon"]}, true))
	card.set_display_tier(1)
	card.add_stun_marker()
	var text: String = card.stats_label.get_parsed_text()
	assert_str(text).contains("Weapon: Hand Cannon")
	assert_str(text).contains("Savvy")
