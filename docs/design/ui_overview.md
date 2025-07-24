# UI Overview

**Last Updated**: July 2025
**Status**: Implemented and Production-Ready

## Overview

The User Interface (UI) of the Five Parsecs Campaign Manager is designed for a streamlined and intuitive user experience, particularly for complex workflows like campaign creation. The UI architecture is built around a centralized `UIManager` and `SceneRouter` for efficient screen management and navigation.

## Key Components

-   **`UIManager` (`src/ui/screens/UIManager.gd`)**: This script is responsible for managing the visibility and state of various UI screens. It handles screen transitions, queues UI updates, and provides a centralized point for showing and hiding different parts of the application's interface.

-   **`SceneRouter` (`src/ui/screens/SceneRouter.gd`)**: The `SceneRouter` acts as the central navigation hub for the entire application. It manages scene transitions, maintains a navigation history for back functionality, and provides a categorized list of all available scenes within the game. It ensures safe and validated transitions between different parts of the game.

## Campaign Creation Workflow

The campaign creation process is a multi-step workflow managed by the `CampaignCreationUI` (`src/ui/screens/campaign/CampaignCreationUI.gd`). This UI integrates deeply with the `CampaignCreationStateManager` (`src/core/campaign/creation/CampaignCreationStateManager.gd`) to guide the user through the necessary steps:

1.  **Configuration (`ConfigPanel`)**: Users define basic campaign parameters like name, difficulty, and victory conditions.
2.  **Crew Setup (`CrewPanel`)**: Users create and customize their crew members, including their attributes, backgrounds, and motivations.
3.  **Captain Creation (`CaptainPanel`)**: A specific crew member is designated as the campaign's captain.
4.  **Ship Assignment (`ShipPanel`)**: Users select and configure their starting spaceship.
5.  **Equipment Generation (`EquipmentPanel`)**: Starting equipment for the crew and ship is generated.
6.  **Final Review (`FinalPanel`)**: Users review all their choices before finalizing the campaign creation.

### Integration with State Manager

The `CampaignCreationUI` communicates with the `CampaignCreationStateManager` to:

-   **Validate Data**: Each step's data is validated against game rules and constraints.
-   **Manage Progress**: The UI updates based on the current phase and validation status provided by the state manager.
-   **Handle Completion**: Once all steps are complete and validated, the state manager orchestrates the final campaign creation and persistence.

## UI Components

The `src/ui/components` directory contains reusable UI elements used across various screens. These components are designed to be modular and adhere to the project's overall design principles.

## Example Usage

```gdscript
# Example of navigating to the campaign creation screen
SceneRouter.navigate_to("campaign_creation")

# Example of showing a specific UI screen
UIManager.show_screen("MainMenu")
```
