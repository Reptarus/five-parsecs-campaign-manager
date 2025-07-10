
# Loans System (Compendium DLC) - Implementation Guide

## 1. Overview
This document provides a comprehensive technical guide for implementing the "Loans: Who Do You Owe?" system from the Compendium DLC. It covers data structures, class implementations, system integration, and DLC gating.

**Features Covered:**
- **High Priority:** Loan origins, interest, enforcement thresholds, and enforcement actions (Rivals, forced missions).

## 2. Data Structures (JSON)

### `data/loans.json`
This new file will define the different loan providers and their terms.

```json
{
  "criminal_syndicate": {
    "name": "Criminal Syndicate",
    "min_amount": 1000,
    "max_amount": 10000,
    "interest_rate": 0.25,
    "enforcement_threshold": 2, // 2 missed payments
    "enforcement_action": "spawn_rival_enforcers"
  },
  "corporate_bank": {
    "name": "Corporate Bank",
    "min_amount": 5000,
    "max_amount": 50000,
    "interest_rate": 0.10,
    "enforcement_threshold": 3,
    "enforcement_action": "force_mission_asset_retrieval"
  }
}
```

## 3. Class Implementation

### `src/core/campaign/LoanManager.gd` (Autoload Singleton)
Manages the player's loan state throughout the campaign.

```gdscript
# src/core/campaign/LoanManager.gd
class_name LoanManager extends Node

var active_loan: Dictionary = {
    "has_loan": false,
    "provider": "",
    "principal": 0,
    "interest_rate": 0.0,
    "due_this_turn": 0,
    "missed_payments": 0
}

func _ready():
    CampaignState.upkeep_phase_started.connect(_on_upkeep_phase_started)

func take_out_loan(provider_id: StringName, amount: int):
    if not DLCManager.is_dlc_owned("compendium") or active_loan.has_loan:
        return

    var provider_data = GameDataManager.get_loan_provider(provider_id)
    active_loan.has_loan = true
    active_loan.provider = provider_id
    active_loan.principal = amount
    active_loan.interest_rate = provider_data.interest_rate
    active_loan.missed_payments = 0
    CampaignState.add_credits(amount)

func make_payment(amount: int):
    if not active_loan.has_loan or amount <= 0:
        return

    if CampaignState.get_credits() < amount:
        # Handle insufficient funds
        return

    CampaignState.remove_credits(amount)
    active_loan.principal -= amount
    if active_loan.principal <= 0:
        _clear_loan()

func _on_upkeep_phase_started():
    if not active_loan.has_loan: return

    var interest_amount = int(active_loan.principal * active_loan.interest_rate)
    active_loan.due_this_turn = interest_amount + (active_loan.principal / 10) # 10% of principal

    # Automatically deduct payment if possible, otherwise it's a missed payment
    if CampaignState.get_credits() >= active_loan.due_this_turn:
        make_payment(active_loan.due_this_turn)
    else:
        active_loan.missed_payments += 1
        _check_for_enforcement()

func _check_for_enforcement():
    var provider_data = GameDataManager.get_loan_provider(active_loan.provider)
    if active_loan.missed_payments >= provider_data.enforcement_threshold:
        _trigger_enforcement(provider_data.enforcement_action)
        active_loan.missed_payments = 0 # Reset after enforcement

func _trigger_enforcement(action: String):
    match action:
        "spawn_rival_enforcers":
            RivalSystem.add_rival("Loan Enforcers", {"source": active_loan.provider})
        "force_mission_asset_retrieval":
            var mission = MissionGenerator.generate_forced_mission("asset_retrieval")
            CampaignState.set_next_mission(mission)

func _clear_loan():
    active_loan.has_loan = false
    # ... reset all dictionary values
```

## 4. System Integration Points

### Campaign Upkeep Phase
- `CampaignPhaseManager.gd` needs to emit the `upkeep_phase_started` signal that `LoanManager` connects to. This is the primary trigger for loan payment and enforcement logic.

### UI for Loans
- A new UI screen is required for players to view available loans from different providers.
- The main campaign HUD should display the current loan status (principal, payment due) if a loan is active.

### Rival System & Mission Generator
- `RivalSystem.gd` and `MissionGenerator.gd` need to have public methods (`add_rival`, `generate_forced_mission`) that the `LoanManager` can call to trigger enforcement actions.

## 5. DLC Gating

- **UI Gating**: The UI for taking out loans must be completely hidden or disabled if `DLCManager.is_dlc_owned("compendium")` is false.
- **Core Logic Gate**: The `take_out_loan` function has a guard clause at the beginning. This is the most critical gate.
- **Upkeep Logic**: The `_on_upkeep_phase_started` function is implicitly gated by the `active_loan.has_loan` check. Since a loan cannot be taken without the DLC, this logic will never run.
- **Save File Robustness**: Even if a save file is edited to have `active_loan.has_loan = true`, the `GameDataManager` would fail to load the `provider_data` if the DLC is not owned, preventing enforcement actions from being triggered.

## 6. Testing Strategy
- **Unit Tests**:
    - `test_take_out_loan`: Verify that taking a loan correctly updates `active_loan` data and player credits.
    - `test_loan_payment`: Simulate making a payment and assert that the principal is reduced.
    - `test_missed_payment_and_enforcement`: Simulate an upkeep phase with insufficient funds, verify `missed_payments` increments, and assert that the correct enforcement action is triggered when the threshold is met.
- **Integration Tests**:
    - `test_loan_lifecycle`: Take out a loan, proceed through several campaign turns, make some payments, miss others, and verify that the system behaves correctly up to and including enforcement.
- **DLC Gating Tests**:
    - Disable the DLC flag and verify that the loan UI is not visible and that no loan-related logic can be triggered.

## 7. Dependencies
- `src/core/data/GameDataManager.gd`
- `src/core/systems/DLCManager.gd`
- `src/core/campaign/CampaignState.gd`
- `src/core/systems/RivalSystem.gd`
- `src/core/systems/MissionGenerator.gd`
