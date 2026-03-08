# MCP Automated Testing Guide — Five Parsecs Campaign Manager

## Overview

The project has two MCP testing interfaces:
1. **Godot MCP Server** — External MCP tools (`mcp__godot__*`) that launch/control Godot
2. **MCP Bridge** (`mcp_bridge.gd`) — In-game UDP server for direct UI interaction

Both can be used together: Godot MCP launches the game, MCP Bridge provides fine-grained control.

---

## Godot MCP Server Tools

### run_project
Launch the game for testing.
```
Tool: mcp__godot__run_project
Parameters: {}  (uses project.godot in project root)
```
Wait 3-5 seconds after launch for scenes to load.

### stop_project
Stop the running game.
```
Tool: mcp__godot__stop_project
Parameters: {}
```

### take_screenshot
Capture current viewport.
```
Tool: mcp__godot__take_screenshot
Returns: { path: "absolute/path/to/screenshot.png" }
```
Use the Read tool to view the screenshot image.

### get_ui_elements
Discover all visible Control nodes.
```
Tool: mcp__godot__get_ui_elements
Returns: { elements: [{ name, type, path, rect: {x,y,width,height}, visible, text?, disabled?, tooltip? }] }
```
Extracts text from Button, Label, LineEdit, TextEdit, RichTextLabel. Shows `disabled` for BaseButton subclasses.

### simulate_input
Send input events to the game.
```
Tool: mcp__godot__simulate_input
Parameters: { actions: [...] }  // Array of action objects
```

Action types:
```json
// Key press
{"type": "key", "key": "Escape", "pressed": true, "shift": false, "ctrl": false}

// Mouse click at coordinates
{"type": "mouse_button", "button": "left", "x": 400, "y": 300}
// Auto press+release. Add "pressed": true for press-only

// Mouse move
{"type": "mouse_motion", "x": 400, "y": 300, "relative_x": 0, "relative_y": 0}

// Godot action (InputMap)
{"type": "action", "action": "ui_accept", "pressed": true}

// Click element by name (BFS search)
{"type": "click_element", "element": "ButtonName"}

// Wait (ms)
{"type": "wait", "ms": 500}
```

### run_script
Execute GDScript in-game. Script MUST define `func execute(scene_tree: SceneTree) -> Variant`.
```
Tool: mcp__godot__run_script
Parameters: { source: "extends RefCounted\nfunc execute(scene_tree: SceneTree) -> Variant:\n\treturn 42" }
```
Return value is serialized: primitives, Vectors, Colors, Dicts, Arrays, Nodes (class+name+path), Resources (class+path).

### get_debug_output
Read console output (prints, errors, warnings).
```
Tool: mcp__godot__get_debug_output
Returns: { output: "..." }
```

### manage_scene
Query or modify the scene tree.
```
Tool: mcp__godot__manage_scene
Parameters: { action: "get_tree" | "get_node", path: "/root/..." }
```

---

## MCP Bridge Commands (UDP Port 9900)

The bridge is accessed via the Godot MCP tools above (they communicate with the bridge internally). These are the JSON commands the bridge understands:

### screenshot
```json
{"command": "screenshot"}
→ {"path": "absolute/path/to/screenshot.png"}
```

### get_ui_elements
```json
{"command": "get_ui_elements", "visible_only": true, "type_filter": "Button"}
→ {"elements": [{name, type, path, rect, visible, text?, disabled?, tooltip?}]}
```
`type_filter` filters to a specific Godot class (e.g., "Button", "Label", "LineEdit").

### input
```json
{"command": "input", "actions": [
    {"type": "click_element", "element": "NewCampaignButton"},
    {"type": "wait", "ms": 500},
    {"type": "click_element", "element": "NextButton"}
]}
→ {"success": true, "actions_processed": 3}
```

### run_script
```json
{"command": "run_script", "source": "extends RefCounted\nfunc execute(scene_tree: SceneTree) -> Variant:\n\treturn scene_tree.root.get_node('/root/GameState').campaign != null"}
→ {"success": true, "result": true}
```

### ping
```json
{"command": "ping"}
→ {"status": "pong"}
```

---

## Known Limitations (from Sprint T-1)

| Issue | Workaround |
|-------|-----------|
| **Native Window popups invisible to screenshots** | Use custom PanelContainer popups instead of AcceptDialog |
| **Native AcceptDialogs not dismissable via input** | Use `run_script` to call `hide()` on the dialog |
| **`run_script` with `await` causes 30s timeout** | Never use `await` in execute(). Return synchronous data only |
| **`pressed.emit()` via run_script can crash** | Don't simulate button presses via emit(). Use `click_element` or coordinate clicks instead |
| **`click_element` reports "not visible" incorrectly** | Use coordinate-based `mouse_button` click as fallback |
| **Headless mode: no viewport** | Always run with UI (not --headless) for MCP testing |

---

## Test Recipes

### Recipe 1: Smoke Test (Launch + Verify MainMenu)

```
1. mcp__godot__run_project
2. Wait 3s
3. mcp__godot__take_screenshot  → Verify MainMenu visible
4. mcp__godot__get_ui_elements  → Verify buttons: "New Campaign", "Load Campaign", "Continue Campaign", "Options", "Library"
5. mcp__godot__get_debug_output → Check for ERROR-level messages
6. mcp__godot__stop_project
```

### Recipe 2: Navigate to Campaign Creation

```
1. Launch game (Recipe 1 steps 1-2)
2. mcp__godot__simulate_input:
   {"actions": [{"type": "click_element", "element": "NewCampaignButton"}]}
3. Wait 1s
4. mcp__godot__take_screenshot  → Verify creation Step 1 visible
5. mcp__godot__get_ui_elements  → Verify config panel elements
```

### Recipe 3: Read Game State

```
mcp__godot__run_script:
source: |
  extends RefCounted
  func execute(scene_tree: SceneTree) -> Variant:
      var gs = scene_tree.root.get_node_or_null("/root/GameState")
      if not gs:
          return {"error": "GameState not loaded"}
      var campaign = gs.campaign if "campaign" in gs else null
      if not campaign:
          return {"has_campaign": false}
      return {
          "has_campaign": true,
          "campaign_name": campaign.campaign_name if "campaign_name" in campaign else "unknown",
          "turn_number": campaign.progress_data.get("turn_number", 0) if "progress_data" in campaign else 0
      }
```

### Recipe 4: Set Text Field Value

Don't use key simulation for text input — it's unreliable. Instead:

```
mcp__godot__run_script:
source: |
  extends RefCounted
  func execute(scene_tree: SceneTree) -> Variant:
      var root = scene_tree.root
      var field = _find_line_edit(root, "CampaignNameInput")
      if field:
          field.text = "Test Campaign Alpha"
          field.text_changed.emit("Test Campaign Alpha")
          return {"success": true}
      return {"error": "Field not found"}

  func _find_line_edit(node: Node, target_name: String) -> LineEdit:
      if node is LineEdit and String(node.name) == target_name:
          return node as LineEdit
      for child in node.get_children():
          var found = _find_line_edit(child, target_name)
          if found:
              return found
      return null
```

### Recipe 5: Verify UI Element Properties

```
mcp__godot__run_script:
source: |
  extends RefCounted
  func execute(scene_tree: SceneTree) -> Variant:
      var results = []
      var root = scene_tree.root
      _check_controls(root, results)
      return {"issues": results, "total_checked": results.size()}

  func _check_controls(node: Node, results: Array) -> void:
      if node is Button and node.is_visible_in_tree():
          var rect = node.get_global_rect()
          if rect.size.y < 48:
              results.append({
                  "node": str(node.name),
                  "issue": "touch_target_too_small",
                  "height": rect.size.y
              })
      for child in node.get_children():
          _check_controls(child, results)
```

### Recipe 6: Check Console for Errors

```
1. mcp__godot__get_debug_output
2. Parse output for lines containing "ERROR", "SCRIPT ERROR", "PUSH_ERROR"
3. Filter out known non-blocking warnings (orphan signals, etc.)
4. Report any genuine errors
```

### Recipe 7: Navigate Full Campaign Creation (Happy Path)

```
1. Launch + Navigate to creation (Recipes 1-2)
2. Step 1 CONFIG:
   - Set campaign name (Recipe 4)
   - Click "NextButton" or equivalent
3. Step 2 CAPTAIN:
   - get_ui_elements → find captain creation elements
   - Use defaults or set specific values
   - Click Next
4. Steps 3-6: Similar pattern
   - get_ui_elements on each panel
   - Set required fields
   - Click Next
5. Step 7 FINAL:
   - take_screenshot → verify review shows all data
   - Click "Create" / "Finish"
6. Verify redirect to campaign_turn_controller
7. take_screenshot → verify dashboard/turn controller loaded
```

---

## Element Name Discovery

Before clicking any element, ALWAYS run `get_ui_elements` first to discover correct node names. Button names in the scene tree may differ from their display text.

Common patterns:
- Buttons often named: `NewCampaignButton`, `NextButton`, `BackButton`, `SaveButton`
- Panels named: `ConfigPanel`, `CaptainPanel`, `CrewPanel`
- Labels named: `TitleLabel`, `CreditsLabel`, `PhaseLabel`

If `click_element` fails with "not visible", fall back to coordinate-based clicking:
1. Get element rect from `get_ui_elements`
2. Calculate center: `x = rect.x + rect.width/2`, `y = rect.y + rect.height/2`
3. Use `mouse_button` action with those coordinates

---

## Best Practices

1. **Always `get_ui_elements` before `click_element`** — node names can change between builds
2. **Use `run_script` for data inspection only** — don't trigger UI actions or complex logic
3. **Wait after navigation** — `{"type": "wait", "ms": 500}` after clicking navigation buttons
4. **Screenshot before and after** — take screenshots before and after actions for comparison
5. **Check debug output regularly** — errors may not be visible in the UI
6. **Don't chain too many actions** — break into smaller action arrays for reliability
7. **Coordinate clicks as fallback** — when `click_element` fails, use `mouse_button` at center of rect
