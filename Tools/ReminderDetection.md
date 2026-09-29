# Reminder detection

The 1.0.4 detection changes use independently checked Blizzard data for Forever
1.60.1.70009, not another addon's implementation or tables.

## Sources

- `https://wago.tools/db2/SpellItemEnchantment/csv?build=1.60.1.70009`
  identifies weapon imbues, rogue poisons and separate temporary totem coatings.
- `https://wago.tools/db2/CreatureFamily/csv?build=1.60.1.70009`
  identifies Imp 23, Voidwalker 16, Succubus 17 and Felhunter 15.
- `https://wago.tools/db2/SpellName/csv?build=1.60.1.70009`
  confirms Windfury Totem ranks 8512/10613/10614, Trueshot ranks 20905/20906
  and starter totem spell IDs.
- Forever is level 60 content. Its SpellName, SkillLineAbility and Talent data
  have no Summon Water Elemental (31687), Fire or Earth Elemental Totem
  (2894/2062), Summon Felguard as a class spell (30146; 427733 has no class
  skill line) or Blessing of Sanctuary (20911-20914, 25899), so those
  reminders and choices are gone. A saved Felguard or Sanctuary choice reads
  as Any; old saved switches for them are ignored. `Tools/TestClassReminders.lua`
  audits every reminder spell against `Modules/TrainingData.lua`.
- Forever's own ranks and choices (added 2026-09-29) were checked in the same
  build's SkillLineAbility, SpellLevels, Talent and SpellEffect (each applies
  its aura to the caster under its own spell ID) and on Wowhead Forever
  (trainer, quest or talent): Seal of Righteousness 20154 (learned
  automatically at level 1), Seal of Wisdom 20356/20357, Seal of Command
  20915/20918-20920 (trainer ranks of the talent), Seal of Fury 1311649,
  1311656, 20163, 20419, 20421-20423, Retribution Aura 10298-10301, Shadow,
  Fire and Frost Resistance Aura 19895/19896, 19891/19899/19900 and
  19888/19897/19898, Ice Armor 7320/10219/10220, Trueshot Aura 1299346 (the
  talent, rank 1) and 1299348 (trainer rank 2), Aspect of the Beast
  1299445-1299447 (trainer, levels 40/50/60) and Summon Incubus 713 (quest).
  Seal and aura clicks cast the last listed spell you know, so Seal of Fury
  leads its list and the new auras sit before Shadow Resistance Aura: clicks
  cast what they did before.
- Left out: Aspect of the Viper 415423, Aspect of the Falcon 469145 and Seal of
  Martyrdom 407798 (407799 is its weapon hit, not a buff). They are Season of
  Discovery spells in Forever's client with no Forever learning level
  (Martyrdom's AcquireMethod is 3, never learned) and no trainer or quest on
  Wowhead Forever. The audit's "never lists" table keeps them out. "Any
  aspect" still accepts any "Aspect of" buff by name.
- CreatureFamily also has Incubus 302, but the client's Creature table does
  not include the summoned Incubus (creature 185317) and Wowhead Forever shows
  no family, so the Incubus choice has none: any living demon counts while it
  is chosen. If `/dump UnitCreatureFamily("pet")` with the Incubus out says
  "Incubus", `family=302` can be added.
- API documentation at `Gethe/wow-ui-source` commit
  `bd2470aed543f72697a044e989285b6c83e63f73`, especially
  `PaperDollInfoDocumentation.lua`, `CreatureInfoDocumentation.lua`,
  `TotemDocumentation.lua` and `Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua`.

## Semantics

- Pet checks require a living pet. Selected demons match localized creature
  family names obtained from Blizzard's family API, not the pet's personal name.
  The Incubus choice has no family yet, so any living demon satisfies it.
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
- On a flight path (`UnitOnTaxi("player")`) every alert hides and clicks are
  disarmed, until 2 seconds after landing so a pet the game brings back does
  not flash SUMMON PET!. A hidden, failing or missing taxi answer counts as
  not flying. PLAYER_CONTROL_LOST/GAINED and UNIT_FLAGS refresh the alerts.
  The rogue Poison Reminders panel (which takes over missing-poison alerts
  while on) waits the same way, keeping only its positioning preview. Both
  read one shared flight clock, `T.Flying` in `Modules/ClassTools.lua`.
- Soulstone application requires a stone in bags and no protected checked
  member. It does not request one stone per member. Unknown member auras defer
  this reminder; disabling group checks makes it self-only.

Run `lua Tools/TestClassReminders.lua` from the addon root for API simulations.
Real cross-class, group and combat behavior still needs in-game testing.
