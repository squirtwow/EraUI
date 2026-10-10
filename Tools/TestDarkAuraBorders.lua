-- Dark Aura Borders and Aura Shadows on the real AuraStyle module. The player's
-- aura buttons are proxies that log every key read and forbid key writes, so
-- the checks prove the rings never read aura data or geometry and never write
-- on Blizzard's buttons. Ring strips are placed from their icon anchors and
-- sampled. Shadow frames are strict mocks: any call beyond the few the shadow
-- needs (mouse, scripts, sizes) fails the run. The native icon allows one
-- call only, the rim trim's SetTexCoord; the grey line is checked against
-- the real Darkness slider maths (Core/Appearance.lua).
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
 function r:SetAlpha(a)self.calls=self.calls+1;self.alpha=a;self.alphaSets=(self.alphaSets or 0)+1 end
 return r
end
local function Texture(layer,sub)
 created=created+1
 local t={layer=layer,sub=sub or 0,points={},shown=true,sets=0}
 function t:SetColorTexture(r,g,b,a)self.colour={r,g,b,a};self.sets=self.sets+1 end
 function t:SetPoint(point,relative,relativePoint,x,y)self.points[point]={relative,relativePoint,x,y}end
 function t:SetShown(v)self.shown=v and true or false end
 return Strict(t,"ring strip")
end
-- A native aura button: only the addon's proxy is handed out. Blizzard makes
-- every button of a row on the same frame level (5 here).
local backOf={}
local function Button(kind,extra)
 local back={textures={},scripts={},holders={},level=5,coordSets=0,reads={}}
 -- The only call allowed on the icon: its texture coords, for the rim trim.
 back.icon=setmetatable({},{__index=function(_,key)
  if key=="SetTexCoord"then return function(_,...)back.coords={...};back.coordSets=back.coordSets+1 end end
  iconCalls=iconCalls+1;error("icon touched: "..tostring(key))
 end,__newindex=function()error("icon written")end})
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
 function back.GetFrameLevel()return back.level end
 local proxy=setmetatable({},{
  __index=function(_,key)reads[key]=(reads[key]or 0)+1;back.reads[key]=(back.reads[key]or 0)+1;return back[key]end,
  __newindex=function(_,key)error("wrote "..tostring(key).." on a Blizzard aura button")end,
 })
 backOf[proxy]=back
 return proxy,back
end
-- A shadow frame: EraUI's own child of an aura button. A new child starts one
-- level above its parent, as in the client.
local holderCount=0
local function Holder(kind,parent)
 local back=backOf[parent]
 assert(kind=="Frame"and back,"shadow frame is a plain Frame on an aura button")
 holderCount=holderCount+1
 local h={points={},textures={},shown=true,level=back.level+1,levelSets=0}
 function h:SetPoint(point,relative,relativePoint,x,y)self.points[point]={relative,relativePoint,x,y}end
 function h:CreateTexture(_,layer,_,sub)local t=Texture(layer,sub);self.textures[#self.textures+1]=t;return t end
 function h:GetFrameLevel()return self.level end
 function h:SetFrameLevel(v)self.level=v;self.levelSets=self.levelSets+1 end
 function h:SetShown(v)self.shown=v and true or false end
 back.holders[#back.holders+1]=h
 return Strict(h,"shadow frame")
end
-- A secret value: any arithmetic or comparison on it fails.
local SECRET=setmetatable({},{__sub=function()error("arithmetic on a secret frame level")end,
 __lt=function()error("compared a secret frame level")end,__le=function()error("compared a secret frame level")end})
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
CreateFrame=function(kind,_,parent)
 if parent~=nil then return Holder(kind,parent)end
 local f={}
 function f:RegisterEvent(e)self.events=self.events or{};self.events[e]=true end
 function f:SetScript(_,fn)self.handler=fn end
 function f:SetAllPoints()end;function f:SetBackdrop()end;function f:SetBackdropColor()end;function f:SetBackdropBorderColor()end
 function f:Hide()end
 events=f;return f
end
InCombatLockdown=function()return combat end
issecretvalue=function(v)return rawequal(v,SECRET)end
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
 reads[key]=(reads[key]or 0)+1;consolidatedBack.reads[key]=(consolidatedBack.reads[key]or 0)+1
 if key=="Tooltip"then return {Auras=popout}end
 return consolidatedBack[key]
end)
BuffFrame.ConsolidatedBuffs=consolidated
local deadly,deadlyBack=Button("DeadlyDebuff");DeadlyDebuffFrame={Debuff=deadly}

local E={modules={},Classic={},settings={enabled=true,unitFrames=false,tooltipSkin=false,darkMode=true}}
function E:RegisterModule(name,m)self.modules[name]=m end
function E:GetSetting(key)return self.settings[key]end
assert(loadfile("Core/Appearance.lua"))("EraUI",E)
assert(loadfile("Modules/AuraStyle.lua"))("EraUI",E)
local M,ns=E.modules.AuraStyle,E.Classic

local function AllBacks()
 local list={}
 for _,row in ipairs({BuffFrame,DebuffFrame,ExternalDefensivesFrame,popout})do
  for i,back in ipairs(row.backs)do if not back.isAuraAnchor then list[#list+1]=back end end
 end
 list[#list+1]=consolidatedBack;list[#list+1]=deadlyBack
 return list
end
-- Reads per button. The debuff row's buttons are also read by the Boosted
-- Rest check (each debuff's type and icon, and its native border); every
-- other button only by the ring, which reads no aura data at all.
local function ResetReads()
 reads={}
 for _,b in ipairs(AllBacks())do b.reads={}end
 anchorBack.reads={}
end
local function OnDebuffRow(b)
 for _,d in ipairs(DebuffFrame.backs)do if d==b then return true end end
 return false
end
local function RingReads()
 local all={}
 for _,b in ipairs(AllBacks())do
  if not OnDebuffRow(b)then for key,n in pairs(b.reads)do all[key]=(all[key]or 0)+n end end
 end
 return all
end
local function DebuffRowReads()
 local all={}
 for _,b in ipairs(DebuffFrame.backs)do for key,n in pairs(b.reads)do all[key]=(all[key]or 0)+n end end
 return all
end
local function Shown(back)
 if #back.textures==0 then return false end
 for _,t in ipairs(back.textures)do if not t.shown then return false end end
 return true
end
local function AllShown(want,label)
 for i,back in ipairs(AllBacks())do equal(Shown(back),want,label.." (button "..i..")")end
end
-- An icon's texture coords as last set ("" when never set), and how many
-- times any icon's coords have been set.
local TRIMMED,FULL="0.07,0.93,0.07,0.93","0,1,0,1"
local function Coords(b)return b.coords and table.concat(b.coords,",")or""end
local function Touched()
 local n=anchorBack.coordSets
 for _,b in ipairs(AllBacks())do n=n+b.coordSets end
 return n
end
-- The consolidated buffs icon is a crop of a sheet with the game's own
-- coords (ConsolidatedBuffsMixin:OnLoad), so it is never trimmed or reset.
local function AllCoords(want,label)
 for i,b in ipairs(AllBacks())do
  if b~=consolidatedBack then equal(Coords(b),want,label.." (button "..i..")")end
 end
 equal(consolidatedBack.coordSets,0,label..": consolidated buffs icon keeps the game's coords")
end

-- Option not on (the default is on; see TestPersistence): Dark Mode on, nothing made.
M:Initialize()
equal(created,0,"option not on: no textures made on any aura button")
equal(Touched(),0,"option not on: no icon trimmed")
equal(events.events.PLAYER_REGEN_ENABLED,true,"waits for combat to end when it has to")
local before=hooks

-- Needs Dark Mode (the loaded style) and EraUI itself.
E.settings.darkAuraBorders=true;E.settings.darkMode=false;M:RefreshBorders()
equal(created,0,"Dark Mode off: no borders even with the option on")
E.settings.darkMode=true;E.settings.enabled=false;M:RefreshBorders()
equal(created,0,"EraUI turned off: no borders")
equal(Touched(),0,"Dark Mode or EraUI off: no icon trimmed")
E.settings.enabled=true

-- Switched on in combat: aura buttons are not protected, so it applies at once.
ResetReads();combat=true;M:RefreshBorders();combat=false
AllShown(true,"on in combat: every player aura icon has a ring")
equal(#consolidatedBack.textures,8,"consolidated buffs button ringed")
equal(#deadlyBack.textures,8,"deadly debuff warning icon ringed")
equal(#popout.backs[1].textures,8,"consolidated popout icons ringed")
equal(#ExternalDefensivesFrame.backs[1].textures,8,"external defensives ringed")
equal(#enchantBack.textures,8,"weapon enchant ringed")
equal(#anchorBack.textures,0,"private aura anchor left alone (its icon is drawn by the game)")
equal(created,8*#AllBacks(),"eight strips per button, nothing else")
local ringReads=RingReads()
for key in pairs(ringReads)do
 equal(key=="Icon"or key=="isAuraAnchor"or key=="CreateTexture"or key=="IsProtected"or key=="Tooltip",true,"ring reads only its own anchors, never aura data: "..key)
end
equal(ringReads.auraType or ringReads.buttonInfo or ringReads.unit or ringReads.timeLeft or ringReads.Duration or ringReads.DebuffBorder,nil,"no aura type, data, timer or native border read")
-- The debuff row: the ring's anchors, plus the Boosted Rest check's type, info and border.
for key in pairs(DebuffRowReads())do
 equal(key=="Icon"or key=="isAuraAnchor"or key=="CreateTexture"or key=="IsProtected"or key=="auraType"or key=="buttonInfo"or key=="DebuffBorder",true,"debuff row reads only the ring's anchors and what the Boosted Rest check needs: "..key)
end
equal(reads.unit or reads.timeLeft or reads.Duration,nil,"no unit, timer or duration read anywhere")
equal(iconCalls,0,"icon geometry never read (anchors and the trim's texture coords only)")
AllCoords(TRIMMED,"on in combat: every ringed icon's bright rim trimmed (.07 a side)")
equal(anchorBack.coordSets,0,"private aura anchor's icon never trimmed")
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
equal(grey.colour[1]==.30 and grey.colour[2]==.31 and grey.colour[3]==.34 and grey.colour[4]==1,true,"at the default Darkness (58) the grey line is exactly .30, .31, .34 as before")
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
ResetReads();combat=true;BuffFrame:UpdateAuraButtons();combat=false
equal(#lateBack.textures,8,"a button acquired later gets its ring on the next native update")
equal(reads.auraType or reads.buttonInfo,nil,"and the buff row's update hook still reads no aura data")
local count=created
BuffFrame:UpdateAuraButtons();DebuffFrame:UpdateAuraButtons();M:Refresh()
equal(created,count,"updates and refreshes never make a second ring")

-- Live toggling: hidden, shown again, never recreated.
E.settings.darkAuraBorders=false;M:RefreshBorders()
AllShown(false,"switched off: rings hidden at once")
AllCoords(FULL,"switched off: every icon back to full texture coords")
local coordSets=Touched()
BuffFrame:UpdateAuraButtons()
equal(Shown(BuffFrame.backs[1]),false,"native updates keep them hidden while off")
M:RefreshBorders()
equal(Touched(),coordSets,"while off, native updates and refreshes leave the icons alone")
E.settings.darkAuraBorders=true;M:RefreshBorders()
AllShown(true,"switched on again: rings back")
AllCoords(TRIMMED,"switched on again: icons trimmed again")
equal(created,count,"toggling reuses the same strips")
-- The game may reset a reused button's coords: the next native update trims it again.
BuffFrame.backs[1].coords={0,1,0,1};BuffFrame:UpdateAuraButtons()
equal(Coords(BuffFrame.backs[1]),TRIMMED,"a native update re-applies the trim")

-- A protected button (not how Forever builds them) waits until combat ends.
local guarded,guardedBack=Button("Buff",{protected=true})
ExternalDefensivesFrame.auraFrames[2],ExternalDefensivesFrame.backs[2]=guarded,guardedBack
combat=true;ExternalDefensivesFrame:UpdateAuraButtons()
equal(#guardedBack.textures,0,"never adds to a protected button in combat")
equal(guardedBack.coordSets,0,"nor trims its icon in combat")
combat=false;events.handler(events,"PLAYER_REGEN_ENABLED")
equal(#guardedBack.textures,8,"ringed once combat ends")
equal(Coords(guardedBack),TRIMMED,"and trimmed once combat ends")

-- With the Classic unit frames on, the Classic debuff border still applies on top.
E.settings.unitFrames=true
local debuffBack=DebuffFrame.backs[1];debuffBack.DebuffBorder.calls=0
DebuffFrame:UpdateAuraButtons()
equal(debuffBack.DebuffBorder.calls>0,true,"Classic debuff border styling unchanged beside the ring")
equal(Shown(debuffBack),true,"debuff keeps its dark ring underneath")

-- Aura Shadows (needs Dark Aura Borders): three rings of black past the dark
-- edge, on an EraUI frame one level under each aura button.
local function Shaded(b)return b.holders[1]~=nil and b.holders[1].shown end
equal(holderCount,0,"shadow option not on: no shadow frame made")
count=created
ResetReads();combat=true;E.settings.darkAuraShadows=true;M:RefreshBorders();combat=false
equal(#guardedBack.holders,0,"protected button's shadow waits for combat to end")
events.handler(events,"PLAYER_REGEN_ENABLED")
for i,b in ipairs(AllBacks())do
 equal(#b.holders,1,"one shadow frame (button "..i..")")
 equal(#b.holders[1].textures,12,"three shadow rings of four strips (button "..i..")")
 equal(Shaded(b)and Shown(b),true,"shadow and border both showing (button "..i..")")
 equal(b.holders[1].level,b.level-1,"shadow frame one level under its button (button "..i..")")
 equal(#b.textures,8,"nothing new drawn on the button itself (button "..i..")")
end
equal(#anchorBack.holders,0,"private aura anchor still left alone")
equal(created,count+12*#AllBacks(),"only the shadow strips are new")
equal(holderCount,#AllBacks(),"one shadow frame per aura button, nothing else")
local shadowReads=RingReads()
for key in pairs(shadowReads)do
 equal(key=="Icon"or key=="isAuraAnchor"or key=="CreateTexture"or key=="IsProtected"or key=="Tooltip"or key=="GetFrameLevel",true,"shadow reads only its anchors and the frame level: "..key)
end
equal(shadowReads.auraType or shadowReads.buttonInfo or shadowReads.unit or shadowReads.timeLeft or shadowReads.Duration or shadowReads.DebuffBorder,nil,"shadow reads no aura type, data, timer or native border")
equal(iconCalls,0,"icon geometry never read for the shadow")
equal(hooks,before,"no new hooks for the shadow")
-- Geometry: every point d..d+1 units outside the icon is covered by exactly
-- one strip, of that ring's alpha; nothing inside the dark edge or past five.
local holder=back.holders[1]
local hp=holder.points
equal(hp.TOPLEFT and hp.BOTTOMRIGHT and hp.TOPLEFT[1]==back.icon and hp.BOTTOMRIGHT[1]==back.icon,true,"shadow frame sized by two icon corners")
equal(hp.TOPLEFT[3]..","..hp.TOPLEFT[4].." "..hp.BOTTOMRIGHT[3]..","..hp.BOTTOMRIGHT[4],"-5,5 5,-5","shadow frame spans five units past the icon")
local SH={}
for _,t in ipairs(holder.textures)do
 local tl,br=t.points.TOPLEFT,t.points.BOTTOMRIGHT
 equal(tl[1]==back.icon and br[1]==back.icon,true,"shadow strip pinned to the native icon")
 equal(t.colour[1]+t.colour[2]+t.colour[3],0,"shadow strip is black")
 SH[#SH+1]={ICON[tl[2]][1]+tl[3],ICON[br[2]][1]+br[3],ICON[br[2]][2]+br[4],ICON[tl[2]][2]+tl[4],t.colour[4],t.layer,t.sub}
end
local function Out(x,y)return math.max(-x,x-30,-y,y-30)end
local badCover,badAlpha,badLayer=0,0,0
for _,r in ipairs(SH)do if not(r[6]=="BACKGROUND"and r[7]==-8)then badLayer=badLayer+1 end end
local ALPHA={.45,.25,.1}
for x=-6.75,36.75,.5 do
 for y=-6.75,36.75,.5 do
  local hits,alpha=0
  for _,r in ipairs(SH)do if x>r[1]and x<r[2]and y>r[3]and y<r[4]then hits=hits+1;alpha=r[5]end end
  local d=Out(x,y)
  local want=(d>2 and d<5)and 1 or 0
  if hits~=want then badCover=badCover+1 end
  if want==1 and hits==1 and alpha~=ALPHA[math.floor(d-2)+1]then badAlpha=badAlpha+1 end
 end
end
equal(badCover,0,"shadow covers 2 to 5 units outside the icon exactly once: no double-dark corners, no gaps")
equal(badAlpha,0,"each ring fainter than the one inside it (45%, 25%, 10%)")
equal(badLayer,0,"shadow strips at BACKGROUND -8 of their frame")
-- Neighbours at Edit Mode's smallest gap (5): the shadow stops at their icon.
local reach=0
for _,r in ipairs(SH)do reach=math.max(reach,-r[1],r[2]-30,-r[3],r[4]-30)end
equal(reach,5,"shadow reaches five units, never onto a neighbouring icon")
-- Under every aura button: its own and its neighbours' icons, timers and
-- debuff borders (all on the buttons' shared level) draw over it.
for _,b in ipairs(AllBacks())do
 for _,other in ipairs({BuffFrame.backs[2],DebuffFrame.backs[1]})do
  equal(b.holders[1].level<other.level,true,"a shadow sits under every neighbouring aura button")
 end
end
-- The level is kept on every native update if the button's moves, and a
-- secret level is never used.
back.level=9;BuffFrame:UpdateAuraButtons()
equal(holder.level,8,"shadow follows its button's level on the next update")
local sets=holder.levelSets;BuffFrame:UpdateAuraButtons()
equal(holder.levelSets,sets,"an unchanged level is not set again")
back.level=SECRET;BuffFrame:UpdateAuraButtons()
equal(holder.level,8,"a secret frame level is left alone, no arithmetic on it")
back.level=5;BuffFrame:UpdateAuraButtons()
equal(holder.level,4,"back one under once the level is readable")
-- Toggling.
count=created
E.settings.darkAuraShadows=false;M:RefreshBorders()
equal(Shaded(back)or not Shown(back),false,"shadow off: shadow hidden, border kept")
AllShown(true,"shadow off: every border kept")
for i,b in ipairs(AllBacks())do equal(Shaded(b),false,"shadow off everywhere (button "..i..")")end
BuffFrame:UpdateAuraButtons()
equal(Shaded(back),false,"native updates keep the shadow hidden while off")
E.settings.darkAuraShadows=true;M:RefreshBorders()
equal(Shaded(back),true,"shadow on again")
E.settings.darkAuraBorders=false;M:RefreshBorders()
equal(Shaded(back)or Shown(back),false,"borders off: shadow goes with them")
BuffFrame:UpdateAuraButtons()
equal(Shaded(back),false,"native updates keep it hidden")
E.settings.darkAuraBorders=true;E.settings.darkMode=false;M:RefreshBorders()
equal(Shaded(back),false,"Dark Mode off: no shadow")
AllCoords(FULL,"Dark Mode off: icons back to full coords")
E.settings.darkMode=true;E.settings.enabled=false;M:RefreshBorders()
equal(Shaded(back),false,"EraUI turned off: no shadow")
AllCoords(FULL,"EraUI turned off: icons back to full coords")
E.settings.enabled=true;M:RefreshBorders()
equal(Shaded(back)and Shown(back),true,"back with Dark Mode and borders")
AllCoords(TRIMMED,"back with Dark Mode and borders: icons trimmed")
equal(created,count,"toggling never makes a second shadow")
equal(holderCount,#AllBacks(),"toggling never makes a second shadow frame")
-- A late button gets its shadow from the update hook, in combat.
local late2,late2Back=Button("Buff");BuffFrame.auraFrames[7],BuffFrame.backs[7]=late2,late2Back
combat=true;BuffFrame:UpdateAuraButtons();combat=false
equal(#late2Back.textures.." "..(late2Back.holders[1]and #late2Back.holders[1].textures or 0),"8 12","late button gets border and shadow")
equal(late2Back.holders[1].level,4,"late button's shadow under it too")
-- A protected button waits for combat to end for its shadow too.
local g2,g2Back=Button("Buff",{protected=true})
ExternalDefensivesFrame.auraFrames[3],ExternalDefensivesFrame.backs[3]=g2,g2Back
combat=true;ExternalDefensivesFrame:UpdateAuraButtons()
equal(#g2Back.textures+#g2Back.holders,0,"protected button: nothing in combat")
combat=false;events.handler(events,"PLAYER_REGEN_ENABLED")
equal(#g2Back.textures.." "..(g2Back.holders[1]and #g2Back.holders[1].textures or 0),"8 12","protected button shaded after combat")
-- Its shadow frame is left alone in combat too, then catches up.
combat=true;E.settings.darkAuraShadows=false;M:RefreshBorders()
equal(g2Back.holders[1].shown,true,"protected button's shadow frame untouched in combat")
equal(Shaded(back),false,"plain buttons switch at once in combat")
combat=false;events.handler(events,"PLAYER_REGEN_ENABLED")
equal(g2Back.holders[1].shown,false,"and it follows once combat ends")
E.settings.darkAuraShadows=true;M:RefreshBorders()
-- Its icon keeps the trim through combat too, then gets full coords back.
combat=true;E.settings.darkAuraBorders=false;M:RefreshBorders()
equal(Coords(g2Back),TRIMMED,"protected button's icon untouched in combat")
equal(Coords(back),FULL,"plain icons get full coords at once in combat")
combat=false;events.handler(events,"PLAYER_REGEN_ENABLED")
equal(Coords(g2Back),FULL,"and it gets full coords once combat ends")
E.settings.darkAuraBorders=true;M:RefreshBorders()
AllCoords(TRIMMED,"borders on again: every icon trimmed")

-- Darkness slider: the grey line follows it, through the real
-- RefreshDarkness, whether or not class colours darken too; the dark edge
-- stays. Every line strip of every ring is checked.
local function Sets()
 local n=0
 for _,b in ipairs(AllBacks())do for _,t in ipairs(b.textures)do n=n+t.sets end end
 return n
end
local function Tones(r,g,b,label)
 local bad=0
 for _,bk in ipairs(AllBacks())do
  for _,t in ipairs(bk.textures)do
   local c,w=t.colour,t.layer=="ARTWORK"and{r,g,b}or{.05,.05,.06}
   if not(c[1]==w[1]and c[2]==w[2]and c[3]==w[3]and c[4]==1)then bad=bad+1 end
  end
 end
 equal(bad,0,label)
end
local function Step(darkness)return math.min(1,(1-darkness/100)/.42)end
equal(E.settings.darkModeDarkness,nil,"slider at its default")
Tones(.30,.31,.34,"Darkness 58 (default): every line exactly .30, .31, .34, every dark edge .05, .05, .06")
local sets=Sets()
ns.RefreshDarkness();M:RefreshBorders();BuffFrame:UpdateAuraButtons();DebuffFrame:UpdateAuraButtons()
equal(Sets(),sets,"nothing changed: the slider, refreshes and native updates set no colour again")
E.settings.darkModeDarkness=58;ns.RefreshDarkness()
equal(Sets(),sets,"58 set explicitly: nothing set")
E.settings.darkModeDarkness=40;ns.RefreshDarkness()
equal(Sets(),sets,"lighter than 58: the line keeps today's grey, nothing set")
E.settings.darkModeDarkness=90;ns.RefreshDarkness()
local f=Step(90)
equal(f>.2 and f<.3,true,"at 90 the line is about a quarter of today's grey")
Tones(.30*f,.31*f,.34*f,"slider to 90: every existing ring's line darkened at once, dark edge unchanged")
equal(Sets()-sets,4*#AllBacks(),"one colour set per line strip, none on the dark edge")
sets=Sets();ns.RefreshDarkness();M:RefreshBorders();BuffFrame:UpdateAuraButtons()
equal(Sets(),sets,"held at 90: nothing set again")
-- A ring made now is dark straight away, each strip coloured once.
local late3,late3Back=Button("Buff");BuffFrame.auraFrames[8],BuffFrame.backs[8]=late3,late3Back
BuffFrame:UpdateAuraButtons()
local once=0
for _,t in ipairs(late3Back.textures)do if t.sets==1 then once=once+1 end end
equal(#late3Back.textures..":"..once,"8:8","a ring made at 90 has the dark line from the start, each strip coloured once")
Tones(.30*f,.31*f,.34*f,"new ring matches the others at 90")
-- Rings hidden while the slider moves take the shade when shown again; a
-- refresh alone also picks up a new Darkness.
E.settings.darkAuraBorders=false;M:RefreshBorders()
E.settings.darkModeDarkness=75;ns.RefreshDarkness()
E.settings.darkAuraBorders=true;M:RefreshBorders()
f=Step(75);Tones(.30*f,.31*f,.34*f,"hidden while the slider moved: shown again at 75's shade")
E.settings.darkModeDarkness=82;M:RefreshBorders()
f=Step(82);Tones(.30*f,.31*f,.34*f,"a refresh picks up a new Darkness")
-- Darken class colours on gives the same line.
E.settings.darkenClassColours=true;sets=Sets();ns.RefreshDarkness()
equal(Sets(),sets,"the class colour tick does not change the line")
E.settings.darkenClassColours=nil
-- Back at the default: exactly today's grey again.
E.settings.darkModeDarkness=58;ns.RefreshDarkness()
Tones(.30,.31,.34,"back at 58: exactly .30, .31, .34 again")
equal(iconCalls,0,"icon never read through all of it")

-- Boosted Rest: listed with your debuffs (so the game rings it red), known
-- by its Bonus XP icon (1001982). While the dark rings show, its red ring's
-- alpha goes to 0 so the dark border shows; any other debuff keeps its own.
local bonus,bonusBack=Button("Debuff")
bonusBack.buttonInfo={texture=1001982,duration=3600,expirationTime=4000,auraInstanceID=9}
DebuffFrame.auraFrames[4],DebuffFrame.backs[4]=bonus,bonusBack
local plainDebuff=DebuffFrame.backs[1]
plainDebuff.DebuffBorder.alpha=nil
DebuffFrame:UpdateAuraButtons()
equal(bonusBack.DebuffBorder.alpha,0,"Boosted Rest: its red ring hidden while the dark borders show")
equal(Shown(bonusBack),true,"and its dark ring shows")
equal(plainDebuff.DebuffBorder.alpha,nil,"a real debuff keeps its coloured border")
-- Off (the option, Dark Mode or EraUI): the red ring comes back, once.
E.settings.darkAuraBorders=false;M:RefreshBorders()
equal(bonusBack.DebuffBorder.alpha,1,"dark borders off: Boosted Rest's own ring back")
local alphaSets=bonusBack.DebuffBorder.alphaSets
M:RefreshBorders();DebuffFrame:UpdateAuraButtons()
equal(bonusBack.DebuffBorder.alphaSets,alphaSets,"while off its alpha is left alone")
E.settings.darkAuraBorders=true;M:RefreshBorders()
equal(bonusBack.DebuffBorder.alpha,0,"on again: hidden again (refresh)")
-- The game reuses the button for another debuff: its ring comes back.
bonusBack.buttonInfo={debuffType="Curse",texture=136139}
DebuffFrame:UpdateAuraButtons()
equal(bonusBack.DebuffBorder.alpha,1,"button reused for a real debuff: its border shows again")
-- A hidden (secret) icon leaves the border as the game set it.
bonusBack.buttonInfo={texture=SECRET};bonusBack.DebuffBorder.alpha=nil
DebuffFrame:UpdateAuraButtons()
equal(bonusBack.DebuffBorder.alpha,nil,"secret icon: border untouched")
-- Only the debuff row is looked at: a buff with that icon is never touched.
local buffBonus,buffBonusBack=Button("Buff")
buffBonusBack.buttonInfo={texture=1001982}
BuffFrame.auraFrames[9],BuffFrame.backs[9]=buffBonus,buffBonusBack
ResetReads();BuffFrame:UpdateAuraButtons()
equal(buffBonusBack.DebuffBorder.alphaSets,nil,"buff row: no border alpha set")
equal(buffBonusBack.reads.buttonInfo,nil,"buff row: no aura data read")
print("Dark aura border checks passed: "..checks.." assertions.")
