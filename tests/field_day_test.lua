-- Headless check, run from the engine checkout:
--   luajit <path-to>/tests/field_day_test.lua <path-to-parent-of-field_day>
-- Loads Field Day on the ROM-free fixture and drives its hooks and exports.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")

local parent = arg[1] or "mods"
local run = T.sdk.loadMod("field_day", { root = parent })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

-- hooks translate species ids against the live game's data; headless there
-- is no game, so stand one in over the merged fixture
run.loader.game = { data = run.data }

local fd = run.loader.exports.field_day
T.check(type(fd) == "table", "exports are published")
T.eq(fd.apiVersion, 1, "exports carry an api version")
T.eq(#fd.swarms(), 24, "the 24 built-in Kanto swarms are registered")

-- ------- addSwarm validation
local ok, why = fd.addSwarm({ species = "FIXMON_B", levels = { 5, 7 }, games = { "gen1" } })
T.check(ok == nil and why:find("map"), "a swarm without a map is refused")
ok, why = fd.addSwarm({ map = "FIX_ROUTE", species = "FIXMON_B", levels = { 9, 5 }, games = { "gen1" } })
T.check(ok == nil and why:find("levels"), "lo > hi is refused")
ok, why = fd.addSwarm({ map = "FIX_ROUTE", species = "FIXMON_B", levels = { 5, 7 } })
T.check(ok == nil and why:find("games"), "a swarm without games is refused")
ok = fd.addSwarm({ map = "FIX_ROUTE", species = "FIXMON_B", levels = { 5, 7 },
                   games = { "gen1" }, early = true })
T.check(ok and ok.id == "FIX_ROUTE:FIXMON_B", "a valid swarm is accepted")
T.eq(#fd.swarms(), 25, "and listed")

-- Kanto species are not in the fixture, so the added swarm is the only
-- candidate the pick can land on.
local today = fd.today()
T.check(today.swarm ~= nil, "a swarm is picked")
T.eq(today.swarm.map, "FIX_ROUTE", "on the added route")
T.eq(today.swarm.species, "FIXMON_B", "with the added species")
T.eq(fd.today().swarm.species, "FIXMON_B", "the pick is stable within the day")

-- ------- encounter.species
local function vanilla(enc) return enc end
local function roll(mapId, terrain, r)
  return Runtime.call("encounter.species", vanilla,
    { species = "FIXMON_A", level = 3 },
    { mapId = mapId, terrain = terrain, rng = function() return r end })
end
local e = roll("FIX_ROUTE", "grass", 0.1)
T.eq(e.species, "FIXMON_B", "a low roll on the swarm route becomes the swarm species")
T.check(e.level >= 5 and e.level <= 7, "at a swarm level (" .. tostring(e.level) .. ")")
T.eq(roll("FIX_ROUTE", "grass", 0.9).species, "FIXMON_A", "a high roll keeps the vanilla pick")
T.eq(roll("OTHER_ROUTE", "grass", 0.1).species, "FIXMON_A", "other routes are untouched")
T.eq(roll("FIX_ROUTE", "water", 0.1).species, "FIXMON_A", "water is untouched by a grass swarm")

-- ------- encounter.table
local dist = Runtime.call("encounter.table", function(d) return d end,
  { FIXMON_A = 50, FIXMON_C = 50 }, { mapId = "FIX_ROUTE", terrain = "grass", preview = true })
T.eq(dist.FIXMON_B, 50, "the preview gives the swarm its share")
T.eq(dist.FIXMON_A, 25, "and scales the rest")

-- ------- START menu
local items = Runtime.call("ui.start_menu.items", function(_, i) return i end, {},
  { { label = "POKéDEX" }, { label = "SAVE" }, { label = "EXIT" } })
T.eq(items[2].label, "NEWS", "NEWS sits before SAVE")
T.eq(#items, 4, "exactly one row added")

-- ------- report text
local text = fd.reportText()
T.check(text:find("ROUTE REPORT", 1, true), "the report names itself")
T.check(text:find("FIX ROUTE", 1, true), "and the route")

-- ------- filters
T.check(fd.addSwarmFilter(function() return false end), "a filter can be added")
run.loader.modSave.field_day.today = nil
T.eq(fd.today().swarm, nil, "a filter returning false makes a quiet day")
T.check(fd.reportText():find("No swarms", 1, true), "and the report says so")

run.release()
T.finish("field_day")
