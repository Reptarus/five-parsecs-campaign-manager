# Campaign Phase Panels

This directory contains UI panels for the different phases of a Five Parsecs campaign.

## Phase Panel Overview

- `UpkeepPhasePanel.gd/tscn` - Upkeep phase UI (payments, maintenance, etc.)
- `StoryPhasePanel.gd/tscn` - Story phase UI (narrative events, story progression)
- `CampaignPhasePanel.gd/tscn` - Campaign phase UI (campaign management)
- `BattleSetupPhasePanel.gd/tscn` - Battle setup phase UI (preparing for battles)
- `BattleResolutionPhasePanel.gd/tscn` - Battle resolution phase UI (resolving battle outcomes)
- `AdvancementPhasePanel.gd/tscn` - Advancement phase UI (character progression)
- `TradePhasePanel.gd/tscn` - Trade phase UI (buying, selling, trading)
- `EndPhasePanel.gd/tscn` - End phase UI (campaign turn conclusion)
- `BasePhasePanel.gd` - Base class for all phase panels

## Phase System Structure

All phase panels inherit from `BasePhasePanel` and follow a consistent structure:

1. `setup_phase()` - Initializes the phase
2. `complete_phase()` - Completes the phase
3. `validate_phase_requirements()` - Validates requirements for phase completion
4. `get_phase_data()` - Returns phase-specific data

## Integration with Campaign System

The phase panels integrate with the campaign system through:

- The CampaignPhaseManager for phase transitions
- The GameState for accessing and modifying game data
- Event signals for phase-specific events

## UI Elements

Each phase panel typically contains:

- Phase-specific information displays
- Action buttons for phase-specific actions
- Navigation controls for phase completion
- Validation messages for requirements

## Best Practices

- Keep phase logic in the core systems, UI panels should focus on display and input
- Implement proper validation and error handling
- Document phase requirements and transitions
- Follow the established design patterns for consistency
- Support both mouse/keyboard and touch interactions
- Ensure responsive design for all screen sizes 