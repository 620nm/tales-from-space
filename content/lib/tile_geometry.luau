-- The pack's tile box, in metres: a 1 m floor tile under a 3 m deck-to-deck
-- level, so a cell is 3 m3. `capabilities.luau` declares it as
-- `simulation.tile`; content that sizes matter to a tile reads it here, so
-- the two never drift.

return {
    width_m = 1,
    depth_m = 1,
    height_m = 3,
}
