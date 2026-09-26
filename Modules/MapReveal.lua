local _,E=...
local M={states={}}
E:RegisterModule("MapReveal",M)
local TEMPLATE="MapExplorationPinTemplate"
local data=E.MapRevealData
local UNEXPLORED_SHADE=.65

local function Enabled()
 return E:GetSetting("enabled")==true and E:GetSetting("revealMap")==true
end

local function Clear(state,reason)
 for _,texture in ipairs(state.textures)do
  texture:Hide()
  texture:ClearAllPoints()
 end
 state.drawn=0
 state.regions=0
 state.skipped=0
 state.status=reason or "cleared"
end

local function BoundsKey(x,y,w,h)
 return tostring(x)..":"..tostring(y)..":"..tostring(w)..":"..tostring(h)
end

local function TextureExtent(pixels)
 local extent=16
 while extent<pixels do extent=extent*2 end
 return extent
end

local function Render(pin,state,fullUpdate)
 state.mapID,state.artID,state.layer=nil,nil,nil
 if not Enabled()then state.status="disabled";return end
 local map=pin:GetMap()
 if map~=M.map then state.status="pin belongs to another map";return end
 if not map:IsShown()then state.status="map hidden";return end
 if not(data and C_Map and C_Map.GetMapArtID and C_Map.GetMapArtLayers
  and C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures)then
  state.status="map data API unavailable";return
 end

 -- Use the displayed map and its current art together. Never use player location.
 local mapID=map:GetMapID()
 local artID=mapID and C_Map.GetMapArtID(mapID)
 state.mapID,state.artID=mapID,artID
 if not(mapID and artID and data.maps[mapID] and data.maps[mapID][artID])then
  state.status="no reveal data for this map/art";return
 end
 local container=map:GetCanvasContainer()
 if not(container and container.GetCurrentLayerIndex)then
  state.status="native canvas unavailable";return
 end
 local index=container:GetCurrentLayerIndex()
 state.layer=index
 local source=data.art[artID] and data.art[artID][index]
 local layers=C_Map.GetMapArtLayers(mapID)
 local layer=layers and layers[index]
 if not(source and layer)then state.status="unsupported art layer";return end
 if source.width~=layer.layerWidth or source.height~=layer.layerHeight
  or source.tileWidth~=layer.tileWidth or source.tileHeight~=layer.tileHeight then
  state.status="art dimensions differ from data build";return
 end
 if math.abs(pin:GetWidth()-source.width)>.1 or math.abs(pin:GetHeight()-source.height)>.1 then
  state.status="waiting for native exploration pin size";return
 end

 local explored={}
 for _,info in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID)or{})do
  if not info.isShownByMouseOver then
   explored[BoundsKey(info.offsetX,info.offsetY,info.textureWidth,info.textureHeight)]=info.fileDataIDs
  end
 end
 local tileW,tileH=source.tileWidth,source.tileHeight
 state.regions=#source.regions
 for _,region in ipairs(source.regions)do
  local x,y,w,h,cells=region[2],region[3],region[4],region[5],region[6]
  local present=explored[BoundsKey(x,y,w,h)]
  local alreadyDrawn=type(present)=="table" and #present==#cells
  if alreadyDrawn then
   for i,cell in ipairs(cells)do
    if present[i]~=cell[3]then alreadyDrawn=false;break end
   end
  end
  if alreadyDrawn then
   state.skipped=state.skipped+1
  else
   for _,cell in ipairs(cells)do
    -- DB2 provides each tile's column and row explicitly, including edge tiles.
    local dx,dy=cell[1]*tileW,cell[2]*tileH
    local width,height=math.min(tileW,w-dx),math.min(tileH,h-dy)
    state.drawn=state.drawn+1
    local texture=state.textures[state.drawn]
    if not texture then
     texture=pin:CreateTexture(nil,"ARTWORK",nil,-1)
     state.textures[state.drawn]=texture
     if map.AddMaskableTexture then map:AddMaskableTexture(texture)end
    end
    texture:SetTexture(cell[3],nil,nil,"TRILINEAR")
    texture:SetSize(width,height)
    texture:SetTexCoord(0,width/TextureExtent(width),0,height/TextureExtent(height))
    texture:SetPoint("TOPLEFT",pin,"TOPLEFT",x+dx,-y-dy)
    texture:SetDrawLayer("ARTWORK",-1)
    -- Only undiscovered regions reach this path. Native exploration refreshes
    -- remove these shaded tiles as each region becomes explored.
    texture:SetVertexColor(UNEXPLORED_SHADE,UNEXPLORED_SHADE,UNEXPLORED_SHADE,1)
    texture:SetAlpha(1)
    if (fullUpdate or pin.isWaitingForLoad)and pin.textureLoadGroup then
     pin.textureLoadGroup:AddTexture(texture)
    end
    texture:Show()
   end
  end
 end
 state.status="ready"
end

function M:RefreshPin(pin,fullUpdate)
 local state=self.states[pin]
 if not state then return end
 -- Clear before all validation and API calls, including failures and empty maps.
 Clear(state)
 local ok,err=pcall(Render,pin,state,fullUpdate)
 if not ok then
  Clear(state,"error: "..tostring(err))
  if self.lastError~=tostring(err)then
   self.lastError=tostring(err)
   E:Print("Map reveal could not refresh: "..tostring(err))
  end
 end
end

function M:Attach(pin)
 if self.states[pin]then return end
 if not(pin.GetMap and pin.RefreshOverlays and pin.RemoveAllData and pin.OnCanvasSizeChanged)then
  self.status="exploration pin methods unavailable";return
 end
 local state={textures={},drawn=0,regions=0,skipped=0,status="attached"}
 self.states[pin]=state
 -- Our textures stay outside Blizzard's pool, but share its pin and lifecycle.
 hooksecurefunc(pin,"RemoveAllData",function()Clear(state)end)
 hooksecurefunc(pin,"RefreshOverlays",function(p,fullUpdate)M:RefreshPin(p,fullUpdate)end)
 hooksecurefunc(pin,"OnCanvasSizeChanged",function(p)M:RefreshPin(p)end)
 pin:HookScript("OnHide",function()Clear(state,"pin hidden")end)
 pin:HookScript("OnShow",function(p)M:RefreshPin(p)end)
end

function M:Install()
 local map=_G.WorldMapFrame
 if self.map and self.map==map then return true end
 if not(map and map.EnumeratePinsByTemplate and map.GetMapID and map.GetCanvasContainer and map.AcquirePin)then
  self.status="waiting for world map APIs";return false
 end
 self.map=map
 hooksecurefunc(map,"AcquirePin",function(_,template)
  if template==TEMPLATE then M:Apply()end
 end)
 map:HookScript("OnShow",function()M:Apply()end)
 map:HookScript("OnHide",function()
  for _,state in pairs(M.states)do Clear(state,"map hidden")end
 end)
 self.status="installed"
 return true
end

function M:Apply()
 if not self:Install()then return end
 local active={}
 -- Preserve the iterator's state and control values returned by the client.
 for pin in self.map:EnumeratePinsByTemplate(TEMPLATE)do
  active[pin]=true
  self:Attach(pin)
  self:RefreshPin(pin)
 end
 for pin,state in pairs(self.states)do
  if not active[pin]then Clear(state,"pin released")end
 end
end

function M:DumpText()
 local lines={"reveal data "..tostring(data and data.build),
  "reveal "..(Enabled()and"enabled"or"disabled").."; "..tostring(self.status)}
 local count=0
 for pin,state in pairs(self.states)do
  count=count+1
  lines[#lines+1]="reveal pin "..count.." map "..tostring(state.mapID).." art "..tostring(state.artID)
   .." layer "..tostring(state.layer).." size "..tostring(pin:GetWidth()).."x"..tostring(pin:GetHeight())
  lines[#lines+1]="  "..state.status.."; regions "..state.regions.." explored "..state.skipped.." drawn textures "..state.drawn
 end
 if count==0 then lines[#lines+1]="reveal: no exploration pin attached"end
 return table.concat(lines,"\n")
end

function M:Initialize()
 hooksecurefunc(E,"SetSetting",function(_,key)
  if key=="revealMap"or key=="enabled"then M:Apply()end
 end)
 if self:Install()then self:Apply();return end
 local listener=CreateFrame("Frame")
 listener:RegisterEvent("ADDON_LOADED")
 listener:SetScript("OnEvent",function()
  if M:Install()then
   listener:UnregisterEvent("ADDON_LOADED")
   listener:SetScript("OnEvent",nil)
   M:Apply()
  end
 end)
end
