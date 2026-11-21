-- Field Day: daily events for gen1recomp.
--
-- Milestone 1: swarms and the ROUTE REPORT on Red, Blue and Yellow.
-- Contests and the Gen 2 / Gen 3 regions come next.
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
  local swarms = include("lib/swarms.lua")(mod, rng, calendar)
  local report = include("lib/report.lua")(mod, swarms)

  local REGIONS = { [1] = { file = "regions/kanto.lua", games = { "gen1" } } }

  local region = REGIONS[mod.generation or 1]
  if region then
    for _, spec in ipairs(include(region.file)) do
      spec.source = "field_day"
      local ok, why = swarms.add(spec, region.games)
      if not ok then mod.log:warn("built-in swarm skipped: %s", tostring(why)) end
    end
  end

  -- ------- options

  mod.options:define({
    { key = "swarms", label = "SWARMS", type = "toggle", default = true },
    { key = "swarm_rate", label = "SWARM SHARE", type = "choice", default = "50",
      choices = { { "LOW (30%)", "30" }, { "MEDIUM (50%)", "50" }, { "HIGH (70%)", "70" } } },
    { key = "news_menu", label = "NEWS IN START MENU", type = "toggle", default = true },
    { key = "news_daily", label = "DAILY BULLETIN", type = "toggle", default = true },
    { key = "swarm_notice", label = "SWARM NOTICE", type = "toggle", default = true },
  })

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
    local swarm = activeSwarm(ctx.mapId, ctx.terrain)
    if not swarm then return enc end
    local random = ctx.rng or math.random
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

  -- ------- the ROUTE REPORT

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or not mod.options:get("news_menu") then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "NEWS",
      onSelect = function() report.open(game) end,
    })
  end)

  -- Bulletins wait for the player's first step on the new map, so they never
  -- land mid-warp, and they back off while a story script is running.
  local pending = nil
  local function showPending()
    local p = pending
    pending = nil
    if not p then return end
    if p.kind == "news" then
      if report.say(report.text()) then mod.save:set("news_day", p.day) end
    elseif p.kind == "notice" then
      if report.say(p.text) then mod.save:set("notice_day", p.day) end
    end
  end

  mod.events:on("map.entered", function(ev)
    if type(ev) ~= "table" or type(ev.mapId) ~= "string" then return end
    swarms.noteVisit(ev.mapId)
    if ev.via == "boot" then return end

    local swarm, _, day = swarms.today()
    local want = nil
    if mod.options:get("news_daily") and report.isNewsSpot(ev.mapId)
       and mod.save:get("news_day", nil) ~= day.day then
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
    }
  end

  mod.exports.reportText = function() return report.text() end
end
