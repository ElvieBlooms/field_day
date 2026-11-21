-- Kanto swarms for Red, Blue and Yellow.
--
-- Each entry: map (map id), species (species id), levels { lo, hi },
-- optional weight (default 1), optional terrain ("grass", "water", "indoor"
-- or a list; default grass and indoor), optional mapName for the report.
-- `early = true` entries can be picked before the player has visited the
-- route, so a brand new save still gets swarms; everything else waits until
-- the player has been there at least once.
--
-- Swarms favour POKéMON that are rare, missing or version-exclusive in the
-- Gen 1 games, so they double as a way to fill the POKéDEX without trading.
return {
  { map = "ROUTE_1",         species = "PIKACHU",    levels = { 3, 5 },   early = true },
  { map = "ROUTE_2",         species = "SANDSHREW",  levels = { 3, 6 },   early = true },
  { map = "ROUTE_22",        species = "MANKEY",     levels = { 3, 6 },   early = true },
  { map = "VIRIDIAN_FOREST", species = "PARAS",      levels = { 4, 6 },   early = true },
  { map = "ROUTE_3",         species = "CLEFAIRY",   levels = { 8, 11 } },
  { map = "ROUTE_4",         species = "MEOWTH",     levels = { 10, 12 } },
  { map = "ROUTE_24",        species = "VULPIX",     levels = { 12, 15 } },
  { map = "ROUTE_25",        species = "GROWLITHE",  levels = { 12, 15 } },
  { map = "ROUTE_5",         species = "PONYTA",     levels = { 14, 17 } },
  { map = "ROUTE_6",         species = "PSYDUCK",    levels = { 14, 17 } },
  { map = "ROUTE_7",         species = "MR_MIME",    levels = { 18, 21 } },
  { map = "ROUTE_8",         species = "JYNX",       levels = { 18, 21 } },
  { map = "ROUTE_9",         species = "CUBONE",     levels = { 16, 19 } },
  { map = "ROUTE_10",        species = "VOLTORB",    levels = { 16, 20 } },
  { map = "ROUTE_11",        species = "FARFETCHD",  levels = { 15, 18 } },
  { map = "ROUTE_12",        species = "SLOWPOKE",   levels = { 22, 26 } },
  { map = "ROUTE_13",        species = "DITTO",      levels = { 22, 26 } },
  { map = "ROUTE_14",        species = "KANGASKHAN", levels = { 24, 27 }, weight = 0.5 },
  { map = "ROUTE_15",        species = "TAUROS",     levels = { 24, 27 }, weight = 0.5 },
  { map = "ROUTE_16",        species = "LICKITUNG",  levels = { 24, 27 } },
  { map = "ROUTE_17",        species = "SCYTHER",    levels = { 25, 28 }, weight = 0.5 },
  { map = "ROUTE_18",        species = "PINSIR",     levels = { 25, 28 }, weight = 0.5 },
  { map = "ROUTE_21",        species = "TANGELA",    levels = { 28, 31 } },
  { map = "ROUTE_23",        species = "EEVEE",      levels = { 30, 34 }, weight = 0.5 },
}
