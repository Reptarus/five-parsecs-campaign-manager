# 🧹 Clean gdUnit4 Integration Plan

## 📋 Phase 1: Verify Stability
- [ ] Test Godot startup (should work now)
- [ ] Verify main scene loads
- [ ] Check autoloads initialize properly
- [ ] Confirm no memory leaks

## 📋 Phase 2: Remove GUT Cleanly
```bash
# 1. Disable GUT plugin
# Edit project.godot: Remove "res://addons/gut/plugin.cfg"

# 2. Remove GUT configuration
# Remove [gut] section from project.godot

# 3. Remove GUT test scene reference
# Remove debug/settings/run_on_load/test_scene
```

## 📋 Phase 3: Install gdUnit4 Fresh
```bash
# 1. Download gdUnit4 from Asset Library
# 2. Enable gdUnit4 plugin only
# 3. Verify no conflicts
```

## 📋 Phase 4: Create Base Test Infrastructure
Copy our proven base classes:
- `tests/fixtures/base/gdunit_base_test.gd`
- `tests/fixtures/base/gdunit_game_test.gd`
- `tests/examples/gdunit4_example_test.gd`

## 📋 Phase 5: Gradual Migration
**Start Small** (5-10 files):
1. Simple unit tests (data classes)
2. Utility function tests
3. Basic component tests

**Expand Gradually**:
1. UI component tests
2. System integration tests
3. Complex battle system tests

## 📋 Phase 6: @tool Cleanup (Optional)
If needed, systematically review @tool usage:
- Keep only for editor-specific functionality
- Remove from autoloads unless absolutely necessary
- Remove from game logic classes

## 🎯 Success Criteria
- [ ] Godot starts without errors
- [ ] gdUnit4 tests run successfully
- [ ] No memory leaks
- [ ] No HTTP request errors
- [ ] Stable test execution

## 🚨 Safety Measures
- Commit after each phase
- Test thoroughly before proceeding
- Keep rollback option available
- Document any issues encountered

---

**Current Status**: Ready for Phase 1 testing 