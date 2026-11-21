-- The Bug-Catching Contest.  On contest days an officer appears in the gate;
-- sign up, and for a set number of real minutes the contest area holds only
-- bugs.  Every catch is kept as normal, and the best one is judged against
-- simulated rivals when time runs out, the balls run out, or the player
-- leaves the area.
--
-- State lives in the save under "contest" so a saved game resumes mid-contest
-- with the time it had left.
return function(mod, rng, calendar, swarms, text)
  local C = {}

  local OFFICER_NAME = "FIELD_DAY_OFFICER"
  local JOIN_FLAG = "mod:contest_joined"

  local def = nil          -- the region's contest table, or nil
  local pending = {}       -- scripts waiting for the overworld to be free
  local announcing = false -- results queued or running this session
  local clock = 0          -- seconds since the last save write / retry

  -- ------- setup and small helpers

  -- A contest ball the region defines (balls.define) becomes a real item:
  -- a bag item, its catch numbers, and an item effect that answers "ball"
  -- so the bag throws it and takes one per throw.  Content writes are only
  -- allowed while the mod loads, so setup() must run from the entry file.
  local EFFECT_ID = "FIELD_DAY_CONTEST_BALL"

  local function defineBall(balls)
    local d = balls.define
    if type(d) ~= "table" then return end
    local c = mod.content
    c.item_effects:register(EFFECT_ID, {
      battle = true, field = false,
      use = function() return "ball" end,
    })
    c.balls:register(balls.item, d.ball)
    c.items:register(balls.item, {
      id = balls.item, name = d.name, price = 0, tossable = false,
      ball = balls.item, effect = EFFECT_ID,
    })
  end

  function C.setup(contest)
    if type(contest) ~= "table" then return end
    def = contest
    local ok, err = pcall(defineBall, def.balls)
    if not ok then mod.log:warn("contest ball not defined: %s", tostring(err)) end
  end

  function C.defined() return def ~= nil end

  local function enabled()
    return def ~= nil and mod.options:get("contests") ~= false
  end

  local function state()
    local s = mod.save:get("contest", nil)
    if type(s) ~= "table" then
      s = {}
      mod.save:set("contest", s)
    end
    return s
  end

  function C.isContestDay(today)
    if not def then return false end
    today = today or calendar.today()
    for _, wd in ipairs(def.weekdays) do
      if wd == today.weekday then return true end
    end
    return false
  end

  local function mmss(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
  end

  local function seed()
    -- the swarm seed doubles as the contest seed, so one save has one story
    local s = mod.save:get("seed", nil)
    return type(s) == "number" and s or 0
  end

  -- gym leaders beaten, from the region's story flags
  function C.progress()
    local n = 0
    for _, flag in ipairs(def.progressFlags or {}) do
      local ok, set = pcall(mod.world.getFlag, mod.world, flag)
      if ok and set then n = n + 1 end
    end
    return n
  end

  function C.tier()
    local badges = C.progress()
    local best = def.tiers[1]
    for _, t in ipairs(def.tiers) do
      if badges >= (t.badges or 0) then best = t end
    end
    return best
  end

  local function tierPool(tier)
    local pool = {}
    for _, row in ipairs(tier.species) do
      if swarms.speciesExists(row[1]) then
        pool[#pool + 1] = { species = row[1], weight = row[2] or 1 }
      end
    end
    return pool
  end

  -- ------- scoring
  -- species points + 2 per level + up to 20 for HP left + up to 20 for DVs

  function C.score(species, level, hp, maxHp, dvs)
    local points = (def.points and def.points[species]) or 20
    local hpPart = 0
    if tonumber(hp) and tonumber(maxHp) and maxHp > 0 then
      hpPart = math.floor(20 * math.max(0, math.min(hp, maxHp)) / maxHp)
    end
    local dvSum = 0
    if type(dvs) == "table" then
      for _, v in pairs(dvs) do
        if type(v) == "number" then dvSum = dvSum + v end
      end
    end
    local dvPart = math.min(20, math.floor(dvSum / 3))
    return points + 2 * (tonumber(level) or 0) + hpPart + dvPart
  end

  -- each rival "catches" one bug from today's tier, decided by the seed
  local function rivalResults(day, tier)
    local pool = tierPool(tier)
    local out = {}
    for i, name in ipairs(def.rivals or {}) do
      local pick = rng.weighted(pool, rng.unit(seed(), day, i, 1))
      if pick then
        local lo, hi = tier.levels[1], tier.levels[2]
        local level = lo + math.floor(rng.unit(seed(), day, i, 2) * (hi - lo + 1))
        level = math.min(hi, level)
        local hpPct = 0.5 + 0.5 * rng.unit(seed(), day, i, 3)
        local dvs = { math.floor(rng.unit(seed(), day, i, 4) * 61) }
        out[#out + 1] = {
          name = name, species = pick.species, level = level,
          score = C.score(pick.species, level, hpPct * 100, 100, dvs),
        }
      end
    end
    return out
  end

  -- ------- running scripts when the overworld is free

  local function flush()
    local item = pending[1]
    if not item then return end
    local ok = mod.world:queueScript(item.rows, {
      onDone = function(done, reason)
        if item.onDone then item.onDone(done, reason) end
      end,
    })
    if ok then table.remove(pending, 1) end
  end

  -- every line the player reads goes through text.box, so it pages like
  -- vanilla Gen 1 text (waits for A at each line) instead of scrolling past
  local function format(rows)
    for _, row in ipairs(rows) do
      if (row[1] == "show_text" or row[1] == "ask") and type(row[2]) == "string" then
        row[2] = text.box(row[2])
      end
    end
    return rows
  end

  local function queue(rows, onDone, tag)
    format(rows)
    if tag then
      for _, p in ipairs(pending) do
        if p.tag == tag then return end
      end
    end
    pending[#pending + 1] = { rows = rows, onDone = onDone, tag = tag }
    flush()
  end

  -- ------- the officer
  --
  -- Runtime NPCs stay on their map for the whole session (they are not
  -- saved), so the officer is placed once and taken away again when the
  -- day is no longer a contest day.
  --
  -- The engine refuses NPC changes while the world is busy, and it always
  -- is on map.entered (the warp is still finishing).  So entering the gate
  -- only marks the officer as needing a check, and tick() keeps trying
  -- every frame until the gate is idle and the change goes through.
  local officerId = nil
  local officerCheck = false
  local lastReason = nil

  -- one attempt; true when nothing is left to do
  local function syncOfficer()
    local here = mod.world:current()
    if not here or here.mapId ~= def.officer.map then return true end
    local wanted = enabled() and C.isContestDay()
    if wanted and not officerId then
      local ok, id, why = pcall(mod.world.spawnNpc, mod.world, def.officer.map, {
        name = OFFICER_NAME, x = def.officer.x, y = def.officer.y,
        sprite = def.officer.sprite, movement = "STAY",
        range = def.officer.facing or "DOWN",
      })
      if ok and id then
        officerId = id
        return true
      end
      local reason = tostring(ok and why or id)
      if reason ~= lastReason then
        lastReason = reason
        mod.log:info("contest officer waiting: %s", reason)
      end
      return false
    elseif not wanted and officerId then
      local ok, removed = pcall(mod.world.removeNpc, mod.world, officerId)
      if ok and removed then officerId = nil return true end
      return false
    end
    return true
  end

  function C.spawnOfficer(mapId)
    if not def or mapId ~= def.officer.map then return end
    officerCheck = true
    lastReason = nil
    if syncOfficer() then officerCheck = false end
  end

  function C.isOfficer(target)
    if type(target) ~= "table" then return false end
    if officerId ~= nil and target.id == officerId then return true end
    local d = type(target.def) == "table" and target.def or target
    return d.name == OFFICER_NAME
  end

  local function nextContestDayName()
    local today = calendar.today()
    local names = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY",
                    "FRIDAY", "SATURDAY" }
    for step = 1, 7 do
      local wd = (today.weekday - 1 + step) % 7 + 1
      for _, d in ipairs(def.weekdays) do
        if d == wd then return names[wd] end
      end
    end
    return "another day"
  end

  -- the officer's lines; returns true when the press was handled
  function C.talk()
    local s, today = state(), calendar.today()
    if not enabled() then
      queue({ { "show_text", "Hi there! I run bug-catching events in the forest. They're on a break right now." } })
      return true
    end
    if not C.isContestDay(today) then
      queue({ { "show_text", ("The %s is held here on TUESDAYS, THURSDAYS and SATURDAYS. The next one is on %s!")
                :format(def.name, nextContestDayName()) } })
      return true
    end
    if s.day == today.day and s.done then
      queue({ { "show_text", ("Today's %s is over. The next one is on %s!")
                :format(def.name, nextContestDayName()) } })
      return true
    end
    local balls = def.balls
    mod.world:setFlag(JOIN_FLAG, false)
    queue({
      { "ask", ("It's the %s! Catch the best bug you can in %s within %d minutes. Want to enter?")
          :format(def.name, def.mapName or def.map, def.minutes) },
      { "jump_if_false", "no" },
      { "show_text", ("Here are %d %s for the contest. You keep everything you catch, and your best bug gets judged.")
          :format(balls.count, swarms.itemName(balls.item)) },
      { "give_item", balls.item, balls.count },
      { "set_flag", JOIN_FLAG },
      { "show_text", ("The clock starts now! Judging happens when time's up, when you run out of %s, or when you leave the forest. Good luck!")
          :format(swarms.itemName(balls.item)) },
      { "jump", "done" },
      { "label", "no" },
      { "show_text", "OK. Come back if you change your mind!" },
      { "label", "done" },
    }, function()
      local ok, joined = pcall(mod.world.getFlag, mod.world, JOIN_FLAG)
      if ok and joined then
        mod.world:setFlag(JOIN_FLAG, false)
        C.start()
      end
    end)
    return true
  end

  -- ------- the contest itself

  function C.start()
    local today = calendar.today()
    local tier = C.tier()
    local s = state()
    for k in pairs(s) do s[k] = nil end
    s.day = today.day
    s.active = true
    s.remaining = def.minutes * 60
    s.thrown = 0
    s.tier = tier.badges or 0
    s.notified = {}
    mod.events:emit("mod.field_day.contest_started", {
      id = def.id, day = today.day, map = def.map, minutes = def.minutes,
      tier = s.tier,
    })
  end

  -- read-only: runs every frame from core.update, so it never writes the
  -- save (which may not be loaded yet on the title screen)
  function C.active()
    if not enabled() then return nil end
    local s = mod.save:get("contest", nil)
    if type(s) == "table" and s.active then return s end
    return nil
  end

  local function currentTier(s)
    for _, t in ipairs(def.tiers) do
      if (t.badges or 0) == s.tier then return t end
    end
    return C.tier()
  end

  -- an encounter on the contest map during the contest: always a bug
  function C.encounter(mapId, random)
    local s = C.active()
    if not s or mapId ~= def.map then return nil end
    local tier = currentTier(s)
    local pick = rng.weighted(tierPool(tier), random())
    if not pick then return nil end
    local lo, hi = tier.levels[1], tier.levels[2]
    local level = math.min(hi, lo + math.floor(random() * (hi - lo + 1)))
    return pick.species, level
  end

  -- the preview distribution for encounter guides
  function C.distribution(mapId)
    local s = C.active()
    if not s or mapId ~= def.map then return nil end
    local out = {}
    for _, row in ipairs(tierPool(currentTier(s))) do
      out[row.species] = (out[row.species] or 0) + row.weight
    end
    return out
  end

  function C.onCatch(ev)
    local s = C.active()
    if not s or type(ev) ~= "table" then return end
    local here = mod.world:current()
    if not here or here.mapId ~= def.map then return end
    local mon = type(ev.mon) == "table" and ev.mon or {}
    local species = ev.species or mon.species
    if type(species) ~= "string" then return end
    local score = C.score(species, mon.level, mon.hp, mon.maxHp, mon.dvs)
    if not s.best or score > s.best.score then
      s.best = { species = species, level = mon.level, score = score }
    end
  end

  function C.onBallThrown(ev)
    local s = C.active()
    if not s or type(ev) ~= "table" then return end
    if ev.ball == def.balls.item then
      s.thrown = (s.thrown or 0) + 1
      mod.log:info("contest ball thrown (%d of %d)", s.thrown, def.balls.count)
    end
  end

  function C.onBattleEnded()
    local s = C.active()
    if s and (s.thrown or 0) >= def.balls.count then C.finish("balls") end
  end

  function C.onMapEntered(ev)
    local s = C.active()
    if s and ev.fromMapId == def.map and ev.mapId ~= def.map then
      C.finish("left")
    end
    -- a contest left running from an earlier day ends the next time we look
    if s and s.day ~= calendar.today().day then C.finish("expired") end
    if not C.active() then
      local st = state()
      if st.results and not st.shown then C.announce() end
    end
  end

  -- core.update: the real-minute clock, notices and retries
  function C.tick(dt)
    if officerCheck and def and syncOfficer() then officerCheck = false end
    if #pending > 0 then
      clock = clock + dt
      if clock >= 0.1 then clock = 0 flush() end
    end
    local s = C.active()
    if not s then return end
    s.remaining = (s.remaining or 0) - dt
    s.notified = s.notified or {}
    for _, mark in ipairs({ 300, 60 }) do
      if s.remaining <= mark and s.remaining > 0 and not s.notified[mark] then
        s.notified[mark] = true
        queue({ { "show_text", ("%s left in the %s!")
                  :format(mark >= 120 and (math.floor(mark / 60) .. " minutes") or "1 minute", def.name) } },
              nil, "notice")
      end
    end
    if s.remaining <= 0 then C.finish("time") end
  end

  -- ------- judging

  local function placeName(n)
    return ({ "first", "second", "third" })[n] or (n .. "th")
  end

  function C.finish(reason)
    local s = state()
    if not s.active then return end
    s.active = false
    s.done = true
    s.remaining = 0

    local tier = currentTier(s)
    local entries = rivalResults(s.day, tier)
    if s.best then
      entries[#entries + 1] = { name = "YOU", species = s.best.species,
        level = s.best.level, score = s.best.score, player = true }
    end
    table.sort(entries, function(a, b)
      if a.score ~= b.score then return a.score > b.score end
      return (a.player and 1 or 0) > (b.player and 1 or 0)   -- ties go to you
    end)
    local placing = nil
    for i, e in ipairs(entries) do
      if e.player then placing = i break end
    end
    s.results = { entries = entries, placing = placing, reason = reason }
    s.shown = false

    mod.events:emit("mod.field_day.contest_ended", {
      id = def.id, day = s.day, reason = reason, placing = placing,
      species = s.best and s.best.species or nil,
      level = s.best and s.best.level or nil,
      score = s.best and s.best.score or nil,
    })
    C.announce()
  end

  function C.prizeFor(placing, day)
    local p = def.prizes or {}
    if placing == 1 and p.first and #p.first > 0 then
      return { item = p.first[(day % #p.first) + 1], count = 1 }
    elseif placing == 2 then return p.second
    elseif placing == 3 then return p.third
    elseif placing then return p.entry end
    return nil
  end

  function C.announce()
    local s = state()
    local r = s.results
    if not r or s.shown or announcing then return end
    announcing = true
    local rows = {}
    local here = mod.world:current()
    local inArea = here and here.mapId == def.map

    if r.reason == "time" then
      rows[#rows + 1] = { "show_text", "Time's up! The contest is over." }
    elseif r.reason == "balls" then
      rows[#rows + 1] = { "show_text", ("You're out of %s! The contest is over for you.")
        :format(swarms.itemName(def.balls.item)) }
    end
    if inArea and def.returnTo then
      local t = def.returnTo
      rows[#rows + 1] = { "warp", t.map, t.x, t.y, t.facing or "down" }
    end

    rows[#rows + 1] = { "show_text", ("And now, the results of today's %s!"):format(def.name) }
    for n = 3, 1, -1 do
      local e = r.entries[n]
      if e then
        rows[#rows + 1] = { "show_text", ("In %s place, %s, with a Lv%d %s! Score: %d.")
          :format(placeName(n), e.name, e.level or 0, swarms.speciesName(e.species), e.score) }
      end
    end

    local prize = C.prizeFor(r.placing, s.day)
    if not r.placing then
      rows[#rows + 1] = { "show_text", "You didn't catch anything this time. Better luck next contest!" }
    elseif r.placing <= 3 then
      rows[#rows + 1] = { "show_text", "Congratulations! Here's your prize!" }
    else
      rows[#rows + 1] = { "show_text", ("You came %s. Thanks for joining! Here's a little something.")
        :format(placeName(r.placing)) }
    end
    if prize and prize.item then
      rows[#rows + 1] = { "give_item", prize.item, prize.count or 1 }
    end
    -- collect every contest ball still in the bag; take_item stops at what
    -- the player holds, so this can't take too many or leave any behind
    rows[#rows + 1] = { "take_item", def.balls.item, 999 }

    queue(rows, function(done)
      announcing = false
      if done ~= false then s.shown = true end
    end, "results")
  end

  -- ------- the ROUTE REPORT and the NEWS status

  function C.reportPages(today)
    if not enabled() or not C.isContestDay(today) then return {} end
    local s = state()
    if s.day == today.day and s.active then
      local page = ("%s: %s left."):format(def.name, mmss(s.remaining or 0))
      if s.best then
        page = page .. (" Your best: Lv%d %s."):format(s.best.level or 0,
          swarms.speciesName(s.best.species))
      end
      return { page }
    elseif s.day == today.day and s.done then
      return { ("Today's %s is over. Thanks to everyone who entered!"):format(def.name) }
    end
    return { ("It's %s day! Sign up at the %s and catch the best bug in %s!")
      :format(def.name, def.signUpAt or "gate", def.mapName or def.map) }
  end

  -- swarms never land on the contest area on a contest day
  function C.blocksSwarm(entry, today)
    return enabled() and C.isContestDay(today) and entry.map == def.map
  end

  -- a detached summary for exports.today(); nil when there is no contest today
  function C.summary(today)
    if not enabled() or not C.isContestDay(today) then return nil end
    local s = state()
    local mine = s.day == today.day
    return {
      id = def.id, name = def.name, map = def.map, mapName = def.mapName,
      active = mine and s.active or false,
      done = mine and s.done or false,
      remaining = mine and s.active and math.max(0, s.remaining or 0) or nil,
      best = mine and s.best and { species = s.best.species, level = s.best.level,
                                   score = s.best.score } or nil,
      placing = mine and s.results and s.results.placing or nil,
    }
  end

  -- ------- contest rules: only contest balls in the contest area

  local VANILLA_BALLS = { POKE_BALL = true, GREAT_BALL = true, ULTRA_BALL = true,
                          MASTER_BALL = true, SAFARI_BALL = true }

  local function isBall(id)
    if VANILLA_BALLS[id] then return true end
    local ok, rec = pcall(mod.content.items.get, mod.content.items, id)
    return ok and type(rec) == "table" and rec.ball ~= nil
  end

  -- the refusal text when this ball may not be thrown right now, else nil
  function C.ballRefusal(id, inBattle)
    if not inBattle or type(id) ~= "string" then return nil end
    local s = C.active()
    if not s or id == def.balls.item or not isBall(id) then return nil end
    local here = mod.world:current()
    if not here or here.mapId ~= def.map then return nil end
    return ("Only %s can be used in the %s!")
      :format(swarms.itemName(def.balls.item) .. "s", def.name)
  end

  -- ------- the on-screen counter: balls left and time left

  function C.hud()
    local s = C.active()
    if not s then return nil end
    local left = math.max(0, def.balls.count - (s.thrown or 0))
    return { balls = left, time = mmss(s.remaining or 0) }
  end

  -- for tests
  function C.state() return state() end

  return C
end
