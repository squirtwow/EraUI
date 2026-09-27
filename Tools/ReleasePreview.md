# EraUI release preview

## Standing release-review requirement

Before each release, show the user the proposed version and complete player-facing
changelog, with tested changes and features still needing testing identified.
Include any proposed cleanup separately until approved and implemented. Present
this review before committing, tagging or pushing the release that CurseForge
will package. Wait for the user's explicit release approval. Keep CHANGELOG.txt
and the in-game release notes consistent with the approved final release text.
Repeat the review if the release scope changes after approval.

## Approved 1.0.6 player-facing changelog

### Added

- Cast Progress Ring: class/custom colours, size and opacity controls. Fills during casts, drains during channels, with no interruption flash.
- Cursor Trail: independent toggle, class/custom colours, size, opacity and fade controls.
- Discard Cheapest Junk: frees the lowest-value grey stack on the initial right-click of a known lootable corpse when bags are full. Falls back to the next loot click when loot rights are unavailable. Includes Shift bypass, a chat receipt and one-stack-per-loot-window limit.
- Important Debuffs on Portraits: crowd-control icons and countdowns on player, target, focus and party portraits, marked Needs testing.
- Changelog button in /era.
- Discord button in the status window.
- All new gameplay/cursor options default off.

### Fixed

- Player cast bar jumping vertically.
- XP/status bar jumping to the screen top.
- Train-button hover highlighting while preserving purchases and profession confirmations.
- Class-tool navigation closing settings.
- Quest-level labels causing tracker rebuilds or recursive layout, with prefixes respecting available space.
- Added a centred scroll hint when more settings are below the viewport.

### Changed

- Removed redundant Configure shortcuts for Druid, Warrior, Paladin, Shaman, Priest and Warlock.
- Clearly labelled Hunter feeding and Mage conjuring/trade sections.
- Hidden ineffective Rogue/Shaman group-reminder options and unsupported Rogue reminder clicking.
- Prevented duplicate Rogue missing-poison alerts while preserving saved choices and supply tools.

### Readiness

- Final versioned regression run: **22 Lua suites / 7,020 assertions passed**, **109 Lua files parsed**. The unchanged training-source audit **1,538 checks** and notifier **8 tests** also passed in the preceding full review. The current in-game notes show 1.0.6 and the two previous releases. Existing trainer, quest/Questie, cast/XP positioning, class-reminder and persistence/reset checks pass.
- TOC validation: **87 runtime entries**, all present with no duplicates. Git whitespace checks pass. TOC/Core now read 1.0.6 following explicit final release approval; CHANGELOG.txt and Core/Updates.lua contain the same approved release bullets.
- Both new cursor textures have valid uncompressed 32-bit TGA headers, dimensions and payload sizes. The staged release archive passed validation: 328 entries under EraUI, all 87 runtime entries present, the two new cursor textures included, and Tools/.github excluded. Version 1.0.6, Interface 16001, author Squirt and all 17 shared release bullets were verified directly in the archive.
- User-confirmed: cast-bar stability, XP-bar stability, Train hover/purchasing, Changelog display, corrected HUD setting placement, the new casting ring working, and the Discord button appearing.
- Portrait aura behaviour remains unverified in-game and explicitly labelled Needs testing. Other-class layout/control behaviour is covered by the nine-class fixtures, not nine live characters.
- The user confirms the previous junk-discard path works but required looting twice. They approved the first-click refinement and said to push despite being unable to retest with currently empty bags. The refinement is now implemented and covered by 198 transaction assertions, but remains unverified in-game. Cursor trail behaviour, channel-specific ring behaviour, scroll hint and copying the Discord invite are also not explicitly confirmed. The user approved the complete updated 1.0.6 release review with these testing limitations disclosed.
- The user reported poor scroll discoverability, a deletion popup and then a blocked UNKNOWN() call while looting. The scroll hint remains implemented. The timer/popup-auto-accept deletion approach was replaced with a hardware-input-only path; the regression test reproduces the former refusal. Subsequent feedback confirms deletion works with an extra loot click; no explicit fresh status report has yet verified that blocked-call logging is clear.
- Level-up retests were error-free with taint logging off; the release notes do not claim the original taint source is conclusively identified.
- Final explicit approval received for version 1.0.6, these release notes and testing status, authorizing package verification, commit, annotated tag and push.

## Current local changes since published 1.0.5

The approved release version is 1.0.6. The in-game Changelog displays the
approved 1.0.6 notes followed by 1.0.5 and 1.0.4.

### Added

- Independent, off-by-default Cast Progress Ring and Cursor Trail controls under
  Text & Camera. Both support class/custom colours and opacity; cast diameter
  keeps an outer gap around the existing cursor ring, and trail size/fade are
  adjustable. Casts fill, channels drain, and interruption simply hides the ring.
- Off-by-default junk discarding under Automation, using total grey-stack value
  on the initial right-click of a known lootable corpse when bags are full. If
  corpse loot rights are unavailable, the existing full-bag-error/next-click
  fallback remains available.
  Limited to one stack per loot window, with
  Shift/combat/cursor checks and a linked chat report after confirmed deletion.
  Automatic loot gets one retry once space is freed; manual looting stays manual.
- Discord invite button in the status/error-report footer using the existing
  copy-link window and public EraUI invite.
- Optional Important Debuffs on Portraits for player, target, focus and party
  frames. Displays the highest-priority supported crowd-control icon, cooldown
  sweep and remaining time. Off by default. The enable setting is marked
  **Needs testing** because client behaviour has not yet been verified.
- Changelog button at the bottom of `/era`, opening the current and two prior
  releases in the scrollable notes window.

### Fixed

- Important Debuffs on Portraits now has its own HUD row instead of overlapping
  Match Focus Size. The shared HUD layout is checked for card collisions on all
  nine classes. The portrait feature itself remains marked Needs testing.
- Train button draws the same Classic highlight as Exit using only a texture on
  its existing mouse-disabled artwork. A small visible-only cursor-geometry check
  controls the glow; no extra input frame covers the native purchase button.
  Highlight clears when leaving, disabling, hiding or entering combat. Earlier
  attempts either failed to highlight or intercepted clicks. The latest revision
  passes trainer checks, and the user confirmed hovering and purchasing now work.
- Player cast-bar placement updates immediately after native layout rather than
  jumping vertically on a timer. The user confirmed the casting fix works.
- XP/status-strip anchor recovery happens immediately after native repositioning,
  preventing the observed brief jump to the screen top. The user reports the
  XP bar is now staying in place; separate incoming-damage cases were not detailed.
- Class-tool and reminder navigation shows/focuses the intended controls rather
  than toggling settings closed. Hunter/Mage inline options and Rogue's separate
  poison-supply window retain their own navigation routes.
- Quest-level labels no longer trigger native tracker rebuilds or recursively
  recalculate header layout. Labels remain cosmetic and skip prefixes that would
  clip or expand titles. Subsequent level-up retests were error-free with taint
  logging off, including the requested Questie-enabled retest; the original
  taint's exact origin is not proven.
- Changelog uses a foreground dialog layer to prevent settings controls drawing
  through it. The user confirmed opening the changelog now works correctly.

### Changed

- Removed redundant Configure shortcuts for Druid, Warrior, Paladin, Shaman,
  Priest and Warlock. Their Class Reminders & Buffs options remain directly
  available on the class page.
- Hunter and Mage inline sections are now non-clickable option headings:
  Pet Feeding Options and Conjuring & Trade Options. Their controls remain below.
- Reminder options follow actual class capabilities: party/raid checking is
  hidden for Rogue/Shaman and unsupported reminder clicking is hidden for Rogue.
  Saved preferences are preserved.
- Dedicated Rogue Poison Reminders suppresses duplicate generic missing-poison
  alerts while enabled. Turning it off restores the generic alerts according to
  saved choices. Settings explain which feature handles the alerts; time/charge
  warnings and the separate purchase/crafting tools remain available.
- Prepared CurseForge description places the Discord badge/support link below
  the title. Existing screenshot layout is retained. Publication is unverified.

## Nine-class redundancy audit before cleanup, 2026-09-27

This is a source/control-flow review, supported by the existing nine-class settings
layout/navigation suite. It does not replace live-client testing of every class.

| Class | Configure card / tool controls | Additional finding |
| --- | --- | --- |
| Druid | Redundant card already removed. Reminder options are inline. | Resource Bar switches between mana/energy/rage, so separate class resource toggles are correctly filtered out. |
| Warrior | Configure only focuses existing reminder controls. Redundant. | Rage Bar and melee Swing Timer have separate functions. Party checking applies to Battle Shout. |
| Paladin | Configure only focuses existing reminder controls. Redundant. | Mana, melee timing, blessing choices, seals and auras have distinct functions. |
| Shaman | Configure only focuses existing reminder controls. Redundant. | Party/raid reminder checking has no effect: current definitions check own shield, own weapon, active totems and cooldowns. |
| Priest | Configure only focuses existing reminder controls. Redundant. | Mana, wand timing and buff reminders have distinct functions. |
| Warlock | Configure only focuses existing reminder controls. Redundant. | Creating a Soulstone and checking whether it is applied are distinct reminders. |
| Hunter | Configure is a non-clickable header anchoring useful feeding options. | Rename to Pet Feeding Options. Feeding/happiness, missing pet and dead pet cover different states. |
| Mage | Configure is a non-clickable header anchoring conjure buttons and trade quantities. | Rename to Conjuring & Trade Options. Conjuring Suggestions and Auto-fill Trade have separate behaviour. |
| Rogue | Configure opens the actual poison-supply window, so it is useful. | Generic missing-poison alerts overlap the separate Poison Reminders module. Party/raid checking and click-to-cast options have no effect for the current two generic poison definitions. |

Evidence: Core/Settings.lua class filters, inline panels and Configure callbacks;
Modules/ClassTools.lua ActiveModule/Open; Modules/ClassReminders.lua
BuildOptions/UnitsToCheck/DefState/ClickSpell; Modules/ClassReminderData.lua;
Modules/HunterFeed.lua Attach; Modules/MageSupplies.lua Attach;
Modules/RoguePoisons.lua Open; Modules/PoisonReminders.lua Snapshot/Refresh.

## Approved cleanup, implemented locally

1. Remove the five remaining reminder-only Configure cards: Warrior, Paladin,
   Shaman, Priest and Warlock. Keep their inline reminder controls and command routes.
2. Make Hunter/Mage inline sections clearly labelled option headers instead of
   Configure button-style cards. Keep their attached controls and navigation anchors.
3. Hide party/raid checking for Rogue/Shaman and click-to-cast for Rogue, based
   on actual supported reminder capabilities. Preserve saved preferences.
4. Let the dedicated Rogue Poison Reminders handle missing-poison warnings while
   enabled, suppressing duplicate generic poison alerts. Keep its time/charge
   warnings and the independent Poison Supplies purchase/crafting feature.

The user approved all four items. The runtime changes are now included above.
Verification: settings layout (1,508), reminder click/deduplication lifecycle (65),
reminder detection (81) and hunter feeding (59) pass, totaling 1,713 assertions.
All four changed Lua files parse. The new HUD collision assertion failed on the
previous overlapping placement and passes for all nine classes after relocation.
The user has since shown the corrected Druid/HUD layout and accepted the testing
label presentation. The complete 1.0.6 release has since been explicitly approved.
