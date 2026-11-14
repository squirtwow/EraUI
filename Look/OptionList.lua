-- The Classic option list (ns.TOGGLES): every Classic look switch in its
-- order, as { key, label, description, parent }. A child is indented under
-- its parent and greyed while the parent is off. Read by the old options
-- page (Look/OptionPage.lua), the /eraui-classic help and toggles commands,
-- Core/Integration.lua (which adds its Quality of Life rows at the end and
-- reads labels for its chat line), the status report and tests.
--
-- Most keys are copied from /era on every pass (Core/Integration.lua), so a
-- tick here only lasts for the keys that are the Classic side's own.
local _, EraUI = ...
local ns = EraUI.Classic

local list = {}
ns.TOGGLES = list

local function Row(key, label, description, parent)
    list[#list + 1] = { key, label, description, parent }
end

Row("classicBar", "Classic main menu bar",
    "The 1.x stone band with its gryphons along the bottom, holding the action buttons, page arrows, micro buttons, bags and XP bar where they used to be.")
Row("defaultBarSize", "Default interface bar size",
    "Draws the band at the game's own button size (45 instead of 1.x's 36), about a fifth larger. In the EraUI layout bars 1 and 2 go to ten icons and the side bars to eight, and back to twelve when this is off; Edit Mode can change them. Off is the true old size.",
    "classicBar")
Row("oneBar", "One bar",
    "The band stops after the twelve main slots, with the right gryphon beside them and the XP bar just as wide. The bottom right bar, micro menu and bags stay where Edit Mode puts them.",
    "classicBar")
Row("bagsBesideBars", "Opened bags beside the right action bars",
    "Opened bags start to the left of the bars down the right edge instead of covering them. A bar moved off that edge doesn't count. Off: bags open in the corner over the bars.")
Row("bagsAboveRow", "Opened bags above the bag buttons",
    "Opened bags stand above the bag buttons and move with them. Off (the default): they open where the game puts them, bottom right. Edit Mode's bags dialog has the same tick.",
    "classicBar")
Row("questMapPane", "Classic map quest pane",
    "The map's quest list in the quest log's style: a dark list with plus and minus headers, 1.x difficulty colours, the old check, and the details on parchment.")
Row("gameMenu", "Classic game menu",
    "The Escape menu as the old dialog box, with its header plate and small red buttons.")
Row("settingsPanel", "Classic settings window",
    "The game's settings window as the old options dialog: the box, the header plate, bordered insets, a highlight bar and every control in the old art.")
Row("buttons", "Classic button style",
    "Square slot borders, the red attack flash and the old pressed and highlight art on the action buttons.")
Row("squareIcons", "Square icons",
    "Action icons square, without the round mask, as in 1.x. Needs the classic button style.", "buttons")
Row("castAnim", "No cast animation on buttons",
    "Nothing plays over a button while its spell casts, and the cooldown swipe stays solid.")
Row("hideExtraBars", "Hide bars 6 to 8",
    "1.x had five bars, so bars 6 to 8 are faded and take no clicks; their keybinds still work. Turn this off to place them in Edit Mode.")
Row("emptySlots", "Hide empty side bar slots",
    "Empty slots on the extra bars stay hidden until a spell is dragged onto them, whatever Always Show Buttons says.")
Row("unitFrames", "Classic unit frames",
    "Player, target, focus, target of target, pet and party frames in the 1.x art and layout. Turning this off takes full effect after a reload.")
Row("unitFramePlayer", "Classic player frame", "The player frame on its own. Needs Classic unit frames.", "unitFrames")
Row("unitFrameTarget", "Classic target frame", "The target frame and its target of target.", "unitFrames")
Row("unitFrameFocus", "Classic focus frame", "The focus frame.", "unitFrames")
Row("unitFramePet", "Classic pet frame", "The pet frame.", "unitFrames")
Row("unitFrameParty", "Classic party frames", "The party frames.", "unitFrames")
Row("talents", "Classic talent window",
    "The old talent window: one tree at a time with its tabs along the foot, the grid with rank plates and arrows. Clicks stage points and Learn keeps them. The talents button opens it; the talents key opens the game's own window. Off: the game's own window.")
Row("trainer", "Classic trainer window",
    "The old trainer window: the greeting, the All tab and filter, a coloured list under headers, the chosen service with what it needs and costs, your money, Train and Exit.")
Row("hideBuffArrow", "No arrow beside the buffs",
    "The arrow that folds your buffs stays hidden until the mouse is over it. Off: it always shows.")
Row("mirrorTimers", "Classic breath and fatigue bars",
    "Breath, fatigue and feign death timers in the old cast bar border: blue for breath, yellow for fatigue, the label on the bar.")
Row("castBars", "Classic cast bars",
    "The 1.x cast bar border, spark, flash and colours on the player, pet, target, focus and boss bars. The boss bars follow Forever Enhanced Cooldown Manager's Raid Timers while that's on.")
Row("welcomeNote", "Welcome note",
    "Shows the welcome note the first time a character logs in (on Forever, as a link in chat).")
Row("comboPoints", "Classic combo points",
    "Five orbs curving down the right of the target portrait, and the modern combo points under the player frame hidden.")
Row("minimap", "Classic minimap",
    "The round 1.x minimap ring with the zone name on top and tracking, zoom, mail and the clock in their old spots.")
Row("namePlates", "Classic nameplates",
    "The 1.x nameplate at its old size: a rounded border with the level slot, a shaded bar, the name above and the cast bar below. Turning this off takes full effect after a reload.")
Row("fullPlates", "No simplified nameplates",
    "Friendly players, NPCs, minions and minor mobs get the full nameplate instead of the game's reduced one. Off puts your own setting back.")
Row("questLog", "Classic quest log",
    "The 1.x quest log in its own window. The quest button and quest clicks in the tracker open it; the quest log key opens the game's own map quest panel.")
Row("questLogDual", "Double-pane quest log", "The wider quest log with two panes side by side. Off is the single pane.", "questLog")
Row("questTracker", "Classic quest tracker",
    "Old stone headers, small collapse buttons and the parchment background on the objective tracker.")
Row("bags", "Classic bags",
    "The 1.x bag windows with the old bag art, portrait ring, name strip and slots, and the old art on the One bag window too. Turning this off takes full effect after a reload.")
Row("oneBag", "One bag",
    "All your bags in one window, in the old bag art, as tall as your slots need. This is the game's own Combine Bags setting.")
Row("characterSheet", "Classic character sheet",
    "The 1.x character window. Turning this off takes full effect after a reload.")
Row("statPanes", "Stat panes with drop downs",
    "The 2.x stat boxes, each with a drop down to show any section of the game's own stats.", "characterSheet")
Row("classColorHealth", "Class coloured unit frames",
    "Health on the player, target, focus and target of target frames in a player's class colour; everything else stays green.",
    "unitFrames")
Row("classColorPlates", "Class coloured nameplates",
    "A player's nameplate health in their class colour; everything else keeps the game's colour.", "namePlates")
Row("mapFade", "Fade map while moving", "The game's own world map fade while you move. Off: the map stays solid.")
Row("hideLastNames", "Hide last names",
    "Hides every player's surname, yours too, and keeps the game's own My surname box off while on. Off: the box is yours to set again.")
Row("whoList", "Classic who list",
    "The 1.x Who tab with sortable columns and its buttons. /who answers there, and the tabs read Friends, Who, Guild.")
Row("groupFinder", "Classic group finder",
    "The group finder at the social window's size and place, with the old controls and side tabs. Needs Classic window frames.")
Row("guildRoster", "Classic guild roster",
    "The old guild tab: the member count, the message of the day, four sortable columns and the old buttons.")
Row("spellBook", "Classic spellbook",
    "The 1.x parchment spellbook. The spellbook button opens it; the spellbook key opens the game's own.")
Row("spellDrag", "Drag spells to the bars in a fight",
    "Keeps the game's own spellbook open out of sight under this one, so a spell dragged in a fight still lands on the bars.",
    "spellBook")
Row("spellBookTopRank", "Highest spell ranks only",
    "Shows only the highest rank you know of each spell. Off (the old way): every rank.", "spellBook")
Row("spellBookSearch", "Spellbook search box",
    "A search box listing every spell you know whose name holds the words you type.", "spellBook")
Row("gameDamageNumbers", "Show the game's damage numbers",
    "The game's own floating damage numbers. It lives here because an early version turned it off and the game's window no longer has it.")
Row("tradeSkill", "Classic profession windows", "A profession's window as the old trade skill window.")
Row("tradeSkillSearch", "Trade skill search box", "A search box on the profession window.", "tradeSkill")
Row("professionsBook", "Classic professions book", "The professions overview as the old two page book.")
Row("panels", "Classic window frames",
    "The old metal border, round portrait, small red X, stone title strip and character sheet tabs on the game's windows.")
-- Added 2026-10-22, last so the old page's two columns keep their places.
Row("legacyWindow", "Classic Legacy window",
    "The Legacy window (Y) in the 1.x look, like the spellbook: stone frame, parchment pages, red-brown tabs, the challenges as a quest log and the Legacy Tree as old talents. Everything in it works as before. Turning this off takes full effect after a reload.")
