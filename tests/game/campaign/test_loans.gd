
# tests/game/campaign/test_loans.gd
extends GutTest

const LoanManager = preload("res://src/game/campaign/LoanManager.gd") # Assuming this will be created
const GameState = preload("res://src/core/state/GameState.gd") # For DLC check

var loan_manager: LoanManager

func before_each():
    loan_manager = LoanManager.new()
    # Mock GameState for DLC check
    mock_class(GameState)
    GameState.mock_method("is_compendium_dlc_unlocked").returns(true) # Assume DLC is unlocked for testing

func test_initial_loan_state():
    assert_false(loan_manager.has_active_loan(), "Should not have active loan initially")
    assert_eq(loan_manager.current_debt, 0, "Current debt should be 0 initially")

func test_take_loan():
    loan_manager.take_loan(100, 10, "Criminal Syndicate")
    assert_true(loan_manager.has_active_loan(), "Should have active loan after taking one")
    assert_eq(loan_manager.current_debt, 100, "Current debt should be 100")
    assert_eq(loan_manager.loan_origin, "Criminal Syndicate", "Loan origin should be set")

func test_make_payment():
    loan_manager.take_loan(100, 10, "Criminal Syndicate")
    loan_manager.make_payment(50)
    assert_eq(loan_manager.current_debt, 50, "Debt should decrease after payment")

func test_loan_enforcement_thresholds():
    loan_manager.take_loan(100, 10, "Criminal Syndicate")
    loan_manager.make_payment(10) # Debt 90
    loan_manager.process_loan_enforcement() # Should not trigger enforcement yet
    assert_false(loan_manager.enforcement_triggered, "Enforcement should not be triggered yet")

    loan_manager.make_payment(80) # Debt 10
    loan_manager.process_loan_enforcement() # Should trigger enforcement
    assert_true(loan_manager.enforcement_triggered, "Enforcement should be triggered")

func test_dlc_gating():
    GameState.mock_method("is_compendium_dlc_unlocked").returns(false)
    var new_manager = LoanManager.new()
    new_manager.take_loan(100, 10, "Criminal Syndicate")
    assert_false(new_manager.has_active_loan(), "Loan should not be taken if DLC is locked")

# Add tests for specific enforcement actions, rival generation from loans, etc.
