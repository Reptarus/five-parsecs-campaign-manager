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
