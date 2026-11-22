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
--   MONDAY      FISHING DERBY      VERMILION CITY (needs a rod)
--   TUESDAY     BUG-CATCHING       VIRIDIAN FOREST
--   WEDNESDAY   ROCK CONTEST       MT. MOON
--   THURSDAY    BUG-CATCHING       VIRIDIAN FOREST
--   FRIDAY      PLANT CONTEST      ROUTES 24 and 25
--   SATURDAY    BUG-CATCHING       VIRIDIAN FOREST
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
-- venue: count per map, sprites, lines), tiers, points, rivals, prizes.first.
-- Anything in `shared` below is the default for every contest.

-- Officers for the new contests stand in the nearest POKéMON CENTER.  Every
-- Gen 1 CENTER shares one layout, so they share one spot: the open floor
-- right of the door, facing the way in.
local function centerOfficer(map)
  return { map = map, x = 6, y = 5, sprite = "SPRITE_GENTLEMAN", facing = "LEFT" }
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
  -- THE BUG-CATCHING CONTEST, Tuesdays, Thursdays and Saturdays like Gold,
  -- Silver and Crystal, in the forest.
  {
    id = "bug_catching",
    name = "BUG-CATCHING CONTEST",
    weekdays = { 3, 5, 7 },
    maps = { "VIRIDIAN_FOREST" },
    mapName = "VIRIDIAN FOREST",
    signUpAt = "VIRIDIAN FOREST south gate",
    intro = "Catch the best bug you can in VIRIDIAN FOREST",
    report = "Catch the best bug in VIRIDIAN FOREST.",
    -- beside the door to the forest, facing the path (the desks are at x 6
    -- and 8, rows 2-3 and 5-6)
    officer = { map = "VIRIDIAN_FOREST_SOUTH_GATE", x = 6, y = 1,
                sprite = "SPRITE_GENTLEMAN", facing = "LEFT" },
    returnTo = { map = "VIRIDIAN_FOREST_SOUTH_GATE", x = 4, y = 1, facing = "down" },
    -- other contestants wandering the forest during the contest
    crowd = { count = 4,
              sprites = { "SPRITE_YOUNGSTER", "SPRITE_LITTLE_GIRL", "SPRITE_YOUNGSTER", "SPRITE_BRUNETTE_GIRL" },
              lines = { "I'm going to catch a SCYTHER this time!",
                        "Shh! There's something rustling in the grass!",
                        "My CATERPIE won't stop growing. Is that normal?",
                        "PINSIR or bust!",
                        "I've thrown half my PARK BALLs already..." } },
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
    crowd = { count = 3,
              sprites = { "SPRITE_FISHER", "SPRITE_SAILOR", "SPRITE_FISHER" },
              lines = { "The big ones bite when you least expect it.",
                        "Another MAGIKARP... that's my fifth!",
                        "They say a LAPRAS was hooked here once!",
                        "Patience is the real secret of fishing." } },
    tiers = {
      { badges = 0, levels = { 5, 10 }, species = {
          { "MAGIKARP", 40 }, { "POLIWAG", 20 }, { "GOLDEEN", 20 }, { "TENTACOOL", 10 },
          { "HORSEA", 5 }, { "KRABBY", 5 } } },
      { badges = 2, levels = { 12, 20 }, species = {
          { "POLIWAG", 15 }, { "GOLDEEN", 15 }, { "HORSEA", 15 }, { "KRABBY", 15 },
          { "SHELLDER", 10 }, { "STARYU", 10 }, { "PSYDUCK", 10 }, { "MAGIKARP", 10 } } },
      { badges = 4, levels = { 22, 30 }, species = {
          { "SEAKING", 15 }, { "KINGLER", 15 }, { "SEADRA", 10 }, { "POLIWHIRL", 15 },
          { "STARYU", 15 }, { "SHELLDER", 15 }, { "SLOWPOKE", 10 }, { "DRATINI", 5 } } },
      { badges = 6, levels = { 32, 40 }, species = {
          { "SEAKING", 15 }, { "KINGLER", 15 }, { "SEADRA", 15 }, { "STARMIE", 10 },
          { "CLOYSTER", 10 }, { "POLIWHIRL", 10 }, { "GYARADOS", 10 }, { "LAPRAS", 5 },
          { "DRATINI", 5 }, { "DRAGONAIR", 5 } } },
    },
    points = {
      MAGIKARP = 10, POLIWAG = 25, GOLDEEN = 25, TENTACOOL = 25, HORSEA = 30,
      KRABBY = 30, PSYDUCK = 35, SLOWPOKE = 40, SHELLDER = 40, STARYU = 40,
      POLIWHIRL = 50, SEAKING = 55, KINGLER = 60, SEADRA = 65, STARMIE = 75,
      CLOYSTER = 75, GYARADOS = 90, DRATINI = 90, LAPRAS = 100, DRAGONAIR = 100,
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
                        "An ONIX would win this for sure." } },
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
                        "EXEGGCUTE always come in groups, you know." } },
    tiers = {
      { badges = 0, levels = { 6, 10 }, species = {
          { "ODDISH", 35 }, { "BELLSPROUT", 35 }, { "PARAS", 20 },
          { "EXEGGCUTE", 5 }, { "TANGELA", 5 } } },
      { badges = 2, levels = { 12, 18 }, species = {
          { "ODDISH", 25 }, { "BELLSPROUT", 25 }, { "PARAS", 15 }, { "GLOOM", 10 },
          { "WEEPINBELL", 10 }, { "EXEGGCUTE", 10 }, { "TANGELA", 5 } } },
      { badges = 4, levels = { 22, 30 }, species = {
          { "GLOOM", 20 }, { "WEEPINBELL", 20 }, { "EXEGGCUTE", 20 }, { "PARASECT", 15 },
          { "TANGELA", 15 }, { "BULBASAUR", 10 } } },
      { badges = 6, levels = { 32, 40 }, species = {
          { "GLOOM", 20 }, { "WEEPINBELL", 20 }, { "PARASECT", 15 }, { "EXEGGCUTE", 15 },
          { "TANGELA", 15 }, { "VILEPLUME", 5 }, { "VICTREEBEL", 5 }, { "BULBASAUR", 5 } } },
    },
    points = {
      ODDISH = 25, BELLSPROUT = 25, PARAS = 25, GLOOM = 50, WEEPINBELL = 50,
      PARASECT = 55, EXEGGCUTE = 60, TANGELA = 70, BULBASAUR = 90,
      VILEPLUME = 100, VICTREEBEL = 100,
    },
    rivals = { "LASS HALEY", "JR.TRAINER CINDY", "BEAUTY BRIDGET",
               "BUG CATCHER COLTON", "LASS KELSEY" },
    prizes = { first = { "LEAF_STONE" } },
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
                        "An ELECTABUZZ would be shocking!" } },
    tiers = {
      { badges = 0, levels = { 10, 15 }, species = {
          { "PIKACHU", 30 }, { "MAGNEMITE", 30 }, { "VOLTORB", 30 },
          { "MAGNETON", 5 }, { "ELECTABUZZ", 5 } } },
      { badges = 2, levels = { 15, 22 }, species = {
          { "PIKACHU", 25 }, { "MAGNEMITE", 25 }, { "VOLTORB", 25 },
          { "MAGNETON", 10 }, { "ELECTABUZZ", 10 }, { "ELECTRODE", 5 } } },
      { badges = 4, levels = { 25, 32 }, species = {
          { "PIKACHU", 20 }, { "MAGNEMITE", 20 }, { "VOLTORB", 20 }, { "MAGNETON", 15 },
          { "ELECTRODE", 10 }, { "ELECTABUZZ", 10 }, { "RAICHU", 5 } } },
      { badges = 6, levels = { 33, 42 }, species = {
          { "MAGNETON", 20 }, { "ELECTRODE", 20 }, { "ELECTABUZZ", 15 }, { "PIKACHU", 15 },
          { "RAICHU", 10 }, { "MAGNEMITE", 10 }, { "VOLTORB", 5 }, { "JOLTEON", 5 } } },
    },
    points = {
      MAGNEMITE = 30, VOLTORB = 30, PIKACHU = 35, MAGNETON = 60, ELECTRODE = 60,
      ELECTABUZZ = 80, RAICHU = 80, JOLTEON = 100,
    },
    rivals = { "ROCKER LUCA", "ENGINEER BAILY", "SCIENTIST TAYLOR",
               "JUGGLER DALTON", "SUPER NERD ERIC" },
    prizes = { first = { "THUNDER_STONE" } },
  },
}

return { swarms = swarms, contests = contests, contestDefaults = shared }
