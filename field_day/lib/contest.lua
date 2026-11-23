-- Contests.  A region lists any number of them (the Bug-Catching Contest,
-- the Fishing Derby, ...), each on its own weekdays at its own venue.  On a
-- contest day that contest's officer appears; sign up, and for a set number
-- of real minutes the venue holds only that contest's POKéMON.  Every catch
-- is kept as normal, and the best one is judged against simulated rivals
-- when time runs out, the balls run out, or the player leaves the venue.
--
-- Only one contest runs at a time.  State lives in the save under
-- "contest", so a saved game resumes mid-contest with the time it had left.
return function(mod, rng, calendar, swarms, text)
  local C = {}

  local OFFICER_PREFIX = "FIELD_DAY_OFFICER_"
  local JOIN_FLAG = "mod:contest_joined"
  local EFFECT_ID = "FIELD_DAY_CONTEST_BALL"
  local WEEKDAY_NAMES = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY",
                          "THURSDAY", "FRIDAY", "SATURDAY" }

  local defs = {}          -- the region's contests, in order
  local byId = {}
  local pending = {}       -- scripts waiting for the overworld to be free
  local announcing = false -- results queued or running this session
  local clock = 0          -- seconds since the last retry

  -- ------- setup

  -- A contest ball the region defines (balls.define) becomes a real item:
  -- a bag item, its catch numbers, and an item effect that answers "ball"
  -- so the bag throws it and takes one per throw.  Content writes are only
  -- allowed while the mod loads, so setup() must run from the entry file.
  local definedBalls = {}
  local effectDefined = false

  local function defineBall(balls)
    local d = balls.define
    if type(d) ~= "table" or definedBalls[balls.item] then return end
    local c = mod.content
    if not effectDefined then
      c.item_effects:register(EFFECT_ID, {
        battle = true, field = false,
        use = function() return "ball" end,
      })
      effectDefined = true
    end
    c.balls:register(balls.item, d.ball)
    c.items:register(balls.item, {
      id = balls.item, name = d.name, price = 0, tossable = false,
      ball = balls.item, effect = EFFECT_ID,
    })
    definedBalls[balls.item] = true
  end

  local function withDefaults(d, shared)
    shared = shared or {}
    d.minutes = d.minutes or shared.minutes or 20
    d.balls = d.balls or shared.balls
    d.progressFlags = d.progressFlags or shared.progressFlags
    d.maps = d.maps or { d.map }
    d.map = d.map or d.maps[1]
    d.method = d.method or "walk"   -- "walk", "fishing" or "any"
    d.option = d.option or ("contest_" .. d.id)
    local p, sp = d.prizes or {}, shared.prizes or {}
    d.prizes = { first = p.first or sp.first, second = p.second or sp.second,
                 third = p.third or sp.third, entry = p.entry or sp.entry }
    d.venue = {}
    for _, m in ipairs(d.maps) do d.venue[m] = true end
    return d
  end

  -- setup(contests, shared): contests is a list (or one contest table);
  -- shared holds defaults every contest falls back on (balls, minutes,
  -- progressFlags, prizes).
  function C.setup(list, shared)
    if type(list) ~= "table" then return end
    if list.id then list = { list } end
    for _, d in ipairs(list) do
      if type(d) == "table" and d.id then
        withDefaults(d, shared)
        defs[#defs + 1] = d
        byId[d.id] = d
        local ok, err = pcall(defineBall, d.balls)
        if not ok then mod.log:warn("contest ball not defined: %s", tostring(err)) end
      end
    end
  end

  function C.contests() return defs end
  function C.get(id) return byId[id] end

  local function enabled(d)
    return d ~= nil and mod.options:get("contests") ~= false
      and mod.options:get(d.option) ~= false
  end

  local function state()
    local s = mod.save:get("contest", nil)
    if type(s) ~= "table" then
      s = {}
      mod.save:set("contest", s)
    end
    return s
  end

  -- Contests with unlockBadges (Gold/Silver/Crystal's Kanto contests) wait
  -- until the player has that many badges: no officer, no report line.
  local function unlocked(d)
    if not d.unlockBadges then return true end
    return C.progress(d) >= d.unlockBadges
  end

  local function runsOn(d, today)
    if not unlocked(d) then return false end
    for _, wd in ipairs(d.weekdays) do
      if wd == today.weekday then return true end
    end
    return false
  end

  -- is d (or, without d, any enabled contest) on today?
  function C.isContestDay(today, d)
    today = today or calendar.today()
    if d then return enabled(d) and runsOn(d, today) end
    for _, c in ipairs(defs) do
      if enabled(c) and runsOn(c, today) then return true end
    end
    return false
  end

  -- today's enabled contests, in region order
  function C.todays(today)
    today = today or calendar.today()
    local out = {}
    for _, d in ipairs(defs) do
      if enabled(d) and runsOn(d, today) then out[#out + 1] = d end
    end
    return out
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

  local function daysText(d)
    local names = {}
    for _, wd in ipairs(d.weekdays) do names[#names + 1] = WEEKDAY_NAMES[wd] .. "S" end
    if #names == 1 then return names[1] end
    return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
  end

  local function nextDayName(d)
    local today = calendar.today()
    for step = 1, 7 do
      local wd = (today.weekday - 1 + step) % 7 + 1
      for _, x in ipairs(d.weekdays) do
        if x == wd then return WEEKDAY_NAMES[wd] end
      end
    end
    return "another day"
  end

  -- ------- progress, tiers and scoring

  -- gym leaders beaten, from the region's story flags
  function C.progress(d)
    d = d or defs[1]
    local n = 0
    for _, flag in ipairs(d and d.progressFlags or {}) do
      local ok, set = pcall(mod.world.getFlag, mod.world, flag)
      if ok and set then n = n + 1 end
    end
    return n
  end

  function C.tier(d)
    d = d or defs[1]
    local badges = C.progress(d)
    local best = d.tiers[1]
    for _, t in ipairs(d.tiers) do
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

  -- species points + 2 per level + up to 20 for HP left + up to 20 for DVs
  function C.score(d, species, level, hp, maxHp, dvs)
    local points = (d.points and d.points[species]) or 20
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

  -- each rival "catches" one POKéMON from the contest's tier, by the seed
  local function rivalResults(d, day, tier)
    local pool = tierPool(tier)
    local out = {}
    local salt = rng.hash(#d.id, d.id:byte(1, -1))
    for i, name in ipairs(d.rivals or {}) do
      local pick = rng.weighted(pool, rng.unit(seed(), day, salt, i, 1))
      if pick then
        local lo, hi = tier.levels[1], tier.levels[2]
        local level = lo + math.floor(rng.unit(seed(), day, salt, i, 2) * (hi - lo + 1))
        level = math.min(hi, level)
        local hpPct = 0.5 + 0.5 * rng.unit(seed(), day, salt, i, 3)
        local dvs = { math.floor(rng.unit(seed(), day, salt, i, 4) * 61) }
        out[#out + 1] = {
          name = name, species = pick.species, level = level,
          score = C.score(d, pick.species, level, hpPct * 100, 100, dvs),
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

  -- ------- officers
  --
  -- Runtime NPCs stay on their map for the whole session (they are not
  -- saved), so an officer is placed once and taken away again when the day
  -- is no longer his contest's day.
  --
  -- The engine refuses NPC changes while the world is busy, and it always
  -- is on map.entered (the warp is still finishing).  So entering an
  -- officer's map only marks him as needing a check, and tick() keeps
  -- trying every frame until the map is idle and the change goes through.
  local officerIds = {}    -- contest id -> runtime NPC id
  local officerCheck = {}  -- contest id -> true while a check is due
  local lastReason = {}

  -- one attempt for one contest's officer; true when nothing is left to do
  local function syncOfficer(d)
    local here = mod.world:current()
    if not here or here.mapId ~= d.officer.map then return true end
    local wanted = C.isContestDay(nil, d)
    if wanted and not officerIds[d.id] then
      local ok, id, why = pcall(mod.world.spawnNpc, mod.world, d.officer.map, {
        name = OFFICER_PREFIX .. d.id, x = d.officer.x, y = d.officer.y,
        sprite = d.officer.sprite, movement = "STAY",
        range = d.officer.facing or "DOWN",
      })
      if ok and id then
        officerIds[d.id] = id
        return true
      end
      local reason = tostring(ok and why or id)
      if reason ~= lastReason[d.id] then
        lastReason[d.id] = reason
        mod.log:info("%s officer waiting: %s", d.id, reason)
      end
      return false
    elseif not wanted and officerIds[d.id] then
      local ok, removed = pcall(mod.world.removeNpc, mod.world, officerIds[d.id])
      if ok and removed then officerIds[d.id] = nil return true end
      return false
    end
    return true
  end

  function C.spawnOfficer(mapId)
    for _, d in ipairs(defs) do
      if d.officer and d.officer.map == mapId then
        officerCheck[d.id] = true
        lastReason[d.id] = nil
        if syncOfficer(d) then officerCheck[d.id] = nil end
      end
    end
  end

  -- the contest whose officer this is, or nil
  function C.officerFor(target)
    if type(target) ~= "table" then return nil end
    for id, npcId in pairs(officerIds) do
      if target.id == npcId then return byId[id] end
    end
    local d = type(target.def) == "table" and target.def or target
    local name = type(d.name) == "string" and d.name or ""
    if name:sub(1, #OFFICER_PREFIX) == OFFICER_PREFIX then
      return byId[name:sub(#OFFICER_PREFIX + 1)]
    end
    return nil
  end

  function C.isOfficer(target) return C.officerFor(target) ~= nil end

  -- the officer's lines; returns true when the press was handled
  function C.talk(d)
    if type(d) ~= "table" or not d.weekdays then d = C.officerFor(d) end
    if not d then return false end
    local s, today = state(), calendar.today()
    if not enabled(d) then
      queue({ { "show_text", ("Hi there! The %s is taking a break right now."):format(d.name) } })
      return true
    end
    if not runsOn(d, today) then
      queue({ { "show_text", ("The %s is held on %s. The next one is on %s!")
                :format(d.name, daysText(d), nextDayName(d)) } })
      return true
    end
    if s.active and s.id ~= d.id then
      local other = byId[s.id]
      queue({ { "show_text", ("You're already in the %s! Finish that one first.")
                :format(other and other.name or "other contest") } })
      return true
    end
    if s.day == today.day and s.id == d.id and s.done then
      queue({ { "show_text", ("Today's %s is over. The next one is on %s!")
                :format(d.name, nextDayName(d)) } })
      return true
    end

    local balls = d.balls
    local ballName = swarms.itemName(balls.item)
    local rows = {}
    -- an entry requirement, like a fishing rod: any one of the items will do
    if d.requires and #d.requires.items > 0 then
      for _, item in ipairs(d.requires.items) do
        rows[#rows + 1] = { "check_item", item }
        rows[#rows + 1] = { "jump_if_true", "ready" }
      end
      rows[#rows + 1] = { "show_text", d.requires.text }
      rows[#rows + 1] = { "jump", "done" }
      rows[#rows + 1] = { "label", "ready" }
    end
    mod.world:setFlag(JOIN_FLAG, false)
    local more = {
      { "ask", ("It's the %s! %s within %d minutes. Want to enter?")
          :format(d.name, d.intro, d.minutes) },
      { "jump_if_false", "no" },
      { "show_text", ("Here are %d %ss for the contest. You keep everything you catch, and your best one gets judged.")
          :format(balls.count, ballName) },
      { "give_item", balls.item, balls.count },
      { "set_flag", JOIN_FLAG },
      { "show_text", ("The clock starts now! Judging happens when time's up, when you run out of %ss, or when you leave %s. Good luck!")
          :format(ballName, d.mapName or d.map) },
      { "jump", "done" },
      { "label", "no" },
      { "show_text", "OK. Come back if you change your mind!" },
      { "label", "done" },
    }
    for _, r in ipairs(more) do rows[#rows + 1] = r end
    queue(rows, function()
      local ok, joined = pcall(mod.world.getFlag, mod.world, JOIN_FLAG)
      if ok and joined then
        mod.world:setFlag(JOIN_FLAG, false)
        C.start(d)
      end
    end)
    return true
  end

  -- ------- the contest itself

  function C.start(d)
    if type(d) == "string" then d = byId[d] end
    d = d or defs[1]
    local today = calendar.today()
    local tier = C.tier(d)
    local s = state()
    for k in pairs(s) do s[k] = nil end
    s.id = d.id
    s.day = today.day
    s.active = true
    s.remaining = d.minutes * 60
    s.thrown = 0
    s.tier = tier.badges or 0
    s.notified = {}
    mod.events:emit("mod.field_day.contest_started", {
      id = d.id, day = today.day, map = d.map, minutes = d.minutes,
      tier = s.tier,
    })
  end

  -- read-only: runs every frame from core.update, so it never writes the
  -- save (which may not be loaded yet on the title screen).
  -- Returns the state and the running contest.
  function C.active()
    local s = mod.save:get("contest", nil)
    if type(s) ~= "table" or not s.active then return nil end
    local d = byId[s.id or (defs[1] and defs[1].id)]
    if not enabled(d) then return nil end
    return s, d
  end

  local function currentTier(s, d)
    for _, t in ipairs(d.tiers) do
      if (t.badges or 0) == s.tier then return t end
    end
    return C.tier(d)
  end

  local function pickFrom(tier, random)
    local pick = rng.weighted(tierPool(tier), random())
    if not pick then return nil end
    local lo, hi = tier.levels[1], tier.levels[2]
    return pick.species, math.min(hi, lo + math.floor(random() * (hi - lo + 1)))
  end

  -- a walking encounter in the venue during a contest: a contest POKéMON
  function C.encounter(mapId, random)
    local s, d = C.active()
    if not s or d.method == "fishing" or not d.venue[mapId] then return nil end
    return pickFrom(currentTier(s, d), random)
  end

  -- a bite while fishing in the venue during a fishing contest (method
  -- "fishing", or "any" for a venue where SURF and the rod both count)
  function C.fishing(mapId, random)
    local s, d = C.active()
    if not s or not (d.method == "fishing" or d.method == "any")
       or not d.venue[mapId] then return nil end
    return pickFrom(currentTier(s, d), random)
  end

  -- the preview distribution for encounter guides (walking contests)
  function C.distribution(mapId)
    local s, d = C.active()
    if not s or d.method == "fishing" or not d.venue[mapId] then return nil end
    local out = {}
    for _, row in ipairs(tierPool(currentTier(s, d))) do
      out[row.species] = (out[row.species] or 0) + row.weight
    end
    return out
  end

  function C.onCatch(ev)
    local s, d = C.active()
    if not s or type(ev) ~= "table" then return end
    local here = mod.world:current()
    if not here or not d.venue[here.mapId] then return end
    local mon = type(ev.mon) == "table" and ev.mon or {}
    local species = ev.species or mon.species
    if type(species) ~= "string" then return end
    local score = C.score(d, species, mon.level, mon.hp, mon.maxHp, mon.dvs)
    if not s.best or score > s.best.score then
      s.best = { species = species, level = mon.level, score = score }
    end
  end

  function C.onBallThrown(ev)
    local s, d = C.active()
    if not s or type(ev) ~= "table" then return end
    if ev.ball == d.balls.item then
      s.thrown = (s.thrown or 0) + 1
      mod.log:info("contest ball thrown (%d of %d)", s.thrown, d.balls.count)
    end
  end

  function C.onBattleEnded()
    local s, d = C.active()
    if s and (s.thrown or 0) >= d.balls.count then C.finish("balls") end
  end

  function C.onMapEntered(ev)
    local s, d = C.active()
    if s and ev.fromMapId and d.venue[ev.fromMapId] and not d.venue[ev.mapId] then
      C.finish("left")
    end
    -- a contest left running from an earlier day ends the next time we look
    s = C.active()
    if s and s.day ~= calendar.today().day then C.finish("expired") end
    if not C.active() then
      local st = state()
      if st.results and not st.shown then C.announce() end
    end
  end

  -- core.update: the real-minute clock, notices, officers and retries
  function C.tick(dt)
    for id in pairs(officerCheck) do
      local d = byId[id]
      if not d or syncOfficer(d) then officerCheck[id] = nil end
    end
    if #pending > 0 then
      clock = clock + dt
      if clock >= 0.1 then clock = 0 flush() end
    end
    local s, d = C.active()
    if not s then return end
    s.remaining = (s.remaining or 0) - dt
    s.notified = s.notified or {}
    for _, mark in ipairs({ 300, 60 }) do
      if s.remaining <= mark and s.remaining > 0 and not s.notified[mark] then
        s.notified[mark] = true
        queue({ { "show_text", ("%s left in the %s!")
                  :format(mark >= 120 and (math.floor(mark / 60) .. " minutes") or "1 minute", d.name) } },
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
    local d = byId[s.id] or defs[1]
    s.active = false
    s.done = true
    s.remaining = 0

    local tier = currentTier(s, d)
    local entries = rivalResults(d, s.day, tier)
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
      id = d.id, day = s.day, reason = reason, placing = placing,
      species = s.best and s.best.species or nil,
      level = s.best and s.best.level or nil,
      score = s.best and s.best.score or nil,
    })
    C.announce()
  end

  function C.prizeFor(placing, day, d)
    if type(d) == "string" then d = byId[d] end
    d = d or defs[1]
    local p = d.prizes or {}
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
    local d = byId[s.id] or defs[1]
    if not d then return end
    announcing = true
    local rows = {}
    local here = mod.world:current()
    local inVenue = here and d.venue[here.mapId]

    if r.reason == "time" then
      rows[#rows + 1] = { "show_text", ("Time's up! The %s is over."):format(d.name) }
    elseif r.reason == "balls" then
      rows[#rows + 1] = { "show_text", ("You're out of %ss! The %s is over for you.")
        :format(swarms.itemName(d.balls.item), d.name) }
    end
    if inVenue and d.returnTo then
      local t = d.returnTo
      rows[#rows + 1] = { "warp", t.map, t.x, t.y, t.facing or "down" }
    end

    rows[#rows + 1] = { "show_text", ("And now, the results of today's %s!"):format(d.name) }
    for n = 3, 1, -1 do
      local e = r.entries[n]
      if e then
        rows[#rows + 1] = { "show_text", ("In %s place, %s, with a Lv%d %s! Score: %d.")
          :format(placeName(n), e.name, e.level or 0, swarms.speciesName(e.species), e.score) }
      end
    end

    local prize = C.prizeFor(r.placing, s.day, d)
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
    rows[#rows + 1] = { "take_item", d.balls.item, 999 }

    queue(rows, function(done)
      announcing = false
      if done ~= false then s.shown = true end
    end, "results")
  end

  -- ------- the ROUTE REPORT, NEWS and today()

  function C.reportPages(today)
    local s = state()
    local pages = {}
    for _, d in ipairs(C.todays(today)) do
      local mine = s.day == today.day and s.id == d.id
      if mine and s.active then
        local page = ("%s: %s left."):format(d.name, mmss(s.remaining or 0))
        if s.best then
          page = page .. (" Your best: Lv%d %s."):format(s.best.level or 0,
            swarms.speciesName(s.best.species))
        end
        pages[#pages + 1] = page
      elseif mine and s.done then
        pages[#pages + 1] = ("Today's %s is over. Thanks to everyone who entered!"):format(d.name)
      else
        pages[#pages + 1] = ("It's %s day! %s Sign up at the %s!")
          :format(d.name, d.report or "", d.signUpAt or "contest desk")
      end
    end
    return pages
  end

  -- swarms never land on a venue on its contest day
  function C.blocksSwarm(entry, today)
    for _, d in ipairs(C.todays(today)) do
      if d.venue[entry.map] then return true end
    end
    return false
  end

  local function summaryOf(d, today, s)
    local mine = s.day == today.day and s.id == d.id
    return {
      id = d.id, name = d.name, map = d.map, mapName = d.mapName,
      maps = { unpack(d.maps) },
      active = mine and s.active or false,
      done = mine and s.done or false,
      remaining = mine and s.active and math.max(0, s.remaining or 0) or nil,
      best = mine and s.best and { species = s.best.species, level = s.best.level,
                                   score = s.best.score } or nil,
      placing = mine and s.results and s.results.placing or nil,
    }
  end

  -- detached summaries of today's contests, for exports.today()
  function C.summaries(today)
    local s, out = state(), {}
    for _, d in ipairs(C.todays(today)) do out[#out + 1] = summaryOf(d, today, s) end
    return out
  end

  -- the one to show first: the running contest, else today's first; or nil
  function C.summary(today)
    local list = C.summaries(today)
    for _, x in ipairs(list) do if x.active then return x end end
    return list[1]
  end

  -- ------- contest rules: only contest balls in the venue

  local VANILLA_BALLS = { POKE_BALL = true, GREAT_BALL = true, ULTRA_BALL = true,
                          MASTER_BALL = true, SAFARI_BALL = true, PARK_BALL = true,
                          -- Gold, Silver and Crystal's APRICORN balls
                          LEVEL_BALL = true, LURE_BALL = true, MOON_BALL = true,
                          FRIEND_BALL = true, FAST_BALL = true, HEAVY_BALL = true,
                          LOVE_BALL = true }

  local function isBall(id)
    if VANILLA_BALLS[id] then return true end
    local ok, rec = pcall(mod.content.items.get, mod.content.items, id)
    return ok and type(rec) == "table" and rec.ball ~= nil
  end

  -- the refusal text when this ball may not be thrown right now, else nil
  function C.ballRefusal(id, inBattle)
    if not inBattle or type(id) ~= "string" then return nil end
    local s, d = C.active()
    if not s or id == d.balls.item or not isBall(id) then return nil end
    local here = mod.world:current()
    if not here or not d.venue[here.mapId] then return nil end
    return ("Only %ss can be used in the %s!")
      :format(swarms.itemName(d.balls.item), d.name)
  end

  -- ------- the on-screen counter: balls left and time left

  function C.hud()
    local s, d = C.active()
    if not s then return nil end
    local left = math.max(0, d.balls.count - (s.thrown or 0))
    return { balls = left, time = mmss(s.remaining or 0), id = d.id }
  end

  -- a plain message through the same queue (used by the other contestants)
  function C.say(message)
    queue({ { "show_text", message } })
  end

  -- for tests
  function C.state() return state() end

  return C
end
