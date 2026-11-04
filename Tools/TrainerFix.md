# Trainer purchase boundary and Classic layout

The EraUI 1.0.4 custom Train button called restricted `BuyTrainerService()`
directly. The first local fix retained Blizzard's full-size rows and worked in
the user's client, but changed the requested Classic presentation.

The revised local implementation restores the nine-line compact list, category
headers, separate ability details, and Train/Exit footer. The user confirmed
that pet training works with this layout on Forever 1.60.1 build 70009.

An earlier in-game retest showed an empty compact list with no Lua error,
including with RXPGuides disabled. A later pet level-up exposed Growl Rank 2,
which the user successfully trained. Already Known was unchecked; the original
empty state has not been conclusively attributed to filtering. The Classic
status module includes read-only trainer diagnostics: API and named
service counts, filters, native and bound row counts, refresh phase and service
counts around layout, and the last ten trainer/show/hide events. The general
`/era status` output supplied during testing did not include that section.

The subsequent local repair keeps the Classic overlay visible during combat,
disarms secure row forwarding, and places a secure input shield over Train.
Previously the combat visibility rule hid the overlay and exposed the faded
native shell. A native OnShow post-hook now refreshes the overlay synchronously
before painting. Empty catalogs display a filter message; pending service names
display a loading message. These latest presentation/combat changes still need
in-game validation. The separate RXPGuides trainer-close nil guard has already
been confirmed working by the user.

## Native click ownership

- Compact ability rows are secure click forwarders targeting real, initialized
  Blizzard rows. Addon Lua does not call selection/initializer/purchase handlers
  or write native selection fields.
- An invisible native list viewport materializes services beyond the compact
  list's current page. Geometry that can initialize pooled native controls is
  changed through a restricted handler, not through addon-context layout calls.
- Secure post-hooks invalidate old routes immediately when native rows update,
  then coalesce a read-only refresh of labels, costs and routing next frame.
- Blizzard's real Train button overlays the Classic Train artwork, retaining
  its original scripts, enabled state and profession-confirmation handling.
- Pet details use the pet's level and training points. Other trainers use
  player requirements and copper. The footer shows available pet points.
- Restoring the setting removes routes and restores native geometry/alpha.
   Combat defers layout/routing refreshes while retaining the Classic artwork
   and securely blocking row selection and training clicks.
- There is no recurring polling timer.

Technical reference only: Blizzard's build-matched TrainerUI and restricted
frame API at `Gethe/wow-ui-source` commit
`bd2470aed543f72697a044e989285b6c83e63f73`. All EraUI code is original.

## Validation

`Tools/TestTrainer.lua` exercises delayed loading, offscreen selection, recycled
rows, native confirmation/eligibility ownership, point/coin display, category
collapse, filters, empty/loading messages, synchronous reopening, combat input
blocking, and repeated restoration (176 assertions). The simulated
boundary does not prove actual WoW taint behavior or pixel-perfect layout.

Reload the actual client and test:

1. Compare the compact list, detail panel and Train/Exit footer with the old UI.
2. Select and train a pet ability. Check pet level and point costs, then learn
   another ability without closing the window.
3. Scroll to abilities beyond the first page, select them and train. Filter and
   collapse/expand categories; verify the details always match the clicked row.
4. Check class-trainer coin prices and profession confirmation/slot limits.
5. Toggle Trainer off/on and reopen it. Check the blocked-action report.
6. Check that opening the trainer does not flash an empty native shell and that
   combat does not replace the Classic layout with grey artwork. With no matching
   abilities, check the message and enable Already Known to inspect learned ranks.

## Packaged Questie visibility compatibility

`Modules/QuestieCompatibility.lua` now owns the repair inside EraUI. The earlier
local Questie wrapper was removed, returning that section to its preceding
implementation. The EraUI adapter uses the required second pre-handler return
to enable Blizzard's secure post-handler. It preserves native OnShow behavior,
handles protected trackers securely and handles unprotected combat trackers
with an ordinary visibility hook. Both idle and combat re-shows are covered.

The policy follows Questie's tracker enablement, addon enablement, profile changes
and Show Blizzard Timer preference. Combat changes apply after combat. Releasing
suppression also releases any older Questie native-hide request. Late loading
and native frame replacement are handled without polling.

`Tools/TestQuestieTrackerVisibility.lua` loads the shipped EraUI adapter without
requiring a Questie source checkout. Its 74 assertions model wrapper eligibility
and the message gate, idle Orgrimmar re-shows, combat, preference changes,
disable/restore, late loading and replacement frames. Real-client validation
remains pending for this revision.

No commit, version bump, tag or release accompanies this local revision. The
complete prepared CurseForge description now includes tracker compatibility.
