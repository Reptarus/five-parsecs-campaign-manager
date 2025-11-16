class_name PsionicSystem
extends Node

## PsionicSystem
##
## Manages psionic powers from Trailblazer's Toolkit DLC.
## Handles power activation, targeting, effects, and duration tracking.
##
## Usage:
##   PsionicSystem.activate_power(character, "Barrier", target)
##   PsionicSystem.process_active_powers(character) # Call each round
##   var powers := PsionicSystem.get_available_powers(character)

signal power_activated(character, power_name: String, target, success: bool)
signal power_expired(character, power_name: String)
signal power_effect_applied(target, effect_name: String, power_name: String)

## Available psionic powers (loaded from JSON)
var psionic_powers: Array = []

## Active powers currently in effect
## Structure: { character_id: [ { power: Dictionary, target: Variant, rounds_remaining: int, activated_on_turn: int } ] }
var active_powers: Dictionary = {}

## Content filter for DLC checking
var content_filter: ContentFilter = null

func _ready() -> void:
	content_filter = ContentFilter.new()
	_load_psionic_powers()

## Load psionic powers from DLC data
func _load_psionic_powers() -> void:
	if not content_filter.is_content_type_available("psionic_powers"):
		push_warning("PsionicSystem: Trailblazer's Toolkit not available. Psionic powers disabled.")
		return

	var expansion_manager := get_node_or_null("/root/ExpansionManager")
	if not expansion_manager:
		push_error("PsionicSystem: ExpansionManager not found.")
		return

	var powers_data = expansion_manager.load_expansion_data("trailblazers_toolkit", "psionic_powers.json")
	if powers_data and powers_data.has("psionic_powers"):
		psionic_powers = powers_data.psionic_powers
		print("PsionicSystem: Loaded %d psionic powers." % psionic_powers.size())
	else:
		push_error("PsionicSystem: Failed to load psionic powers data.")

## Get all available psionic powers
func get_all_powers() -> Array:
	return psionic_powers.duplicate()

## Get psionic power by name
func get_power(power_name: String) -> Dictionary:
	for power in psionic_powers:
		if power.name == power_name:
			return power
	return {}

## Get powers available to a character
## Filters based on character's known powers
func get_available_powers(character) -> Array:
	if not _can_use_psionics(character):
		return []

	# If character has specific known powers, return those
	if character.has("known_powers") and character.known_powers is Array:
		var available := []
		for power_name in character.known_powers:
			var power := get_power(power_name)
			if not power.is_empty():
				available.append(power)
		return available

	# If character is a psyker but no specific powers, return all powers
	if _is_psyker(character):
		return get_all_powers()

	return []

## Attempt to activate a psionic power
## Returns true if activation successful, false if failed
func activate_power(caster, power_name: String, target = null) -> bool:
	if not _can_use_psionics(caster):
		push_warning("PsionicSystem: Character cannot use psionics.")
		power_activated.emit(caster, power_name, target, false)
		return false

	var power := get_power(power_name)
	if power.is_empty():
		push_error("PsionicSystem: Power '%s' not found." % power_name)
		power_activated.emit(caster, power_name, target, false)
		return false

	# Validate target
	if not _validate_target(power, caster, target):
		push_warning("PsionicSystem: Invalid target for power '%s'." % power_name)
		power_activated.emit(caster, power_name, target, false)
		return false

	# Check activation roll
	var activation_success := _roll_activation(caster, power)
	if not activation_success:
		print("PsionicSystem: Power '%s' activation failed." % power_name)
		power_activated.emit(caster, power_name, target, false)
		return false

	# Apply power effects
	_apply_power_effects(caster, power, target)

	# Track power if it persists
	if power.get("persists", false):
		_track_active_power(caster, power, target)

	print("PsionicSystem: Power '%s' activated successfully." % power_name)
	power_activated.emit(caster, power_name, target, true)
	return true

## Process active powers (call at start of each round)
func process_active_powers(character) -> void:
	var char_id := _get_character_id(character)
	if not active_powers.has(char_id):
		return

	var powers_to_remove := []

	for i in range(active_powers[char_id].size()):
		var active_power := active_powers[char_id][i]

		# Decrease duration
		if active_power.has("rounds_remaining") and active_power.rounds_remaining > 0:
			active_power.rounds_remaining -= 1

			if active_power.rounds_remaining <= 0:
				powers_to_remove.append(i)
				_expire_power(character, active_power.power)

	# Remove expired powers (iterate backwards to avoid index issues)
	powers_to_remove.sort()
	powers_to_remove.reverse()
	for idx in powers_to_remove:
		active_powers[char_id].remove_at(idx)

## Get active powers for a character
func get_active_powers(character) -> Array:
	var char_id := _get_character_id(character)
	if active_powers.has(char_id):
		return active_powers[char_id].duplicate()
	return []

## Check if character has a specific power active
func has_active_power(character, power_name: String) -> bool:
	var char_id := _get_character_id(character)
	if not active_powers.has(char_id):
		return false

	for active_power in active_powers[char_id]:
		if active_power.power.name == power_name:
			return true
	return false

## End a specific power early (e.g., concentration broken)
func end_power(character, power_name: String) -> void:
	var char_id := _get_character_id(character)
	if not active_powers.has(char_id):
		return

	for i in range(active_powers[char_id].size() - 1, -1, -1):
		if active_powers[char_id][i].power.name == power_name:
			var power := active_powers[char_id][i].power
			active_powers[char_id].remove_at(i)
			_expire_power(character, power)
			break

## Clear all active powers for a character (e.g., character knocked out)
func clear_all_powers(character) -> void:
	var char_id := _get_character_id(character)
	if active_powers.has(char_id):
		for active_power in active_powers[char_id]:
			_expire_power(character, active_power.power)
		active_powers.erase(char_id)

## Get power difficulty as numeric value
func get_power_difficulty_value(power: Dictionary) -> int:
	var difficulty := power.get("difficulty", "basic")
	match difficulty:
		"basic": return 1
		"intermediate": return 2
		"advanced": return 3
		_: return 1

## Get power activation target number (e.g., "5+" returns 5)
func get_activation_target(power: Dictionary) -> int:
	var activation_roll: String = power.get("activation", {}).get("activation_roll", "4+")
	return int(activation_roll.replace("+", ""))

## Check if target is valid for power
func can_target(power: Dictionary, caster, target) -> bool:
	return _validate_target(power, caster, target)

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _can_use_psionics(character) -> bool:
	# Must have Trailblazer's Toolkit DLC
	if not content_filter.is_content_type_available("psionic_powers"):
		return false

	# Character must be a psyker or have psionic ability
	return _is_psyker(character)

func _is_psyker(character) -> bool:
	if character is Dictionary:
		# Check character type
		if character.get("character_type", "") == "Psyker":
			return true
		# Check for psionic ability
		if character.has("abilities") and character.abilities is Array:
			for ability in character.abilities:
				if "psionic" in str(ability).to_lower():
					return true
		# Check for known powers
		if character.has("known_powers") and character.known_powers is Array:
			return character.known_powers.size() > 0
	elif character is Resource:
		if character.get("is_psyker"):
			return true
		if character.has_method("can_use_psionics"):
			return character.can_use_psionics()

	return false

func _validate_target(power: Dictionary, caster, target) -> bool:
	var target_type: String = power.get("target_type", "enemy")

	match target_type:
		"self":
			return target == null or target == caster
		"enemy":
			return target != null and target != caster
		"any":
			return target != null
		_:
			return false

func _roll_activation(caster, power: Dictionary) -> bool:
	var target_number := get_activation_target(power)

	# Roll 1D6 + Savvy modifier
	var roll := randi() % 6 + 1
	var savvy := _get_character_savvy(caster)

	var total := roll + savvy
	var success := total >= target_number

	print("PsionicSystem: Activation roll for %s: %d (1d6) + %d (Savvy) = %d vs %d+ = %s" % [
		power.name, roll, savvy, total, target_number, "SUCCESS" if success else "FAIL"
	])

	return success

func _get_character_savvy(character) -> int:
	if character is Dictionary:
		return character.get("savvy", 0)
	elif character is Resource:
		return character.get("savvy") if character.get("savvy") else 0
	return 0

func _apply_power_effects(caster, power: Dictionary, target) -> void:
	var effects: Array = power.get("effects", [])

	for effect in effects:
		if effect is Dictionary:
			_apply_single_effect(caster, power, target, effect)
			power_effect_applied.emit(target, effect.get("name", "Unknown"), power.name)

func _apply_single_effect(caster, power: Dictionary, target, effect: Dictionary) -> void:
	# This is a simplified version - full implementation would integrate with combat system
	var effect_name: String = effect.get("name", "")

	print("PsionicSystem: Applying effect '%s' from power '%s'" % [effect_name, power.name])

	# Different powers have different effect implementations
	# Full integration would modify target stats, apply status effects, etc.
	match power.name:
		"Barrier":
			_apply_barrier_effect(target)
		"Grab":
			_apply_grab_effect(target)
		"Push":
			_apply_push_effect(caster, target)
		"Sever":
			_apply_sever_effect(target)
		"Shielding":
			_apply_shielding_effect(target)
		"Stun":
			_apply_stun_effect(target)
		"Weaken":
			_apply_weaken_effect(target)
		_:
			print("PsionicSystem: Effect for power '%s' not implemented yet." % power.name)

func _track_active_power(caster, power: Dictionary, target) -> void:
	var char_id := _get_character_id(caster)

	if not active_powers.has(char_id):
		active_powers[char_id] = []

	# Calculate duration in rounds
	var duration := _parse_duration(power.get("activation", {}).get("duration", "Instant"))

	active_powers[char_id].append({
		"power": power,
		"target": target,
		"rounds_remaining": duration,
		"activated_on_turn": _get_current_turn()
	})

func _parse_duration(duration_string: String) -> int:
	if duration_string == "Instant":
		return 0
	elif duration_string.contains("Until"):
		return 1
	elif duration_string.contains("1D3"):
		return randi() % 3 + 1
	elif duration_string.contains("Concentration"):
		return 999 # Effectively infinite until broken
	else:
		return 1

func _expire_power(character, power: Dictionary) -> void:
	print("PsionicSystem: Power '%s' expired for character." % power.name)
	power_expired.emit(character, power.name)

func _get_character_id(character) -> String:
	if character is Dictionary:
		return character.get("id", str(character.get_instance_id()))
	elif character is Resource:
		return character.get("id") if character.get("id") else str(character.get_instance_id())
	return str(character.get_instance_id()) if character is Object else "unknown"

func _get_current_turn() -> int:
	# Would integrate with campaign/battle turn tracking
	return 0

# ============================================================================
# POWER EFFECT IMPLEMENTATIONS
# ============================================================================

func _apply_barrier_effect(target) -> void:
	# Grant deflection chance against ranged attacks
	if target is Dictionary:
		if not target.has("active_effects"):
			target.active_effects = []
		target.active_effects.append({"type": "barrier", "deflection_chance": 4})

func _apply_grab_effect(target) -> void:
	# Immobilize target
	if target is Dictionary:
		target.is_immobilized = true
		target.combat_skill_modifier = target.get("combat_skill_modifier", 0) - 1

func _apply_push_effect(caster, target) -> void:
	# Knockback and potential stun
	var knockback_distance := randi() % 6 + 1
	print("PsionicSystem: Target pushed %d inches away." % knockback_distance)

func _apply_sever_effect(target) -> void:
	# Deal damage ignoring armor
	var damage := randi() % 6 + 1
	print("PsionicSystem: Target takes %d psionic damage (ignores armor)." % damage)

func _apply_shielding_effect(target) -> void:
	# Grant armor save
	if target is Dictionary:
		var current_armor := target.get("armor_save", 7)
		target.armor_save = max(4, current_armor - 1)

func _apply_stun_effect(target) -> void:
	# Incapacitate target
	if target is Dictionary:
		target.is_stunned = true
		target.stun_duration = randi() % 3 + 1

func _apply_weaken_effect(target) -> void:
	# Reduce attributes
	if target is Dictionary:
		target.toughness = max(1, target.get("toughness", 3) - 1)
		target.combat_skill_modifier = target.get("combat_skill_modifier", 0) - 1
