-- Cosmetic player aura borders, Classic tooltips and class-coloured player
-- tooltips. Native aura data, timers, dispel symbols, cancellation and tooltip
-- lines remain owned by the client.
local _,E=...
local M={};E:RegisterModule("AuraStyle",M)
local owners=setmetatable({}, {__mode="k"})
local tips=setmetatable({}, {__mode="k"})
local hooked=setmetatable({}, {__mode="k"})
local function Public(v)return not(issecretvalue and issecretvalue(v))end
local function Enabled()return E:GetSetting("enabled")and E:GetSetting("unitFrames")end
local function GeneralTooltips()return E:GetSetting("enabled")and E:GetSetting("tooltipSkin")end

local BORDER="Interface\\AddOns\\EraUI\\Media\\TooltipBorder.tga"
-- In Dark Mode the bevel's grey follows the Darkness slider, as Dark Aura
-- Borders' line does: as drawn at 58 or lighter, near black at 90. A
-- class-coloured border keeps its colour.
local function BevelShade()
 local grey=E.Classic and E.Classic.DarkGrey
 if not(grey and E:GetSetting("darkMode"))then return 1 end
 return math.min(1,(grey())/.42)
end
local function PlainBorder(backdrop)
 local shade=BevelShade()
 backdrop:SetBackdropBorderColor(shade,shade,shade,1)
end
local function RestoreTooltip(tip)
 local state=tips[tip]
 if not state then return end
 state.aura=false;state.styled=false;state.backdrop:Hide()
 if state.originalAlpha~=nil and tip.NineSlice then
  tip.NineSlice:SetAlpha(state.originalAlpha);state.originalAlpha=nil
 end
end
local function PaintTooltip(tip)
 local state=tips[tip]
 if not state then return end
 if state.embedded or tip.IsEmbedded or(not GeneralTooltips()and not(Enabled()and state.aura))then RestoreTooltip(tip);return end
 state.styled=true
 if tip.NineSlice then
  if state.originalAlpha==nil then state.originalAlpha=tip.NineSlice:GetAlpha()end
  tip.NineSlice:SetAlpha(0)
 end
 local level=math.max(0,tip:GetFrameLevel()-1)
 state.backdrop:SetFrameLevel(level)
 if state.glow then state.glow:SetFrameLevel(level+1)end
 state.backdrop:Show()
end
local function AuraTooltip(tip)
 if not tips[tip]then return end
 tips[tip].aura=true;PaintTooltip(tip)
end
-- Class-coloured Tooltips: a player's tooltip border, name
-- line and class word in their class colour. Only colours change; the lines
-- stay the game's. The border tint goes on whichever border is showing:
-- EraUI's Classic bevel, or the game's own through its colour setter. A secret
-- or unknown class leaves the tooltip native, and every clear or hide puts
-- the old colours back. Nothing is stored on Blizzard's frames.
local tinted=setmetatable({}, {__mode="k"})
local NAME_LINE=Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.UnitName
local function ClassTooltips()return(E:GetSetting("enabled")and E:GetSetting("tooltipClassColours"))and true or false end
local function Str(v)return Public(v)and type(v)=="string"and v~=""and v or nil end
local function Num(v)return Public(v)and type(v)=="number"and v or nil end
local function Line(tip,index)
 if tip.GetLeftLine then return tip:GetLeftLine(index)end
 local name=tip.GetName and tip:GetName()
 return name and _G[name.."TextLeft"..index]
end
-- Where word stands on its own in text, not inside a longer word.
local function Word(text,word)
 local from=1
 while true do
  local s,e=text:find(word,from,true)
  if not s then return end
  if not text:sub(s-1,s-1):find("[%w\128-\255]")and not text:sub(e+1,e+1):find("[%w\128-\255]")then return s,e end
  from=s+1
 end
end
-- r, g, b, class word and race for a player; nothing for NPCs, pets or a
-- class the game keeps secret.
local function PlayerClass(unit,guid)
 local word,class,race
 if Str(unit)then
  local player=UnitIsPlayer(unit)
  if not Public(player)or not player then return end
  word,class=UnitClass(unit);race=UnitRace and UnitRace(unit)
 elseif Str(guid)and guid:find("^Player%-")and GetPlayerInfoByGUID then
  word,class,race=GetPlayerInfoByGUID(guid)
 end
 word,class=Str(word),Str(class)
 local c=class and((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])or(RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
 if not word or type(c)~="table"or not(Num(c.r)and Num(c.g)and Num(c.b))then return end
 return c.r,c.g,c.b,word,Str(race)
end
-- The Classic bevel is a mid grey, so tinted alone it shows the class colour
-- at under half strength. While tinted, a second bevel of EraUI's own adds
-- the same colour on top (additive), bringing the border up to about the
-- name's colour with the bevel's shading kept.
local function Glow(tip,state)
 local glow=state.glow
 if not glow then
  glow=CreateFrame("Frame",nil,state.backdrop,"BackdropTemplate")
  glow:SetAllPoints(state.backdrop)
  glow:SetBackdrop({edgeFile=BORDER,edgeSize=16})
  if glow.SetBorderBlendMode then glow:SetBorderBlendMode("ADD")end
  glow:Hide();state.glow=glow
 end
 glow:SetFrameLevel(math.max(0,tip:GetFrameLevel()-1)+1)
 return glow
end
local function Untint(tip)
 local saved=tinted[tip]
 if not saved then return end
 tinted[tip]=nil
 if saved.backdrop then PlainBorder(saved.backdrop)end
 if saved.glow then saved.glow:Hide()end
 local nine=saved.nine
 if nine then tip.NineSlice:SetBorderColor(nine[1],nine[2],nine[3],nine[4])end
 if saved.name then saved.name:SetTextColor(saved.r,saved.g,saved.b)end
 local line=saved.line
 if not line then return end
 local text=line:GetText()
 if Public(text)and text==saved.coloured then line:SetText(saved.text)end
end
local function Tint(tip,data)
 local state=tip and tips[tip]
 if not state or type(data)~="table"or(tip.IsForbidden and tip:IsForbidden())then return end
 Untint(tip)
 if not ClassTooltips()then return end
 local unit,index
 for _,line in ipairs(type(data.lines)=="table"and data.lines or{})do
  if NAME_LINE and Num(line.type)==NAME_LINE then unit,index=line.unitToken,line.lineIndex;break end
 end
 local r,g,b,word,race=PlayerClass(unit,data.guid)
 if not r then return end
 index=Num(index)or 1
 local saved={};tinted[tip]=saved
 local name=Line(tip,index)
 if name then
  local nr,ng,nb=name:GetTextColor()
  if Num(nr)and Num(ng)and Num(nb)then saved.name,saved.r,saved.g,saved.b=name,nr,ng,nb end
  name:SetTextColor(r,g,b)
 end
 -- The class word on the line that also names the race (the level line),
 -- else on the first line with it that isn't a <Guild> tag.
 local pick
 for i=1,Num(tip.NumLines and tip:NumLines())or 0 do
  local line=i~=index and Line(tip,i)
  local text=line and Str(line:GetText())
  local s,e
  if text then s,e=Word(text,word)end
  if s then
   if race and Word(text,race)then pick={line,text,s,e};break end
   if not pick and text:sub(1,1)~="<"then pick={line,text,s,e}end
  end
 end
 if pick then
  local text,s,e=pick[2],pick[3],pick[4]
  local function Byte(v)return math.max(0,math.min(255,math.floor(v*255+.5)))end
  saved.line,saved.text=pick[1],text
  saved.coloured=text:sub(1,s-1)..string.format("|cff%02x%02x%02x",Byte(r),Byte(g),Byte(b))..word.."|r"..text:sub(e+1)
  saved.line:SetText(saved.coloured)
 end
 if state.styled then
  saved.backdrop=state.backdrop;state.backdrop:SetBackdropBorderColor(r,g,b,1)
  saved.glow=Glow(tip,state);saved.glow:SetBackdropBorderColor(r,g,b,1);saved.glow:Show()
 elseif tip.NineSlice and tip.NineSlice.SetBorderColor then
  local br,bg,bb,ba
  if tip.NineSlice.GetBorderColor then br,bg,bb,ba=tip.NineSlice:GetBorderColor()end
  saved.nine=(Num(br)and Num(bg)and Num(bb))and{br,bg,bb,Num(ba)or 1}or{1,1,1,1}
  tip.NineSlice:SetBorderColor(r,g,b,1)
 end
end
local function AttachTooltip(tip)
 if not tip or tips[tip]or(tip.IsForbidden and tip:IsForbidden())then return end
 local backdrop=CreateFrame("Frame",nil,tip,"BackdropTemplate")
 backdrop:SetAllPoints(tip)
  -- Authored neutral-grey bevel and curved corners, independent of the client's
  -- recoloured tooltip assets. Text and item-quality colours remain native.
  backdrop:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
   edgeFile=BORDER,edgeSize=16,
   insets={left=3,right=3,top=3,bottom=3}})
  backdrop:SetBackdropColor(.016,.016,.02,.9);PlainBorder(backdrop)
 backdrop:Hide();tips[tip]={backdrop=backdrop}
 if tip.NineSlice then
  hooksecurefunc(tip.NineSlice,"SetAlpha",function(slice,value)
   if tips[tip].styled and Public(value)and value~=0 then slice:SetAlpha(0)end
  end)
 end
 tip:HookScript("OnShow",function(self)
   local owner=self.GetOwner and self:GetOwner()
  if Public(owner)and owners[owner]then tips[self].aura=true end
  PaintTooltip(self)
 end)
 tip:HookScript("OnHide",function(self)RestoreTooltip(self);Untint(self)end)
 if not tip.HasScript or tip:HasScript("OnTooltipCleared")then
  tip:HookScript("OnTooltipCleared",function(self)
   Untint(self);RestoreTooltip(self)
   if GeneralTooltips()then PaintTooltip(self)end
  end)
 end
 for _,method in ipairs({"SetUnitAura","SetUnitBuff","SetUnitDebuff","SetUnitAuraByAuraInstanceID","SetUnitBuffByAuraInstanceID","SetUnitDebuffByAuraInstanceID"})do
  if tip[method]then hooksecurefunc(tip,method,AuraTooltip)end
 end
 if tip:IsShown()then PaintTooltip(tip)end
end

-- Forever's client has no DebuffTypeColor; its own aura buttons colour a
-- debuff's border with AuraUtil.GetAuraBorderColor. Use that, the old table
-- where a client still has it, then plain red.
local function DebuffColour(dispel)
 local get=AuraUtil and AuraUtil.GetAuraBorderColor
 if get then
  local ok,colour=pcall(get,dispel)
  if ok and type(colour)=="table" and type(colour.r)=="number" then return colour.r,colour.g or 0,colour.b or 0 end
 end
 local old=DebuffTypeColor and(DebuffTypeColor[dispel or "none"]or DebuffTypeColor.none)
 if old then return old.r or .8,old.g or 0,old.b or 0 end
 return .8,0,0
end
local function StyleButton(button)
 if not button or button.isAuraAnchor then return end
 owners[button]=true
 if not Enabled()then return end
 local border=button.DebuffBorder
 local kind=button.auraType
 if not border or not Public(kind)or(kind~="Debuff"and kind~="DeadlyDebuff")then return end
 local info=button.buttonInfo
 local dispel=info and info.debuffType
 -- Keep the native border when its type is restricted; never infer a dispel.
 if not Public(dispel)then return end
 border:SetTexture("Interface\\Buttons\\UI-Debuff-Border")
 border:SetTexCoord(0,1,0,1)
 border:SetVertexColor(DebuffColour(dispel))
  if button.Icon then
   -- Native aura geometry can be secret. Let anchors follow the icon without
   -- reading or performing arithmetic on its width/height.
   border:ClearAllPoints()
   border:SetPoint("TOPLEFT",button.Icon,"TOPLEFT",-3,3)
   border:SetPoint("BOTTOMRIGHT",button.Icon,"BOTTOMRIGHT",3,-3)
  end
end
-- Dark Aura Borders (on by default): a thin dark ring round each of the
-- player's own aura icons while Dark Mode is active. EraUI's own textures,
-- anchored to the icon and always below the native debuff, enchant, symbol
-- and count overlays. Nothing about the aura is read (type, data, geometry),
-- so styling a button is the same in and out of combat. Target and focus
-- auras are secure, forbidden buttons and are left alone.
-- Each aura button's borders: {dab = Dark Aura Borders' ring, thick = Thick
-- Aura Borders' ring, trimmed, shadow, steps, shaded, soft}. A ring is its
-- strips in order plus {line = its line strips, on, r, g, b, dim, typed};
-- the thick ring also {thick, wide, bronze}.
local rings=setmetatable({}, {__mode="k"})
local pending=false
-- {outside, inside, r, g, b, layer, sublevel}: a band from `outside` units
-- past the icon's edge (negative: inside it) to `inside` units in. Dark Aura
-- Borders: a dark edge outside the icon, drawn under the icon and its timer
-- text, then a grey line over the icon's own bright rim, in Dark Mode's
-- grey. The line darkens with the Darkness slider.
local LINE={0,1,.30,.31,.34,"ARTWORK",1}
local TONES={{2,0,.05,.05,.06,"BACKGROUND",-8},LINE}
-- Thick Aura Borders (off unless ticked; Classic or Dark Mode, its own
-- switch): a thick near-black edge with a fine line inside it. Forever's
-- aura icons are 30 units square (AuraButtonArtTemplate) and Edit Mode puts
-- them at least 5 apart (Icon Padding 5 to 15, in the icon's own scale, so
-- it holds at every Icon Size); rows of the usual layout sit 15 apart (the
-- timer is under each icon). So the edge reaches only 2 units past the icon,
-- like Dark Aura Borders' edge, and two neighbours' edges keep a unit apart;
-- the other 2 units lie over the icon's outer rim: 4 in all, about 13% of
-- the icon. The part outside sits under the timer text, the part inside
-- over the icon. Then a 1-unit line, 2 to 3 units in: Dark Mode's grey
-- (with the Darkness slider), or in Classic a muted bronze. A debuff whose
-- type is known gets a 2-unit line (2 to 4 in) in the type's colour.
local BRONZE={.55,.46,.27}
local THICK_LINE={-2,3,0,0,0,"ARTWORK",2}
local THICK={{2,0,.05,.05,.06,"BACKGROUND",-8},{0,2,.05,.05,.06,"ARTWORK",1},THICK_LINE}
local TYPED_LINE=4 -- a debuff's type line ends 4 units in, not 3
-- The four strips of a band: top, bottom, left and right, each pinned by two
-- icon corners. Corners are covered twice; every strip is opaque.
local function Band(o,i)
 return{{"TOPLEFT",-o,o,"TOPRIGHT",o,-i},{"BOTTOMLEFT",-o,i,"BOTTOMRIGHT",o,-o},
  {"TOPLEFT",-o,o,"BOTTOMLEFT",i,-o},{"TOPRIGHT",-i,o,"BOTTOMRIGHT",o,-o}}
end
local function Pin(strip,icon,edge)
 strip:SetPoint("TOPLEFT",icon,edge[1],edge[2],edge[3])
 strip:SetPoint("BOTTOMRIGHT",icon,edge[4],edge[5],edge[6])
end
-- Aura Shadows (on by default, needs Dark Aura Borders): a soft shadow past
-- the dark edge, three one-unit rings of black, each fainter than the last
-- (the ring technique of Forever Enhanced Cooldown Manager's icon shadow).
-- Five units in all, Edit Mode's smallest gap between icons, so it never
-- reaches a neighbouring icon. The rings sit on an EraUI frame one level
-- below the aura button, so every aura's icon, timer and debuff border draws
-- over every shadow: its own and its neighbours'.
local SHADOW={.45,.25,.1}
-- With Thick Aura Borders the shadow drops to a softer two-step one, 2 to 4
-- units out (35%, then 15%): edge and shadow end a unit short of the next
-- icon at Edit Mode's smallest gap (5). Between close neighbours its outer
-- step lies under the neighbour's own edge, which draws over every shadow.
local SOFT={.35,.15}
local EDGE=2 -- the dark edge's width outside the icon (both looks)
local function DarkBorders()
 return(E:GetSetting("enabled")and E:GetSetting("darkMode")and E:GetSetting("darkAuraBorders"))and true or false
end
local function DarkShadows()
 return(DarkBorders()and E:GetSetting("darkAuraShadows"))and true or false
end
local function ThickBorders()
 return(E:GetSetting("enabled")and E:GetSetting("thickAuraBorders"))and true or false
end
-- A protected button (not how Forever builds aura buttons) waits for combat to end.
local function Locked(button)
 if InCombatLockdown()and button.IsProtected and button:IsProtected()then pending=true;return true end
 return false
end
-- The shadow's own frame, sized by two icon corners and never mouse-enabled.
-- Top and bottom rings take the corners, so no spot is shaded twice. Each
-- ring's strips are kept (steps) for the softer shadow.
local function Shadow(button,icon)
 local reach=EDGE+#SHADOW
 local holder=CreateFrame("Frame",nil,button)
 holder:SetPoint("TOPLEFT",icon,"TOPLEFT",-reach,reach)
 holder:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",reach,-reach)
 local steps={}
 for step,alpha in ipairs(SHADOW)do
  local d=EDGE+step-1
  steps[step]={}
  for _,edge in ipairs({{"TOPLEFT",-d-1,d+1,"TOPRIGHT",d+1,d},{"BOTTOMLEFT",-d-1,-d,"BOTTOMRIGHT",d+1,-d-1},
   {"TOPLEFT",-d-1,d,"BOTTOMLEFT",-d,-d},{"TOPRIGHT",d,d,"BOTTOMRIGHT",d+1,-d}})do
   local strip=holder:CreateTexture(nil,"BACKGROUND",nil,-8)
   strip:SetColorTexture(0,0,0,alpha)
   Pin(strip,icon,edge)
   table.insert(steps[step],strip)
  end
 end
 return holder,steps
end
-- The full shadow (three rings) or, under Thick Aura Borders, the softer
-- two-step one: the first two rings fainter, the third hidden. Set only when
-- it changes.
local function Soften(state,soft)
 if state.soft==soft then return end
 state.soft=soft
 for step,strips in ipairs(state.steps)do
  local alpha=(soft and SOFT or SHADOW)[step]
  for _,strip in ipairs(strips)do
   if alpha then strip:SetColorTexture(0,0,0,alpha)end
   strip:SetShown(alpha~=nil)
  end
 end
end
-- One level under the button, checked on every update in case it moved. The
-- level is checked as a plain number before any arithmetic.
local function Lower(button,holder)
 local level=Num(button:GetFrameLevel())
 level=level and math.max(0,level-1)
 if level and holder:GetFrameLevel()~=level then holder:SetFrameLevel(level)end
end
-- How far the grey line follows the Darkness slider: 1 (today's grey) at the
-- default 58 or lighter, down to about a quarter at 90. The same step as
-- "Darken class colours too".
local function Dim()
 local grey=E.Classic and E.Classic.DarkGrey
 return grey and math.min(1,(grey())/.42)or 1
end
-- Colours a ring's line; a line already in that colour is left alone.
local function Paint(ring,r,g,b)
 if ring.r==r and ring.g==g and ring.b==b then return end
 ring.r,ring.g,ring.b=r,g,b
 for _,strip in ipairs(ring.line)do strip:SetColorTexture(r,g,b,1)end
end
-- The grey line at the slider's shade (a Thick Aura Borders line in
-- Classic: bronze, which the slider leaves alone). A line wearing a debuff's
-- type colour (Thin Debuff Colours, below) keeps it: the slider leaves it alone.
local function Tone(ring,dim)
 ring.dim=dim
 if ring.typed then return end
 if ring.bronze then Paint(ring,BRONZE[1],BRONZE[2],BRONZE[3])else Paint(ring,LINE[3]*dim,LINE[4]*dim,LINE[5]*dim)end
end
-- A thick ring's line: 1 unit wide, or 2 in a debuff's type colour. Our own
-- strips are pinned again only when the width changes, which only follows
-- the native border's own change (Debuff, below): a protected button (not
-- how Forever builds them) has already waited for combat to end by then.
local function Widen(ring,wide,button)
 if ring.wide==wide then return end
 ring.wide=wide
 for side,edge in ipairs(Band(THICK_LINE[1],wide and TYPED_LINE or THICK_LINE[2]))do
  local strip=ring.line[side]
  strip:ClearAllPoints();Pin(strip,button.Icon,edge)
 end
end
-- A debuff's type colour on its ring's line, or (no colour) the grey again.
local function TypeLine(ring,r,g,b,button)
 ring.typed=r~=nil or nil
 if r then Paint(ring,r,g,b)else Tone(ring,ring.dim)end
 if ring.thick then Widen(ring,r~=nil,button)end
end
-- While its ring shows, the icon's art is zoomed in a little (the .07 trim
-- EraUI's own icons use) so its bright built-in bevel is cut off and the
-- border reads dark. Set on every pass, as the game may reset a reused
-- button's coords; full coords go back once when the ring hides. Constants
-- only: nothing about the icon is read. The consolidated buffs button is left
-- out: its icon is a cropped piece of a larger sheet with the game's own coords.
local function Trim(button,state,on)
 if not(on or state.trimmed)or Locked(button)then return end
 state.trimmed=on
 if on then button.Icon:SetTexCoord(.07,.93,.07,.93)else button.Icon:SetTexCoord(0,1,0,1)end
end
-- One of a button's two rings: made (EraUI's own textures on the button)
-- the first time it shows, then only shown, hidden and toned.
local function Show(button,state,key,on,dim)
 local ring=state[key]
 if not ring then
  if not on or Locked(button)then return end
  local tones,line=TONES,LINE
  ring={line={}};state[key]=ring
  if key=="thick"then tones,line,ring.thick,ring.wide=THICK,THICK_LINE,true,false end
  for _,tone in ipairs(tones)do
   for _,edge in ipairs(Band(tone[1],tone[2]))do
    local strip=button:CreateTexture(nil,tone[6],nil,tone[7])
    if tone==line then ring.line[#ring.line+1]=strip else strip:SetColorTexture(tone[3],tone[4],tone[5],1)end
    Pin(strip,button.Icon,edge)
    ring[#ring+1]=strip
   end
  end
 end
 -- Thick Aura Borders' line is bronze in the Classic look.
 if key=="thick"then ring.bronze=not E:GetSetting("darkMode")or nil end
 Tone(ring,dim)
 if ring.on~=on then
  ring.on=on
  for _,strip in ipairs(ring)do strip:SetShown(on)end
 end
end
-- One pass over an aura button. on: Dark Aura Borders; thick: Thick Aura
-- Borders, which wins (Dark Aura Borders' ring hides while it shows); shade:
-- Aura Shadows, softer under the thick edge.
local function Ring(button,on,shade,dim,cropped,thick)
 if not button or button.isAuraAnchor or not button.Icon then return end
 local state=rings[button]
 if not state then
  if not(on or thick)or Locked(button)then return end
  state={};rings[button]=state
 end
 thick=thick and true or false
 on=on and not thick
 Show(button,state,"dab",on,dim)
 Show(button,state,"thick",thick,dim)
 if not cropped then Trim(button,state,on or thick)end
 if not(shade or state.shadow)or Locked(button)then return end
 if not state.shadow then state.shadow,state.steps=Shadow(button,button.Icon);state.soft=false end
 if shade then Lower(button,state.shadow);Soften(state,thick)end
 if state.shaded~=shade then state.shaded=shade;state.shadow:SetShown(shade)end
end
-- Boosted Rest is good for you, but the game lists it with your debuffs, so
-- it wears a typeless debuff's red ring. While Dark Aura Borders (or Thick
-- Aura Borders) show, that ring goes and the dark border shows, as on your
-- buffs, its line plain. Known by the Bonus XP icon it shows: with the
-- debuff's type (Thin Debuff Colours, below) the only aura data EraUI reads,
-- and only on the debuff row (the dark ring itself reads none). In a fight
-- the game can keep the icon secret, so each aura seen as Boosted Rest is
-- remembered by its instance ID; when neither can be read, the border is
-- left as it is.
local BONUS_XP_ICON=1001982 -- Interface\Icons\xpbonus_icon
local friendly=setmetatable({}, {__mode="k"})
local bonusAuras={} -- auraInstanceID -> true, learnt while the icon could be read
-- Whether a debuff button shows Boosted Rest; nil when it can't be told.
local function IsBonus(button)
 local kind,info=button.auraType,button.buttonInfo
 if not Public(kind)then return nil end
 if kind~="Debuff"or type(info)~="table"then return false end
 local icon,id=info.texture,info.auraInstanceID
 local known=Public(id)and id~=nil
 if Public(icon)then
  local bonus=icon==BONUS_XP_ICON
  if known then bonusAuras[id]=bonus or nil end
  return bonus
 end
 if known then return bonusAuras[id]==true end
 return nil
end
-- Thin Debuff Colours (off unless ticked, needs Dark Aura Borders): on the
-- debuff row, a debuff whose type can be read wears the dark border like
-- your buffs, its ring's thin line in the type's colour (the game's own,
-- DebuffColour) and the game's thick coloured border hidden (alpha 0). In a
-- fight the game can keep the type secret, so each type read is remembered
-- by the aura's instance ID, as Boosted Rest is; a debuff whose type can't
-- be told keeps the game's border as the game set it. Boosted Rest keeps
-- its plain dark border. Remembered types are kept for the last hundred or
-- so auras seen (two lists: the newer one is moved back when full).
-- Thick Aura Borders does the same on its own (no tick needed), in Classic
-- too: a known type colours the thick ring's line, 2 units wide; an unknown
-- one keeps the game's coloured border, as the game set it, which still
-- shows the right colour. The ring that shows takes the colour; the other
-- (hidden) keeps its plain line.
local typed=setmetatable({}, {__mode="k"}) -- debuff button: its border hidden for a type line
local TYPES_KEPT=100
local types,oldTypes,typeCount={},{},0 -- auraInstanceID -> dispel type (false: none)
local function RememberType(id,dispel)
 if types[id]==nil then
  if typeCount>=TYPES_KEPT then oldTypes,types,typeCount=types,{},0 end
  typeCount=typeCount+1
 end
 types[id]=dispel or false
end
-- Whether the type of the debuff a button shows can be told, and the type
-- (nil for none). Read only while it is public; secret values are never
-- compared or kept.
local function DebuffType(info)
 if type(info)~="table"then return false end
 local dispel,id=info.debuffType,info.auraInstanceID
 local known=Public(id)and id~=nil
 if Public(dispel)then
  if known then RememberType(id,dispel)end
  return true,dispel
 end
 if not known then return false end
 local seen=types[id]
 if seen==nil then seen=oldTypes[id];if seen~=nil then RememberType(id,seen)end end
 if seen==nil then return false end
 return true,seen or nil
end
-- Hides a debuff's native border; one already hidden is left alone.
local function HideBorder(border)
 local alpha=border:GetAlpha()
 if not(Public(alpha)and alpha==0)then border:SetAlpha(0)end
end
-- A debuff button's border and line, checked on every pass of the debuff
-- row: Boosted Rest's dark border, a type line, or the game's own border.
local function Debuff(button,on,thick)
 if not button or button.isAuraAnchor then return end
 local border=button.DebuffBorder
 if not border then return end
 local state=rings[button]
 local dab,wide=state and state.dab,state and state.thick
 -- The ring that shows (Thick Aura Borders wins) and whether it takes a
 -- type colour: always under Thick Aura Borders, else with Thin Debuff Colours.
 local ring,lines=dab,E:GetSetting("darkDebuffLines")
 if thick then ring,lines=wide,true end
 on=on or thick
 local bonus=false
 if on then bonus=IsBonus(button)end
 if bonus==nil then
  -- Nothing can be told: Boosted Rest's dark border stays as it is; a type
  -- line gives way to the game's own border.
  if typed[button]and not Locked(button)then
   typed[button]=nil;border:SetAlpha(1)
   if dab then TypeLine(dab,nil,nil,nil,button)end
   if wide then TypeLine(wide,nil,nil,nil,button)end
  end
  return
 end
 local r,g,b
 if not bonus and on and ring and ring.on and lines then
  local kind=button.auraType
  if Public(kind)and kind=="Debuff"then
   local known,dispel=DebuffType(button.buttonInfo)
   if known then r,g,b=DebuffColour(dispel)end
  end
 end
 if bonus or r then
  if Locked(button)then return end
  HideBorder(border)
  friendly[button],typed[button]=bonus or nil,r and true or nil
 elseif friendly[button]or typed[button]then
  if Locked(button)then return end
  friendly[button],typed[button]=nil,nil;border:SetAlpha(1)
 end
 if dab then TypeLine(dab,ring==dab and r or nil,g,b,button)end
 if wide then TypeLine(wide,ring==wide and r or nil,g,b,button)end
end
-- Each debuff button is checked again straight after the game updates it, so
-- the dark border stays on the right icon however the row is refreshed.
local watched=setmetatable({}, {__mode="k"})
local function WatchDebuff(button)
 if not button or watched[button]or button.isAuraAnchor or type(button.Update)~="function"then return end
 watched[button]=true
 hooksecurefunc(button,"Update",function(self)Debuff(self,DarkBorders(),ThickBorders())end)
end
-- The player's aura rows: buffs, debuffs, external defensives and the
-- consolidated-buff popout, plus the consolidated button itself.
local function Rows()
 local consolidated=BuffFrame and BuffFrame.ConsolidatedBuffs
 return{BuffFrame,DebuffFrame,ExternalDefensivesFrame,consolidated and consolidated.Tooltip and consolidated.Tooltip.Auras},consolidated
end
local function StyleFrame(frame)
 if not frame then return end
 if not hooked[frame]and frame.UpdateAuraButtons then
  hooked[frame]=true
  hooksecurefunc(frame,"UpdateAuraButtons",StyleFrame)
 end
 local on,shade,dim,thick=DarkBorders(),DarkShadows(),Dim(),ThickBorders()
 local debuffs=frame==DebuffFrame
 for _,button in ipairs(frame.auraFrames or{})do
  Ring(button,on,shade,dim,nil,thick);StyleButton(button)
  if debuffs then WatchDebuff(button);Debuff(button,on,thick)end
 end
end
function M:RefreshBorders()
 local on,shade,dim,thick=DarkBorders(),DarkShadows(),Dim(),ThickBorders();pending=false
 local rows,consolidated=Rows()
 for index=1,4 do
  for _,button in ipairs(rows[index]and rows[index].auraFrames or{})do
   Ring(button,on,shade,dim,nil,thick)
   if index==2 then Debuff(button,on,thick)end
  end
 end
 Ring(consolidated,on,shade,dim,true,thick);Ring(DeadlyDebuffFrame and DeadlyDebuffFrame.Debuff,on,shade,dim,nil,thick)
end
-- The Darkness slider (Core/Appearance.lua RefreshDarkness): every ring's
-- grey line takes the new shade at once (Dark Aura Borders' and, in Dark
-- Mode, Thick Aura Borders').
function M:RefreshDarkness()
 local dim=Dim()
 for _,state in pairs(rings)do
  if state.dab then Tone(state.dab,dim)end
  if state.thick then Tone(state.thick,dim)end
 end
 -- And every tooltip's bevel that isn't wearing a class colour.
 for tip,state in pairs(tips)do if not tinted[tip]then PlainBorder(state.backdrop)end end
end
function M:Refresh()
 for _,name in ipairs({"GameTooltip","BuffFrameTooltip","ItemRefTooltip","ShoppingTooltip1","ShoppingTooltip2",
  "ItemRefShoppingTooltip1","ItemRefShoppingTooltip2"})do AttachTooltip(_G[name])end
 local rows=Rows()
 for index=1,4 do StyleFrame(rows[index])end
 self:RefreshBorders()
end
-- Switching Class-coloured Tooltips off puts a tinted tooltip back at once;
-- switching it on shows on the next player tooltip.
function M:RefreshClassTooltips()
 if ClassTooltips()then return end
 for tip in pairs(tinted)do Untint(tip)end
end
function M:Initialize()
 self:Refresh()
 -- Blizzard's supported hook for addons: it runs after a unit tooltip's
 -- lines are added and keeps this code apart from the tooltip's own.
 if not self.classHooked and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
  and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
  self.classHooked=true
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,Tint)
 end
 if SharedTooltip_SetBackdropStyle then
  hooksecurefunc("SharedTooltip_SetBackdropStyle",function(tip,_,embedded)
   if not tips[tip]and GeneralTooltips()then AttachTooltip(tip)end
   if tips[tip]then tips[tip].embedded=embedded;PaintTooltip(tip)end
  end)
 end
 local events=CreateFrame("Frame")
 events:RegisterEvent("ADDON_LOADED");events:RegisterEvent("PLAYER_ENTERING_WORLD");events:RegisterEvent("PLAYER_REGEN_ENABLED")
 events:SetScript("OnEvent",function(_,event)
  if event~="PLAYER_REGEN_ENABLED"then M:Refresh()elseif pending then M:RefreshBorders()end
 end)
end
