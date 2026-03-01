# Combat System

**Last Updated**: July 2025
**Status**: Implemented and Production-Ready

## Overview

The Five Parsecs Campaign Manager features a comprehensive combat system that adheres to the rules of Five Parsecs From Home. The system is composed of two primary components:

-   **`CombatResolver`**: Handles the core mechanics of combat, including hit calculation, damage resolution, and the application of status effects.
-   **`FPCM_BattleEventsSystem`**: Manages dynamic battle events that occur during combat, adding narrative and tactical depth.

## Combat Resolver

The `CombatResolver` (`src/game/combat/CombatResolver.gd`) is responsible for the turn-by-turn resolution of combat actions. It includes:

-   **Interface Validation**: Ensures that `Character` objects conform to the expected properties and methods required for combat.
-   **Action Resolution**: Resolves various combat actions, such as ranged attacks and special abilities.
-   **Hit and Damage Calculation**: Implements the game's rules for determining hits and calculating damage, considering factors like cover, elevation, and weapon traits.
-   **Status Effects**: Applies and manages various combat-related status effects (e.g., stun, suppress, bleed).
-   **Reactions**: Handles character reactions like overwatch, counter-attacks, and dodges.

## Battle Events System

The `FPCM_BattleEventsSystem` (`src/core/battle/BattleEventsSystem.gd`) introduces dynamic and unpredictable elements to combat encounters. Key features include:

-   **Event Triggers**: Battle events are triggered at specific rounds (e.g., end of rounds 2 and 4) as per the Five Parsecs rules.
-   **100 Core Rules Events**: Implements a wide array of battle events defined in the Five Parsecs From Home core rulebook.
-   **Environmental Hazards**: Introduces environmental hazards that can affect characters and the battlefield.
-   **Conflict Resolution**: Manages conflicts between triggered events to ensure a consistent and fair experience.
-   **Serialization**: Supports saving and loading of active events and hazards, ensuring persistence across game sessions.

## Integration

Both systems work in conjunction to provide a rich combat experience. The `CombatResolver` focuses on the immediate tactical interactions, while the `FPCM_BattleEventsSystem` adds a layer of strategic and narrative unpredictability through its event management.

## Example Usage

```gdscript
# Example of resolving a ranged attack
CombatResolver.resolve_combat_action(attacker_character, target_character, GlobalEnums.UnitAction.ATTACK)

# Example of advancing a battle round to trigger events
BattleEventsSystem.advance_round()
```
