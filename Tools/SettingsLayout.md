# Settings layout and mage controls

## Grouped tabs, sub-tabs and rows (2026-10-11)

/era has 14 tabs under four small-capital group headings in the tab list:

- **LOOK:** Appearance, Action Bars, Frames & Nameplates, Map & Minimap, Windows & Tooltips
- **GAMEPLAY:** your class, Casting, Quests, Character & Spells, Bags & Vendors
- **SOCIAL:** Chat & Names, Group & Invites
- **EXTRAS:** Screen & Cursor, More from Squirt

Each tab has a fixed word id (`Nav.TAB_IDS` in `Core/SettingsNav.lua`); its
number is only its place in the list. Under each tab's title is a one-line
description. Busy tabs have sub-tabs: Appearance (Style, Dark Mode, Class
Colours), Frames & Nameplates (Unit Frames, Nameplates), Bags & Vendors (Bags
& Loot, Vendors) and Screen & Cursor (Screen, Cursor, AFK Screen). A tab
remembers its last sub-tab for the session. Appearance > Style has the Style
section (the Classic / Dark Mode choice, Presets) and, under it, Frame Style
(Flat Bars, Thick Frames with Portrait Rings, Classic Party Frames and Edge,
a choice of Dark or Class colour, indented under it, Thick Aura Borders,
Rounded Cast Bars and the Raid-style
Party Outline, its own switch, never greyed: it dresses the game's raid-style
party frames, not EraUI's). Rounded Cast Bars needs Cast Bars (on Casting): it
is greyed, with "Switch on Cast Bars first (Casting)." in the footer, while
that is off, and never indented under it (they're on different pages).
Thick Frames needs Unit Frames the same way ("Switch on Unit Frames first
(Frames & Nameplates > Unit Frames)."); its two ticks and Edge are greyed
while it's off ("Switch on Thick Frames first."). Edge is named with one
short word: indented, with "experimental" and its Dark and Class colour
buttons, "Frame Edge" doesn't fit.
Casting has Cast bars (Cast Bars, the Advanced Cast Bar and its options) and,
under it, Colour: Cast Bar Colour (Match look, Yellow, Grey, Class, Custom)
and Custom Cast Bar Colour, a colour swatch that shows only with Custom.
Appearance > Dark Mode has Darkness, Borders and Bars and windows: Dark Menu
Bar beside Dark Bag Buttons, then Dark Windows with Black Pages under it; all
of them greyed while Dark Mode is off.
Action Bars ends with Upgrade Spell Ranks, after Hide Macro Names: it works
with any bars, so the Classic Action Bars look being off never greys it.
Character & Spells ends with the Stat Tracker (2026-10-14): a Stat tracker
section under Spellbook with its switch, Layout (List, One line) beside it,
Show It (Always, In a fight, Out of a fight) on a whole line, Panel Size (a
whole-line slider, 50% to 150%), Stats per Line (a whole-line slider, 1 to
16, All at the top; greyed while Layout is List, the footer saying "Set
Layout to One line first.", `NEEDS_CHOICE`), then Gains in Green beside Show Title, then
Stat Name Colour (Match look, Gold, Class, White, Custom) on a whole line
with Custom Stat Name Colour, a swatch, folded under it until Custom is
chosen; then its sixteen stat ticks, two to a line, under
Attributes, Offence, Defence and Other. All but the switch show only while
it's on (`SHOWN_WITH`, below), so switched off the page fits; switched on it
scrolls, the one page that does with its rows open.

`TABS` in `Core/SettingsNav.lua` is the map: every page's sections (titles
drawn in gold small capitals) and rows, in reading order. Every option is on
exactly one sub-page; setting keys never change with a row's place, so no
saved choice moves. The class tab has Reminders, Class tools, a resource
section named per class ("Combo points and energy" for rogues, "Combo points
and resources" for druids, "Resource bars" for the rest) and Timers; rows not
for your class (`classAllowed`) and sections left empty are left out.

The search box sits at the top of the tab list, "Take the tour" at its foot.
The window keeps its size (984 x 650, FitToScreen), its dark chrome, close
button and Escape (UISpecialFrames).

### Rows

One row per option (`Core/SettingsRows.lua`), 32 tall, in two columns 352
wide (x 0 and 366 of the 718 page); a wide row (the Look choice, Presets, the
Darkness and damage text sliders, the damage font, Class Reminders & Buffs,
a hunter's or mage's class tools heading, AFK Screen, the More from Squirt
addons, Cast Bar Colour, whose five choices don't fit half a line, the
Stat Tracker's Show It, whose three don't either, its Panel Size and Stats
per Line sliders and its Stat Name Colour, five choices again) takes the whole 718. A tick row has a 14 x 14
square tick box (dark fill, grey edge) with an 8 x 8 inner square in the
player's class colour when on; a click anywhere on the row flips it (PreClick
flips the tick, then the row's own OnClick saves and applies, exactly as the
old cards did). Sliders, the Classic / Dark Mode choice, colour swatches, the
damage font list and buttons (Presets, Get it) sit in rows of the same look.

Right after a row's name, a small plain word or two (10 point, lower case,
no box, no border, no capitals; 5 apart, 6 after the name, on the name's
line): "just added" in the game's gold (1, .82, 0), "experimental" in a
muted warm grey (.66, .61, .53) for options not seen working in game yet
(`EXPERIMENTAL` in Core/Settings.lua: Aura Shadows, Thin Debuff Colours,
Dark Windows, Black Pages, Character Item Levels, Flat Bars, Thick Aura
Borders, Rounded Cast Bars, Dark Bag Buttons, Upgrade Spell Ranks, Stat Tracker, Thick Frames, Portrait Rings,
Classic Party Frames, Edge, Raid-style Party Outline, Clean Minimap's Style, Cast Bar Colour; the last
two have no "just added", which wouldn't fit before their buttons, nor do
Portrait Rings, Classic Party Frames and Edge: indented, "Classic Party Frames" and
both words don't fit, nor Edge's buttons, and Thick Frames above them says it), "coming soon" and "log
out to apply" (a new damage font, after the font button) in the muted grey.
"just added" shows only to players who had the old layout and only while
they run the version the new layout arrived in (`EraUIDB.layoutPillsVersion`,
the name kept so saved values stay), never in the setup walkthrough: Thin
Debuff Colours, Black Pages, Dark Windows, Flat Bars, Thick Aura Borders,
Rounded Cast Bars, Dark Bag Buttons, Upgrade Spell Ranks, Stat Tracker, Thick Frames, Raid-style Party Outline (new since 1.5.5). Nothing says an
option moved any more (the user, 2026-10-11: the boxed capital labels
"looked too AI generated"). Search results carry the same words, and
searching "experimental" finds those options. The class box's Click to apply
poisons says "experimental" the same way.

A slider row shows "Name: value" in 194 (12 to 206; the slider from 214), so
the longest, "Cast Ring Opacity (%): 100", fits whole; the wide sliders keep
200 (12 to 212, the slider from 222). Its value shows once, in its name: the
Darkness row's grey swatch after the slider (it read as an empty dark box at
high Darkness) is gone.

### More from Squirt

Three whole-line rows, 56 tall, in this order: Forever Enhanced Cooldown
Manager, Forever Enhanced Cursor and Forever Enhanced Cooldown Pulse (the
author's own addons, so they are named). Each has its icon (copied into
Media: FECMIcon, FECIcon, FECPIcon; a new file needs a full restart), its
name and a state line. Not installed: Get it copies its CurseForge link and
a small GitHub button its repo (an addon can't open a web page). Installed:
Open, which closes /era and runs its command (/ccm, /fec or /fecp; the slash
handlers FECM, FECURSOR and FECP). Its footer description is its one-line
about.

### Blocks, indents and folds

Rows are grouped into column blocks: an option and the sub-options under it
(its fold, its GROUPS entry or its first DEPENDS option) stay together in one
column, each sub-option indented 22 a level (two at most) with a thin line up
to its parent. A wide row's sub-options start the next block in the left
column (the AFK Screen's options). Options whose parent is on another
sub-page (Dark Mode on Style, Unit Frames for Class-coloured Unit Borders)
are not indented, and nor is a wide row: Cast Bar Colour is greyed by Cast
Bars (DEPENDS) but sits on its own line (GroupParent gives a wide row no
DEPENDS parent). Clean Minimap and Character Item Levels work without the
option before them, so they sit beside it, not under it. Red Combo Points and
the reward profile sit under their row through GROUPS, layout only, never
greyed.

The cursor ring, cast progress ring and cursor trail options are folded:
hidden, not greyed, until their switch is on, then shown right under it at
once, keeping the scroll. The AFK Screen's options are not folded; they grey
out while it is off. A fold can also wait for a choice (`FOLD_CHOICES`):
Icons per Row for Clean Minimap's Drawer, Custom Cast Bar Colour for Cast
Bar Colour's Custom and Custom Stat Name Colour for Stat Name Colour's
Custom (folded under the choice row itself, so the choice alone opens it,
indented one level under the wide row).

Rows can also show only with their switch without being laid out under it
(`SHOWN_WITH`): the Stat Tracker's eight options and sixteen stat ticks. They
have no layout parent, so each is a block of its own: Layout sits beside the
switch, Show It, Panel Size, Stats per Line and Stat Name Colour take their own lines, and
the ticks go two to a line under their group headings (a fold would stack
them all in one indented column). They open and close at once with the
switch, keeping the scroll; search lists them while hidden and a jump to one
lands on the switch. Custom Stat Name Colour is both: hidden while the Stat
Tracker is off, then folded under Stat Name Colour until Custom is chosen
(`Folded` checks the switch first, then the fold); a jump to it lands on Stat
Name Colour, or on the switch while that's off.

### Greying and hand-overs

An option waiting on another (DEPENDS, every option up the chain) is greyed
(alpha .45) and refuses clicks and keys, putting its tick back; it still
shows its description. One waiting on another's choice (`NEEDS_CHOICE`:
Stats per Line on Layout's One line) greys the same way, its slider can't be
dragged and a move puts it back; the footer gives the reason ("Set Layout to
One line first."), and the Layout click frees or greys it at once. Forever Enhanced Nameplates takes both nameplate rows,
and another map addon revealing the map takes Reveal World Map: greyed, a
second muted line on the row says what handles it, the saved choice is kept.
The row grows to 46; its name, tick box and labels move up 7 together, and the
note runs from under the tick box (x 10) to 10 from the row's end (332), so
the longest note fits on its one line.

### Footer descriptions

The footer (92 tall, under the page) shows the reload hint, the signature,
Changelog, Discord and Reload UI (only with a reload waiting). Hovering a row,
or reaching it with the keyboard, shows its description instead: its name in
white and its help (`settingHelp`, else its summary), then, each only when it
applies: "Coming soon: not finished yet.", "Switch on X first." (with "(Tab >
Sub-tab)" when X is on another sub-page), the hand-over help, "Needs /reload
to apply." (the damage font: "Needs a log out to apply. A /reload won't do
it."; never on a Coming soon switch, which can't be turned on) and its
default. Rows never use the game's tooltip.

Every description, name included, fits two of the footer's lines at the
default window size (570 at 12 point, measured word by word with the glyph
widths in `Tools/SettingsMock.lua`, never under the game's; roughly 150
letters). They were rewritten short on 2026-10-11 (the user: "descriptions
are too long, shorten them"): plain, British spelling, no em dashes, the one
caveat that matters (Discard Junk When Full: never in combat, Shift skips),
no "Needs testing" (the row's "experimental" says it), no reload, "applies
immediately" or default (the footer adds those), Shift always "Hold Shift to
skip" (never "bypass"), no other addon's name (Quest Tracker: "another quest
addon's tracker"; Squirt's own addons may be named), and location words that
match this layout ("Conjuring & Trade Options below", "the row beside it").
Every row has its own `settingHelp` entry or, for rows built with their own
words (More from Squirt, the class tools heading or link), a summary written
the same way; the old card summaries stay only as search words. The reward
profile's description is how to switch, then the three stats its weights
count most ("Arms weighs damage per second, strength and hit rating most.").
TestSettingsLayout measures every row for every class, in normal, greyed and
handed-over states, and every class's reward profiles, and asserts a reload
row's help never mentions the reload. In setup the footer is 466 wide (no list
beside it): every row the walkthrough offers keeps its description to the
footer's three lines and its extras to two there too, handed over as well
(Reveal World Map's hand-over line is on the Map & Minimap page).

### Search and jump

Search matches every option, folded ones too, on its name, summary, key,
earlier names (`OLD_NAMES`, including the AFK options' old "AFK Screen: ..."
labels), its tab's and sub-tab's names, and each class's own tool words;
colour/color and grey/gray either way. Results are a scrolling list of rows,
two to a line, in tab then page order, each with a small "Tab > Sub-tab"
breadcrumb and the option's labels. Clicking one changes nothing: it opens
that tab and sub-tab, scrolls the row to the middle (a folded option: its
switch) and flashes it in the class colour.

### Keyboard

Nothing is bound. Tab in the search box gives the keyboard to a hidden edit
box (no mouse) that moves through the page's rows (Tab, Shift-Tab, up and
down arrows), acts on the focused one (Space or Enter; greyed and handed-over
rows refuse) and lets go on Escape. The focused row has a class-colour edge
and its description in the footer. The edit box has a font (an edit box needs
one before it takes text) and holds at most one letter, cleared at once.

### Welcome card and walkthrough

`Core/Integration.lua` decides once per account, after every saved copy has
loaded: `layoutWelcome` 1 and `layoutPillsVersion` = the running version
(`EraUI.version`, read from the .toc's Version as the addon loads, "dev" for
a copy without a number; it used to be typed into Init.lua and sat at 1.5.2
through 1.5.5) for
accounts that used an earlier EraUI (the same signs as the old one-time note:
update notes, welcome or setup seen, the AFK marker, or that note still
waiting), 0 and "" for fresh installs. Both are backed up. The first /era
open shows a centred card over a dimmed window ("Settings have a new
layout", Not now, Show me around); either button, or closing /era, puts it
away for good (and the old note with it). Not now leaves "You can take the
tour any time: Take the tour, at the bottom of the list." in the footer. The
card never shows during setup or when a class tool opens /era at its
controls, and opens Appearance first rather than cover the class tab.

The walkthrough (Show me around, or Take the tour any time) has six steps:
Grouped tabs (the tab list), Sub-tabs (Appearance > Dark Mode's strip), One
row per option (the rows), Descriptions (the footer), Search (the box) and
Nothing lost (the rows). A layer over the window dims all but the step's part
(outlined in the class colour, 4 round it) and takes the mouse and wheel; a
300 wide card sits beside the part where there's room (right, left, below,
above), inside the window. Skip or Back, Next or Done; Escape or closing /era
ends it. The old "New layout" banner is gone; `layoutNotice` is still decided
and backed up.

### Setup walkthrough

The setup pages use the same rows. The style page is all of Appearance but
Presets (the Look choice, Dark Mode's options and the class colours; it may
scroll). The option pages are, in order: Action Bars, Map & Minimap, Quests,
Bags & Vendors, Chat & Names, Group & Invites and Screen & Cursor, each with
its section headings and without its reload-only looks (Classic Chat
Dragging stays) or Update Notice (Action Bars offers Upgrade Spell Ranks with
the rest, it needs no reload). Show All Spell Ranks joins Action Bars,
Tooltip IDs joins Chat & Names (after Click Links Again to Close), and
Class-coloured Chat Names joins Chat & Names when the style page is skipped,
so every option the walkthrough offered before is still offered once. An
option waiting on a look left out (Show Gryphons with the Action Bars look
off) is left out with it. Of the setup pages, the style page and Screen &
Cursor scroll. On the finish page the damage font question ("Yes, log out" /
"No, later") sits 11 above the footer's line (`FOOTER_H` + 12), never on it.

### New-player hints

The hints pulse on the class and Casting tabs, saved by tab number in the
per-character onboarding CVar and backup, so the tab order is versioned:
`discoveryHintsVersion` 3 is the grouped order (class 6, Casting 7); version 2
(2 and 5) and version 1 (12 and 13) move once when settings initialise, after
both saved copies have loaded. Setup finished before the hints existed (no
version, stored as 0) gets both.

### Lua limits

The game refuses a function with more than 60 upvalues or 200 live locals.
`Core/Settings.lua` keeps the rules, the help texts, each option's click
handler (`MakeCheck`) and the setup walkthrough, with the rows built by
separate builder functions; the navigation, rows and tour live in
`Core/SettingsNav.lua`, `Core/SettingsRows.lua` and `Core/SettingsTour.lua` as
file-level functions that take the window as their first argument and keep
state on it. `Tools/TestLuaLimits.mjs` checks every file.

## Tab list width

Every tab name fits inside its tab (188 x 28) and ends before the sidebar
divider. The tab font is Friz Quadrata at 13 and the text starts 36 in;
measured in game (2026-10-01), Frames & Nameplates is about 146 wide and
Windows & Tooltips about 136. The list is `NAV_WIDTH` 212 with 188 tabs (12
in from the window edge, 13 short of the divider). The pages start just right
of it (`PAGE_LEFT`, `VIEW_LEFT`) and keep their 718 width. Each tab label is
held inside its tab (LEFT 36, RIGHT -2, one line, 150 of room), so a name that
renders wider at another UI scale is cut short inside the highlight instead of
crossing the divider. The tabs sit between the search box and Take the tour.

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
arrive. Out of combat a row first asks `C_CVar.GetCVarInfo`; a secure or
read-only switch is not written and the row says "Only Options > Interface
can change this portrait setting." Otherwise it writes the CVar with
`SetCVar`, reads it back (`GetCVarBool` giving nothing means the game has no
such switch), and then redraws the portraits itself by calling the game's
`UnitFramePortrait_Update` on the player, target, focus, both
targets-of-target and the active party frames (read only, each in a `pcall`,
nothing written on the frames). If Blizzard's own redraw already ran, this is
a harmless second one. If the game kept its old value, the row follows the
game and says "The game kept its own portrait setting. Change it in Options >
Interface." The two lines tell the two refusals apart in game. A `CVAR_UPDATE`
watcher keeps both rows in step when the switch is flipped in the game's
Options window, with /era open or not; only EraUI's rows change there. In
combat the rows refuse, as before.

## Viewport and class pages

`Core/SettingsLayout.lua` provides a clipped content viewport, pinned by two
corners, between the header (under the sub-tabs when the tab has them) and
the footer. Every page, search and setup page lays out its headings and
blocks, measuring each row plus its inline panel, and advances by the taller
block in each two-block line. The scroll range updates when panels expand,
collapse or change visibility; shorter content clamps the current scroll
position. Setup mode repositions the same viewport rather than reparenting
its rows.

Inline panels belong to the content frame, not the root settings window.
`ClassTools.BindInlinePanel` connects size/visibility changes to a coalesced
layout update. Supply sliders reserve the height of their labels as well as
the track. Search never shows the rows themselves (it lists result rows), so
no class box opens there.

A class box (Class Reminders & Buffs' options, a hunter's Pet Feeding
Options, a mage's Conjuring & Trade Options) opens 6 under its row, which
takes the whole line, and spans the page (718; `T.BOX_WIDTH` in
Modules/ClassTools.lua). Its options sit in the page's two columns, lined up
with the rows: tick boxes at 10 and 376, names at 34 and 400, buttons a
column wide (332). The switches use the rows' square tick box
(`Rows.TickBox`, a local copy in ClassTools when the rows aren't loaded, as in
the module tests) with the inner square in the class colour; the ON/OFF
tracks are gone. Class Reminders & Buffs: the switches two to a line (for a
rogue: Show during combat | Clickable reminders, Click to apply poisons |
Show all reminders), then the buttons in a grid (Main hand | Off hand poison,
Alert size | Reset alert positions, Advanced). Advanced puts four to a line,
half a column each (160, the name 132 at 12 point); a reminder with its own
button (SEAL!, AURA!, PET LOW HEALTH!) fills a column with the button at its
end (a choice button 176 there), a plain switch whose name needs more than
132 (over 17 capitals, or wider as the game measures it: CREATE HEALTHSTONE!,
SHADOW PROTECTION!) fills a column too, and a switch with a choice button
beside it keeps the two in one column. A choice button shows just the
choice ("Any blessing  >", "Blessing of Salvation  >"): its switch's name
before it says what it picks. The test measures the box's names, buttons and
every choice a button can show with the glyph widths (`M.Glyphs`), not the
mock's six a letter. `T.SubLayout` lays the
hunter and mage boxes out the same way, starting a new line for a new kind
of option (switches, buttons, sliders): the mage's two conjure buttons side
by side with each stack slider under its button. Every behaviour is as
before: greyed (and disabled) while its switch is off, with the hint line at
the bottom, Advanced folding, the greyed Click pet reminders in combat and
Click to apply poisons until Clickable reminders is on. The class tab still
scrolls when the boxes are taller than the window (measured: a hunter, mage
or rogue with Advanced open at the default size; every class in a shorter
window).

Mage conjure slots inside settings are ordinary presentation controls. Their
secure spell buttons are separate children of UIParent, positioned using
absolute coordinates and matching effective scale. They have no parent or
anchor dependency on settings. Only fully visible slots receive click
targets. Scroll, layout, window dragging, visibility and scale changes
synchronize these targets outside combat. Native visibility state drivers hide
them during combat; no insecure combat handler changes their attributes,
visibility, position or size. Combat exit refreshes the selected ranks and
geometry. The welcome card and the walkthrough open Appearance first, so no
conjure button sits over their dim layer.

## Tests

Run `fengari Tools/TestSettingsLayout.lua` and `Tools/TestSettingsTour.lua`
(the project's fengari.cmd) from the addon root. Both use the frame mock and
session in `Tools/SettingsMock.lua` (frames know their children, so OnShow
and OnHide run down a branch, as in the client), loading the real settings,
navigation, rows, tour and class modules. TestSettingsLayout checks the map
(groups, tab order, names, descriptions, icons, sub-tabs, section titles and
every row in order, each option on exactly one sub-page), the class tab per
class, sub-options after their parent with their indent and line, folds,
greying chains and their footer words, hand-overs, search (spellings, tab and
sub-tab names, old names, class tool words, breadcrumbs, the jump and its
flash), rows and tick boxes (sizes, colours, a click anywhere, the
keyboard), the footer and every kind of row's extras, every description
fitting two footer lines (every class, every state, every reward profile),
the words after a name (which, their colours, small and lower case, no box
or border, right after the name on its line, fitting the row, their version
gating, nothing about moving), the Darkness row (its value once, nothing
after the slider), the three More from Squirt rows (links, Open, icons, fit),
the hint migration, the setup pages, combat, tidy labels and tab widths, the
class boxes (the page's width under a whole-line row, both columns used,
square class-colour tick boxes and no tracks, nothing overlapping, inside
the box, the hint under the options, the rogue's and mage's arrangement),
the portrait switches and the mage's secure overlays as before.
TestSettingsTour checks the welcome card (who, when, its words, its
buttons, the keyboard) and the six walkthrough steps (targets, the card's
place, Skip, Back, Next, Done, Escape, closing; none mentions moving).
`Tools/TestReminderClicks.lua` checks the reminders box's places (two
columns, Advanced's grid) with the module alone. `Tools/TestPersistence.lua`
checks who gets the card and the words, that both are backed up, and What's
New with the version from the .toc (an account marked at the stuck 1.5.2
sees the newest notes once). `Tools/TestVersion.mjs` loads Core/Init.lua
with the .toc's Version answered by the game's metadata calls (and "dev"
for a copy without a number); `Tools/TestRules.mjs` checks no version is
typed into Init.lua.

The simulation does not reproduce WoW's taint engine. In-game verification
still needs a mage with learned conjuring spells: open settings, scroll and
move the window, enter combat, navigate/search/close/reopen, then leave combat
and conjure.
