# EraUI release audit: 2026-09-27

## Final 1.0.6 approval and versioned checks

The user explicitly approved the complete final 1.0.6 changelog and testing
status, including the first-click refinement being untested in-game and the
portrait Needs testing label. Commit, annotated tag and push are authorized.
TOC and Core versions are now 1.0.6. CHANGELOG.txt and Core/Updates.lua carry the
same 17 approved bullets, and the in-game window retains 1.0.5 and 1.0.4 history.

Final versioned full checks: 22 Lua suites / 7,020 assertions, all 109 Lua files
parse, whitespace checks pass. The new note history increases TestUpdates from
54 to 63 assertions; all other totals are unchanged. Prior training-source audit
1,538 checks and notifier eight tests passed with their inputs unchanged.
Remote main was verified at the published 1.0.5 commit 49b79e9, with no remote
1.0.6 tag. Git author identity is Squirt with the established noreply address.

Staged package validation passed: 328 ZIP entries under EraUI; all 87 runtime
entries present with no duplicates; new portrait/cursor/junk modules and both
cursor textures included; Tools/.github and unrelated addon payloads excluded.
The archive's Interface 16001, author Squirt, TOC/Core version 1.0.6 and identical
17-bullet packaged/in-game changelogs were checked directly. Candidate archive:
C:\Users\beauh\AppData\Local\Temp\opencode\EraUI-1.0.6-validated.zip.
Local main and fetched origin/main were identical before the release commit.

## Approved first-click refinement and final review preparation

The user approved automatic bag checking on the first lootable-corpse click,
reported their bags are now empty so a new live test is unavailable, and gave
general permission to push. The standing complete version/changelog/testing
review still precedes final release approval, so no release action was taken.

JunkDiscard now recognizes a genuine right-button WorldFrame mouse-down on a
dead mouseover unit with a public GUID and public, affirmative CanLootUnit loot
rights. It checks bag space and selects/revalidates the grey stack during that
same hardware callback. A short opening-state allowance carries the one-attempt
limit into LOOT_READY/LOOT_OPENED. It expires if no session opens. Mouse-up,
left-clicking, unknown/restricted loot rights, missing APIs, living targets,
Shift, combat, existing free space and an occupied cursor do not initiate this
preflight. The existing full-bag-error/next-input path covers unavailable loot
rights and other loot sources. There is no destructive timer or popup auto-click.

Tests cover initial click before and after native loot-ready delivery, transfer
of the per-session allowance, later loot sessions, expiration, asynchronous bag
confirmation and native autoloot flags. Full current run: 22 Lua suites / 7,011
assertions; all 109 Lua files parse; git whitespace checks pass. Junk transactions
account for 198 assertions and nine-class settings for 3,637. The preceding
training-source audit and notifier checks remain valid (1,538 and eight).

The first-click refinement remains untested in the Forever client. The casting
ring and Discord button visibility are client-confirmed; trail behaviour and
channel-specific direction are not explicitly confirmed. Portrait CC remains
marked Needs testing. Tools/ReleasePreview.md contains the complete updated
proposed 1.0.6 release notes and these remaining client-test limitations.

## Client confirmation and remaining extra loot click

The user reports: "it works, but need to loot twice for it to do it", "casting
ring is working", and "discord button is showing". Record casting-ring operation
and status-button visibility as confirmed. This does not independently verify
channel direction, cursor trail, copying the invite or a clean fresh blocked-call
report. Junk deletion is functioning, but its current error-first request logic
requires another hardware input, explaining the reported extra loot click.

A first-click refinement is being proposed for approval. No runtime changes were
made in this follow-up, and no release action has been authorized or performed.

## Full regression recheck before requested push assessment

The user asked whether anything remained before pushing and whether recent work
had broken other features. A fresh full run on the current tree passed all 22 Lua
suites / 6,920 assertions, all 109 Lua syntax parses, 1,538 training-source checks
and all eight notifier tests. All 87 TOC entries exist with no duplicate paths.
The two generated cursor textures have valid uncompressed BGRA TGA headers and
payload sizes (128x128 ring, 32x32 trail). Whitespace checks pass.

These checks include trainer purchasing/hover fixtures, quest presentation and
Questie integration, cast/XP positioning, nine-class settings/reminders, saved
settings and reset recovery. No regression was detected by those checks. Client
confirmation is still needed for the latest hardware-input loot repair, cursor
effects and the scroll hint/Discord link. Portrait CC remains explicitly marked
Needs testing. After those confirmations, present the full updated proposed 1.0.6
notes and testing status for approval before version/notes finalization and
release actions. No commit, tag, push or release was made during this assessment.

## Looting UNKNOWN() follow-up: hardware input and Discord support link

The user reported a blocked UNKNOWN() at 13:29:05 and confirmed it occurred while
looting. The on-disk General.log had no matching current event, so there is no
captured stack proving that individual call. Inspection identified a concrete
defect: the new module called DeleteCursorItem from a timer, despite the API's
hardware-event requirement. The previous mocks did not model that restriction.
Adding the restriction made the old test fail (expected deletion, got zero).

The user reiterated RXP's enable-once, no-confirmation behaviour and requested
a Discord link on the status page. RXP was inspected only as a technique reference:
its deletion is tied to real mouse input, not an asynchronous timer. EraUI now
queues intent on a full-bag loot error and executes its own stack-selection and
deletion code from normal WorldFrame mouse-down/up or native loot-button clicks.
The input hooks retain normal click behaviour and are installed once per frame.
No destructive timer callbacks or popup-acceptance hook remain. Selection is
revalidated at input time, with the existing Shift/combat/cursor checks, one-stack
limit, verified chat receipt and automatic-loot retry. Closing loot clears intent.
The earlier popup-acceptance approach documented below is superseded.

Classic/Status.lua now includes a Discord footer button, using the existing
ns.CopyLink window and the public https://discord.gg/FVfcDWJncr invite. The five
footer buttons fit the existing 560-wide window, and the instructions point to
Discord for support, bugs and ideas. The URL is shared from Classic/Welcome.lua.

Verification: TestJunkDiscard passes 107 assertions, with DeleteCursorItem refusing
all non-hardware execution in the mock. Tests cover passive-event inactivity,
real world/loot clicks, no duplicate input hooks, normal loot-click preservation,
Shift/combat/cursor changes before input, asynchronous receipts and existing stack
selection/restoration cases. TestSettingsLayout passes 3,637 assertions; total
affected assertions 3,744. All five changed Lua files parse. The latest combined
22-suite assertion count is 6,920. In-game repair confirmation remains pending;
no version update, commit, tag, push or release has occurred. Keep taintLog at 0.

## Client follow-up: scroll hint and automatic junk confirmation

The user supplied screenshots of the long Text & Camera page and a native
"Do you want to destroy Cracked Shortbow?" prompt. They requested a centred
bottom scroll hint and deletion without having to accept a confirmation.

SettingsLayout now reserves a 22-pixel band below the clipped options viewport,
above the footer, for "Scroll down for more options". Visibility follows the
remaining scroll range on every page, search, layout change and scroll. The
hint disappears at the bottom or when the page fits. Setup mode uses the same
reserved bottom boundary so the hint cannot overlap cards or footer controls.

JunkDiscard now owns a short-lived deletion transaction before DeleteCursorItem.
A secure post-hook on StaticPopup_Show accepts only DELETE_ITEM with nil dialog
data, the exact selected cursor item ID/link, matching loot-session generation,
and still-enabled/out-of-combat/non-Shift conditions. It invokes the native
StaticPopup_OnClick(dialog, 1) acceptance path, guarded against recursive/repeated
acceptance. It supports a next-frame popup before its bounded restoration fallback.
Manual, pre-existing, quest/valuable and GUID-based dialogs are not auto-accepted.
Verified deletions retain the linked chat receipt and one automatic-loot retry.

Verification: junk transactions pass 86 assertions, including immediate/deferred
native confirmations, one-time acceptance, changed cursor, disabled option, closed
loot and unrelated dialogs. Nine-class settings/navigation pass 3,637 assertions,
including hint visibility, bottom/up scrolling, empty search and geometric footer
clearance. Total affected checks: 3,723. All five changed Lua files parse and git
whitespace checks pass. Client confirmation of both repairs is pending. No release
action occurred; the current combined 22-suite assertion total is 6,899.

## Approved scope expansion: cursor effects and full-bag junk discarding

The user approved a cursor cast ring and trail before release, explicitly without
the suggested red interruption flash. They then approved the full-bag cheapest
junk feature under Automation and requested a linked chat message like the
provided screenshot. The existing cursor category is Text & Camera, not Extras;
this was corrected in the conversation and the new controls remain beside the
existing ring there. All three features default off and apply live after loading.

CursorEffects is independent of the original CursorRing and cast-bar modules.
The native Cooldown widget consumes original annulus artwork for a filling cast
sweep or draining channel sweep. Public timing uses CastTiming, preserving the
channel scale after pushback; opaque timing uses the supported native duration
object path when available, otherwise hides. No native cast bar is modified.
The trail reuses a fixed 160-texture pool, emits only on movement, fades in
0.10-0.60 seconds, and clears on cursor warps/disable. Disabled effects have no
OnUpdate, and a cast-only setup has no idle polling. Effect frames disable mouse
input. Class/custom colours, sizes and opacity are saved; picker cancellation
restores both the prior colour and class-colour mode. Artwork and the generator
are original: Media/CursorCastRing.tga, Media/CursorTrailDot.tga and
Tools/GenerateCursorEffects.mjs.

JunkDiscard waits for ERR_INV_FULL during an active loot session. It considers
only unlocked, non-quest grey stacks in general-purpose bags, compares total
vendor value, and declines selection when an eligible price is unavailable.
It checks Shift, combat, cursor occupancy and the exact chosen stack before
pickup/deletion. There is at most one attempt per loot window, and rejected
deletion restores the owned cursor item when possible. A linked chat receipt is
printed only after empty cursor/bag state confirms deletion; delayed bag updates
are supported. Automatic loot has one retry after that confirmation, and stale
or closed-session callbacks cannot retry loot. No deletion outside looting.

Verification: 22 Lua suites pass, with a current combined total of 6,821 assertions.
The full run passed 6,814; subsequent asynchronous-deletion coverage increased
JunkDiscard from 55 to 62 passing assertions. CursorEffects passes 42 assertions,
and settings passes 3,583 including collision checks for HUD, Automation and
Text & Camera on all nine classes, plus picker preview/cancel behaviour.
All 109 Lua files parse; the final two edited junk files were reparsed. All 87
TOC entries exist with no duplicates. Native Cooldown and Classic colour-picker
API shapes were checked against the existing pinned Blizzard-source reference.

Live cursor rendering, casting/channel behaviour and junk deletion still require
user testing. Existing portrait Needs testing status remains. The release preview
includes these additions, so the previous release review is superseded. Version
metadata remains 1.0.5; no commit, tag, push or release is authorized or performed.

## Proposed 1.0.6 pre-release review

The user asked whether it is time to push. In accordance with the standing
pre-push review requirement, the complete proposed 1.0.6 player-facing changelog
and readiness status are in Tools/ReleasePreview.md for explicit approval first.

Full current-working-tree checks pass: 20 Lua suites / 4,642 assertions; all 105
Lua files parse as Lua 5.1; training-source audit 1,538 checks with 1,398 packaged
entries; notifier 8 tests. All 85 TOC runtime entries exist with no duplicates,
including PortraitDebuffs; whitespace checks pass. Existing version metadata
remains 1.0.5, and 1.0.6 has no local tag. Final version/notes and package checks
must follow release approval before committing/tagging/pushing.

Client confirmations cover cast bar, XP bar, Train hover plus purchasing,
Changelog layering and the corrected HUD option placement. Portrait debuff
behaviour is still untested in-game and remains off by default with a visible
Needs testing label. Nine-class checks are simulated layout/control checks.
The level-up results are recorded without claiming a proven universal taint fix.
No commit, tag, push or CurseForge release was made during this readiness review.

## Approved class cleanup and portrait-setting overlap repair

The user approved the all-class cleanup, then supplied a HUD screenshot showing
Important Debuffs on Portraits overlapping Match Focus Size. Both settings had
been assigned category 1, column 1, row 3. This was a shared HUD slot collision,
not a Druid-specific conditional. The portrait option now occupies column 0,
row 4. A geometric pairwise HUD collision check failed before this move and now
passes for all nine classes, with both affected options remaining visible.

Reminder-only Configure shortcuts are now filtered out for Druid, Warrior,
Paladin, Shaman, Priest and Warlock. Hunter/Mage cards remain inline attachment
anchors, but are ordinary non-interactive Frames with neutral header styling and
specific Pet Feeding Options / Conjuring & Trade Options titles. Rogue's real
poison-supply window remains reachable. The normal class page compacts around
the retained entries, and the same visibility filter applies to search.

Reminder definitions determine whether group checking or click-to-cast is useful.
Rogue/Shaman group controls and Rogue clicking are hidden without overwriting
saved choices. Dedicated Poison Reminders suppresses generic Rogue poison rows,
including preview duplicates. Toggling it refreshes generic alerts and the inline
ownership explanation immediately. Disabling it restores generic alerts from
their saved individual preferences; dedicated time/charge warnings and supply
purchasing/crafting remain separate functions.

Verification: actual settings and navigation across nine classes pass 1,508
assertions; reminder click/deduplication lifecycle 65; detection 81; hunter feeding
59. Total 1,713. All four changed Lua files parse. Tests cover capability-filtered
options, HUD collision avoidance, inline headers, saved preferences and duplicate
alert suppression/restoration. Live HUD/class-layout review is pending. All work
remains local; the updated release preview must be reviewed before release.

## Approved repair: Train button hover feedback (client confirmed)

The user showed Exit highlighting normally while Train had no visible hover
feedback. They approved mirroring the transparent native TrainButton's hover
onto the Classic artwork. Native OnEnter/OnLeave and enabled/hidden transitions
now lock/unlock only the addon button's existing highlight. Eligibility refreshes
recheck the pointer, and the combat input blocker's visibility clears/restores
the cosmetic state. No native purchase or selection handler is replaced.

The actual trainer regression suite passes 180 assertions, including hover,
leave, immediate native-disable and combat-blocker transitions alongside native
purchase forwarding, pet requirements, offscreen services and profession
confirmation. Both changed Lua files parse. ReleasePreview.md includes the repair;
it remains local and awaits visual confirmation in the client.

Client retest: the first hover mirror still produced no visible highlight. Its
mock checks proved callbacks and ownership only, not that the alpha-zero native
button emits usable hover events or that LockHighlight paints a mouse-disabled
button on this client. The exact failed runtime step remains undetermined.

The repair was revised within the approved hover scope: a visible motion-only
frame sits above the native TrainButton, with mouse clicks disabled. It draws an
explicit OVERLAY copy of the existing Classic highlight texture, using the same
texture coordinates and ADD blend as Exit. Its own OnEnter/OnLeave drive that
texture; native enabled/hidden transitions and the combat shield still clear it.
The shield sits above both input and hover layers. Purchase scripts and secure
selection remain untouched. The updated trainer fixture tests visible texture
state without emitting native hover events, verifies click-through flags and
frame ordering, and retains purchase/confirmation checks. All 189 assertions
pass, both Lua files parse. This revised visual implementation awaits client test.

Second client retest: the glow worked, but purchasing no longer did. The motion-only
frame above native Train was implicated by that change; setting click input false
had not provided the expected pass-through on Forever. The original regression
fixture invoked the native button directly, bypassing UI hit testing. A narrow
pointer-routing model covering the observed motion-layer interception now fails
on that implementation (expected selected service 2, purchase remained nil).

The extra frame and all its mouse handling have been removed. The glow is a plain
texture on the original mouse-disabled Classic button. Only that visible button
checks cursor bounds at 0.05-second intervals, accounting for effective scale and
rejecting unavailable/restricted geometry. Native purchase remains the top input
target outside combat; the existing combat blocker retains its original level.
The trainer suite now passes 187 assertions, including pointer-routed purchases,
profession confirmation, combat blocking, glow visibility and scaled hit bounds.
Both Lua files parse. The user must confirm the latest revision can both highlight
and purchase before it is considered client-verified.

Final client retest: the user confirmed the latest revision works after being
asked to test both hovering and purchasing. Train highlight and native purchasing
are now client-confirmed. The repair remains local and unreleased.

## Current review and release workflow

Latest client feedback: the user explicitly confirmed the changelog opens and
displays correctly. They also requested visible hover feedback on Train. Source
inspection found the Classic button has mouse input disabled and the transparent
native TrainButton receives input, without forwarding its hover state. A cosmetic
hover-state mirror is proposed, awaiting approval. The all-class redundancy cleanup
also remains unapproved; this new request did not authorize those removals.

The user requested a redundancy review across all nine classes and a readable
preview of changes before every Git/CurseForge release. Tools/ReleasePreview.md
records the standing review requirement, all current unreleased changes and the
nine-class source audit. Five other classes retain the same redundant Configure
shortcut removed for Druid; Hunter/Mage have useful inline panels under misleading
button-like headings. Rogue/Shaman expose ineffective group-check options; Rogue
also exposes unsupported reminder clicking and overlapping poison alerts. Proposed
cleanup is listed separately and awaits approval. No runtime changes were made
during this audit, and no commit, tag, push or release was performed.

## Approved repair: XP strip flashes at screen top (client reported working)

The user reported the XP bar briefly jumping from the bottom to the screen top
while repeatedly casting Wrath, and possibly while taking melee/ranged damage.
Inspection found status geometry was recovered by StatusMoved/StatusBack on a
0.1-second poll. A native anchor reset can therefore render before recovery.
The exact live triggering callback has not been captured.

With approval, ClassicBar now remembers the anchors it assigns to each status
container, child bar and fill. Post-hooks on SetPoint/SetAllPoints and, where
available, ApplySystemAnchor restore those anchors synchronously. These hooks
perform only anchor recovery, not a full skin pass or native manager rebuild.
The latest explicit EraUI layout updates the desired anchors, including XP/rep
container swaps. Guards cover recursive writes, addon disable/restore, active
layout work, Edit Mode, dragging, restricted geometry and combat protection.
Deferred anchors are checked again on combat exit. The existing size/skin
fallback remains and now preflights combat protection for the whole strip.

TestStatusBarPosition loads the actual ClassicBar module and first failed on the
old code because a native XP reset still pointed at UIParent before a poll.
All 117 assertions now pass. Coverage includes repeated native resets, XP child
and fill anchors, combat, Edit Mode, disabling, role swaps, restricted geometry,
and the actual cast and XP placement paths running together during repeated
cast starts and mid-cast managed layouts. Existing cast position (56) and channel
timing (24) checks also pass, totaling 197 assertions. Both Lua files parse, and
the full-module tests verify the Lua local-variable limit. Client verification
of Wrath spam and incoming damage is still required. Local and unreleased.

Client follow-up: the user reports the XP bar seems to be working and no longer
appears at the screen top. This confirms the observed jumping has stopped in
their retest; separate melee/ranged scenarios were not explicitly detailed.

## Approved feature: important debuffs on portraits (awaiting client test)

Client follow-up: the user cannot currently test the feature with their available
characters and requests a visible "Needs testing" or work-in-progress label.
Portrait CC behaviour remains unverified in-game. Ordinary Concussive Shot is a
slow and is deliberately outside the current CC list; Freezing Trap or Entangling
Roots are supported examples once learned. A changelog entry point in /era was
also requested; presentation changes are awaiting the proposed scope's approval.

The user approved the footer changelog and clarified that the testing label belongs
where the option is enabled. The HUD setting now displays a yellow "Needs testing"
line beneath its title; its tooltip explains the unverified status, supported CC
and exclusion of ordinary Concussive Shot. The Changelog footer button opens the
existing scrollable current-and-two-prior release notes and brings that window
to the front. It is hidden during onboarding to leave the setup navigation clear.
Existing settings layout (1,183) and update-note scrolling (54) checks pass,
totaling 1,237 assertions. Three Lua files parse. Local and awaiting client review.

Changelog client follow-up: the screenshot showed settings controls interleaved
with the notes. Both windows used DIALOG; raising the notes window did not place
its backdrop above all settings descendants. With approval, the notes tree now
uses FULLSCREEN_DIALOG, above the settings and its DIALOG action overlays. The
cursor ring remains on its existing TOOLTIP layer. Existing update-note (54) and
settings (1,183) checks pass and Updates.lua parses; live layering needs a retest.

The user also asked about Configure Druid Tools appearing unresponsive. Its actual
route is ClassTools:Open -> ClassReminders:Open -> ShowClassControls, which focuses
the already-visible reminder options rather than opening a separate Druid window.
Existing nine-class navigation checks pass. This does not establish whether the
live click was intercepted by the overlapping changelog or simply had no obvious
visual effect. No class-tool behaviour change was made with this layering repair.

Subsequent Druid confirmation: the user reports the Configure button only scrolls
the page. They approved removing that redundant Druid card. It is now excluded
from the Druid class page and search through the existing class-visibility filter;
the page compacts around the remaining controls. Class Reminders & Buffs and its
Advanced options remain the direct configuration route. The existing class-tools
navigation test now uses the module route when a Configure card is hidden.
Settings layout/combat checks pass with 1,175 assertions. Local and unreleased.

The user approved an original portrait-only crowd-control indicator for player,
target, focus and the four native party portraits. Modules/PortraitDebuffs.lua
adds masked, click-through spell icons, a circular dark cooldown sweep and a
yellow countdown inside the current portrait rim. One effect wins: stun first,
fear/incapacitation next, then silence and root; equal priorities prefer the
longer remaining effect. The initial spell list covers Classic player CC ranks,
selected pet effects, procs and racials. Unknown/custom Forever IDs are not
classified automatically. Ordinary damage and slows do not replace portraits.

The HUD setting "Important Debuffs on Portraits" is off by default, requires
Unit Frames and refreshes immediately. It uses the normal settings persistence
and reset lifecycle. Reload once to load the new module before enabling it.

Native portraits remain untouched underneath addon-owned overlays. The module
does not rebuild native trackers, change secure unit controls or resize raid
debuffs. It scans harmful auras on unit/target/focus/roster events and maintains
countdown text only while an overlay is visible. Expiry selects the next valid
effect, and target changes, pooled party reuse, removals and disabling clear
stale icons. New displays are deferred out of combat; existing cosmetic displays
can update in combat when aura data is public. The client secret-aura policy is
checked before querying, guarded reads handle unavailable access, and restricted
identifiers/timing restore the ordinary portrait rather than being compared.

Verification: TestPortraitDebuffs passes 90 assertions against the actual module,
including priority, dispel/expiry fallback, all seven units, aliases, pool reuse,
restricted fields/access, combat deferral, click-through and native ownership.
Related settings layout (1,183), persistence (66), reset (65) and aura styling
(78) suites also pass, for 1,482 assertions. All four new/changed Lua files parse.
Actual portrait layering, circular swipe appearance and public combat aura
availability still require the user's client test. Local only, not released.

## Post-release finding: player cast-bar position flicker (client confirmed)

The user reported the player cast bar jumping vertically on every Wrath, Healing
Touch and other cast. ClassicBar repositioned it only on a 0.1-second poll while
Blizzard's OnShow registers it with the managed-frame layout, which resets its
anchors. That leaves the native position visible until the next addon tick.

With approval, the cast-placement poll is removed. Placement runs immediately
after native OnShow, bottom managed-container Layout, system-anchor and bar-scale
updates, and after EraUI's own band layout. Layout/visibility events cover pet,
stance and status-row changes. Hooks are installed once per bar/container, with
replacement containers discovered on show. Native cast state and Edit Mode
settings are not overwritten. Custom positions, dragging, Edit Mode previews,
player-frame attachment and Advanced Cast Bar are respected; protected bars are
not moved in combat. Geometry checks skip restricted/unavailable coordinates,
and optional missing bars no longer truncate the clearance scan.

TestCastBarPosition loads the full ClassicBar module, supplying band geometry via
existing private upvalues. Its first-show assertion failed before the repair
(native bottom 160 instead of the fixture's required 79). All 56 position checks
now pass, including repeated casts, mid-cast layout resets, scale changes, actual
button bounds, pet clearance, native custom placement, combat and replacement
containers. Channel timing also passes its 24 assertions, totaling 80 checks.
Both changed/new Lua files pass syntax checks; loading the complete module also
verifies Lua's local-variable limit. Actual rendering still needs a client test.
The repair remains local and unreleased. No description change is required.

Client follow-up: the user confirmed the cast-bar repair works after the requested
reload and casting retest. The implementation remains uncommitted and unreleased.

## Post-release finding: level-up aura taint and diagnostic error flood

The user reported an EraUI-tainted GetAuraDataByIndex failure on a Druid level-up
at 11:11:35. General.log contains both the Edit Mode anchor-update stack and a
more detailed native tracker stack: ShouldShowMawBuffs -> ScenarioObjectiveTracker
LayoutContents -> tracker Update. The latter was called from a dirty-update
callback. The matching Blizzard reference is wow-ui-source commit
`bd2470aed543f72697a044e989285b6c83e63f73`.

After detailed taint logging was requested, nil-call errors began at 11:13:55
and spread across many hooked native methods after the 11:14 reload. These
included SetNormalAtlas, UpdateTickPosition, SetAlpha, ClearLines, UpdateTextures
and UpdateAuraButtons. With no hook changes made, the user confirmed that the
errors stopped after `/console taintLog 0` and `/reload`. This strongly implicates
the diagnostic logging mode in the flood; the exact client mechanism remains
unconfirmed. It does not establish that those hooks need replacing. Keep logging
off for the client retest. General.log records Lua errors independently, and
copies of General.log, taint.log and FrameXML.log were preserved outside the repo.

Source review found a concrete native-layout ownership problem in QoL quest-level
labels: an addon timer calls QuestObjectiveTracker:MarkDirty, and a SetHeader
post-hook recursively calls native SetHeader, writing native block.height from
addon code. These are plausible contributors to the original tracker taint, not
a proven reconstruction of that client's taint propagation.

With user approval, the local repair removes the addon-triggered dirty refresh
and recursive header-layout call. Existing/new quest labels are painted directly
on their font strings after native layout, with source text retained in a weak
addon-owned table. Prefixes are declined if they expand the allocated title
height or truncate the full title. Preference changes restore only owned text;
pooled blocks use their current quest. The Classic skin no longer adds a second
prefix during native string measurement. Native tracker state and update
scheduling are not written by this quest-level feature.

TestQuestLevelPresentation loads the actual QoL and Classic tracker modules and
forbids calls to native layout methods from addon callbacks. It failed before
the repair on the queued MarkDirty call and now passes 115 assertions, including
both hook-loading orders, default/Classic presentation, toggles, accumulated
objective height, wrapping, pool reuse, restricted data and late loading.
Reset lifecycle (65) and Questie tracker visibility (74) also pass: 254 assertions
across the three suites. All three changed/new Lua files pass syntax parsing.
These are ownership regression checks, not an emulation of the client's taint VM.
The original level-up aura error remains awaiting in-game verification. No commit,
tag or release has been made for this repair; no description revision is needed.

Client follow-up: at 11:27:34 another level-up produced the same Edit Mode aura
error, this time naming Questie. That does not establish the taint's original
writer, or prove the earlier EraUI change sufficient. Questie's local Forever
adapter also calls native ObjectiveTrackerFrame:Update when releasing suppression,
as does EraUI's compatibility adapter. No further tracker changes were made based
on that attribution alone. The user is testing the next level-up with Questie
temporarily disabled and EraUI enabled, keeping detailed taint logging off.

Subsequent client result: the user confirmed another level-up completed without
an error with `taintLog 0`, then explicitly confirmed Questie was disabled for
that test. EraUI enabled with Questie disabled therefore passed one level-up.
This supports investigating the Questie/native-tracker interaction, but does not
prove Questie alone causes the error or that the combined setup is fixed.

Combined-setup retest: after being asked to re-enable Questie and reload with
`taintLog 0`, the user reported no errors and supplied a Level 5 screenshot.
Record the requested combined-setup level-up retest as passing based on that
response. The screenshot verifies the level-up; it does not independently show
addon enablement. This is a successful client retest, not proof of the original
taint's exact source or that an intermittent recurrence is impossible.

## Post-release finding: class-tool navigation (local fix awaiting client test)

After 1.0.5 was approved on CurseForge, the user reported that Configure Druid
Tools closed settings instead of opening controls. The shared ClassReminders
Open method called Classic.OpenOptions, which delegates to the settings toggle.
That reproduces for Druid, Warrior, Paladin, Shaman, Priest and Warlock. Hunter
and Mage used the same toggle in their Open helpers, although their settings
cards already display inline controls. Rogue uses its own poison-tools window.

The release audit missed this: TestSettingsLayout exercised nine-class layout,
scrolling and mage combat controls, but never clicked Configure and omitted
Core/Integration.lua, which contains the actual toggle connection. Its passing
assertions did not establish that class-tool navigation worked.

With approval, Settings.ShowClassControls now explicitly shows the class page,
clears search/setup, attaches the requested controls and scrolls to their anchor.
ClassReminders, HunterFeed and MageSupplies Open methods use this path, without
delayed attachment callbacks. Disabled reminders can be reached without enabling
them; normal /era still toggles, and Rogue retains its separate poison window.

The expanded settings suite loads actual Integration, Commands and RoguePoisons
code. Its new Druid click assertion failed before the fix and passes afterward.
It exercises all nine class routes, actual Configure clicks where present, open
helpers, repeat navigation, initially closed settings, search/setup, disabled
reminders, slash commands, immediate close and combat. It passes 1,183 assertions.
Related detection, reminder-click and hunter-feeding suites also pass, totaling
1,374 assertions across the four affected suites. Five changed Lua files pass
syntax parsing and whitespace checks pass. No description change is required.
This local correction has not been committed, tagged or released; the historical
1.0.5 release results below are retained rather than retroactively amended.

## Verdict

**Approved for the 1.0.5 release.** The user confirmed the requested client checks,
including automatic reset/reload/default restoration, and authorized the Git
release for CurseForge. Corrections for A1 and A2 are implemented, and A3's
Questie compatibility ships from EraUI itself. The findings below preserve
the original audit evidence and explicitly list remaining follow-up coverage.

### Final 1.0.5 checks

- All 16 Lua suites pass: **3,424 assertions**.
- All 100 EraUI Lua files pass Lua 5.1 syntax parsing.
- Training-source audit: **1,538 checks**, 1,398 packaged entries across nine classes.
- CurseForge comment notifier: **8 tests passed**.
- TOC and Core versions are 1.0.5; CHANGELOG and What's New describe this release.
- Package audit passes: all 84 runtime files tracked and listed once, 215 bundled
  texture references resolved, no scanned credential patterns, and all seven
  description image tags preserved with Discord below the author. A local
  package-layout ZIP was opened and validated: 316 entries under EraUI, all TOC
  entries present, version 1.0.5, and no Tools/.github or adjacent addon payloads.
- Client-confirmed: aura errors resolved after reload; Questie suppression works
  including combat; trainer purchases and quest/map navigation work; reminder
  click-to-cast works; `/era reset` automatically reloads and restores defaults.
- The separate RXPGuides edit is outside EraUI and is not claimed as a shipped fix.
- The user received the complete updated CurseForge HTML in a single copyable
  code block. Publishing that description is separate from the tagged package.

The user's subsequent screenshot confirmed native/Questie tracker duplication
while idle in Orgrimmar, outside combat. That case is now covered explicitly.
The external RXPGuides nil guard remains a separate, locally confirmed repair.

### Approved correction validation

- Latest client confirmation: aura errors stay gone after reload, Questie tracker
  suppression works including combat, and trainer purchases plus quest/map
  navigation work. These confirm the reported flows, not every edge case below.
- With approval, `/era reset` now reloads automatically after the durable reset
  request succeeds. Combat and request-save failure do not reload. The focused
  lifecycle suite passes **65 assertions**, with guards verifying that the marker
  is saved and writes are frozen before ReloadUI is called; both changed Lua
  files pass syntax checks and the diff passes whitespace checks. The complete
   prepared HTML and command help now describe automatic reload. The user
  subsequently confirmed the automatic reload and default restoration.
- Subsequent approved reminder additions: separate Hunter PET DEAD/Revive Pet
  alert and an opt-in `Clickable reminders (outside combat)` control. The
  saved preference defaults off and is included in recovery. Click overlays
  are independent of the ordinary alert frames, with no parent/anchor links
  that would protect the alerts. Secure combat entry clears and hides actions;
  combat exit leaves them disarmed until the current reminder is reconciled.
  Preview mode is non-actionable, and reminder text retains dragging.
- Reminder follow-up checks: **953 assertions** across reminder click lifecycle
  (51), detection (81), persistence (66), reset lifecycle (62) and settings
  layout/combat (693). The six changed/new Lua files pass syntax checking and
  diff whitespace checks pass. Click tests verify configuration and lifecycle;
  actual in-client casting and rendering still require user testing.
- The user reviewed the new reminder UI and received the full prepared HTML. Their
  cropped icon screenshot was clarified as a slightly covered number, which
  the user considers minor. Its geometry has not been changed further as part
  of the reminder work.
- User confirmed reminder click-to-cast works, showing Aspect of the Hawk.
  At their request, the reminder icon's instructional hover tooltip was removed;
  casting, opt-in settings and the hover highlight remain. Hunter Call Pet /
  Revive Pet and combat transitions still need explicit client confirmation.
- After the reset/tracker repairs, all 15 Lua suites passed, totaling **3,333 assertions**.
- The subsequent approved aura fix (A6) passes its focused 78-assertion suite
  and Lua 5.1 syntax/whitespace checks. Its 17 new assertions replace the
  earlier 61-assertion aura result; unrelated suites were not rerun.
- Lua 5.1 syntax: 99 EraUI files plus the 2 external files, 0 failures.
- All 84 runtime files are present and listed once in the TOC. The new
  `Modules/QuestieCompatibility.lua` is included in the release staging list.
- Reset keeps live aliases valid, freezes recovery/legacy saves while pending,
  applies defaults before loaders bind their databases on the next load, and
  retains its durable marker through failed clearing or snapshot publication.
- Tracker tests model protected/unprotected wrapper eligibility and the second
  return-value gate. The adapter follows profile/toggle/addon changes, supports
  late loading and replacement frames, and installs no recurring poll.
- The faulty external Questie wrapper was removed; that section is back to its
  preceding implementation. The new test suite loads EraUI's packaged adapter
  without requiring a sibling Questie source checkout.
- Diff whitespace checks pass. The seven description image tags and four
  image-containing paragraph blocks remain unchanged, and Discord remains below
  the author line. The HTML now describes tracker compatibility and automatic reset.
- Performance follow-up A4 and diagnostic cleanup A5 have not been included in
  these correctness repairs.

Audited baseline: `48342cd`, released version `1.0.4`, plus the existing local
trainer, quest-navigation, quest-detail and map-reveal changes. Reference client:
Forever 1.60.1 build 70009, interface 16001.

This is the source/automated phase of the release audit. All runtime files were
inventoried and syntax checked. Manual review concentrated on initialization,
settings recovery/reset, native action ownership, recent changes, recurring
callbacks, automation transactions, optional-addon integration and packaging.
Client rendering, combat taint and actual CPU usage remain client-test items.

## Findings

### A1. High: reset leaves live callbacks with invalid settings

Locations: `Core/Commands.lua:244-252`, `Core/Persistence.lua:252-259`,
`Modules/Convenience.lua:174-184`.

`/era reset` clears `EraUIDB` and `Classic.db` while events, hooks, open windows
and update callbacks continue running until the player manually reloads.
`EraUI.db` still points at the old table. The persistence reset guard prevents
new recovery snapshots, but does not suspend those consumers or all older
mirrors. The command also permits running this transition in combat.

Reproduction loaded the actual Init, Persistence, Commands and Convenience
files, ran a successful Convenience refresh, executed the actual reset command,
and refreshed again. Result:

```text
Modules/Convenience.lua:182: attempt to index a nil value (global 'EraUIDB')
```

This callback is reachable through ordinary world/action-bar/binding events.
The defect is not a failure of the recovery codec tests; the command-to-live-module
lifecycle was outside their coverage.

Proposed correction: keep the runtime settings lifecycle coherent until reload,
handle combat explicitly, verify recovery/legacy clearing, and prevent deferred
saves or logout callbacks from recreating pre-reset settings. Add a real command
integration regression covering open UI, queued work, combat and logout/reload.

### A2. High: Questie's new secure tracker post-handler never executes

Locations: adjacent `Questie/Modules/QuestieCompat.lua:358-361`,
`Tools/TestQuestieTrackerVisibility.lua:35-45`.

The new wrapper supplies an empty pre-handler and puts suppression in the
post-handler. Blizzard's `CreateSimpleWrapper` executes the post-handler only
when the pre-handler's **second return value is non-nil**. The empty pre-handler
does not supply one. Initial hiding works, but later native shows escape it.

The test mock always executes post-handlers and therefore falsely passes this
case. Re-running the actual suite in memory with Blizzard's message gate gives:

```text
native combat show suppressed synchronously: expected false, got true
```

Reference: build-matched
`Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua`, `CreateSimpleWrapper`:
<https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua>

Proposed correction: honor the wrapper message contract, model wrapper eligibility
for protected and unprotected frames, retain the native handler, and test both
combat suppression and release of suppression. Validate in the real client with
and without a tracked quest-item button. The prior 31-assertion pass is not proof
that the currently installed tracker repair works.

### A3. Release integration gap: third-party edits are local only

The Questie visibility repair is in `../Questie/Modules/QuestieCompat.lua` and
the confirmed RXPGuides nil guard is in `../RXPGuides/RXPGuides.lua`. Neither file
belongs to the EraUI repository or package. Updating EraUI alone will not give
other players those repairs.

Recommended release approach: implement the requested Questie tracker policy
as an original, optional EraUI compatibility adapter, respecting Questie's
replacement setting and the native tracker when that replacement is disabled.
Test with an unpatched Questie installation. The independent RXPGuides cleanup
bug needs its own upstream/local-fix handling; do not list it as fixed by an
EraUI download unless an EraUI-side remedy is separately approved and tested.

### A4. Performance follow-up: avoidable repeated work remains

There are 56 OnUpdate registration sites across runtime source. That is an
inventory count, not 56 simultaneously busy loops. Many handlers have throttles,
visibility checks, active-state checks or run only while interacting.

Specific remaining candidates:

- `Classic/UnitFrames.lua:1222-1236`: player power and maximum power are queried
  before the 0.25-second throttle, every rendered frame. Executing that exact
  callback body with stable public values for 10 simulated seconds produced
  1,200 power reads at 60 FPS and 2,880 at 144 FPS, with one repaint request.
  Power events are already registered at lines 1215-1219. A bounded fallback
  poll is a candidate, subject to checking Forever's power-update behavior.
- `Classic/Professions.lua:549-627`: the watcher performs work before its throttle
  and runs tab/icon/layout reconciliation at 10 Hz even with the native window
  closed. A dirty/visibility-gated reconciliation would merit profiling.
- `Classic/Skin.lua:480-510`: the native-window discovery watcher scans its cached
  panel list at 10 Hz. Its existing throttle is useful; measure before changing
  this compatibility mechanism.

These operation counts are not CPU timings or evidence of an FPS regression.
Actual idle, combat, open-window and raid CPU captures remain outstanding.
Prioritize the reproduced correctness defects before changing layout watchers.

### A5. Low: trainer diagnostics are absent from the usual status command

`Classic/Status.lua:96-103` includes the new trainer diagnostic section, but
`Core/Commands.lua:208-209` routes `/era status` to its separate `PrintStatus`
report. That explains the earlier report lacking the requested section.
Consolidate the report or remove the temporary instrumentation before release.
This does not prevent training.

### A6. Client-reported: secret aura geometry arithmetic (locally corrected)

At 02:45:21 the client reported arithmetic on a secret number in
`Modules/AuraStyle.lua:87`. The old border sizing read the native icon width and
height and added six. Aura dimensions can be restricted even when the aura kind
is public and the dispel type is absent.

With approval, border sizing now anchors three pixels beyond each icon corner.
The client resolves the geometry; addon Lua does not read or calculate dimensions.
The regression first reproduced the old arithmetic failure, then passed after
the correction. It covers restricted width, restricted height, both restricted,
and recycled/resized icons, while preserving native aura data and click handlers.
The targeted aura suite passes 78 assertions. The user confirmed the error stays
gone after reload. This bug fix needs no description change.

## Original audit results, before the approved corrections

| Check | Result |
| --- | --- |
| Lua 5.1 parsing | 97 EraUI Lua files plus the 2 edited external files, 0 syntax failures |
| Runtime manifest | All 83 runtime Lua files present, tracked, listed exactly once |
| Lua suites | 14 suites report 3,227 assertions passed; A2 exposes the tracker mock's false confidence |
| Training source audit | 1,538 checks, 1,398 packaged class entries |
| CurseForge notifier | All 8 behavioral tests passed |
| Package inventory | 315 candidate tracked deliverable files, 11,882,506 uncompressed bytes; dry-run inventory only |
| Texture registry | 215 distinct fallback references resolve to tracked local assets or intentional client paths; checked Windows case-insensitively |
| Credential-pattern scan | No Discord webhook credentials, GitHub token patterns or private-key headers found in scanned tracked text files |
| Metadata | TOC 16001, author Squirt, All Rights Reserved; TOC and Core versions agree at 1.0.4 |
| Description preservation | All 7 image tags unchanged; all 4 image-containing paragraph blocks unchanged; current Discord invite follows Created by Squirt |

Individual Lua totals: aura 61, channel 24, class reminders 74, hunter feeding 59,
map reveal 128, movable map 116, persistence 62, Questie visibility 31,
quest-map pane 33, quest navigation 31, settings 693, trainer 176,
Training Guide 1,695, update notes 44.

`.pkgmeta` retains package name `EraUI`, `CHANGELOG.txt`, and excludes `.github`
and `Tools`. The notification workflow uses pinned action revisions, read-only
repository permissions, serialized runs, secret injection and durable state.
No hosted workflow was triggered by this audit.

## Source review notes

- Trainer purchases still belong to Blizzard's real Train button. Compact rows
  forward hardware clicks to native rows; selection mapping agrees with the
  matching TrainerUI source. The addon does not directly call BuyTrainerService.
- Trainer combat code preserves the artwork, disarms row selection and shields
  the purchase button. Its latest client behavior still needs testing, including
  entering combat with the filter menu already open.
- Questie title routing retains the original action for disabled/invalid/combat
  cases and changes only its explicit quest-log action. Objective/map routing
  remains in Questie's code.
- Map-detail changes retain native rewards/scroll handling and restore saved
  geometry. Reveal waits for native zoom data and refreshes after canvas setup.
- Recovery remains bounded, data-only and double-buffered. It verifies chunks
  before publishing the header and retains a previous backup on write failure.
- Merchant selling and mage trading have transaction/session guards. Automatic
  quest completion avoids multiple reward choices and paid turn-ins.
- Bundled training data and reminder logic retain all nine classes and Forever's
  expanded race/class combinations. Existing source/data tests passed.
- Reveal metadata still omits overlay 5252 on art 2160 and the previously
  documented zero-dimension records. Supported-map wording remains appropriate.

## Client validation and release preparation

Already confirmed by the user: pet training with the compact layout and the
separate RXPGuides trainer-close nil guard.

The user confirmed the basic flows listed in Final 1.0.5 checks. Further edge-case
coverage, not represented as completed by that confirmation:

1. Latest trainer opening/empty-list/combat behavior; class and profession trainer
   selection, purchase and profession confirmation.
2. Corrected tracker suppression during combat and objective progress, and native
   tracker restoration when Questie's tracker is disabled.
3. Questie title selection for folded/offscreen quests, objective/map navigation,
   and fallback with the Classic quest log disabled.
4. Map details at small/large sizes, long-description/reward scrolling, and clean
   startup with Map Reveal enabled.
5. Corrected reset with normal UI, queued work and combat, followed by reload and
   a subsequent login to verify default/recovery behavior.

Older pending client checks remain: mage conjuring/navigation in combat,
other-class reminders, channel behavior under damage, guide learned updates and
Forever-specific prices, and What's New scrolling. Automated passes do not
close those visual/client checks.

The approved version is 1.0.5. Metadata, CHANGELOG and in-addon What's New notes
were prepared together, with all release suites rerun before commit/tag/push.

The subsequent approved repairs updated the prepared description with shipped
tracker compatibility and queued-reset wording. The complete HTML remains at
`C:\Users\beauh\OneDrive\Desktop\curse forge code - 1.0.4 - Discord.txt`,
pending client validation and publication at:
<https://authors.curseforge.com/#/projects/1709918/description>.

## Reproduction artifacts

Temporary read-only probes are under
`C:\Users\beauh\AppData\Local\Temp\opencode`:

- `eraui-audit-20260927.lua`: historical pre-fix tracker/reset failure probes.
  The corrected suites supersede these baseline-only repros.
- `eraui-package-audit.cjs`: runtime, package, texture, credential-pattern and
  description-image inventory.
- `eraui-polling-audit.cjs`: actual player-power callback operation counts with
  stable mocked values at 60/144 FPS.

Run these from the EraUI directory. The probes do not mutate the game settings
or addon runtime files. This report does not assert closure of the older,
unrecovered severity-labelled audit list.
