extends GdUnitTestSuite
## The creation tables and species data are book-correct; APPLYING them was not.
##
## Three defects, all of the same shape — a lookup that misses silently and
## returns a default instead of erroring:
##
##   1. character_creation_bonuses.json keyed the three Compendium origins one
##      lower than GlobalEnums.Origin, so choosing Krag returned SKULKER's stat
##      block, Skulker returned Prison Planet's, and Prison Planet returned
##      nothing at all.
##
##   2. character_species.json writes stat_modifiers in lowercase ("combat",
##      "reactions"); STAT_PROPERTY_MAP is keyed in SCREAMING_CASE
##      ("COMBAT_SKILL", "REACTIONS"). Every lookup missed, the applier returned
##      early, and EVERY Strange Character came out as a baseline Human.
##
##   3. Bots kept the Background/Class/Motivation bonuses seeded from the default
##      dropdown selections, though p.15 says "Bots do not make any rolls on the
##      character creation tables."

const CreatorScript = preload("res://src/core/character/Generation/CharacterCreator.gd")
const SpeciesData = preload("res://src/core/character/SpeciesDataService.gd")

const BONUSES_PATH := "res://data/character_creation_bonuses.json"
const SPECIES_PATH := "res://data/character_species.json"

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("could not open " + path).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(f.get_as_text())).override_failure_message(
		path + " is not valid JSON").is_equal(OK)
	return json.data as Dictionary

# ── 1. Origin ids must agree with the enum ───────────────────────────────

func test_origin_bonus_keys_match_the_enum_ordinals() -> void:
	# Each entry's _comment names the species AND asserts its enum value. Both
	# must agree with the real ordinal and with the key the entry is filed under,
	# or a species silently inherits its neighbour's stat block.
	var data := _load_json(BONUSES_PATH)
	var origins: Dictionary = data.get("origin_bonuses", {})
	assert_bool(origins.is_empty()).is_false()

	var regex := RegEx.new()
	regex.compile("GlobalEnums\\.Origin\\.(\\w+)=(\\d+)")
	var checked := 0
	for key in origins.keys():
		var comment: String = str(origins[key].get("_comment", ""))
		var m := regex.search(comment)
		if m == null:
			continue
		var species_name: String = m.get_string(1)
		var claimed: int = int(m.get_string(2))
		assert_bool(GlobalEnums.Origin.has(species_name)).override_failure_message(
			"_comment names GlobalEnums.Origin.%s, which does not exist" % species_name
		).is_true()
		var actual: int = GlobalEnums.Origin[species_name]
		assert_int(actual).override_failure_message(
			"%s is enum value %d but the JSON files it under key \"%s\" and its comment claims %d — the lookup would return another species' stats"
			% [species_name, actual, str(key), claimed]
		).is_equal(int(key))
		assert_int(claimed).is_equal(actual)
		checked += 1
	assert_int(checked).override_failure_message(
		"no origin entries carried a checkable enum comment").is_greater(0)

func test_krag_and_skulker_do_not_share_a_stat_block() -> void:
	# The exact symptom of the off-by-one: Krag's key returned Skulker's data.
	var origins: Dictionary = _load_json(BONUSES_PATH).get("origin_bonuses", {})
	var krag: Dictionary = origins.get(str(GlobalEnums.Origin.KRAG), {})
	var skulker: Dictionary = origins.get(str(GlobalEnums.Origin.SKULKER), {})
	assert_bool(krag.is_empty()).override_failure_message(
		"no origin_bonuses entry at KRAG's real enum value").is_false()
	assert_bool(skulker.is_empty()).override_failure_message(
		"no origin_bonuses entry at SKULKER's real enum value").is_false()
	# Krag is the tough one (Compendium p.12 T4); Skulker is the fast one (p.14).
	assert_int(int(krag.get("TOUGHNESS", 0))).override_failure_message(
		"Krag must get the Toughness bonus, not Skulker's Speed/Savvy").is_equal(1)
	assert_int(int(skulker.get("SPEED", 0))).is_equal(2)
	assert_bool(krag.has("SPEED")).override_failure_message(
		"Krag has picked up Skulker's SPEED bonus — the keys are off by one again"
	).is_false()

func test_prison_planet_has_an_entry_at_its_real_enum_value() -> void:
	var origins: Dictionary = _load_json(BONUSES_PATH).get("origin_bonuses", {})
	assert_bool(origins.has(str(GlobalEnums.Origin.PRISON_PLANET))) \
		.override_failure_message(
			"Prison Planet's entry is filed under the wrong key, so it receives nothing"
		).is_true()

# ── 2. Every species stat key must resolve to a character property ───────

func test_every_species_stat_modifier_key_resolves() -> void:
	# The case-mismatch bug, asserted at the data level so it cannot come back
	# through a new species entry either.
	var species_data := _load_json(SPECIES_PATH)
	var seen_keys := {}
	_collect_stat_keys(species_data, seen_keys)
	assert_int(seen_keys.size()).override_failure_message(
		"found no stat_modifiers blocks at all — the probe is wrong, not the data"
	).is_greater(0)

	for raw_key in seen_keys.keys():
		var resolved: String = _resolve(str(raw_key))
		assert_str(resolved).override_failure_message(
			"species stat key \"%s\" resolves to no character property, so every species using it is silently applied as a baseline Human"
			% str(raw_key)
		).is_not_empty()

func _resolve(raw_key: String) -> String:
	## Mirror of CharacterCreator._resolve_stat_property using its real constants.
	var direct: String = CreatorScript.STAT_PROPERTY_MAP.get(raw_key, "")
	if not direct.is_empty():
		return direct
	var alias: String = CreatorScript.STAT_KEY_ALIASES.get(raw_key.to_upper(), "")
	if alias.is_empty():
		return ""
	return CreatorScript.STAT_PROPERTY_MAP.get(alias, "")

func _collect_stat_keys(node: Variant, out: Dictionary) -> void:
	if node is Dictionary:
		var d: Dictionary = node
		for k in d.keys():
			if str(k) == "stat_modifiers" and d[k] is Dictionary:
				for sk in (d[k] as Dictionary).keys():
					out[str(sk)] = true
			else:
				_collect_stat_keys(d[k], out)
	elif node is Array:
		for item in node:
			_collect_stat_keys(item, out)

func test_resolved_properties_exist_on_a_real_character() -> void:
	var character = load("res://src/core/character/Character.gd").new()
	for raw_key in ["combat", "reactions", "toughness", "savvy", "speed",
			"COMBAT_SKILL", "REACTIONS", "LUCK"]:
		var prop: String = _resolve(raw_key)
		assert_str(prop).override_failure_message(
			"\"%s\" did not resolve" % raw_key).is_not_empty()
		assert_bool(prop in character).override_failure_message(
			"\"%s\" resolved to \"%s\", which is not a property on Character"
			% [raw_key, prop]
		).is_true()

# ── 3. The species that make no creation rolls ───────────────────────────

func test_only_bots_are_barred_from_the_creation_tables() -> void:
	# Core Rules p.15 (Bot) and p.21 (Assault Bot). If a future data edit flips
	# another species, that is a rules change and should fail here first.
	assert_bool(SpeciesData.can_roll_creation_tables("bot")).is_false()
	assert_bool(SpeciesData.can_roll_creation_tables("assault_bot")).is_false()
	assert_bool(SpeciesData.can_roll_creation_tables("human")).is_true()
	assert_bool(SpeciesData.can_roll_creation_tables("hulker")).is_true()

func test_hakshan_motivation_is_additional_and_traveler_is_not() -> void:
	# Core Rules p.20: Hakshan has Truth "in addition to the usual rolls".
	# Core Rules p.23: Traveler's "Motivation is always Truth" — a replacement.
	# Both carried the same forced_motivation field, so Hakshan was losing the
	# motivation the book says they still roll.
	assert_bool(SpeciesData.is_motivation_additional("hakshan")).override_failure_message(
		"Hakshan's Truth motivation is ADDITIONAL (p.20), not a replacement"
	).is_true()
	assert_bool(SpeciesData.is_motivation_additional("traveler")).override_failure_message(
		"Traveler's motivation IS a replacement (p.23) and must not be marked additional"
	).is_false()
	assert_str(SpeciesData.get_forced_motivation("traveler").to_lower()).is_equal("truth")

func test_the_double_roll_species_are_flagged() -> void:
	# Mysterious Past (p.20) rolls Background twice; Feeler (p.22) rolls
	# Motivation twice. Both accessors existed with zero call sites.
	assert_bool(SpeciesData.has_double_background("mysterious_past")).is_true()
	assert_bool(SpeciesData.has_double_motivation("feeler")).is_true()
	assert_bool(SpeciesData.has_double_background("human")).is_false()
	assert_bool(SpeciesData.has_double_motivation("human")).is_false()
