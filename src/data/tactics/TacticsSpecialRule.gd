class_name TacticsSpecialRule
extends Resource

## TacticsSpecialRule - Five Parsecs: Tactics special rule definition
## Replaces AoF SpecialRule with Tactics-specific rule types and traits.
## Used for both weapon traits (25 types) and species abilities.
## Source: Five Parsecs: Tactics rulebook pp.38-42, species army lists

enum RuleType {
	WEAPON,         # Weapon trait (Area, Piercing, Sniping, etc.)
	SPECIES,        # Species-wide ability (Widely Skilled, Keen Senses, etc.)
	VETERAN,        # Veteran skill (Covering Fire, Marksmen, etc.)
	COMBAT,         # Combat modifier (Flanking Fire, Overwatch, etc.)
	MORALE,         # Morale-related (Determined, Disciplined, Fearsome, etc.)
	MOVEMENT,       # Movement modifier (Loping Run, Winged, etc.)
	DEFENSIVE,      # Defensive ability (Saving Throw, Hardened Network, etc.)
	SPECIAL,        # Other effects
}

# Rule Identity
@export var rule_name: String = ""
@export var rule_type: RuleType = RuleType.SPECIAL
@export var description: String = ""

# Parametric Value (for rules like Saving(5), Transport(10))
@export var rule_value: int = 0

# Cost modifier for army building (pts delta when this rule is present)
@export var points_cost: int = 0


## Get display name with parameter if applicable
func get_display_name() -> String:
	if rule_value > 0:
		return "%s(%d)" % [rule_name, rule_value]
	return rule_name


## Check if this rule matches a name (case-insensitive)
func matches(name: String) -> bool:
	return rule_name.to_lower() == name.to_lower()


## Create a TacticsSpecialRule from string format like "Piercing" or "Transport(10)"
static func from_string(rule_string: String) -> TacticsSpecialRule:
	var rule := TacticsSpecialRule.new()

	var paren_start := rule_string.find("(")
	if paren_start != -1:
		rule.rule_name = rule_string.substr(0, paren_start).strip_edges()
		var paren_end := rule_string.find(")")
		if paren_end != -1:
			rule.rule_value = int(rule_string.substr(paren_start + 1, paren_end - paren_start - 1))
	else:
		rule.rule_name = rule_string.strip_edges()

	rule.rule_type = _infer_rule_type(rule.rule_name)
	return rule


## Create from a dictionary (JSON hydration)
static func from_dict(data: Dictionary) -> TacticsSpecialRule:
	var rule := TacticsSpecialRule.new()
	rule.rule_name = data.get("name", data.get("rule_name", ""))
	rule.description = data.get("description", "")
	rule.rule_value = data.get("value", data.get("rule_value", 0))
	rule.points_cost = data.get("points_cost", 0)

	var type_str: String = data.get("type", data.get("rule_type", "special"))
	rule.rule_type = _type_from_string(type_str)
	return rule


## Serialize to dictionary
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"name": rule_name,
		"type": RuleType.keys()[rule_type].to_lower(),
	}
	if not description.is_empty():
		data["description"] = description
	if rule_value > 0:
		data["value"] = rule_value
	if points_cost != 0:
		data["points_cost"] = points_cost
	return data


## Infer rule type from rule name (Tactics-specific)
static func _infer_rule_type(name: String) -> RuleType:
	var lower := name.to_lower()

	# Weapon traits (Tactics rulebook pp.38-42)
	if lower in [
		"area", "ammo choice", "burn", "clumsy", "crewed", "critical",
		"destructive", "elegant", "focused", "fog", "gas", "heavy",
		"indirect", "knock back", "launcher", "limited supply", "lock on",
		"melee", "minimum range", "overheat", "piercing", "pin-point",
		"pistol", "shock", "shrapnel", "snap shot", "sniping", "stream",
		"stun", "team", "weak",
	]:
		return RuleType.WEAPON

	# Morale rules
	if lower in ["determined", "disciplined", "fearsome", "fearless", "uncaring", "mindless assault"]:
		return RuleType.MORALE

	# Movement rules
	if lower in ["loping run", "winged", "wheeled", "tracked", "drifter", "walker"]:
		return RuleType.MOVEMENT

	# Defensive rules
	if lower in ["saving throw", "hardened network", "synthetic", "enviro-suits"]:
		return RuleType.DEFENSIVE

	return RuleType.SPECIAL


static func _type_from_string(type_str: String) -> RuleType:
	match type_str.to_lower():
		"weapon": return RuleType.WEAPON
		"species": return RuleType.SPECIES
		"veteran": return RuleType.VETERAN
		"combat": return RuleType.COMBAT
		"morale": return RuleType.MORALE
		"movement": return RuleType.MOVEMENT
		"defensive": return RuleType.DEFENSIVE
		_: return RuleType.SPECIAL
