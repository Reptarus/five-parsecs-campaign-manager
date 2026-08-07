# QA Specialist — Agent Memory

<!-- Loaded into your system prompt. KEEP UNDER 200 LINES. -->
<!-- Durable rules only. Dated session logs were archived 2026-08-06 to -->
<!-- docs/archive/agent-memory-logs/qa-specialist-MEMORY-2026-08-06.md -->

## ABSOLUTE RULE

The Core Rules and Compendium PDFs at `docs/rules/` are canonical. If code disagrees with the book,
the code is wrong. Extraction commands and the source-authority hierarchy live in `CLAUDE.md`.

---

## Critical Gotchas — Must Remember

1. **Godot 4.6 type inference**: `var x := dict["key"]` will NOT compile. Always
   `var x: Type = dict["key"]`. The #1 cause of compile errors in new code.
2. **TWO enum systems, not three** — `GlobalEnums` and `GameEnums` must stay ordinal-synced.
   ⚠ Older notes said "Three-Enum Sync Rule (… FiveParsecsGameEnums)". That file was **deleted
   2026-05-24** (Sprint A Bug 3). Pinned by `tests/unit/test_enum_ordinal_sync.gd`.
3. **Parse sweep: use `--import`, NOT `--quit`.** `--quit` validates STARTUP scripts only; `--import`
   loads **every** script. On Aug 6 2026 `--quit` reported clean while `PostBattleSequence.gd` failed
   to parse — taking the entire post-battle wizard down — and so did **2254 passing unit cases** and a
   **46/46 backend harness**, because neither loads that UI script. `--import` caught it in one run.
   It also generates the `.gd.uid` files this project commits. Cheapest high-value check you own;
   run it before calling any sweep green.
4. **gdUnit4 takes `-c`, never `--headless`.** Always read the case **COUNT** — a parse error reports
   "No test cases found" and **exits 0**.
5. **GDScript does NOT hot-reload in a running Godot instance.** After editing a `.gd` you MUST
   `stop_project` + `run_project` before re-probing via MCP `run_script`, or you verify against stale
   launch-time bytecode. Symptom: a probe reports values inconsistent with the on-disk source.
6. **MCP runs in DEBUG (break-on-error) and this cuts BOTH ways.** Decide the error CLASS first.
   - **Class (a) — Dictionary missing-key access**: Godot returns null, logs `SCRIPT ERROR`, and
     continues *within the same function*. Often harmless log-spam. Do not OVER-claim a crash.
   - **Class (b) — nonexistent method/property, or a type-method mismatch** (`.to_lower()` on a float,
     `has_active_quest()` on a node lacking it): Godot **ABORTS the current function** then continues
     the process. The app doesn't close, but if that function was doing essential work the feature
     **silently does nothing**. A REAL bug — do not under-claim it as "debug-only."
7. **Green unit tests ≠ exercised runtime path.** `test_injury_determination` passed 13/13 both before
   AND after a real crash-spam fix in the very function it tests, because the test data never tripped
   the offending line. The MCP runtime is the real gate.
8. **Some bugs are reachable ONLY by an on-device PLAYED walk.** Unit tests, `--headless`, and desktop
   MCP all passed through F9 (the tracker drawer won't vertical-**touch**-scroll on tablet; desktop
   mouse-wheel hides it) and F10 (a PLAYED LOG_ONLY battle had no reachable control to end it —
   desktop verification papered over it by INJECTING a tracker and calling the API instead of driving
   the real UI). For "played on my table" flows, an ADB touch walk is the gate.
9. **Never truncate a lint's output** (`Select-Object -Last N`, `head`). On Aug 6 that under-reported
   3 data-ownership violations as 1, and two of the three were live rules bugs.
10. **A red harness row is a LEAD, not a verdict.** All three long-standing `verify_post_battle`
    failures were TEST defects. Widen the observation, never relax the assertion — then prove the test
    can still fail. And a **containment assertion is blind to duplication**: asserting a button is
    present passes even when the whole set is duplicated.

---

## Sweep methodology — walk BOTH save-states

The two sweeps below found disjoint bug sets. Run both; neither substitutes for the other.

**Legacy-save walk (under MCP `run_project`)** — surfaced 4 pre-existing class-(b) crashes that
`--headless` and green unit tests both passed through. All were "function aborts, process survives,
feature silently broken". Method: walk the FULL happy path on a *legacy* save (NOT a fresh campaign),
root-cause each break with `git show` on the introducing commit rather than dismissing it, then
re-walk to confirm the next step proceeds. The recurring trap is **legacy `origin` stored as a float**
— any string op (`.to_lower()`) hard-errors, so `str()`-wrap; prefer `species_id` (always String).

**New-campaign walk (on-device via ADB)** — NEW-CAMPAIGN-ONLY bugs, because fresh crew/captain are
Character **Resources**, not the dict form a save→reload produces. Found a P0 soft-lock: 2-arg
`Dictionary.get(key, default)` silently aborts on a Resource → empty crew list → World Phase Step 2
won't advance. Also caught int→validated-string enum defaults, a hand-copied stat list omitting
`luck`, and starting credits dropped by a signal adapter — none visible to `--headless`.

**ADB methodology**: `adb exec-out screencap -p`; tap coords = screencap pixels; **COLOR-SCAN the PNG
for button centers** (don't eyeball fractions); force portrait via
`adb shell settings put system accelerometer_rotation 0` + `user_rotation 0`. MCP `take_screenshot`
works ONLY on MCP-launched instances (not adb-launched); `uiautomator dump` does NOT expose Godot
controls; **desktop cannot simulate a portrait window** — portrait layout is device-authoritative.
⚠ An Android emulator cannot render Vulkan here, so a black screencap is meaningless.

---

## Lints — all four are exit 0, so a finding means a NEW regression

`lint_signal_wiring` · `lint_tscn_connections` · `lint_autoload_lookups` · `lint_data_ownership`.
The legacy backlogs they were opened with are CLOSED. `lint_orphan_assets` exits 1 on `orphans` OR
`test_only`; orphans is 0, and the 41 test-only files are a tracked product decision — do not
bulk-delete that list.

---

## Cross-Mode Transfer — test surface (24/24 green, KEEP GREEN)

Files: `tests/unit/test_character_transfer_hub.gd`, `test_planetfall_transfer.gd`,
`test_tactics_transfer.gd` (9 Tactics tests).

- **Round-trip invariant**: import into Bug Hunt/Planetfall, muster out to 5PFH → the restored
  character must equal the original VERBATIM (driven by the embedded `snapshot`;
  `export_to_canonical` short-circuits on it). **Stat re-derivation on the way out is a bug.**
- **Reward suppression**: 5PFH-only exit rewards attach ONLY when `target_mode == "five_parsecs"`.
  Verify none leak to another mode.
- **Double-import guard**: `apply_transfer_rewards()` deletes the `user://transfers/` file — verify a
  transfer cannot be picked up twice.
- **Captain safety**: `FiveParsecsCampaignCore.add_crew_member()` forces `is_captain=false` and
  rebuilds `_crew_id_index` — verify added crew never overwrite the captain.
- **Planetfall pp.165-166 regression**: `independence_won` uses `ship_debt_prepaid` (2D6 **PARTIAL**
  prepayment), NOT a full debt wipe. Verify against `planetfall_source.txt` L12088-12113.
- **Tactics p.184 regression**: the invented `military_backgrounds` `GAME_BALANCE_ESTIMATE` list is
  GONE — assert it is not reintroduced. The `>=1` KP floor lives at the veteran layer
  (`add_veteran_character()`), not in the conversion, so the conversion stays exactly "1 Kill Point
  per Luck point". A transferred character lands in `veteran_characters[]`, never `campaign_units[]`.

---

## Test-design traps

- **A detection test is valid only if ISOLATED** — prove it fails when the fix is reverted, with
  nothing else changed.
- **Never sample a table to describe itself.** A seed fixes the RNG *stream*, not the value: assert
  invariants, not specific rolls.
- **A detached `.new()` node cannot resolve `get_node_or_null("/root/X")`** — the call errors and
  ABORTS the enclosing function, silently returning the default. Add it to the tree before asserting,
  or the probe measures the trap rather than the code.
- **Never edit files during a gdUnit run.**
- Layout/portrait QA is a DESKTOP job with a real window (`tests/tools/verify_layout.gd`, **no**
  `--headless`) — a desktop window pixel IS a device dp. But a scrollable axis ABSORBS the child
  minimum and hides overflow from the sweep; an unchanged number after a fix usually means you edited
  the WRONG FILE.
