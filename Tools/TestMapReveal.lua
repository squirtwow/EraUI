-- Run from the addon directory with a Lua interpreter.
-- Exercises real module/data files against a simulated native map lifecycle.
local unpack=table.unpack or unpack
local checks=0
local function equal(actual,expected,label)
 checks=checks+1
 assert(actual==expected,(label or "check")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local frames={}
local function Frame()
 local f={scripts={},hooks={},shown=true,width=1002,height=668,textures={}}
 function f:GetWidth()return self.width end
 function f:GetHeight()return self.height end
 function f:IsShown()return self.shown end
 function f:HookScript(event,fn)
  self.hooks[event]=self.hooks[event]or{}
  table.insert(self.hooks[event],fn)
 end
 function f:SetScript(event,fn)self.scripts[event]=fn end
 function f:RegisterEvent(event)self.events=self.events or{};self.events[event]=true end
 function f:UnregisterEvent(event)self.events[event]=nil end
 function f:Fire(event,...)
  if self.scripts[event]then self.scripts[event](self,...)end
  for _,fn in ipairs(self.hooks[event]or{})do fn(self,...)end
 end
 function f:Show()self.shown=true;self:Fire("OnShow")end
 function f:Hide()self.shown=false;self:Fire("OnHide")end
 function f:CreateTexture()
  local t={parent=self,shown=false}
  function t:Hide()self.shown=false end
  function t:Show()self.shown=true end
  function t:ClearAllPoints()self.point=nil end
  function t:SetTexture(id)self.file=id end
  function t:SetSize(w,h)self.width=w;self.height=h end
  function t:SetTexCoord(...)self.uv={...}end
  function t:SetPoint(...)self.point={...}end
  function t:SetDrawLayer(...)self.layer={...}end
  function t:SetVertexColor(...)self.colour={...}end
  function t:SetAlpha(alpha)self.alpha=alpha end
  table.insert(self.textures,t)
  return t
 end
 frames[#frames+1]=f
 return f
end
CreateFrame=function(kind)equal(kind,"Frame","frame type");return Frame()end
hooksecurefunc=function(target,name,callback)
 local original=assert(target[name],name)
 target[name]=function(...)
  local result={original(...)}
  callback(...)
  return unpack(result)
 end
end

local E={modules={},settings={enabled=true,revealMap=false},messages={}}
function E:RegisterModule(name,module)self.modules[name]=module end
function E:GetSetting(key)return self.settings[key]end
function E:SetSetting(key,value)self.settings[key]=value end
function E:Print(text)table.insert(self.messages,text)end
assert(loadfile("Modules/MapRevealData.lua"))("EraUI",E)
local data=E.MapRevealData
local artIDs={[947]=2141,[1414]=2142,[1415]=2140}
for id,arts in pairs(data.maps)do for art in pairs(arts)do artIDs[id]=art end end
local explored,failAPI,badArt,badDimensions=nil,false,nil,false
C_Map={
 GetMapArtID=function(id)return badArt or artIDs[id]end,
 GetMapArtLayers=function()
  return {{layerWidth=badDimensions and 999 or 1002,layerHeight=668,tileWidth=256,tileHeight=256}}
 end,
 -- Any accidental player-location fallback must fail the test.
 GetBestMapForUnit=function()error("must not read player location")end,
}
C_MapExplorationInfo={GetExploredMapTextures=function()
 if failAPI then error("simulated API failure")end
 return explored
end}

local function NewPin(map)
 local pin=Frame()
 pin.map=map
 pin.nativeTexture=pin:CreateTexture()
 pin.nativeTexture:Show()
 pin.textureLoadGroup={textures={},AddTexture=function(self,texture)table.insert(self.textures,texture)end}
 function pin:GetMap()return self.map end
 function pin:RemoveAllData()
  self.nativeTexture:Hide()
  self.textureLoadGroup.textures={}
  self.isWaitingForLoad=nil
 end
 function pin:RefreshOverlays(fullUpdate)
  self:RemoveAllData()
  self.isWaitingForLoad=fullUpdate
  self.nativeTexture:Show()
 end
 function pin:OnCanvasSizeChanged()end
 return pin
end
local function NewMap()
 local map=Frame()
 map.mapID=1411
 map.pins={}
 map.layer=1
 map.masked={}
 function map:GetMapID()return self.mapID end
 function map:GetCanvasContainer()
  return {GetCurrentLayerIndex=function()return self.layer end}
 end
 function map:EnumeratePinsByTemplate()
  -- Deliberately use a stateful iterator, rather than a closure-only iterator.
  return next,self.pins,nil
 end
 function map:AcquirePin()
  local pin=NewPin(self)
  self.pins[pin]=true
  return pin
 end
 function map:AddMaskableTexture(texture)self.masked[texture]=true end
 return map
end
local map=NewMap()
WorldMapFrame=map
local pin=map:AcquirePin("MapExplorationPinTemplate")
assert(loadfile("Modules/MapReveal.lua"))("EraUI",E)
local M=E.modules.MapReveal
M:Initialize()
local function visible(p)
 local n=0
 for _,t in ipairs(M.states[p].textures)do if t.shown then n=n+1 end end
 return n
end
local function tile(file)
 for _,t in ipairs(M.states[pin].textures)do if t.shown and t.file==file then return t end end
 error("missing texture "..file)
end
local function navigate(id)
 map.mapID=id
 for p in map:EnumeratePinsByTemplate()do p:OnCanvasSizeChanged();p:RefreshOverlays(true)end
end

equal(visible(pin),0,"default off")
E:SetSetting("revealMap",true)
equal(visible(pin),12,"Durotar unexplored textures")
equal(M.states[pin].regions,11,"Durotar regions")
equal(pin.nativeTexture.shown,true,"native artwork retained")
local edge=tile(8074089)
equal(edge.width,256,"Durotar edge width")
equal(edge.height,241,"Durotar edge height")
equal(edge.uv[4],241/256,"Durotar edge crop")
equal(edge.point[2],pin,"texture parent anchor")
equal(edge.point[4],549,"Durotar edge x")
equal(edge.point[5],-427,"Durotar edge y")
equal(tile(8074092).point[4],500,"second-column position")
equal(map.masked[edge],true,"native clipping registration")

explored={{offsetX=427,offsetY=78,textureWidth=256,textureHeight=256,fileDataIDs={8073637}}}
pin:RefreshOverlays(true)
equal(visible(pin),11,"explored region skipped")
equal(#pin.textureLoadGroup.textures,11,"reveal participates in native texture loading")
explored[1].fileDataIDs={1}
pin:RefreshOverlays()
equal(visible(pin),12,"different-art explored record cannot hide valid reveal")
explored[1].fileDataIDs={8073637}
explored[1].isShownByMouseOver=true
pin:RefreshOverlays()
equal(visible(pin),12,"mouseover preview is not exploration")

for _,id in ipairs({947,1414,1415,999999})do
 navigate(id)
 equal(visible(pin),0,"no stale zone artwork on map "..id)
end
explored=nil
navigate(1438)
equal(visible(pin),12,"Teldrassil textures")
equal(M.states[pin].artID,2180,"displayed map art, not player zone")
local durotarFiles={}
for _,r in ipairs(data.art[2169][1].regions)do for _,c in ipairs(r[6])do durotarFiles[c[3]]=true end end
for _,t in ipairs(M.states[pin].textures)do
 if t.shown then equal(durotarFiles[t.file],nil,"no Durotar textures on Teldrassil")end
end
navigate(2652)
local narrow=tile(7970593)
equal(narrow.width,1,"one-pixel edge tile")
equal(narrow.uv[2],1/16,"minimum padded texture extent")
equal(narrow.point[4],751,"one-pixel edge position")

E:SetSetting("revealMap",false)
equal(visible(pin),0,"toggle off clears immediately")
equal(pin.nativeTexture.shown,true,"toggle off retains native artwork")
E:SetSetting("revealMap",true)
E:SetSetting("enabled",false)
equal(visible(pin),0,"master toggle clears immediately")
E:SetSetting("enabled",true)
navigate(1411)
map:Hide()
equal(visible(pin),0,"map hide cleanup")
map:Show()
equal(visible(pin),12,"map reopen refresh")
pin:RemoveAllData()
equal(visible(pin),0,"native clear cleanup")
pin:RefreshOverlays(true)
equal(visible(pin),12,"native refresh redraw")

badArt=2180
pin:RefreshOverlays()
equal(visible(pin),0,"map/art mismatch clears")
badArt=nil;badDimensions=true
pin:RefreshOverlays()
equal(visible(pin),0,"layer dimension mismatch clears")
badDimensions=false;map.layer=2
pin:RefreshOverlays()
equal(visible(pin),0,"unknown active layer clears")
map.layer=1;pin.width=500
pin:RefreshOverlays()
equal(visible(pin),0,"uninitialised pin size draws nothing")
pin.width=1002;pin:OnCanvasSizeChanged()
equal(visible(pin),12,"native size event resumes reveal")
failAPI=true
pin:RefreshOverlays()
equal(visible(pin),0,"API failure clears old artwork")
equal(#E.messages,1,"API failure reported once")
pin:RefreshOverlays()
equal(#E.messages,1,"repeated error does not spam")
failAPI=false
pin:RefreshOverlays()
equal(visible(pin),12,"recover after API failure")

local old=pin
old:Hide()
map.pins={}
pin=map:AcquirePin("MapExplorationPinTemplate")
equal(visible(old),0,"released pin retains no visible artwork")
equal(visible(pin),12,"replacement pin attaches")
equal(M.states[pin].textures[1].parent,pin,"replacement owns separate textures")

-- Fully explored zones should have zero addon textures and intact native art.
explored={}
for _,r in ipairs(data.art[2169][1].regions)do
 local files={}
 for _,cell in ipairs(r[6])do files[#files+1]=cell[3]end
 explored[#explored+1]={offsetX=r[2],offsetY=r[3],textureWidth=r[4],textureHeight=r[5],fileDataIDs=files}
end
pin:RefreshOverlays()
equal(visible(pin),0,"fully explored zone")
equal(pin.nativeTexture.shown,true,"fully explored native art remains")
explored=nil

-- Exercise every generated map through the native refresh path.
local maps,regions,textures=0,0,0
for id in pairs(data.maps)do
 navigate(id)
 local state=M.states[pin]
 equal(state.status,"ready","map data renders "..id)
 maps=maps+1;regions=regions+state.regions;textures=textures+state.drawn
 for _,t in ipairs(state.textures)do
  if t.shown then
   assert(t.width>0 and t.height>0 and t.width<=256 and t.height<=256)
   assert(t.uv[2]>0 and t.uv[2]<=1 and t.uv[4]>0 and t.uv[4]<=1)
  end
 end
end
equal(maps,45,"supported maps")
equal(regions,572,"generated region coverage")
equal(textures,972,"generated texture coverage")
assert(M:DumpText():find("drawn textures",1,true),"diagnostics include renderer state")
for _,f in ipairs(frames)do equal(f.scripts.OnUpdate,nil,"no reveal polling")end

-- Late-loaded map and restored enabled setting.
local E2={modules={},MapRevealData=data,settings={enabled=true,revealMap=true},messages={}}
E2.RegisterModule,E2.GetSetting,E2.SetSetting,E2.Print=E.RegisterModule,E.GetSetting,
 function(self,key,value)self.settings[key]=value end,E.Print
WorldMapFrame=nil
assert(loadfile("Modules/MapReveal.lua"))("EraUI",E2)
local late=E2.modules.MapReveal
late:Initialize()
local listener=frames[#frames]
equal(listener.events.ADDON_LOADED,true,"wait for late-loaded map")
WorldMapFrame=NewMap()
local latePin=WorldMapFrame:AcquirePin("MapExplorationPinTemplate")
listener:Fire("OnEvent","ADDON_LOADED","Blizzard_WorldMap")
equal(late.states[latePin].drawn,12,"saved enabled setting works on late map")
equal(listener.events.ADDON_LOADED,nil,"late-load listener retired")
print("Map reveal lifecycle/data checks passed: "..checks.." assertions; 45 maps, 572 regions, 972 textures.")
