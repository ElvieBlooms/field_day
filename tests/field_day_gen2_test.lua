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
run.release()
T.finish("field_day gen2")
