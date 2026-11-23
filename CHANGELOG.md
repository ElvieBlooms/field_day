# Changelog

## Unreleased

Gold, Silver and Crystal.

**New**
- Field Day runs on Gold, Silver and Crystal: 33 swarms across Johto and
  Kanto, six Johto contests (DRAGON, LAKE OF RAGE DERBY, CAVE, GHOST, ICE,
  DARK) and seven Kanto contests (ELECTRIC, VERMILION DERBY, ROCK, FIRE,
  PLANT, STEEL, NORMAL) that open after the eighth Johto badge.
- Progress counts all sixteen gym leaders on Gen 2.
- The DRAGON CONTEST counts both SURF and the rod.
- Swarm and contest POKéMON are more likely to be shiny on Gen 2: 1 in
  1024 by default, set with EVENT SHINY ODDS (from the usual 1 in 8192 up to
  1 in 128).
- The ROUTE REPORT mentions the NATIONAL PARK's own BUG-CATCHING CONTEST on
  its days.

**Changed**
- Contests can wait for a number of badges before they run.
- APRICORN balls and the PARK BALL count as balls for the contest rule.

**Not changed**
- The games' own swarms, the NATIONAL PARK contest and scripted encounters
  are left exactly as they are.

## 0.1.0-beta.2

Second open beta. A FIRE CONTEST joins the week, starters and EEVEE's
evolutions can turn up as very rare contest catches, and the first round of
tester notes is in: swarms that follow your progress, police officers,
contestants who each have their own thing to say, anglers at the water's
edge, and a bulletin that comes on once per play session.

**New**

- FIRE CONTEST on Thursdays, on ROUTES 7 and 8 (sign up at the CELADON
  POKéMON CENTER), with GROWLITHE, VULPIX, PONYTA, MAGMAR and their
  evolutions. The BUG-CATCHING CONTEST is now on Tuesdays and Saturdays.
- Very rare catches, about 1 in 100: CHARMANDER and FLAREON at the fire
  contest, SQUIRTLE and VAPOREON at the derby, BULBASAUR with the plants and
  JOLTEON with the electric POKéMON. They score above everything else.

**Changed**

- Contest officers are police officers (SPRITE_GUARD). With a restyled NPC
  set they no longer turn into a man in a suit.
- Every contest has twelve lines of chatter of its own plus ten shared ones,
  and no two contestants say the same thing.
- At the FISHING DERBY, anglers stand at the water's edge facing the sea,
  and two sailors stroll the S.S. ANNE dock.
- Swarms follow your progress. Each route now unlocks with the badges you'd
  usually have when you reach it, as well as by visiting, and routes behind
  you fade: full chance within 2 badges of your progress, half at 3 or 4
  behind, a tenth at 5 or more. On an 8-badge save the four starting routes
  now get about 8% of swarms, down from all of them.
- The daily bulletin comes on once per play session: the first POKéMON
  CENTER (or your house) after you start the game, and again only if the
  date changes while you play. It used to be once per day per save, so it
  didn't come back after a restart.

**Fixed**

- Talking to a contestant gave the game's default reply, the same for
  everyone. They're now recognised and each says their own line.
- On a save that was already well along when Field Day was added, swarms
  kept landing on ROUTE 1, ROUTE 2, ROUTE 22 and VIRIDIAN FOREST, because a
  route only counted once the mod had seen you walk on it. Routes now
  unlock by badges too.

**Upgrading**

- Import the new zip over the old one. Your settings carry over, and the
  BUG-CATCHING CONTEST option now covers Tuesdays and Saturdays only.

## 0.1.0-beta.1

First public beta, for Red, Blue and Yellow. Everything works in testing,
but expect rough edges: officers or contestants standing somewhere odd,
text that reads strangely, balance that needs tuning. Please report what
you find on the repo's Issues page, with a screenshot if you can.

**Swarms**

- One route a day where a single POKéMON takes over a share of the wild
  encounters (30/50/70%, your choice). It's picked from the device's date
  and is different for each save.
- 24 Kanto swarms, mostly rare or version-exclusive POKéMON. Routes only get
  swarms after you've visited them, apart from a few starting routes.

**Contests: one every day of the week**

- BUG-CATCHING CONTEST (Tuesday, Thursday, Saturday) in VIRIDIAN FOREST,
  FISHING DERBY (Monday) in VERMILION CITY (needs a rod), ROCK CONTEST
  (Wednesday) in MT. MOON, PLANT CONTEST (Friday) on ROUTES 24 and 25, and
  ELECTRIC CONTEST (Sunday) in the POWER PLANT.
- Sign up with the contest's officer and get 20 PARK BALLs (a new ball that
  catches like a GREAT BALL) and 20 real minutes. Only PARK BALLs work in the
  venue during a contest; you keep your team and everything you catch.
- The POKéMON get stronger as you earn badges, from 0 to 6+.
- Your best catch is judged against five rivals on species, level, HP and
  DVs. Prizes: a stone for 1st, a NUGGET for 2nd, GREAT BALLs for 3rd and
  POTIONs for everyone else who caught something.
- Other contestants wander the venue while a contest runs.
- A balls-and-time counter in the bottom-right corner during a contest.
- Swarms never land on a venue on its contest day.

**The ROUTE REPORT**

- NEWS in the START menu, a ROUTE REPORT entry on every POKéMON CENTER PC, a
  daily bulletin in POKéMON CENTERS and your house, and a notice on the
  swarm route.

**Options**

- Every feature can be switched off: swarms, swarm share, each contest on
  its own (or ALL CONTESTS), the counter, and each kind of report.
- TEST: DAYS AHEAD jumps the calendar forward to try other days' swarms and
  contests. The ROUTE REPORT shows TEST MODE while it's on.

**For mod authors** (API version 1)

- `addSwarm`, `removeSwarm`, `addSwarmFilter`, `swarms`, `today` (with
  today's contests) and `reportText` exports, and the `swarm_started`,
  `swarm_encounter`, `contest_started` and `contest_ended` events. See the
  README.
