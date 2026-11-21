-- Unit test for lib/contest.lua against a fake mod object.  The headless
-- engine has no overworld to run scripts, so a tiny runner here plays the
-- officer's rows (answering YES) and records what the player would see.
--   luajit tests/contest_test.lua [path-to-repo]
local root = (arg[1] or ".") .. "/field_day/"

local passed, failed = 0, 0
local function check(cond, label)
  if cond then passed = passed + 1
  else failed = failed + 1 print("FAIL " .. label) end
end
local function eq(got, want, label)
  check(got == want, ("%s (got %s, want %s)"):format(label, tostring(got), tostring(want)))
end

local function include(path) return dofile(root .. path) end
local rng = include("lib/rng.lua")
local calendar = include("lib/calendar.lua")
local kanto = include("regions/kanto.lua")
local text = include("lib/textbox.lua")

-- ------- the fake mod

local saveData, flags, options, emitted, shown, bag = {}, {}, {}, {}, {}, {}
local here = { mapId = "VIRIDIAN_FOREST_SOUTH_GATE" }
local spawned = {}
local registered = {}
local answer = true
local busy = false

local KNOWN = {}
for _, tier in ipairs(kanto.contest.tiers) do
  for _, row in ipairs(tier.species) do KNOWN[row[1]] = true end
end

local function runRows(rows)
  local labels = {}
  for i, r in ipairs(rows) do if r[1] == "label" then labels[r[2]] = i end end
  local last, i = nil, 1
  while i <= #rows do
    local r = rows[i]
    local verb = r[1]
    if verb == "show_text" or verb == "ask" then
      local raw = r[2]
      -- every line fits the box (17 columns) and breaks with \n then \v
      for line in (raw .. "\v"):gmatch("([^\n\v\f]*)[\n\v\f]") do
        local cols = 0
        for i = 1, #line do local b = line:byte(i) if b < 0x80 or b >= 0xC0 then cols = cols + 1 end end
        if cols > 17 then error("line wider than the box: " .. line) end
      end
      shown[#shown + 1] = (raw:gsub("[\n\v]", " "))
      if verb == "ask" then last = answer end
    elseif verb == "jump_if_false" then if not last then i = labels[r[2]] end
    elseif verb == "jump_if_true" then if last then i = labels[r[2]] end
    elseif verb == "jump" then i = labels[r[2]]
    elseif verb == "set_flag" then flags[r[2]] = true
    elseif verb == "give_item" then bag[r[2]] = (bag[r[2]] or 0) + (r[3] or 1)
    elseif verb == "take_item" then
      -- like the engine: never more than the bag holds
      bag[r[2]] = (bag[r[2]] or 0) - math.min(r[3] or 1, bag[r[2]] or 0)
    elseif verb == "warp" then here = { mapId = r[2], x = r[3], y = r[4] }
    elseif verb == "label" then -- nothing
    else error("unexpected verb " .. tostring(verb)) end
    i = i + 1
  end
end

local mod = {
  generation = 1,
  options = { get = function(_, k) return options[k] end },
  save = {
    get = function(_, k, d) if saveData[k] == nil then return d end return saveData[k] end,
    set = function(_, k, v) saveData[k] = v end,
  },
  events = { emit = function(_, name, payload) emitted[#emitted + 1] = { name = name, p = payload } end },
  log = { warn = function() end, info = function() end },
  world = {
    getFlag = function(_, name) return flags[name] == true end,
    setFlag = function(_, name, v) flags[name] = v and true or nil return true end,
    current = function() return here end,
    spawnNpc = function(_, mapId, def)
      if busy then return nil, "world is busy" end
      spawned[#spawned + 1] = { mapId = mapId, def = def } return 900
    end,
    removeNpc = function(_, id)
      if busy then return nil, "world is busy" end
      spawned.removed = id return true
    end,
    queueScript = function(_, rows, extra)
      if busy then return nil, "busy" end
      runRows(rows)
      if extra and extra.onDone then extra.onDone(true) end
      return true
    end,
  },
  content = {
    item_effects = { register = function(_, id, r) registered.effect = { id = id, r = r } end },
    balls = { register = function(_, id, r) registered.ball = { id = id, r = r } end },
    pokemon = { has = function(_, id) return KNOWN[id] == true end,
                get = function(_, id) return KNOWN[id] and { name = id } or nil end },
    items = {
      get = function(_, id)
        return { name = (id:gsub("_", " ")), ball = id == "PARK_BALL" and "PARK_BALL" or nil }
      end,
      register = function(_, id, r) registered.item = { id = id, r = r } end,
    },
  },
}

local swarms = include("lib/swarms.lua")(mod, rng, calendar)
local contest = include("lib/contest.lua")(mod, rng, calendar, swarms, text)
contest.setup(kanto.contest)

-- ------- the contest ball is a real item: a ball the bag throws and uses up
eq(registered.item and registered.item.id, "PARK_BALL", "PARK BALL is registered as an item")
eq(registered.item.r.name, "PARK BALL", "named PARK BALL")
eq(registered.item.r.effect, registered.effect.id, "with the contest-ball effect")
eq(registered.item.r.ball, "PARK_BALL", "and its own catch numbers")
eq(registered.item.r.tossable, false, "it can't be tossed")
eq(registered.effect.r.use(), "ball", "using it in battle throws it")
eq(registered.effect.r.field, false, "not usable in the field")
eq(registered.ball.r.randMax, 200, "catches like a GREAT BALL")

-- pick a contest day by shifting the calendar to the next Tuesday
local real = calendar.today()
local toTuesday = (3 - real.weekday) % 7
calendar.offset = function() return options.test_days or 0 end
options.test_days = toTuesday + 1      -- a Wednesday first
check(not contest.isContestDay(), "Wednesday is not a contest day")
contest.talk()
check(shown[#shown]:find("next one is on THURSDAY", 1, true), "off-day, the officer names the next contest day")
check(not contest.active(), "and no contest starts")
options.test_days = toTuesday
check(contest.isContestDay(), "Tuesday is a contest day")

-- ------- the officer appears once the warp into the gate settles
-- map.entered fires while the warp is still finishing; the engine refuses
-- NPC changes then, so the officer waits for the world to settle
busy = true
contest.spawnOfficer("VIRIDIAN_FOREST_SOUTH_GATE")
eq(#spawned, 0, "no officer while the warp is finishing")
contest.tick(0.016)
eq(#spawned, 0, "still none while the world is busy")
busy = false
contest.tick(0.016)
eq(#spawned, 1, "the officer is placed once the gate is idle")
eq(spawned[1].def.sprite, "SPRITE_GENTLEMAN", "with the officer sprite")
eq(spawned[1].def.x .. "," .. spawned[1].def.y, "6,1", "beside the forest door, off the desks")
eq(spawned[1].def.range, "LEFT", "facing the path")
contest.spawnOfficer("VIRIDIAN_FOREST_SOUTH_GATE")
contest.tick(0.016)
eq(#spawned, 1, "re-entering the gate doesn't place a second officer")
check(contest.isOfficer({ id = 900 }), "the officer is recognised by id")
check(contest.isOfficer({ id = "x", def = { name = "FIELD_DAY_OFFICER" } }), "and by name")
check(not contest.isOfficer({ id = 5, def = { name = "GIRL" } }), "other NPCs are not")

-- ------- the officer signs you up
answer = false
contest.talk()
check(not contest.active(), "saying NO doesn't start the contest")
eq(bag.PARK_BALL, nil, "and gives no balls")

answer = true
contest.talk()
local s = contest.active()
check(s ~= nil, "saying YES starts the contest")
eq(bag.PARK_BALL, 20, "with 20 PARK BALLs")
eq(s.remaining, 20 * 60, "and 20 minutes on the clock")
eq(emitted[#emitted].name, "mod.field_day.contest_started", "contest_started is emitted")
eq(s.tier, 0, "no badges means the first tier")

-- ------- swarms stay out of the forest on contest days
check(contest.blocksSwarm({ map = "VIRIDIAN_FOREST" }, calendar.today()), "swarms skip the forest today")
check(not contest.blocksSwarm({ map = "ROUTE_1" }, calendar.today()), "but not other routes")

-- ------- encounters in the forest are contest bugs
here = { mapId = "VIRIDIAN_FOREST" }
local seq = { 0.5, 0.5 }
local k = 0
local sp, lv = contest.encounter("VIRIDIAN_FOREST", function() k = k + 1 return seq[(k - 1) % 2 + 1] end)
check(sp ~= nil and KNOWN[sp], "a forest encounter is a contest bug (" .. tostring(sp) .. ")")
check(lv >= 4 and lv <= 8, "at a first-tier level (" .. tostring(lv) .. ")")
eq(contest.encounter("ROUTE_2", math.random), nil, "other maps are untouched")
local dist = contest.distribution("VIRIDIAN_FOREST")
check(dist and dist.CATERPIE == 30, "the preview shows the contest table")

-- ------- catches are scored; the best one is kept
contest.onCatch({ species = "CATERPIE", mon = { level = 5, hp = 10, maxHp = 20, dvs = { atk = 3 } } })
eq(s.best.species, "CATERPIE", "the first catch becomes the best")
contest.onCatch({ species = "BEEDRILL", mon = { level = 8, hp = 25, maxHp = 25, dvs = { atk = 15, def = 15 } } })
eq(s.best.species, "BEEDRILL", "a better catch replaces it")
local beedrill = s.best.score
contest.onCatch({ species = "WEEDLE", mon = { level = 4, hp = 5, maxHp = 18 } })
eq(s.best.species, "BEEDRILL", "a worse catch doesn't")
eq(beedrill, 60 + 16 + 20 + 10, "the score is species + 2*level + HP + DVs")

-- ------- only PARK BALLs in the forest during the contest
check(contest.ballRefusal("POKE_BALL", true):find("Only PARK BALLs", 1, true), "a POKé BALL is refused")
check(contest.ballRefusal("ULTRA_BALL", true) ~= nil, "so is an ULTRA BALL")
eq(contest.ballRefusal("PARK_BALL", true), nil, "PARK BALLs are fine")
eq(contest.ballRefusal("POTION", true), nil, "other items are fine")
eq(contest.ballRefusal("POKE_BALL", false), nil, "outside battle nothing is refused")
here = { mapId = "ROUTE_2" }
eq(contest.ballRefusal("POKE_BALL", true), nil, "outside the forest your own balls work")
here = { mapId = "VIRIDIAN_FOREST" }

-- ------- the on-screen counter
local hud = contest.hud()
eq(hud.balls, 20, "the counter starts at 20 balls")
eq(hud.time, "20:00", "and 20:00")
contest.onBallThrown({ ball = "PARK_BALL" })
contest.tick(65)
hud = contest.hud()
eq(hud.balls, 19, "a throw takes one off the counter")
eq(hud.time, "18:55", "and the clock runs down")
s.thrown, s.remaining = 0, 20 * 60
s.notified = {}

-- ------- the clock: notices, then time's up
for _ = 1, 3 do contest.onBallThrown({ ball = "PARK_BALL" }) end
contest.tick(20 * 60 - 299)
check(shown[#shown]:find("5 minutes left", 1, true), "a 5-minute notice")
contest.tick(240)
check(shown[#shown]:find("1 minute left", 1, true), "a 1-minute notice")
contest.tick(120)
check(not contest.active(), "time's up ends the contest")
eq(contest.hud(), nil, "the counter goes away when the contest ends")
local st = contest.state()
check(st.done and st.results and st.shown, "results are decided and shown")
eq(here.mapId, "VIRIDIAN_FOREST_SOUTH_GATE", "time's up sends you back to the gate")
eq(bag.PARK_BALL, 0, "every contest ball left in the bag is taken back")
local ended = emitted[#emitted]
eq(ended.name, "mod.field_day.contest_ended", "contest_ended is emitted")
eq(ended.p.species, "BEEDRILL", "with the judged catch")
check(ended.p.placing and ended.p.placing >= 1, "and a placing (" .. tostring(ended.p.placing) .. ")")
local sawResults = false
for _, t in ipairs(shown) do if t:find("results of today", 1, true) then sawResults = true end end
check(sawResults, "the results are announced")

-- ------- talking again the same day
local before = #shown
contest.talk()
check(shown[#shown]:find("is over", 1, true) and #shown == before + 1, "the officer says today's contest is over")

-- ------- leaving the forest ends it too; busy overworld waits
saveData.contest = nil
options.test_days = toTuesday + 2     -- Thursday
contest.talk()
check(contest.active() ~= nil, "a new contest on Thursday")
here = { mapId = "VIRIDIAN_FOREST" }
busy = true
contest.onMapEntered({ mapId = "VIRIDIAN_FOREST_NORTH_GATE", fromMapId = "VIRIDIAN_FOREST" })
here = { mapId = "VIRIDIAN_FOREST_NORTH_GATE" }
check(not contest.active(), "leaving the forest ends the contest")
check(not contest.state().shown, "results wait while the overworld is busy")
busy = false
contest.tick(1.1)
check(contest.state().shown, "and show once it's free")
eq(contest.state().results.placing, nil, "no catch means no placing")

-- ------- running out of balls
saveData.contest = nil
options.test_days = toTuesday + 4     -- Saturday
contest.talk()
for _ = 1, 20 do contest.onBallThrown({ ball = "PARK_BALL" }) end
contest.onBattleEnded()
check(not contest.active(), "running out of balls ends the contest")
eq(contest.state().results.reason, "balls", "for that reason")

-- ------- prizes
eq(contest.prizeFor(2, 0).item, "NUGGET", "2nd place wins a NUGGET")
eq(contest.prizeFor(1, 0).item, "MOON_STONE", "1st place rotates through stones")
eq(contest.prizeFor(1, 1).item, "FIRE_STONE", "day by day")
eq(contest.prizeFor(7, 0).item, "POTION", "everyone else who caught something gets a POTION")
eq(contest.prizeFor(nil, 0), nil, "no catch, no prize")

-- ------- the officer leaves on a non-contest day
here = { mapId = "VIRIDIAN_FOREST_SOUTH_GATE" }
options.test_days = toTuesday + 1
contest.spawnOfficer("VIRIDIAN_FOREST_SOUTH_GATE")
eq(spawned.removed, 900, "the officer is removed on a non-contest day")

-- ------- badges raise the tier
flags.EVENT_BEAT_BROCK, flags.EVENT_BEAT_MISTY = true, true
eq(contest.tier().badges, 2, "two badges unlock the second tier")
for _, f in ipairs(kanto.contest.progressFlags) do flags[f] = true end
eq(contest.tier().badges, 6, "eight badges use the top tier")

print(("%d/%d checks passed%s  (contest)"):format(passed, passed + failed,
  failed > 0 and (", " .. failed .. " FAILURES") or ""))
os.exit(failed == 0 and 0 or 1)
