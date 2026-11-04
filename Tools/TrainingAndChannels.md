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
SpellEffect and class trait tree (SkillLineXTraitTree, TraitNode,
TraitNodeXTraitNodeEntry, TraitNodeEntry, TraitDefinition) exports. SHA-256
hashes and URLs are recorded in `Tools/TrainingDataSources.json`. A
SkillLineAbility row with no ClassMask takes its class skill line's class
(SkillRaceClassInfo). Class spellbook lines exclude pet skill lines, talents
(every spell defined in a class's trait tree; Forever trains many Classic
talents, so the Classic Talent table is not used), hidden or descriptionless
implementation spells, teaching wrappers and Revoke (1325499), which
Salvation's trainer spell teaches with it. Skill-granted passives use their class-specific skill level.
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

Data build: 1.60.1.70707 (regenerated 2026-10-31; the 70707 CSVs are the ones
in `C:\AddonDev\_ForeverData\changes-70707\db2-70707`, checked against fresh
wago.tools downloads, plus SkillRaceClassInfo and Talent, unchanged since
70425; the Wowhead price pages are the 70425 cached copies, so their
checksums are unchanged). Before regenerating, the generator reproduced the
shipped 70425 files byte for byte. From the client data: Righteous Fury
(25780) at 10 instead of 16 (its Classic reference price, for level 16, is
kept until a trainer visit), and Frost Blast ranks 1-3 (1326053-1326055) gone
(no learnable row). Explosive Trap Effect 13812/14314/14315 is renamed
Explosive Trap; it stays out as before, so the trap is one row per rank
(13813, 14316, 14317). Accelerant and Precision are renamed talents, still
out. wago.tools exports hold no hotfix rows, so nothing from the 28 and 30
Oct hotfixes is in this data. Trainer lists are server-side, so
`GenerateTrainingData.mjs` follows the 30 Oct hotfix notes by spell ID
(`trainerChanges` in the manifest): Blessing of Light ranks 1-3, Greater
Blessing of Light, Salvation, Mass Salvation and Revoke are left out (a trainer
that still offers one shows it again from its recorded quote). Their client
rows are still learnable, so the spellbook may still list them as future
spells: the generator writes the same IDs to `E.TrainingData.notTaught` and
`TrainingGuide:Collect` skips future entries with those IDs (a quote still
adds them back). Voice of Truth
(1310897, paladin, 20) and Binding Heal rank 1 (401937, priest, 25), which
left the talent trees, are trainer rows at the levels SpellLevels gives.
Paladin 145 -> 140, Priest 223 -> 224, Mage 185 -> 182; total 1387 -> 1380.
Not followed, for want of IDs: the hotfix's new Ferocious Bite, Lacerate and
Holy Shield ranks, Primal Bite's new levels and the reworked talents. Spell
names and ranks come from the game at runtime, so hotfixed names show.

Rules fixed 2026-11-01 (same 70707 cache), after a check against Forever's
own spellbook changes for 70707, which carry the 30 Oct hotfix. Rows with no
ClassMask now take their skill line's class, and only the trait trees decide
talents, which adds Innervate, Evocation, Omen of Clarity, Holy Light rank 5,
Bane of Agony rank 2, Aimed Shot 1-6, Seal of Command 2-5, Holy Shock 2-4,
Trueshot Aura 2-5, Arcane Wrath 2-4, Shadow Word: Death 1-4, Curse of the
Elements 1-4 (440892, 1311676, 1311677, 1311680), hunter Lacerate 1-4, Sniper
Shot rank 2, and the former talents Nature's Grasp 1, Blessing of Kings,
Consecration 1, Divine Spirit 1, Lightwell 1 and Conflagrate 3. Lightning
Shield's classless damage helpers still collapse into the trainer ranks. By
ID: Tiger's Fury (5217, AcquireMethod 3, marked `trainedById` in the
manifest) at 24; levels (manifest source `forever-level-by-id`, each with
its evidence) for Primal Bite ranks 2-3 (50, 60, the 30 Oct hotfix) and
Aspect of the Beast ranks 2-4 (40, 50, 60: new ranks with BaseLevel 0 and no
Classic reference). A class skill line must name exactly one class, or the
generator stops. Out are Chilled, Master
of Elements and Impact (talent effects), Aquatic Form (Passive), Hammer of the
Righteous and Portal of Summoning (seasonal rune spells), and Holy Shield
ranks 2-3 until a trainer visit settles their levels. A SupercedesSpell with
no SpellName row is dropped (Claw rank 1 named 1263850). Feral Charge (Bear)
16979 and Sniper Shot rank 3 1310786 stay out pending in-game checks. Total
1380 -> 1422. Left as they are: starting spells every character knows, hunter
pet abilities (not class trainer rows), Dual Wield and the held conflicts.

Later the same day: the trained ranks of a spell whose rank 1 is a tree
talent had prev 0 (the client's SupercedesSpell), so the guide offered them
without the talent. The generator now gives each such rank the rank before
it by the client's rank number (rank 2 the talent, rank 3 rank 2...): 92
rows over 27 spells, listed as `talentChains` in the manifest. Binding Heal
(rank 1 trained, nowTaught) and Primal Bite rank 4 keep prev 0. Other spells
keep the client's prev: most classes' ranks still have prev 0 there, and the
generator stops if one of them follows a talent rank.

That evening, the rest: the client names the rank before (SupercedesSpell)
only on the warrior's and rogue's lines, most of the druid's Feral Combat and
a few paladin rows, so for the other classes rank 3 showed as ready before
rank 2 was bought. `chainTrainedRanks` gives every other trained rank above 1
the rank of the same class, skill line and name one lower: a row (the quest
rank 1s of Redemption and three totems are rows), or else the rank 1 every
character of the class starts with (an AcquireMethod 2 row: Fireball, Smite
and 9 more). 743 rows, listed as `rankChains`; every one matches the rank
numbers in Forever's 70707 spellbook changes. Held at 0 by ID (`heldPrev`,
with reasons): Primal Bite 4, Binding Heal 2-6, Seal of Righteousness 2 (which
rank 1 characters have waits for a game check) and Greater Blessing of Might
and Wisdom 2 (Forever's trainers ask for the plain blessing's top rank). A
rank with no rank before it, or two different ones (a row and another starting
spell, as Seal of Righteousness 2 would have), stops the generator. A starting
spell only some races get is not used. The guide's tooltip names the rank
before only while it is not known.

The guide reads a chain this way: a rank is ready at its level when the rank
before it is known or ready itself, as one trainer visit can buy both. A talent
or a quest's spell you don't know stops the chain, and so does a rank above
your level, so everything above those waits. So does a rank 1 no trainer sells
that the quest list doesn't have yet (`NOT_SOLD` in Modules/TrainingGuide.lua: a
priest's racial spells and two book ranks), until a trainer has quoted it. It
isn't on the quest list because the guide's and Prep's imports read that file.
The trainer's own list and purchases never read this.

Build 70753 (2026-11-03), from the saved tables in
`_ForeverData/changes-2026-11-03/impact/wago-70753` and the same saved Classic
pages, kept in `_ForeverData/classic-reference-pages` (Wowhead answers 403 now,
and those pages don't move with Forever's builds; copy them into each new
build's cache folder). 1422 -> 1423 rows. In: Holy Shield 2-4 (20927, 20928, 1239570 at 40,
50, 60, from talent 20925), Ferocious Bite's new rank 1 (1328618 at 24) and
Lacerate's new rank 2 (1328616 at 34, from talent 1328617). Their old ranks
move up by the client's rank text and SupercedesSpell, so those chains are the
client's own, as is Primal Bite's now. Out: Primal Bite 4 (1238073, gone from
the client) and Lava Burst 2-4 (1238299, 1238300, 1326047): Blizzard's launch
notes remove the spell, the client still lists it, so they are `notTaught` by ID
until live data says otherwise. The blessings and Salvation lost their level
rows in 70753 but stay on `notTaught` for a client still on 70707.

The list can be a build ahead of the client: on 70707 the client has neither
1328616, 1328617, 1328618 nor 1239570. The guide asks `C_Spell.DoesSpellExist`:
a row the client hasn't got stays out, and a rank naming one as the rank before
doesn't wait for it, so a 70707 druid still sees Lacerate at 42 and Ferocious
Bite at 32 under the client's own rank text. Only a plain false counts: no API,
an error or a secret answer leaves the list as it is.

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
