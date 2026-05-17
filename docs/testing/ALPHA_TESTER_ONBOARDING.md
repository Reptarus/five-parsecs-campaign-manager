# Welcome to the 5PFH Digital Closed Alpha

Thanks for joining the alpha test for the Five Parsecs From Home digital companion app. This document walks you through everything you need to know to get the build running, give feedback, and stay in the loop.

**TL;DR:**

1. Download the build from the Discord pinned link (Windows-only for now)
2. Walk through the SmartScreen warning (instructions below — it's normal for unsigned alpha builds)
3. Play 2-3 sessions per week for the next 6 weeks
4. Drop bugs in `#5pfh-alpha-bugs`, open thoughts in `#5pfh-alpha-feedback`
5. Take the in-app pricing survey when it appears at session-end (it's optional, but it really helps)

If you have questions before you start, drop a message in the Discord and someone will help.

---

## What This Build Is

This is the **closed alpha** for the digital companion app version of Five Parsecs From Home, currently in development with Modiphius for a Steam Early Access launch later this year.

It's a **companion app**, not a digital edition replacing the books. The goal is to make solo 5PFH campaigns easier to track, with bookkeeping handled in-app while you keep playing on the tabletop. If you've ever wanted to skip the spreadsheet management, that's what this is built for.

**What's in the alpha build:**

- Full Standard 5PFH 9-phase campaign mode
- 7-phase character/crew/ship creation wizard
- All three Compendium expansion packs unlocked (Trailblazer's Toolkit, Freelancer's Handbook, Fixer's Guidebook) — 33 features togglable in Settings
- Battle assistant with three optional-depth modes (logging only / suggestions / full auto-resolve)
- Battle Simulator (standalone battles, no campaign needed)
- Story Track, Character Events, Red & Black Zone Jobs, all 16 Strange Character species

**What's NOT in this alpha (yet):**

- Bug Hunt, Planetfall, and Tactics gamemodes — we're alpha-testing those separately later
- Mac and Linux builds — Windows-only for alpha-1
- Online features, multiplayer, or cloud saves — everything is local

**Expectations**: this is **alpha**, not beta. Things will be rough. UI will have weird edges. Some text won't be final. That's the point — we want to find what's rough before more people see it.

---

## Installation

### Step 1 — Download the build

Get the latest build link from the Discord pinned message in `#5pfh-alpha-builds`. Builds drop **every Monday at 10AM Pacific** for the duration of alpha. The file is around 150-200 MB.

### Step 2 — Extract the build (if zipped)

Right-click the .zip → "Extract All" → pick a folder you'll remember. The alpha build is a single self-contained `FiveParsecsAlpha.exe` — there's no separate `.pck` data file to keep with it. (We bundle everything into the .exe to reduce installation friction during alpha; the .exe + .pck pair pattern returns at beta + release.)

### Step 3 — Run it (and walk through the SmartScreen warning)

Because the build is unsigned for alpha, Windows Defender SmartScreen will probably warn you the first time you run it. Here's exactly what to do:

1. Double-click `FiveParsecsAlpha.exe`
2. You'll see a blue dialog: **"Windows protected your PC"** with a generic warning about an unrecognized publisher
3. Click the small **"More info"** link in the dialog
4. A new button appears: **"Run anyway"** — click it
5. The app launches normally from then on (you only do this once)

If SmartScreen blocks the run with no "More info" option, you may need to right-click the .exe → Properties → check "Unblock" near the bottom, then OK and try again.

If it still won't run, drop a note in `#5pfh-alpha-builds` with your Windows version and we'll troubleshoot.

### Step 4 — First-launch flow

The first time the app runs you'll see:

1. **EULA** — read, accept
2. **Privacy notice** — read, accept
3. **Analytics opt-in** — defaults to **OFF**. If you turn it on, the app sends anonymous session data to help us see what's getting played and what's not. **No personal info is ever collected.** Off is fine. On is helpful.
4. **Main menu** — you're in.

After first launch you'll go straight to the main menu every time.

---

## How to Give Feedback

We have **two Discord channels** for alpha feedback:

### `#5pfh-alpha-bugs` — for bug reports

Drop a structured report any time something breaks. Use this template (also pinned at top of the channel):

```
**Build version**: A1 / A2 / A3 / etc (check Settings → About)
**Game mode**: Standard 5PFH (alpha-1 is Standard only)
**What happened**: [one or two sentences]
**What you expected**: [one or two sentences]
**Repro steps**:
  1. ...
  2. ...
  3. ...
**Save file** (if applicable): drag-drop the file from `user://saves/` into Discord
**Screenshot/video** (optional): drag-drop in
**Severity**: P0 / P1 / P2 / P3 (see below)
```

**Severity tiers:**

- **P0 (Game-Breaking)** — crash, data loss, can't continue campaign, save corruption
- **P1 (Major UX)** — feature doesn't work as documented, big visual bug, blocks an action
- **P2 (Annoying)** — minor visual glitch, awkward flow, typo in important text
- **P3 (Cosmetic)** — typo elsewhere, minor visual polish, suggestion for later

We'll respond to P0/P1 reports same-day during weekdays. P2/P3 we'll batch into the weekly build.

**Where to find your save file** (for attaching to bug reports):
Open Windows Run dialog (Win+R) → paste `%APPDATA%\Godot\app_userdata\Five Parsecs Campaign Manager\saves` → press Enter. Drag the most recent `.json` file into the Discord report.

### `#5pfh-alpha-feedback` — for open thoughts

Anything that isn't a bug:

- "This part felt great"
- "I expected X to work but it does Y, and Y is actually fine"
- "I'd pay for this if it had Z"
- "Is the goal of this app A or B?"
- "Reminded me of [other product]"

No structure required. Stream of consciousness is fine. Even single sentences are useful.

### Weekly debriefs

Every week we'll do a **30-min Discord voice call** with 2-3 testers (rotating). Casual — what you played that week, what stood out, what felt rough. **You don't need to take notes; we will.** First debrief end of week 1, last one end of week 6.

If you can't make the time slot offered, no worries — drop a Discord note instead.

---

## Pricing-Perception Survey (please take this when it shows up)

At the end of game sessions, you'll occasionally see a modal asking 5-7 quick pricing questions (~3 minutes). It uses the **Van Westendorp price sensitivity meter** — a standard market-research tool — to figure out what the app is worth to people who actually play 5PFH.

The survey asks four price-related questions in randomized order, plus a recommendation question and two short open-ended ones. **It's optional.** Skip it if you're not in the mood. But if you have 3 minutes, your answer genuinely shapes what the EA build looks like and gets priced at.

It's also replicated as a **Google Form** if you'd rather take it outside the app — link will be pinned in `#5pfh-alpha-feedback`.

You'll see the survey **once per build version**, so we're not nagging you weekly with the same questions. We may also occasionally show a quick "category-perception" probe asking how you'd describe the app — same idea, even shorter.

---

## Your Privacy

- **No NDA** — this is a gentleman's agreement. Don't post screenshots, streams, or recordings publicly until we open beta or later. Talking with friends about it is fine; sharing the build is not.
- **One exception** — if anything about Modiphius's other licensed projects comes up incidentally, **don't share that anywhere**. That's the only NDA-grade content.
- **Telemetry (if opted in)** collects: session start/end, mode visits, save events, build crash logs. **No personal info ever.** No email, no save content, no name, no IP-tracked identifiers. You can revoke consent any time in Settings → Privacy.
- **GDPR-style data export and delete** — Settings → Privacy → "Export my data" or "Delete all data". Both work; both are documented per current EU/CA regulations.
- **Crash auto-capture** — if the app crashes, on next launch you'll see a dialog with the crash log file path. You can choose whether to share it in Discord. Logs contain no personal info, but you can review the file before sharing.

---

## What to Expect Week-by-Week

| Week | Build | What's New |
|---|---|---|
| Mon May 25 | A1 | Kickoff baseline — the version you started with |
| Mon Jun 1 | A2 | Week-1 fixes |
| Mon Jun 8 | A3 | Mid-alpha checkpoint week — first category-perception probe |
| Mon Jun 15 | A4 | Week-3 fixes + UX polish based on early feedback |
| Mon Jun 22 | A5 | Week-4 fixes |
| Mon Jun 29 | A6 | Final alpha build — second category-perception probe |
| Sun Jul 6 | — | Alpha window closes |

**We don't add features during alpha.** Alpha is for refining what's already there. New scope waits for beta.

**Hotfixes between weekly builds are possible** if we hit a P0 — we'll drop those out-of-band in the same Discord channel.

---

## After Alpha

When alpha closes Jul 6:

- I'll post a summary write-up in `#5pfh-alpha-feedback` covering what we learned and what changes
- Alpha testers stay in the loop — invited to the beta cohort, acknowledged in credits, get early Steam keys at 1.0 launch if you want one
- The pricing survey + category-perception data shapes the Steam Early Access launch (target late September 2026)

---

## Quick FAQ

**Q: I tried to play and X crashed. What do I do?**
A: Drop a P0 report in `#5pfh-alpha-bugs` with the save file attached. We aim to respond within 24 hours on weekdays.

**Q: Is my save going to break when I update to next week's build?**
A: We try hard to keep saves compatible across alpha builds. If a save breaks, we'll flag it loudly in the Discord build announcement. Always grab the latest build before continuing a campaign mid-week.

**Q: I'm playing on the tabletop too — can I use the app while I play?**
A: That's literally the design intent — companion app, not replacement. Tell us how the in-tandem play feels; that's the most important feedback.

**Q: I haven't played 5PFH on the tabletop before. Should I still test?**
A: We need testers who have played the tabletop game — feedback is much harder to act on without that grounding. If you'd like to play 5PFH and join later cohorts, the physical Core Rulebook is at modiphius.us/products/five-parsecs-from-home (and your tabletop play counts more than you'd think — solo is its own learning curve).

**Q: I have a friend who'd love to test.**
A: Closed alpha is invite-only via Ivan's playtesting community. Beta opens up wider in July. Forward your friend the beta-signup info when it's posted.

**Q: I want to talk about pricing in the Discord, not just the survey.**
A: Please do. The qualitative "why this price" reasoning is at least as useful as the survey numbers.

**Q: Where does my feedback actually go?**
A: To me (Elijah) directly. I read every Discord post and bug report. The results shape the back-half of alpha and the EA build. You're not yelling into a void.

---

## Thanks

Seriously — your time on this matters. The app gets meaningfully better because of what you find and what you tell us. See you in Discord.

— Elijah Rhyne
*Lead developer, 5PFH Digital*
*Discord: @reptarus | Email: elijahrhyne@gmail.com*

---

*Document v1, May 2026. Lives at `docs/testing/ALPHA_TESTER_ONBOARDING.md`. Ships with the alpha build as `ONBOARDING.md` (project root copy).*
