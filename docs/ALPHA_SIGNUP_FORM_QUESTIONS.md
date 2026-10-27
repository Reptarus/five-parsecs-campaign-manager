# Alpha Signup Form Questions (DRAFT)

**Owner**: Elijah Rhyne
**Created**: 2026-05-26 · **Last reviewed**: 2026-09-21 (checked against the build at `ca6172011`; two selection defects found and fixed, see the two notes below)
**Status**: DRAFT for review. Internal scaffolding and scoring guide above the divider; shareable form content below it.
**Workflow** (per Entry #12): Elijah builds this as a Google Form. The Modiphius dev team reviews the wording before it goes live (bias-check). The form doubles as the experience filter that whittles a large interested pool down to a focused cohort (XCOM precedent: roughly 700 interested down to 50 testers).
**Google Forms setup notes**:

- Android testing through Google Play's closed test REQUIRES each selected tester to have a Google account. We collect that Gmail as a normal question (Q2) rather than via "collect email addresses via Google sign-in", so the form stays low-friction to submit, but Q2 must be the Google account signed in on the Android device they will install on (it is the address we add to the test allowlist). Keep "limit to 1 response" OFF so a tester can resubmit to fix a typo in their Gmail.
- Elijah owns the resulting responses and tester database. Modiphius stays out of the daily workflow and amplifies the signup link on demand.
- ⚠ **The build will not install below Android 10.** `export_presets.cfg:34` sets `gradle_build/min_sdk="29"`, which is Android 10. Until 2026-09-21 Q11 asked only whether a tester owned an Android device, so a tester on Android 9 could pass the filter, be selected, and then be unable to install from the closed test. Q11 now captures the version band. If the floor in `export_presets.cfg` ever moves, move Q11 with it.
- ⚠ **Alpha-1 ships Standard 5PFH and the Battle Simulator only.** `src/ui/screens/mainmenu/MainMenu.gd:20` sets `A1_BUILD := true` and `_apply_a1_scope()` at `:257` dims Co-op, Bug Hunt, Planetfall and Tactics to a "Coming in a later release" note. Q6 still asks which modes a tester has played, because that is useful for later cohorts, but it must not drive selection for this one.

**House style**: no em dashes.

## Internal scoring / triage guide (do NOT put in the live form)

Hard filters (a "no" usually screens out for alpha-1):

- Has played 5PFH on the tabletop, at least a little (Q5). The app is a campaign manager; without table ground-truth, feedback is shallow.
- Has an Android device running **Android 10 or newer** (Q11) with a Google account (Q2). The alpha installs through Google Play's closed test and the build's floor is `min_sdk 29` (`export_presets.cfg:34`), so an older device cannot install it at all. Android is the only platform we can ship to: `steam_appid.txt` holds `480`, Valve's public Spacewar placeholder rather than a real App ID, and `export_presets.cfg` has no iOS preset at all (its three presets are Android, Linux and Windows Desktop), so do not tell an applicant that other platforms are coming (owner instruction, 2026-09-21).
- Can commit roughly 2 to 3 sessions a week for about 6 weeks (Q10).
- Comfortable using Discord (Q12).
- Agrees to the closed-alpha terms (Q16).

Ranking signals (to pick the strongest from those who pass):

- Depth of tabletop experience (Q5, Q7): more play means better ground truth.
- Digital-tabletop-tool experience + critical eye (Q13): have they used the kind of product we are building, and can they say what they would change? The "what you wished was different" half surfaces critical thinking, which now stands in for a dedicated feedback-willingness question.
- Prior playtest experience, digital or tabletop (Q8, Q9).
- A clear, motivated answer to "what draws you to this" (Q14).
- ~~Mode breadth (Q6) if we want coverage across Standard, Bug Hunt, Planetfall, and Tactics.~~ **Does not apply to the Alpha-1 cohort (struck 2026-09-21).** Alpha-1 reaches only Standard 5PFH and the Battle Simulator, so scoring a tester up for Bug Hunt, Planetfall or Tactics experience selects for coverage this build cannot exercise. Score on Standard-campaign depth instead. Keep the Q6 answers on file for the cohort that gets those modes.

Cohort size: set by Elijah (and Modiphius) per phase. The funnel is built to whittle a large pool down to the strongest testers; the exact number is a separate decision (alpha-1 leans small and deep). This guide selects for fit; it does not fix a headcount.

---

=== SHAREABLE CONTENT BELOW ===

## Five Parsecs From Home Companion App: Alpha Tester Signup

Thank you for your interest in helping test the Five Parsecs companion app. This short form helps us put together a focused group of testers. It takes about five minutes. Please answer honestly. There are no wrong answers, and telling us you are not a fit for this round is genuinely useful.

### Section 1: How to reach you

1. Name or handle (what should we call you?) [short answer]
2. Google account email (Gmail) [short answer] (this is how we will contact you, and because the Android test installs through Google Play it is also the account we add to the test, so please give the Gmail signed in on the device you will test on)
3. Discord username (we run the alpha through a private Discord and will assign you a tester role) [short answer]
4. Country and rough time zone (helps us schedule check-ins and time the build drops) [short answer]

### Section 2: Your Five Parsecs experience

5. Have you played Five Parsecs From Home on the tabletop? [multiple choice]
   - Yes, a lot
   - Yes, a little
   - I own it but have not really played yet
   - No, I have not played it

6. Which of these have you played? (Select all that apply) [checkboxes]
   - Standard Five Parsecs campaigns
   - Bug Hunt
   - Planetfall
   - Tactics
   - Five Leagues from the Borderlands
   - Other Modiphius games
   - None of these yet

7. How long have you been playing solo or small-group tabletop RPGs and wargames? [multiple choice]
   - Less than a year
   - 1 to 3 years
   - 3 to 10 years
   - More than 10 years

### Section 3: Testing experience

8. Have you helped playtest a digital product (an app or video game) before it released? [multiple choice]
   - Yes, in an organized playtest
   - Yes, informally
   - No

9. Have you helped playtest a tabletop game before it was published? [multiple choice]
   - Yes
   - No

### Section 4: Fit for this alpha

10. The alpha runs for about six weeks and works best if you can play a couple of sessions a week. Can you commit to that? [multiple choice]
    - Yes
    - Maybe, some weeks
    - No

11. The alpha runs on Android to start: you install it on your phone or tablet through Google Play. The app needs Android 10 or newer. Which of these describes the device you would test on? [multiple choice]
    - Yes, and it runs Android 10 or newer
    - Yes, but it runs Android 9 or older
    - Yes, but I am not sure which version of Android it runs
    - No, I do not have an Android phone or tablet

12. We gather feedback through email, short surveys, and Discord, with Discord being the fastest channel and your direct line to the developer. Are you comfortable using Discord for that day-to-day contact? [multiple choice]
    - Yes
    - No

13. Have you used any digital tools for tabletop games (campaign trackers, character builders, dice apps, virtual tabletops)? What worked, and what did you wish was different? [paragraph]

### Section 5: What you are looking for

14. What draws you to a digital companion for Five Parsecs? [paragraph]

15. Anything else you would like us to know? (optional) [paragraph]

### Section 6: Before you submit

16. Please confirm you understand the following: [checkboxes, all required]
    - This is an early closed alpha. It works, but it has rough edges and is not finished.
    - I will keep screenshots, streams, and recordings private until the team opens things up publicly.
    - If anything about Modiphius's other projects comes up incidentally, I will keep it confidential.
    - I understand testers are credited as playtesters after completing the program, and that this is not paid work.

Thank you. We will be in touch with everyone we bring into the alpha.
