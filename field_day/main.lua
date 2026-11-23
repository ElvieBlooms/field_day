-- Field Day: daily events for gen1recomp.
--
-- Red, Blue and Yellow (regions/kanto.lua) and Gold, Silver and Crystal
-- (regions/johto.lua): daily swarms, contests and the ROUTE REPORT.  The
-- Gen 3 region comes next.
--
-- Other mods can add swarms through mod.find("field_day").exports; see
-- README.md, "For mod authors".
local API_VERSION = 1

return function(mod)
  -- ------- loading our own files (mod:read + load keeps them addressable
  -- through the loader's filesystem, installed or in a repo)
  local function include(path)
    local source, err = mod:read(path)
    if not source then error(("field_day: %s missing (%s)"):format(path, tostring(err)), 0) end
    local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. path)
    if not chunk then error(("field_day: %s"):format(tostring(compileErr)), 0) end
    return chunk()
  end

  local rng = include("lib/rng.lua")
  local calendar = include("lib/calendar.lua")
  local text = include("lib/textbox.lua")
  local swarms = include("lib/swarms.lua")(mod, rng, calendar)
  local contest = include("lib/contest.lua")(mod, rng, calendar, swarms, text)
  local report = include("lib/report.lua")(mod, swarms, contest, text)
  local crowd = include("lib/crowd.lua")(mod, rng, contest)

  local REGIONS = {
    [1] = { file = "regions/kanto.lua", games = { "gen1" } },
    [2] = { file = "regions/johto.lua", games = { "gen2" } },
  }

  local region = REGIONS[mod.generation or 1]
  local regionData = region and include(region.file) or {}
  for _, spec in ipairs(regionData.swarms or {}) do
    spec.source = "field_day"
    local ok, why = swarms.add(spec, region.games)
    if not ok then mod.log:warn("built-in swarm skipped: %s", tostring(why)) end
  end
  contest.setup(regionData.contests, regionData.contestDefaults)
  report.setNotes(regionData.notes)
  swarms.setExclusion(contest.blocksSwarm)
  swarms.setProgress(function() return contest.progress() end)

  -- ------- options

  local optionRows = {
    { key = "swarms", label = "SWARMS", type = "toggle", default = true },
    { key = "swarm_rate", label = "SWARM SHARE", type = "choice", default = "50",
      choices = { { "LOW (30%)", "30" }, { "MEDIUM (50%)", "50" }, { "HIGH (70%)", "70" } } },
    { key = "news_menu", label = "NEWS IN START MENU", type = "toggle", default = true },
    { key = "news_daily", label = "DAILY BULLETIN", type = "toggle", default = true },
    { key = "swarm_notice", label = "SWARM NOTICE", type = "toggle", default = true },
    { key = "news_pc", label = "NEWS ON THE PC", type = "toggle", default = true },
    { key = "contests", label = "ALL CONTESTS", type = "toggle", default = true },
    -- For testing: pretend it is this many days later.  Each step is a new
    -- day, so swarms, bulletins and weekday events all move with it.
    { key = "test_days", label = "TEST: DAYS AHEAD", type = "number",
      default = 0, min = 0, max = 30, step = 1 },
  }
  -- one switch per contest, after ALL CONTESTS, so players keep the ones
  -- they like
  local at = 1
  for i, row in ipairs(optionRows) do if row.key == "contests" then at = i + 1 end end
  for _, d in ipairs(contest.contests()) do
    table.insert(optionRows, at, { key = d.option, label = d.name, type = "toggle", default = true })
    at = at + 1
  end
  table.insert(optionRows, at, { key = "contest_hud", label = "CONTEST COUNTER",
                                 type = "toggle", default = true })
  mod.options:define(optionRows)

  calendar.offset = function() return mod.options:get("test_days") or 0 end

  local function rate()
    return (tonumber(mod.options:get("swarm_rate")) or 50) / 100
  end

  local function activeSwarm(mapId, terrain)
    if not mod.options:get("swarms") then return nil end
    local swarm = swarms.today()
    if swarm and swarm.map == mapId and swarms.terrainMatches(swarm, terrain) then
      return swarm
    end
    return nil
  end

  -- ------- encounters

  -- The real roll: after the vanilla pick, a share of encounters on the
  -- swarm route become the swarm species.  The encounter rate is unchanged.
  mod.hooks:wrap("encounter.species", function(next, enc, ctx)
    enc = next(enc, ctx)
    if type(enc) ~= "table" or type(ctx) ~= "table" then return enc end
    -- Gold/Silver/Crystal's own BUG-CATCHING CONTEST and scripted
    -- encounters are left exactly as the game rolled them
    if ctx.kind == "contest" or ctx.kind == "script" then return enc end
    local random = ctx.rng or math.random

    -- during a contest, the venue holds only that contest's POKéMON
    local cSpecies, cLevel = contest.encounter(ctx.mapId, random)
    if cSpecies then
      local out = {}
      for k, v in pairs(enc) do out[k] = v end
      out.species, out.level = cSpecies, cLevel
      return out
    end

    local swarm = activeSwarm(ctx.mapId, ctx.terrain)
    if not swarm then return enc end
    if random() >= rate() then return enc end
    local out = {}
    for k, v in pairs(enc) do out[k] = v end
    local lo, hi = swarm.levels[1], swarm.levels[2]
    out.species = swarm.species
    out.level = math.min(hi, lo + math.floor(random() * (hi - lo + 1)))
    mod.events:emit("mod.field_day.swarm_encounter", {
      mapId = ctx.mapId, species = out.species, level = out.level,
    })
    return out
  end)

  -- The preview: encounter guides and dex radars that read
  -- mod.world:effectiveEncounters see the swarm too.
  mod.hooks:wrap("encounter.table", function(next, dist, ctx)
    dist = next(dist, ctx)
    if type(dist) ~= "table" or type(ctx) ~= "table" then return dist end
    local contestDist = contest.distribution(ctx.mapId)
    if contestDist then return contestDist end
    local swarm = activeSwarm(ctx.mapId, ctx.terrain)
    if not swarm then return dist end
    local total = 0
    for _, w in pairs(dist) do total = total + w end
    if total <= 0 then return dist end
    local share = rate()
    local out = {}
    for species, w in pairs(dist) do out[species] = w * (1 - share) end
    out[swarm.species] = (out[swarm.species] or 0) + total * share
    return out
  end)

  -- The Fishing Derby: in the venue, every cast bites and the bite is a
  -- derby POKéMON, whatever the rod
  mod.hooks:wrap("encounter.fishing", function(next, rod, mapId, candidates, ...)
    local species, level = contest.fishing(mapId, math.random)
    if species then return { species = species, level = level } end
    return next(rod, mapId, candidates, ...)
  end)

  -- ------- the ROUTE REPORT

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or not mod.options:get("news_menu") then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "NEWS",
      onSelect = function() report.open(game) end,
    })
  end)

  -- a ROUTE REPORT row on the POKéMON CENTER PC (LOG OFF stays last: the
  -- engine adds it after this hook)
  mod.hooks:wrap("ui.pc.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or mod.options:get("news_pc") == false then return out end
    out[#out + 1] = {
      label = "ROUTE REPORT", keepOpen = true,
      onSelect = function() report.open(game) end,
    }
    return out
  end)

  -- Bulletins wait for the player's first step on the new map, so they never
  -- land mid-warp, and they back off while a story script is running.
  local pending = nil
  local function showPending()
    local p = pending
    pending = nil
    if not p then return end
    if p.kind == "news" then
      if report.say(report.text()) then report.markBulletin(p.day) end
    elseif p.kind == "notice" then
      if report.say(p.text) then mod.save:set("notice_day", p.day) end
    end
  end

  mod.events:on("map.entered", function(ev)
    if type(ev) ~= "table" or type(ev.mapId) ~= "string" then return end
    swarms.noteVisit(ev.mapId)
    contest.spawnOfficer(ev.mapId)
    contest.onMapEntered(ev)
    crowd.onMapEntered(ev.mapId)
    if ev.via == "boot" then return end

    local swarm, _, day = swarms.today()
    local want = nil
    if mod.options:get("news_daily") and report.bulletinDue(ev.mapId, day.day) then
      want = { kind = "news", day = day.day }
    elseif mod.options:get("swarm_notice") and mod.options:get("swarms")
       and swarm and swarm.map == ev.mapId
       and mod.save:get("notice_day", nil) ~= day.day then
      want = { kind = "notice", day = day.day, text = report.noticeText(swarm) }
    end
    if want then
      local first = pending == nil
      pending = want
      if first then mod.events:once("world.stepped", showPending) end
    end
  end)

  -- ------- the contest

  -- the officer: claim the A press on our NPC, let everything else through
  mod.hooks:wrap("world.talk", function(next, ow, target)
    local d = contest.officerFor(target)
    if d and contest.talk(d) then return end
    local line = crowd.lineFor(target)
    if line then contest.say(line) return end
    return next(ow, target)
  end)

  mod.events:on("pokemon.caught", function(ev) contest.onCatch(ev) end)
  mod.events:on("battle.ball_thrown", function(ev) contest.onBallThrown(ev) end)
  mod.events:on("battle.ended", function() contest.onBattleEnded() end)

  -- only contest balls in the contest area: refuse others with a message
  mod.content.screens:register("FieldDayContestRule", {
    new = function(game, message)
      return mod.ui.TextBox.new(game, text.box(message), nil)
    end,
  })
  mod.hooks:wrap("item.use", function(next, game, battle, id, ...)
    local refusal = contest.ballRefusal(id, battle ~= nil)
    if refusal then
      -- not calling next claims the use, so nothing is spent
      pcall(mod.ui.push, game, "FieldDayContestRule", refusal)
      return nil
    end
    return next(game, battle, id, ...)
  end)

  -- the counter in the bottom-right corner while a contest runs, drawn in
  -- Game Boy pixels over the finished frame, only while the overworld is
  -- the screen on top (so it never covers text boxes, menus or battles)
  -- Is the plain overworld on screen?  Gen 1 keeps the overworld on the
  -- screen stack; Gold/Silver/Crystal draw it under an empty stack, with
  -- text and choice boxes owned by the World itself.
  local function overworldShowing(game)
    local stack = game and game.stack
    local ok, top = pcall(function() return stack and stack.top and stack:top() end)
    if not ok then return false end
    if (mod.generation or 1) == 1 then return top ~= nil and top.isOverworld == true end
    if top ~= nil then return false end
    local world = mod.world:overworld()
    return world ~= nil and world.textbox == nil and world.choicebox == nil
  end

  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local result = next(game, viewport)
    local info = mod.options:get("contest_hud") ~= false and contest.hud()
    if not info or type(viewport) ~= "table" then return result end
    if not overworldShowing(game) then return result end
    local Font = mod.ui.Font
    local g = love.graphics
    g.push("all")
    g.setColor(1, 1, 1, 1)
    g.translate(viewport.gameX or 0, viewport.gameY or 0)
    g.scale((viewport.gameWidth or 160) / 160, (viewport.gameHeight or 144) / 144)
    -- 9 x 4 tiles at the bottom right of the 20 x 18 tile screen
    Font.drawBox(11, 14, 9, 4)
    local balls = ("BALL\195\151%d"):format(info.balls)      -- BALLx20
    Font.draw(balls, 12 * 8, 15 * 8)
    local t = info.time
    Font.draw(t, (19 - #t) * 8, 16 * 8)                      -- right-aligned
    g.pop()
    return result
  end)

  -- the real-minute clock
  mod.hooks:wrap("core.update", function(next, game, dt)
    local result = next(game, dt)
    contest.tick(tonumber(dt) or 0)
    crowd.tick()
    return result
  end)

  -- ------- the inter-mod API (versioned; check exports.apiVersion)

  mod.exports.apiVersion = API_VERSION

  -- addSwarm{ map, species, levels = { lo, hi }, games = { "gen1" },
  --           weight?, terrain?, mapName?, early?, id? } -> entry | nil, reason
  mod.exports.addSwarm = function(spec)
    local entry, why = swarms.add(spec, nil)
    if not entry then return nil, why end
    local out = {}
    for k, v in pairs(entry) do out[k] = v end
    return out
  end

  mod.exports.removeSwarm = function(id) return swarms.remove(id) end

  -- addSwarmFilter(fn(pick, ctx)) -- runs when a new day's swarm is decided.
  -- Return nil to keep the pick, false for no swarm today, or a swarm table
  -- to replace it.  ctx = { day, weekday, generation, candidates }.
  mod.exports.addSwarmFilter = function(fn) return swarms.addFilter(fn) end

  mod.exports.swarms = function() return swarms.list() end

  -- today() -> { day, weekday, weekdayName, swarm = { map, species, levels } | nil }
  mod.exports.today = function()
    local swarm, _, day = swarms.today()
    return {
      day = day.day, weekday = day.weekday, weekdayName = day.weekdayName,
      swarm = swarm and {
        map = swarm.map, mapName = swarms.mapName(swarm), species = swarm.species,
        levels = { swarm.levels[1], swarm.levels[2] },
      } or nil,
      contest = contest.summary(day),
      contests = contest.summaries(day),
    }
  end

  mod.exports.reportText = function() return report.text() end
end
