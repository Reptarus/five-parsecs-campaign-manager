extends GdUnitTestSuite
## T5-08 — the post-battle log must name the crew it is talking about
##
## On device, every step 9 line read "Unknown gained 3 XP" (six times) and step 13
## read "Unknown: Overhear Something Useful". The awards themselves landed; only the
## names were lost. That is arguably worse than a crash: it reads as an app that
## does not know who its own crew are, and a Character Event names ONE specific crew
## member by design (Core Rules p.126), so a nameless one has no content left.
##
## Cause was a producer/consumer key hole in two places at once —
## PostBattleSequence reads `crew_name` / `character_name`, and neither producer
## ever wrote them. Both are fixed at the PRODUCER because the carriers are public
## signals (PostBattlePhase.experience_awarded / character_event_occurred): patching
## the one consumer that happened to display it would leave the next listener with
## the same hole.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const XP_PROCESSOR := "res://src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd"
const CHAR_EVENTS := "res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd"
const SEQUENCE := "res://src/ui/screens/postbattle/PostBattleSequence.gd"


func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	return f.get_as_text()


func test_the_xp_award_carries_the_name_its_consumer_reads() -> void:
	# The pairing is the assertion. Either half alone proves nothing: a producer
	# writing `crew_name` is useless if the consumer reads `name`, and vice versa.
	assert_str(_source(XP_PROCESSOR)).contains("\"crew_name\"")
	assert_str(_source(SEQUENCE)).contains("award.get(\"crew_name\"")


func test_the_character_event_carries_the_name_its_consumer_reads() -> void:
	assert_str(_source(CHAR_EVENTS)).contains("\"character_name\"")
	assert_str(_source(SEQUENCE)).contains("event.get(\"character_name\"")


func test_both_precursor_events_are_named_not_just_the_first() -> void:
	# p.17 + p.126: a Precursor rolls TWICE and the player picks. Either roll can be
	# the one that surfaces, so stamping only character_event would leave a 50%
	# chance of "Unknown" for that species specifically — the kind of gap that
	# reproduces rarely enough to be dismissed as a fluke.
	var src := _source(CHAR_EVENTS)
	assert_str(src).contains("second_event[\"character_name\"]")
	assert_str(src).contains("character_event[\"character_name\"]")


func test_the_shared_name_resolver_handles_both_crew_shapes() -> void:
	# Crew are Dictionaries after a save/load round-trip and Character Resources on a
	# fresh campaign, and the log was equally broken on both. get_char_name() is the
	# resolver both producers now call; if it only handled one shape the fix would
	# work for exactly half of all campaigns.
	var ContextClass: GDScript = load(
		"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
	var ctx = ContextClass.new()

	assert_str(ctx.get_char_name({"character_name": "Mars Stark"})).is_equal("Mars Stark")
	assert_str(ctx.get_char_name({"name": "Finn Mendez"})).is_equal("Finn Mendez")
	assert_str(ctx.get_char_name({})).is_equal("Unknown")
