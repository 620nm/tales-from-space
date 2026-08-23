-- Plasma fire, the supersaturated branch: the same fire in a room with
-- far more oxygen than it can use, making tritium instead of exhaust.
--
-- This is `plasma_fire.luau` with two fields changed and every tuned
-- number identical — the same window, the same ramp, the same divisor,
-- the same 1 : 1.4 consumption, the same 3e6 J per mole. Two files
-- rather than one with a branch inside it, because the engine's gates
-- are how a rule says which room it is for, and two mutually exclusive
-- ratio gates are exactly two rules (docs/MATTER.md §6).
--
-- What differs:
--
--   * `ratio_at_least` where the ordinary branch says `ratio_below` —
--     tg's SUPER_SATURATION_THRESHOLD = 96, the oxygen-to-plasma ratio
--     above which the reaction goes strange. The two gates partition
--     every room between them, so exactly one of the pair can ever fire
--     in a given tile.
--   * the product is tritium and nothing else. tg's supersaturated burn
--     makes no carbon dioxide and no water: the oxygen is not going
--     into exhaust, it is going into a fusion feedstock.
--
-- Tritium's heat capacity is 10 J/(mol·K) against carbon dioxide's 30
-- and steam's 40 (substances/tritium.luau), so the same 3e6 J lands in
-- a fraction of the heat capacity and a supersaturated fire runs away
-- far harder than an ordinary one. That is tg's behaviour and it falls
-- out of the numbers rather than being written anywhere.
return {
    id = "plasma_fire_supersaturated",
    priority = "fire",
    requires = {
        { min = { "plasma:gas", 0.01 } },
        { min = { "o2:gas", 0.01 } },
        { ratio_at_least = { "o2", "plasma", "gas", 96.0 } },
    },
    temp_window = { lo = 373.15, hi = math.huge },
    reactants = { ["plasma:gas"] = 1.0, ["o2:gas"] = 1.4 },
    products = { ["tritium:gas"] = 1.0 },
    rate = {
        burn = {
            limiting = "plasma:gas",
            divisor = 9.0,
            ramp = { floor_k = 373.15, ceiling_k = 1643.15 },
        },
    },
    energy = 3.0e6,
    volatile = true,
}
