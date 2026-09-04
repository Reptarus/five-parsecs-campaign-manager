extends GdUnitTestSuite
## Core Rules p.123 kill credit reaching the character sheet.
##
## `PostBattleCompletion.update_character_lifetime_statistics()` reads
## `battle_result["kills_by_character"]` and it had NO producer on the played
## path: the battle screen computed the credit into its results prefill, but
## `BattleResultsInputForm._on_submit()` never forwarded the key. The only other
## writer of `Character.lifetime_kills` is `Character.add_kill()`, which has
## ZERO callers repo-wide — so the "Kills" figure on CharacterDetailsScreen and
## CharacterHistoryPanel read 0 for every campaign ever played.
##
## The shape is load-bearing: the consumer does
## `var kills: Array = kills_by_character.get(char_id, [])` and then
## `kills.size()`. An int there is an invalid assignment to a typed Array, which
## ABORTS the function — taking every other lifetime counter and the
## per-character battle journal event down with it.

const CompletionClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleCompletion.gd")
const ContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

func _crew() -> Array:
	return [
		{"character_id": "id_a", "character_name": "Alpha",
			"lifetime_kills": 0, "battles_participated": 0, "battles_survived": 0},
		{"character_id": "id_b", "character_name": "Beta",
			"lifetime_kills": 0, "battles_participated": 0, "battles_survived": 0},
	]

func _run(crew: Array, battle_result: Dictionary) -> void:
	var ctx = ContextClass.new()
	ctx.crew_participants = crew
	ctx.battle_result = battle_result
	CompletionClass.new().update_character_lifetime_statistics(ctx)

func test_lifetime_kills_moves_by_the_number_of_credited_kills() -> void:
	var crew: Array = _crew()
	_run(crew, {"kills_by_character": {
		"id_a": ["Pirate", "Pirates Lieutenant"], "id_b": ["Pirate"]}})
	assert_int(crew[0]["lifetime_kills"]).is_equal(2)
	assert_int(crew[1]["lifetime_kills"]).is_equal(1)

func test_uncredited_crew_keep_zero_kills() -> void:
	var crew: Array = _crew()
	_run(crew, {"kills_by_character": {"id_a": ["Pirate"]}})
	assert_int(crew[0]["lifetime_kills"]).is_equal(1)
	assert_int(crew[1]["lifetime_kills"]).is_equal(0)

func test_participation_still_moves_with_no_kill_credit_at_all() -> void:
	## Guards the abort: if the kills value were the wrong type the typed Array
	## assignment would unwind this function and NONE of these would move.
	var crew: Array = _crew()
	_run(crew, {})
	assert_int(crew[0]["battles_participated"]).is_equal(1)
	assert_int(crew[0]["battles_survived"]).is_equal(1)
	assert_int(crew[0]["lifetime_kills"]).is_equal(0)

func test_a_downed_crew_member_participates_but_does_not_survive() -> void:
	var crew: Array = _crew()
	_run(crew, {"kills_by_character": {"id_a": ["Pirate"]},
		"units_downed": ["id_b"]})
	assert_int(crew[1]["battles_participated"]).is_equal(1)
	assert_int(crew[1]["battles_survived"]).is_equal(0)
	assert_int(crew[0]["battles_survived"]).is_equal(1)

func test_crew_carrying_only_id_still_get_their_stats() -> void:
	## Character.to_dictionary() emits BOTH "character_id" and "id" (CLAUDE.md,
	## "dual keys"), but hand-built crew dicts often carry only "id". In a real
	## turn-20 save the CAPTAIN had character_id and the other FIVE crew had only
	## id, so reading character_id alone skipped them: battles_participated,
	## battles_survived and lifetime_kills never moved for 5 of 6 crew, and their
	## per-character battle journal event never fired. The producer side already
	## resolved both spellings, so the contract was one-sided.
	var crew: Array = [
		{"id": "id_only", "character_name": "Legacy",
			"lifetime_kills": 0, "battles_participated": 0, "battles_survived": 0},
	]
	_run(crew, {"kills_by_character": {"id_only": ["Pirate", "Pirate"]}})
	assert_int(crew[0]["lifetime_kills"]).is_equal(2)
	assert_int(crew[0]["battles_participated"]).is_equal(1)

func test_character_id_still_wins_when_both_spellings_are_present() -> void:
	var crew: Array = [
		{"character_id": "canonical", "id": "legacy", "character_name": "Both",
			"lifetime_kills": 0, "battles_participated": 0, "battles_survived": 0},
	]
	_run(crew, {"kills_by_character": {"canonical": ["Pirate"], "legacy": ["A", "B", "C"]}})
	assert_int(crew[0]["lifetime_kills"]).is_equal(1)
