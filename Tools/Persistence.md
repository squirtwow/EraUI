# Settings recovery

`Core/Persistence.lua` supplements the existing Classic scalar CVar mirror on
Forever. Account recovery loads after legacy migration and before visual settings
are captured. Character recovery loads before QoL module initialization.

## Scope

- Account: declared EraUI defaults, reminder controls and per-class reminder
  choices/positions, map/minimap position, map dimensions, movable bars, combo
  points and reward profiles. Existing account/class ownership is preserved.
- Character: `EraUIClassicCharDB.classTools`, onboarding and swing toggles,
  indexed by character name plus realm.
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

Encoding supports finite numbers, booleans, strings and bounded nested tables.
It does not use `loadstring` or execute saved text. Unreadable recovery keeps
SavedVariables and reports the failure without overwriting the backup. Reset
invalidates the header and suppresses queued writes until reload.

## Verification

From the addon directory:

```text
lua Tools/TestPersistence.lua
```

The checks load real Init, Integration, Persistence and ClassTools code with a
simulated CVar service. They cover lost SavedVariables, legacy migration,
character/realm isolation, nested layouts, false values, deleted keys, delayed
identity, write coalescing, logout, corrupt/truncated/interrupted writes and reset.
Actual CVar retention across a full game restart still requires an in-game test.
