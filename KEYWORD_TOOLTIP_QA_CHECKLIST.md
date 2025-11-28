# KeywordTooltip System - QA & Integration Checklist

## Pre-Integration Verification

### Autoload Registration
- [x] KeywordDB added to project.godot autoloads (already existed)
- [x] KeywordTooltip added to project.godot autoloads (line 37)
- [ ] Run project and verify no autoload errors in console
- [ ] Check console for "KeywordDB: Initialized with 10 keywords, 0 bookmarks"
- [ ] Check console for "KeywordTooltip: System initialized"

### File Integrity
- [x] src/qol/KeywordDB.gd (229 lines) - Upgraded from stub
- [x] src/ui/components/tooltips/KeywordTooltip.gd (220 lines) - Created
- [x] src/ui/components/tooltips/EquipmentFormatter.gd (208 lines) - Created
- [x] src/ui/components/tooltips/IMPLEMENTATION_NOTES.md (393 lines) - Created
- [x] src/ui/components/tooltips/INTEGRATION_EXAMPLE.gd (185 lines) - Created
- [x] .uid files created for new scripts

## Functional Testing

### Keyword Database
- [ ] Run: `print(KeywordDB.get_keyword("Assault"))` in console
  - Expected: `{term: "Assault", definition: "Can be fired without penalty...", ...}`
- [ ] Run: `print(KeywordDB.get_all_keywords())`
  - Expected: Array with 10 keywords
- [ ] Run: `print(KeywordDB.get_keywords_by_category("weapon_trait"))`
  - Expected: 7 weapon trait keywords

### Tooltip Display
- [ ] Create test RichTextLabel with keyword BBCode
- [ ] Click keyword link
- [ ] Verify AcceptDialog appears centered on screen
- [ ] Verify tooltip contains:
  - [ ] Term name (e.g., "Assault")
  - [ ] Definition text
  - [ ] Related terms (if any)
  - [ ] Rule page reference (if > 0)
  - [ ] Bookmark button (☆ or ★)
  - [ ] Close button

### Bookmark Functionality
- [ ] Click bookmark button in tooltip (☆ → ★)
- [ ] Verify console: "KeywordDB: Added bookmark for 'Assault'"
- [ ] Close tooltip and reopen same keyword
- [ ] Verify bookmark button shows ★ (bookmarked state)
- [ ] Click bookmark button again (★ → ☆)
- [ ] Verify console: "KeywordDB: Removed bookmark for 'Assault'"
- [ ] Close and restart Godot project
- [ ] Verify bookmarks persist (check user://keyword_bookmarks.json)

### Static Formatting Methods
- [ ] Test: `KeywordTooltip.format_equipment_with_keywords("Laser", ["Assault", "Bulky"])`
  - Expected: `"Laser ([url=keyword:Assault]Assault[/url], [url=keyword:Bulky]Bulky[/url])"`
- [ ] Test: `KeywordTooltip.format_equipment_with_keywords("Pistol", [])`
  - Expected: `"Pistol"` (no traits)
- [ ] Test: `EquipmentFormatter.extract_traits(equipment_resource)`
  - Verify extracts traits array correctly

## Integration Testing

### Screen Integration Pattern
- [ ] Choose test screen (e.g., CharacterDetailsScreen or EquipmentPanel)
- [ ] Replace Label with RichTextLabel
- [ ] Set `bbcode_enabled = true`
- [ ] Use `KeywordTooltip.format_equipment_with_keywords()` for text
- [ ] Connect `meta_clicked` signal
- [ ] Test keyword clicks show tooltips

### Example Integration Code
```gdscript
var rich_label = RichTextLabel.new()
rich_label.bbcode_enabled = true
rich_label.text = KeywordTooltip.format_equipment_with_keywords(
    "Infantry Laser", 
    ["Assault", "Bulky"]
)
rich_label.meta_clicked.connect(func(meta):
    if meta is String and meta.begins_with("keyword:"):
        KeywordTooltip.show_tooltip(meta.substr(8))
)
```

### Screens to Integrate
- [ ] CharacterDetailsScreen (equipment list)
- [ ] EquipmentPanel (campaign wizard)
- [ ] CrewManagementScreen (character equipment)
- [ ] WorldPhaseController (shop items with traits)
- [ ] BattleCompanionUI (weapon traits in combat)

## Mobile Testing (Critical)

### Touch Target Verification
- [ ] Test on mobile device or mobile simulator
- [ ] Verify keyword links tappable (≥48dp touch area)
- [ ] Verify bookmark button ≥48dp high
- [ ] Verify AcceptDialog close button tappable

### Responsive Behavior
- [ ] Test portrait orientation (phone)
- [ ] Test landscape orientation (tablet)
- [ ] Verify tooltip auto-centers on all screen sizes
- [ ] Verify text wraps correctly in narrow screens
- [ ] Verify no horizontal scrolling in tooltip

### Performance
- [ ] Test rapid keyword tapping (no lag)
- [ ] Test multiple tooltips in sequence
- [ ] Verify 60fps maintained (F3 to show FPS)
- [ ] Check memory usage (should be minimal)

## Edge Case Testing

### Unknown Keywords
- [ ] Test: `KeywordTooltip.show_tooltip("NonexistentTrait")`
  - Expected: Tooltip shows "Unknown term" definition
  - Should not crash or error

### Empty Trait Arrays
- [ ] Test: `format_equipment_with_keywords("Item", [])`
  - Expected: Returns "Item" (no parentheses)

### Long Definitions
- [ ] Create keyword with 200+ character definition
- [ ] Verify text wraps (autowrap_mode enabled)
- [ ] Verify tooltip doesn't exceed screen bounds

### Rapid Interactions
- [ ] Click 10 keywords rapidly
- [ ] Verify no duplicate dialogs
- [ ] Verify no memory leaks (each dialog clears previous content)

### Case Sensitivity
- [ ] Test: `KeywordDB.get_keyword("ASSAULT")` (uppercase)
  - Expected: Returns same data as "assault" (case-insensitive)
- [ ] Test: `KeywordDB.get_keyword("  Assault  ")` (spaces)
  - Expected: Returns data (strip_edges() applied)

## Regression Testing

### Existing Screens
- [ ] Run all existing screens without integration
- [ ] Verify no errors from KeywordTooltip/KeywordDB autoloads
- [ ] Verify existing equipment displays still work (plain text)

### Save/Load System
- [ ] Create campaign, bookmark 3 keywords
- [ ] Save game
- [ ] Load game
- [ ] Verify bookmarks persist

## Performance Benchmarks

### Target Metrics (60fps = 16.67ms/frame)
- [ ] Tooltip display: <16ms ✅ (Expected: ~5ms)
- [ ] Keyword lookup: <1ms ✅ (Hash lookup)
- [ ] Dialog creation: <10ms ✅ (Cached instance)
- [ ] BBCode parsing: N/A (Engine-optimized)

### Memory Usage
- [ ] Initial load: Record memory baseline
- [ ] Open 20 tooltips
- [ ] Close all tooltips
- [ ] Record memory after
- [ ] Verify memory returns to baseline (no leaks)

## Documentation Verification

### Implementation Notes
- [ ] Read IMPLEMENTATION_NOTES.md completely
- [ ] Verify all code examples are syntactically correct
- [ ] Test each usage example in isolation
- [ ] Verify troubleshooting section addresses actual errors

### Integration Example
- [ ] Copy INTEGRATION_EXAMPLE.gd code into test scene
- [ ] Verify all methods compile without errors
- [ ] Test each integration pattern works as described

## Accessibility Testing

### Keyboard Navigation
- [ ] Tab to keyword link
- [ ] Press Enter to open tooltip
- [ ] Escape to close tooltip
- [ ] Verify keyboard-only navigation works

### Screen Reader Compatibility
- [ ] Test with screen reader (if available)
- [ ] Verify keyword links announced correctly
- [ ] Verify tooltip content readable

## Production Readiness Checklist

### Code Quality
- [x] All variables statically typed
- [x] All functions have type hints
- [x] Signal architecture follows "call down, signal up"
- [x] Design system constants used (SPACING_*, FONT_SIZE_*, COLOR_*)
- [x] Touch targets ≥48dp (TOUCH_TARGET_MIN)
- [x] No @onready in static/autoload classes
- [x] No get_parent() calls

### Performance
- [x] Dialog reuse (single instance)
- [x] Hash-based keyword lookup (O(1))
- [x] No unnecessary allocations in hot paths
- [x] AcceptDialog auto-centering (no position calculations)

### Error Handling
- [x] Unknown keywords handled gracefully
- [x] Missing equipment fields handled
- [x] File I/O errors caught (bookmark persistence)
- [x] Null checks in EquipmentFormatter

### Documentation
- [x] Implementation guide complete
- [x] Usage examples provided
- [x] Migration path documented
- [x] Troubleshooting guide included

## Known Issues / Limitations

### Documented Limitations
- [x] ItemList incompatibility documented
- [x] RichTextLabel requirement documented
- [x] BBCode requirement documented
- [x] Workarounds provided for each limitation

### Future Enhancements (Not Blocking)
- [ ] Load keywords from JSON (data file integration)
- [ ] Keyword search UI
- [ ] Bookmark management screen
- [ ] Rich tooltip content (images, tables)
- [ ] Keyword history tracking

## Sign-Off

### Developer Sign-Off
- [ ] Code review completed
- [ ] All tests pass
- [ ] Documentation accurate
- [ ] No breaking changes to existing code
- [ ] Ready for QA testing

**Developer**: Claude Code (AI Assistant)
**Date**: 2025-11-28

### QA Sign-Off
- [ ] Functional testing passed
- [ ] Mobile testing passed
- [ ] Regression testing passed
- [ ] Performance benchmarks met
- [ ] Ready for integration

**QA Tester**: _______________
**Date**: _______________

### Integration Sign-Off
- [ ] Integrated into target screens
- [ ] User acceptance testing passed
- [ ] Production deployment checklist completed
- [ ] Ready for production

**Integrator**: _______________
**Date**: _______________

---

## Quick Test Script

Run this in Godot console to verify basic functionality:

```gdscript
# Test KeywordDB
print("=== KeywordDB Test ===")
print(KeywordDB.get_keyword("Assault"))
print("Keywords:", KeywordDB.get_all_keywords().size())

# Test bookmark
KeywordDB.toggle_bookmark("Assault")
print("Bookmarked:", KeywordDB.is_bookmarked("Assault"))

# Test formatting
print("\n=== Formatting Test ===")
var formatted = KeywordTooltip.format_equipment_with_keywords(
    "Infantry Laser", 
    ["Assault", "Bulky"]
)
print(formatted)

# Test tooltip (must be in-game, not console)
print("\n=== Tooltip Test (in-game) ===")
print("Run: KeywordTooltip.show_tooltip('Assault')")
```

## Status

**Current Phase**: Implementation Complete ✅
**Next Phase**: QA Testing & Integration ⏳
**Target Release**: TBD
