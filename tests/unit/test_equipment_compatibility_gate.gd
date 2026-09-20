extends GdUnitTestSuite

## EquipmentManager.can_character_use_equipment — the compatibility gate that
## returned true unconditionally, and the fabricated rule that lived inside it.
##
## THE DEFECT (found 2026-09-10): every branch dispatched on
## `equipment_data.get("category", EquipmentCategory.GEAR)`. The function's ONLY
## caller is EquipmentPanel.gd:821, which passes items built by
## _create_equipment_item() — and that stamps `type: "Weapon"/"Armor"/"Gear"` as a
## STRING and never writes `category`. So category defaulted to GEAR for every
## item and NO branch could ever fire: a permanently-TRUE gate, the mirror image
## of the permanently-false has_method guards `lint_dead_has_method_guards.py`
## exists to catch. The dispatch now uses the tolerant is_weapon_item() /
## is_armor_item() tests the live World-Phase path already used.
##
## THE FABRICATION: the armor branch carried
## `if armor_type == GameEnums.ArmorType.HEAVY and char_toughness < 3: return false`.
## Core Rules pp.54-55 list all nine protective devices (Battle dress, Camo cloak,
## Combat armor, Deflector field, Flak screen, Flex-armor, Frag vest, Screen
## generator, Stealth gear) and have NO weight classes and NO Toughness
## requirement. The only constraint the book states is "A character may wear no
## more than one piece of armor and one screen" (p.54), delivered on the Cheat
## Sheet. `armor_type` as an enum appears in ZERO data files, and the comparison
## was int-vs-String besides. Removed.
##
## ⚠ SCOPE, stated so nobody over-reads these cases: this gate protects
## EquipmentManager's per-character CACHE, not what a campaign persists.
## CampaignFinalizationService never consults this manager — it builds
## campaign.equipment_data from the wizard's own dictionary via
## split_equipment_by_owner(), keyed on item["owner"].

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _gs
var _saved_campaign

func before_test() -> void:
	_gs = get_node_or_null("/root/GameState")
	_saved_campaign = _gs.current_campaign if _gs and "current_campaign" in _gs else null
	_gs.current_campaign = CampaignCore.new()

func after_test() -> void:
	_gs.current_campaign = _saved_campaign


## The shape EquipmentPanel._create_equipment_item() actually produces: a STRING
## `type`, no `category` key. Every case below uses it deliberately — that is the
## whole point, since the enum form was never the thing reaching this function.
func _panel_weapon(name: String, traits: Array) -> Dictionary:
	return {"type": "Weapon", "name": name, "traits": traits}

func _panel_armor(name: String) -> Dictionary:
	return {"type": "Armor", "name": name}


# ── is_weapon_item: the tolerant test that was missing ──────────────────────

func test_is_weapon_item_accepts_the_string_form_data_actually_uses() -> void:
	assert_bool(EquipmentManager.is_weapon_item({"type": "Weapon", "name": "Hand Laser"})).is_true()

func test_is_weapon_item_accepts_the_enum_form_generated_items_use() -> void:
	assert_bool(EquipmentManager.is_weapon_item(
		{"category": EquipmentManager.EquipmentCategory.WEAPON})).is_true()

func test_is_weapon_item_rejects_armor() -> void:
	assert_bool(EquipmentManager.is_weapon_item(
		{"type": "Armor", "name": "Combat Armor"})).is_false()


# ── Compendium p.18: Psionics use Pistol or Melee weapons only ──────────────

func test_a_psionic_is_refused_a_weapon_with_neither_trait() -> void:
	var psionic := {"name": "Vell", "psionic_power": "Barrier"}
	var rattle_gun := _panel_weapon("Rattle Gun", ["Heavy", "Area"])
	assert_bool(EquipmentManager.can_character_use_equipment(
		psionic, rattle_gun)).is_false()

func test_a_psionic_may_take_a_pistol() -> void:
	var psionic := {"name": "Vell", "psionic_power": "Barrier"}
	assert_bool(EquipmentManager.can_character_use_equipment(
		psionic, _panel_weapon("Hand Gun", ["Pistol"]))).is_true()

func test_a_psionic_may_take_a_melee_weapon() -> void:
	var psionic := {"name": "Vell", "psionic_powers": ["Barrier", "Shock"]}
	assert_bool(EquipmentManager.can_character_use_equipment(
		psionic, _panel_weapon("Blade", ["Melee"]))).is_true()

func test_a_non_psionic_may_take_anything() -> void:
	## The discriminating control. Without it every case above would still pass
	## with the gate refusing that weapon for everyone.
	var ordinary := {"name": "Ila"}
	assert_bool(EquipmentManager.can_character_use_equipment(
		ordinary, _panel_weapon("Rattle Gun", ["Heavy", "Area"]))).is_true()


# ── Compendium p.13: Krag armor fit ─────────────────────────────────────────

func test_a_krag_is_refused_armor_that_is_not_krag_fitted() -> void:
	var krag := {"name": "Bruul", "species_id": "krag"}
	assert_bool(EquipmentManager.can_character_use_equipment(
		krag, _panel_armor("Combat Armor"))).is_false()

func test_a_krag_may_wear_krag_fitted_armor() -> void:
	var krag := {"name": "Bruul", "species_id": "krag"}
	var fitted := _panel_armor("Combat Armor")
	fitted["is_krag_armor"] = true
	assert_bool(EquipmentManager.can_character_use_equipment(krag, fitted)).is_true()

func test_krag_fitted_armor_is_refused_to_an_ordinary_human() -> void:
	var human := {"name": "Ila", "species_id": "human"}
	var fitted := _panel_armor("Combat Armor")
	fitted["is_krag_armor"] = true
	assert_bool(EquipmentManager.can_character_use_equipment(human, fitted)).is_false()

func test_a_skulker_wears_either_without_modification() -> void:
	## Compendium p.13: "Skulkers and Engineers can wear both Krag and non-Krag
	## armor without modification." p.15 (the Skulker page) says the same.
	var skulker := {"name": "Tsk", "species_id": "skulker"}
	var fitted := _panel_armor("Combat Armor")
	fitted["is_krag_armor"] = true
	assert_bool(EquipmentManager.can_character_use_equipment(skulker, fitted)).is_true()
	assert_bool(EquipmentManager.can_character_use_equipment(
		skulker, _panel_armor("Combat Armor"))).is_true()

func test_an_engineer_wears_either_without_modification() -> void:
	var engineer := {"name": "Sev", "species_id": "human", "character_class": "Engineer"}
	var fitted := _panel_armor("Combat Armor")
	fitted["is_krag_armor"] = true
	assert_bool(EquipmentManager.can_character_use_equipment(engineer, fitted)).is_true()


# ── The fabricated rule must not come back ─────────────────────────────────

func test_a_toughness_one_character_may_wear_any_armor() -> void:
	## REGRESSION GUARD for the deleted "Heavy armor requires Toughness 3+" gate.
	## No weight classes exist in Core Rules pp.54-55 and no armor carries a
	## Toughness requirement, so a Toughness-1 character wearing Combat Armor is
	## simply legal. If someone re-adds a weight gate, this goes red.
	var frail := {"name": "Ila", "toughness": 1}
	assert_bool(EquipmentManager.can_character_use_equipment(
		frail, _panel_armor("Combat Armor"))).is_true()
	var heavy := _panel_armor("Battle Dress")
	heavy["armor_type"] = "heavy"  # the STRING form BattleCalculations uses
	assert_bool(EquipmentManager.can_character_use_equipment(frail, heavy)).is_true()

func test_no_armor_in_the_shipped_database_carries_an_armor_type_weight() -> void:
	## The fabricated gate read `armor_type` as a GameEnums.ArmorType ordinal. Not
	## one shipped armor entry has the key at all, which is half of why the branch
	## was unreachable — assert that from the FILE so a future data edit that
	## introduces weight classes is noticed rather than silently re-enabling a rule
	## the book does not have.
	var file := FileAccess.open("res://data/equipment_database.json", FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	var parsed: int = json.parse(file.get_as_text())
	file.close()
	assert_int(parsed).is_equal(OK)
	var armor: Array = json.data.get("armor", [])
	assert_int(armor.size()).is_greater(0)
	for entry in armor:
		if entry is Dictionary:
			assert_bool(entry.has("armor_type")).override_failure_message(
				"%s gained an armor_type; Core Rules pp.54-55 have no weight classes"
				% str(entry.get("name", "?"))).is_false()


# ── Core Rules p.54: one piece of armor ────────────────────────────────────

func test_the_one_armor_slot_rule_can_now_recognise_shipped_armor() -> void:
	## "A character may wear no more than one piece of armor and one screen."
	## assign_equipment_to_character() enforced the armor half through the SAME
	## dead `category` enum the compatibility gate used, so it never fired either;
	## it now calls is_armor_item().
	##
	## ⚠ This asserts the PREDICATE, not the replacement. Driving the swap needs a
	## character registered in EquipmentManager's CharacterManager, which this
	## suite deliberately does not build — and a case named for a replacement it
	## never performs would be exactly the false green this project has found
	## eleven times. What is pinned here is the half that was broken: the slot
	## logic could not recognise a shipped armor item at all.
	for name in ["Combat Armor", "Flex-Armor", "Frag Vest", "Battle Dress"]:
		assert_bool(EquipmentManager.is_armor_item(_panel_armor(name))) \
			.override_failure_message("%s not recognised as armor by the slot rule" % name) \
			.is_true()
	## And the enum form the old test would have used, so both representations
	## stay covered if generated market items ever reach this path.
	assert_bool(EquipmentManager.is_armor_item(
		{"category": EquipmentManager.EquipmentCategory.ARMOR})).is_true()
