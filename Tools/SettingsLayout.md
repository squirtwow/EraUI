# Settings layout and mage controls

## One home per topic

/era has 14 tabs, one per topic a player thinks of, in this order: Appearance,
your class, Action Bars, Frames & Nameplates, Casting, Map & Minimap, Quests,
Character & Spells, Bags & Vendors, Chat & Names, Group & Invites, Windows &
Tooltips, Screen & Cursor, More from Squirt. Each tab has a fixed word id
(`TAB_IDS` in `Core/Settings.lua`); its number is only its place in the list.
Each tab shows a one-line description under its title.

`PAGES` in `Core/Settings.lua` lists every tab's cards in reading order, two
per row. Every card is on exactly one page, and each sub-option sits right
after its parent: next in reading order, or directly under the parent or one
of its other sub-options (Appearance reads as two columns, Dark Mode extras
and class colours, under half-width section labels). Full-width entries (the
Bags & Vendors section labels, the Classic / Dark Mode choice row and the More
from Squirt card) take a row of their own. Setting keys never change with a
card's place, so no saved choice moves. On a page or walkthrough page, a card
with its sub-options on show starts a row, so they follow it from the left
column (Advanced Cast Bar, the cursor effects, AFK Screen, Highlight Reward
Upgrades); search results are listed two to a row as they come.

The cursor ring, cast progress ring and cursor trail options are folded:
hidden, not greyed, until their switch is on, then shown right after it at
once, keeping the scroll. The AFK Screen's options are not folded (it is on by
default); they grey out while it is off, like every other `DEPENDS` option.
Class-coloured Unit Borders needs both Dark Mode and Unit Frames; the hover
names the first missing one, walking up each chain.

Among the topic tabs, only Bags & Vendors (12 cards) and Screen & Cursor (the
AFK Screen's options are open) scroll at the default size, with the existing
scroll hint. The class tab can scroll with its inline panels open (hunters,
rogues and mages), measured as before. Of the walkthrough's option pages only
Screen & Cursor scrolls.

Search matches every card, folded ones too, and each card's tab name, with
colour/color and grey/gray spelled either way. Results come in tab and page
order, eight cells to a page (a full-width card takes a row), each with its
tab's name in small capitals above it. The Classic / Dark Mode choice is a
result like any card, and old card names (for example Character / Reputation
/ Skills) still find the renamed cards. The Update Notice tick under Presets
has a search-only card, "Update Notice", on no page, tagged "TOP RIGHT, UNDER
PRESETS"; it is the same switch as the tick.

The setup walkthrough's quality-of-life pages are, in order: Action Bars, Map
& Minimap, Quests, Bags & Vendors, Chat & Names, Group & Invites and Screen &
Cursor, each without its reload-only looks (Classic Chat Dragging stays).
Show All Spell Ranks joins Action Bars, Tooltip IDs joins Chat & Names (after
Click Links Again to Close), and Class-coloured Chat Names joins Chat & Names
when the style page (the whole Appearance tab) is skipped, so every option the
walkthrough offered before is still offered once. An option waiting on a look
the walkthrough leaves out (Show Gryphons with the Action Bars look off) is
left out with it, since it could not be switched on there. Section labels stay
on the tab, so Bags & Vendors (nine options without its looks) fits its page.

New-player hints pulse on the class and Casting tabs. They are saved by tab
number in the per-character onboarding CVar and backup, so the tab order is
versioned: `discoveryHintsVersion` 2 is this order; version 1 (class 12,
Casting 13) is moved once when settings initialise, after both saved copies
have loaded. Setup finished before the hints existed (no version, stored as 0
in the CVar) gets both hints.

A one-time "New layout" note sits at the top of the window. Core/Integration.lua
sets `layoutNotice` once per account after the saved copies load: 1 for an
account that used an earlier EraUI (update notes, welcome, setup or the AFK
marker seen), 0 for a fresh install. It ends before the Presets column, so its
X is well clear of the window's close button. It never shows during the setup
walkthrough; its X, or closing /era after seeing it, sets 0. The value is
backed up like `afkScreenVersion`.

## Tab list width

Every tab name fits inside its tab (its highlight) and ends before the
sidebar divider. The tab font is Friz Quadrata at 13 and the text starts 36 in;
measured in game (2026-10-01), Frames & Nameplates is about 146 wide and
Windows & Tooltips about 136, so the 164 tabs of the 188 list were too narrow.
The list is now `NAV_WIDTH` 212 with 188 tabs, keeping the font, insets and
margins (12 in from the window edge, 13 short of the divider). The pages start
just right of it (`PAGE_LEFT`, `VIEW_LEFT`), so the window grows by the same
24 to 984 and the cards keep their 718 width. The setup walkthrough (800 wide,
no list) is unchanged. Each tab label is also held inside its tab (LEFT 36,
RIGHT -2, one line, 150 of room), so a name that renders wider at another UI
scale is cut short inside the highlight instead of crossing the divider; the
measurement is from one scale (1.2) only, so the headroom is about 4. The
quest tracker choices (setup only) use `PAGE_LEFT` outside setup too.

## The game's portrait switches

Class Icon Portraits: Mine and Class Icon Portraits: Others mirror the game's
own Options > Interface switches (CVars `ReplaceMyPlayerPortrait` and
`ReplaceOtherPlayerPortraits`, `EraUI.cvarSettings`). On Forever the game
registers them as plain CVar settings (Blizzard_SettingsDefinitions_Frame
Interface.lua), and its unit frames redraw through
`Settings.SetOnValueChangedCallback(cvar, UnitFramePortrait_Update, frame)`
(Blizzard_UnitFrame Mainline UnitFrame.lua). In Forever's source a script
`SetCVar` should already reach that redraw: `CVAR_UPDATE` is synchronous,
`SettingsPanel:OnCVarChanged` (registered for every CVar update and meant for
changes made from the console or the CVar script API) calls
`setting:SetValue(value, true)`, and `ApplyValue` always runs
`TriggerValueChanged`. The in-game failure is not proven: either the write is
quietly refused (`C_CVar.SetCVar` has `RequiresNonSecureCVar` and
`RequiresNonReadOnlyCVar`, FailureMode ReturnNothing) or the redraw does not
arrive. Out of combat a card first asks `C_CVar.GetCVarInfo`; a secure or
read-only switch is not written and the card says "Only Options > Interface
can change this portrait setting." Otherwise it writes the CVar with
`SetCVar`, reads it back (`GetCVarBool` giving nothing means the game has no
such switch), and then redraws the portraits itself by calling the game's
`UnitFramePortrait_Update` on the player, target, focus, both
targets-of-target and the active party frames (read only, each in a `pcall`,
nothing written on the frames). If Blizzard's own redraw already ran, this is
a harmless second one. If the game kept its old value, the card follows the
game and says "The game kept its own portrait setting. Change it in Options >
Interface." The two lines tell the two refusals apart in game. It does not
call `Settings.GetSetting(cvar):SetValue` directly: `SetCVar` is the script
route the Options window expects, and the same Setting code (`ApplyValue`,
`ClearPendingValue`) runs from it anyway, so a direct call gains nothing. A
`CVAR_UPDATE` watcher keeps both
cards in step when the switch is flipped in the game's Options window, with
/era open or not; only EraUI's cards change there, the game redraws its own
portraits. In combat the cards refuse, as before.

## Viewport and class pages

`Core/SettingsLayout.lua` provides a clipped content viewport above the fixed
footer. Every page, search and walkthrough page measures each card plus its
inline panel, then advances by the taller block in each two-column row. The
scroll range updates when panels expand, collapse or change visibility;
shorter content clamps the current scroll position. Setup mode repositions
the same viewport rather than reparenting its controls.

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

Run `fengari Tools/TestSettingsLayout.lua` (the project's fengari.cmd) from the
addon root. It loads the actual settings and class modules with a geometric
frame mock. Checks cover all nine
class layouts, expansion, search, setup transitions, footer separation, scroll
clamping, slider label spacing and mage action alignment. The mock rejects combat
mutations of secure buttons, their ancestors and anchor dependencies. It also
checks the 14 tabs and their descriptions, every card on exactly one page in
its approved place, sub-options right after their parent, which pages scroll,
folding, search spellings, tab names and paging, the Dark Mode choice and
Update Notice in search, old names, the full-width More card and its text
clear of its buttons, parents with sub-options starting a row, the hint
migration, the walkthrough pages (none but Screen & Cursor scrolls), the
one-time note and tidy labels (Title Case, "&",
"Class-coloured", summaries within two lines at 40 letters). Tab names are
checked with honest widths for the tab font (the in-game measurements, and a
glyph estimate never under them for any other name) for all nine classes, and
each label is held inside its tab on one line with every name fitting whole.
The portrait cards are checked both ways: the CVar written, every portrait
redrawn once, refusals (a quiet one, a game without the switch giving nothing
back, secure and read-only switches never written), combat, a failing frame,
and following the game's Options window.
`Tools/TestPersistence.lua` checks who gets the note and that it is backed up.

The simulation does not reproduce WoW's taint engine. In-game verification still
needs a mage with learned conjuring spells: open settings, scroll and move the
window, enter combat, navigate/search/close/reopen, then leave combat and conjure.
