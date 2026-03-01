# Post-Launch Support Plan

## 1. Overview

This document outlines the strategy and procedures for providing player support after the official launch of the game. A clear and responsive support plan is crucial for maintaining player trust, gathering valuable feedback, and improving the game over time.

## 2. Support Channels

We will provide several channels for players to report bugs, ask questions, and give feedback. All channels should be clearly linked from within the game and on the main website.

-   **Primary Channel (Bugs):** The **In-Game Bug Reporting Tool**. This is the preferred method for bug reports as it provides structured, technical data.
-   **Secondary Channel (Discussion & Feedback):** The **Official Discord Server**. A dedicated `#feedback-and-suggestions` channel will be created.
-   **Tertiary Channel (General Inquiries):** **Support Email** (`support@yourgame.com`). For account issues, payment problems (directing them to the storefront), or other inquiries not suitable for public channels.
-   **Platform-Specific Forums:** **Steam Community Hub**. We will monitor the forums for feedback and bug reports, but will always encourage users to use the in-game tool for bugs.

## 3. Bug Triage and Prioritization

All bug reports, regardless of channel, will be triaged and categorized to ensure we address the most critical issues first.

### 3.1. Triage Process

1.  **Collection**: All reports from Discord, email, and Steam forums will be manually converted into issues in the private GitHub bug-tracking repository, matching the format of the automated reports.
2.  **Reproduction**: A bug report is not confirmed until we can reproduce it. The attached save games and logs from the in-game reporter are critical for this step.
3.  **Labeling**: Each confirmed bug will be labeled in GitHub with:
    -   **Priority**: `P0-Critical`, `P1-High`, `P2-Medium`, `P3-Low`.
    -   **Category**: `UI/UX`, `Combat`, `Campaign`, `Crash`, etc.
    -   **Status**: `Needs-Repro`, `Confirmed`, `In-Progress`, `Fixed-In-Next-Patch`.

### 3.2. Priority Levels

-   **P0 - Critical**: Game-breaking bugs. Crashes, corrupted save files, inability to progress in the campaign. **Requires an immediate hotfix.**
-   **P1 - High**: Bugs that significantly impair the gameplay experience but don't stop it entirely. (e.g., A psionic power not working, incorrect mission rewards).
-   **P2 - Medium**: Bugs that are noticeable but have workarounds or are minor annoyances. (e.g., A typo in an event, a minor UI visual glitch).
-   **P3 - Low**: Very minor issues that have little impact on gameplay.

## 4. Patching Strategy and Cadence

-   **Hotfixes (e.g., v1.0.1)**:
    -   **Trigger**: Deployed as soon as possible after a `P0-Critical` bug is identified and fixed.
    -   **Content**: Contains only the fix for the critical issue.

-   **Minor Patches (e.g., v1.0.2)**:
    -   **Cadence**: Aim for a regular schedule, such as every 2-4 weeks, depending on the volume of reported issues.
    -   **Content**: Will include fixes for `P1-High` and `P2-Medium` bugs, as well as minor quality-of-life improvements.

-   **Major Updates (e.g., v1.1.0)**:
    -   **Cadence**: As-needed for new content or significant feature changes (e.g., future DLC).
    -   **Content**: Will include new features and any outstanding bug fixes.

## 5. Player Communication

-   **Patch Notes**: Every update, no matter how small, will be accompanied by clear and detailed patch notes posted on Steam, Discord, and the game's website.
-   **Known Issues List**: A public list of `P1` and `P2` bugs that are confirmed and being worked on will be maintained (e.g., a pinned thread in the Steam forums or Discord). This manages player expectations and reduces duplicate reports.
-   **Community Engagement**: We will actively engage with players on Discord and Steam, acknowledging their feedback and providing updates on the status of key issues.
