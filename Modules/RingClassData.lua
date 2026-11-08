local _, E = ...

-- Each class's ready-made ring (Action Rings, Modules/RingFill.lua): the
-- spells in the ring's order, as rank 1 spell IDs from Forever's own spell
-- data (the Wowhead Forever spellbook, build 70707). Each one is cast at the
-- highest rank you know, and is left out while you know none of it.
-- {pick = {...}} is one slice: the first of those you know (a mage's best
-- mana gem, a druid's bear form, a paladin's best mount). Forever has no
-- runes, so no rune spell is here, and it took the warlock's Felsteed and
-- Dreadsteed out, so neither is in the warlock's ring. A rogue's ring is its
-- poisons instead (poisons = true): the best of each kind it carries, for
-- each hand (Modules/PoisonData.lua).
E.RingClassData = {
    -- Food, water, the best mana gem, then teleports and portals (a mage
    -- knows only its own faction's), then the intellect buffs.
    MAGE = {587, 5504, {pick = {10054, 10053, 3552, 759}},
        3561, 3562, 3565, 3567, 3563, 3566, 1297659,
        10059, 11416, 11419, 11417, 11418, 11420,
        1459, 23028},
    -- The stones, summoning, the demons and the rest of the warlock's
    -- out-of-combat spells.
    WARLOCK = {6201, 693, 2362, 6366, 698, 688, 697, 712, 713, 691, 126, 5697, 132, 1122},
    PRIEST = {1243, 21562, 14752, 27681, 976, 27683, 588, 6346, 1706, 2096, 9484, 453, 2006},
    -- Forms (Moonkin from its talent), Moonglade, then the druid's buffs and
    -- raising the dead.
    DRUID = {{pick = {9634, 5487}}, 768, 1066, 783, 24858, 18960, 1126, 21849, 467, 20484, 437138},
    -- Travel, utility, raising the dead, then the weapon imbues and shields.
    SHAMAN = {2645, 556, 546, 131, 6196, 2008, 8017, 8024, 8033, 8232, 324, 408510},
    -- Auras (Sanctity from its talent), blessings, the best mount, Redemption.
    PALADIN = {465, 7294, 19746, 19876, 19888, 19891, 20218, 19740, 19742, 20217, 1044, 1022, 6940,
        {pick = {23214, 1279399, 13819}}, 7328},
    -- Aspects, then the pet.
    HUNTER = {13163, 13165, 5118, 13159, 13161, 20043, 883, 2641, 982, 136, 6991, 1515, 1002, 1462},
    -- Stances, shouts and rages.
    WARRIOR = {2457, 71, 2458, 6673, 1160, 1161, 5246, 2687, 18499},
    ROGUE = {poisons = true},
}
-- The poison kinds in a rogue's ring, in order (keys of Modules/PoisonData.lua).
E.RingClassData.POISON_ORDER = {"instant", "deadly", "crippling", "numbing", "wound"}
