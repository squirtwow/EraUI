-- Dark Menu Bar on the real Classic/BarSkins.lua and Core/Appearance.lua: in
-- Dark Mode, with its tick on, each micro button's frame art (Background and
-- PushedBackground) takes Dark Mode's grey at the Darkness slider's value; the
-- icon (the button's state textures) is never tinted; a button wearing the
-- classic art is left alone; a pass with nothing new sets nothing, and the
-- game reloading a button's art paints it again.
local checks=0
local function equal(got,want,label)
 checks=checks+1;assert(got==want,label..": expected "..tostring(want)..", got "..tostring(got))
end
local function Near(a,b)return math.abs(a-b)<1e-6 end

-- A texture that logs its vertex colour; any other call is allowed but counted.
local function Texture(name)
 local t={name=name,colour={1,1,1},sets=0,other=0}
 return setmetatable(t,{__index=function(_,key)
  if key=="SetVertexColor"then return function(self,r,g,b)self.colour={r,g,b};self.sets=self.sets+1 end end
  return function(self)self.other=self.other+1 end
 end})
end
-- A micro button: its frame art, and state textures that must never be tinted.
local function Button(name)
 local b={name=name,Background=Texture("bg"),PushedBackground=Texture("pushedBg"),state="NORMAL"}
 b.states={}
 for _,s in ipairs({"Normal","Pushed","Disabled","Highlight"})do
  local t=Texture(s);b.states[s]=t
  b["Get"..s.."Texture"]=function()return t end
 end
 b.GetName=function()return name end
 b.GetButtonState=function(self)return self.state end
 b.HookScript=function()end
 b.SetNormal=function()end;b.SetPushed=function()end;b.UpdateMicroButton=function()end
 for _,m in ipairs({"SetNormalAtlas","SetPushedAtlas","SetDisabledAtlas","SetHighlightAtlas"})do b[m]=function()end end
 return b
end
local NAMES={"CharacterMicroButton","PlayerSpellsMicroButton","QuestLogMicroButton","MainMenuMicroButton","HelpMicroButton"}
local buttons={}
for i,name in ipairs(NAMES)do buttons[i]=Button(name);_G[name]=buttons[i]end

hooksecurefunc=function(t,key,fn)
 if type(t)=="string"then fn=key;key=t;t=_G end
 local old=t[key];t[key]=function(...)if old then old(...)end;fn(...)end
end
local frames={}
CreateFrame=function()
 local f={events={}}
 function f:RegisterEvent(e)self.events[e]=true end
 function f:SetScript(kind,fn)self[kind]=fn end
 frames[#frames+1]=f;return f
end
LoadMicroButtonTextures=function()end
UnitIsPlayer=function()return false end

local E={modules={},Classic={},settings={enabled=true,darkMode=true,darkMenuBar=true,darkModeDarkness=90}}
function E:GetSetting(key)return self.settings[key]end
local ns=E.Classic
ns.SetTex=function()end;ns.SetButtonTex=function()end
assert(loadfile("Core/Appearance.lua"))("EraUI",E)
assert(loadfile("Classic/BarSkins.lua"))("EraUI",E)

local function Sets()
 local n=0
 for _,b in ipairs(buttons)do n=n+b.Background.sets+b.PushedBackground.sets end
 return n
end
local function Untouched(label)
 for _,b in ipairs(buttons)do
  for s,t in pairs(b.states)do equal(t.sets,0,label..": "..b.name.." "..s.." texture never tinted")end
 end
end
local function AllAt(r,label)
 for _,b in ipairs(buttons)do
  equal(Near(b.Background.colour[1],r)and Near(b.PushedBackground.colour[1],r),true,label..": "..b.name)
 end
end

-- Nothing before you're in the world; then every button at once.
equal(Sets(),0,"nothing tinted while loading")
local watch
for _,f in ipairs(frames)do if f.events.PLAYER_ENTERING_WORLD then watch=f end end
equal(watch~=nil and type(watch.OnEvent),"function","waits for the world")
watch.OnEvent(watch,"PLAYER_ENTERING_WORLD")
AllAt(.10,"Darkness 90: frames near black")
equal(Near(buttons[1].Background.colour[3],.10*48/42),true,"keeping Dark Mode's slight blue")
Untouched("in the world")

-- A pass with nothing new sets nothing.
local before=Sets()
ns.RefreshDarkMenuBar();watch.OnEvent(watch,"PLAYER_ENTERING_WORLD")
equal(Sets(),before,"nothing set again when nothing changed")

-- The Darkness slider re-tints at once, through RefreshDarkness.
E.settings.darkModeDarkness=58;ns.RefreshDarkness()
AllAt(.42,"Darkness 58: Dark Mode's own grey")

-- The game reloading a button's art paints it again, even unchanged.
before=Sets()
LoadMicroButtonTextures(buttons[2],"SpellbookAbilities")
equal(Sets(),before+2,"its art reloaded: both frames painted again")

-- The tick off: white again, then left alone.
E.settings.darkMenuBar=false;ns.RefreshDarkMenuBar()
AllAt(1,"tick off: as the game draws them")
before=Sets();ns.RefreshDarkMenuBar();LoadMicroButtonTextures(buttons[1],"Character")
equal(Sets(),before,"off: never touched again")
E.settings.darkMenuBar=true;ns.RefreshDarkMenuBar()
AllAt(.42,"tick back on")

-- Dark Mode off (after a reload) or EraUI off: as the game draws them.
E.settings.darkMode=false;ns.RefreshDarkMenuBar()
AllAt(1,"Dark Mode off")
E.settings.darkMode=true;E.settings.enabled=false;ns.RefreshDarkMenuBar()
AllAt(1,"EraUI off")
E.settings.enabled=true;ns.RefreshDarkMenuBar()

-- A button wearing the classic art is left to it, and darkened again after.
local quest=buttons[3]
ns.SkinMicroButton(quest)
equal(Near(quest.Background.colour[1],1),true,"classic art: its frame back to white (the classic look hides it)")
before=Sets();ns.RefreshDarkMenuBar()
equal(Sets(),before,"classic art: left alone by later passes")
ns.UnskinMicroButton(quest)
equal(Near(quest.Background.colour[1],.42)and Near(quest.PushedBackground.colour[1],.42),true,"back to the modern art: dark again")
Untouched("after the classic art came and went")

-- Buttons the game doesn't have are skipped without errors.
_G.HelpMicroButton=nil;ns.RefreshDarkMenuBar()

print("Dark menu bar checks passed: "..checks.." assertions.")
