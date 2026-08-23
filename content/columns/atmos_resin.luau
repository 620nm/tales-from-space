-- The fire-smothering skin an atmos resin projector leaves on a tile.
-- It is a column rather than a substance because the resin keeps NEW
-- fires from starting after the spray itself has gone: tg materialises a
-- transparent structure and deletes the hotspot beneath it
-- (code/game/objects/effects/effect_system/fluid_spread/effects_foam.dm:
-- 421-470). A reaction gate can read this state without putting a fake
-- mole in the room.
--
-- One percent fades per 2 Hz atmos pass. Plasma fire stays blocked down
-- to 0.1, so one application protects the tile for about two minutes;
-- the rate and threshold are TfS tuning, while decay itself is native.
return {
    id = "atmos_resin",
    name = "Atmospheric resin",
    decay_per_pass = 0.01,
}
