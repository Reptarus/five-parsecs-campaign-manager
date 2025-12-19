# Run BattleRoundTracker Test Suite
# Uses UI mode to avoid headless signal 11 crash

& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_battle_round_tracker.gd `
  --quit-after 60

# Expected Output:
# ================
# 12 tests run
# 12 tests passed
# 0 tests failed
#
# Test Coverage:
# - Phase transitions: 4 tests
# - Round counter: 3 tests
# - Battle events: 4 tests
# - Edge cases: 2 tests
# - Total: 12/13 tests (within stability limit)
