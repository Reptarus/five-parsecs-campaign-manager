
# tests/game/character/psionics/test_psionics.gd
extends GutTest

const PsionicPower = preload("res://src/game/character/psionics/PsionicPower.gd")
const PsionicCharacter = preload("res://src/game/character/psionics/PsionicCharacter.gd")
const PsionicSystem = preload("res://src/core/systems/PsionicSystem.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const DiceSystem = preload("res://src/core/systems/DiceSystem.gd")

var psionic_system: PsionicSystem
var mock_psionic_character: PsionicCharacter
var mock_target_character: Character

func before_each():
    psionic_system = PsionicSystem.new()
    mock_psionic_character = PsionicCharacter.new()
    mock_target_character = Character.new()

    # Mock DiceSystem for predictable rolls
    mock_class(DiceSystem)
    DiceSystem.mock_method("roll_d10").returns(1) # Default to Barrier
    DiceSystem.mock_method("roll_2d6").returns(10) # Default projection roll
    DiceSystem.mock_method("roll_d6").returns(1) # Default strain roll

    # Mock character methods needed for psionics
    mock_psionic_character.global_position = Vector2(0, 0)
    mock_target_character.global_position = Vector2(100, 0)
    mock_psionic_character.add_stun_marker = funcref(self, "_mock_add_stun_marker")
    mock_psionic_character.has_special_ability = funcref(self, "_mock_has_special_ability")
    mock_target_character.has_special_ability = funcref(self, "_mock_has_special_ability")

func _mock_add_stun_marker():
    mock_psionic_character.stunned = true

func _mock_has_special_ability(ability_name: String) -> bool:
    if ability_name == "robotic" and mock_target_character == mock_psionic_character:
        return false # Psionic character is not robotic
    if ability_name == "robotic" and mock_target_character != mock_psionic_character:
        return mock_target_character.is_robotic_mock # Allow setting for target
    return false

func test_psionic_power_loads_from_data():
    # This test assumes GameDataManager is set up and loads psionic_powers.json
    # and PsionicPower._ready() is called.
    var barrier_power = PsionicPower.new(PsionicPower.PowerType.BARRIER)
    # Manually call _ready for testing if not in scene tree
    barrier_power._ready()
    assert_true(barrier_power.affects_robotic_targets, "Barrier should affect robotic targets")
    assert_true(barrier_power.target_self, "Barrier should target self")
    assert_true(barrier_power.persists, "Barrier should persist")
    assert_not_empty(barrier_power.description, "Barrier should have a description")

func test_psionic_system_determine_starting_powers():
    DiceSystem.mock_method("roll_d10").returns(1).then.returns(2) # Barrier, then Grab
    var powers = psionic_system.determine_starting_powers()
    assert_eq(powers.size(), 2, "Should get two starting powers")
    assert_eq(powers[0].power_type, PsionicPower.PowerType.BARRIER, "First power should be Barrier")
    assert_eq(powers[1].power_type, PsionicPower.PowerType.GRAB, "Second power should be Grab")

func test_psionic_system_resolve_projection_success():
    var grab_power = PsionicPower.new(PsionicPower.PowerType.GRAB)
    mock_psionic_character.global_position = Vector2(0,0)
    mock_target_character.global_position = Vector2(5,0) # Target within 10 (2d6 roll)
    DiceSystem.mock_method("roll_2d6").returns(10)

    var success = psionic_system.resolve_psionic_projection(mock_psionic_character, grab_power, mock_target_character.global_position, mock_target_character)
    assert_true(success, "Projection should succeed if target is in range")
    assert_false(mock_psionic_character.stunned, "Psionic should not be stunned on success without strain")

func test_psionic_system_resolve_projection_strain_success():
    var grab_power = PsionicPower.new(PsionicPower.PowerType.GRAB)
    mock_psionic_character.global_position = Vector2(0,0)
    mock_target_character.global_position = Vector2(15,0) # Target out of 2d6 range, needs strain
    DiceSystem.mock_method("roll_2d6").returns(10) # Initial roll
    DiceSystem.mock_method("roll_d6").returns(5) # Strain roll that causes stun

    # Mock the await for strain decision (assuming it's always true for testing)
    psionic_system.get_strain_decision = funcref(self, "_mock_get_strain_decision_true")

    var success = psionic_system.resolve_psionic_projection(mock_psionic_character, grab_power, mock_target_character.global_position, mock_target_character)
    assert_true(success, "Projection should succeed with strain")
    assert_true(mock_psionic_character.stunned, "Psionic should be stunned due to strain roll of 5")

func _mock_get_strain_decision_true():
    return true

func test_psionic_system_resolve_projection_strain_fail():
    var grab_power = PsionicPower.new(PsionicPower.PowerType.GRAB)
    mock_psionic_character.global_position = Vector2(0,0)
    mock_target_character.global_position = Vector2(15,0)
    DiceSystem.mock_method("roll_2d6").returns(10)
    DiceSystem.mock_method("roll_d6").returns(6) # Strain roll that causes stun and failure

    psionic_system.get_strain_decision = funcref(self, "_mock_get_strain_decision_true")

    var success = psionic_system.resolve_psionic_projection(mock_psionic_character, grab_power, mock_target_character.global_position, mock_target_character)
    assert_false(success, "Projection should fail with strain roll of 6")
    assert_true(mock_psionic_character.stunned, "Psionic should be stunned due to strain roll of 6")

func test_psionic_character_cannot_use_power_on_robotic_target_if_not_allowed():
    var enrage_power = PsionicPower.new(PsionicPower.PowerType.ENRAGE) # Enrage does not affect robotic targets
    mock_target_character.is_robotic_mock = true # Set target as robotic

    var can_use = mock_psionic_character.can_use_power(enrage_power, mock_target_character)
    assert_false(can_use, "Psionic should not be able to use Enrage on a robotic target")

func test_psionic_character_can_use_power_on_robotic_target_if_allowed():
    var barrier_power = PsionicPower.new(PsionicPower.PowerType.BARRIER) # Barrier affects robotic targets
    mock_target_character.is_robotic_mock = true

    var can_use = mock_psionic_character.can_use_power(barrier_power, mock_target_character)
    assert_true(can_use, "Psionic should be able to use Barrier on a robotic target")

# Add tests for Psionic Legality System, Enemy Psionics, Psi-Hunter Rivals
# These would involve mocking GameState, WorldGenerator, RivalSystem, etc.
