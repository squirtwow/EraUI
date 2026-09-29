local _,E=...
-- One entry per reminder. text is the big alert word; dynamic names use the
-- learned spell instead. kind: aura | pet | petDead | item | imbue | totems | shards
--   ids       learned ranks (highest learned supplies the icon)
--   requires  at least one of these spells must be learned
--   auras     extra aura ids that also satisfy the buff
--   group     also check party/raid when the group option is on
--   groupOnly only applies while you are in a group
--   self      only ever check yourself
--   off       reminder starts switched off
--   dynamic   the alert word comes from the learned spell
--   color     optional text colour, otherwise the class colour
--   weapon    which hand an imbue or poison reminder watches
--   items     products counted in bags (item kind) or required (aura kinds)
--   minLevel  level required before the reminder applies
--   nameMatch accept any aura whose name contains this text
--   choices   pick which spell is tracked (Advanced cycle button)
--   subgroup  party-only effects do not check other raid subgroups
--   mana      skip warriors and rogues, including when druids are shapeshifted
--   anyTarget one protected group member satisfies this reminder
--   missingOnly leave dead hunter pets to their separate Revive Pet reminder
--   castIds   preferred learned spell for clicks when a choice is set to Any
--   noCast    informational only, even when reminder clicking is enabled
--   reagentIds group versions that need a reagent (Greater Blessings, Prayer of
--             Fortitude and the like): they count as the buff, but clicks, icons
--             and alert names use the single-target ranks
--   reagentItems the reagent each group version needs (spell id = item id): with
--             it in your bags a click casts the group version; paladins have
--             none, so their clicks always cast the normal blessing
--   power     what the spell costs when it isn't mana, for "Not enough ..."
-- Demon family IDs independently checked in CreatureFamily, build 1.60.1.70009.
-- Spell IDs are Forever's own (same build); Tools/TestClassReminders.lua audits
-- them. Forever is level 60 content, so later pets and totems (Water Elemental,
-- Felguard, Fire and Earth Elemental Totem) and Blessing of Sanctuary, which it
-- lacks, are left out.
E.ReminderSpells={
 WARRIOR={
   {key="battleShout",text="BATTLE SHOUT!",kind="aura",group=true,subgroup=true,power="rage",ids={6673,5242,6192,11549,11550,11551,25289}},
 },
 PALADIN={
  {key="blessing",text="BLESSING!",kind="aura",group=true,choiceLabel="Blessing",
   ids={19740,19834,19835,19836,19837,19838,25291,25782,25916,19742,19850,19852,19853,19854,25290,25894,25918,20217,25898,1038,25895,19977,19978,19979,25890},
   reagentIds={25782,25916,25894,25918,25898,25895,25890},
   choices={
    {key="any",name="Any blessing"},
    {key="might",name="Blessing of Might",ids={19740,19834,19835,19836,19837,19838,25291,25782,25916}},
     {key="wisdom",name="Blessing of Wisdom",mana=true,ids={19742,19850,19852,19853,19854,25290,25894,25918}},
    {key="kings",name="Blessing of Kings",ids={20217,25898}},
    {key="salvation",name="Blessing of Salvation",ids={1038,25895}},
    {key="light",name="Blessing of Light",ids={19977,19978,19979,25890}},
   }},
  -- Seal and aura clicks cast the last spell listed that you know, so the
  -- Forever-only Seal of Fury leads and new auras sit before Shadow Resistance.
  {key="seal",text="SEAL!",kind="aura",self=true,off=true,ids={1311649,1311656,20163,20419,20421,20422,20423,20154,21084,20162,20375,20915,20918,20919,20920,20305,20306,20307,20308,21082,20164,20165,20166,20356,20357,20287,20288,20289,20290,20291,20292,20293,20347,20348,20349}},
  {key="aura",text="AURA!",kind="aura",self=true,off=true,ids={465,10290,643,10291,1032,10292,10293,7294,10298,10299,10300,10301,19746,19888,19897,19898,19891,19899,19900,19876,19895,19896}},
 },
 HUNTER={
    {key="pet",text="SUMMON PET!",kind="pet",missingOnly=true,color={1,.36,.3},icon="Interface\\Icons\\Ability_Hunter_BeastCall",minLevel=10,ids={883}},
    {key="petDead",text="PET DEAD!",kind="petDead",color={1,.36,.3},icon="Interface\\Icons\\Ability_Hunter_BeastSoothe",minLevel=10,ids={982}},
  {key="aspect",text="ASPECT!",kind="aura",self=true,choiceLabel="Aspect",nameMatch="Aspect of",
   ids={13163,13165,14318,14319,14320,14321,14322,25296,5118,13159,13161,1299445,1299446,1299447,20043,20190},
   castIds={13163,13165,14318,14319,14320,14321,14322,25296},
   choices={
    {key="any",name="Any aspect"},
    {key="hawk",name="Aspect of the Hawk",ids={13165,14318,14319,14320,14321,14322,25296}},
    {key="monkey",name="Aspect of the Monkey",ids={13163}},
    {key="cheetah",name="Aspect of the Cheetah",ids={5118}},
    {key="pack",name="Aspect of the Pack",ids={13159}},
    {key="beast",name="Aspect of the Beast",ids={13161,1299445,1299446,1299447}},
    {key="wild",name="Aspect of the Wild",ids={20043,20190}},
   }},
   {key="trueshot",text="TRUESHOT AURA!",kind="aura",group=true,subgroup=true,ids={1299346,1299348,19506,20905,20906}},
 },
 ROGUE={
  {key="poisonMain",text="POISON: MAIN HAND!",kind="imbue",weapon="main",color={.52,1,.4},icon="Interface\\Icons\\Trade_BrewPoison",minLevel=20},
  {key="poisonOff",text="POISON: OFF HAND!",kind="imbue",weapon="off",off=true,color={.52,1,.4},icon="Interface\\Icons\\Trade_BrewPoison",minLevel=20},
 },
 PRIEST={
  {key="fortitude",text="FORTITUDE!",kind="aura",group=true,dynamic=true,ids={1243,1244,1245,2791,10937,10938,21562,21564},reagentIds={21562,21564},reagentItems={[21562]=17029,[21564]=17029}},
  {key="inner",text="INNER FIRE!",kind="aura",self=true,ids={588,7128,602,1006,10951,10952}},
  {key="shadow",text="SHADOW PROTECTION!",kind="aura",group=true,off=true,dynamic=true,ids={976,10957,10958,27683},reagentIds={27683},reagentItems={[27683]=17029}},
   {key="spirit",text="DIVINE SPIRIT!",kind="aura",group=true,mana=true,off=true,dynamic=true,ids={14752,14818,14819,27841,27681},reagentIds={27681},reagentItems={[27681]=17029}},
 },
 SHAMAN={
  {key="shield",text="LIGHTNING SHIELD!",kind="aura",self=true,ids={324,325,905,945,8134,10431,10432}},
  {key="imbue",text="WEAPON IMBUE!",kind="imbue",weapon="main",choiceLabel="Imbue",
   ids={8017,8018,8019,10399,16314,16315,16316,8024,8027,8030,16339,16341,16342,8033,8038,10456,16355,16356,8232,8235,10486,16362},
   choices={
    {key="any",name="Any imbue"},
    {key="rockbiter",name="Rockbiter Weapon",ids={8017,8018,8019,10399,16314,16315,16316}},
    {key="flametongue",name="Flametongue Weapon",ids={8024,8027,8030,16339,16341,16342}},
    {key="frostbrand",name="Frostbrand Weapon",ids={8033,8038,10456,16355,16356}},
    {key="windfury",name="Windfury Weapon",ids={8232,8235,10486,16362}},
   }},
   {key="totems",text="NO TOTEMS!",kind="totems",requires={8071,2484,3599,5394},icon="Interface\\Icons\\Spell_Nature_StoneSkinTotem"},
   {key="windfuryTotem",text="WINDFURY TOTEM!",kind="totems",off=true,ids={8512,10613,10614}},
 },
 MAGE={
   {key="intellect",text="ARCANE INTELLECT!",kind="aura",group=true,mana=true,dynamic=true,ids={1459,1460,1461,10156,10157,23028},reagentIds={23028},reagentItems={[23028]=17020}},
  {key="armor",text="ARMOR!",kind="aura",self=true,off=true,ids={168,7300,7301,7302,7320,10219,10220,6117,22782,22783}},
 },
 WARLOCK={
   {key="pet",text="SUMMON PET!",kind="pet",color={1,.36,.3},icon="Interface\\Icons\\Spell_Shadow_SummonImp",choiceLabel="Demon",ids={688,697,712,713,691},
   choices={
    {key="any",name="Any demon"},
     {key="imp",name="Summon Imp",ids={688},family=23},
     {key="voidwalker",name="Summon Voidwalker",ids={697},family=16},
     {key="succubus",name="Summon Succubus",ids={712},family=17},
     -- No family yet: CreatureFamily has Incubus 302, but no game data says the
     -- summoned Incubus uses it, so any living demon counts for this choice.
     {key="incubus",name="Summon Incubus",ids={713}},
     {key="felhunter",name="Summon Felhunter",ids={691},family=15},
   }},
  {key="healthstone",text="CREATE HEALTHSTONE!",kind="item",color={.5,1,.5},icon="Interface\\Icons\\INV_Stone_04",ids={6201,6202,5699,11729,11730},items={5512,5511,5509,5510,9421,19004,19005,19006,19007,19008,19009,19010,19011,19012,19013}},
  {key="soulstone",text="CREATE SOULSTONE!",kind="item",color={.78,.58,1},icon="Interface\\Icons\\Spell_Shadow_SoulGem",ids={693,20752,20755,20756,20757},items={5232,16892,16893,16895,16896}},
   {key="soulstoneApply",text="SOULSTONE!",kind="aura",group=true,anyTarget=true,off=true,noCast=true,color={.78,.58,1},icon="Interface\\Icons\\Spell_Shadow_SoulGem",ids={693,20752,20755,20756,20757},auras={20707,20762,20763,20764,20765},items={5232,16892,16893,16895,16896}},
  {key="shards",text="LOW SOUL SHARDS!",kind="shards",color={.78,.58,1},icon="Interface\\Icons\\INV_Misc_Gem_Amethyst_02",minLevel=10},
 },
 DRUID={
  {key="mark",text="MARK OF THE WILD!",kind="aura",group=true,ids={1126,5232,6756,5234,8907,9884,9885,21849,21850},reagentIds={21849,21850},reagentItems={[21849]=17021,[21850]=17026}},
  {key="thorns",text="THORNS!",kind="aura",self=true,ids={467,782,1075,8914,9756,9910}},
 },
}
