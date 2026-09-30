local _,E=...
-- AFK Screen class quotes, shown like a loading-screen tip: famous World of
-- Warcraft Classic lines (Classic 1.x content only, at most 14 words), each
-- checked word for word against the source in its comment. Keys are class
-- tokens; GENERAL tops up a pool of fewer than three lines. Every line shows
-- to both factions.
E.AFKQuotes={
 WARRIOR={
  {text="Warriors, I know you can hit harder than that! Let's see it!",speaker="Nefarian",where="Blackwing Lair"}, -- warcraft.wiki.gg/wiki/Nefarian_(tactics)
  {text="Ah - I've been waiting for a real challenge!",speaker="Herod",where="Scarlet Monastery"}, -- www.wowhead.com/classic/npc=3975/herod
  {text="You're a lot tougher than you look!",speaker="Bartleby",where="Quest: Beat Bartleby"}, -- warcraft.wiki.gg/wiki/Beat_Bartleby
  {text="Have a drink, and savor it... because it might be your last.",speaker="Yorus Barleybrew",where="Quest: Yorus Barleybrew"}, -- warcraft.wiki.gg/wiki/Yorus_Barleybrew_(quest)
  {text="We are the shield of the Horde, and we keep our weaker brethren safe.",speaker="Uzzek",where="Quest: Path of Defense"}, -- warcraft.wiki.gg/wiki/Path_of_Defense
  {text="But you are a warrior, and you will triumph or perish trying.",speaker="Fallen Hero",where="Quest: War on the Shadowsworn"}, -- warcraft.wiki.gg/wiki/War_on_the_Shadowsworn
  {text="I see fire in your eyes.",speaker="Bath'rah",where="Quest: The Windwatcher"}, -- warcraft.wiki.gg/wiki/The_Windwatcher
 },
 PALADIN={
  {text="The Light knows no bounds.",speaker="Tirion Fordring",where="Quest: Of Lost Honor"}, -- www.wowhead.com/classic/quest=5845/of-lost-honor
  {text="Take solace in knowing that the Order is reborn.",speaker="Tirion Fordring",where="Quest: In Dreams"}, -- www.wowhead.com/classic/quest=5944/in-dreams
  {text="Face me, coward. Face the faith and strength that you once embodied.",speaker="Tirion Fordring",where="Hearthglen, Quest: In Dreams"}, -- www.wowhead.com/classic/npc=12126/lord-tirion-fordring
  {text="Infidels! They must be purified!",speaker="Mograine",where="Scarlet Monastery"}, -- www.wowhead.com/classic/npc=3976/scarlet-commander-mograine
  {text="Kneel! Kneel before the Ashbringer!",speaker="Scarlet Monk",where="Scarlet Monastery"}, -- www.wowhead.com/classic/npc=4540/scarlet-monk
  {text="At long last, your time has come!",speaker="Grayson Shadowbreaker",where="Quest: The Divination Scryer"}, -- warcraft.wiki.gg/wiki/The_Divination_Scryer
  {text="Congratulations, and may the Light protect you.",speaker="Duthorian Rall",where="Quest: The Tome of Nobility"}, -- www.wowhead.com/classic/quest=1661/the-tome-of-nobility
 },
 HUNTER={
  {text="Release the hounds!",speaker="Houndmaster Loksey",where="Scarlet Monastery"}, -- warcraft.wiki.gg/wiki/Houndmaster_Loksey_(tactics)
  {text="May your arrows strike true.",speaker="Hastat the Ancient",where="Quest: Ancient Sinew Wrapped Lamina"}, -- warcraft.wiki.gg/wiki/Ancient_Sinew_Wrapped_Lamina_(quest)
  {text="Kill King Bangalash and your hunting prowess is proven to be second to none.",speaker="Hemet Nesingwary",where="Quest: Big Game Hunter"}, -- warcraft.wiki.gg/wiki/Big_Game_Hunter_(Classic)
  {text="What a wonderful day to be alive!",speaker="Simone",where="Un'Goro Crater"}, -- warcraft.wiki.gg/wiki/Simone_the_Seductress
  {text="May the blessings of the Earthmother guide you in choosing a pet.",speaker="Yaw Sharpmane",where="Quest: Taming the Beast"}, -- warcraft.wiki.gg/wiki/Taming_the_Beast_(Tauren_3)
  {text="Use your new skills with pride; you have earned them.",speaker="Dazalar",where="Quest: Taming the Beast"}, -- warcraft.wiki.gg/wiki/Taming_the_Beast_(night_elf_3)
  {text="Da path of da hunter is one of our oldest walks of life.",speaker="Jen'shan",where="Quest: Etched Tablet"}, -- warcraft.wiki.gg/wiki/Etched_Tablet_(quest)
 },
 ROGUE={
  {text="None may challenge the Brotherhood!",speaker="VanCleef",where="The Deadmines"}, -- www.wowhead.com/classic/npc=639/edwin-vancleef
  {text="You won't see us coming but you'll feel it when we get there...",speaker="Mathias Shaw",where="Quest: Snatch and Grab"}, -- www.wowhead.com/classic/quest=2206
  {text="Ravenholdt has taken an interest in you, young thief.",speaker="Fahrad",where="Quest: The Manor, Ravenholdt"}, -- www.wowhead.com/classic/quest=6681
  {text="Consider yourself the newest member of the Shattered Hand.",speaker="Therzok",where="Quest: The Shattered Hand"}, -- www.wowhead.com/classic/quest=1858
  {text="Being a field agent of the Shattered Hand is dangerous work.",speaker="Shenthul",where="Quest: Mission: Possible But Not Probable"}, -- www.wowhead.com/classic/quest=2478
  {text="Looks can be deceiving though, right?",speaker="Marion Call",where="Quest: Mennet Carkad"}, -- www.wowhead.com/classic/quest=1885
  {text="Keep your eyes peeled for thieves.",speaker="Defias Traitor",where="Westfall"}, -- www.wowhead.com/classic/npc=467/the-defias-traitor
 },
 PRIEST={
  {text="Arise, my champion!",speaker="Whitemane",where="Scarlet Monastery"}, -- warcraft.wiki.gg/wiki/High_Inquisitor_Whitemane_(Classic)
  {text="Mograine has fallen? You shall pay for this treachery!",speaker="Whitemane",where="Scarlet Monastery"}, -- warcraft.wiki.gg/wiki/High_Inquisitor_Whitemane_(Classic)
  {text="Battle with honor. Harness the Light.",speaker="Eris Havenfire",where="Quest: A Warning"}, -- warcraft.wiki.gg/wiki/A_Warning
  {text="Tendrils of light escape her hands, cutting through undead by the hundreds.",speaker="The Eye of Divinity",where="Molten Core, item text"}, -- warcraft.wiki.gg/wiki/The_Eye_of_Divinity
  {text="But before you can know the dark, you must also know the light.",speaker="Dark Cleric Beryl",where="Quest: Garments of Darkness"}, -- warcraft.wiki.gg/wiki/Garments_of_Darkness
  {text="You got the Light inside you, that's for sure.",speaker="Maxan Anvol",where="Quest: Garments of the Light"}, -- warcraft.wiki.gg/wiki/Garments_of_the_Light_(Dun_Morogh)
  {text="Bethekk, your priestess calls upon your might!",speaker="Arlokk",where="Zul'Gurub"}, -- warcraft.wiki.gg/wiki/High_Priestess_Arlokk
 },
 SHAMAN={
  {text="Patience is earth's greatest virtue.",speaker="Canaga Earthcaller",where="Quest: Call of Earth"}, -- warcraft.wiki.gg/wiki/Call_of_Earth_(Durotar)
  {text="It is the cycle of things. Mountains become deserts. Rivers become canyons.",speaker="Seer Ravenfeather",where="Quest: Call of Earth"}, -- warcraft.wiki.gg/wiki/Call_of_Earth_(Mulgore)
  {text="I see it in your eyes already, the burning, the desire.",speaker="Kranal Fiss",where="Quest: Call of Fire"}, -- warcraft.wiki.gg/wiki/Call_of_Fire_(Horde)
  {text="Water be in ya future, mon.",speaker="Searn Firewarder",where="Quest: Call of Water"}, -- warcraft.wiki.gg/wiki/Call_of_Water_(Orgrimmar)
  {text="Be bathed in my power! Drink in my might!",speaker="Thrall",where="Quest: For The Horde!"}, -- warcraft.wiki.gg/wiki/For_The_Horde!_(quest)
  {text="Today, you will meet your ancestors!",speaker="Drek'Thar",where="Alterac Valley"}, -- warcraft.wiki.gg/wiki/Drek%27Thar
  {text="BY FIRE BE PURGED!",speaker="Ragnaros",where="Molten Core"}, -- warcraft.wiki.gg/wiki/Ragnaros_(tactics)
 },
 MAGE={
  {text="Mages too? You should be more careful when you play with magic...",speaker="Nefarian",where="Blackwing Lair"}, -- warcraft.wiki.gg/wiki/Nefarian_(tactics)
  {text="This place is under my protection. The mysteries of the arcane shall remain inviolate.",speaker="Azuregos",where="Azshara"}, -- warcraft.wiki.gg/wiki/Azuregos_(tactics)
  {text="You, too, shall serve!",speaker="Arugal",where="Shadowfang Keep"}, -- warcraft.wiki.gg/wiki/Archmage_Arugal_(tactics)
  {text="You will not defile these mysteries!",speaker="Arcanist Doan",where="Scarlet Monastery"}, -- warcraft.wiki.gg/wiki/Arcanist_Doan
  {text="Magic is powerful. Magic is corrupting. Magic is addicting.",speaker="Khelden Bremen",where="Glyphic Letter"}, -- warcraft.wiki.gg/wiki/Glyphic_Letter
  {text="We are the ones who control our fate.",speaker="Isabella",where="Glyphic Scroll"}, -- warcraft.wiki.gg/wiki/Glyphic_Scroll
  {text="I had forgotten about that little curse I put on Johnson.",speaker="Magus Tirth",where="Quest: Get the Scoop"}, -- warcraft.wiki.gg/wiki/Get_the_Scoop
 },
 WARLOCK={
  {text="For the Legion! For Kil'jaeden!",speaker="Lord Kazzak",where="Blasted Lands"}, -- warcraft.wiki.gg/wiki/Lord_Kazzak_(tactics)
  {text="Silence, servant! Vengeance will be mine! Death to Stormwind! Death by chicken!",speaker="Niby the Almighty",where="Felwood"}, -- warcraft.wiki.gg/wiki/Niby_the_Almighty
  {text="Don't tell anyone this but Niby is daft.",speaker="Impsy",where="Quest: Flawless Fel Essence"}, -- warcraft.wiki.gg/wiki/Flawless_Fel_Essence
  {text="When power is concerned, you are drawn in like a moth to the flame.",speaker="Strahad Farsan",where="Quest: Summon Felsteed"}, -- warcraft.wiki.gg/wiki/Summon_Felsteed_(Orgrimmar)
  {text="I summon demons from the Twisting Nether at my leisure.",speaker="Nartok",where="Tainted Parchment"}, -- warcraft.wiki.gg/wiki/Tainted_Parchment
  {text="So few warlocks remain... We risk much, but the risks are warranted.",speaker="Gan'rul Bloodeye",where="Quest: Creature of the Void"}, -- warcraft.wiki.gg/wiki/Creature_of_the_Void_(Orgrimmar)
  {text="Face the true might of the Nathrezim!",speaker="Balnazzar",where="Stratholme"}, -- warcraft.wiki.gg/wiki/Balnazzar_(Classic)
 },
 DRUID={
  {text="I AM AWAKE, AT LAST!",speaker="Naralex",where="Wailing Caverns"}, -- warcraft.wiki.gg/wiki/Naralex
  {text="You will never wake the dreamer!",speaker="Lord Cobrahn",where="Wailing Caverns"}, -- warcraft.wiki.gg/wiki/Lord_Cobrahn
  {text="Within the Dream we fight a new foe, born of an ancient evil.",speaker="Malfurion Stormrage",where="Quest: Waking Legends"}, -- warcraft.wiki.gg/wiki/Waking_Legends
  {text="Fiend! Face the might of Cenarius!",speaker="Keeper Remulos",where="Quest: The Nightmare Manifests"}, -- warcraft.wiki.gg/wiki/The_Nightmare_Manifests
  {text="The strands of LIFE have been severed! The Dreamers must be avenged!",speaker="Ysondre",where="Dragons of Nightmare"}, -- warcraft.wiki.gg/wiki/Ysondre_(Classic)
  {text="Inside each of Cenarius' children is the call to serve nature.",speaker="Druid trainer",where="Quest: Heeding the Call"}, -- warcraft.wiki.gg/wiki/Heeding_the_Call_(Alliance)
  {text="To keep the balance is not to be complacent or banal.",speaker="Great Bear Spirit",where="Moonglade"}, -- warcraft.wiki.gg/wiki/Great_Bear_Spirit_(quest)
 },
 GENERAL={
  {text="The drums of war thunder once again.",speaker="Narrator",where="The intro cinematic"}, -- warcraft.wiki.gg/wiki/Seasons_of_War
  {text="TOO SOON! YOU HAVE AWAKENED ME TOO SOON, EXECUTUS!",speaker="Ragnaros",where="Molten Core"}, -- warcraft.wiki.gg/wiki/Ragnaros_(tactics)
  {text="How fortuitous. Usually, I must leave my lair in order to feed.",speaker="Onyxia",where="Onyxia's Lair"}, -- www.wowhead.com/classic/npc=10184/onyxia
  {text="In this world where time is your enemy, it is my greatest ally.",speaker="Victor Nefarius",where="Blackwing Lair"}, -- warcraft.wiki.gg/wiki/Nefarian_(tactics)
  {text="Your friends will abandon you.",speaker="C'Thun",where="Ahn'Qiraj"}, -- warcraft.wiki.gg/wiki/C'Thun_(tactics)
  {text="A huge gnoll, Hogger, is prowling the woods in southwestern Elwynn.",speaker="Wanted Poster",where="Quest: Wanted: \"Hogger\""}, -- warcraft.wiki.gg/wiki/Wanted:_%22Hogger%22
  {text="Have you found any sign of her at all?",speaker="Mankrik",where="Quest: Lost in Battle"}, -- warcraft.wiki.gg/wiki/Lost_in_Battle
  {text="You no take candle!",speaker="Kobolds",where="Elwynn Forest"}, -- www.wowhead.com/classic/npc=6/kobold-vermin
 },
}
