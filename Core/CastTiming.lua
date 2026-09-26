-- Public player cast timestamps use one clock and a stable channel scale.
local _,E=...
local T={};E.CastTiming=T
local function Public(v)return not(issecretvalue and issecretvalue(v))end
function T.Snapshot(previous,channel,name,startMS,endMS,spellID,fresh)
 if not Public(name)or type(name)~="string"or not Public(startMS)or not Public(endMS)or not Public(spellID)
  or type(startMS)~="number"or type(endMS)~="number"or endMS<=startMS then return end
 local total=(endMS-startMS)/1000
 local same=not fresh and previous and previous.channel==channel and previous.name==name
  and previous.spellID==spellID
 if channel and same and type(previous.total)=="number"then total=math.max(previous.total,total)end
 return {name=name,spellID=spellID,channel=channel,start=startMS/1000,finish=endMS/1000,total=total}
end
function T.Value(s,now)
 return math.max(0,math.min(s.total,s.channel and s.finish-now or now-s.start))
end
