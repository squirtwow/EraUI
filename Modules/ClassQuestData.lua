-- Class spells a quest teaches rather than a trainer, for the Training Guide.
-- Each spell lists its quest by race token (UnitRace), by "Race:Faction" where
-- the two Skyborne have their own, or by faction when every race shares it.
-- name: the quest that teaches the spell. first: the quest its chain starts
-- with, when that's another one. npc, spot, where: who starts the chain, and
-- where. accept: learned as you accept the quest.
-- Sources: Wowhead Classic and Wowhead Forever, checked 2026-09-28.
local _,E=...
local Q={}
E.ClassQuests=Q

-- Warrior ----------------------------------------------------------------------

-- Defensive Stance comes with Taunt and Sunder Armor.
local defense={
 Human={name="Bartleby's Mug",first="A Warrior's Training",npc="Lyria Du Lac",spot="Goldshire",where="Elwynn Forest"},
 Dwarf={name="Vejrek",first="Muren Stormpike",npc="Granis Swiftaxe",spot="Kharanos",where="Dun Morogh"},
 Gnome={name="Vejrek",first="Muren Stormpike",npc="Granis Swiftaxe",spot="Kharanos",where="Dun Morogh"},
 NightElf={name="Vorlus Vilehoof",first="Elanaria",npc="Kyra Windblade",spot="Dolanaar",where="Teldrassil"},
 Orc={name="Path of Defense",first="Veteran Uzzek",npc="Tarshaw Jaggedscar",spot="Razor Hill",where="Durotar"},
 Troll={name="Path of Defense",first="Veteran Uzzek",npc="Tarshaw Jaggedscar",spot="Razor Hill",where="Durotar"},
 Tauren={name="Path of Defense",first="Veteran Uzzek",npc="Krang Stonehoof",spot="Bloodhoof Village",where="Mulgore"},
 Scourge={name="Ulag the Cleaver",first="Speak with Dillinger",npc="Austil de Mon",spot="Brill",where="Tirisfal Glades"},
 Skyborne={name="The Skybreaker Bulwark",npc="Seena Skybreaker",spot="Valanaar",where="Zephras Isle"},
}
Q[71]=defense -- Defensive Stance
Q[355]=defense -- Taunt
Q[7386]=defense -- Sunder Armor
-- Berserker Stance comes with Intercept, from Fray Island in the Barrens.
local berserker={
 Alliance={name="The Affray",first="The Islander",npc="Wu Shen",where="Stormwind City"},
 Dwarf={name="The Affray",first="The Islander",npc="Kelv Sternhammer",where="Ironforge"},
 Gnome={name="The Affray",first="The Islander",npc="Kelv Sternhammer",where="Ironforge"},
 Horde={name="The Affray",first="The Islander",npc="Sorek",where="Orgrimmar"},
 Tauren={name="The Affray",first="The Islander",npc="Torm Ragetotem",where="Thunder Bluff"},
 Scourge={name="The Affray",first="The Islander",npc="Baltus Fowler",where="Undercity"},
}
Q[2458]=berserker -- Berserker Stance
Q[20252]=berserker -- Intercept

-- Paladin ----------------------------------------------------------------------

Q[7328]={ -- Redemption
 Human={name="The Tome of Divinity",npc="Duthorian Rall",spot="Cathedral of Light",where="Stormwind City"},
 Dwarf={name="The Tome of Divinity",npc="Tiza Battleforge",where="Ironforge"},
}

-- Hunter -----------------------------------------------------------------------

-- Tame Beast comes with Call Pet and Dismiss Pet.
local taming={
 Human={name="Taming the Beast",npc="Josephine Carson",spot="Goldshire",where="Elwynn Forest"},
 Dwarf={name="Taming the Beast",npc="Grif Wildheart",spot="Kharanos",where="Dun Morogh"},
 NightElf={name="Taming the Beast",npc="Dazalar",spot="Dolanaar",where="Teldrassil"},
 Orc={name="Taming the Beast",npc="Thotar",spot="Razor Hill",where="Durotar"},
 Troll={name="Taming the Beast",npc="Thotar",spot="Razor Hill",where="Durotar"},
 Tauren={name="Taming the Beast",npc="Yaw Sharpmane",spot="Bloodhoof Village",where="Mulgore"},
 Skyborne={name="Taming the Beast",npc="Quel'ana Quickgale",spot="Valanaar",where="Zephras Isle"},
}
Q[1515]=taming -- Tame Beast
Q[883]=taming -- Call Pet
Q[2641]=taming -- Dismiss Pet
-- Feed Pet and Revive Pet come next, from the same hunter.
local training={
 Human={name="Training the Beast",npc="Josephine Carson",spot="Goldshire",where="Elwynn Forest"},
 Dwarf={name="Training the Beast",npc="Grif Wildheart",spot="Kharanos",where="Dun Morogh"},
 NightElf={name="Training the Beast",npc="Dazalar",spot="Dolanaar",where="Teldrassil"},
 Orc={name="Training the Beast",npc="Thotar",spot="Razor Hill",where="Durotar"},
 Troll={name="Training the Beast",npc="Thotar",spot="Razor Hill",where="Durotar"},
 Tauren={name="Training the Beast",npc="Yaw Sharpmane",spot="Bloodhoof Village",where="Mulgore"},
 Skyborne={name="Training the Beast",npc="Quel'ana Quickgale",spot="Valanaar",where="Zephras Isle"},
}
Q[6991]=training -- Feed Pet
Q[982]=training -- Revive Pet

-- Shaman -----------------------------------------------------------------------

Q[8071]={ -- Stoneskin Totem
 Orc={name="Call of Earth",npc="Canaga Earthcaller",spot="Valley of Trials",where="Durotar"},
 Troll={name="Call of Earth",npc="Canaga Earthcaller",spot="Valley of Trials",where="Durotar"},
 Tauren={name="Call of Earth",npc="Seer Ravenfeather",spot="Camp Narache",where="Mulgore"},
 Dwarf={name="Call of Earth",npc="Teo Hammerstorm",spot="Anvilmar",where="Dun Morogh"},
 Skyborne={name="Call of Earth",npc="Windshaper Boro",spot="Thendal Grove",where="Zephras Isle"},
}
local fire={name="Call of Fire",npc="Kranal Fiss",where="The Barrens"}
Q[3599]={ -- Searing Totem
 Orc=fire,Troll=fire,Tauren=fire,
 Dwarf={name="Call of Fire"},
 Skyborne={name="Call of Fire",npc="Sessaria Skystride",spot="Valanaar",where="Zephras Isle"},
}
local water={name="Call of Water",npc="Islen Waterseer",where="The Barrens"}
Q[5394]={ -- Healing Stream Totem
 Orc=water,Troll=water,Tauren=water,
 Dwarf={name="Call of Water"},
}

-- Warlock ----------------------------------------------------------------------

Q[697]={ -- Summon Voidwalker
 Human={name="The Binding",first="Gakin's Summons",npc="Remen Marcot",spot="Goldshire",where="Elwynn Forest"},
 Gnome={name="The Binding",first="The Slaughtered Lamb",npc="Lago Blackwrench",where="Ironforge"},
 Orc={name="The Binding",first="Gan'rul's Summons",npc="Ophek",spot="Razor Hill",where="Durotar"},
 Scourge={name="The Binding",first="Halgar's Summons",npc="Ageron Kargal",spot="Brill",where="Tirisfal Glades"},
}
local gakin={name="The Binding",first="Devourer of Souls",npc="Gakin the Darkbinder",spot="The Slaughtered Lamb",where="Stormwind City"}
Q[712]={ -- Summon Succubus
 Human=gakin,Gnome=gakin,
 Orc={name="The Binding",first="Devourer of Souls",npc="Gan'rul Bloodeye",spot="Cleft of Shadow",where="Orgrimmar"},
 Scourge={name="The Binding",first="Devourer of Souls",npc="Carendin Halgar",spot="Magic Quarter",where="Undercity"},
}
local love={name="The Binding",first="What Is Love?",npc="Takar the Seer",where="The Barrens"}
Q[713]={ -- Summon Incubus
 Human=love,Gnome=love,
 Orc={name="The Binding",first="Love Hurts"},
 Scourge={name="The Binding",first="Hearts of the Lovers",npc="Godrick Farsan",where="Undercity"},
}
local strahad={name="The Binding",first="Seeking Strahad",npc="Gakin the Darkbinder",spot="The Slaughtered Lamb",where="Stormwind City"}
Q[691]={ -- Summon Felhunter
 Human=strahad,Gnome=strahad,
 Orc={name="The Binding",first="Seeking Strahad",npc="Gan'rul Bloodeye",spot="Cleft of Shadow",where="Orgrimmar"},
 Scourge={name="The Binding",first="Seeking Strahad",npc="Carendin Halgar",spot="Magic Quarter",where="Undercity"},
}
-- The same for every warlock.
local inferno={name="Kroshius' Infernal Core",npc="Niby the Almighty",where="Felwood"}
Q[1122]={Alliance=inferno,Horde=inferno} -- Inferno
local doom={name="Suppression",npc="Daio the Decrepit",spot="Tainted Scar",where="Blasted Lands"}
Q[18540]={Alliance=doom,Horde=doom} -- Ritual of Doom

-- Druid ------------------------------------------------------------------------

-- Bear Form comes with Growl and Maul.
local bear={
 NightElf={name="Body and Heart",first="Moonglade",npc="Mathrengyl Bearwalker",spot="Cenarion Enclave",where="Darnassus"},
 Tauren={name="Body and Heart",first="Moonglade",npc="Turak Runetotem",spot="Elder Rise",where="Thunder Bluff"},
 Skyborne={name="Strength and Mercy",first="The Great Ursera Spirit",npc="Lotheluum Starbreeze",spot="Valanaar",where="Zephras Isle"},
}
Q[5487]=bear -- Bear Form
Q[6795]=bear -- Growl
Q[6807]=bear -- Maul
Q[18960]={ -- Teleport: Moonglade
 NightElf={name="Moonglade",npc="Mathrengyl Bearwalker",spot="Cenarion Enclave",where="Darnassus",accept=true},
 Tauren={name="Moonglade",npc="Turak Runetotem",spot="Elder Rise",where="Thunder Bluff",accept=true},
 ["Skyborne:Alliance"]={name="Moonglade",first="Child of Nature",npc="Archmage Ansirem Runeweaver",spot="Dalaran",where="Alterac Mountains",accept=true},
 ["Skyborne:Horde"]={name="Moonglade",first="Child of Nature",npc="Muln Earthfury",where="Mulgore",accept=true},
}
Q[8946]={ -- Cure Poison
 NightElf={name="Power over Poison",first="Lessons Anew",npc="Mathrengyl Bearwalker",spot="Cenarion Enclave",where="Darnassus"},
 Tauren={name="Power over Poison",first="Lessons Anew",npc="Turak Runetotem",spot="Elder Rise",where="Thunder Bluff"},
}
Q[1066]={ -- Aquatic Form
 NightElf={name="Aquatic Form",first="A Lesson to Learn",npc="Mathrengyl Bearwalker",spot="Cenarion Enclave",where="Darnassus"},
 Tauren={name="Aquatic Form",first="A Lesson to Learn",npc="Turak Runetotem",spot="Elder Rise",where="Thunder Bluff"},
}
