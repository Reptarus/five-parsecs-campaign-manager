extends GdUnitTestSuite
## B2 narrative-bridge data-transform tests.
##
## Covers `_battle_result_to_narrative_dict()` on `FPCM_CampaignTurnController`,
## which translates a resolver result dict into the event_data shape consumed
## by `NarrativeScreen.present()`. The bridge is the convergence point between
## Workstream A (narrative) and Workstream B (combat modes), so the contract
## between resolver output and NarrativeScreen input must hold exactly.
##
## Two key-name bugs in the original implementation made this test set load-
## bearing: (1) the producer used `briefing` while the consumer reads
## `briefing_text` (so summary lines never displayed); (2) the producer read
## `held_the_field` while both resolvers emit `held_field` (so held-field
## partial successes were mislabeled as Withdrawals). These tests pin both
## down so regressions surface immediately.

const CTC = preload("res://src/ui/screens/campaign/CampaignTurnController.gd")


# ── 1: Victory outcome ────────────────────────────────────────────────
func test_victory_produces_victory_title_and_art_tag() -> void:
	var d := CTC._battle_result_to_narrative_dict({
		"victory": true,
		"held_field": true,
		"rounds_played": 4,
		"casualties": 0,
		"auto_resolved": true,
	})
	assert_str(d.get("title", "")).is_equal("Aftermath: Victory")
	assert_str(d.get("art_tag", "")).is_equal("battle_aftermath_victory")
	assert_str(d.get("advisor_mood", "")).is_equal("positive")
	assert_str(d.get("advisor_role", "")).is_equal("fighter")


# ── 2: Withdrawal outcome (lost AND didn't hold) ──────────────────────
func test_withdrawal_produces_warning_mood_and_retreat_art_tag() -> void:
	var d := CTC._battle_result_to_narrative_dict({
		"victory": false,
		"held_field": false,
		"rounds_played": 2,
		"casualties": 2,
		"auto_resolved": true,
	})
	assert_str(d.get("title", "")).is_equal("Aftermath: Withdrawal")
	assert_str(d.get("art_tag", "")).is_equal("battle_aftermath_retreat")
	assert_str(d.get("advisor_mood", "")).is_equal("warning")


# ── 3: Held-field-but-lost (partial success) — the key bug case ───────
func test_held_field_but_lost_uses_objective_held_title() -> void:
	var d := CTC._battle_result_to_narrative_dict({
		"victory": false,
		"held_field": true,
		"rounds_played": 5,
		"casualties": 1,
		"auto_resolved": true,
	})
	# Bug-pin: with the original "held_the_field" lookup defaulting to `won`,
	# this case fell through to "Withdrawal". The fix accepts both spellings
	# and uses the held_field flag to pick the middle title.
	assert_str(d.get("title", "")).is_equal("Aftermath: Objective Held")
	assert_str(d.get("advisor_mood", "")).is_equal("neutral")
	# Held-field outcomes lean visually toward victory (the only mood-positive
	# art_tag in the opener map).
	assert_str(d.get("art_tag", "")).is_equal("battle_aftermath_victory")


# ── 4: Accepts BOTH "held_field" and "held_the_field" spellings ───────
func test_held_field_legacy_spelling_still_works() -> void:
	var d := CTC._battle_result_to_narrative_dict({
		"victory": false,
		"held_the_field": true,
		"rounds_played": 3,
		"casualties": 1,
		"auto_resolved": true,
	})
	assert_str(d.get("title", "")).is_equal("Aftermath: Objective Held")


# ── 5: Briefing key must be "briefing_text" (NOT "briefing") ──────────
func test_briefing_lines_use_consumer_key() -> void:
	var d := CTC._battle_result_to_narrative_dict({
		"victory": true,
		"held_field": true,
		"rounds_played": 4,
		"casualties": 2,
		"no_minis": true,
		"auto_resolved": true,
	})
	# Bug-pin: NarrativeScreen._populate_briefing reads "briefing_text".
	# If the producer ever drifts back to "briefing", the section silently hides.
	assert_bool(d.has("briefing_text")).is_true()
	assert_bool(d.has("briefing")).is_false()
	var briefing: String = str(d.get("briefing_text", ""))
	assert_str(briefing).contains("Rounds: 4")
	assert_str(briefing).contains("Casualties: 2")
	assert_str(briefing).contains("No-Minis combat")


# ── 6: Choice list has exactly one Continue button using consumer keys ──
func test_single_continue_choice_uses_consumer_keys() -> void:
	# Bug-pin: NarrativeChoiceButton.setup() reads "label" and "id" — NOT
	# "text" and "value". Producer/consumer key drift hid the button text
	# entirely in the first ship; visual screenshot caught it as third
	# instance of the same bug class in this feature.
	var d := CTC._battle_result_to_narrative_dict({
		"victory": true,
		"held_field": true,
	})
	var choices: Array = d.get("choices", [])
	assert_int(choices.size()).is_equal(1)
	var choice: Dictionary = choices[0]
	# Must have the consumer's keys, not the legacy/intuitive ones.
	assert_bool(choice.has("label")).is_true()
	assert_bool(choice.has("id")).is_true()
	assert_bool(choice.has("text")).is_false()
	assert_bool(choice.has("value")).is_false()
	assert_str(str(choice.get("label"))).is_equal("Continue")


# ── 7: combat_mode label defaults to "Auto-resolved" ──────────────────
func test_combat_mode_defaults_for_standard_resolver() -> void:
	var d := CTC._battle_result_to_narrative_dict({
		"victory": true,
		"held_field": true,
		"rounds_played": 3,
		"casualties": 0,
	})
	var briefing: String = str(d.get("briefing_text", ""))
	assert_str(briefing).contains("Auto-resolved")


# ── 8: Missing held_field key defaults FALSE (not `won`) ──────────────
func test_missing_held_field_defaults_false_not_won() -> void:
	# Bug-pin: the original default was `won`, which for a victory would
	# silently report held_field as true even when the resolver had no
	# opinion. The fix defaults to FALSE so omission ≠ assertion.
	var d := CTC._battle_result_to_narrative_dict({
		"victory": false,
		# held_field intentionally missing
	})
	# With held_field undefined and won=false, the path is "Withdrawal"
	# (which is what we'd want for a result with no held_field signal).
	assert_str(d.get("title", "")).is_equal("Aftermath: Withdrawal")
