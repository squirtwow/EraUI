-- Dark Aura Borders on the real AuraStyle module. The player's aura buttons are
-- proxies that log every key read and forbid key writes, so the checks prove
-- the rings never read aura data or geometry and never write on Blizzard's
-- buttons. Ring strips are placed from their icon anchors and sampled.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local LAYERS={BACKGROUND=1,BORDER=2,ARTWORK=3,OVERLAY=4,HIGHLIGHT=5}
local created,combat=0,false
local reads,iconCalls={},0
local function Strict(t,label)
 return setmetatable(t,{__index=function(_,key)error(label.." has no "..tostring(key))end})
end
local function Region(layer,sub)
 local r={layer=layer,sub=sub or 0,calls=0}
 for _,m in ipairs({"SetTexture","SetAtlas","SetTexCoord","SetVertexColor","ClearAllPoints","SetPoint","Show","Hide","SetShown","SetText","SetAlpha"})do
  r[m]=function(self)self.calls=self.calls+1 end
 end
 return r
end
local function Texture(layer,sub)
 created=created+1
 local t={layer=layer,sub=sub or 0,points={},shown=true}
 function t:SetColorTexture(r,g,b,a)self.colour={r,g,b,a}end
 function t:SetPoint(point,relative,relativePoint,x,y)self.points[point]={relative,relativePoint,x,y}end
 function t:SetShown(v)self.shown=v and true or false end
 return Strict(t,"ring strip")
end
-- A native aura button: only the addon's proxy is handed out.
local function Button(kind,extra)
 local back={textures={},scripts={}}
 back.icon=setmetatable({},{__index=function()iconCalls=iconCalls+1;error("icon touched")end,__newindex=function()error("icon written")end})
 back.Icon=back.icon
 back.DebuffBorder=Region("OVERLAY");back.TempEnchantBorder=Region("OVERLAY")
 back.Symbol=Region("OVERLAY");back.Count=Region("OVERLAY");back.Duration=Region("BACKGROUND")
 back.auraType=kind;back.buttonInfo={debuffType="Magic",duration=30,expirationTime=40,auraInstanceID=7}
 back.unit="player";back.timeLeft=12
 back.scripts.OnClick=function()end
 for key,value in pairs(extra or{})do back[key]=value end
 function back.CreateTexture(_,name,layer,template,sub)
  local t=Texture(layer,sub);back.textures[#back.textures+1]=t;return t
 end
 function back.IsProtected()return back.protected==true end
 local proxy=setmetatable({},{
  __index=function(_,key)reads[key]=(reads[key]or 0)+1;return back[key]end,
  __newindex=function(_,key)error("wrote "..tostring(key).." on a Blizzard aura button")end,
 })
 return proxy,back
end
local function Row(count,kind)
 local row={auraFrames={},backs={}}
 for i=1,count do row.auraFrames[i],row.backs[i]=Button(kind)end
 row.UpdateAuraButtons=function()end
 return row
end
local hooks=0
hooksecurefunc=function(t,key,fn)
 if type(t)=="string"then fn=key;key=t;t=_G end
 local old=t[key];hooks=hooks+1;t[key]=function(...)old(...);fn(...)end
end
local events
CreateFrame=function()
 local f={}
 function f:RegisterEvent(e)self.events=self.events or{};self.events[e]=true end
 function f:SetScript(_,fn)self.handler=fn end
 function f:SetAllPoints()end;function f:SetBackdrop()end;function f:SetBackdropColor()end;function f:SetBackdropBorderColor()end
 function f:Hide()end
 events=f;return f
end
InCombatLockdown=function()return combat end
issecretvalue=function()return false end
-- Target and focus auras are secure, forbidden frames: any touch fails.
local forbidden=setmetatable({},{__index=function()error("touched a forbidden target/focus aura frame")end})
TargetFrame,FocusFrame=forbidden,forbidden

BuffFrame=Row(4,"Buff");DebuffFrame=Row(2,"Debuff");ExternalDefensivesFrame=Row(1,"Buff")
local anchor,anchorBack=Button(nil,{isAuraAnchor=true})
DebuffFrame.auraFrames[3],DebuffFrame.backs[3]=anchor,anchorBack
local enchant,enchantBack=Button("TempEnchant");BuffFrame.auraFrames[5],BuffFrame.backs[5]=enchant,enchantBack
local consolidated,consolidatedBack=Button("Buff")
local popout=Row(3,"Buff")
rawset(getmetatable(consolidated),"__index",function(_,key)
 reads[key]=(reads[key]or 0)+1
 if key=="Tooltip"then return {Auras=popout}end
 return consolidatedBack[key]
end)
BuffFrame.ConsolidatedBuffs=consolidated
local deadly,deadlyBack=Button("DeadlyDebuff");DeadlyDebuffFrame={Debuff=deadly}

local E={modules={},settings={enabled=true,unitFrames=false,tooltipSkin=false,darkMode=true}}
function E:RegisterModule(name,m)self.modules[name]=m end
function E:GetSetting(key)return self.settings[key]end
assert(loadfile("Modules/AuraStyle.lua"))("EraUI",E)
local M=E.modules.AuraStyle

local function AllBacks()
 local list={}
 for _,row in ipairs({BuffFrame,DebuffFrame,ExternalDefensivesFrame,popout})do
  for i,back in ipairs(row.backs)do if not back.isAuraAnchor then list[#list+1]=back end end
 end
 list[#list+1]=consolidatedBack;list[#list+1]=deadlyBack
 return list
end
local function Shown(back)
 if #back.textures==0 then return false end
 for _,t in ipairs(back.textures)do if not t.shown then return false end end
 return true
end
local function AllShown(want,label)
 for i,back in ipairs(AllBacks())do equal(Shown(back),want,label.." (button "..i..")")end
end

-- Option not on (the default is on; see TestPersistence): Dark Mode on, nothing made.
M:Initialize()
equal(created,0,"option not on: no textures made on any aura button")
equal(events.events.PLAYER_REGEN_ENABLED,true,"waits for combat to end when it has to")
local before=hooks

-- Needs Dark Mode (the loaded style) and EraUI itself.
E.settings.darkAuraBorders=true;E.settings.darkMode=false;M:RefreshBorders()
equal(created,0,"Dark Mode off: no borders even with the option on")
E.settings.darkMode=true;E.settings.enabled=false;M:RefreshBorders()
equal(created,0,"EraUI turned off: no borders")
E.settings.enabled=true

-- Switched on in combat: aura buttons are not protected, so it applies at once.
reads={};combat=true;M:RefreshBorders();combat=false
AllShown(true,"on in combat: every player aura icon has a ring")
equal(#consolidatedBack.textures,8,"consolidated buffs button ringed")
equal(#deadlyBack.textures,8,"deadly debuff warning icon ringed")
equal(#popout.backs[1].textures,8,"consolidated popout icons ringed")
equal(#ExternalDefensivesFrame.backs[1].textures,8,"external defensives ringed")
equal(#enchantBack.textures,8,"weapon enchant ringed")
equal(#anchorBack.textures,0,"private aura anchor left alone (its icon is drawn by the game)")
equal(created,8*#AllBacks(),"eight strips per button, nothing else")
for key in pairs(reads)do
 equal(key=="Icon"or key=="isAuraAnchor"or key=="CreateTexture"or key=="IsProtected"or key=="Tooltip",true,"ring reads only its own anchors, never aura data: "..key)
end
equal(reads.auraType or reads.buttonInfo or reads.unit or reads.timeLeft or reads.Duration or reads.DebuffBorder,nil,"no aura type, data, timer or native border read")
equal(iconCalls,0,"icon geometry never read or changed (anchors only)")
equal(hooks,before,"no new hooks for the borders")

-- Geometry: anchors to the icon only; sample the drawn strips.
local ICON={TOPLEFT={0,30},TOPRIGHT={30,30},BOTTOMLEFT={0,0},BOTTOMRIGHT={30,0}}
local back=BuffFrame.backs[1]
local tones={}
for _,t in ipairs(back.textures)do
 local tl,br=t.points.TOPLEFT,t.points.BOTTOMRIGHT
 equal(tl[1]==back.icon and br[1]==back.icon,true,"strip pinned to the native icon")
 local left,top=ICON[tl[2]][1]+tl[3],ICON[tl[2]][2]+tl[4]
 local right,bottom=ICON[br[2]][1]+br[3],ICON[br[2]][2]+br[4]
 equal(left<right and bottom<top,true,"strip has a positive size")
 local key=table.concat(t.colour,",")
 tones[key]=tones[key]or{layer=t.layer,sub=t.sub,colour=t.colour,rects={}}
 table.insert(tones[key].rects,{left,right,bottom,top})
end
local dark,grey
for _,tone in pairs(tones)do if tone.colour[1]<.1 then dark=tone else grey=tone end end
equal(dark~=nil and grey~=nil,true,"two tones: a dark edge and a grey line")
local function Covered(tone,x,y)
 for _,r in ipairs(tone.rects)do if x>r[1]and x<r[2]and y>r[3]and y<r[4]then return true end end
 return false
end
local function Inside(x,y,lo,hi)return x>lo and x<hi and y>lo and y<hi end
local wrong=0
for x=-3.75,33.75,.5 do
 for y=-3.75,33.75,.5 do
  if Covered(dark,x,y)~=(Inside(x,y,-2,32)and not Inside(x,y,0,30))then wrong=wrong+1 end
  if Covered(grey,x,y)~=(Inside(x,y,0,30)and not Inside(x,y,1,29))then wrong=wrong+1 end
 end
end
equal(wrong,0,"dark edge fills exactly two units outside the icon, grey line one unit inside")
equal(dark.colour[1]==dark.colour[2]and dark.colour[4],1,"dark edge is a solid neutral dark")
equal(grey.colour[1]<.42 and grey.colour[3]>=grey.colour[1],true,"grey line is in Dark Mode's cool grey family, darker than the art tint")
equal(LAYERS[dark.layer]==LAYERS.BACKGROUND and dark.sub<0,true,"dark edge under the icon and its timer text")
equal(LAYERS[grey.layer]<LAYERS.OVERLAY and LAYERS[grey.layer]>LAYERS.BACKGROUND,true,"grey line over the icon rim, under the native overlays")
equal(LAYERS[BuffFrame.backs[1].DebuffBorder.layer]>LAYERS[grey.layer],true,"native debuff/enchant borders, symbol and count stay on top")

-- Nothing native changed.
for _,b in ipairs(AllBacks())do
 for _,key in ipairs({"DebuffBorder","TempEnchantBorder","Symbol","Count","Duration"})do
  equal(b[key].calls,0,"native "..key.." untouched")
 end
end
equal(type(BuffFrame.backs[1].scripts.OnClick),"function","right-click cancelling handler untouched")

-- Buttons acquired later are ringed by the existing update hook, in combat.
local late,lateBack=Button("Buff");BuffFrame.auraFrames[6],BuffFrame.backs[6]=late,lateBack
reads={};combat=true;BuffFrame:UpdateAuraButtons();combat=false
equal(#lateBack.textures,8,"a button acquired later gets its ring on the next native update")
equal(reads.auraType or reads.buttonInfo,nil,"and the update hook still reads no aura data")
local count=created
BuffFrame:UpdateAuraButtons();DebuffFrame:UpdateAuraButtons();M:Refresh()
equal(created,count,"updates and refreshes never make a second ring")

-- Live toggling: hidden, shown again, never recreated.
E.settings.darkAuraBorders=false;M:RefreshBorders()
AllShown(false,"switched off: rings hidden at once")
BuffFrame:UpdateAuraButtons()
equal(Shown(BuffFrame.backs[1]),false,"native updates keep them hidden while off")
E.settings.darkAuraBorders=true;M:RefreshBorders()
AllShown(true,"switched on again: rings back")
equal(created,count,"toggling reuses the same strips")

-- A protected button (not how Forever builds them) waits until combat ends.
local guarded,guardedBack=Button("Buff",{protected=true})
ExternalDefensivesFrame.auraFrames[2],ExternalDefensivesFrame.backs[2]=guarded,guardedBack
combat=true;ExternalDefensivesFrame:UpdateAuraButtons()
equal(#guardedBack.textures,0,"never adds to a protected button in combat")
combat=false;events.handler(events,"PLAYER_REGEN_ENABLED")
equal(#guardedBack.textures,8,"ringed once combat ends")

-- With the Classic unit frames on, the Classic debuff border still applies on top.
E.settings.unitFrames=true
local debuffBack=DebuffFrame.backs[1];debuffBack.DebuffBorder.calls=0
DebuffFrame:UpdateAuraButtons()
equal(debuffBack.DebuffBorder.calls>0,true,"Classic debuff border styling unchanged beside the ring")
equal(Shown(debuffBack),true,"debuff keeps its dark ring underneath")
print("Dark aura border checks passed: "..checks.." assertions.")
