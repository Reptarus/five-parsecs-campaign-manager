# Species Expansion (Compendium DLC) - Implementation Guide

## 1. Overview
This document provides a comprehensive technical guide for implementing the new playable species (Krag and Skulkers) and related world-building features from the Compendium DLC. It covers data structures, class implementations, system integration, and DLC gating.

**Features Covered:**
- **High Priority:** Krag Species, Skulker Species, Updated Primary Alien Table.
- **Medium Priority:** Krag Colony Worlds, Skulker Colony Worlds.

## 2. Data Structures (JSON)

### `data/character_species.json`
This file will define all playable species, including the new DLC ones.

```json
{
  "human": { "name": "Human", "description": "Standard human.", "source": "core" },
  "krag": {
    "name": "Krag",
    "description": "Stocky and belligerent humanoids.",
    "source": "compendium_dlc",
    "abilities": ["no_dash", "belligerent_reroll", "mandatory_rival_with_patron"]
  },
  "skulker": {
    "name": "Skulker",
    "description": "Agile, rodent-like humanoids.",
    "source": "compendium_dlc",
    "abilities": ["ignore_difficult_ground", "flexible_armor_use", "agile_movement", "biological_resistance"]
  }
}
```

### `data/world_traits.json`
This existing file will be expanded with traits for colony worlds.

```json
{
  "busy_markets": {
    "name": "Busy Markets",
    "description": "This world has extensive trade networks.",
    "source": "compendium_dlc",
    "effects": ["special_trade_options"]
  },
  "vendetta_system": {
    "name": "Vendetta System",
    "description": "Reputation is everything here.",
    "source": "compendium_dlc",
    "effects": ["increased_rival_risk"]
  },
  "adventurous_population": {
    "name": "Adventurous Population",
    "description": "The locals are always looking for excitement.",
    "source": "compendium_dlc",
    "effects": ["unique_job_opportunities"]
  }
}
```

## 3. Class Implementation

### `src/game/character/species/Species.gd` (Base Class)
A new base `Resource` to define a species.

```gdscript
# src/game/character/species/Species.gd
class_name Species extends Resource

@export var id: StringName
@export var species_name: String
@export var description: String
@export var source: String # "core" or "compendium_dlc"
@export var abilities: Array[StringName]

func apply_traits(character: Character) -> void:
    # Base implementation (can be empty)
    pass

func _to_string() -> String:
    return str("Species[", species_name, "]")
```

### `src/game/character/species/KragSpecies.gd`

```gdscript
# src/game/character/species/KragSpecies.gd
class_name KragSpecies extends Species

func apply_traits(character: Character) -> void:
    # 1. Apply movement restriction
    character.set_meta("can_dash", false)

    # 2. Add special abilities as tags for other systems to interpret
    character.add_ability("belligerent_reroll")

    # 3. Handle mandatory rival (logic handled by CharacterGenerationManager)
    if character.has_patron():
        character.add_ability("needs_rival_for_patron")
```

### `src/game/character/species/SkulkerSpecies.gd`

```gdscript
# src/game/character/species/SkulkerSpecies.gd
class_name SkulkerSpecies extends Species

func apply_traits(character: Character) -> void:
    character.add_ability("ignore_difficult_ground")
    character.add_ability("flexible_armor_use")
    character.add_ability("agile_movement")
    character.add_ability("biological_resistance")
```

## 4. System Integration Points

### `CharacterGenerationManager.gd`
This manager orchestrates character creation and is the primary integration point.

```gdscript
# src/core/character/CharacterGenerationManager.gd

# --- In a function that creates a character ---
func create_new_character(species_id: StringName) -> Character:
    var character = Character.new()
    
    # Load species data
    var species_data = GameDataManager.get_species(species_id)
    if species_data == null:
        push_error(str("Species not found: ", species_id))
        return null

    # Instantiate and apply species resource
    var species_resource: Species = load(str("res://src/game/character/species/", species_id.capitalize(), "Species.gd")).new()
    character.species = species_resource
    species_resource.apply_traits(character)

    # Post-trait application logic
    if character.has_ability("needs_rival_for_patron"):
        RivalSystem.add_rival_for_character(character, "Krag Vendetta")

    return character
```

### `WorldGenerator.gd`
Integrates colony world generation.

```gdscript
# src/core/world/WorldGenerator.gd
func _generate_world_traits(world: World) -> void:
    # ... existing trait generation ...

    if DLCManager.is_dlc_owned("compendium"):
        # Krag Colony
        if randf() < 0.05: # 5% chance
            world.add_trait("Busy Markets")
            world.add_trait("Vendetta System")
            world.set_meta("colony_type", "Krag")
        # Skulker Colony
        elif randf() < 0.05: # 5% chance
            world.add_trait("Adventurous Population")
            world.set_meta("colony_type", "Skulker")
```

### `CombatManager.gd`
Interprets abilities during combat.

```gdscript
# src/core/systems/CombatManager.gd

# Example: Belligerent Reroll
func _resolve_attack(attacker: Character, target: Character) -> void:
    var roll = DiceSystem.roll_d20()
    if attacker.has_ability("belligerent_reroll") and roll <= 5:
        # Offer player a choice to reroll
        var choice = await get_tree().create_timer(0.1).timeout # Placeholder for UI
        if choice == "reroll":
            roll = DiceSystem.roll_d20()
            # Apply consequences (e.g., attacker becomes stunned)
            attacker.add_status("stunned")
    # ... continue attack resolution
```

## 5. DLC Gating Implementation

Gating must be applied at every point where DLC content could be accessed.

### Character Creation UI
The UI must check DLC ownership before showing species options.

```gdscript
# In CharacterCreationUI.gd
func _populate_species_list():
    var all_species = GameDataManager.get_all_species()
    for species_id in all_species:
        var species_data = all_species[species_id]
        if species_data.source == "compendium_dlc" and not DLCManager.is_dlc_owned("compendium"):
            continue # Skip DLC species if not owned
        
        var option_button = Button.new()
        option_button.text = species_data.name
        option_button.connect("pressed", Callable(self, "_on_species_selected").bind(species_id))
        add_child(option_button)
```

### Random Generation Fallback
Ensure random rolls cannot select DLC content if not owned.

```gdscript
# In CharacterGenerationManager.gd
func _get_random_species_id() -> StringName:
    var species_pool = GameDataManager.get_all_species().keys()
    if not DLCManager.is_dlc_owned("compendium"):
        species_pool = species_pool.filter(func(id): return GameDataManager.get_species(id).source == "core")
    
    return species_pool.pick_random()
```

## 6. Testing Strategy
- **Unit Tests**:
    - `test_krag_traits`: Verify a character passed to `KragSpecies.apply_traits` has `can_dash=false` and the correct abilities.
    - `test_skulker_traits`: Verify a character passed to `SkulkerSpecies.apply_traits` has the correct abilities.
- **Integration Tests**:
    - `test_character_creation_flow_with_dlc`: Create a Krag character and verify it has the correct rival and abilities.
    - `test_character_creation_flow_without_dlc`: Ensure Krag/Skulker species are not available for selection or random generation.
    - `test_world_gen_with_dlc`: Run world generation 100 times and assert that Krag/Skulker colonies appear.
    - `test_combat_belligerent_reroll`: Simulate combat and verify the reroll option appears for a Krag character.
- **DLC Gating Tests**:
    - Disable the DLC flag and run all integration tests to ensure the game falls back gracefully without errors.

## 7. Dependencies
- `src/core/character/Base/Character.gd`
- `src/core/data/GameDataManager.gd`
- `src/core/systems/DLCManager.gd` (Autoload Singleton)
- `src/core/world/WorldGenerator.gd`
- `src/core/character/CharacterGenerationManager.gd`
- `src/core/systems/CombatManager.gd`
- `src/core/systems/RivalSystem.gd`
