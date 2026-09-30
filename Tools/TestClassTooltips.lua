-- Class-coloured Tooltips on the real AuraStyle module. GameTooltip, its
-- NineSlice and its lines are proxies that forbid key writes, so the checks
-- prove nothing is stored on Blizzard's frames. A hover runs in the client's
-- order: clear the lines, add them, run addon post-calls, then show.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local back={}
local function Proxy(b,label)
 local p=setmetatable({},{__index=b,__newindex=function(_,k)error("wrote "..tostring(k).." on "..label)end})
 back[p]=b;return p
end
hooksecurefunc=function(t,key,fn)
 if type(t)=="string"then fn=key;key=t;t=_G end
 local store=back[t]or t
 local old=store[key];store[key]=function(...)old(...);fn(...)end
end
local secret=setmetatable({},{__index=function()error("indexed a secret value")end,
 __concat=function()error("joined a secret value")end,__len=function()error("measured a secret value")end})
issecretvalue=function(v)return v==secret end
InCombatLockdown=function()return false end
Enum={TooltipDataType={Item=0,Unit=2},TooltipDataLineType={None=0,UnitName=2}}
local postCalls={}
TooltipDataProcessor={AddTooltipPostCall=function(kind,fn)postCalls[#postCalls+1]={kind,fn}end}
RAID_CLASS_COLORS={ROGUE={r=1,g=.96,b=.41},MAGE={r=.25,g=.78,b=.92},WARRIOR={r=.78,g=.61,b=.43}}

-- EraUI's own frames (the Classic backdrop and the event frame).
local backdrops={}
CreateFrame=function(_,_,parent,template)
 local f={parent=parent,shown=true,border={1,1,1,1}}
 for _,m in ipairs({"SetBackdropColor","RegisterEvent","SetScript"})do f[m]=function()end end
 function f:SetAllPoints(to)self.all=to end
 function f:SetBackdrop(info)self.info=info end
 function f:SetFrameLevel(level)self.level=level end
 function f:SetBorderBlendMode(mode)self.blend=mode end
 function f:SetBackdropBorderColor(r,g,b,a)self.border={r,g,b,a}end
 function f:Show()self.shown=true end
 function f:Hide()self.shown=false end
 if template=="BackdropTemplate"then backdrops[parent]=f;backdrops.made=(backdrops.made or 0)+1 end
 return f
end

-- Blizzard's tooltip: every line, the NineSlice and the tooltip are proxies.
local function Line(i)
 local b={colour={1,1,1},shown=false}
 function b:SetText(t)b.text=t end
 function b:GetText()return b.text end
 function b:SetTextColor(r,g,bb)b.colour={r,g,bb}end
 function b:GetTextColor()return b.colour[1],b.colour[2],b.colour[3],1 end
 function b:Show()b.shown=true end
 function b:Hide()b.shown=false end
 return Proxy(b,"tooltip line "..i),b
end
local function Tooltip(name)
 local b={shown=false,hooks={},lines={},backs={},count=0}
 local p=Proxy(b,name)
 local nb={border={1,1,1,1},alpha=1,sets=0}
 function nb:SetBorderColor(r,g,bb,a)nb.border={r,g,bb,a or 1};nb.sets=nb.sets+1 end
 function nb:GetBorderColor()return nb.border[1],nb.border[2],nb.border[3],nb.border[4]end
 function nb:SetAlpha(a)nb.alpha=a end
 function nb:GetAlpha()return nb.alpha end
 b.NineSlice=Proxy(nb,name.." NineSlice");b.nine=nb
 for i=1,10 do
  b.lines[i],b.backs[i]=Line(i)
  _G[name.."TextLeft"..i]=b.lines[i]
 end
 local function Fire(event)for _,fn in ipairs(b.hooks[event]or{})do fn(p)end end
 function b:HookScript(event,fn)b.hooks[event]=b.hooks[event]or{};table.insert(b.hooks[event],fn)end
 function b:HasScript(event)return event=="OnShow"or event=="OnHide"or event=="OnTooltipCleared"end
 function b:IsShown()return b.shown end
 function b:Show()b.shown=true;Fire("OnShow")end
 function b:Hide()if b.shown then b.shown=false;Fire("OnHide")end end
 function b:ClearLines()
  for _,line in ipairs(b.lines)do line:Hide();line:SetText(nil)end
  b.count=0;Fire("OnTooltipCleared")
 end
 function b:AddLine(text,r,g,bb)
  b.count=b.count+1;local line=b.lines[b.count]
  line:SetText(text);line:SetTextColor(r or 1,g or .82,bb or 0);line:Show()
 end
 function b:SetText(text,r,g,bb)b.ClearLines(p);b.AddLine(p,text,r,g,bb);b.Show(p)end
 function b:NumLines()return b.count end
 function b:GetLeftLine(i)return b.lines[i]end
 function b:GetName()return name end
 function b:GetFrameLevel()return 10 end
 function b:GetOwner()return nil end
 function b:IsForbidden()return false end
 return p,b
end
local tip,tipBack=Tooltip("GameTooltip")
GameTooltip=tip

-- Units by token. NPCs have classes too; only players are coloured.
local units={
 rogue={player=true,name="Zriel Gustbellow",word="Rogue",class="ROGUE",race="Human",guid="Player-1-00000001",
  lines={"<Rogue Squad>","Level 60 Human Rogue (Player)","Alliance"}},
 mage={player=true,name="Tessa Brightwick",word="Mage",class="MAGE",race="Gnome",guid="Player-1-00000002",
  lines={"Level 58 Gnome Mage (Player)","Alliance"}},
 wolf={player=false,name="Defias Enforcer",word="Warrior",class="WARRIOR",race="Human",guid="Creature-0-1-2-3-4-5",
  lines={"Level 17 Warrior","Defias Brotherhood"}},
}
local reaction={.25,.5,1}
local classCalls,guidCalls=0,0
UnitIsPlayer=function(unit)return units[unit].player end
UnitClass=function(unit)classCalls=classCalls+1;local u=units[unit];return u.word,u.class,1 end
UnitRace=function(unit)return units[unit].race end
GetPlayerInfoByGUID=function(guid)
 guidCalls=guidCalls+1
 for _,u in pairs(units)do if u.guid==guid then return u.word,u.class,u.race,u.race,2,u.name,""end end
end
-- The client's unit tooltip: data first, then clear, lines, post-calls, show.
local function Hover(t,token,opts)
 opts=opts or{}
 local u=units[token]
 local data={type=Enum.TooltipDataType.Unit,guid=opts.guid or u.guid,lines={}}
 for _,text in ipairs(opts.before or{})do data.lines[#data.lines+1]={type=0,leftText=text}end
 local nameLine={type=Enum.TooltipDataLineType.UnitName,leftText=u.name,unitToken=token}
 if opts.token~=nil then nameLine.unitToken=opts.token end
 if opts.noToken then nameLine.unitToken=nil end
 data.lines[#data.lines+1]=nameLine
 for _,text in ipairs(opts.lines or u.lines)do data.lines[#data.lines+1]={type=0,leftText=text}end
 t:ClearLines()
 for _,line in ipairs(data.lines)do
  local colour=line==nameLine and reaction or{1,1,1}
  t:AddLine(line.leftText,colour[1],colour[2],colour[3]);line.lineIndex=t:NumLines()
 end
 for _,call in ipairs(postCalls)do if call[1]==data.type then call[2](t,data)end end
 t:Show()
 return data
end
local function Text(i)return tipBack.backs[i].text end
local function Colour(i)return table.concat(tipBack.backs[i].colour,",")end
local function Border()return table.concat(tipBack.nine.border,",")end
local function Classic()return table.concat(backdrops[tip].border,",")end

local E={modules={},settings={enabled=true,tooltipSkin=false}}
function E:RegisterModule(name,m)self.modules[name]=m end
function E:GetSetting(key)return self.settings[key]end
assert(loadfile("Modules/AuraStyle.lua"))("EraUI",E)
local M=E.modules.AuraStyle
M:Initialize();M:Initialize()
equal(#postCalls,1,"one post-call, registered once")
equal(postCalls[1][1],Enum.TooltipDataType.Unit,"registered for unit tooltips through Blizzard's addon hook")

-- Off by default: the rogue's tooltip stays native.
Hover(tip,"rogue")
equal(Colour(1),"0.25,0.5,1","off by default: name keeps the game's colour")
equal(Text(3),"Level 60 Human Rogue (Player)","off by default: class word untouched")
equal(tipBack.nine.sets,0,"off by default: native border untouched")

-- On, with the Classic tooltip skin off: the game's own border is tinted.
E.settings.tooltipClassColours=true
tipBack.nine.border={.9,.8,.7,1}
Hover(tip,"rogue")
equal(Colour(1),"1,0.96,0.41","rogue name in rogue yellow")
equal(Text(1),"Zriel Gustbellow","name text unchanged")
equal(Text(3),"Level 60 Human |cfffff569Rogue|r (Player)","class word in rogue yellow")
equal(Text(2),"<Rogue Squad>","guild line untouched even with the class word in it")
equal(Text(4),"Alliance","other lines untouched")
equal(Colour(3),"1,1,1","level line keeps its own colour")
equal(Border(),"1,0.96,0.41,1","native border in rogue yellow")
equal(Classic(),"1,1,1,1","Classic backdrop not tinted while the skin is off")
equal(backdrops[tip].shown,false,"Classic backdrop stays hidden while the skin is off")

-- Moving to an NPC clears the tooltip: everything goes back.
Hover(tip,"wolf")
equal(Border(),"0.9,0.8,0.7,1","clear restores the border colour it had before")
equal(Colour(1),"0.25,0.5,1","NPC name keeps the game's colour")
equal(Text(2),"Level 17 Warrior","NPC class word untouched")
Hover(tip,"mage")
equal(Border(),"0.25,0.78,0.92,1","mage border")
equal(Text(2),"Level 58 Gnome |cff40c7ebMage|r (Player)","mage class word")
tip:Hide()
equal(Border(),"0.9,0.8,0.7,1","hiding restores the border")
equal(Colour(1),"0.25,0.5,1","hiding restores the name colour")
equal(Text(2),"Level 58 Gnome Mage (Player)","hiding restores the class word")
-- A non-unit tooltip after a player never keeps the tint.
Hover(tip,"rogue");tip:SetText("Linen Cloth",1,1,1)
equal(Border(),"0.9,0.8,0.7,1","item tooltip after a player: native border")
equal(Colour(1),"1,1,1","item tooltip after a player: item colour")

-- A rebuild without a clear never wraps the class word twice.
local data=Hover(tip,"rogue")
postCalls[1][2](tip,data);postCalls[1][2](tip,data)
equal(Text(3),"Level 60 Human |cfffff569Rogue|r (Player)","repeat post-calls colour the word once")
tip:Hide()
equal(Border(),"0.9,0.8,0.7,1","and still restore the original border")

-- Switching the option off while a player shows puts it back at once.
Hover(tip,"rogue")
E.settings.tooltipClassColours=false;M:RefreshClassTooltips()
equal(Border(),"0.9,0.8,0.7,1","switching off restores the border at once")
equal(Colour(1),"0.25,0.5,1","switching off restores the name colour at once")
equal(Text(3),"Level 60 Human Rogue (Player)","switching off restores the class word at once")
E.settings.tooltipClassColours=true;M:RefreshClassTooltips()
equal(Border(),"0.9,0.8,0.7,1","switching on waits for the next player tooltip")
tip:Hide()

-- With the Classic tooltip skin on, EraUI's own bevel is tinted instead.
equal(backdrops[backdrops[tip]],nil,"no second bevel while the skin is off")
E.settings.tooltipSkin=true
local made=backdrops.made
Hover(tip,"mage")
equal(backdrops[tip].shown,true,"Classic backdrop showing")
equal(Classic(),"0.25,0.78,0.92,1","Classic border in mage blue")
equal(tipBack.nine.alpha,0,"native border stays hidden under the Classic skin")
local sets=tipBack.nine.sets
equal(Colour(1),"0.25,0.78,0.92","name in mage blue with the skin on")
-- The grey bevel alone shows under half the colour, so a second copy of it,
-- EraUI's own, adds the same colour on top: about the name's brightness.
local glow=backdrops[backdrops[tip]]
equal(glow~=nil and glow.shown,true,"a second bevel shows while tinted")
equal(glow.parent==backdrops[tip]and glow.all,backdrops[tip],"on EraUI's own backdrop, the same size")
equal(glow.info.edgeFile==backdrops[tip].info.edgeFile and glow.info.edgeSize==backdrops[tip].info.edgeSize,true,"the same bevel art")
equal(glow.info.bgFile,nil,"with no background of its own")
equal(glow.blend,"ADD","added on top, so the border brightens")
equal(table.concat(glow.border,","),"0.25,0.78,0.92,1","in mage blue")
equal(glow.level,backdrops[tip].level+1,"drawn over the tinted bevel")
Hover(tip,"wolf")
equal(Classic(),"1,1,1,1","clear restores the Classic grey border")
equal(glow.shown,false,"and the second bevel goes")
equal(tipBack.nine.sets,sets,"the hidden native border is never tinted under the skin")
Hover(tip,"rogue")
equal(glow.shown and table.concat(glow.border,","),"1,0.96,0.41,1","the next player brings it back in their colour")
tip:Hide()
equal(Classic(),"1,1,1,1","hide restores the Classic grey border")
equal(glow.shown,false,"hide takes the second bevel away")
Hover(tip,"mage")
E.settings.tooltipClassColours=false;M:RefreshClassTooltips()
equal(glow.shown,false,"switching the option off takes it away at once")
E.settings.tooltipClassColours=true;tip:Hide()
equal(backdrops.made,made+1,"one second bevel per tooltip, made the first time it's needed")
E.settings.tooltipSkin=false

-- Players only: a player's pet or an NPC with a class stays native.
classCalls=0
Hover(tip,"wolf")
equal(tipBack.nine.border[1],.9,"NPC border native")
equal(classCalls,0,"class never looked up for NPCs")

-- Secret values leave the tooltip native, without errors.
local function Native(label)
 equal(Colour(1),"0.25,0.5,1",label..": name native")
 equal(Border(),"0.9,0.8,0.7,1",label..": border native")
end
units.rogue.word,units.rogue.class=secret,secret
Hover(tip,"rogue");Native("secret class")
equal(Text(3),"Level 60 Human Rogue (Player)","secret class: class word native")
units.rogue.word,units.rogue.class="Rogue","ROGUE"
units.rogue.player=secret
Hover(tip,"rogue");Native("secret player flag")
units.rogue.player=true
guidCalls=0
Hover(tip,"rogue",{token=secret,guid=secret});Native("secret unit and GUID")
equal(guidCalls,0,"a secret GUID is never passed on")
Hover(tip,"rogue",{token=secret});equal(Border(),"1,0.96,0.41,1","secret unit token: the public GUID still works")
tip:Hide()
-- A secret level line keeps its text; the name and border still colour.
local getText=tipBack.backs[3].GetText
tipBack.backs[3].GetText=function(self)if tipBack.backs[3].text=="Level 60 Human Rogue (Player)"then return secret end return getText(self)end
Hover(tip,"rogue")
equal(Colour(1),"1,0.96,0.41","secret level line: name still coloured")
equal(Text(3),"Level 60 Human Rogue (Player)","secret level line: text left alone")
tip:Hide();tipBack.backs[3].GetText=getText
-- A secret race: the class word still goes on the first non-guild line with it.
units.rogue.race=secret
Hover(tip,"rogue")
equal(Text(3),"Level 60 Human |cfffff569Rogue|r (Player)","secret race: level line still found")
equal(Text(2),"<Rogue Squad>","secret race: guild tag skipped")
tip:Hide();units.rogue.race="Human"
-- Secret border and name colours: tinted, then put back to the defaults.
local getBorder=tipBack.nine.GetBorderColor
tipBack.nine.GetBorderColor=function()return secret,secret,secret,secret end
Hover(tip,"rogue");tip:Hide()
equal(Border(),"1,1,1,1","unreadable border restores to white")
tipBack.nine.GetBorderColor=getBorder;tipBack.nine.border={.9,.8,.7,1}
local getColour=tipBack.backs[1].GetTextColor
tipBack.backs[1].GetTextColor=function()return secret,secret,secret,1 end
Hover(tip,"rogue")
equal(Colour(1),"1,0.96,0.41","unreadable name colour: still tinted")
tip:Hide();tipBack.backs[1].GetTextColor=getColour

-- The class word must stand alone: not part of a longer word, ASCII or not.
Hover(tip,"rogue",{lines={"Roguesque Company","Level 60 Human Rogue (Player)"}})
equal(Text(2),"Roguesque Company","'Roguesque' is not the class word")
equal(Text(3),"Level 60 Human |cfffff569Rogue|r (Player)","the level line is")
tip:Hide()
units.rogue.race=nil
Hover(tip,"rogue",{lines={"Rogue Squad","Level 60 Human Rogue (Player)"}})
equal(Text(2),"|cfffff569Rogue|r Squad","with no race known the first non-tag line is used")
tip:Hide()
units.rogue.race="Human"
Hover(tip,"rogue",{lines={"Rogue Squad","Level 60 Human Rogue (Player)"}})
equal(Text(2),"Rogue Squad","with the race known, a plain guild name is skipped")
equal(Text(3),"Level 60 Human |cfffff569Rogue|r (Player)","and the level line coloured")
tip:Hide()
-- (Race unknown here, so only the word test decides which line is used.)
units.rogue.word,units.rogue.race="Pícaro",nil
Hover(tip,"rogue",{lines={"Pícaros","Nivel 60 Pícaroé","Nivel 60 ÉPícaro","Nivel 60 Humano Pícaro (Jugador)"}})
equal(Text(2),"Pícaros","accented word: plural not matched")
equal(Text(3),"Nivel 60 Pícaroé","accented word: a following accented letter is part of the word")
equal(Text(4),"Nivel 60 ÉPícaro","accented word: a leading accented letter is part of the word")
equal(Text(5),"Nivel 60 Humano |cfffff569Pícaro|r (Jugador)","accented class word coloured")
tip:Hide();units.rogue.word,units.rogue.race="Rogue","Human"
-- The name line itself is never rewritten, even with the class word in it.
units.rogue.name,units.rogue.race="Rogue Stabsworth",nil
Hover(tip,"rogue",{lines={"Level 60 Human Rogue (Player)"}})
equal(Text(1),"Rogue Stabsworth","name line text never rewritten")
equal(Colour(1),"1,0.96,0.41","name line still coloured")
equal(Text(2),"Level 60 Human |cfffff569Rogue|r (Player)","level line coloured")
tip:Hide();units.rogue.name,units.rogue.race="Zriel Gustbellow","Human"
-- The name line index comes from the tooltip data.
Hover(tip,"rogue",{before={"Corpse"}})
equal(Colour(1),"1,1,1","a line before the name keeps its colour")
equal(Colour(2),"1,0.96,0.41","the name line found by its index")
tip:Hide()

-- GUID route: no unit token on the name line.
guidCalls=0
Hover(tip,"rogue",{noToken=true})
equal(Border(),"1,0.96,0.41,1","player GUID alone is enough")
equal(guidCalls,1,"looked up once by GUID")
tip:Hide();guidCalls=0
Hover(tip,"wolf",{noToken=true})
equal(Border(),"0.9,0.8,0.7,1","creature GUID stays native")
equal(guidCalls,0,"creature GUIDs are never looked up")
tip:Hide()

-- Older clients without GetLeftLine use the named lines.
tipBack.GetLeftLine=false
Hover(tip,"rogue")
equal(Text(3),"Level 60 Human |cfffff569Rogue|r (Player)","named lines work too")
tip:Hide();tipBack.GetLeftLine=function(_,i)return tipBack.lines[i]end

-- Custom class colours win, like the rest of EraUI.
CUSTOM_CLASS_COLORS={ROGUE={r=.5,g=.25,b=0}}
Hover(tip,"rogue")
equal(Border(),"0.5,0.25,0,1","custom class colour used")
equal(Text(3),"Level 60 Human |cff804000Rogue|r (Player)","custom colour on the class word")
tip:Hide();CUSTOM_CLASS_COLORS=nil

-- EraUI switched off: native.
E.settings.enabled=false
Hover(tip,"rogue")
equal(Border(),"0.9,0.8,0.7,1","EraUI off: native border")
tip:Hide();E.settings.enabled=true

-- Only tooltips EraUI watches are tinted, since only they are restored.
local other,otherBack=Tooltip("OtherTooltip")
Hover(other,"rogue")
equal(otherBack.nine.sets,0,"an unwatched tooltip is left alone")
equal(table.concat(otherBack.backs[1].colour,","),"0.25,0.5,1","an unwatched tooltip's name is left alone")

print("Class-coloured tooltip checks passed: "..checks.." assertions.")
