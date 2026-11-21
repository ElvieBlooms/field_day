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

-- THE BUG-CATCHING CONTEST, Tuesdays, Thursdays and Saturdays like Gold,
-- Silver and Crystal.  Sign up with the officer in the Viridian Forest south
-- gate, catch bugs for 20 minutes, and your best catch is judged against
-- the other entrants.  You keep everything you catch.
--
-- The forest's bugs get stronger as you beat gym leaders: the tier with the
-- most badges you have reached is used.  Species points reward rarer bugs;
-- see lib/contest.lua for the scoring.
local contest = {
  id = "bug_catching",
  name = "BUG-CATCHING CONTEST",
  weekdays = { 3, 5, 7 },             -- 1 = Sunday: Tue, Thu, Sat
  map = "VIRIDIAN_FOREST",
  mapName = "VIRIDIAN FOREST",
  signUpAt = "VIRIDIAN FOREST south gate",
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

  -- the officer who runs it, and where time's up sends you
  -- beside the door to the forest, facing the path (the desks are at x 6
  -- and 8, rows 2-3 and 5-6)
  officer = { map = "VIRIDIAN_FOREST_SOUTH_GATE", x = 6, y = 1,
              sprite = "SPRITE_GENTLEMAN", facing = "LEFT" },
  returnTo = { map = "VIRIDIAN_FOREST_SOUTH_GATE", x = 4, y = 1, facing = "down" },

  -- gym leaders beaten, counted from these story flags
  progressFlags = {
    "EVENT_BEAT_BROCK", "EVENT_BEAT_MISTY", "EVENT_BEAT_LT_SURGE",
    "EVENT_BEAT_ERIKA", "EVENT_BEAT_KOGA", "EVENT_BEAT_SABRINA",
    "EVENT_BEAT_BLAINE", "EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI",
  },

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
        { "PARASECT", 10 }, { "VENOMOTH", 10 }, { "SCYTHER", 7 }, { "PINSIR", 7 } } },
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

  -- 1st place rotates through these; 2nd and 3rd are fixed
  prizes = {
    first = { "MOON_STONE", "FIRE_STONE", "THUNDER_STONE", "WATER_STONE", "LEAF_STONE" },
    second = { item = "NUGGET", count = 1 },
    third = { item = "GREAT_BALL", count = 5 },
    entry = { item = "POTION", count = 2 },   -- everyone else who caught something
  },
}

return { swarms = swarms, contest = contest }
