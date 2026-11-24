-- Swarms: one route per day where a single species takes over a share of the
-- wild encounters.  The pick is stored in the save, so it stays put for the
-- whole day even as the player visits new routes.
return function(mod, rng, calendar)
  local S = {}

  local GAME_TOKEN = { [1] = "gen1", [2] = "gen2", [3] = "gen3" }
  local FAMILY = { frlg = 3, rse = 3 }
  local DEFAULT_TERRAIN = { grass = true, indoor = true }

  local entries = {}   -- every known swarm, built in and from other mods
  local byId = {}
  local filters = {}
  local excluded = function() return false end  -- (entry, today) -> skip?
  local progress = function() return 0 end      -- gym leaders beaten

  -- ------- helpers

  local function copy(t)
    local out = {}
    for k, v in pairs(t) do
      out[k] = type(v) == "table" and copy(v) or v
    end
    return out
  end

  local function save(key, default)
    local ok, value = pcall(mod.save.get, mod.save, key, default)
    if ok then return value end
    return default
  end

  local function store(key, value)
    pcall(mod.save.set, mod.save, key, value)
  end

  local function runsHere(entry)
    local gen = mod.generation or 1
    for _, token in ipairs(entry.games) do
      if token == "all" or token == GAME_TOKEN[gen] or FAMILY[token] == gen then
        return true
      end
    end
    return false
  end

  function S.speciesExists(id)
    local reg = mod.content.pokemon
    local ok, found = pcall(function()
      if reg.has then return reg:has(id) end
      return reg:get(id) ~= nil
    end)
    return ok and found and true or false
  end

  function S.speciesName(id)
    local ok, rec = pcall(mod.content.pokemon.get, mod.content.pokemon, id)
    if ok and rec and type(rec.name) == "string" and rec.name ~= "" then
      return rec.name
    end
    return (tostring(id):gsub("_", " "))
  end

  function S.itemName(id)
    local ok, rec = pcall(mod.content.items.get, mod.content.items, id)
    if ok and rec and type(rec.name) == "string" and rec.name ~= "" then
      return rec.name
    end
    return (tostring(id):gsub("_", " "))
  end

  function S.mapName(entry)
    return entry.mapName or (tostring(entry.map):gsub("_", " "))
  end

  -- ------- registering swarms

  local function normaliseTerrain(t)
    if t == nil then return nil end
    if type(t) == "string" then return { [t] = true } end
    if type(t) == "table" then
      local out = {}
      for k, v in pairs(t) do
        if type(k) == "number" and type(v) == "string" then out[v] = true
        elseif type(k) == "string" and v then out[k] = true end
      end
      return out
    end
    return nil
  end

  -- Checks a swarm table; returns a clean entry (not stored) or nil, reason.
  function S.validate(spec, defaultGames)
    if type(spec) ~= "table" then return nil, "swarm must be a table" end
    if type(spec.map) ~= "string" or spec.map == "" then
      return nil, "swarm.map must be a map id string"
    end
    if type(spec.species) ~= "string" or spec.species == "" then
      return nil, "swarm.species must be a species id string"
    end
    local lv = spec.levels
    if type(lv) ~= "table" then return nil, "swarm.levels must be { lo, hi }" end
    local lo, hi = tonumber(lv[1]), tonumber(lv[2] or lv[1])
    if not lo or not hi or lo % 1 ~= 0 or hi % 1 ~= 0
       or lo < 1 or hi > 100 or lo > hi then
      return nil, "swarm.levels must be whole numbers 1..100 with lo <= hi"
    end
    local weight = tonumber(spec.weight or 1)
    if not weight or weight <= 0 then return nil, "swarm.weight must be > 0" end
    local games = spec.games or defaultGames
    if type(games) == "string" then games = { games } end
    if type(games) ~= "table" or #games == 0 then
      return nil, 'swarm.games must list game tokens, e.g. { "gen1" }'
    end

    local entry = {
      id = spec.id or (spec.map .. ":" .. spec.species),
      map = spec.map,
      mapName = type(spec.mapName) == "string" and spec.mapName or nil,
      species = spec.species,
      levels = { lo, hi },
      weight = weight,
      games = copy(games),
      terrain = normaliseTerrain(spec.terrain),
      early = spec.early and true or false,
      badges = tonumber(spec.badges),
      source = type(spec.source) == "string" and spec.source or nil,
    }
    return entry
  end

  -- Stores a swarm (replacing one with the same id); entry or nil, reason.
  function S.add(spec, defaultGames)
    local entry, why = S.validate(spec, defaultGames)
    if not entry then return nil, why end
    local existing = byId[entry.id]
    if existing then
      for i, e in ipairs(entries) do
        if e == existing then entries[i] = entry break end
      end
    else
      entries[#entries + 1] = entry
    end
    byId[entry.id] = entry
    return entry
  end

  function S.remove(id)
    local existing = byId[id]
    if not existing then return false end
    byId[id] = nil
    for i, e in ipairs(entries) do
      if e == existing then table.remove(entries, i) break end
    end
    return true
  end

  -- how far along the player is, in badges (main.lua points this at the
  -- contests' gym-leader flags)
  function S.setProgress(fn)
    progress = type(fn) == "function" and fn or function() return 0 end
  end

  -- Routes behind the player fade out: full weight within 2 badges of
  -- their progress, half at 3 or 4 behind, a tenth at 5 or more.
  function S.effectiveWeight(e, badges)
    local w = e.weight or 1
    if not e.badges then return w end
    local behind = badges - e.badges
    if behind >= 5 then return w * 0.1 end
    if behind >= 3 then return w * 0.5 end
    return w
  end

  function S.setExclusion(fn)
    excluded = type(fn) == "function" and fn or function() return false end
  end

  function S.addFilter(fn)
    if type(fn) ~= "function" then return nil, "filter must be a function" end
    filters[#filters + 1] = fn
    return true
  end

  -- every swarm that can run on this game, as detached copies
  function S.list()
    local out = {}
    for _, e in ipairs(entries) do
      if runsHere(e) then out[#out + 1] = copy(e) end
    end
    return out
  end

  -- ------- visited routes

  function S.noteVisit(mapId)
    local known = false
    for _, e in ipairs(entries) do
      if e.map == mapId then known = true break end
    end
    if not known then return end
    local visited = save("visited", {})
    if not visited[mapId] then
      visited[mapId] = true
      store("visited", visited)
    end
  end

  -- ------- the daily pick

  local function seed()
    local s = save("seed", nil)
    if type(s) ~= "number" then
      s = rng.hash(os.time(), math.floor(os.clock() * 1000), math.random(1, 2147483646))
      store("seed", s)
    end
    return s
  end

  -- Who can swarm today: routes marked early, routes the player has been
  -- to, and routes their badges say they can reach.  Each comes back as a
  -- copy carrying its effective weight for the day's pick.
  function S.candidates(today)
    local visited = save("visited", {})
    local okP, badges = pcall(progress)
    badges = okP and tonumber(badges) or 0
    local out = {}
    for _, e in ipairs(entries) do
      local reachable = e.early or visited[e.map] or (e.badges ~= nil and badges >= e.badges)
      if runsHere(e) and reachable and not excluded(e, today)
         and S.speciesExists(e.species) then
        local c = copy(e)
        c.weight = S.effectiveWeight(e, badges)
        out[#out + 1] = c
      end
    end
    return out
  end
  local candidates = S.candidates

  local function choose(today)
    local pool = candidates(today)
    local pick = rng.weighted(pool, rng.unit(seed(), today.day))
    pick = pick and copy(pick) or nil
    local ctx = {
      day = today.day, weekday = today.weekday,
      generation = mod.generation or 1,
      candidates = copy(pool),
    }
    for _, fn in ipairs(filters) do
      local ok, result = pcall(fn, pick, ctx)
      if not ok then
        mod.log:warn("a swarm filter failed: %s", tostring(result))
      elseif result == false then
        pick = nil
      elseif type(result) == "table" then
        -- a filter's swarm is for today only, so it is checked, not stored
        local checked, why = S.validate(result, { GAME_TOKEN[mod.generation or 1] })
        if checked and S.speciesExists(checked.species) then
          pick = checked
        else
          mod.log:warn("a swarm filter returned a bad swarm: %s",
            tostring(why or ("unknown species " .. tostring(result.species))))
        end
      end
    end
    return pick
  end

  -- Today's swarm, or nil for a quiet day.  `fresh` is true the first time
  -- a new day's swarm is decided.
  function S.today()
    local today = calendar.today()
    local stored = save("today", nil)
    if type(stored) == "table" and stored.day == today.day then
      if stored.none then return nil, false, today end
      return stored, false, today
    end
    local pick = choose(today)
    local record
    if pick then
      record = {
        day = today.day, id = pick.id, map = pick.map, mapName = pick.mapName,
        species = pick.species, levels = { pick.levels[1], pick.levels[2] },
        terrain = pick.terrain,
      }
    else
      record = { day = today.day, none = true }
    end
    store("today", record)
    if pick then
      mod.events:emit("mod.catch_of_the_day.swarm_started", {
        day = today.day, weekday = today.weekday,
        map = record.map, species = record.species,
        levels = { record.levels[1], record.levels[2] },
      })
      return record, true, today
    end
    return nil, true, today
  end

  function S.terrainMatches(swarm, terrain)
    local allowed = swarm.terrain or DEFAULT_TERRAIN
    return allowed[terrain] == true
  end

  -- Forget today's pick so the next call decides again (new filters, tests).
  function S.reroll()
    store("today", nil)
  end

  return S
end
