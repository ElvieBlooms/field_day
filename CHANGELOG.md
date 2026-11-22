# Changelog

## Unreleased

- Four more contests, so there's one every day: the FISHING DERBY (Mondays,
  VERMILION CITY, needs a rod), the ROCK CONTEST (Wednesdays, MT. MOON), the
  PLANT CONTEST (Fridays, ROUTES 24 and 25) and the ELECTRIC CONTEST
  (Sundays, POWER PLANT). Each has its own officer, POKéMON tiers, rivals and
  1st prize, and its own on/off option.
- ROUTE REPORT entry on every POKéMON CENTER PC (NEWS ON THE PC option).
- Other contestants wander each venue while its contest runs, with a line
  or two of chatter.
- The Bug-Catching Contest: Tuesdays, Thursdays and Saturdays in Viridian
  Forest. Sign up with the officer in the south gate, catch bugs for 20
  minutes with 20 PARK BALLs (a new contest ball that catches like a GREAT
  BALL), and your best catch is judged against five
  rivals for prizes. Bug levels rise with your gym badges. You keep your team
  and everything you catch.
- The ROUTE REPORT announces contest days, and NEWS shows the time left and
  your best catch during one.
- Only PARK BALLs work in the forest during a contest; other balls are
  refused without being used up.
- A balls-and-time counter in the bottom-right corner during a contest
  (CONTEST COUNTER option).
- Swarms skip Viridian Forest on contest days.
- CONTESTS option, `today().contest` in the exports, and
  `contest_started` / `contest_ended` events.
- TEST: DAYS AHEAD option to jump the calendar forward for testing. The
  ROUTE REPORT shows a TEST MODE line while it's on.

## 0.1.0

First release, Red, Blue and Yellow only.

- Daily swarms: one route a day where a single POKéMON takes over a share of
  the wild encounters, picked from the device's date and different per save.
- 24 Kanto swarms, mostly rare or version-exclusive POKéMON. Routes only get
  swarms after you've visited them, except a few starting routes.
- The ROUTE REPORT: NEWS in the START menu, a daily bulletin in POKéMON
  CENTERS and your house, and a notice on the swarm route.
- Options for swarms, swarm share (30/50/70%) and each kind of report.
- API for other mods (version 1): addSwarm, removeSwarm, addSwarmFilter,
  swarms, today, reportText, plus the swarm_started and swarm_encounter
  events.
