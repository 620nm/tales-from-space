-- The pack's thermal FEEL constants: the numbers that decide how hard a
-- run of pipe pulls on the room over it. One home, so an item declares
-- them and a spec reads the same value back rather than spelling it a
-- second time.

return {
    -- The conductivity the heat-exchange law is scaled by, 0..=1. tg's
    -- `WINDOW_HEAT_TRANSFER_COEFFICIENT`
    -- (__DEFINES/atmospherics/atmos_core.dm:122), copied verbatim.
    -- Raise it and a run drags the room faster; lower it and a freezer
    -- loop takes a shift to bite.
    he_coefficient = 0.1,

    -- The deadband: nothing moves until run and room differ by this
    -- many kelvin. tg's `minimum_temperature_difference` is 20
    -- (he_pipes.dm:2) and that is too wide here -- a run parked 20 K
    -- off could neither warm nor cool an interior room enough to feel.
    -- At 1 K a run tracks the room instead of giving up short of it.
    he_deadband_k = 1,
}
