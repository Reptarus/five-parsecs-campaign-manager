extends GdUnitTestSuite
## F9 regression — a DOWN figure in the Crew/Enemy tracker drawer collapses to a
## compact one-line ledger row (name + ☠ + 0/max), NOT a full CharacterStatusCard
## with Stun/Dmg/Aim/Snap/Mark-Down controls. Full-height cards for the dead
## inflated the drawer past the viewport, so the last LIVE enemy's Mark-Down
## button fell off the bottom with no way to touch-scroll to it on the tablet.
## Keeping the downed row control-free is what keeps a full roster + casualties
## inside the drawer viewport.

const TBUClass = preload("res://src/ui/screens/battle/TacticalBattleUI.gd")

class MockUnit:
	var node_name: String = "Gun Slingers Specialist"
	var max_health: int = 3
	var is_dead: bool = true

func _count_buttons(node: Node) -> int:
	var n: int = 1 if node is Button else 0
	for c in node.get_children():
		n += _count_buttons(c)
	return n

func _all_label_text(node: Node) -> String:
	var s: String = (node.text + " ") if node is Label else ""
	for c in node.get_children():
		s += _all_label_text(c)
	return s

func test_downed_row_has_no_interactive_controls() -> void:
	var tbu = TBUClass.new()
	auto_free(tbu)
	var row = tbu._build_downed_unit_row(MockUnit.new())
	auto_free(row)
	assert_object(row).is_not_null()
	# The whole point of the collapse: zero buttons on a defeated figure.
	assert_int(_count_buttons(row)).is_equal(0)

func test_downed_row_shows_name_and_status() -> void:
	var tbu = TBUClass.new()
	auto_free(tbu)
	var row = tbu._build_downed_unit_row(MockUnit.new())
	auto_free(row)
	var text: String = _all_label_text(row)
	assert_str(text).contains("Gun Slingers Specialist")
	assert_str(text).contains("DOWN")
	assert_str(text).contains("0/3")

func test_downed_row_is_a_panel_container() -> void:
	var tbu = TBUClass.new()
	auto_free(tbu)
	var row = tbu._build_downed_unit_row(MockUnit.new())
	auto_free(row)
	assert_bool(row is PanelContainer).is_true()
