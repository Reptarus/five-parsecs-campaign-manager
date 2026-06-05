# SOP: Cross-Mode Character Transfer

**Read this before** adding or editing any character-transfer leg between the
persistent gamemodes, touching the `user://transfers/` file-drop envelope, the
lossless snapshot, the reward-suppression rule, or the mode-generic dashboard
pickup.

The canonical-hub + file-drop + snapshot pattern has now been used across all
four modes (Foundation: Bug Hunt ↔ 5PFH; Planetfall P1; Tactics named veteran),
so it is a documented pattern.

---

## What this covers

Moving a SINGLE character between the 4 persistent gamemodes:

| Mode | mode id | Campaign core | Roster mutator |
|---|---|---|---|
| Standard 5PFH | `"five_parsecs"` | `FiveParsecsCampaignCore` | `add_crew_member()` |
| Bug Hunt | `"bug_hunt"` | `BugHuntCampaignCore` | `add_main_character()` |
| Planetfall | `"planetfall"` | `PlanetfallCampaignCore` | `add_roster_character()` |
| Tactics | `"tactics"` | `TacticsCampaignCore` | `add_veteran_character()` (named veteran, NOT a squad unit — see below) |

Battle Simulator is standalone (no persistence) and is OUT of scope.

---

## The canonical hub (single chokepoint)

All transfer logic lives in `src/core/character/CharacterTransferService.gd`
(`class_name CharacterTransferService`, extends `RefCounted`). The canonical
interchange form is the **full 5PFH-standard Character dict**. Every mode
exports-to / imports-from that one form. This mirrors the rulebooks themselves —
each expansion documents how a character "returns to 5PFH play" and how a
standard character enters that mode.

```text
Source mode character
  └─ export_to_canonical(char, source_mode)     ← SOURCE LEG (a book rule)
       → canonical 5PFH-standard Character dict
            └─ import_from_canonical(canonical, target_mode)   ← TARGET LEG (a book rule)
                 → target-mode shape + embedded lossless `snapshot`
```

`transfer_character(char, source_mode, target_mode)` composes the two legs and
returns the transfer envelope.

### Route matrix: 9 book-defined + 3 composed

Of the 12 directed routes among the 4 modes, **9 are book-defined**. The other
**3 have NO direct book rule** — Planetfall→Bug Hunt, Tactics→Bug Hunt,
Tactics→Planetfall. They are offered ONLY by composing two book-defined legs
through the 5PFH canonical, which means **zero values are invented**. If you are
tempted to write a direct converter for one of those 3 routes, STOP — compose
through the canonical instead.

---

## Reward-suppression rule

5PFH-specific exit rewards attach **ONLY when `target_mode == "five_parsecs"`**:

- Bug Hunt muster-out: mustering credits (1 per 2 completed missions),
  +1 Story Point, +Sector Government patron (Compendium p.213)
- Planetfall ending bonuses (ship / ship-debt prepayment / rival / psionic /
  Luck) (Planetfall pp.165-166)

These are gated in `transfer_character()` and re-applied to the receiving
campaign in `apply_transfer_rewards()`. A character routed Bug Hunt→Planetfall
must NOT carry 5PFH mustering credits — only a leg that LANDS in 5PFH does.

---

## Lossless snapshot ("return ticket")

Each imported character embeds a `snapshot` key holding its canonical form.

- On export, `export_to_canonical()` SHORT-CIRCUITS on the snapshot
  (`_restore_from_snapshot()`), so a round-trip restores the original verbatim.
- `_attach_snapshot()` strips any nested snapshot first so snapshots never recurse.
- Planetfall ending bonuses are layered on TOP of a snapshot-restored veteran by
  `_layer_planetfall_ending()`, because the bonuses depend on the ENDING, not the
  stats. Do NOT recompute stats from the Planetfall-side character — use the
  snapshot.

**KP→Luck is deliberately NOT converted on Planetfall export.** The book is
silent on a KP→Luck export conversion (the p.27 "prefer the Luck system" note is
an IMPORT-side option only). `convert_from_planetfall()` restores base Luck (1);
imported veterans recover their real Luck via the snapshot. Inventing an export
formula would violate data integrity.

---

## Transfer mechanism: direct file-drop

Transfers are written to `user://transfers/<id>.json` (the user chose direct
file-drop, NOT a persistent barracks — barracks is deferred to P3).

Envelope (`schema_version 2`):

| Key | Meaning |
|---|---|
| `schema_version` | `2` |
| `direction` | `"<source>_to_<target>"` |
| `source_mode` / `target_mode` | mode ids |
| `character` | the down-converted target-mode character |
| `snapshot` | the lossless canonical form |
| `stashed_equipment` | equipment set aside on the source leg |
| `mustering_credits` / `bonus_story_points` / `add_sector_government_patron` | rewards (only set when target is 5PFH) |
| `source_campaign_id` / `source_campaign_name` | provenance for the pickup dialog |
| `transferred_at` | timestamp |

- Static `load_pending_transfers(target_mode="")` filters files by destination.
  v1 muster-out files predate `target_mode` and always targeted 5PFH —
  `_transfer_targets_mode()` treats a missing `target_mode` as `"five_parsecs"`.
- Static `apply_transfer_rewards(campaign, transfer_data)` applies rewards to the
  receiving campaign and **DELETES the file** — this is what prevents a
  double-import. Skipped (not applied) transfers keep their file.

---

## Mode-generic pickup (wire BOTH halves)

The destination side lives in `src/ui/screens/campaign/CampaignScreenBase.gd`:

- `_check_pending_transfers()` — loads files for THIS campaign's mode, shows the
  "Veterans Awaiting Orders" dialog
- `_apply_pending_transfers()` — applies rewards + dispatches the character
- `_add_character_to_mode()` — dispatch: `five_parsecs`→`add_crew_member`,
  `bug_hunt`→`add_main_character`, `planetfall`→`add_roster_character`,
  `tactics`→`add_veteran_character`
- `_notify_transfer_result()`, `_campaign_mode()`, and the
  `_on_transfers_applied()` virtual hook

Each dashboard calls `_check_pending_transfers.call_deferred()` in
`_setup_screen()` and overrides `_on_transfers_applied()` to rebuild its roster
view. Wired in CampaignDashboard (5PFH), BugHuntDashboard, PlanetfallDashboard,
TacticsDashboard. `GameState.load_campaign()` emits
`pending_character_transfers(count)` on a 5PFH load.

> **A SOURCE leg with no DESTINATION pickup is dead code.** The original Bug Hunt
> muster-out bug was exactly this — files were written to `user://transfers/`
> but nothing read them, so veterans silently vanished. When you add a transfer
> route, verify the destination dashboard calls `_check_pending_transfers`.

The 5PFH crew-addition chokepoint is
`FiveParsecsCampaignCore.add_crew_member(member_dict)`: it appends to
`crew_data["members"]`, forces `is_captain=false`, rebuilds `_crew_id_index`, and
updates the modified time. Never `crew_data["members"].append()` from outside.

---

## Planetfall import UI

`src/ui/screens/planetfall/panels/PlanetfallCharacterImportPanel.gd`: select a
source character from 5PFH/Bug Hunt saves → preview → **Class Training** D6
aptitude (1-2 fail, 3 random class, 4-6 player choice; max 3 trained, one per
class) → embed snapshot → `add_roster_character`. 5PFH Luck → 1 Kill Point each;
Bug Hunt Tech → Savvy; imported characters begin Loyal (Planetfall pp.26-27).

- Creation-wizard entry: the import button in `PlanetfallRosterPanel.gd`.
- Dashboard cards on PlanetfallDashboard: "Import Veterans" and "Muster Colonists
  Out".

---

## Tactics import UI

`src/ui/screens/tactics/panels/TacticsVeteranImportPanel.gd`: select a source
character from 5PFH / Bug Hunt / Planetfall saves → preview the Tactics
conversion → embed snapshot → `add_veteran_character`. TacticsDashboard exposes:

- A **"Commission Veteran"** card (opens the import panel).
- A **"Retire Veteran Out"** card (a 3-target overlay → 5PFH / Bug Hunt /
  Planetfall).

TacticsDashboard calls `_check_pending_transfers.call_deferred()` and overrides
`_on_transfers_applied()`. The named veteran is stored in `veteran_characters[]`,
never in `campaign_units[]`, so it never affects army points.

---

## convert_from_planetfall ending matrix (data-integrity, verify against the book)

Planetfall pp.165-166 (verified in `docs/rules/planetfall_source.txt`
L12088-12113). The old matrix was WRONG; the corrected values are:

| Ending | Effect |
|---|---|
| `loyalty` | `bonus_ship` + `ship_debt 0` (no debt) |
| `independence_won` | `bonus_ship` + `ship_debt_prepaid` (2D6 **partial** prepayment) + `bonus_story_points 2` |
| `independence_lost` | `add_rival` (Enforcers or Bounty Hunters) + `bonus_story_points 2` |
| `isolation` | +1 Luck + `isolation_single_char` flag |
| `ascension` | `gains_psionic` |

The OLD BUG zeroed the WHOLE debt on `independence_won`. The book only prepays
**2D6** of it. Never re-introduce full debt forgiveness.

---

## Tactics named veteran (SHIPPED Jun 4)

Individual character transfer to/from Tactics is BUILT and tested.

- A transferred character becomes a **NAMED VETERAN** (an "officer or hero"
  figure, Tactics p.185) stored in `TacticsCampaignCore.veteran_characters[]` (a
  serialized array) — NEVER a squad unit in `campaign_units[]` (the book uses
  "no points cost formula", p.184, so veterans stay OUT of points validation).
  Army lists remain species-profile-based; the army-list / points system is
  unchanged.
- Core mutators: `add_veteran_character()` (applies a tagged playability floor of
  ≥1 Kill Point), `remove_veteran_character()`, `get_veteran_characters()`.
- **The data-integrity prerequisite is DONE.** `convert_to_tactics()` /
  `convert_from_tactics()` were verified against Tactics p.184 ("Converting
  Characters") and three fabrications were removed:
  1. The invented `military_backgrounds` list → replaced with a
     `"military"` / `"war-torn"` substring check grounded in the real
     `gear_database.json` backgrounds. The book says only "+2 with a
     military-type background", with NO enumerated list, so the
     `GAME_BALANCE_ESTIMATE` tag is GONE.
  2. The `max(luck, 1)` KP floor → the book is exactly "1 Kill Point per Luck
     point", so the floor moved to the veteran layer (`add_veteran_character()`,
     tagged playability) and the conversion stays book-exact.
  3. The "military property, equipment not transferred" strip → the book says
     "carry weapons over as they are", so equipment carries over unchanged.
  Combat cap +2, Toughness cap 5, and "each Kill Point after the first becomes
  1 Luck" on export were confirmed CORRECT.

---

## Files

| File | Role |
|---|---|
| `src/core/character/CharacterTransferService.gd` | Canonical hub, all conversion legs, envelope build/load, reward application |
| `src/game/campaign/FiveParsecsCampaignCore.gd` | `add_crew_member()` crew-addition chokepoint |
| `src/ui/screens/campaign/CampaignScreenBase.gd` | Mode-generic dashboard pickup |
| `src/core/state/GameState.gd` | Emits `pending_character_transfers(count)` on 5PFH load |
| `src/ui/screens/planetfall/panels/PlanetfallCharacterImportPanel.gd` | Planetfall import UI (Class Training) |
| `src/ui/screens/planetfall/panels/PlanetfallRosterPanel.gd` | Creation-wizard import button |
| `src/game/campaign/TacticsCampaignCore.gd` | `veteran_characters[]` array + `add_/remove_/get_veteran_character(s)()` |
| `src/ui/screens/tactics/panels/TacticsVeteranImportPanel.gd` | Tactics named-veteran import UI (Commission Veteran) |
| `src/ui/screens/tactics/TacticsDashboard.gd` | "Commission Veteran" + "Retire Veteran Out" cards; `_on_transfers_applied()` override |
| `tests/unit/test_character_transfer_hub.gd` | Hub / route-matrix / reward-suppression / snapshot tests |
| `tests/unit/test_planetfall_transfer.gd` | Planetfall import/export + ending-matrix tests |
| `tests/unit/test_tactics_transfer.gd` | Tactics conversion + named-veteran tests (9 tests) |

24/24 gdUnit4 transfer tests pass across the three test files. Run them (not
`--headless`, not `--script`) with the `-c` flag per `feedback_gdunit4_flags`.

---

## Status

- Foundation (Bug Hunt ↔ 5PFH; fixed the broken muster-out pickup): **SHIPPED**
- Planetfall P1 (import at creation wizard + dashboard; muster out to 5PFH or Bug
  Hunt; reciprocal pickup on Planetfall + Bug Hunt dashboards): **SHIPPED**
- Tactics named-veteran import/export (Commission Veteran + Retire Veteran Out;
  book-faithful conversion per p.184; `veteran_characters[]` array): **SHIPPED**
  (Jun 4). All 4 persistent modes now interconnect any-to-any.
- P3 persistent "veteran barracks": **deferred**
