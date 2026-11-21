# Field Day

Daily events for gen1recomp. Every day a different POKéMON swarms one route,
three days a week there's a Bug-Catching Contest in Viridian Forest, and the
**ROUTE REPORT** tells you what's on.

**This version:** swarms, the Bug-Catching Contest and the ROUTE REPORT on
Red, Blue and Yellow. Gold/Silver/Crystal and the Gen 3 games are planned.

## How it plays

- **One swarm a day.** The day comes from your device's clock. Each save gets
  its own schedule, and the swarm stays the same all day.
- **On the swarm route**, about half of wild encounters (you can change this)
  are the swarm species. The encounter rate itself doesn't change.
- **Swarms favour rare and version-exclusive POKéMON** (Clefairy, Farfetch'd,
  Scyther, Pinsir, Eevee and more), so they help fill the POKéDEX without
  trading.
- **Only routes you've been to.** Apart from a few starting routes, a route
  can only have a swarm after you've visited it, so you won't hear about
  places you can't reach yet.

## The Bug-Catching Contest

Every **Tuesday, Thursday and Saturday**, an officer stands in the
**Viridian Forest south gate**. Talk to him to enter:

- You get **20 PARK BALLs** and **20 minutes** (real time) to catch the
  best bug you can. During the contest the forest holds only bugs. PARK
  BALLs catch like GREAT BALLs and can't be used outside battle.
- **Only PARK BALLs** can be thrown in the forest during the contest; your
  own balls are refused (and not used up). They work as normal everywhere
  else.
- A **counter** in the bottom-right corner shows the balls and time you have
  left while you walk around (it hides behind menus, text and battles).
- **Bring your whole team, and keep everything you catch.** Your best catch
  is the one that's judged.
- **The bugs grow with you.** With 0-1 badges it's Caterpie and Weedle at
  Lv4-8; at 2, 4 and 6 badges the levels rise and Butterfree, Beedrill,
  Venomoth, Parasect, Scyther and Pinsir turn up more often.
- **Judging** happens when time runs out (you're taken back to the gate),
  when you run out of balls, or when you leave the forest. Your catch is
  scored on species, level, remaining HP and DVs, then ranked against five
  other entrants. Leftover balls are collected.
- **Prizes:** 1st place gets an evolution stone (a different one each
  contest), 2nd a NUGGET, 3rd five GREAT BALLs, and everyone else who caught
  something gets two POTIONs.

Swarms never land on Viridian Forest on contest days.

## The ROUTE REPORT

- **NEWS** in the START menu shows today's report at any time. During a
  contest it shows the time left and your best catch so far.
- **Daily bulletin:** the first time each day you walk into a POKéMON CENTER
  or your house, the report comes on.
- **Swarm notice:** when you step onto the swarm route, you're told it's
  crawling with that POKéMON.

## Options

| Option | Default | What it does |
|---|---|---|
| SWARMS | on | Turns swarms on or off |
| SWARM SHARE | 50% | How many encounters on the swarm route are the swarm species (30 / 50 / 70%) |
| NEWS IN START MENU | on | Shows the NEWS entry in the START menu |
| DAILY BULLETIN | on | Shows the report in POKéMON CENTERS and your house once a day |
| SWARM NOTICE | on | Shows a message when you enter the swarm route |
| CONTESTS | on | Turns the Bug-Catching Contest on or off |
| CONTEST COUNTER | on | Shows the balls and time left in the corner during a contest |
| TEST: DAYS AHEAD | 0 | For testing: pretends it's this many days later (0–30), so you can check other days' swarms and events. The report shows "TEST MODE" while it's on |

## For mod authors

Field Day publishes a versioned API. Add `"field_day"` to your
`optional_dependencies` so it loads first, then:

```lua
local fd = mod.find("field_day")
if fd and fd.exports.apiVersion == 1 then
  -- add a swarm (call this from your entry file)
  fd.exports.addSwarm{
    games = { "gen1" },          -- "gen1", "gen2", "gen3", "frlg", "rse" or "all"
    map = "ROUTE_12",            -- map id
    species = "MUNCHLAX",        -- species id; skipped if it doesn't exist
    levels = { 20, 25 },
    weight = 1,                  -- optional, relative chance (default 1)
    terrain = "grass",           -- optional: "grass", "water", "indoor" or a list
    early = false,               -- optional: true = can swarm before the route is visited
    mapName = "ROUTE 12",        -- optional: name shown in the report
  }

  -- change or veto the day's pick
  fd.exports.addSwarmFilter(function(pick, ctx)
    -- ctx = { day, weekday (1 = Sunday), generation, candidates }
    return nil      -- keep the pick
    -- return false -- no swarm today
    -- return { map = ..., species = ..., levels = { lo, hi } } -- today only
  end)
end
```

Other exports: `removeSwarm(id)`, `swarms()` (every swarm for the running
game), `today()` and `reportText()`. On contest days `today().contest` is
`{ id, name, map, mapName, active, done, remaining?, best?, placing? }`.

Events you can listen to:

- `mod.field_day.swarm_started` (`{ day, weekday, map, species, levels }`):
  a new day's swarm was decided.
- `mod.field_day.swarm_encounter` (`{ mapId, species, level }`): a swarm
  POKéMON appeared.
- `mod.field_day.contest_started` (`{ id, day, map, minutes, tier }`): the
  player entered a contest.
- `mod.field_day.contest_ended` (`{ id, day, reason, placing, species,
  level, score }`): a contest was judged. `reason` is `"time"`, `"balls"`,
  `"left"` or `"expired"`; `placing` is nil when nothing was caught.

Swarms also show up in `mod.world:effectiveEncounters`, so encounter guides
and dex radars list them.
