# Settings recovery

`Core/Persistence.lua` supplements the existing Classic scalar CVar mirror on
Forever. Account recovery loads after legacy migration and before visual settings
are captured. Character recovery loads before QoL module initialization.

## Scope

- Account: declared EraUI defaults, reminder controls and per-class reminder
  choices/positions, map/minimap position, map dimensions, movable bars, combo
  points and reward profiles. Existing account/class ownership is preserved.
- Character: `EraUIClassicCharDB.classTools` (without the Training Guide's
  trainer quotes, `classTools.trainingGuide`: a cache the next trainer visit
  fills again, and the quotes SavedVariables hold are kept when a record is
  read back), onboarding, swing toggles and the minimap zooms Remember Minimap
  Zoom keeps (`minimapZoom`, only its two finite numbers), indexed by
  character name plus realm. Each record carries `seen`, the load counter
  (`loads`) at the character's last login.
- Mini-games: the account's window place and best scores (`miniGamePosition`,
  `miniGameBest`), and each character's best scores (`miniGames.best`, whole
  numbers of 0 or more only; Azeroth Blast's kept board is left out). Read
  back, a character's best is the higher of the backup's and SavedVariables'.
- Mini-game progress (`miniGameProgress`, Modules/MiniGameProgress.lua): the
  account's levels, stars, coins, power-ups and unlocks, a small versioned
  record with a `stamp` that rises on every change. Read back, the record with
  the higher stamp wins (SavedVariables' on a tie), so a level played after the
  last backup is never lost; a record with no stamp never beats the backup.
  Reset progress makes a record whose stamp is past the old one's, so an older
  backup can't bring the old progress back. The level or stage in progress
  (`miniGameResume`, a few KB) and Whack's tune values (`miniGameTune`) are
  not backed up.
- The game keeps addon CVars only until it closes (they never reach
  Config.wtf), so all of this covers SavedVariables lost within one client
  session. Across a full restart only SavedVariables come back: the swing
  toggles therefore also live in `EraUIClassicCharDB.swing`.
- Existing Classic skin settings continue using `EraUIClassicSettings`.
- Legacy name-only swing/onboarding entries migrate to the first matching
  character that logs in. The old format contains no realm, so it cannot identify
  which realm originally owned an ambiguous name. Migration consumes that entry
  rather than copying it to further same-name characters.

The new recovery snapshot takes precedence over stale SavedVariables, including
omitted optional keys. This keeps deleted/reset positions from returning.
Existing settings which were already lost before installation cannot be recovered.

## Storage and writes

`EraUIRecovery1Head` selects a complete version-1 snapshot, split into 900-byte
CVars named `EraUIRecovery1A1`, `EraUIRecovery1A2`, etc., or the corresponding B
bank. The inactive bank is written and read back before publishing a new header.
The header contains the bank, chunk count and checksum. Maximum payload is 128
chunks. Unchanged snapshots produce no writes; interactive edits coalesce over
0.2 seconds. Logout flushes synchronously, including nested table edits.

A snapshot over the limit drops other characters' records, the one seen
longest ago first, until it fits; the current character and the account are
never dropped. If it still does not fit, or cannot be encoded, the header is
cleared (`EraUIRecovery1Head` = ""), so the next load keeps SavedVariables
instead of reading an older snapshot back over them.

Encoding supports finite numbers, booleans, strings and bounded nested tables.
It does not use `loadstring` or execute saved text. Unreadable recovery keeps
SavedVariables and reports the failure without overwriting the backup.

## Reset lifecycle

`/era reset` only opens a prompt (outside combat; in combat it just says to
finish first). The prompt's Reset button verifies a durable
`EraUIRecovery1Reset=1` request, then calls `ReloadUI()` from that click only
after the request succeeds; Cancel, its X and Escape change nothing. Combat or
a failed request does not trigger a reload.
The current session keeps its live tables and
aliases until reload. Account recovery, Classic, swing and onboarding mirrors
stop saving while this request is pending, including queued/logout saves.

On the next load, before Init applies defaults or the Classic loader binds its
database, recovery and legacy mirrors are cleared and verified, and fresh
account/Classic/current-character tables are created. Old SavedVariables cannot
override the request. The marker clears only after a fresh recovery snapshot is
successfully written and verified. A failed clear or interrupted initialization
retains the request for retry on the next load.

## Verification

From the addon directory:

```text
lua Tools/TestPersistence.lua
lua Tools/TestResetLifecycle.lua
```

The checks load real Init, Integration, Persistence and ClassTools code with a
simulated CVar service. They cover lost SavedVariables, legacy migration,
character/realm isolation, nested layouts, false values, deleted keys, delayed
identity, write coalescing, logout, corrupt/truncated/interrupted writes and reset.
The lifecycle suite additionally loads the real slash command and Classic loader,
exercises live callbacks and aliases before reload, rejects combat resets, checks
every mirror through logout, reloads stale SavedVariables, and injects failures
into clearing, snapshot publication and final marker completion.
Actual CVar retention across a full game restart still requires an in-game test.
