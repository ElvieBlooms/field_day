-- Other contestants: while a contest runs, a few trainers fill the venue so
-- it feels busy.  They're decoration with a line of chatter each; they don't
-- battle or catch anything (the rivals' scores are simulated).
--
-- Placement reads the map's collision grid (mod.world:mapOverview).  A
-- contest picks, per map, how its crowd stands:
--   walk   wander freely, starting on open ground away from doorways, the
--          player and each other
--   shore  stand still on the water's edge, facing the water (anglers)
-- Like the officers, they are runtime NPCs: the engine refuses NPC changes
-- while the world is busy (always the case on map.entered), so spawns and
-- removals are retried from tick() until they go through.
--
-- They're recognised by name when you talk to them, not by the id the
-- spawn returned: the NPC the talk hook receives doesn't carry that id.
return function(mod, rng, contest)
  local W = {}

  local NAME_PREFIX = "FIELD_DAY_CONTESTANT_"

  -- said by anyone at any contest, mixed in with each contest's own lines
  local SHARED_LINES = {
    "Have you caught anything good yet?",
    "I've been practising my throw all week.",
    "I almost had one, then it broke free!",
    "Don't scare them off, please!",
    "Twenty minutes goes by so fast.",
    "I came fourth last time. Not today!",
    "Is this your first contest? Good luck!",
    "My POKéMON is cheering me on from its BALL.",
    "I only have a few PARK BALLs left...",
    "The officer says the judges love a healthy catch.",
  }

  local placed = {}       -- mapId -> { npc ids }
  local lineByName = {}   -- npc name -> what they say
  local lineById = {}     -- npc id -> what they say
  local dealt = {}        -- "contest:day" -> { order, next }
  local serial = 0        -- makes every contestant's name unique
  local wanted = nil      -- mapId waiting for its crowd
  local removals = {}     -- npc ids waiting to be removed

  local function seed()
    local s = mod.save:get("seed", nil)
    return type(s) == "number" and s or 0
  end

  local function blockedCells(mapId)
    -- the map's own objects' starting cells
    local out = {}
    local ok, rec = pcall(mod.content.maps.get, mod.content.maps, mapId)
    if ok and type(rec) == "table" then
      for _, obj in ipairs(rec.objects or {}) do
        if obj.x and obj.y then out[obj.x .. "," .. obj.y] = true end
      end
    end
    return out
  end

  local function near(x, y, list, r)
    for _, p in ipairs(list) do
      if math.abs(p.x - x) <= r and math.abs(p.y - y) <= r then return true end
    end
    return false
  end

  local function cellAt(rows, x, y)
    local row = rows[y + 1]
    if not row or x < 0 then return nil end
    local c = row:sub(x + 1, x + 1)
    return c ~= "" and c or nil
  end

  -- the direction from a cell to the water beside it, or nil
  local WATER_SIDES = { { 0, -1, "UP" }, { 0, 1, "DOWN" }, { -1, 0, "LEFT" }, { 1, 0, "RIGHT" } }
  local function waterSide(rows, x, y)
    for _, s in ipairs(WATER_SIDES) do
      if cellAt(rows, x + s[1], y + s[2]) == "~" then return s[3] end
    end
    return nil
  end

  -- Pick up to n cells from the collision grid, deterministic per day.
  -- mode "walk": open cells with open ground on every side.
  -- mode "shore": open cells right beside water; each gets a facing.
  function W.pickCells(overview, n, player, taken, salt, mode)
    local rows = overview.rows or {}
    local warps = {}
    for _, m in ipairs(overview.markers or {}) do
      if m.kind == "warp" then warps[#warps + 1] = m end
    end
    for y, row in ipairs(rows) do
      for x = 1, #row do
        if row:sub(x, x) == "+" then warps[#warps + 1] = { x = x - 1, y = y - 1 } end
      end
    end
    local open = {}
    for y, row in ipairs(rows) do
      for x = 1, #row do
        local cx, cy = x - 1, y - 1
        if row:sub(x, x) == "." and not (taken and taken[cx .. "," .. cy])
           and not near(cx, cy, warps, 2)
           and not (player and near(cx, cy, { player }, mode == "shore" and 2 or 3)) then
          if mode == "shore" then
            local facing = waterSide(rows, cx, cy)
            if facing then open[#open + 1] = { x = cx, y = cy, facing = facing } end
          else
            -- open ground on every side, so nobody starts boxed in
            local roomy = cellAt(rows, cx, cy - 1) == "." and cellAt(rows, cx, cy + 1) == "."
              and cellAt(rows, cx - 1, cy) == "." and cellAt(rows, cx + 1, cy) == "."
            if roomy then open[#open + 1] = { x = cx, y = cy } end
          end
        end
      end
    end
    -- a seeded shuffle, then take every cell that keeps its distance from
    -- the ones already taken; if the map is too tight for everyone, go
    -- round again a little closer together
    for _, cell in ipairs(open) do
      cell.order = rng.hash(seed(), salt, cell.x, cell.y)
    end
    table.sort(open, function(a, b)
      if a.order ~= b.order then return a.order < b.order end
      return a.y * 1000 + a.x < b.y * 1000 + b.x
    end)
    local chosen, used = {}, {}
    for _, gap in ipairs({ 3, 2, 1 }) do
      for _, cell in ipairs(open) do
        if #chosen >= n then break end
        if not used[cell] and not near(cell.x, cell.y, chosen, gap) then
          chosen[#chosen + 1] = { x = cell.x, y = cell.y, facing = cell.facing }
          used[cell] = true
        end
      end
      if #chosen >= n then break end
    end
    return chosen
  end

  -- deal the next line for this contest and day, so nobody repeats another
  -- until the pool runs out
  local function dealLine(d, day)
    local pool = {}
    for _, l in ipairs(d.crowd.lines or {}) do pool[#pool + 1] = l end
    for _, l in ipairs(SHARED_LINES) do pool[#pool + 1] = l end
    local key = d.id .. ":" .. day
    local deck = dealt[key]
    if not deck or deck.next > #deck.order then
      local round = deck and deck.round + 1 or 1
      local order = {}
      for i = 1, #pool do order[i] = i end
      local salt = rng.hash(day, round, #d.id, d.id:byte(1, -1))
      table.sort(order, function(a, b)
        local ha, hb = rng.hash(seed(), salt, a), rng.hash(seed(), salt, b)
        if ha ~= hb then return ha < hb end
        return a < b
      end)
      deck = { order = order, next = 1, round = round }
      dealt[key] = deck
    end
    local line = pool[deck.order[deck.next]]
    deck.next = deck.next + 1
    return line
  end

  local function groupFor(crowd, mapId)
    local g = crowd.perMap and crowd.perMap[mapId]
    if type(g) == "number" then return { count = g, place = crowd.place or "walk" } end
    if type(g) == "table" then
      return { count = g.count or crowd.count or 3, place = g.place or crowd.place or "walk",
               sprites = g.sprites }
    end
    return { count = crowd.count or 3, place = crowd.place or "walk" }
  end

  -- one attempt to fill the map we're on; true when nothing is left to do
  local function fill(mapId)
    local s, d = contest.active()
    local crowd = type(d) == "table" and type(d.crowd) == "table" and d.crowd or nil
    if not s or not crowd or not d.venue[mapId] or placed[mapId] then return true end
    local here = mod.world:current()
    if not here or here.mapId ~= mapId then return true end
    local overview = mod.world:mapOverview()
    if type(overview) ~= "table" or overview.mapId ~= mapId then return false end
    local group = groupFor(crowd, mapId)
    if group.count <= 0 then placed[mapId] = {} return true end
    local salt = rng.hash(s.day, #mapId, mapId:byte(1, -1))
    local cells = W.pickCells(overview, group.count, here, blockedCells(mapId), salt, group.place)
    local sprites = group.sprites or crowd.sprites
    local ids, names = {}, {}
    for i, cell in ipairs(cells) do
      serial = serial + 1
      local name = NAME_PREFIX .. serial
      local standing = group.place == "shore"
      local ok, id, why = pcall(mod.world.spawnNpc, mod.world, mapId, {
        name = name, x = cell.x, y = cell.y,
        sprite = sprites[(i - 1) % #sprites + 1],
        movement = standing and "STAY" or "WALK",
        range = standing and (cell.facing or "DOWN") or "ANY_DIR",
      })
      if not (ok and id) then
        -- the world got busy part-way: take back what we placed, try again
        for _, placedId in ipairs(ids) do
          removals[#removals + 1] = placedId
          lineById[placedId] = nil
        end
        for _, n in ipairs(names) do lineByName[n] = nil end
        mod.log:info("contestants waiting: %s", tostring(ok and why or id))
        return false
      end
      ids[#ids + 1], names[#names + 1] = id, name
      local line = dealLine(d, s.day)
      lineByName[name], lineById[id] = line, line
    end
    placed[mapId] = ids
    return true
  end

  local function clearAll()
    for mapId, ids in pairs(placed) do
      for _, id in ipairs(ids) do removals[#removals + 1] = id end
      placed[mapId] = nil
    end
    for k in pairs(lineByName) do lineByName[k] = nil end
    for k in pairs(lineById) do lineById[k] = nil end
  end

  function W.onMapEntered(mapId)
    wanted = mapId
  end

  -- core.update: place the crowd once the map settles, clear it when the
  -- contest is over
  function W.tick()
    local s = contest.active()
    if not s and next(placed) then clearAll() end
    if wanted then
      if not s then wanted = nil
      elseif fill(wanted) then wanted = nil end
    end
    if #removals > 0 then
      local id = removals[1]
      local ok, removed = pcall(mod.world.removeNpc, mod.world, id)
      if ok and removed then table.remove(removals, 1) end
    end
  end

  -- a contestant's line, or nil when the target isn't one of ours
  function W.lineFor(target)
    if type(target) ~= "table" then return nil end
    local def = type(target.def) == "table" and target.def or {}
    local name = type(def.name) == "string" and def.name
      or (type(target.name) == "string" and target.name) or nil
    if name and lineByName[name] then return lineByName[name] end
    if target.id ~= nil and lineById[target.id] then return lineById[target.id] end
    return nil
  end

  -- for tests
  function W.placed() return placed end
  function W.pendingRemovals() return #removals end
  W.SHARED_LINES = SHARED_LINES

  return W
end
