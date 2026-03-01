## Test Helper: Mock Campaign Data
## Simulates campaign data resource for testing UpkeepSystem
## Plain class (no Node inheritance) to avoid lifecycle issues in tests
## GDScript 2.0 compatible - replaces dynamic GDScript.new() pattern

class_name MockCampaignData
extends Resource

# Campaign properties - use untyped Array for compatibility
var crew_members: Array = []
var ship_data = null
var living_standard: String = "normal"
var credits: int = 100
var ship_debt: int = 0

# Standard API method for UpkeepSystem compatibility
func get_crew_members() -> Array:
	"""Return crew members array"""
	return crew_members

# Reset to default values for test isolation
func reset() -> void:
	"""Reset all properties to defaults"""
	crew_members.clear()
	ship_data = null
	living_standard = "normal"
	credits = 100
	ship_debt = 0
