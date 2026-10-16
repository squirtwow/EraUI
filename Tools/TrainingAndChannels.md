# Training Guide and channel timing

Native reference: `Gethe/wow-ui-source` commit
`bd2470aed543f72697a044e989285b6c83e63f73` (Forever 1.60.1.70009).

## Training Guide

This is an original, optional module, enabled by default for fresh settings and
resets while respecting existing saved choices. Its spellbook button replaces the previous
external-addon shortcut. The setting is staged until reload alongside Spellbook.
The information-only page is a child of the Classic spellbook. It replaces the
visible spell grid, search and page controls while selected. Switching in or
out is guarded in combat, since the native spell click layer is protected.
The click layer remains hidden during training-tab refreshes and reopening.
Because of that, the spellbook key's secure click raises the layer on this tab,
so out of combat the key closes the book whenever the guide shows. The spell
pages under the layer stay off while the guide is selected, so a layer the key
raises in combat has nothing clickable over the guide.

`C_SpellBook.GetSpellBookItemInfo` provides names, ranks, spell IDs and future
entries. `C_Spell.GetSpellLevelLearned` supplies the future entries' levels.
`Tools/GenerateTrainingData.mjs` independently bundles exact-build SkillLine,
SkillLineAbility, SkillRaceClassInfo, SpellLevels, SpellName, Spell, SpellMisc,
SpellEffect, Talent and class trait tree (SkillLineXTraitTree, TraitNode,
TraitNodeXTraitNodeEntry, TraitNodeEntry, TraitDefinition) exports. SHA-256
hashes and URLs are recorded in `Tools/TrainingDataSources.json`. Class
spellbook lines exclude pet skill lines, direct talent purchases (the Classic
Talent table and every spell defined in a class's trait tree), hidden or
descriptionless implementation spells, teaching wrappers and Revoke (1325499),
which Salvation's trainer spell teaches with it. Skill-granted passives use their class-specific skill level.
Duplicate same-name/rank/level/race helpers are collapsed into a single entry.
Race masks are combined across duplicate spell records and filtered at runtime.

The export also contains seasonal/internal records. `TrainingLevelRules.mjs`
requires an explicit BaseLevel, a non-seasonal reference corroborating a
non-default SpellLevel (or a documented priced starter), or a class-specific
skill requirement. Default level-one seasonal records are excluded. Spells
reused and relevelled by Forever are retained rather than rejecting every ID
that originated in a season. The source manifest records per-entry decisions;
these checks improve filtering but are not a server-side trainer catalog.
Native future entries with only a default level of 1 are also omitted.

Data build: 1.60.1.70170 (regenerated 2026-10-02; 70009 and 70124 exports were
identical). The Wowhead price pages are the same cached copies as before, so
their checksums are unchanged. The only catalog change is Druid: SkillLineAbility
now marks Tiger's Fury (5217) as not trainer-learned (AcquireMethod 3) and Primal
Bite ranks 1-4 (407995, 1238069, 1238070, 1238073; levels 25/36/48/60) as
trainer-learned. Primal Bite has no Classic price reference, so it shows as an
unknown price until a trainer visit records one.

Data build: 1.60.1.70425 (regenerated 2026-10-16 from an empty cache; the
Wowhead price pages were fetched again and give the same prices). Forever's
talents are trait trees, not the Classic Talent table, so 20 talents had been
listed as trainer spells (Spearing Strike, Swift Judgement, Light's Vigil,
Summon Hawk, Strider Kick, Mutilate, Venom, Binding Heal, Penance, Lava Burst
and Riptide rank 1, Arcane Blast and Ice Lance rank 1, Bane of Havoc,
Conflagrate, Incinerate, Wrack, Feral Charge, Primal Bite rank 1 and Wild
Growth); they are gone, and the new Arcane Wrath (1326079) and Prayer of
Mending rank 1 (401859) talents never appear. Their trained higher ranks stay.
Changes from the build: Shred rank 1 at 20, Seal of Fury rank 3 at 26,
Berserker Rage at 30, Mana Tide Totem ranks 2-4 at 38/48/58 (1325256 new),
Lava Burst ranks 2-4 at 40/50/60 (1326047 new), Frost Blast ranks 1-3
(1326053-1326055) at 24/36/48, Prayer of Mending ranks 2-3 (1240826/1240827)
now trainer-taught at 50/60, and 1038/25895 renamed Salvation and Mass
Salvation. Sense Undead (5502) drops out: its SpellLevel is now 0 and it comes
from quest 1652 or Libram item 5676, never a trainer. New spells have no price
reference yet, so they show as unknown until a trainer visit.

Known entries are checked separately, with exact rank keys and higher-rank
recognition for hidden lower ranks. Future entries are not treated as learned.

The exact-build trainer UI uses `GetTrainerServiceInfo` for name, type, icon,
level, rank and category; `GetTrainerServiceCost` supplies the current quote.
`C_Trainer.GetTrainerType` distinguishes General, Tradeskills and Pet trainers.
Only General trainer catalogs with a matching class/skill-line category are
recorded. Profession and pet catalogs are excluded. Native service filters are
temporarily enabled to include future and learned ranks, then restored even if
reading fails. Synchronous filter events are ignored while capturing.

Offers from visited class trainers merge per character in
`classTools.trainingGuide`, covered by the realm-aware recovery system. Ability
requirements are stored as name/boolean pairs within the recovery depth limit.
The catalog also includes factual Classic base-price references extracted from
non-seasonal Wowhead class-ability records. These are labelled references, not verified Forever
quotes. Missing prices are not extrapolated from character level. Captured prices
reflect the last visit for each offer, including then-current discounts, and can
refine the bundled references. Visits are optional, not needed for population.
The cache saves the client build (`GetBuildInfo`) it was recorded on and is
cleared when the build changes, since a patch can move levels, prices and
names; caches from before this was saved are cleared once. A quote whose name
and rank match no row joins the row with its spell ID instead, under the
current name, so a renamed spell (Blessing of Salvation to Salvation in
70425) is listed and counted once.

The UI separates current and all-listed-unlearned totals. Unknown prices have
an explicit question-mark count rather than becoming zero-cost offers. Learning
and leveling refresh the display through native events. Search filters the
embedded rows, while totals remain for the complete unlearned list. Grouping
separates available spells, missing rank/ability requirements, the next two
levels, and later spells.

## Channels

The Advanced bar previously preferred `UnitChannelDuration` even with public
timestamps, then rebuilt its state on every damage update. The Classic native
bar also recomputes its maximum from the shortened span on channel updates.
These paths could mix timer sources or renormalize the progress display.

`Core/CastTiming.lua` consumes public player timestamps with one `GetTime` clock.
Channels count down to the updated endpoint while retaining their original
scale when damage shortens them. Genuine extensions can increase the scale; a
new channel resets it. Classic post-hooks affect the displayed scale/value and
spark only, leaving native completion/interrupt handling in place. Empowered
casts stay on the native path. The Advanced bar uses native Duration objects
only when public timestamps are unavailable. A one-frame channel-info gap on
an update gets one deferred retry rather than immediately hiding the bar.

## Verification

- `node Tools/TestTrainingSources.mjs`: seasonal/default-level regression cases
  and recorded evidence for every packaged class entry.
- `Tools/TestTrainingGuide.lua`: live filters, future/known ranks, quotes, totals,
  prerequisites, level-up, class-only collection, failed captures and isolation.
- `Tools/TestSpellBookToggle.lua`: the spellbook key on the spell pages and on
  the Training Guide, in and out of combat, with and without spell dragging.
- `Tools/TestPersistence.lua`: training quotes and prerequisite maps survive
  missing SavedVariables, with character/realm separation.
- `Tools/TestChannelTiming.lua`: both actual cast-bar modules with shortened
  endpoints and a deliberately stale Duration API, plus stop/new-channel cases.

Real client checks still cover the taming rod under damage, trainer categories
and prices, spellbook-button visibility, and the panel's appearance.
