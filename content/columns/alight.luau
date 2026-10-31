-- The spark latch: a tile is alight while this column is held.
-- Ethanol fire requires it, so a warm room of vapour does not start
-- burning by itself; an ignition source sets the column and the fire
-- then sustains itself on fuel and heat.
--
-- Like `atmos_resin` (columns/atmos_resin.luau) it is a column rather
-- than a substance, but it does not fade per pass.
return {
    id = "alight",
    name = "Alight",
    decay_per_pass = 0,
}
