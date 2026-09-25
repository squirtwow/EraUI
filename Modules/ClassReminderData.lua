local _,E=...
-- Ordered Classic spell ranks. Learned rank and names are resolved by the client.
E.ReminderSpells={
 WARRIOR={
  {key="shout",name="Battle Shout",self=true,ids={6673,5242,6192,11549,11550,11551,25289}},
 },
 DRUID={
  {key="mark",name="Mark of the Wild",ids={1126,5232,6756,5234,8907,9884,9885},auras={21849,21850}},
  {key="thorns",name="Thorns",ids={467,782,1075,8914,9756,9910}},
  {key="gift",name="Gift of the Wild",ids={21849,21850},auras={1126,5232,6756,5234,8907,9884,9885},reagent=17021},
 },
 PRIEST={
  {key="fortitude",name="Fortitude",ids={1243,1244,1245,2791,10937,10938},auras={21562,21564}},
  {key="spirit",name="Divine Spirit",ids={14752,14818,14819,27841},auras={27681}},
  {key="shadow",name="Shadow Protection",ids={976,10957,10958},auras={27683}},
  {key="inner",name="Inner Fire",self=true,ids={588,7128,602,1006,10951,10952}},
  {key="prayerFortitude",name="Prayer of Fortitude",ids={21562,21564},auras={1243,1244,1245,2791,10937,10938}},
  {key="prayerSpirit",name="Prayer of Spirit",ids={27681},auras={14752,14818,14819,27841}},
  {key="prayerShadow",name="Prayer of Shadow Protection",ids={27683},auras={976,10957,10958}},
 },
 PALADIN={
  {key="might",name="Blessing of Might",blessing=true,ids={19740,19834,19835,19836,19837,19838,25291},auras={25782,25916}},
  {key="wisdom",name="Blessing of Wisdom",blessing=true,ids={19742,19850,19852,19853,19854,25290},auras={25894,25918}},
  {key="kings",name="Blessing of Kings",blessing=true,ids={20217},auras={25898}},
  {key="salvation",name="Blessing of Salvation",blessing=true,ids={1038},auras={25895}},
  {key="light",name="Blessing of Light",blessing=true,ids={19977,19978,19979},auras={25890}},
  {key="sanctuary",name="Blessing of Sanctuary",blessing=true,ids={20911,20912,20913,20914},auras={25899}},
  {key="greaterMight",name="Greater Blessing of Might",blessing=true,ids={25782,25916},auras={19740,19834,19835,19836,19837,19838,25291}},
  {key="greaterWisdom",name="Greater Blessing of Wisdom",blessing=true,ids={25894,25918},auras={19742,19850,19852,19853,19854,25290}},
  {key="greaterKings",name="Greater Blessing of Kings",blessing=true,ids={25898},auras={20217}},
  {key="greaterSalvation",name="Greater Blessing of Salvation",blessing=true,ids={25895},auras={1038}},
  {key="greaterLight",name="Greater Blessing of Light",blessing=true,ids={25890},auras={19977,19978,19979}},
  {key="greaterSanctuary",name="Greater Blessing of Sanctuary",blessing=true,ids={25899},auras={20911,20912,20913,20914}},
 },
 WARLOCK={
  {key="healthstone",name="Create Healthstone",kind="healthstone",ids={6201,6202,5699,11729,11730},items={5512,5511,5509,5510,9421,19004,19005,19006,19007,19008,19009,19010,19011,19012,19013}},
  {key="soulstone",name="Create Soulstone",kind="soulstone",ids={693,20752,20755,20756,20757},items={5232,16892,16893,16895,16896},auras={20707,20762,20763,20764,20765}},
 },
 SHAMAN={
  {key="lightning",name="Lightning Shield",self=true,ids={324,325,905,945,8134,10431,10432}},
  {key="rockbiter",name="Rockbiter Weapon",kind="imbue",self=true,ids={8017,8018,8019,10399,16314,16315,16316}},
  {key="flametongue",name="Flametongue Weapon",kind="imbue",self=true,ids={8024,8027,8030,16339,16341,16342}},
  {key="frostbrand",name="Frostbrand Weapon",kind="imbue",self=true,ids={8033,8038,10456,16355,16356}},
  {key="windfury",name="Windfury Weapon",kind="imbue",self=true,ids={8232,8235,10486,16362}},
 },
}
