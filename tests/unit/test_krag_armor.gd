extends GdUnitTestSuite

## Krag armor designation (Compendium p.15). is_armor_item tolerates both item
## representations (enum category OR string type); modify_armor_for_krag charges 2
## credits and toggles the Krag fit, or fails when the crew can't afford it.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _gs
var _saved

func before_test() -> void:
	_gs = get_node_or_null("/root/GameState")
	_saved = _gs.current_campaign if _gs and "current_campaign" in _gs else null
	_gs.current_campaign = CampaignCore.new()

func after_test() -> void:
	_gs.current_campaign = _saved

func test_is_armor_item_string_type() -> void:
	assert_bool(EquipmentManager.is_armor_item({"type": "armor", "name": "Combat Armor"})).is_true()

func test_is_armor_item_enum_category() -> void:
	assert_bool(EquipmentManager.is_armor_item(
		{"category": EquipmentManager.EquipmentCategory.ARMOR})).is_true()

func test_is_armor_item_weapon_is_false() -> void:
	assert_bool(EquipmentManager.is_armor_item({"type": "weapon", "name": "Rifle"})).is_false()

func test_modify_for_krag_with_credits_toggles_and_charges() -> void:
	GameStateManager.set_credits(10)
	var item := {"type": "armor", "name": "Combat Armor"}
	assert_bool(EquipmentManager.modify_armor_for_krag(item)).is_true()
	assert_bool(item.get("is_krag_armor", false)).is_true()
	assert_int(GameStateManager.get_credits()).is_equal(8)

func test_modify_for_krag_insufficient_credits_fails() -> void:
	GameStateManager.set_credits(1)
	var item := {"type": "armor"}
	assert_bool(EquipmentManager.modify_armor_for_krag(item)).is_false()
	assert_bool(item.has("is_krag_armor")).is_false()
	assert_int(GameStateManager.get_credits()).is_equal(1)

func test_modify_for_krag_non_armor_fails() -> void:
	GameStateManager.set_credits(10)
	assert_bool(EquipmentManager.modify_armor_for_krag({"type": "weapon"})).is_false()
	assert_int(GameStateManager.get_credits()).is_equal(10)  # no charge
