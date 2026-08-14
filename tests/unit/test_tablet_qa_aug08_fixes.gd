extends GdUnitTestSuite
## Findings from the Aug 8 2026 tablet confirmation sprint (T8-01, T8-05).
##
## Both were found on real hardware and BOTH render identically on desktop — they
## were simply never looked at, because reaching them needs a campaign with accrued
## debt (T8-01) or a press of the dashboard "?" (T8-05).
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const ShiplessSystemScript := preload("res://src/core/ship/ShiplessSystem.gd")
const OverlayScript := preload("res://src/ui/components/tutorial/TutorialOverlay.gd")
const CampaignCoreScript := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
# (CampaignPhaseManager / GameState preloads removed with the retired T8-02 cases —
#  see the note below; they live in test_rollover_guard_key_ordering.gd now.)


# ------------------------------------------------------------------- T8-02
#
# RETIRED Aug 9 2026 (T9-02). Three cases lived here pinning a persisted
# progress_data["rollover_applied_for_turn"] marker. That guard was WRONG and these
# tests could not see it, because they hand-set turns_played between calls instead of
# letting the production writer move it — and the production writer
# (CampaignTurnController._on_campaign_turn_started, :638) runs downstream of the very
# read it feeds. Driven properly, the marker swallowed turn 2 of every campaign AND
# still let the second spurious re-entry through.
#
# The guard now lives at the top of CampaignPhaseManager.start_new_turn() as a
# session-scoped latch released by complete_current_turn(), which also covers the
# Story Track / Intro Campaign per-turn hooks (T9-01) that the old placement missed.
# It is pinned by tests/unit/test_rollover_guard_key_ordering.gd, which wires the real
# listener. Do not re-add a turn-counter-keyed guard here.


# ------------------------------------------------------------------- T8-01

func _campaign_with_debt(amount: int) -> Resource:
	var c: Resource = CampaignCoreScript.new()
	c.ship_debt = amount
	if "ship_data" in c and c.ship_data is Dictionary:
		c.ship_data["debt"] = amount
	if "has_ship" in c:
		c.has_ship = true
	return c


func test_debt_interest_moves_the_display_mirror_with_the_owner() -> void:
	# DETECTION-CRITICAL. `campaign.ship_debt` is the owner; `ship_data["debt"]` is
	# the mirror every ship/trade/editor screen reads. ShiplessSystem wrote only the
	# owner, so the mirror froze at its creation value while the p.76 ladder kept
	# charging. Measured on the live tablet save: ship_debt=45, ship.debt=25.0.
	var c := _campaign_with_debt(20)

	var result: Dictionary = ShiplessSystemScript.process_debt_interest(c)

	assert_int(int(result.get("interest", 0))).override_failure_message(
		"p.76: debt of 20 (<=30) accrues +1/turn").is_equal(1)
	assert_int(int(c.ship_debt)).is_equal(21)
	assert_int(int(c.ship_data.get("debt", -1))).override_failure_message(
		"display mirror did not follow the owner — ship/trade/editor screens will " +
		"show a frozen debt while the rules charge interest against the real one"
	).is_equal(int(c.ship_debt))


func test_the_high_debt_rung_also_syncs_the_mirror() -> void:
	# p.76: "2 credits if you owe 31 credits or more".
	var c := _campaign_with_debt(40)

	ShiplessSystemScript.process_debt_interest(c)

	assert_int(int(c.ship_debt)).is_equal(42)
	assert_int(int(c.ship_data.get("debt", -1))).is_equal(42)


func test_repeated_turns_never_drift_the_two_apart() -> void:
	# The real defect was cumulative: one tick is easy to miss, twenty is a
	# 20-credit lie about how close the p.76 seizure threshold (75) is.
	var c := _campaign_with_debt(10)
	for _i in range(20):
		ShiplessSystemScript.process_debt_interest(c)
		if not c.has_ship:
			break # seizure zeroes the debt; nothing left to compare
	assert_int(int(c.ship_data.get("debt", -1))).override_failure_message(
		"owner and mirror drifted apart over repeated turns").is_equal(int(c.ship_debt))


# ------------------------------------------------------------------- T8-05

func _overlay_showing(text: String, viewport_hint: Vector2) -> Node:
	var ov: Node = auto_free(OverlayScript.new())
	add_child(ov)
	ov.start_tutorial([{ "text": text, "target_path": "" }])
	return ov


func test_the_coach_mark_bubble_is_a_bubble_not_a_full_height_slab() -> void:
	# DETECTION-CRITICAL. show_current_step() positioned the panel BEFORE setting its
	# text and making it visible, and the autowrap label had no definite width — so
	# the panel resolved to a ~234px-wide, full-viewport-height column with no
	# readable text and no reachable Next/Skip. Observed live on the dashboard "?"
	# tour; four taps failed to dismiss it.
	var long_text := ("This is the kind of multi-sentence coach-mark copy the real " +
		"tutorial data uses, long enough that an unconstrained autowrap label will " +
		"wrap it into a very tall narrow column instead of a readable bubble.")
	var ov := _overlay_showing(long_text, Vector2(1728, 1080))
	await await_idle_frame()
	await await_idle_frame()

	var panel: Control = ov._tooltip_panel
	var vp_h: float = ov.get_viewport().get_visible_rect().size.y

	assert_bool(panel.visible).override_failure_message(
		"the tooltip never became visible").is_true()
	assert_float(panel.size.y).override_failure_message(
		"bubble is %.0f tall against a %.0f viewport — that is the slab" % [panel.size.y, vp_h]
	).is_less(vp_h * 0.75)
	assert_float(panel.size.x).override_failure_message(
		"bubble collapsed to %.0f wide; the autowrap label lost its wrap width" % panel.size.x
	).is_greater_equal(280.0)


func test_the_bubble_carries_its_controls_and_step_counter() -> void:
	# The slab was unescapable precisely because these were laid out off the bubble.
	# A tour the player cannot advance or skip is worse than no tour.
	var ov := _overlay_showing("Short step.", Vector2(1728, 1080))
	await await_idle_frame()
	await await_idle_frame()

	var panel: Control = ov._tooltip_panel
	var panel_rect := Rect2(panel.global_position, panel.size)
	for child_name: String in ["_next_button", "_skip_button", "_step_label"]:
		var c: Control = ov.get(child_name)
		assert_that(c).override_failure_message("%s missing" % child_name).is_not_null()
		var r := Rect2(c.global_position, c.size)
		var inter := panel_rect.intersection(r)
		assert_float(inter.size.x * inter.size.y).override_failure_message(
			"%s at %s is not inside the bubble %s" % [child_name, r, panel_rect]
		).is_greater(0.0)


func test_the_bubble_stays_inside_the_viewport_when_centred() -> void:
	# _center_tooltip() is the no-target fallback, and it is what the dashboard tour
	# actually hits (its step target paths do not resolve). With a slab-sized panel
	# the centred y went negative, which is why the band ran off both edges.
	var ov := _overlay_showing("A centred step with no highlight target.", Vector2(1728, 1080))
	await await_idle_frame()
	await await_idle_frame()

	var panel: Control = ov._tooltip_panel
	var vp := ov.get_viewport().get_visible_rect().size
	assert_float(panel.position.y).override_failure_message(
		"centred bubble starts above the top edge — it is taller than the screen"
	).is_greater_equal(0.0)
	assert_float(panel.position.y + panel.size.y).is_less_equal(vp.y + 1.0)
