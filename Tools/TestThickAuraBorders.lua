-- Thick Aura Borders on the real AuraStyle module (with the real Darkness
-- maths of Core/Appearance.lua). The player's aura buttons are proxies that
-- log every key read and forbid key writes; the native icon allows only the
-- rim trim's SetTexCoord; target and focus auras are forbidden frames. Ring
-- strips are placed from their icon anchors and sampled. Covered: off is
-- today's look exactly (Classic and Dark Mode, before and after a round
-- trip); on in Classic (bronze line) and Dark Mode (the Darkness grey, live
-- with the slider); the edge's size against Forever's icon size and Edit
-- Mode's smallest gap; debuff type colours (no tick needed), remembered
-- through a fight, the game's border kept when the type can't be told, and
-- Boosted Rest dark; Aura Shadows' softer two-step shadow; precedence over
-- Dark Aura Borders and Thin Debuff Colours; live switching both ways;
-- protected buttons waiting for combat to end; no keys, hooks or tooltips.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local LAYERS={BACKGROUND=1,BORDER=2,ARTWORK=3,OVERLAY=4,HIGHLIGHT=5}
local created,combat=0,false
local reads,iconCalls={},0
local E -- the addon table, set below
local function Strict(t,label)
 return setmetatable(t,{__index=function(_,key)error(label.." has no "..tostring(key))end})
end
local function Region(layer)
 local r={layer=layer,calls=0}
 for _,m in ipairs({"SetTexture","SetAtlas","SetTexCoord","SetVertexColor","ClearAllPoints","SetPoint","Show","Hide","SetShown","SetText"})do
  r[m]=function(self)self.calls=self.calls+1 end
 end
 function r:SetAlpha(a)self.calls=self.calls+1;self.alpha=a;self.alphaSets=(self.alphaSets or 0)+1 end
 function r:GetAlpha()if self.alpha==nil then return 1 end;return self.alpha end
 return r
end
-- A strip remembers which ring made it: the thick ring is only ever made
-- while Thick Aura Borders is on, Dark Aura Borders' only while it is off.
local function Texture(layer,sub)
 created=created+1
 local kind=(E.settings.enabled and E.settings.thickAuraBorders)and"thick"or"dab"
 local t={layer=layer,sub=sub or 0,points={},shown=true,sets=0,pins=0,clears=0,shows=0,kind=kind}
 function t:SetColorTexture(r,g,b,a)self.colour={r,g,b,a};self.sets=self.sets+1 end
 function t:SetPoint(point,relative,relativePoint,x,y)self.points[point]={relative,relativePoint,x,y};self.pins=self.pins+1 end
 function t:ClearAllPoints()self.points={};self.clears=self.clears+1 end
 function t:SetShown(v)self.shown=v and true or false;self.shows=self.shows+1 end
 return Strict(t,"ring strip")
end
local backOf={}
local function Button(kind,extra)
 local back={textures={},holders={},level=5,coordSets=0,reads={}}
 back.icon=setmetatable({},{__index=function(_,key)
  if key=="SetTexCoord"then return function(_,...)back.coords={...};back.coordSets=back.coordSets+1 end end
  iconCalls=iconCalls+1;error("icon touched: "..tostring(key))
 end,__newindex=function()error("icon written")end})
 back.Icon=back.icon
 back.DebuffBorder=Region("OVERLAY");back.TempEnchantBorder=Region("OVERLAY")
 back.Symbol=Region("OVERLAY");back.Count=Region("OVERLAY");back.Duration=Region("BACKGROUND")
 back.auraType=kind;back.buttonInfo={debuffType="Magic",auraInstanceID=7,texture=135894}
 back.unit="player";back.timeLeft=12
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
local holderCount=0
local function Holder(kind,parent)
 local back=backOf[parent]
 assert(kind=="Frame"and back,"shadow frame is a plain Frame on an aura button")
 holderCount=holderCount+1
 local h={points={},textures={},shown=true,level=back.level+1}
 function h:SetPoint(point,relative,relativePoint,x,y)self.points[point]={relative,relativePoint,x,y}end
 function h:CreateTexture(_,layer,_,sub)local t=Texture(layer,sub);t.kind="shadow";self.textures[#self.textures+1]=t;return t end
 function h:GetFrameLevel()return self.level end
 function h:SetFrameLevel(v)self.level=v end
 function h:SetShown(v)self.shown=v and true or false end
 back.holders[#back.holders+1]=h
 return Strict(h,"shadow frame")
end
local SECRET=setmetatable({},{__sub=function()error("arithmetic on a secret")end,
 __lt=function()error("compared a secret")end,__le=function()error("compared a secret")end})
local function Row(count,kind)
 local row={auraFrames={},backs={}}
 for i=1,count do row.auraFrames[i],row.backs[i]=Button(kind)end
 row.UpdateAuraButtons=function()end
 return row
end
local hooks=0
hooksecurefunc=function(t,key,fn)
 if type(t)=="string"then fn=key;key=t;t=_G end
 local target=backOf[t]or t
 local old=target[key];hooks=hooks+1;target[key]=function(...)old(...);fn(...)end
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
local forbidden=setmetatable({},{__index=function()error("touched a forbidden target/focus aura frame")end,
 __newindex=function()error("wrote on a forbidden target/focus aura frame")end})
TargetFrame,FocusFrame=forbidden,forbidden
-- The game's debuff colours (Forever has no DebuffTypeColor).
local TYPE={Magic={.2,.6,1},Curse={.6,0,1},Disease={.6,.4,0},Poison={0,.6,0},none={.8,0,0}}
AuraUtil={GetAuraBorderColor=function(dispel)
 assert(not rawequal(dispel,SECRET),"a secret type handed to the game's colour lookup")
 local c=TYPE[dispel or"none"]or TYPE.none
 return{r=c[1],g=c[2],b=c[3]}
end}

BuffFrame=Row(3,"Buff");DebuffFrame=Row(3,"Debuff");ExternalDefensivesFrame=Row(1,"Buff")
local anchor,anchorBack=Button(nil,{isAuraAnchor=true})
DebuffFrame.auraFrames[4],DebuffFrame.backs[4]=anchor,anchorBack
local enchant,enchantBack=Button("TempEnchant");BuffFrame.auraFrames[4],BuffFrame.backs[4]=enchant,enchantBack
local consolidated,consolidatedBack=Button("Buff")
local popout=Row(2,"Buff")
rawset(getmetatable(consolidated),"__index",function(_,key)
 reads[key]=(reads[key]or 0)+1;consolidatedBack.reads[key]=(consolidatedBack.reads[key]or 0)+1
 if key=="Tooltip"then return {Auras=popout}end
 return consolidatedBack[key]
end)
BuffFrame.ConsolidatedBuffs=consolidated
local deadly,deadlyBack=Button("DeadlyDebuff");DeadlyDebuffFrame={Debuff=deadly}
-- The debuff row: a magic debuff, one with no type (the game's "none"), and
-- Boosted Rest (the Bonus XP icon).
local d1,d2,rest=DebuffFrame.backs[1],DebuffFrame.backs[2],DebuffFrame.backs[3]
d1.buttonInfo={debuffType="Magic",texture=135894,auraInstanceID=101}
d2.buttonInfo={texture=136000,auraInstanceID=102}
rest.buttonInfo={texture=1001982,auraInstanceID=103}
-- The game updates one debuff button on its own too.
for _,b in ipairs({d1,d2,rest})do function b.Update(_,info)b.buttonInfo=info end end

E={modules={},Classic={},settings={enabled=true,unitFrames=false,tooltipSkin=false,darkMode=false,
 darkAuraBorders=true,darkAuraShadows=true}}
function E:RegisterModule(name,m)self.modules[name]=m end
function E:GetSetting(key)return self.settings[key]end
assert(loadfile("Core/Appearance.lua"))("EraUI",E)
assert(loadfile("Modules/AuraStyle.lua"))("EraUI",E)
local M,ns=E.modules.AuraStyle,E.Classic

local function AllBacks()
 local list={}
 for _,row in ipairs({BuffFrame,DebuffFrame,ExternalDefensivesFrame,popout})do
  for _,back in ipairs(row.backs)do if not back.isAuraAnchor then list[#list+1]=back end end
 end
 list[#list+1]=consolidatedBack;list[#list+1]=deadlyBack
 return list
end
local function OnDebuffRow(b)
 for _,d in ipairs(DebuffFrame.backs)do if d==b then return true end end
 return false
end
local function ResetReads()
 reads={}
 for _,b in ipairs(AllBacks())do b.reads={}end
end
local function Strips(b,kind,layer,sub)
 local out={}
 for _,t in ipairs(b.textures)do
  if t.kind==kind and(layer==nil or t.layer==layer)and(sub==nil or t.sub==sub)then out[#out+1]=t end
 end
 return out
end
local function Shown(list)
 if #list==0 then return false end
 for _,t in ipairs(list)do if not t.shown then return false end end
 return true
end
local function Hidden(list)
 for _,t in ipairs(list)do if t.shown then return false end end
 return true
end
local function Count(field)
 local n=0
 for _,b in ipairs(AllBacks())do
  for _,t in ipairs(b.textures)do n=n+t[field]end
  for _,h in ipairs(b.holders)do for _,t in ipairs(h.textures)do n=n+t[field]end end
 end
 return n
end
local function AlphaSets()
 local n=0
 for _,b in ipairs(AllBacks())do n=n+(b.DebuffBorder.alphaSets or 0)end
 return n
end
-- Everything a player sees of a button, as text: the strips showing (layer,
-- colour, place), the shadow showing, the icon's coords and the native
-- debuff border's alpha.
local ICON={TOPLEFT={0,30},TOPRIGHT={30,30},BOTTOMLEFT={0,0},BOTTOMRIGHT={30,0}}
local function Rect(t)
 local tl,br=t.points.TOPLEFT,t.points.BOTTOMRIGHT
 return ICON[tl[2]][1]+tl[3],ICON[br[2]][1]+br[3],ICON[br[2]][2]+br[4],ICON[tl[2]][2]+tl[4]
end
local function Fmt(t)
 local l,r,b,tp=Rect(t)
 return string.format("%s%d %.3f,%.3f,%.3f,%.2f %g,%g,%g,%g",t.layer,t.sub,t.colour[1],t.colour[2],t.colour[3],t.colour[4],l,r,b,tp)
end
local function Look(b)
 local parts={}
 for _,t in ipairs(b.textures)do if t.shown then parts[#parts+1]=Fmt(t)end end
 for _,h in ipairs(b.holders)do
  if h.shown then for _,t in ipairs(h.textures)do if t.shown then parts[#parts+1]="shadow "..Fmt(t)end end end
 end
 table.sort(parts)
 parts[#parts+1]="coords "..(b.coords and table.concat(b.coords,",")or"0,1,0,1")
 parts[#parts+1]="border "..tostring(b.DebuffBorder:GetAlpha())
 return table.concat(parts,"|")
end
-- Kept per button, so buttons added later don't shift the comparison.
local function Snapshot()
 local s,n={},0
 for _,b in ipairs(AllBacks())do s[b]=Look(b);n=n+1 end
 return s,n
end
local function SameLook(before,label)
 local n=0
 for i,b in ipairs(AllBacks())do
  if before[b]then n=n+1;equal(Look(b),before[b],label.." (button "..i..")")end
 end
 equal(n>=12,true,label..": every button compared")
end
-- Sampling a group of strips: whether (x, y) is covered.
local function Covers(list,x,y)
 for _,t in ipairs(list)do
  local l,r,b,tp=Rect(t)
  if x>l and x<r and y>b and y<tp then return true end
 end
 return false
end
local function Inside(x,y,lo,hi)return x>lo and x<hi and y>lo and y<hi end
-- A band from `out` units outside the icon to `inn` units in, sampled.
local function Band(list,out,inn,label)
 local wrong=0
 for x=-6.75,36.75,.5 do
  for y=-6.75,36.75,.5 do
   if Covers(list,x,y)~=(Inside(x,y,-out,30+out)and not Inside(x,y,inn,30-inn))then wrong=wrong+1 end
  end
 end
 equal(wrong,0,label)
end
local function Colour(list,r,g,b)
 if #list==0 then return false end
 for _,t in ipairs(list)do
  local c=t.colour
  if not(c and math.abs(c[1]-r)<1e-9 and math.abs(c[2]-g)<1e-9 and math.abs(c[3]-b)<1e-9 and c[4]==1)then return false end
 end
 return true
end
local function Line(b)return Strips(b,"thick","ARTWORK",2)end
local function Outer(b)return Strips(b,"thick","BACKGROUND")end
local function Inner(b)return Strips(b,"thick","ARTWORK",1)end
local BRONZE={.55,.46,.27}
local function Step(darkness)return math.min(1,(1-darkness/100)/.42)end
local function Grey(darkness)local s=Step(darkness or 58);return .30*s,.31*s,.34*s end

-- 1. Off (the default): today's look exactly. -------------------------------
-- Classic: nothing at all.
M:Initialize()
local before=hooks
GameTooltip=setmetatable({},{__index=function()error("GameTooltip touched")end,__newindex=function()error("GameTooltip written")end})
equal(created,0,"off in Classic: no textures made on any aura button")
for _,b in ipairs(AllBacks())do equal(b.coordSets+(b.DebuffBorder.alphaSets or 0),0,"off in Classic: no icon trimmed, no border touched")end
local classicOff=Snapshot()
-- Dark Mode with Dark Aura Borders and Aura Shadows (both on by default): their look, nothing of ours.
E.settings.darkMode=true;M:RefreshBorders()
for i,b in ipairs(AllBacks())do
 equal(#Strips(b,"dab").." "..#Strips(b,"thick").." "..(b.holders[1]and #b.holders[1].textures or 0),"8 0 12","off in Dark Mode: Dark Aura Borders' ring and shadow only (button "..i..")")
end
local darkOff=Snapshot()
E.settings.darkMode=false;M:RefreshBorders()
SameLook(classicOff,"off, back in Classic: nothing shows")

-- 2. On in Classic. ----------------------------------------------------------
ResetReads();combat=true;E.settings.thickAuraBorders=true;M:RefreshBorders();combat=false
for i,b in ipairs(AllBacks())do
 equal(#Strips(b,"thick").." "..tostring(Shown(Strips(b,"thick"))),"12 true","on in combat (not protected): a thick ring at once (button "..i..")")
 equal(Hidden(Strips(b,"dab")),true,"Dark Aura Borders' ring stays hidden in Classic (button "..i..")")
 equal(b.holders[1]==nil or not b.holders[1].shown,true,"no shadow in Classic (Aura Shadows needs Dark Mode) (button "..i..")")
end
equal(#anchorBack.textures,0,"private aura anchor left alone")
for i,b in ipairs(AllBacks())do
 if b~=consolidatedBack then equal(table.concat(b.coords,","),"0.07,0.93,0.07,0.93","icon trimmed of its bright rim (button "..i..")")end
end
equal(consolidatedBack.coordSets,0,"consolidated buffs icon keeps the game's coords")
equal(anchorBack.coordSets,0,"private aura anchor's icon never trimmed")
local back=BuffFrame.backs[1]
for _,t in ipairs(Strips(back,"thick"))do
 equal(t.points.TOPLEFT[1]==back.icon and t.points.BOTTOMRIGHT[1]==back.icon,true,"strip pinned by two corners of its own icon")
end
-- Geometry, sampled: 2 units outside (under the timer), 2 inside (over the
-- icon), then a 1-unit line 2 to 3 units in.
Band(Outer(back),2,0,"outer edge: exactly 2 units outside the icon")
Band(Inner(back),0,2,"inner edge: exactly 2 units over the icon's rim")
Band(Line(back),-2,3,"line: one unit, 2 to 3 units in")
equal(Colour(Outer(back),.05,.05,.06)and Colour(Inner(back),.05,.05,.06),true,"the edge is near black")
equal(Colour(Line(back),BRONZE[1],BRONZE[2],BRONZE[3]),true,"in Classic the line is a muted bronze")
equal(BRONZE[1]>BRONZE[2]and BRONZE[2]>BRONZE[3]and BRONZE[1]<.6,true,"bronze: warm and muted, not gold")
equal(Outer(back)[1].layer.." "..Outer(back)[1].sub,"BACKGROUND -8","the part outside sits under the icon and its timer text")
equal(LAYERS[Inner(back)[1].layer]>LAYERS.BACKGROUND and LAYERS[Line(back)[1].layer]<LAYERS.OVERLAY and Line(back)[1].sub>Inner(back)[1].sub,true,
 "the part inside over the icon, the line over it, both under the game's overlays (count, symbol, enchant and debuff borders)")
-- Reads: the ring reads only its anchors; the debuff row also the type,
-- icon and border.
for i,b in ipairs(AllBacks())do
 for key in pairs(b.reads)do
  local ok=key=="Icon"or key=="isAuraAnchor"or key=="CreateTexture"or key=="IsProtected"or key=="Tooltip"
  if OnDebuffRow(b)then ok=ok or key=="auraType"or key=="buttonInfo"or key=="DebuffBorder"or key=="Update"end
  equal(ok,true,"button "..i.." reads only what it needs: "..key)
 end
end
equal(reads.unit or reads.timeLeft or reads.Duration,nil,"no unit, timer or duration read")
equal(iconCalls,0,"icon geometry never read")
for _,b in ipairs(AllBacks())do
 for _,key in ipairs({"TempEnchantBorder","Symbol","Count","Duration"})do equal(b[key].calls,0,"native "..key.." untouched")end
end

-- 3. Sizes within the gap. ---------------------------------------------------
-- Forever's aura icon is 30 units (AuraButtonArtTemplate); Edit Mode's
-- smallest Icon Padding is 5, in the icon's own scale (rows of the usual
-- layout are 15 apart, the timer between). Neighbours 35 apart, side by
-- side or one above the other, never overlap.
local all=Strips(back,"thick")
local reach,depth=0,0
for _,t in ipairs(all)do
 local l,r,b,tp=Rect(t)
 reach=math.max(reach,-l,r-30,-b,tp-30)
end
for _,t in ipairs(Inner(back))do local l,r,b,tp=Rect(t);depth=math.max(depth,math.min(r-l,tp-b))end
equal(reach,2,"the edge reaches 2 units past the icon")
equal(reach+depth,4,"the edge is 4 units thick in all (2 out, 2 in)")
equal((reach+depth)/30>=.1 and(reach+depth)/30<=.17,true,"about 15% of the icon (13%)")
local overlap=0
for _,t in ipairs(all)do
 local l,r,b,tp=Rect(t)
 for _,u in ipairs(all)do
  local l2,r2,b2,tp2=Rect(u)
  -- the neighbour to the right, and the one below (vertical layout)
  if l<r2+35 and l2+35<r and b<tp2 and b2<tp then overlap=overlap+1 end
  if l<r2 and l2<r and b<tp2-35 and b2-35<tp then overlap=overlap+1 end
 end
end
equal(overlap,0,"at Edit Mode's smallest gap (5) two neighbours' edges never overlap")

-- 4. Debuffs: type colours, Boosted Rest, unknown types. --------------------
equal(E.settings.darkDebuffLines,nil,"setup: Thin Debuff Colours not ticked (Classic can't tick it)")
equal(Colour(Line(d1),.2,.6,1)and d1.DebuffBorder.alpha==0,true,"a magic debuff: its line in magic's colour, the game's border hidden")
Band(Line(d1),-2,4,"a debuff's type line is 2 units wide (2 to 4 in)")
equal(Colour(Line(d2),.8,0,0)and d2.DebuffBorder.alpha==0,true,"a debuff with no type: the game's no-type colour")
equal(Colour(Line(rest),BRONZE[1],BRONZE[2],BRONZE[3])and rest.DebuffBorder.alpha==0,true,"Boosted Rest: dark, its line plain bronze, no red ring")
Band(Line(rest),-2,3,"Boosted Rest's line stays one unit")
equal(Colour(Line(deadlyBack),BRONZE[1],BRONZE[2],BRONZE[3])and deadlyBack.DebuffBorder.alphaSets==nil,true,"the deadly debuff warning: thick edge, its own border kept")
for i,b in ipairs(AllBacks())do
 if not OnDebuffRow(b)then equal(Colour(Line(b),BRONZE[1],BRONZE[2],BRONZE[3])and b.reads.buttonInfo==nil,true,"buffs: bronze line, no aura data read (button "..i..")")end
end
-- Unchanged passes set nothing.
local sets,pins,shows,alphas=Count("sets"),Count("pins"),Count("shows"),AlphaSets()
M:RefreshBorders();DebuffFrame:UpdateAuraButtons();BuffFrame:UpdateAuraButtons();ns.RefreshDarkness()
DebuffFrame.auraFrames[1]:Update(d1.buttonInfo)
equal(Count("sets").." "..Count("pins").." "..Count("shows").." "..AlphaSets(),sets.." "..pins.." "..shows.." "..alphas,
 "unchanged passes, the slider and the game's own updates set no colour, place, show or alpha again")
-- In a fight the type is secret: remembered by the aura's ID.
d1.buttonInfo={debuffType=SECRET,texture=SECRET,auraInstanceID=101};DebuffFrame:UpdateAuraButtons()
equal(Colour(Line(d1),.2,.6,1)and d1.DebuffBorder.alpha==0,true,"type secret in a fight: remembered, still magic's line")
-- Never seen with its type: the game's own border, as the game set it, and the plain line.
d1.buttonInfo={debuffType=SECRET,texture=SECRET,auraInstanceID=150};DebuffFrame:UpdateAuraButtons()
equal(d1.DebuffBorder.alpha==1 and Colour(Line(d1),BRONZE[1],BRONZE[2],BRONZE[3]),true,"unknown type: the game's border back (it shows the right colour) and the plain line")
Band(Line(d1),-2,3,"and the line back to one unit")
local fresh,freshBack=Button("Debuff");freshBack.buttonInfo={debuffType=SECRET,texture=SECRET,auraInstanceID=151}
DebuffFrame.auraFrames[5],DebuffFrame.backs[5]=fresh,freshBack
DebuffFrame:UpdateAuraButtons()
equal(freshBack.DebuffBorder.alphaSets==nil and Colour(Line(freshBack),BRONZE[1],BRONZE[2],BRONZE[3]),true,"a debuff whose type was never seen: its border never touched")
-- Nothing readable: the game's border; Boosted Rest known by its aura stays dark.
d1.buttonInfo={debuffType="Curse",texture=136139,auraInstanceID=152};DebuffFrame:UpdateAuraButtons()
equal(Colour(Line(d1),.6,0,1),true,"a curse: purple")
d1.buttonInfo={debuffType=SECRET,texture=SECRET,auraInstanceID=SECRET};DebuffFrame:UpdateAuraButtons()
equal(d1.DebuffBorder.alpha==1 and Colour(Line(d1),BRONZE[1],BRONZE[2],BRONZE[3]),true,"nothing readable: the game's border and the plain line")
rest.buttonInfo={texture=SECRET,auraInstanceID=103};DebuffFrame:UpdateAuraButtons()
equal(rest.DebuffBorder.alpha==0 and Colour(Line(rest),BRONZE[1],BRONZE[2],BRONZE[3]),true,"Boosted Rest, icon secret in a fight: still dark")
-- The game's own update of one button: checked again straight after.
DebuffFrame.auraFrames[1]:Update({debuffType="Poison",texture=136064,auraInstanceID=153})
equal(Colour(Line(d1),0,.6,0)and d1.DebuffBorder.alpha==0,true,"the game's own update: the new type's colour at once")
Band(Line(d1),-2,4,"and 2 units wide again")
DebuffFrame.auraFrames[1]:Update({texture=1001982,auraInstanceID=154})
equal(Colour(Line(d1),BRONZE[1],BRONZE[2],BRONZE[3])and d1.DebuffBorder.alpha==0,true,"Boosted Rest moved onto it: plain line, dark")
DebuffFrame.auraFrames[1]:Update({debuffType="Magic",texture=135894,auraInstanceID=101})
-- With the Classic unit frames on, their debuff border styling still runs; the hidden border stays hidden.
E.settings.unitFrames=true;d1.DebuffBorder.calls=0;DebuffFrame:UpdateAuraButtons()
equal(d1.DebuffBorder.calls>0 and d1.DebuffBorder.alpha==0 and Colour(Line(d1),.2,.6,1),true,"Classic debuff styling beside it, the border still hidden under the type line")
E.settings.unitFrames=false

-- 5. Dark Mode: the Darkness grey, live; precedence. -------------------------
E.settings.darkMode=true;E.settings.darkAuraShadows=false;M:RefreshBorders()
for i,b in ipairs(AllBacks())do
 equal(Shown(Strips(b,"thick"))and Hidden(Strips(b,"dab")),true,"Dark Mode with Dark Aura Borders: the thick ring wins, theirs hidden (button "..i..")")
end
equal(Colour(Line(back),Grey(58)),true,"in Dark Mode the line is Dark Mode's grey (.30, .31, .34 at 58)")
equal(Colour(Line(d1),.2,.6,1)and Colour(Line(rest),Grey(58)),true,"type colours kept, Boosted Rest grey")
equal(Colour(Strips(d1,"dab","ARTWORK"),Grey(58)),true,"Dark Aura Borders' hidden line stays plain: only the ring that shows is coloured")
sets=Count("sets")
E.settings.darkModeDarkness=90;ns.RefreshDarkness()
equal(Colour(Line(back),Grey(90))and Colour(Line(rest),Grey(90)),true,"Darkness 90: the lines darken at once")
equal(Colour(Line(d1),.2,.6,1)and Colour(Line(d2),.8,0,0),true,"and the type colours stay")
-- Dark Aura Borders' hidden rings follow the slider too, as they always have.
local grey=0
for _,b in ipairs(AllBacks())do
 if Colour(Line(b),Grey(90))then grey=grey+1 end
 if Colour(Strips(b,"dab","ARTWORK"),Grey(90))then grey=grey+1 end
end
equal(Count("sets")-sets,4*grey,"one colour set per grey line strip, none on the edge or a type line")
E.settings.darkModeDarkness=nil;ns.RefreshDarkness()
equal(Colour(Line(back),Grey(58)),true,"back at 58")
-- Thin Debuff Colours ticked too: the thick ring still carries the colour;
-- Dark Aura Borders' (hidden) line stays plain.
E.settings.darkDebuffLines=true;M:RefreshBorders()
equal(Colour(Line(d1),.2,.6,1)and Hidden(Strips(d1,"dab"))and d1.DebuffBorder.alpha==0,true,"with Thin Debuff Colours: one coloured line, the thick one")
-- Thick off: Dark Aura Borders' ring takes over exactly as without us,
-- with Thin Debuff Colours' line.
E.settings.thickAuraBorders=false;M:RefreshBorders()
equal(Hidden(Strips(d1,"thick"))and Shown(Strips(d1,"dab"))and d1.DebuffBorder.alpha==0,true,"thick off: the thin ring back, the border still hidden for Thin Debuff Colours")
equal(Colour(Strips(d1,"dab","ARTWORK"),.2,.6,1),true,"and its thin line in magic's colour")
E.settings.darkDebuffLines=nil;M:RefreshBorders()
equal(d1.DebuffBorder.alpha==1 and Colour(Strips(d1,"dab","ARTWORK"),Grey(58)),true,"Thin Debuff Colours off: the game's border and the grey line")
E.settings.thickAuraBorders=true;M:RefreshBorders()
equal(Shown(Strips(d1,"thick"))and Hidden(Strips(d1,"dab"))and d1.DebuffBorder.alpha==0 and Colour(Line(d1),.2,.6,1),true,"thick on again: its own type line, no tick needed")
-- Dark Aura Borders off: the thick ring still shows in Dark Mode (its own gate).
E.settings.darkAuraBorders=false;M:RefreshBorders()
equal(Shown(Strips(back,"thick"))and Colour(Line(back),Grey(58)),true,"Dark Aura Borders off: Thick Aura Borders still shows")
E.settings.darkAuraBorders=true;M:RefreshBorders()

-- 6. Aura Shadows: softer, two steps, edge and shadow within the gap. ------
local SOFT={.35,.15}
local function ShadowRings(b,want)
 local h=b.holders[1]
 if not(h and h.shown)then return want==nil end
 local bad=0
 for _,t in ipairs(h.textures)do
  if t.shown then
   local l,r,bt,tp=Rect(t)
   local d=math.max(-l,r-30,-bt,tp-30)-1 -- the ring's inner distance
   local ring=d-1
   if not(want[ring]and math.abs(t.colour[4]-want[ring])<1e-9)then bad=bad+1 end
  end
 end
 return bad==0
end
E.settings.darkAuraShadows=true;M:RefreshBorders()
for i,b in ipairs(AllBacks())do
 equal(b.holders[1]~=nil and b.holders[1].shown,true,"Aura Shadows on: a shadow (button "..i..")")
 equal(ShadowRings(b,SOFT),true,"under the thick edge a softer two-step shadow, 35% then 15% (button "..i..")")
 equal(b.holders[1].level,b.level-1,"under its button, as before (button "..i..")")
end
local h=back.holders[1]
local far,cover=0,0
for _,t in ipairs(h.textures)do
 if t.shown then local l,r,bt,tp=Rect(t);far=math.max(far,-l,r-30,-bt,tp-30)end
end
equal(far,4,"shadow from 2 to 4 units out: edge 2 + shadow 2 = 4, within Edit Mode's smallest gap (5)")
for x=-6.75,36.75,.5 do
 for y=-6.75,36.75,.5 do
  local hits=0
  for _,t in ipairs(h.textures)do
   if t.shown then local l,r,bt,tp=Rect(t);if x>l and x<r and y>bt and y<tp then hits=hits+1 end end
  end
  local d=math.max(-x,x-30,-y,y-30)
  if hits~=((d>2 and d<4)and 1 or 0)then cover=cover+1 end
 end
end
equal(cover,0,"the softer shadow covers 2 to 4 units out exactly once: no double-dark corners, no gaps")
-- Thick off: the full three rings again; on: soft again; unchanged passes set nothing.
E.settings.thickAuraBorders=false;M:RefreshBorders()
for i,b in ipairs(AllBacks())do equal(ShadowRings(b,{.45,.25,.1}),true,"thick off: Aura Shadows' own three rings again (button "..i..")")end
E.settings.thickAuraBorders=true;M:RefreshBorders()
equal(ShadowRings(back,SOFT),true,"thick on again: soft again")
sets,shows=Count("sets"),Count("shows")
M:RefreshBorders();BuffFrame:UpdateAuraButtons();DebuffFrame:UpdateAuraButtons()
equal(Count("sets").." "..Count("shows"),sets.." "..shows,"held: the shadow is not set again")
equal(holderCount,#AllBacks(),"one shadow frame per button, never a second")

-- 7. Live switch both ways: off is today's look exactly. -------------------
E.settings.thickAuraBorders=false;M:RefreshBorders()
SameLook(darkOff,"switched off in Dark Mode: exactly Dark Aura Borders and Aura Shadows as before")
local made=created
E.settings.thickAuraBorders=true;M:RefreshBorders()
equal(created,made,"switched on again: the same strips, none made")
E.settings.darkMode=false;M:RefreshBorders()
equal(Colour(Line(back),BRONZE[1],BRONZE[2],BRONZE[3])and(back.holders[1]==nil or not back.holders[1].shown),true,"Classic again: bronze, no shadow")
E.settings.thickAuraBorders=false;M:RefreshBorders()
SameLook(classicOff,"switched off in Classic: exactly today's Classic look (full icons, the game's borders)")
sets,alphas,pins=Count("sets"),AlphaSets(),Count("pins")
M:RefreshBorders();DebuffFrame:UpdateAuraButtons();BuffFrame:UpdateAuraButtons();ns.RefreshDarkness()
DebuffFrame.auraFrames[1]:Update(d1.buttonInfo)
equal(Count("sets").." "..AlphaSets().." "..Count("pins"),sets.." "..alphas.." "..pins,"off: then left alone")
local coordSets=0
for _,b in ipairs(AllBacks())do coordSets=coordSets+b.coordSets end
M:RefreshBorders()
local after=0
for _,b in ipairs(AllBacks())do after=after+b.coordSets end
equal(after,coordSets,"off: icons left alone")
-- EraUI turned off: nothing shows.
E.settings.thickAuraBorders=true;E.settings.enabled=false;M:RefreshBorders()
SameLook(classicOff,"EraUI turned off: nothing shows")
E.settings.enabled=true;M:RefreshBorders()
equal(Shown(Strips(back,"thick")),true,"EraUI back on: the thick ring back")
-- A button acquired later gets its thick ring from the existing update hook, in combat.
local late,lateBack=Button("Buff");BuffFrame.auraFrames[5],BuffFrame.backs[5]=late,lateBack
combat=true;BuffFrame:UpdateAuraButtons();combat=false
equal(#Strips(lateBack,"thick").." "..table.concat(lateBack.coords,","),"12 0.07,0.93,0.07,0.93","a later button: thick ring and trim on the next native update")

-- 8. Protected buttons wait for combat to end. -------------------------------
E.settings.thickAuraBorders=false;M:RefreshBorders()
local guarded,guardedBack=Button("Buff",{protected=true})
ExternalDefensivesFrame.auraFrames[2],ExternalDefensivesFrame.backs[2]=guarded,guardedBack
combat=true;E.settings.thickAuraBorders=true;M:RefreshBorders()
equal(#guardedBack.textures+guardedBack.coordSets,0,"a protected button: nothing made or trimmed in combat")
equal(Shown(Strips(back,"thick")),true,"plain buttons switch at once in combat")
combat=false;events.handler(events,"PLAYER_REGEN_ENABLED")
equal(#Strips(guardedBack,"thick").." "..table.concat(guardedBack.coords,","),"12 0.07,0.93,0.07,0.93","ringed and trimmed once combat ends")
combat=true;E.settings.thickAuraBorders=false;M:RefreshBorders()
equal(table.concat(guardedBack.coords,","),"0.07,0.93,0.07,0.93","its trim kept through combat")
combat=false;events.handler(events,"PLAYER_REGEN_ENABLED")
equal(table.concat(guardedBack.coords,",").." "..tostring(Hidden(Strips(guardedBack,"thick"))),"0,1,0,1 true","full coords and hidden once combat ends")
-- A protected debuff button: its line's width waits too.
local guardedDebuff,gdBack=Button("Debuff",{protected=true})
gdBack.buttonInfo={debuffType="Magic",texture=135894,auraInstanceID=160}
DebuffFrame.auraFrames[6],DebuffFrame.backs[6]=guardedDebuff,gdBack
E.settings.thickAuraBorders=true;M:RefreshBorders()
Band(Line(gdBack),-2,4,"protected debuff out of combat: a 2-unit type line")
equal(Colour(Line(gdBack),.2,.6,1)and gdBack.DebuffBorder.alpha==0,true,"and magic's colour")
gdBack.buttonInfo={texture=1001982,auraInstanceID=161}
local clears=Count("clears")
combat=true;M:RefreshBorders()
Band(Line(gdBack),-2,4,"in combat a protected button's line keeps its place")
equal(Colour(Line(gdBack),.2,.6,1)and Count("clears")==clears,true,"and its colour: nothing re-pinned in combat")
combat=false;events.handler(events,"PLAYER_REGEN_ENABLED")
Band(Line(gdBack),-2,3,"once combat ends: Boosted Rest's plain line, one unit")
equal(Colour(Line(gdBack),BRONZE[1],BRONZE[2],BRONZE[3])and gdBack.DebuffBorder.alpha==0,true,"bronze and dark")
-- A protected button already wearing Dark Aura Borders' ring: Thick Aura
-- Borders switched on in a fight makes its own ring only once combat ends.
E.settings.thickAuraBorders=false;E.settings.darkMode=true;M:RefreshBorders()
local worn,wornBack=Button("Buff",{protected=true})
ExternalDefensivesFrame.auraFrames[3],ExternalDefensivesFrame.backs[3]=worn,wornBack
M:RefreshBorders()
equal(#Strips(wornBack,"dab").." "..tostring(Shown(Strips(wornBack,"dab"))).." "..#Strips(wornBack,"thick"),"8 true 0",
 "setup: a protected button with Dark Aura Borders' ring")
combat=true;E.settings.thickAuraBorders=true;M:RefreshBorders()
equal(#Strips(wornBack,"thick"),0,"its thick ring is not made in combat")
combat=false;events.handler(events,"PLAYER_REGEN_ENABLED")
equal(#Strips(wornBack,"thick").." "..tostring(Shown(Strips(wornBack,"thick"))).." "..tostring(Hidden(Strips(wornBack,"dab"))),"12 true true",
 "made once combat ends, Dark Aura Borders' ring hidden")
equal(Colour(Line(wornBack),Grey(58)),true,"in Dark Mode's grey")
E.settings.darkMode=false;M:RefreshBorders()

-- 9. No keys, hooks or tooltips. --------------------------------------------
-- Every key write on an aura button, the icon, target/focus auras or the
-- game's tooltip would have failed the run.
equal(hooks,before,"no new hooks for Thick Aura Borders")
equal(iconCalls,0,"icon geometry never read through all of it")
print("Thick aura border checks passed: "..checks.." assertions.")
