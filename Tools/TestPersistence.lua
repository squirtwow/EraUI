-- Run from the addon directory. Loads real startup, integration and recovery code.
-- Models Forever losing SavedVariables while retaining addon CVars across logins.
local checks = 0
local function equal(actual, expected, label)
    checks = checks+1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k,v in pairs(value) do out[k]=copy(v) end; return out
end
local cvars, writes, registrations, messages = {}, 0, 0, {}
local failWrite, truncateWrite
local character, realm = "Hunter", "RealmOne"
local function Session(db, char, classic, lateIdentity)
    local frames, timers = {}, {}
    EraUIDB, EraUIClassicCharDB = db, char
    C_CVar = {
        GetCVar=function(name) return cvars[name] end,
        RegisterCVar=function(name, default)
            registrations=registrations+1
            -- Deliberately destructive, to verify read-before-register behaviour.
            cvars[name]=default
        end,
        SetCVar=function(name,value)
            writes=writes+1
            if failWrite and name:match(failWrite) then error("simulated write failure") end
            cvars[name]=(truncateWrite and name:match(truncateWrite)) and value:sub(1,30) or value
        end,
    }
    GetCVarBool=function() return false end
    UnitFullName=function() if not lateIdentity then return character, realm end end
    UnitName=function() return character end
    GetNormalizedRealmName=function() return realm end
    DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
    C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
    CreateFrame=function()
        local f={events={},scripts={}}
        function f:RegisterEvent(event) self.events[event]=true end
        function f:SetScript(event,fn) self.scripts[event]=fn end
        frames[#frames+1]=f; return f
    end
    local E={}
    assert(loadfile("Core/Init.lua"))("EraUI",E)
    assert(loadfile("Core/Persistence.lua"))("EraUI",E)
    E.Classic={DB_DEFAULTS={},TOGGLES={},db=classic or {
        erauiMigrated=true,erauiSettingsMenuMigrated=true,
    },OnForever=function() return true end,MirrorSave=function() end,QueueApply=function() end}
    assert(loadfile("Core/Integration.lua"))("EraUI",E)
    assert(loadfile("Modules/ClassTools.lua"))("EraUI",E)
    local function fire(event,...)
        for _,f in ipairs(frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end
        end
    end
    local function flush()
        local pending=timers; timers={}
        for _,fn in ipairs(pending) do fn() end
    end
    fire("ADDON_LOADED","EraUI")
    lateIdentity=false
    fire("PLAYER_LOGIN")
    return E,flush,fire
end

-- Existing SavedVariables and dynamic legacy booleans migrate without loss.
cvars.EraUICharSwing="Hunter:10;Other:01"
cvars.EraUIOnboarding="Hunter:110,1,12.13;Other:100,1,"
local E,flush,fire=Session({reminderSize=3,reminderChoice_HUNTER_aspect=13165,
    reminderPX_HUNTER_pet=-165.25,reminderPY_HUNTER_pet=93.125,reminderSpotVersion=2,
    mapPosition={x=-200.5,y=33.25},mapSize={w=800,h=530},profile="Text ;=: | utf8 café",
    resourceBarPositions={HUNTER={x=50,y=-10,width=200,height=22}},
    rewardProfiles={HUNTER=2},cursorRingSize=72,
}, {classTools={feedFish=true,feedLowest=false,feedPosition={x=160,y=-175,size=46},
    trainingGuide={entries={shot={name="Arcane Shot",rank="Rank 2",cost=120,level=12,
        requirements={["Arcane Shot (Rank 1)"]=false}}},trainer="Class trainer",updated="2026-09-26"}}}, {
    erauiMigrated=true,erauiSettingsMenuMigrated=true,
    eraui_reminderGroup=false,eraui_reminder_HUNTER_pet=false,
})
equal(EraUIDB.reminderGroup,false,"legacy group option recovered")
equal(EraUIDB.reminder_HUNTER_pet,false,"legacy individual option recovered")
equal(E:GetCharSetting("swingTimer"),true,"legacy swing flag imported")
equal(EraUIClassicCharDB.onboarding.setupComplete,true,"legacy onboarding imported")
equal(cvars.EraUICharSwing:find("Hunter:",1,true),nil,"old swing identity consumed")
equal(cvars.EraUIOnboarding:find("Hunter:",1,true),nil,"old onboarding identity consumed")
flush()
equal(type(cvars.EraUIRecovery1Head),"string","snapshot published")
local count=tonumber(cvars.EraUIRecovery1Head:match("^[AB]:(%d+):"))
equal(count>1,true,"account spans multiple small CVars")
local before=writes
E:SaveSettings();E:SaveSettings();flush()
equal(writes,before,"unchanged snapshot does not write")

-- Simulate a new login with BOTH SavedVariables files missing.
local registered=registrations
E,flush,fire=Session()
equal(registrations,registered,"existing CVars never re-registered at startup")
equal(EraUIDB.reminderSize,3,"size survives missing SavedVariables")
equal(EraUIDB.reminderChoice_HUNTER_aspect,13165,"choice survives")
equal(EraUIDB.reminderPX_HUNTER_pet,-165.25,"negative fractional x survives")
equal(EraUIDB.reminderPY_HUNTER_pet,93.125,"fractional y survives")
equal(EraUIDB.reminderSpotVersion,2,"migration marker survives")
equal(EraUIDB.reminderGroup,false,"group false survives")
equal(EraUIDB.reminder_HUNTER_pet,false,"individual false survives")
equal(EraUIDB.profile,"Text ;=: | utf8 café","strings round-trip")
equal(EraUIDB.mapSize.w,800,"map dimensions survive")
equal(EraUIDB.resourceBarPositions.HUNTER.width,200,"nested resource layout survives")
equal(EraUIDB.rewardProfiles.HUNTER,2,"reward profile survives")
equal(E.ClassTools.Options().feedLowest,false,"character preference false survives")
equal(E.ClassTools.Options().feedPosition.size,46,"feeding layout survives")
equal(E.ClassTools.Options().trainingGuide.entries.shot.cost,120,"trainer quote survives missing SavedVariables")
equal(E.ClassTools.Options().trainingGuide.entries.shot.requirements["Arcane Shot (Rank 1)"],false,"training prerequisite fits recovery depth and survives")
equal(EraUIClassicCharDB.onboarding.discoverTabs[12],true,"numeric table keys survive")
equal(E:GetCharSetting("rangedSwingTimer"),false,"swing false survives")
flush()

-- A reset to defaults must beat an older SavedVariables file and legacy mirror.
EraUIDB.reminderPX_HUNTER_pet=nil;EraUIDB.reminderPY_HUNTER_pet=nil
E:SetSetting("cursorRingSize",48)
E.Classic.MirrorSave();flush()
E,flush,fire=Session({reminderPX_HUNTER_pet=999,cursorRingSize=99})
equal(EraUIDB.reminderPX_HUNTER_pet,nil,"deleted positions stay deleted")
equal(EraUIDB.cursorRingSize,48,"reset default beats stale SavedVariables")

-- Same-name characters on different realms do not share tools or swing toggles.
flush(); realm="RealmTwo"
E,flush,fire=Session()
equal(E.ClassTools.Options().feedFish,nil,"new realm does not inherit tools")
equal(E.ClassTools.Options().trainingGuide,nil,"training offers remain character and realm specific")
equal(E:GetCharSetting("swingTimer"),false,"new realm does not inherit swing toggle")
equal(EraUIClassicCharDB.onboarding and EraUIClassicCharDB.onboarding.setupComplete,nil,"new realm has own onboarding")
E.ClassTools.Options().feedFish=false
E.ClassTools.Options().mageWaterStacks=4
E:SetCharSetting("rangedSwingTimer",true)
E:SetSetting("revealMap",true)
flush()
realm="RealmOne"
E,flush,fire=Session()
equal(E.ClassTools.Options().feedFish,true,"first realm tool options retained")
equal(E.ClassTools.Options().mageWaterStacks,nil,"second realm quantities isolated")
equal(E:GetCharSetting("swingTimer"),true,"first realm swing toggle retained")
equal(E:GetCharSetting("rangedSwingTimer"),false,"first realm ranged toggle retained")
equal(EraUIDB.revealMap,true,"account options shared between characters")
flush();realm="RealmTwo"
E,flush,fire=Session()
equal(E.ClassTools.Options().mageWaterStacks,4,"second realm supplies restored")
equal(E:GetCharSetting("rangedSwingTimer"),true,"second realm swing restored")
flush()

-- Settings are restored before module initialization and loaded visual snapshots.
E:SetSetting("darkMode",true);flush()
E,flush,fire=Session()
equal(E:GetSetting("darkMode"),true,"loaded visual choices use recovery")
flush()
before=writes
for size=50,70 do E:SetSetting("cursorRingSize",size) end
equal(writes,before,"slider changes queue instead of writing immediately")
flush()
local chunks=tonumber(cvars.EraUIRecovery1Head:match("^[AB]:(%d+):"))
equal(writes-before,chunks+1,"rapid changes publish one snapshot")

-- Truncated/interrupted chunk writes must never publish a partial snapshot.
local goodHead=cvars.EraUIRecovery1Head
local inactive=goodHead:sub(1,1)=="A" and "B" or "A"
truncateWrite="^EraUIRecovery1"..inactive.."1$"
E:SetSetting("reminderSize",1);flush()
equal(cvars.EraUIRecovery1Head,goodHead,"truncated write keeps old header")
truncateWrite=nil
E,flush,fire=Session()
equal(EraUIDB.reminderSize,3,"old complete snapshot survives truncation")
flush();goodHead=cvars.EraUIRecovery1Head
inactive=goodHead:sub(1,1)=="A" and "B" or "A"
failWrite="^EraUIRecovery1"..inactive.."2$"
E:SetSetting("reminderSize",1);flush()
equal(cvars.EraUIRecovery1Head,goodHead,"mid-write failure keeps old header")
failWrite=nil
E,flush,fire=Session()
equal(EraUIDB.reminderSize,3,"old snapshot survives interrupted write")
flush()
goodHead=cvars.EraUIRecovery1Head
failWrite="^EraUIRecovery1Head$"
E:SetSetting("reminderSize",1);flush()
equal(cvars.EraUIRecovery1Head,goodHead,"failed publication keeps old header")
equal(E.Persistence:Reset(),false,"failed reset reported")
equal(E.Persistence.resetting,nil,"failed reset leaves persistence running")
failWrite=nil
E,flush,fire=Session()
equal(EraUIDB.reminderSize,3,"failed publication keeps old settings")
flush()

-- Logout flushes direct table edits even when a queued save has not run.
E.ClassTools.Options().poisonPowder=75
EraUIDB.advancedCastBarPosition={x=35,y=-210,width=300,height=28}
fire("PLAYER_LOGOUT")
E,flush,fire=Session()
equal(E.ClassTools.Options().poisonPowder,75,"logout captures nested tool edit")
equal(EraUIDB.advancedCastBarPosition.width,300,"logout captures layout edit")
flush()

-- Corrupt recovery cannot partially apply data or destroy the existing backup.
local backup=copy(cvars)
cvars.EraUIRecovery1Head="A:999999:0"
local corruptHead=cvars.EraUIRecovery1Head
E,flush,fire=Session({reminderSize=2})
equal(EraUIDB.reminderSize,2,"corrupt header preserves SavedVariables")
flush();fire("PLAYER_LOGOUT")
equal(cvars.EraUIRecovery1Head,corruptHead,"corrupt backup not overwritten")
cvars=copy(backup)
local active=cvars.EraUIRecovery1Head:sub(1,1)
cvars["EraUIRecovery1"..active.."1"]="truncated"
E,flush,fire=Session({mapPosition={x=12,y=34}})
equal(EraUIDB.mapPosition.x,12,"bad checksum preserves SavedVariables")
equal(E.Persistence.blocked,true,"bad checksum blocks publishing")
cvars=copy(backup)

-- No character identity at ADDON_LOADED: restore at PLAYER_LOGIN instead.
E,flush,fire=Session(nil,nil,nil,true)
equal(E.Persistence.character,"Hunter-RealmTwo","late identity resolved")
equal(E.ClassTools.Options().mageWaterStacks,4,"late identity restores correct tools")
flush()

-- Reset invalidates recovery and a previously queued save cannot revive it.
E:SetSetting("reminderSize",1)
E.Persistence:Reset()
flush();fire("PLAYER_LOGOUT")
equal(cvars.EraUIRecovery1Head,"","reset prevents queued resurrection")
cvars.EraUICharSwing="";cvars.EraUIOnboarding=""
E,flush,fire=Session()
equal(EraUIDB.reminderSize,nil,"reset starts without custom reminder size")
equal(E.ClassTools.Options().mageWaterStacks,nil,"reset starts without tool quantities")
flush()
print("Persistence recovery checks passed: " .. checks .. " assertions.")
