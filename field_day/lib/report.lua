-- The ROUTE REPORT: the in-game news that tells the player what is
-- happening today.  Shown from the START menu, as a daily bulletin when the
-- player walks into a POKéMON CENTER or their house, and as a short notice
-- on the swarm route itself.
return function(mod, swarms)
  local R = {}

  local SCREEN = "FieldDayRouteReport"

  -- Gen 1 places where the bulletin "comes on".  Matched against map ids.
  local NEWS_SPOTS = {
    [1] = { patterns = { "POKECENTER" }, exact = { REDS_HOUSE_1F = true } },
  }

  function R.text()
    local swarm, _, day = swarms.today()
    local pages = { ("This is the ROUTE REPORT for %s!"):format(day.weekdayName) }
    if day.offset and day.offset ~= 0 then
      -- make it obvious the test option is on
      table.insert(pages, 1, ("TEST MODE: %d day%s ahead.")
        :format(day.offset, day.offset == 1 and "" or "s"))
    end
    if swarm then
      pages[#pages + 1] = ("Huge numbers of %s have been spotted on %s!")
        :format(swarms.speciesName(swarm.species), swarms.mapName(swarm))
      pages[#pages + 1] = "Get out there and see for yourself!"
    else
      pages[#pages + 1] = "All quiet out there today. No swarms to report."
    end
    return table.concat(pages, "\f")
  end

  function R.noticeText(swarm)
    return ("There are a lot of %s around here!")
      :format(swarms.speciesName(swarm.species))
  end

  function R.isNewsSpot(mapId)
    local spots = NEWS_SPOTS[mod.generation or 1]
    if not spots or type(mapId) ~= "string" then return false end
    if spots.exact[mapId] then return true end
    for _, p in ipairs(spots.patterns) do
      if mapId:find(p, 1, true) then return true end
    end
    return false
  end

  -- ------- showing it

  -- From a menu: a text box pushed as a screen.
  mod.content.screens:register(SCREEN, {
    new = function(game)
      return mod.ui.TextBox.new(game, R.text(), nil)
    end,
  })

  function R.open(game)
    mod.ui.push(game, SCREEN)
  end

  -- From the overworld: through the script queue, which refuses while
  -- another script (a story scene) is running.  Returns true when shown.
  function R.say(text)
    local ok, why = mod.world:queueScript({ { "show_text", text } })
    if not ok and why then mod.log:info("route report waiting: %s", tostring(why)) end
    return ok and true or false
  end

  return R
end
