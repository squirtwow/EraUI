# Settings layout and mage controls

`Core/SettingsLayout.lua` provides a clipped content viewport above the fixed
footer. Class pages and search pages measure each card plus its inline panel,
then advance by the taller block in each two-column row. Normal categories keep
their existing positions. The scroll range updates when panels expand, collapse
or change visibility; shorter content clamps the current scroll position.
Setup mode repositions the same viewport rather than reparenting its controls.

Inline panels belong to the content frame, not the root settings window.
`ClassTools.BindInlinePanel` connects size/visibility changes to a coalesced layout
update. Supply sliders reserve the height of their labels as well as the track.

Mage conjure slots inside settings are ordinary presentation controls. Their
secure spell buttons are separate children of UIParent, positioned using absolute
coordinates and matching effective scale. They have no parent or anchor dependency
on settings. Only fully visible slots receive click targets. Scroll, layout,
window dragging, visibility and scale changes synchronize these targets outside
combat. Native visibility state drivers hide them during combat; no insecure
combat handler changes their attributes, visibility, position or size. Combat
exit refreshes the selected ranks and geometry.

Run `lua Tools/TestSettingsLayout.lua` from the addon root. It loads the actual
settings and class modules with a geometric frame mock. Checks cover all nine
class layouts, expansion, search, setup transitions, footer separation, scroll
clamping, slider label spacing and mage action alignment. The mock rejects combat
mutations of secure buttons, their ancestors and anchor dependencies.

The simulation does not reproduce WoW's taint engine. In-game verification still
needs a mage with learned conjuring spells: open settings, scroll and move the
window, enter combat, navigate/search/close/reopen, then leave combat and conjure.
