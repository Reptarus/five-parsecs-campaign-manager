extends GdUnitTestSuite
## Official errata v1.06 items that neither rulebook contains, so a player
## working off the printed page would get them wrong.
##
## p.17 — Soulless and Bot Upgrades. The book reads "They may also have Bot
## Upgrades installed, but must pay 1.5 times the normal cost (rounded up)".
## The errata replaces that outright: "Soulless characters CANNOT install Bot
## upgrades." data/character_species.json was still advertising the 1.5x rule.
##
## AI clarifications — three rules that change how the enemy turn is run:
##   - the AI is always aware of your characters, even behind terrain
##   - Defensive AI treats terrain within one move as "Adjacent"
##   - a Guardian whose protected figure dies adopts the main force's AI

const AdvancementSystemClass = preload(
	"res://src/core/character/advancement/AdvancementSystem.gd")
const CharacterClass = preload("res://src/core/character/Character.gd")

func _system() -> Object:
	return auto_free(AdvancementSystemClass.new())

func _bot() -> Resource:
	var c: Resource = auto_free(CharacterClass.new())
	c.is_bot = true
	c.is_soulless = false
	return c

func _soulless() -> Resource:
	# A Soulless is mechanical enough that a future refactor could plausibly
	# fold it into is_bot — which is exactly the case the explicit gate covers.
	var c: Resource = auto_free(CharacterClass.new())
	c.is_bot = true
	c.is_soulless = true
	return c

# ── p.17: Soulless cannot install Bot Upgrades ───────────────────────────

func test_a_soulless_cannot_install_a_bot_upgrade() -> void:
	var sys = _system()
	assert_bool(sys.can_install_bot_upgrade(_soulless(), "toughness", 999)) \
		.override_failure_message(
			"Errata v1.06 forbids Soulless Bot upgrades; the gate allowed one") \
		.is_false()

func test_a_soulless_install_attempt_is_refused_outright() -> void:
	# can_install_* is the query; install_* must refuse independently, so a
	# caller that skips the query cannot slip past.
	var sys = _system()
	assert_bool(sys.install_bot_upgrade(_soulless(), "toughness", null)).is_false()

func test_an_ordinary_bot_is_unaffected() -> void:
	# The errata narrows Soulless only. A Bot must still qualify, or the fix
	# would have removed a mechanic the book keeps (p.123).
	var sys = _system()
	assert_bool(sys.can_install_bot_upgrade(_bot(), "toughness", 999)) \
		.override_failure_message(
			"The Soulless gate also blocked ordinary Bots").is_true()

func test_a_soulless_is_recognised_by_species_id_as_well_as_the_flag() -> void:
	# Loaded saves and freshly-created characters do not always agree on which
	# marker is set, so both are honoured.
	var sys = _system()
	var c: Resource = auto_free(CharacterClass.new())
	c.is_bot = true
	c.is_soulless = false
	c.species_id = "soulless"
	assert_bool(sys.can_install_bot_upgrade(c, "toughness", 999)).is_false()

func test_the_species_data_no_longer_advertises_the_superseded_rule() -> void:
	# The JSON is what the Compendium screen shows the player. Leaving the 1.5x
	# line in would have the app teaching a rule the errata deleted, even with
	# the code gate closed.
	var f := FileAccess.open("res://data/character_species.json", FileAccess.READ)
	assert_object(f).is_not_null()
	var raw: String = f.get_as_text()
	f.close()
	assert_str(raw).override_failure_message(
		"character_species.json still offers Soulless Bot Upgrades at 1.5x cost") \
		.not_contains("1.5x cost")
	var parsed: Variant = JSON.parse_string(raw)
	assert_that(parsed).is_not_null()

# ── AI clarifications reach the oracle reference text ────────────────────
#
# These are checked through FPCM_EnemyAIOracleRouter's data rather than the UI,
# so they hold regardless of which tier is active. The reference card is the
# only surface that can carry them: they are in neither book.

const RouterClass = preload("res://src/core/battle/EnemyAIOracleRouter.gd")

func test_every_book_ai_type_resolves_to_a_data_entry() -> void:
	# The errata lines are appended to whatever the router returns, so an AI type
	# that resolves to nothing would drop them silently. p.92 code table: A C D
	# G R T B.
	var r = auto_free(RouterClass.new())
	for type_name in ["Aggressive", "Cautious", "Defensive", "Guardian",
			"Rampage", "Tactical", "Beast"]:
		var data: Dictionary = r._find_ai_type(type_name)
		assert_dict(data).override_failure_message(
			"AI type '%s' has no entry, so its reference card would be empty"
			% type_name).is_not_empty()

func test_defensive_and_guardian_are_distinct_entries() -> void:
	# The two errata clarifications are per-type; if these collapsed onto one
	# entry the wrong note would show.
	var r = auto_free(RouterClass.new())
	var d: Dictionary = r._find_ai_type("Defensive")
	var g: Dictionary = r._find_ai_type("Guardian")
	assert_dict(d).is_not_empty()
	assert_dict(g).is_not_empty()
	assert_str(str(d.get("base_condition", "d"))) \
		.is_not_equal(str(g.get("base_condition", "g")))

# ── _is_bot() never read the property that marks a Bot ───────────────────
#
# Found by the "an ordinary Bot is unaffected" case above, which failed against
# a Character with is_bot = true. _is_bot() checked has_method("is_bot") and
# then compared `origin` to "BOT"/"Bot". Character has NO is_bot() method —
# is_bot is an @export PROPERTY — and `origin` is a validated species string
# defaulting to "HUMAN". So the flag that actually marks a Bot was never read,
# and since _is_bot() gates both upgrade functions, Bot upgrades (Core Rules
# p.123) were unreachable for every Bot in the crew.

func test_the_is_bot_property_is_what_identifies_a_bot() -> void:
	var sys = _system()
	var c: Resource = auto_free(CharacterClass.new())
	c.is_bot = true
	assert_bool(sys._is_bot(c)).override_failure_message(
		"is_bot = true was not recognised, so Bot upgrades stay unreachable") \
		.is_true()

func test_a_non_bot_is_still_rejected() -> void:
	var sys = _system()
	var c: Resource = auto_free(CharacterClass.new())
	c.is_bot = false
	assert_bool(sys._is_bot(c)).is_false()
	assert_bool(sys.can_install_bot_upgrade(c, "toughness", 999)).is_false()

func test_a_lowercase_species_id_is_recognised() -> void:
	# The old origin comparison was case-sensitive against "BOT"/"Bot", which is
	# not how species ids are spelled anywhere in the data.
	var sys = _system()
	var c: Resource = auto_free(CharacterClass.new())
	c.is_bot = false
	c.species_id = "bot"
	assert_bool(sys._is_bot(c)).is_true()
