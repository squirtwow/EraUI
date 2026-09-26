# Map geometry and aura styling

Verified native UI source: `Gethe/wow-ui-source` commit
`bd2470aed543f72697a044e989285b6c83e63f73`, matching Forever 1.60.1.70009.

## Map

`MapCanvasMixin:GetCanvas()` identifies the native canvas explicitly.
`MapCanvasMixin:OnFrameSizeChanged()` calls the scroll container's
`OnCanvasSizeChanged()`, which fits its own fixed-size artwork immediately using
`ResetZoom()` and `InstantPanAndZoom()`. EraUI no longer resizes or unanchors the
canvas, guesses a canvas from the largest child, or schedules delayed refits.

While a grip is held, cursor movement updates the outer frame's dimensions with
the map aspect ratio and window chrome dimensions accounted for. The
opposite top corner stays anchored. Native fitting follows each size change.
Releasing saves the geometry without a second aspect correction. Header dragging
also uses cursor deltas, allowing combat entry to stop movement without leaving
the native frame in a moving/sizing state.

`mapPosition` stores UIParent-space offsets, including map/UI scale conversion.
Normal layouts use the table root; expanded layouts use its `expanded` record.
`mapSize` uses the same arrangement. Old single-layout settings remain readable.
Restore runs after native show/maximize/minimize/panel-placement callbacks,
coalesced once per frame. Position-only restoration does not refit or reset zoom.
Version 3 sizes restore both saved dimensions. Earlier sizes are corrected once
to the full-artwork aspect, retaining width within screen bounds. The viewport's
right edge anchors directly to the outer window, while the quest list overlays
its right side above the artwork. Native canvas anchors and dimensions are not
changed. A post-hook on `SetQuestLogPanelShown` restores the outer window after
the native width change, and the initial layout is recorded before manual
resizing. The sidebar toggle stays above the quest overlay. Disabling the mover
restores the native viewport anchor and overlay frame levels.

The exact-build `WorldMapTrackingPinButtonTemplate` defines a 32x32 button, and
Camelot's `AdjustOverlayFrames` places it at the canvas container's top left.
EraUI restores that explicit geometry and confines the highlight to the button.

## Aura cosmetics and level colour

`AuraStyle` follows the existing Unit Frames setting. It uses the classic
`UI-Debuff-Border` texture and public `DebuffTypeColor` values for player debuffs.
Restricted dispel data stays with the native border. The native symbols, aura
duration, tooltip content and cancellation scripts are not replaced.

Aura tooltips receive an owned translucent dark backdrop with an original thin,
neutral-grey bevel and softened corners. `Tools/GenerateTooltipBorder.mjs`
generates `Media/TooltipBorder.tga` and an atlas-rendered inspection preview.
The 128x16 RGBA atlas follows the native backdrop strip/corner UV layout.
The client's `UI-Tooltip-Border` is not reused because its current artwork can
retain a gold/brown tint. The modern NineSlice is temporarily faded, and a
post-hook keeps later alpha writes from exposing it while styled.
Hiding/clearing the tooltip restores its native border so
unrelated item, unit and quest tooltips do not inherit the aura style. State is
kept outside native tooltip data tables. Both GameTooltip and BuffFrameTooltip
are covered, including late-loaded frames and reused aura buttons.

The separate **Tooltips** setting extends this styling to regular hover boxes,
linked items and comparison tooltips. It defaults to enabled for fresh settings
and resets, respects existing saved choices, and requires a reload to change.
Shared backdrop-style callbacks discover late-created tooltips and reapply the
Classic style after native refreshes. Embedded item details keep their native
borderless presentation. General tooltip styling is independent of Unit Frames.

Blizzard's `PlayerFrame_UpdateLevel()` writes the level and resets its vertex
colour. A post-hook reapplies Classic gold while the player-frame skin is active.
The existing anchor keeper also repairs it if another native refresh changes it.

## Checks

- `lua Tools/TestMovableMap.lua`: resize edges/corners, same-frame fit, release,
  mode-separated layouts, reopen, scale conversion, combat interruption, native
  pin dimensions, no direct canvas edits and disabled behavior.
- `lua Tools/TestAuraStyle.lua`: tooltip reuse/restoration, native text/actions,
  public/restricted dispel borders and native level-update recolouring.
- `lua Tools/TestMapReveal.lua`: reveal renderer/data regression checks.

These simulations require in-game confirmation of appearance and native UI
behavior, particularly resizing with map overlays visible and the next level-up.
