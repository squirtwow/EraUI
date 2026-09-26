-- Actual cosmetic module and player-level hook; native content is deliberately
-- changed between hovers to check that the skin never replaces text or actions.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local all={}
local function Frame(parent)
 local f={parent=parent,shown=true,alpha=1,w=30,h=30,scripts={},hooks={},colour={1,1,1}}
 function f:Fire(event,...)
  if self.scripts[event]then self.scripts[event](self,...)end
  for _,fn in ipairs(self.hooks[event]or{})do fn(self,...)end
 end
 function f:SetScript(event,fn)self.scripts[event]=fn end
 function f:HookScript(event,fn)self.hooks[event]=self.hooks[event]or{};table.insert(self.hooks[event],fn)end
  function f:SetShown(v)self.shown=v end
  function f:IsShown()return self.shown end
 function f:Hide()self.shown=false;self:Fire("OnHide")end
 function f:Show()self.shown=true;self:Fire("OnShow")end
 function f:GetAlpha()return self.alpha end
 function f:SetAlpha(a)self.alpha=a end
 function f:SetBackdrop(data)self.backdrop=data end
 function f:SetBackdropColor(...)self.background={...}end
 function f:SetBackdropBorderColor(...)self.borderColour={...}end
 function f:SetAllPoints(target)self.target=target end
 function f:SetFrameLevel(level)self.level=level end
 function f:GetFrameLevel()return self.level or 10 end
 function f:GetOwner()return self.owner end
 function f:RegisterEvent()end
 function f:SetTexture(file)self.texture=file;self.atlas=nil end
 function f:SetAtlas(atlas)self.atlas=atlas;self.texture=nil end
 function f:SetTexCoord(...)self.coords={...}end
 function f:SetVertexColor(...)self.colour={...}end
 function f:SetTextColor(...)self.colour={...}end
 function f:GetTextColor()return table.unpack(self.colour)end
 function f:SetText(text)self.text=text end
 function f:ClearAllPoints()self.points={};self.anchors={}end
 function f:SetPoint(...)
  self.points={...};self.anchors=self.anchors or{};self.anchors[self.points[1]]=self.points
 end
 function f:SetSize(w,h)self.w,self.h=w,h end
 function f:GetWidth()self.dimensionReads=(self.dimensionReads or 0)+1;return self.w end
 function f:GetHeight()self.dimensionReads=(self.dimensionReads or 0)+1;return self.h end
 all[#all+1]=f;return f
end
CreateFrame=function(_,_,parent)return Frame(parent)end
local hooks=0
hooksecurefunc=function(t,key,fn)
 if type(t)=="string"then fn=key;key=t;t=_G end
 local old=t[key];hooks=hooks+1;t[key]=function(...)old(...);fn(...)end
end
SharedTooltip_SetBackdropStyle=function(tip)tip.NineSlice:SetAtlas("NativeBrown");tip.NineSlice:SetAlpha(1)end
local secret=setmetatable({}, {__add=function()error("arithmetic on a secret dimension")end})
issecretvalue=function(v)return v==secret end
DebuffTypeColor={Magic={r=.2,g=.6,b=1},Poison={r=0,g=.6,b=0},none={r=.8,g=0,b=0}}
local function Tooltip()
 local t=Frame();t.NineSlice=Frame(t)
 function t:SetUnitAuraByAuraInstanceID(unit,id)
  self:Fire("OnTooltipCleared");self.text="Aura "..id.." on "..unit
  SharedTooltip_SetBackdropStyle(self);self:Show()
 end
 function t:SetText(text)
  self:Fire("OnTooltipCleared");self.text=text
  SharedTooltip_SetBackdropStyle(self);self:Show()
 end
 return t
end
GameTooltip=Tooltip();BuffFrameTooltip=Tooltip()
local buff=Frame();buff.auraType="Buff";buff.Icon=Frame(buff);buff.DebuffBorder=Frame(buff)
local debuff=Frame();debuff.auraType="Debuff";debuff.Icon=Frame(debuff);debuff.DebuffBorder=Frame(debuff)
debuff.buttonInfo={debuffType="Magic"};debuff.Symbol={text="Magic symbol"};debuff.Duration={text="11s"}
local click=function()end;debuff.scripts.OnClick=click
BuffFrame={auraFrames={buff},UpdateAuraButtons=function()end}
DebuffFrame={auraFrames={debuff},UpdateAuraButtons=function(self)
 for _,b in ipairs(self.auraFrames)do b.DebuffBorder:SetAtlas("NativeTypeBorder")end
end}
local E={modules={},settings={enabled=true,unitFrames=true}}
function E:RegisterModule(name,m)self.modules[name]=m end
function E:GetSetting(key)return self.settings[key]end
assert(loadfile("Modules/AuraStyle.lua"))("EraUI",E)
E.modules.AuraStyle:Initialize()
equal(debuff.DebuffBorder.texture,"Interface\\Buttons\\UI-Debuff-Border","classic debuff texture")
equal(debuff.DebuffBorder.colour[3],1,"magic blue border retained")
equal(debuff.Symbol.text,"Magic symbol","native dispel symbol retained")
equal(debuff.Duration.text,"11s","native timer retained")
equal(debuff.scripts.OnClick,click,"native click script untouched")
debuff.buttonInfo.debuffType="Poison";DebuffFrame:UpdateAuraButtons()
equal(debuff.DebuffBorder.colour[2],.6,"pooled border recoloured for next debuff")
-- Match the reported native update: public Debuff kind, no public dispel type,
-- restricted aura data and restricted icon geometry. Test either/both axes.
debuff.buttonInfo={duration=secret,expirationTime=secret,auraInstanceID=secret}
for _,size in ipairs({{secret,30},{30,secret},{secret,secret}})do
 debuff.Icon.w,debuff.Icon.h=size[1],size[2]
 debuff.Icon.dimensionReads=0
 DebuffFrame:UpdateAuraButtons()
 equal(debuff.Icon.dimensionReads,0,"styling never reads restricted icon dimensions")
 equal(debuff.DebuffBorder.texture,"Interface\\Buttons\\UI-Debuff-Border","secret geometry retains Classic border")
end
local top=debuff.DebuffBorder.anchors.TOPLEFT
local bottom=debuff.DebuffBorder.anchors.BOTTOMRIGHT
equal(top and top[2],debuff.Icon,"top edge follows native icon")
equal(top and top[3],"TOPLEFT","top edge uses native top-left corner")
equal(top and top[4],-3,"left edge extends three pixels")
equal(top and top[5],3,"top edge extends three pixels")
equal(bottom and bottom[2],debuff.Icon,"bottom edge follows native icon")
equal(bottom and bottom[3],"BOTTOMRIGHT","bottom edge uses native bottom-right corner")
equal(bottom and bottom[4],3,"right edge extends three pixels")
equal(bottom and bottom[5],-3,"bottom edge extends three pixels")
equal(debuff.buttonInfo.duration,secret,"restricted duration remains untouched")
equal(debuff.scripts.OnClick,click,"restricted geometry retains native click handler")
debuff.Icon.w,debuff.Icon.h=40,24
DebuffFrame:UpdateAuraButtons()
equal(debuff.Icon.dimensionReads,0,"recycled resized icon also uses native anchoring")
debuff.buttonInfo.debuffType=secret;DebuffFrame:UpdateAuraButtons()
equal(debuff.DebuffBorder.atlas,"NativeTypeBorder","restricted debuff type keeps native border")
local function Backdrop(tip)
 for _,f in ipairs(all)do if f.parent==tip and f.backdrop then return f end end
end
local background=Backdrop(GameTooltip)
GameTooltip.owner=debuff;GameTooltip:SetUnitAuraByAuraInstanceID("player",1)
equal(GameTooltip.text,"Aura 1 on player","native tooltip text retained")
equal(GameTooltip.NineSlice.alpha,0,"modern tooltip border hidden for aura")
equal(background.shown,true,"classic hover backdrop shown")
equal(background.backdrop.edgeFile,"Interface\\AddOns\\EraUI\\Media\\TooltipBorder.tga","tooltip uses authored grey bevel and curved corners")
equal(background.backdrop.edgeSize,16,"bevel atlas has full corner regions instead of a flat two-pixel stroke")
equal(background.background[4],.9,"tooltip background is translucent Classic black")
equal(background.borderColour[1],background.borderColour[2],"tooltip border is neutral grey")
equal(background.borderColour[2],background.borderColour[3],"tooltip border has no brown tint")
GameTooltip.NineSlice:SetAlpha(1)
equal(GameTooltip.NineSlice.alpha,0,"direct native alpha repaint cannot expose gold border")
SharedTooltip_SetBackdropStyle(GameTooltip)
equal(GameTooltip.NineSlice.alpha,0,"native style refresh cannot restore brown aura border")
GameTooltip:Hide();equal(GameTooltip.NineSlice.alpha,1,"hide restores original native alpha")
GameTooltip.owner=buff;GameTooltip:SetUnitAuraByAuraInstanceID("player",2)
equal(background.shown,true,"own buff gets same classic tooltip")
GameTooltip.owner={};GameTooltip:SetText("Quest or item information")
equal(background.shown,false,"non-aura tooltip never inherits aura backdrop")
equal(GameTooltip.NineSlice.alpha,1,"non-aura tooltip native border restored")
equal(GameTooltip.text,"Quest or item information","non-aura content unchanged")
BuffFrameTooltip.owner=debuff;BuffFrameTooltip:SetUnitAuraByAuraInstanceID("player",3)
equal(Backdrop(BuffFrameTooltip).shown,true,"automatic buff tooltip also styled")
E.settings.enabled=false
GameTooltip.owner=buff;GameTooltip:SetUnitAuraByAuraInstanceID("player",4)
equal(background.shown,false,"master toggle respects native styling")
equal(GameTooltip.NineSlice.alpha,1,"master toggle restores native tooltip")
local before=hooks;E.modules.AuraStyle:Refresh();equal(hooks,before,"repeated discovery adds no duplicate hooks")
E.settings.enabled=true;E.settings.unitFrames=false;E.settings.tooltipSkin=true
for _,text in ipairs({"Map Pin","Quest details","Item information","Spell description","Unit name"})do
 GameTooltip.owner={};GameTooltip:SetText(text)
 equal(GameTooltip.text,text,"general tooltip content retained")
 equal(background.shown,true,"general tooltip works independently of unit frames")
 equal(GameTooltip.NineSlice.alpha,0,"general tooltip brown outline removed")
 SharedTooltip_SetBackdropStyle(GameTooltip)
 equal(GameTooltip.NineSlice.alpha,0,"general border survives native repaint")
end
ShoppingTooltip1=Tooltip();ItemRefTooltip=Tooltip();E.modules.AuraStyle:Refresh()
ShoppingTooltip1:SetText("Equipped comparison");ItemRefTooltip:SetText("Linked item")
equal(Backdrop(ShoppingTooltip1).shown,true,"comparison tooltip styled")
equal(Backdrop(ItemRefTooltip).shown,true,"linked item tooltip styled")
local late=Tooltip();late:SetText("Late loaded map tooltip")
equal(Backdrop(late).shown,true,"shared-style late tooltip discovered")
SharedTooltip_SetBackdropStyle(late,nil,true)
equal(Backdrop(late).shown,false,"embedded item details do not gain a nested border")
SharedTooltip_SetBackdropStyle(late,nil,false)
equal(Backdrop(late).shown,true,"standalone tooltip regains classic border")
GameTooltip:Hide();equal(GameTooltip.NineSlice.alpha,1,"general hide restores native alpha")
E.settings.tooltipSkin=false;GameTooltip:SetText("Native style")
equal(GameTooltip.NineSlice.alpha,1,"general toggle off restores native border")
equal(background.shown,false,"general toggle off hides classic backdrop")

-- Capture the real unit-frame colour helper through its registered module.
local modules={}
local ns={db={},RegisterModule=function(name,module)modules[name]=module end}
E.Classic=ns
PlayerLevelText=Frame()
PlayerFrame_UpdateLevel=function(level)PlayerLevelText:SetText(level);PlayerLevelText:SetVertexColor(1,1,1)end
assert(loadfile("Classic/UnitFrames.lua"))("EraUI",E)
local function Find(fn,wanted,seen)
 seen=seen or{};if seen[fn]then return end;seen[fn]=true
 for i=1,100 do
  local name,value=debug.getupvalue(fn,i);if not name then break end
  if name==wanted then return value end
  if type(value)=="function"then local found=Find(value,wanted,seen);if found then return found end end
 end
end
local keep=assert(Find(modules.unitFrames.apply,"KeepPlayerLevelColour"))
local install=assert(Find(modules.unitFrames.apply,"HookPlayerLevelColour"))
for i=1,100 do local name=debug.getupvalue(keep,i);if name=="active"then debug.setupvalue(keep,i,true);break end end
install();PlayerFrame_UpdateLevel(9)
equal(PlayerLevelText.text,9,"level-up retains native numeric level")
equal(PlayerLevelText.colour[2],.82,"level-up reasserts classic gold")
equal(PlayerLevelText.colour[3],0,"level-up no longer white")
PlayerFrame_UpdateLevel(10);equal(PlayerLevelText.text,10,"subsequent level update")
equal(PlayerLevelText.colour[2],.82,"gold persists on subsequent level-up")
before=hooks;install();equal(hooks,before,"player-level hook installed once")
ns.db.unitFramePlayer=false;PlayerFrame_UpdateLevel(11)
equal(PlayerLevelText.colour[2],1,"disabled player skin leaves native colour")
print("Aura/level styling checks passed: "..checks.." assertions.")
