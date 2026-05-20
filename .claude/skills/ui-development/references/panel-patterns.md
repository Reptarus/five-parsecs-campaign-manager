# Panel Patterns Reference

## BaseCampaignPanel (FiveParsecsCampaignPanel)
- **Path**: `src/ui/screens/campaign/panels/BaseCampaignPanel.gd`
- **extends**: Control
- **Auto-background**: `_ensure_base_background()` in `_ready()` injects a COLOR_BASE ColorRect behind all panels (added Mar 23 2026). BasePhasePanel has the same pattern via `_apply_phase_theme()`.
- **Background pattern**: ColorRect with `show_behind_parent = true`, `MOUSE_FILTER_IGNORE`, `PRESET_FULL_RECT`, named `"__panel_bg"` or `"__phase_bg"` to prevent duplicates.
- **class_name**: FiveParsecsCampaignPanel

## Signals
```
panel_data_changed(data: Dictionary)
panel_validation_changed(is_valid: bool)
panel_completed(data: Dictionary)
validation_failed(errors: Array[String])
panel_ready()
```

## Factory Methods (UI Component Creation)

### Cards & Containers
```gdscript
_create_section_card(title: String, content: Control, description: String = "", icon: String = "") -> PanelContainer
_create_section_header(title: String, icon: String = "") -> HBoxContainer
_create_progress_indicator(current_step: int, total_steps: int, step_title: String = "") -> Control
```

### Input Controls
```gdscript
_create_labeled_input(label_text: String, input: Control) -> VBoxContainer
_create_button_group_selector(options: Array, selected_index: int = 0) -> HBoxContainer
_create_add_button(text: String) -> Button
```

### Character & Stats
```gdscript
_create_stat_display(stat_name: String, value: Variant) -> PanelContainer
_create_stats_grid(stats: Dictionary, columns: int = 4) -> GridContainer
_create_stat_badge(stat_name: String, value: int, show_plus: bool = false) -> PanelContainer
_create_character_card(char_name: String, subtitle: String, stats: Dictionary = {}) -> PanelContainer
```

### Styling Methods
```gdscript
_style_line_edit(line_edit: LineEdit) -> void
_style_option_button(option_btn: OptionButton) -> void
_style_button(button: Button, is_primary: bool = false) -> void
_style_danger_button(button: Button) -> void
```

## Signal Pattern: Signal-Up, Call-Down

```
Parent (CampaignCreationUI)
  ↓ calls panel.set_panel_data(data)     # call DOWN
  ↑ panel.panel_completed.emit(data)     # signal UP
```

- Parent calls DOWN to child via direct method calls
- Child signals UP to parent via signals
- Never call parent methods from child

## Coordinator Integration

```gdscript
# Panel receives coordinator
func set_coordinator(coord) -> void
func set_state_manager(manager) -> void
func get_coordinator()
func get_state_manager()
func _on_coordinator_set() -> void   # virtual, override to react

# Panel syncs with coordinator
func sync_with_coordinator() -> void
func _on_campaign_state_updated(state_data: Dictionary) -> void
func _handle_campaign_state_update(state_data: Dictionary) -> void  # virtual
```

## Responsive Layout

```gdscript
# Query current mode
is_mobile_layout() -> bool
is_tablet_layout() -> bool
is_desktop_layout() -> bool
should_use_single_column() -> bool
get_optimal_column_count() -> int

# Responsive helpers
get_responsive_font_size(base_size: int) -> int
get_responsive_spacing(base_spacing: int) -> int
get_responsive_touch_target() -> int

# Virtual overrides for layout modes
_apply_mobile_layout() -> void
_apply_tablet_layout() -> void
_apply_desktop_layout() -> void
```

## Safe Node Access
```gdscript
safe_get_node(path: String, fallback_creation_func: Callable) -> Node
safe_get_child_node(parent: Node, child_name: String, fallback_creation_func: Callable) -> Node
create_basic_container(container_type: String) -> Control
```

## Validation Pattern
```gdscript
validate_panel() -> bool
get_validation_message() -> String
_validate_and_emit_completion() -> void
safe_validate_and_complete() -> void
```

## SlideOverDrawer — Reusable Slide-Over Widget

`src/ui/components/common/SlideOverDrawer.gd` (keeper widget, gdUnit 10/10).
Edge-anchored non-blocking drawer on a CanvasLayer (L92 in TacticalBattleUI).
ESC / scrim-tap closes; exclusivity is the host's responsibility (call
`close()` on the others before `open()`-ing one).

```gdscript
@export var edge: Edge = Edge.RIGHT      # LEFT / RIGHT / BOTTOM
@export var drawer_title: String = ""
@export var animate: bool = true         # false in tests for snap behavior
@export var min_panel_width: float = 0.0 # 0 = tight reading column (default)
```

**Width contract (LEFT/RIGHT):**
- `min_panel_width == 0` → tight reading column `clampf(vp.x * 0.26, 300, 380)`.
  Use for text/cheat-sheet drawers (Reference card).
- `min_panel_width > 0` → CONTENT-sized `minf(min_panel_width, vp.x * 0.5)`.
  Set to ~480 for drawers that host full component panels (unit-tracker
  cards with a 5-button action row, DiceDashboard, MoralePanicTracker,
  EnemyIntentPanel). **NEVER size a content panel as a viewport fraction**
  — `vp.x * 0.42` balloons to ~828px on a 1972px monitor (a half-screen
  takeover that defeats the "readable column, map stays visible" intent).
  Content widgets are content-sized; viewport sizing is for the chrome.

```gdscript
# Tight reading column (Reference card text)
_make_drawer("reference", "Battle Round Reference", DrawerClass.Edge.RIGHT)

# Wide drawer (full unit-tracker cards)
_make_drawer("crew", "Crew", DrawerClass.Edge.LEFT, true)   # wide=true → 480
```

**Drawer owns scrolling.** The internal `ScrollContainer` uses
`SCROLL_MODE_AUTO` horizontal (a wide production body like
`WeaponTableDisplay` ~420px min scrolls inside the column rather than
overhanging the viewport). Production bodies pass plain content — no
per-body `ScrollContainer` / vertical-expand. `_fit_panel_height()`
re-asserts the capped width/position after a late layout pass.

**`set_content()` replaces** — one content `Control` at a time. Previous
content is `remove_child` → `queue_free` then the new one is `add_child`'d.
This is the documented Godot 4.6 reparenting pattern (Context7-confirmed:
`class_packedscene.html` / `instancing_with_signals.html`).

**Host-side overflow guard for reused cards** (no edit to the shared
component): after `instantiate()` + `add_child`, set the card's text labels
to autowrap so long lines don't propagate width past the column cap:

```gdscript
for lbl_name in ["status_label", "stats_label"]:
    if lbl_name in card and card.get(lbl_name) is Label:
        var lbl: Label = card.get(lbl_name)
        lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        lbl.custom_minimum_size.x = 0.0
```
