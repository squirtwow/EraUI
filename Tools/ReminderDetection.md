# Reminder detection

The 1.0.4 detection changes use independently checked Blizzard data for Forever
1.60.1.70009, not another addon's implementation or tables.

Rechecked on 1.60.1.70170 (2026-10-02): no reminder ID changed. That build's
SpellItemEnchantment only edits effect columns (Flametongue ranks, SoD-style
weapon enchants) and moves row 7567; its CreatureFamily only changes Fox's pet
skill line. The demon families, coating IDs and audited spells are unaffected.

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
  Seals and auras are choices like blessings: under /era Advanced the
  "SEAL!" and "AURA!" switches take a whole
  line each (`wide`), like PET LOW HEALTH!, with the choice button in the line
  ("Any seal  >", "Seal of Fury  >") and help on hover. Every id belongs to
  one choice, named and ranked as in TrainingData (Seal of Command: talent
  20375, then trainer ranks 20915/20918-20920). Before, a click cast the last
  listed spell you knew, so a level 60 paladin got Seal of Light and Shadow
  Resistance Aura. On Any with several known and none cast yet, the click
  casts nothing and the icon is a question mark rather than one spell's
  (blessings, demons and imbues too), until you cast one.
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
- The rogue's POISON! (one reminder for both hands, after 1.5.1; it replaced
  the two hand alerts and the separate Poison Reminders panel) uses
  `ClassTools.WeaponCoating`. Modern slot data is preferred; legacy off-hand
  data starts at the fifth API return. Empty slots and shields do not need
  coatings and are never mentioned. Unknown coating types remain unconfirmed.
  A hand needs a poison when it has none, another coating, 60 seconds or less
  left, or 1 to 10 charges left; zero charges alone do not mean the enchant
  is depleted, and hidden time or charges are never read as low. It applies
  from the first level any poison can be used (20, from
  `Modules/PoisonData.lua`), with Poisons (2842, or Forever's 1298494)
  learned or a poison your level allows in your bags.
- POISON!'s click (`Modules/ClassReminderPoisons.lua`): each hand has a pick
  (`poisonPickMain` / `poisonPickOff` in the character's class tools
  settings, so each rogue has its own, saved as the family's rank 1 item;
  only families your level allows are offered; defaults Instant, and Deadly
  from its first level for the off hand, Instant before, also below level 20
  where nothing can be picked yet). With
  Clickable reminders and "Click to apply poisons" (`reminderPoisonClick`,
  off by default, Needs testing) on, one secure button over the icon has
  `type1`/`type2` "item", `item1`/`item2` "item:<id>" (the highest rank in
  your bags your level allows) and `target-slot1` 16 / `target-slot2` 17:
  Blizzard's SecureActionButton uses the item, then, while the cursor waits
  for an item (`SpellCanTargetItem`), uses the inventory slot. Only a hand
  that needs a poison and has one to use is armed. Attributes change only
  out of combat; a `[combat] 1; 0` state driver clears both clicks and hides
  the button the moment a fight starts, and the next refresh after it
  re-arms. The driver hands its snippet the number 1, not the text "1"
  (Forever 70170 SecureStateDriver.lua resolveDriver: `tonumber(newValue)`),
  so the snippets accept both. The bag notes name each hand's pick only
  while a click is live; otherwise POISON! only says when no poison at all
  can be used ("No poison in your bags", "Your poisons need a higher level").
  Forever applies these poisons with spell effect 360 (see
  `Tools/PoisonDataSources.json`); that the target slot is honoured for it
  is the in-game check still to do.
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
  Every reminder panel reads one shared flight clock, `T.Flying` in
  `Modules/ClassTools.lua`.
- A picked seal or aura counts only itself; on Any every seal or aura counts.
  On Any a click casts the only one you know, or else the one you cast last
  (`reminderLast_PALADIN_seal` / `_aura`); with several known and none cast
  yet it casts nothing and hovering says so. Seals change all fight long, so
  one cast in combat is remembered at once and backed up when combat ends.
- PET LOW HEALTH! (off by default; added 2026-09-30) is the
  hunter's Mend Pet (136, 3111, 3661, 3662, 13542-13544) and the warlock's
  Health Funnel (755, 3698-3700, 11693-11695), ranks as in TrainingData. It
  shows while a living pet is below the limit set with the Below button in
  /era Advanced (`reminderLimit_<CLASS>_petHealth`, 20 to 60% in fives,
  default 35; anything else reads as 35). A dead or missing pet is left to
  PET DEAD! or SUMMON PET!. Its switch takes a whole line (label "PET LOW
  HEALTH!", Below button beside the switch, help on hover),
  and it is listed last so an unseen row never pushes other alerts down.
- Secrecy, from the `forever` branch's API documentation: UnitHealth has
  `SecretReturns`; UnitHealthMax is secret only for units that aren't
  player-controlled; UnitExists and UnitIsDeadOrGhost are never secret.
  UnitHealthPercent(unit, usePredicted, curve) returns a 0 to 1 fraction, or
  the curve evaluated at it, and is secret when UnitHealth is. Frame SetAlpha
  accepts secret values from addons (`AllowedWhenTainted`, adding the Alpha
  secret aspect). So out of combat public health is compared
  (`health*100 < max*limit`), and when it is hidden the alert is drawn with
  mouse off and no click, and its alpha is UnitHealthPercent("pet", true,
  curve) passed straight to SetAlpha. The curve is Linear through (0,1),
  (limit-0.1%,1), (limit,0), (1,0), so it's 1 below the limit and 0 from it
  up. No hidden value is read, compared or kept. Without C_CurveUtil or
  UnitHealthPercent it stays hidden in combat. It shows in combat only with
  Show during combat on, and it hides on a flight path like every alert.
  Rows are recycled, so every other alert sets alpha 1 and mouse on when it
  is painted.
- Soulstone application requires a stone in bags and no protected checked
  member. It does not request one stone per member. Unknown member auras defer
  this reminder; disabling group checks makes it self-only.

Run `lua Tools/TestClassReminders.lua` from the addon root for API simulations.
Real cross-class, group and combat behavior still needs in-game testing.
