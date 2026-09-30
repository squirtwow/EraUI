# EraUI

Classic-era interface for **World of Warcraft: Forever**, with a full set of
quality-of-life options on top. Every piece is optional and can be switched on
or off in the settings.

## Presets

- Classic + Quality of Life (recommended), Classic look only, or Quality of
  Life only, which keeps Blizzard's modern interface
- Chosen on the first page of `/era setup`, or switched any time with the
  Presets button in `/era`, which shows your current preset
- Presets switch only the Classic look; Quality of Life choices are never
  changed. Options that need a Classic piece, such as the Training Guide, are
  greyed out while it is off

## The classic look

- Action bar: the stone band with gryphons, page arrows, micro menu, bag
  buttons and the experience bar in their original spots (optional one-bar mode
  and default-bar sizing)
- Unit frames: player, target, target of target, focus, pet and party frames
  with the original art and bars, Classic debuff borders and aura hover boxes
- Dark Mode: darker decorative artwork, with thin dark borders round your buff
  and debuff icons, and optional soft shadows behind them
- Tooltips: translucent dark backgrounds and thin, bevelled grey borders
  with softened corners, including linked items and item comparisons, and
  optional class colours on player tooltips
- Cast bars and mirror timers: player, pet, target and focus cast bars; classic
  breath and fatigue timers
- Minimap and nameplates: the round classic minimap with its zone name and old
  tracking, and 1.x-style nameplates
- Windows: character sheet, spellbook, talents, professions, trade skills,
  trainers, quest log and tracker, bags and bank, game menu, settings window,
  Who list, guild roster and group finder
- Other windows: trade, taxi, macros, calendar, achievements, collections and
  more, with their own Other Windows switch
- Damage meter: optional Classic look for Blizzard's damage meter, including
  extra windows and the spell breakdown (off by default)
- Questie integration: quest-log clicks open the selected quest in EraUI's
  Classic quest log when enabled; objective and map-icon navigation stays on the map.
  With Questie installed, choose between the Classic tracker and Questie's own
  tracker (Questie's currently lists no quests on WoW Forever, so the Classic
  tracker is recommended). Blizzard's tracker stays hidden while Questie's
  replaces it, including during combat
- Map quest details: the parchment and scrolling description fit the panel's
  available height, with quest action buttons at the bottom
- Combo points: floating orbs in gold or red, draggable and resizable

## Quality of life

- Vendor prices, bag-space counter, quest levels and map quest objectives
- Auto-sell junk and auto-repair at vendors
- Class colours in chat, optional secondary names, highest-rank spell filtering
- Damage and healing text: choose the font of the numbers, your own heals
  included (Pepsi by default, or thirteen others), and their size, with a
  live sample. A new font shows after you log out and back in
- Click an item or spell link in chat again to close its tooltip
- Update notice: tells you in chat when someone in your guild or group has a
  newer EraUI (the tick under Presets in `/era`)
- AFK Screen (on by default): your class-coloured EraUI banner, your character,
  your details and a famous Classic line for your class while you're away
- Bag Item Levels (optional): item levels in quality colours, upgrade arrows and
  a red icon on gear you can't equip
- Energy, rage, mana and druid resource bars, swing timers and a ranged swing timer
- Advanced cast bar with ticks and latency display
- Movable world map: drag its header and resize it from corners or edges,
  scaling the whole window. It stays where you put it, even in combat. Normal
  and expanded layouts are remembered separately; the quest list overlays the
  map without squeezing the artwork
- Important Debuffs on Portraits: crowd-control icons and countdowns on player,
  target, focus and party portraits, in combat too (off by default)
- Reveal World Map: supported unexplored terrain appears with darker shading
- Class reminders: class-coloured, independently draggable alerts for buffs,
  pets, weapon coatings and supplies, with optional party and raid checks.
  Hunters have separate SUMMON PET and PET DEAD alerts. Optional Clickable
  reminders (off by default) let you cast supported spells by clicking their
  icons outside combat; drag the text to move. On Any, clicking a blessing,
  imbue or demon reminder casts the only one you know or the one you cast last;
  or pick one under Advanced. A buff you're missing is cast on you, and "Not
  enough mana" (rage for a warrior's shout) shows until you can cast it. All
  reminders hide while you're on a flight path. Paladins can pick a seal and
  aura under Advanced, and hunters and warlocks can turn on PET LOW HEALTH!
- Class tools: hunter feeding, mage supplies, rogue poisons
- Optional Training Guide tab inside the Classic spellbook: bundled Forever
  spell levels, unlearned ranks, availability groups and search work immediately.
  Reference cost totals use Classic base prices, marking unverified prices with
  ?. Spells taught by class quests name the quest and where it starts, for
  your race and faction. Enabled by default for fresh settings and resets, as
  is tooltip styling.
  Existing saved choices are respected; change either option in `/era` and reload.
- Coordinates, clean minimap, cursor ring, draggable chat and more
- A screen-fitting, scrollable "what's new" window after each update, in your class colour
- More from Squirt: a tab at the bottom of `/era` listing my other addons

## Commands

- `/era` opens the settings window, with Presets at the top
- `/era setup` replays the guided first-run setup, starting with the presets
- `/era welcome` shows the welcome screen again
- `/era updates` shows the latest update notes again
- `/era reminders` opens class-reminder settings
- `/era discord` gives the Discord invite to copy, for bugs and ideas (the
  bottom of `/era` and the what's new window have a Discord button too)
- `/era status` opens a selectable diagnostics report
- `/era audit` runs the addon audit report
- `/era mapdebug` opens map diagnostics
- `/era version` shows the loaded version
- `/era reset` restores default settings and reloads automatically; use it outside combat

Most options apply immediately; the settings panel marks the few that need a
reload. General settings and reminder layouts are shared across your characters;
swing toggles and class-tool preferences are remembered per character and realm.
Settings recovery also keeps a copy of supported preferences and positions in
addon CVars, but the game doesn't save these to disk, so the copy is gone once
you close the game. Windows take the class colour of the character you're
playing.
Quiet Mode (hide status messages) is on by default.

## Install

Copy the `EraUI` folder into `Interface/AddOns`, or install through
[CurseForge](https://www.curseforge.com/wow/addons/eraui), then enable it in the
client's AddOns menu.

## Links

- CurseForge: <https://www.curseforge.com/wow/addons/eraui>
- Changelog: [CHANGELOG.txt](CHANGELOG.txt)

## License

All rights reserved. See [LICENSE.txt](LICENSE.txt). The bundled damage-text
fonts keep their own licences; see [Media/Fonts/README.txt](Media/Fonts/README.txt).
