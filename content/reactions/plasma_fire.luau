-- Plasma fire, the ordinary branch: the reaction the whole station is
-- built around not having.
--
-- Every number here is tg's, verbatim, from `reactions.dm:174-242` and
-- `__DEFINES/reactions.dm:37-57`:
--
--   * PLASMA_MINIMUM_BURN_TEMPERATURE = 100C + T0C = 373.15 K — the
--     window's floor AND the ramp's, because tg uses the same constant
--     for both: nothing burns below it, and at it the rate is zero.
--   * PLASMA_UPPER_TEMPERATURE = 1370C + T0C = 1643.15 K — where the
--     ramp reaches 1 and stops climbing.
--   * PLASMA_BURN_RATE_DELTA = 9 — the divisor: a tile with nine moles
--     of plasma in it burns one mole a pass at full ramp.
--   * SUPER_SATURATION_THRESHOLD = 96 — the oxygen-to-plasma ratio this
--     branch stays BELOW. At or above it the fire goes strange, and
--     that is the file next door.
--   * OXYGEN_BURN_RATIO_BASE — 1 plasma to 1.4 oxygen. tg's full-burn
--     branch refines the ratio with temperature; this is the base value
--     and the single-tier burn, and the refinement is a noted gap
--     (docs/MATTER.md §6).
--   * FIRE_PLASMA_ENERGY_RELEASED = 3e6 J per mole burnt.
--
-- `hi = math.huge` is deliberate and RATIFIED: plasma fire has a floor
-- and no ceiling. The engine's window check requires a finite `lo` and
-- `lo < hi` and deliberately does not require `hi` to be finite, so an
-- open-topped window is a first-class thing to author rather than a
-- number somebody has to invent (substances/reactions.rs).
--
-- **The humidity a fire makes is WATER, as a gas.** tg's `water_vapor`
-- is water's gas phase and this pack carries no twin for it
-- (substances/water.luau). The ported energy is untouched by that: the
-- reaction step credits each product `ratio·extent·(cv·T + b)` and the
-- temperature projection subtracts `Σ n·b` again, so a product with its
-- own gas-phase offset lands temperature-neutral and the 3e6 still buys
-- exactly tg's rise per extent.
--
-- The divergence is downstream and deliberate: a burning room sits
-- above 373.15 K, so the steam stays gas while it burns, but once the
-- cell cools past its own dew point that water condenses and gives its
-- latent heat back as a puddle. A burnt-out room ends DAMP. tg's fires
-- never rained out, because tg's fire product had no liquid phase to
-- rain into.
--
-- `volatile`: the first time this fires in a given holder in a shift is
-- a ledger row. A fire that burns for two hundred ticks is one event,
-- and the record wants the moment it started.
--
-- Atmos resin is the persistent emergency-kit state: while the tile's
-- column is at least 0.1 this rule cannot fire, so an existing fire
-- crosses the native ExtinguishedAt edge and a new one cannot start.
return {
    id = "plasma_fire",
    priority = "fire",
    requires = {
        { min = { "plasma:gas", 0.01 } },
        { min = { "o2:gas", 0.01 } },
        { ratio_below = { "o2", "plasma", "gas", 96.0 } },
        { column_below = { "atmos_resin", 0.1 } },
    },
    temp_window = { lo = 373.15, hi = math.huge },
    reactants = { ["plasma:gas"] = 1.0, ["o2:gas"] = 1.4 },
    products = { ["co2:gas"] = 1.0, ["water:gas"] = 1.0 },
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
