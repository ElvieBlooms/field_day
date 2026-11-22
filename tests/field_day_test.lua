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

-- ------- the contest's PARK BALL is a real, throwable, consumable item
local park = run.data.items.PARK_BALL
T.check(park ~= nil, "PARK_BALL is in the merged items")
T.eq(park and park.name, "PARK BALL", "named PARK BALL")
T.check(run.data.balls and run.data.balls.PARK_BALL ~= nil, "with its own catch numbers")
local ItemEffects = require("src.inventory.ItemEffects")
local okUse, result = pcall(ItemEffects.use, run.data, { inventory = {}, party = {} },
  "PARK_BALL", nil, { kind = "wild" })
T.check(okUse, "the engine can use it (" .. tostring(result) .. ")")
T.eq(result, "ball", "and treats it as a ball to throw")


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
T.check(not text:find("TEST MODE", 1, true), "no test banner on the real date")

-- ------- TEST: DAYS AHEAD
local real = fd.today()
run.loader.modOptions.field_day = run.loader.modOptions.field_day or {}
run.loader.modOptions.field_day.test_days = 3
local shifted = fd.today()
T.eq(shifted.day, real.day + 3, "the test option moves the day forward")
T.eq(shifted.weekday, (real.weekday + 3 - 1) % 7 + 1, "and the weekday with it")
T.check(shifted.swarm ~= nil, "the shifted day gets its own swarm")
T.check(fd.reportText():find("TEST MODE: 3 days ahead.", 1, true), "the report flags test mode")
run.loader.modOptions.field_day.test_days = 0
T.eq(fd.today().day, real.day, "setting it back to 0 returns to the real date")

-- ------- filters
T.check(fd.addSwarmFilter(function() return false end), "a filter can be added")
run.loader.modSave.field_day.today = nil
T.eq(fd.today().swarm, nil, "a filter returning false makes a quiet day")
-- on a contest day the contest takes that page instead
if fd.today().contest then
  T.check(fd.reportText():find(fd.today().contest.name, 1, true), "and the report leads with today's contest")
else
  T.check(fd.reportText():find("No swarms", 1, true), "and the report says so")
end

-- ------- one contest every day of the week, in today() and the report
local SCHEDULE = { "electric", "fishing_derby", "bug_catching", "rock_cave",
                   "bug_catching", "plant", "bug_catching" }
local SIGN_UP = {
  electric = "ROUTE 10", fishing_derby = "VERMILION CITY",
  bug_catching = "VIRIDIAN FOREST south gate", rock_cave = "MT. MOON",
  plant = "CERULEAN CITY",
}
for ahead = 0, 6 do
  run.loader.modOptions.field_day.test_days = ahead
  local t = fd.today()
  local want = SCHEDULE[t.weekday]
  T.eq(t.contest and t.contest.id, want, t.weekdayName .. ": the " .. want .. " contest")
  T.eq(#t.contests, 1, t.weekdayName .. ": exactly one contest")
  T.check(fd.reportText():find(SIGN_UP[want], 1, true),
    t.weekdayName .. ": the report says where to sign up")
end
-- each contest has its own switch
run.loader.modOptions.field_day.contest_bug_catching = false
for ahead = 0, 6 do
  run.loader.modOptions.field_day.test_days = ahead
  local t = fd.today()
  if SCHEDULE[t.weekday] == "bug_catching" then
    T.eq(t.contest, nil, t.weekdayName .. ": the bug contest can be switched off")
  end
end
run.loader.modOptions.field_day.contest_bug_catching = nil
run.loader.modOptions.field_day.contests = false
T.eq(fd.today().contest, nil, "ALL CONTESTS off means no contest at all")
run.loader.modOptions.field_day.contests = nil
run.loader.modOptions.field_day.test_days = 0

-- ------- the ROUTE REPORT on the POKéMON CENTER PC
local pcItems = Runtime.call("ui.pc.items", function(_, i) return i end, {},
  { { label = "BILL'S PC" }, { label = "RED's PC" } })
T.eq(#pcItems, 3, "the PC menu gains one row")
T.eq(pcItems[3].label, "ROUTE REPORT", "ROUTE REPORT, after the PCs (LOG OFF is added later)")
T.check(type(pcItems[3].onSelect) == "function" and pcItems[3].keepOpen, "it opens the report and keeps the PC menu")
run.loader.modOptions.field_day.news_pc = false
pcItems = Runtime.call("ui.pc.items", function(_, i) return i end, {}, { { label = "BILL'S PC" } })
T.eq(#pcItems, 1, "NEWS ON THE PC off removes it")
run.loader.modOptions.field_day.news_pc = nil

-- ------- contest counter and ball rule, through the real hooks
local Font = require("src.render.Font")
pcall(Font.load, run.data)
local today = fd.today()
run.loader.modSave.field_day.contest = { day = today.day, active = true,
  remaining = 9 * 60 + 5, thrown = 3, tier = 0, notified = {} }
local drawn = {}
local savedDraw = Font.draw
Font.draw = function(t, x, y) drawn[#drawn + 1] = t return savedDraw(t, x, y) end
local overworld = { isOverworld = true }
local fakeGame = { data = run.data, stack = { top = function() return overworld end } }
local okHud, hudErr = pcall(Runtime.call, "render.hud", function() end, fakeGame,
  { gameX = 0, gameY = 0, gameWidth = 160, gameHeight = 144, width = 160, height = 144, scale = 1 })
Font.draw = savedDraw
T.check(okHud, "the counter draws without error (" .. tostring(hudErr) .. ")")
T.eq(drawn[1], "BALL\195\15117", "it shows the balls left")
T.eq(drawn[2], "9:05", "and the time left")
drawn = {}
Font.draw = function(t) drawn[#drawn + 1] = t end
fakeGame.stack.top = function() return { isOverworld = false } end
Runtime.call("render.hud", function() end, fakeGame, { gameX = 0, gameY = 0, gameWidth = 160, gameHeight = 144 })
Font.draw = savedDraw
T.eq(#drawn, 0, "it hides behind menus, text and battles")
run.loader.modSave.field_day.contest = nil

run.release()
T.finish("field_day")
