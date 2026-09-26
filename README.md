# EraUI

Classic-era interface for **World of Warcraft: Forever**, with a full set of
quality-of-life options on top. Every piece is optional and can be switched on
or off in the settings.

## The classic look

- Action bar: the stone band with gryphons, page arrows, micro menu, bag
  buttons and the experience bar in their original spots (optional one-bar mode
  and default-bar sizing)
- Unit frames: player, target, target of target, focus, pet and party frames
  with the original art and bars, Classic debuff borders and aura hover boxes
- Tooltips: translucent dark backgrounds and thin, bevelled grey borders
  with softened corners, including linked items and item comparisons
- Cast bars and mirror timers: player, pet, target and focus cast bars; classic
  breath and fatigue timers
- Minimap and nameplates: the round classic minimap with its zone name and old
  tracking, and 1.x-style nameplates
- Windows: character sheet, spellbook, talents, professions, trade skills,
  trainers, quest log and tracker, bags and bank, game menu, settings window,
  Who list, guild roster and group finder
- Combo points: floating orbs in gold or red, draggable and resizable

## Quality of life

- Vendor prices, bag-space counter, quest levels and map quest objectives
- Auto-sell junk and auto-repair at vendors
- Class colours in chat, optional secondary names, highest-rank spell filtering
- Energy, rage, mana and druid resource bars, swing timers and a ranged swing timer
- Advanced cast bar with ticks and latency display
- Movable world map: drag its header and resize proportionally from corners or
  edges. Normal and expanded layouts are remembered separately; the quest list
  overlays the map without squeezing the artwork
- Reveal World Map: supported unexplored terrain appears with darker shading
- Class reminders: class-coloured, independently draggable alerts for buffs,
  pets, weapon coatings and supplies, with optional party and raid checks
- Class tools: hunter feeding, mage supplies, rogue poisons
- Optional Training Guide tab inside the Classic spellbook: bundled Forever
  spell levels, unlearned ranks, availability groups and search work immediately.
  Reference cost totals use Classic base prices, marking unverified prices with
  ?. Enabled by default for fresh settings and resets, as is tooltip styling.
  Existing saved choices are respected; change either option in `/era` and reload.
- Coordinates, clean minimap, cursor ring, draggable chat and more
- A screen-fitting, scrollable "what's new" window after each update, in your class colour

## Commands

- `/era` opens the settings window
- `/era setup` replays the guided first-run setup
- `/era welcome` shows the welcome screen again
- `/era updates` shows the latest update notes again
- `/era reminders` opens class-reminder settings
- `/era status` opens a selectable diagnostics report
- `/era audit` runs the addon audit report
- `/era mapdebug` opens map diagnostics
- `/era version` shows the loaded version
- `/era reset` restores defaults (reload afterwards)

Most options apply immediately; the settings panel marks the few that need a
reload. General settings and reminder layouts are shared across your characters;
swing toggles and class-tool preferences are remembered per character and realm.
Settings recovery also mirrors supported preferences and positions through addon
CVars. Windows take the class colour of the character you're playing.
Quiet Mode (hide status messages) is on by default.

## Install

Copy the `EraUI` folder into `Interface/AddOns`, or install through
[CurseForge](https://www.curseforge.com/wow/addons/eraui), then enable it in the
client's AddOns menu.

## Links

- CurseForge: <https://www.curseforge.com/wow/addons/eraui>
- Changelog: [CHANGELOG.txt](CHANGELOG.txt)

## License

All rights reserved. See [LICENSE.txt](LICENSE.txt).
