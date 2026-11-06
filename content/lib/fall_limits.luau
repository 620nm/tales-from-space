-- How far a fall may carry sideways: the `simulation.fall` this pack declares
-- (capabilities.luau) and the one copy `lib/fall.luau` clamps glides to. A
-- leaf with no imports, so the capability load pulls in no behavior.
return {
    -- Whole tiles (Chebyshev). A folded paper plane asks 2 per level it
    -- drops (`lib/paper_plane.luau`), so 8 covers a four-level fall.
    glide_max_tiles = 8,
}
