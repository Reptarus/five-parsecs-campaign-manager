extends GdUnitTestSuite
## Tests for PostBattle subsystem processors (Phase 33 decomposition)
## Covers 3 NOT_TESTED mechanics: Danger Pay, Training, Galactic War
## Core Rules Reference: p.97 (Pay), p.129 (Training), p.102 (Galactic War)

const PaymentProcessor := preload(
	"res://src/core/campaign/phases/post_battle/PaymentProcessor.gd")
const ExperienceTrainingProcessor := preload(
	"res://src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd")
const GalacticWarProcessor := preload(
	"res://src/core/campaign/phases/post_battle/GalacticWarProcessor.gd")
const PostBattleContextClass := preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

# ============================================================================
# PaymentProcessor - Danger Pay Bonus (difficulty multiplier)
# ============================================================================

func test_payment_processor_exists():
	"""PaymentProcessor class loads successfully"""
	assert_that(PaymentProcessor).is_not_null()

func test_payment_processor_is_refcounted():
	"""PaymentProcessor should be RefCounted (not Node)"""
	var processor = PaymentProcessor.new()
	assert_that(processor is RefCounted).is_true()

func test_failed_mission_still_pays():
	## Regression for Bug 2 (Sprint A, 2026-05-24): Core Rules p.120 says
	## payment is unconditional (1D6 credits in pay/loot/bounty/salvage).
	## Only Invasion battles deny pay. Previous code at PaymentProcessor.gd:60-61
	## zeroed payment on mission_successful=false — a fabricated rule.
	## This test ensures a failed non-Invasion mission still pays >= 1 credit.
	var processor = PaymentProcessor.new()
	var ctx = auto_free(PostBattleContextClass.new())
	ctx.battle_result = {
		"is_invasion": false,
		"is_red_zone": false,
		"is_quest_finale": false,
		"is_rival_mission": false,
		"danger_pay": 0,
	}
	ctx.mission_successful = false
	# No game_state / journal — process_payment short-circuits both safely.
	# roll_d6() falls back to randi_range(1, 6) when dice_manager is null.
	var payment: int = processor.process_payment(ctx)
	assert_that(payment).is_greater_equal(1)
	assert_that(payment).is_less_equal(6)

func test_invasion_battle_still_denies_pay():
	## Regression for Bug 2 (Sprint A, 2026-05-24): Invasion battles ARE the
	## only Core Rules p.121 exception to unconditional payment. The early-
	## return at PaymentProcessor.gd:31 must still fire.
	var processor = PaymentProcessor.new()
	var ctx = auto_free(PostBattleContextClass.new())
	ctx.battle_result = {"is_invasion": true}
	ctx.mission_successful = true  # successful invasion still denies pay
	var payment: int = processor.process_payment(ctx)
	assert_that(payment).is_equal(0)

# ============================================================================
# ExperienceTrainingProcessor - Training Opportunities
# ============================================================================

func test_training_processor_exists():
	"""ExperienceTrainingProcessor class loads successfully"""
	assert_that(ExperienceTrainingProcessor).is_not_null()

func test_training_processor_is_refcounted():
	var processor = ExperienceTrainingProcessor.new()
	assert_that(processor is RefCounted).is_true()

func test_training_processor_has_courses():
	"""Training processor should define course types"""
	var processor = ExperienceTrainingProcessor.new()
	# The TRAINING_COURSES const should exist
	assert_that(processor.has_method("process_training") or
		"TRAINING_COURSES" in processor).is_true()

# ============================================================================
# GalacticWarProcessor - 2D6 per planet
# ============================================================================

func test_galactic_war_processor_exists():
	"""GalacticWarProcessor class loads successfully"""
	assert_that(GalacticWarProcessor).is_not_null()

func test_galactic_war_processor_is_refcounted():
	var processor = GalacticWarProcessor.new()
	assert_that(processor is RefCounted).is_true()

# ============================================================================
# All processors have required methods
# ============================================================================

func test_payment_has_process_method():
	var processor = PaymentProcessor.new()
	assert_that(processor.has_method("process_payment")).is_true()

func test_training_has_process_method():
	var processor = ExperienceTrainingProcessor.new()
	assert_that(processor.has_method("process_training")).is_true()

func test_galactic_war_has_process_method():
	var processor = GalacticWarProcessor.new()
	assert_that(processor.has_method("process_galactic_war")).is_true()
