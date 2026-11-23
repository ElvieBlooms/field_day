-- Headless Gen 2 check, run from the engine checkout:
--   luajit <path-to>/tests/field_day_gen2_test.lua <path-to-parent-of-field_day>
-- Loads Field Day as if Gold were running and drives its hooks.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")

local parent = arg[1] or "mods"
local run = T.sdk.loadMod("field_day", { root = parent, generation = 2 })
T.eq(#run.errors, 0, "loads clean on Gen 2 (" .. tostring(run.errors[1]) .. ")")
run.loader.game = { data = run.data }

local fd = run.loader.exports.field_day
T.check(type(fd) == "table", "exports are published")
T.eq(#fd.swarms(), 33, "the 33 built-in Johto and Kanto swarms are registered")
local park = run.data.items and run.data.items.PARK_BALL
T.check(not (park and park.effect == "FIELD_DAY_CONTEST_BALL"), "no PARK BALL of our own on Gen 2")
T.check(not (run.data.balls and run.data.balls.PARK_BALL), "no ball record of our own on Gen 2")

-- a gen1-only swarm is refused here; a gen2 one is accepted
local ok = fd.addSwarm({ map = "FIX_ROUTE", species = "FIXMON_B", levels = { 5, 7 },
                         games = { "gen1" }, early = true })
T.check(ok ~= nil, "a Gen 1 swarm can still be registered")
T.eq(#fd.swarms(), 33, "but it isn't listed on Gen 2")
ok = fd.addSwarm({ map = "FIX_ROUTE", species = "FIXMON_B", levels = { 5, 7 },
                   games = { "gen2" }, early = true })
T.check(ok ~= nil, "a Gen 2 swarm is accepted")
T.eq(#fd.swarms(), 34, "and listed")

local today = fd.today()
T.eq(today.swarm and today.swarm.species, "FIXMON_B", "the fixture's species is the only one that can swarm")

local function vanilla(enc) return enc end
local function roll(kind)
  return Runtime.call("encounter.species", vanilla, { species = "FIXMON_A", level = 3 },
    { mapId = "FIX_ROUTE", terrain = "grass", kind = kind, rng = function() return 0 end })
end
T.eq(roll("wild").level >= 5, true, "a wild roll on the swarm route becomes the swarm")
T.eq(roll("contest").level, 3, "the games' own bug contest is left alone")
T.eq(roll("script").level, 3, "scripted encounters are left alone")

T.check(type(fd.reportText()) == "string", "the ROUTE REPORT has text")

-- ------- swarm POKéMON get better shiny odds
local opts = run.loader.modOptions
opts.field_day = opts.field_day or {}
local function notShiny() return false end
local function shinyRoll(species, level)
  return Runtime.call("shiny.roll", notShiny, { species = species, level = level, dvs = {} })
end
local function frame() Runtime.call("core.update", function() end, nil, 0) end

-- the mark only applies to the POKéMON the swarm encounter builds
local enc = roll("wild")
opts.field_day.event_shiny = "128"
math.randomseed(7)
local hits = 0
for _ = 1, 20000 do
  frame()
  local e = roll("wild")
  if shinyRoll(e.species, e.level) then hits = hits + 1 end
end
T.check(hits > 80 and hits < 260, "about 1 in 128 swarm POKéMON are shiny (" .. hits .. " of 20000)")

frame()
roll("wild")
T.eq(shinyRoll("FIXMON_A", 99), false, "a different POKéMON doesn't use the swarm's odds")

local spent = 0
for _ = 1, 2000 do
  frame()
  local e = roll("wild")
  shinyRoll(e.species, e.level)
  if shinyRoll(e.species, e.level) then spent = spent + 1 end
end
T.eq(spent, 0, "each swarm encounter gets one boosted roll, not more")

local stale = 0
for _ = 1, 2000 do
  local e = roll("wild")
  frame()   -- e.g. a REPEL dropped it: the mark is gone next frame
  if shinyRoll(e.species, e.level) then stale = stale + 1 end
end
T.eq(stale, 0, "a mark doesn't outlive its frame")

opts.field_day.event_shiny = "normal"
local normal = 0
for _ = 1, 2000 do
  frame()
  local e = roll("wild")
  if shinyRoll(e.species, e.level) then normal = normal + 1 end
end
T.eq(normal, 0, "NORMAL leaves the game's own odds")

-- contests too: the DRAGON CONTEST's pool, stood in by fixture copies
for _, id in ipairs({ "DRATINI", "MAGIKARP", "HORSEA", "SEADRA", "DRAGONAIR",
                      "GYARADOS", "KINGDRA", "DRAGONITE" }) do
  if not run.data.pokemon[id] then
    local copy = {}
    for k, v in pairs(run.data.pokemon.FIXMON_A) do copy[k] = v end
    copy.name = id
    run.data.pokemon[id] = copy
  end
end
run.loader.modSave.field_day.contest = { active = true, id = "dragon",
  day = fd.today().day, remaining = 600, thrown = 0, tier = 0, notified = {} }
opts.field_day.event_shiny = "128"
local contestHits, fishHits = 0, 0
for _ = 1, 20000 do
  frame()
  local e = Runtime.call("encounter.species", vanilla, { species = "FIXMON_A", level = 3 },
    { mapId = "DRAGONS_DEN_B1F", terrain = "water", kind = "wild", rng = math.random })
  if shinyRoll(e.species, e.level) then contestHits = contestHits + 1 end
  frame()
  local bite = Runtime.call("encounter.fishing", function() return nil end, "SUPER_ROD",
    "DRAGONS_DEN_B1F", nil, {})
  if bite and shinyRoll(bite.species, bite.level) then fishHits = fishHits + 1 end
end
T.check(contestHits > 80 and contestHits < 260, "contest POKéMON get the odds too (" .. contestHits .. ")")
T.check(fishHits > 80 and fishHits < 260, "and so do contest bites (" .. fishHits .. ")")
run.loader.modSave.field_day.contest = nil
opts.field_day.event_shiny = nil
T.check(enc ~= nil, "encounters still roll")
run.release()
T.finish("field_day gen2")
