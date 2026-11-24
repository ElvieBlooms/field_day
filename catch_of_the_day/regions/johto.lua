-- Johto and Kanto events for Gold, Silver and Crystal: swarms and contests.
--
-- The fields are the same as regions/kanto.lua (see the notes there).  Two
-- things are different here:
--
--   * Progress counts all sixteen gym leaders, Johto's eight first, so
--     `badges` and the contest tiers run from 0 to 16.
--   * Kanto contests have `unlockBadges = 8`: they start once the player
--     has all eight Johto badges, and until then they don't run, don't
--     show an officer and aren't in the ROUTE REPORT.
--
-- The games' own swarms are left alone.  Catch of the Day never picks the routes
-- the phone swarms use (DUNSPARCE in DARK CAVE, YANMA on ROUTE 35, QWILFISH
-- on ROUTE 32), and never touches the NATIONAL PARK, where the games' own
-- BUG-CATCHING CONTEST runs on Tuesdays, Thursdays and Saturdays.

local swarms = {
  -- Johto
  { map = "ROUTE_29",       species = "PIKACHU",    levels = { 3, 5 },   badges = 0 },
  { map = "ROUTE_46",       species = "SANDSHREW",  levels = { 3, 6 },   badges = 0 },
  { map = "ROUTE_30",       species = "PINECO",     levels = { 4, 6 },   badges = 0 },
  { map = "ROUTE_31",       species = "TEDDIURSA",  levels = { 4, 7 },   badges = 0 },
  { map = "ILEX_FOREST",    species = "HERACROSS",  levels = { 7, 10 },  badges = 1, weight = 0.5 },
  { map = "ROUTE_33",       species = "AIPOM",      levels = { 6, 9 },   badges = 1 },
  { map = "RUINS_OF_ALPH_OUTSIDE", species = "SMEARGLE", levels = { 8, 11 }, badges = 1, weight = 0.5,
    mapName = "the RUINS OF ALPH" },
  { map = "ROUTE_34",       species = "SNUBBULL",   levels = { 10, 13 }, badges = 2 },
  { map = "ROUTE_36",       species = "GROWLITHE",  levels = { 10, 13 }, badges = 2 },
  { map = "ROUTE_37",       species = "VULPIX",     levels = { 13, 16 }, badges = 3 },
  { map = "ROUTE_38",       species = "MILTANK",    levels = { 14, 17 }, badges = 3, weight = 0.5 },
  { map = "ROUTE_39",       species = "TAUROS",     levels = { 14, 17 }, badges = 3, weight = 0.5 },
  { map = "MOUNT_MORTAR_1F_OUTSIDE", species = "TYROGUE", levels = { 14, 17 }, badges = 4, weight = 0.5,
    mapName = "MT. MORTAR" },
  { map = "ROUTE_42",       species = "PHANPY",     levels = { 15, 18 }, badges = 5 },
  { map = "ROUTE_43",       species = "GIRAFARIG",  levels = { 16, 19 }, badges = 5 },
  { map = "ROUTE_44",       species = "LICKITUNG",  levels = { 22, 25 }, badges = 7 },
  { map = "ROUTE_45",       species = "GLIGAR",     levels = { 22, 25 }, badges = 7 },
  { map = "ICE_PATH_1F",    species = "DELIBIRD",   levels = { 20, 23 }, badges = 7,
    mapName = "the ICE PATH" },
  -- Kanto, after the Johto badges
  { map = "ROUTE_1",        species = "EEVEE",      levels = { 25, 28 }, badges = 8, weight = 0.5 },
  { map = "ROUTE_22",       species = "PONYTA",     levels = { 28, 31 }, badges = 8 },
  { map = "ROUTE_26",       species = "LARVITAR",   levels = { 30, 33 }, badges = 8, weight = 0.5 },
  { map = "ROUTE_27",       species = "SLUGMA",     levels = { 28, 31 }, badges = 8 },
  { map = "ROUTE_2",        species = "PINSIR",     levels = { 30, 33 }, badges = 9, weight = 0.5 },
  { map = "ROUTE_3",        species = "CLEFAIRY",   levels = { 28, 31 }, badges = 9 },
  { map = "ROUTE_6",        species = "MR_MIME",    levels = { 30, 33 }, badges = 10 },
  { map = "ROUTE_9",        species = "CHANSEY",    levels = { 30, 33 }, badges = 10, weight = 0.3 },
  { map = "ROUTE_11",       species = "KANGASKHAN", levels = { 32, 35 }, badges = 10, weight = 0.5 },
  { map = "ROUTE_13",       species = "PORYGON",    levels = { 32, 35 }, badges = 11, weight = 0.5 },
  { map = "ROUTE_17",       species = "SKARMORY",   levels = { 35, 38 }, badges = 12, weight = 0.5 },
  { map = "ROUTE_21",       species = "TANGELA",    levels = { 32, 35 }, badges = 12 },
  -- the fossils have no wild home in Gold, Silver or Crystal
  { map = "ROUTE_19",       species = "OMANYTE",    levels = { 30, 34 }, badges = 12, weight = 0.5,
    terrain = "water" },
  { map = "ROUTE_20",       species = "KABUTO",     levels = { 30, 34 }, badges = 12, weight = 0.5,
    terrain = "water" },
  { map = "ROUTE_14",       species = "AERODACTYL", levels = { 35, 38 }, badges = 13, weight = 0.3 },
}

-- CONTESTS.  Johto has one every day; Kanto adds a second one every day
-- once the player has the eight Johto badges.
--
--   DAY        JOHTO                            KANTO (8 badges)
--   SUNDAY     DRAGON   DRAGON'S DEN            ELECTRIC  ROUTE 10 and ROCK TUNNEL
--   MONDAY     FISHING  LAKE OF RAGE            FISHING   VERMILION CITY and port
--   TUESDAY    (the games' own bug contest)     ROCK      MT. MOON
--   WEDNESDAY  CAVE     UNION CAVE              FIRE      ROUTES 7 and 8
--   THURSDAY   GHOST    BURNED TOWER            PLANT     ROUTES 24 and 25
--   FRIDAY     ICE      ICE PATH                STEEL     ROUTES 45 and 46
--   SATURDAY   DARK     ROUTES 36 and 37        NORMAL    ROUTES 1 and 2
--
-- Only one contest runs at a time, so on a two-contest day the player
-- picks one.  Rare catches (1 in 100): the Johto starters, EEVEE's
-- evolutions and a few others, where they fit.

-- Every Gen 2 POKéMON CENTER shares one ground floor, so the officers share
-- one spot: open floor right of the middle, facing the door.  Two
-- contests that use the same CENTER never fall on the same day.
local function centerOfficer(map)
  return { map = map, x = 6, y = 4, sprite = "SPRITE_OFFICER", facing = "DOWN" }
end

local RODS = { items = { "OLD_ROD", "GOOD_ROD", "SUPER_ROD" },
               text = "You'll need a FISHING ROD to enter. Come back when you have one!" }

local shared = {
  minutes = 20,
  -- the games' own PARK BALL, so nothing is defined here
  balls = { item = "PARK_BALL", count = 20 },
  progressFlags = {
    "EVENT_BEAT_FALKNER", "EVENT_BEAT_BUGSY", "EVENT_BEAT_WHITNEY",
    "EVENT_BEAT_MORTY", "EVENT_BEAT_JASMINE", "EVENT_BEAT_CHUCK",
    "EVENT_BEAT_PRYCE", "EVENT_BEAT_CLAIR",
    "EVENT_BEAT_BROCK", "EVENT_BEAT_MISTY", "EVENT_BEAT_LTSURGE",
    "EVENT_BEAT_ERIKA", "EVENT_BEAT_JANINE", "EVENT_BEAT_SABRINA",
    "EVENT_BEAT_BLAINE", "EVENT_BEAT_BLUE",
  },
  prizes = {
    second = { item = "NUGGET", count = 1 },
    third = { item = "ULTRA_BALL", count = 3 },
    entry = { item = "SUPER_POTION", count = 2 },
  },
}

local contests = {
  -- ======================================================== JOHTO

  -- THE DRAGON CONTEST, Sundays, in the DRAGON'S DEN.  Water only: SURF
  -- or fish in the pool.  You need SURF and WHIRLPOOL to get there.
  {
    id = "dragon",
    name = "DRAGON CONTEST",
    weekdays = { 1 },
    maps = { "DRAGONS_DEN_1F", "DRAGONS_DEN_B1F" },
    mapName = "the DRAGON'S DEN",
    signUpAt = "BLACKTHORN CITY POKéMON CENTER",
    intro = "SURF or fish for the best dragon in the DRAGON'S DEN",
    report = "Brave the DRAGON'S DEN behind the BLACKTHORN GYM.",
    method = "any",
    officer = centerOfficer("BLACKTHORN_POKECENTER_1F"),
    crowd = { count = 2, place = "shore",
              sprites = { "SPRITE_COOLTRAINER_M", "SPRITE_COOLTRAINER_F" },
              lines = { "The ELDER is watching. No pressure.",
                        "DRATINI shed their skin as they grow.",
                        "I've fished here for hours. Worth it.",
                        "They say DRAGONAIR can change the weather.",
                        "A KINGDRA? In this pool? Maybe!",
                        "Don't splash. You'll scare them off.",
                        "CLAIR trained here when she was young.",
                        "MAGIKARP again. The dragons are hiding.",
                        "This water is colder than it looks.",
                        "My grandpa caught a DRAGONITE once. He says.",
                        "HORSEA keep spitting ink at my rod.",
                        "A true dragon tamer never gives up." } },
    tiers = {
      { badges = 0, levels = { 15, 22 }, species = {
          { "DRATINI", 40 }, { "MAGIKARP", 20 }, { "HORSEA", 25 }, { "SEADRA", 8 },
          { "DRAGONAIR", 4 }, { "GYARADOS", 2 }, { "KINGDRA", 1 } } },
      { badges = 9, levels = { 25, 33 }, species = {
          { "DRATINI", 35 }, { "HORSEA", 20 }, { "SEADRA", 15 }, { "MAGIKARP", 10 },
          { "DRAGONAIR", 12 }, { "GYARADOS", 7 }, { "KINGDRA", 1 } } },
      { badges = 12, levels = { 35, 43 }, species = {
          { "DRAGONAIR", 30 }, { "SEADRA", 25 }, { "DRATINI", 20 }, { "GYARADOS", 15 },
          { "HORSEA", 5 }, { "DRAGONITE", 3 }, { "KINGDRA", 2 } } },
    },
    points = {
      MAGIKARP = 10, HORSEA = 30, DRATINI = 60, SEADRA = 65, GYARADOS = 85,
      DRAGONAIR = 95, KINGDRA = 120, DRAGONITE = 125,
    },
    rivals = { "COOLTRAINER DARIN", "COOLTRAINER CARA", "TAMER BRETT",
               "FISHER TULLY", "COOLTRAINER PAUL" },
    prizes = { first = { "DRAGON_SCALE", "DRAGON_FANG" } },
  },

  -- THE FISHING DERBY, Mondays, at the LAKE OF RAGE.
  {
    id = "fishing_johto",
    name = "LAKE OF RAGE DERBY",
    weekdays = { 2 },
    maps = { "LAKE_OF_RAGE" },
    mapName = "the LAKE OF RAGE",
    signUpAt = "MAHOGANY TOWN POKéMON CENTER",
    intro = "Fish up the best water POKéMON you can at the LAKE OF RAGE",
    report = "Bring a rod to the LAKE OF RAGE.",
    method = "fishing",
    requires = RODS,
    officer = centerOfficer("MAHOGANY_POKECENTER_1F"),
    crowd = { count = 4, place = "shore",
              sprites = { "SPRITE_FISHER", "SPRITE_FISHER", "SPRITE_FISHING_GURU", "SPRITE_FISHER" },
              lines = { "This lake used to be full of GYARADOS.",
                        "WOOPER keep nibbling my bait.",
                        "I heard a red GYARADOS lived here once.",
                        "QUAGSIRE just sit there and smile.",
                        "Patience. The lake gives what it gives.",
                        "A CHINCHOU! Wait, no, a stick.",
                        "The wind off the lake is chilly today.",
                        "I came all the way from CIANWOOD for this!",
                        "REMORAID spit water at you. Rude.",
                        "My rod's older than I am.",
                        "Another MAGIKARP. They never stop.",
                        "Best spot is by the big tree. Shh." } },
    tiers = {
      { badges = 0, levels = { 10, 18 }, species = {
          { "MAGIKARP", 30 }, { "GOLDEEN", 20 }, { "POLIWAG", 20 }, { "WOOPER", 20 },
          { "KRABBY", 8 }, { "TOTODILE", 1 }, { "VAPOREON", 1 } } },
      { badges = 5, levels = { 20, 28 }, species = {
          { "GOLDEEN", 15 }, { "POLIWAG", 13 }, { "WOOPER", 15 }, { "MAGIKARP", 10 },
          { "CHINCHOU", 10 }, { "REMORAID", 10 }, { "QWILFISH", 10 }, { "SEAKING", 8 },
          { "QUAGSIRE", 7 }, { "TOTODILE", 1 }, { "VAPOREON", 1 } } },
      { badges = 8, levels = { 30, 38 }, species = {
          { "SEAKING", 15 }, { "QUAGSIRE", 15 }, { "POLIWHIRL", 12 }, { "LANTURN", 12 },
          { "OCTILLERY", 12 }, { "QWILFISH", 10 }, { "CHINCHOU", 8 }, { "GYARADOS", 10 },
          { "MAGIKARP", 4 }, { "TOTODILE", 1 }, { "VAPOREON", 1 } } },
      { badges = 12, levels = { 38, 46 }, species = {
          { "LANTURN", 18 }, { "OCTILLERY", 18 }, { "SEAKING", 15 }, { "QUAGSIRE", 15 },
          { "GYARADOS", 15 }, { "POLITOED", 5 }, { "KINGLER", 10 }, { "CROCONAW", 2 },
          { "TOTODILE", 1 }, { "VAPOREON", 1 } } },
    },
    points = {
      MAGIKARP = 10, GOLDEEN = 25, POLIWAG = 25, WOOPER = 25, KRABBY = 30,
      CHINCHOU = 35, REMORAID = 35, QWILFISH = 45, SEAKING = 55, POLIWHIRL = 55,
      QUAGSIRE = 60, KINGLER = 60, LANTURN = 70, OCTILLERY = 70, GYARADOS = 90,
      POLITOED = 100, TOTODILE = 110, CROCONAW = 115, VAPOREON = 120,
    },
    rivals = { "FISHER RALPH", "FISHER ANDRE", "FISHER RAYMOND",
               "FISHER EDGAR", "FISHER JUSTIN" },
    prizes = { first = { "MYSTIC_WATER", "WATER_STONE" } },
  },

  -- THE CAVE CONTEST, Wednesdays, in UNION CAVE.  (DARK CAVE is left out:
  -- its VIOLET CITY side is where the games' own DUNSPARCE swarm turns up.)
  {
    id = "cave",
    name = "CAVE CONTEST",
    weekdays = { 4 },
    maps = { "UNION_CAVE_1F", "UNION_CAVE_B1F", "UNION_CAVE_B2F" },
    mapName = "UNION CAVE",
    signUpAt = "POKéMON CENTER on ROUTE 32",
    intro = "Catch the best rock or ground POKéMON you can in UNION CAVE",
    report = "Dig into UNION CAVE for rock and ground POKéMON.",
    officer = centerOfficer("ROUTE_32_POKECENTER_1F"),
    crowd = { count = 3,
              sprites = { "SPRITE_POKEFAN_M", "SPRITE_SUPER_NERD", "SPRITE_YOUNGSTER" },
              lines = { "Watch your step. GEODUDE look like rocks.",
                        "An ONIX went right under my feet!",
                        "My flashlight is running low...",
                        "They say a LAPRAS swims down below.",
                        "PHANPY curl up into balls. Adorable.",
                        "SANDSHREW dig faster than I can walk.",
                        "I've been lost in here twice today.",
                        "Rocks, rocks and more rocks. Love it.",
                        "A GLIGAR swooped right over my head!",
                        "Is that dripping water or a WOOPER?",
                        "I'm going for a STEELIX. Wish me luck.",
                        "Cave air is good for the lungs. Probably." } },
    tiers = {
      { badges = 0, levels = { 6, 12 }, species = {
          { "GEODUDE", 30 }, { "SANDSHREW", 20 }, { "ONIX", 15 }, { "WOOPER", 15 },
          { "DIGLETT", 14 }, { "PHANPY", 5 }, { "LARVITAR", 1 } } },
      { badges = 2, levels = { 12, 20 }, species = {
          { "GEODUDE", 20 }, { "SANDSHREW", 15 }, { "ONIX", 15 }, { "WOOPER", 12 },
          { "DIGLETT", 10 }, { "PHANPY", 10 }, { "GLIGAR", 8 }, { "QUAGSIRE", 5 },
          { "GRAVELER", 4 }, { "LARVITAR", 1 } } },
      { badges = 4, levels = { 20, 28 }, species = {
          { "GRAVELER", 15 }, { "ONIX", 15 }, { "PHANPY", 12 }, { "GLIGAR", 12 },
          { "SANDSLASH", 10 }, { "QUAGSIRE", 10 }, { "DUGTRIO", 10 }, { "GEODUDE", 8 },
          { "DONPHAN", 4 }, { "STEELIX", 2 }, { "LARVITAR", 2 } } },
      { badges = 7, levels = { 30, 38 }, species = {
          { "GRAVELER", 15 }, { "DONPHAN", 15 }, { "SANDSLASH", 12 }, { "DUGTRIO", 12 },
          { "GLIGAR", 12 }, { "QUAGSIRE", 10 }, { "ONIX", 10 }, { "RHYHORN", 8 },
          { "STEELIX", 4 }, { "LARVITAR", 2 } } },
    },
    points = {
      GEODUDE = 25, DIGLETT = 25, WOOPER = 25, SANDSHREW = 30, ONIX = 40,
      PHANPY = 45, GLIGAR = 50, GRAVELER = 50, QUAGSIRE = 55, DUGTRIO = 60,
      SANDSLASH = 60, RHYHORN = 65, DONPHAN = 80, STEELIX = 100, LARVITAR = 110,
    },
    rivals = { "HIKER RUSSELL", "HIKER DANIEL", "POKEMANIAC LARRY",
               "SUPER NERD ERIC", "HIKER PARRY" },
    prizes = { first = { "SOFT_SAND", "HARD_STONE" } },
  },

  -- THE GHOST CONTEST, Thursdays, in the BURNED TOWER.
  {
    id = "ghost",
    name = "GHOST CONTEST",
    weekdays = { 5 },
    maps = { "BURNED_TOWER_1F", "BURNED_TOWER_B1F" },
    mapName = "the BURNED TOWER",
    signUpAt = "ECRUTEAK CITY POKéMON CENTER",
    intro = "Catch the best ghost POKéMON you can in the BURNED TOWER",
    report = "Something stirs in ECRUTEAK's BURNED TOWER.",
    officer = centerOfficer("ECRUTEAK_POKECENTER_1F"),
    crowd = { count = 3,
              sprites = { "SPRITE_SAGE", "SPRITE_GRANNY", "SPRITE_SUPER_NERD" },
              lines = { "Did you feel that? Something cold.",
                        "GASTLY are made of gas. Don't breathe in.",
                        "The tower burned down long ago...",
                        "MISDREAVUS cry at night. I'm not scared.",
                        "A HAUNTER licked me! I can't stop shaking!",
                        "MORTY says ghosts are just misunderstood.",
                        "The floor creaks with every step.",
                        "I heard a GENGAR laughing in the dark.",
                        "Three POKéMON ran from here, they say.",
                        "My grandma told me stories about this place.",
                        "Who keeps turning out the lights?",
                        "I brought a CLEANSE TAG. Just in case." } },
    tiers = {
      { badges = 0, levels = { 10, 16 }, species = {
          { "GASTLY", 45 }, { "KOFFING", 20 }, { "ZUBAT", 20 }, { "MISDREAVUS", 10 },
          { "HAUNTER", 4 }, { "GENGAR", 1 } } },
      { badges = 3, levels = { 16, 24 }, species = {
          { "GASTLY", 35 }, { "MISDREAVUS", 20 }, { "HAUNTER", 15 }, { "KOFFING", 14 },
          { "GOLBAT", 10 }, { "MAGMAR", 4 }, { "GENGAR", 1 }, { "ESPEON", 1 } } },
      { badges = 6, levels = { 26, 34 }, species = {
          { "HAUNTER", 30 }, { "MISDREAVUS", 25 }, { "GASTLY", 20 }, { "WEEZING", 10 },
          { "GOLBAT", 8 }, { "MAGMAR", 4 }, { "GENGAR", 2 }, { "ESPEON", 1 } } },
      { badges = 10, levels = { 36, 44 }, species = {
          { "HAUNTER", 35 }, { "MISDREAVUS", 30 }, { "GASTLY", 10 }, { "WEEZING", 10 },
          { "CROBAT", 5 }, { "MAGMAR", 4 }, { "GENGAR", 5 }, { "ESPEON", 1 } } },
    },
    points = {
      ZUBAT = 20, KOFFING = 25, GASTLY = 35, GOLBAT = 45, WEEZING = 55,
      MAGMAR = 70, HAUNTER = 70, MISDREAVUS = 80, CROBAT = 90, GENGAR = 115,
      ESPEON = 120,
    },
    rivals = { "SAGE PING", "MEDIUM MARTHA", "MEDIUM GRACE",
               "SAGE JEFFREY", "POKEMANIAC SHANE" },
    prizes = { first = { "SPELL_TAG" } },
  },

  -- THE ICE CONTEST, Fridays, in the ICE PATH.
  {
    id = "ice",
    name = "ICE CONTEST",
    weekdays = { 6 },
    maps = { "ICE_PATH_1F", "ICE_PATH_B1F", "ICE_PATH_B2F_MAHOGANY_SIDE",
             "ICE_PATH_B2F_BLACKTHORN_SIDE", "ICE_PATH_B3F" },
    mapName = "the ICE PATH",
    signUpAt = "MAHOGANY TOWN POKéMON CENTER",
    intro = "Catch the best ice POKéMON you can in the ICE PATH",
    report = "Wrap up warm for the ICE PATH.",
    officer = centerOfficer("MAHOGANY_POKECENTER_1F"),
    crowd = { count = 3,
              sprites = { "SPRITE_COOLTRAINER_M", "SPRITE_COOLTRAINER_F", "SPRITE_POKEFAN_F" },
              lines = { "I can't feel my toes!",
                        "SWINUB sniff out mushrooms under the snow.",
                        "Careful on the ice. I slid into a wall.",
                        "A DELIBIRD gave me a present! It was a rock.",
                        "SNEASEL are sneaky. One took my glove!",
                        "JYNX dance in the cold. Weird, right?",
                        "PRYCE trains here every winter.",
                        "My breath is freezing in the air.",
                        "They say a LAPRAS sings down below.",
                        "Hot cocoa after this. Definitely.",
                        "Slide, stop, slide, stop. I'm dizzy.",
                        "SEEL are so happy in the cold!" } },
    tiers = {
      { badges = 0, levels = { 20, 26 }, species = {
          { "SWINUB", 35 }, { "SEEL", 15 }, { "JYNX", 15 }, { "SNEASEL", 10 },
          { "DELIBIRD", 10 }, { "SHELLDER", 10 }, { "PILOSWINE", 3 }, { "LAPRAS", 2 } } },
      { badges = 9, levels = { 28, 36 }, species = {
          { "SWINUB", 20 }, { "PILOSWINE", 15 }, { "JYNX", 15 }, { "SNEASEL", 15 },
          { "DELIBIRD", 10 }, { "SEEL", 10 }, { "DEWGONG", 8 }, { "CLOYSTER", 5 },
          { "LAPRAS", 2 } } },
      { badges = 12, levels = { 38, 46 }, species = {
          { "PILOSWINE", 25 }, { "SNEASEL", 20 }, { "JYNX", 15 }, { "DEWGONG", 15 },
          { "CLOYSTER", 10 }, { "DELIBIRD", 10 }, { "LAPRAS", 5 } } },
    },
    points = {
      SWINUB = 30, SHELLDER = 35, SEEL = 40, DELIBIRD = 55, PILOSWINE = 65,
      JYNX = 70, SNEASEL = 75, DEWGONG = 75, CLOYSTER = 80, LAPRAS = 110,
    },
    rivals = { "SKIER ROXANNE", "BOARDER RONALD", "BOARDER BRAD",
               "SKIER CLARISSA", "BOARDER DOUGLAS" },
    prizes = { first = { "NEVERMELTICE" } },
  },

  -- THE DARK CONTEST, Saturdays, on ROUTES 36 and 37.
  {
    id = "dark",
    name = "DARK CONTEST",
    weekdays = { 7 },
    maps = { "ROUTE_36", "ROUTE_37" },
    mapName = "ROUTES 36 and 37",
    signUpAt = "ECRUTEAK CITY POKéMON CENTER",
    intro = "Catch the best dark POKéMON you can on ROUTES 36 and 37",
    report = "Night creatures are out south of ECRUTEAK CITY.",
    officer = centerOfficer("ECRUTEAK_POKECENTER_1F"),
    crowd = { count = 3,
              sprites = { "SPRITE_COOLTRAINER_M", "SPRITE_LASS", "SPRITE_ROCKER" },
              lines = { "MURKROW keep stealing my shiny things.",
                        "HOUNDOUR howl to call their pack.",
                        "It's darker out here than I thought.",
                        "HOOTHOOT always know what time it is.",
                        "I saw yellow rings glowing in the grass!",
                        "SPINARAK webs are everywhere tonight.",
                        "An UMBREON? Here? You're kidding.",
                        "Bad luck to see a MURKROW, they say.",
                        "My flashlight scares them all away.",
                        "Shh. Listen. Something's watching us.",
                        "SNEASEL claws are sharp. Careful.",
                        "The moon's out. Perfect contest weather." } },
    tiers = {
      { badges = 0, levels = { 12, 18 }, species = {
          { "HOOTHOOT", 25 }, { "SPINARAK", 25 }, { "MURKROW", 20 }, { "HOUNDOUR", 20 },
          { "SNEASEL", 9 }, { "UMBREON", 1 } } },
      { badges = 4, levels = { 20, 28 }, species = {
          { "MURKROW", 22 }, { "HOUNDOUR", 22 }, { "NOCTOWL", 15 }, { "ARIADOS", 15 },
          { "SNEASEL", 15 }, { "MISDREAVUS", 10 }, { "UMBREON", 1 } } },
      { badges = 8, levels = { 30, 38 }, species = {
          { "MURKROW", 20 }, { "HOUNDOUR", 18 }, { "SNEASEL", 18 }, { "HOUNDOOM", 12 },
          { "NOCTOWL", 12 }, { "ARIADOS", 10 }, { "MISDREAVUS", 8 }, { "UMBREON", 2 } } },
      { badges = 12, levels = { 38, 46 }, species = {
          { "HOUNDOOM", 22 }, { "SNEASEL", 22 }, { "MURKROW", 20 }, { "NOCTOWL", 14 },
          { "ARIADOS", 10 }, { "MISDREAVUS", 7 }, { "TYRANITAR", 2 }, { "UMBREON", 3 } } },
    },
    points = {
      HOOTHOOT = 25, SPINARAK = 25, NOCTOWL = 50, ARIADOS = 50, MURKROW = 60,
      HOUNDOUR = 60, SNEASEL = 75, MISDREAVUS = 75, HOUNDOOM = 90,
      TYRANITAR = 115, UMBREON = 120,
    },
    rivals = { "BIRD KEEPER ROD", "PSYCHIC MARK", "COOLTRAINER GAVEN",
               "LASS DANA", "BUG CATCHER WADE" },
    prizes = { first = { "BLACKGLASSES" } },
  },

  -- ======================================================== KANTO
  -- These open once the player has all eight Johto badges.

  -- THE ELECTRIC CONTEST, Sundays, on ROUTE 10 and in ROCK TUNNEL.  (The
  -- POWER PLANT has no wild POKéMON in these games.)
  {
    id = "electric",
    name = "ELECTRIC CONTEST",
    weekdays = { 1 },
    unlockBadges = 8,
    maps = { "ROUTE_10_NORTH", "ROCK_TUNNEL_1F", "ROCK_TUNNEL_B1F" },
    mapName = "ROUTE 10",
    signUpAt = "POKéMON CENTER on ROUTE 10",
    intro = "Catch the best electric POKéMON you can on ROUTE 10",
    report = "Electric POKéMON are buzzing by the POWER PLANT.",
    officer = centerOfficer("ROUTE_10_POKECENTER_1F"),
    crowd = { count = 3,
              sprites = { "SPRITE_SCIENTIST", "SPRITE_ROCKER", "SPRITE_SUPER_NERD" },
              lines = { "My hair's standing on end out here!",
                        "VOLTORB look just like POKé BALLs. Careful!",
                        "MAREEP wool crackles when you pet it.",
                        "An ELECTABUZZ would be shocking!",
                        "The POWER PLANT hums all day long.",
                        "MAGNEMITE keep sticking to my bike.",
                        "I heard a JOLTEON lives here somewhere.",
                        "ELEKID are so cute. And so zappy.",
                        "AMPHAROS light the way at night.",
                        "I came here to study static. Science!",
                        "PIKACHU are cuter than any of these.",
                        "ELECTRODE explode if you look at them wrong." } },
    tiers = {
      { badges = 0, levels = { 30, 36 }, species = {
          { "VOLTORB", 20 }, { "MAGNEMITE", 20 }, { "MAREEP", 15 }, { "PIKACHU", 12 },
          { "FLAAFFY", 10 }, { "ELECTABUZZ", 8 }, { "MAGNETON", 7 }, { "ELEKID", 7 },
          { "JOLTEON", 1 } } },
      { badges = 11, levels = { 36, 42 }, species = {
          { "MAGNETON", 18 }, { "ELECTRODE", 15 }, { "FLAAFFY", 15 }, { "ELECTABUZZ", 15 },
          { "PIKACHU", 10 }, { "VOLTORB", 10 }, { "RAICHU", 8 }, { "AMPHAROS", 5 },
          { "ELEKID", 3 }, { "JOLTEON", 1 } } },
      { badges = 14, levels = { 42, 50 }, species = {
          { "MAGNETON", 20 }, { "ELECTRODE", 18 }, { "ELECTABUZZ", 18 }, { "AMPHAROS", 12 },
          { "RAICHU", 12 }, { "FLAAFFY", 10 }, { "LANTURN", 8 }, { "JOLTEON", 2 } } },
    },
    points = {
      MAGNEMITE = 30, VOLTORB = 30, MAREEP = 30, PIKACHU = 35, ELEKID = 50,
      FLAAFFY = 50, MAGNETON = 60, ELECTRODE = 60, LANTURN = 70, ELECTABUZZ = 80,
      RAICHU = 80, AMPHAROS = 95, JOLTEON = 120,
    },
    rivals = { "ROCKER LUCA", "SCIENTIST TAYLOR", "JUGGLER IRWIN",
               "SUPER NERD SAM", "GUITARIST VINCENT" },
    prizes = { first = { "MAGNET", "THUNDERSTONE" } },
  },

  -- THE KANTO FISHING DERBY, Mondays, in VERMILION CITY and its port.
  {
    id = "fishing_kanto",
    name = "VERMILION DERBY",
    weekdays = { 2 },
    unlockBadges = 8,
    maps = { "VERMILION_CITY", "VERMILION_PORT" },
    mapName = "VERMILION CITY",
    signUpAt = "VERMILION CITY POKéMON CENTER",
    intro = "Fish up the best water POKéMON you can in VERMILION CITY",
    report = "Bring a rod to VERMILION CITY.",
    method = "fishing",
    requires = RODS,
    officer = centerOfficer("VERMILION_POKECENTER_1F"),
    crowd = { count = 3, place = "shore",
              sprites = { "SPRITE_FISHER", "SPRITE_SAILOR", "SPRITE_FISHER" },
              perMap = {
                VERMILION_CITY = { count = 3, place = "shore",
                                   sprites = { "SPRITE_FISHER", "SPRITE_FISHING_GURU", "SPRITE_FISHER" } },
                VERMILION_PORT = { count = 2, place = "walk",
                                   sprites = { "SPRITE_SAILOR", "SPRITE_FISHER" } },
              },
              lines = { "The big ones bite when you least expect it.",
                        "Another MAGIKARP... that's my fifth!",
                        "The S.S. AQUA brings fishers from all over.",
                        "Patience is the real secret of fishing.",
                        "CORSOLA came all the way from CIANWOOD?",
                        "My lucky lure hasn't failed me yet.",
                        "A TENTACOOL tangled my line again!",
                        "STARYU glow at night. Did you know?",
                        "Sea air and a good rod. Perfect day.",
                        "I felt a huge tug! Then nothing...",
                        "SHELLDER pinch harder than you'd think.",
                        "The harbour's busy today, isn't it?" } },
    tiers = {
      { badges = 0, levels = { 28, 35 }, species = {
          { "TENTACOOL", 15 }, { "KRABBY", 15 }, { "SHELLDER", 12 }, { "STARYU", 12 },
          { "HORSEA", 10 }, { "CORSOLA", 10 }, { "MANTINE", 5 }, { "MAGIKARP", 9 },
          { "TENTACRUEL", 10 }, { "SQUIRTLE", 1 }, { "VAPOREON", 1 } } },
      { badges = 11, levels = { 35, 42 }, species = {
          { "TENTACRUEL", 15 }, { "KINGLER", 15 }, { "SEADRA", 12 }, { "STARMIE", 10 },
          { "CLOYSTER", 10 }, { "CORSOLA", 10 }, { "MANTINE", 8 }, { "GYARADOS", 10 },
          { "LAPRAS", 3 }, { "WARTORTLE", 5 }, { "SQUIRTLE", 1 }, { "VAPOREON", 1 } } },
      { badges = 14, levels = { 42, 50 }, species = {
          { "KINGLER", 15 }, { "STARMIE", 15 }, { "CLOYSTER", 15 }, { "GYARADOS", 15 },
          { "MANTINE", 12 }, { "SEADRA", 10 }, { "LAPRAS", 5 }, { "KINGDRA", 2 },
          { "WARTORTLE", 9 }, { "SQUIRTLE", 1 }, { "VAPOREON", 1 } } },
    },
    points = {
      MAGIKARP = 10, TENTACOOL = 25, KRABBY = 30, HORSEA = 30, SHELLDER = 40,
      STARYU = 40, CORSOLA = 50, TENTACRUEL = 55, KINGLER = 60, SEADRA = 65,
      MANTINE = 75, STARMIE = 75, CLOYSTER = 75, GYARADOS = 90, LAPRAS = 100,
      SQUIRTLE = 110, WARTORTLE = 115, KINGDRA = 120, VAPOREON = 120,
    },
    rivals = { "FISHER KYLE", "SAILOR HARRY", "SWIMMER SETH",
               "FISHER MARTIN", "SAILOR KENT" },
    prizes = { first = { "WATER_STONE", "MYSTIC_WATER" } },
  },

  -- THE ROCK CONTEST, Tuesdays, in MT. MOON.
  {
    id = "rock",
    name = "ROCK CONTEST",
    weekdays = { 3 },
    unlockBadges = 8,
    maps = { "MOUNT_MOON" },
    mapName = "MT. MOON",
    signUpAt = "PEWTER CITY POKéMON CENTER",
    intro = "Catch the best rock POKéMON you can in MT. MOON",
    report = "Rock POKéMON are rumbling in MT. MOON.",
    officer = centerOfficer("PEWTER_POKECENTER_1F"),
    crowd = { count = 3,
              sprites = { "SPRITE_POKEFAN_M", "SPRITE_SUPER_NERD", "SPRITE_BLACK_BELT" },
              lines = { "BROCK said this cave made him who he is.",
                        "Watch your step. GEODUDE look like rocks.",
                        "CLEFAIRY dance here when the moon is full.",
                        "I'm after a LARVITAR. They eat mountains!",
                        "SUDOWOODO aren't trees. Don't be fooled.",
                        "An ONIX went right under my feet!",
                        "My lamp keeps going out in here.",
                        "SHUCKLE make juice from berries. Gross.",
                        "Rocks, rocks and more rocks. Love it.",
                        "A TYRANITAR here? I'd faint.",
                        "I found a MOON STONE once. True story.",
                        "Echo! Echo! ...Sorry." } },
    tiers = {
      { badges = 0, levels = { 30, 36 }, species = {
          { "GEODUDE", 20 }, { "GRAVELER", 18 }, { "ONIX", 15 }, { "RHYHORN", 12 },
          { "SUDOWOODO", 8 }, { "SHUCKLE", 8 }, { "CLEFAIRY", 9 }, { "LARVITAR", 8 },
          { "PUPITAR", 2 } } },
      { badges = 11, levels = { 36, 42 }, species = {
          { "GRAVELER", 20 }, { "ONIX", 15 }, { "RHYHORN", 15 }, { "SUDOWOODO", 10 },
          { "SHUCKLE", 8 }, { "LARVITAR", 12 }, { "PUPITAR", 10 }, { "GOLEM", 5 },
          { "STEELIX", 4 }, { "TYRANITAR", 1 } } },
      { badges = 14, levels = { 42, 50 }, species = {
          { "GRAVELER", 15 }, { "RHYDON", 15 }, { "PUPITAR", 15 }, { "SUDOWOODO", 12 },
          { "GOLEM", 12 }, { "STEELIX", 10 }, { "SHUCKLE", 8 }, { "LARVITAR", 10 },
          { "TYRANITAR", 3 } } },
    },
    points = {
      GEODUDE = 25, CLEFAIRY = 35, ONIX = 40, GRAVELER = 50, RHYHORN = 55,
      SHUCKLE = 70, SUDOWOODO = 75, LARVITAR = 80, RHYDON = 80, GOLEM = 85,
      PUPITAR = 90, STEELIX = 100, TYRANITAR = 125,
    },
    rivals = { "HIKER ANTHONY", "HIKER BAILEY", "BLACKBELT KIYO",
               "SUPER NERD MIGUEL", "HIKER LENNY" },
    prizes = { first = { "HARD_STONE", "MOON_STONE" } },
  },

  -- THE FIRE CONTEST, Wednesdays, on ROUTES 7 and 8.
  {
    id = "fire",
    name = "FIRE CONTEST",
    weekdays = { 4 },
    unlockBadges = 8,
    maps = { "ROUTE_7", "ROUTE_8" },
    mapName = "ROUTES 7 and 8",
    signUpAt = "CELADON CITY POKéMON CENTER",
    intro = "Catch the best fire POKéMON you can on ROUTES 7 and 8",
    report = "Find fire POKéMON either side of SAFFRON CITY.",
    officer = centerOfficer("CELADON_POKECENTER_1F"),
    crowd = { count = 3,
              sprites = { "SPRITE_COOLTRAINER_M", "SPRITE_BIKER", "SPRITE_COOLTRAINER_F" },
              lines = { "It's getting hot out here!",
                        "GROWLITHE are so loyal. I want one!",
                        "VULPIX tails are like little flames.",
                        "I heard someone saw a CYNDAQUIL!",
                        "A FLAREON? Here? You're dreaming.",
                        "PONYTA run faster than my bike.",
                        "I packed BURN HEALs, just in case.",
                        "SLUGMA leave little burn marks everywhere.",
                        "That FIRE STONE prize is mine.",
                        "My shoes are smoking. Is that bad?",
                        "MAGBY breathe little sparks. So cute.",
                        "Stay hydrated, everyone!" } },
    tiers = {
      { badges = 0, levels = { 30, 36 }, species = {
          { "GROWLITHE", 18 }, { "VULPIX", 18 }, { "PONYTA", 15 }, { "HOUNDOUR", 15 },
          { "SLUGMA", 12 }, { "MAGBY", 7 }, { "MAGMAR", 12 }, { "CYNDAQUIL", 1 },
          { "CHARMANDER", 1 }, { "FLAREON", 1 } } },
      { badges = 11, levels = { 36, 42 }, species = {
          { "GROWLITHE", 14 }, { "VULPIX", 14 }, { "RAPIDASH", 14 }, { "MAGMAR", 14 },
          { "HOUNDOUR", 12 }, { "MAGCARGO", 10 }, { "HOUNDOOM", 8 }, { "NINETALES", 5 },
          { "ARCANINE", 4 }, { "QUILAVA", 2 }, { "CYNDAQUIL", 1 }, { "CHARMANDER", 1 },
          { "FLAREON", 1 } } },
      { badges = 14, levels = { 42, 50 }, species = {
          { "RAPIDASH", 18 }, { "MAGMAR", 18 }, { "HOUNDOOM", 15 }, { "MAGCARGO", 12 },
          { "NINETALES", 10 }, { "ARCANINE", 10 }, { "GROWLITHE", 6 }, { "VULPIX", 6 },
          { "QUILAVA", 2 }, { "CYNDAQUIL", 1 }, { "CHARMANDER", 1 }, { "FLAREON", 1 } } },
    },
    points = {
      SLUGMA = 30, GROWLITHE = 35, VULPIX = 35, PONYTA = 35, HOUNDOUR = 50,
      MAGBY = 55, MAGCARGO = 65, RAPIDASH = 65, MAGMAR = 70, HOUNDOOM = 85,
      NINETALES = 85, ARCANINE = 90, CYNDAQUIL = 110, CHARMANDER = 110,
      QUILAVA = 115, FLAREON = 120,
    },
    rivals = { "FIREBREATHER OTIS", "FIREBREATHER WALT", "BIKER CHARLES",
               "COOLTRAINER KEVIN", "COOLTRAINER MEG" },
    prizes = { first = { "CHARCOAL", "FIRE_STONE" } },
  },

  -- THE PLANT CONTEST, Thursdays, on ROUTES 24 and 25.
  {
    id = "plant",
    name = "PLANT CONTEST",
    weekdays = { 5 },
    unlockBadges = 8,
    maps = { "ROUTE_24", "ROUTE_25" },
    mapName = "ROUTES 24 and 25",
    signUpAt = "CERULEAN CITY POKéMON CENTER",
    intro = "Catch the best plant POKéMON you can on ROUTES 24 and 25",
    report = "The grass is growing tall north of CERULEAN CITY.",
    officer = centerOfficer("CERULEAN_POKECENTER_1F"),
    crowd = { count = 3,
              sprites = { "SPRITE_LASS", "SPRITE_TWIN", "SPRITE_BUG_CATCHER" },
              lines = { "HOPPIP float away if the wind picks up.",
                        "ODDISH walk around at night. Spooky!",
                        "SUNKERN just sit there. Like me.",
                        "BELLSPROUT sway when you sing to them.",
                        "I heard a CHIKORITA was seen here!",
                        "Smell that? Fresh-cut grass!",
                        "MISTY's place is right down the road.",
                        "Someone said BULBASAUR used to live here.",
                        "My sneezes are scaring them off.",
                        "BELLOSSOM dance when the sun comes out.",
                        "I want an EXEGGCUTE. Six friends in one!",
                        "The flowers on ROUTE 25 are lovely." } },
    tiers = {
      { badges = 0, levels = { 28, 34 }, species = {
          { "ODDISH", 18 }, { "BELLSPROUT", 18 }, { "HOPPIP", 14 }, { "SUNKERN", 10 },
          { "GLOOM", 10 }, { "WEEPINBELL", 10 }, { "SKIPLOOM", 8 }, { "EXEGGCUTE", 5 },
          { "TANGELA", 5 }, { "CHIKORITA", 1 }, { "BULBASAUR", 1 } } },
      { badges = 11, levels = { 34, 40 }, species = {
          { "GLOOM", 15 }, { "WEEPINBELL", 15 }, { "SKIPLOOM", 15 }, { "TANGELA", 12 },
          { "EXEGGCUTE", 12 }, { "SUNKERN", 8 }, { "ODDISH", 8 }, { "BELLSPROUT", 8 },
          { "BAYLEEF", 2 }, { "IVYSAUR", 2 }, { "CHIKORITA", 1 }, { "BULBASAUR", 1 },
          { "SUNFLORA", 1 } } },
      { badges = 14, levels = { 40, 48 }, species = {
          { "VILEPLUME", 12 }, { "VICTREEBEL", 12 }, { "JUMPLUFF", 12 }, { "BELLOSSOM", 10 },
          { "TANGELA", 12 }, { "EXEGGUTOR", 10 }, { "SUNFLORA", 8 }, { "GLOOM", 10 },
          { "WEEPINBELL", 8 }, { "BAYLEEF", 2 }, { "IVYSAUR", 2 }, { "CHIKORITA", 1 },
          { "BULBASAUR", 1 } } },
    },
    points = {
      SUNKERN = 20, ODDISH = 25, BELLSPROUT = 25, HOPPIP = 25, GLOOM = 45,
      WEEPINBELL = 45, SKIPLOOM = 45, EXEGGCUTE = 50, TANGELA = 60,
      SUNFLORA = 70, JUMPLUFF = 75, VILEPLUME = 80, VICTREEBEL = 80,
      BELLOSSOM = 85, EXEGGUTOR = 85, CHIKORITA = 110, BULBASAUR = 110,
      BAYLEEF = 115, IVYSAUR = 115,
    },
    rivals = { "PICNICKER LIZ", "CAMPER TODD", "LASS KRISE",
               "TWINS AMY & MAY", "BUG CATCHER DON" },
    prizes = { first = { "MIRACLE_SEED", "LEAF_STONE", "SUN_STONE" } },
  },

  -- THE STEEL CONTEST, Fridays, on ROUTES 45 and 46.  Johto ground, but
  -- held for TRAINERs back from Kanto.
  {
    id = "steel",
    name = "STEEL CONTEST",
    weekdays = { 6 },
    unlockBadges = 8,
    maps = { "ROUTE_45", "ROUTE_46" },
    mapName = "ROUTES 45 and 46",
    signUpAt = "BLACKTHORN CITY POKéMON CENTER",
    intro = "Catch the best steel POKéMON you can on ROUTES 45 and 46",
    report = "Steel POKéMON gleam on the mountain roads south of BLACKTHORN.",
    officer = centerOfficer("BLACKTHORN_POKECENTER_1F"),
    crowd = { count = 3,
              sprites = { "SPRITE_POKEFAN_M", "SPRITE_COOLTRAINER_F", "SPRITE_BLACK_BELT" },
              lines = { "SKARMORY feathers are sharp as knives.",
                        "I heard a SCIZOR clank by just now!",
                        "PINECO blow up if you poke them. Don't.",
                        "MAGNEMITE keep sticking to my watch.",
                        "JASMINE's STEELIX started out right here.",
                        "These hills are hard on the legs.",
                        "Steel types are tough. Like me!",
                        "My METAL COAT is lucky. I think.",
                        "FORRETRESS hide in their shells all day.",
                        "A clink! Did you hear a clink?",
                        "Watch out for the ledges going down.",
                        "Shiny things everywhere today." } },
    tiers = {
      { badges = 0, levels = { 30, 36 }, species = {
          { "MAGNEMITE", 20 }, { "PINECO", 20 }, { "SKARMORY", 12 }, { "ONIX", 12 },
          { "SCYTHER", 10 }, { "FORRETRESS", 10 }, { "MAGNETON", 12 }, { "STEELIX", 2 },
          { "SCIZOR", 1 }, { "GEODUDE", 1 } } },
      { badges = 11, levels = { 36, 42 }, species = {
          { "MAGNETON", 20 }, { "FORRETRESS", 18 }, { "SKARMORY", 18 }, { "SCYTHER", 12 },
          { "MAGNEMITE", 10 }, { "PINECO", 10 }, { "STEELIX", 7 }, { "SCIZOR", 3 },
          { "ONIX", 2 } } },
      { badges = 14, levels = { 42, 50 }, species = {
          { "SKARMORY", 22 }, { "MAGNETON", 20 }, { "FORRETRESS", 20 }, { "STEELIX", 15 },
          { "SCYTHER", 12 }, { "SCIZOR", 6 }, { "MAGNEMITE", 5 } } },
    },
    points = {
      GEODUDE = 20, MAGNEMITE = 30, PINECO = 30, ONIX = 40, MAGNETON = 60,
      FORRETRESS = 70, SCYTHER = 80, SKARMORY = 90, STEELIX = 100, SCIZOR = 120,
    },
    rivals = { "HIKER MICHAEL", "COOLTRAINER RYAN", "BLACKBELT KENJI",
               "HIKER TIMOTHY", "COOLTRAINER KELLY" },
    prizes = { first = { "METAL_COAT" } },
  },

  -- THE NORMAL CONTEST, Saturdays, on ROUTES 1 and 2.
  {
    id = "normal",
    name = "NORMAL CONTEST",
    weekdays = { 7 },
    unlockBadges = 8,
    maps = { "ROUTE_1", "ROUTE_2" },
    mapName = "ROUTES 1 and 2",
    signUpAt = "VIRIDIAN CITY POKéMON CENTER",
    intro = "Catch the best normal POKéMON you can on ROUTES 1 and 2",
    report = "Everyday POKéMON, extraordinary prizes, either side of VIRIDIAN CITY.",
    officer = centerOfficer("VIRIDIAN_POKECENTER_1F"),
    crowd = { count = 4,
              sprites = { "SPRITE_YOUNGSTER", "SPRITE_LASS", "SPRITE_POKEFAN_F", "SPRITE_GRAMPS" },
              lines = { "SENTRET stand on their tails to look around.",
                        "A SNORLAX? On ROUTE 1? Imagine!",
                        "MILTANK milk is the best, you know.",
                        "I heard an EEVEE hiding in the grass!",
                        "AIPOM stole my hat. Again.",
                        "SNUBBULL look scary but they're sweethearts.",
                        "This is where my journey started, too.",
                        "TAUROS charge if you get too close.",
                        "My RATTATA is in the top percentage of RATTATA!",
                        "STANTLER antlers make me dizzy.",
                        "Normal types are anything but normal.",
                        "PROF. OAK lives just down the road!" } },
    tiers = {
      { badges = 0, levels = { 28, 34 }, species = {
          { "SENTRET", 15 }, { "RATTATA", 12 }, { "PIDGEY", 12 }, { "MEOWTH", 10 },
          { "SNUBBULL", 10 }, { "AIPOM", 10 }, { "TEDDIURSA", 8 }, { "STANTLER", 7 },
          { "DUNSPARCE", 6 }, { "FURRET", 8 }, { "EEVEE", 1 }, { "ESPEON", 1 } } },
      { badges = 11, levels = { 34, 40 }, species = {
          { "FURRET", 14 }, { "PERSIAN", 10 }, { "PIDGEOTTO", 12 }, { "STANTLER", 12 },
          { "GRANBULL", 8 }, { "URSARING", 8 }, { "MILTANK", 8 }, { "TAUROS", 8 },
          { "DUNSPARCE", 6 }, { "LICKITUNG", 6 }, { "AIPOM", 5 }, { "SNORLAX", 1 },
          { "EEVEE", 1 }, { "ESPEON", 1 } } },
      { badges = 14, levels = { 40, 48 }, species = {
          { "URSARING", 14 }, { "GRANBULL", 12 }, { "STANTLER", 12 }, { "MILTANK", 12 },
          { "TAUROS", 12 }, { "PIDGEOT", 10 }, { "PERSIAN", 8 }, { "KANGASKHAN", 8 },
          { "PORYGON", 5 }, { "SNORLAX", 3 }, { "CHANSEY", 2 }, { "EEVEE", 1 },
          { "ESPEON", 1 } } },
    },
    points = {
      RATTATA = 15, PIDGEY = 15, SENTRET = 20, MEOWTH = 30, SNUBBULL = 35,
      AIPOM = 40, TEDDIURSA = 40, FURRET = 45, PIDGEOTTO = 45, DUNSPARCE = 55,
      PERSIAN = 60, STANTLER = 65, LICKITUNG = 70, GRANBULL = 70, MILTANK = 75,
      TAUROS = 75, PIDGEOT = 80, URSARING = 85, KANGASKHAN = 90, PORYGON = 95,
      CHANSEY = 100, SNORLAX = 110, EEVEE = 110, ESPEON = 120,
    },
    rivals = { "YOUNGSTER JOEY", "LASS MICHELLE", "POKEFAN BEVERLY",
               "SCHOOLBOY JACK", "GENTLEMAN PRESTON" },
    prizes = { first = { "PINK_BOW", "POLKADOT_BOW", "MOON_STONE" } },
  },
}

-- Lines the ROUTE REPORT adds on the days the games' own events run, so
-- players know where else to go.
local notes = {
  { weekdays = { 3, 5, 7 },
    text = "The BUG-CATCHING CONTEST is on at the NATIONAL PARK too!" },
}

return { swarms = swarms, contests = contests, contestDefaults = shared, notes = notes }
