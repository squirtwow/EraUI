# EraUI release audit: 2026-09-27

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
