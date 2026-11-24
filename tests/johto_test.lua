-- Unit test for the Gold/Silver/Crystal region (regions/johto.lua) against a
-- fake Gen 2 mod object: the sixteen-badge progress, Kanto contests that
-- wait for the Johto badges, two contests on one day, the DRAGON'S DEN's
-- SURF-or-rod rule, the games' own balls, and the ROUTE REPORT's notes.
--   luajit tests/johto_test.lua [path-to-repo]
local root = (arg[1] or ".") .. "/catch_of_the_day/"

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
local johto = include("regions/johto.lua")
local text = include("lib/textbox.lua")

-- ------- the fake mod

local saveData, flags, options, shown, bag = {}, {}, {}, {}, {}
local here = { mapId = "NEW_BARK_TOWN" }
local spawned, nextNpc = {}, 900
local registered = { items = 0, screens = 0 }

local KNOWN = {}
for _, sw in ipairs(johto.swarms) do KNOWN[sw.species] = true end
for _, c in ipairs(johto.contests) do
  for _, tier in ipairs(c.tiers) do
    for _, row in ipairs(tier.species) do KNOWN[row[1]] = true end
  end
end

local function cols(line)
  local n = 0
  for k = 1, #line do local b = line:byte(k) if b < 0x80 or b >= 0xC0 then n = n + 1 end end
  return n
end

local function fits(raw)
  for line in (raw .. "\v"):gmatch("([^\n\v\f]*)[\n\v\f]") do
    if cols(line) > 17 then return false, line end
  end
  return true
end

local function runRows(rows)
  local labels = {}
  for i, r in ipairs(rows) do if r[1] == "label" then labels[r[2]] = i end end
  local last, i = nil, 1
  while i <= #rows do
    local r = rows[i]
    local verb = r[1]
    if verb == "show_text" or verb == "ask" then
      local ok, wide = fits(r[2])
      if not ok then error("line wider than the box: " .. wide) end
      shown[#shown + 1] = (r[2]:gsub("[\n\v\f]", " "))
      if verb == "ask" then last = true end
    elseif verb == "check_item" then last = (bag[r[2]] or 0) > 0
    elseif verb == "jump_if_false" then if not last then i = labels[r[2]] end
    elseif verb == "jump_if_true" then if last then i = labels[r[2]] end
    elseif verb == "jump" then i = labels[r[2]]
    elseif verb == "set_flag" then flags[r[2]] = true
    elseif verb == "give_item" then bag[r[2]] = (bag[r[2]] or 0) + (r[3] or 1)
    elseif verb == "take_item" then
      bag[r[2]] = (bag[r[2]] or 0) - math.min(r[3] or 1, bag[r[2]] or 0)
    elseif verb == "warp" then here = { mapId = r[2], x = r[3], y = r[4] }
    elseif verb == "label" then -- nothing
    else error("unexpected verb " .. tostring(verb)) end
    i = i + 1
  end
end

local mod = {
  generation = 2,
  options = { get = function(_, k) return options[k] end },
  save = {
    get = function(_, k, d) if saveData[k] == nil then return d end return saveData[k] end,
    set = function(_, k, v) saveData[k] = v end,
  },
  events = { emit = function() end },
  log = { warn = function() end, info = function() end },
  ui = { push = function() end, TextBox = { new = function() return {} end } },
  world = {
    getFlag = function(_, name) return flags[name] == true end,
    setFlag = function(_, name, v) flags[name] = v and true or nil return true end,
    current = function() return here end,
    spawnNpc = function(_, mapId, def)
      nextNpc = nextNpc + 1
      spawned[#spawned + 1] = { mapId = mapId, def = def, id = nextNpc }
      return nextNpc
    end,
    removeNpc = function() return true end,
    queueScript = function(_, rows, extra)
      runRows(rows)
      if extra and extra.onDone then extra.onDone(true) end
      return true
    end,
  },
  content = {
    screens = { register = function() registered.screens = registered.screens + 1 end },
    item_effects = { register = function() registered.items = registered.items + 1 end },
    balls = { register = function() registered.items = registered.items + 1 end },
    pokemon = { has = function(_, id) return KNOWN[id] == true end,
                get = function(_, id) return KNOWN[id] and { name = id } or nil end },
    items = {
      get = function(_, id)
        local balls = { POKE_BALL = 1, PARK_BALL = 1, LURE_BALL = 1, ULTRA_BALL = 1 }
        return { name = (id:gsub("_", " ")), ball = balls[id] and id or nil }
      end,
      register = function() registered.items = registered.items + 1 end,
    },
  },
}

local swarms = include("lib/swarms.lua")(mod, rng, calendar)
local contest = include("lib/contest.lua")(mod, rng, calendar, swarms, text)
contest.setup(johto.contests, johto.contestDefaults)
local report = include("lib/report.lua")(mod, swarms, contest, text)
report.setNotes(johto.notes)
swarms.setExclusion(contest.blocksSwarm)
swarms.setProgress(function() return contest.progress() end)
for _, spec in ipairs(johto.swarms) do assert(swarms.add(spec, { "gen2" })) end

calendar.offset = function() return options.test_days or 0 end
local real = calendar.today()
local function goTo(weekday)
  options.test_days = (weekday - real.weekday) % 7
end
local FLAGS = johto.contestDefaults.progressFlags
local function badges(n)
  for i, f in ipairs(FLAGS) do flags[f] = i <= n or nil end
end
local function ids(list)
  local out = {}
  for _, d in ipairs(list) do out[#out + 1] = d.id end
  return table.concat(out, ",")
end

-- ------- setup
eq(#contest.contests(), 13, "13 contests (6 Johto, 7 Kanto)")
eq(registered.items, 0, "nothing registered: the games' own PARK BALL is used")
eq(#FLAGS, 16, "progress counts sixteen gym leaders")
for _, d in ipairs(contest.contests()) do
  check(d.officer.map:find("POKECENTER_1F", 1, true) ~= nil, d.id .. " officer is in a CENTER")
  eq(d.officer.x .. "," .. d.officer.y, "6,4", d.id .. " officer spot")
  eq(d.balls.item, "PARK_BALL", d.id .. " uses PARK BALLs")
end

-- ------- the week, before and after the Johto badges
local BEFORE = { "dragon", "fishing_johto", "", "cave", "ghost", "ice", "dark" }
local AFTER = { "dragon,electric", "fishing_johto,fishing_kanto", "rock", "cave,fire",
                "ghost,plant", "ice,steel", "dark,normal" }
badges(7)
for wd = 1, 7 do
  goTo(wd)
  eq(ids(contest.todays()), BEFORE[wd], "7 badges, weekday " .. wd)
end
badges(8)
for wd = 1, 7 do
  goTo(wd)
  eq(ids(contest.todays()), AFTER[wd], "8 badges, weekday " .. wd)
end

-- the Kanto officer only turns up once the contest is unlocked
badges(0)
goTo(1)
here = { mapId = "ROUTE_10_POKECENTER_1F" }
contest.spawnOfficer(here.mapId)
eq(#spawned, 0, "no ROUTE 10 officer with no badges")
badges(8)
contest.spawnOfficer(here.mapId)
eq(#spawned, 1, "the ROUTE 10 officer appears with 8 badges")
eq(spawned[1] and spawned[1].def.sprite, "SPRITE_OFFICER", "as an officer")

-- ------- tiers follow all sixteen badges
local dragon = contest.get("dragon")
badges(8)
eq(contest.tier(dragon).badges, 0, "8 badges: the dragon contest's first tier")
badges(12)
eq(contest.tier(dragon).badges, 12, "12 badges: its last tier")

-- ------- the ROUTE REPORT: both contests, plus the games' own bug contest
badges(8)
goTo(5)   -- Thursday
local news = report.text()
check(news:find("GHOST CONTEST", 1, true) ~= nil, "Thursday's news has the ghost contest")
check(news:find("PLANT CONTEST", 1, true) ~= nil, "and the plant contest")
check(news:find("NATIONAL PARK", 1, true) ~= nil, "and the NATIONAL PARK's bug contest")
check(fits(text.box(news)), "the news fits the box")
goTo(2)   -- Monday
check(report.text():find("NATIONAL PARK", 1, true) == nil, "no bug contest note on Monday")
check(report.isNewsSpot("GOLDENROD_POKECENTER_1F"), "a Gen 2 CENTER is a news spot")
check(report.isNewsSpot("PLAYERS_HOUSE_1F"), "and so is the player's house")
check(not report.isNewsSpot("POKECENTER_2F"), "but not the CENTER's upstairs")

-- ------- signing up and every contest's lines and results fit the box
local function runContest(d, weekday)
  saveData.contest = nil
  for k in pairs(bag) do bag[k] = nil end
  bag.SUPER_ROD = 1
  goTo(weekday)
  here = { mapId = d.officer.map }
  check(contest.talk(d), d.id .. " officer answers")
  local s = contest.active()
  check(s ~= nil, d.id .. " starts")
  eq(bag.PARK_BALL, 20, d.id .. " hands out 20 PARK BALLs")
  here = { mapId = d.maps[1] }
  local k = 0
  local seq = function() k = k + 1 return (k * 0.37) % 1 end
  local sp, lv
  if d.method == "fishing" then sp, lv = contest.fishing(d.maps[1], seq)
  else sp, lv = contest.encounter(d.maps[1], seq) end
  check(sp ~= nil and KNOWN[sp], d.id .. " venue gives a contest POKéMON")
  contest.onCatch({ species = sp, mon = { level = lv, hp = 10, maxHp = 20 } })
  contest.finish("time")
  eq(bag.PARK_BALL, 0, d.id .. " collects the leftover balls")
  local st = contest.state()
  check(st.results and st.results.placing ~= nil, d.id .. " you are placed")
  contest.tick(0.016)
  eq(here.mapId, d.officer.map, d.id .. " the ride back lands in the officer's CENTER")
  eq(here.x .. "," .. here.y, "6,5", d.id .. " in front of the officer")
end
badges(16)
for _, d in ipairs(contest.contests()) do
  local ok, err = pcall(runContest, d, d.weekdays[1])
  check(ok, d.id .. " runs (" .. tostring(err) .. ")")
end

-- ------- the DRAGON'S DEN counts SURF and the rod; the derby only the rod
badges(8)
saveData.contest = nil
goTo(1)
contest.start(dragon)
local r = function() return 0.5 end
check(contest.encounter("DRAGONS_DEN_B1F", r) ~= nil, "surfing in the DEN finds a dragon contest POKéMON")
check(contest.fishing("DRAGONS_DEN_B1F", r) ~= nil, "and so does fishing")
contest.finish("time")
saveData.contest = nil
goTo(2)
contest.start(contest.get("fishing_johto"))
check(contest.encounter("LAKE_OF_RAGE", r) == nil, "the LAKE derby ignores surfing")
check(contest.fishing("LAKE_OF_RAGE", r) ~= nil, "and counts the rod")

-- the derby asks for a rod
contest.finish("time")
saveData.contest = nil
for k in pairs(bag) do bag[k] = nil end
here = { mapId = "MAHOGANY_POKECENTER_1F" }
local before = #shown
contest.talk(contest.get("fishing_johto"))
check(shown[before + 1] and shown[before + 1]:find("FISHING ROD", 1, true), "no rod, no derby")
check(contest.active() == nil, "and it doesn't start")

-- ------- the games' own balls stay in the bag during a contest
saveData.contest = nil
goTo(5)
contest.start(contest.get("ghost"))
here = { mapId = "BURNED_TOWER_1F" }
check(contest.ballRefusal("POKE_BALL", true) ~= nil, "POKé BALL refused in the venue")
check(contest.ballRefusal("LURE_BALL", true) ~= nil, "APRICORN balls refused too")
check(contest.ballRefusal("PARK_BALL", true) == nil, "PARK BALL allowed")
contest.finish("time")

-- ------- swarms: Johto first, Kanto with the badges, never the games' own routes
local NATIVE = { ROUTE_35 = true, ROUTE_32 = true, DARK_CAVE_VIOLET_ENTRANCE = true,
                 NATIONAL_PARK = true }
for _, sw in ipairs(johto.swarms) do
  check(not NATIVE[sw.map], sw.map .. " is not one of the games' own swarm routes")
end
saveData.visited = {}
badges(0)
goTo(2)
local early = swarms.candidates(calendar.today())
local kanto = 0
for _, c in ipairs(early) do if c.badges >= 8 then kanto = kanto + 1 end end
eq(kanto, 0, "no Kanto swarms at the start")
check(#early >= 3, "a few Johto swarms are open at the start")
badges(16)
local late = swarms.candidates(calendar.today())
local kantoLate = 0
for _, c in ipairs(late) do if c.badges >= 8 then kantoLate = kantoLate + 1 end end
check(kantoLate >= 10, "Kanto swarms open with the badges")

print(("%d/%d checks passed  (johto)"):format(passed, passed + failed))
os.exit(failed == 0 and 0 or 1)
