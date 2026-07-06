extends GdUnitTestSuite
## Objective completion coverage — MissionObjectiveSystem.check_completion() vs the
## Core Rules p.90 win conditions and mission_objectives.json (the SSOT).
##
## Locks the F5/F6 fixes (Move Through = 2 crew, Patrol = 3 points — were 3/4, and
## Patrol was UNWINNABLE at 4) and characterizes the F1 gap (ACCESS/ELIMINATE/SECURE
## have no check_completion() case yet — auto-eval added in Phase 6).
##
## Objective is constructed directly (registry/JSON not needed) for determinism.

const MOS = preload("res://src/core/battle/MissionObjectiveSystem.gd")

var _m

func before_test() -> void:
	_m = MOS.new()

func _use(objective_id: String, progress: Dictionary) -> void:
	var o = MOS.Objective.new()
	o.objective_id = objective_id
	_m.current_objective = o
	_m.objective_progress = progress

# ── The 8 auto-evaluated objectives (rulebook-correct completion) ──────────

func test_fight_off_completes_when_enemies_gone() -> void:
	_use("FIGHT_OFF", {"enemies_remaining": 0})
	assert_bool(_m.check_completion()).is_true()

func test_fight_off_completes_when_enemies_fled() -> void:
	_use("FIGHT_OFF", {"enemies_remaining": 3, "enemies_fled": true})
	assert_bool(_m.check_completion()).is_true()

func test_acquire_needs_secured_and_exited() -> void:
	_use("ACQUIRE", {"item_secured": true, "exited_with_item": true})
	assert_bool(_m.check_completion()).is_true()
	_use("ACQUIRE", {"item_secured": true, "exited_with_item": false})
	assert_bool(_m.check_completion()).is_false()

func test_move_through_completes_at_2_crew() -> void:
	# F6: rulebook p.90 "at least 2 crew" — was requiring 3.
	_use("MOVE_THROUGH", {"crew_exited": 2})
	assert_bool(_m.check_completion()).is_true()

func test_move_through_not_complete_at_1_crew() -> void:
	_use("MOVE_THROUGH", {"crew_exited": 1})
	assert_bool(_m.check_completion()).is_false()

func test_patrol_completes_at_3_points() -> void:
	# F5: rulebook p.90 "all 3 checked" — was requiring 4 (unwinnable, only 3 placed).
	_use("PATROL", {"markers_checked": 3})
	assert_bool(_m.check_completion()).is_true()

func test_patrol_not_complete_at_2_points() -> void:
	_use("PATROL", {"markers_checked": 2})
	assert_bool(_m.check_completion()).is_false()

func test_defend_needs_intact_and_6_rounds() -> void:
	_use("DEFEND", {"objective_intact": true, "rounds_survived": 6})
	assert_bool(_m.check_completion()).is_true()
	_use("DEFEND", {"objective_intact": true, "rounds_survived": 5})
	assert_bool(_m.check_completion()).is_false()

func test_search_completes_when_found() -> void:
	_use("SEARCH", {"item_found": true})
	assert_bool(_m.check_completion()).is_true()

func test_protect_needs_vip_alive_and_won() -> void:
	_use("PROTECT", {"vip_alive": true, "battle_won": true})
	assert_bool(_m.check_completion()).is_true()
	_use("PROTECT", {"vip_alive": false, "battle_won": true})
	assert_bool(_m.check_completion()).is_false()

func test_deliver_completes_when_delivered() -> void:
	_use("DELIVER", {"delivered": true})
	assert_bool(_m.check_completion()).is_true()

# ── ACCESS / ELIMINATE / SECURE are PLAYER-DRIVEN by design (NOT a bug) ──────
# check_completion() intentionally returns false for these three: their win
# states (a 1D6+Savvy 6+ access roll, killing a specific marked figure, holding
# the exact table centre for 2 consecutive rounds) are things the app cannot see
# on the physical table, so they complete via the player's manual toggle in
# VictoryProgressPanel — same tabletop-companion pattern as the FIGHT_OFF counter.
# The player-driven completion path is covered in test_battle_objective_tracker.gd
# (test_uncovered_types_have_no_auto_completion / _uncovered_row_exposes_manual_toggle).
# These assertions lock that check_completion() (the AUTO path) correctly does NOT
# claim to evaluate them — inventing auto-math here would violate the companion model.

func test_access_is_not_auto_derivable_by_design() -> void:
	_use("ACCESS", {"console_accessed": true})  # p.90: 1D6+Savvy 6+ -> player reports Win
	assert_bool(_m.check_completion()).is_false()

func test_eliminate_is_not_auto_derivable_by_design() -> void:
	_use("ELIMINATE", {"target_eliminated": true})  # p.90: kill marked target -> player reports
	assert_bool(_m.check_completion()).is_false()

func test_secure_is_not_auto_derivable_by_design() -> void:
	_use("SECURE", {"consecutive_secure_rounds": 2})  # p.91: hold centre 2 rounds -> player reports
	assert_bool(_m.check_completion()).is_false()
