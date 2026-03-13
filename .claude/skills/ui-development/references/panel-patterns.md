# Panel Patterns Reference

## BaseCampaignPanel (FiveParsecsCampaignPanel)
- **Path**: `src/ui/screens/campaign/panels/BaseCampaignPanel.gd`
- **extends**: Control
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
