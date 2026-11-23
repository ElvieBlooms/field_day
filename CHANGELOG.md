# Changelog

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
