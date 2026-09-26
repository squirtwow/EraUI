-- The actual slash command, both loaders, every settings mirror, a live module,
-- logout and the next load share this harness. CVars survive between sessions.
local checks = 0
local function Equal(actual, expected, label)
    checks=checks+1
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function Copy(t)
    if type(t)~="table" then return t end
    local copy={}; for k,v in pairs(t) do copy[k]=Copy(v) end; return copy
end
local cvars, combat, failWrite = {cameraDistanceMaxZoomFactor="1.9"}, false, nil
local messages, errors = {}, {}
local function Session(saved)
    local env=setmetatable({}, {__index=_G}); env._G=env
    env.EraUIDB=saved and Copy(saved.account)
    env.EraUIClassicDB=saved and Copy(saved.classic)
    env.EraUIClassicCharDB=saved and Copy(saved.character)
    env.StaticPopupDialogs={};env.SlashCmdList={}
    env.unpack=table.unpack or unpack
    env.InCombatLockdown=function() return combat end
    env.GetBuildInfo=function() return "1.60.1","70009","",16001 end
    env.GetCVarBool=function() return false end
    env.UnitName=function() return "Hunter" end
    env.UnitFullName=function() return "Hunter","Realm" end
    env.GetNormalizedRealmName=function() return "Realm" end
    env.geterrorhandler=function() return function(err) errors[#errors+1]=err;return err end end
    env.DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
    env.C_CVar={
        GetCVar=function(name) return cvars[name] end,
        RegisterCVar=function(name,value) cvars[name]=value end,
        SetCVar=function(name,value)
            if name==failWrite then error("simulated write failure: "..name) end
            cvars[name]=value
        end,
    }
    local frames,timers={},{}
    env.CreateFrame=function()
        local f={events={},scripts={}}
        function f:RegisterEvent(event) self.events[event]=true end
        function f:UnregisterEvent(event) self.events[event]=nil end
        function f:SetScript(event,fn) self.scripts[event]=fn end
        frames[#frames+1]=f;return f
    end
    env.C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
    local E={}
    local reloads=0
    env.ReloadUI=function()
        assert(not combat,"reset must not reload during combat")
        assert(cvars.EraUIRecovery1Reset=="1","reset request must be durable before reload")
        assert(E.Persistence.resetting,"saves must be frozen before reload")
        reloads=reloads+1
    end
    local function Load(path) assert(loadfile(path,"t",env))("EraUI",E) end
    Load("Core/Init.lua");Load("Core/Persistence.lua");Load("Classic/Core.lua")
    E.Classic.TOGGLES={}; E.Classic.FirstRun=function() end
    Load("Core/Integration.lua");Load("Modules/ClassTools.lua")
    Load("Modules/Convenience.lua");Load("Core/Commands.lua")
    local function Fire(event,...)
        for _,f in ipairs(frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
    end
    local function Flush()
        local pending=timers;timers={}
        for _,fn in ipairs(pending) do fn() end
    end
    Fire("ADDON_LOADED","EraUI");Fire("PLAYER_LOGIN")
    return {E=E,env=env,fire=Fire,flush=Flush,reset=function() env.SlashCmdList.ERAUI("reset") end,
        reloads=function() return reloads end,
        saved=function() return {account=Copy(env.EraUIDB),classic=Copy(env.EraUIClassicDB),character=Copy(env.EraUIClassicCharDB)} end}
end

local s=Session()
s.E:SetSetting("darkMode",true)
s.E:SetSetting("cursorRingSize",91)
s.E:SetCharSetting("swingTimer",true)
s.E.ClassTools.Options().mageWaterStacks=4
s.env.EraUIClassicCharDB.onboarding={welcomeSeen=true,setupComplete=true}
s.E.SaveCharOnboarding()
s.E.Classic.db.microScale=1.5;s.E.Classic.MirrorSave();s.flush()
local oldHead=cvars.EraUIRecovery1Head
local oldMirrors={classic=cvars.EraUIClassicSettings,swing=cvars.EraUICharSwing,onboarding=cvars.EraUIOnboarding}
local account,classic,char=s.env.EraUIDB,s.env.EraUIClassicDB,s.env.EraUIClassicCharDB

combat=true;s.reset()
Equal(s.reloads(),0,"combat reset does not reload")
Equal(cvars.EraUIRecovery1Reset,nil,"combat reset makes no durable request")
Equal(s.E.Persistence.resetting,nil,"combat reset does not suspend saves")
Equal(s.env.EraUIDB,account,"combat reset keeps account settings")
combat=false
failWrite="EraUIRecovery1Reset";s.reset()
Equal(s.reloads(),0,"failed reset request does not reload")
Equal(s.E.Persistence.resetting,nil,"failed reset request keeps persistence running")
Equal(cvars.EraUIRecovery1Head,oldHead,"failed request preserves recovery")
failWrite=nil

s.E:SetSetting("cursorRingSize",92) -- pending save when reset runs
oldMirrors.classic=cvars.EraUIClassicSettings
s.reset()
Equal(s.reloads(),1,"successful reset automatically reloads exactly once")
Equal(cvars.EraUIRecovery1Reset,"1","request verified in durable marker")
Equal(s.env.EraUIDB,account,"account table survives until reload")
Equal(s.E.db,account,"main alias remains valid")
Equal(s.E.Classic.db,classic,"Classic alias remains valid")
Equal(s.env.EraUIClassicCharDB,char,"open tool preferences remain valid")
Equal(s.E:GetSetting("cursorRingSize"),92,"current session remains coherent")
Equal(s.E:GetSetting("darkMode"),false,"loaded visual snapshot remains staged")
Equal(s.env.EraUIDB.darkMode,true,"saved visual request retained until reload")

-- Real callbacks that previously crashed, plus simulated open-window references.
s.E.modules.Convenience:Refresh()
s.fire("ACTIONBAR_SLOT_CHANGED");s.fire("UPDATE_BINDINGS")
local openWindow=function() return account.cursorRingSize,classic.microScale,char.classTools.mageWaterStacks end
local size,scale,stacks=openWindow()
Equal(size,92,"open settings callback still reads account")
Equal(scale,1.5,"open Classic callback still reads layout")
Equal(stacks,4,"open class-tool callback still reads character")
s.E:SaveCharSettings();s.E.SaveCharOnboarding();s.E.Classic.MirrorSave()
s.flush();s.fire("PLAYER_LOGOUT")
Equal(cvars.EraUIRecovery1Head,oldHead,"queued save and logout cannot rewrite snapshot")
Equal(cvars.EraUIClassicSettings,oldMirrors.classic,"Classic mirror frozen while reset pending")
Equal(cvars.EraUICharSwing,oldMirrors.swing,"swing mirror frozen while reset pending")
Equal(cvars.EraUIOnboarding,oldMirrors.onboarding,"onboarding mirror frozen while reset pending")
Equal(cvars.EraUIRecovery1Reset,"1","logout cannot cancel reset")

local stale=s.saved()
s=Session(stale) -- even old SavedVariables cannot override the reset request
Equal(s.E:GetSetting("cursorRingSize"),48,"reload applies account default")
Equal(s.E:GetSetting("darkMode"),false,"reload applies visual default")
Equal(s.E:GetSetting("tooltipSkin"),true,"tooltip reset default retained")
Equal(s.E:GetSetting("trainingGuide"),true,"guide reset default retained")
Equal(s.E.Classic.db.microScale,1,"reload applies Classic layout default")
Equal(s.E:GetCharSetting("swingTimer"),false,"reload clears character swing")
Equal(s.E.ClassTools.Options().mageWaterStacks,nil,"reload clears class-tool preference")
Equal(s.env.EraUIClassicCharDB.onboarding and s.env.EraUIClassicCharDB.onboarding.setupComplete,nil,"reload clears onboarding")
Equal(s.E.db,s.env.EraUIDB,"new account alias rebound correctly")
Equal(s.E.Classic.db,s.env.EraUIClassicDB,"new Classic alias rebound correctly")
Equal(cvars.EraUIRecovery1Reset,"1","request kept until fresh snapshot is complete")
s.flush()
Equal(cvars.EraUIRecovery1Reset,"","verified fresh snapshot completes reset")
s=Session(s.saved());s.flush()
Equal(s.E:GetSetting("cursorRingSize"),48,"subsequent login retains reset defaults")
Equal(s.E:GetCharSetting("swingTimer"),false,"old swing choice does not return")
Equal(s.E.ClassTools.Options().mageWaterStacks,nil,"old class tools do not return")

-- Each failed clearing operation must preserve the authoritative request.
for _,name in ipairs({"EraUIClassicSettings","EraUICharSwing","EraUIOnboarding","EraUIRecovery1Head"}) do
    s.E:SetSetting("cursorRingSize",79);s.flush();s.reset()
    cvars[name]=cvars[name]~="" and cvars[name] or "stale"
    failWrite=name
    local failed=Session(s.saved());failed.flush();failed.fire("PLAYER_LOGOUT")
    Equal(cvars.EraUIRecovery1Reset,"1","failed clear retains reset marker: "..name)
    Equal(failed.E.Persistence.resetting,true,"failed clear prevents saves: "..name)
    Equal(failed.env.EraUIDB~=nil,true,"failed clear keeps a usable settings table")
    failWrite=nil;s=Session(failed.saved());s.flush()
    Equal(s.E:GetSetting("cursorRingSize"),48,"reload retries failed clear: "..name)
    Equal(cvars.EraUIRecovery1Reset,"","successful retry completes reset")
end

s.reset()
s=Session(s.saved())
failWrite="EraUIRecovery1Head";s.flush()
Equal(cvars.EraUIRecovery1Reset,"1","failed default snapshot retains reset marker")
failWrite=nil;s=Session(s.saved());s.flush()
Equal(cvars.EraUIRecovery1Reset,"","next load finishes interrupted default snapshot")
s.reset();s=Session(s.saved())
failWrite="EraUIRecovery1Reset";s.flush()
Equal(s.E.Persistence.finishingReset,true,"failed marker clear remains retryable")
local freshHead=cvars.EraUIRecovery1Head
failWrite=nil;s.E:SaveSettings();s.flush()
Equal(cvars.EraUIRecovery1Reset,"","unchanged snapshot retries marker completion")
Equal(cvars.EraUIRecovery1Head,freshHead,"marker retry does not rewrite snapshot")
Equal(#errors,0,"no loader/module errors")
print("Reset lifecycle: "..checks.." assertions passed")
