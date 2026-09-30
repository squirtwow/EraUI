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
 if saved.backdrop then saved.backdrop:SetBackdropBorderColor(1,1,1,1)end
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
  backdrop:SetBackdropColor(.016,.016,.02,.9);backdrop:SetBackdropBorderColor(1,1,1,1)
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
 local colour=DebuffTypeColor and(DebuffTypeColor[dispel or "none"]or DebuffTypeColor.none)
 border:SetTexture("Interface\\Buttons\\UI-Debuff-Border")
 border:SetTexCoord(0,1,0,1)
 border:SetVertexColor(colour and colour.r or .8,colour and colour.g or 0,colour and colour.b or 0)
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
local rings=setmetatable({}, {__mode="k"})
local pending=false
-- {outside, inside, r, g, b, layer}: a dark edge outside the icon, drawn
-- under the icon and its timer text, then a grey line over the icon's own
-- bright rim, in Dark Mode's grey.
local TONES={{2,0,.05,.05,.06,"BACKGROUND",-8},{0,1,.30,.31,.34,"ARTWORK",1}}
-- Aura Shadows (on by default, needs Dark Aura Borders): a soft shadow past
-- the dark edge, three one-unit rings of black, each fainter than the last
-- (the ring technique of Forever Enhanced Cooldown Manager's icon shadow).
-- Five units in all, Edit Mode's smallest gap between icons, so it never
-- reaches a neighbouring icon. The rings sit on an EraUI frame one level
-- below the aura button, so every aura's icon, timer and debuff border draws
-- over every shadow: its own and its neighbours'.
local SHADOW={.45,.25,.1}
local EDGE=2 -- the dark edge's width outside the icon
local function DarkBorders()
 return(E:GetSetting("enabled")and E:GetSetting("darkMode")and E:GetSetting("darkAuraBorders"))and true or false
end
local function DarkShadows()
 return(DarkBorders()and E:GetSetting("darkAuraShadows"))and true or false
end
-- A protected button (not how Forever builds aura buttons) waits for combat to end.
local function Locked(button)
 if InCombatLockdown()and button.IsProtected and button:IsProtected()then pending=true;return true end
 return false
end
-- The shadow's own frame, sized by two icon corners and never mouse-enabled.
-- Top and bottom rings take the corners, so no spot is shaded twice.
local function Shadow(button,icon)
 local reach=EDGE+#SHADOW
 local holder=CreateFrame("Frame",nil,button)
 holder:SetPoint("TOPLEFT",icon,"TOPLEFT",-reach,reach)
 holder:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",reach,-reach)
 for step,alpha in ipairs(SHADOW)do
  local d=EDGE+step-1
  for _,edge in ipairs({{"TOPLEFT",-d-1,d+1,"TOPRIGHT",d+1,d},{"BOTTOMLEFT",-d-1,-d,"BOTTOMRIGHT",d+1,-d-1},
   {"TOPLEFT",-d-1,d,"BOTTOMLEFT",-d,-d},{"TOPRIGHT",d,d,"BOTTOMRIGHT",d+1,-d}})do
   local strip=holder:CreateTexture(nil,"BACKGROUND",nil,-8)
   strip:SetColorTexture(0,0,0,alpha)
   strip:SetPoint("TOPLEFT",icon,edge[1],edge[2],edge[3])
   strip:SetPoint("BOTTOMRIGHT",icon,edge[4],edge[5],edge[6])
  end
 end
 return holder
end
-- One level under the button, checked on every update in case it moved. The
-- level is checked as a plain number before any arithmetic.
local function Lower(button,holder)
 local level=Num(button:GetFrameLevel())
 level=level and math.max(0,level-1)
 if level and holder:GetFrameLevel()~=level then holder:SetFrameLevel(level)end
end
local function Ring(button,on,shade)
 if not button or button.isAuraAnchor or not button.Icon then return end
 local ring=rings[button]
 if not ring then
  if not on or Locked(button)then return end
  ring={};rings[button]=ring
  local icon=button.Icon
  for _,tone in ipairs(TONES)do
   local o,i=tone[1],tone[2]
   -- Top, bottom, left and right strips, each pinned by two icon corners.
   for _,edge in ipairs({{"TOPLEFT",-o,o,"TOPRIGHT",o,-i},{"BOTTOMLEFT",-o,i,"BOTTOMRIGHT",o,-o},
    {"TOPLEFT",-o,o,"BOTTOMLEFT",i,-o},{"TOPRIGHT",-i,o,"BOTTOMRIGHT",o,-o}})do
    local strip=button:CreateTexture(nil,tone[6],nil,tone[7])
    strip:SetColorTexture(tone[3],tone[4],tone[5],1)
    strip:SetPoint("TOPLEFT",icon,edge[1],edge[2],edge[3])
    strip:SetPoint("BOTTOMRIGHT",icon,edge[4],edge[5],edge[6])
    ring[#ring+1]=strip
   end
  end
 end
 if ring.on~=on then
  ring.on=on
  for _,strip in ipairs(ring)do strip:SetShown(on)end
 end
 if not(shade or ring.shadow)or Locked(button)then return end
 ring.shadow=ring.shadow or Shadow(button,button.Icon)
 if shade then Lower(button,ring.shadow)end
 if ring.shaded~=shade then ring.shaded=shade;ring.shadow:SetShown(shade)end
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
 local on,shade=DarkBorders(),DarkShadows()
 for _,button in ipairs(frame.auraFrames or{})do Ring(button,on,shade);StyleButton(button)end
end
function M:RefreshBorders()
 local on,shade=DarkBorders(),DarkShadows();pending=false
 local rows,consolidated=Rows()
 for index=1,4 do
  for _,button in ipairs(rows[index]and rows[index].auraFrames or{})do Ring(button,on,shade)end
 end
 Ring(consolidated,on,shade);Ring(DeadlyDebuffFrame and DeadlyDebuffFrame.Debuff,on,shade)
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
