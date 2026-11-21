# Field Day

Daily events for gen1recomp. Every day a different POKéMON swarms one route,
and the **ROUTE REPORT** tells you where.

**This version:** swarms and the ROUTE REPORT on Red, Blue and Yellow.
Contests, Gold/Silver/Crystal and the Gen 3 games are planned.

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

## The ROUTE REPORT

- **NEWS** in the START menu shows today's report at any time.
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
game), `today()` and `reportText()`.

Events you can listen to:

- `mod.field_day.swarm_started` (`{ day, weekday, map, species, levels }`):
  a new day's swarm was decided.
- `mod.field_day.swarm_encounter` (`{ mapId, species, level }`): a swarm
  POKéMON appeared.

Swarms also show up in `mod.world:effectiveEncounters`, so encounter guides
and dex radars list them.

## Development

The headless test loads the mod on the engine's ROM-free fixture and drives
its hooks and exports. From a gen1recomp checkout:

```
luajit /path/to/field_day-repo/tests/field_day_test.lua /path/to/field_day-repo
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
