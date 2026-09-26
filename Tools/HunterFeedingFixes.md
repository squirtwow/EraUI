# Forever pet feeding API repair

Matching client source: `Gethe/wow-ui-source` commit
`bd2470aed543f72697a044e989285b6c83e63f73`,
`Blizzard_APIDocumentationGenerated/PetInfoDocumentation.lua`.

- Prefer `C_PetInfo.GetPetHappiness`; the legacy global is a fallback only.
- `C_PetInfo.GetPetFoodTypes` returns a table, unlike the legacy varargs API.
- Prefer `C_PetInfo.CanPetEatItem` for native item compatibility; retain the
  existing food allowlist, food preferences and minimum item-level checks.
- Unknown/restricted happiness is not converted into a hungry state.
- The existing secure click/visibility lifecycle still requires the option,
  learned Feed Pet, a living pet, low happiness and closed settings, outside combat.
- Settings explain happy, missing or dead pets and the settings-open suppression.

`Tools/TestHunterFeed.lua` exercises the modern-only API, precedence over legacy
globals, both diet return shapes, incompatible food, missing happiness and the
movement/combat lifecycle. In-game feeding and visibility still need confirmation.
