# Component Patterns SOP

Five conventions that keep new components from regressing into bugs we've
already fixed. Each one has a story behind it — keep the pattern, even if
the reasoning isn't obvious from the code.

## Single source of truth for derived data

A character has a `portrait_path` field. The UI used to read it directly.
Result: when the field was empty (90% of generated characters), the card
fell back to a colored initial — bypassing the species-portrait registry
we'd built to handle exactly that case.

**Rule**: when a field has a computed fallback, expose only the accessor.
Never let callers read the raw field.

```gdscript
# In Character.gd:
func get_portrait() -> String:
    if not portrait_path.is_empty():
        return portrait_path  # user-uploaded wins
    var from_registry: String = SpeciesPortraitRegistry.get_portrait_for(
        species_id, character_id)
    if not from_registry.is_empty():
        return from_registry  # species default
    return SpeciesPortraitRegistry.DEFAULT_PORTRAIT  # last resort

# In any consumer:
var path := character.get_portrait()  # always — never character.portrait_path
```

The same pattern applies to `get_max_implants()` (species-dependent),
`get_bonus_xp()` (trait-dependent), `get_task_bonus()` (Empath +1), etc.
If a derived value has more than one input, hide the inputs.

## Single-source-of-truth JSON + static loader

When data needs to ship with the project AND be readable by humans AND
load fast at runtime: JSON file + static RefCounted loader + UI consumer.

```
data/<domain>.json                              # truth
src/<domain>/<Domain>Catalog.gd (RefCounted)    # static loader, cached
src/ui/.../<Domain>Card.gd (Control)            # consumer, no logic
```

Examples already in the codebase: `DLCContentCatalog`, `ModeInfoCatalog`,
`PlanetfallPresetCrew`, `SpeciesPortraitRegistry`, `KeywordDB`.

Loader skeleton:

```gdscript
extends RefCounted

const JSON_PATH := "res://data/mode_info.json"
static var _cache: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
    if _loaded:
        return
    var f := FileAccess.open(JSON_PATH, FileAccess.READ)
    if not f:
        push_warning("ModeInfoCatalog: cannot open %s" % JSON_PATH)
        _loaded = true  # mark loaded so we don't retry every call
        return
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if parsed is Dictionary:
        _cache = parsed
    _loaded = true

static func get_mode(id: String) -> Dictionary:
    _ensure_loaded()
    return _cache.get("modes", {}).get(id, {})
```

**Why static + cached**: callers don't have to manage instances. The cache
survives the entire session. `_ensure_loaded()` runs once and is cheap
after that.

**Why RefCounted not Node**: no scene tree presence, no `_ready()`, no
autoload registration. The class is a namespace for static functions.

## Path-loaded preload pattern

Some components risk a name collision with autoloads, or are loaded
*before* the autoload system finishes parsing. Two safe patterns:

**Pattern A — `const X = preload(...)` at top of file**:

```gdscript
extends Control

const SpeciesPortraitRegistry = preload(
    "res://src/core/character/SpeciesPortraitRegistry.gd")
const ModeInfoCatalog = preload(
    "res://src/ui/screens/mainmenu/ModeInfoCatalog.gd")

@export var character: Character

# ... rest of script
```

**Pattern B — `extends "res://path/to/Base.gd"`** (no class_name):

```gdscript
extends "res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd"
# No class_name on this file.
```

**Rule**: all `const` and `preload` declarations must be at the TOP of the
file, before any `@export` vars, signals, or function definitions. A
mid-file `const` is a parse error in GDScript — and Godot's error
location reporting for this case is misleading.

**When to drop `class_name` entirely**:
- The script is registered as an autoload (collision: "Class hides
  autoload singleton")
- The script extends another script via path (load-order safety)
- The script is path-loaded by other scripts via `load()` (no need for
  the global identifier)

`SceneStage.gd`, `PlanetfallScreenBase.gd`, and most of the path-loaded
panels in `src/ui/screens/planetfall/` follow Pattern B.

## Export-safe asset loading

`Image.load()` works in the editor and dev builds because the source PNG
sits next to the imported `.ctex` in the project tree. Exports strip the
PNG — only the `.ctex` ships in the `.pck`. `Image.load()` then fails
silently at decode time.

**Rule**:
- `res://` paths → `load()` (returns `Texture2D` from the imported `.ctex`)
- `user://` paths → `Image.load()` + `ImageTexture.create_from_image()`
  (these are runtime-written files Godot has never imported)
- Absolute paths (e.g. file picker on desktop) → same as `user://`

```gdscript
var pp := character.get_portrait()
var tex: Texture2D = null

if pp.begins_with("res://"):
    var res = load(pp)
    if res is Texture2D:
        tex = res
elif not pp.is_empty():
    var img := Image.new()
    if img.load(pp) == OK:
        tex = ImageTexture.create_from_image(img)

if tex:
    texture_rect.texture = tex
```

The exact same branching lives in `CharacterCard._update_portrait()` and
`SceneStage._make_layer_rect()`. Copy this pattern when adding any new
component that handles user-uploaded images alongside packed assets.

**Test for regression**: Godot's debug console will print
`"Loaded resource as image file, this will not work on export"` the
moment `Image.load()` is called on a `res://` path. If you see that
warning, you have a bug — even if the image renders fine in the editor.

## Deferred initial swap (for import-timing races)

`MainMenu._build_mode_showcase()` instantiates a `ModeShowcaseCard` and
asks it to display the default mode. The default cover PNG was imported
*after* `_ready()` finished. Result: the very first show was blank; only
hovering a button populated the card.

**Rule**: when a `_ready()` chain triggers asset loading that the rest of
the scene depends on, defer the consumer:

```gdscript
func _build_mode_showcase() -> void:
    var card := ModeShowcaseCardClass.new()
    add_child(card)
    # Don't call card.set_mode() yet — assets may not be imported.
    var _initial_swap = func():
        card.set_mode("standard", true)  # instant = true, no fade
    _initial_swap.call_deferred()
```

Why `call_deferred()` instead of `await get_tree().process_frame`:
- `call_deferred` runs at the END of the current frame, which is the
  point where Godot guarantees imported textures are available
- `await process_frame` runs at the *start* of the next frame, which is
  later than needed and adds a one-frame visual gap
- Lambdas with `call_deferred` keep the call adjacent to its setup, so
  the reader sees both halves together

Subsequent swaps (button hovers) don't need deferral — the textures are
already in memory by then.

## When to break these rules

Patterns exist to prevent past bugs. If you have a reason to break one,
**document why in `decision-log.md`** so the next person doesn't "fix"
your deliberate choice back into the trap.

Examples of legitimate deviations:
- Test fixtures may read raw fields directly (testing the SSOT layer
  itself)
- One-off migration scripts may bypass the loader (truth is being
  rewritten)
- Editor tool scripts (`@tool`) often need to operate before autoloads
  exist; they're allowed to special-case

If your deviation isn't on that list, follow the pattern.

## Updating this SOP

Add a pattern here when:
- The same gotcha bites a second time across different components
- A new abstraction layer becomes load-bearing (e.g. an event bus
  pattern, a save-load wrapper)
- A safer way to express an existing pattern emerges

Don't add transient tips ("use this widget instead of that one") — those
belong in `CLAUDE.md` under the relevant subsystem heading.
