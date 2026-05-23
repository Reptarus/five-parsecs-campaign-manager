extends GdUnitTestSuite
## Weapon trait KeywordDB coverage contract (Sprint 2 F3)
##
## WeaponTableDisplay._get_trait_description() used to hold a hardcoded
## 14-entry trait table duplicating KeywordDB. Sprint 2 F3 deleted that table
## in favour of KeywordDB as the single source of truth.
##
## This test pins down the contract so a future agent re-adding a trait can't
## silently break the lookup:
##   1. All 14 Core Rules weapon traits resolve to a non-empty definition
##   2. Space → underscore normalization works ("Single use" → single_use)
##   3. Unknown traits return "Unknown term" category (not crash)
##
## gdUnit4 v6.0.3 compatible.

const WEAPON_TRAITS_CORE_RULES: Array = [
	"Area", "Clumsy", "Critical", "Elegant", "Focused", "Heavy",
	"Impact", "Melee", "Piercing", "Pistol", "Single use",
	"Snap Shot", "Stun", "Terrifying",
]


func _resolve_trait(trait_name: String) -> Dictionary:
	var kdb: Node = Engine.get_main_loop().root.get_node_or_null("/root/KeywordDB")
	assert_object(kdb).is_not_null()
	var lookup: String = trait_name.strip_edges()
	var entry: Dictionary = kdb.get_keyword(lookup)
	if str(entry.get("category", "")) == "unknown":
		entry = kdb.get_keyword(lookup.replace(" ", "_"))
	return entry


func test_all_core_rules_weapon_traits_resolve_with_non_empty_definition() -> void:
	for trait_name in WEAPON_TRAITS_CORE_RULES:
		var entry: Dictionary = _resolve_trait(trait_name)
		var def: String = str(entry.get("definition", ""))
		var category: String = str(entry.get("category", ""))
		assert_bool(category != "unknown").override_failure_message(
			"Trait '%s' not found in KeywordDB (category=unknown)" % trait_name
		).is_true()
		assert_bool(not def.is_empty()).override_failure_message(
			"Trait '%s' has empty definition in KeywordDB" % trait_name
		).is_true()


func test_space_to_underscore_normalization_works() -> void:
	# "Single use" displays with space, KeywordDB key is single_use.
	var entry: Dictionary = _resolve_trait("Single use")
	var term: String = str(entry.get("term", ""))
	assert_str(term).is_equal("Single Use")

	# Same for "Snap Shot" → snap_shot.
	var entry2: Dictionary = _resolve_trait("Snap Shot")
	var term2: String = str(entry2.get("term", ""))
	assert_str(term2).is_equal("Snap Shot")


func test_unknown_trait_returns_unknown_category_not_crash() -> void:
	# Future-proofing: an invented trait must produce a graceful miss, not
	# an exception or empty dict.
	var entry: Dictionary = _resolve_trait("Vibroblade Resonance")
	assert_str(str(entry.get("category", ""))).is_equal("unknown")
