extends GdUnitTestSuite
## Every crew member must reach the save with its FULL character record, not a
## captain-only privilege.
##
## THE BUG THIS EXISTS TO PREVENT
##
## CampaignCreationCoordinator._character_to_dict() hand-built a new dict from ~17
## properties when handed a Character RESOURCE, while Character.to_dictionary()
## emits 53. CrewPanel appends Resources (CrewPanel.gd:143/153), so every non-captain
## crew member took the narrow path and lost ~38 fields on the way to disk.
##
## The captain escaped it purely by accident of shape: update_crew_state wraps the
## captain as {name, character_name, "character": <Resource>} — a DICTIONARY — and the
## dictionary branch already merged to_dictionary() back in. That asymmetry is why the
## bug reads as "species rules work" in any spot check.
##
## MEASURED across all 30 save files on disk before the fix:
##   0 of 73 non-captain crew members carried species_id
##   median non-captain: 18 keys; median captain: 27
##   absent from EVERY non-captain: species_id, is_bot, is_soulless, special_rules,
##   psionic_powers, status_effects, implants, acquired_training, health, max_health,
##   character_id, portrait_path, and the lifetime_* counters
##
## CONSEQUENCE, for 5 of 6 crew, for the whole campaign:
##   - all 16 Strange Character species rules inert (species_id is read with NO
##     fallback at CampaignPhaseManager:576 Unity Agent favor, EquipmentManager:604
##     Krag armor gate, LuckSystem:300 can_receive_luck, CharacterEventEffects,
##     ExperienceTrainingProcessor:100)
##   - Bots gain XP, which Core Rules p.98 forbids (is_bot absent)
##   - rolled psionic powers vanish (psionic_powers absent)
##   - Character Events cannot persist status_effects
##
## gdUnit4 v6.0.3 compatible.

const Coordinator = preload("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
const CharacterScript = preload("res://src/core/character/Character.gd")

## Fields whose absence silently disables a documented game rule. Not an exhaustive
## list of what to_dictionary() emits — these are the ones with real consumers.
const RULE_BEARING_FIELDS := [
	"species_id",       # every Strange Character rule
	"is_bot",           # Core Rules p.98 — Bots never gain XP
	"is_soulless",      # 6+ armor save (p.17)
	"special_rules",    # per-species rule list from character_species.json
	"psionic_powers",   # rolled at creation, read by TacticalBattleUI
	"status_effects",   # Character Events persistence (pp.128-130)
	"implants",         # capacity gates (p.55)
	"character_id",     # crew lookup index
]


func _coordinator() -> Node:
	var c = Coordinator.new()
	add_child(c)
	auto_free(c)
	return c


func _a_crew_member() -> Resource:
	## A non-captain with every rule-bearing field populated.
	var ch = CharacterScript.new()
	ch.character_name = "Vex Kalder"
	ch.species_id = "krag"
	ch.is_bot = false
	ch.combat = 2
	ch.toughness = 4
	return ch


func test_a_crew_resource_keeps_its_species() -> void:
	# The single most consequential field: absent, every species rule is inert.
	var c := _coordinator()
	var out: Dictionary = c._character_to_dict(_a_crew_member())

	assert_str(str(out.get("species_id", ""))).override_failure_message(
		"species_id was dropped converting the crew member — all 16 Strange Character rules are inert"
	).is_equal("krag")


func test_a_crew_resource_keeps_every_rule_bearing_field() -> void:
	var c := _coordinator()
	var out: Dictionary = c._character_to_dict(_a_crew_member())

	var missing: Array[String] = []
	for f in RULE_BEARING_FIELDS:
		if not out.has(f):
			missing.append(f)

	assert_array(missing).override_failure_message(
		"fields dropped on the way to the save: %s" % str(missing)
	).is_empty()


func test_crew_and_captain_serialise_to_the_same_shape() -> void:
	# The asymmetry IS the bug: the captain went through a different branch and kept
	# everything. Both must now land identically wide.
	var c := _coordinator()

	var crew_member = _a_crew_member()
	var captain = _a_crew_member()
	captain.character_name = "Captain Reyes"
	captain.is_captain = true

	var crew_out: Dictionary = c._character_to_dict(crew_member)
	# The captain's real shape: a dict wrapping the live Resource.
	var captain_out: Dictionary = c._character_to_dict({
		"name": "Captain Reyes",
		"character_name": "Captain Reyes",
		"character": captain,
	})

	var only_on_captain: Array[String] = []
	for k in captain_out.keys():
		if k == "character":
			continue  # the wrapper key, not a character field
		if not crew_out.has(k):
			only_on_captain.append(k)

	assert_array(only_on_captain).override_failure_message(
		"still captain-only, dropped for regular crew: %s" % str(only_on_captain)
	).is_empty()


func test_character_object_survives_the_canonical_path() -> void:
	# to_dictionary() does not emit character_object; the downstream equipment
	# re-attachment (CampaignCreationCoordinator:1366-1395) relies on it, so the
	# canonical path must put it back rather than trade one loss for another.
	var c := _coordinator()
	var member = _a_crew_member()
	var out: Dictionary = c._character_to_dict(member)

	assert_object(out.get("character_object")).override_failure_message(
		"character_object was lost in the swap to to_dictionary()"
	).is_not_null()


func test_a_plain_dictionary_still_passes_through() -> void:
	# Loaded saves hold Dictionaries, not Resources. That path must be unchanged.
	var c := _coordinator()
	var out: Dictionary = c._character_to_dict({
		"character_name": "Legacy Crew", "combat": 1,
	})
	assert_str(str(out.get("character_name", ""))).is_equal("Legacy Crew")
	assert_str(str(out.get("name", ""))).override_failure_message(
		"the dictionary branch stopped normalising name/character_name"
	).is_equal("Legacy Crew")
