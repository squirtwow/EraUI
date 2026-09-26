# Reminder detection

The 1.0.4 detection changes use independently checked Blizzard data for Forever
1.60.1.70009, not another addon's implementation or tables.

## Sources

- `https://wago.tools/db2/SpellItemEnchantment/csv?build=1.60.1.70009`
  identifies weapon imbues, rogue poisons and separate temporary totem coatings.
- `https://wago.tools/db2/CreatureFamily/csv?build=1.60.1.70009`
  identifies Imp 23, Voidwalker 16, Succubus 17, Felhunter 15 and Felguard 310.
- `https://wago.tools/db2/SpellName/csv?build=1.60.1.70009`
  confirms Windfury Totem ranks 8512/10613/10614, Trueshot ranks 20905/20906,
  starter totem spell IDs and Summon Felguard 427733. The previous 30146 choice
  identifier remains accepted for existing preferences; unavailable spells do
  not enable reminders.
- API documentation at `Gethe/wow-ui-source` commit
  `bd2470aed543f72697a044e989285b6c83e63f73`, especially
  `PaperDollInfoDocumentation.lua`, `CreatureInfoDocumentation.lua`,
  `TotemDocumentation.lua` and `Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua`.

## Semantics

- Pet checks require a living pet. Selected demons match localized creature
  family names obtained from Blizzard's family API, not the pet's personal name.
- Both poison displays use `ClassTools.WeaponCoating`. Modern slot data is
  preferred; legacy off-hand data starts at the fifth API return. Empty slots
  and shields do not need coatings. Unknown coating types remain unconfirmed.
  Zero charges alone do not mean the enchant is depleted.
- Shaman selection requires the chosen weapon imbue. Windfury Totem's temporary
  coating is distinct from the player's Windfury Weapon. The generic totem
  check means at least one active totem; the optional Windfury check requires
  the player's active Windfury Totem, by spell ID or localized name.
- Group checks exclude duplicate player tokens and members known to be dead,
  offline, hostile or out of range. Party-only effects restrict raid checks to
  the player's subgroup. Intellect, Spirit and selected Wisdom skip warriors and rogues, while
  druids remain eligible in animal forms. Unknown aura data never counts as an
  active buff. Group caches clear on aura/roster/world/combat-exit events.
- Soulstone application requires a stone in bags and no protected checked
  member. It does not request one stone per member. Unknown member auras defer
  this reminder; disabling group checks makes it self-only.

Run `lua Tools/TestClassReminders.lua` from the addon root for API simulations.
Real cross-class, group and combat behavior still needs in-game testing.
