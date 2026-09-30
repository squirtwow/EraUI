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

### Dark Aura Borders

A separate /era option under Appearance, on by default and greyed out until
Dark Mode is chosen (`darkAuraBorders`, depends on `darkMode`), so choosing
Dark Mode gives the borders and players can still switch them off. Presets
leave it alone. It applies live
while the loaded style is Dark Mode. Checked against the `forever` branch of
`Gethe/wow-ui-source`: camelot loads the mainline `BuffFrame.lua`, whose
`AuraFrame_OnLoad` builds a fixed pool of `AuraButtonTemplate` buttons in
`auraFrames` for BuffFrame, DebuffFrame, ExternalDefensivesFrame and the
consolidated-buff popout. `DeadlyDebuffFrame.Debuff` and the consolidated
button are standalone buttons. Private aura anchors (`isAuraAnchor`) are left
alone because the game draws their icons.

Each button gets eight addon-owned colour strips pinned to its `Icon` by
anchors only: a dark edge two units outside the icon (BACKGROUND -8, under
the icon and its timer text) and a Dark Mode grey line one unit over the
icon's rim (ARTWORK). Native debuff, enchant, symbol and count overlays stay
on top. Rings are made once, when the option is on, from `Refresh` or the
existing `UpdateAuraButtons` post-hook, and later only shown or hidden. No
aura type, aura data or geometry is read, no native region is changed and no
key is written on the buttons, so the same path runs in combat. A protected button (not how Forever builds them)
would wait for `PLAYER_REGEN_ENABLED`.

Target and focus auras are not covered: camelot builds them from the secure
`TargetFrameAuraContainerTemplate`, whose buttons come from the forbidden
`ForbiddenTargetFrame*ButtonTemplate` templates when `RestrictedAuraAPI` is
set. EraUI only repositions that container.

Blizzard's `PlayerFrame_UpdateLevel()` writes the level and resets its vertex
colour. A post-hook reapplies Classic gold while the player-frame skin is active.
The existing anchor keeper also repairs it if another native refresh changes it.

### Class-coloured Tooltips

A separate /era option on the Interface page, off by default, applied live
(`tooltipClassColours`, no dependency). Checked against the `forever` branch:
camelot uses the mainline tooltip data path, so `GameTooltip:SetUnit` and the
world-cursor tooltip both run `TooltipDataHandlerMixin:InternalProcessInfo`
(clear, add lines, post-calls, show). EraUI registers one
`TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit)` callback;
Blizzard runs addon callbacks through its forbidden attribute delegate with
`securecallfunction` and `forceinsecure`, so they stay apart from the
tooltip's own code.

The callback finds the `UnitName` line (its `unitToken` and `lineIndex`), or
falls back to a `Player-` GUID. Players only (`UnitIsPlayer`); the class comes
from `UnitClass` / `GetPlayerInfoByGUID` and the colour from
`CUSTOM_CLASS_COLORS` or `RAID_CLASS_COLORS`. Any secret token, GUID, flag or
class leaves the tooltip native. It then:

- sets the name line's text colour;
- wraps the class word, as a whole word, in a colour code on the line that
  also names the race (the level line), else on the first line with it that
  isn't a `<Guild>` tag. Secret line text is skipped;
- tints the border that is showing: EraUI's Classic bevel
  (`SetBackdropBorderColor`) with the Tooltips skin on, or the native NineSlice
  through its own `SetBorderColor` with it off. `TooltipBorder.tga` is a mid
  grey (opaque pixels average about 115/255, brightest 182), so the tinted
  bevel alone shows the class colour at under half strength. While tinted, a
  second copy of the bevel (EraUI's own `BackdropTemplate` frame, same edge,
  no background, `SetBorderBlendMode("ADD")`, one level above) adds the same
  colour, bringing the border to about 0.9 of the class colour with the
  bevel's shading kept. It is made the first time it's needed and hidden with
  every untint.

`SharedTooltip_SetBackdropStyle` on camelot never resets the NineSlice border
colour, so the previous colour is saved and put back on `OnTooltipCleared` and
`OnHide`, together with the name colour and the original line text. Only
tooltips AuraStyle already watches are tinted, since only those are restored.
State lives in a weak table; nothing is written on Blizzard's frames.

## Checks

- `lua Tools/TestMovableMap.lua`: resize edges/corners, same-frame fit, release,
  mode-separated layouts, reopen, scale conversion, combat interruption, native
  pin dimensions, no direct canvas edits and disabled behavior.
- `lua Tools/TestAuraStyle.lua`: tooltip reuse/restoration, native text/actions,
  public/restricted dispel borders and native level-update recolouring.
- `lua Tools/TestMapReveal.lua`: reveal renderer/data regression checks.
- `lua Tools/TestDarkAuraBorders.lua`: ring geometry and layers, nothing made
  when switched off (the default is on, checked in TestPersistence), Dark Mode
  and EraUI gating, live toggling, late buttons, combat,
  protected-button deferral, private anchors, and no aura data reads or
  writes on Blizzard's buttons.
- `lua Tools/TestClassTooltips.lua`: the client's clear/lines/post-call/show
  order on proxy tooltips that forbid key writes; name, class word and border
  with the skin on and off, restore on clear, hide and switching off, players
  only, secret values, whole-word and guild-tag rules, GUID fallback.

These simulations require in-game confirmation of appearance and native UI
behavior, particularly resizing with map overlays visible and the next level-up.
