#### Battle-phase DELIVERY audit (Aug 6 2026) — the rule was right, the CALL was missing

Follow-up to the Jul 30-31 sprint below, on a different axis. That one found
rules computed and never consumed. **This one found rules implemented correctly
and never REACHED** — the fifth-most-common shape in this codebase and the one no
key census can see, because both halves exist and are correct.

**The generalization, which held five times in one day:** *when a rule appears
missing, check whether a function implementing it already exists with no caller.*

| Disguise | What was actually wrong |
|---|---|
| Four Compendium chapters unreachable in campaign play (No-Minis pp.66-73, stealth, street fight pp.123-138, salvage pp.137-147) | an **early return** in `initialize_battle` above their four setup calls. `CampaignTurnController` stamps `selected_tier` on EVERY campaign battle, so the last 40 lines never ran. The file warned about this hazard 7 lines above the return; four later additions landed below it anyway |
| p.88 deployment panel blank in every battle | `_populate_deployment_conditions` called BEFORE the panel it fills existed |
| Compendium mission panels invisible at the default tier | they were added to the `tracking` drawer, whose opener is ASSISTED+; the default is LOG_ONLY. All three routes (landscape bar, portrait menu, auto-open) were closed at once |
| Hold the Field scored as a WIN in Rival/Invasion battles (p.91, p.92 "There is no Win condition") | `no_win_condition` computed for both, read by nothing → +3 XP instead of +2, and inflated `battles_won`. Applied at **all four** `success` producers, two more than the sweep first listed |
| Compendium p.137 salvage availability D6 totally inert | `find_salvage_job()` held the roll and had ZERO callers; the live producer never invoked it. Three rules dead at once: no-job (a job every turn instead of 5 in 6), the 2cr fee, and `is_illegal` |
| Grid movement all-or-nothing, contra p.90 | the three ungated `build_*` functions written for the per-battle choice had ZERO callers |
| Gloomy / Invasion early-departure | correct rules, stated once pre-battle and never at the decision point |
| Insanity earned story points from travel events (p.65) | `TravelEventResolver` was the ONE award site bypassing `GameStateManager`, where the gate lives |

**The tier was also locked for the whole battle.** `set_tier()` had exactly one
caller passing `force = true`, and `tier_badge` was a `Label`. The controller's own
"cannot downgrade mid-battle" guard proves a non-forced caller was intended and
never written. The badge is now a Button; lower tiers are GREYED with a reason
rather than silently no-opping into a `push_warning`.

**Traps worth keeping.** `queue_free()` DEFERS to end-of-frame, so rebuilding a
container in place must `remove_child()` FIRST or it holds old and new children
together for a frame (a toolbar rebuild returned 14 buttons instead of 7). And a
**containment assertion is blind to duplication** — all 79 checks in
`verify_battle_ui` missed that, because they assert the button is present and a
duplicate set still contains it.

Ledger: sweeps W1-W10 in `review-the-core-rules-jazzy-harbor.md`. Harnesses now
`verify_battle_ui` 79/79 and `verify_post_battle` 46/46 (its first fully green run
— two of its three long-standing failures were TEST defects, not code).

---

*Extracted from `CLAUDE.md` on 2026-08-06 to keep the always-loaded file small. The durable rules from this audit remain inline in CLAUDE.md; this file is the full narrative record.*
