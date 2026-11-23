-- Unit test for lib/contest.lua against a fake mod object.  The headless
-- engine has no overworld to run scripts, so a tiny runner here plays the
-- officers' rows (answering YES) and records what the player would see.
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
local function lastShown(shown) return shown[#shown] or "" end

local function include(path) return dofile(root .. path) end
local rng = include("lib/rng.lua")
local calendar = include("lib/calendar.lua")
local kanto = include("regions/kanto.lua")
local text = include("lib/textbox.lua")

-- ------- the fake mod

local saveData, flags, options, emitted, shown, bag = {}, {}, {}, {}, {}, {}
local here = { mapId = "VIRIDIAN_FOREST_SOUTH_GATE" }
local spawned, nextNpc = {}, 900
local overviews = {}
local registered = { items = 0, balls = 0, effects = 0 }
local answer = true
local busy = false

local KNOWN = {}
for _, c in ipairs(kanto.contests) do
  for _, tier in ipairs(c.tiers) do
    for _, row in ipairs(tier.species) do KNOWN[row[1]] = true end
  end
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
        for k = 1, #line do local b = line:byte(k) if b < 0x80 or b >= 0xC0 then cols = cols + 1 end end
        if cols > 17 then error("line wider than the box: " .. line) end
      end
      shown[#shown + 1] = (raw:gsub("[\n\v]", " "))
      if verb == "ask" then last = answer end
    elseif verb == "check_item" then last = (bag[r[2]] or 0) > 0
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
    mapOverview = function()
      if overviews[here.mapId] then return overviews[here.mapId] end
      -- a 14x10 field: open ground, a wall row, a door at the bottom
      local rows = {}
      for y = 0, 9 do
        local row = {}
        for x = 0, 13 do
          local c = "."
          if y == 0 or x == 0 or x == 13 then c = " " end
          if y == 9 then c = (x == 6 or x == 7) and "+" or " " end
          row[#row + 1] = c
        end
        rows[#rows + 1] = table.concat(row)
      end
      return { mapId = here.mapId, width = 14, height = 10, rows = rows, markers = {} }
    end,
    spawnNpc = function(_, mapId, def)
      if busy then return nil, "world is busy" end
      nextNpc = nextNpc + 1
      spawned[#spawned + 1] = { mapId = mapId, def = def, id = nextNpc }
      return nextNpc
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
    maps = { get = function(_, id) return { objects = { { x = 4, y = 4 } } } end },
    item_effects = { register = function(_, id, r)
      registered.effects = registered.effects + 1; registered.effect = { id = id, r = r } end },
    balls = { register = function(_, id, r)
      registered.balls = registered.balls + 1; registered.ball = { id = id, r = r } end },
    pokemon = { has = function(_, id) return KNOWN[id] == true end,
                get = function(_, id) return KNOWN[id] and { name = id } or nil end },
    items = {
      get = function(_, id)
        return { name = (id:gsub("_", " ")), ball = id == "PARK_BALL" and "PARK_BALL" or nil }
      end,
      register = function(_, id, r)
        registered.items = registered.items + 1; registered.item = { id = id, r = r } end,
    },
  },
}

local swarms = include("lib/swarms.lua")(mod, rng, calendar)
local contest = include("lib/contest.lua")(mod, rng, calendar, swarms, text)
contest.setup(kanto.contests, kanto.contestDefaults)
local crowd = include("lib/crowd.lua")(mod, rng, contest)

local bug = contest.get("bug_catching")
local derby = contest.get("fishing_derby")
local rock = contest.get("rock_cave")

-- jump the calendar to the next given weekday (1 = Sunday)
calendar.offset = function() return options.test_days or 0 end
local real = calendar.today()
local function goTo(weekday, extraWeeks)
  options.test_days = (weekday - real.weekday) % 7 + 7 * (extraWeeks or 0)
end
local function reset()
  saveData.contest = nil
  for k in pairs(bag) do bag[k] = nil end
end

-- ------- setup: five contests, one shared PARK BALL
eq(#contest.contests(), 6, "six Kanto contests")
eq(registered.items, 1, "PARK BALL is registered once, not once per contest")
eq(registered.item.id, "PARK_BALL", "as PARK_BALL")
eq(registered.item.r.name, "PARK BALL", "named PARK BALL")
eq(registered.item.r.effect, registered.effect.id, "with the contest-ball effect")
eq(registered.item.r.tossable, false, "it can't be tossed")
eq(registered.effect.r.use(), "ball", "using it in battle throws it")
eq(registered.effect.r.field, false, "not usable in the field")
eq(registered.ball.r.randMax, 200, "catches like a GREAT BALL")
eq(derby.balls.item, "PARK_BALL", "every contest uses PARK BALLs (shared default)")
eq(derby.minutes, 20, "and 20 minutes")
eq(derby.prizes.second.item, "NUGGET", "shared 2nd prize")
eq(derby.prizes.first[1], "WATER_STONE", "own 1st prize")

-- ------- the week
local WEEK = { "electric", "fishing_derby", "bug_catching", "rock_cave",
               "fire", "plant", "bug_catching" }
for wd = 1, 7 do
  goTo(wd)
  local list = contest.todays()
  eq(#list, 1, ("weekday %d has one contest"):format(wd))
  eq(list[1] and list[1].id, WEEK[wd], ("weekday %d runs %s"):format(wd, WEEK[wd]))
end
goTo(2)
options.contest_fishing_derby = false
eq(#contest.todays(), 0, "a contest can be switched off on its own")
options.contest_fishing_derby = nil
options.contests = false
goTo(3)
eq(#contest.todays(), 0, "ALL CONTESTS off switches every contest off")
options.contests = nil

-- ------- the bug officer: Wednesday off, Tuesday on once the warp settles
goTo(4)
contest.spawnOfficer("VIRIDIAN_FOREST_SOUTH_GATE")
contest.tick(0.016)
eq(#spawned, 0, "no bug officer on a Wednesday")
contest.talk(bug)
check(lastShown(shown):find("held on TUESDAYS and SATURDAYS", 1, true), "off-day, he lists the days")
check(lastShown(shown):find("next one is on SATURDAY", 1, true), "and names the next one")

goTo(3)
busy = true
contest.spawnOfficer("VIRIDIAN_FOREST_SOUTH_GATE")
eq(#spawned, 0, "no officer while the warp is finishing")
contest.tick(0.016)
eq(#spawned, 0, "still none while the world is busy")
busy = false
contest.tick(0.016)
eq(#spawned, 1, "the officer is placed once the gate is idle")
local officerNpc = spawned[1]
eq(officerNpc.def.x .. "," .. officerNpc.def.y, "6,1", "beside the forest door, off the desks")
eq(officerNpc.def.range, "LEFT", "facing the path")
eq(officerNpc.def.sprite, "SPRITE_GUARD", "he's a police officer")
contest.spawnOfficer("VIRIDIAN_FOREST_SOUTH_GATE")
contest.tick(0.016)
eq(#spawned, 1, "re-entering the gate doesn't place a second officer")
eq(contest.officerFor({ id = officerNpc.id }), bug, "he is recognised by id")
eq(contest.officerFor({ id = "x", def = { name = "FIELD_DAY_OFFICER_bug_catching" } }), bug, "and by name")
eq(contest.officerFor({ id = 5, def = { name = "GIRL" } }), nil, "other NPCs are not officers")

-- ------- the bug contest
answer = false
contest.talk(bug)
check(not contest.active(), "saying NO doesn't start the contest")
eq(bag.PARK_BALL, nil, "and gives no balls")
answer = true
contest.talk({ id = officerNpc.id })
local s, running = contest.active()
check(s ~= nil, "saying YES starts it (talking to the officer NPC)")
eq(running, bug, "the bug contest is the one running")
eq(bag.PARK_BALL, 20, "with 20 PARK BALLs")
eq(s.remaining, 20 * 60, "and 20 minutes on the clock")
eq(emitted[#emitted].p.id, "bug_catching", "contest_started names the contest")

check(contest.blocksSwarm({ map = "VIRIDIAN_FOREST" }, calendar.today()), "swarms skip the forest today")
check(not contest.blocksSwarm({ map = "ROUTE_1" }, calendar.today()), "but not other routes")

here = { mapId = "VIRIDIAN_FOREST" }
local seq, k = { 0.5, 0.5 }, 0
local sp, lv = contest.encounter("VIRIDIAN_FOREST", function() k = k + 1 return seq[(k - 1) % 2 + 1] end)
check(sp ~= nil and KNOWN[sp], "a forest encounter is a contest bug (" .. tostring(sp) .. ")")
check(lv >= 4 and lv <= 8, "at a first-tier level (" .. tostring(lv) .. ")")
eq(contest.encounter("ROUTE_2", math.random), nil, "other maps are untouched")
eq(contest.fishing("VIRIDIAN_FOREST", math.random), nil, "the bug contest doesn't change fishing")
check(contest.distribution("VIRIDIAN_FOREST").CATERPIE == 30, "the preview shows the contest table")

check(contest.ballRefusal("POKE_BALL", true):find("Only PARK BALLs can be used in the BUG-CATCHING", 1, true), "a POKé BALL is refused")
eq(contest.ballRefusal("PARK_BALL", true), nil, "PARK BALLs are fine")
eq(contest.ballRefusal("POTION", true), nil, "other items are fine")

local hud = contest.hud()
eq(hud.balls .. " " .. hud.time, "20 20:00", "the counter starts at 20 balls and 20:00")
contest.onBallThrown({ ball = "PARK_BALL" })
contest.tick(65)
hud = contest.hud()
eq(hud.balls .. " " .. hud.time, "19 18:55", "a throw and 65 seconds later")

contest.onCatch({ species = "CATERPIE", mon = { level = 5, hp = 10, maxHp = 20, dvs = { atk = 3 } } })
eq(s.best.species, "CATERPIE", "the first catch becomes the best")
contest.onCatch({ species = "BEEDRILL", mon = { level = 8, hp = 25, maxHp = 25, dvs = { atk = 15, def = 15 } } })
eq(s.best.species, "BEEDRILL", "a better catch replaces it")
contest.onCatch({ species = "WEEDLE", mon = { level = 4, hp = 5, maxHp = 18 } })
eq(s.best.species, "BEEDRILL", "a worse catch doesn't")
eq(s.best.score, 60 + 16 + 20 + 10, "the score is species + 2*level + HP + DVs")

contest.tick(20 * 60 - 65 - 299)
check(lastShown(shown):find("5 minutes left", 1, true), "a 5-minute notice")
contest.tick(240)
check(lastShown(shown):find("1 minute left", 1, true), "a 1-minute notice")
contest.tick(120)
check(not contest.active(), "time's up ends the contest")
eq(contest.hud(), nil, "the counter goes away")
local st = contest.state()
check(st.done and st.results and st.shown, "results are decided and shown")
eq(here.mapId, "VIRIDIAN_FOREST_SOUTH_GATE", "time's up sends you back to the gate")
eq(bag.PARK_BALL, 0, "every PARK BALL left is taken back")
local ended = emitted[#emitted]
eq(ended.name, "mod.field_day.contest_ended", "contest_ended is emitted")
eq(ended.p.id .. " " .. ended.p.species, "bug_catching BEEDRILL", "with the contest and judged catch")
contest.talk(bug)
check(lastShown(shown):find("is over", 1, true), "the officer says today's contest is over")

-- ------- other contestants wander the venue
reset()
goTo(3, 2)
here = { mapId = "VIRIDIAN_FOREST_SOUTH_GATE", x = 4, y = 2 }
contest.talk(bug)
local before = #spawned
crowd.onMapEntered("VIRIDIAN_FOREST_SOUTH_GATE")
crowd.tick()
eq(#spawned, before, "no contestants outside the venue")
here = { mapId = "VIRIDIAN_FOREST", x = 6, y = 8 }
busy = true
crowd.onMapEntered("VIRIDIAN_FOREST")
crowd.tick()
eq(#spawned, before, "none while the warp into the forest finishes")
busy = false
crowd.tick()
local wanderers = {}
for i = before + 1, #spawned do wanderers[#wanderers + 1] = spawned[i] end
eq(#wanderers, 4, "four contestants appear in the forest")
local ok, spread, nearDoor, onObject, nearYou = true, true, false, false, false
for i, w in ipairs(wanderers) do
  if w.def.movement ~= "WALK" or w.def.range ~= "ANY_DIR" then ok = false end
  if w.def.y >= 7 and (w.def.x >= 4 and w.def.x <= 9) then nearDoor = true end
  if w.def.x == 4 and w.def.y == 4 then onObject = true end
  if math.abs(w.def.x - 6) <= 3 and math.abs(w.def.y - 8) <= 3 then nearYou = true end
  for j = i + 1, #wanderers do
    local o = wanderers[j]
    -- 3 cells apart where there's room; on this small field the fallback
    -- may close in, but never side by side
    if math.abs(o.def.x - w.def.x) <= 1 and math.abs(o.def.y - w.def.y) <= 1 then spread = false end
  end
end
check(ok, "they wander freely")
check(not nearDoor, "none start next to the door")
check(not onObject, "none start on another NPC's cell")
check(not nearYou, "none start right next to you")
check(spread, "they never start side by side")
check(wanderers[1].def.sprite == "SPRITE_YOUNGSTER", "dressed for the bug contest")
crowd.onMapEntered("VIRIDIAN_FOREST")
crowd.tick()
eq(#spawned, before + 4, "re-entering doesn't add more")
-- the talk hook gets the engine's own NPC, whose id isn't the one the
-- spawn returned, so contestants are found by name
local said = crowd.lineFor({ id = "VIRIDIAN_FOREST_obj_99", def = { name = wanderers[1].def.name } })
check(type(said) == "string" and #said > 0, "they have something to say (" .. tostring(said) .. ")")
eq(crowd.lineFor({ id = wanderers[1].id }), said, "found by id as well")
local seen, distinct, names = {}, true, {}
for _, w in ipairs(wanderers) do
  local line = crowd.lineFor({ def = { name = w.def.name } })
  if seen[line] then distinct = false end
  seen[line] = true
  names[w.def.name] = true
end
check(distinct, "each contestant says something different")
local n = 0 for _ in pairs(names) do n = n + 1 end
eq(n, 4, "and each has their own name")
eq(crowd.lineFor({ id = "someone else", def = { name = "GIRL" } }), nil, "other NPCs aren't contestants")
contest.finish("left")
for _ = 1, 6 do crowd.tick() end
eq(crowd.pendingRemovals(), 0, "when the contest ends they all leave")
eq(next(crowd.placed()), nil, "and nothing is left placed")

-- ------- the Fishing Derby: a rod to enter, every cast bites
reset()
goTo(2)
here = { mapId = "VERMILION_POKECENTER" }
contest.spawnOfficer("VERMILION_POKECENTER")
local derbyNpc = spawned[#spawned]
eq(derbyNpc.mapId, "VERMILION_POKECENTER", "the derby officer is in the VERMILION POKéMON CENTER")
eq(derbyNpc.def.x .. "," .. derbyNpc.def.y, "6,5", "at the shared center spot")
contest.talk({ id = derbyNpc.id })
check(lastShown(shown):find("need a FISHING ROD", 1, true), "no rod, no entry")
check(not contest.active(), "and no contest")
bag.OLD_ROD = 1
contest.talk({ id = derbyNpc.id })
local ds, dd = contest.active()
eq(dd, derby, "with a rod, the derby starts")
here = { mapId = "VERMILION_CITY" }
eq(contest.encounter("VERMILION_CITY", math.random), nil, "walking encounters are left alone")
local fsp, flv = contest.fishing("VERMILION_CITY", function() return 0.3 end)
check(fsp ~= nil and KNOWN[fsp], "a cast in the city bites with a derby POKéMON (" .. tostring(fsp) .. ")")
check(flv >= 5 and flv <= 10, "at a first-tier level")
check(contest.fishing("VERMILION_DOCK", math.random) ~= nil, "the dock counts too")
eq(contest.fishing("ROUTE_6", math.random), nil, "fishing elsewhere is normal")
check(contest.ballRefusal("POKE_BALL", true) ~= nil, "own balls are refused at the derby too")
contest.onCatch({ species = "STARYU", mon = { level = 9, hp = 30, maxHp = 30 } })
contest.onMapEntered({ mapId = "VERMILION_POKECENTER", fromMapId = "VERMILION_CITY" })
check(not contest.active(), "leaving VERMILION CITY ends the derby")
eq(contest.state().results.reason, "left", "for that reason")
check(contest.state().results.placing ~= nil, "and the STARYU is judged")

-- ------- derby anglers stand at the water's edge; sailors walk the dock
do
  -- a harbour: open ground on the left, the sea on the right, a door below
  local rows = {}
  for y = 0, 11 do
    local row = {}
    for x = 0, 15 do
      local c = "."
      if x >= 10 then c = "~" end
      if y == 0 or x == 0 then c = " " end
      if y == 11 then c = (x == 3) and "+" or " " end
      row[#row + 1] = c
    end
    rows[#rows + 1] = table.concat(row)
  end
  overviews.VERMILION_CITY = { mapId = "VERMILION_CITY", rows = rows, markers = {} }
end
reset()
goTo(2, 1)
bag.OLD_ROD = 1
here = { mapId = "VERMILION_POKECENTER", x = 3, y = 5 }
contest.talk(derby)
check(contest.active() ~= nil, "a new derby")
local before = #spawned
here = { mapId = "VERMILION_CITY", x = 3, y = 9 }
crowd.onMapEntered("VERMILION_CITY")
crowd.tick()
local anglers = {}
for i = before + 1, #spawned do anglers[#anglers + 1] = spawned[i] end
eq(#anglers, 4, "four anglers in the city")
local onShore, still, facingSea = true, true, true
for _, a in ipairs(anglers) do
  if a.def.x ~= 9 then onShore = false end
  if a.def.movement ~= "STAY" then still = false end
  if a.def.range ~= "RIGHT" then facingSea = false end
end
check(onShore, "they stand right at the water's edge")
check(still, "and stay put")
check(facingSea, "facing the water")
check(anglers[3].def.sprite == "SPRITE_FISHING_GURU", "dressed as anglers")
local seenLines, repeated = {}, false
for _, a in ipairs(anglers) do
  local line = crowd.lineFor({ def = { name = a.def.name } })
  if seenLines[line] then repeated = true end
  seenLines[line] = true
end
check(not repeated, "no two anglers say the same thing")
before = #spawned
here = { mapId = "VERMILION_DOCK", x = 6, y = 8 }
crowd.onMapEntered("VERMILION_DOCK")
crowd.tick()
eq(#spawned - before, 2, "two more on the S.S. ANNE dock")
eq(spawned[#spawned].def.movement, "WALK", "who stroll about")
local dockLine = crowd.lineFor({ def = { name = spawned[#spawned].def.name } })
check(dockLine and not seenLines[dockLine], "with lines nobody in the city used")
contest.finish("left")
for _ = 1, 8 do crowd.tick() end
bag.OLD_ROD = nil

-- ------- the Fire contest: Thursdays on ROUTES 7 and 8
local fire = contest.get("fire")
reset()
goTo(5)
eq(contest.todays()[1], fire, "Thursday is the FIRE CONTEST")
here = { mapId = "CELADON_POKECENTER", x = 3, y = 5 }
contest.spawnOfficer("CELADON_POKECENTER")
contest.tick(0.016)
eq(spawned[#spawned].mapId, "CELADON_POKECENTER", "its officer is in the CELADON POKéMON CENTER")
contest.talk(fire)
check(contest.active() ~= nil, "it starts")
here = { mapId = "ROUTE_7", x = 3, y = 5 }
check(contest.encounter("ROUTE_8", function() return 0.4 end) ~= nil, "both routes hold fire POKéMON")
contest.finish("left")
eq(contest.prizeFor(1, 0, fire).item, "FIRE_STONE", "1st place wins a FIRE STONE")

-- ------- very rare starters and EEVEE evolutions
local function share(d, tierBadges, species)
  for _, t in ipairs(d.tiers) do
    if t.badges == tierBadges then
      local total, w = 0, 0
      for _, r in ipairs(t.species) do
        total = total + r[2]
        if r[1] == species then w = r[2] end
      end
      return w / total
    end
  end
end
eq(share(fire, 0, "CHARMANDER"), 0.01, "CHARMANDER is a 1-in-100 catch at the fire contest")
eq(share(fire, 2, "FLAREON"), 0.01, "FLAREON from 2 badges")
eq(share(derby, 2, "VAPOREON"), 0.01, "VAPOREON at the derby")
eq(share(derby, 0, "SQUIRTLE"), 0.01, "SQUIRTLE at the derby")
eq(share(contest.get("plant"), 0, "BULBASAUR"), 0.01, "BULBASAUR with the plants")
eq(share(contest.get("electric"), 2, "JOLTEON"), 0.01, "JOLTEON with the electric POKéMON")
check(fire.points.FLAREON > fire.points.ARCANINE, "and they score above everything else")

-- ------- the Rock Contest: one venue across several cave floors
reset()
goTo(4)
here = { mapId = "MT_MOON_POKECENTER" }
contest.spawnOfficer("MT_MOON_POKECENTER")
contest.talk({ id = spawned[#spawned].id })
local _, rd = contest.active()
eq(rd, rock, "the Rock Contest starts in the MT. MOON POKéMON CENTER")
here = { mapId = "MT_MOON_1F" }
contest.onMapEntered({ mapId = "MT_MOON_1F", fromMapId = "ROUTE_4" })
contest.onMapEntered({ mapId = "MT_MOON_B1F", fromMapId = "MT_MOON_1F" })
check(contest.active() ~= nil, "going down a floor stays inside the venue")
check(contest.encounter("MT_MOON_B1F", function() return 0.5 end) ~= nil, "B1F holds contest POKéMON")
contest.onMapEntered({ mapId = "ROUTE_4", fromMapId = "MT_MOON_B1F" })
check(not contest.active(), "leaving the cave ends it")

-- ------- leaving while the overworld is busy: results wait
reset()
goTo(3)
here = { mapId = "VIRIDIAN_FOREST_SOUTH_GATE" }
contest.talk(bug)
here = { mapId = "VIRIDIAN_FOREST" }
busy = true
contest.onMapEntered({ mapId = "VIRIDIAN_FOREST_NORTH_GATE", fromMapId = "VIRIDIAN_FOREST" })
here = { mapId = "VIRIDIAN_FOREST_NORTH_GATE" }
check(not contest.active(), "leaving the forest ends the contest")
check(not contest.state().shown, "results wait while the overworld is busy")
busy = false
contest.tick(0.2)
check(contest.state().shown, "and show once it's free")
eq(contest.state().results.placing, nil, "no catch means no placing")

-- ------- running out of balls
reset()
goTo(3, 1)
contest.talk(bug)
for _ = 1, 20 do contest.onBallThrown({ ball = "PARK_BALL" }) end
contest.onBattleEnded()
check(not contest.active(), "running out of balls ends the contest")
eq(contest.state().results.reason, "balls", "for that reason")

-- ------- the officer leaves on a day without his contest
goTo(4)
here = { mapId = "VIRIDIAN_FOREST_SOUTH_GATE" }
contest.spawnOfficer("VIRIDIAN_FOREST_SOUTH_GATE")
eq(spawned.removed, officerNpc.id, "the bug officer is removed on a non-contest day")

-- ------- prizes
eq(contest.prizeFor(2, 0, bug).item, "NUGGET", "2nd place wins a NUGGET")
eq(contest.prizeFor(1, 0, bug).item, "MOON_STONE", "bug 1st place rotates through stones")
eq(contest.prizeFor(1, 1, bug).item, "FIRE_STONE", "day by day")
eq(contest.prizeFor(1, 1, derby).item, "WATER_STONE", "the derby always gives a WATER STONE")
eq(contest.prizeFor(7, 0, bug).item, "POTION", "everyone else who caught something gets a POTION")
eq(contest.prizeFor(nil, 0, bug), nil, "no catch, no prize")

-- ------- badges raise the tier
flags.EVENT_BEAT_BROCK, flags.EVENT_BEAT_MISTY = true, true
eq(contest.tier(bug).badges, 2, "two badges unlock the second tier")
for _, f in ipairs(kanto.contestDefaults.progressFlags) do flags[f] = true end
eq(contest.tier(derby).badges, 6, "eight badges use the top tier")

-- ------- the daily bulletin: once per play session per day
do
  local function session()
    local m = setmetatable({
      content = setmetatable({ screens = { register = function() end } }, { __index = mod.content }),
      ui = { TextBox = { new = function() return {} end }, push = function() end },
    }, { __index = mod })
    return include("lib/report.lua")(m, swarms, contest, text)
  end
  local r = session()
  check(r.bulletinDue("VIRIDIAN_POKECENTER", 100), "the first POKéMON CENTER of the session shows it")
  r.markBulletin(100)
  check(not r.bulletinDue("PEWTER_POKECENTER", 100), "the next one the same day doesn't")
  check(not r.bulletinDue("REDS_HOUSE_1F", 100), "nor does going home")
  check(not r.bulletinDue("ROUTE_1", 101), "other maps never show it")
  check(r.bulletinDue("CERULEAN_POKECENTER", 101), "after midnight in the same session it shows again")
  r.markBulletin(101)
  check(not r.bulletinDue("CERULEAN_POKECENTER", 101), "once")
  local fresh = session()
  check(fresh.bulletinDue("VIRIDIAN_POKECENTER", 101), "starting the game again shows it again, same day")
end

print(("%d/%d checks passed%s  (contest)"):format(passed, passed + failed,
  failed > 0 and (", " .. failed .. " FAILURES") or ""))
os.exit(failed == 0 and 0 or 1)
