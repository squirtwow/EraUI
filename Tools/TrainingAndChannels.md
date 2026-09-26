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

`C_SpellBook.GetSpellBookItemInfo` provides names, ranks, spell IDs and future
entries. `C_Spell.GetSpellLevelLearned` supplies the future entries' levels.
`Tools/GenerateTrainingData.mjs` independently bundles exact-build SkillLine,
SkillLineAbility, SkillRaceClassInfo, SpellLevels, SpellName, Spell, SpellMisc,
SpellEffect and Talent exports. SHA-256 hashes and URLs are recorded in
`Tools/TrainingDataSources.json`. Class spellbook lines exclude pet skill lines,
direct talent purchases, hidden/descriptionless implementation spells and
teaching wrappers. Skill-granted passives use their class-specific skill level.
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
- `Tools/TestPersistence.lua`: training quotes and prerequisite maps survive
  missing SavedVariables, with character/realm separation.
- `Tools/TestChannelTiming.lua`: both actual cast-bar modules with shortened
  endpoints and a deliberately stale Duration API, plus stop/new-channel cases.

Real client checks still cover the taming rod under damage, trainer categories
and prices, spellbook-button visibility, and the panel's appearance.
