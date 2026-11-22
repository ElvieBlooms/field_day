# Field Day

Daily events for gen1recomp. Every day a different POKéMON swarms one route,
there's a contest somewhere in Kanto, and the **ROUTE REPORT** tells you
what's on.

**This version:** swarms, five contests and the ROUTE REPORT on Red, Blue and
Yellow. Gold/Silver/Crystal and the Gen 3 games are planned.

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

## Contests

There's a contest **every day of the week**. Talk to the contest's officer
to enter:

| Day | Contest | Venue | Sign up at |
|---|---|---|---|
| Sunday | ELECTRIC CONTEST | POWER PLANT (needs SURF) | ROUTE 10 POKéMON CENTER |
| Monday | FISHING DERBY | VERMILION CITY and the dock (needs a rod) | VERMILION POKéMON CENTER |
| Tuesday | BUG-CATCHING CONTEST | VIRIDIAN FOREST | VIRIDIAN FOREST south gate |
| Wednesday | ROCK CONTEST | MT. MOON | MT. MOON POKéMON CENTER |
| Thursday | BUG-CATCHING CONTEST | VIRIDIAN FOREST | VIRIDIAN FOREST south gate |
| Friday | PLANT CONTEST | ROUTES 24 and 25 | CERULEAN POKéMON CENTER |
| Saturday | BUG-CATCHING CONTEST | VIRIDIAN FOREST | VIRIDIAN FOREST south gate |

Every contest works the same way:

- You get **20 PARK BALLs** and **20 minutes** (real time) to catch the
  best POKéMON you can. During the contest the venue holds only that
  contest's POKéMON. PARK BALLs catch like GREAT BALLs and can't be used
  outside battle.
- **Only PARK BALLs** can be thrown in the venue during a contest; your own
  balls are refused (and not used up). They work as normal everywhere else.
- **The FISHING DERBY is all about the rod:** you need one to enter, and
  every cast in the venue bites with a derby POKéMON, whatever rod you use.
- A **counter** in the bottom-right corner shows the balls and time you have
  left while you walk around (it hides behind menus, text and battles).
- **Bring your whole team, and keep everything you catch.** Your best catch
  is the one that's judged.
- **You're not alone:** other contestants wander the venue while a contest
  runs. Talk to them for a bit of chatter. They leave when it's over.
- **The POKéMON grow with you.** Each contest has four tiers, at 0, 2, 4 and
  6 badges: higher tiers mean higher levels and rarer POKéMON (Scyther and
  Pinsir, Dratini and Lapras, Rhyhorn, Vileplume, Jolteon...).
- **Judging** happens when time runs out, when you run out of balls, or when
  you leave the venue. Your catch is scored on species, level, remaining HP
  and DVs, then ranked against five other entrants. Leftover balls are
  collected. (The BUG-CATCHING CONTEST also takes you back to the gate when
  time's up.)
- **Prizes:** 2nd place wins a NUGGET, 3rd five GREAT BALLs, and everyone
  else who caught something gets two POTIONs. 1st place wins a stone that
  fits the contest: a WATER STONE for the derby, a MOON STONE for rocks, a
  LEAF STONE for plants and a THUNDER STONE for electric. The bug contest's
  1st prize rotates through all five stones.

Only one contest runs at a time, swarms never land on a venue on its contest
day, and every contest can be switched off on its own in the options.

## The ROUTE REPORT

- **NEWS** in the START menu shows today's report at any time. During a
  contest it shows the time left and your best catch so far.
- **ROUTE REPORT on the PC:** every POKéMON CENTER PC has a ROUTE REPORT
  entry under the usual PCs.
- **Daily bulletin:** the first time each day you walk into a POKéMON CENTER
  or your house, the report comes on.
- **Swarm notice:** when you step onto the swarm route, you're told it's
  crawling with that POKéMON.

## Install

Download the latest `field_day-<version>.zip` from
[Releases](https://github.com/ElvieBlooms/field_day/releases) and import it in
the launcher with **Import mod .zip**. Needs gen1recomp 0.4.8 or newer.

## Options

| Option | Default | What it does |
|---|---|---|
| SWARMS | on | Turns swarms on or off |
| SWARM SHARE | 50% | How many encounters on the swarm route are the swarm species (30 / 50 / 70%) |
| NEWS IN START MENU | on | Shows the NEWS entry in the START menu |
| DAILY BULLETIN | on | Shows the report in POKéMON CENTERS and your house once a day |
| SWARM NOTICE | on | Shows a message when you enter the swarm route |
| NEWS ON THE PC | on | Adds ROUTE REPORT to the POKéMON CENTER PC |
| ALL CONTESTS | on | Turns every contest on or off at once |
| BUG-CATCHING CONTEST | on | The Tuesday/Thursday/Saturday bug contest |
| FISHING DERBY | on | The Monday fishing contest |
| ROCK CONTEST | on | The Wednesday cave contest |
| PLANT CONTEST | on | The Friday plant contest |
| ELECTRIC CONTEST | on | The Sunday electric contest |
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
game), `today()` and `reportText()`. `today().contests` lists today's
contests, each `{ id, name, map, maps, mapName, active, done, remaining?,
best?, placing? }`, and `today().contest` is the running one (or today's
first). Contest ids: `bug_catching`, `fishing_derby`, `rock_cave`, `plant`,
`electric`.

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

## Development

The headless test loads the mod on the engine's ROM-free fixture and drives
its hooks and exports. From a gen1recomp checkout:

```
luajit /path/to/field_day-repo/tests/field_day_test.lua /path/to/field_day-repo
```

The contest test needs no engine. It runs the contest against a fake mod
object and plays the officer's dialogue itself:

```
luajit tests/contest_test.lua .
```

Package with the engine's modkit:

```
python3 tools/modkit.py validate /path/to/field_day-repo/field_day --strict
python3 tools/modkit.py pack /path/to/field_day-repo/field_day -o field_day-0.1.0.zip
```

## Releasing

GitHub Actions tests every push to `main`. To publish a version:

1. Bump `version` in `field_day/manifest.json`.
2. Add a `## <version>` section to `CHANGELOG.md`.
3. Commit, then push a matching tag: `git tag v0.2.0 && git push origin v0.2.0`.

The workflow checks that the tag matches the manifest, builds the zip with
modkit, and publishes the release with that changelog section as its notes.
