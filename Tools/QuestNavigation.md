# Questie routing and map quest-detail layout

Local changes pending in-game validation on Forever 1.60.1 build 70009.

## Quest log clicks

`Classic/QuestLog.lua` adapts Questie's `TrackerUtils:ShowQuestLog(quest)` at
runtime. It opens the requested quest in EraUI's enabled Classic quest log,
expands the relevant Classic category and scrolls the selected row into view.
Questie's configured click bindings still decide when that action is invoked.
Objective/finisher/map-icon navigation is not intercepted. Existing open maps
are not closed as a side effect of reading a quest.

Questie can load before or after EraUI. The adapter installs once and falls
back to the original handler when the Classic log/master setting is disabled,
the requested quest is absent, the window cannot open, or the player is in
combat. The original handler receives its receiver, arguments and return values.
No Questie files or Blizzard quest-opening globals are replaced on disk.

## Map details

The build-matched native XML gives `DetailsFrame` a fixed 502-unit height and
its description scroll frame a fixed 430-unit height. Those dimensions leave a
large unused dark region in an enlarged map. `Classic/QuestMapPane.lua` retains
the native top and width anchors and adds bottom anchors to follow the map's
quest panel. The existing parchment and action buttons follow the detail frame.
Native reward clipping is recalculated after resizing, and out-of-range scroll
positions are clamped. Disabling the skin restores the original geometry.

The Map Reveal initialization fix separately waits for native zoom levels,
resuming after native canvas initialization rather than iterating a nil table.

Technical references: installed Questie tracker action boundaries, and
Blizzard's `QuestMapFrame.xml`/Lua at `Gethe/wow-ui-source` commit
`bd2470aed543f72697a044e989285b6c83e63f73`. EraUI implementation is original.

## Checks

- `Tools/TestQuestNavigation.lua`: specific quest selection, folded categories,
  scrolling, late-loaded Questie, fallback and unchanged navigation dispatch.
- `Tools/TestQuestMapPane.lua`: normal/enlarged geometry, scroll clamping, native
  rewards, combat deferral and repeated setting restoration.
- Existing `Tools/TestMapReveal.lua` and `Tools/TestMovableMap.lua` regressions.

In game, reload and test a Questie title, an objective/map marker, a quest title
in a folded Classic category, and both map sizes with long quest text/rewards.
Confirm the map detail buttons stay at the bottom and descriptions still scroll.
No commit, version bump, tag or release has been made. The complete Desktop
CurseForge HTML draft includes the two new description bullets and preserves
the original images and bottom Discord invite; publish only after validation.
