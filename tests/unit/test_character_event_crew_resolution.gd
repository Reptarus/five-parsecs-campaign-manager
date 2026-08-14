extends GdUnitTestSuite
## Character Events must receive a CREW MEMBER, never a crew ID string.
##
## Found on the tablet 2026-08-08 by submitting a battle result: the battle screen tore
## down and the 14-step post-battle sequence never appeared. No crash, no dialog. The
## remote-deploy debugger caught it:
##
##     Invalid call. Nonexistent function 'set' in base 'String'.
##       PostBattleContext.gd:785   _set_character_stat   character = "char_690716_1964"
##       PostBattleContext.gd:824   apply_random_ability_increase   stat="reaction" value=1
##       CharacterEventEffects.gd:478   "Personal Breakthrough" (Core Rules p.129)
##       CharacterEventEffects.gd:206   finalize_event
##       PostBattlePhase.gd:543     _process_character_events   (step 13)
##
## finalize_event() did
##     var crew = event.get("crew_id", ctx.get_random_crew_member())
## which yields a String on one branch and a Character/Dictionary on the other. A
## non-empty String is TRUTHY, so `elif character:` in _set_character_stat accepted it,
## and Godot ABORTS a function on an invalid call — unwinding step 13 and the whole
## sequence with it.
##
## Two independent guards are pinned here, because either alone leaves a trap:
##   1. finalize_event() resolves an id through ctx.get_crew_member() (the real fix)
##   2. _set_character_stat/_get_character_stat refuse a non-character (the backstop,
##      so a future caller that forgets loses one stat write instead of the run)
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const ContextClass := preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const EffectsClass := preload(
	"res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")


## finalize_event() is typed to PostBattleContext, so a stub class will not parse —
## build a REAL context and give it a Dictionary campaign (get_crew_members() reads
## campaign["crew"] on that branch).
func _ctx_with(members: Array):
	var ctx = ContextClass.new()
	ctx.campaign = {"crew": members}
	ctx.battle_result = {"turn": 1}
	return ctx


func _stat_total(m: Dictionary) -> int:
	return (
		int(m["reaction"]) + int(m["combat"]) + int(m["speed"])
		+ int(m["savvy"]) + int(m["toughness"])
	)


func _member(id: String, name: String) -> Dictionary:
	return {
		"character_id": id, "id": id, "character_name": name, "name": name,
		"origin": "HUMAN", "reaction": 1, "combat": 0, "speed": 4,
		"savvy": 0, "toughness": 3, "luck": 0,
	}


func test_finalize_event_resolves_a_crew_id_string_to_the_member() -> void:
	## The exact device case: an event carrying a crew_id string, applying a stat change.
	var target := _member("char_690716_1964", "Bryn Ito")
	var other := _member("char_2", "Dex")
	var ctx = _ctx_with([target, other])
	var before := _stat_total(target)

	var effects = EffectsClass.new()
	effects.finalize_event({
		"type": "character_event",
		"name": "Personal Breakthrough",
		"crew_id": "char_690716_1964",
	}, ctx)

	# p.129 Personal Breakthrough raises exactly one ability by 1, on the member the
	# crew_id names. Passing the raw id through instead aborts inside
	# _set_character_stat and nothing is raised at all.
	assert_int(_stat_total(target)) \
		.override_failure_message(
			"finalize_event() did not apply Personal Breakthrough to the crew member the "
			+ "crew_id names. If it passes the raw id string through, _set_character_stat "
			+ "aborts on String.set() and step 13 unwinds the whole post-battle sequence.") \
		.is_equal(before + 1)
	assert_int(_stat_total(other)) \
		.override_failure_message("a resolvable crew_id must not hit a random member") \
		.is_equal(_stat_total(_member("x", "x")))


func test_finalize_event_falls_back_when_the_id_does_not_resolve() -> void:
	## An id naming nobody (stale save, dead crew) must not crash and must not no-op —
	## it falls back to a random member, and with a roster of one that member is known.
	var only := _member("char_a", "Bryn Ito")
	var ctx = _ctx_with([only])
	var before := _stat_total(only)

	var effects = EffectsClass.new()
	effects.finalize_event({
		"type": "character_event",
		"name": "Personal Breakthrough",
		"crew_id": "char_DOES_NOT_EXIST",
	}, ctx)

	assert_int(_stat_total(only)) \
		.override_failure_message(
			"an unresolvable crew_id must fall back to get_random_crew_member(), not "
			+ "silently skip the event") \
		.is_equal(before + 1)


func test_a_string_id_cannot_abort_the_stat_writer() -> void:
	## The backstop, exercised through the public API that the device crash came from.
	## Before the fix apply_random_ability_increase() raised "Nonexistent function 'set'
	## in base 'String'" and ABORTED its caller; it must now return harmlessly so one
	## bad argument can never take the sequence down again.
	var ctx = ContextClass.new()

	var raised: String = ctx.apply_random_ability_increase("char_690716_1964")
	# Reaching this line at all is the assertion — an abort would never return here.
	assert_str(raised) \
		.override_failure_message(
			"a String id must raise nothing, and must not abort the calling function") \
		.is_equal("")

	# ...and the legitimate shape still works.
	var d := _member("char_a", "Bryn")
	var before := _stat_total(d)
	var got: String = ctx.apply_random_ability_increase(d)
	assert_str(got).is_not_empty()
	assert_int(_stat_total(d)).is_equal(before + 1)
