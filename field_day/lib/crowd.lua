-- Other contestants: while a contest runs, a few trainers wander the venue
-- so it feels busy.  They're decoration with a line or two of chatter; they
-- don't battle or catch anything (the rivals' scores are simulated).
--
-- Placement reads the map's collision grid (mod.world:mapOverview), so they
-- only start on open ground: away from doorways, away from the player and
-- spread out from each other.  Like the officers, they are runtime NPCs: the
-- engine refuses NPC changes while the world is busy (always the case on
-- map.entered), so spawns and removals are retried from tick() until they
-- go through.
return function(mod, rng, contest)
  local W = {}

  local NAME_PREFIX = "FIELD_DAY_CONTESTANT_"

  local placed = {}       -- mapId -> { npc ids }
  local lines = {}        -- npc id -> what they say
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

  -- pick up to n open cells from the collision grid, deterministic per day
  function W.pickCells(overview, n, player, taken, salt)
    local warps = {}
    for _, m in ipairs(overview.markers or {}) do
      if m.kind == "warp" then warps[#warps + 1] = m end
    end
    for y, row in ipairs(overview.rows or {}) do
      for x = 1, #row do
        if row:sub(x, x) == "+" then warps[#warps + 1] = { x = x - 1, y = y - 1 } end
      end
    end
    local function near(x, y, list, r)
      for _, p in ipairs(list) do
        if math.abs(p.x - x) <= r and math.abs(p.y - y) <= r then return true end
      end
      return false
    end
    local open = {}
    for y, row in ipairs(overview.rows or {}) do
      for x = 1, #row do
        local cx, cy = x - 1, y - 1
        -- an open cell with open cells on every side, so nobody spawns
        -- boxed in or wedged in a corridor
        if row:sub(x, x) == "." and not (taken and taken[cx .. "," .. cy]) then
          local up = overview.rows[y - 1]
          local down = overview.rows[y + 1]
          local roomy = up and down and up:sub(x, x) == "." and down:sub(x, x) == "."
            and row:sub(x - 1, x - 1) == "." and row:sub(x + 1, x + 1) == "."
          if roomy and not near(cx, cy, warps, 2)
             and not (player and near(cx, cy, { player }, 3)) then
            open[#open + 1] = { x = cx, y = cy }
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
          chosen[#chosen + 1] = { x = cell.x, y = cell.y }
          used[cell] = true
        end
      end
      if #chosen >= n then break end
    end
    return chosen
  end

  local function crowdFor(d)
    return type(d) == "table" and type(d.crowd) == "table" and d.crowd or nil
  end

  -- one attempt to fill the map we're on; true when nothing is left to do
  local function fill(mapId)
    local s, d = contest.active()
    local crowd = crowdFor(d)
    if not s or not crowd or not d.venue[mapId] or placed[mapId] then return true end
    local here = mod.world:current()
    if not here or here.mapId ~= mapId then return true end
    local overview = mod.world:mapOverview()
    if type(overview) ~= "table" or overview.mapId ~= mapId then return false end
    local count = crowd.perMap and crowd.perMap[mapId] or crowd.count or 3
    local salt = rng.hash(s.day, #mapId, mapId:byte(1, -1))
    local cells = W.pickCells(overview, count, here, blockedCells(mapId), salt)
    local ids = {}
    for i, cell in ipairs(cells) do
      local sprite = crowd.sprites[(i - 1) % #crowd.sprites + 1]
      local ok, id, why = pcall(mod.world.spawnNpc, mod.world, mapId, {
        name = NAME_PREFIX .. i, x = cell.x, y = cell.y, sprite = sprite,
        movement = "WALK", range = "ANY_DIR",
      })
      if not (ok and id) then
        -- the world got busy part-way: take back what we placed, try again
        for _, placedId in ipairs(ids) do removals[#removals + 1] = placedId end
        for _, placedId in ipairs(ids) do lines[placedId] = nil end
        mod.log:info("contestants waiting: %s", tostring(ok and why or id))
        return false
      end
      ids[#ids + 1] = id
      local say = crowd.lines or { "Good luck out there!" }
      lines[id] = say[1 + math.floor(rng.unit(seed(), salt, i, 7) * #say) % #say]
    end
    placed[mapId] = ids
    return true
  end

  local function clearAll()
    for mapId, ids in pairs(placed) do
      for _, id in ipairs(ids) do removals[#removals + 1] = id end
      placed[mapId] = nil
    end
    for id in pairs(lines) do lines[id] = nil end
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
    if target.id ~= nil and lines[target.id] then return lines[target.id] end
    return nil
  end

  -- for tests
  function W.placed() return placed end
  function W.pendingRemovals() return #removals end

  return W
end
