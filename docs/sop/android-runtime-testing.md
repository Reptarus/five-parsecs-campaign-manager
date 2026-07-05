# Android Runtime Testing SOP

**Platform**: Android (launch platform)
**Covers**: MCP window-resize simulation (Windows) AND on-device ADB testing
**Created**: 2026-06-22
**Read together with**:
- `docs/sop/responsive-adaptive-ui.md` — architecture, DIP math, ResponsiveManager contract
- `docs/sop/visual-runtime-verification.md` — MCP injection patterns, screenshot evidence rules
- `docs/testing/QA_INTEGRATION_SCENARIOS.md` — integration scenario templates (Appendix A)

---

## Why This Exists

Android is the launch platform. The responsive architecture (ResponsiveManager, AdaptivePanelGroup,
square 1080x1080 viewport base) was designed and MCP-verified on Windows/desktop. Android
introduces three failure modes that desktop testing misses:

- **Real DIP math**: `DisplayServer.screen_get_scale()` = 1.0 on Windows; 2.0-3.5 on Android.
  ResponsiveManager's DIP classification only fires at real device density on-device.
- **Safe-area insets**: notch, status bar, nav bar are zero on desktop.
  `CampaignScreenBase.get_safe_area_insets()` returns real values on-device only.
- **Touch physics**: a button that passes headless size checks may still be too small to hit
  reliably with a finger. The 48dp design-minimum must hold under fat-finger conditions.

The headline rule mirrors `visual-runtime-verification.md`:
**headless compile clean and unit tests are not sufficient for Android layout verification.**

---

## Two-Tier Strategy

| Tier | When | Tools | Catches |
|---|---|---|---|
| **T1: MCP Simulation** | Every responsive UI change; every PR touching layout | MCP + `window_set_size` + `run_script` + `take_screenshot` | Column count, layout collapse, h-overflow, text clipping, design-px touch targets |
| **T2: On-Device** | Pre-APK-distribution gate; new screens; safe-area work | Physical Android device + ADB + logcat | Real DPI, safe-area insets, system UI overlap, touch tap miss-rate, rotation lock, performance |

**Alpha integration**:
- Alpha-1 (A0/A1 gate, Windows cohort): T1 only is sufficient.
- Any Android APK distribution (A2 or later): T2 required before the first APK goes out.
- Every responsive UI PR: T1 minimum (5-minute check, no device needed).

---

## T1: MCP Window-Resize Simulation

### DIP math on Windows

On Windows, `DisplayServer.screen_get_scale()` returns `1.0`, so window pixels = DIP directly.
Setting `window_set_size(Vector2i(360, 640))` simulates a 360dp x 640dp Android phone.

**ResponsiveManager breakpoints** (`src/autoload/ResponsiveManager.gd`):

| DIP width | Breakpoint constant | Portrait `get_effective_columns()` | Landscape `get_effective_columns()` |
|---|---|---|---|
| < 480 | `Breakpoint.MOBILE` | 1 | 1 |
| 480 - 767 | `Breakpoint.TABLET` | 1 | 2 |
| 768 - 1023 | `Breakpoint.DESKTOP` | 1 | 3 |
| >= 1024 | `Breakpoint.WIDE` | 1 | 4 |

Portrait is **always 1 column** regardless of DIP width — this is the `get_effective_columns()`
contract (`is_portrait()` short-circuits before the width ladder).

### Standard test matrix

| Window size (px = DIP on Windows) | Simulates | Expected breakpoint | Expected columns |
|---|---|---|---|
| `360 x 640` | 360dp phone portrait — design floor | MOBILE | 1 |
| `540 x 960` | 540dp phone portrait | TABLET | 1 |
| `960 x 540` | 960dp landscape — triggers breakpoint change (TABLET→DESKTOP) AND orientation change | DESKTOP | 3 |
| `480 x 700` | 480dp portrait — constant-bucket rotation baseline | TABLET | 1 |
| `700 x 480` | 700dp landscape — same TABLET bucket, only orientation changes | TABLET | 2 |
| `768 x 1024` | 768dp tablet portrait | DESKTOP | 1 |
| `1024 x 768` | 1024dp landscape (WIDE bucket: 1024dp is NOT < 1024) | WIDE | 4 |
| `1280 x 720` | Desktop baseline | WIDE | 4 |

### Step-by-step procedure

#### Step 1 — Disable TransitionOverlay

The `TransitionManager` overlay (full-screen ColorRect) blocks screenshots during transitions.
Run this once per MCP session before any other scripts:

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var tm = scene_tree.root.get_node_or_null("/root/TransitionManager")
    if tm:
        var overlay = tm.get_node_or_null("TransitionOverlay")
        if overlay:
            overlay.visible = false
    return {"ok": true}
```

#### Step 2 — Resize the window

`window_set_size` is **async**. Do NOT read ResponsiveManager state in the same `run_script` call
that sets the size. Always use a separate call (Step 3).

```gdscript
# Example: phone portrait
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    DisplayServer.window_set_size(Vector2i(360, 640))
    return {"queued": true}
```

#### Step 3 — Read state (separate run_script call, AFTER Step 2)

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var rm = scene_tree.root.get_node_or_null("/root/ResponsiveManager")
    if not rm:
        return {"error": "ResponsiveManager not found"}
    return {
        "window_size": str(DisplayServer.window_get_size()),
        "screen_scale": DisplayServer.screen_get_scale(),
        "dip": str(Vector2(DisplayServer.window_get_size()) / DisplayServer.screen_get_scale()),
        "breakpoint": rm.current_breakpoint,
        "is_landscape": rm.is_landscape,
        "effective_columns": rm.get_effective_columns(),
        "should_collapse": rm.should_collapse_to_single_column()
    }
```

Verify `effective_columns` and `breakpoint` match the expected values from the test matrix before
taking the screenshot. If they don't match, the window resize hasn't propagated — wait and call
Step 3 again.

#### Step 4 — Take screenshot

```
mcp__godot__take_screenshot
```

#### Step 5 — Rotation test (constant-bucket orientation change)

`breakpoint_changed` does NOT fire when rotating within the same DIP width bucket.
`layout_class_changed` DOES fire (it covers both bucket changes and orientation changes).
Adaptive screens that connect only to `breakpoint_changed` will miss this rotation.

Use a pair where BOTH orientations land in the same bucket. TABLET spans 480-767dp, so:

```gdscript
# Portrait: width=480dp → TABLET
DisplayServer.window_set_size(Vector2i(480, 700))
```
```gdscript
# Landscape: width=700dp → still TABLET (700 < 768)
DisplayServer.window_set_size(Vector2i(700, 480))
```

Read state after each. Expect: `is_landscape` flips, `effective_columns` changes 1 -> 2,
`breakpoint` (TABLET) stays the same. That proves `layout_class_changed` fired but
`breakpoint_changed` did not.

Note: 540x960 -> 960x540 is NOT a constant-bucket rotation. 540dp (TABLET) and 960dp (DESKTOP)
are different buckets, so BOTH `breakpoint_changed` AND `layout_class_changed` fire. It is
still a useful test for verifying column count after a cross-bucket rotation, but it does not
isolate the `layout_class_changed`-only case.

---

### What to check at each size

**360 x 640 (design floor — every screen must pass this)**:
- All screens render 1 column — no side-by-side panes
- No horizontal overflow or scrollbar (except intentional h-scroll in battle log or enemy list)
- All buttons and interactive elements visible without excessive scrolling
- Text not char-wrapping to single-character columns (autowrap-beside-wide-sibling trap —
  see `feedback_autowrap_in_hflow_trap.md`)
- Touch targets: every interactive element visually occupies >= ~5% of the 640dp screen height
  (48dp / 640dp = 7.5% — if a button looks noticeably shorter, measure it)

**960 x 540 (DESKTOP landscape)**:
- AdaptivePanelGroup screens show 3 columns (not stacked)
- Crew panel / mission panel grid shows correct density

**1024 x 768 (WIDE landscape)**:
- 4-column layouts active (WIDE bucket returns 4 from `get_optimal_columns()`).
  Note: `BREAKPOINTS[Breakpoint.WIDE] = 1440` is defined in the dict but is NEVER USED
  in `_classify_breakpoint()` -- the ladder checks `< ULTRAWIDE (2560)` as the WIDE ceiling,
  so the effective WIDE bucket is 1024-2559dp, not 1024-1439dp.
  At exactly 1024dp: `1024 < 1024` is false (not DESKTOP), `1024 < 2560` is true -> WIDE.
- Max-form-width cap (800 from `BaseCampaignPanel.MAX_FORM_WIDTH`) centers content on wide screens

**1280 x 720 (WIDE landscape)**:
- 4-column layouts active where used
- Max-form-width cap still constrains narrow forms

**Constant-bucket rotation 480x700 -> 700x480 (both TABLET)**:
- Layout re-builds without crash at both sizes
- No orphaned or mis-parented panels (AdaptivePanelGroup reparents panes ONCE — if rotation
  fires a second time it should be idempotent)
- `breakpoint` stays TABLET; only `is_landscape` and `effective_columns` change

---

## T2: On-Device Testing

### Prerequisites

1. **Android export template** installed: `Editor -> Manage Export Templates -> Download` (Android Debug)
2. **JDK 17** installed and set in `Editor Settings -> Export -> Android -> Java SDK Path`
3. **Android SDK**: `Editor Settings -> Export -> Android -> Android SDK Path`. On this machine: `C:\Users\admin\Documents\Android\Sdk`. ADB is at `<sdk_path>\platform-tools\adb.exe` — it is NOT on the system PATH, so Method B must use the full path (see below).
4. **Export preset**: "fiveparsecsfromhometest" in `export_presets.cfg`. Debug keystore at `C:\Users\admin\Documents\Android\debug.keystore` (configured). Method A (one-click) uses the debug template automatically. Method B: choose **"Export With Debug"** (not "Export Project") to preserve GDScript stack traces in logcat.
5. **USB debugging** enabled on the device: `Settings -> Developer Options -> USB debugging`

### Method A: One-Click Deploy (preferred — fastest, debugger attached automatically)

With an Android device connected via USB and USB debugging enabled, Godot shows an Android icon
in the top-right corner of the editor. Clicking it builds, installs, and launches the game on
the connected device in one action, with the **remote debugger attached** — GDScript stack
traces, `print()` output, and runtime errors appear live in the editor's `Debugger` panel
(bottom dock).

This is faster than the manual ADB path and gives you the full Godot remote debugger experience
(see "Remote Debugger Profiling" below).

**Known issue (Godot 4.3+)**: The game may install and launch correctly but the remote debugger
fails to attach (the Debugger panel stays empty). This is a known engine bug tracked at
[godotengine/godot#96524](https://github.com/godotengine/godot/issues/96524). If it happens,
fall back to Method B (ADB logcat) for error visibility.

### Method B: Manual ADB Install + Logcat (fallback)

```powershell
# ADB is NOT on the system PATH — use the full path.
# Get the SDK path from: Godot Editor -> Editor Settings -> Export -> Android -> Android SDK Path
# On this machine: C:\Users\admin\Documents\Android\Sdk
$adb = "C:\Users\admin\Documents\Android\Sdk\platform-tools\adb.exe"

# Step 1: Export APK via Godot Editor
# Project -> Export -> Android -> "Export With Debug" (NOT "Export Project" — that uses release template)
# Preset is "fiveparsecsfromhometest"; export_path in export_presets.cfg is ".\FiveParsecsTest03.apk" (project root)

# Step 2: Install (use -r to replace existing)
& $adb install -r ".\FiveParsecsTest03.apk"

# Step 3: Launch (or tap the app icon on device)
& $adb shell am start -n "com.reptarus.fiveparsecs/com.godot.game.GodotAppLauncher"

# Step 4: Stream logcat -- include AndroidRuntime for native crashes too
& $adb logcat -s "Godot:*" "AndroidRuntime:*"

# Filter for errors + native fatal exceptions (PowerShell)
& $adb logcat -s "Godot:*" "AndroidRuntime:*" | Select-String "ERROR|SCRIPT ERROR|FATAL EXCEPTION"
```

**Logcat tag guide**:
- `Godot:*` — all GDScript `push_error()`, `print()`, and runtime SCRIPT ERROR lines
- `AndroidRuntime:*` — native Java layer crashes (`FATAL EXCEPTION`, ANR, JNI errors)
- `FATAL EXCEPTION` — signals a hard crash; always investigate these first

### Remote Debugger Profiling (Method A only — requires debugger attached)

Once the remote debugger is attached via one-click deploy, the editor's `Debugger` panel shows
live on-device data without touching the device:

| Panel tab | What to watch | Threshold |
|---|---|---|
| **Monitor -> FPS** | Frames per second while navigating | 60 fps target; below 30 fps is unacceptable |
| **Monitor -> Frame Time** | ms per frame | Under 16.6ms (60fps); spikes above 50ms cause visible hitches |
| **Monitor -> Draw Calls** | Renderer calls per frame | Under 200 = safe; 200-500 = borderline; over 500 will thermal-throttle on budget chips |
| **Monitor -> Video Memory** | GPU memory usage | Watch for continuous growth (leak) |
| **Profiler** | GDScript function time breakdown | Identify which function is causing a spike |

Run the profiler on these sequences:
- Campaign Dashboard initial load (most complex screen)
- World Phase step-through (signal-heavy)
- CampaignCreationUI 7-step wizard (many panel instantiations)
- Rotation from portrait to landscape (AdaptivePanelGroup reparent pass)

### What Android reveals that MCP simulation misses

| Failure mode | Why MCP misses it |
|---|---|
| Real `screen_get_scale()` values (2.0-3.5) | Windows returns 1.0 — DIP math is untested at real density |
| Safe-area insets (notch, status bar, nav bar) | `get_safe_area_insets()` returns zeros on desktop |
| Navigation bar overlap on bottom buttons | Nav bar occludes content; MarginContainer safe-area padding is only meaningful on-device |
| Touch tap miss-rate | Cursor is always precise; fingers have ~10mm contact area |
| Virtual keyboard overlap | Doesn't exist on desktop; can push layout or obscure inputs |
| Rotation lock behavior | SENSOR orientation mode (handheld/orientation=6) requires physical rotation |
| Memory pressure | Android OS may kill background processes; cold-launch rehydration from `user://` must work |
| Logcat-level errors | `push_error()` reaches logcat; some classes of error are silent on desktop |

### On-device checklist (required before any APK distribution)

Run on a clean install (uninstall first to clear `user://` state):

- [ ] Cold launch: app opens to MainMenu, zero `SCRIPT ERROR` lines in logcat
- [ ] First-run EULA -> consent flow renders correctly; all buttons tappable first-try
- [ ] Safe area: content not obscured by status bar (top), notch, or nav bar (bottom)
- [ ] Portrait: all screens 1 column, no horizontal overflow
- [ ] Landscape: rotation triggers re-layout; multi-column where expected
- [ ] Touch targets: every button on MainMenu, campaign creation, and dashboard is tappable
  first-try with thumb (no miss requiring second tap)
- [ ] Campaign creation wizard: 7 steps complete without crash
- [ ] Save: `user://saves/` writes correctly; no FileAccess errors in logcat
- [ ] Load: reload saved campaign; state matches what was saved
- [ ] System back button: navigates back correctly; does not force-quit from inside a screen
- [ ] Virtual keyboard: any text input (e.g. campaign name) shows keyboard without obscuring
  the input field
- [ ] Logcat clean: zero `SCRIPT ERROR` lines after a 5-minute session

### Physical device targets

| Priority | Device class | Target DIP width | Why |
|---|---|---|---|
| P0 | 360dp phone (Pixel 3a, Galaxy A-series) | 360 DIP | Design floor; most common Android DIP width |
| P1 | 393dp phone (Pixel 5/6, Galaxy S21/22) | 393 DIP | Most common current flagship |
| P2 | 600dp+ tablet (any 7-10 inch Android tablet) | 600-800 DIP | Second major Android form factor |

Android Studio emulator is acceptable for pre-device smoke checks, but `screen_get_scale()` may
not return the correct hardware density. Always confirm with a real device before any APK
distribution.

---

## MCP Quick-Start for This Session

Run these in order to start an Android simulation session:

1. `mcp__godot__launch_editor` (imports any new assets)
2. `mcp__godot__run_project`
3. Disable TransitionOverlay (Script above)
4. Navigate to the screen to test via SceneRouter or UI interaction
5. Resize to 360x640 (`window_set_size(Vector2i(360, 640))`)
6. Read state (separate `run_script` call — window_set_size is async)
7. `mcp__godot__take_screenshot` (portrait at design floor)
8. Resize to 960x540 for landscape
9. Read state again (confirm `effective_columns == 3`, `is_landscape == true`, `breakpoint` = DESKTOP)
10. `mcp__godot__take_screenshot` (landscape)

**Screens to prioritize** (Phase 5 uncommitted work from the mobile re-pivot, plus high-traffic
standard screens):

| Screen | File | Priority | Notes |
|---|---|---|---|
| Campaign Dashboard | `src/ui/screens/campaign/CampaignDashboard.tscn` | P0 | Most-used screen; outer-scroll already committed |
| World Phase panels | `src/ui/screens/campaign/panels/world/` | P0 | Portrait stack committed; verify at 360dp |
| PreBattle + Equipment | `src/ui/screens/battle/PreBattleUI.tscn` | P0 | Phase 4 committed; tabs on mobile |
| TacticalBattleUI | `src/ui/screens/battle/TacticalBattleUI.tscn` | P1 | Phase 4 rails->drawers; verify both orientations |
| Tactics Dashboard | `src/ui/screens/tactics/TacticsDashboard.tscn` | P1 | Phase 5 AdaptivePanelGroup — uncommitted |
| Planetfall Dashboard | `src/ui/screens/planetfall/PlanetfallDashboard.tscn` | P1 | Phase 5 AdaptivePanelGroup — uncommitted |
| Bug Hunt Dashboard | `src/ui/screens/bug_hunt/BugHuntDashboard.tscn` | P2 | Phase 5 AdaptivePanelGroup — uncommitted |

---

## Updating This SOP

Add to this doc when:
- A new Android-specific failure mode is discovered in on-device testing
- New ADB workflows prove useful (logcat filters, memory profiling, input latency)
- The Android APK distribution workflow is finalized (signing key, Play Console internal track,
  sideload instructions for alpha cohort)
- A new class of touch or layout bug emerges that MCP simulation misses

Do not add transient debugging tips here — those go in `CLAUDE.md` Gotchas.
