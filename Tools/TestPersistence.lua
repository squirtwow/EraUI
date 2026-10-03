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
    -- Model the Classic loader rebinding its namespace after the early reset.
    local classicLoader=CreateFrame("Frame")
    classicLoader:RegisterEvent("ADDON_LOADED")
    classicLoader:SetScript("OnEvent",function(_,_,name)
        if name=="EraUI" and E.Persistence.finishingReset then
            E.Classic.db=EraUIClassicDB
            E.Classic.db.erauiMigrated=true;E.Classic.db.erauiSettingsMenuMigrated=true
        end
    end)
    assert(loadfile("Core/Integration.lua"))("EraUI",E)
    assert(loadfile("Modules/ClassTools.lua"))("EraUI",E)
    assert(loadfile("Modules/ClassReminderData.lua"))("EraUI",E)
    assert(loadfile("Modules/ClassReminderPoisons.lua"))("EraUI",E)
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
local E,flush,fire=Session({reminderSize=3,reminderChoice_HUNTER_aspect=13165,reminderLast_PALADIN_blessing=19742,
    reminderChoice_PALADIN_seal=20165,reminderLast_PALADIN_aura=19746,reminderLimit_HUNTER_petHealth=45,reminder_WARLOCK_petHealth=true,reminderLimit_WARLOCK_petHealth="55",reminderPX_HUNTER_pet=-165.25,reminderPY_HUNTER_pet=93.125,reminderSpotVersion=2,
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
EraUIDB.reminderClickable=true
EraUIDB.reminderCombatClick=true
EraUIDB.reminder_HUNTER_petDead=false
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
equal(EraUIDB.reminderLast_PALADIN_blessing,19742,"the blessing cast last survives")
equal(EraUIDB.reminderChoice_PALADIN_seal,20165,"the picked seal survives")
equal(EraUIDB.reminderLast_PALADIN_aura,19746,"the aura cast last survives")
equal(EraUIDB.reminderLimit_HUNTER_petHealth,45,"the PET LOW HEALTH! limit survives")
equal(EraUIDB.reminder_WARLOCK_petHealth,true,"PET LOW HEALTH! switched on survives")
equal(EraUIDB.reminderLimit_WARLOCK_petHealth,nil,"a limit that is not a number is not backed up")
equal(EraUIDB.reminderPX_HUNTER_pet,-165.25,"negative fractional x survives")
equal(EraUIDB.reminderPY_HUNTER_pet,93.125,"fractional y survives")
equal(EraUIDB.reminderSpotVersion,2,"migration marker survives")
equal(EraUIDB.reminderGroup,false,"group false survives")
equal(EraUIDB.reminderClickable,true,"optional reminder clicks survive missing SavedVariables")
equal(EraUIDB.reminderCombatClick,true,"pet reminder clicks in combat survive missing SavedVariables")
equal(EraUIDB.reminder_HUNTER_petDead,false,"pet-dead reminder opt-out survives")
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
EraUIDB.reminderClickable=false
E:SetSetting("cursorRingSize",48)
E.Classic.MirrorSave();flush()
E,flush,fire=Session({reminderPX_HUNTER_pet=999,cursorRingSize=99})
equal(EraUIDB.reminderPX_HUNTER_pet,nil,"deleted positions stay deleted")
equal(EraUIDB.cursorRingSize,48,"reset default beats stale SavedVariables")
equal(EraUIDB.reminderClickable,false,"disabled reminder clicks stay disabled")

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
-- Dark Aura Borders: on by default (it only shows in Dark Mode, so choosing
-- Dark Mode gives it), applied live, and a switch-off is never undone.
equal(E.settingDefaults.darkAuraBorders,true,"Dark Aura Borders on by default")
equal(E.reloadSettings.darkAuraBorders,nil,"Dark Aura Borders applies live, not on reload")
-- Saved before the option existed (1.2.2): SavedVariables and backup lack it.
E:SetSetting("darkAuraBorders",nil);E:SaveSettings();flush()
local older=copy(EraUIDB)
equal(older.darkAuraBorders,nil,"a save from before the option")
E,flush,fire=Session(older)
equal(EraUIDB.darkAuraBorders,true,"an older save gets Dark Aura Borders on")
flush()
E:SetSetting("darkAuraBorders",nil);E:SaveSettings();flush()
E,flush,fire=Session()
equal(EraUIDB.darkAuraBorders,true,"an older backup without SavedVariables gets it on too")
flush()
-- Switched off by the player: kept off, with or without SavedVariables.
E:SetSetting("darkAuraBorders",false);E:SaveSettings();flush()
E,flush,fire=Session(copy(EraUIDB))
equal(EraUIDB.darkAuraBorders,false,"a switched-off Dark Aura Borders stays off")
flush()
E,flush,fire=Session()
equal(EraUIDB.darkAuraBorders,false,"and stays off when SavedVariables are lost")
flush()
E:SetSetting("darkAuraBorders",true);E:SaveSettings();flush()
E,flush,fire=Session()
equal(EraUIDB.darkAuraBorders,true,"switched back on, it survives missing SavedVariables")
flush()
-- Aura Shadows: the same (on by default, it only shows with Dark Mode and
-- Dark Aura Borders), and a switch-off is never undone.
equal(E.settingDefaults.darkAuraShadows,true,"Aura Shadows on by default")
equal(E.reloadSettings.darkAuraShadows,nil,"Aura Shadows applies live, not on reload")
E:SetSetting("darkAuraShadows",nil);E:SaveSettings();flush()
older=copy(EraUIDB)
equal(older.darkAuraShadows,nil,"a save from before Aura Shadows")
E,flush,fire=Session(older)
equal(EraUIDB.darkAuraShadows,true,"an older save gets Aura Shadows on")
equal(EraUIDB.darkAuraBorders,true,"and keeps its Dark Aura Borders")
flush()
E:SetSetting("darkAuraShadows",nil);E:SaveSettings();flush()
E,flush,fire=Session()
equal(EraUIDB.darkAuraShadows,true,"an older backup without SavedVariables gets Aura Shadows on too")
flush()
E:SetSetting("darkAuraShadows",false);E:SaveSettings();flush()
E,flush,fire=Session(copy(EraUIDB))
equal(EraUIDB.darkAuraShadows,false,"a switched-off Aura Shadows stays off")
flush()
E,flush,fire=Session()
equal(EraUIDB.darkAuraShadows,false,"and stays off when SavedVariables are lost")
flush()
E:SetSetting("darkAuraShadows",true);E:SaveSettings();flush()
E,flush,fire=Session()
equal(EraUIDB.darkAuraShadows,true,"Aura Shadows switched back on survives missing SavedVariables")
flush()
-- Class-coloured Tooltips: the same.
equal(E.settingDefaults.tooltipClassColours,false,"Class-coloured Tooltips off by default")
equal(E.reloadSettings.tooltipClassColours,nil,"Class-coloured Tooltips applies live, not on reload")
E:SetSetting("tooltipClassColours",true);flush()
E,flush,fire=Session()
equal(EraUIDB.tooltipClassColours,true,"Class-coloured Tooltips survives missing SavedVariables")
flush()
-- Bag Item Levels: the same.
equal(E.settingDefaults.bagItemLevels,false,"Bag Item Levels off by default")
equal(E.reloadSettings.bagItemLevels,nil,"Bag Item Levels applies live, not on reload")
E:SetSetting("bagItemLevels",true);flush()
E,flush,fire=Session()
equal(EraUIDB.bagItemLevels,true,"Bag Item Levels survives missing SavedVariables")
flush()
-- Character Item Levels: the same.
equal(E.settingDefaults.characterItemLevels,false,"Character Item Levels off by default")
equal(E.reloadSettings.characterItemLevels,nil,"Character Item Levels applies live, not on reload")
E:SetSetting("characterItemLevels",true);flush()
E,flush,fire=Session()
equal(EraUIDB.characterItemLevels,true,"Character Item Levels survives missing SavedVariables")
flush()
-- AFK Screen: on by default now, and a choice already saved is kept, with or
-- without SavedVariables.
equal(E.settingDefaults.afkScreen,true,"AFK Screen on by default")
equal(E.reloadSettings.afkScreen,nil,"AFK Screen applies live, not on reload")
E:SetSetting("afkScreen",nil);E:SaveSettings();flush()
E,flush,fire=Session(copy(EraUIDB))
equal(EraUIDB.afkScreen,true,"a save without the AFK Screen gets it on")
flush()
E:SetSetting("afkScreen",false);E:SaveSettings();flush()
E,flush,fire=Session(copy(EraUIDB))
equal(EraUIDB.afkScreen,false,"a saved off AFK Screen stays off")
flush()
E,flush,fire=Session()
equal(EraUIDB.afkScreen,false,"and stays off when SavedVariables are lost")
flush()
-- 1.3.0 saved AFK Screen off for everyone while it was Coming soon: the
-- defaults fill, the backup and the old mirror all hold false, with no marker.
-- It is switched on once, then a switch-off sticks.
local old130={erauiMigrated=true,erauiSettingsMenuMigrated=true,eraui_afkScreen=false}
E:SetSetting("afkScreen",false);E:SetSetting("afkScreenVersion",nil);E:SaveSettings();flush()
local v130=copy(EraUIDB)
equal(v130.afkScreen==false and v130.afkScreenVersion==nil,true,"a 1.3.0 save: AFK Screen off, no marker")
E,flush,fire=Session(v130,nil,copy(old130))
equal(EraUIDB.afkScreen,true,"a 1.3.0 save gets the AFK Screen switched on")
equal(EraUIDB.afkScreenVersion,2,"once: the switch-on is marked")
flush()
E,flush,fire=Session()
equal(EraUIDB.afkScreen==true and EraUIDB.afkScreenVersion==2,true,"the switch-on and its marker survive missing SavedVariables")
flush()
E:SetSetting("afkScreen",false);E:SaveSettings();flush()
E,flush,fire=Session(copy(EraUIDB),nil,copy(old130))
equal(EraUIDB.afkScreen,false,"switched off after that, it stays off")
flush()
E,flush,fire=Session()
equal(EraUIDB.afkScreen,false,"and stays off when SavedVariables are lost")
flush()
-- A 1.3.0 backup alone, with SavedVariables lost, is switched on once too.
E:SetSetting("afkScreenVersion",nil);E:SaveSettings();flush()
E,flush,fire=Session()
equal(EraUIDB.afkScreen==true and EraUIDB.afkScreenVersion==2,true,"a 1.3.0 backup without SavedVariables gets the AFK Screen switched on")
flush()
E:SetSetting("afkScreen",false);E:SaveSettings();flush()
E,flush,fire=Session()
equal(EraUIDB.afkScreen,false,"and a switch-off after that sticks too")
flush()
E:SetSetting("afkScreen",true);E:SaveSettings();flush()
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
failWrite="^EraUIRecovery1Reset$"
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
equal(cvars.EraUIRecovery1Reset,"1","queued saves and logout retain authoritative reset request")
E,flush,fire=Session()
equal(EraUIDB.reminderSize,nil,"reset starts without custom reminder size")
equal(E.ClassTools.Options().mageWaterStacks,nil,"reset starts without tool quantities")
flush()
equal(cvars.EraUIRecovery1Reset,"","verified fresh snapshot completes reset")
-- Class icon portraits read the game's own switches (Options > Interface), never EraUIDB.
do
    local oldBool,oldEra=GetCVarBool,_G.EraUI
    GetCVarBool=function(name) return name=="ReplaceMyPlayerPortrait" end
    local P={};assert(loadfile("Core/Init.lua"))("EraUI",P)
    equal(P.cvarSettings.classIconPortraitMine,"ReplaceMyPlayerPortrait","mine maps to the game's switch")
    equal(P.cvarSettings.classIconPortraitOthers,"ReplaceOtherPlayerPortraits","others map to the game's switch")
    EraUIDB={classIconPortraitMine=false,classIconPortraitOthers=true}
    equal(P:GetSavedSetting("classIconPortraitMine"),true,"mine reads the game's setting, not EraUIDB")
    equal(P:GetSavedSetting("classIconPortraitOthers"),false,"others too")
    GetCVarBool,_G.EraUI=oldBool,oldEra
end
-- The new /era layout note (the reorganisation after 1.4.0): decided once per
-- account, 1 (show once) only for accounts that used an earlier EraUI, 0 for
-- fresh installs; backed up, so a dismissed note stays dismissed.
do
    local function Fresh()
        for k in pairs(cvars) do cvars[k]=nil end
        character,realm="Hunter","RealmOne"
    end
    local classic=function(extra)
        local db={erauiMigrated=true,erauiSettingsMenuMigrated=true}
        for k,v in pairs(extra or {}) do db[k]=v end
        return db
    end
    Fresh();E,flush,fire=Session({},{},classic())
    equal(EraUIDB.layoutNotice,0,"a fresh install never gets the new layout note")
    flush()
    E,flush,fire=Session()
    equal(EraUIDB.layoutNotice,0,"and it stays decided when SavedVariables are lost")
    flush()
    Fresh();E,flush,fire=Session({afkScreenVersion=2},{},classic())
    equal(EraUIDB.layoutNotice,1,"a 1.4.0 save gets the note once")
    equal(EraUIDB.afkScreenVersion,2,"the AFK marker is untouched")
    flush()
    E,flush,fire=Session()
    equal(EraUIDB.layoutNotice,1,"a waiting note survives lost SavedVariables")
    flush()
    E:SetSetting("layoutNotice",0);E:SaveSettings();flush()
    E,flush,fire=Session(copy(EraUIDB),nil,classic({updateNotesSeen="1.4.0"}))
    equal(EraUIDB.layoutNotice,0,"once put away it is never asked for again")
    flush()
    E,flush,fire=Session()
    equal(EraUIDB.layoutNotice,0,"not even when SavedVariables are lost")
    flush()
    Fresh();E,flush,fire=Session({},{},classic({updateNotesSeen="1.3.0"}))
    equal(EraUIDB.layoutNotice,1,"an account that saw earlier update notes gets it")
    flush()
    Fresh();E,flush,fire=Session({},{},classic({erauiWelcomeSeen=true}))
    equal(EraUIDB.layoutNotice,1,"an account that saw the welcome gets it")
    flush()
    Fresh();cvars.EraUIOnboarding="Hunter-RealmOne:110,2,5"
    E,flush,fire=Session({},{},classic())
    equal(EraUIDB.layoutNotice,1,"a character that finished setup before gets it")
    flush()
    -- Each sign of an earlier EraUI on its own is enough.
    Fresh();E,flush,fire=Session({},{},classic({erauiSetupComplete=true}))
    equal(EraUIDB.layoutNotice,1,"an account that finished setup gets it, with nothing else seen")
    flush()
    Fresh();cvars.EraUIOnboarding="Hunter-RealmOne:010,2,5"
    E,flush,fire=Session({},{},classic())
    equal(EraUIClassicCharDB.onboarding.welcomeSeen==false and EraUIClassicCharDB.onboarding.setupComplete,true,"a character with only setup finished")
    equal(EraUIDB.layoutNotice,1,"gets it")
    flush()
    Fresh();cvars.EraUIOnboarding="Hunter-RealmOne:100,0,"
    E,flush,fire=Session({},{},classic())
    equal(EraUIClassicCharDB.onboarding.welcomeSeen==true and EraUIClassicCharDB.onboarding.setupComplete==false,true,"a character that only saw the welcome")
    equal(EraUIDB.layoutNotice,1,"gets it")
    flush()
    Fresh();cvars.EraUIOnboarding="Hunter-RealmOne:000,0,"
    E,flush,fire=Session({},{},classic())
    equal(EraUIDB.layoutNotice,0,"a character record with nothing seen is a fresh install")
    flush()
    Fresh();E,flush,fire=Session({layoutNotice=1},{},classic())
    equal(EraUIDB.layoutNotice,1,"a waiting note is kept")
    flush()
    Fresh();E,flush,fire=Session({layoutNotice=0,afkScreenVersion=2},{},classic({updateNotesSeen="1.4.0"}))
    equal(EraUIDB.layoutNotice,0,"a decided 0 is never turned into 1")
    flush()
end
-- The Poison Reminders panel became the rogue's POISON! class reminder (after
-- 1.5.1). Its users keep poison alerts, once; the two old alerts become one;
-- the new switches and picks are backed up like the others.
do
    local function Fresh()
        for k in pairs(cvars) do cvars[k]=nil end
        character,realm="Hunter","RealmOne"
    end
    local classic=function(extra)
        local db={erauiMigrated=true,erauiSettingsMenuMigrated=true}
        for k,v in pairs(extra or {}) do db[k]=v end
        return db
    end
    equal(E.settingDefaults.poisonReminders,false,"the old switch is still known, so a backup of it is read")
    Fresh();E,flush,fire=Session({poisonReminders=true,classReminders=false,reminder_PRIEST_inner=true},{},classic({eraui_poisonReminders=true}))
    equal(EraUIDB.classReminders,true,"an old Poison Reminders user gets Class Reminders & Buffs on")
    equal(EraUIDB.reminder_ROGUE_poison,true,"with POISON! on")
    equal(EraUIDB.poisonReminders,false,"the old switch is spent")
    equal(E.Classic.db.eraui_poisonReminders==false and E.Classic.db.eraui_classReminders==true,true,"in the old mirror too")
    -- Class Reminders & Buffs is one switch for the whole account and was off,
    -- so every other class still shows nothing: each alert on by default goes
    -- off; ones off by default, and a choice already made, are left alone.
    local function OtherClasses()
        local on,off,untouched=0,0,0
        for class,defs in pairs(E.ReminderSpells) do
            if class~="ROGUE" then
                for _,def in ipairs(defs) do
                    local v=EraUIDB["reminder_"..class.."_"..def.key]
                    if v==nil then untouched=untouched+1 elseif v then on=on+1 else off=off+1 end
                end
            end
        end
        return on,off,untouched
    end
    local on,off,untouched=OtherClasses()
    equal(on.." on, "..off.." off, "..untouched.." untouched","1 on, 17 off, 9 untouched","the other classes' alerts")
    equal(EraUIDB.reminder_WARRIOR_battleShout==false and EraUIDB.reminder_HUNTER_pet==false and EraUIDB.reminder_WARLOCK_healthstone==false,true,
        "BATTLE SHOUT!, SUMMON PET! and CREATE HEALTHSTONE! go off")
    equal(EraUIDB.reminder_PALADIN_seal==nil and EraUIDB.reminder_HUNTER_petHealth==nil,true,"SEAL! and PET LOW HEALTH!, off by default, are left alone")
    equal(EraUIDB.reminder_PRIEST_inner,true,"INNER FIRE! switched on before stays on")
    flush()
    E,flush,fire=Session()
    equal(EraUIDB.classReminders==true and EraUIDB.reminder_ROGUE_poison==true and EraUIDB.poisonReminders==false,true,"the move survives missing SavedVariables")
    equal(EraUIDB.reminder_WARRIOR_battleShout,false,"and so do the other classes' alerts going off")
    flush()
    -- With Class Reminders & Buffs already on, every class keeps its alerts.
    Fresh();E,flush,fire=Session({poisonReminders=true,classReminders=true},{},classic())
    on,off,untouched=OtherClasses()
    equal(EraUIDB.reminder_ROGUE_poison==true and on+off==0,true,"Class Reminders & Buffs already on: POISON! on, every other class untouched")
    flush()
    Fresh();E,flush,fire=Session({poisonReminders=true,classReminders=false},{},classic({eraui_poisonReminders=true}))
    flush()
    E:SetSetting("classReminders",false);E:SaveSettings();flush()
    E,flush,fire=Session()
    equal(EraUIDB.classReminders,false,"Class Reminders & Buffs switched off after that stays off")
    flush()
    E,flush,fire=Session(copy(EraUIDB),nil,classic({eraui_poisonReminders=false,eraui_classReminders=false}))
    equal(EraUIDB.classReminders,false,"with SavedVariables too: it happens once")
    flush()
    -- A 1.5.1 backup alone, with SavedVariables lost, moves over too.
    Fresh();E,flush,fire=Session({},{},classic())
    E:SetSetting("poisonReminders",true);E:SaveSettings();flush()
    equal(EraUIDB.classReminders,false,"a 1.5.1 backup: Poison Reminders on, Class Reminders & Buffs off")
    E,flush,fire=Session()
    equal(EraUIDB.classReminders==true and EraUIDB.reminder_ROGUE_poison==true and EraUIDB.poisonReminders==false,true,"read from the backup alone, it moves over")
    flush()
    -- Without the old panel nothing changes.
    Fresh();E,flush,fire=Session({classReminders=false},{},classic())
    equal(EraUIDB.classReminders==false and EraUIDB.reminder_ROGUE_poison==nil,true,"no old panel: Class Reminders & Buffs left as it was")
    flush()
    -- The two old alerts: off only when both were. The main hand's spot is kept.
    Fresh();E,flush,fire=Session({reminder_ROGUE_poisonMain=false,reminder_ROGUE_poisonOff=false,
        reminderPX_ROGUE_poisonMain=40.5,reminderPY_ROGUE_poisonMain=-20,reminderPX_ROGUE_poisonOff=1,reminderPY_ROGUE_poisonOff=2},{},classic())
    equal(EraUIDB.reminder_ROGUE_poison,false,"both old poison alerts off: POISON! off")
    equal(EraUIDB.reminderPX_ROGUE_poison==40.5 and EraUIDB.reminderPY_ROGUE_poison==-20,true,"where the main hand's alert was dragged")
    local left=0
    for _,key in ipairs({"reminder_ROGUE_poisonMain","reminder_ROGUE_poisonOff","reminderPX_ROGUE_poisonMain","reminderPY_ROGUE_poisonMain","reminderPX_ROGUE_poisonOff","reminderPY_ROGUE_poisonOff"}) do
        if EraUIDB[key]~=nil then left=left+1 end
    end
    equal(left,0,"the old keys are cleared")
    flush()
    E,flush,fire=Session()
    equal(EraUIDB.reminder_ROGUE_poison==false and EraUIDB.reminderPX_ROGUE_poison==40.5,true,"that survives missing SavedVariables")
    equal(EraUIDB.reminder_ROGUE_poisonMain,nil,"and the old keys don't come back")
    flush()
    Fresh();E,flush,fire=Session({reminder_ROGUE_poisonMain=false,reminder_ROGUE_poisonOff=true},{},classic())
    equal(EraUIDB.reminder_ROGUE_poison,nil,"the off hand's alert on: POISON! stays on")
    flush()
    Fresh();E,flush,fire=Session({reminder_ROGUE_poisonOff=false},{},classic())
    equal(EraUIDB.reminder_ROGUE_poison,nil,"the main hand's alert on by default: POISON! stays on")
    flush()
    Fresh();E,flush,fire=Session({reminder_ROGUE_poisonMain=false},{},classic())
    equal(EraUIDB.reminder_ROGUE_poison,false,"the main hand's alert off, the off hand's left at its default (off): POISON! off")
    flush()
    Fresh();E,flush,fire=Session({reminder_ROGUE_poison=true,reminder_ROGUE_poisonMain=false},{},classic())
    equal(EraUIDB.reminder_ROGUE_poison,true,"a POISON! choice already made wins")
    equal(EraUIDB.reminder_ROGUE_poisonMain,nil,"and the old key still goes")
    flush()
    -- Old alerts that only the skinning layer's mirror remembers.
    Fresh();local mirror=classic({eraui_reminder_ROGUE_poisonMain=false,eraui_reminder_ROGUE_poisonOff=false})
    E,flush,fire=Session({},{},mirror)
    equal(EraUIDB.reminder_ROGUE_poison,false,"old alerts from the mirror move over too")
    equal(mirror.eraui_reminder_ROGUE_poisonMain==nil and mirror.eraui_reminder_ROGUE_poisonOff==nil,true,"and the mirror forgets them")
    flush()
    -- New switches and picks survive missing SavedVariables. The picks are
    -- each character's own.
    E:SetSetting("reminderPoisonClick",true)
    E.ClassTools.Options().poisonPickMain=2892;E.ClassTools.Options().poisonPickOff=3775
    EraUIDB.reminderPX_ROGUE_poison=12;EraUIDB.reminderPY_ROGUE_poison=-34;E:SaveSettings();flush()
    E,flush,fire=Session()
    equal(EraUIDB.reminderPoisonClick,true,"Click to apply poisons survives")
    equal(E.ClassTools.Options().poisonPickMain==2892 and E.ClassTools.Options().poisonPickOff==3775,true,"each hand's poison survives, for this character")
    equal(EraUIDB.poisonPickMain==nil and EraUIDB.reminderChoice_ROGUE_poisonMain==nil,true,"not as an account setting")
    equal(EraUIDB.reminderPX_ROGUE_poison==12 and EraUIDB.reminderPY_ROGUE_poison==-34,true,"POISON!'s spot survives")
    flush()
    character="Alt"
    E,flush,fire=Session()
    equal(E.ClassTools.Options().poisonPickMain==nil and EraUIDB.reminderPoisonClick==true,true,"another character keeps picks of its own, and the account's switches")
    character="Hunter"
    E,flush,fire=Session();flush()
    -- Nothing to move: nothing is saved for it.
    local saved=writes
    E,flush,fire=Session(copy(EraUIDB),nil,classic());flush()
    equal(writes,saved,"a settled account writes nothing at login")
end
print("Persistence recovery checks passed: " .. checks .. " assertions.")
