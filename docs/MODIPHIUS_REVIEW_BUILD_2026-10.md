# Five Parsecs Campaign Manager - Review Build Handoff (October 2026)

Audience: the reviewers who will open the review build, and the project owner.
This note says what the build contains, how the review switch works, how to reach late-game
states, what is deliberately unfinished, and where the books contradict themselves. It
contains no commercial terms.

Status: written 2026-10-30, before the Sprint 8 device walk. The "Device walk record"
section is a placeholder until that walk is done.

## 1. What the build contains

The review build is the alpha build with every entry point open and every expansion pack
switched on. Nothing is edited between the two; one predicate (`src/core/systems/ReviewBuild.gd`)
decides which you have.

| Mode | How to reach it | What a reviewer can do |
|---|---|---|
| Standard campaign (Core Rules) | Main menu, New Campaign | The 7-step creation wizard, then the 9-phase turn: Story, Travel, Upkeep, Mission, Post-Mission, Advancement, Trading, Character, Retirement. Battles run in the tabletop companion screen at three tracking tiers. Printable sheets (PNG/PDF) and the Galaxy Log. |
| Bug Hunt | Main menu, Bug Hunt | 4-step creation, Special Assignments, mission setup (support, loadout, signals), battle, post-battle (Compendium p.202 Military Life), muster-out to a transfer file for Standard play. |
| Bug Hunt Co-op Campaign | Main menu, Co-op, "Bug Hunt Co-op Campaign" | Bug Hunt creation with co-op switched on (Compendium pp.209-211): a shared sector map, sector Factors, operational turns and Enemy Moves. |
| Expanded Co-op rules | Main menu, Co-op, "Expanded Co-op rules" | Reference text only (Compendium pp.39-41). The app does not run this variant. |
| Planetfall | Main menu, Planetfall | 6-step colony creation, then the 18-step turn flow. |
| Tactics | Main menu, Tactics | Army building, battles, post-battle with Campaign Points, and the operational turn. |
| Battle Simulator | Main menu, Battle Simulator | A standalone battle with no campaign and nothing saved. |

Cross-mode: a single character can move between the four persistent modes (Standard,
Bug Hunt, Planetfall, Tactics) through the transfer files in `user://transfers/`.

Compendium chapters: with every pack on, all 33 Compendium feature flags are available.
They are switched on per campaign in the creation wizard's expansion section; the review
grant covers ownership only, so a reviewer chooses the toggles.

An in-app Help guide (chapters 00-19) covers each mode. Per-screen audit ledgers are in
`docs/audits/` (for example `BUG_HUNT_PARITY_AUDIT_2026-09-10.md` and
`UI_UX_SCREEN_AUDIT_2026-10.md`).

## 2. How the review switch works

- `ReviewBuild.is_active()` is true when the export carries the custom feature tag
  `review_build`. That tag is set only on two presets in `export_presets.cfg`:
  `fiveparsecs-review-android` and `five-parsecs-review-windows`. The alpha presets have no tag.
- When active: the Alpha-1 menu scope is off (`MainMenu.is_a1_build()` is false), and every
  DLC pack is granted in memory (`DLCManager._apply_review_grants()`). The grant is not
  written to disk, and a save cannot persist it. The store and billing screens are not used.
- The Android review preset is an APK under its own package id, `com.reptarus.fiveparsecs.review`,
  version name `0.9.8-review`, version code 19. It installs beside the alpha and keeps its own
  data. The alpha preset (`com.reptarus.fiveparsecs`, 0.9.7, code 18) is unchanged.
- In an editor run or a unit-test run the tag is absent, so the build behaves as the alpha. In a
  debug build only, the argument `-- --review-build` turns it on; a release build ignores it.

## 3. Reaching late-game states

Both tools below are gated on `ReviewBuild.qa_tools_enabled()`, which is true in a debug build
or a review build and false in the alpha.

- **Scenarios** (Standard campaign dashboard, labelled "Scenarios" in the review build, "QA" in a
  debug build): applies a prepared state to a loaded campaign, such as injuries and Sick Bay,
  Compendium mission types, rivals plus patrons plus an active Quest, or the endgame block. It
  does not jump the turn phase.
- **Force the next roll** (inside the same dialog): queues a value for the next dice roll whose
  context matches a row (for example a Character Event, an Explore result, the Rival attack type,
  or a Bug Hunt muster-out). An out-of-range value is discarded rather than clamped.

These cover the Standard campaign. The other modes have no scenario loader; they are reached by
playing, plus the forced rolls above where a mode's rows are listed.

## 4. What is parked

- **Store and billing.** Purchases are not part of this build. `OfflineStoreAdapter` stays in
  place; the review flag bypasses it in memory. Billing is parked pending the agreement with the
  publisher.
- **Legal text.** The shipped EULA and privacy policy carry seven bracketed placeholders (license
  grant scope, revenue share, governing law, contact email, release date). They are visible on
  purpose and mark terms that are not yet settled. The public web copy under `docs/legal/gh-pages/`
  carries eight. See `docs/legal/POST_LOI_LEGAL_CHECKLIST.md`. No value has been invented.
- **Steam.** `steam_appid.txt` holds `480`, a placeholder App ID. It is not a real product id.
- **Device record.** Hardware verification of the new screens is the Sprint 8 walk (section 7).

## 5. Rules where the books contradict themselves or are ambiguous

Each row records the app's chosen reading so nobody "fixes" it by accident.

| Where | The conflict | The app follows | Why |
|---|---|---|---|
| Ship debt seizure, Core Rules p.60 vs p.76 | p.60: debt "exceeds 75 credits". p.76 (the upkeep procedure where the check is made): "75 credits or more", then roll 2D6, 2-6 loses the ship | p.76, at 75 or more | The procedural page is where the roll is executed. Recorded in `docs/RULES_WIRING_AUDIT_2026-08.md`. |
| Co-op stash, Compendium p.210 vs p.211 | p.210: a sector's resource stash is 1D6 Support points. p.211 says "+5" | p.210 | The procedural page (The Map) wins. `data/bug_hunt/bug_hunt_coop_campaign.json` records `stash_size_contradiction`. |
| Tactics raw-material reclaim, p.69 vs p.98 (row T15a) | p.69: BP equal to half the BP cost. p.98: half the BP cost, rounded down, in Raw Materials | p.98 (Raw Materials) | The procedural page, same reasoning as the debt row. |
| Bug Hunt Vital/Critical objective under Campaign escalation, Compendium p.187 (row MG-12) | Escalation is used "instead of rolling" the Priority; "increase Priority by +1" for a Vital Objective is its own paragraph | The +1 (Vital) or +2 (Critical) applies on top of an escalation rating, clamped 1-6 | Escalation replaces the 2D6 roll only. `docs/audits/BUG_HUNT_PARITY_AUDIT_2026-09-10.md`. |
| Bug Hunt escalation sequence length, p.187 (row MG-13) | The option exists so a campaign "slowly escalates", but the sequence is finite | The last rating holds (no wrap back to Priority 1) | Read from the page rather than left ambiguous; recorded as fixed. |
| Direct Quests, Core Rules Quest rules | The book is silent on Rumors held when a Direct Quest arrives, and on a Direct Quest received during an active Quest | Held Rumors are kept; a Direct Quest during an active Quest does nothing | Silence in the book; `docs/audits/UI_UX_SCREEN_AUDIT_2026-10.md`. |
| Errata over print | Several printed rules were overturned by the errata (v1.06) and the publisher FAQ | The errata | A page cite proves code followed the book, not that the book still says it. |

## 6. One open owner question

**F6-3b: a Raided boarding and the one-battle-per-turn model.** Core Rules p.70 says the pirate
raid from the Starship Travel Events table "is an 'out of sequence' encounter, and does not
count as the main Battle stage for the campaign turn". The app has one battle slot per turn.
The raid is delivered (enemy dice, loss penalty, bonus Loot roll), but it takes the turn's battle
when no job is accepted, and is dropped when one is. The book does not say whether the
once-per-turn post-battle steps (Campaign Event, Character Event, Rival and Patron status) run
again after a raid, and errata v1.06 is silent. This is pending an owner ruling; it is not
answered here. Ledger row: `docs/audits/UI_UX_SCREEN_AUDIT_2026-10.md` (F6-3b).

## 7. Device walk record

To be filled in by Sprint 8. One section per mode, with the build version, the device, and the
date of each walk.

- Standard campaign: not yet recorded
- Bug Hunt: not yet recorded
- Co-op Campaign: not yet recorded
- Planetfall: not yet recorded
- Tactics: not yet recorded
- Battle Simulator: not yet recorded
