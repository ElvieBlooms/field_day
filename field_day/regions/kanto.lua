-- Kanto events for Red, Blue and Yellow: swarms and the Bug-Catching Contest.
--
-- SWARMS. Each entry: map (map id), species (species id), levels { lo, hi },
-- optional weight (default 1), optional terrain ("grass", "water", "indoor"
-- or a list; default grass and indoor), optional mapName for the report.
-- `early = true` entries can be picked before the player has visited the
-- route, so a brand new save still gets swarms; everything else waits until
-- the player has been there at least once.
--
-- Swarms favour POKéMON that are rare, missing or version-exclusive in the
-- Gen 1 games, so they double as a way to fill the POKéDEX without trading.
local swarms = {
  { map = "ROUTE_1",         species = "PIKACHU",    levels = { 3, 5 },   early = true },
  { map = "ROUTE_2",         species = "SANDSHREW",  levels = { 3, 6 },   early = true },
  { map = "ROUTE_22",        species = "MANKEY",     levels = { 3, 6 },   early = true },
  { map = "VIRIDIAN_FOREST", species = "PARAS",      levels = { 4, 6 },   early = true },
  { map = "ROUTE_3",         species = "CLEFAIRY",   levels = { 8, 11 } },
  { map = "ROUTE_4",         species = "MEOWTH",     levels = { 10, 12 } },
  { map = "ROUTE_24",        species = "VULPIX",     levels = { 12, 15 } },
  { map = "ROUTE_25",        species = "GROWLITHE",  levels = { 12, 15 } },
  { map = "ROUTE_5",         species = "PONYTA",     levels = { 14, 17 } },
  { map = "ROUTE_6",         species = "PSYDUCK",    levels = { 14, 17 } },
  { map = "ROUTE_7",         species = "MR_MIME",    levels = { 18, 21 } },
  { map = "ROUTE_8",         species = "JYNX",       levels = { 18, 21 } },
  { map = "ROUTE_9",         species = "CUBONE",     levels = { 16, 19 } },
  { map = "ROUTE_10",        species = "VOLTORB",    levels = { 16, 20 } },
  { map = "ROUTE_11",        species = "FARFETCHD",  levels = { 15, 18 } },
  { map = "ROUTE_12",        species = "SLOWPOKE",   levels = { 22, 26 } },
  { map = "ROUTE_13",        species = "DITTO",      levels = { 22, 26 } },
  { map = "ROUTE_14",        species = "KANGASKHAN", levels = { 24, 27 }, weight = 0.5 },
  { map = "ROUTE_15",        species = "TAUROS",     levels = { 24, 27 }, weight = 0.5 },
  { map = "ROUTE_16",        species = "LICKITUNG",  levels = { 24, 27 } },
  { map = "ROUTE_17",        species = "SCYTHER",    levels = { 25, 28 }, weight = 0.5 },
  { map = "ROUTE_18",        species = "PINSIR",     levels = { 25, 28 }, weight = 0.5 },
  { map = "ROUTE_21",        species = "TANGELA",    levels = { 28, 31 } },
  { map = "ROUTE_23",        species = "EEVEE",      levels = { 30, 34 }, weight = 0.5 },
}

-- CONTESTS: one every day of the week, each with its own on/off option.
--
--   SUNDAY      ELECTRIC CONTEST   POWER PLANT
--   MONDAY      FISHING DERBY      VERMILION CITY and the dock (needs a rod)
--   TUESDAY     BUG-CATCHING       VIRIDIAN FOREST
--   WEDNESDAY   ROCK CONTEST       MT. MOON
--   THURSDAY    FIRE CONTEST       ROUTES 7 and 8
--   FRIDAY      PLANT CONTEST      ROUTES 24 and 25
--   SATURDAY    BUG-CATCHING       VIRIDIAN FOREST
--
-- Starters and EEVEE's evolutions turn up as very rare catches (about 1 in
-- 100) where they fit: CHARMANDER and FLAREON at the fire contest, SQUIRTLE
-- and VAPOREON at the derby, BULBASAUR with the plants, JOLTEON with the
-- electric POKéMON.
--
-- Sign up with the contest's officer, catch for 20 minutes with the
-- contest's PARK BALLs, and your best catch is judged against the other
-- entrants.  You keep everything you catch.  The POKéMON get stronger as you
-- beat gym leaders: the tier with the most badges you have reached is used.
-- Species points reward rarer catches; see lib/contest.lua for the scoring.
--
-- Each contest: id, name, weekdays (1 = Sunday), maps (the venue; leaving it
-- ends the contest), mapName, signUpAt, intro (the officer's pitch), report
-- (the ROUTE REPORT's line), officer { map, x, y, sprite, facing }, optional
-- returnTo (where time's up sends you), method ("walk" or "fishing"),
-- optional requires { items, text }, crowd (other contestants who wander the
-- venue: count, sprites, lines, and perMap overrides with place "walk" or
-- "shore"), tiers, points, rivals, prizes.first.
-- Anything in `shared` below is the default for every contest.

-- Officers are police officers (SPRITE_GUARD, the Saffron gate guard).
-- Those for contests away from a gate stand in the nearest POKéMON CENTER.
-- Every Gen 1 CENTER shares one layout, so they share one spot: the open
-- floor right of the door, facing the way in.
local function centerOfficer(map)
  return { map = map, x = 6, y = 5, sprite = "SPRITE_GUARD", facing = "LEFT" }
end

local shared = {
  minutes = 20,
  -- the contest's own ball, like Gold/Silver/Crystal's PARK BALL.  Not the
  -- SAFARI BALL: Gen 1 flags that as a key item (the Safari Zone counts its
  -- balls separately), so outside the Safari Zone it never runs out.
  balls = {
    item = "PARK_BALL", count = 20,
    define = {
      name = "PARK BALL",
      -- Gen 1 catch math (src/battle/Catching.lua): the GREAT BALL's numbers
      ball = { randMax = 200, hpFactor = 8, wobbleFactor = 200,
               tossAnim = "GREATTOSS_ANIM" },
    },
  },
  -- gym leaders beaten, counted from these story flags
  progressFlags = {
    "EVENT_BEAT_BROCK", "EVENT_BEAT_MISTY", "EVENT_BEAT_LT_SURGE",
    "EVENT_BEAT_ERIKA", "EVENT_BEAT_KOGA", "EVENT_BEAT_SABRINA",
    "EVENT_BEAT_BLAINE", "EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI",
  },
  prizes = {
    second = { item = "NUGGET", count = 1 },
    third = { item = "GREAT_BALL", count = 5 },
    entry = { item = "POTION", count = 2 },   -- everyone else who caught something
  },
}

local contests = {
  -- THE BUG-CATCHING CONTEST, Tuesdays and Saturdays, in the forest.
  {
    id = "bug_catching",
    name = "BUG-CATCHING CONTEST",
    weekdays = { 3, 7 },
    maps = { "VIRIDIAN_FOREST" },
    mapName = "VIRIDIAN FOREST",
    signUpAt = "VIRIDIAN FOREST south gate",
    intro = "Catch the best bug you can in VIRIDIAN FOREST",
    report = "Catch the best bug in VIRIDIAN FOREST.",
    -- beside the door to the forest, facing the path (the desks are at x 6
    -- and 8, rows 2-3 and 5-6)
    officer = { map = "VIRIDIAN_FOREST_SOUTH_GATE", x = 6, y = 1,
                sprite = "SPRITE_GUARD", facing = "LEFT" },
    returnTo = { map = "VIRIDIAN_FOREST_SOUTH_GATE", x = 4, y = 1, facing = "down" },
    -- other contestants wandering the forest during the contest
    crowd = { count = 4,
              sprites = { "SPRITE_YOUNGSTER", "SPRITE_LITTLE_GIRL", "SPRITE_YOUNGSTER", "SPRITE_BRUNETTE_GIRL" },
              lines = { "I'm going to catch a SCYTHER this time!",
                        "Shh! There's something rustling in the grass!",
                        "My CATERPIE won't stop growing. Is that normal?",
                        "PINSIR or bust!",
                        "BUTTERFREE are so pretty when they fly.",
                        "A KAKUNA just stared at me. Creepy.",
                        "I bet the judges love a big BEEDRILL.",
                        "Bug POKéMON are the best POKéMON. Fact.",
                        "Watch out, WEEDLE stings hurt!",
                        "I've been coming here since I was little.",
                        "VENONAT's eyes are huge up close!",
                        "Forest air makes me feel so alive." } },
    tiers = {
      { badges = 0, levels = { 4, 8 }, species = {
          { "CATERPIE", 30 }, { "WEEDLE", 30 }, { "METAPOD", 15 }, { "KAKUNA", 15 },
          { "PARAS", 8 }, { "BUTTERFREE", 1 }, { "BEEDRILL", 1 } } },
      { badges = 2, levels = { 10, 16 }, species = {
          { "CATERPIE", 15 }, { "WEEDLE", 15 }, { "METAPOD", 10 }, { "KAKUNA", 10 },
          { "PARAS", 15 }, { "VENONAT", 15 }, { "BUTTERFREE", 7 }, { "BEEDRILL", 7 },
          { "SCYTHER", 3 }, { "PINSIR", 3 } } },
      { badges = 4, levels = { 18, 25 }, species = {
          { "VENONAT", 20 }, { "PARAS", 15 }, { "BUTTERFREE", 15 }, { "BEEDRILL", 15 },
          { "PARASECT", 10 }, { "VENOMOTH", 10 }, { "SCYTHER", 8 }, { "PINSIR", 7 } } },
      { badges = 6, levels = { 28, 36 }, species = {
          { "VENOMOTH", 20 }, { "PARASECT", 20 }, { "BUTTERFREE", 15 }, { "BEEDRILL", 15 },
          { "SCYTHER", 15 }, { "PINSIR", 15 } } },
    },
    -- base points per species; anything missing scores 20
    points = {
      CATERPIE = 20, WEEDLE = 20, METAPOD = 25, KAKUNA = 25, PARAS = 35,
      VENONAT = 40, BUTTERFREE = 60, BEEDRILL = 60, PARASECT = 65,
      VENOMOTH = 70, SCYTHER = 100, PINSIR = 100,
    },
    rivals = { "BUG CATCHER RICK", "BUG CATCHER DOUG", "LASS ROBIN",
               "YOUNGSTER JOEY", "BUG CATCHER SAMMY" },
    -- 1st place rotates through these
    prizes = { first = { "MOON_STONE", "FIRE_STONE", "THUNDER_STONE",
                         "WATER_STONE", "LEAF_STONE" } },
  },

  -- THE FISHING DERBY, Mondays.  Only fishing counts: every cast in the
  -- venue bites, and the bite is a derby POKéMON whatever rod you use.
  {
    id = "fishing_derby",
    name = "FISHING DERBY",
    weekdays = { 2 },
    maps = { "VERMILION_CITY", "VERMILION_DOCK" },
    mapName = "VERMILION CITY",
    signUpAt = "VERMILION CITY POKéMON CENTER",
    intro = "Fish up the best water POKéMON you can in VERMILION CITY",
    report = "Bring a rod to VERMILION CITY.",
    method = "fishing",
    requires = { items = { "OLD_ROD", "GOOD_ROD", "SUPER_ROD" },
                 text = "You'll need a FISHING ROD to enter the FISHING DERBY. Come back when you have one!" },
    officer = centerOfficer("VERMILION_POKECENTER"),
    -- anglers stand at the water's edge in the city; a couple more stroll
    -- the S.S. ANNE dock
    crowd = { count = 3, place = "shore",
              sprites = { "SPRITE_FISHER", "SPRITE_FISHER", "SPRITE_SAILOR" },
              perMap = {
                VERMILION_CITY = { count = 4, place = "shore",
                                   sprites = { "SPRITE_FISHER", "SPRITE_FISHER", "SPRITE_FISHING_GURU", "SPRITE_FISHER" } },
                VERMILION_DOCK = { count = 2, place = "walk",
                                   sprites = { "SPRITE_SAILOR", "SPRITE_FISHER" } },
              },
              lines = { "The big ones bite when you least expect it.",
                        "Another MAGIKARP... that's my fifth!",
                        "They say a LAPRAS was hooked here once!",
                        "Patience is the real secret of fishing.",
                        "I used to sail on the S.S. ANNE, you know.",
                        "My lucky lure hasn't failed me yet.",
                        "A TENTACOOL tangled my line again!",
                        "STARYU glow at night. Did you know?",
                        "Sea air and a good rod. Perfect day.",
                        "I felt a huge tug! Then nothing...",
                        "SHELLDER pinch harder than you'd think.",
                        "The harbour's busy today, isn't it?" } },
    tiers = {
      { badges = 0, levels = { 5, 10 }, species = {
          { "MAGIKARP", 39 }, { "POLIWAG", 20 }, { "GOLDEEN", 20 }, { "TENTACOOL", 10 },
          { "HORSEA", 5 }, { "KRABBY", 5 }, { "SQUIRTLE", 1 } } },
      { badges = 2, levels = { 12, 20 }, species = {
          { "POLIWAG", 15 }, { "GOLDEEN", 15 }, { "HORSEA", 15 }, { "KRABBY", 15 },
          { "SHELLDER", 10 }, { "STARYU", 10 }, { "PSYDUCK", 10 }, { "MAGIKARP", 8 },
          { "SQUIRTLE", 1 }, { "VAPOREON", 1 } } },
      { badges = 4, levels = { 22, 30 }, species = {
          { "SEAKING", 15 }, { "KINGLER", 15 }, { "SEADRA", 10 }, { "POLIWHIRL", 15 },
          { "STARYU", 15 }, { "SHELLDER", 15 }, { "SLOWPOKE", 8 }, { "DRATINI", 5 },
          { "SQUIRTLE", 1 }, { "VAPOREON", 1 } } },
      { badges = 6, levels = { 32, 40 }, species = {
          { "SEAKING", 15 }, { "KINGLER", 15 }, { "SEADRA", 15 }, { "STARMIE", 10 },
          { "CLOYSTER", 10 }, { "POLIWHIRL", 9 }, { "GYARADOS", 9 }, { "LAPRAS", 5 },
          { "DRATINI", 5 }, { "DRAGONAIR", 5 }, { "SQUIRTLE", 1 }, { "VAPOREON", 1 } } },
    },
    points = {
      MAGIKARP = 10, POLIWAG = 25, GOLDEEN = 25, TENTACOOL = 25, HORSEA = 30,
      KRABBY = 30, PSYDUCK = 35, SLOWPOKE = 40, SHELLDER = 40, STARYU = 40,
      POLIWHIRL = 50, SEAKING = 55, KINGLER = 60, SEADRA = 65, STARMIE = 75,
      CLOYSTER = 75, GYARADOS = 90, DRATINI = 90, LAPRAS = 100, DRAGONAIR = 100,
      SQUIRTLE = 110, VAPOREON = 120,
    },
    rivals = { "FISHERMAN NED", "FISHERMAN RALPH", "SWIMMER LUIS",
               "SAILOR DUNCAN", "FISHERMAN WADE" },
    prizes = { first = { "WATER_STONE" } },
  },

  -- THE ROCK CONTEST, Wednesdays, in MT. MOON's caves.
  {
    id = "rock_cave",
    name = "ROCK CONTEST",
    weekdays = { 4 },
    maps = { "MT_MOON_1F", "MT_MOON_B1F", "MT_MOON_B2F" },
    mapName = "MT. MOON",
    signUpAt = "POKéMON CENTER by MT. MOON",
    intro = "Catch the best cave POKéMON you can in MT. MOON",
    report = "Head into MT. MOON for cave POKéMON.",
    officer = centerOfficer("MT_MOON_POKECENTER"),
    crowd = { count = 2,
              sprites = { "SPRITE_HIKER", "SPRITE_SUPER_NERD" },
              lines = { "Rock POKéMON love it down here!",
                        "I swear I saw a CLEFAIRY dancing back there.",
                        "Watch your step. ZUBAT everywhere!",
                        "An ONIX would win this for sure.",
                        "I've climbed every mountain in Kanto.",
                        "GEODUDE make great pillows. Don't ask.",
                        "It's so dark, I keep bumping into rocks.",
                        "I'm looking for MOON STONEs too, shh.",
                        "PARAS grow mushrooms on their backs!",
                        "My legs are tired, but I'm not giving up.",
                        "A MACHOP just flexed at me!",
                        "Caves echo when you shout. HELLO!" } },
    tiers = {
      { badges = 0, levels = { 6, 10 }, species = {
          { "ZUBAT", 30 }, { "GEODUDE", 30 }, { "PARAS", 15 }, { "SANDSHREW", 10 },
          { "CLEFAIRY", 10 }, { "ONIX", 5 } } },
      { badges = 2, levels = { 12, 18 }, species = {
          { "GEODUDE", 20 }, { "ZUBAT", 15 }, { "CLEFAIRY", 15 }, { "SANDSHREW", 15 },
          { "ONIX", 15 }, { "MACHOP", 10 }, { "CUBONE", 10 } } },
      { badges = 4, levels = { 22, 30 }, species = {
          { "GRAVELER", 20 }, { "GOLBAT", 15 }, { "ONIX", 15 }, { "SANDSLASH", 15 },
          { "MACHOKE", 10 }, { "MAROWAK", 10 }, { "CLEFAIRY", 10 }, { "RHYHORN", 5 } } },
      { badges = 6, levels = { 32, 40 }, species = {
          { "GRAVELER", 20 }, { "GOLBAT", 15 }, { "ONIX", 15 }, { "MACHOKE", 15 },
          { "MAROWAK", 10 }, { "SANDSLASH", 10 }, { "RHYHORN", 10 }, { "CLEFABLE", 5 } } },
    },
    points = {
      ZUBAT = 15, GEODUDE = 20, PARAS = 20, SANDSHREW = 30, MACHOP = 35,
      CUBONE = 35, GOLBAT = 45, CLEFAIRY = 50, ONIX = 50, GRAVELER = 55,
      SANDSLASH = 55, MACHOKE = 60, MAROWAK = 65, RHYHORN = 70, CLEFABLE = 90,
    },
    rivals = { "HIKER MARCOS", "HIKER LENNY", "SUPER NERD JOVAN",
               "BLACKBELT KOICHI", "LASS IRIS" },
    prizes = { first = { "MOON_STONE" } },
  },

  -- THE PLANT CONTEST, Fridays, in the grass north of CERULEAN CITY.
  {
    id = "plant",
    name = "PLANT CONTEST",
    weekdays = { 6 },
    maps = { "ROUTE_24", "ROUTE_25" },
    mapName = "ROUTES 24 and 25",
    signUpAt = "CERULEAN CITY POKéMON CENTER",
    intro = "Catch the best plant POKéMON you can on ROUTES 24 and 25",
    report = "Catch plant POKéMON north of CERULEAN CITY.",
    officer = centerOfficer("CERULEAN_POKECENTER"),
    crowd = { count = 3,
              sprites = { "SPRITE_GIRL", "SPRITE_COOLTRAINER_F", "SPRITE_BEAUTY" },
              lines = { "ODDISH only come out if you're quiet.",
                        "I'm hoping for a TANGELA today!",
                        "The grass up here smells so nice.",
                        "EXEGGCUTE always come in groups, you know.",
                        "BELLSPROUT sway when they're happy.",
                        "I brought a picnic. Want a sandwich?",
                        "Someone saw a BULBASAUR here once!",
                        "GLOOM smell funny, but I love them.",
                        "The sun's out. Plant POKéMON love that.",
                        "I'm going to win that LEAF STONE.",
                        "Careful, the bridge is busy today.",
                        "I named my ODDISH after my grandma." } },
    tiers = {
      { badges = 0, levels = { 6, 10 }, species = {
          { "ODDISH", 35 }, { "BELLSPROUT", 35 }, { "PARAS", 19 },
          { "EXEGGCUTE", 5 }, { "TANGELA", 5 }, { "BULBASAUR", 1 } } },
      { badges = 2, levels = { 12, 18 }, species = {
          { "ODDISH", 25 }, { "BELLSPROUT", 25 }, { "PARAS", 14 }, { "GLOOM", 10 },
          { "WEEPINBELL", 10 }, { "EXEGGCUTE", 10 }, { "TANGELA", 5 }, { "BULBASAUR", 1 } } },
      { badges = 4, levels = { 22, 30 }, species = {
          { "GLOOM", 22 }, { "WEEPINBELL", 22 }, { "EXEGGCUTE", 20 }, { "PARASECT", 17 },
          { "TANGELA", 18 }, { "BULBASAUR", 1 } } },
      { badges = 6, levels = { 32, 40 }, species = {
          { "GLOOM", 20 }, { "WEEPINBELL", 20 }, { "PARASECT", 17 }, { "EXEGGCUTE", 16 },
          { "TANGELA", 16 }, { "VILEPLUME", 5 }, { "VICTREEBEL", 5 }, { "BULBASAUR", 1 } } },
    },
    points = {
      ODDISH = 25, BELLSPROUT = 25, PARAS = 25, GLOOM = 50, WEEPINBELL = 50,
      PARASECT = 55, EXEGGCUTE = 60, TANGELA = 70, BULBASAUR = 110,
      VILEPLUME = 100, VICTREEBEL = 100,
    },
    rivals = { "LASS HALEY", "JR.TRAINER CINDY", "BEAUTY BRIDGET",
               "BUG CATCHER COLTON", "LASS KELSEY" },
    prizes = { first = { "LEAF_STONE" } },
  },

  -- THE FIRE CONTEST, Thursdays, in the grass either side of SAFFRON CITY,
  -- where GROWLITHE and VULPIX live.
  {
    id = "fire",
    name = "FIRE CONTEST",
    weekdays = { 5 },
    maps = { "ROUTE_7", "ROUTE_8" },
    mapName = "ROUTES 7 and 8",
    signUpAt = "CELADON CITY POKéMON CENTER",
    intro = "Catch the best fire POKéMON you can on ROUTES 7 and 8",
    report = "Find fire POKéMON either side of SAFFRON CITY.",
    officer = centerOfficer("CELADON_POKECENTER"),
    crowd = { count = 3,
              sprites = { "SPRITE_COOLTRAINER_M", "SPRITE_BIKER", "SPRITE_COOLTRAINER_F" },
              lines = { "It's getting hot out here!",
                        "GROWLITHE are so loyal. I want one!",
                        "VULPIX tails are like little flames.",
                        "I heard someone saw a CHARMANDER!",
                        "A FLAREON? Here? You're dreaming.",
                        "PONYTA run faster than my bike.",
                        "I packed BURN HEALs, just in case.",
                        "MAGMAR give off so much heat!",
                        "That FIRE STONE prize is mine.",
                        "My shoes are smoking. Is that bad?",
                        "ARCANINE are said to run like the wind.",
                        "Stay hydrated, everyone!" } },
    tiers = {
      { badges = 0, levels = { 8, 12 }, species = {
          { "GROWLITHE", 33 }, { "VULPIX", 33 }, { "PONYTA", 33 }, { "CHARMANDER", 1 } } },
      { badges = 2, levels = { 15, 22 }, species = {
          { "GROWLITHE", 28 }, { "VULPIX", 28 }, { "PONYTA", 28 }, { "MAGMAR", 14 },
          { "CHARMANDER", 1 }, { "FLAREON", 1 } } },
      { badges = 4, levels = { 24, 32 }, species = {
          { "GROWLITHE", 20 }, { "VULPIX", 20 }, { "PONYTA", 18 }, { "RAPIDASH", 15 },
          { "MAGMAR", 20 }, { "CHARMELEON", 5 }, { "CHARMANDER", 1 }, { "FLAREON", 1 } } },
      { badges = 6, levels = { 34, 42 }, species = {
          { "RAPIDASH", 25 }, { "MAGMAR", 25 }, { "GROWLITHE", 15 }, { "VULPIX", 15 },
          { "NINETALES", 8 }, { "ARCANINE", 8 }, { "CHARMELEON", 2 }, { "CHARMANDER", 1 },
          { "FLAREON", 1 } } },
    },
    points = {
      GROWLITHE = 35, VULPIX = 35, PONYTA = 35, RAPIDASH = 65, MAGMAR = 70,
      NINETALES = 85, ARCANINE = 90, CHARMANDER = 110, CHARMELEON = 115,
      FLAREON = 120,
    },
    rivals = { "BURGLAR DUSTY", "BURGLAR SIMON", "COOLTRAINER KEVIN",
               "BIKER LUKAS", "COOLTRAINER MEG" },
    prizes = { first = { "FIRE_STONE" } },
  },

  -- THE ELECTRIC CONTEST, Sundays, in the POWER PLANT.  You need SURF to
  -- get there, so it's a late-game contest.
  {
    id = "electric",
    name = "ELECTRIC CONTEST",
    weekdays = { 1 },
    maps = { "POWER_PLANT" },
    mapName = "the POWER PLANT",
    signUpAt = "POKéMON CENTER on ROUTE 10",
    intro = "Catch the best electric POKéMON you can in the POWER PLANT",
    report = "Surf to the POWER PLANT for electric POKéMON.",
    officer = centerOfficer("ROCK_TUNNEL_POKECENTER"),
    crowd = { count = 3,
              sprites = { "SPRITE_SCIENTIST", "SPRITE_ROCKER", "SPRITE_SUPER_NERD" },
              lines = { "My hair's standing on end in here!",
                        "VOLTORB look just like POKé BALLs. Careful!",
                        "I'm charged up and ready to win!",
                        "An ELECTABUZZ would be shocking!",
                        "This place hums. Can you hear it?",
                        "MAGNEMITE keep sticking to my bike.",
                        "I heard a JOLTEON lives here somewhere.",
                        "Don't touch the machines!",
                        "PIKACHU are cuter than any of these.",
                        "I came here to study static. Science!",
                        "The lights keep flickering. Spooky.",
                        "ELECTRODE explode if you look at them wrong." } },
    tiers = {
      { badges = 0, levels = { 10, 15 }, species = {
          { "PIKACHU", 30 }, { "MAGNEMITE", 30 }, { "VOLTORB", 30 },
          { "MAGNETON", 5 }, { "ELECTABUZZ", 5 } } },
      { badges = 2, levels = { 15, 22 }, species = {
          { "PIKACHU", 25 }, { "MAGNEMITE", 25 }, { "VOLTORB", 25 },
          { "MAGNETON", 10 }, { "ELECTABUZZ", 9 }, { "ELECTRODE", 5 }, { "JOLTEON", 1 } } },
      { badges = 4, levels = { 25, 32 }, species = {
          { "PIKACHU", 20 }, { "MAGNEMITE", 20 }, { "VOLTORB", 20 }, { "MAGNETON", 15 },
          { "ELECTRODE", 10 }, { "ELECTABUZZ", 9 }, { "RAICHU", 5 }, { "JOLTEON", 1 } } },
      { badges = 6, levels = { 33, 42 }, species = {
          { "MAGNETON", 20 }, { "ELECTRODE", 20 }, { "ELECTABUZZ", 18 }, { "PIKACHU", 15 },
          { "RAICHU", 11 }, { "MAGNEMITE", 10 }, { "VOLTORB", 5 }, { "JOLTEON", 1 } } },
    },
    points = {
      MAGNEMITE = 30, VOLTORB = 30, PIKACHU = 35, MAGNETON = 60, ELECTRODE = 60,
      ELECTABUZZ = 80, RAICHU = 80, JOLTEON = 120,
    },
    rivals = { "ROCKER LUCA", "ENGINEER BAILY", "SCIENTIST TAYLOR",
               "JUGGLER DALTON", "SUPER NERD ERIC" },
    prizes = { first = { "THUNDER_STONE" } },
  },
}

return { swarms = swarms, contests = contests, contestDefaults = shared }
