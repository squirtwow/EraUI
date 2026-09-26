# Map reveal development data

`Modules/MapRevealData.lua` is generated from Blizzard's DB2 records for Forever
**1.60.1.70009**, exported by Wago Tools. The generator does not read any addon.
Only numeric metadata is included. The game supplies all referenced artwork.

Sources, with this build explicitly selected:

- `https://wago.tools/db2/WorldMapOverlay/csv?build=1.60.1.70009`
- `https://wago.tools/db2/WorldMapOverlayTile/csv?build=1.60.1.70009`
- `https://wago.tools/db2/UiMapXMapArt/csv?build=1.60.1.70009`
- `https://wago.tools/db2/UiMapArt/csv?build=1.60.1.70009`
- `https://wago.tools/db2/UiMapArtStyleLayer/csv?build=1.60.1.70009`

`MapRevealData.json` records source checksums, counts and excluded records. Only
art IDs linked to maps in this build are retained. Empty regions and regions
without texture records are omitted; their texture IDs are never guessed.
Incomplete grids, duplicate bounds and malformed exports fail generation.

From the addon directory, using Node 18 or newer:

```powershell
node Tools/GenerateMapReveal.mjs "$env:LOCALAPPDATA\Temp\eraui-map-data"
```

The data's layer keys use the Lua API's one-based indices; DB2 tile row/column
values stay zero-based. Runtime rendering validates the displayed map, current
art ID, layer dimensions and tile size before showing any texture.

Client lifecycle research used the matching Blizzard UI source, build 70009:
`https://github.com/Gethe/wow-ui-source/tree/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_SharedMapDataProviders`

The renderer owns its textures on the native exploration pin. It responds to
native refresh/clear operations and map visibility instead of polling. Local
tests cover lifecycle and coordinates; final appearance still requires in-game
testing, including Durotar, Teldrassil, continent navigation and toggle-off.

Run the lifecycle checks from the addon directory with a Lua interpreter:

```text
lua Tools/TestMapReveal.lua
```

These checks simulate the client frame API. They cover stateful pin enumeration,
map/art mismatches, native clearing, replacement pins, delayed map loading,
explored-area matching, padded edge tiles, API failures and immediate disable.
They cannot establish whether the client displays the artwork correctly.
